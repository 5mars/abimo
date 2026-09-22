#!/usr/bin/env bash
# Store-asset helper: boots the 6.9" simulator, installs a Release build, and
# wraps the capture/record/compose steps used for App Store screenshots and
# app previews. Navigation inside the app is done by hand (or by the Claude
# simulator tool) between calls.
#
#   scripts/store-assets.sh boot                 # boot iPhone 17 Pro Max (6.9")
#   scripts/store-assets.sh install              # Release build for simulator + install + launch
#   scripts/store-assets.sh shot <name>          # docs/store/raw/<name>.png (1320×2868)
#   scripts/store-assets.sh rec start <name>     # begin recording → docs/store/raw/<name>.mov
#   scripts/store-assets.sh rec stop
#   scripts/store-assets.sh compose              # docs/store/raw + captions.json → docs/store/screenshots
#   scripts/store-assets.sh preview <in.mov> <out.mp4> [start] [duration]
#       → 886×1920 30fps H.264 High L4.0 + silent stereo AAC, 15–30 s (needs ffmpeg)
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE_NAME="iPhone 17 Pro Max"
BUNDLE_ID="com.mars.Abimo"
RAW=docs/store/raw
OUT=docs/store/screenshots
DD="${STORE_DD:-/tmp/abimo-store-dd}"

udid() { xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next(x['udid'] for r in d for x in d[r] if x['name']=='$DEVICE_NAME'))"; }

case "${1:-}" in
  boot)
    U=$(udid); xcrun simctl boot "$U" 2>/dev/null || true; open -a Simulator
    xcrun simctl status_bar "$U" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
    echo "booted $DEVICE_NAME ($U), status bar cleaned";;
  install)
    U=$(udid)
    xcodebuild -project Abimo.xcodeproj -scheme Abimo -configuration Release -destination "id=$U" -derivedDataPath "$DD" build | grep -E "error:|BUILD" || true
    APP=$(find "$DD/Build/Products/Release-iphonesimulator" -maxdepth 1 -name "Abimo.app" | head -1)
    xcrun simctl install "$U" "$APP" && xcrun simctl launch "$U" "$BUNDLE_ID" >/dev/null && echo "installed + launched";;
  shot)
    mkdir -p "$RAW"; U=$(udid); xcrun simctl io "$U" screenshot --type png "$RAW/$2.png" && sips -g pixelWidth -g pixelHeight "$RAW/$2.png" | tail -2 | tr '\n' ' '; echo;;
  rec)
    mkdir -p "$RAW"; U=$(udid)
    case "$2" in
      start) nohup xcrun simctl io "$U" recordVideo --codec h264 --force "$RAW/$3.mov" >/tmp/abimo-rec.log 2>&1 & echo $! > /tmp/abimo-rec.pid; echo "recording → $RAW/$3.mov (pid $(cat /tmp/abimo-rec.pid))";;
      stop)  kill -INT "$(cat /tmp/abimo-rec.pid)" && sleep 2 && rm -f /tmp/abimo-rec.pid && echo "stopped";;
    esac;;
  compose)
    swift tools/compose-screenshots.swift docs/store/captions.json "$RAW" "$OUT";;
  preview)
    IN=$2; OUTF=$3; START=${4:-0}; DUR=${5:-25}
    ffmpeg -y -ss "$START" -t "$DUR" -i "$IN" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
      -vf "scale=886:1920:force_original_aspect_ratio=decrease,pad=886:1920:(ow-iw)/2:(oh-ih)/2,fps=30,format=yuv420p" \
      -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p -b:v 10M -c:a aac -b:a 128k -shortest -movflags +faststart "$OUTF"
    ffprobe -v error -select_streams v -show_entries stream=width,height,codec_name,profile,r_frame_rate,duration -of default=nw=1 "$OUTF";;
  *) sed -n 2,16p "$0";;
esac
