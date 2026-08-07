# 独立审查 · 阶段 6 · REVIEW

> change: l2l3-cross-platform · 日期: 2026-08-07 · Reviewer: 主 agent（Phase 6 · flow-review 协议）

## 第一轮 · Spec 合规审查

| AC | 实现位置 | 测试覆盖（TEST.md） | 结论 |
|---|---|---|---|
| AC-1 三源凭证解析 | `common.sh::fk_resolve_api_credentials`（L266-314）+ l3-api.sh/l2-detect.sh 同源调用 | test_l3_credential_resolution.bats（17 用例：7 态优先级矩阵 + rc=2 + 同源断言） | ✅ |
| AC-2 优先级表 | 函数内 Path1>Path3>Path2 短路 + rc 语义 | 同上（Path3 短路 Path2 / Path1 优先 Path3 / 矩阵） | ✅ |
| AC-3 平台检测统一 | `common.sh::fk_platform_is_opencode`（L321-323，OPENCODE_BIN/OPENCODE 双信号）+ 载体边界（提示可含 env 名/correction 不含） | test_l2_dispatch_mode.bats（三态 + correction 载体 e2e） | ✅ |
| AC-4 L2 派发双模式 | 6 prompt 7 锚点注释 + l2-detect.sh box L109-113 + l3-review.sh box L217 + transcript-parser.sh L104 jq | test_l2_dispatch_mode.bats（结构断言 6 prompt + category 优先链） | ✅ |
| AC-5 agent 定义 | `.opencode/agent/flow-kit-l2-reviewer.md`（13955B）+ install_hooks.sh agent 段 L145-168 | T10 打包验证（tar 含 2 条目）+ T09 verify | ✅ |
| AC-6 凭证不落盘 | 全实现：共享函数只写全局；提示只含 env 名；curl header 仅内存 | 双 grep 红线（token 值模式全覆盖 / env 名模式限非审查者产物）零命中 | ✅ |
| AC-7 回归 25 用例 | 3+10+12 合集 | 745/745 全绿（716 既有 + 29 新增；二进制 bats 实跑） | ✅ |
| AC-8 双源 + make check + 禁动例外 | test/ 与 flow-kit-bundle/test/ diff -rq 零差异 | 745/745 全绿 + 打包源逐文件 742/742（T-FIX-01 修复后实跑）+ 禁动例外已登记 CONTEXT.md | ✅ |
| AC-9a 端到端硬条件 | pipeline 0-4 阶段真实跑通 | ⚠️ 部分：L3 真实拉起未执行（无凭证）→ UAT-1 补测约定（TEST.md 已声明） | 🟡 见 R6-1 |
| AC-9b 人工终检 | — | 7-integration 终检点 | ⏳ |

- **out-of-scope 检查**：无引入排除项内容（未读 auth.json token / 未改平台层 / 未做 provider 段自动发现 / 未改 gate 核心链 / 未重做 v1 内容）✅
- **范围蔓延检查**：无 REQUIREMENT.md 未列功能。T04 曾顺手改 box header 文本（越界）——已恢复 HEAD 原文并记录 ✅
- **架构触碰检查**：全部改动在 DESIGN §0.5.1 触碰模块 + 新增模块范围内；无 DESIGN 之外架构改动 ✅

### 第一轮结论：通过（1 项 🟡 需确认）

**R6-1 🟡 · AC-9a 的 L3 真实拉起未执行**：UAT-1（opencode 凭证配置拉起 L3）因当前会话无 FLOW_KIT_L3_* 凭证未执行。处置：已在 TEST.md 标 ⚠️ 部分 + 7-integration 终检前补测（需带凭证新会话）。**不阻塞进入 integration，但 AC-9a 的「端到端真实验证」最终判定依赖补测**。

## 第二轮 · 代码质量审查（6 维衰退风险 · 内置路径）

### R1 认知过载

- `fk_resolve_api_credentials`（common.sh L266-314）：48 行，单层 if/elif 链，每分支 4 行内完成「写全局 + return」——认知负载低 ✅
- `l2_dispatch_agent` 凭证段（l2-detect.sh L181-214）：`|| _cred_rc=$?` 条件上下文 + 三分支 rc 处理，注释解释了 set -e 陷阱——可读 ✅
- `_l3_call_api` 凭证段（l3-api.sh L30-56）：rc=2/1/0 三分支 + 拆串 hack（见 G1）——**G1 已登记 MINOR-DEFERRED M12**（v2 删 hack）

### R2 变更传播

- **正向**：凭证解析从「l3-api.sh + l2-detect.sh 两处重复实现」收敛为单一共享函数——未来改凭证链只动一处（这正是 D1 设计目标，已达成）✅
- **残留**：`credential source` 判定（l3-api.sh L89-92）重读 env 判定 Path3——与共享函数契约不一致，若未来改 Path 判定需同步两处（**G2 已登记 M13**，v2 建议 FK_API_SOURCE 第 4 全局）🟡

