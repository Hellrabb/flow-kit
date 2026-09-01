#!/bin/bash
# stop-hook common library — shared functions for all stop hook modules
# Source this file: source "${HOOK_BASE_DIR}/lib/common.sh"

set -euo pipefail

# ── Runtime adapter (platform decoupling · dsh-flow-kit) ─────────────
# Single source for dsh|opencode|claude detection and path defaults.
# Pure function definitions only — source-safe for every hook.
# shellcheck source=/dev/null
# 注意：必须用 BASH_SOURCE[0]（common.sh 自身位置）定位，而不是调用方可能
# 已设为 session-start/ 的 HOOK_BASE_DIR（stop-report-reminder.sh 的调用形态）。
_RUNTIME_ADAPTER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/runtime-adapter.sh"
if [ -f "$_RUNTIME_ADAPTER" ]; then
  source "$_RUNTIME_ADAPTER"
fi
unset _RUNTIME_ADAPTER

# ── Config ──────────────────────────────────────────────────────────
# CONFIG_FILE is resolved in init_paths() because it depends on PROJECT_ROOT.
# Override via env var STOP_HOOK_CONFIG before sourcing; default: <project>/.claude/stop-hook.json
: "${CONFIG_FILE:=}"  # 仅在未设时设默认值，不覆盖调用方已设的值

# Read a config value with jq, return default if missing
config_get() {
  local key="$1" default="${2:-}"
  if [[ ! -f "$CONFIG_FILE" ]]; then echo "$default"; return; fi
  local val
  val=$(jq -r "$key // \"$default\"" "$CONFIG_FILE" 2>/dev/null) || true
  echo "${val:-$default}"
}

# Check if a module is enabled
module_enabled() {
  local mod="$1"
  local en
  en=$(config_get ".modules[\"${mod}\"].enabled" "false")
  [[ "$en" == "true" ]]
}

# Check if a specific check is enabled
check_enabled() {
  local mod="$1" check="$2"
  local en
  en=$(config_get ".modules[\"${mod}\"].enabled" "false")
  [[ "$en" != "true" ]] && return 1
  # If checks array is empty or not defined, all are enabled
  local has_checks
  has_checks=$(jq -r ".modules[\"${mod}\"].checks // [] | length" "$CONFIG_FILE" 2>/dev/null || echo "0")
  if [[ "$has_checks" == "0" ]]; then return 0; fi
  jq -e ".modules[\"${mod}\"].checks | index(\"$check\")" "$CONFIG_FILE" >/dev/null 2>&1
}

# ── run_check() · check 统一包装（DESIGN D3 · sweep-fix-2026-07-10）──
# 用法: run_check <module> <check_id> [precondition_file] <body_function>
#   module: 模块名 ("git", "memory", "quality", ...)
#   check_id: check 代码 ("C1", "B2", ...)
#   precondition_file: 可选，HOOK_TMP_DIR 下的文件名（跳过检查若文件不存在/为空）
#   body_function: 实际 check 逻辑的函数名（同文件中已定义）
# 消除 30 处 check_enabled 模板重复——各模块 check_XX() 改为 1 行调用此函数。
run_check() {
  local mod="$1" check_id="$2" precondition_file="$3" body_fn="$4"
  check_enabled "$mod" "$check_id" || return 0
  if [[ -n "$precondition_file" ]]; then
    [[ -f "$HOOK_TMP_DIR/$precondition_file" && -s "$HOOK_TMP_DIR/$precondition_file" ]] || return 0
  fi
  "$body_fn"
}

# ── Environment (set by hook_init, inherited via export for subprocesses) ─
# Use := to only set defaults, never overwrite values exported from parent
: "${HOOK_EVENT:=}"
: "${SESSION_ID:=}"
: "${TRANSCRIPT_PATH:=}"
: "${CWD:=}"
: "${PARENT_SESSION:=}"
: "${HOOK_TMP_DIR:=}"
: "${STOP_COUNT:=0}"

