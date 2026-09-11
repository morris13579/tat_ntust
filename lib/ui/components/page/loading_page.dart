import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/tat_progress.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage(
      {super.key,
      required this.isLoading,
      this.isShowBackground = true,
      this.message});

  final bool isLoading;
  final bool isShowBackground;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Visibility(
        visible: isLoading,
        child: Stack(
          children: [
            // 一律透明：全螢幕變暗的載入畫面整個 App 都不用了。這一層留著是
            // 因為它擋得住點擊——底下的 WebView 在載入中本來就不該被點到。
            Positioned.fill(
                child: Container(
                    color: context.scheme.scrim.withValues(alpha: 0))),
            Center(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                indicator(),
                Visibility(
                    visible: message != null,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child:
                          Text(message ?? "", style: context.text.bodyMedium),
                    )),
              ],
            ))
          ],
        ));
  }

  Widget indicator() => const TatProgress(size: 28);
}
