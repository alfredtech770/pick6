# Turns the Spread win push back on once Pick1 1.0.25 is live on the App Store.
# Usage: python3 spread_push_on_approval.py   (safe to run any number of times)
# Prints exactly one status line: WAITING <state>, FLIPPED, ALREADY_ON, or STOPPED <state>.
# Only ever touches one thing: affiliate_partners row 'spread-push' (enabled -> true).
import json, subprocess, sys, urllib.request
sys.path.insert(0, '/Users/ethan/betting-app/scripts/asc_2026-10-20')
import asc

APP, VER, REF = '6761689331', '1.0.25', 'lgnjawngkiamlngcffrk'
STOP = {'REJECTED', 'METADATA_REJECTED', 'DEVELOPER_REJECTED', 'INVALID_BINARY', 'REMOVED_FROM_SALE', 'DEVELOPER_REMOVED_FROM_SALE'}

v = asc.api('GET', f'/v1/apps/{APP}/appStoreVersions?filter[versionString]={VER}&filter[platform]=IOS')['data']
state = v[0]['attributes']['appStoreState'] if v else 'NOT_FOUND'
if state in STOP:
    print('STOPPED', state); sys.exit(0)
if state != 'READY_FOR_SALE':
    print('WAITING', state); sys.exit(0)

# the service key goes from the CLI straight into the request, never printed
keys = json.loads(subprocess.run(['supabase', 'projects', 'api-keys', '--project-ref', REF, '-o', 'json'], capture_output=True, text=True, check=True).stdout)
key = next(k['api_key'] for k in keys if k['name'] == 'service_role')
base = f'https://{REF}.supabase.co/rest/v1/affiliate_partners?id=eq.spread-push'
h = {'apikey': key, 'Authorization': f'Bearer {key}', 'Content-Type': 'application/json', 'Prefer': 'return=representation'}
row = json.load(urllib.request.urlopen(urllib.request.Request(base + '&select=enabled', headers=h)))
if row and row[0]['enabled']:
    print('ALREADY_ON'); sys.exit(0)
req = urllib.request.Request(base, data=json.dumps({'enabled': True}).encode(), headers=h, method='PATCH')
out = json.load(urllib.request.urlopen(req))
print('FLIPPED' if out and out[0]['enabled'] else 'FAILED')
