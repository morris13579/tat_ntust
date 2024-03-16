import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';

import 'error_page.dart';

class BasePage extends StatelessWidget {
  const BasePage({
    super.key,
    required this.title,
    required this.child,
    this.isError = false,
    this.errorMsg,
    this.onRetry,
    this.isLoading = false,
    this.loadingPadding,
    this.action,
    this.floatingActionButton, this.loadingMsg,
    this.resizeToAvoidBottomInset = true,
  });

  final String title;
  final Widget child;
  final List<Widget>? action;
  final FloatingActionButton? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  // error control
  final bool isError;
  final String? errorMsg;
  final Function()? onRetry;

  // loading control
  final bool isLoading;
  final EdgeInsets? loadingPadding;
  final String? loadingMsg;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: mainAppbar(title: title, action: action),
      floatingActionButton: floatingActionButton,
      body: isError
          ? ErrorPage(errorMsg: errorMsg, onRetry: onRetry)
          : isLoading
              ? const LoadingPage(isLoading: true)
              : SafeArea(child: child),
    );
  }
}
