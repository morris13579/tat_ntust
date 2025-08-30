import 'package:flutter_inappwebview/flutter_inappwebview.dart';

extension InAppWebViewControllerExtension on InAppWebViewController {
  Future<bool> waitForElement({
    required String condition,
    Duration timeout = const Duration(seconds: 10),
    Duration pollingInterval = const Duration(milliseconds: 200),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      final result = await evaluateJavascript(source: condition);

      if (result == true) {
        stopwatch.stop();
        return true;
      }

      await Future.delayed(pollingInterval);
    }

    stopwatch.stop();
    return false;
  }
}