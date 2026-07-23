#!/usr/bin/env python3
"""
Port the iOS in-code localization tables (Betting app/Localization/Lang/*.swift)
into Android string resources (android/app/src/main/res/values*/strings.xml).

iOS table entry:      .some_key: "Some value {n}",
Android resource:     <string name="some_key">Some value %1$d</string>

Notes:
  * {n} is the iOS interpolation placeholder -> Android positional %1$d.
  * Android requires escaping of ' " @ ? and newlines inside string resources.
  * en -> values/ (default), others -> values-<lang>/.
"""
import os, re, html

IOS_LANG_DIR = "/Users/ethan/betting-app/Betting app/Localization/Lang"
AND_RES_DIR  = "/Users/ethan/betting-app/android/app/src/main/res"

LANG_TO_DIR = {
    "en": "values",       # default
    "es": "values-es",
    "fr": "values-fr",
    "de": "values-de",
    "it": "values-it",
    "pt": "values-pt",
    "ar": "values-ar",
}

# .key: "value",   (value may contain escaped quotes and \n)
ENTRY_RE = re.compile(r'^\s*\.(\w+)\s*:\s*"((?:[^"\\]|\\.)*)"\s*,\s*$')


def parse_swift_table(path):
    """Return ordered [(key, value)] from a Lang/<code>.swift table."""
    out = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            m = ENTRY_RE.match(line)
            if m:
                key, raw = m.group(1), m.group(2)
                # Un-escape Swift string escapes into real characters.
                val = raw.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")
                out.append((key, val))
    return out


def to_android(value):
    """Escape a literal string for an Android <string> resource body."""
    v = value
    # {n} is the only interpolation the iOS tables use -> positional int arg.
    has_arg = "{n}" in v
    v = v.replace("%", "%%")          # literal % must be doubled once we format
    v = v.replace("{n}", "%1$d")
    # XML entities first, then Android-specific escapes.
    v = html.escape(v, quote=False)   # & < >
    v = v.replace('"', '\\"').replace("'", "\\'")
    v = v.replace("@", "\\@").replace("?", "\\?") if v[:1] in ("@", "?") else v
    v = v.replace("\n", "\\n")
    return v, has_arg


def main():
    # en defines the canonical key set/order.
    en_entries = parse_swift_table(os.path.join(IOS_LANG_DIR, "en.swift"))
    en_keys = [k for k, _ in en_entries]
    print(f"en: {len(en_entries)} keys")

    for lang, subdir in LANG_TO_DIR.items():
        src = os.path.join(IOS_LANG_DIR, f"{lang}.swift")
        entries = dict(parse_swift_table(src))
        outdir = os.path.join(AND_RES_DIR, subdir)
        os.makedirs(outdir, exist_ok=True)

        lines = ['<?xml version="1.0" encoding="utf-8"?>',
                 "<!-- Generated from Betting app/Localization/Lang/%s.swift -->" % lang,
                 "<!-- Do not hand-edit: re-run scratchpad/port_l10n.py after changing the iOS tables. -->",
                 "<resources>"]
        # NOTE: app_name already exists in the iOS tables, so it is emitted by
        # the loop below — don't add it again or resource merging fails with
        # "Found item String/app_name more than one time".

        n = 0
        for key in en_keys:
            if key not in entries:
                continue   # falls back to the default (en) resource at runtime
            body, has_arg = to_android(entries[key])
            fmt = "" if has_arg else ' formatted="false"' if "%%" in body else ""
            lines.append(f'    <string name="{key}">{body}</string>')
            n += 1
        lines.append("</resources>")

        path = os.path.join(outdir, "strings.xml")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
        print(f"{lang}: {n} strings -> {subdir}/strings.xml")


if __name__ == "__main__":
    main()
