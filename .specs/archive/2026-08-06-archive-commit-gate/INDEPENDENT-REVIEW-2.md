# 独立审查 · 阶段 2

> 盲审参数：change-id=archive-commit-gate · 工件=DESIGN.md（参考 ADR-022 / CONTEXT.md / REQUIREMENT.md / CHANGE.md）
> 独立性声明：输入仅含工件文件，无主 agent 自评/草稿注入。判断基于对 flow-kit-bundle/ 的独立 grep 实证。

## L2 盲审

### 🔴 R1 · 00-gate.sh run_module 调度行漏列：34 号模块永远不会被 Stop 链执行

**Severity**：🔴 Critical
**Symptom（症状）**：DESIGN §0.5.1 触碰模块清单（L13-31）——修改列表含 common.sh / install.sh / install_hooks.sh / package-flow-kit.sh，**未列 `hooks/stop/00-gate.sh`**。实证：`00-gate.sh:78-123` 的 `run_module` 调度是**硬编码逐行**（`run_module "${HOOK_BASE_DIR}/33-flow-active-integrity.sh" "flow_active_integrity"` ... `99-report`），不迭代 HOOK_MODULE_NAMES。
**Source（源头）**：L-031 跨文件一致性（第 4 类：DESIGN 漏列且未改 = 🔴）；L-020 三处接线（L2-blind-review.md:82）；AC-3（Stop hook 34 检测）与 AC-4（"注册新 Stop hook 模块 34 到 HOOK_MODULE_NAMES + install_hooks.sh + package-flow-kit.sh + .claude/settings.json Stop 数组 + stop-hook.json modules 开关"）。
**Consequence（后果）**：34 加入 HOOK_MODULE_NAMES 后 install/package 均正常（DESIGN 的 Part D 自动纳入说法属实，`package-flow-kit.sh:99-103` 实证），但 **00-gate.sh 不调度它 → AC-3 兜底检测静默失效**。且 `test_hook_dispatch.bats` L-020 测试只断言 `declared_count >= disk_count` 与 run_module 路径存在性，**测不出调度缺失**——全绿假象下功能全无。另 R4 缓解句「HOOK_MODULE_NAMES 顺序保证（34 > 32，Stop 链按数字升序执行）」依据错误：执行顺序由 00-gate.sh 硬编码序列决定，与数组无关。
**Remedy（修补）**：0.5.1 触碰清单补列 `hooks/stop/00-gate.sh`（在 L123 `run_module ... 99-report` 之前追加 `run_module "${HOOK_BASE_DIR}/34-archive-commit-check.sh" "34-archive-commit-check"`）；补一条 bats 测试断言「HOOK_MODULE_NAMES 每元素在 00-gate.sh 有对应 run_module 行」（反向完整性）；R4 缓解句改为「00-gate.sh run_module 插入位置保证 34 在 33 之后、99 之前」。

### 🔴 R2 · AC-3 单阶段模式检测被 DESIGN 移出 v1：与 REQUIREMENT v1 范围直接冲突

**Severity**：🔴 Critical
**Symptom（症状）**：REQUIREMENT.md AC-3 Given（L85）——"或单阶段（`.flow-active.goal` 为 null 但 `.specs/archive/` 有新归档目录，mtime 在当前会话 active_since 之后）"；REQUIREMENT v1 范围（L188）"AC-3 全实施"。DESIGN D3（L116）"单阶段归档检测需额外标记机制（如目录 mtime），**v2 覆盖**"；DESIGN §5 不在范围（L230）"单阶段模式归档检测（goal=null 时 34 号不触发 · v2）"。
**Source（源头）**：AC-3 验收准则（Given/When/Then 的 Given 含单阶段分支）；REQUIREMENT v1 范围声明；ADR-019 写作原则①（AC 必须确定性）。
**Consequence（后果）**：v1 实施后 AC-3 的「单阶段模式」验收分支无法通过——单阶段用户（goal=null）归档后不 commit 时 34 号不触发，AC-3 判定 fail，toll-gate 无法闭合；或 4-dev 被迫绕过 AC 验收到 v2，遗留假绿。
**Remedy（修补）**：二选一——(a) DESIGN v1 实现单阶段检测（`goal==null` 时用 `.specs/archive/` 最新目录 mtime vs `.flow-active` active_since 比较，AC-3 已给出判定式）；(b) 正式缩小 AC-3 范围（更新 REQUIREMENT AC-3 Given + v1 范围 + 验证方式，经用户确认），并在 DESIGN §5 标注「REQUIREMENT 修订」。禁止保持现状（AC 与 DESIGN 互斥）。

### 🟡 R3 · stop-hook.json modules 开关漏列：AC-4 明确要求，且 module_enabled 默认 false

**Severity**：🟡 Important
**Symptom（症状）**：AC-4（L128）"stop-hook.json modules 开关"列为注册点；DESIGN 0.5.1 未列 `hooks/config/stop-hook.json`（该文件是 install_hooks.sh:111 安装的模板）。实证：`common.sh:22-27` `module_enabled()` 经 `config_get ".modules[mod].enabled" "false"` 默认 **false**；现模板 `hooks/config/stop-hook.json` 无 34 条目。
**Source（源头）**：AC-4 Then 条款；L-020（L2-blind-review.md:82 明确含 stop-hook.json）；28-weak-model-compliance.sh:18 的 guard 先例（`module_enabled "..." || exit 0`）。
**Consequence（后果）**：若 34 号采用 28 号 guard 模式，无 stop-hook.json 条目 → 模块默认禁用（静默）；若采用 31/32 号 `&& true` 模式则能跑但 AC-4 的「stop-hook.json modules 开关」验收失败。当前 DESIGN 未定义 34 号采用哪种 guard，实现者任意选择导致行为漂移。
**Remedy（修补）**：0.5.1 补列 `hooks/config/stop-hook.json`（模板加 `"34_archive_commit_check": {"enabled": true}` 或命名与 00-gate 第二参数一致）；D3 明确 34 号 guard 模式（建议 28 号风格 + 模板条目）。

### 🟡 R4 · correction_file_clear API 误用：按 D3 伪代码实现会全文件删除，毁掉 compliance 等其他 type 的 correction

