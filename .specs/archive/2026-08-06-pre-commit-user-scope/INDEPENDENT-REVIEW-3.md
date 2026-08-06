# 独立审查 · 阶段 3

## L2 盲审（phase 3）

**审查时间**: 2026-08-06T16:05:19+08:00
**verdict**: pass

### 发现

#### #1 [🟡 Important] verify 管道吞 exit code — AC-3「bats 全绿」门禁不可机器强制
**source**: TASK.md:61-62
**symptom**: verify 链中 `npx bats test/ 2>&1 | tail -5 && make check-test-sync 2>&1 | tail -3`。bash 管道退出码 = 最后一条命令（tail）的退出码，bats/make 失败时管道仍返回 0，`&&` 链继续，verify 恒过。
**consequence**: 测试失败（含新增 user scope 行为测试失败、双源不同步）时 TASK 仍可被标记 done——AC-3「npx bats test/ 全绿（0 not ok）」失去机器强制。这正是 CONTEXT 已锁教训 TD-012 的假绿模式（「修 Makefile test target 管道 exit code 漏洞（bats|tail→bats 直接判 exit）」）；本仓库 Makefile:10-11 已为此专门修复（bats 跑两遍，第二遍无管道判 exit）。弱模型看到 tail 输出里有失败行也可能跳过。
**remedy**: 参照 Makefile 既有修复模式，去掉管道或显式检查：`npx bats test/ > /dev/null 2>&1 && echo ok || { echo fail; exit 1; } && make check-test-sync > /dev/null 2>&1 && echo ok || exit 1`（或 `set -o pipefail` + PIPESTATUS 检查）。verify 是 task 级硬门禁，必须能对失败返回非零。

#### #2 [🟡 Important] read_files 缺 REQUIREMENT.md — AC 源文档不在读取清单
**source**: TASK.md:67-72
**symptom**: read_files 仅列 install_hooks.sh / pre-commit.sh / test_archive_commit_gate.bats / DESIGN.md。本 change 的 verify 目标与测试断言全部派生自 REQUIREMENT.md 的 AC-1/2/3（user scope 正负断言、project scope symlink、冲突检测不变、AC-2 回归锚点语义），但 REQUIREMENT.md 不在读取清单。DESIGN §4 只重述测试形状，不承载 AC-2 回归锚点声明与 out-of-scope 边界。
**consequence**: 弱模型无 AC 原文可依据，测试/verify 可能偏离 AC 条款（如漏掉 AC-1 Then-2 的「不 mkdir $HOME/.git」语义、AC-2 的「行为由 AC-1 项目级块覆盖」约束），且无法自查覆盖完整性。
**remedy**: read_files 追加 `.specs/pre-commit-user-scope/REQUIREMENT.md`（若担心体积，可在 action 中引用 AC-1/2/3 全文要点，但读文件是最低成本路径）。

#### #3 [🟢 Minor] verify 中两条 grep 为永真空断言，不检测 guard 位置
**source**: TASK.md:56-57
**symptom**: `grep -q 'install_file.*pre-commit.*pre-commit'` 与 `grep -q 'return 0'` 在修改前（当前 install_hooks.sh:39,43,52）即命中，改前改后恒真。无任何 grep/结构断言验证 install_file 位于 guard 之前；guard 顺序的唯一机器保障是新行为测试（依赖 #1 修复后才有意义）。
**consequence**: 空断言制造「已验证」假象；若行为测试被弱模型写坏（断言写反），verify 无兜底。实际风险低（行为测试的正向断言 `test -f` 在旧 guard 结构下必然失败，能捕获 guard 未移动）。
**remedy**: 删除或替换为有区分度的结构断言，如 `awk '/deploy_pre_commit\(\) \{/,/^\}/' flow-kit-bundle/lib/install_hooks.sh | grep -n 'install_file.*pre-commit' | head -1` 行号 < guard 行号；或依赖 #1 修复后的行为测试并删除这两条空断言。

