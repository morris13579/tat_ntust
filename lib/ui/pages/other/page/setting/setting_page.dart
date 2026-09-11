import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/tat_switch.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/file/file_store.dart';
import 'package:flutter_app/src/service/theme_service.dart';
import 'package:flutter_app/src/util/document_utils.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/components/tile/settings_tile.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/other/page/setting/moodle_setting_page.dart';
import 'package:get/get.dart';

/// 目前生效的語言名稱，給「語言設定」那一列右邊顯示。
String currentLanguageName() => LanguageUtils.getLangIndex() == LangEnum.en
    ? R.current.languageEn
    : R.current.languageZhTW;

String themeModeName(ThemeMode mode) => switch (mode) {
      ThemeMode.dark => R.current.theme_dark,
      ThemeMode.light => R.current.theme_light,
      ThemeMode.system => R.current.theme_system,
    };

/// 語言的單選選單。回傳「有沒有真的換掉」。
///
/// 只有繁體中文與 English 兩個選項，**沒有「跟隨系統」**：
/// [LanguageUtils.getLangIndex] 刻意把「從沒設定過」收斂成中文，因為
/// CourseConnector 會依它送 `Culture=en-US`、NTUSTConnector 會改抓 /EN/student。
/// 第三個狀態是連接器層的改動，不在這一輪。
Future<bool> showLanguageSheet(BuildContext context) async {
  final current = LanguageUtils.getLangIndex();
  final picked = await showTatSingleSelectSheet<LangEnum>(
    context: context,
    title: R.current.languageSetting,
    selected: current,
    options: [
      TatSheetOption(label: R.current.languageZhTW, value: LangEnum.zh),
      TatSheetOption(label: R.current.languageEn, value: LangEnum.en),
    ],
  );
  if (picked == null || picked == current) return false;

  await HapticFeedback.lightImpact();
  await LanguageUtils.setLangByIndex(picked);
  // 換語言會清掉課表快取，所以回到課表那一頁。選單自己已經關掉了，這裡不再
  // 多 pop 一次——舊版那句 Get.back() 會順手把整個設定頁也關掉。
  if (Get.isRegistered<MainController>()) {
    Get.find<MainController>().pageController.jumpToPage(0);
  }
  return true;
}

/// 主題的單選選單。回傳「有沒有真的換掉」。
Future<bool> showThemeSheet(BuildContext context) async {
  final current = ThemeService.instance.theme;
  final picked = await showTatSingleSelectSheet<ThemeMode>(
    context: context,
    title: R.current.theme_setting,
    selected: current,
    options: [
      TatSheetOption(label: R.current.theme_system, value: ThemeMode.system),
      TatSheetOption(label: R.current.theme_light, value: ThemeMode.light),
      TatSheetOption(label: R.current.theme_dark, value: ThemeMode.dark),
    ],
  );
  if (picked == null || picked == current) return false;

  await HapticFeedback.mediumImpact();
  await ThemeService.instance.changeThemeMode(picked);
  return true;
}

/// 舊的設定頁。
///
/// 這一輪把 Moodle／語言／主題／下載位置四項直接攤在「更多」上（畫面 3b），
/// 所以這一頁已經沒有入口。留著是因為它是 `languageSwitch`、`willRestart`、
/// `theme_setting_description` 三個字串目前唯一的讀取點，翻譯檔不歸這一批動。
class SettingPage extends StatefulWidget {
  const SettingPage({
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  String downloadPath = "";

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized()
        .addPostFrameCallback((timeStamp) async {
      // callback 是掛在 binding 上而不是這個 State 上，即使頁面在第一幀後
      // 馬上被 pop 掉也照樣會跑；此時讀 State.context 會 assert 失敗。
      if (!mounted) return;
      await _getDownloadPath();
    });
  }

  Future<void> _getDownloadPath() async {
    String path = await FileStore.findLocalPath(context);
    // 這個 await 可能停在系統的儲存權限對話框上，長度不可控。使用者在對話框
    // 開著的時候退出設定頁，setState 就會打在已經 dispose 的 State 上。
    if (!mounted) return;
    setState(() {
      downloadPath = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(title: R.current.setting),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildLanguageSetting(),
          const SizedBox(height: 2),
          SettingsTile(
            icon: LucideIcons.palette,
            title: R.current.theme_setting,
            subtitle: R.current.theme_setting_description,
            trailingValue: themeModeName(ThemeService.instance.theme),
            showChevron: false,
            onTap: () async {
              if (await showThemeSheet(context) && mounted) setState(() {});
            },
          ),
          const SizedBox(height: 2),
          SettingsTile(
            icon: LucideIcons.graduationCap,
            title: R.current.moodle_setting,
            subtitle: R.current.moodle_setting_description,
            onTap: () => Get.to(() => const MoodleSettingPage()),
          ),
          if (downloadPath.isNotEmpty) ...[
            const SizedBox(height: 2),
            SettingsTile(
              icon: LucideIcons.folder,
              title: R.current.downloadPath,
              subtitle: downloadPath,
              onTap: _pickDownloadPath,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDownloadPath() async {
    String? directory = await DocumentUtils.choiceFolder();
    // mounted 同 _getDownloadPath：系統資料夾選擇器會停留任意久，
    // 期間使用者可以退出設定頁，回來時 State 已經 dispose。
    if (directory != null && mounted) {
      setState(() {
        downloadPath = directory;
      });
    }
  }

  Widget _buildLanguageSetting() {
    final scheme = context.scheme;
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(TatTokens.radiusCard),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(R.current.languageSwitch,
                    style: context.text.bodyLarge
                        ?.copyWith(color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(R.current.willRestart,
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TatSwitch(
              value: LanguageUtils.getLangIndex() == LangEnum.en,
              onChanged: (value) async {
                await HapticFeedback.lightImpact();
                await LanguageUtils.setLangByIndex(
                    value ? LangEnum.en : LangEnum.zh);
                if (Get.isRegistered<MainController>()) {
                  Get.find<MainController>().pageController.jumpToPage(0);
                }
                if (mounted) setState(() {});
              })
        ],
      ),
    );
  }
}
