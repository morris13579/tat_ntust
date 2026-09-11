import 'package:flutter/material.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/score_utils.dart';
import 'package:get/get.dart';

enum ScoreUIState { loading, success, fail, notLogin }

class ScorePageController extends GetxController
    with GetTickerProviderStateMixin {
  var state = ScoreUIState.loading.obs;
  var semesterScoreList = <SemesterScoreJson>[].obs;
  var currentTabIndex = 0.obs;

  /// 只在 initTask 成功走到最後才會有值，所以是可空而不是 late：initTask 有
  /// 兩條 early return，late 的 LateInitializationError 會從 GetX 那個沒有
  /// try/catch 的 _removeDependencyByRoute 迴圈中間拋出，同一條 route 上排在
  /// 後面的 controller 全部收不到 onDelete。
  TabController? tabController;

  @override
  Future<void> onInit() async {
    super.onInit();
    await initTask();
  }

  @override
  void onClose() {
    tabController?.dispose();
    super.onClose();
  }

  /// 登出時重設畫面狀態。由 SessionCleaner 的呼叫端觸發。
  void reset() {
    semesterScoreList.clear();
    currentTabIndex.value = 0;
    tabController?.dispose();
    tabController = null;
    state(ScoreUIState.notLogin);
  }

  Future<void> initTask({refresh = false}) async {
    if (!AuthSession.instance.isSignedIn) {
      state(ScoreUIState.notLogin);
      return;
    }
    state(ScoreUIState.loading);
    await Model.instance.loadScore();
    semesterScoreList = Model.instance.getScore().info.obs;
    if (semesterScoreList.isEmpty || refresh) {
      final result = await NtustRepository.instance.getScoreRank();
      // getScoreRank 不帶快取（成績的持久化由 store 的 ScoreStore 負責，
      // 兩份會漂移），所以這裡只有 Ok 與 Failed 兩種。
      final data = result.dataOrNull;
      if (data == null) {
        state(ScoreUIState.fail);
        return;
      }
      semesterScoreList = data.info.obs;
      Model.instance.setScore(data);
      await Model.instance.saveScore();
    }

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

    // 排序在這裡做（資料的事），畫面由 ScoreViewerPage 依這份清單產生。
    for (final semesterScore in semesterScoreList) {
      semesterScore.item.sort((a, b) {
        return ScoreUtils.gradeToGP[b.score]
                ?.compareTo(ScoreUtils.gradeToGP[a.score] ?? 0) ??
            0;
      });
    }
    // 每次 refresh 都會建一顆新的，舊的要先釋放，否則每按一次重新整理就漏一顆。
    tabController?.dispose();
    tabController =
        TabController(vsync: this, length: semesterScoreList.length);

    state(ScoreUIState.success);
  }

  void toIndex(int index) {
    currentTabIndex(index);
  }
}
