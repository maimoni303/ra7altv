#!/usr/bin/env bash
# Generates the native platform folders with `flutter create`, then applies
# RA7AlTV's settings (cleartext/self-signed IPTV servers, network entitlement,
# deployment targets, display name, icons). Usage: tool/setup_platforms.sh ios|macos|windows
set -euo pipefail
PLATFORM="$1"

flutter create --platforms="$PLATFORM" --org com.ra7al --project-name ra7altv . >/dev/null
rm -rf test   # flutter create adds a sample test that does not apply here

pb() { /usr/libexec/PlistBuddy "$@" 2>/dev/null || true; }

allow_http() {   # $1 = Info.plist
  pb -c "Delete :NSAppTransportSecurity" "$1"
  pb -c "Add :NSAppTransportSecurity dict" "$1"
  pb -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" "$1"
  pb -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoadsForMedia bool true" "$1"
}

case "$PLATFORM" in
  ios)
    PLIST=ios/Runner/Info.plist
    allow_http "$PLIST"
    pb -c "Set :CFBundleDisplayName RA7AlTV" "$PLIST" || pb -c "Add :CFBundleDisplayName string RA7AlTV" "$PLIST"
    pb -c "Add :UIBackgroundModes array" "$PLIST"
    pb -c "Add :UIBackgroundModes:0 string audio" "$PLIST"
    pb -c "Add :LSApplicationCategoryType string public.app-category.entertainment" "$PLIST"
    if [ -f ios/Podfile ]; then
      sed -i '' -E "s/^#? *platform :ios, '[0-9.]+'/platform :ios, '13.0'/" ios/Podfile
    fi
    ;;
  macos)
    allow_http macos/Runner/Info.plist
    for ENT in macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements; do
      pb -c "Add :com.apple.security.network.client bool true" "$ENT"
      pb -c "Set :com.apple.security.network.client true" "$ENT"
    done
    sed -i '' -E 's/^PRODUCT_NAME = .*/PRODUCT_NAME = RA7AlTV/' macos/Runner/Configs/AppInfo.xcconfig
    sed -i '' -E 's/MACOSX_DEPLOYMENT_TARGET = 10\.[0-9]+;/MACOSX_DEPLOYMENT_TARGET = 10.15;/g' macos/Runner.xcodeproj/project.pbxproj
    if [ -f macos/Podfile ]; then
      sed -i '' -E "s/^#? *platform :osx, '[0-9.]+'/platform :osx, '10.15'/" macos/Podfile
    fi
    ;;
  windows)
    # Window title and executable description.
    sed -i 's/L"ra7altv"/L"RA7AlTV"/' windows/runner/main.cpp || true
    sed -i 's/"FileDescription", "ra7altv"/"FileDescription", "RA7AlTV"/; s/"ProductName", "ra7altv"/"ProductName", "RA7AlTV"/' windows/runner/Runner.rc || true
    ;;
esac

flutter pub get >/dev/null
dart run flutter_launcher_icons >/dev/null || echo "icon generation skipped"
echo "Platform $PLATFORM ready"
