#!/usr/bin/env bash
# Two-phase walk (see walk-drop.yml). Phase A opens checkout; then waits up to ~15 min for Tab's go flag in the drop.
set -u
export OUT=/tmp/dsk-out; mkdir -p $OUT
R=.github/walk-request; U=https://hs-apk-drop.charles-h-hartmann1.workers.dev
N=$(sed -n 1p $R/request.txt | tr -cd 'A-Za-z0-9_-')
A=$(ls dsk-apk/*.apk | head -1); PKG=$(sed -n 2p $R/request.txt | tr -cd 'A-Za-z0-9._')
adb wait-for-device; adb shell getprop ro.build.version.release </dev/null | sed 's/^/android /' | tee $OUT/device.txt
KEEP_APP=1 bash .github/walk/direct-test.sh "$A" "$PKG" $R/steps-a.txt buy || true
echo '{"phase":"A done"}' | curl -s -m 30 -X PUT -H "X-Key: $DROP_KEY" --data-binary @- "$U/c/ready_$N/0" >/dev/null || true
echo "[$(date +%H:%M:%S)] phase A done; waiting for go flag" | tee -a $OUT/steps.log
go=0; for i in $(seq 1 90); do if curl -sf -m 20 -H "X-Key: $DROP_KEY" "$U/c/go_$N/0" >/dev/null; then go=1; break; fi; sleep 10; done
echo "[$(date +%H:%M:%S)] go flag: $go" | tee -a $OUT/steps.log
KEEP_APP=1 bash .github/walk/direct-test.sh "$A" "$PKG" $R/steps-b.txt restore || true
bash .github/walk/direct-test.sh "$A" "$PKG" $R/steps-c.txt relaunch || true
ls -la $OUT | tail -80
cat $OUT/*-fatal.txt 2>/dev/null | head -40
