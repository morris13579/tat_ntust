#!/usr/bin/env python3
"""從 Moodle 官方 App 的對照表產生 lib/src/util/file_icon_table.dart。

用法:
    python3 tool/gen_file_icon_table.py                # moodlehq/moodleapp 的 main
    python3 tool/gen_file_icon_table.py --ref <ref>    # 指定 tag / branch / commit
    python3 tool/gen_file_icon_table.py --source DIR   # 本機的 exttomime.json、mimetoext.json

規則照官方 App 的 CoreMimetype（src/core/static/mimetype.ts）：
- 副檔名有 icon 就用；沒有、但 MIME 主類型是 video/text/image/document/audio
  就用主類型當 icon 名稱。
- MIME 取其副檔名清單中第一個解析得出 icon 的。
只保留解析得出、且不是 unknown 的項目。產出後要跑 `dart format`。
"""
import argparse
import json
import os
import sys
import urllib.request

REPO = "moodlehq/moodleapp"
FILES = ("exttomime.json", "mimetoext.json")
INFERRED_TYPES = {"video", "text", "image", "document", "audio"}
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "lib", "src", "util", "file_icon_table.dart")


def fetch(url):
    with urllib.request.urlopen(url, timeout=30) as resp:
        return resp.read().decode("utf-8")


def load_remote(ref):
    data = {}
    for name in FILES:
        url = f"https://raw.githubusercontent.com/{REPO}/{ref}/src/assets/{name}"
        data[name] = json.loads(fetch(url))
    try:
        rev = json.loads(fetch(f"https://api.github.com/repos/{REPO}/commits/{ref}"))["sha"]
    except Exception:
        rev = ref
    return data, rev


def load_local(source):
    data = {}
    for name in FILES:
        with open(os.path.join(source, name), encoding="utf-8") as f:
            data[name] = json.load(f)
    return data, f"local copy in {source}"


def icon_for_extension(ext_to_mime, ext):
    info = ext_to_mime.get(ext)
    if not info:
        return None
    if info.get("icon"):
        return info["icon"]
    main_type = info.get("type", "").split("/")[0]
    return main_type if main_type in INFERRED_TYPES else None


def build_tables(ext_to_mime, mime_to_ext):
    by_ext = {}
    for ext in ext_to_mime:
        icon = icon_for_extension(ext_to_mime, ext)
        if icon and icon != "unknown":
            by_ext[ext] = icon

    by_mime = {}
    for mime, exts in mime_to_ext.items():
        for ext in exts:
            icon = icon_for_extension(ext_to_mime, ext)
            if icon:
                if icon != "unknown":
                    by_mime[mime] = icon
                break
    return by_ext, by_mime


def dart_string(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def emit(by_ext, by_mime, rev):
    lines = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND",
        "// 由 tool/gen_file_icon_table.py 產生，來源",
        f"// https://github.com/{REPO} @ {rev}",
        "// src/assets/exttomime.json 與 src/assets/mimetoext.json（Apache-2.0）。",
        "",
        "/// 副檔名與 MIME type → assets/image/files/<名稱>.svg 的名稱；",
        "/// 查表邏輯在 FileIconUtils。",
        "abstract final class FileIconTable {",
        "  FileIconTable._();",
        "",
        f"  /// 副檔名（小寫、不含點）→ icon 名稱，{len(by_ext)} 筆。",
        "  static const Map<String, String> byExtension = {",
    ]
    for ext in sorted(by_ext):
        lines.append(f"    {dart_string(ext)}: {dart_string(by_ext[ext])},")
    lines += [
        "  };",
        "",
        f"  /// MIME type（小寫、不含參數）→ icon 名稱，{len(by_mime)} 筆。",
        "  static const Map<String, String> byMimetype = {",
    ]
    for mime in sorted(by_mime):
        lines.append(f"    {dart_string(mime)}: {dart_string(by_mime[mime])},")
    lines += ["  };", "}", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--ref", default="main", help="moodleapp 的 branch / tag / commit")
    parser.add_argument("--source", help="本機目錄，內含 exttomime.json 與 mimetoext.json")
    parser.add_argument("--out", default=OUT, help="輸出的 Dart 檔路徑")
    args = parser.parse_args()

    if args.source:
        data, rev = load_local(args.source)
    else:
        data, rev = load_remote(args.ref)

    by_ext, by_mime = build_tables(data["exttomime.json"], data["mimetoext.json"])
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(emit(by_ext, by_mime, rev))
    icons = sorted(set(by_ext.values()) | set(by_mime.values()))
    print(f"wrote {os.path.relpath(args.out)}: {len(by_ext)} extensions, "
          f"{len(by_mime)} mimetypes, icons: {' '.join(icons)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
