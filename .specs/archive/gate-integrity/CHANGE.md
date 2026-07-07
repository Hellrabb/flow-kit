# CHANGE: 加固 toll-gate 不可绕过性 + 扩展 L2 独立审查到 3/5/7

- **Change ID**: gate-integrity
- **创建日期**: 2026-07-01
- **路径建议**: 完整（REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION · 非前端无 2a）
- **状态: done（2026-07-07 · 3C+5I 修复 · 14 tasks · 全量 gate integrity 加固）

---

## Why（为什么做）

`/flow goal --pipeline --from 0` 把 pipeline goal 扩到全链 0→7 后，agent 在 auto_advance 推进时暴露两个**完整性缺口**：

1. **toll-gate 可被 agent 自己绕过**。现有三道防线都挡不住一个"想快速推进"的 agent：
   - PCSC（prompt 内自检）— 纯文本指令，agent 可跳过自检直接产 `.done`
   - PCG（GO 路由产物门禁）— 只查"产物文件是否存在"，agent `touch` 一个空 `.done` / `.independent-review-<phase>.done` 就能骗过
   - 29-independent-review hook + L3 hook — 依赖 agent 自觉触发 review 子进程；agent 可不触发、或触发后自己写 `.done` 标记"已审查"
   结果：agent 能在没真正跑独立审查的情况下越过 L2/L3 门禁推进到下一阶段，gate 形同虚设。

2. **L2 independent review 覆盖不全**。当前只有 1-requirement / 2-design / 6-review 有 L2 盲审；3-task / 5-test / 7-integration 无独立审查。这三个阶段的输出（任务拆解合理性、测试质量、集成发布）在 pipeline 全自动推进时缺少独立校验，agent 自评自通过。

触发原因：上个 change `independent-review` 刚把 L2/L3 机制和 gate-config 预设落地（2026-07-01 归档），随即发现"机制有了，但 agent 能自己绕过"——典型的护栏写了但可被绕过的问题。

## What（做什么）

**Q1（防规避）· hook 层强制**：把"靠 agent 自觉"改成"靠 hook 兜底，agent 无法绕过"。
- 校验 `.independent-review-<phase>.done` / 阶段 `.done` 的**真实性**（不是"存在性"）：防空文件、防内容伪造、防跳过 review 子进程直接 transition。
- pipeline transition（phase N→N+1）前**强制查 gate 状态: done（2026-07-07 · 3C+5I 修复 · 14 tasks · 全量 gate integrity 加固）

**Q2（扩展覆盖）· 给 3/5/7 加 L2**：把 1/2/6 既有的 independent review gate 机制复制到 3-task / 5-test / 7-integration，进/出阶段时拦 transition 直到主 agent 写出合法的 `.independent-review-3/5/7.done`。

**验收范式**：沿用 weak-model-robustness 既定范式 — regression-demo（每个失败模式一个 demo + check.sh）+ bats 覆盖新 hook 逻辑。

## 影响面

- [x] 影响 `REQUIREMENT.md`（新增 gate 校验 + 3/5/7 L2 的 Given/When/Then AC）
- [x] 影响 `DESIGN.md` / 引入新 ADR（.done 真实性校验的分层方案：存在性 / 内容真实性 / transition 前置查 gate；可能新增 ADR 记 .done 信任机制决策）
- [x] 影响现有 AC（pipeline goal 的 toll-gate 行为 AC 需对齐"hook 强制"语义；1/2/6 现有 L2 AC 不改）
- [x] 影响数据模型 / 迁移（`.done` 文件结构可能扩展——加签名/哈希/进程凭证元数据；`.flow-active.goal` schema 若需承载 gate 校验状态: done（2026-07-07 · 3C+5I 修复 · 14 tasks · 全量 gate integrity 加固）
- [ ] 影响外部 API 兼容性（无外部 API）
- [ ] 仅修复 bug（是机制加固 + 功能扩展，非 bugfix）

## 范围排除（这次不做）

- **不引入 L4 model_tier opt-out** — 保持 `protect the weakest` 哲学，不加强模型降级开关（L4 伪双轨留 v2）。
- **不改 1/2/6 现有 L2 blind-review 机制** — 只新增 3/5/7，既有 1/2/6 的 independent review 触发与 `.done` 约定不动。
- **不重构 pipeline goal 整体语义** — toll-gate / gate / auto_advance 的概念模型不变，只在其上叠加 hook 强制校验层。
- 注：`goal schema` 与 `brooks-lint 集成` 的改动**未预先排除** —— 若 .done 真实性校验需要元数据承载，DESIGN 阶段按需决定是否扩展 schema；本 change 聚焦 hook gate + L2 覆盖，不主动改 brooks 集成。

## 验收线（粗粒度，不是 AC）

1. **regression-demo**：≥3 个失败模式各一个 demo（含诱导场景 + `check.sh`）—— ① agent 伪造空 `.done` 绕门禁；② agent 写假内容 `.done`（审查证据是幻觉）；③ agent 跳过 review 子进程直接 transition —— `check.sh` 验证三种都被新护栏挡住。
2. **bats 测试**：覆盖新 hook 校验逻辑（`.done` 真实性校验 + transition 前置 gate 强查 + 3/5/7 L2 门禁触发）。
3. **3/5/7 L2 生效**：pipeline 推进经 3/5/7 时，未写合法 `.independent-review-3/5/7.done` 则 transition 被拦截，与 1/2/6 行为一致。

## 风险与未知

- **.done 真实性分层判定**（DESIGN 核心）：v1 做基础判定——区分 `.done` 是否由合法 review 子 agent 产出（写入者标识 / transcript 边界 / 子 agent 握手，DESIGN 选定载体），主 agent 自产一律拒。加密签名 / 内容哈希强化留 v2（见范围 v2，v1 基础判定必做，不整体降级）。
- **"假内容 .done"的校验边界**：review 子进程本身由模型驱动，模型 review 时也可能幻觉证据。L3 证据链如何作用于 review 子进程（而非只作用于主 agent）是未知项。
- **token 成本**：3/5/7 加 L2 后，每次 pipeline 推进多三次盲审（~25k/次量级）。gate-config 默认值与 `--from 0` 全链成本需在 DESIGN 权衡（是否给 3/5/7 默认 off、由用户显式开）。
- **向后兼容**：若扩展 `.done` 结构或 goal schema，旧 goal / 旧 `.done` 数据需平滑过渡（detect-and-migrate 或 tolerant read）。
- **meta 风险**：本 change 用 flow-kit 加固 flow-kit 自己的 gate。6-review 阶段若开启 `6-review=independent`，会出现"用自己的 L2 审自己写的 L2 机制"——需要在 REVIEW 阶段额外注意证据链真实性。

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
