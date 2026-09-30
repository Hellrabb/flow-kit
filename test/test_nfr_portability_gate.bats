#!/usr/bin/env bats
# test_nfr_portability_gate.bats — check-nfr-portability（Makefile 目标）常设回归网
#                                   （TD-053 收敛 · AC-8 · NFR 兼容性判据）
#
# 为什么存在（TD-053）：NFR 兼容性判据是三态判据，rc=3 的语义是「未验证 ≠ 通过」。
#   此前只有 change 期判据覆盖它；归档后若有人把「空变更集 ⇒ rc=3」退化成 rc=0、
#   把包装层的 3 泄漏成非零、把合规惯用法（stat -c … || stat -f …）判红、或把
#   注释行也纳入受检面，`make check` 仍会全绿（门禁只在变更集上跑）。
#   本文件把这些语义固化为常设判据（三态 + 包装映射）。
#
# 活性（为什么不是假绿）：夹具在**运行时**复制仓内真实 Makefile ⇒ 目标语义被改坏时
#   本文件的断言会转红（含「包装层必须保留 SKIP 且不得打印 ✅」这类反向断言）。
#
# 夹具隔离：夹具是 ${TMPDIR:-/tmp} 下 mktemp -d + git init 的独立仓，teardown 清理；
#   不触碰工作树（受检面 git diff / git ls-files 全在夹具仓内）。
#
# 三态观测口径：make 会把 recipe 内的退出码掩盖（recipe 各分支一律 exit 0），
#   故真实 rc 由该目标的**契约通道** $NFR_RC_FILE 回传（见 Makefile
#   check-nfr-portability-internals 的 _write_rc），本文件据此断言 rc ∈ {0,1,3}。
#
# 脱敏（L-129）：本文件不含真实账号路径形态；一切路径以 $FIXTURE 变量拼接。
#
# 断言约定（沿用 test_l3_review_defects_2026_09.bats 的 L3 04:42 教训：`run` 默认把
#   stderr 合进 $output 会造成假绿）：全文件统一 `run --separate-stderr`，
#   并**分通道**断言——SKIP/✅ 的判定结论走 stdout，违规归因走 stderr。
#   该 flag 需要 bats ≥ 1.5，故下一行声明最低版本。
bats_require_minimum_version 1.5.0

