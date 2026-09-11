import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 群組標題，刻意放在卡片外：內容載入中或失敗時標題仍在。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    this.icon,
    required this.title,
    this.trailing,
    this.first = false,
  });

  /// null 就只有文字。設定頁那三段照設計稿不帶圖示——一整排彼此無關的圖示
  /// 只會讓人以為它們是同一組東西。
  final IconData? icon;
  final String title;
  final Widget? trailing;
  final bool first;

  static const double _iconSize = 18;

  /// 標題第一行的行高。
  ///
  /// [Icon] 是圖示字型裡的一個字，Flutter 算得出它的基線，但那是圖示字型的
  /// 基線，和標題的文字基線互不相干（lucide 的 ascender 就是字身高，所以
  /// 18px 的圖示回報的基線剛好是 18，比標題的 ~17 低）——所以圖示改成置中在
  /// 這個高度裡，而不是跟標題對基線。高度跟著主題字級與系統字級縮放走。
  static double _titleLineHeight(BuildContext context, TextStyle? style) {
    final fontSize = style?.fontSize;
    final height = style?.height;
    // 主題沒給字級或行高倍率就退回圖示自己的高度：算不出行高，寧可不推。
    if (fontSize == null || height == null) return _iconSize;
    return MediaQuery.textScalerOf(context).scale(fontSize) * height;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final titleStyle =
        context.text.titleSmall?.copyWith(color: scheme.onSurfaceVariant);
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(8, first ? 4 : 20, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: icon == null
                ? titleText
                // 圖示和標題自成一列（切齊頂端），trailing 留在外層才對得到標題
                // 的基線——內層這一列回報的基線就是標題的。
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IgnoreBaseline：把圖示排除在基線計算外。預設字級下
                      // 標題的基線本來就比較高、贏得過圖示，但系統字級放大時
                      // 圖示不跟著放大（iconTheme 沒開 applyTextScaling），
                      // 它的基線會反過來蓋過標題，trailing 就對到圖示去。
                      IgnoreBaseline(
                        child: SizedBox(
                          height: _titleLineHeight(context, titleStyle),
                          child: Center(
                            child: Icon(icon,
                                size: _iconSize,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: titleText),
                    ],
                  ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 內容卡：surfaceContainer、圓角 12、padding 14/12。
class SectionCard extends StatelessWidget {
  const SectionCard(this.children, {super.key}) : _padding = padding;

  /// 上下讓出 16 的緊湊版。給「高度被鍵盤壓到連編輯面都守不住」的版面用，
  /// 左右與圓角一律不動——卡片還是同一張卡片。
  const SectionCard.compact(this.children, {super.key})
      : _padding = compactPadding;

  static const double radius = TatTokens.radiusCard;
  static const EdgeInsets padding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 12);
  static const EdgeInsets compactPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 4);

  /// 卡片底色的唯一出處。編輯面與工具列的漸層都要跟它一致，各自寫一份在
  /// 動態取色的機器上一定會對不起來。
  static Color fill(BuildContext context) => context.tokens.card;

  static BoxDecoration _decoration(BuildContext context) => BoxDecoration(
        color: fill(context),
        borderRadius: BorderRadius.circular(radius),
      );

  final List<Widget> children;

  final EdgeInsets _padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _decoration(context),
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// 列數不定時的內容卡：外觀同 [SectionCard]，但內容留在 sliver 裡逐列建構，
/// 上百個檔案的資料夾才不會在進頁時一次建完。
class SectionCardSliver extends StatelessWidget {
  const SectionCardSliver({super.key, required this.sliver});

  final Widget sliver;

  @override
  Widget build(BuildContext context) => DecoratedSliver(
        decoration: SectionCard._decoration(context),
        sliver: SliverPadding(padding: SectionCard.padding, sliver: sliver),
      );
}

/// 「標籤：值」的一列。標籤小而淡（固定 104 寬），值才是主角。
class SectionField extends StatelessWidget {
  const SectionField(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label,
                style: text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                style: text.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                    height: 1.3)),
          ),
        ],
      ),
    );
  }
}

/// 卡片內的子標題。
class SectionSubLabel extends StatelessWidget {
  const SectionSubLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: context.text.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 卡片內的分隔線。
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  @override
  Widget build(BuildContext context) => const Divider(height: 24);
}
