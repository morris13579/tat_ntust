import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InputField extends StatelessWidget {
  const InputField(
      {Key? key,
      required this.hint,
      this.controller,
      this.inputType,
      this.textAlign = TextAlign.start,
      this.maxLength,
      this.isError = false,
      this.errorMsg = "",
      this.onChange,
      this.readOnly = false,
      this.label, this.onTap, this.maxLines})
      : super(key: key);

  final String hint;
  final String? label;
  final TextEditingController? controller;
  final TextInputType? inputType;
  final TextAlign textAlign;
  final int? maxLength;
  final bool isError;
  final String errorMsg;
  final int? maxLines;
  final bool readOnly;
  final Function(String)? onChange;
  final Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Visibility(
            visible: label != null,
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 4),
              child: Text("${label?.tr}"),
            )),
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
              border: Border.all(
                  color: isError ? Colors.redAccent : Get.theme.primaryColor,
                  width: 1.2),
              borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: controller,
            obscureText: inputType == TextInputType.visiblePassword,
            keyboardType: inputType,
            textAlign: textAlign,
            maxLength: maxLength,
            readOnly: readOnly,
            onChanged: onChange,
            onTap: onTap,
            maxLines: inputType == TextInputType.visiblePassword ? 1 : maxLines,
            style: const TextStyle(height: 1),
            cursorHeight: 20,
            cursorRadius: const Radius.circular(999),
            decoration: InputDecoration(
                hintText: hint.tr,
                hintStyle: TextStyle(
                    color: isError
                        ? Colors.redAccent.withOpacity(0.4)
                        : Get.theme.primaryColor.withOpacity(0.4)),
                contentPadding: const EdgeInsets.only(
                    left: 12, right: 12, top: 12, bottom: 12),
                border: InputBorder.none),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: AnimatedSize(
              duration: const Duration(milliseconds: 140),
              child: Visibility(
                  visible: isError && errorMsg.isNotEmpty,
                  child: Text(
                    errorMsg,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 14),
                  ))),
        )
      ],
    );
  }
}
