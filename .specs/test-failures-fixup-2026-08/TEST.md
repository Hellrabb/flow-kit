# TEST · test-failures-fixup-2026-08

> Phase 5 测试执行 · 2026-08-03

---

## § 1 测试金字塔

### 1.1 R1 单元测试

| 测试文件 | 测试数 | 状态 |
|---|---|---|
| test/test_gate_integrity.bats | 24 (含修改的 AC-3 5站点) | ✅ ok (24/24) |
| test/test_lessons_cleanup.bats | 16 (含修改的 AC-5/AC-6/边界) | ✅ ok (16/16) |
| test/test_install.bats | (含 AC-3 make lint) | ✅ ok |
| test/test_*.bats 其余 | 622 | ✅ ok |
| **总计** | **662 tests / 662 ok / 0 fail** | ✅ 基线恢复 |

### 1.2 R2 性能
- 单测 ≤5s ✓（所有修改的 tests 均 <1s）

### 1.3 R3 安全
- 无新外部输入 / 无新网络调用 ✓

### 1.4 R4 兼容
- bash -n all modified files ✓
- make lint 0 errors ✓

### 1.5 AC 覆盖矩阵

| AC | 类型 | 覆盖 | 状态 |
|---|---|---|---|
| AC-A1 | gate regex split-aware | test_gate_integrity.bats:152-172 | ✅ |
| AC-B1 | AC-5 npx bats 双文件 OR | test_lessons_cleanup.bats:144-176 | ✅ |
| AC-B2 | AC-6 失败阻断 pattern 重写 | test_lessons_cleanup.bats:189-215 | ✅ |
| AC-B3 | 边界 子段编号 tdd-workflow.md | test_lessons_cleanup.bats:258-268 | ✅ |
| AC-C1 | shellcheck 指令 | make lint + 逐文件 shellcheck | ✅ |
| AC-D1 | diff -r 双源 sync | diff -r test flow-kit-bundle/test | ✅ |
| AC-D2 | 0 fail 基线 | npx bats test/ → 662/0 | ✅ |
| AC-E1 | commit + files | phase 7 commit + 13 files | ✅ |
| AC-E2 | .specs sync | CONTEXT/CHANGELOG/LESSONS/STATE | ✅ |

---

**Verdict**: ✅ PASS — 准备 REVIEW。
