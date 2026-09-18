#!/usr/bin/env bats
# test_l3_review_defects_2026_09.bats — L3 审查链缺陷修复回归（2026-09-18）
#
# 来源：`L3-review-defects-2026-09-17.md`（chisel-skill 开发中在 chisel_env 的
#       change `verify-ac-env-fix` 踩到，阶段 7 实测复现）。
# 本文覆盖该报告 5 条缺陷的**重新实测 + 修复**回归，逐条标注 §Bx：
#
#   §B1 fk_extract_l2_verdict 抽错 verdict  → 取到 L3 段 JSON / 无行首锚定 / 大小写不归一
#       后果：`invalid L2_verdict: PASS` → l3-review.sh return 3 → L3 永不运行且工件无痕
#   §B2 L3 段重写按标题截断、无结束标记     → 载荷含行首 '## ' 时旧段尾残留并逐轮累积
#   §B3 max_artifact_chars 名"字符"实"字节" → 中文工件 60000 只装 ~2 万汉字 → 假阳性
#   §B4 阶段 7 产物清单 head -30 + 硬编码 INTEGRATION.md → 假"产物缺失" + 假 major
#   §B5 安装树不同步                        → ~/.claude/hooks 跑旧代码，同 change 换路径结论不同
#
# 命名约定：用例标题前缀 = 缺陷编号；末尾 `R<n>` 为同名缺陷的第 n 条断言。

setup() {
  TEST_TMP=$(mktemp -d)
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  FK_ROOT="$d"
  HOOKS="$FK_ROOT/flow-kit-bundle/hooks"
  export HOOK_BASE_DIR="$HOOKS/stop"
  L2_LIB="$HOOK_BASE_DIR/lib/l2-detect.sh"
  L3_API_LIB="$HOOK_BASE_DIR/lib/l3-api.sh"
  L3_SECTION_LIB="$HOOK_BASE_DIR/lib/l3-section.sh"
  L3_DONE_LIB="$HOOK_BASE_DIR/lib/l3-done.sh"
  L3_PROMPT_LIB="$HOOK_BASE_DIR/lib/l3-prompt.sh"
  L3_REVIEW_LIB="$HOOK_BASE_DIR/lib/l3-review.sh"
  H29="$HOOK_BASE_DIR/29-independent-review.sh"
  export PROJECT_ROOT="$TEST_TMP"
  # 站点级 env 隔离：避免开发者 ~/.bashrc 的调优泄漏进"默认值"断言
  unset FLOW_KIT_L3_MAX_ARTIFACT_BYTES FLOW_KIT_L3_MAX_ARTIFACT_CHARS L3_MAX_ARTIFACT_CHARS
  unset FLOW_KIT_L3_MAX_FAILURES_BEFORE_BYPASS
}

teardown() {
  rm -rf "$TEST_TMP"
}

# 在独立 bash 里 source l2-detect.sh 并求值（隔离 set -euo pipefail 副作用）
_l2v() {
  bash -c "source '$L2_LIB' 2>/dev/null; fk_extract_l2_verdict \"\$1\"" _ "$1" 2>/dev/null
}

# ══════════════════════════════════════════════════════════════════════════
# §B1 · fk_extract_l2_verdict
# ══════════════════════════════════════════════════════════════════════════

@test "B1-R1: 报告 §B1 的自包含复现 → 期望 fail（修复前实际 PASS）" {
  local f="$TEST_TMP/repro.md"
  printf '%s\n' "## L2 盲审" "**Verdict**: fail" "" "### 结论" \
    "第 2 轮复核后 Verdict: PASS" > "$f"
  [ "$(_l2v "$f")" = "fail" ]
}

@test "B1-R2: L2 段后有 L3 段时取 L2 结论，不被 L3 的 JSON verdict 改写" {
  local f="$TEST_TMP/l2-then-l3.md"
  cat > "$f" <<'EOF'
# INDEPENDENT-REVIEW-7

## L2 盲审

**Verdict**: fail

### 结论
发现 2 个 critical。

## L3 重审（deepseek-v4-flash 外部模型 · 2026-09-17 10:00）

### 审查结论

```json
{"critical":[],"major":[],"verdict":"pass","summary":"round 2"}
```
EOF
  [ "$(_l2v "$f")" = "fail" ]
}

