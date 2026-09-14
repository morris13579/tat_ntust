#!/usr/bin/env ruby
# 產生 ios_native/TATNative.xcodeproj。專案檔是產出物、不進版控：要改結構就改這支再重跑。
#
#   ruby ios_native/generate_project.rb            # 模擬器
#   DEVICE=1 ruby ios_native/generate_project.rb   # 實機
#   (cd ios_native && pod install)
#
# 資料夾就是 Xcode 群組，新增檔案不必改這支（結構見 ios_native/ARCHITECTURE.md）。
# 例外是小工具 extension 向 App 借的檔案，列在 WIDGET_BORROWS。
#
# **Flutter 的東西全部交給 CocoaPods 與 xcode_backend.sh**，和 ios/Runner 用同一支：
# Dart 的 App.framework 由 "Run Script" 產生、由 "Thin Binary" 嵌入。手動塞 xcframework
# 會踩到三個坑：缺 `Firebase/Firebase.h`、模擬器要 Debug 而實機要 Release、native asset。

require 'xcodeproj'
require 'fileutils'

ROOT       = File.expand_path('..', __dir__)
NATIVE_DIR = File.join(ROOT, 'ios_native')
SOURCES    = File.join(NATIVE_DIR, 'TATNative')
WIDGET     = File.join(NATIVE_DIR, 'TATWidget')
PROJECT    = File.join(NATIVE_DIR, 'TATNative.xcodeproj')
DEVICE     = ENV['DEVICE'] == '1'
BUNDLE_ID  = 'club.ntust.tat.72QP2FGS73'
TEAM       = '72QP2FGS73'
# 原生版的版號，App 與小工具 extension 必須相同。接在 Flutter 版上架過的 2.1.0（124）之後，minor 加一，不跳大版本。
MARKETING_VERSION = '2.2.0'
BUILD_NUMBER      = '125'

# 小工具 extension 向 App 借的檔案（相對 TATNative/）：畫面與資料格式、字串、Lucide、課表配色。
# extension 裡沒有 Flutter 引擎，借來的檔案不可以用到核心的型別。
WIDGET_BORROWS = %w[
  Widgets
  App/Localization.swift
  Resources/Generated/L10n.swift
  Resources/Generated/Lucide.swift
  DesignSystem/LucideImage.swift
  DesignSystem/CoursePalette.swift
].freeze

generated_xcconfig = File.join(ROOT, 'ios', 'Flutter', 'Generated.xcconfig')
unless File.exist?(generated_xcconfig)
  abort "找不到 #{generated_xcconfig}\n  先在 repo 根目錄跑：flutter pub get"
end

# Firebase 設定不在版控裡；少了它 FirebaseApp.configure() 會讓 App 一啟動就結束。
firebase_plist = File.join(SOURCES, 'Resources', 'GoogleService-Info.plist')
unless File.exist?(firebase_plist)
  warn "⚠ 找不到 #{firebase_plist}"
  warn "  從主 checkout 複製：cp ios/Runner/GoogleService-Info.plist ios_native/TATNative/Resources/"
end

FileUtils.rm_rf(PROJECT)
project = Xcodeproj::Project.new(PROJECT)
project.root_object.development_region = 'zh-Hant'
project.root_object.known_regions = %w[zh-Hant en Base]
target = project.new_target(:application, 'TATNative', :ios, '17.0')

# .xcassets 是資源包、.lproj 是語系變體，兩者都不當成一般資料夾往下走。
def add_folder(target, group, dir)
  names = Dir.children(dir).reject { |n| n.start_with?('.') }.sort
  lproj, others = names.partition { |n| File.extname(n) == '.lproj' }

  lproj.flat_map { |l| Dir.children(File.join(dir, l)).map { |f| [l, f] } }
       .group_by(&:last).each do |file, pairs|
    variant = group.new_variant_group(file)
    pairs.sort.each do |l, f|
      ref = variant.new_reference(File.join(l, f))
      ref.name = File.basename(l, '.lproj')
    end
    target.resources_build_phase.add_file_reference(variant)
  end

  others.each do |name|
    path = File.join(dir, name)
    if File.directory?(path) && File.extname(name) != '.xcassets'
      add_folder(target, group.new_group(name, name), path)
      next
    end
    ref = group.new_reference(name)
    case File.extname(name)
    when '.swift', '.m' then target.add_file_references([ref])
    when '.h', '.entitlements' then nil
    when '.plist' then target.add_resources([ref]) unless name == 'Info.plist'
    else target.add_resources([ref])
    end
  end