### R3 知识重复

- 三 Path 优先级逻辑：**单点实现**（common.sh），两调用方只读输出全局——无重复 ✅
- 平台检测：**单点**（fk_platform_is_opencode），l2-detect/l3-api/resume 均调用 ✅
- 派发双模式文案：6 prompt 注释行 + l2-detect box + l3-review box 三处各有自己的措辞（平台语义相同但文本不同）——**轻微重复**，属各载体上下文适配（box 需要对齐宽度），可接受 🟢

### R4 偶然复杂

- 三 Path 优先级 + rc 三态（0/1/2）：是需求本身（双平台 + legacy 兜底 + 配置完整性检测），非过度设计 ✅
- `FK_API_AUTH_SCHEME` 第三全局：为统一 curl 消除「双 Path 双 curl 块」的重复——简化而非复杂化 ✅
- 兜底 source（l3-api.sh L33-38 / l2-detect.sh L19-28）：为 bats 直 source 场景——必要防御，注释清楚 ✅

### R5 依赖混乱

- common.sh 被两个 hook lib 依赖：方向正确（lib 层 → lib 层），无业务层反向 ✅
- resume.sh 用 `script_dir` 相对路径 source common.sh：与既有 L175/176 模式一致 ✅
- install_hooks.sh agent 段复用 install_file()/PLATFORM_CONFIG_DIR：无新依赖方向 ✅
- **注意**：common.sh 现在被 pre-tool-use 链（gate-checks-basic.sh → l2-detect.sh）间接依赖——pre-tool-use 首次 source common.sh，检查无副作用（纯函数定义 + 变量声明，无顶层执行）✅

### R6 领域扭曲

- 命名：`fk_resolve_api_credentials` / `fk_platform_is_opencode` / `FK_API_AUTH_SCHEME` / `credential_source`——与既有 fk_/_fk_ 前缀规范一致，领域语义准确 ✅
- box 内文案「subagent_type 在 opencode 下会挂起」——准确反映 P1 根因，无模糊表述 ✅

### 第二轮发现汇总

| 编号 | 级别 | 发现 | 处置 |
|---|---|---|---|
| R6-2 | 🟢 | l3-review.sh box 双模式两行并存（subagent_type + category 同时列出），用户复制时可能两行都保留 | 注释已引导按平台选择；v2 候选：按平台条件渲染 box（l3_dispatch_prompt 增加平台分支）。登记 MINOR |
| R6-3 | 🟢 | 6 prompt 注释行文案 3 处载体措辞微异 | 可接受（见 R3） |
| G1/G2/G3/G4 | 🟢 | 均已登记 MINOR-DEFERRED M12-M15（T12/T13/T14/T15） | 已登记 |

**第二轮结论：通过（0 🔴 / 0 🟡 / 4 🟢，全部已登记）**

## 第三轮 · UI 视觉审查

**跳过**：lib/CLI 项目（Bash 分发包），无 UI-DESIGN.md、无 UI 文件。

## 第四轮 · 补充审查

### 4.1 技术债评估

**未命中**：未装 brooks-lint（内置不提供债评估回退，按 flow-review 协议跳过）。既有 MINOR-DEFERRED M12-M15 已覆盖本 change 的债项。

### 4.2 跨模型 spot-check

**命中**（涉安全/认证：凭证处理链）→ 按 6-review.md:302 派独立盲审第 2 轮（oracle 不同模型 tier），结果写入本报告「跨模型分歧」段（见 INDEPENDENT-REVIEW-6.md ## Cross-Model Spot-Check 段）。

## 跨模型分歧（第 2 轮盲审 · Cross-Model Spot-Check）

_已归档 INDEPENDENT-REVIEW-6.md（Cross-Model Spot-Check 段）。_

主 agent 审查（初版 REVIEW.md）vs 第 2 轮盲审关键差异：

