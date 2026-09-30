#!/usr/bin/env bats
# test_independent_review_model.bats — env-var-first 模型 + API 直连测试
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  # Save original env for restoration
  SAVED_HAIKU_MODEL="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"
  SAVED_BASE_URL="${ANTHROPIC_BASE_URL:-}"
  SAVED_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-}"
  # l2-l3-model-config: 全部读仓库源树（对齐 test_common.bats 向上查找），
  # 禁止 $HOME/.claude/hooks 安装副本回落（R5-26 · ADR-014 spot-check F3）：
  # 删除/改名 bundle 源件时本网必须 fail-fast 转红，不得被已安装副本顶替通过。
  local d="${BATS_TEST_DIRNAME:-.}"
  while [ "$d" != "/" ] && [ ! -f "$d/flow-kit-bundle/hooks/stop/29-independent-review.sh" ]; do
    d="$(dirname "$d")"
  done
  FK_ROOT="$d"
  FK_STOP="$d/flow-kit-bundle/hooks/stop"
  FK_SRC_29="$FK_STOP/29-independent-review.sh"
  FK_SRC_30="$FK_STOP/30-ai-analyze.sh"
  FK_L3_REVIEW="$FK_STOP/lib/l3-review.sh"
  FK_L3_API="$FK_STOP/lib/l3-api.sh"
  # fail-fast：仓库源件缺失即立即失败并具名报错（不得静默 skip / 回落 $HOME）。
  local missing=""
  [ -f "$FK_SRC_29" ]   || missing="$missing $FK_SRC_29"
  [ -f "$FK_SRC_30" ]   || missing="$missing $FK_SRC_30"
  [ -f "$FK_L3_REVIEW" ] || missing="$missing $FK_L3_REVIEW"
  [ -f "$FK_L3_API" ]   || missing="$missing $FK_L3_API"
  if [ -n "$missing" ]; then
    echo "缺失仓库源件（R5-26 fail-fast）:$missing" >&3
    return 1
  fi
  export FK_ROOT FK_STOP FK_SRC_29 FK_SRC_30 FK_L3_REVIEW FK_L3_API
}

teardown() {
  rm -rf "$TEST_TMPDIR"
  # Restore original env
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="${SAVED_HAIKU_MODEL}"
  export ANTHROPIC_BASE_URL="${SAVED_BASE_URL}"
  export ANTHROPIC_AUTH_TOKEN="${SAVED_AUTH_TOKEN}"
}

# ── AC-1: 29号脚本用 fk_resolve_model 三级链（l2-l3-model-config ADR-012）──

