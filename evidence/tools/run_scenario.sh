#!/bin/bash
# usage: run_scenario.sh <scenario> <outdir>
set -u
SC=$1; OUT=$2; mkdir -p "$OUT"
cd /home/user/otcv8/otcv8-dev
echo "$SC" > mods/autotest/scenario.txt
LOG=$OUT/client_$SC.log
pkill -x otclient 2>/dev/null; sleep 1
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 ./otclient > "$LOG" 2>&1 &
PID=$!
seen=""
for i in $(seq 1 600); do
  while read -r name; do
    if ! grep -qx "$name" <<<"$seen"; then
      DISPLAY=:99 import -window root "$OUT/$name.png"; seen="$seen"$'\n'"$name"; echo "shot $name"
    fi
  done < <(grep -o "\[AUTOTEST\] [0-9]* SHOT .*" "$LOG" | awk "{print \$4}")
  grep -q "\[AUTOTEST\] DONE" "$LOG" && break
  sleep 0.2
done
sleep 1; kill $PID 2>/dev/null
grep "AUTOTEST" "$LOG"
