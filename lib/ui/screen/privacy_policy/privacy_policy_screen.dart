import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_colors.dart';
import 'package:flutter_app/ui/components/adaptive_button.dart';
import 'package:flutter_app/ui/components/page/base_page.dart';
import 'package:flutter_app/ui/screen/privacy_policy/privacy_policy_controller.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';

class PrivacyPolicyScreen extends GetView<PrivacyPolicyController> {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(PrivacyPolicyController());

    return Obx(() {
      return BasePage(
          title: R.current.PrivacyPolicy,
          isError: controller.isError.value,
          errorMsg: controller.errorMsg.value,
          isLoading: controller.isLoading.value,
          child: Column(
            children: [
              Expanded(
                child: contentBody(),
              ),
              const SizedBox(
                height: 15,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: agreeButton(),
              ),
              const SizedBox(
                height: 15,
              ),
            ],
          ));
    });
  }

  Widget contentBody() {
    return Markdown(
        selectable: true,
        data: controller.content.value,
        styleSheet: MarkdownStyleSheet.fromTheme(Get.theme.copyWith(
            textTheme: Get.textTheme.copyWith(
                bodyMedium: Get.textTheme.bodyMedium?.copyWith(height: 1.2)))));
  }

  Widget agreeButton() {
    return AdaptiveButton(
      onPressed: controller.onAgreePrivacyPolicy,
      borderRadius: BorderRadius.circular(999.0),
      backgroundColor: AppColors.mainColor,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        R.current.agree,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white
        ),
      ),
    );
  }
}
