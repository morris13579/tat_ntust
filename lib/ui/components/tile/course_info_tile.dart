import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

class CourseInfoTile extends StatelessWidget {
  const CourseInfoTile(
      {super.key,
      required this.index,
      required this.title,
      required this.icon,
      this.isShowArrow = false,
      required this.onTap});

  final int index;
  final String title;
  final IconData icon;
  final bool isShowArrow;
  final Function() onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return InkWell(
        onTap: onTap,
        child: Container(
          color: UIUtils.getListColor(index),
          height: TatTokens.heightRow,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(icon, size: 24, color: scheme.onSurfaceVariant),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (isShowArrow)
                Icon(LucideIcons.chevronRight,
                    size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8)
            ],
          ),
        ));
  }
}
