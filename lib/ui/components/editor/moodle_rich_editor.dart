import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/util/rich_editor_bridge_utils.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// [MoodleRichEditor] 的遙控器。頁面拿它下指令、取內容，widget 本身不知道
/// 那些內容是什麼意思。
class MoodleRichEditorController {
  _MoodleRichEditorState? _state;

  bool get isReady => _state?._ready ?? false;

  void exec(EditorCommand command) => _state?._exec(command);

  void setSourceMode(bool on) => _state?._setSourceMode(on);

  /// 編輯器現在的內容；還沒接上時回 null（呼叫端不可以把 null 當成空內容
  /// 送出去——那會把整篇貼文清掉）。
  Future<String?> content() async => _state?._content();

  /// 收鍵盤。平台視圖握著 first responder，Flutter 的 FocusManager 管不到它。
  /// 兩條路都走，見 [MoodleRichEditor.dropInputAccessoryView]。
  Future<void> blur() async => _state?._blur();
}

/// `assets/editor/` 那一頁的殼。**HTML 進、HTML 出，沒有別的**：不認識
/// Moodle、不改網址、不判斷格式。
///
/// 它在 `flutter_test` 底下幾乎測不到（平台視圖畫不出來），所以它裡面能少放
/// 一點邏輯就少放一點——判斷與改寫全部住在 `lib/src/util/` 的純函式裡。
class MoodleRichEditor extends StatefulWidget {
  const MoodleRichEditor({
    super.key,
    required this.initialHtml,
    this.placeholder,
    required this.controller,
    required this.onStateChanged,
    required this.onChanged,
    required this.onReady,
    required this.onLoadFailed,
  });

  /// 編輯面空著時顯示的提示字。null 就不畫——論壇貼文那一頁上面已經有一列
  /// 「內容」的標籤，再畫一次是重複。
  final String? placeholder;

  /// 進到 contenteditable 的 HTML。內嵌圖片的網址必須已經是可以直接載入的
  /// 樣子——這一層不會替任何網址加憑證。
  final String initialHtml;

  final MoodleRichEditorController controller;

  /// 游標處生效的格式（[RichEditorBridgeUtils.parseEditorState] 的輸出）。
  final ValueChanged<Set<String>> onStateChanged;

  /// 使用者真的動過內容（`input`，不是移動游標）。放棄草稿的確認靠它。
  final VoidCallback onChanged;

  final VoidCallback onReady;

  /// 握手一直沒來。頁面要據此換成 inline 錯誤，而不是留一塊白。
  final VoidCallback onLoadFailed;

  /// 資產頁的路徑。`assets/editor/` 有列進 pubspec 的 flutter.assets。
  static const String assetPath = 'assets/editor/editor.html';

  /// 從載入到握手的等待上限。超過就當成載不起來。
  static const Duration readyTimeout = Duration(seconds: 10);

  /// iOS 把鍵盤和 WKWebView 的 ^ v ✓ 那一條算成同一個 viewInsets（402×874
  /// 上實測 405 對 336，那一條就是 69pt），而工具列正要釘在那個位置——留著
  /// 等於為同一段空間付兩次。
  ///
  /// 這一條同時是 iOS 內建的收鍵盤入口，所以拿掉它之後，收鍵盤由
  /// [MoodleRichEditorController.blur] 接手，而那個方法**兩條路都走**：先
  /// `clearFocus`（iOS 那一邊就是對 WKContentView `resignFirstResponder`，跟
  /// 打勾做的事一模一樣），再補一次頁面內的 `blur`。原生那條不經過 JS，
  /// 頁面壞掉、`evaluateJavascript` 沒回應時它照樣收得掉。
  ///
  /// 而且**收不掉也不會把人關在裡面**：打字時標題列上有一顆送出，儲存不必先
  /// 收鍵盤。真機上兩條都失靈就把這一顆改回 false，其餘設計一行都不用動
  /// （編輯面從 325 退回 256）。
  static const bool dropInputAccessoryView = true;

  @override
  State<MoodleRichEditor> createState() => _MoodleRichEditorState();
}

class _MoodleRichEditorState extends State<MoodleRichEditor> {
  InAppWebViewController? _webView;
  Timer? _readyTimer;
  bool _ready = false;
  bool _failed = false;

  /// 已經推給頁面的深淺。底色由 Flutter 畫在後面（`transparentBackground`），
  /// 換主題時它會立刻重畫；字色留在頁面裡，不跟著重推就會變成同色的一片。
  Brightness? _pushed;

