import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/score/score_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

enum ScoreUIState { loading, success, fail, notLogin }

class ScorePageController extends GetxController
    with GetTickerProviderStateMixin {
  var state = ScoreUIState.loading.obs;
  var semesterScoreList = <SemesterScoreJson>[].obs;
  var currentTabIndex = 0.obs;
  var tabLabelList = <Widget>[];
  var tabChildList = <Widget>[];
  late TabController tabController;

  @override
  void onInit() {
    super.onInit();
    initTask();
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  void initTask({refresh = false}) async {
    if (Model.instance.getAccount().isEmpty) {
      state(ScoreUIState.notLogin);
      return;
    }
    state(ScoreUIState.loading);
    await Model.instance.loadScore();
    semesterScoreList = Model.instance.getScore().info.obs;
    if (semesterScoreList.isEmpty || refresh) {
      TaskFlow taskFlow = TaskFlow();
      var scoreTask = ScoreTask();
      taskFlow.addTask(scoreTask);
      if (await taskFlow.start()) {
        semesterScoreList = scoreTask.result.info.obs;
        Model.instance.setScore(scoreTask.result);
        await Model.instance.saveScore();
      } else {
        state(ScoreUIState.fail);
        return;
      }
    }
    tabLabelList.clear();
    tabChildList.clear();

    semesterScoreList.sort((a, b) {
      final yearA = int.tryParse(a.semester.year) ?? 0;
      final yearB = int.tryParse(b.semester.year) ?? 0;
      final semesterA = int.tryParse(a.semester.semester) ?? 0;
      final semesterB = int.tryParse(b.semester.semester) ?? 0;

      int yearCompare = yearB.compareTo(yearA);
      if (yearCompare != 0) {
        return yearCompare;
      } else {
        return semesterB.compareTo(semesterA);
      }
    });

    for (int i = 0; i < semesterScoreList.length; i++) {
      var semester = semesterScoreList[i].semester;
      tabLabelList.add(_buildTabLabel("${semester.year}-${semester.semester}"));
      tabChildList.add(_buildSemesterScores(semesterScoreList[i].item));
    }
    tabController = TabController(vsync: this, length: tabLabelList.length);

    state(ScoreUIState.success);
  }

  void toIndex(int index) {
    currentTabIndex(index);
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

  Widget _buildSemesterScores(List<ScoreItemJson> courseScore) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: AnimationLimiter(
        child: Column(
          children: AnimationConfiguration.toStaggeredList(
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: <Widget>[
              ..._buildCourseScores(courseScore),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCourseScores(List<ScoreItemJson> courseScore) {
    return [
      _buildTitle(R.current.resultsOfVariousSubjects),
      for (var score in courseScore) _buildScoreItem(score),
    ];
  }

  Widget _buildScoreItem(ScoreItemJson score) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 25,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: AutoSizeText(
                  score.name,
                  style: const TextStyle(fontSize: 16.0),
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                child: Text(
                  score.score,
                  style: const TextStyle(fontSize: 16.0),
                  textAlign: TextAlign.end,
                ),
                onTap: () {
                  MyToast.show(score.score);
                },
              ),
            ],
          ),
        ),
        const SizedBox(
          height: 8.0,
        ),
      ],
    );
  }

  Widget _buildTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
