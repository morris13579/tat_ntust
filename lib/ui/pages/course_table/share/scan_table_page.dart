import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/service/image_pick_service.dart';
import 'package:flutter_app/src/util/course_table_share_codec.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/note_icon.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 掃描他人課表。
///
/// 相機之外一定要留相簿與貼上這兩條路：分享碼多半是被截圖丟進群組的，收方
/// 沒有第二支手機掃自己的螢幕。所以相機起不來（沒權限）也不是死路。
///
/// 匯入與錯誤提示都由呼叫端注入——這一頁不開 toast、不換頁。
class ScanTablePage extends StatefulWidget {
  const ScanTablePage({
    super.key,
    required this.onDetected,
    required this.onError,
  });

  /// 解得開的分享碼。最多只會被呼叫一次。
  final void Function(SharedTablePayload payload) onDetected;

  final void Function(String message) onError;

  @override
  State<ScanTablePage> createState() => _ScanTablePageState();
}

class _ScanTablePageState extends State<ScanTablePage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  /// 收下一次就結束。相機一秒會丟好幾筆，沒有這道閘就會重複匯入。
  bool _handled = false;

  /// 上一次提示過的內容。對著別的 QR 時同一份內容會一直進來，只提示一次。
  String? _rejected;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mainAppbar(title: R.current.scanTableTitle, isShowBack: true),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(TatTokens.radiusField),
                  child: MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    placeholderBuilder: (context, child) =>
                        ColoredBox(color: context.tokens.card),
                    errorBuilder: (context, error, child) => _cameraError(),
                    overlayBuilder: _overlay,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _actions(),
              const SizedBox(height: 10),
              _note(),
            ],
          ),
        ),
      ),
    );
  }

  /// 取景框：外面壓一層 scrim，四角畫括號，框下面放提示。
  Widget _overlay(BuildContext context, BoxConstraints constraints) {
    final side = math.min(
        math.min(constraints.maxWidth, constraints.maxHeight) * 0.62, 280.0);
    final frame = Rect.fromCenter(
      center: constraints.biggest.center(Offset.zero),
      width: side,
      height: side,
    );
    final bright = _brightOf(context.scheme);
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ScanFramePainter(
              frame: frame,
              bracket: bright,
              scrim: context.scheme.scrim
                  .withValues(alpha: TatTokens.scrimOpacity),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          top: frame.bottom + 16,
          child: Text(
            R.current.scanTableHint,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: bright),
          ),
        ),
      ],
    );
  }

  Widget _cameraError() => ColoredBox(
        color: context.tokens.card,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.cameraOff,
                    size: 28, color: context.scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  R.current.scanTablePermission,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );

  /// 三塊動作連成一組：外緣 14、相鄰的角 4，和清單列同一套圓角。
  Widget _actions() => Column(
        children: [
          Row(
            children: [
              Expanded(child: _torchAction()),
              const SizedBox(width: 2),
              Expanded(
                child: _action(
                  icon: LucideIcons.image,
                  label: R.current.scanTableGallery,
                  radius: const BorderRadius.only(
                    topLeft: _inner,
                    topRight: _outer,
                    bottomLeft: _inner,
                    bottomRight: _inner,
                  ),
                  onTap: _pickFromGallery,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _action(
            icon: LucideIcons.clipboard,
            label: R.current.scanTablePaste,
            radius: const BorderRadius.vertical(top: _inner, bottom: _outer),
            onTap: _pasteCode,
          ),
        ],
      );

  Widget _torchAction() => ValueListenableBuilder<MobileScannerState>(
        valueListenable: _controller,
        builder: (context, state, child) {
          final isOn = state.torchState == TorchState.on;
          // 相機沒跑起來時 toggleTorch 會丟例外，所以這裡直接讓它按不下去。
          final usable =
              state.isRunning && state.torchState != TorchState.unavailable;
          return _action(
            icon: LucideIcons.flashlight,
            label: R.current.scanTableTorch,
            radius: const BorderRadius.only(
              topLeft: _outer,
              topRight: _inner,
              bottomLeft: _inner,
              bottomRight: _inner,
            ),
            selected: isOn,
            onTap: usable ? () => unawaited(_controller.toggleTorch()) : null,
          );
        },
      );

  Widget _action({
    required IconData icon,
    required String label,
    required BorderRadius radius,
    required VoidCallback? onTap,
    bool selected = false,
  }) {
    final scheme = context.scheme;
    final foreground = selected
        ? scheme.primary
        : scheme.onSurfaceVariant.withValues(alpha: onTap == null ? 0.38 : 1.0);
    return Material(
      color: selected ? scheme.primaryContainer : context.tokens.card,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: TatTokens.heightRow),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge
                      ?.copyWith(color: foreground, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _note() {
    final scheme = context.scheme;
    final style =
        context.text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NoteIcon(LucideIcons.info,
              style: style, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(R.current.scanTableNote, style: style)),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      if (_accept(barcode.rawValue)) return;
    }
    final raw =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw == _rejected) return;
    _rejected = raw;
    widget.onError(R.current.scanTableInvalid);
  }

  /// 從相簿挑一張截圖來解。
  ///
  /// 走 [ImagePickService] 而不是直接 `ImagePicker()`：Android 的 manifest 把
  /// READ_MEDIA_IMAGES 移掉了，只有那支服務設的系統相片挑選器這條路走得通。
  Future<void> _pickFromGallery() async {
    try {
      final file =
          await ImagePickService.instance.pick(ImagePickSource.gallery);
      if (file == null || !mounted) return;
      final capture = await _controller.analyzeImage(file.path);
      if (!mounted) return;
      for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
        if (_accept(barcode.rawValue)) return;
      }
      widget.onError(R.current.scanTableInvalid);
    } on ImagePickFailure catch (e) {
      widget.onError(e.reason == ImagePickFailureReason.unavailable
          ? R.current.unknownError
          : R.current.noPermission);
    }
  }

  Future<void> _pasteCode() async {
    final code = await showTatDialog<String>(dialog: const _PasteCodeDialog());
    if (code == null || code.trim().isEmpty || !mounted) return;
    if (_accept(code)) return;
    widget.onError(R.current.scanTableInvalid);
  }

  /// 解得開就收下並離開，回 true。
  bool _accept(String? raw) {
    if (_handled || raw == null || !mounted) return false;
    final payload = CourseTableShareCodec.decode(raw);
    if (payload == null) return false;
    _handled = true;
    unawaited(_controller.stop());
    widget.onDetected(payload);
    Navigator.pop(context);
    return true;
  }
}

/// 貼上代碼。
class _PasteCodeDialog extends StatefulWidget {
  const _PasteCodeDialog();

  @override
  State<_PasteCodeDialog> createState() => _PasteCodeDialogState();
}

class _PasteCodeDialogState extends State<_PasteCodeDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return TatDialog(
      title: R.current.scanTablePaste,
      body: null,
      kind: TatDialogKind.info,
      // 底色、圓角、高度與內距全都在 InputDecorationTheme。外面不要再包一層
      // 圓角容器並把 border 蓋成 none：InputBorder.none 的外框是方的，主題的
      // filled 會照著它畫一塊方形填色蓋在圓角上，角就沒了。
      content: TextField(
        controller: _controller,
        autofocus: true,
        cursorColor: scheme.primary,
        maxLines: 3,
        minLines: 1,
        style: context.text.bodyLarge,
        decoration: InputDecoration(hintText: R.current.scanTablePasteHint),
      ),
      secondary: TatDialogAction(
        label: R.current.cancel,
        onPressed: () => Navigator.pop(context),
      ),
      primary: TatDialogAction(
        label: R.current.sure,
        onPressed: () => Navigator.pop(context, _controller.text),
      ),
    );
  }
}

