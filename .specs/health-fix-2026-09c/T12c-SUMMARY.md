# T12c-SUMMARY — C13 更名触点收敛（quality_baseline 断言迁移 + 指南/pipeline-gates 引用重锚 · AC-11 配套 · L2 R9）

> 阶段 4（DEV）· health-fix-2026-09c · 前置：T08 done（挂链范式 8808ed6）、T12b done eca69ff
> （check-skills-sync 三判据门禁 + check-gate-sync PAIRS 迁出）。本任务只动 write_files 清单内
> 文件；TASK.md 状态未碰；无 git commit；两个门禁脚本本体零改动（只读）。

## 0. 交付物清单（与 TASK.md write_files 一一对应）

| 文件 | 动作 | 说明 |
|---|---|---|
| test/test_quality_baseline.bats | 修改（125→126 行区段，AC-2 段 −10/+9） | 摘除门禁存在性腿 + 运行腿重锚 |
| flow-kit-bundle/test/test_quality_baseline.bats | 镜像 | cmp 逐字节一致 |
| test/test_skills_sync.bats | append（155→181 行，尾部 +26） | T12c 迁移承接腿 ×2 |
| flow-kit-bundle/test/test_skills_sync.bats | 镜像 | cmp 逐字节一致 |
| FLOW-KIT-用户指南.md | 修改（:1585 单行） | 17 预设自述按新门禁指名更新 |
| flow-kit-bundle/FLOW-KIT-用户指南.md | 镜像（:1585 同串双写） | cmp 逐字节一致（test_guide_copy_parity md5 面） |
| flow-kit-bundle/flow-kit/reference/pipeline-gates.md | 修改（:4 单行） | check-gate-sync.sh → check-skills-sync.sh（仓内仅此一份，无镜像需求） |

## 1. 语义定夺（关键解读，偏差①的展开）

grep 实证 test/test_quality_baseline.bats 全文**无任何**「预设」/「preset」字面断言——任务块
「预设名断言（旧 PCSC prompt↔skill 比对语义；行号可能漂移）」的实际所指，依
INDEPENDENT-REVIEW-3.md:365-376 R4 Remedy 定死终态：

> 预设名断言摘除、由 T12b 的 test_skills_sync.bats 承接，test_quality_baseline 仅保留
> check-gate-sync 运行断言。

即摘除对象 = AC-2 的 `run test -x flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`
存在性腿（旧 :29-32，任务块锚 :26,29-30 附近）；保留 AC-2 运行腿并重锚到 check-gate-sync
的门禁语义（gate-config 预设键值对同步，exit 0=预设键值对一致 / 1=发现预设键值漂移 /
2=脚本错误——断言 `[ "$status" -ne 2 ]` 维持不变）。

## 2. 迁移逐锚表（旧锚 → 处置 → 新锚）

