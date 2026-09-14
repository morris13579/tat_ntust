#!/usr/bin/env bash
#
# 打包可上架的 Android AAB 與 iOS IPA。
#
#   tool/release.sh            兩個都打
#   tool/release.sh android    只打 AAB
#   tool/release.sh ios        只打 IPA
#   tool/release.sh ios-native 只打原生版 IPA（ios_native/TATNative）；加 --upload 直接送 App Store Connect
#   tool/release.sh all --skip-checks   跳過 analyze / test（不建議）
#
# 為什麼是腳本而不是兩行指令：
#
# * **兩個平台之間一定要 flutter clean。** path_provider_foundation 走
#   native assets，換一個 target 之後沿用上一次的產出會裝出一個
#   objective_c.framework 載不起來的 App——畫面上是開啟即紅屏
#   （LateInitializationError: _cookieJar），完全不像建置問題。
# * **檢查與建置不可以並行。** 兩者搶同一份 native assets 的簽章，測試會
#   莫名其妙失敗。所以這裡一律跑完檢查才開始建置。
# * 一律用 puro 的 flutter：裸的 flutter 指到別的 SDK。
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

# 產出一律先複製到 dist/。build/ 會被兩個 target 之間的 flutter clean 清掉，
# 先前 all 打完 Android 再打 iOS，那顆 AAB 就這樣被自己的腳本刪了。
DIST="$ROOT/dist"

FLUTTER=(puro flutter)
TARGET="${1:-all}"
SKIP_CHECKS=0
UPLOAD=0
for arg in "$@"; do
  [[ "$arg" == "--skip-checks" ]] && SKIP_CHECKS=1
  [[ "$arg" == "--upload" ]] && UPLOAD=1
done

case "$TARGET" in
  android|ios|ios-native|all|--skip-checks) ;;
  *) echo "用法: tool/release.sh [android|ios|ios-native|all] [--skip-checks] [--upload]" >&2; exit 2 ;;
esac
[[ "$TARGET" == "--skip-checks" ]] && TARGET=all

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }
die() { printf '\n\033[1;31m!! %s\033[0m\n' "$1" >&2; exit 1; }

VERSION="$(awk -F'[ +]' '/^version:/{print $2}' pubspec.yaml)"
BUILD="$(awk -F'+' '/^version:/{print $2}' pubspec.yaml)"
say "TAT $VERSION (build $BUILD)"
mkdir -p "$DIST"

command -v puro >/dev/null || die "找不到 puro。"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "⚠️  工作區有未提交的變更，打出來的包會含這些改動。"
fi

# 上架包一定要用 release 的 Firebase 設定與簽章，缺一個就不要浪費十分鐘。
if [[ "$TARGET" == "android" || "$TARGET" == "all" ]]; then
  [[ -f android/key.properties ]] || die "缺 android/key.properties，AAB 會簽不了名。"
  # Gradle 的 file() 是相對 android/app 解的，不是 android/。
  STORE_FILE="$(awk -F= '/^storeFile=/{print $2}' android/key.properties | tr -d '[:space:]')"
  [[ -f "android/app/$STORE_FILE" ]] ||
    die "key.properties 指到的 keystore 不存在：android/app/$STORE_FILE"
fi

if [[ "$TARGET" == "ios-native" ]]; then
  # worktree 裡沒有這份（gitignored），缺了 Crashlytics 與推播都不會動。
  [[ -f ios_native/TATNative/Resources/GoogleService-Info.plist ]] ||
    die "缺 ios_native/TATNative/Resources/GoogleService-Info.plist：cp ios/Runner/GoogleService-Info.plist ios_native/TATNative/Resources/"
  command -v pod >/dev/null || die "找不到 CocoaPods（pod）。"
fi

if [[ "$SKIP_CHECKS" -eq 0 ]]; then
  say "分析"
  "${FLUTTER[@]}" analyze
  say "測試"
  "${FLUTTER[@]}" test
  say "相依層級"
  python3 tool/deps.py --check
else
  echo "⚠️  跳過 analyze / test。"
fi

build_android() {
  say "Android AAB"
  "${FLUTTER[@]}" clean >/dev/null
  "${FLUTTER[@]}" pub get >/dev/null
  "${FLUTTER[@]}" build appbundle --release
  AAB="$ROOT/build/app/outputs/bundle/release/app-release.aab"
  [[ -f "$AAB" ]] || die "AAB 沒有產生出來。"
  OUT="$DIST/TAT-$VERSION+$BUILD.aab"
  cp "$AAB" "$OUT"
  ARTIFACTS+=("$OUT")
}

