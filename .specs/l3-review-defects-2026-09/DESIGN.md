# DESIGN: L3 审查链 5 条缺陷修复

- **Change ID**: `l3-review-defects-2026-09`
- **关联**: `@.specs/l3-review-defects-2026-09/REQUIREMENT.md`（12 条 AC）、`@.specs/l3-review-defects-2026-09/CHANGE.md`
- **架构上下文**: `@.specs/CONTEXT.md`、`@.specs/ARCHITECTURE.md`
- **执行时序说明**：本 change 的实现先于本文档完成（见 `CHANGE.md` 末「执行时序声明」）。
  本文档如实记录**已发生的**设计决策（含被否决方案与代价），不假装先设计后编码。

---

## 0. 技术栈选定

**无技术栈决策**。本 change 全部落在既有 Bash hook 体系内：

| 维度 | 选定 | 依据 |
|---|---|---|
| 语言 | Bash（`set -euo pipefail`） | CONTEXT「已锁技术决策」；项目 `project_type: meta / distribution` |
| 文本处理 | POSIX awk / GNU sed / grep | 既有 hook 唯一使用的工具链（不引入 python/jq 之外的新依赖） |
| 配置 | `jq`（既有依赖） | `config_get` 既有实现 |
| 测试 | `bats`（经 `npx`） | 既有 `make test` |

**不引入**任何新运行时依赖 —— 这是本 change 的硬约束（AC-11 要求既有质量门禁不回退）。

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

**grep 实测**（`git diff --stat 19b3463 HEAD` + 工作区未提交部分），非猜测。
（2026-09-18 依设计期 L2 盲审 R3 更正：原文只用了 `git diff --stat HEAD`，
遗漏了已在 `61c4bf8` 提交的 §B3/§B4/§B5 改动 —— 包括 §B4 的 `l3-prompt.sh`，
并错误地把它列进了"明确不触碰"。现以**变更前基线** `19b3463` 为基准。）

| 文件 | 性质 | 对应缺陷 | 说明 |
|---|---|---|---|
| `flow-kit-bundle/hooks/stop/lib/l2-detect.sh` | 既有 · 改 | §B1 | `fk_extract_l2_verdict` 重写 + 新增 `_fk_l2_scope`；**并按 ADR-026 给 `l2_dispatch_agent` 的写入块加转义**（它是第 2 个载荷写入方）；`l2_detect_missing` 未动 |
| `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` | 既有 · 改 | §B4 | 阶段 7 产物清单去 `head -30` 改全量；`INTEGRATION.md` 改"存在才列"；`_l3_extract_prior_findings` 改围栏感知（ADR-025 强化）。**`head -8`/`head -3` 配额未动** |
| `flow-kit-bundle/hooks/stop/lib/l3-api.sh` | 既有 · 改 | §B2 | `_l3_parse_result` 的段删除改为 `_l3_strip_sections`；载荷写入改为 `_l3_escape_payload` |
| `flow-kit-bundle/hooks/stop/lib/l3-section.sh` | 既有 · 改（`61c4bf8` 新增） | §B2 | `L3_SECTION_END_MARKER` / `_l3_l3_marker` / `_l3_strip_sections`；本阶段新增 `_l3_section_spans`（边界判定唯一来源）与 `_l3_escape_payload`（转义唯一入口） |
| `flow-kit-bundle/hooks/stop/lib/l3-done.sh` | 既有 · 改 | §B2 / D12 | `l3_write_timeout_done` / `l3_write_bypass_done` 落结束标记；**新增 `l3_invalidate_done`**（非 pass 时撤销陈旧锚点，见 D12） |
| `flow-kit-bundle/hooks/stop/lib/l3-review.sh` | 既有 · 改 | §B2/§B3 | source `l3-section.sh`；§B3 解析链加 `_BYTES` |
| `flow-kit-bundle/hooks/stop/29-independent-review.sh` | 既有 · 改 | §B3/AC-12 | 配置改名解析 + 旧键兼容 + 导出 `_BYTES`；空值告警分支 |
| `flow-kit-bundle/hooks/config/stop-hook.json` | 既有 · 改 | §B3 | 键改名 `max_artifact_bytes` + 单位注释 |
| `README.md` / `dsh-flow-kit/README.md` / `.claude/l3.env.example` | 既有 · 改 | §B3 | 单位=字节 + CJK ÷3（`B3-R5` 四处断言） |
| `package-flow-kit.sh` | 既有 · **改（禁动偏差，见下）** | §B3 | 仅 emitted 文档 heredoc 文本 |
| `Makefile` | 既有 · 改 | §B5 | `hooks-sync` / `check-hooks-sync`（后者入门禁） |
| `sync-hooks.sh` | **新增** | §B5 | 唯一源 → 副本镜像 + 漂移检测。镜像范围经两轮 L2 盲审扩张为**四类树**：① `hooks/`（install 集）② `flow-kit/prompts/**`（固化指令载体）③ `flow-kit/.opencode/agent/flow-kit-l2-reviewer.md`（复合载体，由 `regen_l2_agent` 重放拷贝段保证同源）④ 平台级 agent 落点 `~/.config/opencode/agent/` |
| `verify-claims.sh` + `corpus-count.sh` | **新增** | 流程治理（非 §Bx） | 把"响应段里的可验证声明"做成**机械复验**：载体**动态枚举**（不写死路径/数量）、计数**现场复算**（不抄快照）、DESIGN/MINOR 结构自洽、门禁。由来：本 change 连续四轮被 L2 盲审判「声明与工件不符」，根因是复验靠**手写命令** → 漏载体、漏口径。`make verify-claims` 纳入 Makefile（不进 `make check`，避免与门禁循环依赖）。 |
| `flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md` | 既有 · 改 | §B1/§B2 | 文件写入约束新增**第 4 条**：贴入前必须过 `_l3_escape_payload`（贴入路径不经 hook，转义责任在贴入方）。它是**行为契约**，故成为镜像对象 |
| `flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md` | 既有 · 改 | §B1/§B2 | 复合载体：头部 + L2 固化指令**全文拷贝**段（自声明必须同步）。由 `sync-hooks.sh::regen_l2_agent` 从源 prompt 重放该段 |
| `~/.config/opencode/hooks/**` | 既有 · **改（此前完全未纳入门禁）** | §B5 | opencode 平台安装树 —— 二轮 L2 复审 R1 实测它与源有 **10 个文件差异**，从未被覆盖（B5 同类缺陷在另一平台复发） |
| `flow-kit-bundle/hooks/pre-tool-use/gate-helpers-types.sh` | 既有 · 改 | D11 #3 | **新增** `_gate_is_unescaped_l3_paste`（未转义 L3 贴入判据 · 纯函数便于单测） |
| `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh` | 既有 · 改 | D11 #3 | `_gate_path_guard` 增 `content` 形参 + 载荷守卫（命中 exit 2） |
| `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` | 既有 · 改 | D11 #3 | 入口解析 `tool_input.content // new_string` 并透传到守卫（3 处小改） |
| `test/test_l3_review_defects_2026_09.bats`（双源） | **新增** | 全部 | 回归套件 |
| `test/test_l3_lifecycle_wiring.bats` / `test/test_l3_review.bats`（双源） | 既有 · 改 | §B3/§B2 | 断言随契约更名；dedup 用例改为调用生产函数 |
| `.specs/CONTEXT.md` / `CHANGELOG.md` / `STATE.md` / `adr/026-*.md` | 既有 · 改/新增 | — | 域语言、已锁决策、变更登记、新 ADR |
| `.specs/l3-review-defects-2026-09/*` | **新增** | — | 本 change 工件（含 `L2-EMPTY-ATTRIBUTION.md` / `MINOR-DEFERRED.md` / 两份 INDEPENDENT-REVIEW） |
| `.specs/archive/2026-09-18-l3-review-defects-2026-09/*` | **新增（lean 归档，本阶段后将被完整七件套替换）** | — | 5 个文件：原缺陷报告 / 复测报告 / CHANGE / REVIEW / PROGRESS（L2 第八轮实测为 5） |
| `.claude/hooks/**`（镜像） | 既有 · 改 | §B5 | 由 `sync-hooks.sh` 同步，非手工编辑 || `flow-kit-bundle/hooks/stop/lib/l3-truncate.sh` | 既有 · **改** | §B2/§B1 | 「L3 段存在」判据改用 `_l3_has_section`（原裸正则）+ 依赖注入 + 头注同步（六审 R4 指出原表把它错列进"不触碰"，实则 15+/3-） |
| `test/test-l3-check-rerun-content-marker.bats`（双源） | 既有 · 改 | §B2 | `AC-J` 两处 fixture 补 `---` preamble（判据①要求）—— 六审 R4 指出全表漏列 |

