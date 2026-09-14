import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/score/score_json.dart';

class ScoreUtils {
  ScoreUtils._();

  static final Map<String, double> gradeToGP = {
    "A+": 4.3,
    "A": 4.0,
    "A-": 3.7,
    "B+": 3.3,
    "B": 3.0,
    "B-": 2.7,
    "C+": 2.3,
    "C": 2.0,
    "C-": 1.7,
    "D": 1.0,
    "E": 0.0,
    "X": 0.0,
  };

  /// 抵免課的學分寫成 "(3)"。GPA 的分母與畫面上的學分總和一定要走同一個
  /// 解析，否則抵免課只會算進其中一邊。
  static int parseCredit(String credit) =>
      int.tryParse(credit.replaceAll("(", "").replaceAll(")", "")) ?? 0;

  static String calculateGPA(List<ScoreItemJson> courseList) {
    final totalCredit = courseList
        .where((e) => e.isValidScore)
        .map((c) => parseCredit(c.credit))
        .fold(0, (a, b) => a + b);

    final totalScore = courseList.map((c) {
      return parseCredit(c.credit) * (gradeToGP[c.score] ?? 0);
    }).fold(0, (num a, num b) => a + b);

    return (totalScore / totalCredit).toStringAsFixed(2);
  }

  /// 及格課程的學分總和。
  static int passedCredit(List<ScoreItemJson> courseList) => courseList
      .where((c) => c.isPassScore)
      .map((c) => parseCredit(c.credit))
      .fold(0, (a, b) => a + b);

  /// 不及格門數。
  static int failedCount(List<ScoreItemJson> courseList) =>
      courseList.where((c) => c.isFailScore).length;

  /// 學期新到舊，每學期裡的課照等第高到低。
  static void sortForDisplay(List<SemesterScoreJson> semesters) {
    semesters.sort((a, b) {
      final year = (int.tryParse(b.semester.year) ?? 0)
          .compareTo(int.tryParse(a.semester.year) ?? 0);
      if (year != 0) return year;
      return (int.tryParse(b.semester.semester) ?? 0)
          .compareTo(int.tryParse(a.semester.semester) ?? 0);
    });
    for (final semester in semesters) {
      semester.item.sort((a, b) =>
          gradeToGP[b.score]?.compareTo(gradeToGP[a.score] ?? 0) ?? 0);
    }
  }

  /// 學校把及格與否寫成中文字串，英文語系照搬會夾一段中文。
  static const _passLiterals = {'通過', 'Pass'};

  /// 分數欄要顯示的字。沒有等第時退回備註（抵免、停修…），兩者皆無就是還沒
  /// 評分——設計稿要的是字，不是一個看不出意思的「-」。
  static String scoreLabel(ScoreItemJson score) {
    final grade = score.score.trim();
    final text = (grade.isEmpty || grade == '-') ? score.remark.trim() : grade;
    if (text.isEmpty) return R.current.assignNotGraded;
    if (_passLiterals.contains(text)) return R.current.scorePassed;
    return text;
  }
}
