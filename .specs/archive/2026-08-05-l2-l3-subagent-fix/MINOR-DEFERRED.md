# MINOR-DEFERRED · 阶段 1+2 · l2-l3-subagent-fix

> Minor 发现按 severity gating 协议不入 fix loop，记入本台账，最终审查（6-review）时 triage。

| ID | 发现 | 位置 | 处理决定 |
|---|---|---|---|
| R5 | AC-3「每条修复方案标 risk」被 `grep -cE 'risk: (low\|high)' ≥ 1` 验证：一条达标即可放行其余未标条目 | REQUIREMENT.md:35-36 | **deferred** — 报告写作期（阶段 4 DEV 产出 ROOT-CAUSE.md）人工核对每条方案带 risk 标注；验证命令在 TEST 阶段可临时加强为 `grep -cE '^### .*方案'` 与 `grep -cE 'risk: (low\|high)'` 数值相等 |
| R6 | v1 范围「CONTEXT.md 术语沉淀」无 AC 覆盖：范围项不可验证 | REQUIREMENT.md:61 | **已满足** — 术语表 `l2-l3-subagent-fix 追加块`（双平台派发兼容 / 拉起失败 / 根因报告 / risk 分级修复方案）已于 2026-08-05 写入 `.specs/CONTEXT.md`，无需再补 AC |
| R7 | AC-4/AC-5 为条件 AC 但无「条件不成立」分支声明：用户否掉全部 low 修复时空洞通过 | REQUIREMENT.md:40,47 | **deferred** — 当前 change 用户已确认调查为主、修复以报告为准（CHANGE.md「修复范围以报告为准，不预先承诺」）；若实施时用户确认清单为空，AC-4/AC-5 以"不适用"记录于 DEV-SUMMARY.md，交付物为 ROOT-CAUSE.md |

## 阶段 2 · L2 盲审 Minor（INDEPENDENT-REVIEW-2.md）

| ID | 发现 | 位置 | 处理决定 |
|---|---|---|---|
| R3 | 触碰模块清单漏列 `gate-checks-review.sh`（L24 `fk_extract_l2_verdict` / L65 `_gate_check_l2`，环节② L2 verdict 消费方） | DESIGN.md §0.5.1 | **deferred** — ROOT-CAUSE.md 受影响模块清单（五段结构）阶段 4 产出时补入该文件，TEST 阶段验证 `grep gate-checks-review` |
| R4 | §9.2 决策表与 §4「v1 无新增 ADR」张力：agent model 声明规范无 ADR 载体 | DESIGN.md §9.2 | **deferred** — 若 D5 候选②（qa-expert model: sonnet → inherit）经根因确认后实施，随修复补简短 ADR（或登记 CONTEXT.md 已锁决策条目）；§9.2 表述已隐含"候选决策（待根因确认后升格）" |
| R5 | D2/D3 中「R2 修复」「R3 修复」编号与 §5 风险表编号重合，读表歧义 | DESIGN.md §1 D2/D3 | **deferred** — 编号语义上下文自明（决策表 vs 风险表不同区），6-review 最终审查时统一校验；如需可改「（缓解风险 R2）」 |

## 阶段 3 · L2 盲审重审 Minor（INDEPENDENT-REVIEW-3.md · 重审段）

| ID | 发现 | 位置 | 处理决定 |
|---|---|---|---|
| N1 | T07 verify 禁动排除正则缺 `done-validation`（`fk_validate_done_marker` 所在，属 gate 核心链）与 `gate-helpers*`；且 `git diff --stat` 仅查 unstaged 变更 | TASK.md:182 | **deferred** — T07 write_files 已限域（ROOT-CAUSE.md/DEV-SUMMARY.md/l2-detect.sh/qa-expert.md，均非禁动），verify 的 diff 排除是兜底防线；DEV 阶段若 T07 触发实施，补 `done-validation|gate-helpers` 到排除正则并改用 `git diff HEAD --stat` |
| N2 | T08 verify `[ "$(npx bats test/ 2>&1 | grep -c '^not ok')" = "0" ]`：若 npx bats 本身启动失败（无输出），grep -c 计 0 → 假绿（0 fail 与"没跑起来"不可区分） | TASK.md:202 | **deferred** — 与 REQUIREMENT.md:50 AC-5 验证方式一致（基线 662/662 · STATE.md test-failures-fixup-2026-08）；DEV 阶段跑 T08 时先确认 `npx bats test/` 正常启动再判结果，TEST 阶段可临时加强为同时断言 bats 退出码 |
| N3 | TASK.md:180 与 DESIGN.md:141 引用「R7 台账空分支」但 DESIGN §5 风险表仅 R1-R6 无 R7 定义（两文档一致） | TASK.md:180 · DESIGN.md:141 | **deferred** — 语义上下文自明（指 MINOR-DEFERRED 台账 R7 条 · 条件 AC 空分支声明）；6-review 最终审查时统一校验，如需改述「台账 R7」 |

