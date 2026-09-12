/// 校內信箱（Openfind Mail2000 V8）的連線常數與資料夾對照。
///
/// 數值全部來自 docs/WEBMAIL_IMAP.md 的實測，不要憑常識改。
class MailConfig {
  MailConfig._();

  static const String host = "mail.ntust.edu.tw";

  /// 收件匣的 IMAP 路徑。RFC 3501 保證這個名字一定存在，其餘資料夾都要靠
  /// `LIST` 問出來（這台伺服器沒有 `SPECIAL-USE`）。
  ///
  /// 放在 config 而不是 repository：connector 也要用它，而 connector 讀
  /// repository 是上行邊。
  static const String inboxPath = "INBOX";

  /// **只走 implicit TLS。** 587 與 25 對外都不通，STARTTLS 那條路在這台
  /// 伺服器上是死路。
  static const int imapPort = 993;
  static const int smtpPort = 465;

  /// `enough_mail` 的預設是 20 秒，行動網路上等太久。
  static const Duration connectTimeout = Duration(seconds: 12);

  /// 指令層的逾時。**`connectTimeout` 蓋不到這些。**
  ///
  /// `enough_mail` 的 `connectToServer(timeout:)` 只套在 `SecureSocket.connect`
  /// 上，TCP + TLS 握手完就沒它的事了——`login` / `SELECT` / `FETCH` / `APPEND`
  /// 之後全都是無限期等待。更糟的是連線被伺服器踢掉時它**不會**讓等待中的
  /// future 失敗（`ImapClient.onConnectionError` 只 fire 一個沒有人訂閱的
  /// 事件），所以那些 future 會永遠掛著。而這台 Mail2000 是真的會踢連線的
  /// （見 §5 的 `auto logout; idle for too long`）。
  ///
  /// 少了這幾個上限，症狀就是使用者看到的「轉圈轉到天荒地老」。
  static const Duration responseTimeout = Duration(seconds: 30);
  static const Duration writeTimeout = Duration(seconds: 30);

  /// 寄件備份的 `APPEND` 上限。整封信（含附件）要再上傳一次，所以比一般指令寬。
  ///
  /// `appendMessage` **不吃** `defaultResponseTimeout`——它用的是自己的方法
  /// 參數，不明給就是 null，也就是沒有上限。呼叫端一定要傳。
  static const Duration appendTimeout = Duration(seconds: 60);

  /// 整段 SMTP（連線 → EHLO → 認證 → 送出）的上限。
  ///
  /// `SmtpClient` 整個類別**沒有任何逾時鉤子**（grep timeout 零命中），連
  /// `sendCommand` 都不帶，所以只能從外面用 `Future.timeout` 包住。
  static const Duration smtpTimeout = Duration(seconds: 90);

  /// SMTP `EHLO` 用的 client domain。
  static const String clientDomain = "ntust.edu.tw";

  /// 分頁時一頁幾封。
  ///
  /// 和 [inboxFetchLimit] 是兩回事：那個是「開頁先抓幾封」，這個是「捲到底
  /// 再抓幾封」。先前同一個常數被當成兩種語意用。
  static const int pageSize = 50;

  /// 收件匣一次抓幾封。
  ///
  /// 伺服器沒有 `SORT` 也沒有 `CONDSTORE`，排序與比對都得把整批 envelope 抓
  /// 回本機做，所以這個數字直接決定開頁的等待時間。
  static const int inboxFetchLimit = 50;

  /// 搜尋時往回抓多少封 envelope 到本機篩。
  ///
  /// **搜尋刻意不走伺服器端 `SEARCH`。** 實測這台 Mail2000 在 4366 封的信箱上：
  ///
  /// | 操作 | 耗時 |
  /// | --- | --- |
  /// | `SEARCH ALL` | 0.1s |
  /// | `FETCH` 最新 500 封 envelope | 7.0s |
  /// | `SEARCH HEADER SUBJECT` | 16.0s |
  /// | `SEARCH SUBJECT` | **69.3s** |
  ///
  /// 主旨與寄件者各查一次會超過伺服器的閒置逾時，實測直接被回
  /// `auto logout; idle for too long`——連線在指令跑完前就被踢掉，搜尋永遠不會
  /// 回來。抓 500 封回本機篩反而比伺服器搜一次還快一倍，而且不會逾時。
  ///
  /// 代價是搜尋範圍限於最近這 500 封，不是整個信箱。
  static const int searchWindow = 500;

  /// 寄件大小上限，來自 `EHLO` 回的 `SIZE 52428800`。
  static const int maxMessageBytes = 52428800;

  /// 附件的**原始檔案**總大小上限。
  ///
  /// 不是直接用 [maxMessageBytes]：MIME 會把附件 base64 編碼，膨脹約 4/3，
  /// 再加上標頭與內文。用 35 MB 去擋，等於留了約三成的餘裕——寧可在選檔當下
  /// 就說不行，也不要讓使用者傳完才被伺服器退。
  static const int maxAttachmentBytes = 35 * 1024 * 1024;
}
