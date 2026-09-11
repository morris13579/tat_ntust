import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/components/adaptive_button.dart';
import 'package:flutter_app/ui/components/page/base_page.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/other/page/privacy_policy_view.dart';
import 'package:flutter_app/ui/screen/privacy_policy/privacy_policy_controller.dart';
import 'package:get/get.dart';

/// 首次啟動的同意閘門，也是 `Model.setAgreeContributor(true)` 唯一的寫入點。
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final PrivacyPolicyController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(PrivacyPolicyController());
  }

  @override
  void dispose() {
    Get.delete<PrivacyPolicyController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return PopScope(
        canPop: false,
        child: BasePage(
            title: R.current.PrivacyPolicy,
            isError: controller.isError.value,
            errorMsg: controller.errorMsg.value,
            isLoading: controller.isLoading.value,
            child: Column(
              children: [
                Expanded(
                    child: PrivacyPolicyView(policy: controller.content.value)),
                // 同意鈕一直可按：不做倒數、也不要求捲到底。強迫閱讀不會讓人
                // 真的讀，只會讓人更快按掉。
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: _agreeButton(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                  child: Text(
                    R.current.privacyAgreeRequired,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                ),
              ],
            )),
      );
    });
  }

  Widget _agreeButton(BuildContext context) {
    return SizedBox(
      height: TatTokens.heightButton,
      child: AdaptiveButton(
        onPressed: controller.onAgreePrivacyPolicy,
        borderRadius: BorderRadius.circular(TatTokens.radiusButton),
        backgroundColor: context.scheme.primary,
        width: double.infinity,
        child: Text(
          R.current.privacyAgreeContinue,
          style: context.text.titleSmall
              ?.copyWith(color: context.scheme.onPrimary),
        ),
      ),
    );
  }
}
