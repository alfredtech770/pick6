import Foundation
import Compression
import CoreGraphics

/// Indexed (palette) PNG encoder for crests carried inside a Live Activity.
///
/// ActivityKit rejects attributes over 4096 bytes, and two crests are most of
/// that. iOS only writes 32-bit PNGs (about 3.4KB for a 36px crest, plus a
/// colour profile) and its JPEGs carry ~600 bytes of headers, so neither fits.
/// A 32-colour palette PNG of the same crest is about 850 bytes.
enum TinyPNG {
    static func encode(_ image: CGImage, side: Int, colors: Int = 32) -> Data? {
        let w = side, h = side
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &rgba, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        // Fit the crest in the square, keeping its proportions.
        let iw = CGFloat(image.width), ih = CGFloat(image.height)
        let scale = min(CGFloat(w) / iw, CGFloat(h) / ih)
        let dw = iw * scale, dh = ih * scale
        ctx.draw(image, in: CGRect(x: (CGFloat(w) - dw) / 2, y: (CGFloat(h) - dh) / 2, width: dw, height: dh))

        // Un-premultiply and bucket colours at 4 bits per channel.
        var counts: [UInt16: Int] = [:]
        var keys = [UInt16](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            let a = rgba[i * 4 + 3]
            if a < 24 { keys[i] = 0xFFFF; continue }
            let un: (UInt8) -> UInt8 = { c in UInt8(min(255, Int(c) * 255 / Int(a))) }
            let r = un(rgba[i * 4]), g = un(rgba[i * 4 + 1]), b = un(rgba[i * 4 + 2])
            rgba[i * 4] = r; rgba[i * 4 + 1] = g; rgba[i * 4 + 2] = b
            let k = UInt16(r >> 4) << 12 | UInt16(g >> 4) << 8 | UInt16(b >> 4) << 4 | UInt16(a >> 4)
            keys[i] = k
            counts[k, default: 0] += 1
        }
        // Palette: index 0 transparent, then the most common buckets.
        let top = counts.sorted { $0.value > $1.value }.prefix(colors - 1).map(\.key)
        var palette: [(UInt8, UInt8, UInt8, UInt8)] = [(0, 0, 0, 0)]
        for k in top {
            let ex: (UInt16) -> UInt8 = { v in UInt8(v & 0xF) * 17 }
            palette.append((ex(k >> 12), ex(k >> 8), ex(k >> 4), ex(k)))
        }
        var cache: [UInt16: UInt8] = [0xFFFF: 0]
        var raw = [UInt8](); raw.reserveCapacity(h * (w + 1))
        for y in 0..<h {
            raw.append(0)   // filter: none
            for x in 0..<w {
                let i = y * w + x
                if let idx = cache[keys[i]] { raw.append(idx); continue }
                let r = Int(rgba[i * 4]), g = Int(rgba[i * 4 + 1]), b = Int(rgba[i * 4 + 2]), a = Int(rgba[i * 4 + 3])
                var best = 1, bestD = Int.max
                for (j, p) in palette.enumerated().dropFirst() {
                    let d = (r - Int(p.0)) * (r - Int(p.0)) + (g - Int(p.1)) * (g - Int(p.1))
                        + (b - Int(p.2)) * (b - Int(p.2)) + (a - Int(p.3)) * (a - Int(p.3))
                    if d < bestD { bestD = d; best = j }
                }
                cache[keys[i]] = UInt8(best)
                raw.append(UInt8(best))
            }
        }
        guard let deflated = zlib(raw) else { return nil }

        var png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        var ihdr = Data(); ihdr.append(be32(w)); ihdr.append(be32(h)); ihdr.append(contentsOf: [8, 3, 0, 0, 0])
        png.append(chunk("IHDR", ihdr))
        png.append(chunk("PLTE", Data(palette.flatMap { [$0.0, $0.1, $0.2] })))
        png.append(chunk("tRNS", Data(palette.map { $0.3 })))
        png.append(chunk("IDAT", deflated))
        png.append(chunk("IEND", Data()))
        return png
    }

    private static func be32(_ v: Int) -> Data { Data([UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)]) }

    private static func chunk(_ type: String, _ body: Data) -> Data {
        var d = be32(body.count)
        var crcInput = Data(type.utf8); crcInput.append(body)
        d.append(crcInput)
        d.append(be32(Int(crc32(crcInput))))
        return d
    }

    private static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
        return c
    }
    private static func crc32(_ d: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for b in d { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFFFFFF
    }

    /// zlib stream: header, raw deflate from the Compression framework, Adler-32.
    private static func zlib(_ input: [UInt8]) -> Data? {
        let cap = input.count + 1024
        var out = [UInt8](repeating: 0, count: cap)
        let n = compression_encode_buffer(&out, cap, input, input.count, nil, COMPRESSION_ZLIB)
        guard n > 0 else { return nil }
        var a: UInt32 = 1, b: UInt32 = 0
        for x in input { a = (a + UInt32(x)) % 65521; b = (b + a) % 65521 }
        var d = Data([0x78, 0xDA]); d.append(contentsOf: out[0..<n]); d.append(be32(Int(b << 16 | a)))
        return d
    }
}
