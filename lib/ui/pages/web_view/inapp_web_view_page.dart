import 'dart:async';
import 'dart:convert';

import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/service/ssoam2_login.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/ui/service/file_download.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/open_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/web_view/browser_notice_bar.dart';
import 'package:flutter_app/src/util/my_toast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

class InAppWebViewPage extends StatefulWidget {
  final WebUri url;

  /// [url] 是 autologin 包裝網址時原本要開的那個。鑰匙被拒（過期、IP 不符、
  /// 已用過）時 autologin.php 顯示錯誤頁而不轉址，這時退回去開它。
  final WebUri? fallbackUrl;
  final String title;
  final bool openWithExternalWebView;
  final Function(Uri)? onWebViewDownload;
  final Function(InAppWebViewController) loadDone;

  const InAppWebViewPage({
    required this.title,
    required this.url,
    this.fallbackUrl,
    this.openWithExternalWebView = false,
    this.onWebViewDownload,
    required this.loadDone,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _InAppWebViewPageState();
}

class _InAppWebViewPageState extends State<InAppWebViewPage> {
  final cookieManager = CookieManager.instance();
  final cookieJar = DioConnector.instance.cookiesManager;
  InAppWebViewController? webView;
  Uri url = Uri();
  double progress = 0;
  Uri? lastLoadUri;
  final String ntustLoginUri = "https://ssoam.ntust.edu.tw/nidp/app/login";

  /// 正在代填帳密。認出登入頁時打開，離開登入頁就關掉。
  bool _autoLogin = false;

  /// 代填被驗證碼擋下來了。這是整個瀏覽器唯一需要使用者動手的時刻。
  bool _captcha = false;

  /// 免登入的鑰匙被拒、已經退回原網址。
  bool _fellBackNotice = false;

  /// 剛下載完的檔名。
  String? _downloaded;

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(myInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(myInterceptor);
    super.dispose();
  }

  /// 問 WebView 自己還有沒有上一頁，而不是數 onLoadStop 的次數：學校系統
  /// 轉址很多，用次數猜會退到錯的地方，甚至退不出這一頁。
  bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    final controller = webView;
    if (controller == null) return false;
    unawaited(() async {
      if (await controller.canGoBack()) {
        await controller.goBack();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    }());
    return true;
  }

  bool firstLoad = true;

  /// 只退回一次：之後使用者按上一頁回到那個錯誤頁是他自己要去的。
  bool fellBack = false;

  Future<bool> setCookies() async {
    if (!firstLoad) return true;
    firstLoad = false;
    final cookies = await cookieJar.loadForRequest(widget.url);
    // Moodle 的頁面不清平台 cookie store：autologin.php 建立的 MoodleSession
    // 只存在那裡，而伺服器 6 分鐘內只發一把鑰匙，清掉第二頁就停在登入頁。
    if (!MoodleWebApiConnector.isOwnHost(widget.url)) {
      await cookieManager.deleteAllCookies();
    }
    // 只剩「同一批 Dio cookie 內部同名去重」的作用，所以從空集合開始。
    final cookiesName = <String>{};
    for (var cookie in cookies) {
      if (!cookiesName.contains(cookie.name)) {
        cookiesName.add(cookie.name);
        await cookieManager.setCookie(
          url: widget.url,
          name: cookie.name,
          value: cookie.value,
          domain: cookie.domain,
          path: cookie.path ?? "/",
          maxAge: cookie.maxAge,
          isSecure: cookie.secure,
          isHttpOnly: cookie.httpOnly,
        );
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context),
      body: FutureBuilder<bool>(
        future: setCookies(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData) {
            return Column(
              children: <Widget>[
                if (_noticeBar(context) case final notice?) notice,
                Expanded(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: widget.url),
                    initialSettings: InAppWebViewSettings(
                        useHybridComposition: true, useOnDownloadStart: true),
                    onWebViewCreated: (InAppWebViewController controller) {
                      webView = controller;
                    },
                    onLoadStart: (InAppWebViewController controller, Uri? url) {
                      setState(() {
                        lastLoadUri = url;
                        this.url = url!;
                        // 離開登入頁就把代填／驗證碼的提示收起來。
                        if (!_isLoginPage(url)) {
                          _autoLogin = false;
                          _captcha = false;
                        }
                        _downloaded = null;
                      });
                    },
                    onLoadStop:
                        (InAppWebViewController controller, Uri? url) async {
                      if (shouldFallBackFrom(url)) {
                        // 成功時會 303 轉走，停在它身上就是鑰匙被拒。
                        fellBack = true;
                        setState(() => _fellBackNotice = true);
                        Log.e("[autologin] autologin.php 沒有轉址，改開原網址：$url");
                        await controller.loadUrl(
                            urlRequest: URLRequest(url: widget.fallbackUrl));
                        return;
                      }
                      if (url.toString().startsWith(ntustLoginUri)) {
                        setState(() => _autoLogin = true);
                        await controller.evaluateJavascript(
                            source:
                                'document.getElementsByName("Ecom_User_ID")[0].value = ${jsonEncode(Model.instance.getAccount())};');
                        await controller.evaluateJavascript(
                            source:
                                'document.getElementsByName("Ecom_Password")[0].value = ${jsonEncode(Model.instance.getPassword())};');
                        await controller.evaluateJavascript(
                            source:
                                'document.getElementById("loginButton2").click();');
                      } else if (Ssoam2Login.isLoginPage(url)) {
                        setState(() => _autoLogin = true);
                        final outcome = await Ssoam2Login.submit(
                          controller,
                          account: Model.instance.getAccount(),
                          password: Model.instance.getPassword(),
                        );
                        // 代填失敗最常見的原因就是驗證碼。提示留在畫面上而不是
                        // 跳 toast——人還在那一頁，toast 幾秒就沒了。
                        if (outcome != Ssoam2LoginOutcome.submitted) {
                          setState(() {
                            _autoLogin = false;
                            _captcha = true;
                          });
                        }
                      }
                      widget.loadDone(controller);
                      setState(
                        () {
                          this.url = url!;
                        },
                      );
                    },
                    onProgressChanged:
                        (InAppWebViewController controller, int progress) {
                      setState(
                        () {
                          this.progress = progress / 100;
                        },
                      );
                    },
                    onDownloadStartRequest: (InAppWebViewController controller,
                        DownloadStartRequest downloadStartRequest) {
                      var url = downloadStartRequest.url;
                      Log.d("WebView download ${url.toString()}");
                      if (widget.onWebViewDownload != null) {
                        widget.onWebViewDownload!(url);
                      } else {
                        unawaited(_download(url));
                      }
                    },
                  ),
                ),
              ],
            );
          }

          return const LoadingPage(
            isLoading: true,
            isShowBackground: false,
          );
        },
      ),
    );
  }

  /// 這一次 onLoadStop 停在 autologin.php 本身，而且還沒退過。
  bool shouldFallBackFrom(Uri? url) =>
      widget.fallbackUrl != null &&
      !fellBack &&
      MoodleWebApiConnector.isAutologinScript(url);

  bool _isLoginPage(Uri? url) =>
      url != null &&
      (url.toString().startsWith(ntustLoginUri) ||
          Ssoam2Login.isLoginPage(url));

  /// host 不屬於學校。這是「帶著登入狀態開任意 http(s)」唯一的可見防線——
  /// `WebViewUrlPolicy` 只驗 scheme，課程 HTML 裡的連結可以帶去任何地方。
  bool get _isExternal {
    final host = url.host;
    return host.isNotEmpty && !host.endsWith('ntust.edu.tw');
  }

  /// 同一時間只出現一條，優先序由上而下。
  Widget? _noticeBar(BuildContext context) {
    if (_autoLogin) {
      return BrowserNoticeBar(
        icon: LucideIcons.info,
        message: R.current.browserAutoLoginNotice,
        kind: BrowserNoticeKind.info,
      );
    }
    if (_captcha) {
      return BrowserNoticeBar(
        icon: LucideIcons.triangleAlert,
        message: R.current.browserCaptchaNotice,
        kind: BrowserNoticeKind.warning,
      );
    }
    if (_fellBackNotice) {
      return BrowserNoticeBar(
        icon: LucideIcons.circleAlert,
        message: R.current.browserAutologinExpired,
        kind: BrowserNoticeKind.warning,
        actionLabel: R.current.browserRelogin,
        onAction: () => unawaited(webView?.reload() ?? Future<void>.value()),
      );
    }
    if (_isExternal) {
      return BrowserNoticeBar(
        icon: LucideIcons.externalLink,
        message: R.current.browserExternalSite,
        kind: BrowserNoticeKind.warning,
      );
    }
    if (_downloaded case final name?) {
      return BrowserNoticeBar(
        icon: LucideIcons.download,
        message: sprintf(R.current.browserDownloadSaved, [name]),
        kind: BrowserNoticeKind.success,
      );
    }
    return null;
  }

  Future<void> _download(Uri target) async {
    final name = target.pathSegments.isEmpty ? null : target.pathSegments.last;
    await FileDownload.download(context, target.toString(), "WebView");
    if (!mounted || name == null || name.isEmpty) return;
    setState(() => _downloaded = name);
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);
    return AppBar(
      backgroundColor: context.tokens.card,
      toolbarHeight: 60,
      titleSpacing: 0,
      leadingWidth: 52,
      leading: IconButton(
        tooltip: materialL10n.backButtonTooltip,
        icon: const Icon(LucideIcons.chevronLeft),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: BrowserAddressBar(url: url, title: widget.title),
      actions: [
        IconButton(
          tooltip: R.current.refresh,
          icon: const Icon(LucideIcons.refreshCw, size: 20),
          onPressed: () => unawaited(webView?.reload() ?? Future<void>.value()),
        ),
        IconButton(
          tooltip: R.current.titleMore,
          icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
          onPressed: () => unawaited(_openMenu(context)),
        ),
      ],
      bottom: BrowserProgressLine(progress: progress),
    );
  }

  /// ⋮ 的選單。最上面重複一次 host 與標題：裡面每一個動作都作用在「當前這個
  /// 網址」，它必須跟動作在同一個視野裡。
  Future<void> _openMenu(BuildContext context) async {
    final canForward = await webView?.canGoForward() ?? false;
    if (!context.mounted) return;
    await showTatContentSheet<void>(
      context: context,
      builder: (sheetContext) => _BrowserMenu(
        url: url,
        title: widget.title,
        canForward: canForward,
        showOpenExternal: widget.openWithExternalWebView,
        onForward: () {
          Navigator.pop(sheetContext);
          unawaited(webView?.goForward() ?? Future<void>.value());
        },
        onCopy: () {
          Navigator.pop(sheetContext);
          unawaited(Clipboard.setData(ClipboardData(text: url.toString())));
          MyToast.show(R.current.browserUrlCopied);
        },
        onShare: () {
          Navigator.pop(sheetContext);
          unawaited(SharePlus.instance.share(ShareParams(
            uri: url,
            sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
          )));
        },
        onOpenExternal: () {
          Navigator.pop(sheetContext);
          unawaited(OpenUtils.launchURL(url.toString()));
        },
      ),
    );
  }
}