**Severity**：🟡 Important
**Symptom（症状）**：DESIGN D3（L113）"未命中（git 干净）→ correction_file_clear type=CORRECTION_TYPE_ARCHIVE_UNCOMMITTED（自清除）"——伪代码向 clear 传 type 参数。实证：`correction-file.sh:83-88` 真实签名 `correction_file_clear <path>`，实现 `rm -f "$path"` **全文件删除，无 type 维度**。既有 type 守卫先例：`correction-file.sh:132-144` `write_model_missing_clear()`（先查 `.type == mtype` 再删）。
**Source（源头）**：CONTEXT 已锁决策「correction-file.sh 4 函数签名」（禁动清单条目）；AC-3（"自动清除 type=archive-uncommitted 的 correction"——语义要求 type 级清除）。
**Consequence（后果）**：① 按字面实现调用不存在的参数签名；② 若 28-weak-model-compliance 刚写入 compliance correction，34 号在 git 干净时 `rm -f` 会把 compliance 矫正数据一并销毁（数据丢失 + 弱模型护栏失效）；③ 反向：34 号 overwrite 写入时（correction-file.sh merge/overwrite 策略均以新数据 type 覆盖顶层字段）会覆盖既有 compliance correction，两 type 无法共存。
**Remedy（修补）**：D3 改写为「`correction_file_read` 后判 `.type == CORRECTION_TYPE_ARCHIVE_UNCOMMITTED` 才 `correction_file_clear`」（对齐 write_model_missing_clear 先例）；显式声明与 compliance correction 的共存策略（建议：34 号命中且现存其他 type 时用 merge 或推迟写入）。

### 🟡 R5 · run_check API 误用：「34 号完全遵循」断言与已锁 API 签名矛盾

**Severity**：🟡 Important
**Symptom（症状）**：DESIGN D3 伪代码（L108）`run_check "34-archive-commit-check" <enabled_check> <condition> <message>`；0.5.2（L44）"沿用（34 号完全遵循）"。实证：`common.sh:42-58` 已锁签名 `run_check <module> <check_id> [precondition_file] <body_function>`——参数为 module/check_id/可选 precondition 文件/body 函数名，precondition 仅支持 HOOK_TMP_DIR 文件存在性检查（YAGNI 注释），无 condition/message 概念。
**Source（源头）**：CONTEXT 已锁决策 [2026-07-10] `run_check() API 设计：run_check MODULE CHECK_ID [PRECONDITION_FILE] BODY_FN，4 参数回调模式`；`git status --porcelain` 条件无法经 precondition 文件表达。
**Consequence（后果）**：实现阶段必返工（D3 的 enabled_check/condition 语义无 API 承载，需改为自定义 BODY_FN 回调）；「完全遵循」声明与伪代码自相矛盾，弱模型实现者可能强行套用 API 导致条件检查形同虚设（enabled_check 被塞进 check_id 位）。
**Remedy（修补）**：D3 改为「34 号模块 check 入口 = `run_check "archive_commit" "AC1" "" _check_archive_commit_body`，enabled/condition 逻辑全部放 `_check_archive_commit_body`（同文件函数，遵循 check_<id>_body 命名约定）」；module 名对齐 stop-hook.json key。

### 🟡 R6 · D4 correction schema 字段不匹配 + 既有 dispatch 结构描述失实

**Severity**：🟡 Important
**Symptom（症状）**：DESIGN D4（L129）读 `jq -r '.file_count // "??"'`；AC-3（L93）correction schema 为 `violations: [{ files: <行数>, hint: ... }]`——**无 file_count 字段**。D4（L134）"既有 compliance/interactive-ui 两分支"——实证 `flow-kit-resume.sh:92-149` 实际四分支：compliance / l3-model-missing / l2-model-missing / l2-missing，且 else（L151-155）对未知 type **rm -f 清文件**。
**Source（源头）**：AC-3 correction schema；flow-kit-resume.sh 现有 dispatch 实现。
**Consequence（后果）**：banner 永远显示 `??`（file_count 无处写入）；若 elif 插入位置错误（如插到 else 之后）或 bundle 升级不同步（34 号已装、resume 未更新），else 分支会把 archive-uncommitted correction 当"格式异常"删掉，矫正链路整体失效。
**Remedy（修补）**：D4 读取改为 `jq -r '.violations[0].files // .violations | length // "??"'`（与 AC-3 对齐，二选一即可但必须一致）；明确 elif 插在 `l2-missing` 分支之后、else 之前；部署顺序约束（34 号与 resume 更新同批发布，防半升级）。

### 🟡 R7 · AC-4 向后兼容（既有 hooksPath / 既有 pre-commit 冲突）零设计 + CONTEXT.md 术语与 ADR-022 直接矛盾

**Severity**：🟡 Important
**Symptom（症状）**：AC-4（L129）"既有 hooksPath 检测 → 询问/跳过 + 精确文案 `[archive-commit-gate] existing hooksPath: <path>, skipped`"；AC-4 验证方式（L135-146）用 trap + `git config core.hooksPath /custom/path` 断言该文案。DESIGN D1/ADR-022 选 symlink，全篇未设计：既有 `.git/hooks/pre-commit` 文件（非 flow-kit symlink）时 `ln -s` 会失败，skip/询问/覆盖路径未定义。另：CONTEXT.md 本 change 已登记术语（L: "pre-commit 门禁…通过 `git config core.hooksPath` 部署，不写 `.git/hooks/`" + "core.hooksPath 部署" 条目）与 ADR-022 symlink 决策**互斥**。
**Source（源头）**：AC-4 向后兼容条款（REQUIREMENT 明确未锁机制，但兼容行为是 AC 内容）；L-031 跨文件一致性；CONTEXT 术语沉淀（本 change 阶段 1 写入）。
**Consequence（后果）**：① 升级场景既有 pre-commit 被静默破坏或安装报错（ln 失败无处理）；② AC-4 验证方式在 symlink 下不可执行（install.sh 不碰 core.hooksPath，断言必失败）→ 验收挂；③ CONTEXT 术语误导后续 change（读到"core.hooksPath 部署"与 ADR-022 相悖）。
**Remedy（修补）**：DESIGN 补 D8：既有 `.git/hooks/pre-commit` 存在且非指向 flow-kit 的 symlink → 询问（交互）或跳过输出等价精确文案（非交互 --yes）；同步修订 AC-4 验证方式为 symlink 语义（trap 恢复目标改为 pre-commit 文件）；更新 CONTEXT.md 两条术语与 ADR-022 一致（或 ADR 标注 supersedes 术语）。

### 🟡 R8 · symlink 目标路径在已安装环境未定义：9.3 契约指向不存在的 flow-kit-bundle/

