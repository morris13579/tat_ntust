import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// TAT 公告全文。啟動彈窗與通知頁的「看完整公告」共用這一頁。
///
/// 翻頁的控制項全部收在底部的固定列：上一則、頁點、下一則／確定。原本的
/// 「確定」在 appbar 上，離使用者的拇指最遠，而且與「翻到下一則」看起來
/// 是兩件無關的事。
class AnnouncementPage extends StatefulWidget {
  final List<AnnouncementInfoJson> info;

  /// 啟動彈窗的閱讀倒數；使用者自己點進來時傳 0。
  final int countDown;

  const AnnouncementPage({
    super.key,
    required this.info,
    required this.countDown,
  });

  @override
  State<StatefulWidget> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  final PageController _pageController = PageController();
  Timer? _countDownTimer;
  int _index = 0;
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.countDown;
    // Timer 必須存成欄位並在 dispose 取消，回呼裡也要先檢查 mounted：對已
    // unmount 的 State setState 會拋例外，例外若在 timer.cancel() 之前逸出，
    // Timer 就永遠不會自我取消，每秒丟一次直到 process 結束。結束條件用 <= 0，
    // 避免 remote config 設成 0 或負數時永不結束。
    if (_count > 0) {
      _countDownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _count--);
        if (_count <= 0) timer.cancel();
      });
    }
  }

  @override
  void dispose() {
    _countDownTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(title: R.current.appAnnouncement),
      // bottom: false，安全區留給底部那條自己吃：SafeArea 包在外面的話，
      // 那條的底色就停在安全區上緣，底下透出 Scaffold 的底色，看起來像斷成兩截。
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.info.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) =>
                    _buildPage(context, widget.info[i], i),
              ),
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, AnnouncementInfoJson info, int i) {
    final scheme = context.scheme;
    final text = context.text;
    // startTime 是 UTC 欄位裝著台北的牆上時間（見 RemoteConfigUtils），
    // toLocal() 會讓每一則公告的日期整整位移八小時。
    final date = DateFormat.MMMd().format(info.startTime);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      children: [
        Row(
          children: [
            if (widget.info.length > 1) ...[
              _CounterChip(position: i + 1, total: widget.info.length),
              const SizedBox(width: 9),
            ],
            Semantics(
              label: '${R.current.announcementPublishedAt} $date',
              child: Text(
                date,
                style: AppTypography.tabular(text.bodySmall!)
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          info.title,
          style: text.headlineSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        SectionCard([
          MarkdownBody(
            data: info.content,
            selectable: true,
            styleSheet:
                MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: text.bodyLarge?.copyWith(color: scheme.onSurface),
              listBullet: text.bodyLarge?.copyWith(color: scheme.onSurface),
              a: text.bodyLarge?.copyWith(
                color: scheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: scheme.primary,
              ),
              horizontalRuleDecoration: BoxDecoration(
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
            ),
            // 公告連的是表單與商店，不是 Moodle，一律走外部瀏覽器。
            onTapLink: (t, href, title) {
              if (href != null) unawaited(launchUrlString(href));
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final scheme = context.scheme;
    final multiple = widget.info.length > 1;
    final isLast = _index >= widget.info.length - 1;
    final waiting = _count > 0;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      // 底色鋪到螢幕底部，內容自己讓開安全區。
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 14 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          if (multiple) ...[
            _SquareButton(
              icon: LucideIcons.chevronLeft,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: _index == 0 ? null : _previous,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: multiple
                ? _Dots(count: widget.info.length, active: _index)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 10),
          FilledButton(
            // 倒數只擋最後那顆「確定」：翻頁不是關掉公告，沒有理由等。
            onPressed: isLast ? (waiting ? null : _confirm) : _next,
            child: Text(isLast
                ? (waiting ? '${R.current.wait} $_count' : R.current.sure)
                : R.current.announcementNext),
          ),
        ],
      ),
    );
  }

  void _previous() => unawaited(_pageController.previousPage(
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut));

  void _next() => unawaited(_pageController.nextPage(
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut));

  void _confirm() {
    Navigator.of(context).pop(true);
    unawaited(RemoteConfigUtils.setAnnouncementRead());
  }
}

/// 「1 / 2」。只在有兩則以上時出現——一則的時候它只是在說「一共一則」。
class _CounterChip extends StatelessWidget {
  const _CounterChip({required this.position, required this.total});

  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(TatTokens.radiusButton),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.megaphone,
              size: 14, color: scheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            '$position / $total',
            style: AppTypography.tabular(context.text.labelMedium!)
                .copyWith(color: scheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active ? scheme.primary : scheme.outlineVariant,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

/// 底部列左邊那顆方形圖示鈕。不用 IconButton：它的形狀是圓的，而設計稿這裡
/// 是一個 44 見方、圓角 8 的色塊。
class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TatTokens.radiusButton),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: TatTokens.heightButton,
            height: TatTokens.heightButton,
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? scheme.onSurfaceVariant
                  : scheme.onSurfaceVariant.withValues(alpha: 0.38),
            ),
          ),
        ),
      ),
    );
  }
}
