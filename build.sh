#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
app="$PWD/CaffeinateBar.app"
mkdir -p "$app/Contents/MacOS" "$PWD/.build/module-cache"
xcrun swiftc Sources/main.swift -o "$app/Contents/MacOS/CaffeinateBar" \
  -target "$(uname -m)-apple-macosx13.0" -O \
  -module-cache-path "$PWD/.build/module-cache" \
  -framework AppKit -framework ServiceManagement
mkdir -p "$app/Contents/Resources" "$PWD/.build/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Resources/Icon.png --out ".build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  doubled=$((size * 2))
  sips -z "$doubled" "$doubled" Resources/Icon.png --out ".build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
python3 - "$app/Contents/Resources/AppIcon.icns" <<'PYICON'
import pathlib, struct, sys
chunks = []
for kind, name in [('icp4', '16x16'), ('icp5', '32x32'), ('icp6', '32x32@2x'), ('ic07', '128x128'), ('ic08', '256x256'), ('ic09', '512x512'), ('ic10', '512x512@2x')]:
    data = pathlib.Path('.build/AppIcon.iconset/icon_' + name + '.png').read_bytes()
    chunks.append(kind.encode() + struct.pack('>I', len(data) + 8) + data)
body = b''.join(chunks)
pathlib.Path(sys.argv[1]).write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
PYICON
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - --identifier local.elliot.CaffeinateBar "$app"
echo "Built $app"
