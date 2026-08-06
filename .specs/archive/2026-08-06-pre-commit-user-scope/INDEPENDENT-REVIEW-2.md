# 独立审查 · 阶段 2

## L2 盲审（phase 2）

**审查时间**: 2026-08-06T16:00:55+08:00
**审查 agent**: L2 blind review (unspecified-high)
**verdict**: pass

### 发现

#### #1 🟡 Important · D1 伪代码冲突检测块为注释占位，不可被弱模型照抄执行
**source**: DESIGN.md:58-60（§2 D1 伪代码 `if [[ -e "$target" && ! -L "$target" ]]; then # 冲突检测（FLOW_KIT_YES=1 skip / read -p 交互）— 逻辑不变 fi`）
**symptom**: 伪代码中 if 块体被替换为单行注释，实际逻辑（FLOW_KIT_YES=1 早退、`read -p` 交互、`rm -f "$target"`，对应现码 install_hooks.sh:46-54 共 9 行）需实现者凭记忆重建。按 protect-the-weakest 已锁决策与本次审查重点「伪代码可被弱模型照抄执行无歧义」，此占位符不达标——照抄产物将是空 if 块或残缺逻辑。
**consequence**: 弱模型实现时若丢失 `FLOW_KIT_YES=1` 早退分支，`install.sh --yes`（test_archive_commit_gate.bats:95-97 有 grep 断言的功能）在冲突场景将回落到交互 `read -p` 而非静默跳过，破坏既有用户可见行为；丢失 `rm -f` 则冲突文件永不被替换，symlink 创建静默失败。
**remedy**: 将现码 install_hooks.sh:45-54 的完整冲突检测块逐字贴入伪代码（仅 `$target` 沿用新局部变量），或显式标注「照抄 L45-54 原文，不得改写」。

#### #2 🟡 Important · §4「既有测试已覆盖（回归确认）」与事实不符——现有测试仅 grep 级断言
**source**: DESIGN.md:102-104（§4 第二个测试草图注释「既有测试已覆盖（回归确认）」）
**symptom**: 实测 test/test_archive_commit_gate.bats T05（L95-105）全部是 grep 断言（`deploy_pre_commit` 函数定义存在 / 调用存在 / FLOW_KIT_YES 存在），**没有任何测试执行 install_hooks 项目级路径验证 symlink 创建**。所谓「既有测试已覆盖」不存在。
**consequence**: 本次改动恰好在 project scope 路径动了 mkdir（合并→独立）与 guard（前移→后移）——正是回归高危区。设计据此省略项目级行为测试后，若实现引入 project scope 回归（如 mkdir 丢失、guard 位置错误导致 symlink 永不创建），无任何测试兜底，且 REQUIREMENT AC-1 项目级三条款依赖该覆盖声明成立。
**remedy**: 新增 project scope 行为测试（temp repo 含 `.git` → source install_hooks project scope → 断言 `-L "$repo/.git/hooks/pre-commit"` + readlink 指向已装源文件 + 源文件存在），或将注释改为「新增」，并在 TASK 中落实。

#### #3 🟢 Minor · 风险表「语义不变」在 DRY_RUN 模式下不成立
**source**: DESIGN.md:84（风险表第 2 行「mkdir 从合并拆为独立但语义不变」）
**symptom**: 实证（bash 模拟 CASE3）：旧代码 `mkdir -p "${project}/.git/hooks" "$hook_dst/pre-commit"` 在 DRY_RUN 下仍真实创建两个目录；新代码中 `$hook_dst/pre-commit` 的创建移入 install_file（L27 受 `DRY_RUN` guard），DRY_RUN 下不再创建该目录。即 DRY_RUN 模式下语义**有变**（且新行为更正确——DRY_RUN 不应建目录）。
**consequence**: 若未来有测试断言 dry-run 后 `~/.claude/hooks/pre-commit/` 存在则失败（当前 test_install_dry_run.bats 无此断言，实际影响为零）。
**remedy**: 风险表该行补充一句「DRY_RUN 下不再创建 $hook_dst/pre-commit 目录（旧代码会创建），无测试依赖，视为改进」。

#### #4 🟢 Minor · ADR-023 未记录被否决的替代方案
**source**: DESIGN.md:71-77（ADR-023 仅含决策/理由/影响）
**symptom**: 未记录已否决的替代结构——(a) 将 symlink 段整体包进 `if [[ -d "${project}/.git" ]]` 而非 `|| return 0` 早退；(b) 拆分为 `install_pre_commit_source()` + `link_pre_commit()` 两函数。
**consequence**: 决策可追溯性弱：后续维护者无法判断「早退式」是深思熟虑还是随手选择；早退式在函数尾部再追加代码时会意外跳过（return 截断），`if` 包裹式无此陷阱——该权衡未留痕。
**remedy**: ADR-023 补「备选方案」段（一行即可）：否决 (a) 因函数线性流程下早退等价且更短；否决 (b) 因 34 号模块已注册、无复用场景，拆函数违反 YAGNI。

