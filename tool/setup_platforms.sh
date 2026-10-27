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
  android)
    python3 - <<'PY'
import re
p = "android/app/src/main/AndroidManifest.xml"
s = open(p, encoding="utf-8").read()
if "android.permission.INTERNET" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="RA7AlTV"', s, count=1)
if "usesCleartextTraffic" not in s:
    s = s.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
open(p, "w", encoding="utf-8").write(s)
PY
    ;;
  windows)
    # Window title and executable description.
    sed -i 's/L"ra7altv"/L"RA7AlTV"/' windows/runner/main.cpp || true
    sed -i 's/"FileDescription", "ra7altv"/"FileDescription", "RA7AlTV"/; s/"ProductName", "ra7altv"/"ProductName", "RA7AlTV"/' windows/runner/Runner.rc || true
    ;;
esac

flutter pub get >/dev/null

# App icon for this platform only.
{
  echo "flutter_launcher_icons:"
  echo "  image_path: assets/icon.png"
  case "$PLATFORM" in
    ios) printf '  ios: true\n  android: false\n  remove_alpha_ios: true\n' ;;
    android) printf '  android: true\n  ios: false\n  min_sdk_android: 21\n' ;;
    macos) printf '  ios: false\n  android: false\n  macos:\n    generate: true\n    image_path: assets/icon.png\n' ;;
    windows) printf '  ios: false\n  android: false\n  windows:\n    generate: true\n    image_path: assets/icon.png\n    icon_size: 256\n' ;;
  esac
} > icons.yaml
dart run flutter_launcher_icons -f icons.yaml || echo "icon generation skipped"
rm -f icons.yaml
echo "Platform $PLATFORM ready"
