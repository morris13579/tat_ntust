import 'package:flutter/material.dart';
import 'package:flutter_app/src/util/file_icon_utils.dart';
import 'package:flutter_app/ui/other/svg_tint.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Moodle 檔案的類型 icon，對應官方 App 的 core-file 元件。
/// 挑選規則在 [FileIconUtils]，這裡只負責畫。
class FileTypeIcon extends StatelessWidget {
  const FileTypeIcon({
    super.key,
    this.filename = "",
    this.mimetype = "",
    this.modicon = "",
    this.size = 24,
    this.color,
  });

  final String filename;
  final String mimetype;
  final String modicon;
  final double size;

  /// null 時跟 [Icon] 一樣取 IconTheme 的顏色。
  final Color? color;

  String get iconName => FileIconUtils.iconFor(
        filename: filename,
        mimetype: mimetype,
        modicon: modicon,
      );

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      FileIconUtils.assetPath(iconName),
      width: size,
      height: size,
      colorFilter: svgTint(color ?? IconTheme.of(context).color),
    );
  }
}
