import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/console_output.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/auth/session_cleaner.dart';
import 'package:flutter_app/src/config/app_link.dart';
import 'package:flutter_app/src/controller/announcement/notification_badge_controller.dart';
import 'package:flutter_app/src/controller/course_table/course_controller.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/controller/score_page/score_page_controller.dart';
import 'package:flutter_app/src/service/image_pick_service.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/service/theme_service.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter_app/src/util/document_utils.dart';
import 'package:flutter_app/src/version/app_version.dart';
import 'package:flutter_app/src/version/store_update.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/components/shimmer/profile_loading.dart';
import 'package:flutter_app/ui/components/tile/settings_tile.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/other/components/avatar_action_sheet.dart';
import 'package:flutter_app/ui/pages/other/components/user_profile.dart';
import 'package:flutter_app/ui/pages/other/page/profile_page.dart';
import 'package:flutter_app/ui/pages/other/page/setting/moodle_setting_page.dart';
import 'package:flutter_app/ui/pages/other/page/setting/setting_page.dart';
import 'package:flutter_app/ui/pages/subsystem/sub_system_page.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:get/get.dart';

class OtherPage extends StatefulWidget {
  const OtherPage({
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _OtherPageState();
}

class _OtherPageState extends State<OtherPage> {
  String _appVersion = '';
  String _downloadPath = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadTrailingValues());
  }

  /// 「檢查新版本」右邊的版本號與「下載位置」的現值。
  ///
  /// 這裡刻意不呼叫 `FileStore.findLocalPath`：它會先要儲存權限，而「更多」是
  /// 底部導航進得來的頁，一開就跳權限對話框說不過去。設定過的路徑本來就在
  /// 偏好設定裡，直接讀。
  Future<void> _loadTrailingValues() async {
    String version = '';
    try {
      version = await APPVersion.getAppVersion();
    } catch (e) {
      Log.d(e);
    }
    final path = await SettingsStore.instance.downloadPath ?? '';
    if (!mounted) return;
    setState(() {
      _appVersion = version;
      _downloadPath = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = AuthSession.instance.isSignedIn;
    return Scaffold(
      appBar: mainAppbar(title: R.current.titleMore),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildAccountTile(),
          SectionHeader(
            title: R.current.informationSystem,
            trailing: _HeaderLink(
              label: R.current.allServices,
              onTap: () => _openSubSystem(),
            ),
          ),
          // 分類攤成 2x2，第一眼就看得到裡面有什麼，不用先點一次。清單是寫死
          // 的：getSubSystemTree 走 SSO 而且刻意沒有快取，掛在這裡等於每次開
          // 「更多」都去爬一次學校站台。真正的清單進資訊系統頁才抓。
          // 副標題是手工維護的，內容取自 getSubSystemTree 真的回傳的服務名稱
          // （不是設計稿上的示意文字）。學校那邊改了服務就要跟著改，對照方式
          // 是進「全部服務」看每一類底下實際列了什麼。
          _categoryGrid([
            (
              LucideIcons.bookOpen,
              R.current.curriculum,
              R.current.curriculumDescription,
              'service-1'
            ),
            (
              LucideIcons.idCard,
              R.current.person_info,
              R.current.personInfoDescription,
              'service-2'
            ),
            (
              LucideIcons.bus,
              R.current.campus_life,
              R.current.campusLifeDescription,
              'service-3'
            ),
            (
              LucideIcons.handCoins,
              R.current.financial_support,
              R.current.financialSupportDescription,
              'service-4'
            ),
            (
              LucideIcons.ticket,
              R.current.activities,
              R.current.activitiesDescription,
              'service-5'
            ),
            (
              LucideIcons.folder,
              R.current.resources,
              R.current.resourcesDescription,
              'service-6'
            ),
          ]),
          SectionHeader(title: R.current.setting),
          _group([
            _Row(
              icon: LucideIcons.graduationCap,
              title: R.current.moodle_setting,
              subtitle: R.current.moodle_setting_description,
              onTap: () => unawaited(Get.to(() => const MoodleSettingPage(),
                  transition: RouteUtils.transition)),
            ),
            _Row(
              icon: LucideIcons.languages,
              title: R.current.languageSetting,
              // 右邊直接顯示目前的值，不必點進去才知道。
              value: currentLanguageName(),
              onTap: () => unawaited(_onLanguageTap()),
            ),
            _Row(
              icon: LucideIcons.palette,
              title: R.current.theme_setting,
              value: themeModeName(ThemeService.instance.theme),
              onTap: () => unawaited(_onThemeTap()),
            ),
            // 選資料夾只有 Android 有原生實作，iOS 上這一列點了不會有反應。
            if (Platform.isAndroid)
              _Row(
                icon: LucideIcons.folder,
                title: R.current.downloadPath,
                subtitle: _downloadPath.isEmpty ? null : _downloadPath,
                onTap: () => unawaited(_onDownloadPathTap()),
              ),
          ]),
          SectionHeader(title: R.current.groupAboutTat),
          _group([
            _Row(
              icon: LucideIcons.messageSquare,
              title: R.current.feedback,
              onTap: () => unawaited(_openFeedback()),
            ),
            _Row(
              icon: LucideIcons.cloudDownload,
              title: R.current.checkVersion,
              value: _appVersion.isEmpty ? null : _appVersion,
              onTap: () => unawaited(_checkVersion()),
            ),
            _Row(
              icon: LucideIcons.info,
              title: R.current.about,
              onTap: () => unawaited(RouteUtils.toAboutPage()),
            ),
          ]),
          const SizedBox(height: 24),
          if (signedIn)
            _AccountButton(
              icon: LucideIcons.logOut,
              label: R.current.logout,
              destructive: true,
              onTap: () => unawaited(_onLogout()),
            )
          else
            _AccountButton(
              icon: LucideIcons.logIn,
              label: R.current.login,
              onTap: () => unawaited(RouteUtils.toLoginScreen()),
            ),
        ],
      ),
    );
  }

