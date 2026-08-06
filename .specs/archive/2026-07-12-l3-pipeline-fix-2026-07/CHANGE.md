# CHANGE — L3 审查管线 + Stop Hook 性能修复

## Why

`health-fix-l3-2026-07` 的 L3 审查反复假阳性暴露了 L3 管线 5 项系统限制（L-040）。同时 Stop hook 链（14 模块串行 + L3 API 同步等待 30s）执行缓慢，影响每轮对话的响应体验。

## What

一次性修复 L3 审查管线 5 项限制 + Stop hook 性能问题：

### 🔴 L3 审查管线（L-040 · 5 项）

1. **`git diff` 硬限 5000 字符**（`l3-review.sh:204`）
   - 大变更的代码 diff 被截断 → L3 基于不完整信息审查
   - 修复：增大上限至 50000；或改用动态截断（按 token 估算而非字符数）
2. **`git diff HEAD` 不含 untracked 文件**（`l3-review.sh:200`）
   - 新增文件（如 correction-types.sh）对 L3 不可见
   - 修复：改用 `git diff --cached HEAD`（含 staged）+ `git ls-files --others --exclude-standard`（untracked）
3. **`head -c $max_chars` 逐文件硬截断**（`l3-review.sh:168-194`）
   - 大产物（REQUIREMENT 12.3K / DESIGN 19.2K）尾部丢弃
   - 修复：`smart_truncate()` 改为保留头 + 尾策略（取前 N/2 + 后 N/2）；或按重要性加权截断（AC 段 / 风险段优先保留）
4. **仅审当前 phase，历史积压不处理**（`29-independent-review.sh`）
   - Stop hook 只看 `.flow-active.goal.current_phase`，前面积压的 L3 永远不跑
   - 修复：添加积压扫描——检查 `phases_done` 中哪些 phase 的 gate_config 含 L3 但 `.done` 缺失，逐个补跑
5. **无状态，每次审查独立**（`l3-review.sh` 整体）
   - 前次反驳 / L2 结论 / waiver 决策对下次审查不可见
   - 修复：L3 prompt 注入前次审查摘要（verdict + 主 agent 反驳）+ L2 verdict 上下文

### 🟡 Stop hook 性能

6. **Stop hook 链执行缓慢**
   - 14 模块串行 + 每模块 source 多个 lib + L3 API 同步等待 30s
   - 修复方向（调查后确定）：
     - 测量各模块耗时，定位瓶颈
     - L3 API 异步化（fire-and-forget + 下次 SessionStart 收割结果）
     - lib 懒加载（按需 source 而非全量预加载）

## 影响面

- [x] 需更新 REQUIREMENT.md（6 项修复各有验收标准）
- [x] 触及核心 hook/lib 代码，需 DESIGN.md
- [x] 改动 `l3-review.sh`（主要）+ `29-independent-review.sh` + `smart_truncate` 重构
- [x] 可能涉及 Stop hook 加载机制变更（性能优化）
- [x] 不涉及 ADR 变更（管线改进，架构不变）

**触碰模块**（`flow-kit-bundle/` 维护源）：
- `flow-kit-bundle/hooks/stop/lib/l3-review.sh`（主要 · L3 管线核心）
- `flow-kit-bundle/hooks/stop/29-independent-review.sh`（积压扫描 + L3 派发）
- `flow-kit-bundle/hooks/stop/lib/common.sh`（可能的性能优化共享函数）
- `test/` 下对应测试文件

## 范围排除

- ❌ 不改变 L3 API 调用方式（仍用 curl + 30s timeout）
- ❌ 不新增 hook 模块编号
- ❌ 不改动 gate_config schema
- ❌ 不改动 `.done` KVP 格式
- ❌ 不修改 `package-flow-kit.sh`

## 验收线

1. **AC-1 git diff 上限**：Phase 6 L3 能收到完整代码 diff（≥ 50000 字符或智能截断保留关键变更）
2. **AC-2 新文件可见**：untracked/staged 新文件出现在 L3 prompt 的 diff 中
3. **AC-3 智能截断**：大产物截断后保留 AC 段 + 风险段 + 决策段（而非纯头部截断）
4. **AC-4 积压扫描**：Stop hook 自动检测并补齐历史 phase 的 L3 审查
5. **AC-5 上下文注入**：L3 prompt 含前次审查 verdict + 主 agent 反驳摘要
6. **AC-6 Stop hook 性能**：Stop hook 链执行时间降低 ≥ 30%（基线待测量）
7. **AC-7 零回归**：`npx bats test/` 全量通过，`bash -n` 全过

## 路径建议

**完整路径**: `REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION`

理由：涉及 L3 管线核心逻辑重构 + 性能优化，需要 DESIGN 规划具体方案，需要 REQUIREMENT 明确每项验收标准。
