#!/usr/bin/env bats
# test_flow_model.bats — /flow model 配置命令 jq 写入逻辑测试（AC-5/5b/5c）
# 验证 jq --arg 防注入 + 原子写 + 字段边界（仅 l2_model/l3_model）
# l2-l3-model-config (L2 Phase 5 R2 补强)

setup() {
  export PROJECT_ROOT="$(mktemp -d)"
  # 初始 .flow-active（goal 存在，含其他字段验证不误碰）
  cat > "$PROJECT_ROOT/.flow-active" << 'EOF'
{"change_id":"fm-test","phase":"4","goal":{"condition":"x","l2_model":null,"l3_model":null,"gate_config":{"6-review":"both"}},"updated_at":"2026-01-01T00:00:00+08:00"}
EOF
}

teardown() {
  [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT" ] && rm -rf "$PROJECT_ROOT"
}

# 模拟 /flow model l3=<m> 的 jq 写入（jq --arg 防注入 + 临时文件 mv 原子写）
_flow_model_set() {
  local field="$1" val="$2"
  jq --arg m "$val" --arg ts "$(date -Iseconds)" \
    ".goal.${field} = \$m | .updated_at = \$ts" \
    "$PROJECT_ROOT/.flow-active" > "$PROJECT_ROOT/.flow-active.tmp" \
    && mv "$PROJECT_ROOT/.flow-active.tmp" "$PROJECT_ROOT/.flow-active"
}

_flow_model_clear() {
  local field="$1"
  jq --arg ts "$(date -Iseconds)" \
    ".goal.${field} = null | .updated_at = \$ts" \
    "$PROJECT_ROOT/.flow-active" > "$PROJECT_ROOT/.flow-active.tmp" \
    && mv "$PROJECT_ROOT/.flow-active.tmp" "$PROJECT_ROOT/.flow-active"
}

@test "AC-5: /flow model l3=deepseek-v4-flash 写入 .goal.l3_model" {
  _flow_model_set "l3_model" "deepseek-v4-flash"
  [ "$(jq -r '.goal.l3_model' "$PROJECT_ROOT/.flow-active")" = "deepseek-v4-flash" ]
}

@test "AC-5: /flow model l2=deepseek-v4-pro 写入 .goal.l2_model" {
  _flow_model_set "l2_model" "deepseek-v4-pro"
  [ "$(jq -r '.goal.l2_model' "$PROJECT_ROOT/.flow-active")" = "deepseek-v4-pro" ]
}

@test "AC-5b: /flow model l2=A l3=B 合并写入（同次 jq 两字段）" {
  jq --arg l2 "model-a" --arg l3 "model-b" --arg ts "$(date -Iseconds)" \
    '.goal.l2_model = $l2 | .goal.l3_model = $l3 | .updated_at = $ts' \
    "$PROJECT_ROOT/.flow-active" > "$PROJECT_ROOT/.flow-active.tmp" \
    && mv "$PROJECT_ROOT/.flow-active.tmp" "$PROJECT_ROOT/.flow-active"
  [ "$(jq -r '.goal.l2_model' "$PROJECT_ROOT/.flow-active")" = "model-a" ]
  [ "$(jq -r '.goal.l3_model' "$PROJECT_ROOT/.flow-active")" = "model-b" ]
}

@test "AC-5c: /flow model --clear l3 → .goal.l3_model = null（回到降级）" {
  _flow_model_set "l3_model" "some-model"
  _flow_model_clear "l3_model"
  [ "$(jq -r '.goal.l3_model' "$PROJECT_ROOT/.flow-active")" = "null" ]
}

@test "字段边界：/flow model 不触碰 goal.condition / gate_config（DESIGN §5）" {
  _flow_model_set "l3_model" "new-model"
  [ "$(jq -r '.goal.condition' "$PROJECT_ROOT/.flow-active")" = "x" ]
  [ "$(jq -r '.goal.gate_config["6-review"]' "$PROJECT_ROOT/.flow-active")" = "both" ]
}

@test "防注入：模型名含特殊字符（jq --arg 安全引用）" {
  _flow_model_set "l3_model" 'model"; rm -rf / #'
  [ "$(jq -r '.goal.l3_model' "$PROJECT_ROOT/.flow-active")" = 'model"; rm -rf / #' ]
  # .flow-active 仍是合法 JSON（注入未破坏结构）
  jq empty "$PROJECT_ROOT/.flow-active"
}
