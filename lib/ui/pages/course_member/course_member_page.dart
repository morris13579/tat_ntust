import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/controller/course_member/course_member_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/input/input_field.dart';
import 'package:flutter_app/ui/components/page/notice_bar.dart';
import 'package:flutter_app/ui/components/shimmer/list_skeleton.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';
import 'package:sprintf/sprintf.dart';

/// 修課學生名單。
///
/// Moodle 的名單 API 很慢，所以它獨占一個畫面：等待可以用滿版骨架表達，失敗
/// 有地方放重試，搜尋也放得下。人數由上一頁帶過來，標題列因此一開始就是完整
/// 的，不必等 API。
class CourseMemberPage extends StatefulWidget {
  const CourseMemberPage({
    required this.controller,
    required this.courseName,
    required this.knownMemberCount,
    required this.errorBuilder,
    super.key,
  });

  /// 由課程頁持有，返回再進來不重查。
  final CourseMemberController controller;

  final String courseName;

  /// 上一頁那支主要 API 就給了的人數，骨架的列數也用它決定。
  final int knownMemberCount;

  /// 失敗時要畫什麼。由呼叫端注入而不是直接用 `ErrorPage`，
  /// 見 docs/ARCHITECTURE.md「UI 慣例」。
  final Widget Function(String message, Future<void> Function() onRetry)
      errorBuilder;

  @override
  State<CourseMemberPage> createState() => _CourseMemberPageState();
}

class _CourseMemberPageState extends State<CourseMemberPage> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 請求發在這裡而不是 build()：每一次 rebuild 都重打一次 API 是個災難。
    unawaited(widget.controller.load());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _retry() => widget.controller.load(force: true);

  /// 骨架列數貼著真實筆數，載完版面才不會整個跳掉；人數不明時給三列。
  int get _skeletonRows =>
      widget.knownMemberCount > 0 ? math.min(widget.knownMemberCount, 5) : 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(title: R.current.enrolledStudents),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Expanded(
              child: Obx(() => _buildBody(widget.controller.members.value))),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final subtitle = [
      widget.courseName.trim(),
      if (widget.knownMemberCount > 0)
        sprintf(R.current.peopleCount, [widget.knownMemberCount]),
    ].where((text) => text.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                subtitle,
                style: context.text.bodyMedium
                    ?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
            ),
          InputField(
            hint: R.current.searchStudent,
            controller: _query,
            // 搜尋框不該叫出帳號密碼的自動填入。
            autofillHints: const [],
            onChange: (_) => setState(() {}),
            // 放大鏡在前面，和資訊系統的搜尋欄同一個形狀。
            prefix: const Icon(LucideIcons.search, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Result<List<MoodleCoreEnrolGetUsers>>? result) {
    if (result == null) {
      // 骨架而不是轉圈圈：沒有遮罩，畫面也不會整片空白。
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListSkeleton(rows: _skeletonRows),
      );
    }
    if (result is Failed<List<MoodleCoreEnrolGetUsers>>) {
      return widget.errorBuilder(result.reason.message, _retry);
    }

    final members = widget.controller.filter(_query.text);
    return Column(
      children: [
        if (result is Stale<List<MoodleCoreEnrolGetUsers>>)
          NoticeBar(
            message: result.reason.message,
            icon: LucideIcons.history,
            actionLabel: R.current.refresh,
            onAction: _retry,
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: members.length,
            itemBuilder: (context, index) => _MemberRow(member: members[index]),
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatefulWidget {
  const _MemberRow({required this.member});

  final MoodleCoreEnrolGetUsers member;

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  /// 圖抓不到就退回姓名首字。Moodle 給的網址在沒有 session 或使用者沒設頭貼
  /// 時會 404 或回一張預設圖。
  bool _imageFailed = false;

  void _onImageError() {
    // 錯誤是在繪製途中回報的，直接 setState 會撞到「build 期間呼叫 setState」。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _imageFailed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final scheme = context.scheme;
    final name = member.name.toString();
    final studentId = member.studentId.toString();
    final url = member.profileImageUrlSmall.trim();
    final showPlaceholder = url.isEmpty || _imageFailed;
    return Container(
      constraints: const BoxConstraints(minHeight: TatTokens.heightRow),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.surfaceContainerHighest,
            backgroundImage: showPlaceholder ? null : NetworkImage(url),
            // 少了 onBackgroundImageError，404 會把例外丟進 FlutterError.onError。
            onBackgroundImageError:
                showPlaceholder ? null : (_, __) => _onImageError(),
            child: showPlaceholder
                ? Text(
                    name.isEmpty ? '?' : name.characters.first,
                    style: context.text.titleSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: context.text.bodyLarge),
                if (studentId.isNotEmpty)
                  Text(
                    studentId,
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