  /// 一組相連的列：頭尾各自收圓角，中間留 2px 的縫。
  Widget _group(List<_Row> rows) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          SettingsTile(
            icon: rows[i].icon,
            title: rows[i].title,
            subtitle: rows[i].subtitle,
            trailingValue: rows[i].value,
            onTap: rows[i].onTap,
            index: i,
            length: rows.length,
          ),
        ],
      ],
    );
  }

  /// 資訊系統的四張分類卡，2x2。點進去只看那一類。
  Widget _categoryGrid(List<(IconData, String, String, String)> items) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          // IntrinsicHeight 讓同一列的兩張卡等高；沒有它 stretch 在 ListView
          // 裡會拿到無限高度而畫不出來。
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _categoryCard(items[i])),
                const SizedBox(width: 8),
                if (i + 1 < items.length)
                  Expanded(child: _categoryCard(items[i + 1]))
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _categoryCard((IconData, String, String, String) item) {
    final (icon, title, subtitle, serviceId) = item;
    return Builder(builder: (context) {
      final scheme = context.scheme;
      return Material(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(TatTokens.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openSubSystem(serviceId: serviceId),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(height: 8),
                Text(title,
                    style: context.text.titleSmall
                        ?.copyWith(color: scheme.onSurface)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// [serviceId] 帶進來就只看那一個分類。
  void _openSubSystem({String? serviceId}) {
    unawaited(Get.to(
      () => SubSystemPage(
        serviceId: serviceId,
        errorBuilder: (message) => ErrorPage(errorMsg: message),
        openWebView: (title, url) => RouteUtils.toWebViewPage(title, url),
      ),
      transition: RouteUtils.transition,
    ));
  }

  Future<void> _openFeedback() async {
    String link = AppLink.feedbackBaseUrl;
    try {
      String mainVersion = await APPVersion.getAppVersion();
      link = AppLink.feedback(mainVersion, LogBuffer.getLog());
    } catch (e) {
      Log.d(e);
    }
    await RouteUtils.toWebViewPage(R.current.feedback, link);
  }

  Future<void> _checkVersion() async {
    TatToast.show(R.current.checkingVersion, kind: TatToastKind.info);
    if (!await StoreUpdate.offer()) {
      TatToast.show(R.current.isNewVersion, kind: TatToastKind.info);
    }
  }

  Future<void> _onLanguageTap() async {
    if (!await showLanguageSheet(context)) return;
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _onThemeTap() async {
    if (!await showThemeSheet(context)) return;
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _onDownloadPathTap() async {
    final directory = await DocumentUtils.choiceFolder();
    if (directory is! String || !mounted) return;
    setState(() {
      _downloadPath = directory;
    });
  }

  Future<void> _onLogout() async {
    final confirmed = await showTatDialog<bool>(
      dialog: TatDialog(
        title: R.current.logoutConfirmTitle,
        body: R.current.logoutConfirmDesc,
        kind: TatDialogKind.warning,
        destructive: true,
        secondary: TatDialogAction(
          label: R.current.cancel,
          onPressed: () => Get.back<bool>(result: false),
        ),
        primary: TatDialogAction(
          label: R.current.sure,
          onPressed: () => Get.back<bool>(result: true),
        ),
      ),
    );
    if (confirmed != true) return;

    await SessionCleaner.platform().logoutAll();
    // 重設仍然存活的 controller。不要 Get.delete<MainController>()：
    // MainScreen 以 State 欄位持有它，這一頁登出後仍會 Get.find 它。
    final mainController = Get.find<MainController>();
    mainController.cancelAvatarChange();
    mainController.profile.value = null;
    if (Get.isRegistered<CourseController>()) {
      Get.find<CourseController>().reset();
    }
    if (Get.isRegistered<ScorePageController>()) {
      Get.find<ScorePageController>().reset();
    }
    // 紅點是 process 級狀態，重設由 SessionCleaner 的呼叫端觸發
    // （auth → controller 是 tool/deps.py 擋死的上行邊）。
    NotificationBadgeController.instance.reset();
    // 直接回登入頁。先前是 jumpToPage(0) 留在主畫面，靠課表頁的錯誤狀態顯示
    // 「請先登入」——等於登出後還站在一個沒有資料的殼裡。
    await RouteUtils.toLoginScreenAsRoot();
  }

  Widget _buildAccountTile() {
    if (!AuthSession.instance.isSignedIn) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(R.current.pleaseLogin, style: context.text.bodyLarge),
      );
    }

    var controller = Get.find<MainController>();

    return Obx(() {
      if (controller.isProfileLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: ProfileLoading(),
        );
      }

      final profile = controller.profile.value;
      if (profile == null) {
        // 載入結束但沒有資料：Moodle token 過期、斷網，或 site_info 少了欄位。
        // 載入中與載入失敗必須分開判斷，否則失敗之後骨架動畫永遠不會結束——
        // 畫面看起來像還在載入，既沒有錯誤訊息也沒有重試入口。
        return InkWell(
          onTap: controller.reloadProfile,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    R.current.somethingError,
                    style: context.text.bodyLarge
                        ?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                ),
                Icon(LucideIcons.refreshCw,
                    size: 20, color: context.scheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      }

      // 這一列整列都是「進個人資訊頁」。頭貼不給改：換頭貼是個人資訊頁的事，
      // 所以 onAvatarTap 不傳，相機角標也就不會出現。
      return InkWell(
        onTap: () => unawaited(Get.to(
          () => ProfilePage(
            onChangeAvatar: () => _onAvatarTap(controller),
            onOpenStudentRecord: _openSubSystem,
          ),
          transition: RouteUtils.transition,
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: UserProfile(
                  data: profile,
                  progress: controller.avatarProgress.value,
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 18, color: context.scheme.onSurfaceVariant),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _onAvatarTap(MainController controller) async {
    final action = await showAvatarActionSheet(context,
        canRemove: controller.hasCustomAvatar);
    if (action == null) return;

    if (action == AvatarAction.remove) {
      // 換一張不必確認：使用者已經連按三下（頭貼 → 來源 → 選圖），而且結果
      // 可逆（再換一張或移除）。移除要確認：它是唯一破壞性的分支，伺服器端
      // delete_area_files 直接把舊圖刪掉、沒有復原，而且這一列就貼在兩個
      // 「選擇」旁邊，很容易誤按。
      final confirmed = await showTatDialog<bool>(
        dialog: TatDialog(
          title: R.current.avatarRemove,
          body: R.current.avatarRemoveConfirm,
          kind: TatDialogKind.warning,
          destructive: true,
          secondary: TatDialogAction(
            label: R.current.cancel,
            onPressed: () => Get.back<bool>(result: false),
          ),
          primary: TatDialogAction(
            label: R.current.sure,
            onPressed: () => Get.back<bool>(result: true),
          ),
        ),
      );
      if (confirmed != true) return;
      final error = await controller.changeAvatar();
      TaskUiDelegate.instance.toast(error ?? R.current.avatarRemoved);
      return;
    }

    File? file;
    try {
      file = await ImagePickService.instance.pick(
        action == AvatarAction.camera
            ? ImagePickSource.camera
            : ImagePickSource.gallery,
        // 頭貼要縮圖與重新編碼，理由見 image_pick_service.dart 的常數註解。
        maxEdge: kAvatarImageMaxEdge,
        quality: kAvatarImageQuality,
      );
    } on ImagePickFailure catch (e) {
      TaskUiDelegate.instance.toast(_pickFailureMessage(e.reason));
      return;
    }
    // 使用者按取消不是錯誤，什麼都不做也不提示。
    if (file == null) return;

    final error = await controller.changeAvatar(file: file);
    TaskUiDelegate.instance.toast(error ?? R.current.avatarUpdated);
  }

  String _pickFailureMessage(ImagePickFailureReason reason) => switch (reason) {
        ImagePickFailureReason.cameraDenied => R.current.avatarCameraDenied,
        ImagePickFailureReason.galleryDenied => R.current.avatarGalleryDenied,
        ImagePickFailureReason.unavailable => R.current.avatarPickerUnavailable,
      };
}

/// 「更多」頁上的一列。只是把 [SettingsTile] 的參數先湊齊，讓 build() 讀起來
/// 是一份清單而不是一疊建構式。
class _Row {
  _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback onTap;
}

/// 分段標題右邊的文字連結（「全部服務」）。
class _HeaderLink extends StatelessWidget {
  const _HeaderLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TatTokens.radiusButton),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style:
              context.text.labelLarge?.copyWith(color: context.scheme.primary),
        ),
      ),
    );
  }
}

/// 登入／登出。刻意不放進上面任何一組：它是整頁唯一會改變登入狀態的動作，
/// 混在「關於 TAT」裡會和「意見反饋」看起來一樣重。
class _AccountButton extends StatelessWidget {
  const _AccountButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final color = destructive ? scheme.error : scheme.primary;
    return Material(
      color: context.tokens.card,
      borderRadius: BorderRadius.circular(TatTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: TatTokens.heightRow),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label,
                  style: context.text.titleSmall?.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