@test "AC-1: 29-independent-review.sh uses fk_resolve_model (l2-l3-model-config ADR-012)" {
  run grep -c 'fk_resolve_model' "$FK_SRC_29"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-2: 30号脚本同样读环境变量 ──────────────────────────────────────

@test "AC-2: 30-ai-analyze.sh references ANTHROPIC_DEFAULT_HAIKU_MODEL" {
  run grep -c 'ANTHROPIC_DEFAULT_HAIKU_MODEL' "$FK_SRC_30"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "AC-2: 30-ai-analyze.sh references ANTHROPIC_BASE_URL" {
  run grep -c 'ANTHROPIC_BASE_URL' "$FK_SRC_30"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-3: 模型解析 — 29 用 fk_resolve_model, 30 保持 env-var-first ──

@test "AC-3: 29 用 fk_resolve_model 三级链, 30 保持 env-var-first :- (l2-l3-model-config)" {
  # 29 (ADR-012): fk_resolve_model "L3" 三级链替代 :?
  run grep -c 'fk_resolve_model "L3"' "$FK_SRC_29"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]

  # 30 (未改，env-var-first 保持)：ANTHROPIC_DEFAULT_HAIKU_MODEL:- pattern
  run grep -cE 'ANTHROPIC_DEFAULT_HAIKU_MODEL:[-?]' "$FK_SRC_30"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-4: API 直连 ────────────────────────────────────────────────────

@test "AC-4: l3-review.sh uses ANTHROPIC_BASE_URL for direct API (pipeline-fallback-fix: 迁移到共享lib)" {
  run grep -c 'ANTHROPIC_BASE_URL' "$FK_L3_REVIEW"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "AC-4: l3-review.sh uses ANTHROPIC_AUTH_TOKEN for auth header (pipeline-fallback-fix: 迁移到共享lib)" {
  run grep -c 'ANTHROPIC_AUTH_TOKEN' "$FK_L3_REVIEW"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-9: token 不泄露到日志 ──────────────────────────────────────────

@test "AC-9: AUTH_TOKEN only in assignment and curl header, not in echo/module_output" {
  # 先断言被检文件存在——否则「文件缺失 ⇒ 反向断言恒真」（AC-7 假绿消除）
  [ -f "$FK_SRC_29" ]
  [ -f "$FK_SRC_30" ]

  # 29号脚本
  run bash -c "grep -n 'ANTHROPIC_AUTH_TOKEN' \"$FK_SRC_29\" | grep -v 'auth_token=' | grep -v 'Bearer' | grep -v '^[0-9]*: *#' "
  [ "$status" -ne 0 ]  # No matches outside assignment/header/comment

  # 30号脚本
  run bash -c "grep -n 'ANTHROPIC_AUTH_TOKEN' \"$FK_SRC_30\" | grep -v 'auth_token=' | grep -v 'Bearer' | grep -v '^[0-9]*: *#' "
  [ "$status" -ne 0 ]
}

# ── API 路径优先级 smoke test ─────────────────────────────────────────

@test "API path: direct curl before legacy key in l3-api.sh (pipeline-fallback-fix: 迁移到共享lib · final-debt-cleanup: split to l3-api.sh)" {
  # 直连代码块应该在 legacy API key 之前出现
  # final-debt-cleanup-2026-08 将 API 路径逻辑从 l3-review.sh 拆到 l3-api.sh
  # 源码树读取（l3-api.sh 注释已随 split 更新为 Path1/Path2 中文注释）。
  direct_line=$(grep -n 'env-var-first（claude code 原生）' "$FK_L3_API" | head -1 | cut -d: -f1)
  legacy_line=$(grep -n 'Path2 legacy 兜底' "$FK_L3_API" | head -1 | cut -d: -f1)
  [ -n "$direct_line" ]
  [ -n "$legacy_line" ]
  [ "$direct_line" -lt "$legacy_line" ]
}

@test "API path: direct curl before onecli in 30 script" {
  script="$FK_SRC_30"
  direct_line=$(grep -n 'Path 1.*Direct API' "$script" | head -1 | cut -d: -f1)
  onecli_line=$(grep -n 'Path 2.*onecli' "$script" | head -1 | cut -d: -f1)
  [ -n "$direct_line" ]
  [ -n "$onecli_line" ]
  [ "$direct_line" -lt "$onecli_line" ]
}

# ── onecli 保留为 fallback ────────────────────────────────────────────

@test "API fallback: 29 script sources l3-review.sh shared lib (pipeline-fallback-fix: 迁移到共享lib)" {
  run grep -c 'l3-review.sh' "$FK_SRC_29"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "onecli fallback: 30 script still references onecli" {
  run grep -c 'onecli' "$FK_SRC_30"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-7 删除注入封闭腿（R5-26）：临时移走 bundle 29 号源件 ⇒ 本网必须转红 ──

@test "AC-7 delete-injection: removing bundle 29 source turns the net red (R5-26 closure)" {
  # 复刻判据③：把仓库源件临时移到夹具（cp + rm，可中断复原），随后重跑本网
  # 的 fail-fast 断言路径——源件缺失时 setup 的 fail-fast 必须转红，不得静默回落。
  hold=$(mktemp -d "$TEST_TMPDIR/hold.XXXXXX")
  cp "$FK_SRC_29" "$hold/29-independent-review.sh"
  rm "$FK_SRC_29"
  # 源件已移走：重新执行 setup 的 fail-fast 检查（同一逻辑），期望失败。
  run bash -c "
    d='${BATS_TEST_DIRNAME:-.}'
    while [ \"\$d\" != / ] && [ ! -f \"\$d/flow-kit-bundle/hooks/stop/29-independent-review.sh\" ]; do d=\$(dirname \"\$d\"); done
    src=\"\$d/flow-kit-bundle/hooks/stop/29-independent-review.sh\"
    if [ -f \"\$src\" ]; then echo 'STILL-PRESENT'; exit 0; else echo '缺失仓库源件：'\"\$src\"; exit 1; fi
  "
  [ "$status" -eq 1 ]          # fail-fast 命中 ⇒ 红
  [ "$output" != "STILL-PRESENT" ]
  # 复原并校验逐字一致（cp 回来 + cmp -s，不用 mv）
  cp "$hold/29-independent-review.sh" "$FK_SRC_29"
  cmp -s "$hold/29-independent-review.sh" "$FK_SRC_29"
  restore_rc=$?
  [ "$restore_rc" -eq 0 ]      # cmp 一致 ⇒ 复原成功
}

# ── stop-hook.json 未被修改（D5 决策） ─────────────────────────────────
# 例外（判据⑤）：本用例属「已安装环境」面（stop-hook.json 仅存在于 $HOME 安装态，
# 非仓库源件）。文件不存在或 jq 不可用时必须显式 skip，禁止静默回落/恒真。
# C14-c 显式化（AC-12-c · T15 修）：安装态环境探针——与 HOME夹具自包含 豁免族不同，
# 判定值取自 $HOME 安装态是本用例固有语义（环境面残留检查）；skip 已打印原因（合规
# 终态），在场时 jq 判定照常执行，异机差异由 skip 原因显式可读。

@test "stop-hook.json still has plain model string (not env var placeholder)" {
  if [ ! -f "$HOME/.claude/stop-hook.json" ]; then
    skip "环境面残留：$HOME/.claude/stop-hook.json 不存在（已安装态未部署）"
  fi
  if ! command -v jq >/dev/null 2>&1; then
    skip "环境面残留：jq 不可用"
  fi
  model_val=$(jq -r '.ai.model' "$HOME/.claude/stop-hook.json")
  # Should be a plain string like "deepseek-v4-flash", not an env var ref like "${...}"
  run bash -c "echo '$model_val' | grep -c '^\\\$'"
  [ "$status" -ne 0 ]
}
