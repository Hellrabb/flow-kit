# 独立审查 · 阶段 1

## L2 盲审

Verdict: pass

### 🟡 R1 · 待定决策与验证命令硬编码冲突：hook 编号「待定」但验证命令锁定 34
**Severity**：🟡 Important
**Symptom**：REQUIREMENT.md:77 声明新模块「编号待定，候选 34-archive-commit-check.sh」，但 :90/:94（AC-3 验证）与 :118（AC-4 验证）硬编码 `bash flow-kit-bundle/hooks/stop/34-archive-commit-check.sh` 与 grep '34-archive-commit-check'。:52 声明「DESIGN 阶段确认 make test / make check / 增量」，但 :62-63 验证依赖全量 suite 才能捕获 temp-fail。
**Source**：ADR-019 原则①（AC 必须确定性）；固化指令阶段 1 checklist 项 1（验证方式是否真能区分 pass/fail）。
**Consequence**：若 DESIGN 选定不同编号或增量测试，两条 AC 验证命令立即失真（假 fail 或假 pass），且 :77 与 :90/:94 文档自相矛盾，实施者无法判断 34 是否为已锁编号。
**Remedy**：二选一——(a) 在 REQUIREMENT 直接锁定编号 34 与全量 `make test`（把待定项转正）；(b) 验证命令改用占位符 + DESIGN 落定后回填（如 `hooks/stop/<N>-archive-commit-check.sh`）。禁止「待定」与硬编码并存。

### 🟡 R2 · 越界锁定部署策略：core.hooksPath 属范围决策却已写死进 AC
**Severity**：🟡 Important
**Symptom**：REQUIREMENT.md:55（AC-2 Then）「hook 通过 `git config core.hooksPath` 部署」+ AC-4 整体（:98-123）围绕 core.hooksPath 展开；CHANGE.md:53 明确「需选部署策略——core.hooksPath vs symlink farm vs husky 等价物。各有取舍，DESIGN 阶段定」。
**Source**：ADR-019 原则②（范围决策属 DESIGN 非 REQUIREMENT）；固化指令阶段 1 checklist 项 2。
**Consequence**：REQUIREMENT 已把 CHANGE.md 明确定义为 DESIGN 决策的方案提前锁定，DESIGN 阶段失去权衡空间；若 DESIGN 论证 core.hooksPath 有缺陷（如与已锁决策「user-scope hooks 统一」的交互问题），需回改 AC-2/AC-4 及全部验证命令。
**Remedy**：AC-2/AC-4 收敛为「pre-commit hook 经 install.sh 部署且不写 .git/hooks/ 不入仓库，具体机制（core.hooksPath / symlink）DESIGN 定」，验证命令改为机制无关断言（`git commit` 行为测试），把 hooksPath 细节下放 DESIGN。

### 🟡 R3 · AC-1 验证命令无法区分归档 commit 与 4-dev 任务级 commit
**Severity**：🟡 Important
**Symptom**：REQUIREMENT.md:42 `git log --oneline -10 | grep -cE '^[0-9a-f]+ (fix|docs|chore)\('` 期望 ≤3 且 ≥1。commit-protocol.md 的任务级 commit 格式同为 `fix(<change-id>): T0X …`（README 提交格式节），pipeline 一次运行即可产生多个匹配提交。
**Source**：ADR-019 原则①；固化指令阶段 1 checklist 项 1（验证方式命令是否真能区分 pass/fail）。
**Consequence**：真实归档 commit 发生且合格时，窗口内混入任务级 commit → 计数 >3 → 假 fail；反之仅靠历史任务级 commit 也可计数 ≥1 → 假 pass。验证对「归档 commit 是否发生」无判定力。
**Remedy**：验证锚定归档时刻——如 `git log --since="$(stat -c %y 归档产物首文件)" --oneline` 或归档步骤记录 commit 起点 SHA，仅统计起点之后的提交并按 change-id 过滤（`fix(archive-commit-gate)`）。

### 🟡 R4 · AC-3 Given 第二析取项不可机器验证 + 单阶段模式空分支未声明
**Severity**：🟡 Important
**Symptom**：REQUIREMENT.md:72「归档完成（`.flow-active.goal.status == "done"` 或 7-integration 归档步骤已执行）」——第二项「归档步骤已执行」无任何硬标记可检测；且单阶段模式（无 pipeline goal）下 goal.status 字段可能整体缺失，未声明不适用分支。
**Source**：ADR-019 原则①（条件 AC 拆 hard+soft / 可机器验证）；固化指令阶段 1 checklist 项 1 + 项 8（空分支声明）。
**Consequence**：Stop hook 实现时无法确定判定条件；单阶段模式归档后 hook 行为未定义——漏检（无兜底）或误报（每次 Stop 都写 correction）。
**Remedy**：锁定单一硬条件（如归档步骤写入显式标记 `git tag` 或 `.specs/archive/` 下新目录 mtime 检测），并显式声明「单阶段模式无 goal 时不触发，属不适用分支」。

