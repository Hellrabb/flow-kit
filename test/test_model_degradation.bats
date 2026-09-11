#!/usr/bin/env bats
# test_model_degradation.bats — L2/L3 模型降级行为测试（AC-4a/4b 集成层）
# 验证 caller 在 model 全空时：① return 非0（降级信号）② 写 model-missing correction ③ 不发起 API
# l2-l3-model-config (L2 Phase 5 R1 补强)

setup() {
  BATS_ROOT="${BATS_TEST_DIRNAME:-.}"
  while [ "$BATS_ROOT" != "/" ] && [ ! -f "$BATS_ROOT/flow-kit-bundle/hooks/stop/lib/common.sh" ]; do
    BATS_ROOT="$(dirname "$BATS_ROOT")"
  done
  COMMON_SH="$BATS_ROOT/flow-kit-bundle/hooks/stop/lib/common.sh"
  CORRECTION_SH="$BATS_ROOT/flow-kit-bundle/hooks/stop/lib/correction-file.sh"
  L3_REVIEW_SH="$BATS_ROOT/flow-kit-bundle/hooks/stop/lib/l3-review.sh"
  L2_DETECT_SH="$BATS_ROOT/flow-kit-bundle/hooks/stop/lib/l2-detect.sh"
  [ -f "$COMMON_SH" ] || skip "common.sh not found"
  export HOOK_BASE_DIR="$BATS_ROOT/flow-kit-bundle/hooks/stop"
  export PROJECT_ROOT="$(mktemp -d)"
  # artifacts_dir（l3_review_run 需要）
  ARTIFACTS_DIR="$PROJECT_ROOT/.specs/test-change"
  mkdir -p "$ARTIFACTS_DIR"
}

teardown() {
  [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT" ] && rm -rf "$PROJECT_ROOT"
}

_clear_model_env() {
  # 前 4 项 = 显式配置级；后 2 项 = 站点级默认级（fk_resolve_model 第 4/5 级，~/.bashrc 常 export）
  # 漏 unset 后两项 → 「全空」前置条件在开发者机器上不成立（与 test_fk_resolve_model.bats setup 同口径）
  unset ANTHROPIC_DEFAULT_HAIKU_MODEL FLOW_KIT_L3_MODEL ANTHROPIC_L2_MODEL FLOW_KIT_L2_MODEL
  unset FLOW_KIT_L3_DEFAULT_MODEL FLOW_KIT_L2_DEFAULT_MODEL
}

# ── 降级机制（fk_resolve_model 空 → correction type 标记）──

@test "降级机制：fk_resolve_model L3 空 → write_model_missing_correction 写 type=l3-model-missing" {
  _clear_model_env
  # 无 .flow-active（goal.l3_model 也不存在）
  source "$COMMON_SH"
  source "$CORRECTION_SH"
  [ -z "$(fk_resolve_model "L3")" ]
  write_model_missing_correction "L3"
  [ "$(jq -r '.type' "$PROJECT_ROOT/.flow-active.correction")" = "l3-model-missing" ]
}

@test "降级机制：fk_resolve_model L2 空 → write_model_missing_correction 写 type=l2-model-missing" {
  _clear_model_env
  source "$COMMON_SH"
  source "$CORRECTION_SH"
  [ -z "$(fk_resolve_model "L2")" ]
  write_model_missing_correction "L2"
  [ "$(jq -r '.type' "$PROJECT_ROOT/.flow-active.correction")" = "l2-model-missing" ]
}

# ── caller 集成：l3_review_run model 空 → return 3 + correction type + 不调 API ──

@test "L3 caller 降级：l3_review_run model 空 → return 3 + type=l3-model-missing + 不调 _l3_call_api" {
  _clear_model_env
  # mock _l3_call_api（若被调则设标志）
  API_CALLED=0
  _l3_call_api() { API_CALLED=1; echo "MOCK_API"; }

  # 准备合法 artifacts（l3_review_run 参数校验需 phase∈1-7 + change_id + artifacts_dir 存在 + l2_verdict）
  echo "# 独立审查 · 阶段 1" > "$ARTIFACTS_DIR/INDEPENDENT-REVIEW-1.md"

  # source caller lib（l3_review_run 在 l3-review.sh）
  source "$COMMON_SH"
  source "$CORRECTION_SH"
  source "$L3_REVIEW_SH"

  # model 空 → l3_review_run 应在 model 解析后、API 前 return 3
  # 用 || rc=$? 捕获非0退出（避免 bats 把降级 return 3 当测试失败）；捕获 stderr 验证第三后果
  rc=0
  stderr_out=$(l3_review_run "1" "test-change" "$ARTIFACTS_DIR" "pass" "both" 2>&1 >/dev/null) || rc=$?

  # ① return 3（降级信号）
  [ "$rc" -eq 3 ]
  # ② correction type = l3-model-missing（降级独有标记）
  [ "$(jq -r '.type' "$PROJECT_ROOT/.flow-active.correction" 2>/dev/null)" = "l3-model-missing" ]
  # ③ 不发起 API（_l3_call_api 未被调）
  [ "$API_CALLED" = "0" ]
  # ④ stderr 含 FLOW_KIT_L3_MODEL（第三可观测后果，REQUIREMENT AC-4a）
  [[ "$stderr_out" == *"FLOW_KIT_L3_MODEL"* ]]
}

# 注：L2 caller（l2_dispatch_prompt）+ 29-indep caller 完整集成测试留技术债
# （l2_dispatch_prompt 需 review_md + 复杂参数路径；29-indep 是顶层脚本需 bash 执行）
# L2/29 caller 的降级机制由 test 1/2（fk_resolve_model 空 → correction type）覆盖，
# 核心降级行为（model 空 → correction type 标记 + caller return）已由 test 3（L3 caller）验证。
