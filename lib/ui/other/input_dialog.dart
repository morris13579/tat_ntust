import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:get/get.dart';

typedef OnCallBack = Function(String);

class CustomInputDialog extends StatelessWidget {
  final title;
  final initText;
  final TextEditingController controller = TextEditingController();
  final OnCallBack onOk;
  final OnCallBack onCancel;
  final maxLine;
  final hint;

  CustomInputDialog({
    required this.title,
    required this.initText,
    required this.onOk,
    required this.onCancel,
    this.maxLine = 1,
    this.hint = "",
  }) {
    controller.text = initText;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        cursorColor: Colors.blue[800],
        decoration: InputDecoration(
          hintText: hint,
        ),
        maxLines: maxLine,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.back();
            onCancel(controller.text);
          },
          child: Text(R.current.cancel),
        ),
        TextButton(
          onPressed: () async {
            Get.back();
            onOk(controller.text);
          },
          child: Text(R.current.sure),
        )
      ],
    );
  }
}