**Severity**：🟡 Important
**Symptom（症状）**：DESIGN D1（L64）"symlink .git/hooks/pre-commit → flow-kit-bundle/hooks/pre-commit/pre-commit.sh"；§9.3（L246）契约同样写"symlink 指向 flow-kit-bundle/hooks/pre-commit/<hook-name>.sh"。实证：install_hooks.sh:58-72 将 hooks 部署到 `~/.claude/hooks`（user）或 `$project/.claude/hooks`（project），**目标项目不存在 flow-kit-bundle/ 目录**（该目录是打包源仓库布局）；CONTEXT 已锁决策「hooks 只装 user scope（~/.claude/）」。
**Source（源头）**：install_hooks.sh 部署目标逻辑；已锁决策 [2026-07-01] user-scope hooks 统一。
**Consequence（后果）**：实现者按 9.3 字面在目标项目创建指向不存在目录的悬空 symlink → pre-commit 全部静默失效（git 执行悬空 symlink 报错或忽略）；或临时 bundle 目录被删后门禁消失。
**Remedy（修补）**：契约改写为「symlink 目标 = 已安装 hooks 目录（user: `~/.claude/hooks/pre-commit/pre-commit.sh` / project: `${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-commit/pre-commit.sh`），由 install_hooks.sh 负责写入」（与 stop/session-start 部署同源）；9.3 明确相对 vs 绝对路径策略。

### 🟡 R9 · D2 PATH 补齐不可靠：非交互 shell source ~/.bashrc 常被 $- 守卫短路

**Severity**：🟡 Important
**Symptom（症状）**：DESIGN D2（L85）"source ~/.bashrc ~/.profile 2>/dev/null # PATH 补齐"。实证：git 以非交互、非登录方式执行 hook；主流发行版 .bashrc 首行 `case $- in *i*) ;; *) return;; esac`，非交互 source 直接 return；nvm 等 PATH 注入（`~/.nvm/nvm.sh`、`~/.bashrc` 内的 export PATH）全部失效；`npx` 常见于 `~/.nvm/*/bin` 或 `~/.local/bin`，默认非登录 PATH 通常不含。
**Source（源头）**：REQUIREMENT AC-2 空分支声明（PATH 补齐后再 warn）；bash 交互守卫语义。
**Consequence（后果）**：主路径（PATH 补齐）在典型 nvm 环境无效 → 走 warn+skip 降级 → L-023 门禁在「最需要它的开发机」上静默缺席；AC-2 的 Given（npx 可见）只在 PATH 本就完整的环境成立。
**Remedy（修补）**：D2 增补：source `/etc/profile` + 检测 `$NVM_DIR` 时 source `$NVM_DIR/nvm.sh` + `~/.local/bin` 显式加入；降级路径保留但文案注明「PATH 补齐失败，门禁跳过」（避免假安全感）。

### 🟡 R10 · D7 archive_base_sha 写 .flow-active.goal：撞禁动清单 + 双存储二义 + 全设计无消费方

**Severity**：🟡 Important
**Symptom（症状）**：DESIGN D7（L157）"归档时 jq 写 `.flow-active.goal.archive_base_sha`"；D6 文本（L152）"记录 ARCHIVE_BASE_SHA…到 STATE.md 供 verify"——两处存储目标。实证：CONTEXT 禁动清单「.flow-active.goal 字段 — 不允许手动编辑，必须通过 /flow goal 子命令操作」；32-fallback-guard.sh:42 先例是 **hook 进程** jq 写，D7 是 **prompt 指令 AI 执行** jq 写——AI 手编 .flow-active.goal 正是禁动约束对象；且 28-weak-model-compliance L1 层会 grep transcript 触碰禁动路径，prompt 里的 jq 写指令文本本身即可能触发合规告警。全 DESIGN 无任何读取 archive_base_sha 的消费者（AC-1 验证用 bash 变量）。
**Source（源头）**：CONTEXT 禁动清单；AC-1 验证方式（变量锚定，非持久化字段）。
**Consequence（后果）**：① 弱模型照 prompt 执行 jq 写 → 28 号合规扫描误报/实报（transcript 含 `.flow-active.goal` 写入）；② STATE.md 与 .flow-active 双记录漂移；③ 无消费方的 schema 扩展（死字段 + goal schema 膨胀，跨 session 状态污染）。
**Remedy（修补）**：删 D7 的 .flow-active.goal 写入，统一「STATE.md 记录 ARCHIVE_BASE_SHA」（D6 文本方案）；若坚持持久化，需在 0.5.1 禁动段显式声明例外 + CONTEXT 登记字段 + 定义读取方（如 pre-commit 或 34 号校验归档 commit 数），否则 v1 不做。

### 🟡 R11 · D6 fix/docs/chore 三分类对「非 specs 的 .md（prompts/templates/reference）」无归属

**Severity**：🟡 Important
**Symptom（症状）**：AC-1 分类：fix = `.sh/.py/.ts 等非 .md 非产物`；docs = `.specs/archive/` 归档产物；chore = `.specs/` 四个元数据文件。DESIGN D6（L147）"prompts 不算源码"却未给替代归属。本 change 自身即会修改 `7-integration.md` + `commit-protocol.md`（AC-5 文件清单）——这两个文件在归档时点不属于任何分类。
**Source（源头）**：AC-1 拆分粒度条款；commit-protocol.md 原子原则（单一意图）。
**Consequence（后果）**：弱模型面对无归属文件任意归类（多数会塞进 docs 或 chore），commit message 类型与实际内容不符；`git log --grep` 校验（AC-1 验证按 fix|docs|chore 计数）语义漂移。
**Remedy（修补）**：D6 分类表补第四类或扩 docs 定义：「docs：归档产物 + 非 .specs 的 .md 文档改动（prompts/templates/reference）」；同步修订 AC-1 分类行（或标注 v1 例外）。

### 🟢 R12 · 风险表 R1 与选定机制不符 + 新 CLI 表面未设计

**Severity**：🟢 Minor
**Symptom（症状）**：DESIGN §4 R1（L219）"install.sh user-scope 安装时 pre-commit 只到 `~/.claude/hooks/`，但 git 不认 user-scope hooks"——symlink 方案下 pre-commit 从不部署到 ~/.claude/hooks/，风险描述是 core.hooksPath 思路的残留；缓解句新增 `--deploy-pre-commit <project>` CLI 参数在 0.5.1 / D1 / AC-4 中均无定义。
**Source（源头）**：DESIGN D1（symlink）与 §4 R1 自相矛盾；REQUIREMENT 未提该参数。
**Consequence（后果）**：风险条目误导实现者；新 CLI 参数凭空出现，无验收。
**Remedy（修补）**：R1 改写为 symlink 语义（user-scope 安装后项目 .git/hooks/pre-commit 未建 → 提示运行 `install.sh --project <path>`）；`--deploy-pre-commit` 若保留需并入 D1/触碰清单。

