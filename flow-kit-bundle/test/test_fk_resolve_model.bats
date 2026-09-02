#!/usr/bin/env bats
# test_fk_resolve_model.bats — fk_resolve_model 五级优先级链测试
# 覆盖 AC-1(L3 全链) / AC-2(L3 P1 命中·CC 不变) / AC-3(L2 全链)
# l2-l3-model-config (ADR-012) + l3-default-model 站点级默认（tier-4/5）

# 向上查找 flow-kit-bundle/hooks/（对齐 test_common.bats 模式）
setup() {
  BATS_ROOT="${BATS_TEST_DIRNAME:-.}"
  while [ ! -f "$BATS_ROOT/flow-kit-bundle/hooks/stop/lib/common.sh" ] && [ "$BATS_ROOT" != "/" ]; do
    BATS_ROOT="$(dirname "$BATS_ROOT")"
  done
  COMMON_SH="$BATS_ROOT/flow-kit-bundle/hooks/stop/lib/common.sh"
  [ -f "$COMMON_SH" ] || { skip "common.sh not found"; }
  export HOOK_BASE_DIR="$BATS_ROOT/flow-kit-bundle/hooks/stop"
  # 每用例独立 PROJECT_ROOT（临时 .flow-active）
  export PROJECT_ROOT="$(mktemp -d)"
}

teardown() {
  [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT" ] && rm -rf "$PROJECT_ROOT"
}

# helper: 写临时 .flow-active（含 goal.l2_model / l3_model）
_make_flow() {
  local l2="$1" l3="$2"
  jq -n --arg l2 "$l2" --arg l3 "$l3" '{goal:{l2_model:$l2, l3_model:$l3}}' \
    > "$PROJECT_ROOT/.flow-active"
}

# helper: 清空所有 model env var（场景隔离）
_clear_model_env() {
  unset ANTHROPIC_DEFAULT_HAIKU_MODEL FLOW_KIT_L3_MODEL ANTHROPIC_L2_MODEL FLOW_KIT_L2_MODEL
  unset FLOW_KIT_L3_DEFAULT_MODEL FLOW_KIT_L2_DEFAULT_MODEL
}

# helper: 写站点级默认（.goal.l3_default_model / l2_default_model）
_set_defaults() {
  local l2d="$1" l3d="$2"
  jq --arg l2d "$l2d" --arg l3d "$l3d" \
    '.goal.l2_default_model = (if $l2d == "" then null else $l2d end)
     | .goal.l3_default_model = (if $l3d == "" then null else $l3d end)' \
    "$PROJECT_ROOT/.flow-active" > "$PROJECT_ROOT/.flow-active.tmp" \
    && mv "$PROJECT_ROOT/.flow-active.tmp" "$PROJECT_ROOT/.flow-active"
}

# ── L3 场景 ──

@test "L3-A: P1(ANTHROPIC_DEFAULT_HAIKU_MODEL) 命中，截断 P2/P3 (AC-2)" {
  _clear_model_env
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="haiku-p1"
  export FLOW_KIT_L3_MODEL="flash-p2"
  _make_flow "" "cfg-p3"
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L3")" = "haiku-p1" ]
}

@test "L3-B: P2(FLOW_KIT_L3_MODEL) 命中，压制 P3" {
  _clear_model_env
  export FLOW_KIT_L3_MODEL="flash-p2"
  _make_flow "" "cfg-p3"
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L3")" = "flash-p2" ]
}

@test "L3-C: P3(.flow-active.goal.l3_model) 命中" {
  _clear_model_env
  _make_flow "" "cfg-p3"
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L3")" = "cfg-p3" ]
}

@test "L3-D: 全空 → 返回空字符串(降级)" {
  _clear_model_env
  _make_flow "" ""
  source "$COMMON_SH"
  [ -z "$(fk_resolve_model "L3")" ]
}

@test "L3-E: 三级同设 → 返回 P1" {
  _clear_model_env
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="l3-p1"
  export FLOW_KIT_L3_MODEL="l3-p2"
  _make_flow "" "l3-p3"
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L3")" = "l3-p1" ]
}

# ── L2 场景 ──

@test "L2-A: P1(ANTHROPIC_L2_MODEL) 命中，截断 P2/P3" {
  _clear_model_env
  export ANTHROPIC_L2_MODEL="sonnet-p1"
  export FLOW_KIT_L2_MODEL="gpt-p2"
  _make_flow "cfg-p3" ""
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L2")" = "sonnet-p1" ]
}

@test "L2-B: P2(FLOW_KIT_L2_MODEL) 命中，压制 P3" {
  _clear_model_env
  export FLOW_KIT_L2_MODEL="gpt-p2"
  _make_flow "cfg-p3" ""
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L2")" = "gpt-p2" ]
}

@test "L2-C: P3(.flow-active.goal.l2_model) 命中" {
  _clear_model_env
  _make_flow "cfg-p3" ""
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L2")" = "cfg-p3" ]
}

@test "L2-D: 全空 → 返回空字符串(降级，无 fallback)" {
  _clear_model_env
  _make_flow "" ""
  source "$COMMON_SH"
  [ -z "$(fk_resolve_model "L2")" ]
}

@test "L2-E: 三级同设 → 返回 P1" {
  _clear_model_env
  export ANTHROPIC_L2_MODEL="l2-p1"
  export FLOW_KIT_L2_MODEL="l2-p2"
  _make_flow "l2-p3" ""
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L2")" = "l2-p1" ]
}

# ── 站点级默认（tier-4 env / tier-5 持久化）──

@test "L3-F: 前三级空 + FLOW_KIT_L3_DEFAULT_MODEL → 命中默认(AC-default)" {
  _clear_model_env
  export FLOW_KIT_L3_DEFAULT_MODEL="site-default-l3"
  _make_flow "" ""
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L3")" = "site-default-l3" ]
}

@test "L3-G: 前四级空 + .goal.l3_default_model → 命中持久化默认" {
  _clear_model_env
  _make_flow "" ""
  _set_defaults "" "persist-default-l3"
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L3")" = "persist-default-l3" ]
}

@test "L3-H: 显式模型(P2) 压过站点默认(tier-4/5)" {
  _clear_model_env
  export FLOW_KIT_L3_MODEL="explicit-l3"
  export FLOW_KIT_L3_DEFAULT_MODEL="site-default-l3"
  _make_flow "" ""
  _set_defaults "" "persist-default-l3"
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L3")" = "explicit-l3" ]
}

@test "L2-F: 前三级空 + FLOW_KIT_L2_DEFAULT_MODEL → 命中默认" {
  _clear_model_env
  export FLOW_KIT_L2_DEFAULT_MODEL="site-default-l2"
  _make_flow "" ""
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L2")" = "site-default-l2" ]
}

@test "L2-G: 前四级空 + .goal.l2_default_model → 命中持久化默认" {
  _clear_model_env
  _make_flow "" ""
  _set_defaults "persist-default-l2" ""
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L2")" = "persist-default-l2" ]
}

@test "L2-H: 显式模型(P3 持久化) 压过站点默认(tier-4/5)" {
  _clear_model_env
  export FLOW_KIT_L2_DEFAULT_MODEL="site-default-l2"
  _make_flow "explicit-persist-l2" ""
  _set_defaults "persist-default-l2" ""
  source "$COMMON_SH"
  [ "$(fk_resolve_model "L2")" = "explicit-persist-l2" ]
}
