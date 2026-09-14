import 'dart:async';

import 'package:flutter_app/generated/core_api.g.dart' as native;
import 'package:flutter_app/src/service/web_view_session.dart';

/// 原生版的 WebView：真正的 WKWebView 在 Swift（`Web/WebSession.swift`）。
///
/// headless 的取代 HeadlessInAppWebView；可見的給 `NativeInteractiveLoginGateway` 開登入頁。
class NativeWebSessions
    implements HeadlessWebViewHost, native.TatWebSessionEvents {
  NativeWebSessions([native.TatCoreUiApi? api])
      : _api = api ?? native.TatCoreUiApi();

  final native.TatCoreUiApi _api;
  final _sessions = <int, NativeWebSession>{};
  var _nextId = 1;

  static NativeWebSessions? _instance;

  static NativeWebSessions get instance =>
      _instance ?? (throw StateError('NativeWebSessions 尚未安裝'));

  static void install([native.TatCoreUiApi? api]) {
    final sessions = NativeWebSessions(api);
    native.TatWebSessionEvents.setUp(sessions);
    HeadlessWebViewHost.instance = sessions;
    _instance = sessions;
  }

  @override
  Future<WebViewSession> open(String url) => openSession(url: url);

  /// App 內瀏覽器的 WebView 由 Swift 自己開，要讓核心驅動時先來拿一個編號，與這裡開的共用同一組。
  int reserveId() => _nextId++;

  /// 驅動一個已經用 [reserveId] 的編號掛在 Swift 那一側的 WebView。
  WebViewDriver driver(int id) => _AttachedWebView(_api, id);

  Future<NativeWebSession> openSession({
    required String url,
    bool visible = false,
    String title = '',
    String? progressMessage,
    List<String> interceptSchemes = const [],
  }) async {
    final id = _nextId++;
    final session = NativeWebSession._(_api, id, () => _sessions.remove(id));
    // 先登記再請 Swift 開，第一個 onLoadStop 才有地方去。
    _sessions[id] = session;
    await _api.openWebSession(native.WebSessionRequest(
      sessionId: id,
      url: url,
      visible: visible,
      title: title,
      progressMessage: progressMessage,
      interceptSchemes: interceptSchemes,
    ));
    return session;
  }

  @override
  void onLoadStop(int sessionId, String? url) =>
      _sessions[sessionId]?._add(WebViewLoadStop(url));

  @override
  void onLoadError(int sessionId, String description) =>
      _sessions[sessionId]?._add(WebViewLoadError(description));

  @override
  void onIntercepted(int sessionId, String url) =>
      _sessions[sessionId]?._add(WebViewIntercepted(url));

  @override
  void onDismissed(int sessionId) =>
      _sessions.remove(sessionId)?._add(const WebViewDismissed());
}

class NativeWebSession implements WebViewSession {
  NativeWebSession._(this._api, this.id, this._unregister);

  final native.TatCoreUiApi _api;
  final int id;
  final void Function() _unregister;
  final _events = StreamController<WebViewEvent>();
  bool _closed = false;

  void _add(WebViewEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  Stream<WebViewEvent> get events => _events.stream;

  @override
  Future<Object?> evaluateJavascript(String source) =>
      _api.evaluateJavascript(id, source);

  @override
  Future<String?> getHtml() => _api.webSessionHtml(id);

  @override
  Future<void> loadUrl(String url) => _api.loadWebSessionUrl(id, url);

  /// null 代表收起進度提示。
  Future<void> setProgress(String? message) =>
      _api.setWebSessionProgress(id, message);

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _unregister();
    // 不 await：沒有人 listen 過的 controller，close 的 Future 永遠不會完成。
    unawaited(_events.close());
    await _api.closeWebSession(id);
  }
}

class _AttachedWebView implements WebViewDriver {
  const _AttachedWebView(this._api, this._id);

  final native.TatCoreUiApi _api;
  final int _id;

  @override
  Future<Object?> evaluateJavascript(String source) =>
      _api.evaluateJavascript(_id, source);

  @override
  Future<String?> getHtml() => _api.webSessionHtml(_id);

  @override
  Future<void> loadUrl(String url) => _api.loadWebSessionUrl(_id, url);
}