### 🟢 R13 · commit-protocol.md 归入「复用（不改）」却描述为「扩展」

**Severity**：🟢 Minor
**Symptom（症状）**：DESIGN 0.5.1 L26 将 `commit-protocol.md` 列在「既有 · 复用（不改）」，同条注释"扩展归档级段，不改任务级段"——扩展即修改。AC-5 文件清单（REQUIREMENT L152）明确列为修改文件。
**Source（源头）**：0.5.1 清单自身分类逻辑。
**Consequence（后果）**：触碰清单分类漂移，4-dev 按清单评估改动面时误判；L-031 对账噪音。
**Remedy（修补）**：移到「既有 · 修改」段。

### 🟢 R14 · 7-integration.md PCSC「git status 干净」检查项漏出触碰清单

**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT v1 范围（L186）"7-integration.md 步骤 5.1 + PCSC「git status 干净」"、AC-5 文件清单（L151）"7-integration.md（步骤 5.1 + PCSC）"；DESIGN 0.5.1（L17）仅列"新增 5.1 归档 commit 指导段"，PCSC 自检表新增项未列。
**Source（源头）**：AC-5 修改面清单；CHANGE.md 验收线（"PCSC 自检表新增「git status 干净」"）。
**Consequence（后果）**：实现时 PCSC 段遗漏 → prompt 层加固（三层中的第一层）缺一角，CHANGE.md 验收线「未 commit → PCSC ❌ → 禁止完成 pipeline」失效。
**Remedy（修补）**：0.5.1 补列「7-integration.md PCSC 自检表新增『git status 干净』检查项」。

---

**Verdict**: fail

---

## 主 agent 响应（2026-08-06）

> 修代码优先协议 · 逐条回应 L2 盲审发现。

- **R1 🔴** Fixed in: DESIGN.md v2 §0.5.1 补列 `00-gate.sh:120` run_module 调度行（L120 `33-flow-active-integrity` 后、L123 `99-report` 前加 `run_module "${HOOK_BASE_DIR}/34-archive-commit-check.sh" "archive-commit-check"`）+ bats 反向完整性（HOOK_MODULE_NAMES 每元素在 00-gate.sh 有对应 run_module 行）+ §4 R4 缓解句改「00-gate.sh run_module 插入位置保证」
- **R2 🔴** Fixed in: DESIGN.md v2 D3 实现双模式检测——pipeline（goal.status==done）+ 单阶段（.specs/archive/ 最新 mtime > active_since）
- **R3 🟡** Fixed in: DESIGN.md v2 §0.5.1 补列 `stop-hook.json` 模板条目 + D3 采用 28 号 `module_enabled || exit 0` guard
- **R4 🟡** Fixed in: DESIGN.md v2 D3 type-guarded clear（先 correction_file_read 判 type==ARCHIVE_UNCOMMITTED 才 clear，对齐 write_model_missing_clear 先例 correction-file.sh:132-144）+ 共存策略声明（现存其他 type 不覆盖）
- **R5 🟡** Fixed in: DESIGN.md v2 D3 改为 run_check 4 参数回调 API（body 函数 `_check_archive_commit_body`，遵循 `check_<id>_body` 命名）
- **R6 🟡** Fixed in: DESIGN.md v2 D4 读取改 `.violations[0].files`（与 AC-3 schema 对齐）+ elif 插入位置（l2-missing 分支后、else 前）+ 部署顺序约束（34 号与 resume 同批发布）
- **R7 🟡** Fixed in: DESIGN.md v2 新增 D8（既有 .git/hooks/pre-commit 冲突处理）+ REQUIREMENT.md AC-4 验证方式 hooksPath→pre-commit（L129/L134-136/L142-144）+ CONTEXT.md 术语 core.hooksPath→git hook symlink（L565-566）
- **R8 🟡** Fixed in: DESIGN.md v2 D1/§9.3 symlink 目标改为已安装 hooks 目录（user: ~/.claude/hooks/pre-commit/ · project: .claude/hooks/pre-commit/）
- **R9 🟡** Fixed in: DESIGN.md v2 D2 PATH 增补 source /etc/profile + NVM_DIR + ~/.local/bin（.bashrc 常被 $- 守卫短路）
- **R10 🟡** Fixed in: DESIGN.md v2 D7 删 .flow-active.goal 写入，统一 STATE.md 记录 ARCHIVE_BASE_SHA
- **R11 🟡** Fixed in: DESIGN.md v2 D6 扩 docs 定义含非 .specs 的 .md（prompts/templates/reference）
- **R12 🟢** Deferred → MINOR-DEFERRED.md 阶段 2 分区（DESIGN v2 已改 --project 模式，6-review 校验）
- **R13 🟢** Deferred → MINOR-DEFERRED.md 阶段 2 分区（DESIGN v2 已移 commit-protocol.md 到修改段，6-review 校验）
- **R14 🟢** Deferred → MINOR-DEFERRED.md 阶段 2 分区（4-dev 实施 D6 时补 PCSC 检查项，6-review 校验）

**修复后状态**：DESIGN.md v2（255→271 行）+ REQUIREMENT.md AC-4 修订（3 处）+ CONTEXT.md 术语修订（2 行）+ ADR-022 新增 + MINOR-DEFERRED.md 阶段 2 分区。准备重派 L2 盲审 v2。

---

## L2 盲审（重审）

> 盲审参数：阶段=2 · 工件=DESIGN.md v2（R1-R11 修复版）· 独立性声明：输入仅含工件文件，无主 agent 自评注入（主 agent 响应段为待复核对象，非权威）。判断基于对 flow-kit-bundle/ 独立 grep + jq 实证。

### R1-R11 逐条核实