build_ios() {
  say "iOS IPA"
  "${FLUTTER[@]}" clean >/dev/null
  "${FLUTTER[@]}" pub get >/dev/null
  # app-store 匯出用專案裡的自動簽章（team 已設在 Runner.xcodeproj）。
  "${FLUTTER[@]}" build ipa --release --export-method app-store
  IPA="$(ls -t "$ROOT"/build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)"
  if [[ -z "$IPA" ]]; then
    # 封存（archive）通常是成功的，掛掉的是匯出那一步——這台機器上沒有
    # Apple Distribution 憑證或沒登入開發者帳號時就會這樣。封存還在，可以
    # 直接從 Xcode 的 Organizer 送出。
    if [[ -d "$ROOT/build/ios/archive/Runner.xcarchive" ]]; then
      echo "封存已產生：$ROOT/build/ios/archive/Runner.xcarchive"
      echo "匯出失敗多半是缺 Apple Distribution 憑證／描述檔。可以改用："
      echo "  open $ROOT/build/ios/archive/Runner.xcarchive"
    fi
    die "IPA 沒有產生出來，看上面的 Xcode 訊息。"
  fi
  OUT="$DIST/TAT-$VERSION+$BUILD.ipa"
  cp "$IPA" "$OUT"
  ARTIFACTS+=("$OUT")
}

# 平常開發用的 ios_native 專案是模擬器設定；打包時換成實機設定，做完一定要換回來。
restore_native_project() {
  ruby ios_native/generate_project.rb >/dev/null &&
    (cd ios_native && pod install >/dev/null) || true
}

build_ios_native() {
  say "iOS 原生版 IPA"
  export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
  # clean 會把 build/ 與 .dart_tool/ 整個清掉：舊的 native assets 會嵌進錯架構的 objective_c.framework。
  "${FLUTTER[@]}" clean >/dev/null
  "${FLUTTER[@]}" pub get >/dev/null
  DEVICE=1 ruby ios_native/generate_project.rb >/dev/null
  (cd ios_native && pod install >/dev/null)

  local work="$ROOT/build/ios_native"
  local archive="$work/TATNative.xcarchive"
  local exported="$work/export"
  local options="$work/ExportOptions.plist"
  mkdir -p "$exported"
  if ! xcodebuild -workspace ios_native/TATNative.xcworkspace -scheme TATNative \
    -configuration Release -destination 'generic/platform=iOS' \
    -archivePath "$archive" -allowProvisioningUpdates archive; then
    restore_native_project
    die "封存失敗，看上面的 Xcode 訊息。"
  fi

  local destination=export
  [[ "$UPLOAD" -eq 1 ]] && destination=upload
  cat >"$options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$destination</string>
  <key>teamID</key><string>72QP2FGS73</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST
  if ! xcodebuild -exportArchive -archivePath "$archive" -exportPath "$exported" \
    -exportOptionsPlist "$options" -allowProvisioningUpdates; then
    restore_native_project
    echo "封存已產生：$archive"
    echo "匯出失敗多半是缺 Apple Distribution 憑證／描述檔，或沒登入開發者帳號。可以改用："
    echo "  open $archive"
    die "原生版 IPA 沒有產生出來。"
  fi
  restore_native_project

  local plist="$archive/Info.plist"
  local version build
  version="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$plist")"
  build="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' "$plist")"
  if [[ "$UPLOAD" -eq 1 ]]; then
    echo "已送到 App Store Connect：TAT $version ($build)。處理完會出現在 TestFlight。"
    return
  fi
  local ipa
  ipa="$(ls -t "$exported"/*.ipa 2>/dev/null | head -1 || true)"
  [[ -n "$ipa" ]] || die "原生版 IPA 沒有產生出來，看上面的 Xcode 訊息。"
  local out="$DIST/TAT-native-$version+$build.ipa"
  cp "$ipa" "$out"
  ARTIFACTS+=("$out")
}

ARTIFACTS=()
case "$TARGET" in
  android)    build_android ;;
  ios)        build_ios ;;
  ios-native) build_ios_native ;;
  all)        build_android; build_ios ;;
esac

say "完成"
for f in "${ARTIFACTS[@]+"${ARTIFACTS[@]}"}"; do
  printf '  %s  (%s)\n' "$f" "$(du -h "$f" | cut -f1)"
done

cat <<'NOTE'

下一步
  AAB  → Play Console 上傳；版本號要比上一版大。
  IPA  → Transporter 或 xcrun altool 上傳到 App Store Connect。
  原生版 → tool/release.sh ios-native --upload 直接送；版號在 ios_native/generate_project.rb。
NOTE
