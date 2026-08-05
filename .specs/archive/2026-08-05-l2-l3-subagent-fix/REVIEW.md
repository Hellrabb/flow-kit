# REVIEW.md — 阶段 6 合并审查（l2-l3-subagent-fix）

> 审查日期：2026-08-05 | 审查范围：`git diff HEAD -- flow-kit-bundle/hooks/stop/lib/l2-detect.sh .specs/CONTEXT.md` + `.specs/l2-l3-subagent-fix/` 产物（28 文件）

## 审查输入

- REQUIREMENT.md（AC-1..5）/ DESIGN.md（D1-D6 + §0.5.1）/ TASK.md（8 任务）/ TEST.md（5 轮矩阵）/ ROOT-CAUSE.md（五段）/ EVIDENCE-1..5 / DEV-SUMMARY.md
- 代码 diff：l2-detect.sh +10 行（修复③ 平台探测提示）、CONTEXT.md +4 术语

## A. Spec 合规

| AC | 实现 | 测试覆盖 | 状态 |
|---|---|---|---|
| AC-1 根因报告五段+四环节每环节实测 | ROOT-CAUSE.md 五段齐全（现象矩阵 P1-P6 / 根因链 3 条 / 双平台差异矩阵 6 维 / 风险分级方案 7 条 / 受影响模块 8 项）；EVIDENCE-1..5 覆盖环节①②③④ | TEST.md 第1轮逐行映射；五段 grep=5 + 锚点=8 独立复跑 | ✅ |
| AC-2 双平台证据+脱敏 | EVIDENCE-1..4 opencode 实测 + EVIDENCE-5 claude code 静态对照；env var 值全程 *** | TEST.md AC-2 用例；盲审抽查无泄露 | ✅ |
| AC-3 risk 分级方案 | ROOT-CAUSE 修复方案 D5-①..⑦ 全带 risk: low/high，high 项（③④⑤⑦）明确归 v2/out | TEST.md AC-3 用例 | ✅ |
| AC-4 low 修复+实测 | 修复①②③实施（/flow model 配置 / qa-expert sonnet→inherit / l2-detect.sh 平台提示）；DEV-SUMMARY.md 五节实测记录 | git diff HEAD --stat 0 禁动命中 | ✅ |
| AC-5 基线 | 692 ok / 0 not ok（T08 + 盲审独立复跑 plan 1..692） | TEST.md AC-5 三证断言（退出码 0 + ok 计数 692） | ✅ |

- **范围蔓延**：无。产物全部在 REQUIREMENT v1 声明范围（调查+报告+low 修复）；v2/out 项（gate 桥接、L3 API 平台适配、subagent_type 绑定修复、双平台 e2e）均未实施，正确归位
- **DESIGN 越界**：无。触碰模块仅 DESIGN §0.5.1 登记的 l2-detect.sh（low 修复③），qa-expert.md 为 TASK.md write_files 授权的第二修改文件

## B. 代码质量（6 维衰退风险）

> diff 面 = l2-detect.sh 凭证检查段 +10 行。审查框架：brooks-lint 6 维（R1-R6），内置路径。

### F1 · R4 Accidental Complexity · l2-detect.sh:170-178 — 平台探测为必要复杂度
**Severity**: 🟢 Minor
**Symptom**: l2-detect.sh:173 `command -v opencode` 平台分支 | **Source**: 《Philosophy of Software Design》· 复杂度与问题规模 | **Consequence**: 5 行分支逻辑是本 change 修复③核心交付（平台感知降级指引），复杂度与问题相称 | **Remedy**: 无需

### F2 · R3 Knowledge Duplication · l2-detect.sh:173 + CONTEXT.md:557 — 平台差异知识单点表达
**Severity**: 🟢 Minor
**Symptom**: 双平台认证机制差异（opencode auth.json vs claude code env-var-first） | **Source**: 《Clean Architecture》· 单一事实源 | **Consequence**: 代码首次表达 + CONTEXT.md 术语「双平台派发兼容」同步登记，概念级知识不重复 | **Remedy**: 无需

### F3 · R2 Change Propagation · l2-detect.sh:166-182 — 修改面最小化
**Severity**: 🟢 Minor
**Symptom**: 改动仅追加凭证缺失分支 hint 输出 | **Source**: 《Refactoring》· 修改局部化 | **Consequence**: 原 `no API credentials` 行 + `return 1` 语义保留，5 个既有调用点（gate-checks-basic.sh L53/62-63/90、29-independent-review.sh L161）零影响 | **Remedy**: 无需

### F4 · R1 Cognitive Overload · l2_dispatch_agent() — 函数边界清晰
**Severity**: 🟢 Minor
**Symptom**: 新增块紧贴凭证检查段，局部变量 `_hint` 语义自明 | **Source**: 《Code Complete》· 局部化 | **Consequence**: 303 行函数结构未变，理解成本无增量 | **Remedy**: 无需

### F5 · R5 Dependency Disorder · 无新增依赖
**Severity**: 🟢 Minor
**Symptom**: 仅 POSIX 内置 `command -v` + `${VAR:-}` | **Source**: 《Clean Architecture》· 依赖最小化 | **Consequence**: 无新 source/外部命令，hook 加载链不变 | **Remedy**: 无需

### F6 · R6 Domain Model Distortion · 忠实反映领域
**Severity**: 🟢 Minor
**Symptom**: 「凭证缺失 → 平台感知指引 → 降级」映射根因 #3 | **Source**: 《Domain-Driven Design》· 模型保真 | **Consequence**: 指引文案与 ROOT-CAUSE 根因链一致 | **Remedy**: 无需

## C. UI 视觉审查

UI: N/A（非前端项目，无 UI-DESIGN.md，diff 无 UI 文件）

## D. 综合评估

**verdict: pass**

- 无 🔴 Critical、无 🟡 Important
- 🟢 Minor 2 条：F1（平台提示与 OPENCODE-INSTALL.md 无交叉引用）、F2（`OPENCODE_BIN` 为预留 env 当前未使用）→ 入 MINOR-DEFERRED.md

## 动态门禁判定（gate_config[6-review]=L2）

| 检查项 | 级别 | 结果 |
|---|---|---|
| brooks-review 🔴 Critical | critical | 0 条 → 通过 |
| brooks-review 🟡 Major | warn | 0 条 → 通过 |
| spec 合规失败 | critical | 0 条 → 通过 |
| 跨模型分歧（spot-check） | warn | 未触发（无 Critical → ADR-014 不触发） |

**结论**：无 Critical → 无 PIPELINE PAUSE，可继续 toll-gate 6→7（待 L2 盲审 pass 后）
