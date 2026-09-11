/// `mod_forum_update_discussion_post` 與 `mod_forum_delete_post` 共用的回應。
///
/// `warnings` 不宣告：兩支的 `$warnings = []` 在伺服器端從未 append。
/// `status: false` 實務上不可達（`forum_update_post()` 最後無條件回 true），
/// 但照樣要當成失敗——證明不了寫入發生過就是失敗。
class MoodleForumWriteStatus {
  const MoodleForumWriteStatus({required this.status});

  final bool status;

  /// 形狀不對回 null；呼叫端必須把 null 當成失敗。
  static MoodleForumWriteStatus? of(dynamic result) {
    if (result is! Map || !result.containsKey('status')) return null;
    return MoodleForumWriteStatus(status: result['status'] == true);
  }
}
