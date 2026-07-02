# REVIEW: 加固 toll-gate 不可绕过性 + 扩展 L2 独立审查到 3/5/7

- **Change ID**: gate-integrity
- **阶段**: 6-review
- **审查人**: AI（主 agent 角色）+ L2 盲审子 agent + L3 外部模型（待 Stop hook）
- **关联**: REQUIREMENT.md / DESIGN.md / TASK.md / TEST.md

---

## 第一轮 · Spec 合规审查

逐 AC 对照实现 vs 需求：

| AC | 要求 | 实现 | 测试覆盖 | 状态 |
|---|---|---|---|---|
| AC-1 | .done 真实性（6 类威胁）| fk_validate_done_marker 两层校验（T1/T2/T3/T3b/T4）+ D7 is_handshake_write path-guard + D8 ⑥检测 | test_gate_integrity.bats 6 测试 + 7 demo UAT 全过 | ✅ |
| AC-2 | transition 前置查 gate + 全链单一源 | pipeline-gates.md 扩全链 7 gate key transition 语义 + 4-dev 段保留 | skipped-subprocess demo + pipeline-gates.md grep | ✅ |
| AC-3 | 3/5/7 L2 gate 接入（5 站点）| 3 正则 + 2 case phase_name 扩 + 29号 artifact case 扩 3/5/7（A 决策解死锁）| test_gate_integrity.bats 4 测试 grep 5 站点 | ✅ |
| AC-4 | gate-config 预设 / 数字映射 | PRESET_MAP 扩（all 预设 + 数字 3/5/7）+ test_gate_config_presets.bats 39 tests | 39 tests 全过 | ✅ |
| AC-5 | bats 覆盖 + 不回归 | repo-root/test/ 216 total / 12 预存失败（correction-file + AC-7 + CF）/ 0 新增 | T14 实证 + TEST.md | ✅ |
| AC-6 | L3 机制实际生效 | CONFIG_FILE 回退（既有）+ l3_token sha256 + >>追加 + fail_count 随 verdict + 不 dump API JSON | test_gate_integrity.bats 2 测试 + 29号 grep 实证 | ✅ |

- **无范围蔓延**：12 文件改动全在 DESIGN §0.5.1 触碰范围内
- **无 out-of-scope**：未改 1/2/6 L2 触发机制、未重构 pipeline goal 整体语义、未改 brooks-lint 集成路径
- **无架构越界**：DESIGN §0.5.1 禁动清单（package-flow-kit.sh / flow-kit-bundle.tar.gz / .gitignore）未触

**第一轮结论**：PASS ✅。每条 AC 有实现 + 有测试覆盖。

---

## 第二轮 · 代码质量审查（6 维衰退风险 · 内置诊断）

> gate-integrity 是 meta/distribution Bash 项目，改动以机械性扩正则/加 case 分支/新建校验函数为主。用内置 6 维快查（brooks-lint 已装但改动机械性为主，内置足以覆盖）。

### 🟢 R1 · 认知过载：无单函数 > 65 行，无深嵌套 > 3 层

**Symptom**: 无。gate.sh ~180 行但 source guard 分离 helper 函数（is_handshake_write 13 行 / fk_check_gate_config_tamper 19 行 / is_phase_write 12 行），主逻辑线性。artifacts.sh fk_validate_done_marker 65 行（线性校验链，注释密度高）。
**Source**: Code Complete · Function Length / Refactoring · Extract Method
**Consequence**: N/A
**Remedy**: N/A

### 🟢 R2 · 变更传播：0 无关模块被改

**Symptom**: 改动 12 文件全部在 TASK.md write_files 范围内。TASK.md 逐 task 声明 write_files 约束，T01-T14 的越界检查全为 0。
**Source**: Refactoring · Divergent Change / Clean Architecture · Change Propagation
**Consequence**: N/A
**Remedy**: N/A

### 🟢 R3 · 知识重复：D6 "多源镜像"是明确设计决策，非概念重复

**Symptom**: phase_name case 映射在 gate.sh + artifacts.sh 两处镜像。这是 DESIGN D6 明确的"多源镜像"决策（grep 实证 5 站点，靠 bats T13 + check-gate-sync.sh 兜底漂移），非 R3 概念级重复。
**Source**: Pragmatic Programmer · DRY / DDD · Bounded Context
**Consequence**: 两处镜像如不同步会导致 gate 对 3/5/7 判定不一致 → check-gate-sync 兜底。风险可控。
**Remedy**: 已通过 bats（5 站点覆盖）+ check-gate-sync（预设名 set-diff）兜底。v2 可考虑 phase_name 单源化（需架构变更）。

