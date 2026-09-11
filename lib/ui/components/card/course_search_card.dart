import 'package:flutter/cupertino.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

import '../../../src/R.dart';

class CourseSearchCard extends StatelessWidget {
  const CourseSearchCard({super.key, required this.info, required this.onTap});

  final CourseMainInfoJson info;
  final Function(CourseMainInfoJson) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => onTap(info),
      child: DefaultTextStyle(
        style: text.bodyMedium!.copyWith(color: scheme.onSurface),
        child: Container(
          width: double.infinity,
          // 沒有描邊卡片：層級只靠底色高一階。
          decoration: BoxDecoration(
            color: context.tokens.card,
            borderRadius: BorderRadius.circular(TatTokens.radiusCard),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.course.name,
                style: text.titleMedium?.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                info.course.id,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              teacherText(context),
              const SizedBox(height: 2),
              timeText(context),
              const SizedBox(height: 2),
              Text(
                  "${R.current.startClass}: ${info.getOpenClassName().isEmpty ? "--" : info.getOpenClassName()}"),
              const SizedBox(height: 2),
              Text("${R.current.classroom}: ${info.getClassroomName()}"),
              const SizedBox(height: 2),
              Text("${R.current.note}: ${info.course.note}"),
            ],
          ),
        ),
      ),
    );
  }

  Widget timeText(BuildContext context) => _iconWithText(
      context, LucideIcons.clock, courseTimeString(info.course.time));

  Widget teacherText(BuildContext context) =>
      _iconWithText(context, LucideIcons.user, info.getTeacherName());

  Widget _iconWithText(BuildContext context, IconData icon, String content) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(content),
      ],
    );
  }
}
