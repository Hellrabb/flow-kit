# DEV-SUMMARY.md — T07 修复实施记录

- **change**: l2-l3-subagent-fix · 阶段 4 · T07 · 2026-08-05
- **对应 AC**: AC-4（risk: low 修复实施 + opencode 实测拉起 L2）+ AC-5（基线）

## 实施清单（用户确认全部实施 ①+②+③）

### 修复① — /flow model 配置持久化兜底（D5-① · risk: low ✅）
- **做了什么**：`.flow-active.goal.l2_model = .goal.l3_model = deepseek-v4-flash`（jq 原子写 + updated_at）
- **为什么**：fk_resolve_model() 三级链（ANTHROPIC_* > FLOW_KIT_* > .goal.l*_model）在 opencode
  运行时前两级全空 → 第三级持久化兜底可让 L2/L3 模型解析非空
- **实测验证**：`PROJECT_ROOT=$PWD fk_resolve_model L2/L3` → 均返回 `deepseek-v4-flash`（带 PROJECT_ROOT 时）；
  不带 PROJECT_ROOT 返回空（fk_resolve_model 读 ${PROJECT_ROOT}/.flow-active，属既有行为）
- **偏离 DESIGN**：无（D5-① 原样）

### 修复② — qa-expert.md model: sonnet → inherit（D5-② · risk: low ✅）
- **做了什么**：`~/.config/opencode/agents/qa-expert.md:4` model 字段改为 inherit
- **为什么**：消除双平台 agent 定义分歧（opencode sonnet vs claude code inherit，盲审发现 R2）；
  与 claude code 侧对齐无害
- **实测验证**：**修复后重测 `task(subagent_type=qa-expert)` 仍 30min 超时**——鉴别实验证明
  subagent_type 路由创建的子会话 agent=undefined model=undefined，**与 model 字段值无关**
- **偏离 DESIGN**：D5-② 原预期「可修复拉起失败」被鉴别实验推翻——修复②仅对齐声明，不解决
  subagent_type 路由挂起（见下「关键鉴别实验」）

### 修复③ — l2-detect.sh 凭证缺失路径平台探测提示（D5-⑥ · risk: low ✅）
- **做了什么**：`l2-detect.sh` 凭证检查段（L169-174 原位置）无凭证时，先平台探测
  （command -v opencode → opencode 检测到）再输出降级指引：opencode 提示「子 agent 模型绑定
  走 category 路由，请用 category= 派发（如 unspecified-high），或 /flow model l2=<model>
  配置持久化兜底」；claude code 提示「确认 ANTHROPIC_AUTH_TOKEN 已注入，或 /flow model 兜底」
- **为什么**：凭证缺失路径原为静默 return 1——opencode 下必现（认证走 auth.json 不注入 env），
  无指引则主 agent 不知可用替代路径（category 路由）
- **实测验证**：`bash -n` OK；`l2_dispatch_agent 3 l2-l3-subagent-fix /tmp/l2fix-test` →
  输出 `no API credentials` + `opencode 检测到：…category=…` → return 1（降级）

## 关键鉴别实验（根因 #2 修正依据）

| 派发方式 | agent/model | 结果 | 会话 |
|---|---|---|---|
| task(category=quick) | Sisyphus-Junior / deepseek-v4-flash (category: quick) | ✅ 4s | ses_02ee3f0a7ffedjcGtFXE5rL05E |
| task(subagent_type=qa-expert) | sonnet（修复前） | ⛔ 30min 超时 | ses_02ee3228cffehQEyBBGM1omjc3 |
| task(subagent_type=qa-expert) | inherit（修复②后重测） | ⛔ 30min 超时 | ses_02e8f46b0ffeEcavAH1zWIILaF |
| task(subagent_type=architect-reviewer) | inherit（阶段 2/3 成功用过的 agent） | ⛔ 30min 超时 | ses_02e737e2affeMxTSQCdVvNYbT7 |

**结论**：opencode.log 子会话创建记录 `agent=undefined model=undefined` → subagent_type 路由
在本环境未绑定 agent 定义（与 model 字段值无关）；**可用路径 = category 路由**（阶段 2/3
L2 盲审 category=unspecified-high 已验证成功）。subagent_type agent 绑定修复属平台层（out 范围）。

## AC-4 实测结论（opencode 拉起 L2）

- ✅ 走 **category 路由**可拉起（4s 实测 + 阶段 2/3 L2 盲审真实运行 3m25s/1m16s 佐证）
- ⛔ 走 **subagent_type 路由**挂起（30min 超时 × 3 次可复现，含 inherit 对照）
- mock 边界：派发机制走真实运行时（task 工具真实调用），符合 AC-4 mock 边界要求
- 本机 claude code 侧：CLI 2.1.71 环境四环节全通（EVIDENCE-5），未做双平台 e2e（v2 范围）

## 不可行/未实施项

- D5-③/④/⑤（high 风险触禁动清单：gate 核心链 / l3 链）→ 不实施，归 v2（CHANGE.md 范围排除）
- D5-⑦ subagent_type agent 绑定修复 → out 范围（平台层）
- 本机 claude code e2e 实测 → 需 claude code 运行时（v2）

