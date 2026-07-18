# REQUIREMENT: L2/L3 独立审查 gate 残留缺陷根治（F 重构 + H/I/J v2）

- **Change ID**: l2-l3-mock-fix
- **关联**: `@.specs/l2-l3-mock-fix/CHANGE.md`、`@.specs/CONTEXT.md`
- **修订**: 回应 L2 盲审 R1（🔴）+ R2/R3/R4/R5/R6（🟡🟢），见 `INDEPENDENT-REVIEW-1.md`「主 agent 回应」段

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想 gate 编排层用**单一来源**的 `PHASE_GATE_KEY_MAP`，以便 forward transition gate 不因 common.sh 与 gate 文件重复定义而失同步。
- **US-2**：作为 L2 审查子 agent，我想写审查报告时即使正文含 "git commit" 字符串也**不被误拦**，以便审查文本自然、不被迫用 `chr()` 拼装污染。
- **US-3**：作为 flow-kit 用户，我想 Stop hook 尽可能自动触发 L3 审查，并有可靠的 `l3_review_run` 手动兜底，以便 L3 不因触发链断裂而漏跑。
- **US-4**：作为 flow-kit 维护者，我想 L3 复审基于 artifact 的 `## L3` 段而非 mtime，以便 artifact 被 touch 不被误判已审查而 skip 复审。

---

## 验收准则（AC）

### AC-F · PHASE_GATE_KEY_MAP 单一来源（pure fn · 附边界声明 · 回应 R3/R5/R6）

> **边界声明（回应 R5）**：本 AC 仅允许 (a) 提取 `PHASE_GATE_KEY_MAP` 定义为单一来源（pure fn 或纯定义共享文件）；(b) 调整调用点引用该单一来源。**禁止**修改 `_run_review_gates` 7 Gate 的控制流、Gate 间 transition 逻辑、Gate 触发顺序。INT-7 回归作为边界守护。该边界同步到 out 段交叉引用。

- **Given** `PHASE_GATE_KEY_MAP` 当前在 `common.sh` 与 `independent-review-gate.sh` **两处独立 `declare -A`**（v1 为隔离 source common.sh 的全局副作用而引入局部 declare，gate.sh 注释自承"若 common.sh 增删 phase 此处须同步"——结构事实，具体行号见 DESIGN 核实）
- **When** 重构为单一来源纯函数（消除重复 declare），对附录映射表每个 phase key 跑 forward transition gate 集成测试
- **Then** `gate_val` 对每个 phase key **等于文末「附录 · PHASE_GATE_KEY_MAP 预期映射表」oracle 值**（强引用附录，非"非空"——非空不充分）；pure fn 单测逐 key 断言返回值=oracle（回应 L3-Major2）。**review phase(6) 无 `.done` 时 forward transition 被 deny 的行为不在本 AC 断言**（属控制流范畴，与本 AC pure fn 数据结构边界冲突），完全交由 INT-7 回归覆盖
- **验证方式**: `bats` 集成测试（payload 注入 `bash independent-review-gate.sh` + exit code 断言）+ pure fn 单测（逐 key 断言映射值 = 附录 oracle）+ INT-7 回归

### AC-H · is_git_commit 命令识别（反规避约束 · 回应 R1 🔴）

> **机制下沉 DESIGN**：本 AC 只描述**可观察的行为边界**。"结构化命令识别"的具体机制（首 token 匹配 / quoting 感知 / argv 解析等）在 DESIGN.md ADR 定，REQUIREMENT 不规定实现。
> **反规避约束（硬 · 回应 R1）**：实现**禁止**用字符串白名单/黑名单列表（如"排除含 X 的字符串"）达成——否则 TEST 用白名单绕过，BUG-H 根治落空。判据见 Then (f)。