/// ⋮ 選單的內容。
class _BrowserMenu extends StatelessWidget {
  const _BrowserMenu({
    required this.url,
    required this.title,
    required this.canForward,
    required this.showOpenExternal,
    required this.onForward,
    required this.onCopy,
    required this.onShare,
    required this.onOpenExternal,
  });

  final Uri url;
  final String title;
  final bool canForward;
  final bool showOpenExternal;
  final VoidCallback onForward;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final materialL10n = MaterialLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                url.host.isEmpty ? url.toString() : url.host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        // 「下一頁」多數時候沒有歷史可去，但位置固定比較好按，所以是停用而
        // 不是消失。
        _MenuRow(
          icon: LucideIcons.chevronRight,
          label: materialL10n.nextPageTooltip,
          onTap: canForward ? onForward : null,
        ),
        _MenuRow(
          icon: LucideIcons.copy,
          label: R.current.browserCopyUrl,
          onTap: onCopy,
        ),
        _MenuRow(
          icon: LucideIcons.share2,
          label: R.current.browserShare,
          onTap: onShare,
        ),
        if (showOpenExternal)
          _MenuRow(
            icon: LucideIcons.externalLink,
            label: R.current.openInBrowser,
            // 外部瀏覽器拿不到這裡注入的 cookie，學校系統會直接把人踢回登入頁。
            supporting: R.current.browserOpenExternalNote,
            onTap: onOpenExternal,
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.supporting,
  });

  final IconData icon;
  final String label;
  final String? supporting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final enabled = onTap != null;
    final foreground = enabled ? scheme.onSurface : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: TatTokens.heightRow),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: TatTokens.iconColumn,
              child: Icon(icon,
                  size: 20,
                  color: enabled ? scheme.onSurfaceVariant : scheme.outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style:
                          context.text.bodyLarge?.copyWith(color: foreground)),
                  if (supporting != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      supporting!,
                      style: context.text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