### 🟢 R4 · 偶然复杂：两层校验 + source guard + path-guard 均为必要设计

**Symptom**: 无明显"以后可能用到"的扩展点。Tier 1/2 两层是 G1 决策（write gate vs transition gate）。source guard 是 check.sh/bats 可复用性的必要（exotic-escape/check.sh source gate.sh 调 is_handshake_write）。
**Source**: Philosophy of SD · Deep Modules / Code Complete · Accidental Complexity
**Consequence**: N/A
**Remedy**: N/A

### 🟢 R5 · 依赖混乱：依赖单向（hook → lib → data）

**Symptom**: gate.sh → artifacts.sh（lib）→ jq（外部）→ .flow-active/.specs（文件系统）。依赖流一致向下。无业务层 import 基础设施实现的反向依赖。
**Source**: Clean Architecture · Dependency Rule / Brooks · Conceptual Integrity
**Consequence**: N/A
**Remedy**: N/A

### 🟢 R6 · 领域扭曲：全域名

**Symptom**: phase / change_id / done_marker / handshake / verdict / l3_token / gate_config / phases_done 全是领域词。无 data/info/item 类模糊变量。
**Source**: DDD · Ubiquitous Language / Refactoring · Rename Variable
**Consequence**: N/A
**Remedy**: N/A

### 架构依赖检查

**触发条件**: 不触发。本 change 未新增/重命名顶级模块、无跨 ≥5 模块重构、无新中间件/服务。改动在单层（hook 系统 + lib + skill），模块边界未变。

**第二轮结论**：PASS ✅。6 维全 Pass（0 🔴 / 0 🟡 / 0 🟢 Minor），无需要 fix-plan 的质量问题。

---

## 第三轮 · UI 视觉审查

**跳过**。gate-integrity 是 Bash meta/distribution 项目，无前端/UI 组件（无 `.css/.tsx/.vue/.html` 文件，无设计 token/主题/动画）。本轮 N/A。

---

## 动态门禁判定（AC-9）

- 🔴 Critical: 0
- 🟡 Major: 0（check-gate-sync PCSC 预存漂移是既有问题，非本 change 引入，不标 Major）
- 🟢 Minor: 1（SKILL.md snapshot created_at: now epoch vs G3 ISO，不影响功能，fk_check_gate_config_tamper 不校验 created_at）

**门禁结论**：PASS ✅。无 Critical，无 Major 阻塞项。

## Gate 失败项

- check-gate-sync PCSC 漂移（4-dev.md 9 vs flow-dev SKILL.md 8）：预存，T14-SUMMARY 已记录，建议单独 change 修

## TEST.md 5 轮金字塔完整性

| 轮次 | 状态 | 范围 | 验证 |
|---|---|---|---|
| 第 1 轮 功能 | ✅ | AC-1~6 全部 | 矩阵全覆盖 |
| 第 2 轮 性能 | ⚠️ 部分 | gate jq 耗时 | 实测 6ms |
| 第 3 轮 安全 | ✅ | 6 类威胁 UAT | 7 demo |
| 第 4 轮 兼容 | ⚠️ 部分 | tolerant read | phases_done 短路 |
| 第 5 轮 可观测 | ✅ | stderr 拒绝消息 | 4 个可读消息 |

5 轮完整，跳过的轮次均有理由。

---

## 结论

**PASS** ✅。本 change 实现完整（AC-1~6 全覆盖），代码质量良好（6 维全 Pass），无 Critical/Major 问题，无架构侵权。通过 6-review。

## 独立 review 状态

- [x] L2 盲审子 agent — 完成（code-reviewer · 39s · 45 工具调用 · **Verdict: pass, 0 Critical**）
  - 独立确认我的 REVIEW（AC 全覆盖 + 6 维全 Pass 一致）
  - 发现 1 🟡 Major（主 agent 漏判）：29号 L3 verdict 取值为 `"unknown"` 时 fail_count 始终 0 + 门禁静默退化 → **已修复**（verdict 值域校验：非法值归入失败降级）
  - 发现 2 🟢 Minor：.goal-snapshot 更新脱节（已记录）+ created_at epoch vs ISO（与主 agent 一致）
- [ ] L3 外部模型（Stop hook 29号 · session 结束时自动跑）
- [ ] .done 标志（L3 完成后写）