- **Given** 经 gate 的 payload 分属以下等价类（每类 ≥1 例）：
  - (a) 纯文本含敏感子串（如审查报告正文）
  - (b) 命令链 `echo "敏感子串"`
  - (c) 命令链首/尾含敏感子串但非真实命令（注释 / heredoc / 变量展开）
  - (d) 真实 `git commit -m "..."`
  - (e) 真实 `git commit` 带前后管道/重定向/子 shell
- **When** 经 `is_git_commit` 判定
- **Then** (a)(b)(c) **不 deny**；(d)(e) **deny**；(f) 实现源码**不含**针对具体敏感字符串的白/黑名单字面量（grep 静态断言，防 TEST 绕过）
- **验证方式**: `bats` 集成测试覆盖 (a)-(e) 各等价类 + grep 断言 (f)。**活体素材**：本 change L2 盲审写报告时即被 BUG-H 误拦（`INDEPENDENT-REVIEW-1.md` line 9 现场记录），复现该场景为 (a) 类用例

### AC-I · L2-first 顺序契约 + 可观测性（D3 重定义 · Explore 根因诊断 2026-07-18）

> **根因修正**：原"BUG-I Stop hook 触发不可靠"经 Explore 诊断为**误判**——Stop 链没断、29 跑了、CONFIG_FILE 正确注入；L3 不产出是 29 D4 门的设计内 **L2-first 顺序契约**（gate_config=both 时 L3 等 `## L2 盲审` 段；Stop hook 不能自派 L2 子 agent）。见 ADR-009。

- **Given** gate_config[phase]=both 的阶段审查
- **When** 主 agent 派 L2 子 agent + 写 `## L2 盲审` 段后，Stop hook 跑 29
- **Then**
  - (a) **L2-first 顺序契约文档化**：CONTEXT.md / hook 注释明确"gate_config=both 时主 agent 必须先派 L2 + 写段，Stop 才能 L3"
  - (b) **29 D4 提示清晰化**：D4 `exit 0` 时提示含"主 agent 请派 L2 子 agent 并写入 `## L2 盲审` 段"指引（不止"L2 not yet complete"）
  - (c) **可观测性日志**：D4 退出记录"等待 L2"状态到 hook report
- **验证方式**: 构造 gate_config=both + 无 L2 段，跑 29，断言 D4 提示含派发指引 + 日志记录；契约文档存在。**不追求** Stop 自动派 L2（框架硬限制）

### AC-J · _l3_check_rerun 检查 ## L3 段（客观判定 · 回应 R3）

- **Given** artifact 被 touch（mtime 更新）
- **When** `_l3_check_rerun` 判断是否需复审
- **Then** 判定基于 `## L3` 段（regex `^## L3 (盲审|重审)`，**前缀匹配真实 token**——l3-review.sh:439/441 写 `## L3 重审/盲审（模型 · 时间）`，与 l3-review.sh:461/529 自身判定一致；回应 L3-task-R1 🔴：原 `(盲审|外部模型审查)$` 零匹配）+ artifact hash（存 INDEPENDENT-REVIEW-N.md 末尾 `L3_artifact_hash: <sha>` 元数据行，**不触 .done**）：**当前 artifact sha == 记录 hash 且 `## L3` 段非空 → skip；否则（hash 变/段空）触发复审**。touch（hash 不变）不触发
- **验证方式**: `bats` 集成测试：touch artifact（无 `## L3` 段）→ 仍触发复审；有非空 `## L3` 段 → skip

### AC-T · 集成测试覆盖 + 全套真绿（联动 R1 误判场景）

- **Given** 每个 gate 改动（F/H/I/J）
- **When** 跑全套 `bats`
- **Then** 每个改动伴 ≥1 集成测试（payload 注入 + 全链路 exit code 断言）；AC-H 的 (a)-(e) 等价类全覆盖；全套真绿（**不破坏既有测试基线**（具体数量以跑通为准）+ 新增 pass，**0 fail 0 BW01**，无 `bats|tail` 假绿陷阱，回应 L3-minor）
- **验证方式**: `npx bats test/` 直接看 exit code（禁管道 · LESSONS L-027）