### 🟡 R5 · 禁动自违反 + 错误函数引用：AC-3 验证手编 .flow-active.goal，且 fk_resolve_phase 不读 goal.status
**Severity**：🟡 Important
**Symptom**：REQUIREMENT.md:87 验证命令 `jq '.goal.status = "done"' .flow-active > .tmp && mv .tmp .flow-active` 直接手编 `.flow-active.goal`，与 :214 自身声明「禁动：.flow-active.goal 字段不手编（用 /flow 子命令）」直接矛盾；且 :214 所述「读 goal.status 用 fk_resolve_phase」错误——common.sh:215-227 fk_resolve_phase 仅读 `.goal.scope`/`.goal.current_phase`/`.phase`，不读 goal.status（既有先例 32-fallback-guard.sh:42 是直接 jq 读）。
**Source**：CONTEXT.md 禁动清单「.flow-active.goal 字段 — 不允许手动编辑，必须通过 /flow goal 子命令操作」；固化指令阶段 1 checklist 项 5（禁动清单碰撞）。
**Consequence**：实施者照 AC 验证执行即违反禁动、制造状态漂移（已文档化失败类别）；:214 的错误引用会把实现引向错误函数。Spec 自相矛盾，弱模型（protect the weakest 哲学）会照验证命令执行。
**Remedy**：验证改为受控模拟（如复制 .flow-active 到临时副本改 status 后喂给 hook，或声明 hook 内 jq 读不受禁动约束——与 32-fallback-guard 一致），并修正 :214 函数引用（删除 fk_resolve_phase 或改列 32-fallback-guard.sh:42 的直接 jq 模式为合法先例）。

### 🟡 R6 · AC-3 correction 清除语义矛盾：Then 说 AI 清除，验证方式隐含 hook 自清除
**Severity**：🟡 Important
**Symptom**：REQUIREMENT.md:82「AI … 清除 correction」，但 :95 验证「commit 后重跑 hook → 文件不存在或 type 非 archive-uncommitted」——重跑 hook 后文件消失只可能在 hook 自身于 git clean 时清除 correction 才成立。Then 与验证方式对「谁清除、何时清除」表述不一致。
**Source**：ADR-019 原则①（AC 确定性）；固化指令阶段 1 checklist 项 1。
**Consequence**：若按 Then 实现（仅 AI 清除），:95 验证必假 fail（陈旧 correction 永存，SessionStart 每会话注入过期 banner）；若按验证实现（hook 自清除），Then 描述错误且需新增清除语义。
**Remedy**：统一为「hook 在 git status 干净时自动清除 type=archive-uncommitted 的 correction（correction_file_clear()）」写入 Then，验证与语义一致。

### 🟡 R7 · 影响面清单不全：AC-5 Given 缺 flow-kit-resume.sh / common.sh HOOK_MODULE_NAMES，package-flow-kit.sh 禁动碰撞未声明
**Severity**：🟡 Important
**Symptom**：REQUIREMENT.md:127 AC-5 Given 列「7-integration.md + commit-protocol.md + install.sh + install_hooks.sh + 新 Stop hook 模块 + pre-commit hook 脚本」，但 (a) AC-3:81 的 SessionStart banner 落在 flow-kit-resume.sh——实测该文件为 type-dispatch（仅 compliance / l3-model-missing / l2-model-missing 分支），新增 archive-uncommitted 必须加 elif 分支，未列清单；(b) 新 Stop hook 模块需登记 common.sh:270 HOOK_MODULE_NAMES（CONTEXT 禁动：该数组修改需同步 install_hooks.sh + package-flow-kit.sh，即 L-020 三处接线），common.sh 与 package-flow-kit.sh（禁动清单条目）均未声明。
**Source**：固化指令 L-031（跨文件一致性清单可能不全，独立全仓扫描）；固化指令阶段 1 checklist 项 5（禁动碰撞）+ 项 6（既有抽象复用遗漏）。
**Consequence**：DESIGN/实施按清单执行将漏改 flow-kit-resume.sh（banner 永不出现，AC-3 半失效）与 HOOK_MODULE_NAMES（install_hooks 不安装新模块，AC-4 半失效）；package-flow-kit.sh 属禁动，未先声明例外会在 7-integration 撞墙。
**Remedy**：AC-5 Given 补齐 flow-kit-resume.sh、common.sh（HOOK_MODULE_NAMES）、package-flow-kit.sh（声明禁动例外，参照 superpowers-v6-absorb 先例）；复用清单（:208-211）同步补列。

