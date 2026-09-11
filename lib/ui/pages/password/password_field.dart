import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 密碼輸入欄位，附眼睛切換與底下的錯誤訊息列。目前只有
/// `CheckPasswordDialog` 用它。
///
/// 外觀跟 `InputField` 同一套（填色、無描邊、圓角 14、高 48），但這裡不能直接
/// 用它：對話框要靠 `Form` 的 [validator] 才知道能不能送出，而 `InputField`
/// 包的是 `TextField`。
///
/// **這裡只管外觀與可及性。** 要拿什麼比對是呼叫端的事，所以 [validator]
/// 由呼叫端傳入。
class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.obscured,
    required this.onToggleObscured,
    required this.hintText,
    required this.validator,
    required this.errorMessage,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// true 代表目前是遮住的。
  final bool obscured;
  final VoidCallback onToggleObscured;

  final String hintText;
  final String? Function(String?) validator;

  /// 顯示在欄位下方的錯誤訊息。空字串代表不顯示。
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    final hasError = errorMessage.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: TatTokens.heightField),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(TatTokens.radiusField),
            // 出錯才畫的那一圈；平時保留成透明同寬，盒子才不會跳高。
            border: Border.all(
              color: hasError ? scheme.error : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  cursorColor: scheme.primary,
                  textInputAction: TextInputAction.done,
                  focusNode: focusNode,
                  onEditingComplete: focusNode.unfocus,
                  obscureText: obscured,
                  validator: validator,
                  style: text.bodyLarge,
                  decoration: InputDecoration(
                    // 外面那層 Container 已經畫好圓角底色。沒關掉 filled 的話
                    // 主題會照著 InputBorder.none 的方形外框再填一次，把左邊
                    // 兩個角蓋成直角（右邊被眼睛圖示蓋住所以看起來還是圓的）。
                    filled: false,
                    isDense: true,
                    hintText: hintText,
                    hintStyle: text.bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    // 錯誤訊息自己畫在下面，這裡把內建的那條壓成零高度，
                    // 否則對話框會在輸入錯誤時跳一下。
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                  ),
                ),
              ),
              IconButton(
                // 純圖示按鈕沒有 tooltip 時，螢幕閱讀器只唸得出「按鈕」，也唸不
                // 出密碼目前是顯示還是隱藏。tooltip 會轉成 semantics label，文案
                // 要跟著狀態走：現在藏著就唸「顯示密碼」（按下去會發生的事）。
                tooltip:
                    obscured ? R.current.showPassword : R.current.hidePassword,
                icon: Icon(obscured ? LucideIcons.eyeOff : LucideIcons.eye),
                onPressed: onToggleObscured,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 4),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 140),
            child: Visibility(
              visible: hasError,
              child: Text(
                errorMessage,
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
