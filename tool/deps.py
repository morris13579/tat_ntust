#!/usr/bin/env python3
"""lib/ 的匯入相依度量，用來守住分層重構的成果。

用法:
    python3 tool/deps.py                 # 印出報告
    python3 tool/deps.py --check         # CI 模式，違規時以非零結束

CI 模式檢查四件事：

1. **不得有任何上行邊。** MAX_UPWARD_EDGES 是 0，多出任何一條都會失敗。
2. **跨層強連通分量中不得有非 UI 檔案。** lib/ui 內部 route_utils 與各頁面
   互相 import 是固有的環，接受它存在；但 connector、store、util、model
   之間不該有環。門檻也是 0。
3. **最大強連通分量的大小只能降不能升**（棘輪）。門檻寫在 MAX_SCC，
   降下來之後要順手把數字改小，這樣才擋得住回流。
4. **lib/debug/ 必須是葉節點。** 它排在所有層之下（讓任何一層都能記 log），
   那個特權的前提是它自己不依賴專案裡的其他東西。見 check_log_is_a_leaf。

分層的設計理由見 docs/ARCHITECTURE.md。
"""
import os
import re
import sys
from collections import defaultdict

PKG = "flutter_app"
IMPORT_RE = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.M)

# 棘輪門檻：最大 SCC 允許的檔案數。只能往下調。
MAX_SCC = 25

# 棘輪門檻：允許卡在跨層環裡的非 UI 檔案數。只能往下調。
# lib/ui 內部的環是固有的（route_utils 與各頁面互相 import），不計入。
MAX_NON_UI_IN_CYCLE = 0

# 棘輪門檻：允許的上行邊總數。只能往下調。
#
# 這是這份工具唯一直接指名「哪一條 import 違反分層」的指標。放寬門檻等於默許
# controller -> ui、connector -> task 這種相依悄悄長回來，所以維持 0。
MAX_UPWARD_EDGES = 0

# 個別層級配對的上限。同樣只能往下調。
# 拆到配對層級是因為總數持平也可能是「補了一條 connector -> task、
# 剛好又刪掉一條 controller -> ui」，那不是進步。
#
# 空的：任何一條上行邊都會失敗，不論種類。
MAX_UPWARD_BY_PAIR = {}

# rank 越小代表越上層。A -> B 若 rank(B) < rank(A) 就是上行邊。
LAYER_RULES = [
    ("lib/main.dart", "main"),
    ("lib/firebase_options.dart", "config"),
    ("lib/src/R.dart", "config"),
    ("lib/ui/", "ui"),
    ("lib/src/controller/", "controller"),
    ("lib/src/repository/", "repository"),
    ("lib/src/auth/", "auth"),
    ("lib/src/connector/", "connector"),
    ("lib/src/store/", "store"),
    ("lib/src/util/", "util"),
    ("lib/src/file/", "util"),
    ("lib/src/service/", "util"),
    ("lib/src/version/", "util"),
    ("lib/src/providers/", "util"),
    ("lib/debug/", "log"),
    ("lib/src/config/", "config"),
    ("lib/src/model/", "model"),
    ("lib/src/enum/", "model"),
    ("lib/generated/", "generated"),
    ("lib/l10n/", "generated"),
]
# store 排在 util 之下：store 是「可被 util 讀取的
# 底層」，所以 LanguageUtils、AppService 這類讀 Model.instance 的邊是合法的。
# 小數是刻意的：repository 插在 controller 與 task 之間、auth 插在 task 與
# connector 之間，既有層級的相對順序完全不動，報表不會因為改編號而變。
# repository 排在 task 上面，所以 repository -> task 會被標成上行邊，
# 那正是要擋的方向。
RANK = {"main": 0, "ui": 1, "controller": 2, "repository": 2.5, "task": 3,
        "auth": 3.5, "connector": 4, "util": 5, "store": 6, "config": 7,
        "model": 8, "generated": 9, "log": 10}

# log 排在最底下，比 generated 還低。
#
# Log 是每一層都會用到的橫切關注點——main、auth、connector、controller、
# repository、service、store、util、version、ui 全都 import 它——而它自己不
# import flutter_app 底下的任何東西（除了同目錄的 console_output）。
# 把它排成 util 等於宣告「util 以下的層不准記 log」，那條規則沒有人訂過。
#
# 這個特權是**有條件的**，由 check_log_is_a_leaf() 在每次檢查時驗證：
# 只要 lib/debug/ 哪天 import 了自己以外的專案檔案，這個排名就不再正當，
# 那時 CI 會直接失敗，而不是安靜地放行。


def layer_of(path):
    for prefix, layer in LAYER_RULES:
        if path == prefix or path.startswith(prefix):
            return layer
    return "unknown"


def build_graph(repo):
    lib = os.path.join(repo, "lib")
    files = []
    for root, _, names in os.walk(lib):
        for n in names:
            if n.endswith(".dart"):
                files.append(os.path.relpath(os.path.join(root, n), repo))
    files.sort()
    known = set(files)

    graph = defaultdict(set)
    for f in files:
        try:
            src = open(os.path.join(repo, f), encoding="utf-8").read()
        except OSError:
            continue
        here = os.path.dirname(f)
        for uri in IMPORT_RE.findall(src):
            if uri.startswith(f"package:{PKG}/"):
                target = "lib/" + uri[len(f"package:{PKG}/"):]
            elif ":" in uri:
                continue  # 外部套件或 dart: 內建
            else:
                target = os.path.normpath(os.path.join(here, uri))
            if target in known and target != f:
                graph[f].add(target)
    return files, graph


