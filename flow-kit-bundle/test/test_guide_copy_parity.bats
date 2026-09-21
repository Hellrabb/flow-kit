#!/usr/bin/env bats
# test_guide_copy_parity.bats — 用户指南副本一致性 + deck 新鲜度守护（行为级）
#
# 起因（user-guide-sync-2026-09b · 漂移审计 §0）：
#   《FLOW-KIT-用户指南.md》共有 4 份仓内载体（仓库根 / flow-kit-bundle/ /
#   dist/dsh-flow-kit/docs/ / dist/dsh-flow-kit/vendor/flow-kit-bundle/），
#   但 **root ↔ bundle 这条边没有任何门禁**：2026-09-21 提交 817c0b1 声称同步了指南，
#   实际只改了 bundle 副本 → 四份 md5 分裂为 2 个值，而 `make check` 全绿。
#   （bundle → dist 两条边已由 `package-dsh-plugin.sh --check`（check-dist）逐文件 cmp 守护。）
#
# 本文件的断言策略（对应 AC-10）：
#   ① 真跑比较逻辑（md5 一次性比较），不用"源码里出现过某字符串"这类文本判据；
#   ② dist/ 缺席（fresh clone，被 .gitignore 忽略）时**显式 skip 并打印原因**，
#      root ↔ bundle 这条边**永远执行**；
#   ③ 守护自身必须**非恒绿**：夹具里注入 1 字节漂移 → 比较逻辑必须判定不一致
#      （用例 3/5 用夹具验证，不破坏真实仓库）；
#   ④ 顺带守 deck 新鲜度（改 slides.json 忘重建 pptx 是与 md 副本同构的失效形态），
#      pptx 缺失或 python-pptx 不可用时显式 skip。

