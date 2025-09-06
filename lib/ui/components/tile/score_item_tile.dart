import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:get/get.dart';

class ScoreItemTile extends StatelessWidget {
  const ScoreItemTile({super.key, required this.score});

  final ScoreItemJson score;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Get.theme.colorScheme.surfaceContainer),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16.0,
                      color: Get.theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                _buildCourseDescription()
              ],
            ),
          ),
          const SizedBox(width: 24),
          GestureDetector(
            child: _buildScore(),
            onTap: () {
              MyToast.show(score.score);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildCourseDescription() {
    return Row(
      children: [
        Text(
          score.courseId,
          style: TextStyle(color: Get.theme.colorScheme.onSurfaceVariant),
        ),
        Visibility(
            visible: score.generalDimension.isNotEmpty,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Get.theme.colorScheme.onSurfaceVariant),
                  width: 1.5,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                ),
                Text(
                  "${R.current.general_dimension} ${score.generalDimension}",
                  style:
                      TextStyle(color: Get.theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ))
      ],
    );
  }

  Widget _buildScore() {
    final color = score.isPassScore
        ? Get.theme.colorScheme.onSurface
        : Get.theme.colorScheme.error;

    return Text(
      score.score,
      style:
          TextStyle(fontSize: 16.0, color: color, fontWeight: FontWeight.bold),
      textAlign: TextAlign.end,
    );
  }
}