def tarjan(files, graph):
    index = {}
    low = {}
    on_stack = {}
    stack = []
    counter = [0]
    out = []

    def strongconnect(v):
        work = [(v, iter(sorted(graph.get(v, ()))))]
        index[v] = low[v] = counter[0]
        counter[0] += 1
        stack.append(v)
        on_stack[v] = True
        while work:
            node, it = work[-1]
            advanced = False
            for w in it:
                if w not in index:
                    index[w] = low[w] = counter[0]
                    counter[0] += 1
                    stack.append(w)
                    on_stack[w] = True
                    work.append((w, iter(sorted(graph.get(w, ())))))
                    advanced = True
                    break
                if on_stack.get(w):
                    low[node] = min(low[node], index[w])
            if advanced:
                continue
            work.pop()
            if work:
                low[work[-1][0]] = min(low[work[-1][0]], low[node])
            if low[node] == index[node]:
                comp = []
                while True:
                    w = stack.pop()
                    on_stack[w] = False
                    comp.append(w)
                    if w == node:
                        break
                if len(comp) > 1:
                    out.append(sorted(comp))

    for f in files:
        if f not in index:
            strongconnect(f)
    return sorted(out, key=len, reverse=True)


def check_log_is_a_leaf(graph):
    """log 層排在最底下的前提：它不依賴 lib/ 底下的任何其他東西。

    回傳違規的邊；空清單代表前提成立。
    """
    bad = []
    for src, dsts in graph.items():
        if layer_of(src) != "log":
            continue
        for dst in dsts:
            if layer_of(dst) != "log":
                bad.append((src, dst))
    return sorted(bad)


def main():
    repo = os.getcwd()
    check = "--check" in sys.argv
    files, graph = build_graph(repo)
    edges = sum(len(v) for v in graph.values())

    upward = defaultdict(list)
    for a, targets in graph.items():
        la = layer_of(a)
        for b in targets:
            lb = layer_of(b)
            if la in RANK and lb in RANK and RANK[lb] < RANK[la]:
                upward[f"{la} -> {lb}"].append((a, b))

    comps = tarjan(files, graph)
    max_scc = len(comps[0]) if comps else 0
    # lib/ui 內部的環是固有的（route_utils 與各頁面互相 import），只看非 UI 檔案
    offenders = sorted({f for c in comps for f in c if not f.startswith("lib/ui/")})

    print(f"files: {len(files)}  edges: {edges}")
    print(f"max SCC: {max_scc} (門檻 {MAX_SCC})")
    print(f"跨層 SCC 中的非 UI 檔案: {len(offenders)} (門檻 {MAX_NON_UI_IN_CYCLE})")
    print()
    total_upward = sum(len(v) for v in upward.values())
    print(f"上行邊: {total_upward} 條 (門檻 {MAX_UPWARD_EDGES})")
    if not upward:
        print("  (無)")
    for pair in sorted(upward, key=lambda k: -len(upward[k])):
        print(f"  {pair}: {len(upward[pair])}")
        if not check:
            for a, b in sorted(upward[pair]):
                print(f"      {a} -> {b}")
    if offenders and not check:
        print()
        print("跨層 SCC 中的非 UI 檔案:")
        for f in offenders:
            print(f"  {f}  [{layer_of(f)}]")

    if not check:
        return 0

    failed = False
    leaks = check_log_is_a_leaf(graph)
    if leaks:
        print("\nFAIL: lib/debug/ 依賴了自己以外的專案檔案，"
              "log 層排在最底下的前提不再成立：")
        for a, b in leaks:
            print(f"      {a} -> {b}")
        print("      要嘛把那個相依拿掉，要嘛把 lib/debug/ 移回一般的層級"
              "（見 RANK 旁的說明）。")
        failed = True
    if max_scc > MAX_SCC:
        print(f"\nFAIL: 最大 SCC {max_scc} 超過門檻 {MAX_SCC}（棘輪只能降不能升）")
        failed = True
    if total_upward > MAX_UPWARD_EDGES:
        print(f"\nFAIL: 上行邊 {total_upward} 條超過門檻 {MAX_UPWARD_EDGES}"
              f"（棘輪只能降不能升）")
        print("執行 python3 tool/deps.py 看是哪幾條。")
        failed = True
    for pair, limit in sorted(MAX_UPWARD_BY_PAIR.items()):
        actual = len(upward.get(pair, ()))
        if actual > limit:
            print(f"\nFAIL: {pair} 有 {actual} 條，超過門檻 {limit}")
            failed = True
    for pair in sorted(upward):
        if pair not in MAX_UPWARD_BY_PAIR:
            print(f"\nFAIL: 出現新的上行邊種類 {pair}（{len(upward[pair])} 條）。")
            print("      新的跨層方向必須是刻意的決定，不能默默長出來。")
            print("      確定要接受就把它加進 tool/deps.py 的 MAX_UPWARD_BY_PAIR。")
            failed = True
    if len(offenders) > MAX_NON_UI_IN_CYCLE:
        print(f"\nFAIL: 跨層環內的非 UI 檔案 {len(offenders)} 超過門檻 "
              f"{MAX_NON_UI_IN_CYCLE}（棘輪只能降不能升）")
        print("執行 python3 tool/deps.py 看是哪些檔案。")
        failed = True
    elif offenders:
        print(f"\n注意: 仍有 {len(offenders)} 個非 UI 檔案在跨層環內。")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
