#!/bin/bash
# Builds CopyCatch.app from the Swift files in Sources/.
#
#   ./build.sh            build for this Mac only        → build/CopyCatch.app
#   ./build.sh install    build, copy to ~/Applications and open it
#   ./build.sh universal  build one app for Intel AND Apple Silicon Macs
#   ./build.sh dmg        universal build + drag-to-Applications disk image → build/CopyCatch-<version>.dmg
#   ./build.sh pkg        universal build + installer package (for Jamf, Intune etc.) → build/CopyCatch-<version>.pkg
#   ./build.sh release    universal build + both the .dmg and the .pkg
#
# The version number comes from Info.plist. To override it for one build:
#   VERSION=1.2.0 ./build.sh dmg
set -euo pipefail
cd "$(dirname "$0")"

NAME="CopyCatch"
APP="build/$NAME.app"
MODE="${1:-build}"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Info.plist)"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)}"

if ! command -v swiftc >/dev/null 2>&1; then
    echo "Swift compiler not found. Install Apple's Command Line Tools first:"
    echo "    xcode-select --install"
    exit 1
fi

# compile <arch> <output file>
compile() {
    swiftc -O \
        -target "$1-apple-macos13.0" \
        -parse-as-library \
        Sources/*.swift \
        -o "$2"
}

build_app() {
    local universal="$1"
    rm -rf build
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

    if [[ "$universal" == "yes" ]]; then
        echo "→ Compiling for Apple Silicon (arm64)…"
        compile arm64 "build/$NAME-arm64"
        echo "→ Compiling for Intel (x86_64)…"
        compile x86_64 "build/$NAME-x86_64"
        echo "→ Joining both into one universal app…"
        lipo -create "build/$NAME-arm64" "build/$NAME-x86_64" -output "$APP/Contents/MacOS/$NAME"
        rm "build/$NAME-arm64" "build/$NAME-x86_64"
    else
        echo "→ Compiling ($(uname -m))…"
        compile "$(uname -m)" "$APP/Contents/MacOS/$NAME"
    fi

    cp Info.plist "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
    [[ -f Icon/AppIcon.icns ]] && cp Icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

    echo "→ Signing (ad-hoc)…"
    codesign --force --deep --sign - "$APP"
    echo "✓ Built $APP (version $VERSION)"
}

make_dmg() {
    local dmg="build/$NAME-$VERSION.dmg"
    local stage="build/dmg"
    echo "→ Making $dmg…"
    rm -rf "$stage" "$dmg"
    mkdir -p "$stage"
    cp -R "$APP" "$stage/"
    ln -s /Applications "$stage/Applications"   # so people can drag the app straight in
    hdiutil create -volname "$NAME" -srcfolder "$stage" -ov -format UDZO "$dmg" >/dev/null
    rm -rf "$stage"
    echo "✓ Made $dmg"
}

make_pkg() {
    local pkg="build/$NAME-$VERSION.pkg"
    local root="build/pkgroot"
    local plist="build/component.plist"
    echo "→ Making $pkg…"
    rm -rf "$root" "$pkg"
    mkdir -p "$root"
    cp -R "$APP" "$root/"
    # Always install into /Applications, even if another copy of CopyCatch exists elsewhere
    # (by default the installer would "relocate" and update that other copy instead).
    pkgbuild --analyze --root "$root" "$plist" >/dev/null
    plutil -replace 0.BundleIsRelocatable -bool NO "$plist"
    pkgbuild --root "$root" \
        --component-plist "$plist" \
        --install-location /Applications \
        --identifier "$BUNDLE_ID" \
        --version "$VERSION" \
        "$pkg" >/dev/null
    rm -rf "$root" "$plist"
    echo "✓ Made $pkg"
}

case "$MODE" in
    build)     build_app no ;;
    universal) build_app yes ;;
    dmg)       build_app yes; make_dmg ;;
    pkg)       build_app yes; make_pkg ;;
    release)   build_app yes; make_dmg; make_pkg ;;
    install)
        build_app no
        mkdir -p "$HOME/Applications"
        pkill -x "$NAME" 2>/dev/null || true
        # This app used to be called ClipDrop: quit and remove the old copy if it is still there.
        pkill -x ClipDrop 2>/dev/null || true
        rm -rf "$HOME/Applications/ClipDrop.app"
        rm -rf "$HOME/Applications/$NAME.app"
        cp -R "$APP" "$HOME/Applications/"
        touch "$HOME/Applications/$NAME.app"   # nudge Finder/Dock to pick up the new icon
        echo "✓ Installed to ~/Applications/$NAME.app"
        open "$HOME/Applications/$NAME.app"
        ;;
    *)
        echo "Unknown option: $MODE"
        echo "Use one of: install, universal, dmg, pkg, release (or nothing for a quick build)"
        exit 1
        ;;
esac