end
add_folder(target, project.new_group('TATNative', 'TATNative'), SOURCES)

# 與 Flutter App 共用、直接從 repo 收進 bundle：App 圖示、Lucide 字型、登入頁的圖示、
# 條款的離線備援（理由見 PrivacyPolicyController.fetchPolicy）。
shared = project.new_group('Shared', '..')
shared_refs = {}
%w[
  ios/Runner/Assets.xcassets
  assets/fonts/lucide-light.ttf
  assets/fonts/lucide-thin.ttf
  assets/launcher/ios-icon.png
  privacy-policy.md
].each do |path|
  abort "找不到 #{File.join(ROOT, path)}" unless File.exist?(File.join(ROOT, path))
  shared_refs[path] = shared.new_reference(path)
  target.add_resources([shared_refs[path]])
end

config_group = project.new_group('Config', 'Config')
%w[Debug Release].each do |name|
  ref = config_group.new_reference("#{name}.xcconfig")
  target.build_configurations
        .find { |c| c.name == name }
        &.base_configuration_reference = ref
end

# 課表的桌面與鎖定畫面小工具。不掛 Config/*.xcconfig：extension 裡沒有 Flutter 與 Pods。
widget = project.new_target(:app_extension, 'TATWidget', :ios, '17.0')
add_folder(widget, project.new_group('TATWidget', 'TATWidget'), WIDGET)
WIDGET_BORROWS.each do |relative|
  path = File.join(SOURCES, relative)
  refs = project.files.select { |f| (p = f.real_path.to_s) == path || p.start_with?("#{path}/") }
  abort "小工具借的 #{relative} 不在 TATNative/ 裡" if refs.empty?
  widget.add_file_references(refs)
end
localizable = project.objects
                     .grep(Xcodeproj::Project::Object::PBXVariantGroup)
                     .find { |g| g.name == 'Localizable.strings' }
widget.resources_build_phase.add_file_reference(localizable)
widget.add_resources(%w[assets/fonts/lucide-light.ttf assets/fonts/lucide-thin.ttf].map { |p| shared_refs.fetch(p) })