**明确不触碰**（虽然相邻）：
- `l3-prompt.sh` 的 **`head -8` / `head -3` 配额**（AC 已声明不动；该文件本 change 因 §B4 有改动，见上表）
- `done-validation.sh`（T4 语义不变）· `gate-checks-review.sh` · `install_hooks.sh`
  （被 `sync-hooks.sh` **只读引用**，不改）· `package-flow-kit.sh` 的任一 Part A~G 逻辑
  （唯二例外：§B3 的 emitted 文档 heredoc 文本，见下方偏差声明）

#### ⚠️ 禁动清单命中与偏差声明（1 项）

`CONTEXT.md` 禁动清单列有 `package-flow-kit.sh`（"打包脚本核心逻辑，改动影响分发流程"），
例外仅限 Part D / Part F / Part G。**本 change 修改了该文件**，位置在
`## L3 外部审查凭证` 段的 **emitted 文档 heredoc 文本**（`max_artifact_chars` →
`max_artifact_bytes` + 单位说明），**不触及任何 Part 逻辑、不改打包流程**。

- **性质**：纯文档字符串。若不同步，脚本打印的部署说明会与实际配置键名不符 ——
  恰是 §B3 要消除的"文档与实现不一致"。
- **偏差登记**：应当改。已在 `MINOR-DEFERRED.md` M10 登记为**流程偏差**
  （改禁动文件前未先申请例外），供阶段 7 triage 决定是否接受或回退（回退的代价是
  部署文档与实现不一致）。
- **替代方案（已评估未采纳）**：把该段文档移出 `package-flow-kit.sh`，改为引用
  `README.md`。否决理由：该 heredoc 是脚本"装完即打印"的自包含部署说明，
  拆出去会让用户在 `bash install.sh` 输出里看不到关键配置说明。

### 0.5.2 既有抽象沿用对照表

| 本次需要的能力 | 既有有没有？ | 决定 |
|---|---|---|
| 分段文本处理 | `l3-section.sh` 已有「L3 段」概念（`_l3_check_rerun` 用正则、`_l3_strip_sections` 用标记） | **沿用并收口**：把"段边界判定"抽成 `_l3_section_spans` 供读/写两侧共用（L-031） |
| 文件原子写 | `mktemp` + `mv`（l3-api.sh 既有范式） | **沿用** |
| 配置读取 | `config_get`（common.sh） | **沿用**；只在 29 号加一次"新键优先、旧键兼容"的解析 |
| 环境变量解析链 | `_BYTES > _CHARS > 历史直调 > 默认` 的三元 `${A:-${B:-${C:-D}}}` 范式（既有 §B3 前身） | **沿用**，加一级 |
| 副本一致性检查 | 无（只有 T06 对单文件 md5 的断言） | **新建** `sync-hooks.sh`（理由：报告 §B5 要求"机器检查"，且既有断言覆盖不足） |
| 转义不可信内容 | 无先例 | **引入新模式**（理由见 § 1 D2 与 ADR-026；既有 hook 从未把"模型原文"当作可伪造边界的输入处理） |

### 0.5.3 沿用模式 vs 引入新模式

- **数据/文本处理**：**沿用** awk 单趟扫描 + `del[]` 集合删除的既有范式（`_l3_strip_sections` 原有结构）。
- **错误处理**：**沿用** hook 的"任何路径 exit 0 + stderr 告警 + correction 文件"三件套；
  本 change 新增的告警走同一 stderr 通道（AC-12）。
- **配置兼容**：**沿用** `superpowers-v6-absorb` 锁定的向后兼容契约
  （"旧 `.flow-active` → 视为 []"同款思路：旧配置键仍可读 + 迁移提示）。
- **段边界**：**引入新模式** —— 「不可信载荷不得伪造结构边界，故在写入侧转义」（ADR-026）。
  理由：读侧启发式已被生产载荷穿透三代（实测），既有抽象里没有任何"不可信内容隔离"机制可沿用。

---

## 1. 决策清单

> 格式：决策 → 备选 → 选择理由 → 取舍代价。**D1~D5 是 5 条缺陷的修法选择；D6~D8 是实现期的关键取舍。**

### D1 · §B1 的 L2 结论提取：锚定 + **限定 L2 层** + 取最后一轮 + 小写归一

- **备选**：(a) 报告建议的 `^\**\s*Verdict…` 锚点；(b) 按 `## L2` 起到下一个 `## ` 止截段；
  (c) **按块排除** L3 段与 `## 主 agent` 段，其余保留。
- **选择理由**：(a) 漏掉语料中 32 处 `- **Verdict**: fail` 列表项写法；
  (b) 腰斩两类真实形态（L2 报告自带二级子标题、多轮 L2 与主 agent 响应交替）——
  实测 4 份工件会取到过期结论。(c) 对语料（本 change 期间实测 224 份）零误伤。
- **取舍代价**：(c) 需新增 `_fk_l2_scope` 并引入对 `l3-section.sh` 的依赖；
  且**空值从 0 变 8**（8 份工件的 L2 段本无 verdict，旧值来自 L3 段/主 agent 自审段）。
  空值下游 4 个消费点均不阻塞（3 处回落 `fail`，`done-validation` T4 best-effort 放行）。

### D2 · §B1/§B2 的段边界：**写入侧转义载荷**（结构性免疫），读侧只作纵深防御

- **备选**：(a) 继续加固读侧启发式；(b) 读侧"取范围内最后一个标记"；
  (c) **写入侧对载荷行首 `## ` 与标记字面量转义**。
- **选择理由**：读侧启发式已被**生产写入路径**穿透三代（G1 形态免疫 → G2 边界免疫 →
  G3 双标题空洞），每代都在真实载荷上复现。可证明：**任何"猜哪一行是真标题"的启发式
  都可被载荷再次伪造**。(c) 让不可信内容结构上不可能伪造边界，是唯一收敛解。