- **R1 🔴** ✓ 到位：00-gate.sh:120（`run_module .../33-flow-active-integrity.sh`）+ L123（`99-report`）实证硬编码逐行；§0.5.1（DESIGN:14）补列 run_module 行（L120 后、L123 前）+ 新增 bats 反向完整性（DESIGN:34）+ §4 R4 缓解句改「00-gate.sh run_module 插入位置保证」（DESIGN:227）
- **R2 🔴** ✓ 到位（文档级）：D3（DESIGN:98-109）双模式实现（pipeline goal.status + 单阶段 archive mtime > active_since）。**边界缺陷另见 F3（🟡）**
- **R3 🟡** ✓ 到位：§0.5.1（DESIGN:16）stop-hook.json 模板条目 + D3（DESIGN:94）28 号 guard。**key 命名与既有 11 个 snake_case key 约定不符另见 F8（🟢）**
- **R4 🟡** ✓ 到位（clear 侧）：D3（DESIGN:114）type-guarded clear（对齐 write_model_missing_clear correction-file.sh:132-144 实证）+ 共存策略（DESIGN:118-122）。**write 侧签名错位另见 F2（🟡）**
- **R5 🟡** ◐ 未完全到位：run_check 4 参数调用已改（DESIGN:127），但 body 函数签名 `local project_root="$1"` 与 API 实际调用不符 → **F1（🟡）**
- **R6 🟡** ✓ 到位：D4（DESIGN:137）读 `.violations[0].files` + elif 插 l2-missing 后 else 前（flow-kit-resume.sh:147/152 实证）+ 部署顺序（DESIGN:142）。**jq 表达式缺陷另见 F6（🟡）**
- **R7 🟡** ✓ 到位：D8（DESIGN:166-178）+ REQUIREMENT AC-4 修订（L129 精确文案 + L134-146 trap 验证）+ CONTEXT 术语 symlink（CONTEXT:565-566 实证）。**ADR-022 未同步另见 F4（🟡）**
- **R8 🟡** ✓ 到位（DESIGN 侧）：D1（DESIGN:67）+ §9.3（DESIGN:243）symlink 目标改已安装 hooks 目录（install_hooks.sh:60/69 部署目标实证）。**ADR-022:17 仍写 bundle 目标 → F4（🟡）**
- **R9 🟡** ✓ 到位：D2（DESIGN:79-82）source /etc/profile + NVM_DIR + ~/.local/bin（与 R9 remedy 逐字一致）
- **R10 🟡** ✓ 到位：D7（DESIGN:160-164）删 .flow-active.goal 写，统一 STATE.md；§0.5.1 禁动段（DESIGN:39）显式声明「D7 不写 .flow-active.goal」
- **R11 🟡** ◐ 未完全到位：D6（DESIGN:155）docs 已扩「非 .specs 的 .md」；**REQUIREMENT AC-1 docs 分类行（L33）未同步 → F5（🟡）**

### 回归扫描 · 新引入问题

### 🟡 F1 · D3 body 函数签名与 run_check 回调契约矛盾：$1 收不到 project_root，检测链字面实现即静默失效

**Severity**：🟡 Important
**Symptom（症状）**：DESIGN:97 `_check_archive_commit_body() { local project_root="$1" flow_active="$1/.flow-active" ... }`；DESIGN:127 `run_check "archive-commit-check" "AC3" "" _check_archive_commit_body`。实证：common.sh:49-58 `run_check` 回调调用为裸 `"$body_fn"`（**零参数**）；既有 body 函数全部读 `$PROJECT_ROOT` env（22-git.sh:84 `stat -c %s "$PROJECT_ROOT/$f"`；common.sh:124 `export PROJECT_ROOT`）。
**Source（源头）**：已锁决策 `run_check MODULE CHECK_ID [PRECONDITION_FILE] BODY_FN` 回调模式（CONTEXT 已锁决策 2026-07-10）+ `check_<id>_body` 命名约定（sweep-fix-2026-07-10）。
**Consequence（后果）**：4-dev 按 DESIGN 字面实现 → `$1` 为空 → `flow_active="/.flow-active"` → jq 读不存在文件落 else 分支 → `ls -t "/.specs/archive/"` 空 → return 0。34 号模块静默 noop，AC-3 全灭且无报错（假绿）。
**Remedy（修补）**：D3 body 改为 `local project_root="$PROJECT_ROOT"`（或直接引 `$PROJECT_ROOT`），删除 `$1` 参数语义；DESIGN:97 与 run_check 回调契约对齐。

### 🟡 F2 · D3 correction_file_write 调用签名错位：type 常量被当 data、JSON 被当 strategy，correction 内容成裸字符串

**Severity**：🟡 Important
**Symptom（症状）**：DESIGN:124-125 `correction_file_write "$corr" "$CORRECTION_TYPE_ARCHIVE_UNCOMMITTED" '{"violations":[...]}'`。实证：correction-file.sh:36 `Usage: correction_file_write <path> <json_data> [strategy]`，L47-48 `local path="$1" data="$2" strategy="${3:-overwrite}"`——3 参为 path/data/strategy，无 type 参数。
**Source（源头）**：CONTEXT 已锁决策「correction-file.sh 4 函数签名」禁动条目；R4 remedy 要求对齐 lib 真实签名。
**Consequence（后果）**：按字面实现 → data="archive-uncommitted"、strategy=JSON → 落 `overwrite|*` 分支写裸字符串 `"archive-uncommitted"` → `.type` 缺失 → D3 type-guarded clear 永不命中 + resume banner 判 unknown → else rm（flow-kit-resume.sh:155）。AC-3 矫正链路整条失效。
**Remedy（修补）**：D3 改为 `correction_file_write "$corr" "$(jq -n --arg t "$CORRECTION_TYPE_ARCHIVE_UNCOMMITTED" --arg fc "$fc" '{type: $t, violations:[{files:$fc,hint:"..."}]}')"`（data 内嵌 type，参照 28 号弱模型合规写入先例）。

### 🟡 F3 · D3 单阶段锚点 `.updated_at` 被 checkpoint 每次 Write/Edit 刷新：漏 commit 场景下永不触发 + 零验证覆盖