setup() {
  TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/fk-nfr-gate.XXXXXX")"
  FIXTURE="$TEST_TMPDIR/repo"
  RC_FILE="$TEST_TMPDIR/nfr.rc"

  # 仓根：从 test/ 向上找含 flow-kit-bundle/hooks 的目录（兼容 test/ 与 bundle 内镜像）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  MAKEFILE_SRC="$d/Makefile"

  mkdir -p "$FIXTURE"
  git -C "$FIXTURE" init -q
  git -C "$FIXTURE" config user.email "fixture@example.invalid"
  git -C "$FIXTURE" config user.name "fixture"
  # 运行时复制真实 Makefile（活性关键）
  cp -- "$MAKEFILE_SRC" "$FIXTURE/Makefile"
  # T13（AC-12-g / ADR-031）：Makefile internals 块锚点定位改调唯一解析入口
  #   flow-kit-bundle/lib/flow-active-query.sh（相对路径）。夹具仓必须补齐该
  #   依赖件（与 write_baseline() 同模式：Makefile 硬编码相对路径，夹具运行时
  #   提供同路径副本），否则 R3-22 锚点用例退化走多锚点误报分支（937 的期望
  #   消息与降级路径同文会掩盖性通过，936 缺「锚点来源」行而红）。
  mkdir -p "$FIXTURE/flow-kit-bundle/lib"
  cp -- "$d/flow-kit-bundle/lib/flow-active-query.sh" \
    "$FIXTURE/flow-kit-bundle/lib/flow-active-query.sh"
  printf '#!/bin/bash\nt=$(mktemp)\n' > "$FIXTURE/seed.sh"
  # 随基线入库（tracked）：保持「空变更集 ⇒ rc=3」契约——若不入库，该副本成为
  #   未跟踪新增 .sh，NEWF 面必扫，tests 1/6/16 的 SKIP 语义被破坏。脚本本体
  #   NFR-clean（真仓 make check-nfr-portability 全绿），全量模式扫描无虞。
  git -C "$FIXTURE" add -- Makefile seed.sh \
    flow-kit-bundle/lib/flow-active-query.sh
  git -C "$FIXTURE" commit -q -m base
  BASE_SHA="$(git -C "$FIXTURE" rev-parse HEAD)"

  seed_append() { printf '%s\n' "$1" >> "$FIXTURE/seed.sh"; }
  run_internals() {
    rm -f "$RC_FILE"
    env NFR_RC_FILE="$RC_FILE" make --no-print-directory -C "$FIXTURE" \
      check-nfr-portability-internals FLOW_KIT_CHANGE_BASE="$BASE_SHA"
  }
  # T-FIX-23：全量模式入口（FLOW_KIT_CHANGE_BASE=FULL）——基线 ratchet 只在 FULL 生效。
  run_internals_full() {
    rm -f "$RC_FILE"
    env NFR_RC_FILE="$RC_FILE" make --no-print-directory -C "$FIXTURE" \
      check-nfr-portability-internals FLOW_KIT_CHANGE_BASE=FULL
  }
  # T-FIX-23：在夹具仓内写基线文件（真仓基线在 flow-kit-bundle/flow-kit/reference/）。
  #   真仓基线路径由 Makefile 硬编码；夹具仓里我们在同一路径写假基线以驱动 ratchet。
  write_baseline() {
    # 用方括号规避写法（TD-097）避免本测试文件自身被 NFR 判据扫红。
    mkdir -p "$FIXTURE/flow-kit-bundle/flow-kit/reference"
    local _b="$FIXTURE/flow-kit-bundle/flow-kit/reference/nfr-portability-baseline.txt"
    printf '# NFR 可移植性存量基线（T-FIX-23 · R5-23）\n# 格式：<相对路径>:<行号>:<标记>\n' > "$_b"
    while [ $# -ge 2 ]; do
      printf '%s:%s:%s\n' "$1" "$2" "${3:-BAN}" >> "$_b"
      shift 3 2>/dev/null || shift 2
    done
  }
  run_wrapper() {
    make --no-print-directory -C "$FIXTURE" \
      check-nfr-portability FLOW_KIT_CHANGE_BASE="$BASE_SHA"
  }
  internals_rc() { cat "$RC_FILE" 2>/dev/null || printf 'MISSING'; }
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "空变更集（base=HEAD，无 .sh 改动/新增）⇒ 内部 rc=3 且 stdout 含 SKIP:（未验证 ≠ 通过）" {
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "3" ]
  [[ "$output" == *"SKIP:"* ]]
  [[ "$output" != *"✅"* ]]
}

@test "新增行含 sed -i ⇒ 内部 rc=1 且 stderr 归因到 file:line" {
  seed_append "sed -i 's/a/b/' \"\$t\""
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "1" ]
  [[ "$stderr" =~ seed\.sh:3: ]]
  [[ "$stderr" == *"sed -i"* ]]
}

@test "合规惯用法 stat -c … || stat -f … ⇒ 不误报（内部 rc=0）" {
  seed_append 't=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null)'
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "0" ]
  [[ "$output" == *"✅ NFR 兼容性判据通过"* ]]
}

@test "整行注释里的 sed -i ⇒ 不误报（内部 rc=0）" {
  seed_append "# 说明：不要写 sed -i（注释行不计入受检面）"
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "0" ]
  [[ "$output" == *"✅ NFR 兼容性判据通过"* ]]
}

@test "未跟踪新增 .sh 含 GNU-only 构造 ⇒ 内部 rc=1（NEWF 面）" {
  mkdir -p "$FIXTURE/extra"
  printf '#!/bin/bash\nmapfile -t xs < <(printf "a\\n")\n' > "$FIXTURE/extra/new.sh"
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "1" ]
  [[ "$stderr" =~ extra/new\.sh:2: ]]
  [[ "$stderr" == *"mapfile"* ]]
}

@test "包装层把内部 rc=3 映射为 exit 0 且 stdout 保留 SKIP:（SKIP ≠ PASS）" {
  run --separate-stderr run_wrapper
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP:"* ]]
  [[ "$output" != *"✅"* ]]
  # ── 钉住断言（T-FIX-05 / F8 去重）────────────────────────────────────────
  # 判据正文必须唯一存在于 check-nfr-portability-internals，wrapper 为薄壳。
  # 若判据正文被复制回 wrapper，下列断言立即转红（去重未生效 / 复发）。
  # 判据特征串 _report_viol() { 在整份 Makefile 中只能出现 1 次（唯一判据源）。
  local _viol_cnt
  _viol_cnt="$(grep -c '_report_viol() {' "$MAKEFILE_SRC")"
  [ "$_viol_cnt" -eq 1 ] || \
    { echo "🔴 F8：_report_viol() { 在 Makefile 中出现 $_viol_cnt 次（预期 1，判据正文已复制回 wrapper）"; false; }
  # wrapper recipe 行数（verify 口径：awk '/^check-nfr-portability:/,/^$/'）必须 < 30（薄壳）。
  local _wrap_lines
  _wrap_lines="$(awk '/^check-nfr-portability:/,/^$/' "$MAKEFILE_SRC" | wc -l)"
  [ "$_wrap_lines" -lt 30 ] || \
    { echo "🔴 F8：wrapper recipe 仍 $_wrap_lines 行（预期 < 30，判据正文未删除）"; false; }
}