## 验证记录

- T07 verify 三条件：test -s DEV-SUMMARY.md ✅ / grep 拉起|spawn ✅（多处）/ git diff --stat
  无禁动文件（见下）
- 基线：AC-5 基准 662/662（STATE.md · test-failures-fixup-2026-08 · 2026-08-03）；
  当前 test/ 实测 692 条 @test 声明（grep 粗计 710 含 18 处 email 字符串误计，与 npx bats plan 1..692 吻合；L2 盲审阶段 5 独立复核）

## T08 基线回归结果（2026-08-05）

- `npx bats test/` 实测：**692 ok / 0 not ok**（`^ok ` 计数 692，`^not ok` 计数 0）
- AC-5 验证命令 `[ "$(npx bats test/ 2>&1 | grep -c '^not ok')" = "0" ]` → PASS
- 0 新增 fail：无 pre-existing 归因需求（全部通过）
- 修复①②③ 后基线无损（l2-detect.sh 改动仅凭证缺失提示路径，bats 全绿）

## 阶段 6 L2 盲审发现处置（2026-08-05）

INDEPENDENT-REVIEW-6.md verdict=pass（无 🔴），4 条 🟡 Important + 2 条 🟢 Minor，处置：

| 发现 | 级别 | 处置 | 落点 |
|---|---|---|---|
| #1 R6 平台身份探测不可靠（command -v opencode 误判） | 🟡 | **Fixed**（代码修复） | l2-detect.sh:176 移除 `\|\| command -v opencode`，仅 OPENCODE_BIN 显式信号走 opencode 分支；默认 claude code 分支附加 opencode 备选指引；注释更新运行时判定语义 |
| #2 R3/R2 知识重复且漂移（提示 vs prompt subagent_type） | 🟡 | **部分 Fixed + Tech-debt** | 代码侧：l2-detect.sh 提示文案统一（`_model_hint` 抽取消除 L177/L179 逐字重复）；prompt 层漂移（prompts/{1,5,6}-*.md 仍写 subagent_type: qa-expert/code-reviewer）+ L2-blind-review.md SYNC-POINT（l2-detect.sh:119）未同步 category 知识 → **归 v2**（本次 write_files 不含 prompt 文件；属 D5-⑦ 范畴） |
| #3 R5/实效性 目标平台不可达（opencode 下 PreToolUse 不触发） | 🟡 | **Tech-debt**（结构性，非代码可修） | 提示唯一生产触发点=PreToolUse gate 链（gate-checks-basic.sh:53,63），opencode 下结构性不触发（根因 #1 自证）。**修复③价值重新定位**：生产可达场景=claude code 凭证缺失（hook 链触发）+ opencode 手动调用/未来桥接插件（D5-③ v2 落地后自动可达）；「opencode 非静默失败」目标的完整达成依赖 v2 桥接插件，本次仅完成代码层提示实现 |
| #4 证据链内部矛盾（EVIDENCE-5 结论2 vs EVIDENCE-3 鉴别实验） | 🟡 | **Fixed**（证据修订） | EVIDENCE-5-claude-code.md 结论2 + 现象段修订：明确 `inherit` 非 subagent_type 拉起机制；阶段 2/3 成功实为 category 路由；D5② 仅对齐双平台声明不解决 subagent_type 路由；交叉引用 EVIDENCE-3 步骤3 + DEV-SUMMARY 鉴别实验段 |
| 🟢 R4 平台探测 PATH 状态依赖 | 🟢 | **Fixed**（随 #1 修复消除） | command -v 探测移除后不再有 PATH 状态依赖 |
| 🟢 CONTEXT.md 追加块嵌套（L557-562 在 td072 ↓/↑ 标记内） | 🟢 | **Deferred** | 登记阶段 6 MINOR-DEFERRED.md；泛化扫描工具误归风险低（ID 匹配工具无碍），7-integration 归档时重排标记 |

**修代码优先协议合规自检**（l2-l3-fix-compliance · 6-review 特殊点）：
- 4 🟡 中 3 条对应代码/证据修复（#1 代码、#4 证据、#2 代码侧部分）；1 条（#3）为结构性限制不可代码修复，已登记 tech-debt 含明确 v2 路径与价值重新定位（非「仅文档了事」）
- 源码级发现（#1/#2/#3）中 2 条 Fixed、1 条 Tech-debt（33%）< 50% 阈值，无需显式 abuse 说明
- 范围约束：未越界改 prompt 文件（write_files 边界遵守）

## 阶段 6 verify 复跑（修复后）

- `bash -n flow-kit-bundle/hooks/stop/lib/l2-detect.sh` → SYNTAX_OK
- `OPENCODE_BIN= bash -c 'source l2-detect.sh; l2_dispatch_agent 6 test /tmp/l2fix-verify'`（默认分支）→ 输出「claude code 检测到」+ return 1
- `OPENCODE_BIN=/x bash -c '...'`（opencode 显式信号）→ 输出「opencode 检测到」+ return 1
- `npx bats test/` → 692 ok / 0 not ok（修复无损基线）