- **🔴 R1（第 2 轮独有 · 已修复）**：AC-8「双源测试全绿」声明虚假——打包源 `flow-kit-bundle/test/` 实跑 28 失败（test_archive_commit_gate.bats 24 + test_severity_format.bats 4）。主 agent 初版只跑开发源 + 采信 TEST.md 声明数字，未实跑打包源。**T-FIX-01 已修复**（TD-012 类双重 bundle 层路径 bug：`${BATS_TEST_DIRNAME}/../flow-kit-bundle/` 在打包源拼出 `flow-kit-bundle/flow-kit-bundle/`），修复后打包源 28/28、开发源 745/745、打包源逐文件 742/742 全绿（二进制 bats 实跑）。
- **🟡 R2 / R3（第 2 轮提出 · 需人工裁判）**：transcript-parser `.tool == "Agent"` 过滤 vs opencode 实际工具名（task）——category 分支可能永不命中（登记 v2，见 T-FIX-01 响应段）；AC-9a 证据失实（无 `## L3` 段 + 无 .done，UAT-1 补测清单已扩 3 项）。
- **🟡 F-A / F-B（spot-check 提出 · 需人工裁判）**：AC-6「bats 断言拆两条」未实现为 bats（红线无 CI 级回归保护，T12 verify 一次性 + 手工）；Path1 在 opencode 下不短路（残留 ANTHROPIC_AUTH_TOKEN 压制 FLOW_KIT_L3_*，spec 合规但防护不完整）。
- **🟢 共识项**：R4（测试数 716+29=745）/ R5（TD-012 类预存缺陷非本 change 引入）/ F-C（同 R4）/ F-D（平台误判低危）/ F-E（base64 模式弃用已登记 backlog T-01）。

## 审查结论（T-FIX-01 修复后终稿）

- 第一轮（Spec 合规）：通过（AC-1~AC-8 全 ✅；AC-9a ⚠️ 部分 = L3 真实拉起未执行 + 证据链缺口，UAT-1 补测 3 项已入 7-integration 前置）
- 第二轮（6 维质量）：通过（0 🔴 / 0 🟡 / 4 🟢 全登记）
- 第三轮（UI）：跳过（lib 项目）
- 第四轮（补充）：4.1 跳过（无 brooks-lint）；4.2 已执行（第 2 轮盲审完成，分歧已归档 INDEPENDENT-REVIEW-6.md）
- **盲审处置**：🔴 R1 已由 T-FIX-01 修复（实跑证据：打包源 28/28 → 双源全绿）；🟡 R2/R3/F-A/F-B 登记待人工裁判（7-integration 终检点）；🟢 全登记 MINOR-DEFERRED

---

## Delta 修订审查（2026-08-08 · 平台翻转 + 工具名双形状 + AC-6 bats 断言）

### Delta 改动范围（3 文件 +94/-3 行 + 4 新 bats）
- `common.sh +81`：fk_resolve_api_credentials 平台翻转分支（opencode Path3>P1>P2 / CC Path1>P3>P2）+ 3 私有 helper（_fk_api_try_path1 / _fk_api_try_path3 / _fk_api_clear_outputs）
- `transcript-parser.sh +16/-3`：jq 过滤双形状（CC `tool_use`+`Agent` / opencode `tool`+`task`）+ 分类 if/else
- 4 新 bats（双源）：test_l3_credential_resolution.bats 17→22（+3 翻转矩阵 + 2 AC-6 红线）、test_l2_dispatch_mode.bats 12→14（+2 AC-4b 双形状）

### 第一轮 · Spec 合规（delta）
- AC-2 平台翻转：✅ 实现（fk_resolve_api_credentials 顶部 if fk_platform_is_opencode 分支）+ bats 覆盖（3 用例：翻转 + 兜底 + 零回归）
- AC-4b 工具名双形状：✅ 实现（transcript-parser jq 双过滤 + state.input.category 归类）+ bats 覆盖（2 用例：CC + opencode mock）
- AC-6 bats 断言：✅ 实现（2 用例 `-z "$output"` 格式，扫描范围不含审查报告）—— 前轮 F-A 🟡 已解决
- AC-8 双源全绿：✅ 752/752 + make check 四门 + 打包源 66 文件逐文件

### 第二轮 · 6 维质量（delta）
- **R1 认知过载**：✅ 平台翻转分支通过 3 私有 helper 保持主函数可读（每 helper < 15 行）
- **R2 变更传播**：✅ 所有调用方读 FK_API_* 全局（不关心 Path 顺序），翻转零传播
- **R3 知识重复**：✅ Path2 兜底共享（不随平台翻转重复）
- **R4 偶然复杂**：✅ 平台分支是需求必要（非过度工程）
- **R5 依赖混乱**：✅ 私有 helper ← 公共函数（单向）
- **R6 领域扭曲**：✅ Path1/2/3 技术命名是既有约定（不改）

### Delta 结论
- 0 🔴 / 0 🟡 / 0 🟢（delta 改动干净，既有 🟢 仍登记 MINOR-DEFERRED M12-M20）
- 前轮待裁判项 F-A 已解决（AC-6 bats 断言已实现）；F-B 已通过 REQUIREMENT AC-2 修订 + 平台翻转实现解决

**结论：修复后无未决 🔴。** 进入 toll-gate 6→7 前置条件：① R6-1 + R2/R3/F-A/F-B 处置路径已记录 ② R6-2 已登记 MINOR-DEFERRED ③ spot-check 已归档 ④ T-FIX-01 修复已验证（745/745 + 742/742）。
