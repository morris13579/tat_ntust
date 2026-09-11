import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_app/src/util/score_utils.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/controller/score_page/score_page_controller.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/components/tat_tab_bar.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/score/widget/score_row.dart';
import 'package:flutter_app/ui/pages/score/widget/score_summary_strip.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:get/get.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:sprintf/sprintf.dart';

class ScoreViewerPage extends GetView<ScorePageController> {
  const ScoreViewerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        switch (controller.state.value) {
          case ScoreUIState.success:
            return _buildContentPage(context);
          case ScoreUIState.loading:
            return _buildLoadingPage();
          case ScoreUIState.fail:
            return _buildErrorPage();
          case ScoreUIState.notLogin:
            return _buildNotLoginPage();
        }
      },
    );
  }

  List<Widget> _appbarActions({bool refresh = false}) => [
        if (refresh)
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            splashRadius: 18,
            onPressed: () async {
              await controller.initTask(refresh: true);
            },
            tooltip: R.current.update,
          ),
      ];

  Widget _buildContentPage(BuildContext context) {
    return Obx(() {
      return DefaultTabController(
        length: controller.semesterScoreList.length,
        child: Scaffold(
          appBar: mainAppbar(
              title: R.current.searchScore,
              action: _appbarActions(refresh: true),
              bottom: TatTabBar(
                controller: controller.tabController,
                // controller 為 null 時 TabBar 會回退到 DefaultTabController，
                // 不會拋 LateInitializationError。
                isScrollable: true,
                // Widget 由頁面依 semesterScoreList 現算：controller 建 Widget
                // 會讓 lib/src/controller 反向 import lib/ui，形成 controller -> ui
                // 的上行邊。
                tabs: [
                  for (final s in controller.semesterScoreList)
                    _buildTabLabel("${s.semester.year}-${s.semester.semester}")
                ],
                onTap: controller.toIndex,
              )),
          body: TabBarView(
            controller: controller.tabController,
            children: [
              for (final (index, s) in controller.semesterScoreList.indexed)
                _buildSemesterScores(context, s.item,
                    isCurrentSemester: index == 0)
            ],
          ),
        ),
      );
    });
  }

  Widget _buildErrorPage() {
    return Scaffold(
      appBar: mainAppbar(
          title: R.current.searchScore, action: _appbarActions(refresh: true)),
      body: const ErrorPage(),
    );
  }

  Widget _buildLoadingPage() {
    return Scaffold(
      appBar:
          mainAppbar(title: R.current.searchScore, action: _appbarActions()),
      // 這裡要真的畫出載入畫面：沒有任何全螢幕進度框會蓋在上面，空白就是
      // 使用者看到的全部。
      body: const LoadingPage(isLoading: true, isShowBackground: false),
    );
  }

  Widget _buildNotLoginPage() {
    return Scaffold(
      appBar:
          mainAppbar(title: R.current.searchScore, action: _appbarActions()),
      body: const ErrorPage(),
    );
  }

  Widget _buildTabLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 12,
        right: 12,
      ),
      child: Tab(
        text: title,
      ),
    );
  }

  Widget _buildSemesterScores(
      BuildContext context, List<ScoreItemJson> courseScore,
      {required bool isCurrentSemester}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: AnimationLimiter(
        child: Column(
          children: AnimationConfiguration.toStaggeredList(
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: _buildCourseScores(context, courseScore,
                isCurrentSemester: isCurrentSemester),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCourseScores(
      BuildContext context, List<ScoreItemJson> courseScore,
      {required bool isCurrentSemester}) {
    final gpa = ScoreUtils.calculateGPA(courseScore);
    return [
      ScoreSummaryStrip(
        // calculateGPA 一門有效成績都沒有時會回字面上的 "NaN"，那是它被凍結
        // 的契約（見 score_utils_test），所以在畫面這一層擋掉。
        gpa: gpa == 'NaN' ? null : gpa,
        credit: ScoreUtils.passedCredit(courseScore),
        failed: ScoreUtils.failedCount(courseScore),
      ),
      _buildCourseCount(context, courseScore.length),
      for (var i = 0; i < courseScore.length; i++) ...[
        if (i > 0) const SizedBox(height: 2),
        ScoreRow(
          score: courseScore[i],
          index: i,
          length: courseScore.length,
          onTap: RouteUtils.toMoodleCourseGrades,
        ),
      ],
      if (isCurrentSemester) ...[
        const SizedBox(height: 16),
        _buildMoodleEntry(context),
      ],
    ];
  }

  Widget _buildCourseCount(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          sprintf(R.current.courseCount, [count]),
          style: context.text.titleSmall
              ?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildMoodleEntry(BuildContext context) {
    final scheme = context.scheme;
    final borderRadius = BorderRadius.circular(TatTokens.radiusCard);
    return InkWell(
      borderRadius: borderRadius,
      onTap: RouteUtils.toMoodleCourseGrades,
      child: Container(
        decoration: BoxDecoration(
          color: context.tokens.card,
          borderRadius: borderRadius,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Row(
          children: [
            Icon(LucideIcons.chartColumn,
                size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    R.current.moodleCourseGrades,
                    style: context.text.titleSmall
                        ?.copyWith(color: scheme.onSurface),
                  ),
                  Text(
                    R.current.moodleCourseGradesSubtitle,
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight,
                size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
