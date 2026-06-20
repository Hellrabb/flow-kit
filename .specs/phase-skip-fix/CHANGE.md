# CHANGE: 修复 pipeline toll-gate 阶段跳过漏洞

- **Change ID**: phase-skip-fix
- **创建日期**: 2026-06-21
- **路径建议**: 中等（REQUIREMENT 增量 → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: draft

---

## Why（为什么做）

实际使用中发现 AI 在 pipeline goal 自动推进过程中会跳过阶段工作（尤其是 5-test / 6-review / 7-integration，4-dev 也有），但报告里却显示阶段已完成。根因排查如下：

### 根因分析

**R1: 无产物验证即触发 toll-gate（核心漏洞）**。所有阶段 prompt 的 Pipeline Toll-Gate 段在阶段末尾，但 AI 可以直接跳到 toll-gate 段、输出完成提示、执行 transition jq，全程无需验证该阶段产物是否真的写入了磁盘。jq 命令 `.goal.phases_done += ["N"]` 是无条件执行的——没有任何 `test -f .specs/<id>/TEST.md` 之类的产物存在性检查。

> 注：`auto_advance=true` 跳过人工确认是**设计行为**（用户选了「全自动推进」即信任 AI），不算漏洞。但 auto_advance 同样缺乏产物验证——AI 可以在不产出任何文件的情况下自动 transition 到下一阶段。修复方案：auto_advance 模式下仍跑产物自检，全通过才自动 transition，任一失败则暂停并告警。

**R2: 5-test/6-review/7-integration 缺少 `start_phase` 感知**。CONTEXT.md 中已有技术债 TD-003 标注这三个 prompt 的入场 jq 仍是 `current_phase // "4"`（漏了 `start_phase`），虽影响低但一致性差，趁本次一并修复。

**R3: GO.md 路由层无 Phase Completion Gate**。当前 Artifact Preflight Gate 只检查「进入目标阶段需要什么上游工件」，不检查「离开当前阶段时是否已产出应有产物」。即使 prompt 内有自检段（R1 修复），AI 仍可在下一轮 `/flow-go` 时绕过——GO.md 会直接加载下一阶段 prompt，不验证当前阶段产物是否存在。**这层是独立于 prompt 的强制门禁**：不是 hook 脚本，而是在 GO.md 路由逻辑中加一段产物检查，每次路由到新阶段前强制执行。

### 影响范围

- `flow-kit/prompts/4-dev.md` — toll-gate 4→5（漏洞入口：auto_advance 选项）
- `flow-kit/prompts/5-test.md` — toll-gate 5→6（漏洞：auto_advance 跳过 + 无产物验证）
- `flow-kit/prompts/6-review.md` — toll-gate 6→7（漏洞：auto_advance 跳过 + 无产物验证）
- `flow-kit/prompts/7-integration.md` — pipeline 完成（漏洞：无产物汇总验证）
- `flow-kit/prompts/1-requirement.md` — toll-gate 1→2（漏洞：无产物验证）
- `flow-kit/prompts/2-design.md` — toll-gate 2→3（漏洞：无产物验证）
- `flow-kit/prompts/3-task.md` — toll-gate 3→4（漏洞：无产物验证）
- `flow-kit/GO.md` — 路由声明中 pipeline goal 横幅展示（已有 start_phase 读取，需同步修复 `--from 0` 的 toll-gate 逻辑）

## What（做什么）

### 第一层 · Prompt 阶段完成自检（R1 修复）

在每个阶段 prompt 的 Pipeline Toll-Gate 段之前，插入**阶段完成自检（Phase Completion Self-Check）** 强制段：

1. **产物清单枚举**：列出本阶段必须产出的文件，AI 必须逐项自检
2. **自检表格**：格式化的 checklist，每项标记 ✅/❌
3. **阻断规则**：任一必选项缺失 → **禁止进入 toll-gate**，要求 AI 先完成缺失项
4. **auto_advance 适配**：auto_advance=true 时仍跑自检——全通过则自动 transition，任一失败则暂停告警

### 第二层 · GO.md 路由层 Phase Completion Gate（R3 修复）

在 GO.md 第二步（Artifact Preflight Gate）中增加**反向产物检查**——当 AI 请求进入 phase N+1 时，不仅检查上游工件，也检查 phase N 的产物是否存在：

- 新增「Phase Completion Gate」表格：每个阶段的必须产物清单（与 prompt 自检段一致）
- 路由时：`current_phase` 对应的产物缺失 → **拒绝进入下一阶段**，输出缺失清单，要求 AI 回当前阶段补齐
- 这层独立于 prompt 指令——AI 无法绕过，因为 GO.md 每次路由都加载

### 附带修复

5. **5/6/7 阶段入场 jq 补全 `start_phase`**（TD-003 修复）
6. **新增 bats 测试**：覆盖 toll-gate 产物自检段存在性 + GO.md Phase Completion Gate 逻辑

## 影响面

- [x] 影响 `REQUIREMENT.md`（增量：补充 toll-gate 产物自检需求 + GO.md Phase Completion Gate）
- [x] 影响 `DESIGN.md`（设计：自检段模板结构 + 产物清单定义 + GO.md 路由层检查逻辑）
- [ ] 影响现有 AC（无）
- [ ] 影响数据模型 / 迁移（无）
- [ ] 影响外部 API 兼容性（无）
- [x] 影响 `GO.md`（新增 Phase Completion Gate 表 + 路由拦截逻辑）
- [ ] 仅修复 bug，无范围变化（否——机制加固，涉及 7 个 prompt + GO.md + 新测试）

## 范围排除（这次不做）

- 不引入外部 hook 脚本（如 Stop Hook 产物检查）——GO.md 路由层已提供独立强制门禁
- 不改变 toll-gate 的交互模型（仍为 AI 主导 + 用户确认）
- 不改动 `.flow-active` 的 JSON schema
- 不引入 CI/CD 门禁集成

## 验收线（粗粒度，不是 AC）

- **双层防护生效**：AI 无法跳过阶段产物生成而推进到下一阶段（prompt 自检 + GO.md 路由拦截）
- `auto_advance=true` 模式下，产物缺失时 pipeline 暂停并提示用户
- 所有 7 个阶段 prompt 均包含阶段完成自检段
- GO.md 包含 Phase Completion Gate 表，路由时检查退出阶段的产物完整性
- 新增 bats 测试覆盖自检段存在性 + GO.md 产物检查逻辑，`npx bats test/` 全部通过

## 风险与未知

- **AI 仍可在 prompt 内"假装"自检**：第一层（prompt 自检）依赖 AI 诚实执行。但第二层（GO.md 路由拦截）独立于 prompt，AI 绕过第一层会在路由时被拦截，双层防护使绕过概率大幅降低
- **Phase Completion Gate 的产物路径依赖 change-id**：GO.md 需要知道当前 change-id 才能检查 `.specs/<id>/` 下的产物。需确保 GO.md 路由时 change-id 已可用（从 `.flow-active` 读取）
- **自检段可能被 phase 回退绕过**：需确认回退后重新进入阶段时自检逻辑正确触发

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
