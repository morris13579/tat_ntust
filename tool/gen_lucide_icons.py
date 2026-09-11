#!/usr/bin/env python3
"""產生 lib/ui/other/lucide_icons.dart。

用法:
    python3 tool/gen_lucide_icons.py           # 掃描 lib/ 實際用到的圖示並重產
    python3 tool/gen_lucide_icons.py --check   # 只檢查，有差異就非零離開
    python3 tool/gen_lucide_icons.py --list foo-bar baz   # 查這幾個名稱的碼位

筆畫粗細是不同的字體檔，碼位完全相同，所以同一個名稱在每個類別裡都是同一個
碼位、只差 fontFamily：

    LucideIcons.download       1.5px  assets/fonts/lucide-light.ttf  預設
    LucideIconsThin.download   1.0px  assets/fonts/lucide-thin.ttf   和 Moodle
                                                                     檔案圖示同粗
    LucideIconsThick.download  2.0px  （字體還沒加進來，見下）

**一定要是 const IconData，而且 fontFamily 要是字面值**：Flutter 的 icon
tree-shaking 只看得懂 const 的 IconData，看不懂就整份字體原封不動打進包裡。
所以不要寫成「執行期依 weight 換 fontFamily」的 widget，那會讓 tree-shaker
把字體裁成空的、圖示在 release 版變成豆腐。

同理，一個 family 若一個 const 都沒指到，它不會被裁成空的，而是整份打包
（實測 474 KB）。所以 pubspec 只宣告真的有人用的粗細，這支也會擋住「有用到
卻沒宣告 family」的情況——那種錯誤是靜默的，分析器與測試都看不出來。
要加 LucideIconsThick 就把 lucide-regular.ttf 放回 assets/fonts/ 並在
pubspec 補上 family: LucideThick。

產生的常數集合 = lib/ 裡實際出現的用法。沒人用的不會被留下來，少掉的會自動
補上。改完圖示跑一次這支就好。

名稱與碼位的對照表是 tool/lucide_codepoints.json，一次性從 lucide_icons_flutter
3.1.18 的 assets/lucide.ttf 抽出來的（那份字體的 glyph name 就是 lucide.dev 上的
圖示名稱；出貨的權重字體只有 uniXXXX 這種名字，所以名稱要另外留一份）。
要更新對照表就重抓那個套件：
    curl -sSL https://pub.dev/api/archives/lucide_icons_flutter-3.1.18.tar.gz | tar xz

對照表有一批 glyph 沿用 Lucide 舊名（例如 alert-circle 之後改叫 circle-alert），
ALIASES 就是新名到舊名的對照。
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PUBSPEC = os.path.join(ROOT, "pubspec.yaml")
CODEPOINTS = os.path.join(ROOT, "tool", "lucide_codepoints.json")
OUT = os.path.join(ROOT, "lib", "ui", "other", "lucide_icons.dart")
SCAN_DIRS = [os.path.join(ROOT, "lib"), os.path.join(ROOT, "test")]

# 類別名 -> (font family, 說明)。順序就是產出的順序。
WEIGHTS = [
    ("LucideIcons", "Lucide", "1.5px，App 預設的筆畫"),
    ("LucideIconsThin", "LucideThin", "1.0px，和 Moodle 檔案類型圖示同粗"),
    ("LucideIconsThick", "LucideThick", "2.0px，Lucide 原生粗細，用於強調"),
]

# 新名稱 -> 對照表內的舊名（上游改過名，對照表停在舊名）。
ALIASES = {
    "chart-column": "bar-chart-3",
    "chart-line": "line-chart",
    "chart-pie": "pie-chart",
    "circle-alert": "alert-circle",
    "circle-check": "check-circle",
    "clock": "clock-4",
    "code-xml": "code-2",
    "file-pen": "file-edit",
    "file-question": "file-question-mark",
    "grid-2x2": "grid-2-x-2",
    "grid-3x3": "grid-3-x-3",
    "house": "home",
    "loader-circle": "loader-2",
    "pen-line": "pencil-line",
    "square-pen": "edit",
    "triangle-alert": "alert-triangle",
    "user-round": "user-2",
    "users-round": "users-2",
}

HEADER = """import 'package:flutter/widgets.dart';