# Initialize hook environment from stdin JSON
# Call once per hook run, before any module
hook_init() {
  HOOK_INPUT=$(cat)

  # Extract fields (jq not guaranteed available, use fallback)
  if command -v jq &>/dev/null; then
    HOOK_EVENT=$(echo "$HOOK_INPUT" | jq -r '.hook_event_name // ""')
    SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // "unknown"')
    TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // ""')
    CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // ""')
    PARENT_SESSION=$(echo "$HOOK_INPUT" | jq -r '.parent_session_id // ""')
  else
    HOOK_EVENT="Stop"
    SESSION_ID="unknown"
    TRANSCRIPT_PATH=""
    CWD="$PWD"
    PARENT_SESSION=""
  fi

  export HOOK_EVENT SESSION_ID TRANSCRIPT_PATH CWD PARENT_SESSION

  # Create temp dir for this run
  HOOK_TMP_DIR=$(mktemp -d "/tmp/flow-kit-stop-hook-XXXXXX")
  export HOOK_TMP_DIR

  # Store raw input for debugging
  echo "$HOOK_INPUT" > "$HOOK_TMP_DIR/hook-input.json"
}

# ── Path initialization (call after hook_init) ───────────────────────
# Paths that depend on CWD from stdin must be set after hook_init
init_paths() {
  # FLOW_KIT_PROJECT_DIR is the platform-agnostic override (dsh plugin sets it);
  # CWD comes from the synthesized hook event on stdin. Legacy claude fallback
  # keeps identical behavior when neither is set.
  PROJECT_ROOT="${FLOW_KIT_PROJECT_DIR:-${CWD:-$PWD}}"

  # Runtime-aware config directory: .flow-kit (dsh) | .claude (claude/opencode
  # compatibility). FLOW_KIT_CONFIG_DIR lets a host pin an explicit override.
  local config_dir runtime_home
  config_dir="${FLOW_KIT_CONFIG_DIR:-$(fk_runtime_config_dir)}"
  runtime_home="$(fk_runtime_home_dir)"

  # Derive CONFIG_FILE: env override > project-level > user-scope fallback
  # (gate-integrity dogfood: 项目级缺失时回退 user-scope，否则全局 enabled=true 未被读 → module_enabled 恒 false)
  if [[ -z "${CONFIG_FILE:-}" ]]; then
    CONFIG_FILE="${STOP_HOOK_CONFIG:-${PROJECT_ROOT}/${config_dir}/stop-hook.json}"
    if [[ ! -f "$CONFIG_FILE" && -f "${runtime_home}/stop-hook.json" ]]; then
      CONFIG_FILE="${runtime_home}/stop-hook.json"
    fi
  fi

  # Variable name kept for downstream-module compatibility; the path is
  # runtime-aware (AGENTS.md on dsh, CLAUDE.md on claude/opencode).
  CLAWDE_MD="${PROJECT_ROOT}/$(fk_runtime_md_file)"

  # Derive memory dir from PROJECT_ROOT (runtime-aware: ~/.dsh/projects… on dsh,
  # legacy ~/.claude/projects… otherwise; / → - slug convention unchanged).
  MEMORY_DIR="$(fk_runtime_memory_dir "$PROJECT_ROOT")"
  MEMORY_INDEX="${MEMORY_DIR}/MEMORY.md"

  local output_default
  output_default="${config_dir}/stop-hook-report.md"
  REPORT_FILE="${PROJECT_ROOT}/$(config_get '.output.report_file' "$output_default")"
  SUGGESTIONS_FILE="${PROJECT_ROOT}/$(config_get '.output.suggestions_file' "${config_dir}/stop-hook-suggestions.md")"
  STATE_FILE="${PROJECT_ROOT}/${config_dir}/stop-hook-state.json"

  export PROJECT_ROOT CONFIG_FILE CLAWDE_MD MEMORY_DIR MEMORY_INDEX
  export REPORT_FILE SUGGESTIONS_FILE STATE_FILE
}