| 旧锚（test/test_quality_baseline.bats） | 旧内容 | 处置 | 新锚（承接位置） |
|---|---|---|---|
| 舊 :29-32（AC-2 存在性腿） | `@test "AC-2: check-gate-sync.sh 存在且可执行"` = `run test -x flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` | **摘除** | test/test_skills_sync.bats:163 `@test "T12c 迁移承接: 双同步门禁脚本在位且可执行（check-skills-sync + check-gate-sync）"`——升级为**双门禁**存在性断言：check-skills-sync.sh 与 check-gate-sync.sh 各自 `run test -x` + `[ "$status" -eq 0 ]` |
| 舊 :34-38（AC-2 运行腿） | `run bash …/check-gate-sync.sh` + `[ "$status" -ne 2 ]`（语义注释为旧「prompt↔skill 比对」口径） | **保留重锚**（新 :35 起） | 原地：段注释改写为「check-gate-sync.sh（gate-config 预设键值对同步门禁）运行断言」+ T12c 迁移说明（旧 PCSC 内容比对语义已归 check-skills-sync；载体收敛 test_skills_sync / test_check_gate_sync） |
| 舊 :25-28（AC-2 段头注释） | 旧口径描述 | 改写 | 同段（新 :26-34），补 T12c/health-fix-2026-09c/C13/L2 r3 R4 修订溯源注释 |
| （防回潮，新增） | — | **新增** | test/test_skills_sync.bats:170 `@test "T12c 迁移承接: quality_baseline 已摘除门禁存在性腿（断言归属收敛，防回潮）"`——`run grep -c 'run test -x flow-kit-bundle/flow-kit/reference/check-gate-sync.sh'` 对两副本（test/ 与 flow-kit-bundle/test/ 的 test_quality_baseline.bats）断言 `[ "$status" -ne 0 ]` + `[ "$output" = "0" ]` |
| FLOW-KIT-用户指南.md:1585（+ bundle 镜像 :1585） | 「并由 `flow-kit/reference/check-gate-sync.sh` 守护与测试同步」 | **双写更新** | 同行：「守护预设键值对与测试同步（skill 薄壳 ↔ prompt 权威载体的同步门禁为 `flow-kit/reference/check-skills-sync.sh`，两者各司其职）」——verify 的 `grep -c check-gate-sync ≥1` 与 `check-skills-sync ≥1` 双计数均落此行 |
| flow-kit-bundle/flow-kit/reference/pipeline-gates.md:4 | 「改完后运行 `check-gate-sync.sh` 确认 prompt↔skill 一致」 | **引用迁移** | 同行：「改完后运行 `check-skills-sync.sh` 确认 skill 薄壳 ↔ prompt 权威载体同步（T12c · health-fix-2026-09c：原『prompt↔skill 一致』判据由 check-skills-sync 承接）」——TD-030 存量只改引用；该文件 check-gate-sync 计 0 |

## 3. verify 真实输出（任务块原文 + 补充）

```
$ npx bats test/test_quality_baseline.bats && npx bats test/test_skills_sync.bats \
  && test "$(grep -c 'check-skills-sync' FLOW-KIT-用户指南.md)" -ge 1 \
  && test "$(grep -c 'check-gate-sync' FLOW-KIT-用户指南.md)" -ge 1 && make check-test-sync
1..15
ok 1 AC-1: pipeline-gates.md 存在
ok 2 AC-1: 4-dev prompt 引用 pipeline-gates
ok 3 AC-1: flow-dev skill 引用 pipeline-gates
ok 4 AC-2: check-gate-sync.sh 运行无脚本错误
ok 5 AC-3: Makefile 存在
ok 6 AC-3: make test target 定义存在
ok 7 AC-3: make lint target 定义存在
ok 8 AC-3: make check target 定义存在
ok 9 AC-3: make lint (或 shellcheck 未装时 skip)
ok 10 AC-4: pre-push hook 存在且可执行
ok 11 AC-4: pre-push hook 调用 make check
ok 12 AC-5: test_stop_chain.bats 存在
ok 13 AC-5: stop 链 smoke tests 全绿
ok 14 AC-6: shellcheck 无 error 级别问题
ok 15 AC-7: test/ 与 flow-kit-bundle/test/ 一致
1..12
ok 1 T12b: check-skills-sync.sh 存在且可执行
ok 2 T12b 基线: 真实树 → rc=0 + 覆盖 15/15 + 不复制 comm=0 + @see 全可解析
ok 3 T12b 沙箱基线: 完整夹具 → rc=0（判据有牙，非恒红）
ok 4 T12b ①覆盖反向: 删受辖 skill（flow-test/SKILL.md）→ rc≠0 + 🔴 MISSING 具名
ok 5 T12b ②不复制反向: SKILL.md 抄入 prompt 正文行 → rc≠0 + 🔴 DUP 具名
ok 6 T12b ②不复制反向: 同行数改内容不短路（R5-10 ③ 迁移承接腿）
ok 7 T12b ③@see 反向: @see 指向不存在文件 → rc≠0 + 🔴 SEE 具名（行号）
ok 8 T12b ③@see 反向: § 小节指向不存在标题 → rc≠0 + 🔴 SEE（任务块原文腿）
ok 9 T12b 豁免面: 未登记 flow-* 目录（flow-foo）→ rc≠0 + 🔴 UNREGISTERED（白名单外不得静默）
ok 10 T12b ①覆盖反向: 删权威载体 prompt 小节必红的实现面（prompt 文件缺失 → MISSING 具名）
ok 11 T12c 迁移承接: 双同步门禁脚本在位且可执行（check-skills-sync + check-gate-sync）
ok 12 T12c 迁移承接: quality_baseline 已摘除门禁存在性腿（断言归属收敛，防回潮）
🔍 make check-test-sync: test/ ↔ flow-kit-bundle/test/ ...
✅ test 双源一致
TASK_VERIFY_EXIT=0

$ npx bats test/test_quality_baseline.bats test/test_skills_sync.bats   # 补充合并跑
1..27 → 27 ok / 0 not ok（COMBINED_EXIT=0；尾部 ok 26/27 = 两条 T12c 腿）
```