### NFR-1 · 性能（回应 R4）

- **Given** F pure fn 重构前后
- **When** 固定 payload 跑 `bash independent-review-gate.sh`
- **Then** 重构前后 wall time 差 < **阈值**（DESIGN 阶段结束前**必须**填入具体 ms 或精确 %，**禁止保留文字占位符**，回应 L3-minor；参考 Stop hook 性能基线 <30% 上限）
- **验证方式**: `time` 3 次取中位数对比（LESSONS Stop hook 性能基线方法）

### NFR-2 · 兼容性（回应 R4）

- **Given** 目标 bash 版本
- **When** `bash independent-review-gate.sh` + `common.sh` 跑通
- **Then** 兼容 **bash 4.4+**（`declare -A` 需要）；pure fn 重构**不得**提高版本要求（DESIGN 核实：若 pure fn 改用不依赖 `declare -A` 的结构，兼容性只增不减）。macOS bash 3.2 不在矩阵
- **验证方式**: DESIGN 阶段在 bash 4.4 + 5.x 两档实跑

### NFR-3 · 可观测性回归（回应 R4 · 守护 BUG-D stderr）

- **Given** F/H/I/J 改动后的任一 deny 场景
- **When** gate deny
- **Then** stderr 含三要素：**phase 编号 + `.done` 路径 + 阻断原因**（继承上个 change BUG-D 修复，F 重构不得破坏）
- **验证方式**: `bats` grep 断言每个 deny 场景的 stderr 三要素

### NFR-4 · 可维护性 grep 守护（回应 R4 · 守护 DRY）

- **Given** F pure fn 重构后
- **When** `grep -rn 'declare -A PHASE_GATE_KEY_MAP' flow-kit-bundle/`（排除 test）
- **Then** 输出 **== 0 行**（当前基线 = **2 行**：common.sh + gate.sh；重构后 pure fn 用 `case` 非 `declare -A`，== 0。回应 L2-R-NFR4 三方一致）
- **验证方式**: grep 静态断言（写入测试）

### AC-K · 26-workflow.sh G1 pipeline goal 模式 phase 一致性（新增 · 实跑发现 Bug 1）

> **来源**：本 change phase 1 实跑发现——`26-workflow.sh` G1 用 `fk_auto_phase` 检测到阶段产物存在（如 REQUIREMENT.md）→ 绕过 toll-gate 直接写 `.phase=N+1`（line 90），不同步 `goal.current_phase`/`phases_done`/`gates`。单阶段 goal 时代遗留逻辑，pipeline goal 模式下与 toll-gate 机制冲突，制造 phase/current_phase 不一致（本 change 每轮 Stop 复现）。
>
> **范围决策记录（回应 L3-Major1）**：L3 建议 AC-K 范围蔓延（与 F/H/I/J 不同子系统 + 与 AC-F 边界声明张力）、剥离到独立 change。主 agent 认同范围论证，但**用户经独立审查后决定维持 AC-K 纳入 v1**——AC-K 是 phase 1 实跑发现的、**正在阻碍流程**的 bug（每轮 phase 被错误 advance），优先根治。接受 L3 指出的"v1 含 5 大改动、测试/交付风险"，以 AC-T 全绿 + 各 AC 伴单测/集成测试缓解。决策分歧已记录，不剥离（Accepted-risk）。

- **Given** pipeline goal 模式（`.flow-active.goal.scope = "pipeline"`）+ 26-workflow.sh G1 检测到 `fk_auto_phase` 推进条件满足
- **When** Stop hook 跑 26-workflow.sh G1
- **Then** pipeline goal 模式下**不擅自 advance `.phase`**——phase 推进权归 toll-gate（人工）或 31-auto-advance.sh（auto_advance=true 完整 transition，含 current_phase + phases_done + gates 同步）。若 G1 保留 auto-advance，必须**同步**上述四字段，不得只写 `.phase`
- **验证方式**: `bats` 集成测试——构造 pipeline goal + phase 1 + REQUIREMENT.md 存在，跑 26-workflow.sh，断言 `.phase` 与 `goal.current_phase` 一致（不被单独 advance）