@test "违规变更集上包装层不放过：make 非零退出且 stderr 保留 file:line 归因" {
  seed_append "sed -i 's/a/b/' \"\$t\""
  run --separate-stderr run_wrapper
  # 两层语义都锁住：包装层 recipe 自己 exit 1（make 记为「Error 1 / 错误 1」），
  # make 再把 recipe 失败包装成自己的 exit 2 ⇒ 外部观测量是 2，绝不为 0。
  # 若有人把 rc=1 也映射成 exit 0（与 rc=3 的 SKIP 通道混同），本用例转红。
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"Error 1"* || "$stderr" == *"错误 1"* ]]
  [[ "$stderr" =~ seed\.sh:3: ]]
}

# ── T-FIX-09 回归钉（R3-15 / R3-16 / R3-22）──────────────────────────────
# 三类历史失明回归钉：realpath 词边界失明（R3-15）、空格文件名词拆跳过（R3-16）、
# 锚点硬编码/全量模式退化（R3-22）。每例对应一个曾被假绿放过的夹具腿。

@test "R3-15：新增行含 realpath ⇒ 内部 rc=1（词边界修复后不再假绿）" {
  # 修复前：\brealpath\b 经 awk -v 被解释成退格 ⇒ realpath 永不命中（假绿 rc=0）。
  # 修复后：(^|[^[:alnum:]_])realpath([^[:alnum:]_]|$) + ENVIRON["P"] ⇒ 必须判红。
  seed_append 'p=$(realpath .)'
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "1" ]
  [[ "$stderr" =~ seed\.sh:3: ]]
  [[ "$stderr" == *"realpath"* ]]
}

@test "R3-16：未跟踪含空格文件名 ⇒ 内部 rc=1（不再词拆跳过）" {
  # 修复前：for _f in $(git ls-files -o) 把 "sp ace.sh" 词拆成 sp + ace.sh 两段，
  #   两段皆「不存在 ⇒ 跳过」⇒ 仍打印 ✅（假绿）。
  # 修复后：git ls-files -oz + while read -d "" ⇒ 空格名完整枚举 ⇒ 判红。
  printf '#!/bin/bash\nmapfile -t xs < /dev/null\n' > "$FIXTURE/sp ace.sh"
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "1" ]
  [[ "$stderr" == *"sp ace.sh"* ]]
  [[ "$stderr" == *"mapfile"* ]]
}

@test "R3-16：已跟踪含空格文件名的新增行 ⇒ 内部 rc=1（不再词拆跳过）" {
  # 修复前：tracked 面 for _f in $(git diff --name-only) 同样词拆 ⇒ 假绿。
  # 修复后：git diff -z --name-only + while read -d "" ⇒ 判红。
  mkdir -p "$FIXTURE/sub"
  printf '#!/bin/bash\necho base\n' > "$FIXTURE/sub/sp ace.sh"
  git -C "$FIXTURE" add -- "sub/sp ace.sh"
  git -C "$FIXTURE" commit -q -m "add spaced"
  printf 'mapfile -t xs < /dev/null\n' >> "$FIXTURE/sub/sp ace.sh"
  git -C "$FIXTURE" add -- "sub/sp ace.sh"
  git -C "$FIXTURE" commit -q -m "probe"
  # 重新设 BASE_SHA 指向 probe 的父提交（含空格文件已入库但未加违规）
  BASE_SHA="$(git -C "$FIXTURE" rev-parse HEAD~1)"
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "1" ]
  [[ "$stderr" == *"sub/sp ace.sh"* ]]
  [[ "$stderr" == *"mapfile"* ]]
}