@test "B1-R3: 大小写归一 → PASS/FAIL 一律返回小写枚举（值域 ^(pass|fail|skipped)$）" {
  local f="$TEST_TMP/case.md"
  printf '%s\n' "## L2 盲审" "**Verdict**: PASS" > "$f"
  [ "$(_l2v "$f")" = "pass" ]
  printf '%s\n' "## L2 盲审" "**Verdict**: **FAIL**" > "$f"
  [ "$(_l2v "$f")" = "fail" ]
  printf '%s\n' "## L2 盲审" "- **Verdict**: Pass" > "$f"
  [ "$(_l2v "$f")" = "pass" ]
}

@test "B1-R4: 行首锚定 —— 排除 L3 的 JSON 引号键、括号/散文里的顺带提及" {
  local f="$TEST_TMP/anchored.md"
  cat > "$f" <<'EOF'
## L2 盲审
**Verdict**: fail

补充（不参与 Verdict，仅记录）：正文提到 verdict: pass 字样不应被采信
  "verdict": "fail",
EOF
  [ "$(_l2v "$f")" = "fail" ]
}

@test "B1-R5: 标题形 verdict（## Verdict / ### 重审 Verdict）仍被识别" {
  local f="$TEST_TMP/heading.md"
  printf '%s\n' "## L2 盲审" "" "## Verdict" "" "**pass** — 全部通过" > "$f"
  [ "$(_l2v "$f")" = "pass" ]
  printf '%s\n' "## L2 盲审" "" "### 重审 Verdict" "" "**fail** — 仍有 critical" > "$f"
  [ "$(_l2v "$f")" = "fail" ]
}

@test "B1-R6: 多轮 L2 重审 → 取最后一轮（最新）结论，且与轮次顺序无关的确定性" {
  local f="$TEST_TMP/multi.md"
  cat > "$f" <<'EOF'
## L2 盲审
**Verdict**: fail
## 主 agent 响应
已修。
## L2 盲审（重审）
**Verdict**: pass（无 critical）
EOF
  [ "$(_l2v "$f")" = "pass" ]
  # 确定性：同一文件连跑两次结果一致（.done 可复现的前提）
  [ "$(_l2v "$f")" = "$(_l2v "$f")" ]
}

@test "B1-R7: 无 verdict 行 → 空输出 + 非零退出（调用方按 best-effort 不阻塞）" {
  local f="$TEST_TMP/none.md"
  printf '%s\n' "## L2 盲审" "" "正文没有任何结论行" > "$f"
  # set +e：l2-detect.sh 自带 set -e，函数返回 1 会让 shell 在取 rc 之前退出
  run bash -c "source '$L2_LIB' 2>/dev/null; set +e; out=\$(fk_extract_l2_verdict '$f'); rc=\$?; echo \"[\$out][\$rc]\""
  [ "$output" = "[][1]" ]
}

@test "B1-R8: 提取结果恒为小写枚举，可直接通过 l3_review_run 的值域校验" {
  local f="$TEST_TMP/enum.md"
  printf '%s\n' "## L2 盲审" "**Verdict**: PASS" > "$f"
  local v; v="$(_l2v "$f")"
  [[ "$v" =~ ^(pass|fail|skipped)$ ]]
}

# ══════════════════════════════════════════════════════════════════════════
# §B2 · L3 段显式结束标记
# ══════════════════════════════════════════════════════════════════════════

# 模拟一轮 L3 写入：先按标记删旧段，再追加新段（与 _l3_parse_result 同序）
_l3_write_round() {
  local rmd="$1" content="$2" ts="$3" tmp
  tmp="$(mktemp "${rmd}.tmp.XXXXXX")"
  bash -c "source '$L3_SECTION_LIB' 2>/dev/null; _l3_strip_sections \"\$1\" \"\$2\"" _ "$rmd" "$tmp"
  {
    echo ""; echo "---"; echo ""
    echo "## L3 重审（test-model 外部模型 · ${ts}）"; echo ""
    echo "> 自动生成于 ${ts}。由 l3-review.sh 写入。"
    echo ""; echo "### 审查结论"; echo ""; echo '```json'
    echo "$content"; echo '```'
    echo ""; echo "L3_artifact_hash: hash-${ts}"
    echo ""; echo "<!-- /L3-SECTION -->"
  } >> "$tmp"
  mv "$tmp" "$rmd"
}

