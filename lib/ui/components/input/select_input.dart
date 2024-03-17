import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/entity/option_entity.dart';
import 'package:get/get.dart';

class SelectInput extends StatelessWidget {
  const SelectInput(
      {super.key,
      this.isError = false,
      this.errorMsg = "",
      this.readOnly = false,
      this.label,
      required this.onChange,
      required this.options,
      required this.value, this.iconColor});

  final List<OptionEntity> options;
  final String value;
  final String? label;
  final bool isError;
  final String errorMsg;
  final bool readOnly;
  final Color? iconColor;
  final Function(String?) onChange;

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
          width: double.infinity,
          decoration: BoxDecoration(
              border: Border.all(
                  color: isError ? Colors.redAccent : Get.theme.primaryColor,
                  width: 1.2),
              borderRadius: BorderRadius.circular(8)),
          child: DropdownButton(
            style: const TextStyle(height: 1),
            isExpanded: true,
            underline: const SizedBox(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            icon: Icon(CupertinoIcons.chevron_down, color: iconColor,),
            iconSize: 16,
            value: value,
            items: options
                .map((e) => DropdownMenuItem(
                      value: e.value,
                      child: Text(e.label, style: Get.textTheme.titleMedium,),
                    ))
                .toList(),
            onChanged: readOnly? null : onChange,
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
