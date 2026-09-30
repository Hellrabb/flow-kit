# T04-SUMMARY — C2 隐私正则收紧（AC-3）

change-id: health-fix-2026-09c · task: T04 · phase: 4-DEV
执行者：T04 dev agent（fresh context，仅本任务）

## 1. 做了什么

按 TASK.md:113-132 与 DESIGN.md D9-C2(a) 决策执行：维持既有机制（单一通用 PAT + PLACEHOLDER_NAMES 占位排除），不引入真名新正则。四处门禁面改动 + bats 钉行为 + 镜像手动双写。

## 2. 改动清单

### 2.1 flow-kit-bundle/flow-kit/reference/check-path-privacy.sh（+50 行净增）

| 位置 | 改前 | 改后 |
|---|---|---|
| PAT（原 :72） | `PAT='/home/[a-z_][a-z0-9_-]*/'`（必须尾斜杠） | `PAT='/home/[a-z_][a-z0-9_-]*([^a-z0-9_-]|$)'`（路径段边界形态：裸 `/home/<realname>` 无尾斜杠也命中；realname 后必须是行尾/引号/空白/斜杠等非路径段字符） |
| PLACEHOLDER_NAMES（原 :77） | `'user ubuntu acct yourname foo bar someone'`（7 个） | `'user username ubuntu acct yourname your-user your_user me myuser testuser example demo foo bar baz someone developer'`（18 个，REQUIREMENT NFR-安全 节全集；刻意不加 `test`——09b INDEPENDENT-REVIEW-3 裁决禁入排除表；不加 `alice`——09b IR-2 真名漏报样例） |
| 用户名提取 sed（原 :497） | `s#^/home/([a-z_][a-z0-9_-]*)/$#\1#p` | `s#^/home/([a-z_][a-z0-9_-]*).*$#\1#p`（首组贪婪吃满路径段=用户名，`.*` 吃边界字符；不改则裸 `/home/user` 抠空 uname → 占位名误判真名 ⇒ 假红） |
| 头部（:9 `set -uo pipefail` 前） | 无 | T04 块：行为变化说明 + 【下游误报处置入口】grep 锚点（`grep -n '下游误报处置入口' 本文件` 命中 :70）+ 三步处置（①占位写法→补 PLACEHOLDER_NAMES ②真泄漏→修内容、禁白名单掩盖 ③审查/基线字面→allowlist 按 `file:line 理由` 登记） |

边界字符类取广义 `[^a-z0-9_-]`（非任务原文列举的仅 `/"' ` ）：点号、大写等同样构成边界，隐私门禁宁严勿松；实测 `/home/fooBar` → 提取 `foo`、`/home/⟨alice-doc⟩/x` → 整段消费 `alice-doc` 不截断、不误伤更长真实目录名。

**未动**：白名单读序三层逻辑（:98-102 常设>change>双缺 fail-closed）、SELF_EXCLUDE 6 条冻结、行粒度归因（同行多命中记 1 条）。

### 2.2 test/test_path_privacy_gate.bats（35 → 39 用例）

- :33 探针修正：`PROBE="/home/""zz-path-pr""obe/"`（自带尾斜杠，夹具把待测形态写错）→ `PROBE="/home/""zz-path-pr""obe"`（裸形态）；20 处 `${PROBE}` 用法显式拼 `/` 保持原被测字符串（`${PROBE}host`→`${PROBE}/host` 等）。
- 文末追加 T04 节 + 4 个新用例（均带 `T04:` 前缀，verify 计数锚）：
  1. 裸 `/home/<realname>`（无尾斜杠 · 行尾）⇒ 命中 rc=1 且归因 file:line
  2. 裸 `/home/<realname>` 双引号/反引号包裹（非行尾边界）⇒ 同样命中 rc=1
  3. 裸占位名不误报（user/me/username/your-user 行尾 + `<user>` 尖括号形态）⇒ rc=0（同时钉 sed 修正与扩表）
  4. 路径段边界形态：同前缀长段名（`-doc`）整段消费、点号后缀截断边界 ⇒ 均命中 rc=1

### 2.3 flow-kit-bundle/test/test_path_privacy_gate.bats

镜像手动双写（`cp` + `diff -q` IN-SYNC 确认）；遵父指令未跑 `make test-sync` / `make check-test-sync`。

## 3. verify 真实输出

```
$ test "$(grep -c '@test .*T04:' test/test_path_privacy_gate.bats)" -ge 1 && npx bats test/test_path_privacy_gate.bats
（grep -c = 5：4 个真用例 + 1 行节注释含锚点字样；≥1 ✅）
...
ok 33 T-FIX-17③：rev 形态计时 5 次 CHECK_REV=HEAD 实测均 ≤5 s（R5-16 批量化回到预算内）
ok 34 T-FIX-17④：反向控制——摘掉磁盘侧 -e/-- 保护 + 还原候选循环共用 stdin ⇒ 腿①必须转红（还原后转回 ok）
ok 35 T-FIX-24：SELF_EXCLUDE 成员集合精确等于冻结 6 条；副本注入伪条目（新增审查档）⇒ 膨胀 not ok，去行复绿（豁免面冻结 · L-149/TD-054）
ok 36 T04: 裸 /home/<realname>（无尾斜杠 · 行尾）⇒ 命中 rc=1 且归因 file:line
ok 37 T04: 裸 /home/<realname> 双引号/反引号包裹（非行尾边界）⇒ 同样命中 rc=1
ok 38 T04: 裸占位名不误报（user/me/username/your-user 行尾 + <user> 尖括号形态）⇒ rc=0
ok 39 T04: 路径段边界形态：同前缀长段名（-doc）整段消费、点号后缀截断边界 ⇒ 均命中 rc=1
39 tests, 0 failures（35 既有 + 4 新全绿；T-FIX-17③ max=0.062s）
```