## 阶段 5 · L2 盲审 Minor（INDEPENDENT-REVIEW-5.md）

| ID | 发现 | 位置 | 处理决定 |
|---|---|---|---|
| N1 | claude code 侧「四环节全通」结论强度超出实测（实为静态对照 + 架构推断；hook env 继承未实测） | ROOT-CAUSE.md:18 · EVIDENCE-5:21,49 | **Fixed 2026-08-05** — P6 行与 EVIDENCE-5 两处结论加限定「（静态对照 + 架构前提，e2e 归 v2）」 |
| N2 | AC-5 验证命令 `grep -c '^not ok'` 假绿（bats 启动失败计 0），TEST 阶段未加强 | TEST.md:55 | **Fixed 2026-08-05** — TEST.md 补三证断言记录（退出码 0 + plan 1..692 + ok 计数 692）；后续基线验证建议 `npx bats test/ && grep -c` 形式 |
| N3 | 「710 @test」口径错误（18 处 `test@test.com` 邮箱字符串误计，真实 692） | REQUIREMENT.md:49 · DEV-SUMMARY.md:66 | **Fixed 2026-08-05** — 两处更正为 692 并注明误计来源 |
| N4 | REQUIREMENT 依赖「claude code 侧可实测」与 TEST「无法本机运行」张力未闭环 | REQUIREMENT.md:86 | **Fixed 2026-08-05** — 修订为「可静态对照 + e2e 归 v2」 |

## 阶段 6 · 主 agent 审查 Minor（REVIEW.md）

| ID | Task | Finding | Suggested Action |
|---|---|---|---|
| M1 | T07 | l2-detect.sh:173 平台提示文案与 OPENCODE-INSTALL.md 指引无交叉引用 | 后续维护时加 @see 引用（v2 做桥接插件时） |
| M2 | T07 | l2-detect.sh:172 OPENCODE_BIN 为预留 env（当前未使用，无害） | 保留；opencode 官方 env 化后启用 |

## 阶段 6 · L2 盲审 Minor（INDEPENDENT-REVIEW-6.md）

| ID | 发现 | 位置 | 处理决定 |
|---|---|---|---|
| L2-R4 | 平台探测引入 PATH 状态依赖（OPENCODE_BIN 与 command -v 双信号源语义不清） | l2-detect.sh:175-180 | **Fixed 2026-08-05** — 随 🟡#1 修复消除：command -v 探测移除，仅 OPENCODE_BIN 显式信号 |
| L2-CTX | CONTEXT.md 追加块嵌套（L557-562 位于 td072 块 ↓/↑ 标记内，泛化扫描工具会误归） | .specs/CONTEXT.md:557-562 | **Deferred** — ID 匹配工具无碍，7-integration 归档时重排标记 |

## 阶段 7 · Triage 决策（2026-08-05）

**整体策略**：(c) 全部不转技术债（aggressive）

**理由**：
- 阶段 1/2/3 的 deferred 项（R5/R7/R3/R4/R5/N1/N2/N3）多数已在后续阶段隐式闭合：
  - R3（gate-checks-review.sh）→ 阶段 4 ROOT-CAUSE 受影响模块清单已补入
  - R5 编号歧义 → 阶段 3 F7 + 阶段 6 已统一
  - N1/N2 verify 加强 → 阶段 6 fix loop 已实施
  - N3 编号 → 阶段 3 F7 已处理
  - R5/R7 条件 AC → T07/T08 实际执行时已处理（用户确认了修复）
- 剩余 v2/out 范围项（D5-③④⑤⑦）已在 ROOT-CAUSE.md §4 + DEV-SUMMARY.md 记录，无需 LESSONS 重复
- L2-CTX（CONTEXT.md 嵌套）受 7-integration §5.1「禁止改 CONTEXT.md」约束，归 A-evolve 处理（低风险，ID 匹配工具无碍）

**不转 LESSONS 的依据**：提名条件（调试>30min/不限于本任务/6月内再撞）这些 Minor 项多数不满足——它们是写作规范类（编号歧义/验证加强），非可复用技术陷阱。真正的技术陷阱（subagent_type 路由/path-guard）已单独提名 L-073/L-074。