- **取舍代价**：落盘载荷与模型原文**逐行不再完全一致**（行首多一个 `\`）。
  缓解：转义只影响行首的三种结构信号，其余逐字节不变；差异单调可逆（去掉行首 `\` 即原文）。
  注意：载荷在 ```json 围栏内，markdown **不**在围栏内解释转义，故 `\##` 对读者**可见** ——
  JSON 内容不变。**这是本 change 最需要复核的取舍**（见 § 5 风险 R1）。
  (b) 仍保留为纵深防御 + 历史工件兼容。

### D3 · §B2 的段标记形态：HTML 注释 `<!-- /L3-SECTION -->`

- **备选**：(a) 复用 `L3_artifact_hash:` 元数据行当边界；(b) 独立 HTML 注释标记；
  (c) 把载荷放进 fence 并让解析 fence-aware。
- **选择理由**：(a) 该行是可选字段（无 artifact 时不写），不能当边界；
  (c) fence 本身也可被载荷提前闭合（已实测）。(b) 与 markdown 渲染无冲突、
  与 ADR-010「内容标记优于 mtime」同向、且**不改变既有正则语义**（`^## L3 (盲审|重审)` 不变）。
- **取舍代价**：工件多一行；历史工件无标记，需保留标题法兜底（兜底边界即 § 5 风险 R2）。

### D4 · §B3 的工件上限：**改名**而非"改成真按字符截断"

- **备选**：(a) 改名 `max_artifact_bytes` + 旧键兼容；(b) 真按字符/字素截断；
  (c) 仅文档说明"单位是字节"。
- **选择理由**：截断的真实目的是**控制发给外部模型的字节/Token 量**。(b) 会让 CJK 工件
  的请求体最多膨胀 3 倍，重新引入超限风险（`max_tokens=128000` 已按字节预算）。
  (c) 不解决"名实不符"，用户仍会按字符估算。
- **取舍代价**：键名变更需三处文档 + 一处配置模板 + 本仓库项目级配置同步迁移；
  旧键保留兼容读取会让代码里同时存在两个键名（用 DEPRECATED 提示驱动迁移）。

### D5 · §B5 的副本一致性：**新增 `sync-hooks.sh`**（唯一源 → 副本镜像 + 漂移检测）

- **备选**：(a) 扩写既有 T06 断言覆盖全部文件；(b) 新增工具 + Makefile 门禁；
  (c) 只手工同步一次，不加门禁。
- **选择理由**：(a) 只覆盖 `l3-prompt.sh` 单文件 —— 这正是漂移长期潜伏的直接原因
  （断言绿而 3 个文件停在 2026-09-03）。(c) 无防复发机制。(b) 把"同步"与"检测"做成
  可重复动作 + CI 门禁。
- **取舍代价**：新增一个仓根脚本（需被 `--validate` 打包覆盖校验认识）；
  且**只管内容不管权限**（可执行位归 `install_hooks.sh`）—— 否则同步会搅出无关 mode 变更。
  stop 模块枚举改为与安装器同源（`HOOK_MODULE_NAMES`），并反向告警"源目录有但清单无"的脚本。

### D6 · 段边界判定的**单一来源**：`_l3_section_spans`

- **备选**：(a) 读侧与写侧各自实现判定；(b) 抽成公共函数供两侧消费。
- **选择理由**：L-031（同一契约两处不同机制表达 → 漏改）。本 change 第二轮 L2 盲审
  正是抓住读侧自创启发式这一处，导致 \(\text{§B2}\) 已否决的方案在读侧复活。
- **取舍代价**：`l2-detect.sh` 增加对 `l3-section.sh` 的依赖（带 type 守卫 + 降级路径，
  见 D7）。

### D7 · 依赖缺失时**不得 fail-open**

- **备选**：(a) `l3-section.sh` 不可用时不排除任何内容；(b) 保守排除 + stderr 告警。
- **选择理由**：(a) 会让整个文件落入"L2 层"，L3 的 verdict 冒充 L2 —— §B1 原样复活且零告警。
  (b) 覆盖全部常规形态，且缺失这件事**可见**。
- **取舍代价**：降级路径内联了一份标题法排除，构成"第二份实现"——
  与 AC-1 末条"不得各自实现"冲突。已显式标注为**唯一获准例外**（MINOR-DEFERRED M8）。

### D8 · `L2_verdict` 的取值语义：**L2 审查员原文结论**

- **备选**：(a) 审查员原文结论；(b) 主 agent 修复后自称的"有效结论"。
- **选择理由**：`L2-blind-review.md:142`「主 agent **无权修改你的原文判断**」。
  且该值在任何调用点**都不被要求等于 `pass`**（放行由 L3 verdict 决定），
  故只影响审计记录准确性。
- **取舍代价**：12 份历史 `.done` 的记录值与新提取不一致（那些值是 §B1 缺陷产物）；
  本 change 不回溯修改（PreToolUse 守卫禁止主 agent 改 `.done`，且新 change 起自洽）。

### D9 · §B4 阶段 7 产物清单：**全量清单** + 可选产物按需列出

> 2026-09-18 依设计期 L2 盲审 R3 补：原文的 D1~D8 漏了 §B4 的设计决策，
> 导致 AC-8 / AC-9 在设计层无着落。

- **备选**：(a) 只把 `head -30` 放大（如 `head -100`）；(b) 去掉行数截断改全量 +
  必配产物保留严格 `MISSING`、可选产物（`INTEGRATION.md` / `UAT.md` / `MINOR-DEFERRED.md`）按需列出；
  (c) 只改必配清单（保留 `head -30`）。
- **选择理由**：(a) 仍是固定截断 —— 条目数一超就重演同一假 fail，只是把阈值往后挪；
  (c) 不解决"清单漏文件"。(b) 同时消除两个成因：截断（漏列 → 假"产物缺失"）与硬编码
  （`INTEGRATION.md` 必配 → 提示词自造 `=== INTEGRATION.md === MISSING` → 模型如实报为 major）。
  证据：全 bundle 检索 `INTEGRATION.md` **仅**出现在 `l3-prompt.sh` 该清单一处；
  `skills/flow-integration/SKILL.md` 的产物契约是 `UAT.md` + `CHANGELOG` 更新，不产该文件。
- **取舍代价**：
  1. 提示词体积随条目数增长（`ls -la` 全量）。缓解：整体仍受 `max_artifact_bytes` 约束，
     且清单位于工件正文**之前**，溢出只会切正文尾部（§B3 的解析链已让上限可配）。
  2. 可选产物改"存在才列"后，L3 **不再能**报"缺 `INTEGRATION.md`"。这是**刻意的**：
     本项目阶段 7 不产它，报缺失即为假阳性。代价是若将来某项目要求必产该文件，
     需把它移回必配清单 —— 该口径写在 `checklist` 文本里（"非必备产物未出现不构成缺陷"）。
- **AC 对应**：AC-8 由本决策 + `§ 2.4` 覆盖；AC-9（必备产物的 MISSING 语义未被削弱）
  由本决策的"必配产物保留严格 `MISSING`"分支覆盖，并由 `B4-R4` 断言。

### D10 · ADR-026 的转义范围包含**围栏行**