# ── Gate: Subagent Isolation ────────────────────────────────────────
# Stop hook fires for main sessions AND subagents (SubagentStop event).
# subagent events carry parent_session_id. Gate them out.
is_subagent() {
  [[ "$HOOK_EVENT" == "SubagentStop" ]] && return 0
  [[ -n "$PARENT_SESSION" ]] && return 0
  return 1
}

# ── Output helpers ──────────────────────────────────────────────────
# Each module writes findings to $HOOK_TMP_DIR/<module>.txt
# Format: TYPE|CHECK|MESSAGE
# TYPE = suggestion | warning | error | info
# CHECK = check code (A1, B2, C3, etc.)
# MESSAGE = human-readable message (can contain markdown)

module_output() {
  local type="$1" check="$2" message="$3"
  local mod_name
  mod_name=$(basename "$0" .sh | sed 's/^[0-9][0-9]-//')
  echo "${type}|${check}|${message}" >> "$HOOK_TMP_DIR/${mod_name}.txt"
}


# ── File helpers ────────────────────────────────────────────────────
# Count lines in file, 0 if missing
line_count() { wc -l < "$1" 2>/dev/null || echo "0"; }

# Atomically apply a jq filter to a JSON file (write to .tmp then mv).
# Usage: jq_atomic_write '<jq filter>' <target_file>
# Returns: 0 on success, 1 on failure (file unchanged)
jq_atomic_write() {
  local filter="$1" target="$2"
  if [[ ! -f "$target" ]]; then return 1; fi
  jq "$filter" "$target" > "${target}.tmp" 2>/dev/null && mv "${target}.tmp" "$target" || return 1
}

# ── Git helpers ─────────────────────────────────────────────────────
# Run git command if in a git repo
git_safe() {
  if git rev-parse --git-dir >/dev/null 2>&1; then
    git "$@"
  else
    return 1
  fi
}

# ── Project paths (set by init_paths() after hook_init) ──────────────
: "${PROJECT_ROOT:=}"
: "${CLAWDE_MD:=}"
: "${MEMORY_DIR:=}"
: "${MEMORY_INDEX:=}"
: "${REPORT_FILE:=}"
: "${SUGGESTIONS_FILE:=}"
: "${STATE_FILE:=}"

