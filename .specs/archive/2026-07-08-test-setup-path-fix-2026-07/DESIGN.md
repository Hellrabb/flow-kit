# DESIGN: 修 10+ 测试 setup 路径 + Makefile test 管道漏洞

- **Change ID**: test-setup-path-fix-2026-07
- **关联**: `@.specs/test-setup-path-fix-2026-07/CHANGE.md`、`REQUIREMENT.md`

## 0 · 变更摘要

纯 bug 修复：10+ 测试 setup 路径缺 `flow-kit-bundle/` 层 → 改位置无关；Makefile test target 管道漏洞复核。无新功能，无架构变更。

## 0.4 · 架构级预检

**未命中**（纯 bug 修复 + 配置调整，0-change 0.4 白名单）。无需 A-architect。

## 0.5 · 既有架构对齐

- 沿用 health-cleanup-2026-07-08 T01 的**位置无关根治模式**（向上查找目标文件，已验证双源正确）
- Makefile 已用 recipe 内 `command -v`（health-cleanup T02），test target 同理确保 exit code 不被管道吃

## 修法设计

### 修法 A · 测试 setup 路径位置无关化

把 source 目标从 `$(dirname)/../hooks/...`（缺 `flow-kit-bundle/`）改为向上查找目标 lib。通用模式：

```bash
# 以 done-validation.sh 为例
local d
d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
while [ "$d" != "/" ] && [ ! -f "$d/flow-kit-bundle/hooks/stop/lib/done-validation.sh" ]; do
  d="$(dirname "$d")"
done
DONE_VALIDATION_LIB="$d/flow-kit-bundle/hooks/stop/lib/done-validation.sh"
```

**逐文件确认 source 目标**（不能批量替换，每个文件 source 的 lib 不同）：

| 文件 | source 目标 | 当前路径模式 |
|---|---|---|
| test_l2_l3_granular_gate | done-validation.sh | `$(dirname)/../hooks/stop/lib/...` |
| test_dual_review_merge | l3-review.sh + done-validation.sh | 同上 |
| test_correction_file | correction-file.sh (HOOK_BASE_DIR) | `$(dirname)/../hooks/stop` |
| test_flow_active_integrity | hooks/stop (HOOK_BASE_DIR) | 同上 |
| test_checkpoint | checkpoint-lib.sh (cp) | `$(dirname)/../hooks/stop/lib/...` |
| test_setup_integrity | hooks/stop/lib (BUNDLE_DIR) | `$(dirname)/..` |
| test_l2_l3_fix_compliance | hooks/stop/lib (TEST_ROOT) | `$(dirname)/..` |
| test_l3_async_dispatch | l3-review.sh (TEST_ROOT) | `$(dirname)/..` |
| test_smoke_syntax | REPO_ROOT | `$(dirname)/../..` |
| done-skip / l2-detect / l3-truncation / phase-resolution | common.sh / l2-detect.sh / l3-review.sh | `${BATS_TEST_DIRNAME}/../hooks/...` |

### 修法 B · Makefile test target 管道漏洞

- line 12 `@npx bats test/ --formatter tap 2>&1 | tail -3`（展示用，exit code 被 tail 吃）
- line 13 `@npx bats test/ > /dev/null 2>&1 && echo ✅ || exit 1`（判定行，**已直接用 bats exit，正确**）
- 复核：line 12 不影响判定。加 `set -o pipefail` 或注释说明，防混淆

### 修法 C · 暴露的真 fail 迭代处理

修路径后 source 成功，之前因函数未定义被掩盖的真 fail 会显现（Wave 2 处理）：
- 真 bug（如 fk_validate_done_marker 逻辑）→ 修
- 测试断言过时 → 修测试
- 复杂 → 记 TD，独立 change

## 风险

- 逐文件路径修法工作量（10+ 文件，每个 source 目标不同）
- 暴露真 fail 增加修复量（不可预估，Wave 2 迭代）
- 双源同步（每改一处同步 `flow-kit-bundle/test/`）

## ADR

无（纯 bug 修复，无不可逆决策）