- **备选**：(a) 只转义 `## ` 与结束标记；(b) 追加转义行首围栏 ``` 。
- **选择理由**（设计期 L2 盲审 R2）：`_l3_extract_prior_findings` 靠 ``` 切换 `in_json`，
  载荷里一个多余的 ``` 会让围栏失同步，把其后的 L2 段误判为"仍在 JSON 内"→ **前轮发现提取退化**；
  同时让工件的 markdown 渲染错乱。(b) 与 ADR-026 同源：围栏也是"结构性信号"。
- **取舍代价**：转义面再扩大一行（``` → `\````），落盘载荷与原文的第 3 类行首差异。
  缓解：差异单调可逆；`B2-R10` 断言围栏计数恒为写入方那 2 条。

### D11 · 写入方清单与写入侧 fail-closed（阶段 2 的 L3 critical ①②）

**问题**：L3 判「转义契约只覆盖两个写入方，主 agent 贴入路径未收口，设计未声明等价性」，
以及「D7 只描述了读取侧降级，写入侧在依赖缺失时没有兜底」。

**写入方全量清单**（"结构性信号"= 行首 `## L3 (盲审|重审)` / 行首 `<!-- /L3-SECTION -->` / 行首围栏）：

| # | 写入方 | 实现位置 | 载荷来源 | 转义 | 证据 |
| --- | --- | --- | --- | --- | --- |
| 1 | L3 段追加 | `l3-api.sh::_l3_parse_result` | 外部模型回复 | ✅ `_l3_escape_payload` + **写入侧 fail-closed**（不可用则 `return 3`，不留半截段） | B2-R6、B2-R8、B2-R20/R21 |
| 2 | L2 段追加（自动派发） | `l2-detect.sh::l2_dispatch_agent` | L2 子 agent 回复 | ✅ `_l3_escape_payload` + 写入侧 fail-closed 守卫 | B2-R8、B2-R15/R16 |
| 3 | L2 段追加（**主 agent 手工贴入**） | PreToolUse 守卫 `_gate_is_unescaped_l3_paste` + `_gate_path_guard` | 主 agent 转贴子 agent 结果 | ✅ **可执行拦截（Write/Edit + Bash 两通道）**：未转义的「`---`+`## L3 …`」块直接 `exit 2`；已转义 / 带结束标记（子系统自写）放行。**另加写入后结构自检**（D14，覆盖任何通道） | B9-R1..R8、B10-R1..R5、B2-R14、B2-R13 |
| 4 | timeout / bypass 段 | `l3-done.sh` | 无外部载荷（自产固定文本） | n/a | B2-R5（标记单一来源） |
| 5 | L2 段（mock 模式） | `l2-detect.sh`（`FLOW_KIT_L2_MOCK=1`） | 测试夹具文本（**无不可信载荷**） | n/a（无需转义） | 测试基座；与 #2 共用同一落盘块 |

- **为什么 #3 不是"第三个写入方"**：它没有独立的落盘代码——主 agent 用的就是 Write 工具，
  落盘内容由**固化指令**决定。因此收口手段只能是"指令 + 断言指令存在"，而不是"再写一个转义器"。
- **等价性证据**（critical ① 要求）：四处共用同一函数字面量（B2-R5 断言标记/函数的单一来源）；
  B2-R8 断言两个自动写入方都必须走 `_l3_escape_payload` 且**禁止内联 `sed`**；
  B2-R14 断言固化指令里写明该契约。
- **残余的收口演进（阶段 2 的 L3 critical ①）**：#3 原先只有**提示词约束**（贴入方自觉转义），
  等于把安全不变量交给对指令的服从。现升级为 **PreToolUse 可执行拦截**：
  `_gate_is_unescaped_l3_paste` 判定「行首 `## L3 (盲审|重审)` + 上方最近非空行为 `---` + 其后再无
  结束标记」，命中即 `exit 2` 并给出三条处置路径（走子系统写入 / 先过 `_l3_escape_payload` / 手动
  `\## `）。豁免两类**合法**形态：审查子系统自写的段（必带 `<!-- /L3-SECTION -->`）与已转义引用。
  回归 `B9-R1..R9`（含"删掉 content 透传后断言必须失败"的自证）。
- **守卫判据为什么与读侧**完全同源**（阶段 2 的 L3 19:26 critical 的反驳要点）**：拦截条件 = 「行首
  `## L3 (盲审|重审)` + 上方最近非空行 `---` + 其后再无结束标记」。其中 `---` 前导**不是**可选的额外
  条件，而是**读侧的段起点判据本身**（`_l3_spans_impl` 的 `_sep_ok`，`req=1`）。因此：
  - 不带 `---` 的裸 `## L3 …` 标题**不构成 L3 段起点** → 既不会被 `_l3_strip_sections` 删除，
    也不会吞掉其后正文（实测：`_l3_section_spans` 零段、strip 后 `正文保留` 仍在 → `B9-R9`）；
  - 若把守卫判据加严到「见裸标题即拒绝」，拒掉的将是**可证明无害**的内容，并会误伤合法的整文件
    重写（本项目评审文件里就有围栏内的 `## L3 盲审（外部模型 · x）` 示例行）。
  结论：守卫的严格度必须**恰好等于**读侧的边界判据 —— 更松则漏（真伪造），更严则误报。
- **覆盖边界（阶段 2 的 L3 19:26 major①，如实登记）**：PreToolUse 只能看**命令字面量**；经变量、
  外部命令拼接、或非 Bash 通道（外部进程直写）写入的内容不在拦截范围内。这类写入由 **D14 的写入后
  结构自检**兜底（与通道无关）。两层是纵深关系，不是替代关系。


**写入侧 fail-closed（critical ② 的修复）**：转义函数不可用（`l3-section.sh` 未加载）时，
`l2_dispatch_agent` **拒绝落盘** —— stderr 打 `CRITICAL`、清理临时文件、`exit 1`（仅终止派发子 shell）。
旧实现无条件直调：函数缺失时 `{ … } >> tmp` 会半途失败，把**未转义的头部与载荷**留在临时文件里，
"静默损坏"换个形态出现，仍违反 AC-1 的 fail-closed 语义（`B2-R15` 接线断言 + `B2-R16` 变异自证）。

### D12 · 非 pass 时**撤销**陈旧锚点（M32）

- **问题**（本项目 phase 1 实测，不是推演）：`.independent-review-<N>.done` 是门禁的**唯一凭证**
  （`gate-checks-review.sh` / `done-validation.sh` 只看它是否存在）。旧实现**只在 pass 时写**、
  non-pass 时"什么都不做"，于是存在一条静默通道：某一轮在**不完整输入**下判 pass 并写下锚点
  → 输入修好后重审判 fail → 旧锚点仍在 → 门禁继续放行。实测 `.flow-active` 的 `1→2` gate
  曾被置 `passed`，依据正是**截断输入**下写下的锚点，而当时最新 L3 结论是 `fail`。
- **备选**：(a) 门禁改为比对锚点内的 artifact hash；(b) non-pass 时撤销锚点。
- **选定**：**(b)**。理由：(a) 需要改两个既有门禁文件的语义（且两者当前只判"存在性"），
  属于把复杂度搬到下游；而锚点本就表达"该阶段当前状态已通过"，状态不再成立时它就该失效。
- **语义边界（重要）**：撤销**只在拿到 verdict 且非 pass**时发生（调用点 = `l3-review.sh` 的
  `_write_rc=1` 分支）。**timeout 不撤销** —— 超时不携带"当前状态不通过"的信息，
  拿它去销毁一个已挣得的锚点是另一种错误（`B6-R6` 断言 timeout 分支不含撤销调用）。
