/// NTUST SSO 登入的結果。
///
/// 原本定義在 `lib/src/connector/ntust_connector.dart` 裡。搬到 enum 層
/// （`tool/deps.py` 的 model，rank 8）是為了讓 `InteractiveLoginGateway`
/// 的介面能用具名型別而不是 `Map<String, dynamic>`：那個介面在 util 層
/// （rank 5），import connector（rank 4）會是上行邊。
enum NTUSTLoginStatus { success, fail }