# ── fk_resolve_phase() · Pipeline-aware phase resolution ──────────────
# Resolve the active phase from .flow-active.
# Pipeline mode (goal.scope="pipeline"): use goal.current_phase
# Single-phase mode: fall back to .phase
# Outputs the resolved phase string to stdout.
# Returns 0 on success, 1 if .flow-active missing or unreadable.
fk_resolve_phase() {
  local flow_file="${PROJECT_ROOT}/.flow-active"
  [[ -f "$flow_file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  local scope phase
  scope=$(jq -r '.goal.scope // ""' "$flow_file" 2>/dev/null || echo "")

  if [[ "$scope" == "pipeline" ]]; then
    phase=$(jq -r '.goal.current_phase // ""' "$flow_file" 2>/dev/null || echo "")
    # Validate: must be a non-empty phase number (0-7)
    if [[ "$phase" =~ ^[0-7]$ ]]; then
      echo "$phase"
      return 0
    fi
    # Pipeline but current_phase invalid/empty → fall through to .phase
  fi

  # Fallback: single-phase mode or pipeline with invalid current_phase
  phase=$(jq -r '.phase // "?"' "$flow_file" 2>/dev/null || echo "?")
  echo "$phase"
  return 0
}

# ── fk_resolve_model() · L2/L3 model resolution (3-tier priority chain) ──
# l2-l3-model-config (ADR-012, supersedes ADR-006)
# Resolve the review model name for a layer via priority chain (each tier:
# first non-empty wins, stop):
#   L3: ANTHROPIC_DEFAULT_HAIKU_MODEL > FLOW_KIT_L3_MODEL > .flow-active.goal.l3_model > ""
#   L2: ANTHROPIC_L2_MODEL             > FLOW_KIT_L2_MODEL > .flow-active.goal.l2_model > ""
# Usage: model=$(fk_resolve_model "L3")  or  model=$(fk_resolve_model "L2")
# Pure query: writes nothing, calls no API, returns 0 always.
# Empty stdout = all sources unconfigured → caller handles graceful degradation.
# Uses ${PROJECT_ROOT:-} to survive `set -u` when PROJECT_ROOT unset (DESIGN §2 R5).
fk_resolve_model() {
  local layer="$1"
  local model=""

  if [[ "$layer" == "L3" ]]; then
    model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"
    [[ -n "$model" ]] || model="${FLOW_KIT_L3_MODEL:-}"
    [[ -n "$model" ]] || model=$(jq -r '.goal.l3_model // ""' "${PROJECT_ROOT:-}/.flow-active" 2>/dev/null || echo "")
  elif [[ "$layer" == "L2" ]]; then
    model="${ANTHROPIC_L2_MODEL:-}"
    [[ -n "$model" ]] || model="${FLOW_KIT_L2_MODEL:-}"
    [[ -n "$model" ]] || model=$(jq -r '.goal.l2_model // ""' "${PROJECT_ROOT:-}/.flow-active" 2>/dev/null || echo "")
  fi

  echo "$model"
}

# ── fk_resolve_api_credentials() · 多平台 L3 凭证解析（DESIGN D1 · l2l3-cross-platform + dsh）──
# 三 Path 优先级链（命中即停，短路语义；Path1/Path3 相对顺序随平台翻转 —— T01-rev）：
#   claude code（fk_platform_prefers_flowkit_credentials 假）: Path1 > Path3 > Path2（零回归）
#     Path1: ANTHROPIC_AUTH_TOKEN → bearer（claude code 原生主路径，零回归）
#   opencode / dsh（fk_platform_prefers_flowkit_credentials 真）: Path3 > Path1 > Path2
#     Path3: FLOW_KIT_L3_AUTH_TOKEN + FLOW_KIT_L3_BASE_URL → bearer（平台一等路径，短路 Path2）
#   Path2: ANTHROPIC_API_KEY → x-api-key（legacy 兜底，仅当 Path1/3 全空，端点 api.anthropic.com）
# 输出（全局，调用方读这三个全局，不重读 env）：
#   FK_API_BASE_URL / FK_API_AUTH_TOKEN / FK_API_AUTH_SCHEME（bearer | x-api-key）
# rc 语义：0=凭证就绪 / 1=无任何凭证 / 2=Path3 配置不完整（token 已设但 base_url 空 → stderr 报错，禁止静默落 Path2）
# AC-6 红线：凭证完整名/值绝不落盘——本函数不 echo 凭证到 stdout，只写全局变量；
# stderr 提示只含 env 变量名（不含值），调用方可据此记录 credential source（env|flow-kit）。
# 所有 env 用 ${VAR:-} 读取（set -u 兼容）。
# 私有辅助（_fk_api_* 前缀 · 文件内可见 · 公共签名不变）：
#   _fk_api_try_path1 / _fk_api_try_path3 — Path 命中判定（设置 FK_API_* 全局后 return 0；
#     未命中 return 1；Path3 token 有 base_url 空 → stderr 报错 + 清空全局 + return 2）
#   _fk_api_clear_outputs — 清空 FK_API_* 三全局（rc=2 / rc=1 分支复用）
_fk_api_try_path1() {
  [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ] || return 1
  FK_API_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN}"
  FK_API_BASE_URL="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
  FK_API_AUTH_SCHEME="bearer"
  return 0
}

_fk_api_try_path3() {
  [ -n "${FLOW_KIT_L3_AUTH_TOKEN:-}" ] || return 1
  if [ -n "${FLOW_KIT_L3_BASE_URL:-}" ]; then
    FK_API_AUTH_TOKEN="${FLOW_KIT_L3_AUTH_TOKEN}"
    FK_API_BASE_URL="${FLOW_KIT_L3_BASE_URL}"
    FK_API_AUTH_SCHEME="bearer"
    return 0
  fi
  echo "fk_resolve_api_credentials: FLOW_KIT_L3_AUTH_TOKEN 已设但 FLOW_KIT_L3_BASE_URL 为空（Path3 配置不完整，rc=2）" >&2
  _fk_api_clear_outputs
  return 2
}

_fk_api_clear_outputs() {
  FK_API_AUTH_TOKEN=""
  FK_API_BASE_URL=""
  FK_API_AUTH_SCHEME=""
}

fk_resolve_api_credentials() {
  # 平台感知优先级（DESIGN D1 · F-B 修订）：两平台仅 Path1/Path3 相对顺序不同；
  # 公共规则（Path1/3 任一命中短路 Path2；Path3 配置不完整 rc=2 禁落 Path2；Path2 仅当 Path1/3 全空）一致。
  if fk_platform_prefers_flowkit_credentials; then
    # ── opencode / dsh 平台: Path3 > Path1 > Path2（残留 ANTHROPIC_AUTH_TOKEN 不压制 FLOW_KIT_L3_*）──
    _fk_api_try_path3 && return 0
    [ "$?" -eq 2 ] && return 2
    _fk_api_try_path1 && return 0
  else
    # ── claude code 平台: Path1 > Path3 > Path2（零回归）──
    _fk_api_try_path1 && return 0
    _fk_api_try_path3 && return 0
    [ "$?" -eq 2 ] && return 2
  fi

  # Path2: legacy 兜底（ANTHROPIC_API_KEY，两平台共享 · 仅当 Path1/3 全空）
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    # shellcheck disable=SC2034  # 全局：l3-api.sh 跨文件消费
    FK_API_AUTH_TOKEN="${ANTHROPIC_API_KEY}"
    # shellcheck disable=SC2034  # 全局：l3-api.sh 跨文件消费
    FK_API_BASE_URL="https://api.anthropic.com"
    # shellcheck disable=SC2034  # 全局：l3-api.sh 跨文件消费
    FK_API_AUTH_SCHEME="x-api-key"
    return 0
  fi

  # 全空 → rc=1，清空全局
  _fk_api_clear_outputs
  return 1
}

# ── fk_platform_is_opencode() · 多平台检测（DESIGN D2 · l2l3-cross-platform + dsh）──
# Delegates to runtime-adapter.sh: FLOW_KIT_RUNTIME explicit > OPENCODE_BIN /
# OPENCODE signals > claude default. dsh 通过 FLOW_KIT_RUNTIME=dsh 进入
# fk_platform_is_dsh 分支，opencode 信号语义保持不变（零回归）。
# 纯查询零副作用：不写全局、不落盘、不调用外部命令。
# 用法: if fk_platform_is_opencode; then ...; fi  （返回 0=opencode / 1=非 opencode）
fk_platform_is_opencode() {
  [ "$(fk_runtime_detect)" = "opencode" ]
}

# ── Hook module registry (single source of truth) ────────────────────
# All consumers iterate: for name in "${HOOK_MODULE_NAMES[@]}"; do ...
# Single source for install_hooks.sh, package-flow-kit.sh, and any
# future script that needs to enumerate all stop hook modules.
# shellcheck disable=SC2034  # 跨文件单一源：install_hooks.sh / package-flow-kit.sh 枚举消费
declare -a HOOK_MODULE_NAMES=(
  00-gate 01-transcript-parse
  20-claude-md 21-memory 22-git 23-quality 24-session 25-project
  26-workflow 27-interactive-ui-check 28-weak-model-compliance
  29-independent-review 30-ai-analyze 31-auto-advance 32-fallback-guard 33-flow-active-integrity 34-archive-commit-check 99-report
)

# fk_phase_gate_key — phase number → gate_config key for independent review lookups.
# Single source（ADR-007 / D1 · l2-l3-mock-fix）：5 执行消费者（gate.sh:395/413 + 29:77/117/155）
# + 1 文档注释引用本 pure fn，不再 declare -A（消除 v1 重复 declare 的 DRY 违反 = BUG-F 温床）。
# Phase 0（change）and Phase 4（dev）are intentionally excluded — they have no independent review gate.
# If a gate is added for either phase in the future, ALL four layers must be updated:
#   PRESET_MAP + Prompt template + L2-blind-review.md checklist + this fn.
# 用法: local gate_key="$(fk_phase_gate_key "$phase")"
fk_phase_gate_key() {
  case "$1" in
    1) echo "1-requirement" ;;
    2) echo "2-design" ;;
    3) echo "3-task" ;;
    5) echo "5-test" ;;
    6) echo "6-review" ;;
    7) echo "7-integration" ;;
    *) echo "" ;;
  esac
}