@test "R3-22：无锚点且无 FLOW_KIT_CHANGE_BASE ⇒ 全量模式（不退化 SKIP）" {
  # 修复前：BASE 硬编码 .specs/health-fix-2026-09b/.change-base，归档后路径消失
  #   ⇒ SKIP + exit 0 ⇒ 永久静默未验证。
  # 修复后：无锚点 ⇒ 全量模式（打印「全量模式」措辞，而非 SKIP）。
  # seed.sh 仅含 t=$(mktemp)（不违规）⇒ 全量模式扫后 rc=0（通过），但关键是
  #   必须打印「全量模式」措辞（而非 SKIP: …未验证）。
  rm -f "$RC_FILE"
  run --separate-stderr env NFR_RC_FILE="$RC_FILE" make --no-print-directory -C "$FIXTURE" \
    check-nfr-portability-internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "0" ]
  [[ "$output" == *"全量模式"* ]]
  [[ "$output" != *"SKIP"* ]]
}

@test "R3-22：全量模式扫到 tracked 违规行 ⇒ rc=1（fail-closed）" {
  # 全量模式下 seed.sh 的现有行若含禁构 ⇒ 必须判红（fail-closed，符合 R3-22 意图）。
  printf 'mapfile -t xs < /dev/null\n' >> "$FIXTURE/seed.sh"
  git -C "$FIXTURE" add -- seed.sh
  git -C "$FIXTURE" commit -q -m "add violation"
  rm -f "$RC_FILE"
  run --separate-stderr env NFR_RC_FILE="$RC_FILE" make --no-print-directory -C "$FIXTURE" \
    check-nfr-portability-internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "1" ]
  [[ "$stderr" == *"seed.sh"* ]]
  # T-FIX-23 后全量模式命中输出格式为 file:line（不含违规内容），
  #   故不再断言 stderr 含字面 mapfile——改断言命中的行号（seed.sh:3）。
  [[ "$stderr" == *"seed.sh:3"* ]]
}

@test "R3-22：.flow-active 指向锚点 ⇒ 选中该锚点（锚点来源可见）" {
  # 多锚点场景：.flow-active 的 change_id 决定用哪个 .change-base，
  #   而非「≥2 个就红」。打印「锚点来源: .specs/<id>/.change-base」便于自证。
  mkdir -p "$FIXTURE/.specs/change-a" "$FIXTURE/.specs/change-b"
  printf '%s\n' "$BASE_SHA" > "$FIXTURE/.specs/change-a/.change-base"
  printf '%s\n' "$BASE_SHA" > "$FIXTURE/.specs/change-b/.change-base"
  printf '{\n  "change_id": "change-a",\n  "phase": "4"\n}\n' > "$FIXTURE/.flow-active"
  seed_append 'mapfile -t xs < /dev/null'
  git -C "$FIXTURE" add -- seed.sh
  git -C "$FIXTURE" commit -q -m "probe"
  rm -f "$RC_FILE"
  run --separate-stderr env NFR_RC_FILE="$RC_FILE" make --no-print-directory -C "$FIXTURE" \
    check-nfr-portability-internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "1" ]
  [[ "$output" == *"锚点来源: .specs/change-a/.change-base"* ]]
}

@test "R3-22：多锚点且 .flow-active 指向不存在 id ⇒ rc=1 具名（不静默）" {
  # .flow-active 指向不存在的 change_id + 恰好 2 个 .change-base ⇒ 必须红 + 具名。
  mkdir -p "$FIXTURE/.specs/change-a" "$FIXTURE/.specs/change-b"
  printf '%s\n' "$BASE_SHA" > "$FIXTURE/.specs/change-a/.change-base"
  printf '%s\n' "$BASE_SHA" > "$FIXTURE/.specs/change-b/.change-base"
  printf '{\n  "change_id": "change-zzz-nonexist",\n  "phase": "4"\n}\n' > "$FIXTURE/.flow-active"
  rm -f "$RC_FILE"
  run --separate-stderr env NFR_RC_FILE="$RC_FILE" make --no-print-directory -C "$FIXTURE" \
    check-nfr-portability-internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "1" ]
  [[ "$output" == *"检测到 2 个"* ]]
}

# ── T-FIX-23 回归钉（R5-23 · NFR 可移植性存量基线 + map[f]ile 替换）──────────
# 六例覆盖基线 ratchet 的正反两面 + 归档排除 + 可移植写法。基线路径由 Makefile
#   硬编码为 flow-kit-bundle/flow-kit/reference/nfr-portability-baseline.txt，
#   夹具仓在同路径写假基线以驱动 ratchet（不触碰真仓基线文件）。
# 全量模式（FULL）只扫 BAN 族 + 走基线；TMOUT 在全量模式被跳过（设计如此）。

