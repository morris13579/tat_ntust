import 'package:html_unescape/html_unescape.dart';

class HtmlUtils {
  /*
  「		雙引號			&quot;		×	乘號				&times;		←	向左箭頭				&larr;
  &		AND符號			&amp;		÷	除號				&divide;		↑	向上箭頭			&uarr;
  <		小於符號		&lt;		±	正負符號			&plusmn;		→	向右箭頭			&rarr;
  >		大於符號		&gt;			function符號		&fnof;		↓	向下箭頭				&darr;
      空格			&nbsp;		√	根號				&radic;			雙向箭頭				&harr;
  		倒問號			&iquest;	∞	無限大符號			&infin;		⇐	雙線向左箭頭			&lArr;
  «		雙左箭頭		&laquo;		∠	角度符號			&ang;		⇑	雙線向上箭頭			&uArr;
  »		雙右箭頭		&raquo;		∫	微積分符號			&int;		⇒	雙線向右箭頭			&rArr;
  『		左單引號		&lsquo;		°	度數符號			&deg;		⇓	雙線向下箭頭			&dArr;
  』		右單引號		&rsquo;		≠	不等於符號			&ne;			雙線雙向箭頭			&hArr;
  「		左雙引號		&ldquo;		≡	相等符號			&equiv;			黑桃符號				&spades;
  」		右雙引號		&rdquo;		≦	小於等於符號		&le;			梅花符號				&clubs;
  		段落符號		&para;		≧	大於等於符號		&ge;			紅心符號				&hearts;
  §		章節符號		&sect;		⊥	垂直符號			&perp;			方塊符號				&diams;
  ©		版權所有符號	&copy;			二分之一符號		&frac12;	α	Alpha符號				&alpha;
  		註冊商標符號	&reg;			四分之一符號		&frac14;	β	Bata符號				&beta;
  		商標符號		&trade;			四分之三符號		&frac34;	γ	Gamma符號				&gamma;
  €		歐元符號		&euro;			百分符號			&permil;	Δ	Delta符號				&Delta;
  ¢		美分符號		&cent;		∴	所以符號			&there4;	θ	Theta符號				&theta;
  £		英鎊符號		&pound;		π	圓周率符號			&pi;		λ	Lambda符號				&lambda;
  ¥		日圓符號		&yen;		¹	註解1符號			&sup1;		Σ	Sigma符號				&Sigma;
  …		…				&hellip;	²	註解2符號、平方		&sup2;		τ	Tau符號					&tau;
  ⊕		 				&oplus;		³	註解3符號、立方		&sup3;		ω	Omega符號				&omega;
  ∇		倒三角型符號	&nabla;		↵	ENTER符號			&crarr;		Ω	Omega符號、歐姆符號		&Omega;
   */

  /// 把 HTML 實體還原成字元，輸出是**純文字**。
  ///
  /// 名字叫 clean，但它不是 sanitiser，方向剛好相反：它會把
  /// `&lt;script&gt;` 這種本來惰性的字串還原成 `<script>` 這種活的標記。
  /// 呼叫端有義務保證輸出只會流進純文字 sink（Text、AppBar 標題……）；
  /// 一旦接到 HtmlWidget、WebView 或檔案路徑上，就等於開了注入的門。
  ///
  /// 討論串的 `subject` 與 `replysubject` 都走這裡：前者印在卡片子標題，
  /// 後者除了印在撰寫頁的引用卡，還會原樣送回 `mod_forum_add_discussion_post`
  /// 的 `subject`（PARAM_TEXT，伺服器自己會剝標籤），兩者都不是 HTML sink。
  ///
  /// 成績項目的四個 `*formatted` 走 `MoodleRepository.normalizeScore`：Moodle
  /// 把全距送成 `0&ndash;100`，而那四欄的下游只有 Text。同一列的 `feedback`
  /// 是 HTML、下游是 HtmlWidget，刻意不經過這裡。
  ///
  /// `test/util/html_utils_sink_inventory_test.dart` 把現有的 sink 盤點寫成
  /// 可執行的清單：新增 `clean()` 的呼叫端、在 lib 底下新增 `HtmlWidget`，
  /// 或把 `Modules.name` 餵進 `HtmlWidget`，那個測試就會變紅並要求重跑盤點。
  ///
  /// 刻意**不**加「還原後再把標籤剝掉」的防護：課名合法地可能含 `<`、`>`
  /// （例如 `x&lt;y`、`C++ &lt;入門&gt;`），剝標籤會靜默吃掉真實課名。真的要
  /// 防，該防在 sink 那端（HTML sink 自己 escape）。
  static String clean(String html) {
    String result;
    var unescape = HtmlUnescape();
    result = unescape.convert(html);
    return result;
  }
}
