#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
APP="$SCRIPT_DIR/dist/build/vRemote.app"
CONTENTS="$APP/Contents"

cd "$SCRIPT_DIR"
swift build -c release

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"
cp "$SCRIPT_DIR/.build/release/vRemote" "$CONTENTS/MacOS/vRemote"
cp "$SCRIPT_DIR/Packaging/Info.plist" "$CONTENTS/Info.plist"
# App-owned language resources are also processed by SwiftPM for swift run.
for language in en zh-Hans zh-Hant; do
  ditto "$SCRIPT_DIR/Sources/vRemote/Resources/$language.lproj" \
    "$CONTENTS/Resources/$language.lproj"
done
for localization in "$SCRIPT_DIR/Packaging"/*.lproj; do
  [[ -d "$localization" ]] || continue
  ditto "$localization" "$CONTENTS/Resources/${localization:t}"
done
cp "$SCRIPT_DIR/Resources/AppIcon/placeholder-app-icon.png" \
  "$CONTENTS/Resources/AppIcon.png"

ICONSET="$SCRIPT_DIR/dist/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
sips -z 16 16 "$CONTENTS/Resources/AppIcon.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$CONTENTS/Resources/AppIcon.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$CONTENTS/Resources/AppIcon.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$CONTENTS/Resources/AppIcon.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$CONTENTS/Resources/AppIcon.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$CONTENTS/Resources/AppIcon.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$CONTENTS/Resources/AppIcon.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$CONTENTS/Resources/AppIcon.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$CONTENTS/Resources/AppIcon.png" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$CONTENTS/Resources/AppIcon.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# Permission help is drawn with localized native controls; no inherited screenshots.
# Only the image used by the native Chromecast mapping canvas is bundled.
mkdir -p "$CONTENTS/Resources/RemoteImages"
cp "$SCRIPT_DIR/Resources/RemoteImages/chromecast-front-and-volume-enhanced.png" \
  "$CONTENTS/Resources/RemoteImages/chromecast-front-and-volume-enhanced.png"

# Binary distributions must carry the inherited copyright and license notices.
mkdir -p "$CONTENTS/Resources/Licenses"
cp "$SCRIPT_DIR/LICENSE" "$CONTENTS/Resources/Licenses/LICENSE"
cp "$SCRIPT_DIR/THIRD_PARTY_NOTICES.md" "$CONTENTS/Resources/Licenses/THIRD_PARTY_NOTICES.md"
cp "$SCRIPT_DIR/docs/PROJECT_OWNERSHIP_AND_LICENSES.md" \
  "$CONTENTS/Resources/Licenses/PROJECT_OWNERSHIP_AND_LICENSES.md"

chmod 755 "$CONTENTS/MacOS/vRemote"
# The app bundle is a disposable build artifact. Make it owner-writable
# before clearing inherited metadata and applying the final ad-hoc signature.
chmod -R u+w "$APP"
xattr -cr "$APP"

# Give the ad-hoc build a stable designated requirement. Without this,
# codesign falls back to a CDHash-only requirement, so every rebuild looks
# like a different application to Accessibility/Input Monitoring (TCC).
codesign \
  --force \
  --deep \
  --sign - \
  --timestamp=none \
  --requirements '=designated => identifier "local.simaqingfeng.vRemote"' \
  "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
print "Built: $APP"
