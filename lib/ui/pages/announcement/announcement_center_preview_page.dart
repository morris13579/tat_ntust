import 'package:flutter/material.dart';
import 'package:flutter_app/src/controller/announcement/announcement_center_preview.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/tile/settings_tile.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/pages/announcement/announcement_center_page.dart';

/// 通知頁的假資料預覽，只掛在開發者選單底下。
///
/// 為什麼需要它：通知頁設計了「有公告／只有 Moodle／全空」三種樣子，但一個
/// 帳號同一時間只會是其中一種，維護者的帳號長期是空的，另外兩種在真機上根本
/// 看不到。最後兩個項目是設計稿上沒有畫、但程式會走到的樣子（Moodle 關掉站內
/// 通知、以及通知列自己的其餘分支）。
///
/// 假資料**不會**流到正式流程：這一頁是唯一把它塞進 controller 的地方，塞的
/// 方式是把 [AnnouncementCenterPage] 的 `controller` 注入點（本來給測試用的）
/// 換成一顆只在記憶體裡動的 [AnnouncementCenterPreviewController]。真正的 repository、快取與
/// 未讀紅點都沒有被碰到，也沒有任何一條路徑會在正式版把這一頁畫出來
/// （入口是 `AboutPage.inDevMode`，release 版是 false）。
class AnnouncementCenterPreviewPage extends StatelessWidget {
  const AnnouncementCenterPreviewPage({super.key});

  static IconData _iconOf(AnnouncementPreviewCase which) => switch (which) {
        AnnouncementPreviewCase.withNotice => LucideIcons.megaphone,
        AnnouncementPreviewCase.moodleOnly => LucideIcons.bell,
        AnnouncementPreviewCase.empty => LucideIconsThin.inbox,
        AnnouncementPreviewCase.disabledOnMoodle => LucideIcons.eyeOff,
        AnnouncementPreviewCase.multipleNotices => LucideIcons.copy,
        AnnouncementPreviewCase.variants => LucideIcons.layers2,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(title: 'Notification Preview'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (var i = 0; i < announcementPreviewMenu.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            SettingsTile(
              icon: _iconOf(announcementPreviewMenu[i]),
              title: announcementPreviewMenu[i].title,
              subtitle: announcementPreviewMenu[i].subtitle,
              onTap: () => _open(context, announcementPreviewMenu[i]),
              index: i,
              length: announcementPreviewMenu.length,
            ),
          ],
        ],
      ),
    );
  }

  /// controller 是注入進去的，所以那一頁不會自己 dispose；這裡等它 pop 回來
  /// 再關掉，Obx 才不會對已經關掉的 Rx 重畫。
  Future<void> _open(
      BuildContext context, AnnouncementPreviewCase which) async {
    final controller = AnnouncementCenterPreviewController(which);
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => AnnouncementCenterPage(
        controller: controller,
        clock: () => announcementPreviewNow,
        // 預覽不開 WebView：那條路要 autologin，等於拿真的鑰匙去換假資料的
        // 網址。把要開的位址 toast 出來就足以確認點到了正確的一列。
        openWebView: (title, url) async =>
            TaskUiDelegate.instance.toast('preview → $url'),
      ),
    ));
    controller.dispose();
  }
}