### 🟡 R8 · 验证命令副作用污染共享状态：AC-4 永久覆盖 core.hooksPath 且无断言，AC-2 残留 staged 状态
**Severity**：🟡 Important
**Symptom**：REQUIREMENT.md:120-122「git config core.hooksPath /custom/path → install.sh --yes → 仍为 /custom/path」——验证后不恢复，本仓库 pre-commit 门禁被永久禁用，且第二项验证只是打印（无断言）；:62-67 AC-2 验证中 temp-fail.bats 被 `git add` 后 rm、再 commit、再 `git reset --soft HEAD~1`，最终 index 残留该文件、worktree 缺失，仓库留脏（:66 commit 实际提交的是 index 而非 worktree）。
**Source**：ADR-019 原则①（验证可区分性/可重复性）；固化指令阶段 1 checklist 项 1。
**Consequence**：AC-4 先于 AC-1/AC-2 执行（文档顺序即如此）→ hooksPath 已非 flow-kit 目录 → AC-2:60 验证假 fail；AC-2 残留脏状态 → AC-1:40「git status clean = 0」假 fail。验证间相互污染，全量验证不可重复执行。
**Remedy**：AC-4 验证用 `trap` 恢复 hooksPath（存旧值 → 测 → 还原）；AC-2 验证结束加 `git reset HEAD test/temp-fail.bats && git checkout -- test/temp-fail.bats` 真清场，或在子目录/临时 repo 中执行验证隔离副作用。

### 🟡 R9 · pre-commit 运行环境假设未声明：无 Makefile 项目 fail-close 死锁 + hook 环境 PATH 可见性
**Severity**：🟡 Important
**Symptom**：REQUIREMENT.md:52-54 硬门禁语义「bats 非零退出码 → 拒绝 commit」，但未声明 (a) 目标项目无 Makefile 时的行为——`make test` 必败 → 所有 commit 被拒（fail-close 死锁）；(b) git hook 执行环境 PATH 常不含 npx/node（Makefile test target 走 npx bats），hook 内 make/npx 不可见 → 假 fail。
**Source**：固化指令阶段 1 checklist 项 4（NFR 兼容性遗漏关键维度）。
**Consequence**：install.sh 面向任意目标项目（CHANGE.md 范围），无 Makefile 或非交互 shell 环境下，用户 git 工作流被整体锁死，且为无声失败（用户无法 commit 任何内容），破坏性高于原 gap。
**Remedy**：REQUIREMENT 显式声明空分支「目标项目无 Makefile / 无 npx → hook 跳过（warn）而非拒绝」，并把 hook 内 PATH 初始化（source 用户 profile 或绝对路径解析 make/npx）列为兼容性 NFR。

### 🟡 R10 · 复用清单遗漏 correction-types.sh：新 type 未声明登记既有共享常量文件
**Severity**：🟡 Important
**Symptom**：REQUIREMENT.md:201 声明新 correction type `archive-uncommitted`「与现有 type=compliance/interactive-ui/l2-missing 并列」，:208-211 复用清单列了 correction-file.sh / commit-protocol.md / install_hooks.sh / run_check()，但未提及 `hooks/stop/lib/correction-types.sh`——实测该文件（:20-21）集中登记 `CORRECTION_TYPE_COMPLIANCE` / `CORRECTION_TYPE_INTERACTIVE_UI` 常量。
**Source**：CONTEXT.md 既有抽象索引（correction-types.sh = 三模块共享接口常量文件）；固化指令阶段 1 checklist 项 6（既有抽象复用遗漏）。
**Consequence**：新类型绕过常量文件硬编码进 34 号模块 → 与既有三模块的共享接口模式分裂，下次改动 correction 类型时三处失同步（该项目已吃过 correction 三向依赖环的教训，health-fix-l3-2026-07）。
**Remedy**：复用清单补列 correction-types.sh，AC-3 明确要求新增 `CORRECTION_TYPE_ARCHIVE_UNCOMMITTED` 常量并供 34 号模块 + resume 分支共用。

### 🟢 R11 · NFR 安全表述失真：pre-commit hook「不执行用户代码」与 make test 矛盾
**Severity**：🟢 Minor
**Symptom**：REQUIREMENT.md:187「pre-commit hook 不执行用户代码（只跑 make test，不接受外部输入）」——`make test` 即执行仓库内测试代码（含被暂存的 .bats，内可写任意 bash），「不执行用户代码」表述与行为矛盾。
**Source**：固化指令阶段 1 checklist 项 4（NFR 表述准确性）。
**Consequence**：误导 DESIGN 对 hook 威胁模型的评估（真实属性是「不接受外部输入」，而非「不执行用户代码」）；staged 恶意测试在 commit 前即被执行，属固有语义，应如实声明。
**Remedy**：改为「hook 不接受外部输入/无参数，仅运行 `make test`；注意其会执行仓库测试代码（固有语义）」。

