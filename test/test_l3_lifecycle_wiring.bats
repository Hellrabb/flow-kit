#!/usr/bin/env bats
# test_l3_lifecycle_wiring.bats — P0-1/P0-2 修复测试（2026-09-11 · l3-lifecycle-wiring）
#
# 背景（经文件级复核的缺陷）：
#   P0-2  artifact cap 断链：29-independent-review.sh:110 读了 independent_review.max_artifact_chars，
#         但调用 l3_review_run 时从未传入 → l3-review.sh 恒用 ${L3_MAX_ARTIFACT_CHARS:-20000}，
#         项目级覆盖被静默丢弃（REQUIREMENT.md 截到 20K → 反复报"NFR 缺失"假阳性的直接来源）。
#   P0-1  熔断死配置：max_failures_before_bypass 只被读进局部变量、全文零引用，
#         L3 一旦不通过就永不写 .done → "修一轮→工件 hash 变→重审→再 fail" 无界循环
#         （9/10 轮均 fail 且不收敛的机制成因）。
#
# 本文件断言修复后的契约：
#   A. artifact cap 有解析链：FLOW_KIT_L3_MAX_ARTIFACT_CHARS > L3_MAX_ARTIFACT_CHARS > 20000
#   B. 熔断有真实出口：达阈值 → bypass 段 + .done(L3_verdict=skipped) → pipeline 继续
#   C. 向后兼容：阈值 0 / 未设 env → 行为与修复前一致（不熔断）
#   D. 计数与清理：fail 累加、pass 清零、已结案短路

setup() {
  TEST_TMP=$(mktemp -d)
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  FK_ROOT="$d"
  export HOOK_BASE_DIR="$FK_ROOT/flow-kit-bundle/hooks/stop"
  L3_LIB="$HOOK_BASE_DIR/lib/l3-review.sh"
  L3_DONE_LIB="$HOOK_BASE_DIR/lib/l3-done.sh"
  ARTIFACTS_DIR="${TEST_TMP}/.specs/test-change"
  mkdir -p "$ARTIFACTS_DIR"
  # 站点级 env 隔离（同 test_l3_review_params.bats 策略）：避免开发者 ~/.bashrc 的调优
  # 泄漏，令"默认值"断言假失败。
  unset FLOW_KIT_L3_MAX_ARTIFACT_CHARS L3_MAX_ARTIFACT_CHARS
  unset FLOW_KIT_L3_MAX_FAILURES_BEFORE_BYPASS
  # 每个用例前写入合法的 L2 段（D3 契约要求 gate_config=both 时有 L2 段）
  printf '# REVIEW (fixture)\n\n## L2 盲审（stub）\n\nverdict=pass\n' \
    > "${ARTIFACTS_DIR}/INDEPENDENT-REVIEW-1.md"
  # 阶段 1 的工件 fixture：_l3_build_prompt 无工件时提前返回 "no artifact for phase 1"，
  # 会让调用链在到达 API 之前就退出（测试假失败）。A1/A2 会用大文件覆盖它。
  printf '# REQUIREMENT (fixture)\n\n## NFR-1 示例\nGiven a\nWhen b\nThen c\n' \
    > "${ARTIFACTS_DIR}/REQUIREMENT.md"
}

teardown() {
  rm -rf "$TEST_TMP"
}

_make_big_requirement() {
  local n="${1:-1200}"
  : > "${ARTIFACTS_DIR}/REQUIREMENT.md"
  local i
  for i in $(seq 1 "$n"); do
    printf '## NFR-%d 需求条目填充内容用于跨过截断上限\nGiven 前置条件 %d\nWhen 动作 %d\nThen 结果 %d\n\n' \
      "$i" "$i" "$i" "$i" >> "${ARTIFACTS_DIR}/REQUIREMENT.md"
  done
}

# ══════════════════════════════════════════════════════════════════════════
# A. artifact cap 解析链（P0-2）
# ══════════════════════════════════════════════════════════════════════════