/// Lucide 圖示。字體是自帶的 assets/fonts/lucide-*.ttf，不裝
/// lucide_icons_flutter（理由見 pubspec.yaml）。
///
/// 這個檔案是產生出來的，不要手改：加完用法之後跑
/// `python3 tool/gen_lucide_icons.py`，它會掃 lib/ 並重產這裡的常數。
/// 名稱查 https://lucide.dev/icons/ ，碼位查 tool/lucide_codepoints.json。
///
/// 三個類別是三種筆畫粗細，碼位相同、只差 fontFamily。挑粗細就換類別：
/// 內文與清單用預設的 [LucideIcons]，要更細（例如和檔案類型圖示並排）用
/// [LucideIconsThin]，要強調用 [LucideIconsThick]。
"""


def camel_to_kebab(name):
    """arrowLeft -> arrow-left、trash2 -> trash-2（Lucide 的數字後綴都帶連字號）。"""
    name = re.sub(r"(?<!^)(?=[A-Z])", "-", name)
    name = re.sub(r"(?<=[a-zA-Z])(?=\d)", "-", name)
    return name.lower()


def declared_families():
    """pubspec.yaml 宣告過的 font family。"""
    with open(PUBSPEC, encoding="utf-8") as handle:
        return set(re.findall(r"^\s*- family:\s*(\S+)\s*$", handle.read(),
                              re.MULTILINE))


def load_codepoints():
    with open(CODEPOINTS, encoding="utf-8") as handle:
        return json.load(handle)


def scan_usages():
    """回傳 {類別名: {常數名}}，只收真的出現過的。

    連 test/ 一起掃：測試用 `find.byIcon` 指名圖示，只掃 lib/ 的話，某個圖示
    在正式碼裡改了粗細就會讓測試變成編譯錯誤。
    """
    used = {cls: set() for cls, _, _ in WEIGHTS}
    # 長的類別名要先比，否則 LucideIcons 會先吃掉 LucideIconsThin。
    names = sorted((cls for cls, _, _ in WEIGHTS), key=len, reverse=True)
    pattern = re.compile(r"\b(%s)\.([a-zA-Z][a-zA-Z0-9]*)" % "|".join(names))
    for scan_dir in SCAN_DIRS:
        for dirpath, dirnames, filenames in os.walk(scan_dir):
            dirnames[:] = [d for d in dirnames if d != "generated"]
            for filename in filenames:
                if not filename.endswith(".dart"):
                    continue
                path = os.path.join(dirpath, filename)
                if os.path.abspath(path) == os.path.abspath(OUT):
                    continue
                with open(path, encoding="utf-8") as handle:
                    for cls, const in pattern.findall(handle.read()):
                        used[cls].add(const)
    return used


def resolve(kebab, codepoints):
    """圖示名 -> 碼位，找不到回 None。"""
    for candidate in (kebab, ALIASES.get(kebab)):
        if candidate and candidate in codepoints:
            return codepoints[candidate]
    return None


def emit(camel, codepoint):
    """照專案既有的 80 欄折行方式輸出一個常數（repo 沒跑新版 dart format）。"""
    body = f"IconData(0x{codepoint:04x}, fontFamily: _family);"
    line = f"  static const IconData {camel} = {body}"
    if len(line) <= 80:
        return line
    return f"  static const IconData {camel} =\n      {body}"


def render(used, codepoints):
    out = [HEADER.rstrip("\n")]
    missing = []
    for cls, family, note in WEIGHTS:
        # 沒人用的粗細就整個類別不產：空類別的 _family 會踩到 unused_field，
        # 而 CI 是 --fatal-infos。要用先寫呼叫端，再跑一次這支就長出來了。
        if not used[cls]:
            continue
        out.append("")
        out.append(f"/// {note}。")
        out.append("@staticIconProvider")
        out.append(f"class {cls} {{")
        out.append(f"  const {cls}._();")
        out.append("")
        out.append(f"  static const String _family = '{family}';")
        for camel in sorted(used[cls]):
            kebab = camel_to_kebab(camel)
            codepoint = resolve(kebab, codepoints)
            if codepoint is None:
                missing.append(f"{cls}.{camel} ({kebab})")
                continue
            out.append("")
            out.append(f"  /// {kebab}")
            out.append(emit(camel, codepoint))
        out.append("}")
    return "\n".join(out) + "\n", missing


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="只比對，不寫檔")
    parser.add_argument("--list", nargs="*", metavar="NAME",
                        help="查這幾個 kebab-case 名稱的碼位")
    args = parser.parse_args()

    codepoints = load_codepoints()

    if args.list is not None:
        for name in args.list:
            codepoint = resolve(name, codepoints)
            print(f"{name}: " +
                  (f"0x{codepoint:04x}" if codepoint else "對照表裡沒有這個名稱"))
        return 0

    used = scan_usages()

    # 沒宣告在 pubspec 的 family 會直接變成豆腐，而且是靜默的：分析器與測試
    # 都看不出來，只有真的把畫面叫出來才會發現。
    families = declared_families()
    undeclared = [(cls, family) for cls, family, _ in WEIGHTS
                  if used[cls] and family not in families]
    if undeclared:
        print("這些粗細有人用，但 pubspec.yaml 沒宣告對應的 family：",
              file=sys.stderr)
        for cls, family in undeclared:
            print(f"  - {cls} 需要 family: {family}", file=sys.stderr)
        return 1

    content, missing = render(used, codepoints)
    if missing:
        print("對照表裡找不到這些圖示，先改用別的名稱或補進 ALIASES：",
              file=sys.stderr)
        for name in missing:
            print(f"  - {name}", file=sys.stderr)
        return 1

    total = sum(len(v) for v in used.values())
    with open(OUT, encoding="utf-8") as handle:
        current = handle.read()
    if current == content:
        print(f"已是最新，{total} 個圖示")
        return 0
    if args.check:
        print(f"lucide_icons.dart 與用法不同步（應有 {total} 個圖示）",
              file=sys.stderr)
        return 1
    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write(content)
    print(f"已更新 {OUT}，{total} 個圖示 " +
          ", ".join(f"{cls}={len(used[cls])}" for cls, _, _ in WEIGHTS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