**Severity**：🟡 Important
**Symptom（症状）**：DESIGN:104 单阶段分支 `active_since=$(jq -r '.goal.active_since // .updated_at // "1970-..."')`——goal 为 null 时锚点必落 `.updated_at`。实证：checkpoint-lib.sh:39 `| .updated_at = $ts`（checkpoint_write 每次刷新）+ PreToolUse auto-checkpoint 全阶段 0~7 不去抖（CONTEXT 已锁）→ 7-integration 步骤 5 归档 mv 后，D6 5.1 写 STATE.md（ARCHIVE_BASE_SHA）即触发 checkpoint → updated_at > archive mtime → `[ arch_mtime -gt active_since ]` 恒假。
**Source（源头）**：AC-3 Given（REQUIREMENT:85）「mtime 在当前会话 active_since 之后」——单阶段无 active_since 字段，DESIGN 以 .updated_at 代偿但语义不符（updated_at 是最后状态更新时间，非会话锚点）。
**Consequence（后果）**：单阶段用户归档后漏 commit（本 change 目标场景）→ 34 号不触发 → AC-3 单阶段验收分支在真实流程失败；且 AC-3 验证方式（REQUIREMENT:100-118）只造 pipeline fixture（jq 设 goal.status=done），单阶段分支零测试覆盖。另 pipeline 分支（DESIGN:99-100）只查 goal.status==done，漏 AC-3 Given「.specs/archive/ 下存在归档目录」硬条件（done 由 32-fallback-guard 在 PCSC 全✅ 时置位，弱相关）。
**Remedy（修补）**：单阶段锚点改用会话级时间源（如 .flow-active 首写时间 / SessionStart 快照 / `date` 会话启动记入 tmp），或将检测时机改为「归档目录 mtime > 上次 34 号运行时间戳」；AC-3 验证补单阶段分支 fixture（goal=null + 新旧 archive mtime 对比）。

### 🟡 F4 · ADR-022 与 DESIGN v2 直接矛盾：symlink 目标仍写 flow-kit-bundle/（R8 原始缺陷原文）+ `--deploy-pre-commit` 残留

**Severity**：🟡 Important
**Symptom（症状）**：ADR-022:17「symlink `.git/hooks/pre-commit` → `flow-kit-bundle/hooks/pre-commit/pre-commit.sh`」；ADR-022:31「user-scope 安装时需额外 `--deploy-pre-commit <project>` 步骤」。实证：install.sh 全仓 grep `--deploy-pre-commit` 零命中（仅 `--project <path>`，install.sh:64/117）；DESIGN v2 D1:67/§9.3:243/§4 R1:224 已全部改向已安装 hooks 目录 + `--project`。
**Source（源头）**：L-031 跨工件一致性；R8/R12 remedy（DESIGN 侧已修，ADR 侧未同步）；DESIGN §3（L218）将 ADR-022 列为本 change 交付物。
**Consequence（后果）**：实现者/后续 change 读 ADR-022 → 按 bundle 路径建悬空 symlink（R8 后果复现）+ 调用不存在的 CLI 参数。ADR 作为本 change 架构沉淀的权威记录与 DESIGN 互斥。
**Remedy（修补）**：ADR-022:17 改「→ 已安装 hooks 目录（user: `~/.claude/hooks/pre-commit/pre-commit.sh` / project: `<project>/.claude/hooks/pre-commit/pre-commit.sh`）」；ADR-022:31 改「install.sh --project <path> 模式部署」。

### 🟡 F5 · R11 修复半程：D6 docs 已扩，REQUIREMENT AC-1 分类行未同步，非 .specs 的 .md 仍无归属

**Severity**：🟡 Important
**Symptom（症状）**：DESIGN:155 D6 docs 分类含「非 .specs 的 .md（prompts/templates/reference）」；REQUIREMENT AC-1（L33）docs 仍仅「`.specs/archive/<date>-<id>/` 下归档产物」。
**Source（源头）**：R11 原 remedy 明确「同步修订 AC-1 分类行（或标注 v1 例外）」——未执行。
**Consequence（后果）**：本 change 自身修改的 7-integration.md + commit-protocol.md（AC-5 文件清单 REQUIREMENT:152-153）在 AC-1 三分法下仍无归属 → 弱模型任意归类（R11 原始后果未根除），`git log --grep` 分类校验（AC-1 验证）语义漂移。
**Remedy（修补）**：REQUIREMENT AC-1 docs 行补「+ 非 .specs 的 .md（prompts/templates/reference）」，与 DESIGN D6 对齐。

### 🟡 F6 · D4 jq 表达式优先级缺陷：`files // violations | length` 恒得 1（D3 写字符串文件数）

**Severity**：🟡 Important
**Symptom（症状）**：DESIGN:137 `.violations[0].files // .violations | length`；D3（DESIGN:124）写 `"files":"'"$fc"'"'`（**字符串**）。实证 jq：`{"violations":[{"files":"5"}]}` → **1**；files=5（数字）→ 5；`{"violations":[{}]}` → 1。`|` 优先级最低 → 表达式 = `(files // violations) | length`，字符串 "N" 的 length=1。
**Source（源头）**：jq 运算符优先级（`//` 绑定强于 `|`）；R6 remedy 原表达式即含此缺陷，v2 照抄。
**Consequence（后果）**：banner「（N 个）」恒显示 1——矫正提示计数错误（显示层缺陷，correction 写入不受影响）。
**Remedy（修补）**：D3 写数字 `"files":'"$fc"'`（去引号）或 D4 改 `.violations[0].files // "??"`（files 即计数，无需 length 折叠）。

### 🟡 F7 · §4 风险遗漏：REQUIREMENT 明确指令 DESIGN 评估 staged 恶意测试风险，§4 无对应条目

**Severity**：🟡 Important
**Symptom（症状）**：REQUIREMENT NFR 安全（L222）「…但 DESIGN 需评估 staged 恶意测试在 commit 前执行的风险，决定是否需 sandbox/限制」；MINOR-DEFERRED.md 阶段 1 R11 deferred 理由即「DESIGN 阶段评估…决定是否需 sandbox/限制」。DESIGN §4（L222-228）五条风险（R1-R5）无此条目。
**Source（源头）**：REQUIREMENT NFR 安全段的显式 DESIGN 义务；MINOR-DEFERRED 台账的 deferred 去向承诺。
**Consequence（后果）**：威胁模型未评估 → 无 sandbox/限制决策 → 实现照跑 `make test` 执行 staged 任意 bash（AC-2 固有语义）——义务链断裂，阶段 7 收账时无结论可核对。
**Remedy（修补）**：§4 增风险条目（staged 恶意 .bats 在 commit 前以开发者身份执行），明确 v1 决策（建议：接受风险 + 文档标注，或检测 staged .bats 非预期修改时 warn）。

### 🟢 F8 · stop-hook.json 新 key 命名与既有 11 个 snake_case key 约定不符

**Severity**：🟢 Minor
**Symptom（症状）**：DESIGN:16 模板加 `"archive-commit-check": {"enabled": true}`（kebab）；实证 stop-hook.json 全部 11 个 modules key 为 snake_case（`flow_active_integrity` / `weak_model_compliance` / `independent_review` / `interactive_ui_check`…）。
**Source（源头）**：既有 stop-hook.json 模板命名约定（11/11 snake_case）；28 号 `module_enabled "weak_model_compliance"`（snake）与 key 一致先例。
**Consequence（后果）**：模板 key 风格混用；后续 grep/脚本按 snake 约定找 key 时漏配。
**Remedy（修补）**：key 改 `"archive_commit_check"`（D3 guard + 00-gate run_module 第二参同步）。