# 要排在 Sources 之前，否則 App.framework 還沒產生就開始連結。
run_script = target.new_shell_script_build_phase('Run Script')
run_script.shell_script = %q{/bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" build}
target.build_phases.delete(run_script)
target.build_phases.unshift(run_script)

# 小工具嵌進 App。要排在 Thin Binary 之前：Flutter 的 script phase 沒有宣告輸出，排在它後面 Xcode 會判成相依循環。
embed = target.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(widget.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
target.add_dependency(widget)

thin = target.new_shell_script_build_phase('Thin Binary')
thin.shell_script = %q{/bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" embed_and_thin}

# 原生當掉的堆疊要上傳 dSYM 才看得到程式位置，同 Runner 的 Firebase Script。只在封存（上架包）時跑：
# 平常的建置與實機安裝不必每次都連線上傳。
crashlytics = target.new_shell_script_build_phase('Upload Crashlytics dSYM')
crashlytics.shell_script = <<~'SH'
  if [ "${ACTION}" = "install" ]; then
    "${PODS_ROOT}/FirebaseCrashlytics/run" -gsp "${PROJECT_DIR}/TATNative/Resources/GoogleService-Info.plist"
  fi
SH
crashlytics.input_paths = %w[
  ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}
  ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}
  ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist
  $(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist
  $(TARGET_BUILD_DIR)/$(EXECUTABLE_PATH)
]

# 簽章。App 與小工具的 entitlements 都有 App Group（小工具讀課表用）；App 的另外有推播。
def apply_signing(config, entitlements)
  if DEVICE
    # **不可以加 keychain-access-groups**：沒有它時預設 access group 是 `$(AppIdentifierPrefix)$(CFBundleIdentifier)`，
    # 和 Flutter 版相同；自己塞一份寫錯的會讓既有使用者的帳密整批讀不到，而且是判成 absent（送回登入畫面）。
    # App Group 不影響 keychain 的預設 access group。實測見計畫書 §E1c、§R0.3。
    config.build_settings.merge!(
      'DEVELOPMENT_TEAM'      => TEAM,
      'CODE_SIGN_STYLE'       => 'Automatic',
      'CODE_SIGN_IDENTITY'    => 'Apple Development',
      'CODE_SIGNING_REQUIRED' => 'YES',
      'CODE_SIGNING_ALLOWED'  => 'YES',
    )
    # 簽不了推播與 App Group 的團隊（個人帳號）用 `PUSH=0` 產生，少的是推播與小工具的課表。
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements unless ENV['PUSH'] == '0'
  else
    # 模擬器：ad-hoc 簽章、沒有 entitlements，與 `flutter build ios --simulator` 的 Runner.app 一致，
    # 兩個 App 落在同一個 keychain access group。**簽章不可以關掉**：CODE_SIGNING_ALLOWED=NO 時
    # Keychain 一律回 errSecMissingEntitlement (-34018)，CredentialsStore 會判成 unavailable。
    # 也因此模擬器上沒有 App Group，小工具拿不到課表，版面用 Debug 預覽看（見 Debug/WidgetPreview.swift）。
    config.build_settings.merge!(
      'CODE_SIGN_IDENTITY'    => '-',
      'CODE_SIGNING_REQUIRED' => 'YES',
      'CODE_SIGNING_ALLOWED'  => 'YES',
    )
  end
end

target.build_configurations.each do |config|
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER'  => BUNDLE_ID,
    'INFOPLIST_FILE'             => 'TATNative/Resources/Info.plist',
    'GENERATE_INFOPLIST_FILE'    => 'NO',
    'SWIFT_VERSION'              => '5.0',
    'SWIFT_OBJC_BRIDGING_HEADER' => 'TATNative/Core/TATNative-Bridging-Header.h',
    'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
    'TARGETED_DEVICE_FAMILY'     => '1',
    'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
    'CLANG_ENABLE_MODULES'       => 'YES',
    # firebase_* 外掛 `#import <Firebase/Firebase.h>`，而那個 pod 刻意沒有模組，Xcode 預設把
    # -Wnon-modular-include-in-framework-module 當錯誤。**要下在 App target**：模組是由請求它的
    # CorePluginRegistrant.m 觸發編譯的，旗標從這裡繼承。
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'ENABLE_BITCODE'             => 'NO',
    'MARKETING_VERSION'          => MARKETING_VERSION,
    'CURRENT_PROJECT_VERSION'    => BUILD_NUMBER,
    # 只編 Dart 核心：畫面都在 Swift，lib/ui 不必進 App.framework（計畫書 §6.1）。
    # Flutter 版的 Runner 與 Android 照舊用 lib/main.dart。
    'FLUTTER_TARGET'             => 'lib/core_main.dart',
  )
  apply_signing(config, 'TATNative/Resources/TATNative.entitlements')
end

widget.build_configurations.each do |config|
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER'      => "#{BUNDLE_ID}.widget",
    'INFOPLIST_FILE'                 => 'TATWidget/Info.plist',
    'GENERATE_INFOPLIST_FILE'        => 'NO',
    'SWIFT_VERSION'                  => '5.0',
    'IPHONEOS_DEPLOYMENT_TARGET'     => '17.0',
    'TARGETED_DEVICE_FAMILY'         => '1',
    'MARKETING_VERSION'              => MARKETING_VERSION,
    'CURRENT_PROJECT_VERSION'        => BUILD_NUMBER,
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'SKIP_INSTALL'                   => 'YES',
    'LD_RUNPATH_SEARCH_PATHS'        => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
    'ENABLE_BITCODE'                 => 'NO',
  )
  apply_signing(config, 'TATWidget/TATWidget.entitlements')
end

project.save
puts "已產生 #{PROJECT}（#{DEVICE ? '實機' : '模擬器'}）"
puts "下一步：cd ios_native && pod install"
