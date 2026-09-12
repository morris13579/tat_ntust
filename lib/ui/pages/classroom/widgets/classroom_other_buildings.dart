import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/model/classroom/classroom_option.dart';
import 'package:flutter_app/src/model/classroom/classroom_usage_json.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

/// 其他大樓。
///
/// **一次只查得到一棟，就把它講出來。** 每一棟各自顯示自己的抓取時間，
/// 不假裝這是一份即時的全校資料。
class ClassroomOtherBuildings extends StatelessWidget {
  const ClassroomOtherBuildings({
    super.key,
    required this.buildings,
    required this.usage,
    required this.loading,
    required this.onSelect,
  });

  /// 目前這一棟以外的大樓。
  final List<ClassroomOptionJson> buildings;

  /// 已經抓過的結果，大樓代號當鍵。
  final Map<String, Result<ClassroomUsageJson>> usage;

  /// 正在抓的大樓代號。
  final Set<String> loading;

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (buildings.isEmpty) return const SizedBox.shrink();
    final scheme = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 段標題走全 App 同一顆元件，字級與左右內縮才和其他頁對得上。
        SectionHeader(title: R.current.classroomOtherBuildings),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
          child: Text(
            R.current.classroomOtherBuildingsHint,
            style: context.text.bodySmall
                ?.copyWith(height: 1.35, color: scheme.onSurfaceVariant),
          ),
        ),
        // 全 App 的清單都是這個形狀：每一列是自己的圓角塊、頭尾收大圓角、
        // 中間留 2px 的縫，不用分隔線。
        for (var i = 0; i < buildings.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          _row(context, buildings[i], i, buildings.length),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, ClassroomOptionJson building, int index,
      int length) {
    final scheme = context.scheme;
    final isLoading = loading.contains(building.code);
    final fetched = usage[building.code]?.dataOrNull?.fetchedAt;
    return Material(
      color: context.tokens.card,
      borderRadius: UIUtils.getBorderRadius(index, length),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isLoading ? null : () => onSelect(building.code),
        child: Container(
          constraints: const BoxConstraints(minHeight: TatTokens.heightRow),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(building.name,
                    style: context.text.bodyMedium?.copyWith(height: 1.35)),
              ),
              if (isLoading)
                Text(R.current.classroomFetching,
                    style: context.text.labelMedium
                        ?.copyWith(height: 1.3, color: scheme.primary))
              else ...[
                if (fetched != null)
                  Text(
                    sprintf(R.current.classroomLastFetched,
                        [_hhmm(fetched)]),
                    style: context.text.labelMedium?.copyWith(
                        height: 1.3, color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronRight,
                    size: 18, color: scheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `DateTime` → `HH:mm`。整個空教室頁只講「今天幾點抓的」，不需要日期：
/// 換了日期就會重抓，畫面上的時間一定屬於當下那一次查詢。
String _hhmm(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// 給頁面其他地方共用的同一份格式。
String classroomClock(DateTime time) => _hhmm(time);