### 结构复扫

- §0.5.1 触碰清单：修改 8 / 复用 5 / 新增 3 / 禁动 5 全分类齐全（L-031 第 4 类漏改：本次核实无新增漏列；ADR-022 属跨工件不同步 → F4）
- 决策 D1-D8：备选理由代价齐全（D1 双备选+代价；ADR-022 Alternatives Considered 两方案否决理由充分）
- §2 数据流图：四链路（归档→34→resume + pre-commit 独立链路）完整
- §3 ADR：存在但内容与 DESIGN v2 互斥（F4）
- §4 风险：5 条中 3 中 2 低，缺 REQUIREMENT 指令的 staged 恶意测试条目（F7）
- §9 五子段：9.1 N/A / 9.2 / 9.3 / 9.4 N/A / 9.5 新禁动 全在
- MINOR-DEFERRED 阶段 2 分区：R12/R13/R14 三条入账且 v2 均已落实（§4 R1 → `--project`、commit-protocol.md → 修改段、PCSC 检查项 → DESIGN:19/157）

**Verdict**: fail

---

## L2 盲审 v3 重审响应（主 agent 回复 · F1-F8 全 Fixed）

- **F1** Fixed in DESIGN.md D3: 删 `local project_root="$1"`，全用 `$PROJECT_ROOT` env（common.sh:124 export / 22-git.sh:84 check_c1_body 先例 / run_check 零参回调 common.sh:55）
- **F2** Fixed in DESIGN.md D3: correction_file_write 改 2 参（path + json 含 type 字段），对齐 correction-file.sh:47 真签名 `<path> <json_data> [strategy]`
- **F3** Fixed in DESIGN.md D3: 单阶段锡点改 `git log -1 --format=%ct` epoch 秒，不受 checkpoint bump 干扰
- **F4** Fixed in ADR-022 L17+L31: symlink 目标→已安装 hooks 目录（user ~/.claude/hooks/ / project .claude/hooks/）+ `--deploy-pre-commit`→`--project`
- **F5** Fixed in REQUIREMENT.md AC-1 L33: docs 行加「+ 非 .specs 的 .md（prompts/templates/reference）」
- **F6** Fixed in DESIGN.md D4: jq 括号修正 `(.violations[0].files // (.violations|length) // "??")`
- **F7** Fixed in DESIGN.md §4: 新增 R6（staged 恶意测试 · 低 · make test 固有语义非外部输入注入）
- **F8** Fixed in DESIGN.md D3 L94+L129 + §0.5.1 L14+L16: stop-hook.json key + module_enabled + run_check + run_module 第二参 全改 snake_case `archive_commit_check`

---

## L2 盲审（v3 重审）

> 独立性声明：仅工件文件 + flow-kit-bundle/ 独立 grep 实证。主 agent F1-F8 Fixed 声明为待复核对象，逐条独立验证，不以声明判定 pass。

### 独立验证（F1-F8 逐条 grep 实证）

| # | 发现 | grep 实证 | 状态 |
|---|------|----------|------|
| F1 | D3 body 函数用 $PROJECT_ROOT env（非 $1 参数） | DESIGN:97-98 `local flow_active="${PROJECT_ROOT}/.flow-active"`（body 内零 `$1`）；common.sh:55 `"$body_fn"` 零参回调；common.sh:124 `export PROJECT_ROOT`；22-git.sh:84/89 先例 | ✅ Fixed |
| F2 | correction_file_write 对齐真签名（path+json_data） | DESIGN:126-127 `correction_file_write "$corr" "{\"type\":...}"`（type 内嵌 json data）；correction-file.sh:47-48 `<path> <json_data> [strategy]` | ✅ Fixed |
| F3 | 单阶段锚点 git log --format=%ct（非 .updated_at） | DESIGN:108 `git log -1 --format=%ct`；D3 全文零 `.updated_at`/`active_since` 残留。**pipeline 分支缺陷未修 → 回归 N1** | ◐ 部分 |
| F4 | ADR-022 L17 symlink 目标 + L31 --project 同步 | ADR-022:17 已安装 hooks 目录（user `~/.claude/hooks/` / project `.claude/hooks/`）；ADR-022:31 `--project <path>`（install.sh:117 `--project) MODE=project` 实证） | ✅ Fixed |
| F5 | REQUIREMENT AC-1 docs 行含非 specs .md | REQUIREMENT:33 `+ 非 .specs 的 .md（prompts/templates/reference）` | ✅ Fixed |
| F6 | D4 jq 括号修正 | DESIGN:139 `(.violations[0].files // (.violations | length) // "??")`；jq 实证：files="5"（字符串）→ 输出 5 | ✅ Fixed |
| F7 | §4 有 R6 staged 恶意测试风险 | DESIGN:231 R6 行（make test 固有语义非外部输入注入 + install.sh --project 用户显式信任） | ✅ Fixed |
| F8 | 全链路 snake_case | DESIGN:16 `"archive_commit_check"`（stop-hook.json:71/77/85 先例 snake）；DESIGN:94 `module_enabled "archive_commit_check"`；DESIGN:129 `run_check "archive_commit_check"`（= check_enabled common.sh:33 查询 `.modules[key]` 的功能要求）；DESIGN:14 run_module 第二参（00-gate.sh:120 33 先例 `flow_active_integrity` snake） | ✅ Fixed |

### 回归扫描

（v3 新引入 + F3 未完整修复：3 🟡 + 2 🟢）

