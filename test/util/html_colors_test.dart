import 'package:flutter_app/src/util/html_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

void main() {
  test('只標只有字色、沒有配好底色的元素', () {
    final html = HtmlColors.markNeutral(
      '<p style="color:#000">a</p>'
      '<table><tr><td style="background:#1a73e8">'
      '<span style="color:#fff">Join</span></td></tr></table>'
      '<div style="background: none; color: red">b</div>'
      '<div style="margin:0">c</div>',
    );

    final marked = html_parser
        .parse(html)
        .querySelectorAll('[${HtmlColors.neutralAttribute}]')
        .map((e) => e.text);
    expect(marked, ['a', 'b']);
  });

  test('沒有要中和的就原樣回傳，不重新序列化', () {
    const html = '<p style="margin:0">a</p>';
    expect(HtmlColors.markNeutral(html), same(html));
  });
}
