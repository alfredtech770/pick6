# Black Friday push for Spread (approved by Ethan 2026-11-25), one literal send per language to devices seen in 42 days.
# DRY=1 previews counts only. A marker file stops it from ever sending twice.
import json, os, subprocess, urllib.request
REF = 'lgnjawngkiamlngcffrk'
DRY = os.environ.get('DRY') == '1'
COPY = {
  'en': ('Black Friday: 50% off Spread', 'Bet our bankroll, keep 80% of the profit. Challenges from $24.50 until Monday at spreadbets.xyz'),
  'fr': ('Black Friday : -50 % sur Spread', 'Pariez avec notre bankroll, gardez 80 % des gains. Dès 24,50 $ jusqu\'à lundi sur spreadbets.xyz'),
  'es': ('Black Friday: 50% en Spread', 'Apuesta con nuestro bankroll y quédate el 80%. Desde $24.50 hasta el lunes en spreadbets.xyz'),
  'pt': ('Black Friday: 50% na Spread', 'Aposte com a nossa banca e fique com 80% do lucro. Desde $24,50 até segunda em spreadbets.xyz'),
}
keys = json.loads(subprocess.run(['supabase', 'projects', 'api-keys', '--project-ref', REF, '-o', 'json'], capture_output=True, text=True, check=True).stdout)
key = next(k['api_key'] for k in keys if k['name'] == 'service_role')
h = {'apikey': key, 'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'}
def get(path):
    return json.load(urllib.request.urlopen(urllib.request.Request(f'https://{REF}.supabase.co/rest/v1/{path}', headers=h)))
import datetime
since = (datetime.datetime.utcnow() - datetime.timedelta(days=42)).strftime('%Y-%m-%dT%H:%M:%S')
rows = get(f'device_tokens?select=user_id,locale&user_id=not.is.null&last_seen_at=gte.{since}&limit=10000')
by = {}
for r in rows:
    lang = (r.get('locale') or 'en').split('-')[0].split('_')[0].lower()
    lang = lang if lang in COPY else 'en'
    by.setdefault(lang, set()).add(r['user_id'])
MARK = os.path.expanduser('~/betting-app/scripts/release_2026-10/.spread_bf_push_sent')
if not DRY and os.path.exists(MARK):
    print('ALREADY SENT'); raise SystemExit(0)
out = {}
for lang, ids in by.items():
    t, b = COPY[lang]
    assert len(t) <= 40 and len(b) <= 115, (lang, len(t), len(b))
    body = {'title': t, 'body': b, 'userIds': sorted(ids), 'dryRun': DRY, 'data': {'campaign': 'spread_bf_2026'}}
    req = urllib.request.Request(f'https://{REF}.supabase.co/functions/v1/send-push', data=json.dumps(body).encode(), headers=h, method='POST')
    try:
        res = json.load(urllib.request.urlopen(req, timeout=120))
    except urllib.error.HTTPError as e:
        res = {'error': e.code, 'body': e.read().decode()[:300]}
    out[lang] = {'users': len(ids), 'result': {k: v for k, v in res.items() if k not in ('tokens', 'sample')} if isinstance(res, dict) else res}
print(json.dumps(out, indent=1)[:3000])
if not DRY:
    open(MARK, 'w').write(json.dumps(out))
