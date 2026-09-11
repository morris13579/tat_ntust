import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/course_table_share_codec.dart';
import 'package:flutter_app/ui/components/page/note_icon.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sprintf/sprintf.dart';

/// 分享課表：一張 QR，加上「這是誰的、哪一學期」的落款。
///
/// 存檔與提示都由呼叫端注入：存圖要碰檔案系統與分享面板，那不屬於一張選單，
/// 而且注入之後這個檔案在測試裡不需要任何平台外掛。
Future<void> showShareTableSheet({
  required BuildContext context,
  required CourseTableJson table,
  required Future<void> Function(Uint8List png) onSaveImage,
  required VoidCallback onCopied,
}) =>
    showTatContentSheet<void>(
      context: context,
      title: R.current.shareTableTitle,
      builder: (context) => _ShareTableContent(
        table: table,
        onSaveImage: onSaveImage,
        onCopied: onCopied,
      ),
    );

class _ShareTableContent extends StatefulWidget {
  const _ShareTableContent({
    required this.table,
    required this.onSaveImage,
    required this.onCopied,
  });

  final CourseTableJson table;
  final Future<void> Function(Uint8List png) onSaveImage;
  final VoidCallback onCopied;

  @override
  State<_ShareTableContent> createState() => _ShareTableContentState();
}

class _ShareTableContentState extends State<_ShareTableContent> {
  final ScreenshotController _shot = ScreenshotController();

  /// 存圖要跨到平台那一側，慢的時候會被連點。
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final idStyle = context.text.titleLarge;
    final noteStyle =
        context.text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Screenshot(
              controller: _shot,
              child: _QrCard(data: CourseTableShareCodec.encode(widget.table)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            R.current.shareTableHint,
            textAlign: TextAlign.center,
            style: noteStyle,
          ),
          const SizedBox(height: 16),
          Text(
            widget.table.studentId,
            textAlign: TextAlign.center,
            style: idStyle == null ? null : AppTypography.tabular(idStyle),
          ),
          const SizedBox(height: 2),
          Text(
            _summary(),
            textAlign: TextAlign.center,
            style: context.text.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary.withValues(alpha: 0.7),
                    ),
                  )
                : const Icon(LucideIcons.download, size: 18),
            label: Text(R.current.shareTableSaveImage),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _copy,
            child: Text(R.current.shareTableCopyCode),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NoteIcon(LucideIcons.info,
                  style: noteStyle, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(R.current.shareTableNote, style: noteStyle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _summary() {
    final semester = widget.table.courseSemester;
    return [
      '${semester.year}-${semester.semester}',
      sprintf(R.current.courseCount, [widget.table.getCourseIdList().length]),
      sprintf(R.current.creditCount, [widget.table.getTotalCredit()]),
    ].join(' · ');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // 截不到圖就什麼都不做：那代表這一塊還沒畫完，硬存會存出一張空白。
      final png = await _shot.capture(pixelRatio: 3);
      if (png != null) await widget.onSaveImage(png);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: CourseTableShareCodec.encodePayload(widget.table)),
    );
    widget.onCopied();
  }
}

/// QR 那一塊。
class _QrCard extends StatelessWidget {
  const _QrCard({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    // 這一塊刻意不吃 scheme：QR 的黑白對比是掃描器的判讀條件，跟著暗色主題
    // 反白或染色就掃不動，而且存成圖片傳出去之後沒有機會補救。
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TatTokens.radiusSheet),
      ),
      child: QrImageView(
        data: data,
        size: 200,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
  }
}
