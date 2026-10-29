#!/bin/bash
# Rebuild the Seeker-patched GCam from the original BSG APK.
#
#   ./rebuild.sh /path/to/MGC_9.4.103_V41_snap.apk [out.apk]
#
# Needs: java 17+, Android build-tools (zipalign, apksigner), ~/.android/debug.keystore.
# Only classes.dex and classes2.dex are replaced; every other entry of the original APK is kept.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
OUT=${2:-$HERE/MGC_9.4.103_V41_seeker-patched.apk}
BT=${BUILD_TOOLS:-$(ls -d ~/Library/Android/sdk/build-tools/* | sort -V | tail -1)}
APKTOOL=${APKTOOL:-$HERE/apktool_2.10.0.jar}
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

if [ ! -f "$APKTOOL" ]; then
  echo "== fetch apktool 2.10.0"
  curl -sfL -o "$APKTOOL" https://github.com/iBotPeaches/Apktool/releases/download/v2.10.0/apktool_2.10.0.jar
fi

echo "== decode"
java -Xmx8g -jar "$APKTOOL" d --no-res -f -o "$W/dec" "$SRC" >/dev/null

echo "== patch"
for p in "$HERE"/patches/*.diff; do
  echo "   $(basename "$p")"
  patch -s -p0 -d "$W/dec" < "$p"
done

echo "== assemble dex"
java -Xmx10g -jar "$APKTOOL" b "$W/dec" -o "$W/rebuilt.apk" >/dev/null

echo "== inject + sign"
cp "$SRC" "$W/work.apk"
# BSG's v1 signature files are dropped; NoiseModels$0.ab no longer needs META-INF/BSG.RSA.
zip -q -d "$W/work.apk" 'META-INF/BSG.SF' 'META-INF/BSG.RSA' 'META-INF/MANIFEST.MF'
mkdir "$W/inj"
cp "$W/dec/build/apk/classes.dex" "$W/dec/build/apk/classes2.dex" "$W/inj/"
(cd "$W/inj" && zip -q "$W/work.apk" classes.dex classes2.dex)
"$BT/zipalign" -P 16 -f 4 "$W/work.apk" "$W/aligned.apk"
"$BT/apksigner" sign --v1-signing-enabled false \
  --ks ~/.android/debug.keystore --ks-pass pass:android --key-pass pass:android --ks-key-alias androiddebugkey \
  --out "$OUT" "$W/aligned.apk"
"$BT/apksigner" verify "$OUT"
echo "OK: $OUT"