# 仓库根解析：兼容两种落点（仓库根 / flow-kit-bundle/test/ 的同源镜像）。
# 找不到真根 → 显式失败（不静默降级成"比较自己"）。
resolve_repo_root() {
  local d="$BATS_TEST_DIRNAME"
  while [ "$d" != "/" ]; do
    if [ -f "$d/package-dsh-plugin.sh" ] && [ -d "$d/.specs/user-guide-deck-gen" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
REPO_ROOT="$(resolve_repo_root || true)"

setup() {
  [ -n "$REPO_ROOT" ] || { echo "❌ 未能定位 flow-kit 仓库根（本守护只应在仓库内或 flow-kit-bundle/test/ 中运行）"; return 1; }
}

GUIDE_NAME="FLOW-KIT-用户指南.md"
COPIES=(
  "$GUIDE_NAME"
  "flow-kit-bundle/$GUIDE_NAME"
  "dist/dsh-flow-kit/docs/$GUIDE_NAME"
  "dist/dsh-flow-kit/vendor/flow-kit-bundle/$GUIDE_NAME"
)

# ── 比较逻辑（唯一真源：用例 1 与夹具用例 3 走同一函数）──
# 存在的副本 < 2 份 → 视为无比较对象（返回 0）；否则要求 md5 唯一值 = 1。
guide_parity_ok() { # <repo-root>
  local root="$1" rel; local -a present=()
  for rel in "${COPIES[@]}"; do
    [ -f "$root/$rel" ] && present+=("$root/$rel")
  done
  # 存在的副本 < 2 份 → 无比较对象（返回 0）；**≥ 2 份就必须比较**
  # 注：dist 缺席（fresh clone）时 present = root + bundle = 2 份 → 走下面的 md5 比较，
  #     root↔bundle 这条边**永远执行**（这正是本 change 要堵的那条边）。
  [ "${#present[@]}" -ge 2 ] || return 0
  [ "$(md5sum "${present[@]}" | awk '{print $1}' | sort -u | wc -l)" -eq 1 ]
}

# 打印不一致的副本对 + 修复命令（失败时给人看的指引）
guide_parity_report() { # <repo-root>
  local root="$1" rel ref f; local -a present=()
  for rel in "${COPIES[@]}"; do
    [ -f "$root/$rel" ] && present+=("$root/$rel")
  done
  [ "${#present[@]}" -ge 2 ] || return 0
  # 基准恒取 **bundle 底稿**（唯一维护源）：根副本漂移时给出的修复命令方向才正确
  # （817c0b1 的漂移形态正是"只改 bundle、根副本落后"）
  local ref="$root/$COPIES[1]"
  [ -f "$ref" ] || ref="${present[0]}"
  for f in "${present[@]}"; do
    [ "$f" = "$ref" ] && continue
    if ! cmp -s "$ref" "$f"; then
      printf 'MISMATCH: %s 🔴 %s\n  修复: cp %s %s\n' "$ref" "$f" "$ref" "$f"
    fi
  done
}

_guide_version_date() { # <指南文件> → YYYY-MM-DD
  grep -m1 '^> 版本:' "$1" | sed -E 's/.*版本:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/'
}
_guide_section_date() { # <指南文件> → YYYY-MM-DD（分节「最后同步日期」）
  grep -m1 '最后同步日期' "$1" | sed -E 's/.*([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/'
}

@test "guide parity: 仓内四份副本（root + bundle + dist×2）md5 唯一值 = 1" {
  cd "$REPO_ROOT"
  run guide_parity_report "$REPO_ROOT"
  if [ "$status" -ne 0 ] || [ -n "$output" ]; then
    printf '%s\n' "$output"
    return 1
  fi
  guide_parity_ok "$REPO_ROOT"
  # dist 缺席（fresh clone）时显式声明跳过范围，避免"看着绿了"
  if [ ! -f "$REPO_ROOT/dist/dsh-flow-kit/docs/$GUIDE_NAME" ]; then
    echo "NOTE: dist/ 缺席（fresh clone）→ 本次只核 root ↔ bundle 这条边（dist 边由 check-dist 覆盖）"
  fi
}

@test "guide parity: 版本日期口径一致（版本行 == 分节日期）且旧版本号清零" {
  cd "$REPO_ROOT"
  local f="$REPO_ROOT/flow-kit-bundle/$GUIDE_NAME"
  [ -f "$f" ] || skip "bundle 副本不存在"
  local vd sd
  vd="$(_guide_version_date "$f")"
  sd="$(_guide_section_date "$f")"
  [ -n "$vd" ] || { echo "版本行缺失或格式不符: $f"; return 1; }
  [ "$vd" = "$sd" ] || { echo "版本行($vd) != 分节最后同步日期($sd)"; return 1; }
  # 旧版本号不得留存
  [ "$(grep -c '20260713\|2026-07-13' "$f")" -eq 0 ] || { echo "旧版本号残留"; return 1; }
  # 2026-09-03 只允许作为「…起」式历史陈述锚点出现（v4.5 · 阶段 5 L3 major：此前只有 verify-ac.sh 断言该规则）
  [ "$(grep -n '2026-09-03' "$f" | grep -vc '起')" -eq 0 ] || { echo "2026-09-03 出现在非历史陈述句"; return 1; }
}

@test "guide parity guard is not vacuously green: 夹具注入 1 字节漂移必须判定不一致" {
  local fx="$BATS_TEST_TMPDIR/parity-fx"
  rm -rf "$fx"; mkdir -p "$fx/flow-kit-bundle" "$fx/dist/dsh-flow-kit/docs" "$fx/dist/dsh-flow-kit/vendor/flow-kit-bundle"
  local rel
  for rel in "${COPIES[@]}"; do printf 'guide body line\n' > "$fx/$rel"; done
  guide_parity_ok "$fx"                       # 基线：四份一致 → 通过
  printf 'x' >> "$fx/flow-kit-bundle/$GUIDE_NAME"   # 注入 1 字节漂移
  ! guide_parity_ok "$fx"                     # 必须判定不一致
  run guide_parity_report "$fx"
  printf '%s\n' "$output" | grep -q 'MISMATCH'  # 且必须指名
}

@test "deck freshness: pptx 页数 == slides.json 页数，封面日期 == 指南版本行日期" {
  cd "$REPO_ROOT"
  local pptx="$REPO_ROOT/flow-kit-用户指南.pptx"
  local slides="$REPO_ROOT/.specs/user-guide-deck-gen/slides.json"
  [ -f "$pptx" ] || skip "pptx 不存在（未生成的 checkout）"
  [ -f "$slides" ] || skip "slides.json 不存在"
  python3 -c "import pptx" 2>/dev/null || skip "python-pptx 不可用"
  local pages expect
  pages="$(python3 -c "from pptx import Presentation; print(len(Presentation('$pptx').slides))")"
  expect="$(python3 -c "import json,sys; print(len(json.load(open('$slides'))))")"
  [ "$pages" -eq "$expect" ] || { echo "pptx 页数($pages) != slides.json 页数($expect) → 请重跑 build.py"; return 1; }
  local cover vd
  cover="$(python3 -c "
from pptx import Presentation
p = Presentation('$pptx')
print(' '.join(sh.text_frame.text for sh in p.slides[0].shapes if sh.has_text_frame))
" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
  vd="$(_guide_version_date "$REPO_ROOT/flow-kit-bundle/$GUIDE_NAME")"
  [ -n "$cover" ] || { echo "封面未找到日期串"; return 1; }
  [ "$cover" = "$vd" ] || { echo "封面日期($cover) != 指南版本行日期($vd)"; return 1; }
  # v4.6 · 阶段 7 L2 R3：渲染抽检物必须比 pptx 新（否则「用旧 PNG 当终态证据」）
  local rp="$REPO_ROOT/.specs/user-guide-sync-2026-09b/render-preview"
  if [ -d "$rp" ]; then
    local stale=0 total=0
    while IFS= read -r png; do
      total=$((total+1))
      [ "$png" -nt "$pptx" ] || stale=$((stale+1))
    done < <(find "$rp" -name '*.png')
    [ "$total" -ge 1 ] || { echo "render-preview 为空"; return 1; }
    [ "$stale" -eq 0 ] || { echo "有 $stale/$total 张 PNG 早于 pptx（请重渲）"; return 1; }
  fi
}

@test "deck freshness guard is not vacuously green: 夹具页数不一致必须判定失败" {
  local fx="$BATS_TEST_TMPDIR/deck-fx"
  rm -rf "$fx"; mkdir -p "$fx"
  python3 - <<PY
import json
json.dump([{"layout": "cover", "title": "t"}], open("$fx/slides.json", "w"))
PY
  python3 -c "import pptx" 2>/dev/null || skip "python-pptx 不可用"
  # 造一个 2 页 pptx 对比 1 页 slides.json → 比较逻辑必须判定不一致
  python3 - <<PY
from pptx import Presentation
p = Presentation()
for _ in range(2):
    p.slides.add_slide(p.slide_layouts[6])
p.save("$fx/deck.pptx")
PY
  local pages expect
  pages="$(python3 -c "from pptx import Presentation; print(len(Presentation('$fx/deck.pptx').slides))")"
  expect="$(python3 -c "import json; print(len(json.load(open('$fx/slides.json'))))")"
  [ "$pages" -ne "$expect" ]
}

@test "installed dsh plugin guide copy cmp-identical when present" {
  local prof="${DSH_PROFILE:-web}"
  local inst="$HOME/.dsh/profiles/$prof/node_modules/dsh-flow-kit"
  [ -d "$inst" ] || skip "profile $prof 未安装 dsh-flow-kit"
  local rel
  for rel in "docs/$GUIDE_NAME" "vendor/flow-kit-bundle/$GUIDE_NAME"; do
    [ -f "$inst/$rel" ] || continue
    [ -f "$REPO_ROOT/dist/dsh-flow-kit/$rel" ] || skip "dist 缺席，无法比较 $rel"
    cmp -s "$REPO_ROOT/dist/dsh-flow-kit/$rel" "$inst/$rel" || {
      echo "已安装副本与 dist 不一致: $inst/$rel → 请跑 make dsh-sync"
      return 1
    }
  done
}

@test "guide parity guard covers the dist-absent path: 只有 root+bundle 两份时注入漂移必须判定不一致" {
  # v4.5 · 阶段 5 L3 major：用**真实指南副本**搭 fresh-clone 布局（不是自造夹具内容），
  # 先证明干净布局下两份真实副本一致 → 通过；再对真实内容注入 1 字节 → 必须检出。
  local fx="$BATS_TEST_TMPDIR/parity-fx-2"
  rm -rf "$fx"; mkdir -p "$fx/flow-kit-bundle"
  cp "$REPO_ROOT/$GUIDE_NAME" "$fx/$GUIDE_NAME"
  cp "$REPO_ROOT/flow-kit-bundle/$GUIDE_NAME" "$fx/flow-kit-bundle/$GUIDE_NAME"
  # 两份一致 → 通过；且不允许早退（必须真的比较过）
  guide_parity_ok "$fx"
  printf 'x' >> "$fx/flow-kit-bundle/$GUIDE_NAME"     # 注入 1 字节漂移
  ! guide_parity_ok "$fx"                              # dist 缺席时同样必须检出
  run guide_parity_report "$fx"
  printf '%s\n' "$output" | grep -q 'MISMATCH'
}

@test "deck content parity: deck_checks 全部断言生效 + slides.json 每页标题都出现在 pptx 文本中" {
  cd "$REPO_ROOT"
  local pptx="$REPO_ROOT/flow-kit-用户指南.pptx"
  local slides="$REPO_ROOT/.specs/user-guide-deck-gen/slides.json"
  [ -f "$pptx" ] || skip "pptx 不存在（未生成的 checkout）"
  [ -f "$slides" ] || skip "slides.json 不存在"
  python3 -c "import pptx" 2>/dev/null || skip "python-pptx 不可用"
  # ① 把 deck_checks.py 的**全部**断言接进门禁链（页数 / 禁词 / 关键串 / by_title 专页 / 封面 / 逐页非空）
  #    此前它不在任何门禁里 —— 阶段 2 L2 第四轮 R23 指出该覆盖缺口。
  run python3 "$REPO_ROOT/.specs/user-guide-deck-gen/deck_checks.py"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output"; return 1; }
  # ② title 级内容一致性：slides.json 的每页标题必须能在 pptx 文本中找到（改标题不重建 → 必红）
  local py="$BATS_TEST_TMPDIR/deck_title_parity.py"
  cat > "$py" <<'PYCODE'
import json, sys
from pptx import Presentation
pptx, slides = sys.argv[1], sys.argv[2]
titles = [s.get("title", "") for s in json.load(open(slides, encoding="utf-8"))]
prs = Presentation(pptx)
text = "\n".join(sh.text_frame.text for sl in prs.slides for sh in sl.shapes if sh.has_text_frame)
missing = [t for t in titles if t and t not in text]
print(f"titles={len(titles)} missing={len(missing)}")
for t in missing:
    print("MISSING:", t)
sys.exit(1 if missing else 0)
PYCODE
  run python3 "$py" "$pptx" "$slides"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output"; return 1; }
}

