/// HTML 裡 `<img>` 的來源，照出現順序、去掉重複。原生版的 HTML 只畫文字與連結，圖片另外排在下面。
List<String> htmlImageSources(String html) {
  final seen = <String>{};
  return [
    for (final match in _imgSrc.allMatches(html))
      if (seen.add(match.group(1)!.trim())) match.group(1)!.trim(),
  ];
}

final RegExp _imgSrc = RegExp(r'''<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']''',
    caseSensitive: false);
