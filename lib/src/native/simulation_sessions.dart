import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';

/// 開著的模擬課表。搜尋頁加課時改的必須是同一份，而搜尋頁是另一個橋接。
class SimulationSessions {
  final Map<String, SimulationSession> open = {};
}

class SimulationSession {
  SimulationSession(this.draft, this.base);

  final ExtraTable draft;

  /// 同一學期的實際課表；沒有下載過那一學期就是 null。
  final CourseTableJson? base;
}
