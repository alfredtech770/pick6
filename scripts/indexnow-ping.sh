#!/usr/bin/env bash
# IndexNow — ping search engines to re-crawl pick1.live URLs.
# Run after a deploy that touches indexable content.
#
# Usage:
#   ./scripts/indexnow-ping.sh                       # pings the homepage + sitemap
#   ./scripts/indexnow-ping.sh /blog/new-post /nba   # pings specific paths
#
# IndexNow is supported by Bing, Yandex, Naver, Seznam, and indirectly
# feeds the Bing AI Overview / Copilot / ChatGPT-search index.

set -e

KEY="1e2fe6c551e6efa4042febc718c5e4e8"
HOST="pick1.live"
KEY_LOCATION="https://pick1.live/${KEY}.txt"
ENDPOINT="https://api.indexnow.org/IndexNow"

# Default URLs to ping (homepage + every key page) when no args given
if [ "$#" -eq 0 ]; then
  PATHS=(
    "/"
    "/about"
    "/methodology"
    "/blog"
    "/blog/kalshi-polymarket-sports"
    "/blog/ai-vs-tipsters"
    "/blog/closing-line-value"
    "/blog/public-results"
    "/nba" "/nfl" "/epl" "/mlb" "/ufc"
    "/privacy" "/terms"
    "/sitemap.xml"
  )
else
  PATHS=("$@")
fi

# Build JSON URL list
URL_LIST=""
for p in "${PATHS[@]}"; do
  URL="https://${HOST}${p}"
  if [ -z "$URL_LIST" ]; then
    URL_LIST="\"$URL\""
  else
    URL_LIST="$URL_LIST,\"$URL\""
  fi
done

PAYLOAD=$(cat <<JSON
{
  "host": "${HOST}",
  "key": "${KEY}",
  "keyLocation": "${KEY_LOCATION}",
  "urlList": [${URL_LIST}]
}
JSON
)

echo "Pinging IndexNow with ${#PATHS[@]} URLs..."
RESPONSE_CODE=$(curl -s -o /tmp/indexnow-response.txt -w "%{http_code}" \
  -X POST "${ENDPOINT}" \
  -H "Content-Type: application/json; charset=utf-8" \
  --data "${PAYLOAD}")

echo "HTTP ${RESPONSE_CODE}"
if [ "${RESPONSE_CODE}" = "200" ] || [ "${RESPONSE_CODE}" = "202" ]; then
  echo "✓ Submitted. Bing, Yandex, Naver, Seznam will re-crawl shortly."
else
  echo "✗ Unexpected status. Response body:"
  cat /tmp/indexnow-response.txt
  exit 1
fi