/// 取景框的圓角與四角括號。
const double _frameRadius = 20;
const double _bracketArm = 26;

/// 動作那一組的圓角：外緣與相鄰的角，和 `UIUtils.getBorderRadius` 同一組數字。
const Radius _outer = Radius.circular(TatTokens.radiusField);
const Radius _inner = Radius.circular(4);

/// 相機畫面不是主題色的表面，亮色模式的 onSurface 壓在深色影像上會不見。
/// 所以框線把 primary 的色相拉到固定的高明度——顏色仍然跟著裝置配色走。
Color _brightOf(ColorScheme scheme) => HSLColor.fromColor(scheme.primary)
    .withSaturation(0.35)
    .withLightness(0.92)
    .toColor();

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter({
    required this.frame,
    required this.bracket,
    required this.scrim,
  });

  final Rect frame;
  final Color bracket;
  final Color scrim;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(_frameRadius);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(RRect.fromRectAndRadius(frame, radius)),
      ),
      Paint()..color = scrim,
    );

    const r = _frameRadius;
    const arm = _bracketArm;
    final path = Path()
      ..moveTo(frame.left, frame.top + r + arm)
      ..lineTo(frame.left, frame.top + r)
      ..arcToPoint(Offset(frame.left + r, frame.top), radius: radius)
      ..lineTo(frame.left + r + arm, frame.top)
      ..moveTo(frame.right - r - arm, frame.top)
      ..lineTo(frame.right - r, frame.top)
      ..arcToPoint(Offset(frame.right, frame.top + r), radius: radius)
      ..lineTo(frame.right, frame.top + r + arm)
      ..moveTo(frame.right, frame.bottom - r - arm)
      ..lineTo(frame.right, frame.bottom - r)
      ..arcToPoint(Offset(frame.right - r, frame.bottom), radius: radius)
      ..lineTo(frame.right - r - arm, frame.bottom)
      ..moveTo(frame.left + r + arm, frame.bottom)
      ..lineTo(frame.left + r, frame.bottom)
      ..arcToPoint(Offset(frame.left, frame.bottom - r), radius: radius)
      ..lineTo(frame.left, frame.bottom - r - arm);

    canvas.drawPath(
      path,
      Paint()
        ..color = bracket
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.bracket != bracket ||
      oldDelegate.scrim != scrim;
}
