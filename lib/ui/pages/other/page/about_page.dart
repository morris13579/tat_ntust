import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/tile/settings_tile.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';

enum AboutMenuAction { contribution, privacyPolicy, dev }

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<StatefulWidget> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static bool inDevMode = false | kDebugMode;

  /// 一定要是 getter：欄位初始化式只在 State 建立時跑一次，會凍住標題的語言，
  /// 也凍住 [inDevMode] 那一列的出現與否。
  List<({IconData icon, String title, String? value, AboutMenuAction action})>
      get _rows => [
            (
              icon: LucideIcons.award,
              title: R.current.Contribution,
              value: null,
              action: AboutMenuAction.contribution
            ),
            (
              icon: LucideIcons.shieldCheck,
              title: R.current.PrivacyPolicy,
              value: null,
              action: AboutMenuAction.privacyPolicy
            ),
            if (inDevMode)
              (
                icon: LucideIcons.codeXml,
                title: R.current.developerMode,
                value: null,
                action: AboutMenuAction.dev
              ),
          ];

  void _onListViewPress(AboutMenuAction value) {
    switch (value) {
      case AboutMenuAction.contribution:
        unawaited(RouteUtils.toContributorsPage());
        break;
      case AboutMenuAction.privacyPolicy:
        unawaited(RouteUtils.toPrivacyPolicyPage());
        break;
      case AboutMenuAction.dev:
        unawaited(RouteUtils.toDevPage());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: baseAppbar(title: R.current.about),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            SettingsTile(
              icon: rows[i].icon,
              title: rows[i].title,
              trailingValue: rows[i].value,
              onTap: () => _onListViewPress(rows[i].action),
              index: i,
              length: rows.length,
            ),
          ],
        ],
      ),
    );
  }
}
