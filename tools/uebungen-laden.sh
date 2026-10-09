#!/usr/bin/env bash
# Loads the free ExerciseDB v1 set (1,500 exercises, 180p GIFs): rows into tools/uebungen-roh.json
# (skipped if it exists), animations into tools/gifs/<exerciseId>.gif (git-ignored, existing ones skipped).
# The app does not bundle them: it loads each GIF on demand from ExerciseDB (`UebungsMedien`).
# They are only needed here so `uebungen-katalog.sh` keeps exactly the exercises that have one.
# Rate limited (Cloudflare 1015): pauses between calls, retries after a longer wait.
set -euo pipefail
hier="$(cd "$(dirname "$0")" && pwd)"
roh="$hier/uebungen-roh.json"
ziel="$hier/gifs"
mkdir -p "$ziel"
if [ ! -s "$roh" ]; then
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
    [ "$(echo "$antwort" | jq -r '.meta.hasNextPage' | tr -d '\r')" = "true" ] || break
    nach="$(echo "$antwort" | jq -r '.meta.nextCursor' | tr -d '\r')"
    sleep 2
  done
  jq 'unique_by(.exerciseId) | sort_by(.exerciseId)' "$tmp" > "$roh"
fi
echo "Uebungen: $(jq length "$roh")"
# tr: jq on Windows ends lines with CRLF
jq -r '.[] | "\(.exerciseId) \(.gifUrl)"' "$roh" | tr -d '\r' | while read -r id url; do
  [ -s "$ziel/$id.gif" ] && continue
  for versuch in 1 2 3 4 5; do
    code="$(curl -s -o "$ziel/$id.gif" -w '%{http_code}' "$url" || true)"
    if [ "$code" = "200" ] && [ "$(head -c 3 "$ziel/$id.gif")" = "GIF" ]; then break; fi
    rm -f "$ziel/$id.gif"
    # ExerciseDB has no GIF for a few ids: skip those, retry only rate limits and network errors.
    if [ "$code" = "404" ]; then echo "fehlt: $id"; break; fi
    sleep $((versuch * 10))
  done
  sleep 0.2
done
echo "GIFs: $(ls "$ziel"/*.gif | wc -l)"
