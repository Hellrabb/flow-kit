# TEST: L3 独立审查全面修复

- **Change ID**: l3-comprehensive-fix
- **关联**: `REQUIREMENT.md` / `DESIGN.md` / `TASK.md`

---

## 测试矩阵

| AC | 测试类型 | 测试文件 | 结果 |
|---|---|---|---|
| AC-1 (L3 结果注入) | 单元测试 | `test/l3-header-detect.bats` (3 tests) | ✅ PASS |
| AC-2 (截断可控) | 单元 + 集成 | `test/l3-truncation.bats` (6 tests) 离线算法 ✅ / L3 API 3轮集成验证 ⏳ | ⚠️ 算法PASS, 集成待API |
| AC-3 (.done 防重) | 单元测试 | `test/done-skip.bats` (3 tests) | ✅ PASS |
| AC-4 (L2 被动触发) | 单元测试 | `test/l2-detect.bats` (5 tests) | ✅ PASS |
| AC-5 (L2 选项可见) | 单元测试 + 手动 | `test/done-skip.bats` (skip marker) + UAT | ⚠️ 部分覆盖 |
| AC-6 (KVP 校验) | 单元测试 | `test/done-validation.bats` (4 tests) | ✅ PASS |
| AC-7 (phase 一致性) | 单元测试 | `test/phase-resolution.bats` (4 tests) | ✅ PASS |

---

## 回归测试

| 项目 | 结果 |
|---|---|
| `npx bats test/` 全量 | **381 tests / 0 failures** ✅ |
| 新增 tests | 22 tests (phase-resolution: 4 / l2-detect: 5 / done-validation: 4 / l3-header: 3 / l3-truncation: 6) |
| 语法检查 | `bash -n` 全 3 hooks + 2 libs 通过 |
| make check | 全量通过 ✅ |

---

## 手动 UAT 清单

### UAT-1: L3 结果 SessionStart 注入 (AC-1)
1. 模拟完成某阶段 L3 审查（`INDEPENDENT-REVIEW-<N>.md` 含 `## L3 盲审` header + .done 存在）
2. 新 session 启动 → 确认 stdout 含 `L3_RESULT:` 标准行

### UAT-2: .done 阻止重复触发 (AC-3)
1. 写 `.independent-review-7.done` → 触发 stop hook → 确认输出 "skipped" → exit 0
2. 验证无 API 调用、无覆盖已有结果

### UAT-3: L2 选项交互 (AC-5)
1. Phase 5 gate_config=both + L2 未完成 → 尝试切阶段
2. 确认：选项① 一键命令模板输出 / 选项② `FLOW_KIT_SKIP_L2=1` → .skip-L2-5 marker / 选项③ deny

### UAT-4: Phase 检测 pipeline-aware (AC-7)
1. Pipeline mode + current_phase=5 + .phase=0 → stop hook 使用 phase=5 判断触发
2. Pipeline mode + current_phase=5 + .phase=6 (过期) → 不取 max(5,6)=6，使用 5

### UAT-5: L3 截断上下文告知 (AC-2)
1. 30KB REVIEW.md fixture → L3 API 调用 → 确认 prompt 含 "截断" 上下文提示
2. 确认 critical 条数 ≤ 4（3 真实 + 1 容忍）

---

## 覆盖缺口

| 缺口 | 影响 | 风险 |
|---|---|---|
| UAT 手动验证未执行 | AC-1/AC-3/AC-5 缺乏端到端验证 | 低 — 单元测试覆盖核心逻辑，UAT 为最终确认 |
| L3 API 集成测试未跑（需外部 API key） | AC-2 假阳性控制仅单元测试 | 低 — 智能截断算法已通过离线单元测试 |