## 4. 六维自查

1. **write_files 边界**：本任务产生改动 = write_files 7 文件（根树 5 文件 M + 2 镜像 cp M）；
   porcelain 其余 M/??（CHANGE.md、MINOR-DEFERRED.md、hooks/stop/lib/common.sh、6 个测试
   文件 ×2 树、.specs/ 下未跟踪件）均为父波次或兄弟 T15 在途，非本任务产生（会话起点
   porcelain 基线 + 过程 git status 实证，见偏差②）。
2. **TASK.md 状态**：未读改任务状态区（只读 :404-427 T12c 任务块）。
3. **禁碰面**：无 git commit；.flow-active 未动；check-gate-sync.sh / check-skills-sync.sh
   本体零改动（只读引用）；dist/ 两份指南副本未手改（波末重建）。
4. **镜像双写**：两 bats 镜像 cmp 逐字节一致（MIRROR OK ×2）；指南根↔bundle 副本 cmp 一致
   （GUIDE MIRROR OK，grep 计数 check-skills-sync=1 / check-gate-sync=1）；
   pipeline-gates.md 仓内仅一份（recon 实证无镜像）。
5. **SUMMARY 无真名路径**：全文无家目录/用户名字面。
6. **bats set -e 纪律**：期望非零处全部 `run` + status 断言（防回潮腿 grep -c 计 0 退出码 1
   场景 `[ "$status" -ne 0 ]`；运行腿 `[ "$status" -ne 2 ]` 沿用），无 `!` 前缀反直觉写法。

## 5. 偏差登记

1. **「预设名断言」无字面命中**（见 §1）：任务块口径「quality_baseline :26,29-30,34-35 附近
   预设名断言」grep 实证无 '预设'/'preset' 字面；依 INDEPENDENT-REVIEW-3.md:365-376 R4
   Remedy 终态解读为摘除 AC-2 `test -x` 存在性腿 + 运行腿重锚。承接腿升级为双门禁
   （check-skills-sync + check-gate-sync），超出「仅 check-gate-sync 存在性」的最小承接，
   理由：AC-11 双门禁语义下两个脚本的存在性同等重要，且防回潮腿已断言旧腿不再回流。
2. **AC-7 瞬态假红 ×2**：全文件 bats 长跑（AC-5 嵌套 stop 链套件 + AC-9 make lint，秒级窗口）
   期间兄弟 T15 在途写 6 个测试文件双树（git status 实证 M 状态 8 文件双树 = 本任务 2 +
   兄弟 6），diff 窗口恰落编辑半程 ⇒ AC-7 not ok；两次均以「跑后即时 `diff -rq` 全净 +
   `npx bats -f 'AC-7'` 隔离跑绿」自证非本任务引入；最终重跑全绿（ok 15）。另注：cp 镜像
   落盘前的一次 AC-7 红与 skills_sync 腿 12 红为**真红**（镜像未同步），cp 后消解。
3. **指南 make check 六门表滞后（观察不修）**：指南 :941 附近门表与 Makefile 实链
   （已含 check-gate-sync / check-skills-sync / check-path-privacy / check-nfr-portability）
   不一致——超出本任务 :1585 锚点范围，未动，留编排者后续波次。
4. **全量 make test 未跑**：任务纪律明令禁跑（兄弟 T15 并行 flock 互锁，全量归编排者波末），
   非偷懒省略。
