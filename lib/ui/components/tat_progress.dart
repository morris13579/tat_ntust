import 'package:flutter/material.dart';

/// 全 App 共用的轉圈。
///
/// 線寬 2、圓端點：跟 Lucide 那套 1.5px 的線性圖示是同一種筆觸。Material 預設
/// 的 4.0 配上這套圖示會粗得像另一個 App 的東西，`CupertinoActivityIndicator`
/// 的輻條又是第三種畫法——所以這裡不分平台，只有一種。
class TatProgress extends StatelessWidget {
  const TatProgress({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        strokeCap: StrokeCap.round,
        color: color,
      ),
    );
  }
}
