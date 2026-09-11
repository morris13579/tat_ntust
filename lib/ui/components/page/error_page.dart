import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/components/adaptive_button.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 整頁級的錯誤畫面。
///
/// 登入頁走 [TaskUiDelegate] 而不是 `RouteUtils`：這一支被半個 app 的
/// `errorBuilder` 引用，直接 import 路由表會把整包頁面拉進同一個相依環。
class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key, this.errorMsg, this.onRetry});

  final String? errorMsg;

  /// 重試入口。沒有它、而且使用者已經登入時，這一頁就是條死路——所以
  /// 呼叫端能給就要給。
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.triangleAlert,
                size: 32, color: context.scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            errorContent(context),
            const SizedBox(height: 12),
            actionButton(context),
            const SizedBox(height: 24)
          ],
        ),
      ),
    );
  }

  Widget errorContent(BuildContext context) {
    final scheme = context.scheme;
    if (errorMsg != null) {
      return Text(
        errorMsg?.isEmpty == true
            ? R.current.error
            : (errorMsg ?? R.current.error),
        style: context.text.bodyLarge?.copyWith(color: scheme.onSurface),
        textAlign: TextAlign.center,
        maxLines: 5,
        overflow: TextOverflow.fade,
      );
    }
    final headline = context.text.titleSmall?.copyWith(color: scheme.onSurface);
    return FutureBuilder(
        future: (Connectivity().checkConnectivity()),
        builder:
            (BuildContext context, AsyncSnapshot<ConnectivityResult> snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data == ConnectivityResult.none) {
              return Text(R.current.networkError, style: headline);
            }
          }
          return Text(
            !AuthSession.instance.isSignedIn
                ? R.current.pleaseLoginWarning
                : R.current.somethingError,
            style: headline,
          );
        });
  }

  /// 沒登入時出口是登入頁（回來之後順手重試一次），否則是重試。兩者都沒有的
  /// 時候才留白。
  Widget actionButton(BuildContext context) {
    if (!AuthSession.instance.isSignedIn) {
      return AdaptiveButton(
        onPressed: () async {
          await TaskUiDelegate.instance.openLoginScreen();
          await onRetry?.call();
        },
        borderRadius: BorderRadius.circular(999),
        child: Text(R.current.login),
      );
    }
    if (onRetry != null) {
      return TextButton(
        onPressed: onRetry,
        child: Text(R.current.refresh),
      );
    }
    return const SizedBox();
  }
}
