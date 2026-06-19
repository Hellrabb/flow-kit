# REQUIREMENT: 修复 M-health 2026-06-20 的 2 项 🟡 技术债

- **Change ID**: health-fix-2026-q2
- **关联**: `@.specs/health-fix-2026-q2/CHANGE.md`、`@.specs/CONTEXT.md`、`@.specs/health/2026-06-20-HEALTH.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想让 5/6/7 阶段 prompt 的入场 jq 与 4-dev/GO.md 保持一致（读取 start_phase），以便 `--from 0` pipeline 走到这些阶段时不依赖硬编码 fallback。
- **US-2**：作为 flow-kit 维护者，我想给 hooks 系统的核心函数（尤其 `flow-kit-artifacts.sh`）加 smoke test，以便修改 hook 逻辑时有自动验证，不再是 3410 行 bash 完全盲区。

## 验收准则（AC）

### AC-1 · TD-003 一致性补齐

- **Given** `flow-kit-bundle/flow-kit/prompts/5-test.md` / `6-review.md` / `7-integration.md`
- **When** 读取这三个 prompt 的入场 jq 命令
- **Then** 三个文件的入场 jq 均包含 `start_phase` 引用（形式：`current_phase // .start_phase // "4"`），与 `4-dev.md` 和 `GO.md` 一致
- **验证方式**: `grep -c 'start_phase' flow-kit-bundle/flow-kit/prompts/{5-test,6-review,7-integration}.md` 三行均 ≥ 1

### AC-2 · TD-002 artifacts smoke test

- **Given** `test/test_flow_artifacts.bats`（新增）
- **When** 运行 `npx bats test/test_flow_artifacts.bats`
- **Then** 至少覆盖 `flow-kit-artifacts.sh` 的 3 个纯函数（`fk_flow_field` / `fk_file_nonempty` / `fk_validate_flow` 的基础路径），全部 pass
- **验证方式**: `npx bats test/test_flow_artifacts.bats` 显示新增的测试全 ok，无 not ok

### AC-3 · common.sh 边界补全

- **Given** `test/test_common.bats`（已存在 17 tests）
- **When** 运行全量测试
- **Then** 至少补全 2 个边界用例（如 `config_get` 对缺失文件的处理、`check_enabled` 对 module.enabled=false 的判断），总测试数 ≥ 45
- **验证方式**: `npx bats test/` 总数 ≥ 45，0 fail 0 skip

### AC-4 · 全量回归

- **Given** 所有改动已应用（AC-1 + AC-2 + AC-3）
- **When** 运行 `npx bats test/`
- **Then** 全量通过：0 fail，0 skip
- **验证方式**: `npx bats test/` 末行无 `not ok`，无 `skip`（除非 skip 是 `skip_if_no_jq` 的合理跳过）

---

## 范围切分

### v1（本次必做）

- AC-1: 5/6/7 prompt 入场 jq 补 `start_phase`（3 文件微调）
- AC-2: 新增 `test/test_flow_artifacts.bats`，覆盖 `flow-kit-artifacts.sh` 3 个纯函数
- AC-3: `test_common.bats` 补 2+ 边界用例
- AC-4: 全量回归通过

### v2（下一轮考虑，不本次）

- hooks 100% 行覆盖（本次只做 smoke 基线）
- `fk_auto_phase` / `fk_stale_check` / `fk_boundary_check` 等依赖 git/文件系统的函数（需更复杂的 fixture）
- `transcript-parser.sh` 测试

### out（永远不做）

- 不为追求覆盖率指标而写无意义的测试
- 不重构 hooks 系统（本次只加测试，不改逻辑）

---

## 非功能性需求

- **性能**: 无（测试秒级完成）
- **可访问性**: 无
- **安全**: 无
- **兼容性**: 测试用 mktemp 隔离 + jq 可用性检查（沿用 test_common.bats 的 `skip_if_no_jq` pattern），不依赖真实项目状态
- **可观测性**: 测试失败时输出明确断言信息

## 依赖与假设

- **依赖**: bats-core 1.10.0+（已有）、jq（已有）
- **假设**: `flow-kit-artifacts.sh` 的纯函数（`fk_flow_field` / `fk_file_nonempty`）可在 source 后直接调用，无需完整 hook 环境
- **假设**: AC-1 的 jq 微调不影响现有 4-dev/GO.md 行为（纯加法扩展）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