  /// 平台實作沒註冊時（`flutter test`、或還沒支援的平台）不畫 WebView：
  /// 那不是「空的編輯器」，是載不起來，走同一條失敗路徑講同一句話。
  bool get _platformAvailable => InAppWebViewPlatform.instance != null;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    if (!_platformAvailable) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _reportFailure('platform unavailable'));
      return;
    }
    _readyTimer =
        Timer(MoodleRichEditor.readyTimeout, () => _reportFailure('timeout'));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (brightness == _pushed) return;
    _pushed = brightness;
    unawaited(_pushTheme(brightness));
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    if (widget.controller._state == this) widget.controller._state = null;
    super.dispose();
  }

  void _reportFailure(String why) {
    if (_ready || _failed || !mounted) return;
    _failed = true;
    Log.e('rich editor failed to load: $why');
    widget.onLoadFailed();
  }

  /// 握手之前推不進去（頁面還沒有 `documentElement` 可以設），所以握手完成時
  /// 要補推一次現在的深淺，不是握手當下才第一次決定。
  Future<void> _pushTheme(Brightness brightness) async {
    if (!_ready) return;
    await _webView?.evaluateJavascript(
        source: RichEditorBridgeUtils.buildThemeCall(
            dark: brightness == Brightness.dark));
  }

  Future<void> _exec(EditorCommand command) async {
    if (!_ready) return;
    await _webView?.evaluateJavascript(
        source: RichEditorBridgeUtils.buildCommandCall(command));
  }

  Future<void> _setSourceMode(bool on) async {
    if (!_ready) return;
    await _webView?.evaluateJavascript(
        source: 'window.__tatEditor.setSourceMode($on);');
  }

  Future<void> _blur() async {
    final view = _webView;
    if (view == null) return;
    // 原生那條先跑：它不經過 JS，頁面沒回應時也還在。順序反過來的話，
    // evaluateJavascript 一卡住就再也走不到這一行。
    try {
      await view.clearFocus();
    } catch (e) {
      Log.e('rich editor clearFocus failed: $e');
    }
    if (!_ready) return;
    // 不是橋接指令：碰不到 window.__tatEditor，也不需要動 assets/editor/*。
    // 頁面的 CSP 管的是頁面自己載的 script，宿主 evaluateJavascript 不受它管。
    await view.evaluateJavascript(
        source: 'var e = document.getElementById("ed"); if (e) e.blur();');
  }

  Future<String?> _content() async {
    if (!_ready) return null;
    final raw = await _webView?.evaluateJavascript(
        source: 'window.__tatEditor.getContent();');
    // 橋接回來的東西是不可信的資料：只當字串用，不再拼回任何一段 JS。
    return raw is String ? raw : null;
  }

  Future<void> _onReady() async {
    if (_failed || _ready || !mounted) return;
    _readyTimer?.cancel();
    _ready = true;
    await _pushTheme(_pushed ?? Theme.of(context).brightness);
    // 貼文 HTML 進到頁面的唯一途徑：包成 JS 字串常值，絕不字串相接。
    await _webView?.evaluateJavascript(
        source: RichEditorBridgeUtils.buildSetContentCall(widget.initialHtml));
    if (widget.placeholder case final hint?) {
      await _webView?.evaluateJavascript(
          source: RichEditorBridgeUtils.buildPlaceholderCall(hint));
    }
    if (mounted) widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    if (!_platformAvailable) return const SizedBox.shrink();
    return InAppWebView(
      initialFile: MoodleRichEditor.assetPath,
      initialSettings: InAppWebViewSettings(
        // 這一頁是 file://。開了這兩個等於讓貼文作者寫的內容讀得到 App
        // 沙盒裡的檔案。
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        javaScriptCanOpenWindowsAutomatically: false,
        mediaPlaybackRequiresUserGesture: true,
        supportZoom: false,
        transparentBackground: true,
        disableInputAccessoryView: MoodleRichEditor.dropInputAccessoryView,
        // 沒有這一顆，貼文裡的 <a> 被點到就會把整個編輯器導航走，
        // 使用者還沒存的草稿跟著消失，而且沒有回頭路。
        useShouldOverrideUrlLoading: true,
      ),
      onWebViewCreated: (controller) {
        _webView = controller;
        controller.addJavaScriptHandler(
          handlerName: 'tatEditorReady',
          callback: (_) => unawaited(_onReady()),
        );
        controller.addJavaScriptHandler(
          handlerName: 'tatEditorInput',
          callback: (_) {
            widget.onChanged();
            return null;
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'tatEditorState',
          callback: (args) {
            widget.onStateChanged(RichEditorBridgeUtils.parseEditorState(
                args.isEmpty ? null : args.first));
            return null;
          },
        );
      },
      // 只有資產本身那一次放行，其他全部擋下來。iOS 連初次載入都會經過
      // 這裡，所以不可以寫成「一律 CANCEL」。
      shouldOverrideUrlLoading: (controller, action) async {
        final uri = action.request.url;
        final isAsset = uri != null &&
            uri.scheme == 'file' &&
            uri.path.endsWith('/editor.html');
        return isAsset
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onReceivedError: (controller, request, error) =>
          _reportFailure('${error.type}'),
      // CSP 違規只會出現在 console，看不到就等於這一層防護悄悄失效了。
      onConsoleMessage: (controller, message) =>
          Log.d('rich editor console: ${message.message}'),
    );
  }
}
