import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 全 App 唯一的分頁列樣式。
///
/// 指示器是 2px 的 primary，底下再壓一條髮線——設計稿的分頁列是「標頭區的
/// 最後一列」，沒有那條線它會浮在頁面底色上。
///
/// 圖示與文字的顏色交給 TabBar 的 labelColor / unselectedLabelColor，不自己
/// 依 index 上色：手算的那一套在用手勢滑到一半時會停在舊的那一格。
///
/// 裸 `TabBar` 會吃 Material 的預設值，跟這裡差一截，所以分頁列一律走這個元件。
class TatTabBar extends StatelessWidget implements PreferredSizeWidget {
  const TatTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.onTap,
  });

  /// 圖示＋文字或純文字都收，兩種高度由 [preferredSize] 分別算。
  final List<Widget> tabs;

  /// 為 null 時 TabBar 會回退到祖先的 DefaultTabController；沒有祖先可回退的
  /// 頁面要自己在外面擋掉 null。
  final TabController? controller;

  final bool isScrollable;

  final ValueChanged<int>? onTap;

  static const double _indicatorWeight = 2;

  /// 高度借 TabBar 自己的規則算：純文字與「圖示＋文字」的列高不同，抄一份
  /// 常數過來會在 Flutter 改預設值時失準。
  @override
  Size get preferredSize =>
      TabBar(tabs: tabs, indicatorWeight: _indicatorWeight).preferredSize;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    return TabBar(
      tabs: tabs,
      controller: controller,
      isScrollable: isScrollable,
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorColor: scheme.primary,
      indicatorWeight: _indicatorWeight,
      dividerColor: scheme.outlineVariant,
      dividerHeight: 1,
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle:
          text.labelLarge?.copyWith(fontWeight: FontWeight.w400),
      onTap: onTap,
    );
  }
}