@test "B2-R1: 载荷含行首 '## ' 时，重写不残留旧段尾（报告 §B2 的未触发场景）" {
  local rmd="$TEST_TMP/INDEPENDENT-REVIEW-7.md"
  printf '%s\n' "# IR-7" "" "## L2 盲审" "" "**Verdict**: fail" > "$rmd"
  _l3_write_round "$rmd" $'{"summary":"round 2"}\n## 附录：模型自由发挥的标题\nmore text' "R2"
  _l3_write_round "$rmd" '{"summary":"round 3"}' "R3"
  run grep -c '^## L3 ' "$rmd"; [ "$output" = "1" ]
  run grep -c '附录' "$rmd";      [ "$output" = "0" ]
  run grep -c 'hash-R2' "$rmd";   [ "$output" = "0" ]
  run grep -c 'round 3' "$rmd";   [ "$output" = "1" ]
}

@test "B2-R2: 连续 4 轮后围栏配平、标记唯一、分隔符不累积" {
  local rmd="$TEST_TMP/rounds.md"
  printf '%s\n' "# IR-7" "" "## L2 盲审" "" "**Verdict**: fail" > "$rmd"
  _l3_write_round "$rmd" $'{"summary":"r2"}\n## 行首标题 A' "R2"
  _l3_write_round "$rmd" '{"summary":"r3"}' "R3"
  _l3_write_round "$rmd" $'{"summary":"r4"}\n## 行首标题 B' "R4"
  _l3_write_round "$rmd" '{"summary":"r5"}' "R5"
  run grep -c '^```' "$rmd";                    [ "$output" = "2" ]   # json 围栏配平
  run grep -c '^<!-- /L3-SECTION -->$' "$rmd";  [ "$output" = "1" ]   # 标记唯一
  run grep -c '^---$' "$rmd";                   [ "$output" = "1" ]   # 分隔符不累积
  run grep -cE '行首标题|hash-R[234]' "$rmd";   [ "$output" = "0" ]   # 零残留
  # L2 结论仍可提取（B1 与 B2 组合不互相破坏）
  [ "$(_l2v "$rmd")" = "fail" ]
}

@test "B2-R3: 历史工件（无标记）仍按原标题法清除 L3 段（向后兼容）" {
  local legacy="$TEST_TMP/legacy.md" out="$TEST_TMP/legacy.out"
  cat > "$legacy" <<'EOF'
## L2 盲审
**Verdict**: pass
---
## L3 盲审（old · t）
### 审查结论
```json
{"verdict":"fail"}
```
L3_artifact_hash: x
## 主 agent 响应
正文保留
EOF
  bash -c "source '$L3_SECTION_LIB' 2>/dev/null; _l3_strip_sections \"\$1\" \"\$2\"" _ "$legacy" "$out"
  run grep -c '## L3' "$out";        [ "$output" = "0" ]
  run grep -c 'L3_artifact_hash' "$out"; [ "$output" = "0" ]
  run grep -c '正文保留' "$out";      [ "$output" = "1" ]
  run grep -c '## L2 盲审' "$out";    [ "$output" = "1" ]
}

@test "B2-R4: 标记之后的后续内容不被误删" {
  local m="$TEST_TMP/after.md" out="$TEST_TMP/after.out"
  cat > "$m" <<'EOF'
## L2 盲审
**Verdict**: pass
---
## L3 重审（new · t）
```json
{"verdict":"pass"}
```
<!-- /L3-SECTION -->
## 主 agent 响应（L3）
保留我
EOF
  bash -c "source '$L3_SECTION_LIB' 2>/dev/null; _l3_strip_sections \"\$1\" \"\$2\"" _ "$m" "$out"
  run grep -c '保留我' "$out";   [ "$output" = "1" ]
  run grep -c '## L3' "$out";    [ "$output" = "0" ]
}