### 🟢 R12 · AC-4 验证消息契约模糊：三选一 grep 未 pin 文案
**Severity**：🟢 Minor
**Symptom**：REQUIREMENT.md:121 `install.sh --yes 2>&1 | grep -q 'existing hooksPath\|跳过\|skipped'`——提示文案未在 AC 中 pin 死，实现方任意措辞即可能假 fail，或输出中无关「跳过」字样造成假 pass。
**Source**：ADR-019 原则①（可机器验证）。
**Consequence**：验证弱确定，但仅在文案层面，可接受为 Minor。
**Remedy**：AC-4 锁定确切提示字符串（如 `[archive-commit-gate] existing hooksPath: /custom/path, skipped`），验证改 grep 精确串。

---

## 主 agent 响应（2026-08-05）

按修代码优先协议处置 10🟡 + 2🟢：

- **R1 Fixed in REQUIREMENT.md**：编号锁定 34（全文「待定」改「锁定 34」）；make test 锁定（删「DESIGN 阶段确认」，AC-2 明确全量 bats）
- **R2 Fixed in REQUIREMENT.md**：AC-2 Then + AC-4 Then 部署机制改为「属 DESIGN 决策，REQUIREMENT 不锁定」；验证改机制无关断言（git commit 行为触发 + grep 模块名注册）
- **R3 Fixed in REQUIREMENT.md**：AC-1 verify 锚定归档起点（ARCHIVE_BASE_SHA=$(git rev-parse HEAD) → git log ${ARCHIVE_BASE_SHA}..HEAD | grep change-id），区分归档 commit 与 4-dev 任务级 commit
- **R4 Fixed in REQUIREMENT.md**：AC-3 Given 单一硬条件（.specs/archive/ 目录存在 + mtime 检测）；单阶段模式空分支显式声明（goal=null 时用 archive 目录 mtime 检测；无新归档目录→noop 不适用分支）
- **R5 Fixed in REQUIREMENT.md**：AC-3 verify 改副本模拟（cp .flow-active /tmp/ + jq 改副本 status 喂 hook，不手编主文件）；依赖约束段修正 fk_resolve_phase 误引用（改为「直接 jq 遵循 32-fallback-guard.sh:42 先例，hook 内 jq 读不受禁动约束」）
- **R6 Fixed in REQUIREMENT.md**：AC-3 Then 统一为 hook 自清除（git status 干净时 correction_file_clear()），不依赖 AI 手动清除；verify 与 Then 一致
- **R7 Fixed in REQUIREMENT.md**：AC-5 Given 补齐 flow-kit-resume.sh / common.sh（HOOK_MODULE_NAMES）/ package-flow-kit.sh（禁动例外声明参照 superpowers-v6-absorb）；复用清单同步补列
- **R8 Fixed in REQUIREMENT.md**：AC-2 verify 改子目录隔离（mktemp -d 临时 repo，主仓库不受影响）；AC-4 verify 加 trap 恢复 hooksPath（OLD_HOOKSPATH 保存 + trap EXIT 还原）
- **R9 Fixed in REQUIREMENT.md**：AC-2 加空分支声明（无 Makefile → warn 放行不 fail-close；无 npx → source profile 补 PATH，仍无则 warn 放行）；NFR 兼容性补「无 Makefile 项目」+「hook 环境 PATH」两条
- **R10 Fixed in REQUIREMENT.md**：复用清单补列 correction-types.sh；AC-3 明确新增 CORRECTION_TYPE_ARCHIVE_UNCOMMITTED 常量并供 34 号模块 + resume 分支共用；AC-5 Given 补 correction-types.sh
- **R11 Deferred**：NFR 安全表述已修订（改为「不接受外部输入，执行 repo 测试代码固有语义」）；staged 恶意测试威胁模型评估入 MINOR-DEFERRED → DESIGN 阶段 triage
- **R12 Deferred**：AC-4 消息文案已锁定精确串 `[archive-commit-gate] existing hooksPath: <path>, skipped` + grep -qF；4-dev 实施时确认 install.sh 输出匹配 → MINOR-DEFERRED

独立性说明：主 agent 未检测到自身上下文注入盲审 subagent；处置基于 INDEPENDENT-REVIEW-1.md 磁盘文件内容，逐条对应 file:line 修订。