---

## 范围切分

### v1（本次必做）

- F · `PHASE_GATE_KEY_MAP` pure fn 重构 + INT-7 回归 + pure fn 单测（受 AC-F 边界声明约束）
- H · `is_git_commit` 命令识别 + 等价类 (a)-(e) 集成测试 + 反规避 grep 断言 (f)
- I · Stop hook 触发链尽力加固（有改动则伴单测）+ `l3_review_run` 手动兜底文档 + 触发链现状诊断文档
- J · `_l3_check_rerun` 改检查 `## L3` 段 + 集成测试
- NFR-1~4 · 性能 / 兼容 / 可观测 / 可维护 守护 AC
- K · 26-workflow.sh G1 pipeline goal phase 一致性 + 集成测试
- AC-T · 全套 bats 真绿

### v2（下一轮考虑，不本次）

- BUG-I 跨环境 Stop hook **自动触发根治**（受 Claude Code 框架限制，v1 仅尽力 + 兜底）
- L3 模型可靠性 flow-kit 层介入（跟随 `ANTHROPIC_DEFAULT_HAIKU_MODEL`）

### out（永远不做）

- **重写 `_run_review_gates` 7 Gate 编排架构**（含 Gate 间 transition 逻辑 / 触发顺序——AC-F 边界声明交叉引用：F 仅动 PHASE_GATE_KEY_MAP 数据结构单一来源化，不动控制流）
- 改 L2 子 agent 机制
- flow-kit 锁定 L3 模型（跟随环境变量）
- UI / 前端

---

## 非功能性需求

- **性能**: gate hook 执行时间不因重构显著增加（NFR-1 守护，阈值 DESIGN 实测）
- **可访问性**: 无
- **安全**: gate 不能因 F 重构出现新的绕过路径（AC-F 回归兜底）；H 不能因结构化识别漏拦真实 git commit（AC-H (d)(e)）；H 禁白名单绕过（AC-H (f)）
- **兼容性**: bash 4.4+（NFR-2 守护，pure fn 不提版本要求）
- **可观测性**: deny 时 stderr 含 phase 编号 + `.done` 路径 + 阻断原因（NFR-3 守护 BUG-D 继承）

## 依赖与假设

- **依赖**：上个 change `l2-l3-test-defect` 的 gate 修复基线，已修复：BUG-A, B, C, D（D7-alt 方案：**局部 declare 隔离 source common.sh 的全局副作用**——L3 担心 config_get 等污染 PreToolUse 环境）, E, F（v1 形态：局部 declare，本 change 重构为 pure fn）, G（l2-detect mock_ts 清理）
- **假设**：当前测试基线真绿（407 pass · 已核实 `test/` 无 `mock_ts` 残留 · LESSONS L-027 确认）
- **假设**：L3 模型由 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 配置，本 change 不验证具体模型好坏；gate 代码层独立于模型
- **假设**：BUG-I 的环境天花板（本环境 Stop hook 触发行为）在 DESIGN 阶段实测确认，决定"尽力修"的可达边界

---

## 附录 · PHASE_GATE_KEY_MAP 预期映射表（AC-F oracle · 源码核实 2026-07-18）

| phase | gate_config key |
|---|---|
| 1 | 1-requirement |
| 2 | 2-design |
| 3 | 3-task |
| 5 | 5-test |
| 6 | 6-review |
| 7 | 7-integration |

> phase 0（change）与 4（dev）故意排除（无独立审查 gate）。源码两处定义（`common.sh` + `independent-review-gate.sh`）当前**完全一致**（diff 已核），重构须保持此映射不变。

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
