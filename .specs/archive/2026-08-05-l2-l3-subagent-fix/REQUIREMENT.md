# REQUIREMENT: L2/L3 子 agent 双平台拉起失败 — 根因调查与低风险修复

- **Change ID**: l2-l3-subagent-fix
- **关联**: `@.specs/l2-l3-subagent-fix/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想系统性定位 L2/L3 子 agent 在 opencode / claude code 双平台拉起失败的根本原因，以便把"拉不起来"从偶发现象变成有据可查、可修复的确定性根因。
- **US-2**：作为 opencode 用户，我想 L2 独立审查子 agent 能像 claude code 下一样被成功拉起并回写审查结果，以便独立审查机制不因运行时平台差异而断裂。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 根因报告覆盖全链四环节

- **Given** 调查已完成且报告已写入 `.specs/l2-l3-subagent-fix/ROOT-CAUSE.md`
- **When** 检查报告结构
- **Then** 报告包含五段（现象矩阵 / 根因链 / 双平台差异矩阵 / 风险分级修复方案 / 受影响模块清单），且对**全链四环节**——① 派发命令生成（`l2-detect.sh`）② PreToolUse 触发（`independent-review-gate.sh`）③ prompt 派发段 ④ env var 透传链（`ANTHROPIC_*` / `FLOW_KIT_*`）+ L3 API 直连（`l3-review.sh`）——每一环节均给出实测结论
- **验证方式**: `test -s .specs/l2-l3-subagent-fix/ROOT-CAUSE.md && grep -cE '^## (现象矩阵|根因链|双平台差异矩阵|风险分级修复方案|受影响模块清单)' .specs/l2-l3-subagent-fix/ROOT-CAUSE.md` 输出 ≥ 5；且 `grep -cE 'l2-detect|independent-review-gate|prompt 派发段|env var 透传|l3-review' .specs/l2-l3-subagent-fix/ROOT-CAUSE.md` 输出 ≥ 4（四环节锚点各至少命中一次，防"五段齐全但四环节零实测"）

### AC-2 · 每条根因有双平台实测证据

- **Given** 根因报告已完成
- **When** 抽查任意一条根因条目
- **Then** 该条目附 opencode 与 claude code **各至少一次实测**的命令输出与 `文件:行号` 引用；某平台不可复现时，该条目显式标注"该平台未复现 + 原因"，不写无证据猜测；**证据中的 env var 只显示变量名 + set/unset 状态，值一律脱敏为 `***`**（调查对象恰是 `ANTHROPIC_*` / `FLOW_KIT_*` 透传链，实测输出可能含凭证值，必须遵守安全 NFR 防入库泄露）
- **验证方式**: 人工抽查 ≥ 2 条根因；`grep -c '实测' .specs/l2-l3-subagent-fix/ROOT-CAUSE.md` ≥ 2

### AC-3 · 修复方案按风险分级且标注禁动清单碰撞

- **Given** 根因报告已完成
- **When** 检查「风险分级修复方案」段
- **Then** 每条修复方案标注 risk 级别（low=本次可实施 / high=触及 CONTEXT.md 禁动清单或 gate 核心链 → 放 v2），并标注是否触碰禁动清单条目
- **验证方式**: 人工检查；`grep -cE 'risk: (low|high)' .specs/l2-l3-subagent-fix/ROOT-CAUSE.md` ≥ 1

### AC-4 · 低风险修复实施且在 opencode 实测拉起 L2

- **Given** 用户已确认报告中 low 风险修复清单
- **When** 修复实施完成
- **Then** 在 opencode 环境成功拉起一次 L2 子 agent 盲审（阶段产物实测或同参数 mock 复现均可）且结果回写 `INDEPENDENT-REVIEW-N.md`；修复 diff 可见且不含禁动清单模块。**mock 边界**：派发机制必须走真实运行时（真实 task tool / hook 路径 + 真实 env 透传），仅 L2 审查内容本身可 mock；若真实派发不可行，须在 DEV-SUMMARY.md 记录不可行原因（防 mock 绕过真实派发路径造成假绿）
- **验证方式**: 实测记录（子 agent 派发命令 + 回写文件）写入 `.specs/l2-l3-subagent-fix/DEV-SUMMARY.md`；`git diff --stat` 核对改动文件

### AC-5 · 全量测试不回归

- **Given** 低风险修复已实施
- **When** 运行 `npx bats test/`
- **Then** 0 新增 fail（基线 = 归档基线 662/662，来源 `.specs/STATE.md` last_change_archived=test-failures-fixup-2026-08 · 2026-08-03；实测当前 `test/*.bats` 真实 @test 声明 692 条——注：`grep -c '@test'` 粗统计为 710，含 18 处 `test@test.com` 邮箱字符串误计，L2 盲审阶段 5 独立复核确认 692 与 `npx bats` plan 1..692 吻合）。任何 fail 必须逐条列出：属 pre-existing 的须附历史证据（CHANGELOG / 归档记录），无法证明 pre-existing 的一律视为本次引入
- **验证方式**: `npx bats test/ 2>&1 | grep -c '^not ok'` 输出 0；非 0 时把 fail 清单 + pre-existing 归因证据写入 DEV-SUMMARY.md

---

## 范围切分

### v1（本次必做）

- 全链四环节根因调查（派发命令 / PreToolUse 触发 / prompt 派发段 / env var 透传 + L3 API 直连）
- 根因报告 `ROOT-CAUSE.md`（五段结构 + 双平台实测证据 + 风险分级修复方案）
- 用户确认的 **low 风险**修复实施 + opencode 实测拉起验证
- CONTEXT.md 术语沉淀（双平台派发兼容相关新术语）

### v2（下一轮考虑，不本次）

- **high 风险**修复：触及 gate 核心链（`independent-review-gate.sh` / `29-independent-review.sh` / `fk_validate_done_marker`）或 CONTEXT.md 禁动清单其他条目的改动
- ADR-020 更新（OpenCode task 能力快照，若根因指向派发命令需重拍快照）
- 双平台 e2e 自动化验收（claude code 侧 CI 级回归）

### out（永远不做）

- 让 opencode 支持 task-level model-tier（ADR-020 已实测记录不支持）
- 统一两平台 agent 架构为单一运行时（保持双轨适配，不合并）

---

## 非功能性需求

- **性能**: 调查与修复不得给运行时链路（PreToolUse / Stop hook）引入显著额外延迟；新增诊断输出默认关闭（env-var-first config）
- **可访问性**: 无
- **安全**: 根因报告与修复不得泄露本机路径 / 凭证 / 内部端点（遵守 security-privacy-audit 六大维度）；不改变 API 鉴权方式
- **兼容性**: 修复必须双平台兼容（opencode + claude code），不得修复 opencode 侧而破坏 claude code 侧
- **可观测性**: 修复点如有新增输出，遵循 `env-var-first config` 与 `L3_RESULT:` 输出契约格式

## 依赖与假设

- claude CLI 2.1.71 本机可用 → claude code 侧可静态对照（版本/工具存在性/agent 定义 diff 实测，见 EVIDENCE-5）；claude code 会话级 e2e 需运行时凭证，本机不可行 → 归 v2（L2 盲审阶段 5 Minor 修订）
- opencode 为本仓库当前运行环境 → opencode 侧实测条件具备
- CONTEXT.md 禁动清单全程生效（报告中的 high 风险项不得在 v1 实施）
- 双源测试同步（`test/` ↔ `flow-kit-bundle/test/`）继续生效

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
