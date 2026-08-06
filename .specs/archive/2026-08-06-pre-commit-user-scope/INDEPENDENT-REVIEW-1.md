# 独立审查 · 阶段 1

## L2 盲审（phase 1）

**审查时间**: 2026-08-06T16:20:00+08:00
**审查 agent**: L2 blind review (unspecified-high)
**verdict**: pass

### 前置实证（独立验证）

- bug 描述与源码一致：`flow-kit-bundle/lib/install_hooks.sh:39` guard `[[ -d "${project}/.git" ]] || return 0` 位于 `install_file`（L43）之前；user scope 路径 `install.sh:243` `install_hooks "$HOME" "user"`（project=$HOME）→ 无 `~/.git` 时源文件安装被一并跳过。claim 成立。
- 源文件存在：`flow-kit-bundle/hooks/pre-commit/pre-commit.sh` ✓
- 双源测试布局确认：`test/` 与 `flow-kit-bundle/test/` 为两个独立目录（非 symlink），当前内容 IDENTICAL；`Makefile` `check-test-sync` 用 `diff -rq test/ flow-kit-bundle/test/` 做一致性门禁，`test-sync` 单向 cp dev→bundle。`npx bats test/` 只跑 dev 源。

### 发现

#### #1 [🟡 Important] 双源测试遗漏：影响清单只列 bundle 副本，AC-3 验证跑 dev 源
**source**: REQUIREMENT.md:51（影响清单）、:41（AC-3 Then）
**symptom**: 影响清单触碰文件仅列 `flow-kit-bundle/test/test_archive_commit_gate.bats`。但本项目测试是双源（CONTEXT.md 双源测试同步 / Makefile check-test-sync），AC-3 的验证命令 `npx bats test/` 执行的是 dev 源 `test/`。若 4-dev 按影响清单只改 bundle 副本：dev 源无新断言 → AC-3「新增 user scope 源文件安装断言」假绿（新测试从未被 `npx bats test/` 执行）；同时 `make check` 的 check-test-sync diff 必然失败。
**consequence**: 按 spec 字面执行 → 测试覆盖声明失真（同 TD-012 / BUG-G 假绿类别）+ `make check` 质量门禁挂掉，阶段 5 验收信号不可信。
**remedy**: 影响清单补 `test/test_archive_commit_gate.bats`（dev 源为修改点，改后 `make test-sync` 同步 bundle 副本）；或在 AC-3 显式要求双源同步（`make check` 通过作为前置）。

#### #2 [🟡 Important] AC-1 的 Then #2/#3（负面行为断言）无验证路径
**source**: REQUIREMENT.md:17-18（AC-1 Then #2/#3）、:45（验证方式）
**symptom**: AC-1 三条 Then 中仅 #1（源文件存在）有验证方式对应（`test -f`）；#2「不 mkdir $HOME/.git/hooks」与 #3「不建 symlink」在验证方式与 AC-3 均无对应断言。而 guard 位置恰是本 change 的修复对象——负面行为是修复意图的一半。
**consequence**: guard 被删或位置回退（user scope 误写 `$HOME/.git/hooks/pre-commit` symlink）时无任何测试拦截，修复的回归面裸奔。
**remedy**: AC-3 补负面断言（temp HOME 下 user scope 安装后 `! -e "$HOME/.git/hooks/pre-commit"` + `! -d "$HOME/.git"`）；或验证方式补后置条件 `test ! -d ~/.git`（限 When 前提 $HOME 无 .git）。

#### #3 [🟢 Minor] AC-2 Then 不可机器执行，且与 AC-1 项目级块重复
**source**: REQUIREMENT.md:33（AC-2 Then）
**symptom**: 「symlink 创建逻辑与 archive-commit-gate 交付版本完全一致」——引用历史版本无执行语义（违反 ADR-019 写作原则①AC 确定性）；其行为细节已在 AC-1 项目级 When/Then（#1 源文件、#2 symlink 指向已装源文件、#3 冲突检测不变）完整覆盖。验证方式「git commit 触发门禁」为半手工 E2E。
**consequence**: 不可执行的回归断言只能人工背书，且与 AC-1 重复维护。
**remedy**: 删除 AC-2（由 AC-1 项目级块覆盖），或改写为可执行断言：`Then .git/hooks/pre-commit 为 symlink 且 readlink 指向 ${project}/.claude/hooks/pre-commit/pre-commit.sh`。

#### #4 [🟢 Minor] 禁动碰撞论证引用错对象
**source**: REQUIREMENT.md:52
**symptom**: 「install_hooks.sh + test/ 不在禁动清单 Part A-E/G」——Part A-G 是 `package-flow-kit.sh` 的分段（CONTEXT 禁动清单条目），与 install_hooks.sh/test 无关。实际相关禁动条目是「flow-kit-bundle/lib/install_*.sh 不允许外部直接 source」（约束 source 行为，不涉编辑）与「test/ 目录不允许放非 .bats 文件」（本 change 不违反）。
**consequence**: 结论（无碰撞）正确但依据张冠李戴，误导后续 change 对禁动边界的理解。
**remedy**: 改写为引用实际相关禁动条目。

#### #5 [🟢 Minor] 修复草案冗余 mkdir；$HOME 有 .git 的边界未声明
**source**: CHANGE.md:37 / install_hooks.sh:27
**symptom**: 草案在 `install_file` 前显式 `mkdir -p "$hook_dst/pre-commit"`，而 `install_file` 已 `mkdir -p "$(dirname "$dst")"`（L27），冗余。另：$HOME 存在 dotfiles 仓库（`~/.git`）时 user scope 仍会走 symlink 分支（行为自 archive-commit-gate 起未变），AC-1「user scope 无 .git → 只装源文件」未声明此边界。
**consequence**: 冗余 mkdir 无害；~/.git 边界未声明可能让用户意外把 pre-commit 接入 dotfiles 仓库而不自知。
**remedy**: 草案去掉显式 mkdir（或注明防御性冗余）；AC-1 补一句「$HOME 已有 .git 时 user scope 仍按项目级语义接线」。

---

**verdict**: pass

---

## 主 agent 响应（L2 round 1 verdict=pass）

所有发现已处置：

### 🟡 #1（双源测试遗漏）→ Fixed
影响清单 L51 补 `test/test_archive_commit_gate.bats`（dev 源）+ 声明双源同步机制（`make test-sync` + `make check` check-test-sync diff 验证）。

### 🟡 #2（负面断言无验证路径）→ Fixed
AC-3 Then 补负面断言（temp HOME 下 install_hooks user scope 后 `test ! -e "$HOME/.git/hooks/pre-commit"` 且 `test ! -d "$HOME/.git"`）。验证方式段 AC-1 (user scope) 补 `test ! -d ~/.git/hooks`。

### 🟢 #3（AC-2 不可执行且重复）→ Fixed
AC-2 改写为「回归锚点声明」，标注行为由 AC-1 项目级 When/Then 三条款完整覆盖，不重复验证步骤。

### 🟢 #4（禁动引用错对象）→ Fixed
禁动碰撞段改为引用实际相关禁动条目（`install_*.sh` 禁外部 source 不禁编辑 + `test/` 禁非 .bats 文件）。

### 🟢 #5（~/.git 边界未声明）→ Fixed
out of scope 补一条：「$HOME 已存在 dotfiles 仓库（~/.git）时 user scope 仍按项目级语义接线（行为不变，非本 change 引入）」。
