import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';

import 'error_page.dart';

class BasePage extends StatelessWidget {
  const BasePage({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.isError = false,
    this.errorMsg,
    this.isLoading = false,
    this.loadingPadding,
    this.action,
    this.floatingActionButton,
    this.loadingMsg,
    this.resizeToAvoidBottomInset = true,
    this.isShowBack = false,
    this.isSubPage = false,
    this.bottom,
    this.bottomSafeArea = true,
  });

  final String title;

  /// 標題底下那一行小字。只有 mainAppbar 支援。
  final String? subtitle;

  final Widget child;
  final List<Widget>? action;
  final FloatingActionButton? floatingActionButton;
  final bool resizeToAvoidBottomInset;
  final bool isShowBack;
  final bool isSubPage;
  final PreferredSizeWidget? bottom;

  /// 底部安全區要不要由這一層讓開。捲動清單設 false 自己吃掉那段內距，內容
  /// 才會一路鋪到螢幕底部，而不是停在安全區上緣、底下空一條死掉的色帶。
  final bool bottomSafeArea;

  // error control
  final bool isError;
  final String? errorMsg;

  // loading control
  final bool isLoading;
  final EdgeInsets? loadingPadding;
  final String? loadingMsg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: isSubPage
          ? baseAppbar(title: title, action: action, bottom: bottom)
          : mainAppbar(
              title: title,
              subtitle: subtitle,
              action: action,
              isShowBack: isShowBack,
              bottom: bottom),
      floatingActionButton: floatingActionButton,
      body: isError
          ? ErrorPage(errorMsg: errorMsg)
          : isLoading
              ? const LoadingPage(
                  isLoading: true,
                  isShowBackground: false,
                )
              : SafeArea(bottom: bottomSafeArea, child: child),
    );
  }
}
