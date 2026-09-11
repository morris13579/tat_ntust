import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';

typedef OnCallBack = Function(String);

/// 只有 dev 模式的 store_edit_page 在用。
class CustomInputDialog extends StatefulWidget {
  const CustomInputDialog({
    super.key,
    required this.title,
    required this.initText,
    required this.onOk,
    required this.onCancel,
    this.maxLine = 1,
    this.hint = "",
  });

  final String title;
  final String initText;
  final OnCallBack onOk;
  final OnCallBack onCancel;
  final int maxLine;
  final String hint;

  @override
  State<CustomInputDialog> createState() => _CustomInputDialogState();
}

class _CustomInputDialogState extends State<CustomInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return TatDialog(
      title: widget.title,
      body: null,
      kind: TatDialogKind.info,
      content: TextField(
        controller: _controller,
        cursorColor: scheme.primary,
        maxLines: widget.maxLine,
        style: context.text.bodyLarge,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      secondary: TatDialogAction(
        label: R.current.cancel,
        onPressed: () {
          final value = _controller.text;
          Get.back();
          widget.onCancel(value);
        },
      ),
      primary: TatDialogAction(
        label: R.current.sure,
        onPressed: () {
          final value = _controller.text;
          Get.back();
          widget.onOk(value);
        },
      ),
    );
  }
}
