import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/util/classroom_availability.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

/// 清單檢視的一列教室。
///
/// **主要資訊是「空到幾點」，不是課名。** 原本寫成「14:20 微積分（上）·
/// 呂政修 ／ 還有 3 節」會被讀成「這間正在上微積分」——課名沒有時態。所以
/// 右邊那一格直接給答案（空到 14:10），課名退到第二行而且前面加「下一堂」，
/// 把它推到未來。老師名字拿掉：找位子的人不需要。
class ClassroomRoomTile extends StatelessWidget {
  const ClassroomRoomTile({
    super.key,
    required this.vacancy,
    this.onTap,
    this.index,
    this.length,
  });

  final ClassroomVacancy vacancy;
  final VoidCallback? onTap;

  /// 在同一組裡的位置。給了就照群組收圓角——全 App 的清單都是這個形狀：
  /// 每一列是自己的圓角塊、頭尾收大圓角、中間留 2px 的縫，不用分隔線。
  final int? index;
  final int? length;

  /// 第二行：下一堂是什麼、或者今天就這樣了。
  static String subtitle(ClassroomVacancy vacancy) {
    if (vacancy.isFreeAllDay) return R.current.classroomNoClassToday;
    final at = vacancy.nextBusyAt;
    if (at == null) return R.current.classroomNoMoreClass;
    if (vacancy.nextIsBooking) {
      return sprintf(R.current.classroomBookedFrom, [at.start]);
    }
    final slot = vacancy.nextBusySlot;
    return sprintf(
        R.current.classroomNextClass, [at.start, slot?.course ?? '']).trim();
  }

  /// 右邊那一格：整天空著，或空到幾點。
  static String badge(ClassroomVacancy vacancy) {
    if (vacancy.isFreeAllDay) return R.current.classroomFreeAllDay;
    final until = vacancy.freeUntil;
    return until == null
        ? ''
        : sprintf(R.current.classroomFreeUntil, [until.end]);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final borderRadius = (index != null && length != null)
        ? UIUtils.getBorderRadius(index!, length!)
        : null;
    return Material(
      color: tokens.card,
      borderRadius:
          borderRadius ?? BorderRadius.circular(TatTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vacancy.room.name,
                      style: context.text.titleSmall?.copyWith(height: 1.3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle(vacancy),
                      style: context.text.bodySmall?.copyWith(
                        height: 1.35,
                        color: context.scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 空著就是好消息，所以用 success 而不是 primary：它是答案，
              // 不是一個可以點的東西。
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tokens.successContainer,
                  borderRadius: BorderRadius.circular(TatTokens.radiusButton),
                ),
                child: Text(
                  badge(vacancy),
                  style: context.text.labelMedium
                      ?.copyWith(color: tokens.success, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
