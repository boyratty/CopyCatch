#!/bin/bash
# Builds CopyCatch.app from the Swift files in Sources/.
#   ./build.sh           build into ./build/CopyCatch.app
#   ./build.sh install   build, copy to ~/Applications and open it
set -euo pipefail
cd "$(dirname "$0")"

APP="build/CopyCatch.app"

if ! command -v swiftc >/dev/null 2>&1; then
    echo "Swift compiler not found. Install Apple's Command Line Tools first:"
    echo "    xcode-select --install"
    exit 1
fi

echo "→ Compiling ($(uname -m))…"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O \
    -target "$(uname -m)-apple-macos13.0" \
    -parse-as-library \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/CopyCatch"

cp Info.plist "$APP/Contents/Info.plist"
[[ -f Icon/AppIcon.icns ]] && cp Icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "→ Signing (ad-hoc, for this Mac only)…"
codesign --force --deep --sign - "$APP"

echo "✓ Built $APP"

if [[ "${1:-}" == "install" ]]; then
    mkdir -p "$HOME/Applications"
    pkill -x CopyCatch 2>/dev/null || true
    # This app used to be called ClipDrop: quit and remove the old copy if it is still there.
    pkill -x ClipDrop 2>/dev/null || true
    rm -rf "$HOME/Applications/ClipDrop.app"
    rm -rf "$HOME/Applications/CopyCatch.app"
    cp -R "$APP" "$HOME/Applications/"
    touch "$HOME/Applications/CopyCatch.app"   # nudge Finder/Dock to pick up the new icon
    echo "✓ Installed to ~/Applications/CopyCatch.app"
    open "$HOME/Applications/CopyCatch.app"
fi
