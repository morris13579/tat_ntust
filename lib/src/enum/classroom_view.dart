/// 空教室頁的兩種檢視。
///
/// 住在 `enum/` 而不是 controller 旁邊：`SettingsStore` 要存它（記住上次用
/// 哪一個），而 store 在 `tool/deps.py` 裡排在 controller **下面**，從那裡
/// import controller 會是上行邊。
///
/// **索引就是持久化格式**（`SettingsStore.classroomViewKey` 存的是
/// `index`），調換順序會讓升級後的使用者開在另一個檢視。
enum ClassroomView {
  /// 依樓層列出空著的教室。預設。
  list,

  /// 同一棟一整天的形狀。
  day,
}
