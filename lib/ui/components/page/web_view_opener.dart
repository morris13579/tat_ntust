/// 開 App 內 WebView 的入口，由呼叫端注入；免登入的網址替換也在那一端做。
typedef WebViewOpener = Future<void> Function(String title, String url);
