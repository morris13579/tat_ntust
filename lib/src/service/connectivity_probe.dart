import 'package:connectivity_plus/connectivity_plus.dart';

/// 「現在有沒有網路」的唯一出口。
///
/// 抽成介面是為了讓測試能在不接觸平台通道的情況下走到離線分支；直接呼叫
/// `Connectivity()` 的話 `run()` 的離線路徑測不到。
abstract class ConnectivityProbe {
  /// 正式環境的預設實作。測試以 [FakeConnectivityProbe] 覆寫。
  static ConnectivityProbe instance = const PlatformConnectivityProbe();

  Future<bool> isOnline();
}

class PlatformConnectivityProbe implements ConnectivityProbe {
  const PlatformConnectivityProbe();

  @override
  Future<bool> isOnline() async =>
      await Connectivity().checkConnectivity() != ConnectivityResult.none;
}

/// 測試用。[online] 可隨時改變，用來模擬「彈框前又斷線了」這種情境。
class FakeConnectivityProbe implements ConnectivityProbe {
  bool online;
  int calls = 0;

  FakeConnectivityProbe({this.online = true});

  @override
  Future<bool> isOnline() async {
    calls++;
    return online;
  }
}
