import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/controller/announcement/notification_badge_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/error_dialog_parameter.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/src/util/moodle_avatar_utils.dart';
import 'package:get/get.dart';

/// 五個分頁的身分。
///
/// controller 不可以持有 Widget：那會讓 `lib/src/controller` 反向 import
/// `lib/ui`，也就是 `tool/deps.py` 的 controller -> ui 上行邊。畫面由
/// [MainScreen] 持有，controller 只認「第幾個分頁」。
///
/// 這些名稱會直接送進 Analytics 當 screen name，改名等於改掉既有的報表維度。
/// 資訊系統搬進「更多」時是**刪掉** `subSystem` 這個值、而不是改名，其餘四個
/// 的拼法才不會跟著位移，歷史報表也才接得起來；那一頁改由
/// `AnalyticsUtils.observer` 以路由名記錄。
///
/// **在中間插一個值是安全的**：送出去的是 `.name` 不是索引，既有四個的拼法
/// 沒動，歷史報表照樣接得起來。要小心的是順序必須與 [MainScreen] 的頁面清單
/// 一致——導覽列與 `goToTab` 都是靠索引對應的。
enum MainTab { courseTable, mail, calendar, score, other }

class MainController extends GetxController {
  final pageController = PageController();
  RxInt currentIndex = 0.obs;

  var isProfileLoading = false.obs;
  Rxn<MoodleProfileEntity> profile = Rxn();

  @override
  Future<void> onInit() async {
    super.onInit();

    // Moodle 的事在背景做，不擋 App 外殼：課表不需要 Moodle，個人資料也
    // 只有「其他」頁在用。改成 await 的話使用者輸入完帳密要盯著載入畫面
    // 等一整輪 Moodle 登入才看得到課表。
    unawaited(_loadMoodleProfile());
  }

  /// Moodle 登入與個人資料。在背景跑，不擋 App 外殼。
  ///
  /// 個人資料只有「其他」頁在用，而那一頁自己有 isProfileLoading 的載入狀態
  /// 與 reloadProfile 的重試入口。
  Future<void> _loadMoodleProfile() async {
    try {
      // **先確保 SSO，再碰 Moodle。** Moodle 的 launch.php 會轉址經過 ssoam2，
      // 平台 WebView store 有 SSO cookie 那一段才會靜默通過；順序反過來就是
      // 使用者撞上 ssoam2 的表單再登入一次。失敗照樣往下走，Moodle 那條路
      // 自己會再試一次，也有自己的錯誤提示。
      await AuthSession.instance.ensure({SystemId.ntustSso});
      if (await _checkMoodle()) {
        await _getMoodleProfile();
        // 大聲公上的未讀數。放在這裡是因為 Moodle 的登入到這一步才確定過，
        // 不會為了一顆紅點把登入頁蓋在課表上。
        unawaited(NotificationBadgeController.instance.refresh());
      }
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
    }
  }

  /// Event Handler
  void onBottomNavigationTap(int index) {
    pageController.jumpToPage(index);
    HapticFeedback.mediumImpact();
  }

  /// 用分頁身分跳頁，呼叫端因此不必知道課表排第幾個。沒有觸覺回饋：這是
  /// 程式主動導的頁，不是使用者按的那一下。
  void goToTab(MainTab tab) => pageController.jumpToPage(tab.index);

  void onPageChanged(int index) {
    currentIndex.value = index;

    final screenName = MainTab.values[index].name;
    AnalyticsUtils.setScreenName(screenName);

    // 回到課表分頁時順手更新紅點；節流在 NotificationBadgeController 裡。
    if (MainTab.values[index] == MainTab.courseTable) {
      unawaited(NotificationBadgeController.instance.refresh());
    }
  }

  /// Private Method
  ///
  /// **登入一定要走 [AuthSession.ensure]。** 繞過去就繞過 `inFlight`，首次
  /// 登入時會與課表頁的 `preloadSemesterList` 各開一個 LoginMoodlePage，
  /// 先回來的那個 `Get.back` pop 掉另一頁，另一邊收到 null 就跳錯誤框。
  Future<bool> _checkMoodle() async {
    if (!AuthSession.instance.isSignedIn) return false;

    final isMoodleAvailable =
        await MoodleWebApiConnector.isMoodleTokenAvailable();
    if (isMoodleAvailable) {
      return true;
    }

    final error = await AuthSession.instance.ensure({SystemId.moodleWebApi});
    if (error != null) {
      // 走 TaskUiDelegate 而不是直接 new 一個 ErrorDialog：那個 widget 在
      // lib/ui，controller 讀它是 controller -> ui 的上行邊。
      // offCancelBtn 讓它只有一顆「確定」，回傳值沒有意義。
      await TaskUiDelegate.instance.confirmRetry(ErrorDialogParameter(
        title: R.current.error,
        kind: TatDialogKind.error,
        desc: R.current.loginMoodleError,
        okResult: false,
        btnOkText: R.current.sure,
        offCancelBtn: true,
      ));
      return false;
    }

    return true;
  }

