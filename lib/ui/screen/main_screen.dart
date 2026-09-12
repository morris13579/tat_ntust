import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/pages/score/score_page.dart';
import 'package:flutter_app/ui/pages/other/other_page.dart';
import 'package:flutter_app/ui/pages/course_table/course_table_page.dart';
import 'package:flutter_app/ui/pages/calendar/calendar_page.dart';
import 'package:flutter_app/ui/components/in_app_banner.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_app/ui/pages/mail/mail_detail_page.dart';
import 'package:flutter_app/ui/pages/mail/mail_page.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:flutter_app/src/controller/announcement/notification_badge_controller.dart';
import 'package:flutter_app/src/controller/mail/mail_outbox_controller.dart';
import 'package:flutter_app/src/controller/mail/mail_watch_controller.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:get/get.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<StatefulWidget> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with RouteAware, WidgetsBindingObserver {
  // 註冊在 AppBindings（lazyPut + fenix），這裡只取用。
  final controller = Get.find<MainController>();

  /// 一定要是 getter：欄位只在 State 建立時初始化，而 forceAppUpdate 只重跑
  /// build()、不重建 State，導覽列標籤會永遠停在啟動時的語言。
  List<Map<String, dynamic>> get items => [
        {"icon": LucideIcons.table, "name": R.current.titleCourse},
        {"icon": LucideIcons.mail, "name": R.current.mailTab},
        {"icon": LucideIcons.calendarDays, "name": R.current.calendar},
        {"icon": LucideIcons.graduationCap, "name": R.current.titleScore},
        {"icon": LucideIcons.menu, "name": R.current.titleMore}
      ];

  StreamSubscription<List<MailMessageJson>>? _mailArrivals;
  StreamSubscription<MailOutboxResult>? _outboxResults;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mailArrivals = MailWatchController.instance.arrivals.listen(_onNewMail);
    MailWatchController.instance.start();
    // 寄件匣的回報接在這裡而不是信件清單：使用者寄完信常常就切去別的分頁，
    // 那條 toast 不該因為清單被 dispose 掉就不見。
    _outboxResults =
        MailOutboxController.instance.results.listen(_onOutboxResult);
    unawaited(MailOutboxController.instance.restore());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AnalyticsUtils.observer
        .subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  /// 課表是預設分頁，停在它把 App 丟到背景再回來不會觸發 `onPageChanged`，
  /// 沒有這一段紅點就會一直停在進 App 那一刻的數字——那正是輪詢要解決的情境。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(NotificationBadgeController.instance.refresh());
      // 信箱只在前景盯。這一版刻意不做背景通知，所以離開前景就要停——不停
      // 的話它就變成一個沒有人要求、也沒有常駐通知交代的背景輪詢。
      MailWatchController.instance.start();
    } else {
      MailWatchController.instance.stop();
      InAppBanner.dismiss();
    }
  }

  /// 寄件匣那一封寄完了。成功只給一條 toast——把清單重抓一次會在使用者正在
  /// 看別的東西時抽掉他腳下的那一頁；寄件備份匣裡那封信不急著現在出現。
  void _onOutboxResult(MailOutboxResult result) {
    if (!mounted) return;
    TatToast.show(
      result.sent ? R.current.mailSent : R.current.mailSendFailed,
      kind: result.sent ? TatToastKind.success : TatToastKind.error,
    );
  }

  /// 新信到了：畫一條可以點的橫幅。一次來好幾封只畫一條，標題改成數量。
  void _onNewMail(List<MailMessageJson> fresh) {
    if (!mounted || fresh.isEmpty) return;
    final newest = fresh.first;
    final subject = newest.subject.trim();
    InAppBanner.show(
      icon: LucideIcons.mail,
      title: fresh.length == 1
          ? newest.displayFrom
          : sprintf(R.current.mailNewMessages, [fresh.length]),
      message: subject.isEmpty ? R.current.mailNoSubject : subject,
      onTap: () => unawaited(_openMail(newest)),
    );
  }

  Future<void> _openMail(MailMessageJson message) async {
    controller.goToTab(MainTab.mail);
    // 和從清單點進去一樣會標成已讀，不然同一封信在兩條路徑上的行為不一致。
    unawaited(MailRepository.instance.setSeen(message.uid, seen: true));
    await Get.to(() => MailDetailPage(message: message),
        transition: RouteUtils.transition);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AnalyticsUtils.observer.unsubscribe(this);
    unawaited(_mailArrivals?.cancel());
    unawaited(_outboxResults?.cancel());
    MailWatchController.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPageView(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// 五個分頁。**順序必須與 [MainTab] 一致**——底下的導覽列與 controller 的
  /// 分析事件都是靠索引對應的。清單放在這裡，controller 才不必 import 頁面。
  ///
  /// 資訊系統不在這裡：它是用系統的名字命名的入口，擺在導覽列反而容易被
  /// 整個忽略，現在從「更多」的最上面進去。
  ///
  /// **信箱排第二，不是排最後。** 頻率上它贏過成績（一學期看幾次）與行事曆。
  /// 五格是 M3 的上限，390px 寬每格 78px，標籤維持兩到三個字就放得下。
  static const _pages = [
    CourseTablePage(),
    MailPage(),
    CalendarPage(openInApp: RouteUtils.tryOpenUpcomingEvent),
    ScoreViewerPage(),
    OtherPage(),
  ];

  Widget _buildPageView() {
    return PageView(
      controller: controller.pageController,
      onPageChanged: controller.onPageChanged,
      physics: const NeverScrollableScrollPhysics(),
      children: _pages,
    );
  }

  Widget _buildBottomNavigationBar() {
    return Obx(() {
      var currentIndex = controller.currentIndex.value;

      return NavigationBar(
        // 選取狀態只由這個索引表達。**不要**改成拿 item 去 items.indexOf：
        // items 是 getter，每次讀都是新的 Map，而 Map 沒有覆寫 ==，跨兩次
        // 讀取的 indexOf 一律回 -1。
        selectedIndex: currentIndex,
        onDestinationSelected: controller.onBottomNavigationTap,
        destinations: [
          for (final item in items)
            NavigationDestination(
              // 圖示的顏色與尺寸一律交給 NavigationBarThemeData，在這裡再塗
              // 一次會蓋掉主題。
              icon: Icon(item["icon"] as IconData),
              label: item["name"] as String,
            ),
        ],
      );
    });
  }
}
