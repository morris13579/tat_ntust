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

  static String calculateGPA(List<ScoreItemJson> courseList) {
    final totalCredit = courseList
        .where((e) => e.isValidScore)
        .map((c) =>
            int.tryParse(c.credit.replaceAll("(", "").replaceAll(")", "")) ?? 0)
        .reduce((a, b) => a + b);

    final totalScore = courseList.map((c) {
      return (int.tryParse(c.credit.replaceAll("(", "").replaceAll(")", "")) ??
              0) *
          (gradeToGP[c.score] ?? 0);
    }).reduce((a, b) => a + b);

    return (totalScore / totalCredit).toStringAsFixed(2);
  }
}
