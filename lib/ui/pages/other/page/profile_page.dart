import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/note_icon.dart';
import 'package:flutter_app/ui/components/shimmer/profile_loading.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/other/components/user_profile.dart';
import 'package:get/get.dart';

/// 個人資訊（畫面 3h）。
///
/// 刻意不長得像一張表單：除了頭貼，其他都是學校端的資料，所以沒有輸入框、
/// 沒有右側箭頭、也沒有「儲存」。學籍與校內信箱那兩段還沒有連接器可以餵，
/// 所以這一版不畫——鎖住的空欄位比沒有這一段更難解釋。
///
/// 導頁由呼叫端注入，這一頁不 import 路由表（見 docs/ARCHITECTURE.md「UI 慣例」）。
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.onChangeAvatar,
    required this.onOpenStudentRecord,
  });

  final Future<void> Function() onChangeAvatar;
  final VoidCallback onOpenStudentRecord;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MainController>();
    final scheme = context.scheme;
    final noteStyle = context.text.bodyMedium
        ?.copyWith(color: scheme.onSurfaceVariant, height: 1.7);

    return Scaffold(
      appBar: baseAppbar(title: R.current.person_info),
      body: Obx(() {
        final profile = controller.profile.value;
        if (profile == null) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: ProfileLoading(),
          );
        }

        final busy = controller.avatarProgress.value != null;
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // 頭像那一段是自己一塊 surface，不是浮在底色上的散件。
            Container(
              width: double.infinity,
              // 要比頁面底色高一階，否則暗色模式下 surface 和背景同色，
              // 這一塊就看不出是獨立的區塊。
              color: context.tokens.card,
              padding: const EdgeInsets.fromLTRB(16, 26, 16, 24),
              child: Column(
                children: [
                  UserProfile(
                    data: profile,
                    stacked: true,
                    radius: 48,
                    // 角標外圈要和它站著的那一塊同色，縫才看得出來。
                    badgeBorderColor: context.tokens.card,
                    progress: controller.avatarProgress.value,
                    onAvatarTap: () => unawaited(onChangeAvatar()),
                  ),
                  const SizedBox(height: 14),
                  // 頭貼是唯一可改的東西，所以給它兩個入口：角標與這顆按鈕，
                  // 兩者開同一個選單。
                  OutlinedButton(
                    onPressed: busy ? null : () => unawaited(onChangeAvatar()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.primary,
                      side: BorderSide(
                          color: scheme.primary.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                    ),
                    child: Text(R.current.avatarChange),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 校內信箱是從學號推出來的，不需要另一支 API。
            _LabelValueSection(
              title: R.current.contactInfo,
              label: R.current.campusEmail,
              value: '${Model.instance.getAccount()}@mail.ntust.edu.tw',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: context.tokens.card,
                  borderRadius: BorderRadius.circular(TatTokens.radiusCard),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NoteIcon(LucideIcons.info,
                        style: noteStyle,
                        size: 18,
                        color: scheme.onSurfaceVariant),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(R.current.profileReadOnlyNote, style: noteStyle),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: onOpenStudentRecord,
                            borderRadius:
                                BorderRadius.circular(TatTokens.radiusButton),
                            child: Text(
                              R.current.goToStudentRecord,
                              style: context.text.bodyMedium?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// 一段唯讀資料：標題在卡外，卡內是 label / value 兩欄。
class _LabelValueSection extends StatelessWidget {
  const _LabelValueSection({
    required this.title,
    required this.label,
    required this.value,
  });

  final String title;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 11),
            child: Text(title,
                style: context.text.titleSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.tokens.card,
              borderRadius: BorderRadius.circular(TatTokens.radiusCard),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(label,
                      style: context.text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant, height: 1.5)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(value,
                      style: context.text.bodyLarge
                          ?.copyWith(height: 1.5, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