#### #4 [🟢 Minor] 测试 setup 变量值未具体化 — 弱模型需自行推导
**source**: TASK.md:52
**symptom**: 注意段仅写「设置 SCRIPT_DIR + source install_hooks.sh + 设置 $project/$hook_dst 变量」，未给出值：SCRIPT_DIR 需指向 flow-kit-bundle 根（`${BATS_TEST_DIRNAME}/../flow-kit-bundle`）、user scope 的 hook_dst=`"$HOME/.claude/hooks"`、project scope 的 hook_dst=`"$project/.claude/hooks"`、project=temp repo（含 .git）/HOME（无 .git）。DESIGN §4 注释给出了形状但同样无值。
**consequence**: 弱模型若漏设 hook_dst，install_file 目标退化为 `/pre-commit/pre-commit.sh`（根目录 mkdir 权限错误，测试崩）；若 SCRIPT_DIR 指错，源文件找不到。属可执行性歧义，不阻塞标准 tier 但提高失败回退轮次。
**remedy**: 在 action 测试段补一行具体值示例（或引用现有 test 文件的 `HOOK_BASE_DIR="${BATS_TEST_DIRNAME}/../flow-kit-bundle/hooks"` 模式），如 `local SCRIPT_DIR="${BATS_TEST_DIRNAME}/../flow-kit-bundle"; local hook_dst="$HOME/.claude/hooks"`。

#### #5 [🟢 Minor] AC-1 project scope 冲突检测分支无行为覆盖
**source**: TASK.md:45-47
**symptom**: 两个新行为测试均避开冲突路径（user scope 无 .git 直接 return；project scope 为全新 repo 无既有 pre-commit，冲突块不执行）。AC-1 Then-3「冲突检测（FLOW_KIT_YES=1 skip / read -p 交互）行为不变」与 AC-2 回归锚点无行为测试，仅靠伪代码逐字保留。
**consequence**: 若编辑过程中意外改动冲突块（如把 `-e "$target" && ! -L` 写错），无测试捕获。TASK 伪代码与 DESIGN D1 逐字比对一致，回归风险低。
**remedy**: 可选——补第三条 `FLOW_KIT_YES=1` 冲突 skip 行为测试（伪造既有 pre-commit 文件 + `FLOW_KIT_YES=1`，断言 skip 且不覆盖）；或至少在 done 中显式声明冲突块逐字未动。

---

**Verdict**: pass

> 总评：TASK 单任务（T01）粒度合理（≤200 行），伪代码与 DESIGN §2 D1 逐字对齐（guard 后移 / mkdir 拆分 / 冲突块保留 / symlink 不变），write_files 与 DESIGN §0.5.1 一致（含 test-sync 双源），done 可验证，无内部自相矛盾，无禁动碰撞。无 🔴 Critical。两条 🟡（verify 管道吞码、read_files 缺 REQUIREMENT）建议 task 内修复；三条 🟢 可 defer。

---

## 主 agent 响应（L2 round 1 verdict=pass）

### 🟡 #1（verify 管道吞 exit code · TD-012 复辟）→ Fixed
verify 去掉 `npx bats test/ 2>&1 | tail -5` 和 `make check-test-sync 2>&1 | tail -3` 的管道，改为 `npx bats test/` + `make check-test-sync` 直接判 exit code（与 Makefile L10-11 双跑模式一致）。同时删除两个空断言 grep（`grep -q 'return 0'` 和 `grep -q 'install_file.*pre-commit.*pre-commit'` 永真）。

### 🟡 #2（read_files 缺 REQUIREMENT.md）→ Fixed
read_files 补 `.specs/pre-commit-user-scope/REQUIREMENT.md`。弱模型可读 AC-1/2/3 原文。

### 🟢 #3-5 → Deferred / Minor
#3 空断言已随 #1 一并删除。#4 测试 setup 变量值（SCRIPT_DIR / hook_dst / project）在 DESIGN §4 注释 + install_hooks.sh L86/95 可推导，standard tier 足够。#5 冲突检测分支无行为覆盖，伪代码逐字保留 + 全量 bats 回归兜底，风险低。
