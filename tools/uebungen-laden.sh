#!/usr/bin/env bash
# Loads the free ExerciseDB v1 set (1,500 exercises, 180p GIFs) into Lovea/Uebungen/.
# roh.json = raw API rows; <exerciseId>.gif = animation. Re-run safe: existing GIFs are skipped.
# Rate limited (Cloudflare 1015): pauses between calls, retries after a longer wait.
set -euo pipefail
ziel="$(cd "$(dirname "$0")/.." && pwd)/Lovea/Uebungen"
mkdir -p "$ziel"
api="https://oss.exercisedb.dev/api/v1/exercises?limit=25"
tmp="$(mktemp)"; echo '[]' > "$tmp"
nach=""
while :; do
  for versuch in 1 2 3 4 5; do
    antwort="$(curl -s "$api${nach:+&after=$nach}")"
    if echo "$antwort" | jq -e '.success == true' >/dev/null 2>&1; then break; fi
    sleep $((versuch * 20))
  done
  echo "$antwort" | jq '.data' | jq -s '.[0] + .[1]' "$tmp" - > "$tmp.neu" && mv "$tmp.neu" "$tmp"
  [ "$(echo "$antwort" | jq -r '.meta.hasNextPage')" = "true" ] || break
  nach="$(echo "$antwort" | jq -r '.meta.nextCursor')"
  sleep 2
done
jq 'unique_by(.exerciseId) | sort_by(.exerciseId)' "$tmp" > "$ziel/roh.json"
echo "Uebungen: $(jq length "$ziel/roh.json")"
jq -r '.[] | "\(.exerciseId) \(.gifUrl)"' "$ziel/roh.json" | while read -r id url; do
  [ -s "$ziel/$id.gif" ] && continue
  for versuch in 1 2 3 4 5; do
    if curl -sf -o "$ziel/$id.gif" "$url" && [ "$(head -c 3 "$ziel/$id.gif")" = "GIF" ]; then break; fi
    rm -f "$ziel/$id.gif"; sleep $((versuch * 10))
  done
  sleep 0.3
done
echo "GIFs: $(ls "$ziel"/*.gif | wc -l)"
