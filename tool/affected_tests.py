#!/usr/bin/env python3
"""列出「這次改動會影響到的測試檔」，讓開發中的迴圈不必每次都跑完整套。

用法:
    puro flutter test $(python3 tool/affected_tests.py)          # 對照 HEAD 的改動
    python3 tool/affected_tests.py --base develop                # 對照別的 ref
    python3 tool/affected_tests.py --files lib/a.dart lib/b.dart # 自己指定
    python3 tool/affected_tests.py --verbose                     # 附上為什麼被選中

判準是 import 可達性：測試檔 T 直接或間接 import 到被改的 lib 檔案就要跑。
解析方式與 tool/deps.py 相同（同一條 IMPORT_RE、同一種 package:/相對路徑解析）。

Dart 沒有反射，import 圖因此是很準的近似，但**它不是全部**：資產、產生物、
ARB、pubspec 這些不是 import 進去的，所以另外用 EXTRA_TRIGGERS 補。真正的
安全網仍然是「收尾前跑一次完整套」——這支工具是給開發中的快迴圈用的，
不是拿來取代最後那一次。
"""
import argparse
import os
import re
import subprocess
import sys
from collections import defaultdict

PKG = "flutter_app"
IMPORT_RE = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.M)
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 不是靠 import 相連、但改了就得跑的東西。key 是改動路徑的前綴，
# value 是要一起跑的測試路徑前綴。
EXTRA_TRIGGERS = [
    ("lib/l10n/", ["test/l10n/"]),
    ("lib/generated/", ["test/l10n/"]),
    ("assets/image/files/", ["test/util/file_icon_utils_test.dart",
                             "test/ui/file_type_icon_test.dart"]),
    ("assets/fonts/", ["test/ui/file_type_icon_test.dart"]),
    ("android/", ["test/android/"]),
    ("ios/", ["test/ios/"]),
]

# 改了這些就沒有可靠的縮小依據，提醒去跑完整套。
FULL_RUN_HINTS = ("pubspec.yaml", "pubspec.lock", "analysis_options.yaml")


def dart_files(*roots):
    out = []
    for root in roots:
        for dirpath, _, names in os.walk(os.path.join(REPO, root)):
            for n in names:
                if n.endswith(".dart"):
                    out.append(os.path.relpath(os.path.join(dirpath, n), REPO))
    return sorted(out)


def build_imports(files):
    known = set(files)
    graph = defaultdict(set)
    for f in files:
        try:
            src = open(os.path.join(REPO, f), encoding="utf-8").read()
        except OSError:
            continue
        here = os.path.dirname(f)
        for uri in IMPORT_RE.findall(src):
            if uri.startswith(f"package:{PKG}/"):
                target = "lib/" + uri[len(f"package:{PKG}/"):]
            elif ":" in uri:
                continue
            else:
                target = os.path.normpath(os.path.join(here, uri))
            if target in known and target != f:
                graph[f].add(target)
    return graph


def reachable(start, graph, depth=None):
    """從 [start] 沿 import 走得到的檔案。[depth] 限制層數，None 是不限。"""
    seen, frontier, level = set(), {start}, 0
    while frontier and (depth is None or level < depth):
        nxt = {b for a in frontier for b in graph.get(a, ()) if b not in seen}
        seen |= nxt
        frontier = nxt
        level += 1
    return seen


def changed_files(base):
    def run(*args):
        return subprocess.run(args, cwd=REPO, capture_output=True, text=True).stdout.split()
    out = set(run("git", "diff", "--name-only", base))
    out |= set(run("git", "diff", "--name-only", "--cached", base))
    out |= set(run("git", "ls-files", "--others", "--exclude-standard"))
    return {p for p in out if os.path.exists(os.path.join(REPO, p))}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", default="HEAD", help="對照哪個 ref（預設 HEAD）")
    ap.add_argument("--files", nargs="*", help="直接指定改動的檔案")
    ap.add_argument("--verbose", action="store_true", help="印出選中的理由")
    ap.add_argument("--depth", type=int, default=None,
                    help="只往上追這麼多層 import（1 = 只有直接 import 的測試）。"
                         "預設不限，也就是傳遞相依全算。")
    args = ap.parse_args()

    changed = set(args.files) if args.files else changed_files(args.base)
    if not changed:
        return 0

    # 只有 *_test.dart 跑得起來；helper 仍在圖裡，只是不輸出。
    tests = [t for t in dart_files("test") if t.endswith("_test.dart")]
    graph = build_imports(dart_files("lib", "test"))
    # lib 與 test 都放進來：改到 test/helpers 的那種共用檔案，
    # 靠 import 圖就挑得出真正受影響的測試，不必整包重跑。
    changed_dart = {c for c in changed
                    if c.endswith(".dart")
                    and (c.startswith("lib/") or c.startswith("test/"))}

    selected, why = set(), {}
    for t in tests:
        if t in changed:
            selected.add(t)
            why[t] = "測試檔本身被改"
            continue
        hit = changed_dart & reachable(t, graph, args.depth)
        if hit:
            selected.add(t)
            why[t] = "import 到 " + ", ".join(sorted(hit)[:3])

    for prefix, test_prefixes in EXTRA_TRIGGERS:
        if not any(c == prefix or c.startswith(prefix) for c in changed):
            continue
        for t in tests:
            if any(t == tp or t.startswith(tp) for tp in test_prefixes):
                if t not in selected:
                    selected.add(t)
                    why[t] = f"{prefix} 改了（非 import 相依）"

    if any(c in FULL_RUN_HINTS for c in changed):
        print("# 注意：" + "/".join(FULL_RUN_HINTS[:2]) +
              " 改過了，縮小範圍不可靠，收尾請跑完整套。", file=sys.stderr)

    for t in sorted(selected):
        print(f"{t}\t# {why[t]}" if args.verbose else t)
    if args.verbose:
        print(f"\n# {len(selected)} / {len(tests)} 個測試檔",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