# fk_normalize_gate_val — gate_config value normalizer（ADR-007 / D1 · gate-review-fix）
# Single source for gate_val normalization across 4 consumers (3 files).
# Normalization rules:
#   independent|true → both   (backward-compat aliases)
#   L2|L3|both        → keep  (passthrough valid values)
#   other/empty       → ""    (unknown → treat as off)
# 用法: gate_val="$(fk_normalize_gate_val "$raw_val")"
fk_normalize_gate_val() {
  local raw="${1:-}"
  case "$raw" in
    independent|true) echo "both" ;;
    L2|L3|both) echo "$raw" ;;
    *) echo "" ;;
  esac
}

# ══ Token 估算 + 性能计时基础设施（l3-pipeline-fix-2026-07） ══

# fk_estimate_tokens — 轻量 token 估算（字符数 / 2 ≈ token 数 · 中文保守估算）
# 英文实际 ~4 char/token，中文 ~1.5~2 char/token。用 /2 对英文多估 ~2x，
# 但保证中英混合内容不会低估→不会超 context window。安全优先于精确。
# 用法: fk_estimate_tokens <text> [context_window]
# context_window 默认 100000，可通过 FK_CONTEXT_WINDOW 环境变量覆盖
fk_estimate_tokens() {
  local text="${1:-}"
  # shellcheck disable=SC2034  # 接口参数保留：FK_CONTEXT_WINDOW 由 l3-prompt.sh 消费 + test_common.bats 覆盖
  local context_window="${2:-${FK_CONTEXT_WINDOW:-100000}}"
  local char_count=${#text}
  local estimated=$(( char_count / 2 ))
  echo "$estimated"
}

# _FK_PERF_TIMINGS — 全局性能计时关联数组（label → elapsed_seconds）
# 由 fk_perf_timing_start/end 读写；99-report.sh 汇总输出
declare -A _FK_PERF_TIMINGS 2>/dev/null || true

# fk_perf_timing_start — 记录起始时间
# 用法: fk_perf_timing_start <label>
fk_perf_timing_start() {
  local label="${1:-unknown}"
  _FK_PERF_TIMINGS["${label}_start"]=$SECONDS
}

# fk_perf_timing_end — 计算耗时并输出
# 用法: fk_perf_timing_end <label>
# fail-open：未先调 start 时仅警告，不退出（避免阻断 hook 链）
fk_perf_timing_end() {
  local label="${1:-unknown}"
  local start_time="${_FK_PERF_TIMINGS[${label}_start]:-}"
  if [ -z "$start_time" ]; then
    echo "[perf] WARNING: fk_perf_timing_end('$label') called without prior fk_perf_timing_start()" >&2
    return 0
  fi
  local elapsed=$(( SECONDS - start_time ))
  _FK_PERF_TIMINGS["$label"]=$elapsed
}
