import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';

class CourseSearchBar extends StatelessWidget {
  const CourseSearchBar(
      {super.key,
      this.controller,
      this.onChange,
      this.readOnly = false,
      this.onTap,
      this.isBack = false,
      this.onSubmit,
      this.autofocus = true,
      this.hintText,
      this.onLeadingTap});

  final TextEditingController? controller;
  final bool isBack;
  final bool readOnly;
  final Function()? onTap;
  final Function(String)? onSubmit;
  final Function(String)? onChange;

  /// 版面裡的篩選欄要關掉：一進頁就彈鍵盤會把底下的清單整個推出畫面。
  final bool autofocus;

  /// 蓋掉預設的「搜尋」。
  final String? hintText;

  /// 左邊那顆鈕。null 時維持既有行為（離開這一頁）——當它是搜尋圖示而不是
  /// 返回箭頭時，那個行為並不合理，所以就地篩選的呼叫端一定要傳。
  final VoidCallback? onLeadingTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TatTokens.radiusField)),
      color: context.tokens.card,
      clipBehavior: Clip.antiAlias,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              searchButton(context),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  readOnly: readOnly,
                  onTap: onTap,
                  onSubmitted: onSubmit,
                  style: context.text.bodyLarge
                      ?.copyWith(color: context.scheme.onSurface, height: 1),
                  decoration: InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      constraints: const BoxConstraints(),
                      contentPadding: EdgeInsets.zero,
                      hintText: hintText ?? R.current.search),
                  onChanged: onChange,
                ),
              )
            ],
          )),
    );
  }

  Widget searchButton(BuildContext context) {
    final color = context.scheme.onSurface;
    final icon = isBack
        ? Icon(LucideIcons.chevronLeft, size: 18, color: color)
        : Icon(LucideIcons.search, color: color);

    return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onLeadingTap ?? Get.back,
        minimumSize: const Size(0.0, 0.0),
        child: icon);
  }
}