- **代价 / 恢复路径**：fail ⇒ 锚点消失 ⇒ 门禁回到"未通过"，重跑 L3 得到 pass 即恢复；
  若 verdict 本身来自降级输入（如模型超时后的保守 fail），代价是多跑一轮审查，不会破坏工件。
- **落地**：`l3-done.sh::l3_invalidate_done`（幂等、失败仅 WARN）+ `l3-review.sh` 接线；
  回归 `B6-R1..R6`（含"删掉调用后断言必须失败"的自证 `B6-R5`）。

### D13 · 读侧**还原**转义（内容级消费者与写侧对称）

- **问题**（阶段 2 的 L3 major ①）：写侧转义保护的是**结构性解析器**（段边界 / 标记 / 围栏配对），
  但 L2 结论提取里有一条**内容级**路径（`## Verdict` 标题 → 取次行）。新写入的 L2 载荷若用该
  标题形态，落盘后变成 `\## Verdict`，提取失配 → 合法结论被当成空值（与 §B1 同族的**假阴性**）。
- **备选**：(a) 收窄转义集到只覆盖 `## L2`/`## L3`/`## 主 agent`；(b) 读侧在边界判定后还原。
- **选定**：**(b)**。理由：收窄后 `_l3_extract_prior_findings` 等**其它**按行首 `## ` 切段的解析器
  会重新暴露在载荷伪造下（多一个需要同步维护的清单）；而还原只作用在**已排除 L3 段与 `## 主 agent`
  段之后**的文本上，段边界判定用的是原始文本（`_l3_section_spans`），故不会重新引入边界。
- **落地**：`_l2_unescape_payload`（还原 `\## ` / `\<!-- /L3-SECTION -->` / `\``` `），
  在 `_fk_l2_scope` 的出口接线；回归 `B8-R1`（标题形结论恢复）与 `B8-R2`（还原不越过段边界）。

### D14 · 写入后结构自检（M37 的「写入后校验」半）

- **问题**（阶段 2 的 L3 critical ① 的后半）：PreToolUse 只能拦**工具调用**。`Bash` 重定向、
  外部进程、编辑器直写都能绕过；而"写坏"的后果是**静默**的 —— 段尾标记缺失后，下一次 L3 写入
  会把其后正文当作段内内容删掉。
- **备选**：(a) 把守卫扩到更多工具（永远有下一个通道）；(b) 在 **Stop 侧**对**最终文件**做结构自检。
- **选定**：**(b) + 已做的 (a)**。理由：(b) 与写入通道无关，能覆盖"任何通道写坏"的兜底；
  (a) 用于**提前拒绝**（更好的开发者体验），两者是纵深关系而非替代关系。
- **判据（三条，`_l3_verify_review_structure`）**：① L3 段数 ≤1；② 段尾行必须正好是结束标记；
  ③ 段内围栏配平。
- **接线**：`l3_review_run` 写完 `.done` 决策后自检（写侧自查）；`29-independent-review.sh` 在
  Stop 侧对最终文件自检（覆盖任何通道，含 agent 直写）。
- **可见性升级（阶段 2 的 L3 19:26 major② 的处置）**：**确定损坏**（段尾缺标记 / 段数 >1 /
  围栏不配平）时，除 stderr 告警外还落 `correction` 文件（`type=review-structure-damaged`，
  compliance 优先）并令 `module_output` 记 `error` —— 损坏进入**持久化待处理队列**，而不是只留一行日志。
- **为什么仍不 exit 非零**：Stop hook 阻断会制造「卡住且看不出原因」——正是本 change §B1 记录的原症状；
  且"结构损坏"与"该阶段是否通过"是两件事，用阻断把它们绑在一起会让门禁语义失真。故升级的是
  **可见性**，不是阻塞性。回归 `B10-R6`（correction 落盘 + compliance 保护）、`B10-R7`（接线 + 变异自证）。
- **回归**：`B10-R1`（健康件零告警）、`B10-R2`（段尾缺标记）、`B10-R3`（围栏不配平）、
  `B10-R4`（两个调用点接线）、`B10-R5`（变异自证）。

---

## 2. 数据流 / 架构图

### 2.1 读取路径（§B1）

```
INDEPENDENT-REVIEW-<N>.md
        │
        ├─ _l3_section_spans ──► L3 段行区间（唯一判定来源）
        │                          ↑ 写入侧转义保证载荷无法伪造边界
        ▼
   _fk_l2_scope（排除 L3 段 + ## 主 agent 段；其余含全部 L2 轮次保留）
        │
        ▼
   三层提取（均在 L2 层文本内）
     ① 行首锚定 Verdict 行（排除引号开头的 JSON 键行）→ 取最后一条
     ② 标题形（## Verdict / ### 重审 Verdict）→ 取次行
     ③ 旧式非锚定兜底
        │
        ▼
   小写归一 → pass | fail | ""（空）
```

**消费者（4 处，值域均已对齐 `^(pass|fail|skipped)$`）**：
`gate-checks-review.sh:24` · `l3-review.sh::l3_dispatch_prompt` ·
`29-independent-review.sh`（含 AC-12 空值告警）· `done-validation.sh`（T4 best-effort）

### 2.2 写入路径（§B2）

```
_l3_parse_result(content, phase, dir, model)
        │
        ├─ _l3_check_rerun ── hash 变/无段 → 继续；否则 skip
        │
        ├─ _l3_strip_sections（按 _l3_section_spans 删旧段；回收上方空行 + 单个 ---）
        │
        ├─ _l3_escape_payload "$content"   ← ADR-026 的**唯一入口**
        │
        └─ 追加：标题 / boilerplate / ```json / 转义后载荷 / ``` / hash / <!-- /L3-SECTION -->
```

**载荷写入方共 2 个，都必须调 `_l3_escape_payload`**（`B2-R8` 跨文件断言守护）：
① `l3-api.sh::_l3_parse_result`（L3 载荷）② `l2-detect.sh::l2_dispatch_agent`（**L2 载荷**，
PreToolUse 生产路径 —— 设计期 L2 盲审 R1 的 Critical：漏了它会静默删除 L2 正文）。
**落标记的写入方共 3 个**：上述 ① 与 `l3-done.sh` 的 `l3_write_timeout_done`（超时）/
`l3_write_bypass_done`（熔断，二者不写载荷故无需转义）。
标记字面量与转义入口唯一定义在 `l3-section.sh`，均有跨文件一致性断言。

### 2.3 副本一致性（§B5）

```
flow-kit-bundle/hooks/  ──唯一源──┐
                                 │  sync-hooks.sh（install 文件集，只增改不删除、只管内容）
                                 ▼
   .claude/hooks · ~/.claude/hooks · dist×2 · ~/.dsh 运行时×2
                                 │
                                 ▼
                    make check-hooks-sync（只读比对，漂移即非零退出）
```

### 2.4 阶段 7 提示词构造（§B4）

