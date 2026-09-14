#!/usr/bin/env python3
"""把 lib/l10n/*.arb 產生成 iOS 原生版的字串。

用法:
    python3 tool/gen_ios_l10n.py           # 重產
    python3 tool/gen_ios_l10n.py --check   # 只檢查，有差異就非零離開

兩個平台共用同一份 ARB：key 與翻譯只改 ARB。Flutter 那邊照舊由 flutter_intl 產生，
這支負責 ios_native：

    ios_native/TATNative/Resources/zh-Hant.lproj/Localizable.strings
    ios_native/TATNative/Resources/en.lproj/Localizable.strings
    ios_native/TATNative/Resources/Generated/L10n.swift

Swift 端的名稱與 `R.current.<key>` 相同，兩邊可以直接互查。

ARB 的 `%s` 要換成 `%@`：Swift 的 `%s` 吃的是 C 字串，傳 String 進去會讀到記憶體垃圾。
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ARBS = [
    ("zh-Hant", os.path.join(ROOT, "lib", "l10n", "intl_zh_TW.arb")),
    ("en", os.path.join(ROOT, "lib", "l10n", "intl_en.arb")),
]
RESOURCES = os.path.join(ROOT, "ios_native", "TATNative", "Resources")
SWIFT_OUT = os.path.join(RESOURCES, "Generated", "L10n.swift")

# L10n 的執行期成員（App/Localization.swift），key 不可以和它們同名。
RESERVED = {"tr", "bundle", "use"}
SWIFT_KEYWORDS = {
    "associatedtype", "class", "deinit", "enum", "extension", "fileprivate",
    "func", "import", "init", "inout", "internal", "let", "open", "operator",
    "private", "protocol", "public", "rethrows", "static", "struct",
    "subscript", "typealias", "var", "break", "case", "catch", "continue",
    "default", "defer", "do", "else", "fallthrough", "for", "guard", "if",
    "in", "repeat", "return", "throw", "switch", "where", "while", "as",
    "false", "is", "nil", "self", "Self", "super", "throws", "true", "try",
}

SPEC = re.compile(r"%s")


def load(path):
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    return {k: v for k, v in data.items() if not k.startswith("@")}


def apple_format(value):
    """有參數的字串才走 String(format:)，那時其他的 % 都要跳脫。"""
    if not SPEC.search(value):
        return value
    return "%@".join(part.replace("%", "%%") for part in value.split("%s"))


def escape(value):
    return (value.replace("\\", "\\\\").replace('"', '\\"')
            .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t"))


def render_strings(entries):
    lines = ["/* 產生的檔案，不要手改：python3 tool/gen_ios_l10n.py */", ""]
    for key in sorted(entries):
        lines.append(f'"{escape(key)}" = "{escape(apple_format(entries[key]))}";')
    return "\n".join(lines) + "\n"


def swift_name(key):
    return f"`{key}`" if key in SWIFT_KEYWORDS else key


def doc(value):
    first = value.strip().splitlines()[0] if value.strip() else ""
    return first if len(first) <= 60 else first[:57] + "..."


def render_swift(base):
    out = [
        "// 產生的檔案，不要手改：python3 tool/gen_ios_l10n.py",
        "// swiftlint:disable all",
        "",
        "extension L10n {",
    ]
    for key in sorted(base):
        count = len(SPEC.findall(base[key]))
        out.append(f"  /// {doc(base[key])}")
        if count == 0:
            out.append(f'  static var {swift_name(key)}: String {{ tr("{key}") }}')
        else:
            params = ", ".join(f"_ p{i + 1}: String" for i in range(count))
            args = ", ".join(f"p{i + 1}" for i in range(count))
            out.append(f"  static func {swift_name(key)}({params}) -> String {{ "
                       f'tr("{key}", {args}) }}')
    out.append("}")
    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="只比對，不寫檔")
    args = parser.parse_args()

    tables = [(lang, load(path)) for lang, path in ARBS]
    base_lang, base = tables[0]

    problems = []
    for key in base:
        if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key):
            problems.append(f"{key}：不是合法的 Swift 名稱")
        if key in RESERVED:
            problems.append(f"{key}：和 L10n 的執行期成員同名")
    for lang, table in tables[1:]:
        for key in sorted(set(base) ^ set(table)):
            problems.append(f"{key}：只出現在 {base_lang if key in base else lang}")
        for key in sorted(set(base) & set(table)):
            if len(SPEC.findall(base[key])) != len(SPEC.findall(table[key])):
                problems.append(f"{key}：{base_lang} 與 {lang} 的 %s 數量不同")
    if problems:
        print("ARB 有這些問題，iOS 的字串產不出來：", file=sys.stderr)
        for line in problems:
            print(f"  - {line}", file=sys.stderr)
        return 1

    outputs = {os.path.join(RESOURCES, f"{lang}.lproj", "Localizable.strings"):
               render_strings(table) for lang, table in tables}
    outputs[SWIFT_OUT] = render_swift(base)

    stale = []
    for path, content in outputs.items():
        current = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        if current != content:
            stale.append(path)
    if not stale:
        print(f"已是最新，{len(base)} 個字串")
        return 0
    if args.check:
        print("iOS 的字串與 ARB 不同步：", file=sys.stderr)
        for path in stale:
            print(f"  - {os.path.relpath(path, ROOT)}", file=sys.stderr)
        return 1
    for path in stale:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(outputs[path])
        print(f"已更新 {os.path.relpath(path, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
