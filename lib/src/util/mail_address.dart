/// 收件者欄吃逗號與分號分隔。空白項直接丟掉，讓「a@b.c, 」不會變成一個空位址。
///
/// 籤化之後貼上一整串位址也要走同一套切法，原生版的收件者欄也是。
List<String> parseMailAddresses(String raw) => raw
    .split(RegExp(r'[,;\s]+'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

/// 只擋明顯不是位址的輸入。**不做嚴格的 RFC 5322 驗證**：那個文法允許的東西
/// 遠比任何正規表達式寫得出來的多，擋過頭會讓合法位址寄不出去。
bool looksLikeMailAddress(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