  /// 重新載入個人資料。給「其他」頁載入失敗時的重試入口用。
  Future<void> reloadProfile() => _getMoodleProfile();

  Future<void> _getMoodleProfile() async {
    try {
      isProfileLoading.value = true;
      // 抓不到就留著上一份（connector 的 siteInfo 也是這樣）：換完頭貼之後
      // site_info 偶發失敗會把整列換成「發生錯誤」，而使用者剛剛才被告知
      // 「頭貼已更新」。第一次就失敗時 profile 本來就是 null，照樣畫重試列。
      final fetched = await MoodleWebApiConnector.getProfile();
      if (fetched != null || profile.value == null) profile.value = fetched;
    } catch (e) {
      Log.e(e);
    } finally {
      isProfileLoading.value = false;
    }
  }

  /// 換頭貼進行中的送出進度。0..1，null 代表沒有在跑。
  final Rxn<double> avatarProgress = Rxn();

  CancelToken? _avatarCancel;

  bool get isChangingAvatar => avatarProgress.value != null;

  /// 目前是不是有自訂頭貼（決定要不要顯示「移除」）。對著主題預設圖按移除，
  /// 伺服器會因為 picture 沒有變而回 success:false，看起來像失敗。
  bool get hasCustomAvatar =>
      MoodleAvatarUtils.hasCustomPicture(profile.value?.userpictureurl ?? '');

  /// 換或移除頭貼（[file] 為 null 就是移除）。回 null 代表成功，否則是要
  /// toast 的訊息。不在這裡開對話框、不 toast：controller -> ui 是上行邊，
  /// 確認框與提示由 `OtherPage` 負責。
  Future<String?> changeAvatar({File? file}) async {
    if (isChangingAvatar) return null;
    avatarProgress.value = 0;
    final cancel = _avatarCancel = CancelToken();
    try {
      final result = await MoodleRepository.instance.changeProfilePicture(
        file: file,
        cancelToken: cancel,
        onProgress: (sent, total) {
          if (total > 0) avatarProgress.value = sent / total;
        },
      );
      switch (result) {
        case Ok(:final data):
          await _applyAvatar(data);
          return null;
        // 這條路沒有快取，Stale 不可能發生；真的發生了也照樣算成功。
        case Stale(:final data):
          await _applyAvatar(data);
          return null;
        case Failed(:final reason):
          return reason.message;
      }
    } finally {
      avatarProgress.value = null;
      _avatarCancel = null;
    }
  }

  /// 登出時取消進行中的上傳。
  void cancelAvatarChange() {
    _avatarCancel?.cancel();
    _avatarCancel = null;
    avatarProgress.value = null;
  }

  /// 頭貼換掉之後讓畫面真的更新。
  ///
  /// 畫面用的是 `CircleAvatar(backgroundImage: NetworkImage(url))`，快取鍵是
  /// (url, scale)。伺服器端 user_picture::get_url 會在網址後面掛
  /// `?rev=<user.picture>`，而 user.picture 是 process_new_icon 回的新
  /// files.id，每換一次都不一樣；移除時網址則整個換成主題預設圖。所以正常
  /// 情況下網址一定變，NetworkImage 自然重抓。
  ///
  /// 仍然要 evict 舊網址：伺服器端萬一沒改（例如刪掉一張本來就不存在的頭貼），
  /// 舊那筆會一直留在 ImageCache 裡，畫面就永遠停在舊圖而且沒有任何錯誤。
  /// 這是**不改用 CachedNetworkImage** 的理由：那一套多一層
  /// flutter_cache_manager 的磁碟快取，鍵一樣是網址，跨重啟存活而且沒有
  /// 對外的 evict 入口，出問題時比現在更難救。
  Future<void> _applyAvatar(MoodleAvatarChange change) async {
    final oldUrl = profile.value?.userpictureurl;
    if (oldUrl != null && oldUrl.isNotEmpty) {
      await NetworkImage(oldUrl).evict();
    }
    await reloadProfile();
    // site_info 還回著舊網址時（伺服器端快取），退回用 update_picture 自己
    // 算出來的那一個。直接改欄位不會觸發 Obx（Rxn 只在 `.value =` 時通知），
    // 所以一定要換一個新的實例。
    final current = profile.value;
    if (current != null &&
        current.userpictureurl == oldUrl &&
        change.url.isNotEmpty) {
      final patched = Map<String, dynamic>.from(current.toJson())
        ..['userpictureurl'] = change.url;
      profile.value = MoodleProfileEntity.fromJson(patched);
    }
  }
}