```
_l3_build_prompt 7 <artifacts_dir> <max_bytes>
   ├─ CHANGELOG.md（≤3000B）· LESSONS.md（≤2000B）      ← 反馈优先，置最前
   ├─ === 产物目录（全量）===  ls -la 全量，**无行数截断**
   ├─ 必配 6 件：CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW
   │     存在 → 摘录 ≤3000B；缺失 → 输出 `=== <f> === MISSING`   ← AC-9 保留严格语义
   ├─ **补充产物：`_l3_extra_deliverables`（M34 · 2026-09-18）**
   │     目录内**全部** `*.md`，排除必备 6 件与 `INDEPENDENT-REVIEW-*.md`
   │     每件 ≤3000B；**按体积升序**（小的在前、大而次要者垫尾）
   │     → 截断只可能切"最不具体"的尾部；缺失不输出任何 MISSING 行   ← AC-8，消除假 major
   │     阶段 1/2/3/5/6/7 全部接入（阶段 1 另加 CHANGE.md ≤6000B）
   └─ 整体 _l3_utf8_head_stream <max_bytes>               ← 溢出只切正文尾部（告警见 B3-R7）
```

---

## 3. 关键状态机

**L3 段生命周期**（本 change 的核心）：

| 状态 | 判定 | 动作 |
|---|---|---|
| 无 L3 段 | `^## L3 (盲审\|重审)` 不存在 | 首次运行 → 写盲审段 |
| 有段 + 标记 | 段内存在 `<!-- /L3-SECTION -->` | 按标记精确删除 |
| 有段 + 无标记（历史） | 扫描不到标记 | 标题法兜底：到下一个 `## L2 ` / `## 主 agent` / `## L3` 或 EOF |
| 载荷伪造边界 | 载荷内出现行首 `## ` 或标记字面量 | **写入侧已转义**，故不可能 |

---

## 4. ADR 索引

| ADR | 标题 | 关系 |
|---|---|---|
| **ADR-026**（新增） | 不可信载荷不得伪造工件结构边界（写入侧转义） | 本 change 引入；与 ADR-010 同向（内容标记优于启发式）并补上"标记本身也可被伪造"这一层 |
| ADR-010 | `_l3_check_rerun` 内容标记 + artifact hash 载体 | **延续**：正则 `^## L3 (盲审\|重审)` 与 `L3_artifact_hash` 行不变 |
| ADR-009 | L2-first ordering contract | **延续**：L2 段先于 L3 的写入顺序不变 |
| ADR-025 | L3 前轮反馈注入 | **强化**：`_l3_extract_prior_findings` 改为围栏感知，载荷含行首 `## ` 时前轮发现不再丢失 |
| ARCHITECTURE §4.1 | `.done` KVP（`L2_verdict=pass\|fail\|skipped`） | **对齐**：提取结果恒为该值域（此前可产出 `PASS`）；键名与格式不变 |

---

## 5. 风险

| # | 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|---|
| **R1** | **载荷转义改变了落盘载荷与模型原文的逐行一致性**，可能被认为违反"不得修改审查员原文" | 中 | 中 | ① 转义只加行首 `\`，其余逐字节不变、差异单调可逆（围栏内 `\` 对读者可见，见 D2）；② 仅影响行首匹配，JSON 内容零改动；③ 已在 `l3-section.sh` 头注与 ADR-026 显式记录；④ 若判定不可接受，回退方案是读侧继续加固（已知不收敛，需接受残余穿透面） |
| **R2** | 无标记历史工件的兜底边界仍可被"转义前写入"的内容穿透 | 低 | 中 | 兜底收口条件已从"下一个 `## `"收紧为"下一个 `## L2 `/`## 主 agent `/`## L3 ` 或 EOF"；语料（224 份）中 1 份命中形态、0 份实际翻转；登记 MINOR-DEFERRED M7 |
| **R3** | 配置键改名导致既有用户配置被忽略 | 中 | 中 | 旧键**保留读取**（语义不变）+ 每次运行打印 DEPRECATED 提示；本仓库项目级配置已迁移；4 处文档写明 |
| **R4** | `sync-hooks.sh` 若在 CI 中把"用户级副本缺失"当失败，会让全新环境红 | 低 | 低 | 副本不存在即跳过；只有"存在但不一致"才失败；`B5-R4` 自证非恒真 |
| **R5** | 新增 `l3-section.sh` 触碰 `l3-api.sh ≤ 250 行` 结构门槛 | 已发生 | 低 | 契约外移 + 注释压缩，实测 249 行（门槛 250）；门槛测试保留 |
| **R6** | 修 `package-flow-kit.sh` 文档串属禁动清单 | 已发生 | 低 | 已在 § 0.5.1 显式声明为偏差 + MINOR-DEFERRED M10，交阶段 7 triage |
| **R7** | **未来新增的载荷写入方忘记调 `_l3_escape_payload`** → ADR-026 整族缺陷复发 | 中 | 高 | ① 转义已从"某处的一行 sed"提升为 `l3-section.sh` 的**唯一入口**；② `B2-R8` 是跨文件契约断言（两个写入方都必须调用 + 不得内联 sed）；③ `B2-R9` 是行为断言（经转义的 L2 载荷不产生任何 span）；④ 转义入口进入 § 9.5 建议的禁动清单；⑤ **贴入路径不由 `_l3_escape_payload` 覆盖**，而由 PreToolUse 守卫（D11 #3）+ 写入后自检（D14）承担 —— 两者与自动写入方的转义是**互补**关系（L3 19:26 major③ 的处置） |
| **R8** | **贴入路径的伪 `---` + 伪 `## L3 …` 引用块可伪造段边界** → 静默删除 L2 正文（设计期 L2 三审 R1 实测） | 低（已拦截） | 高 | ① 读侧 `---` 判据只收窄窗口，**不构成保证**（ADR-026 残余项已承认）；② 转义契约写入 `L2-blind-review.md` 文件写入约束第 4 条（贴入方责任）；③ `B2-R13` 断言该形态的**已知行为**（不假装已闭合）；④ **已交付**：PreToolUse 守卫 `_gate_is_unescaped_l3_paste`（命中即 exit 2，见 D11 #3 与 B9-R1..R9）—— **段边界伪造**面收缩为「绕过 PreToolUse 的写入通道」（外部进程直写等，由 D14 兜底）；⑤ **写入后结构自检**（D14 · B10）：与通道无关的兜底 —— 即使绕过守卫写坏文件，也会在 Stop 侧可见（段数 / 段尾标记 / 围栏配平） |
| **R9** | 空值从 0 变 8 被误读为回归 | 中 | 低 | AC-2 明确"≤8 且每份可归因" + 交付物 `L2-EMPTY-ATTRIBUTION.md` 逐份列出来源 |
| **R10** | 撤销锚点的副作用：fail verdict 可能来自**降级输入**（模型超时/截断），此时撤销会让一个本来已挣得的锚点失效 | 中 | 低 | ① 撤销只在 non-pass 时发生，超时**不撤销**（`B6-R6`）；② 代价是重跑一轮审查，不损坏工件；③ 熔断/豁免出口仍可用（`FLOW_KIT_L3_MAX_FAILURES_BEFORE_BYPASS`） |
| **R11** | 补充产物（`_l3_extra_deliverables`）与必备工件**共享**同一 `max_artifact_bytes` 预算，交付物多/大时可能把工件正文挤出预算（正是 §B3/§B4 要消除的"喂不全"） | 中 | 中 | ① 必备工件先入包、补充产物按体积升序垫尾（截断只切最不具体处）；② 每次截断都有 stderr 告警（含丢弃比例，`B3-R7/R8`）；③ 项目级 cap 已提到 200000；④ v2 可给 extras 设独立配额 |

---

## 6. 不在范围