@test "A1: FLOW_KIT_L3_MAX_ARTIFACT_CHARS 生效（调用方从 stop-hook.json 导出的路径）" {
  _make_big_requirement 1200
  local out
  out=$(bash -c "source '$L3_LIB' 2>/dev/null
    _l3_build_prompt 1 '$ARTIFACTS_DIR' 60000" 2>/dev/null)
  [ "${#out}" -gt 20000 ]
}

@test "A2: 未设 env 时回落 20000（既有默认不变 · 向后兼容）" {
  _make_big_requirement 1200
  local out
  out=$(bash -c "source '$L3_LIB' 2>/dev/null
    _l3_build_prompt 1 '$ARTIFACTS_DIR' 20000" 2>/dev/null)
  [ "${#out}" -lt 25000 ]
}

@test "A3: 29 号模块把 max_artifact_chars 导出给 l3_review_run（断链修复断言）" {
  run grep -q 'export FLOW_KIT_L3_MAX_ARTIFACT_CHARS="\$max_chars"' \
    "$FK_ROOT/flow-kit-bundle/hooks/stop/29-independent-review.sh"
  [ "$status" -eq 0 ]
}

@test "A4: 29 号模块把 max_failures_before_bypass 导出（P0-1 接线断言）" {
  run grep -q 'export FLOW_KIT_L3_MAX_FAILURES_BEFORE_BYPASS="\$max_fail"' \
    "$FK_ROOT/flow-kit-bundle/hooks/stop/29-independent-review.sh"
  [ "$status" -eq 0 ]
}

@test "A5: 非法 artifact cap 值回落 20000（sanitize 不炸）" {
  local out
  out=$(FLOW_KIT_L3_MAX_ARTIFACT_CHARS="abc" bash -c "source '$L3_LIB' 2>/dev/null
    max_chars=\"\${FLOW_KIT_L3_MAX_ARTIFACT_CHARS:-\${L3_MAX_ARTIFACT_CHARS:-20000}}\"
    [[ \"\$max_chars\" =~ ^[1-9][0-9]*\$ ]] || max_chars=20000
    echo \"\$max_chars\"" 2>/dev/null)
  [ "$out" = "20000" ]
}

@test "A6: 历史直调路径 L3_MAX_ARTIFACT_CHARS 仍在解析链中（向后兼容）" {
  run grep -q 'FLOW_KIT_L3_MAX_ARTIFACT_CHARS:-\${L3_MAX_ARTIFACT_CHARS:-20000}' "$L3_LIB"
  [ "$status" -eq 0 ]
}

# ══════════════════════════════════════════════════════════════════════════
# B. 熔断真实出口（P0-1）
# ══════════════════════════════════════════════════════════════════════════

@test "B1: l3_write_bypass_done 追加 bypass 段到 review 文件" {
  local review_md="${ARTIFACTS_DIR}/INDEPENDENT-REVIEW-1.md"
  run bash -c "source '$L3_DONE_LIB' 2>/dev/null
    l3_write_bypass_done 1 test-change '$ARTIFACTS_DIR' pass both 3"
  [ "$status" -eq 0 ]
  grep -q '^## L3 重审（bypass' "$review_md"
  grep -q '熔断触发' "$review_md"
}

@test "B2: l3_write_bypass_done 写出 .done 且 L3_verdict=skipped（不伪装 pass）" {
  bash -c "source '$L3_DONE_LIB' 2>/dev/null
    l3_write_bypass_done 1 test-change '$ARTIFACTS_DIR' pass both 3" 2>/dev/null
  local done_marker="${ARTIFACTS_DIR}/.independent-review-1.done"
  [ -f "$done_marker" ]
  grep -q '^L3_verdict=skipped$' "$done_marker"
  grep -q '^L3_summary=熔断降级' "$done_marker"
  grep -q '^phase=1$' "$done_marker"
  grep -q '^change_id=test-change$' "$done_marker"
  grep -q '^L2_verdict=pass$' "$done_marker"
  grep -q '^written_by=l3-bypass$' "$done_marker"
}

@test "B3: gate_config=both 且无 L2 段时不写 .done（D3 契约保持一致）" {
  printf '# REVIEW\n\n（无 L2 段）\n' > "${ARTIFACTS_DIR}/INDEPENDENT-REVIEW-1.md"
  bash -c "source '$L3_DONE_LIB' 2>/dev/null
    l3_write_bypass_done 1 test-change '$ARTIFACTS_DIR' fail both 3" 2>/dev/null
  [ ! -f "${ARTIFACTS_DIR}/.independent-review-1.done" ]
}

@test "B4: 达阈值时走熔断且不调用模型（省一次 API）" {
  echo "3" > "${ARTIFACTS_DIR}/.l3-attempts-1"
  local marker="${TEST_TMP}/api_called"
  run bash -c "source '$L3_LIB' 2>/dev/null
    _l3_call_api() { touch '$marker'; echo '{\"verdict\":\"fail\"}'; }
    export FLOW_KIT_L3_MAX_FAILURES_BEFORE_BYPASS=3
    l3_review_run 1 test-change '$ARTIFACTS_DIR' pass both"
  [ "$status" -eq 0 ]
  [ ! -f "$marker" ]
  grep -q '^L3_verdict=skipped$' "${ARTIFACTS_DIR}/.independent-review-1.done"
  # 熔断后计数清零，允许人工删除 .done 后重试
  [ ! -f "${ARTIFACTS_DIR}/.l3-attempts-1" ]
}

@test "B5: 未达阈值时正常调用模型，且计数 +1" {
  echo "1" > "${ARTIFACTS_DIR}/.l3-attempts-1"
  local marker="${TEST_TMP}/api_called"
  run bash -c "source '$L3_LIB' 2>/dev/null
    _l3_call_api() { touch '$marker'; echo '{\"verdict\":\"fail\",\"summary\":\"still failing\"}'; }
    export FLOW_KIT_L3_MAX_FAILURES_BEFORE_BYPASS=3
    l3_review_run 1 test-change '$ARTIFACTS_DIR' pass both"
  [ -f "$marker" ]
  [ "$(cat "${ARTIFACTS_DIR}/.l3-attempts-1")" = "2" ]
}

@test "B6: 已结案阶段（.done 存在）短路，不再调用模型" {
  printf 'phase=1\nL3_verdict=pass\n' > "${ARTIFACTS_DIR}/.independent-review-1.done"
  local marker="${TEST_TMP}/api_called"
  run bash -c "source '$L3_LIB' 2>/dev/null
    _l3_call_api() { touch '$marker'; echo '{}'; }
    export FLOW_KIT_L3_MAX_FAILURES_BEFORE_BYPASS=3
    l3_review_run 1 test-change '$ARTIFACTS_DIR' pass both"
  [ "$status" -eq 0 ]
  [ ! -f "$marker" ]
}

# ══════════════════════════════════════════════════════════════════════════
# C. 向后兼容：阈值 0 / 未设 → 不熔断（修复前语义）
# ══════════════════════════════════════════════════════════════════════════

@test "C1: 阈值 0 时不熔断（显式关闭）" {
  echo "99" > "${ARTIFACTS_DIR}/.l3-attempts-1"
  local marker="${TEST_TMP}/api_called"
  run bash -c "source '$L3_LIB' 2>/dev/null
    _l3_call_api() { touch '$marker'; echo '{\"verdict\":\"fail\",\"summary\":\"x\"}'; }
    export FLOW_KIT_L3_MAX_FAILURES_BEFORE_BYPASS=0
    l3_review_run 1 test-change '$ARTIFACTS_DIR' pass both"
  [ -f "$marker" ]
  [ ! -f "${ARTIFACTS_DIR}/.independent-review-1.done" ]
}

@test "C2: 未设 env 时不熔断（默认保持修复前行为）" {
  echo "99" > "${ARTIFACTS_DIR}/.l3-attempts-1"
  local marker="${TEST_TMP}/api_called"
  run bash -c "source '$L3_LIB' 2>/dev/null
    _l3_call_api() { touch '$marker'; echo '{\"verdict\":\"fail\",\"summary\":\"x\"}'; }
    l3_review_run 1 test-change '$ARTIFACTS_DIR' pass both"
  [ -f "$marker" ]
  [ ! -f "${ARTIFACTS_DIR}/.independent-review-1.done" ]
}

# ══════════════════════════════════════════════════════════════════════════
# D. 计数生命周期
# ══════════════════════════════════════════════════════════════════════════

@test "D1: fail 时计数 +1（真链：API fail → 未写 .done）" {
  # `|| true` 吸收 l3_review_run 的 fail 退出码（bats 下 set -e 会中断后续断言）
  bash -c "source '$L3_LIB' 2>/dev/null
    _l3_call_api() { echo '{\"verdict\":\"fail\",\"summary\":\"f\"}'; }
    export FLOW_KIT_L3_MAX_FAILURES_BEFORE_BYPASS=5
    l3_review_run 1 test-change '$ARTIFACTS_DIR' pass both || true" 2>/dev/null
  [ "$(cat "${ARTIFACTS_DIR}/.l3-attempts-1")" = "1" ]
  [ ! -f "${ARTIFACTS_DIR}/.independent-review-1.done" ]
}

@test "D2: pass 时清零计数并写 .done" {
  # 预置 L3 段 + 计数器，验证 pass 路径同时完成"清零"与"结案"
  echo "2" > "${ARTIFACTS_DIR}/.l3-attempts-1"
  printf '# REVIEW\n\n## L2 盲审（stub）\n\nverdict=pass\n\n## L3 盲审（stub）\n\nVERDICT=pass\n' \
    > "${ARTIFACTS_DIR}/INDEPENDENT-REVIEW-1.md"
  bash -c "source '$L3_LIB' 2>/dev/null
    _l3_call_api() { echo '{\"verdict\":\"pass\"}'; }
    _l3_parse_result() { printf '\n## L3 盲审（stub）\n\nVERDICT=pass\n' >> '$ARTIFACTS_DIR/INDEPENDENT-REVIEW-1.md'; echo 'VERDICT=pass'; echo 'SUMMARY=ok'; return 0; }
    export FLOW_KIT_L3_MAX_FAILURES_BEFORE_BYPASS=5
    l3_review_run 1 test-change '$ARTIFACTS_DIR' pass both || true" 2>/dev/null
  [ ! -f "${ARTIFACTS_DIR}/.l3-attempts-1" ]
  # pass 走真 _l3_write_done：应结案
  grep -q '^L3_verdict=pass$' "${ARTIFACTS_DIR}/.independent-review-1.done"
}

# ══════════════════════════════════════════════════════════════════════════
# E. 配置优先级链 + 文档契约（2026-09-11 · ③④ 收尾）
#    锁住"项目级 .flow-kit/stop-hook.json 优先、缺省回退 20000"这一实测行为，
#    以及 l3.env 模板/README 记录的变量名必须真实存在（防文档漂移）。
# ══════════════════════════════════════════════════════════════════════════

@test "E1: 项目级 .flow-kit/stop-hook.json 优先（dsh 运行时）" {
  local proj="${TEST_TMP}/proj"
  mkdir -p "${proj}/.flow-kit"
  printf '{"independent_review":{"max_artifact_chars":60000,"max_failures_before_bypass":7}}\n' \
    > "${proj}/.flow-kit/stop-hook.json"
  local out
  out=$(FLOW_KIT_RUNTIME=dsh FLOW_KIT_PROJECT_DIR="$proj" bash -c "
    source '$HOOK_BASE_DIR/lib/common.sh' 2>/dev/null
    init_paths 2>/dev/null
    echo \"\$CONFIG_FILE|\$(config_get '.independent_review.max_artifact_chars' 20000)|\$(config_get '.independent_review.max_failures_before_bypass' 3)\"" 2>/dev/null)
  [ "${out%%|*}" = "${proj}/.flow-kit/stop-hook.json" ]
  [[ "$out" == *"|60000|"* ]]
  [[ "$out" == *"|7" ]]
}

@test "E2: 项目无 sidecar 时回退仓库默认 20000（不得继承他项目配置）" {
  local out
  out=$(FLOW_KIT_RUNTIME=dsh FLOW_KIT_PROJECT_DIR="${TEST_TMP}/no-such-proj" bash -c "
    source '$HOOK_BASE_DIR/lib/common.sh' 2>/dev/null
    init_paths 2>/dev/null
    config_get '.independent_review.max_artifact_chars' 20000" 2>/dev/null)
  [ "$out" = "20000" ]
}

@test "E3: claude/opencode 运行时用 .claude 配置目录（零回归）" {
  local out
  out=$(FLOW_KIT_RUNTIME=claude FLOW_KIT_PROJECT_DIR="${TEST_TMP}/proj-claude" bash -c "
    source '$HOOK_BASE_DIR/lib/common.sh' 2>/dev/null
    init_paths 2>/dev/null
    echo \"\$CONFIG_FILE\"" 2>/dev/null)
  [[ "$out" == *"/.claude/stop-hook.json" ]]
}

@test "E4: 29 号把 config 值导出为 FLOW_KIT_L3_MAX_ARTIFACT_CHARS（供 l3_review_run 读取）" {
  # 顺序断言：先 config_get，后 export，且导出的就是同一个变量
  run grep -n 'max_chars=$(config_get' "$HOOK_BASE_DIR/29-independent-review.sh"
  [ "$status" -eq 0 ]
  run grep -n 'export FLOW_KIT_L3_MAX_ARTIFACT_CHARS="$max_chars"' "$HOOK_BASE_DIR/29-independent-review.sh"
  [ "$status" -eq 0 ]
}

@test "E5: l3.env 模板存在且含必填项（新环境部署不再踩死锁）" {
  local tpl="$FK_ROOT/.claude/l3.env.example"
  [ -f "$tpl" ]
  grep -q 'FLOW_KIT_L3_BASE_URL' "$tpl"
  grep -q 'FLOW_KIT_L3_AUTH_TOKEN' "$tpl"
  # 必须写明工件上限不在 env 里配（否则用户会找错地方）
  grep -q 'max_artifact_chars' "$tpl"
  # 必须给出 systemd drop-in 路径（dsh 侧凭证靠它注入）
  grep -q 'EnvironmentFile' "$tpl"
}

@test "E6: 模板/README 记录的模型变量名在代码中真实存在（防文档漂移）" {
  local tpl="$FK_ROOT/.claude/l3.env.example"
  local readme="$FK_ROOT/dsh-flow-kit/README.md"
  local common="$HOOK_BASE_DIR/lib/common.sh"
  for v in FLOW_KIT_L3_DEFAULT_MODEL FLOW_KIT_L2_DEFAULT_MODEL; do
    grep -q "$v" "$tpl" || { echo "模板缺 $v"; return 1; }
    grep -q "$v" "$readme" || { echo "README 缺 $v"; return 1; }
    grep -q "$v" "$common" || { echo "代码未读取 $v（文档与实现不符）"; return 1; }
  done
  # FLOW_KIT_L3_MODEL 是"具体模型"层，同样须一致
  grep -q 'FLOW_KIT_L3_MODEL' "$common"
  grep -q 'FLOW_KIT_L3_MODEL' "$tpl"
}
