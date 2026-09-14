import 'dart:async';

import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/interactive_login_flow.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/service/interactive_login_gateway.dart';
import 'package:flutter_app/src/service/native_web_session.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/service/web_view_session.dart';

/// 原生版的 [InteractiveLoginGateway]。流程與 Flutter 版的登入頁同一份
/// （`interactive_login_flow.dart`），WebView 是 Swift 的 sheet。
class NativeInteractiveLoginGateway implements InteractiveLoginGateway {
  const NativeInteractiveLoginGateway();

  static void install() =>
      InteractiveLoginGateway.instance = const NativeInteractiveLoginGateway();

  @override
  Future<NtustInteractiveLoginResult?> signInNtust({
    required String account,
    required String password,
  }) {
    final flow = NtustLoginFlow(account: account, password: password);
    return _run(
      url: NtustLoginFlow.startUrl,
      title: "${R.current.login}...",
      progressMessage: R.current.loginNTUST,
      onLoadStop: flow.onLoadStop,
    );
  }

  @override
  Future<MoodleTokenEntity?> signInMoodle({
    required String account,
    required String password,
  }) {
    final flow = MoodleLoginFlow(account: account, password: password);
    return _run<MoodleTokenEntity?>(
      url: flow.startUrl,
      title: "${R.current.loginMoodle}...",
      progressMessage: R.current.loginMoodle,
      interceptSchemes: const [MoodleLoginFlow.callbackScheme],
      onLoadStop: flow.onLoadStop,
      onIntercepted: flow.onCallback,
    );
  }

  Future<T?> _run<T>({
    required String url,
    required String title,
    required String progressMessage,
    List<String> interceptSchemes = const [],
    required Future<LoginStep<T>> Function(WebViewDriver web, String? url)
        onLoadStop,
    LoginStep<T> Function(String url)? onIntercepted,
  }) async {
    final session = await NativeWebSessions.instance.openSession(
      url: url,
      visible: true,
      title: title,
      progressMessage: progressMessage,
      interceptSchemes: interceptSchemes,
    );
    final done = Completer<T?>();

    void apply(LoginStep<T> step) {
      switch (step) {
        case LoginContinue():
          break;
        case LoginNeedsHuman():
          unawaited(session.setProgress(null));
          TaskUiDelegate.instance.toast(R.current.needValidateCaptcha);
        case LoginFinished(:final result, :final notice):
          if (notice != null) TaskUiDelegate.instance.toast(notice);
          if (!done.isCompleted) done.complete(result);
      }
    }

    final subscription = session.events.listen((event) async {
      switch (event) {
        case WebViewLoadStop(:final url):
          apply(await onLoadStop(session, url));
        case WebViewIntercepted(:final url):
          if (onIntercepted != null) apply(onIntercepted(url));
        case WebViewDismissed():
          if (!done.isCompleted) done.complete(null);
        case WebViewLoadError():
          // 與 Flutter 版的可見頁一樣不收網：錯誤頁就在使用者眼前，要不要放棄由他決定。
          break;
      }
    });
    try {
      return await done.future;
    } finally {
      await subscription.cancel();
      await session.close();
    }
  }
}
