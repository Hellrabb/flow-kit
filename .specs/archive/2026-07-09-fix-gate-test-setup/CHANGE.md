# CHANGE: 修 TD-013 · test_gate_integrity.bats setup set+e 假绿

- **Change ID**: fix-gate-test-setup
- **创建日期**: 2026-07-09
- **路径建议**: 极简闭环（bugfix · 测试基础设施 · 用户定 gate_config=full）
- **状态**: draft

---

## Why（为什么做）

TD-013（🔴 测试基础设施）。`test/test_gate_integrity.bats` setup line 30 `set +e` 关闭 bats errexit → 全文件 23 测试断言失效：`false` / `[ 1 -eq 0 ]` / `fn(rc≠0)` 全报 `ok`（**假绿**）。

**L2 实测铁证**（来自 `refactor-independent-review-gate` discovery · INDEPENDENT-REVIEW-2 第四轮 F1）：
- 最小复现：setup `set +e` → `false`/`[ 1 -eq 0 ]`/`fn(return 1)` 三条全报 ok；无 set+e → 正确报 not ok
- 实际文件 23 tests / 0 not ok（含应 fail 的 D10 case）

**揭示 TD-012 未真正闭合**：`test-setup-path-fix-2026-07` 修了 setup 路径让函数加载，但 `set +e` 让加载后的断言失效——假绿从"函数未加载 BW01"变成"断言被忽略"，性质同样坏。

**战略位置**：本 change 是 **`fix-gate-phase-detection`（TD-014）的前置**——TD-014 的 gate 检测修复验证依赖 `test_gate_integrity.bats` 可信，本 change 先恢复测试可信度。

## What（做什么）

1. **setup line 30 去 `set +e`**（两副本同步：`test/` + `flow-kit-bundle/test/`）
2. **9 条期望非零的测试体**改 `if ! fn; then rc=$?; [ $rc -eq N ]; fi` 或 `run` + `[ $status -eq N ]` 模式（L2 第四轮 F1 实测断裂清单）：
   - AC-1 ①-⑥（rc=2/2/2/2/1）
   - D9 fail-close（rc=1）
   - D7 #17-18（rc=1）
   - D10 #21（rc=1）
3. **AC 反向断言**：注入 `false` 到测试套件 → `make test` 必须 non-zero exit（防"假绿守门员"自身失效）
4. **source 容错验证**：去 set+e 后确认 `source "$GATE_SH"` 成功（否则 fn 未定义 rc=127 崩溃，L2 第二轮 F3 提示）

## 影响面

- [x] 仅修复 bug（测试基础设施），无范围变化
- [x] **不触碰禁动清单**（`test_gate_integrity.bats` 不在禁动清单 · 禁动清单是 gate 核心 `.sh`）
- [ ] 影响 REQUIREMENT/DESIGN —— 极简闭环新建（AC 载体），无新 ADR

## 范围排除（这次不做）

- **不碰 gate 逻辑**（`independent-review-gate.sh` · 属 TD-014 `fix-gate-phase-detection` 范围）
- **不碰其他测试文件**（grep 确认仅 `test_gate_integrity.bats` 有 `set +e` · L2 第四轮 Positive 6）
- **不做 L73-75/L30/L71 regex 修复**（TD-014/015 范围 · 等 ③ change）
- **不清理基线 warning**（SC1090/SC2034 · 与本 change 无关）
- **不修 is_phase_write 本身**（只修它的测试 setup，让测试可信）

## 验收线（粗粒度）

1. `! grep 'set +e' test/test_gate_integrity.bats`（setup 清除，两副本）
2. 9 条测试体改 if/then/fail 或 run+$status 模式
3. `make test` 全绿（**真绿**，非假绿 · 两副本同步）
4. 反向断言：注入 `false` → `make test` non-zero exit
5. TD-013 标 ✅ resolved（CONTEXT · 含证据：L2 F1 实测 + 反向断言）

## 风险与未知

- **去 set+e 后 source 容错**：`source "$GATE_SH" 2>/dev/null || true` 在 set -e 恢复后，若 source 失败被 `|| true` 吞，fn 未定义 → 127 崩溃。需确认 source 成功（setup 路径已由 TD-012 修正，应 OK，但 4-dev 验证）
- **9 条测试体改写笔误** → bats 验证捕获
- 无禁动清单风险（测试文件）

---

> 后续 AC 进入 REQUIREMENT.md。本 change 是 fix-gate-phase-detection（TD-014）的前置，战略位置关键。
