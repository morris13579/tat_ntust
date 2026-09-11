import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 填色、無描邊的輸入欄。
///
/// 唯一會畫出來的邊是出錯時那圈 1.5px；平時保留成同寬的透明邊框，錯誤訊息
/// 出現時盒子才不會突然長高。
class InputField extends StatelessWidget {
  const InputField({
    super.key,
    required this.hint,
    this.label,
    this.controller,
    this.inputType,
    this.textAlign = TextAlign.start,
    this.maxLength,
    this.isError = false,
    this.errorMsg = "",
    this.onChange,
    this.readOnly = false,
    this.onTap,
    this.maxLines,
    this.obscureText = false,
    this.onToggleObscured,
    this.autofillHints,
    this.suffix,
    this.prefix,
  });

  final String hint;
  final String? label;
  final TextEditingController? controller;
  final TextInputType? inputType;
  final TextAlign textAlign;
  final int? maxLength;
  final bool isError;
  final String errorMsg;
  final int? maxLines;
  final bool readOnly;
  final Function(String)? onChange;
  final Function()? onTap;

  /// 遮住輸入內容。舊呼叫端還是靠 `inputType` 推導，見 [_obscured]。
  final bool obscureText;

  /// 非 null 才會畫出眼睛按鈕，切換由呼叫端持有狀態。
  final VoidCallback? onToggleObscured;

  final Iterable<String>? autofillHints;

  /// 眼睛按鈕以外的尾端元件。
  final Widget? suffix;

  /// 欄位前面的圖示（搜尋框用）。
  final Widget? prefix;

  /// `inputType: visiblePassword` 目前仍等於「要遮住」——舊呼叫端還沒改完，
  /// 這裡若只看 [obscureText]，密碼會在遷移完成前變成明文。
  bool get _obscured =>
      obscureText || inputType == TextInputType.visiblePassword;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 6),
            child: Text(label!, style: text.bodyMedium),
          ),
        // 外框、填色、高度、錯誤圈全部交給 InputDecorationTheme。自己再包一層
        // Container 會出事：主題的 filled:true 仍然生效，但 border 被蓋成 none，
        // 於是在圓角底板上又畫一塊直角的填色。
        TextField(
          controller: controller,
          obscureText: _obscured,
          keyboardType: inputType,
          textAlign: textAlign,
          maxLength: maxLength,
          readOnly: readOnly,
          onChanged: onChange,
          onTap: onTap,
          maxLines: _obscured ? 1 : maxLines,
          autofillHints: autofillHints ??
              [_obscured ? AutofillHints.password : AutofillHints.username],
          cursorRadius: const Radius.circular(999),
          // 單行輸入要壓掉內文的行高，否則字會浮在行框上緣。
          style: text.bodyLarge?.copyWith(height: 1.2),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            errorText: isError ? (errorMsg.isEmpty ? '' : errorMsg) : null,
            prefixIcon: prefix,
            prefixIconConstraints:
                const BoxConstraints(minWidth: 42, minHeight: 24),
            suffixIcon: _buildSuffix(context),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 42, minHeight: 24),
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffix(BuildContext context) {
    if (onToggleObscured != null) {
      return IconButton(
        // 純圖示按鈕沒有 tooltip 時螢幕閱讀器只唸得出「按鈕」。
        // 文案跟著狀態走：現在藏著就唸「顯示密碼」。
        tooltip: _obscured ? R.current.showPassword : R.current.hidePassword,
        icon: Icon(_obscured ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
        onPressed: onToggleObscured,
      );
    }
    return suffix;
  }
}