#### #5 🟢 Minor · 测试草图 `(or DRY_RUN)` 与正向断言自相矛盾
**source**: DESIGN.md:96（测试草图注释「run install_hooks "$HOME" "user" (or DRY_RUN)」）
**symptom**: DRY_RUN=true 时 install_file 仅 echo 不落盘（install_hooks.sh:24-25），若实现者照抄选择 DRY_RUN 路径，紧随的正向断言 `test -f "$HOME/.claude/hooks/pre-commit/pre-commit.sh"`（L97）必然失败。
**consequence**: 弱模型照抄歧义指令 → 选择 DRY_RUN → 测试假红或被迫加 hack，浪费一轮 fix loop。
**remedy**: 删除 `(or DRY_RUN)`，明确「必须实跑（非 DRY_RUN），temp HOME 隔离」；DRY_RUN 变体如需保留另立 @test。

### 已验证通过项（实证）

- §1 根因描述准确：guard 位于 install_hooks.sh:39（源文件安装 L43 与 symlink L56 之前），user scope（install.sh:243 `install_hooks "$HOME" "user"`）经 install_hooks.sh:137 调用点进入 → return 0 → 源文件未装。✓
- §2 核心 bash 语义成立（模拟 CASE1/2/4）：user scope 装源文件且不建 `~/.git`、不建 symlink；project scope symlink 正确指向已装源文件；冲突+拒绝时用户 hook 保留且源文件仍装。✓
- 「install_file 内部 mkdir 覆盖显式 mkdir」属实：install_hooks.sh:27 `mkdir -p "$(dirname "$dst")"`，`dirname "$hook_dst/pre-commit/pre-commit.sh"` = `$hook_dst/pre-commit`，完全覆盖被删除的显式 mkdir。✓
- §0.5.1 触碰清单与 REQUIREMENT 影响清单（REQUIREMENT.md:55）逐项一致，write_files 合理（bundle 测试副本由 `make test-sync` 同步，Makefile:47-48 确认存在）。✓
- ADR-023 核心论据「user scope 全 hook 源文件统一安装」属实：stop（L110-113）/session-start（L122-125）/pre-tool-use（L129-135）均无条件 install_file 到 `$hook_dst`，pre-commit 是唯一因 guard 位置例外者。✓
- L-031 跨文件扫描：`deploy_pre_commit` / `pre-commit` 全仓命中（install_hooks.sh 唯一逻辑点、install.sh 调用点、package-flow-kit.sh/validate_staging.sh 打包 glob、测试）均不受影响或已列入清单，无漏改点。✓
- 调用点 install_hooks.sh:137 `deploy_pre_commit` 不依赖 scope 判断，改后 user/project 均经同一函数——设计 §5「调用点不变」属实。✓

**verdict**: pass

---

## 主 agent 响应（L2 round 1 verdict=pass）

所有发现已处置：

### 🟡 #1（冲突检测块注释占位）→ Fixed
D1 伪代码冲突检测块补逐字 verbatim（FLOW_KIT_YES check + read -p + rm -f，与 install_hooks.sh:45-54 完全一致）。弱模型照抄不再丢失逻辑。

### 🟡 #2（「既有测试已覆盖」为假）→ Fixed
§4 测试策略改为：新增 user scope + project scope 两个行为测试（现有仅 grep 级断言，无行为覆盖）。project scope 测试断言 symlink + readlink 指向 + 源文件存在。

### 🟢 #3（DRY_RUN mkdir 语义微变）→ Fixed
§3 风险表补一行：DRY_RUN 下旧代码显式 mkdir 创建目录、新代码 install_file DRY_RUN 只 echo 不 mkdir → 目录不创建。行为更正确，无测试依赖。

### 🟢 #4（ADR-023 未记录否决方案）→ Deferred
ADR-023 决策合理性成立（unified pattern 论据属实），否决方案记录属文档完整性问题，不阻塞。可在 7-integration 归档时补 ADR 格式。

### 🟢 #5（测试草图 DRY_RUN 歧义）→ Fixed
§4 测试策略明确「禁止 DRY_RUN 模式」+ 说明原因（install_file DRY_RUN 只 echo 不创建文件 → 正向断言必然失败）。
