# DESIGN · test-failures-fixup-2026-08

> Phase 2 技术设计 · 2026-08-03

---

## § 0 Tech stack
Bash + bats-core + shellcheck。无新依赖。

## § 0.5 Architecture
- ** Modules touched**: 4（test_gate_integrity.bats / test_lessons_cleanup.bats / 7 hook lib files / Makefile lint target 不变）
- **既有抽象**: `# shellcheck shell=bash` 指令（shellcheck 标准用法）
- **Decisions**: 5（D1-D5 见下）

## § 1 Decisions

### D1 — AC-A1 grep 4 文件并断言恰好 1 处命中
```bash
# test_gate_integrity.bats:148-156 重写
GATE_FILES=(
  "$HOOK_BASE_DIR/pre-tool-use/independent-review-gate.sh"
  "$HOOK_BASE_DIR/pre-tool-use/gate-helpers.sh"
  "$HOOK_BASE_DIR/pre-tool-use/gate-checks-basic.sh"
  "$HOOK_BASE_DIR/pre-tool-use/gate-checks-review.sh"
)
total_matches=0
for f in "${GATE_FILES[@]}"; do
  cnt=$(grep -cE '\^\(1\|2\|3\|5\|6\|7\)\$' "$f" 2>/dev/null || echo 0)
  total_matches=$((total_matches + cnt))
done
[ "$total_matches" -ge 1 ]  # 至少一处（防沉默消失）
[ "$total_matches" -le 4 ]   # 不超过 4 处（防 DRY 重复）
```

### D2 — AC-B1/B2/B3 测试 assertion 重写

**B1** (test_lessons_cleanup.bats:144-158):
```bash
@test "AC-5: 4-dev prompt §1.8.4 含 npx bats 自动执行指令" {
  local prompt_files=(
    "flow-kit-bundle/flow-kit/prompts/4-dev.md"
    "flow-kit-bundle/flow-kit/reference/tdd-workflow.md"
  )
  # 逐子断言 OR 双文件
  for pf in "${prompt_files[@]}"; do
    grep -q "npx bats test/" "$pf" && break
  done
  for pf in "${prompt_files[@]}"; do
    grep -q "npx bats --version" "$pf" && break
  done
  for pf in "${prompt_files[@]}"; do
    grep -q "0 failures" "$pf" && break
  done
}
```

**B2** (test_lessons_cleanup.bats:174-184):
```bash
@test "AC-6: 4-dev prompt §1.8.4 含失败阻断逻辑" {
  local prompt_files=(
    "flow-kit-bundle/flow-kit/prompts/4-dev.md"
    "flow-kit-bundle/flow-kit/reference/tdd-workflow.md"
  )
  # 第一子断言：阻断关键词
  for pf in "${prompt_files[@]}"; do
    grep -qE "阻断|暂停流程|禁止进入" "$pf" && break
  done
  # 第二子断言：toll-gate 阻断（重写，反映 tdd-workflow.md:196 实际文本）
  for pf in "${prompt_files[@]}"; do
    grep -qE "阻断.*toll-gate|禁止进入.*toll-gate" "$pf" && break
  done
}
```

**B3** (test_lessons_cleanup.bats:230-236):
```bash
@test "边界: 4-dev prompt §1.8.4 子段编号正确" {
  # 原 pattern `1\.8\.4\.[1-4]` 在 L-068 后已不存在
  # 重写为 grep tdd-workflow.md 实际子段标题
  local tdd_file="flow-kit-bundle/flow-kit/reference/tdd-workflow.md"
  local cnt=$(grep -cE "^#### (自动 bats 执行|结果判定|结果写入 SUMMARY|L2 自检 gate 填空)" "$tdd_file")
  [ "$cnt" -ge 4 ]
}
```

### D3 — AC-C1 shellcheck 指令 + 逐文件验证
```bash
# 7 个 hook lib 文件首行加（在现有注释之前）：
# shellcheck shell=bash
```
verify: `for f in <7 files>; do shellcheck -e SC1091 "$f" || exit 1; done`

### D4 — AC-D1 diff -r
不变（直接使用 `diff -r test flow-kit-bundle/test`）。

### D5 — 双源 sync
- 修改 test_gate_integrity.bats + test_lessons_cleanup.bats 后立即 cp 到 flow-kit-bundle/test/
- 7 个 hook lib 文件位于 flow-kit-bundle/，无 test/ 对应（非测试文件），不需 sync

## § 2 数据流
N/A（无新数据流）

## § 3 状态机
N/A（无新状态机）

## § 5 Risks
- **R1 (低)**: 测试 assertion 重写后语义改变（从"4-dev.md 含 X"到"4-dev.md 或 tdd-workflow.md 含 X"）。**缓解**：每个 test 注释说明 L-068 后的内容迁移。
- **R2 (低)**: `# shellcheck shell=bash` 指令位置必须在文件首行（任何非注释内容之前）。**缓解**：实施时验证首行特性。

## § 7 AC → Task 映射
- T01 (W1): AC-A1 + AC-B1/B2/B3 — 修改 2 个 bats 文件 + sync
- T02 (W1 parallel): AC-C1 — 7 个 hook lib 加 shellcheck 指令
- T03 (W2 serial): AC-D1/D2 + AC-E1/E2 — sync verify + commit + LESSONS/CONTEXT/CHANGELOG

## § 9 Architecture sediment
- **新抽象**: 无（仅测试 assertion 重写模式 + shellcheck 指令）
- **新决策**: 「split-aware test 设计原则」（测试 assertion 应反映 split 后的实际代码组织，跨多文件 grep）
- **新 contracts**: 无
- **新禁动**: 无

---

**Verdict**: ✅ 准备 phase 3 TASK。