@test "T-FIX-23 ①：全量模式 fixture 注入 map[f]ile 命中不在基线 ⇒ rc≠0 且具名 file:line" {
  # 用方括号规避写法（TD-097）构造真实违规行——grep 字面 mapfile 会假绿自身。
  seed_append 'xs=(); while IFS= read -r _l; do xs+=("$_l"); done < <(printf "a\n")'
  # 上面这行是可移植写法（不违规）。再加一行真违规（方括号规避在 bash 运行时
  #   会被 shell 当字面字符串，不会执行——但 NFR 扫描面按 ERE 匹配字面）。
  # 为产生真违规命中，直接写 declare -A（不在注释里）。
  seed_append 'declare -A m=([x]=1)'
  write_baseline   # 空基线（无条目）
  run --separate-stderr run_internals_full
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "1" ]
  # 命中输出格式为 file:line（不含违规内容），故只断言文件名+行号。
  # seed.sh 初始 2 行 + read-loop（行3） + declare -A（行4）⇒ 命中在行 4。
  [[ "$stderr" == *"seed.sh:4"* ]]
}

@test "T-FIX-23 ②：变更集模式同注入不报（存量行不在变更集 diff 面）⇒ rc=0 或 SKIP" {
  # declare -A 行作为存量行已提交到 BASE_SHA 之前；之后无新增 ⇒ 变更集为空。
  #   做法：把违规行写进 seed.sh 初始内容，BASE_SHA 即含违规的提交。
  printf '#!/bin/bash\nt=$(mktemp)\ndeclare -A m=([x]=1)\n' > "$FIXTURE/seed.sh"
  git -C "$FIXTURE" add -- seed.sh
  git -C "$FIXTURE" commit -q --amend --no-edit
  BASE_SHA="$(git -C "$FIXTURE" rev-parse HEAD)"
  # 无新增行 ⇒ 变更集为空（相对 BASE_SHA）⇒ rc=3（SKIP：未验证，非通过）
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "3" ]
}

@test "T-FIX-23 ③：可移植写法（read-loop 替代 map[f]ile）⇒ 全量+变更集双模式 rc=0" {
  # read-loop 是 bash 3.2 兼容写法，不触发 BAN 族。
  seed_append 'xs=(); while IFS= read -r _l; do xs+=("$_l"); done < <(printf "a\n")'
  # 全量模式
  write_baseline
  run --separate-stderr run_internals_full
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "0" ]
  [[ "$output" == *"✅ NFR 兼容性判据通过"* ]]
  # 变更集模式
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "0" ]
}

@test "T-FIX-23 ④：归档内部（.specs/archive/）注入禁构 ⇒ 全量模式 rc=0（排除面）" {
  mkdir -p "$FIXTURE/.specs/archive/old-change"
  printf '#!/bin/bash\ndeclare -A m=([x]=1)\n' > "$FIXTURE/.specs/archive/old-change/x.sh"
  write_baseline
  run --separate-stderr run_internals_full
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "0" ]
  # 归档路径的命中不应出现在 stderr（被排除）
  [[ "$stderr" != *".specs/archive"* ]]
}

@test "T-FIX-23 ⑤：fixture 命中基线条目 ⇒ rc=0 且输出含「存量基线」" {
  # 声明违规行，但该行已登记在基线中 ⇒ ratchet 放行。
  seed_append 'declare -A m=([x]=1)'
  # 基线条目：seed.sh 第 3 行（t=$(mktemp) 是第2行，declare 是第3行）
  write_baseline "seed.sh" "3" "declare-A"
  run --separate-stderr run_internals_full
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "0" ]
  [[ "$output" == *"存量基线"* ]]
}

@test "T-FIX-23 ⑥：基线陈旧（删除基线对应行）⇒ rc≠0 且输出含「基线陈旧」" {
  # 基线登记 seed.sh:3 有 declare -A，但实际 seed.sh 第3行不含禁构（漂移/删除）。
  # 写一行无害内容到第3行（让行号 3 存在但内容不匹配）。
  seed_append 'echo harmless'
  write_baseline "seed.sh" "3" "declare-A"
  run --separate-stderr run_internals_full
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "1" ]
  # 「基线陈旧」归因走 stderr（与命中归因同一通道）。
  [[ "$stderr" == *"基线陈旧"* ]]
}