辅助检查：`bash -n` OK；`shellcheck -S warning` rc=0 零告警。完整输出落档 /tmp/t04-bats.log。

## 4. 破坏性变更协议（PAT 属门禁判据 · R4.6）

- **grep 引用面（改前）**：PAT 消费点全在 SUT 内部——:415 自证打印、:491 `grep -oE "$PAT"`（占位排除）、:625/:646/:761/:844 `git grep -naE`、:686 磁盘侧 `grep -naE -e "$PAT"`；仓内对外引用仅 .specs 历史档（HEALTH/archive 审计记录），无活门禁对账依赖旧字面 ⇒ 无外部破坏面。
- **联动修正**：:497 提取 sed 强制尾斜杠，必须随 PAT 同改（已改，见 2.1；bats 用例 ③ 钉住）。
- **回归**：全量 bats 39/39 绿（见第 3 节）。
- 反问用户：父任务书已显式指定 PAT 放宽为 T04 目标并给出形态要求，视为已确认；形态取广义边界是唯一自主裁量点，已记录依据。

## 5. 观察与移交（非 verify 要求，供后续任务情报）

只读实跑本仓门禁对比（不改任何仓文件，/tmp 副本执行）：

- **改前**（HEAD 原版）：rc=0，命中合计 0 条、清单外命中 0 条 —— 本仓当前全绿。
- **改后**（T04 版）：rc=1，候选 1627 个、命中合计/清单外命中 47 条。分布：.specs/archive/2026-09-28-health-fix-2026-09b/INDEPENDENT-REVIEW-2.md 14、.specs/health/2026-09-22-FULL-SWEEP.md 11、INDEPENDENT-REVIEW-1.md 6、.specs/STATE.md 4、INDEPENDENT-REVIEW-7.md 4、T13-SUMMARY.md 3、LESSONS.md 2、CONTEXT.md 2、INDEPENDENT-REVIEW-3.md 1。
- 定性：C2 放宽的**预期红窗口**（DESIGN R6 已编码 C2→C3 偏序）：旧 PAT 下不可见的裸形态/引号形态真名字面（多为历史审查档里的审计引文）现在暴露。归 T05+（tracked 脱敏 / allowlist 登记）收口，非 T04 回归。落档 /tmp/t04-realgate.log、/tmp/t04-realgate-before.log、/tmp/t04-sut-orig.sh。

## 6. 6 维自查（内置快查）

- ✅ R1 认知过载：无新函数；改动为常量重定义 + sed 单行 + 注释块，SUT 逻辑路径未增。
- ✅ R2 变更传播：diff 仅 3 个 write_files 文件（git status 中其余 M/?? 为同波次兄弟任务在途改动，本会话未触碰）。
- ✅ R3 知识重复：无粘贴逻辑；PAT/PLACEHOLDER 单点定义，镜像文件按仓库既定 test-sync 机制双写（未跑工具，遵父指令）。
- ✅ R4 偶然复杂：未加配置项/开关/超前扩展点；边界类一种形态，无多套并存。
- ✅ R5 依赖混乱：bash 脚本无 import；bats 夹具仍运行时 cp 真实 SUT（活性测试范式沿用）。
- ✅ R6 领域扭曲：命名沿用 PAT / PLACEHOLDER_NAMES / PROBE 既有领域词；新用例名含业务语义（裸路径/占位/边界）。
- 🔴 必修：0；🟡 记录：广义边界类 `[^a-z0-9_-]` 比任务原文举例（`/"' `）更严——隐私门禁宁严勿松，依据与实测见 2.1；🟢 可省：无。

## 7. 沿用既有抽象 grep（R6.4）

- 占位排除机制：`grep -n 'PLACEHOLDER_NAMES'` → SUT 既有（:77/:487-497 一带 is_placeholder_name 精确比对）→ 沿用扩表，未新建并行名单。
- 门禁 PAT：`grep -rn "PAT=" flow-kit-bundle/ test/` → 唯一定义于 SUT :72，消费点全内部 → 原地收紧，无旁路副本。
- 误报处置入口：`grep -n '下游误报处置入口'` → 本任务新建（REQUIREMENT NFR-安全 明文要求头部登记）。

## 8. 越界检查（R6.5）

- TASK write_files：3 项（SUT + 主 bats + 镜像 bats）+ 本 SUMMARY。
- 本会话实际 diff：3 项 + 本 SUMMARY（未跟踪 .specs/health-fix-2026-09c/ 下新文件），与 write_files 一致。
- 越界：0。git status 中 .specs/CONTEXT.md、LESSONS.md、STATE.md、hooks/×5、test_check_gate_sync.bats ×2、test_fail_closed.bats、test_l3_backlog_alarm.bats 等为兄弟任务在途改动，非本会话所写。
- 禁项自查：未 git commit、未改 .flow-active、未改 TASK.md 状态、未跑 make test-sync / check-test-sync、未动白名单三层读序。
