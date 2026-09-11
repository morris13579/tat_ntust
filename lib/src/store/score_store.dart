import 'dart:convert';

import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/store/key_value_store.dart';

/// 成績的持久化。key 名 `score_credit`，格式是單一 JSON 字串。
///
/// 這份資料不只成績頁在用：課表對歷史學期是靠這裡的課號反查課程查詢 API
/// 的。所以「取學期清單時順便存成績」那個看起來突兀的副作用不能拿掉。
class ScoreStore {
  static ScoreStore instance = ScoreStore(SharedPrefsKeyValueStore());

  static const scoreKey = 'score_credit';

  final KeyValueStore _store;

  ScoreRankJson score = ScoreRankJson();

  ScoreStore(this._store);

  Future<void> load() async {
    final raw = await _store.readString(scoreKey);
    score = raw == null
        ? ScoreRankJson()
        : ScoreRankJson.fromJson(json.decode(raw));
  }

  Future<void> save() => _store.writeJson(scoreKey, score);

  Future<void> clear() async {
    score = ScoreRankJson();
    await save();
  }
}
