import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/components/adaptive_button.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 區塊層級的錯誤畫面：訊息加一顆重試入口（沒登入時改成「登入」）。長相照
/// `ErrorPage` 但不 import 它，見 docs/ARCHITECTURE.md「UI 慣例」。
class InlineErrorView extends StatelessWidget {
  const InlineErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final signedIn = AuthSession.instance.isSignedIn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.triangleAlert,
                size: 28, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: 12),
            if (!signedIn)
              AdaptiveButton(
                borderRadius: BorderRadius.circular(999),
                onPressed: () async {
                  await TaskUiDelegate.instance.openLoginScreen();
                  await onRetry();
                },
                child: Text(R.current.login),
              )
            else
              TextButton(
                onPressed: onRetry,
                child: Text(R.current.refresh),
              ),
          ],
        ),
      ),
    );
  }
}