@test "B2-R5: 三处写入方共用同一标记字面量（跨文件契约不漂移）" {
  local sec="$HOOK_BASE_DIR/lib/l3-section.sh"
  # 标记字面量唯一定义在 l3-section.sh
  grep -q "L3_SECTION_END_MARKER='<!-- /L3-SECTION -->'" "$sec"
  # 主写入方：l3-api.sh 的 _l3_parse_result 落 L3_SECTION_END_MARKER
  grep -q 'echo "\$L3_SECTION_END_MARKER"' "$L3_API_LIB"
  # 降级写入方：l3-done.sh 的 timeout / bypass 各调一次 _l3_l3_marker
  [ "$(grep -c '^    _l3_l3_marker$' "$L3_DONE_LIB")" -eq 2 ]
  # 标记字面量唯一：三处都不得再自带一份字面量（只允许引用变量/函数）
  [ "$(grep -c "L3_SECTION_END_MARKER='" "$sec")" -eq 1 ]
  [ "$(grep -c "L3_SECTION_END_MARKER='" "$L3_API_LIB")" -eq 0 ]
  [ "$(grep -c "L3_SECTION_END_MARKER='" "$L3_DONE_LIB")" -eq 0 ]
  # 删除侧的 awk 也认这个字面量（在 l3-section.sh 内）
  grep -qF 'L3-SECTION -->' "$sec"
}

@test "B2-R6: 生产链路 _l3_parse_result 连跑 5 轮 → 工件字节稳定、零残留" {
  local d="$TEST_TMP/prod" f r payload
  mkdir -p "$d"
  f="$d/INDEPENDENT-REVIEW-1.md"
  printf '# REQUIREMENT\n## NFR-1 v0\n' > "$d/REQUIREMENT.md"
  printf '# IR-1\n## L2 盲审\n**Verdict**: fail\n' > "$f"
  # 每轮改工件 → 触发 _l3_check_rerun 重审（与真实"修一轮→重审"循环同构）；
  # 第 2/4 轮载荷故意带行首 '## '（§B2 的触发条件）
  for r in 1 2 3 4 5; do
    printf '# REQUIREMENT\n## NFR-1 v%s\n' "$r" > "$d/REQUIREMENT.md"
    payload="{\"critical\":[],\"verdict\":\"pass\",\"summary\":\"r${r}\"}"
    case "$r" in 2|4) payload="${payload}"$'\n'"## 行首标题${r}"$'\n'"尾" ;; esac
    bash -c "source '$L3_REVIEW_LIB' 2>/dev/null; _l3_parse_result \"\$1\" 1 \"\$2\" model-x >/dev/null 2>&1" \
      _ "$payload" "$d"
  done
  run grep -c '^## L3 ' "$f";                 [ "$output" = "1" ]   # 段去重
  run grep -c '^<!-- /L3-SECTION -->$' "$f";  [ "$output" = "1" ]   # 标记唯一
  run grep -c '^---$' "$f";                   [ "$output" = "1" ]   # 分隔符不累积
  run grep -c '^```' "$f";                    [ "$output" = "2" ]   # 围栏配平
  run grep -cE '行首标题|"summary":"r[1-4]"' "$f"; [ "$output" = "0" ]  # 零残留
  run grep -c '^$' "$f";                      [ "$output" = "7" ]   # 空行数逐轮不增长
  [ "$(_l2v "$f")" = "fail" ]                                       # L2 结论未被 L3 覆盖
}

# ══════════════════════════════════════════════════════════════════════════
# §B3 · 工件上限单位 = 字节（配置改名 + 文档）
# ══════════════════════════════════════════════════════════════════════════

@test "B3-R1: 截断按字节执行（60000 字节 ≈ 20000 汉字，不是 60000 字符）" {
  local f="$TEST_TMP/cjk.md"
  python3 -c "import sys; sys.stdout.write('中文测试内容'*5000)" > "$f"
  run bash -c "source '$L3_PROMPT_LIB' 2>/dev/null; _l3_utf8_head_bytes 60000 '$f' | wc -c"
  [ "$output" -eq 60000 ]
  run bash -c "source '$L3_PROMPT_LIB' 2>/dev/null; _l3_utf8_head_bytes 60000 '$f' | python3 -c 'import sys;print(len(sys.stdin.read()))'"
  [ "$output" -eq 20000 ]
}

@test "B3-R2: 规范配置键 max_artifact_bytes 优先，且被导出为 _BYTES" {
  grep -q "config_get '.independent_review.max_artifact_bytes'" "$H29"
  grep -q 'export FLOW_KIT_L3_MAX_ARTIFACT_BYTES="\$max_bytes"' "$H29"
}

@test "B3-R3: 旧键 max_artifact_chars 仍可读（行为不变）+ 打印迁移提示" {
  grep -q "config_get '.independent_review.max_artifact_chars'" "$H29"
  grep -q 'DEPRECATED' "$H29"
  grep -qE '÷3|÷ 3' "$H29"
}

@test "B3-R4: l3-review.sh 解析链 新名 > 旧名 > 历史直调 > 20000" {
  grep -q 'FLOW_KIT_L3_MAX_ARTIFACT_BYTES:-\${FLOW_KIT_L3_MAX_ARTIFACT_CHARS:-\${L3_MAX_ARTIFACT_CHARS:-20000}}}' \
    "$L3_REVIEW_LIB"
}

@test "B3-R5: 配置模板与 l3.env 模板都写明单位=字节 + CJK ÷3" {
  run grep -q 'max_artifact_bytes' "$HOOKS/config/stop-hook.json"
  [ "$status" -eq 0 ]
  local tpl="$FK_ROOT/.claude/l3.env.example"
  grep -q 'max_artifact_bytes' "$tpl"
  grep -qE '单位 = 字节|单位=字节' "$tpl"
  grep -qE '÷3|÷ 3' "$tpl"
}

@test "B3-R6: README 同步写明单位=字节（防文档漂移）" {
  grep -q 'max_artifact_bytes' "$FK_ROOT/README.md"
  grep -qE '单位 = 字节|单位=字节' "$FK_ROOT/README.md"
  grep -q 'max_artifact_bytes' "$FK_ROOT/dsh-flow-kit/README.md"
}

# ══════════════════════════════════════════════════════════════════════════
# §B4 · 阶段 7 产物清单（全量 + INTEGRATION.md 按需）
# ══════════════════════════════════════════════════════════════════════════

# 造一个 > 28 条目的阶段 7 change 目录（报告实测为 33/41 条）
_build_phase7_tree() {
  local dir="$1" n="${2:-41}"
  mkdir -p "$dir" "$(dirname "$dir")"
  local i
  for i in $(seq -w 1 "$n"); do : > "$dir/FILE-$i.md"; done
  printf '# CHANGE\n' > "$dir/CHANGE.md"
  printf '# REQUIREMENT\n' > "$dir/REQUIREMENT.md"
  printf '# DESIGN\n' > "$dir/DESIGN.md"
  printf '# TASK\n' > "$dir/TASK.md"
  printf '# TEST\n' > "$dir/TEST.md"
  printf '# REVIEW\n' > "$dir/REVIEW.md"
  printf '# T07\n' > "$dir/T07-SUMMARY.md"
  printf '# UAT\n' > "$dir/UAT.md"
}

_phase7_prompt() {
  bash -c "source '$L3_REVIEW_LIB' 2>/dev/null; _l3_build_prompt 7 \"\$1\" 200000" _ "$1" 2>/dev/null
}

@test "B4-R1: 顶层条目 41 条时清单全量、零遗漏（修复前 head -30 只给 27 条）" {
  local spec="$TEST_TMP/.specs/chg"; _build_phase7_tree "$spec" 33
  local out; out="$(_phase7_prompt "$spec")"
  local missing=0 f
  while IFS= read -r f; do
    printf '%s' "$out" | grep -qF "$f" || missing=$((missing + 1))
  done < <(ls -A "$spec")
  [ "$missing" -eq 0 ]
  # 报告点名的 5 个"看不见"的文件必须出现
  printf '%s' "$out" | grep -qF 'TASK.md'
  printf '%s' "$out" | grep -qF 'TEST.md'
  printf '%s' "$out" | grep -qF 'T07-SUMMARY.md'
  printf '%s' "$out" | grep -qF 'UAT.md'
}

@test "B4-R2: 不再凭空产出 INTEGRATION.md === MISSING（本项目阶段 7 不产该文件）" {
  local spec="$TEST_TMP/.specs/chg2"; _build_phase7_tree "$spec" 10
  local out; out="$(_phase7_prompt "$spec")"
  run bash -c "printf '%s' \"\$1\" | grep -c 'INTEGRATION.md === MISSING'" _ "$out"
  [ "$output" = "0" ]
}

@test "B4-R3: 存在的可选产物列出、缺失的可选产物不列（不误报）" {
  local spec="$TEST_TMP/.specs/chg3"; _build_phase7_tree "$spec" 5
  local out; out="$(_phase7_prompt "$spec")"
  printf '%s' "$out" | grep -q '=== UAT.md ==='
  run bash -c "printf '%s' \"\$1\" | grep -c 'MINOR-DEFERRED.md ==='" _ "$out"
  [ "$output" = "0" ]
}

@test "B4-R4: 必备产物仍严格执行 MISSING 语义（修复未削弱门禁）" {
  local spec="$TEST_TMP/.specs/chg4"; _build_phase7_tree "$spec" 5
  rm -f "$spec/TASK.md"
  local out; out="$(_phase7_prompt "$spec")"
  printf '%s' "$out" | grep -q '=== TASK.md === MISSING'
}

# ══════════════════════════════════════════════════════════════════════════
# §B5 · 安装树同步（副本漂移机器检查）
# ══════════════════════════════════════════════════════════════════════════

@test "B5-R1: sync-hooks.sh 存在、可执行、且被 Makefile 接线" {
  [ -f "$FK_ROOT/sync-hooks.sh" ]
  [ -x "$FK_ROOT/sync-hooks.sh" ]
  grep -q 'sync-hooks.sh' "$FK_ROOT/Makefile"
  grep -q 'check-hooks-sync' "$FK_ROOT/Makefile"
  # 契约：本工具只管**内容**，不改副本权限 —— 可执行位归 install_hooks.sh。
  # （否则同步会顺手把 stop/lib/*.sh 也 chmod +x，搅出一堆与修复无关的 mode 变更。）
  # 只断言"没有真正调用 chmod"，注释里提到 chmod 不算。
  run grep -cE '^[[:space:]]*chmod|&&[[:space:]]*chmod|\|\|[[:space:]]*chmod' "$FK_ROOT/sync-hooks.sh"
  [ "$output" = "0" ]
}

@test "B5-R2: 所有已存在的 hooks 副本与源一致（漂移=0 · 报告 §7 要求的机器检查）" {
  run bash "$FK_ROOT/sync-hooks.sh" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"漂移 0"* ]]
}

