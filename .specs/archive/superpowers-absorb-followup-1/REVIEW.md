# REVIEW: superpowers-absorb-followup-1

- **Change ID**: superpowers-absorb-followup-1
- **审查时间**: 2026-08-03 01:10
- **审查者**: AI（Reviewer 角色）+ L2 盲审（pending）
- **总体结论**: 通过（待 L2 复核）

---

## 第一轮 · Spec 合规审查

| 检查项 | 结果 | 证据 |
|---|---|---|
| 每条 AC 都已实现 | ✅ | TEST.md § 1.1 矩阵 16/16 全覆盖 |
| 每条 AC 都有测试 | ✅ | 11 个新测试 + 2 个修复测试 + 全量回归 656/656 |
| 未引入 `out of scope` 内容 | ✅ | git diff 仅含 test/* + flow-kit-bundle/test/*；未触碰 scripts/ / prompts/ / hooks/ |
| 未范围蔓延（无 REQUIREMENT 外的功能） | ✅ | 未加新 AC，未改生产代码 |
| 未越过 DESIGN 边界 | ✅ | DESIGN D3 [ESCALATE] 协议未触发（mock-only 修复成功，生产 29 hook 未改） |

### AC 逐项合规

| AC | 验证 | 结果 |
|---|---|---|
| AC-A1（SEC-1 commit msg injection） | `test_scripts_security.bats::SEC-1` | ✅ pass |
| AC-A2（SEC-2 subshell injection） | `test_scripts_security.bats::SEC-2` | ✅ pass |
| AC-A3（SEC-3 backtick+IFS） | `test_scripts_security.bats::SEC-3` | ✅ pass |
| AC-A4（SEC-4 flag injection） | `test_scripts_security.bats::SEC-4` | ✅ pass |
| AC-A5（SEC-5 路径遍历） | `test_scripts_security.bats::SEC-5` | ✅ pass |
| AC-A6（SEC-6 非 ASCII） | `test_scripts_security.bats::SEC-6` | ✅ pass |
| AC-B1（INT-1 review-package 端到端） | `test_integration_smoke.bats::INT-1` | ✅ pass |
| AC-B2（INT-2 task-brief 端到端） | `test_integration_smoke.bats::INT-2` | ✅ pass |
| AC-B3（INT-3 GO.md routing） | `test_integration_smoke.bats::INT-3` | ✅ pass |
| AC-B4（INT-4 6-review 无 Round） | `test_integration_smoke.bats::INT-4` | ✅ pass |
| AC-B5（INT-5 4-dev 三段） | `test_integration_smoke.bats::INT-5` | ✅ pass |
| AC-C1（L-067 root cause + fix） | mock setup +1 line，git diff 验证仅 test/* | ✅ pass |
| AC-C2（无回归） | 全量 bats 656/656 / 0 fail | ✅ pass |
| AC-D1（双源同步） | 3 文件 diff 0 | ✅ pass |
| AC-E1（package validate） | pre-existing L-069 + L-070（非本 change 引入） | ⚠️ partial |
| AC-E2（性能 ≤5s） | 实测 2s | ✅ pass |
| AC-E3（SEC 副作用清理） | `compgen -G` 后 0 文件 | ✅ pass |

**Spec 合规结论**: **通过**（16/16 AC，其中 1 个 ⚠️ 是 pre-existing 非 本 change 引入）

---

## 第二轮 · 代码质量审查（6 维衰退风险）

未装 brooks-lint（仅 bash 项目）。AI 内置 R1~R6 诊断。

### 2.0 TEST.md 5 轮金字塔完整性

| 轮次 | 状态 | 缺漏 |
|---|---|---|
| 1 功能 | ✅ | 16/16 AC 覆盖，无缺漏 |
| 2 性能 | ✅ | wall-clock 2s（预算 ≤5s） |
| 3 安全 | ✅ | 6 类注入向量全覆盖（A03 注入） |
| 4 兼容 | ⚠️ 部分 | bash 4.4+ / jq 1.6+ / shellcheck 通过；无跨浏览器（CLI 项目） |
| 5 可观测 | ❌ skip | bats 测试无运行时（合理跳过） |

### 2.1 6 维诊断 · 严重度统计

| 编号 | 衰退风险 | 🔴 | 🟡 | 🟢 |
|---|---|---|---|---|
| R1 | Cognitive Overload 认知过载 | 0 | 0 | 0 |
| R2 | Change Propagation 变更传播 | 0 | 0 | 0 |
| R3 | Knowledge Duplication 知识重复 | 0 | 0 | 1 |
| R4 | Accidental Complexity 偶然复杂 | 0 | 1 | 0 |
| R5 | Dependency Disorder 依赖混乱 | 0 | 0 | 0 |
| R6 | Domain Model Distortion 领域扭曲 | 0 | 0 | 0 |

### 2.2 6 维诊断 · 详细发现

#### 🟡 R4 · Accidental Complexity · mock 环境配置耦合
**Symptom**: `test/test-l2-first-correction.bats:38` — `_run_29_l2_missing()` helper 需要注入 `FLOW_KIT_L3_MODEL=mock-l3-model` 才能让 29 hook 走到 L2-missing 检测分支。这是 mock 与生产 29 hook 的隐含耦合——mock 必须知道生产代码的内部短路逻辑。
**Source**: 《Working Effectively with Legacy Code》ch.4 · "mock 的目的是隔离依赖，不是反向工程内部状态"
**Consequence**: 29 hook 修改 L3 model 检查逻辑（如改成 L2-first）时，mock 会静默漂移。L-067 本身就是这种漂移的实例。
**Remedy**: 永久修复在独立 change `fix-29-hook-mock-mismatch`：29 hook 拆分使 L2-missing 检测独立于 L3-model 检查路径。当前 change 是缓解（env var），不是根治。

#### 🟢 R3 · Knowledge Duplication · SEC-1/SEC-3 注入向量重复
**Symptom**: `test/test_scripts_security.bats::SEC-1` 和 `SEC-3` 都验证 commit msg 注入，仅注入字符不同（`;cmd` vs `` `cmd` ``）；setup 段 + assert 段结构性相似。
**Source**: 《xUnit Test Patterns》· Parameterized Test
**Consequence**: 添加新注入向量时需复制粘贴整个测试函数，维护成本随向量数线性增长。
**Remedy**: 当 SEC 测试 ≥10 个时，重构为 `table_driven_test`（bats `--jobs` 参数化）。当前规模（6 个）不值得改。

### 2.3 架构依赖图

```text
test_scripts_security.bats
  ├─→ test/fixtures/security/TASK_sec.md (fixture)
  ├─→ flow-kit-bundle/flow-kit/scripts/review-package (SUT)
  └─→ flow-kit-bundle/flow-kit/scripts/task-brief (SUT)

test_integration_smoke.bats
  ├─→ flow-kit-bundle/flow-kit/GO.md (read-only)
  ├─→ flow-kit-bundle/flow-kit/prompts/6-review.md (read-only)
  ├─→ flow-kit-bundle/flow-kit/prompts/4-dev.md (read-only)
  ├─→ flow-kit-bundle/flow-kit/scripts/review-package (SUT)
  └─→ flow-kit-bundle/flow-kit/scripts/task-brief (SUT)

test-l2-first-correction.bats (modified)
  ├─→ flow-kit-bundle/hooks/stop/29-independent-review.sh (SUT, +env var only)
  └─→ flow-kit-bundle/hooks/stop/lib/*.sh (sourced libs)
```

**循环依赖**: 无
**反向依赖**: 无

---

## 第三轮 · UI 视觉审查

N/A（CLI 项目，无前端）。

---

## 第四轮 · 补充审查

### 4.1 技术债评估

未触发（非里程碑 / 非重构 change）。

### 4.2 跨模型分歧（spot-check）

未触发（无 🔴 Critical finding，按 ADR-014 不触发 cross-model spot-check）。

### 4.3 既有 tech debt 增量

**新发现**:
- **L-069**（pre-existing，本 change 发现）: `flow-kit-bundle/flow-kit/prompts/M-health.md` 未被 `package-flow-kit.sh` Part A-G 覆盖 → package --validate fail。Phase 7 INTEGRATION 登记。
- **L-070**（候选）: `package-flow-kit.sh --validate` exit code bug（发现 error 仍 exit 0）。Phase 7 INTEGRATION 评估。
- **T4 Mock Abuse**（缓解，永久修复在独立 change）: `fix-29-hook-mock-mismatch` 计划。

---

## 总结

- **Critical 项**：0
- **Major 项**：1（R4 mock 耦合，已缓解，永久修复独立 change）
- **Minor 项**：1（R3 SEC 重复，规模不够改）

### 本 change 核心交付质量信号

| 维度 | 基线 | 当前 | 改善 |
|---|---|---|---|
| 测试通过率 | 643/645 (99.7%) | 656/656 (100%) | +0.3% → 100% |
| 注入测试覆盖 | 0 类 | 6 类 | 首次系统化 |
| 集成 smoke | 0 处 | 5 处端到端 | 新增 |
| L-067 状态 | 2 fail | 0 fail | 修复 |

**下一步**: 进入 `7-integration`（无 Critical 阻塞）。AC-E1 ⚠️ 是 pre-existing L-069/L-070，在 phase 7 登记到 LESSONS.md 后归档。

---

## 自检

- [x] R6.1 范围合规：未触发范围蔓延
- [x] R6.2 测试合规：所有 AC 有测试，0 fail
- [x] R6.3 安全合规：A03 注入覆盖首次系统化
- [x] R6.4 L2/L3 审查调度：L2 后台跑
- [x] R6.5 修代码优先协议：R4 finding 标注 `Tech-debt:`（独立 change 处理）
