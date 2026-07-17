# ADR-005 · gate-active source 依赖（done-validation.sh + PROJECT_ROOT）

- **Status**: Accepted
- **Date**: 2026-07-17
- **Change**: l2-l3-test-defect（修 BUG-E）

## Context

`_gate_active_check`（Gate3）判定 phase 是否开启独立审查 gate。旧实现 source `flow-kit-artifacts.sh` 试图获取 `fk_independent_review_gate_active`：

```bash
_gate_active_check() {
  local phase="$1"
  local artifacts_lib="${HOOK_BASE_DIR}/../stop/lib/flow-kit-artifacts.sh"
  source "$artifacts_lib" 2>/dev/null || return 0
  type fk_independent_review_gate_active >/dev/null 2>&1 || return 0
  ...
}
```

但 `fk_independent_review_gate_active` **定义在 `done-validation.sh`**（非 artifacts.sh）。artifacts.sh 注释提及"via done-validation.sh"但未实际 source。

后果（BUG-E）：
- `type fk_independent_review_gate_active` 失败 → `|| return 0`（gate 未开）
- `_gate_active_check` 永远返回"未开"
- Gate3 `exit 0` 放行所有 review phase 的 commit/transition
- **gate 完全失效**（gate_config all 也不拦）

且该函数内部用 `${PROJECT_ROOT}/.flow-active`，PROJECT_ROOT 未设则路径错。

## Decision

`_gate_active_check` source **done-validation.sh**（函数真正定义处）+ 传 `PROJECT_ROOT=cwd`：

```bash
_gate_active_check() {
  local phase="$1" cwdd="${2:-$PWD}"
  local lib_dir="${HOOK_BASE_DIR}/../stop/lib"
  local dv_lib="${lib_dir}/done-validation.sh"
  [ -f "$dv_lib" ] || return 0
  PROJECT_ROOT="$cwdd" source "$dv_lib" 2>/dev/null || return 0
  type fk_independent_review_gate_active >/dev/null 2>&1 || return 0
  PROJECT_ROOT="$cwdd" fk_independent_review_gate_active "$phase" 2>/dev/null || return 0
  return 1
}
```

调用方传 cwd：`_gate_active_check "$phase" "$cwd"`。

## Consequences

✅ `fk_independent_review_gate_active` 可用 → gate_active 正确判定
✅ PROJECT_ROOT=cwd → 函数读对 .flow-active
✅ gate_config all 的 review phase gate 真实生效（phase 1 实跑验证：L2+L3 双 pass + .done）
⚠️ _gate_active_check 接收 cwd 参数（调用方须传）
⚠️ PROJECT_ROOT 环境依赖（fk_validate_done_marker 等也用，须确保设）