### 🟡 N1 · F3 修复不完整：D3 pipeline 分支仍漏 AC-3 Given 硬条件（archive 目录存在 + scope==pipeline），phase-scoped goal 模式误报
**Severity**：🟡 Important
**Symptom（症状）**：DESIGN:100-101 pipeline 分支仅判 `jq -e '.goal'` 存在 + `.goal.status == "done"`；AC-3 Given（REQUIREMENT:85）要求「归档完成——单一硬条件：`.specs/archive/` 下存在归档目录」且 pipeline 模式 = `goal.scope == "pipeline"` && status == "done"。本文件:190（v2 F3 原文）已含此缺陷，v3 Fixed 声明仅覆盖单阶段锚点。
**Source（源头）**：AC-3 Given（REQUIREMENT:85）；CONTEXT 已锁「单阶段 goal（scope: phase 或无 scope）为既有模式」。
**Consequence（后果）**：phase-scoped goal 完成（status=done）+ git status 非干净（常规 WIP）→ 34 误写 archive-uncommitted correction，SessionStart 每 session 误报「归档后未 commit」直至 git 干净；AC-3 验证（REQUIREMENT:100-118）仅 pipeline fixture，误报路径零覆盖。
**Remedy（修补）**：D3 pipeline 分支补 `[ "$(jq -r '.goal.scope // ""' "$flow_active")" = "pipeline" ]` + `[ -d "${PROJECT_ROOT}/.specs/archive" ]`，对齐 AC-3 Given；或同步修订 AC-3 Given（二选一，禁止保持现状）。

### 🟡 N2 · D2 no-Makefile 消息文案与 AC-2 契约串不一致：按 DESIGN 实现则 AC-2 空分支验证 grep 必失败
**Severity**：🟡 Important
**Symptom（症状）**：DESIGN:83 `echo "[archive-commit-gate] 无 Makefile，跳过（warn）"`（中文）；AC-2 Then（REQUIREMENT:63）契约串 `[archive-commit-gate] no Makefile, skipping test gate` + 验证（REQUIREMENT:79）`grep -q 'no Makefile, skipping'`。
**Source（源头）**：AC-2 空分支精确文案契约（R12 先例：AC-4 文案已 pin + grep -qF）。
**Consequence（后果）**：弱模型照 DESIGN 伪代码实现 → 输出中文文案 → AC-2 空分支验证不匹配 → 阶段 5 验收挂或被迫改测试（假绿）。
**Remedy（修补）**：DESIGN:83 文案改与 AC-2 逐字一致（`[archive-commit-gate] no Makefile, skipping test gate`），或同步修订 REQUIREMENT:63/79（二选一）。

### 🟡 N3 · D8 非交互跳过契约无载体：FLOW_KIT_YES 全仓 0 producer，install.sh 无 --yes，AC-4 验证命令不可执行
**Severity**：🟡 Important
**Symptom（症状）**：DESIGN:174 `[ "${FLOW_KIT_YES:-0}" = "1" ]`；grep flow-kit-bundle/ → FLOW_KIT_YES 0 匹配；install.sh arg parse（L113-126）无 `--yes`（未知选项 → usage 退出）；AC-4 验证（REQUIREMENT:145）`install.sh --yes 2>&1 | grep -qF '[archive-commit-gate] existing pre-commit: .git/hooks/pre-commit, skipped'`。
**Source（源头）**：AC-4 向后兼容 Then（「非交互式 --yes」）；R12 先例（凭空 CLI 表面）。
**Consequence（后果）**：install_hooks.sh 读 FLOW_KIT_YES 恒空 → 非交互安装落入 `read -p` 阻塞（CI/脚本挂起）；AC-4 验证命令现走「未知选项」路径，grep 必不匹配 → 验收挂；4-dev 自行发明接线则 §0.5.1 漏列 install.sh arg parse 修改点（L-031 漏改风险）。
**Remedy（修补）**：§0.5.1/D8 补列 install.sh arg parse 新增 `--yes) FLOW_KIT_YES=1`（L113-126 case 段）并标注与 AC-4 验证的对应；或 AC-4 验证改 env 注入（`FLOW_KIT_YES=1 install.sh ...`）。

### 🟢 M1 · D4 插入点行号陈旧（L149 位于 l2-missing 分支体内）
**Severity**：🟢 Minor
**Symptom（症状）**：DESIGN:137「（L149 后插入）」——实证 flow-kit-resume.sh:147 `elif l2-missing`、:151 `:`（noop）、:152 `else`；L149 是分支内注释行。语义约束（DESIGN:138「l2-missing 后 else 前」）正确，行号陈旧。
**Remedy（修补）**：改「L151 `:` 后、L152 `else` 前插入」。

### 🟢 M2 · D3 写 files 为字符串，AC-3 schema 语义为数字行数
**Severity**：🟢 Minor
**Symptom（症状）**：DESIGN:127 `"files":"$fc"`（字符串）；REQUIREMENT:93 `files: <git status --porcelain 行数>`（数字语义）。D4 括号修复后显示正确（"5"→5），无功能影响。
**Remedy（修补）**：D3 去引号写数字（`"files":'"$fc"'`）与 AC-3 schema 对齐。

### 结构复扫

- D1-D8 完整（各含备选/代价/修复标注）✓
- §0.5.1：修改 10 / 复用 4 / 新增 3 / 禁动 5。L-031 锚点独立核：00-gate.sh:120/123（run_module 硬编码序列实证，插入位正确）；common.sh:270（HOOK_MODULE_NAMES 实证）；install.sh:218/242/252（install_hooks 调用点实证）；install_hooks.sh:79-87（迭代数组 → 34 自动纳入；L81 fallback 硬编码数组需同步——4-dev 注意）；settings.json 无需改（Stop 数组单入口 00-gate.sh · install_hooks.sh:75 实证）。无第 4 类（DESIGN 漏列且未改）
- §4 风险 R1-R6 六条齐（R6 = F7 新增）
- §9 五子段齐（9.2/9.3 目标=已安装 hooks 目录，与 D1/ADR-022 三方一致）
- 跨工件一致性：DESIGN↔ADR-022 ✅（F4 后无矛盾）；DESIGN↔REQUIREMENT 两处不一致（N2 文案 / N3 非交互载体）+ F3 残差（N1）

**Verdict**: pass（无 🔴 · 3 🟡 入 fix loop · fix 即过）

---

## L2 盲审 v3.1 响应（主 agent 回复 · 3 🟡 Fixed）

- **F3-residual** Fixed in DESIGN.md D3 L100-103: pipeline 分支补 scope==pipeline + archive dir existence 硬条件（AC-3 Given 三条件全检：scope==pipeline && status==done && -d .specs/archive）
- **N1** Fixed in DESIGN.md D2 L83: no-Makefile message 改英文 `no Makefile, skipping test gate`（对齐 REQUIREMENT:63 + AC-2 verify L79 grep 'no Makefile, skipping'）
- **N2** Fixed in DESIGN.md §0.5.1 L21 + D8: install.sh arg parse 加 `--yes`→`FLOW_KIT_YES=1` flag（D8 carrier 补齐，AC-4 verify L145 `install.sh --yes` 可执行）
