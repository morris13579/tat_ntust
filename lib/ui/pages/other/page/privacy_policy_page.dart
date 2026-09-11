import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/empty_state.dart';
import 'package:flutter_app/ui/components/tat_progress.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/pages/other/page/privacy_policy_view.dart';
import 'package:flutter_app/ui/screen/privacy_policy/privacy_policy_controller.dart';

/// 隱私權條款的唯讀入口（「關於」與登入頁的同意那一行都走這裡）。
///
/// 取內文走 [PrivacyPolicyController.fetchPolicy]，跟同意閘門共用同一份離線
/// 備援；否則第一次開 App 沒網路的人會在這裡看到一個沒有字的驚嘆號。
class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  /// 存成欄位而不是寫在 build 裡：FutureBuilder 每次重建都會重新發一次請求。
  late Future<String> _policy;

  @override
  void initState() {
    super.initState();
    _policy = PrivacyPolicyController.fetchPolicy();
  }

  void _retry() {
    setState(() => _policy = PrivacyPolicyController.fetchPolicy());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(title: R.current.PrivacyPolicy),
      body: FutureBuilder<String>(
        future: _policy,
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.hasData) {
            return PrivacyPolicyView(policy: snapshot.data!);
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmptyState(
                    icon: LucideIcons.circleAlert,
                    message: R.current.pleaseConnectToNetwork,
                  ),
                  TextButton(onPressed: _retry, child: Text(R.current.restart)),
                ],
              ),
            );
          }
          return const Center(child: TatProgress());
        },
      ),
    );
  }
}