@test "B5-R3: 用户级 ~/.claude/hooks 带 P0-1/P0-2 修复（历史漂移点）" {
  local d="$HOME/.claude/hooks"
  [ -d "$d" ] || skip "本机无 ~/.claude/hooks（用户级安装）"
  # P0-2：项目级 artifact cap 真正接到 l3_review_run
  grep -rq 'FLOW_KIT_L3_MAX_ARTIFACT' "$d"
  # P0-1：熔断降级出口
  grep -rq 'l3_write_bypass_done' "$d"
  # B3：改名后的规范名也已落地
  grep -q 'FLOW_KIT_L3_MAX_ARTIFACT_BYTES' "$d/stop/29-independent-review.sh"
}

@test "B5-R4: 副本漂移检测能真的发现漂移（自证有效，不是恒真断言）" {
  local fake="$TEST_TMP/fake-root-hooks"
  mkdir -p "$fake/stop/lib"
  # 造一个副本：所有镜像文件都缺 → 漂移必须 > 0
  run bash -c "
    cd '$FK_ROOT'
    sed \"s#\\\$HOME/.claude/hooks#$fake#\" sync-hooks.sh > '$TEST_TMP/fake-sync.sh'
    bash '$TEST_TMP/fake-sync.sh' --check"
  [ "$status" -ne 0 ]
}