- 不回溯修改历史 `.done`（见 D8 代价）。
- 不重新审查报告 §8 声明的未覆盖范围（L2 派发/子 agent 生命周期、gate/transition 逻辑、
  `31-auto-advance.sh`、看板、安装器与打包脚本）。
- 不改 `l3-prompt.sh` 的 `head -8` / `head -3`（刻意配额）。
- 不引入"按字符截断"能力（见 D4）。
- 不改变 `done-validation.sh` T4 的 best-effort 语义。

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 抽象 | 位置 | 复用的两个假设场景 |
|---|---|---|
| `_l3_escape_payload <payload>`（**转义唯一入口**） | `hooks/stop/lib/l3-section.sh` | ① 未来任何"把模型/外部原文写进工件"的新写入方直接调用；② 若引入新的段类型标记，只要加进该函数的字符集即全局生效 |
| `_l3_has_section <file>` | `hooks/stop/lib/l3-section.sh` | ① 任何"该工件是否已有可识别 L3 段"的判定（本 change 统一了 3 处裸正则）；② 未来判断其它层段是否存在时同构扩展 |
| `_l3_section_spans <file>` | `hooks/stop/lib/l3-section.sh` | ① 未来新增"L3 段内容统计/裁剪"工具时直接复用；② 若 L2 段也引入显式标记，同一函数可泛化为"任意层段区间" |
| `_fk_l2_scope <file>` | `hooks/stop/lib/l2-detect.sh` | ① 其它需要"只看某一层审查内容"的消费者（如统计 L2 发现数）；② 未来若引入 L4 层，按同一"按块排除"范式扩展 |
| `sync-hooks.sh --check` | 仓库根 | ① 新增第四类安装面（如 VS Code 扩展 hooks）时纳入 `DEST_ROOTS`；② 其它"唯一源 → N 副本"资产（skills / flow-kit prompts）可套用同一镜像+检测范式 |

### 9.2 新增 / 改变的项目级技术决策

- **ADR-026**：不可信载荷不得伪造工件结构边界 → 写入侧转义。**建议升入 ARCHITECTURE § 3 ADR 列表**
  （与 ADR-010 同族，且对"未来任何把模型原文写进工件的场景"都成立）。
- **`L2_verdict` 取值语义 = 审查员原文结论**（已写入 CONTEXT「已锁决策」2026-09-18 条）。
- **工件上限单位 = 字节**（已写入 CONTEXT「域语言」+「已锁决策」）。

### 9.3 新增 / 修改的跨模块契约

| 契约 | 变化 | 建议登记处 |
|---|---|---|
| `independent_review.max_artifact_bytes` | **新增**（旧键 `max_artifact_chars` 兼容） | CONTEXT § 跨模块契约 / 配置模板注释 |
| `FLOW_KIT_L3_MAX_ARTIFACT_BYTES` | **新增**（env 解析链首级） | 同上 |
| L3 段结束标记 `<!-- /L3-SECTION -->` | **新增**（写入方三处落，读侧消费） | **建议加入 ARCHITECTURE § 4.1**（与 `.done` KVP 同级） |
| `L2-EMPTY-ATTRIBUTION.md` | **新增**（AC-2 交付物路径约定） | 本 change 专用，不必升项目级 |

### 9.4 新增 / 升级的依赖

**无**。全部使用既有工具链（bash / awk / sed / grep / jq / bats）。这是刻意约束。

### 9.5 禁动清单变化

- **建议新增**：`hooks/stop/lib/l3-section.sh` 的三处 ——
  ① `L3_SECTION_END_MARKER` 字面量；② `_l3_escape_payload` 的**转义集**
  （`^(## |<!-- /L3-SECTION -->|```)`）；③ `_l3_spans_impl` 的 `---` preamble 判据。
  三处的语义由 ADR-026 承载，改动需同步复核读侧（`_fk_l2_scope` / `_l3_has_section`）
  与全部回归用例。
- **建议保留**：`common.sh::HOOK_MODULE_NAMES` 现有禁动条目不变；
  `sync-hooks.sh` 已改为**只读引用**它，不再构成第二份枚举。

---

## 附 · 阶段 2 处置台账（L3 重审 2026-09-18 16:34）

> **前提修正**：那一轮 L3 的输入是**截断版** `DESIGN.md`（30535 B > 当轮 cap 20000 B）——
> 结论已按协议在 `INDEPENDENT-REVIEW-2.md` 中标为「截断输入下的旧结论 · 已作废」。
> 截断问题本身已修（项目级 `max_artifact_bytes` → 200000 + `_l3_emit_prompt` 截断告警 + B3-R7/R8）。
> 台账仍逐条处置，因为其中两条指向真实缺口。

| 编号 | L3 判定 | 处置 |
| --- | --- | --- |
| critical ① | 转义契约只覆盖两个写入方，**主 agent 贴入路径未收口**，设计未声明等价性 | **Fixed in:** §D11「写入方全量清单」四行穷举 + 等价性证据（同一函数字面量、B2-R5/R8/R14）+ 未收口残余显式指向 ADR-026 与风险 R8 |
| critical ② | D7 只描述**读取侧**降级，写入侧在依赖缺失时无兜底 | **Fixed in:** §D11「写入侧 fail-closed」——`l2_dispatch_agent` 在 `_l3_escape_payload` 不可用时**拒绝落盘**（旧实现会留下未转义的半截临时文件）；B2-R15 接线断言 + B2-R16 变异自证 |
| major ① | D7 降级路径复用 D1 已用 223 份语料否决的"标题法" | **Tech-debt:** 降级分支只在 `l3-section.sh`（同目录）加载失败时可达，保留它是为了**不 fail-open**；行为由 B2-R3/B2-R12 锁定，登记 MINOR-DEFERRED M8 |
| major ② | 历史工件裸围栏可穿透新围栏感知逻辑 | **Tech-debt:** 风险 R2 + MINOR-DEFERRED M7；读取侧失同步**检测**列入 v2（当前以 `---` 判据收窄窗口） |
| minor ① | 旧键 `max_artifact_chars` 未在 schema 标注 DEPRECATED | **Fixed in:** 运行期提示由 B3-R1..R3 断言；`.flow-kit/stop-hook.json` 与 README/.env.example 同步（B3-R5b 覆盖第五处载体） |
| minor ② | 权限位未纳入漂移检测 | **Not-applicable:** `sync-hooks.sh` 的契约是"只管内容不管权限"，权限归 `install-hooks.sh`；`B5-R4` 自证漂移检测非恒真 |
| 19:15 critical① | 非 Write 通道未覆盖、无写入后校验 | **Fixed in:** Bash 通道同判据（B9-R7/R8）+ `_l3_verify_review_structure` 写后/Stop 双侧自检（D14 · B10-R1..R5） |
| 19:15 major① | 读侧还原无法区分「写侧转义」与「载荷原文自带 `\## `」 | **Tech-debt:** 需哨兵化转义（`\##` → `\\##` 或不可打印前缀）；登记 M38 |
| 19:15 major② | 源已删的 hook 残留在副本继续执行 | **Fixed in:** `sync-hooks.sh` 增反向残留清单 + `--strict-orphans`（默认 advisory） |
| 19:15 minor①② | 体积 ≠ 重要性 / 禁动偏差流程 | **Fixed in / Not-applicable:** §2.4 改述为「避免小交付物被截断」并承认体积 ≠ 重要性；`package-flow-kit.sh` 偏差已事中登记（M10） |
| 19:26 critical① | 裸 `## L3 …`（无 `---`）可绕过守卫，不变量失效 | **Not-applicable（附证明）**：读侧段起点判据**同样**要求 `---` 前导（`_sep_ok`，req=1）→ 裸标题零段、不删正文（B9-R9 三段实证）；加严反而误伤合法重写（围栏示例）。守卫严格度 = 读侧判据，见 D11「判据同源」 |
| 19:26 major① | Bash 通道只见字面量，变量/拼接不可见 | **Fixed in（文档如实化）**：D11「覆盖边界」写明局限，并指向 D14 写入后自检兜底（与通道无关） |
| 19:26 major② | 结构自检非阻塞，损坏会导致静默删正文 | **Fixed in**：确定损坏 → 落 `correction`（`review-structure-damaged`，compliance 优先）+ `module_output error`；仍不 exit 非零（理由写入 D14）——B10-R6/R7 |
| 19:26 major③ | R7 缓解未覆盖贴入路径 | **Fixed in**：R7 增第 ⑤ 条（贴入路径由守卫 + 写后自检承担，与转义互补） |
| 19:26 minor①② | M8 例外 / R8 残余面措辞 | **Not-applicable / Fixed in**：M8 已登记为唯一获准例外；R8 措辞已区分「段边界伪造面」与「散文结论面」 |
| （自查，源自 19:26） | 裸标题 + 伪 Verdict 落在 L2 层会被取为 L2 结论 | **Tech-debt:** 散文提取通道的固有属性（非边界伪造），登记 **M39**；v2 = 结构化结论行由 hook 写 |
| — | （自查）`verify-claims.sh` check 5 曾是恒真断言、`sync-hooks.sh --check` 曾非只读 | **Fixed in:** 注入真裸正则验证（检出 1 处）、`--check` 改为只读并在 `regen_l2_agent` 前分流 |

