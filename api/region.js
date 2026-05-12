// Vercel serverless function: detect visitor region and return pricing.
// Reads the geo headers Vercel injects on every edge-network request
// (x-vercel-ip-country = ISO-3166-1 alpha-2). Returns a JSON payload the
// page reads on load and uses to swap currency + price strings.
//
// Override:  /api/region?region=eu  (or ?region=us)  for testing/preview.

const EU_EEA_COUNTRIES = new Set([
  // EU 27
  'AT','BE','BG','HR','CY','CZ','DK','EE','FI','FR','DE','GR','HU','IE','IT',
  'LV','LT','LU','MT','NL','PL','PT','RO','SK','SI','ES','SE',
  // EEA + Switzerland (use EUR pricing — same European purchasing power tier)
  'IS','LI','NO','CH',
  // UK kept on the EUR tier so post-Brexit visitors get a price near home
  'GB',
]);

const PRICING = {
  EU: {
    region:       'EU',
    currency:     'EUR',
    symbol:       '€',
    code:         'EUR',
    weekly:       '9.99',
    monthly:      '29.99',
    weeklyFull:   '€9.99',
    monthlyFull:  '€29.99',
  },
  US: {
    region:       'US',
    currency:     'USD',
    symbol:       '$',
    code:         'USD',
    weekly:       '14.99',
    monthly:      '39.99',
    weeklyFull:   '$14.99',
    monthlyFull:  '$39.99',
  },
};

module.exports = (req, res) => {
  // Allow caching for 5 min at the edge; users on the same IP shouldn't
  // re-trigger geo detection on every page load.
  res.setHeader('cache-control', 'public, max-age=0, s-maxage=300');
  res.setHeader('content-type', 'application/json; charset=utf-8');
  res.setHeader('access-control-allow-origin', '*');

  // URL override: ?region=eu | ?region=us
  const url = new URL(req.url, 'http://x');
  const override = (url.searchParams.get('region') || '').toUpperCase();
  if (override === 'EU' || override === 'US') {
    return res.end(JSON.stringify({ ...PRICING[override], detected: override, source: 'override' }));
  }

  // Vercel geo header (also try the common alternates as a fallback)
  const country = (
    req.headers['x-vercel-ip-country'] ||
    req.headers['cf-ipcountry'] ||
    req.headers['x-country-code'] ||
    ''
  ).toString().toUpperCase();

  const isEU = country && EU_EEA_COUNTRIES.has(country);
  const payload = {
    ...(isEU ? PRICING.EU : PRICING.US),
    detected: country || 'unknown',
    source: 'geoip',
  };
  res.end(JSON.stringify(payload));
};
