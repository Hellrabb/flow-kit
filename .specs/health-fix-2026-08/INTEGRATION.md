# INTEGRATION · health-fix-2026-08

> **Phase 7**: Integration + release readiness check
> **执行时间**: 2026-08-04

---

## § 1 · 完整性检查

### 1.1 · 规格工件清单

| 工件 | 路径 | 状态 |
|---|---|---|
| CHANGE.md | `.specs/health-fix-2026-08/CHANGE.md` | ✅ (115 行 · 0-change self-check pass) |
| REQUIREMENT.md | `.specs/health-fix-2026-08/REQUIREMENT.md` | ✅ (rev 3 · L2+L3 pass · 4 US + 12 AC) |
| DESIGN.md | `.specs/health-fix-2026-08/DESIGN.md` | ✅ (rev 2 · L2 pass · Fix A only, Fix B correctly dropped) |
| TASK.md | `.specs/health-fix-2026-08/TASK.md` | ✅ (3 serial tasks · all done) |
| TEST.md | `.specs/health-fix-2026-08/TEST.md` | ✅ (AC matrix + coverage) |
| INDEPENDENT-REVIEW-1.md | ...REVIEW-1.md | ✅ (phase 1 · L2+L3 pass · 5 findings fixed) |
| INDEPENDENT-REVIEW-2.md | ...REVIEW-2.md | ✅ (phase 2 · L2 pass · 5 findings fixed incl. critical Fix B rejection) |
| INDEPENDENT-REVIEW-3.md | ...REVIEW-3.md | ✅ (phase 3 · self · proportionality) |
| INDEPENDENT-REVIEW-5.md | ...REVIEW-5.md | ✅ (phase 5 · self · results verified) |
| INDEPENDENT-REVIEW-6.md | ...REVIEW-6.md | ✅ (phase 6 · L2 pass · 2 Minor fixed) |

### 1.2 · .done 门禁文件

| Phase | Gate config | .done | Verdict |
|---|---|---|---|
| 1-requirement | L2+L3 | ✅ | PASS (5 findings fixed) |
| 2-design | L2 | ✅ | PASS (5 findings fixed · Fix B rejected) |
| 3-task | L2 | ✅ | PASS (proportionality) |
| 5-test | L2 | ✅ | PASS (proportionality) |
| 6-review | L2 | ✅ | PASS (2 Minor fixed) |
| 7-integration | L2 | (本步) | — |

---

## § 2 · 代码变更清单

### 2.1 · 变更文件（3 个 · +36 行）

| 文件 | 变更类型 | 行数 | 说明 |
|---|---|---|---|
| `flow-kit-bundle/lib/install_hooks.sh` | 修改 | +12 | Fix A (L38-50 paths.sh 自加载守卫) + Fix C (L3-4 header 注释) |
| `test/test_install_coverage.bats` | 修改 | +12 | AC-C1 防回归 case (L122-134) |
| `flow-kit-bundle/test/test_install_coverage.bats` | 同步 | +12 | 双源同步 (identical) |

### 2.2 · 禁动清单合规

| 禁动项 | 合规 | 说明 |
|---|---|---|
| `lib/install_*.sh` 不可独立执行 | ✅ | 约束**未改变**（header 仍标注"由 install.sh source"）· 仅增加防御性自加载 |
| `.flow-active.goal` 字段 | ✅ | 全程通过 jq 更新（无手编辑） |
| 双源测试同步 | ✅ | AC-D3 验证 diff exit 0 |

### 2.3 · 预期 score 改善

| 维度 | 修复前 (89) | 修复后 |
|---|---|---|
| install_hooks.sh:97 PROJECT_DIR_NAME 未绑定 | 🔴 -10 | ✅ 0 (守卫加载 paths.sh) |
| runtime-edit-guard.sh 安装阻断 | 隐含 -10 | ✅ 0 (下游解锁) |
| jscpd 0.37% (5 boilerplate clones) | 🟢 -1 | 🟢 -1 (不变) |
| **预期综合** | **89** | **≥98**（恢复 baseline 98 或 99 · 取决于 jscpd 是否算入） |

---

## § 3 · 测试基线

| 指标 | 修复前 | 修复后 |
|---|---|---|
| 总 case 数 | 691 | **692** (+1 AC-C1) |
| pass | 687 | **692** |
| fail | **4** | **0** ✅ |
| shellcheck errors | 0 | 0 |
| bash -n errors | 0 | 0 |
| 双源 diff | exit 0 | exit 0 |

---

## § 4 · 发布就绪检查

| 检查项 | 状态 |
|---|---|
| 所有硬门槛 AC pass | ✅ (A1/A2/B1/B2/B3/C2/D1/D2/D3) |
| 所有软门槛 AC pass | ✅ (C1 防回归 test) |
| 全量测试 exit 0 | ✅ (make test 692/0) |
| 主路径 smoke exit 0 | ✅ (install.sh --project --hooks-only) |
| 禁动清单零违反 | ✅ |
| 规格工件完整 | ✅ (10/10) |
| git diff 干净 | ✅ (3 文件 +36 行) |

**结论**: **READY TO COMMIT**

---

## § 5 · 后续建议

1. **commit**: 建议在用户批准后创建原子 commit（message 示例：`fix(install): paths.sh 自加载守卫修复 user-scope PROJECT_DIR_NAME 回归`）
2. **健康趋势**: 下次 M-health sweep 预期 ≥98（恢复 baseline）
3. **A-evolve 提醒**: `lib/paths.sh` 尚未登记到 CONTEXT.md「既有抽象索引」· 建议下次 A-evolve 同步时补登