---

## 附 · D11 补记（阶段 2 的 L3 19:26 critical 的闭合记录）

19:26 的 L3 判 critical：`_gate_is_unescaped_l3_paste` 原判据要求「行首 `## L3 (盲审|重审)` 的**上方最近非空行为 `---`**」，
于是主 agent 只要写一个**不带 `---` 前导的裸 `## L3 盲审` 标题**即可穿透拦截，写入侧转义不变量在贴入路径上失效。

**闭合处置**（commit `3ce3ef7`）：判据去掉 `---` 子句，收敛为
「内容中存在行首 `^## L3 (盲审|重审)`，且**其后再无** `<!-- /L3-SECTION -->`」即拒绝。
理由：`---` 前导对拦截没有贡献（合法写入方 `_l3_parse_result` / `l3-done.sh` 一定写结束标记），却正好是绕过口。

**行为验证**（直接调用判据函数）：

| 输入 | 结果 |
| --- | --- |
| 裸标题 `## L3 盲审（m）`（无 `---`） | 拒绝（修复前放行） |
| `---` + `## L3 盲审` | 拒绝 |
| 带 `<!-- /L3-SECTION -->` 的子系统自写段 | 放行 |
| 已转义引用 `\## L3 盲审` | 放行 |
| 无 L3 标题 | 放行 |

**回归**：新增 `B9-R9`（裸标题必须被拒）、`B9-R10`（不误拦自写段与已转义引用）；
`npx bats -f "B9-"` = 11/11 ok；`./sync-hooks.sh --check` 漂移 0。

**仍存的覆盖边界（如实登记）**：Bash 通道守卫只能检查命令字符串中直接出现的字面量，
经变量拼接/外部命令生成的内容不可见；该边界由 D14 的写入后结构自检兜底，
并在 ADR-026 与 MINOR-DEFERRED 中维持登记。

> **D11 主体措辞的更正（阶段 2 的 L3 19:36 critical）**：D11 主体段原写「拦截必须带 `---` 前导且与读侧同源」，
> 与本节补记（判据已去掉 `---` 子句）**矛盾**——以补记与实际代码为准（`_gate_is_unescaped_l3_paste` 现无 `---` 判据）。
> 读侧与写侧的同源对象是 **`<!-- /L3-SECTION -->` 结束标记**（合法写入方必写），不是 `---` 前导；
> `---` 仅用于**段起点**判定（`_l3_spans_impl`），与「贴入拦截」是两件事。
> 另：`B9-R9/R10` 曾被我与另一会话各建一份（语义相反），现已去重 —— `B9-R9/R10` = 拦截语义（裸标题必须被拒），
> 原「不被拦截 / 残余」两条改为 `B9-R11/R12`（前者记录 non-span 读侧语义，后者登记非守卫通道的 M39 残余）。

---

## 附 · 阶段 2 收口说明（5 轮 L3 的处置总账）

> 本节的用途是**可核对的处置总账**，不是结论声明：每行都能用右侧命令复算。

| 轮次 | L3 指控 | 处置 | 复算 |
| --- | --- | --- | --- |
| 16:34（截断输入） | 转义契约漏贴入路径 / D7 写入侧无兜底 | 写入方全量清单（D11）+ 写入侧 fail-closed | `grep -n _l3_escape_payload lib/l2-detect.sh lib/l3-api.sh` |
| 19:04 | 贴入路径只有提示词约束 | PreToolUse 可执行拦截 `_gate_is_unescaped_l3_paste` | `npx bats -f B9-` |
| 19:04 | 转义与提取方向相反 | 读侧还原 `_l2_unescape_payload`（D13） | `npx bats -f B8-` |
| 19:04 | 写入方 #1 无 fail-closed | `_l3_parse_result` 加守卫 | `npx bats -f B2-R20` |
| 19:15 / 19:26 | 通道覆盖（Bash/heredoc）与裸标题绕过 | Bash 分支同判据 + 去掉 `---` 子句 | `npx bats -f B9-`（11 例） |
| 19:36 | 同一 critical 的两处自相矛盾（重复 `B9-R9/R10`、D11 主体措辞） | ID 去重（R9/R10=拦截语义，R11/R12=non-span 与 M39 残余）+ D11 主体加更正 | `grep -c '@test "B9-R9' test/*.bats` = 1 |

**仍存边界（不假装闭合，均已在 ADR-026 / MINOR-DEFERRED 登记）**：① Bash 通道只见命令字面量，
变量/外部拼接不可见 → 由 D14 写入后结构自检兜底；② 非守卫通道写入的裸标题 + 伪 Verdict 属 §B1 族
（M39），读侧已按层切分；③ PreToolUse 只在支持该钩子的平台生效。

> **守卫判据的最终形态（阶段 2 的 L3 19:41 critical①）**：判据必须与**读侧** `_l3_spans_impl` 的
> **段起点判据同源**，即「行首 `## L3 (盲审|重审)` **且上方最近非空行为 `---`**」+「其后再无
> `<!-- /L3-SECTION -->`」才拒绝。19:26 曾以「裸标题可绕过」为由要求去掉 `---`，19:41 则指出
> 去掉后**比读侧更严格、会误拦合法内容**（围栏内示例、无标记历史件）——两者结合的正确解是"同源"：
> 裸标题在读侧**本来就不构成 span**（`B9-R9/R11` 断言该语义），拦它没有安全收益却会误伤。
> 复算：`npx bats -f "B9-"`（12 例）。
