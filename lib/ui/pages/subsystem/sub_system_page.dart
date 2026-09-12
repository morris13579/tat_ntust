import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/controller/subsystem/sub_system_controller.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/page/section_empty_state.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/subsystem/components/service_row.dart';
import 'package:flutter_app/ui/pages/subsystem/components/sub_system_search_field.dart';
import 'package:flutter_app/ui/pages/subsystem/sub_system_category.dart';
import 'package:get/get.dart';
import 'package:sprintf/sprintf.dart';

/// 資訊系統：可搜尋的分段清單。
///
/// 錯誤畫面與 WebView 開啟器由呼叫端注入，見 docs/ARCHITECTURE.md「UI 慣例」。
class SubSystemPage extends StatefulWidget {
  const SubSystemPage({
    super.key,
    required this.errorBuilder,
    required this.openWebView,
    required this.openClassroom,
    this.serviceId,
  });

  /// 只看單一分類時帶它的代號；null 代表全部服務。
  final String? serviceId;

  final Widget Function(String message) errorBuilder;
  final WebViewOpener openWebView;

  /// 空教室。由呼叫端注入而不是 import 路由表——那會是 lib/ui 那個環的
  /// 又一條邊（見 docs/ARCHITECTURE.md「UI 慣例」）。
  final VoidCallback openClassroom;

  @override
  State<StatefulWidget> createState() => _SubSystemPageState();
}

class _SubSystemPageState extends State<SubSystemPage> {
  final _controller = SubSystemController();

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 從分類卡進來時標題就是那一類，不要再叫「資訊系統」——使用者是從
      // 「課程資訊」點進來的。
      appBar: baseAppbar(
        title: (widget.serviceId == null
                ? null
                : subSystemCategoryName(widget.serviceId!)) ??
            R.current.informationSystem,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SubSystemSearchField(onChanged: _controller.search),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              physics: const BouncingScrollPhysics(),
              children: [
                ResultView<List<APTreeJson>>(
                  state: _controller.tree,
                  shrinkWrap: true,
                  onRetry: _controller.load,
                  errorBuilder: widget.errorBuilder,
                  builder: (tree) => Obx(() => _buildCategories(context, tree)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(BuildContext context, List<APTreeJson> tree) {
    // 先讀一次關鍵字：底下的迴圈有可能一個分類都不進去（例如只看單一分類
    // 時），那樣 Obx 會因為沒有登記到任何 observable 而丟例外。
    final keyword = _controller.keyword.value;
    final sections = <Widget>[];
    // 從「更多」的分類卡進來時只看那一類，標題也已經是分類名，所以不再重複
    // 畫一次分段標題。
    final single = widget.serviceId != null;
    for (final category in tree) {
      if (single && category.serviceId != widget.serviceId) continue;
      final items = _controller.visibleItems(category);
      // 空教室釘在「校園資訊」最上面：那是使用者原本會去翻的位置。它是
      // App 自己的頁面，所以標一個籤，點了不開瀏覽器。
      final pinned = category.serviceId == classroomPinnedCategory &&
          _matchesKeyword(keyword, R.current.classroomTitle);
      if (items.isEmpty && !pinned) continue;

      sections.add(_Section(
        title: single ? null : subSystemCategoryName(category.serviceId),
        trailing: single ? null : sprintf(R.current.itemCount, [items.length]),
        children: [
          if (pinned)
            ServiceRow(
              name: R.current.classroomTitle,
              description: R.current.classroomSubSystemHint,
              badge: R.current.classroomInApp,
              onTap: widget.openClassroom,
            ),
          for (final ap in items)
            ServiceRow(
              name: ap.name,
              onTap: () => widget.openWebView(ap.name, ap.url),
            ),
        ],
      ));
    }

    if (sections.isEmpty) {
      // 關鍵字是空的時候不套這張空畫面：那代表學校端回了一份空清單，
      // 說「未搜尋到任何服務」會把責任推給沒有搜尋的使用者。
      if (keyword.isEmpty) return const SizedBox.shrink();
      return SectionEmptyState(
        icon: LucideIcons.searchX,
        message: R.current.subSystemSearchEmpty,
      );
    }
    return Column(children: sections);
  }
}

/// 空教室釘在哪一類底下：`service-6`＝「校園資訊」，那是使用者原本會去翻
/// 的位置。代號與名稱的對照只有 `subSystemCategoryName` 一份，改那裡就要
/// 回來看這裡——守門測試在 test/ui/sub_system_search_test.dart。
@visibleForTesting
const String classroomPinnedCategory = 'service-6';

/// 釘住的那一列也要吃搜尋：關鍵字不是空的時候，對不上就不畫。
bool _matchesKeyword(String keyword, String name) =>
    keyword.trim().isEmpty ||
    name.toLowerCase().contains(keyword.trim().toLowerCase());

/// 一段服務清單：標題列在外，列本身裝在同一塊 surface 裡，以髮線分隔。
class _Section extends StatelessWidget {
  const _Section({required this.children, this.title, this.trailing});

  /// null 代表對不到的分類代號——照樣畫出底下的服務，只是沒有標題。
  final String? title;

  /// 標題右邊的項數。
  final String? trailing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title!, style: context.text.titleSmall),
                  ),
                  if (trailing != null)
                    Text(
                      trailing!,
                      style: context.text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          // 全 App 的清單都是這個形狀：每一列是自己的圓角塊、頭尾收大圓角、
          // 中間留 2px 的縫，不用分隔線。
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            Material(
              color: context.tokens.card,
              borderRadius: UIUtils.getBorderRadius(i, children.length),
              clipBehavior: Clip.antiAlias,
              child: children[i],
            ),
          ],
        ],
      ),
    );
  }
}
