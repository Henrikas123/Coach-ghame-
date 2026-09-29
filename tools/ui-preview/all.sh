#!/bin/bash
# Paleidžia scenarijus (visus arba nurodytus) ir padaro ekrano nuotraukas į shots/.
# Reikia: lune (cargo install lune), node + playwright, python3 (vienkartiniam fetch_assets.py).
cd "$(dirname "$0")"
[ -f cache/api.json ] || python3 fetch_assets.py || exit 1
if [ $# -eq 0 ]; then
  set -- $(grep -oE '^S\.[a-z_0-9]+' scenarios.luau | sed 's/S\.//' | sort -u)
fi
fail=0
for s in "$@"; do
  out=$(timeout 180 lune run run.luau "$s" 2>&1 | grep -v "DataStore nepasiekiamas")
  echo "$out" | grep -E "ERROR|CHECK|errors" | head -20
  echo "$out" | grep -q "CHECK FAILED\|\[ERROR\]" && fail=1
done
PLAYWRIGHT_PATH=${PLAYWRIGHT_PATH:-$(npm root -g)/playwright} timeout 900 node shoot.js "$@"
exit $fail
