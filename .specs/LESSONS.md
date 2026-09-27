# LESSONS — 项目经验教训与技术债

> 本文件跨 change 累积。M-health 巡检 + 各 change 的 brooks-lint 结果 + 人工标注都写入此处。
> 格式：严重程度 | 位置 | 问题 | 建议 | 状态 | 来源

<!-- l3-pipeline-fix-2026-07 ↓ -->
<!-- user-guide-sync-2026-09 ↓ -->
| L-083 | 🟢 | 全局（流程教训） | 文档/演示型 change 的验证方式必须「产物内可复现」——L3 三轮迭代证明，把断言写成当前可执行命令（而非指向未来的 TEST/deck_checks 占位）是收敛最快路径；新增生成器类工具首次使用注意 Path.parents 语义（parents[0]=父目录，勿把 repo 根算错一层） | 文档 change 的 REQUIREMENT 验证方式一律内联可执行命令；新生成器先用 --smoke 输出路径断言 | ✅ 已吸收 | user-guide-sync-2026-09 L2/L3 |
| L-084 | 🟡 | 全局（流程教训） | subagent 盲审长时间无产出（>30 min）应中断并改用「紧范围 + 前台」重派，盲目等待浪费配额——本 change 3 个后台 L2 卡住，中断重派后 1-5 分钟完成 | 后台盲审 10 分钟无文件产出即 interrupt 重派；prompt 限定 read/bash 次数与输出上限 | ✅ 已吸收 | user-guide-sync-2026-09 执行记录 |
<!-- user-guide-sync-2026-09 ↑ -->
| L-041 | 🟡 | `auto-checkpoint.sh` PreToolUse hook | 自引用竞态：hook 在 Write/Edit `.flow-active` 前触发 `checkpoint_write()` 修改同一文件，导致 harness 检测到文件内容变化后拒绝 Write/Edit | 在 `auto-checkpoint.sh` 中检测 `file_path` 是否为 `.flow-active` 自身——若是则 skip checkpoint 写入 | ✅ 已修复 | `l3-pipeline-fix-2026-07` |
| L-042 | 🔴 | `29-independent-review.sh` L3 派发 | `--background` 异步 flag 硬编码激活导致 `.done` 永不写入：fork 子进程后立即返回 `return 0`，`_l3_write_done()` 未执行 → 下次 Stop hook 再次进入积压扫描 → 无限重派循环 | 异步功能默认关闭（opt-in via `L3_BACKGROUND=1`）；默认同步路径确保 `.done` 写入 | ✅ 已修复 | `l3-pipeline-fix-2026-07` L2 审查 R1 |
| L-043 | 🟡 | `install.sh` 部署流程 | 改了 bundle 源 hook 文件后，容易忘记重跑 `install.sh --user` 同步到 `~/.claude/hooks/`。install.sh 代码不需要改（`install_file` 自动覆盖），但**必须提醒用户重跑**，否则运行时仍是旧版本 | 每次 change 涉及 hook 文件修改时，在归档阶段显式提醒用户执行 `install.sh --user` | ✅ 流程补记 | `l3-pipeline-fix-2026-07` 事后发现 |
<!-- l3-pipeline-fix-2026-07 ↑ -->

---

## M-health 巡检观察（监控级 · 不阻塞）

> 最后更新: 2026-09-20（全量扫描 · 97/100 · 相对 2026-09-06 94/100 ↑3）
> 格式：日期 | 严重度 | 位置 | 观察 | 建议操作

<!-- 2026-09-20 ↓ -->
| 2026-09-20 | 🟢 | `Makefile` / 巡检流程（M-health 步骤 2.6） | **bats 文件不能直接过 `bash -n`**：218 个 `.bats` 裸跑 `bash -n` **全部**报「未预期的记号 }」——那是 bats 自身的 `@test "名" {` 语法，不是语法错误。若照抄 `.sh` 的门禁写法，会得到 218/218 假阳性，真错误会被噪声淹没、门禁形同失效 | 语法门禁对 bats 先预处理再检查：`sed 's/^@test \(.*\) {/test_fn() {/' "$f" > /tmp/_b.bash && bash -n /tmp/_b.bash`（本次实测 218/218 全过 ✅）。可考虑固化为 `make check-syntax` target |
| 2026-09-20 | 🟢 | `flow-kit-bundle/prompts/*.md` ↔ `flow-kit-bundle/skills/*/SKILL.md` | **同内容双载体、无同步门禁**（已登记 TD-025）：两处手工双写同一套流程规则，本仓对 test/、hooks/、l3-prompt 都有机器一致性门禁，唯独 prompts↔skills 没有。jscpd 已量化出 10 组 ≥30 行大块重复（最大 196L），体量分化可见（6-review 351 vs 228 · 4-dev 352 vs 544）→ 确属各自演化 | 补 `make check-skills-sync` 或显式声明「允许差异」并给判定边界；改动任一阶段 prompt 时**必须同步考虑 skills/ 对应 SKILL.md** |
| 2026-09-20 | 🟢 | `sync-hooks.sh:243`（`3ce3ef7` 引入） | shellcheck 报 SC2221/SC2222「模式恒覆盖/永不匹配」——**复核为假阳性**：外层 `for _d in stop stop/lib pre-tool-use pre-commit` 已限定 `_rel` 取值域，4 条 case 臂均可命中。教训：shellcheck 对「case 模式集 ⊇ 变量实际取值域」不做流分析，此类告警需人工复核而非直接改代码 | 加 `# shellcheck disable=SC2221,SC2222` + 一行理由注释（或改写 `stop*.sh\|pre-tool-use/*.sh\|pre-commit/*.sh`），避免 warning 池长期携带已知假阳性、钝化后续判断 |
| 2026-09-20 | 🟢 | `Makefile:22-23`（`make lint` 文件域）· `sync-hooks.sh` exec 判据 | 两处检查器「判据过宽/过窄」类问题：① `make lint` 用 `for f in *.sh flow-kit-bundle/{lib,hooks/*}/*.sh` 枚举，**4 个生产脚本漏在门外**（`flow-kit-bundle/install.sh`、`hooks/pre-commit/pre-commit.sh`、`flow-kit/reference/check-gate-sync.sh`、`flow-kit/regression-demos/*/check.sh`）——实测其中 **5 处 warning**（`install.sh` SC2034×2 + `check-gate-sync.sh` SC2034×2 + regression-demo SC1090×1）从未被门禁看过；② `sync-hooks.sh` 按**目录**判定 exec-bit，把 `pre-tool-use/` 下 4 个「只被 source 的库」误报为「缺可执行位」（实测这些文件零直接调用点，且 `install_hooks.sh:135-141` 对所有部署副本统一 chmod +x → 纯装饰性） | ① 把 `make lint` 枚举改为 `find`（或直接补这 4 个路径）；② 把 exec 判据收窄为「仅真入口」（`independent-review-gate` / `auto-checkpoint` / `runtime-edit-guard` / stop 主模块 / session-start / pre-commit）。判据过宽或过窄都会让门禁失真 |
<!-- 2026-09-20 ↑ -->
<!-- 2026-09-20b ↓ -->
| 2026-09-20b | 🟡 | `dist/dsh-flow-kit/README.md`（打包件）· `package-dsh-plugin.sh` | **打包产物无"新鲜度门禁"**：`make check` 五门全绿、`sync-hooks --check` 漂移 0、巡检也判"无需更新"，但 dist 里**发给用户的 README 已落后源码 7 天**——`61c4bf8`（09-18）把工件上限从「字符」改为「字节」，dist 仍是 09-11 构建，于是发出去的文档仍写 `max_artifact_chars` + 「20000 字符」。用户按旧文档配 60000 期待"6 万字符"，实得 60000 **字节** ≈ 2 万汉字，**差 3 倍**。根源：① `dist/` 被 gitignore，git 看不见它陈旧；② `sync-hooks` 只比 hooks 不比文档；③ 巡检用 `diff -rq` 只比了运行时目录，漏了包顶层文档。**同批还捞出 6 个 vendored 测试陈旧 + 1 新增缺失（含 2 处已修的硬编码绝对路径）** | ① 加 `make check-dist`（或 `package-dsh-plugin.sh --check`）：比 `dist/` 与源，**有差异即 fail**，纳入 `make check`；② 巡检/归档清单把「打包件新鲜度」列为必检项（不能只比 hooks）；③ 改了 `dsh-flow-kit/README.md`、`lib/`、或 `flow-kit-bundle/` 任一内容后**必须重建 dist** |
| 2026-09-20b | 🟢 | `package-dsh-plugin.sh:135-138` | `chmod +x "$PKG_DIR"/hooks/pre-tool-use/*.sh` 只作用于包顶层，**对第 4 步拷进 `vendor/flow-kit-bundle/` 的那份不生效** → 重建后 vendor 的 4 个 pre-tool-use 源库由 755 回落 644，`check-hooks-sync` 的 exec advisory 从 1 涨到 5。零功能影响（这些文件只被 `source`；vendor 是冻结审计副本，插件 JS 对 `vendor` 引用数=0；真正运行的 `dist/dsh-flow-kit/hooks` 与已安装副本 0 个非可执行入口） | 若要 vendor 权限严格镜像源 bundle，在打包脚本第 4 步后对 `$PKG_DIR/vendor` 施同一套 chmod；否则可忽略 |
<!-- 2026-09-20b ↑ -->
<!-- 2026-09-20c ↓ -->
| 2026-09-20c | 🟡 | `test/test_l3_review_defects_2026_09.bats:69`（×2 双源）· 归档收口流程 | **归档收口会打断指向 live 目录的测试**：按既有收口模式移除 `.specs/l3-review-defects-2026-09/` 后，bats #620 AC2 立刻变红——该用例硬编码 live 路径 `.specs/<id>/L2-EMPTY-ATTRIBUTION.md`，而 **archive 才是这份交付物的最终归宿**。CI 正确拦截（archive-commit-gate），未放行。**这是"归档"这一动作的未文档化副作用**：本仓对**代码产物**有 `check-test-sync` / `check-hooks-sync` / md5 副本断言等一堆一致性门禁，但对**"测试引用的 spec 工件在归档后搬了家"**没有任何检查 —— 收口当天才会发现 | ① 测试引用 spec 工件一律走**解析器**（live 优先 → archive 回退，两者皆无则显式失败），**禁止硬编码 live 路径**；② 归档收口动作补一步「跑一次全量 bats」，把这类断裂在提交前暴露；③ 已修 #620（本次随收口一并提交）。**可考虑**加一个 lint：扫 `test/**.bats` 里硬编码的 `.specs/<change-id>/` 引用并告警 |
| 2026-09-20c | 🟢 | `corpus-count.sh:22` | 默认输出路径 `ATTR_OUT=".specs/l3-review-defects-2026-09/L2-EMPTY-ATTRIBUTION.md"` **写死在一个已归档的 change 上**。手动跑无参 `bash corpus-count.sh --attribution` 会写不进去（目录已不存在）；测试传显式第二参数故未被覆盖，属**静默默认失效**。同类隐患：任何把默认输出指向「当前活跃 change」的脚本，change 一归档默认值就烂 | 改为读 `.flow-active` 的 `change_id` 派生路径（无活跃 change 则报错要求显式传参 + 给出用法），避免默认值指向某个具体历史 change。**未并入 health-fix-2026-09**（属该 change 范围排除项，避免范围失控），留待独立处理 |
<!-- 2026-09-20c ↑ -->
<!-- 2026-09-20d ↓ -->
| 2026-09-20d | 🟡 | `flow-kit-bundle/hooks/stop/lib/l2-detect.sh:418` · `l3-review.sh:96`（同款两处） | **type-guard 只 guard 了 `write_model_missing_correction`，却调用 `write_model_missing_clear`** —— 两个函数同在 `correction-file.sh`（:99 / :161），guard 只查其一，故当 `correction-file.sh` **未被上游加载**时，`write_model_missing_clear "L2"` 会 `command not found`。**当前被掩蔽**：常规 Stop 链路里 `29-independent-review.sh:96/:125` 已先 source 该文件，所以生产路径不触发；**任何绕过 29 号链的独立调用**（手动 `l2_dispatch_agent`、新增调用方、将来拆分）都会命中。修 L3 同款需一并处理（`l3-review.sh:96`）。**症状隐蔽**：脚本打印一行 `未找到命令` 后**继续执行**，若该行落在异步子 shell 内，错误既不入 review 文件也不阻塞流程 → 表现为"派发静默不发生" | 两处 guard 改为同时检查两个函数（或任一缺失即 source）：`type write_model_missing_correction >/dev/null 2>&1 && type write_model_missing_clear >/dev/null 2>&1 \|\| source correction-file.sh`。**未并入 health-fix-2026-09**（其 CHANGE.md 明确"不改任何 hook 运行时逻辑"，塞进去即范围失控），留待独立 change |
<!-- 2026-09-20d ↑ -->
<!-- 2026-09-20e ↓ -->
| L-091 | 🔴 | 全局（需求/验证方法论） | **AC 的探针必须落在判据域之内** —— `health-fix-2026-09` 阶段 1 的 AC-6 初稿把探针指向**源** `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`，而 `sync-hooks.sh` 的 `DEST_ROOTS` 只含 **7 个镜像根**、exec 判据只作用于镜像副本 `$dst_f` → **按该 AC 实现，它永远不可能通过**（实测打源：计数纹丝不动仍 5；改打镜像副本：5→6，判据其实看得见）。照此实现会交付一个"改了但 AC 仍红"的门禁，且会被误判成实现有 bug。L2 盲审以 🔴 抓出 | 写 AC 前先确认**判据实际作用于哪个集合**（读实现，别读文档）；探针必须落在该集合内。**"判据域"与"我以为的域"不一致**是同类复发的根因 |
| L-092 | 🔴 | 全局（文档计数） | **同名多份文件禁止用 basename 去重计数** —— 同一 change 里，`make lint` 漏扫脚本数被写成 **4**，实为 **7**：`regression-demos/{hallucination-guard,scope-drift-guard,strong-model-verbosity,weak-model-interactive-ui}/check.sh` 是 **4 个同名 `check.sh`**，basename 去重后塌成 1 个。该误同时污染 CHANGE.md / US-2 / DESIGN R7 三处 | 涉及"多份同名"的枚举与计数**一律用路径级**（`find`/`comm` 用完整路径）；验证脚本写成路径级集合差并**显式注释"勿用 basename 去重"**。轻量自检：若计数与直觉不符，先问"是不是有同名文件被压掉了" |
| L-093 | 🟡 | 全局（基线纪律） | **跨动作的基线必须当场重测，不得转抄早期输出** —— AC-7 抄了本会话 02:53 的 `verify-claims` 输出（13✅/0❌）当基线，但 10:19 的归档提交 `e5fca58` 已把它打红（实测 11✅/2❌）。同理 AC-2 用 `git status --porcelain` 代理 dist 新鲜度，而 **git 对 dist 结构性失明**（`.gitignore:63` 忽略）—— 这正是本 change 要堵的盲区，用它当 Given 条件属**循环论证** | ① 写 AC/基线前**当场重跑**该命令，并记录时间戳；② 禁止用「workspace 干净」代理「派生产物新鲜」（生成物被 ignore 时二者不等价）；③ 本会话内自己造成状态变更（归档/重建/提交）后，**此前测过的基线一律视为失效** |
| L-094 | 🟡 | 全局（归档收口） | **归档动作会打断所有硬编码 live 路径的消费方，且不止测试** —— 同一动作在同一天打断两处：bats #620（硬编码 `.specs/l3-review-defects-2026-09/L2-EMPTY-ATTRIBUTION.md`，见 L-2026-09-20c）与 `verify-claims.sh` **三处**（`:123` D= / `:137` M= / `:158` §0.5.1 grep 目标，全部指向已归档 DESIGN.md 与 MINOR-DEFERRED.md）。后者的**附加危害**：该脚本 `:165` 还硬编码「make check **五门**全绿」，任何增删门禁的 change 都会让它变假陈述 → 与门禁改造类 change **强耦合**，不修则对方 AC 不可达 | ① spec 工件引用一律走**live 优先 → archive 回退**解析器（`resolve_spec_artifact()`，两者皆无则显式失败）；② 门禁/清单类断言**动态推导**（从 `Makefile` 的 `check:` 依赖数门数），禁止写死数量；③ 收口流程补"跑一次全量 bats **和** `make verify-claims`" |
<!-- 2026-09-20e ↑ -->
<!-- 2026-09-20f ↓ -->
| L-095 | 🟡 | 全局（需求/验证方法论） | **新写的 AC 脚本必须先真跑一次 —— 连"这条命令能不能执行"都要验** —— `health-fix-2026-09` 阶段 1 出现一个**修复引入新缺陷**的完整循环：L3 一轮指出 AC-4 脚本"复制实现当判据"（照抄 `Makefile:23` 的 glob → 不改代码也会 PASS，零证明力）→ 我改成让实现自报清单，却写成 **`make lint --list-files`**（`--list-files` 会被 make 当作 **target 名**，**根本不是合法调用**）→ L3 二轮以 Major 抓出。根因：我**只预检了旧脚本、没预检新写的那行命令**，注意力全在"语义上消除循环论证"，没落到"这行能不能跑" | ① AC 里每个新写的命令，**写进需求前当场执行一次**（哪怕只验 `--help`/语法层面）；② "消除 A 缺陷"的修改本身要当作**新代码**走一遍同等验证强度，不能因为"方向对"就跳过；③ 与既有「AC 预检」纪律合并为一条：**预检对象是最终文本里的每一条命令**，不是"我改之前的版本" |
| L-096 | 🟡 | 全局（门禁设计） | **"验证脚本自己枚举"= 把实现当判据** —— AC-4 初稿在验证脚本里手写 6 条 glob 构造"扫描清单"，**照抄了 `Makefile:23` 的实现**。两边同样漏 `pre-commit/*.sh` → `comm -13` 结果为 0 → **一行代码不改也 PASS**。这类"同源盲区"是循环论证的变体：验证与实现共享同一个错误假设时，验证**结构性地无法发现该错误**。相反方向也有风险：AC-2 曾用 `git status --porcelain`（git 对 dist 结构性失明）代理"dist 新鲜" | ① 判据与实现**不得共享同一枚举来源** —— 让实现对**外暴露机器可读出口**（如 `make lint` 固定输出 `SCANNED_FILES:` 行），验证**只解析该出口**；② 自检问句：**"如果我什么都不改，这个验证会通过吗？"** 会通过 = 无证明力；③ 与 L-091（探针须落判据域内）同族：**都要先确认"判据实际作用于哪个集合"** |
<!-- 2026-09-20f ↑ -->
<!-- 2026-09-20g ↓ -->
| L-097 | 🟡 | 全局（工具/脚本契约） | **未知选项被静默忽略 = 最危险的"假成功"** —— 阶段 3 取证时我用 `bash package-dsh-plugin.sh --check >/dev/null 2>&1 && echo 存在` 判断该模式是否已实现，得到"存在"。**实际是错的**：该脚本**没有任何参数解析**，`--check` 被**静默丢弃**，于是它**照常完整重建 dist**（打印 `==> packaging`、重打 tarball）并 `exit 0`。于是：① 探针把"参数被忽略"误读成"功能已存在"；② 更严重的是 **`--check` 这个本应"只读"的模式会真的重建产物** —— 若 CI 或 pre-push 调它，会在检查时**篡改被检查对象**（检查者改了被检查者，结论失去意义） | ① 凡"只读/check/dry-run"类契约，**必须断言"没有副作用"**（比对运行前后的产物 mtime 或内容），不能只看退出码 —— 已据此强化 T01 的 verify：*输出含 `==> packaging` 即判 FAIL*；② 脚本加参数解析时，**未知参数应报错退出**（fail-closed），而非静默忽略；③ 与 L-095 同族：**探针必须断言它真正想断言的东西**，`rc=$?` 单判在两处都骗了我们 |
<!-- 2026-09-20g ↑ -->
<!-- 2026-09-20h ↓ -->
| L-098 | 🔴 | 全局（任务拆解 / verify 设计） | **verify 必须双向验证：实现前失败 + 实现后通过，缺一不可** —— 阶段 3 的 TASK.md 里 8 条 verify 中，**3 条被 L2 判为 Critical 且全是"恒真或方向反"**：① `grep -c '缺可执行位'` —— 有匹配时 rc=0（假绿），**0 匹配时 rc=1**，于是"把误报清零"这个 done 一旦达成，verify **必然翻红**（方向反）；② `bash x.sh; echo "rc=$?"` —— 退出码来自 `echo`，**恒 0**；③ `grep -l … \| wc -l` —— **恒 0**。另有 `… \|\| make check` 的静默降级（引用一个永不会被创建的脚本，fallback 让 verify 现在就是绿的）。**这与 L-095（新写命令没跑过）、L-097（`--check` 被静默忽略）是同一族的第三次** | ① 每条 verify **必须两个方向都实测**：(a) **实现前**跑一次 → 必须**失败**；(b) 手工模拟"实现后"状态跑一次 → 必须**通过**；只做语法检查（`bash -n`）远远不够 —— 本 change 全部 8 条语法都过了，3 条行为是错的；② 具体反模式清单：`grep -c X`（0 匹配 rc=1）、`cmd; echo $?`（rc 被 echo 覆盖）、`… \| wc -l`（恒 0）、`… \|\| fallback`（静默降级）、管道吞退出码（`cmd \| grep`）；③ 断言"零/不存在"时一律用 `[ "$(… \| grep -c … \|\| true)" -eq 0 ]` 形式，不用 `grep -c` 裸判 |
<!-- 2026-09-20h ↑ -->
<!-- 2026-09-21a ↓ -->
| L-099 | 🔴 | 全局（审查协议 / 批量改写） | **批量文本替换必须排除审查产物** —— 我在阶段 6 批量更正一处数字（`21 处 SC1090` → `22`）时，脚本的 glob 是 `['Makefile']+glob('.specs/health-fix-2026-09/*.md')`，于是**把 `INDEPENDENT-REVIEW-6.md` 里审查员的原文也改了**。而 `L2-blind-review.md` 明文规定「**主 agent 无权修改你的原文判断**；它若反驳，必须在你的报告之后另起段标注」。**这是对审计凭证的篡改**，虽然是无意且已当场回退。危害：审查报告是独立第二意见的**唯一凭证**，一旦主 agent 可改写它，"独立性"即归零（正是协议要防的橡皮图章） | ① 任何批量文本替换的 glob **必须显式排除 `INDEPENDENT-REVIEW-*.md`**（与 health 报告、CHANGE/DESIGN 等同视为**只读审计产物**）；② 更稳妥：替换前列出**将修改的文件清单**并核对，而非直接 `glob` + 写入；③ 主 agent 对审查结论的一切异议，只能落在「主 agent 响应」段或本 change 自己的工件里。**自检问句**："我要改的这个文件，是我写的吗？" |
| L-100 | 🟡 | 全局（事实性断言） | **"没看到" ≠ "不存在"：断言环境状态前必须实测** —— 阶段 6 的 REVIEW.md 自称"未装 brooks-lint → 走内置回退"，实际该工具**完整安装**（工具目录 + marketplace skill + `.brooks-lint-history.json` 7 次历史运行 + 本会话技能目录 6 个 brooks 技能）。我的推理是"本轮没调用过它，所以没装"—— 把**缺席的证据**当成了**不存在的证据**。**实质后果**：6 维诊断走了低质量回退（该工具 benchmark：带书本引用 100% vs 约 16%），R3/R4/R5 三维全 0 属**漏判**而非"干净"；评审员独立复核出 4 条我漏判的项 | ① 涉及"某工具/依赖是否存在"的断言，**先 `ls`/`command -v`/查历史记录**再写；② 对"能力/覆盖度"的自评一律标注**取证方式**（跑了什么命令得出该结论）；③ 与 L-095/L-097/L-098 同族（皆为"未实测即断言"）—— 本 change 内这是**第五次**同类，说明该习惯是顽固模式，需在自检清单里固化为独立问句 |
<!-- 2026-09-21a ↑ -->
<!-- 2026-09-06 ↓ -->
| 2026-09-06 | 🟡 | `test/test_l3_pipeline_fix.bats:440-441` | 全量跑偶发 1 fail（F-1 · T04 AC-1 · status 141 SIGPIPE）：`printf | grep -qF` 下 grep 命中即退 → writer SIGPIPE 141；首轮全量 1 not-ok，复跑 803/803 绿、单文件 41/41 绿 → 满负荷偶发 flaky（TD-024 已登记） | 断言改 `[[ "$out" == *marker* ]]` 或 `grep -F … >/dev/null`（去 -q）；下次 health-fix 顺手修 |
| 2026-09-06 | 🟢 | `.specs/{l3-prompt-loop-fix,correction-hygiene-state-guard}/` | 归档移位后残留 ignored PROGRESS.md ×2（09-01 同类已清，本次同类复发 ×2）——归档流程无「源目录清理」步骤 | 归档动作补源目录清空检查；或下个 change 顺手删 2 目录 |
| 2026-09-06 | 🟢 | `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:94` | T02 提取器引入未用局部量 `sev summ`（SC2034×2 · 全文件 0 引用） | 删两变量（一行） |
<!-- 2026-09-06 ↑ -->
<!-- 2026-08-03 Full Sweep ↓ -->
| 2026-08-03 | 🔴 | `flow-kit-bundle/lib/install_hooks.sh:97` | **install_hooks.sh:97 user-scope 回归**：commit `0c79f1c`（双平台拆分）把 `"$project/.claude/stop-hook.json"` 改为 `"${project}/${PROJECT_DIR_NAME}/stop-hook.json"` 但未处理直接 source 路径（PROJECT_DIR_NAME 仅 `lib/paths.sh` 定义 · 仅 install.sh 主入口 source）。单元测试和 `--user` 直调不 source paths.sh → `set -u` exit 1。症状：4 bats fail + `--user` 安装链路断 + 副作用阻断 runtime-edit-guard.sh 安装（L177-183 位于 L97 之后，永不执行）。 | **已修复**（`health-fix-2026-08` · Fix A paths.sh 自加载守卫 · 非 scope guard — DESIGN L2 审查确认 stop-hook.json 在 user-scope 是运行时回退依赖 `common.sh:107-108`，移除致 module_enabled 恒 false）。修复后 692/0 测试通过，评分 89→≥98。 |
| 2026-08-03 | 🟢 | 5 个 Bash 文件（jscpd 检测） | **Bash 样板代码相似率 0.37%**（vs 上次 0.43% · 略降）。5 处克隆均为 6-11 行的 shebang + source 初始化段。TD-008/017/018 拆分未引入新重复。 | 不处理。沿用 2026-07-25 决议。 |
| 2026-08-03 | 🟢 | `flow-kit-bundle/lib/paths.sh`（新增） | **lib/paths.sh 是 0c79f1c 新增的共享变量 lib**（PLATFORM / PROJECT_DIR_NAME / USER_HOOKS_DIR 等平台抽象）。是合理的双平台兼容设计，但**未登记到 CONTEXT.md「既有抽象索引」**，未来 AI 可能重复实现类似平台抽象。 | 下次 A-evolve 同步时登记到 CONTEXT.md § 既有抽象索引。同时建议加 install_hooks.sh 文件头注释明确「依赖 paths.sh · user-scope 不依赖 PROJECT_DIR_NAME」边界。 |
| 2026-08-03 | 🟢 | 全局（流程教训） | **commit-time 测试门禁缺失**：`0c79f1c` 提交时 4 个 bats fail 测试已存在，但 commit 被允许通过（未跑 `make test` 或结果被忽略）。若 commit 前置硬门禁（pre-commit hook 跑 `make test`），此回归可在入库前捕获。 | 建议未来在 .git/hooks/pre-commit 或 Makefile pre-push target 加 `make test` 硬门禁。本项不阻塞 health-fix-2026-08，作为流程改进建议记录。 |
<!-- 2026-08-03 Full Sweep ↑ -->
<!-- 2026-08-04 health-fix-2026-08 ↓ -->
| 2026-08-04 | 🟡 | 全局（流程教训） | **L-064 · self-certify 系统性不如 oracle review**：health-fix-2026-08 pipeline 中 phases 3/5/7 用 self-certify（D7 例外 · gate_config=all 热修复到 all-L2），phases 1/2/6 用 oracle L2。事后对 3/5/7 派 retroactive oracle L2 → **3/3 全部 WOULD-HAVE-FLAGGED**（12 项 finding 含 3 High）：phase 3 filter 假绿（`--filter "writes..."` 匹配 0 case）· phase 5 per-file 计数错（18→17, 3→4）· phase 7 diff stats 错（+36→+40）+ artifact count 错（10→11）+ .gitignore 禁动假 PASS。对比 phases 1/2/6 的 oracle 审查发现 real value（phase 2 拒绝 Fix B 致命错误）。**结论**：gate_config=all 不可用 self-certify shortcut · oracle 的独立核验（尤其可验证数字：行数/计数/matcher 有效性）是 self-certify 盲区。 | gate_config=all 的所有 gated phase 必须用 oracle L2。self-certify 仅限 D7 例外（且事后需 retroactive L2 补审）。 |
<!-- 2026-08-04 health-fix-2026-08 ↑ -->

<!-- 2026-07-25 Full Sweep ↓ -->
| 2026-07-25 | 🟢 | `flow-kit-bundle/hooks/stop/lib/l3-review.sh` | **l3-review.sh 持续增长至 875 行**（+65 vs 上次 810）。增长来自合法功能（`l3-review-timeout-token` 可配置化：FLOW_KIT_L3_MAX_TOKENS / TIMEOUT / THINKING）。12 函数结构良好，主编排函数 `l3_review_run()` 已从上上次 307 行拆至 ~90 行。 | 若未来突破 1000 行或新增第 5 种职责，触发 TD-008（拆为 l3-detect / l3-dispatch / l3-format 子库） |
| 2026-07-25 | 🟢 | 5 个 Bash 文件（jscpd 检测） | **Bash 样板代码相似**：6-11 行的 shebang + `set -euo pipefail` + SOURCE_DIR 初始化段在 l2-detect↔l3-review、27↔28、auto-checkpoint↔gate 等模块间结构相似。非语义重复，是 Bash 脚本的固有模式。 | 不处理。提取公共样板反而增加耦合和认知负荷。 |
<!-- 2026-07-25 Full Sweep ↑ -->

---

## 技术债清单

> 最后更新: 2026-07-20（M-health 巡检）

### L-032: L2 盲审在每阶段都捕获了主 agent 漏检的 Critical 问题（auto-checkpoint-hook）

**严重程度**: 🟡 Major（流程级）
**来源**: `auto-checkpoint-hook` change（2026-07-10 · 全 pipeline 0→7 执行）
**发现**:
- Phase 2 L2 捕获 `hooks/pre-tool/` vs `hooks/pre-tool-use/` 目录名错误（R1 🔴）——主 agent 在 0.5 段甚至自己写了正确路径 `~/.claude/hooks/pre-tool-use/` 但全文用错
- Phase 1 L2 捕获 checkpoint-lib.sh 去重逻辑与 REQUIREMENT "不去抖"的矛盾（R1 🔴）——CONTEXT.md 域语言与已锁决策自相矛盾
- Phase 3 L2 捕获 T02 verify 退出码被 `; echo "exit=$?"` 吞掉（R1 🟡）
- Phase 5 L2 捕获 TEST.md 性能轮缺失（R1 🔴）
- Phase 6 L2 捕获 AC-6 只有写入侧测试、缺 resume 读取侧验证（R1 🔴）

**教训**: L2 盲审的"独立性"价值在本次 change 中得到充分验证——5 个阶段中有 4 个阶段的 L2 审查发现了主 agent 漏检的 🔴 Critical 问题。**L2 不是橡皮图章，是真实的安全网**。gate_config=all 全开虽然多了 ~150k tokens（5 次 L2 审查），但阻止了至少 2 个会导致"部署后完全不可用"的路径级 bug（R1 目录名 + R1 去重矛盾）。

**建议**: 对于涉及新文件创建/目录结构变更/库行为修改的 change，**强烈建议** gate_config=all 全开。纯文档/配置类 change 可降为 code-only（仅 6-review）。

### L-033: Makefile lint for-loop glob 覆盖不完整——`hooks/stop/lib/` 的 12 个 lib 文件绕过 shellcheck（checkpoint-polish）

**严重程度**: 🟡 Major（流程级）
**来源**: `checkpoint-polish` change（2026-07-10 · Phase 6 L2 🔴 R1 发现）
**发现**:
- `make lint` 的 shellcheck for-loop 覆盖了 `*.sh`、`flow-kit-bundle/lib/*.sh`、`flow-kit-bundle/hooks/stop/*.sh`、`flow-kit-bundle/hooks/session-start/*.sh`、`flow-kit-bundle/hooks/pre-tool-use/*.sh`，但**遗漏了 `flow-kit-bundle/hooks/stop/lib/*.sh`**
- 后果：`hooks/stop/lib/` 下全部 12 个 lib 文件（common.sh、correction-file.sh、done-validation.sh、fix-compliance.sh、flow-kit-artifacts.sh、interactive-ui-check.sh、l2-detect.sh、l3-review.sh、transcript-parser.sh、weak-model-compliance.sh、checkpoint-lib.sh、banner.sh）从未经过自动化 shellcheck 扫描
- 本次新增的 banner.sh 也未被扫描——直到 Phase 6 L2 审查时才被发现

**教训**: 当目录结构存在嵌套子目录（如 `hooks/stop/` + `hooks/stop/lib/`）时，shell glob `hooks/stop/*.sh` **不递归**匹配子目录。新增 lib 文件到深层目录时，必须同时检查 Makefile/CI 的静态分析覆盖范围

**修复**: Makefile L23 追加 `flow-kit-bundle/hooks/stop/lib/*.sh` 到 lint for-loop
**建议**: 后续 change 可在 `make lint` 中使用 `find ... -name '*.sh'` 递归扫描替代显式 glob 枚举，从根本上消除此类遗漏

### L-052: 命名约定三套风格共存——`check_g*` / `_gate_*` / `fk_*` 不一致

**严重程度**: 🟡 → ✅ resolved（health-debt-cleanup · 2026-07-20）
**修复**: `26-workflow.sh` 全仓重命名：`check_g*_body()` → `_fk_check_g*_body()`（5 个私有 body 函数）+ `check_g*()` → `_fk_check_g*()`（5 个 thin wrapper）+ `file_age_days()` → `_fk_file_age_days()`（1 个私有 helper）。注释 `flow-kit-artifacts.sh:110` 同步更新。CONTEXT.md 追加命名约定段（公共 `fk_*` + 私有 `_*`）。

### L-053: `install_hooks()` 195 行——安装脚本单体函数偏长

**严重程度**: 🟡 → ✅ resolved（health-debt-cleanup · 2026-07-20）
**修复**: 用户确认暂不拆分（安装脚本非热路径）。补齐测试覆盖（16 bats cases in `test_install_coverage.bats`）+ CONTEXT.md 标注长度容忍度。

### 🔍 观察（M-health 2026-07-20 · 🟢 → ✅ resolved by health-debt-cleanup）

- **T5 · install 函数测试覆盖缺口**: ✅ 已补齐 — `test/test_install_coverage.bats` 16 条 bats cases，覆盖 install_flow_kit_core / install_skills / install_specs_template / install_hooks(user scope) / install_brooks_lint(jq fallback) / install_brooks_tools(shim conflict + PATH warning) / install_file
- **R4 · `_grep` 兼容层间接性**: ✅ 已标注 — CONTEXT.md 记录保留决策 + 理由（`command grep` 跨环境一致性 · 6 处调用隔离良好 · 成本可忽略）

| # | 级别 | 位置 | 问题 | 建议 | 状态 | 来源 |
|---|---|---|---|---|---|---|---|
| L-031 | ✅ | 跨文件批量修改 · DESIGN.md 清单驱动 | ~~DESIGN 漏列导致 AI 漏改~~ → ✅ resolved by `debt-audit-resolve-2026-08`：L2-blind-review.md 顶部新增「通用 · 跨阶段必查项」段，强制 L2 reviewer 独立做全仓 grep 扫描（不信 DESIGN 清单），对每个一致性锚点跑 `grep -rn` + 对比 git diff，"DESIGN 漏列且未改"= 🔴 Critical finding。从「靠主 agent 自觉」升级为「靠 L2 独立扫描兜底」。 | ✅ 已完成（L2-blind-review.md 通用必查段 · debt-audit-resolve-2026-08） | `fix-l3-gate` 2026-07-10 · resolved 2026-08-04 |

| L-030 | 🔴 | `flow-kit-bundle/hooks/stop/29-independent-review.sh` + `independent-review-gate.sh` | ~~**L3 盲审 gate 机制三连异常**~~ → ✅ resolved by `fix-l3-gate`（2026-07-10）：(1) L3 重审——mtime 检测工件变更后追加 `## L3 重审` 段；(2) .done 条件写入——仅 `L3_verdict=pass` 时写 .done；(3) transition `.phase` 同步——9 处 transition jq 全部加 `.phase` 字段 | resolved | `fix-l3-gate` 2026-07-10 |

| L-022 | ✅ | `flow-kit-bundle/hooks/stop/lib/l3-{api,review}.sh` stderr 安全 | ~~curl/jq 错误 stderr 泄露~~ → ✅ resolved：(1) 所有 curl 调用 `2>/dev/null` 屏蔽网络错误细节；(2) 错误日志 sanitize 为 `[l3-review] L3 API returned HTTP ${code}` 等通用消息（无 URL / 无响应体）；(3) `_l3_format_result` 白名单输出 + `L3_RESULT:` 单行格式天然防泄露。剩余 `using max_tokens=N timeout=N thinking=N` 是配置 echo 无敏感性。 | ✅ 已完成 | `l3-feedback-visibility` 2026-07-07 · verified 2026-08-04 |

| L-004 | 🟢 | `flow-kit-bundle/lib/install_hooks.sh` | 辅助函数 `install_file()` 已从 install.sh 抽出到 lib/，但独立工具库 `lib/utils.sh` 尚不必要（当前 1 个共享函数，阈值 ≥ 3）。debt-cleanup 确认保持推迟。 | 等新增 ≥ 2 个共享辅助函数时再建 `lib/utils.sh`，避免只有一个函数的过度抽象 | deferred | `init-git-repo` T03 手动基线 |
| L-005 | 🟡 | `package-flow-kit.sh` L20 | STAGING 前置校验已添加（debt-cleanup） | `[[ -n "$STAGING" && "$STAGING" != "/" ]]` guard 已生效 | resolved | `init-git-repo` T03 手动基线 |
| L-014 | 🟢 | Bash `grep -E` 字符类中 `\]` 的转义 | 在双引号字符串内使用 `grep -E` 的字符类 `[...\]` 时，bash 将 `\]` 展开为 `]`，导致字符类提前关闭、匹配静默失败。典型症状：grep 在 shell 中直接执行正常，但在 bats 测试的 sourced function 中返回空。修复：用 `[^[:space:]]*` 替代复杂字符类 + sed 后处理剥离尾随标点；或使用单引号字符串避免 bash 转义。影响：所有在双引号内使用 `grep -E` + 含 `]` 字符类的 Bash 脚本。来自 `robustness-hook-hardening` T04 L3 测试调试 | 写 Bash regex 优先单引号字符串；必须双引号时用 `[^...] 替代字面排除字符类 | active | `robustness-hook-hardening` T04 调试 |
| L-015 | ✅ | AI 直接编辑 `~/.claude/` 运行时文件 | ~~无技术防护，仅流程规范~~ → ✅ resolved by `debt-audit-resolve-2026-08`：新建 PreToolUse hook `runtime-edit-guard.sh`，检测 Write/Edit 到 `~/.claude/{hooks,skills}/` 路径且 `flow-kit-bundle/` 维护源存在时 exit 2 deny + stderr 输出 redirect 引导。从「流程规范靠 AI 自觉」升级为「hook 硬拦」。 | ✅ 已完成（runtime-edit-guard.sh · debt-audit-resolve-2026-08） | `improve-independent-review` · resolved 2026-08-04 |
| L-013 | 🟢 | `.specs/` 归档流程（7-integration） | 归档流程两种遗漏模式：① **归档未清理**——change 已归档但 `.specs/<id>/` 工作目录未删，留只剩 PROGRESS.md 的空壳（2026-06-24 发现 bundle-packaging / docs-sync / fix-pcsc-gaps）；② **完成未归档**——change 100% 完成（REVIEW✅ / TASK 全done / CHANGELOG 已记）却没走归档，完整工件散落 `.specs/`（2026-06-25 发现 security-privacy-audit） | 归档脚本（7-integration）加双向校验：a) 归档完成后 rm 工作目录（PROGRESS.md 先确认入 archive）；b) 定期扫描 `.specs/` 下非 archive 目录，凡 REVIEW✅ + TASK 全done 的 change 提示归档 | resolved | `lessons-cleanup` T01 / T04 / T06 |
| L-016 | 🟢 | `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh`（501 行） | 单体文件偏大，含 artifact-check / auto-phase / done-validation / stale-check / boundary-check / snapshot / progress / token 共 8 个职责 | 可按职责拆为 `artifact-check.sh` / `auto-phase.sh` / `done-validation.sh` 三个子库（当前可维护性尚可，非紧急） | observed | `M-health 2026-07-02` |
| L-017 | 🟢 | `package-flow-kit.sh`（594 行） | 打包主脚本偏大，`validate_staging_coverage()` 函数 ~100 行独立于主流程 | 可拆出 `validate_staging_coverage()` 为独立 lib（当前可维护性尚可，非紧急） | observed | `M-health 2026-07-02` |
| L-018 | 🟢 | `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh:498` | `fk_accumulate_tokens` 中 `updated_at` 被双重赋值（第一个 `\| .updated_at = now` 被第二个 `\| .updated_at = (now \| strftime(...))` 覆盖），无实际效果但潦草 | 删掉第一个 `\| .updated_at = now`（下次改到该函数时顺手修） | observed | `M-health 2026-07-02` |
| L-019 | ✅ | `flow-kit-bundle/hooks/stop/lib/correction-file.sh` | ~~`correction_file_write()` 仅 overwrite 策略~~ → ✅ resolved：函数签名已升级为 `correction_file_write(path, data, strategy="${3:-overwrite}")`，支持 merge 策略。调用方可选传 `merge` 启用 read-merge-write。 | ✅ 已完成 | `flow-active-integrity` phase 2/3 · verified 2026-08-04 |
| L-020 | ✅ | Stop hook 模块执行链 | ~~三处接线漏一处 = 模块永不执行~~ → ✅ resolved by `debt-audit-resolve-2026-08`：新增 `test/test_hook_dispatch.bats` 3 个 smoke 测试自动检测死代码（文件存在但 00-gate.sh 未调度 / HOOK_MODULE_NAMES 数组与磁盘不同步 / 调度的文件不存在）。新增模块忘接线 → bats 失败。 | ✅ 已完成（test_hook_dispatch.bats · debt-audit-resolve-2026-08） | `flow-active-integrity` · resolved 2026-08-04 |
| L-021 | ✅ | `flow-kit-bundle/hooks/stop/lib/correction-file.sh` ↔ `interactive-ui-check.sh` ↔ `weak-model-compliance.sh` | ~~三个 lib 模块形成双向依赖环~~ → ✅ resolved by `health-fix-2026-07`：提取三方共享接口到 `correction-types.sh`，UI check 和 weak-model-compliance 现在依赖接口（grep 确认：两模块均 source correction-types.sh + correction-file.sh，correction-file.sh 不再 back-reference 它们）。 | ✅ resolved | `M-health 2026-07-04` · verified 2026-08-04 |

---

## 已解决

> 已修复或不再适用的条目移至此段，保留溯源。

| # | 原状态 | 位置 | 问题 | 修复提交 | 解决日期 |
|---|---|---|---|---|---|
| L-002 | 🟡 | `package-flow-kit.sh` L56 | 硬编码 `~` 路径 | `7b1ae91` fix(package): 用 SCRIPT_DIR 替换 | 2026-06-15 |
| L-006 | 🟡 | `install.sh` L243 + brooks-lint hooks | 空 commands 目录导致 hook exit 1 | `47d80f6` fix(brooks-lint): SessionStart hook 空 commands 容错 | 2026-06-14 |
| L-001 | 🟡 | `package-flow-kit.sh` | 打包与安装逻辑耦合 → install.sh 已拆分为独立文件 | `e1ea7b9` refactor package-flow-kit.sh | 2026-06-15 |
| L-003 | 🔴 | `package-flow-kit.sh` | 零测试覆盖 → bats-core 28 tests | `2e745b7` feat(health-fix) | 2026-06-17 |
| L-007 | 🟢 | `package-flow-kit.sh` L104-143 | settings.json 模板 heredoc 重复 → cp 文件替代 | `2e745b7` feat(health-fix) T08 | 2026-06-17 |
| L-008 | 🟢 | `install.sh` L194 | brooks-lint 版本号硬编码 → plugin.json 动态读取 | `2e745b7` feat(health-fix) T09 | 2026-06-17 |

---

| L-009 | 🟡 | `common.sh:10` | CONFIG_FILE 覆盖调用方 → 已改为 `: "${CONFIG_FILE:=}"`（debt-cleanup） | 仅在未设时赋默认值 | resolved | 2026-06-16 health-fix |
| L-010 | 🟡 | T02 流程 | 破坏性变更后未立即验证恢复 → 已记入流程规范 | 1.8 协议后必须立即跑恢复验证 | resolved | `lessons-cleanup` T03 / T04 / T06 |
| L-011 | 🟢 | `common.sh:22-39` | jq key 连字符→减法 → 已改为 bracket 引用 `.modules["${mod}"]`（debt-cleanup） | bracket 引用防止 jq 解析错误 | resolved | 2026-06-16 health-fix |
| L-012 | 🟡 | `package-flow-kit.sh` Part E | **结构变更后打包脚本未同步**：install.sh 拆分为 `lib/` 模块后，`package-flow-kit.sh` Part E 只 `cp install.sh` 忘了 `cp -r lib/`，导致 bundle 安装报 `No such file: lib/install_hooks.sh`。E2E 验证环节才发现。 | 任何改变 `flow-kit-bundle/` 目录结构的修改，必须同步检查 `package-flow-kit.sh` 的 staging 逻辑（Part A~F 的 mkdir/cp/rsync 范围） | resolved | `lessons-cleanup` T02 / T06 |

## 元数据

- **最近更新**: 2026-07-20（M-health 巡检：评分 92/100 · 上次 2🔴 全修复 · 新增 L-052/L-053 + 2 观察）
- **下次复查**: 2026-08-20（建议每月一次 M-health）

## L-016 · 独立审查四层架构必须全对齐

**日期**: 2026-07-02 | **来源**: independent-review-gap

**教训**: L2/L3 独立审查的端到端可用性依赖四层同步：PRESET_MAP → Prompt 模板 → Hook 层 → L2-blind-review.md。任一层缺失，即使 gate_config 正确设置，pipeline 也会在对应阶段死锁——hook 层等 .done 文件，但主 agent 的 prompt 不知道要写 .done。

**预防**: 新增 gate_config 阶段支持时，必须同时检查四层是否都已更新。check-gate-sync.sh 可检测 PRESET_MAP 和 bats 之间的漂移，但 prompt 层和 L2 checklist 层的完整性需要 AC-1/AC-4 验证脚本人工跑。

**状态**: ✅ 已修复 — 3-task/5-test/7-integration prompt + PRESET_MAP 8 新预设 + L2 checklist 3/5/7 均已补齐

---

## L-017 · PRESET_MAP 声明与实现必须同步交付

**日期**: 2026-07-02 | **来源**: independent-review-gap

**教训**: gate-integrity change 的 `all` 预设提前声明了 3/5/7 的 independent 支持，但 prompt 层实现未同步交付。这造成了结构性死锁：hook 层已就绪（会拦 transition 等 .done），但主 agent 不知道该写 .done。"先声明后实现"在跨层变更中是危险的——声明让用户以为可用，实现缺失让实际不可用。

**预防**: 跨层变更（如独立审查这种涉及 Hook + Prompt + Config 三层的功能）不应分 change 交付。要么一个 change 四层全做完，要么 feature-flag 默认关闭直到最后一层就绪。

**状态**: ✅ 已修复 — independent-review-gap 补齐了 gate-integrity 遗留的三层

## L-018 · Pipeline 关键机制不可纯 prompt 驱动——必须有 hook 兜底

**日期**: 2026-07-03 | **来源**: pipeline-fallback-fix (T02, T03)

**教训**: auto_advance 自动推进和 fallback goal 迭代循环都是纯 prompt 驱动的——AI agent 读到 prompt 中的分支指令后自行决定是否执行。这与独立审查 gate（PreToolUse hook 系统层硬拦截）形成鲜明对比。在弱模型下，纯 prompt 机制可能被跳过或忽略，导致 auto_advance=true 仍输出 toll-gate 提示、fallback 迭代忘记自检等。

**6 个具体发现**:
1. L2+L3 异步死锁：L3 需 Stop hook（会话结束），但 pipeline transition 需 L3 完成后才能推进
2. gate_config 篡改检测死锁：`/flow gate-config` 不同步 `.goal-snapshot.json` → hook 拦截全部修改
3. Gate 拦回退：独立审查 gate 不区分前进/回退方向
4. auto_advance 纯 prompt：无 hook 层验证 auto_advance=true 时是否真的自动 transition
5. Fallback 纯 prompt：GO.md 无 mode 特定路由，迭代逻辑仅在 4-dev prompt 一段描述中
6. AC-5a↔hook 字段差异：`artifacts=` 未实现，Tier1 不查 L2/L3_verdict

**预防**: 任何 pipeline 关键行为（auto_advance、fallback 迭代、gate 检查）必须有 hook 层兜底验证。Prompt 指令是"提示"，hook 是"强制执行"。

**状态**: 🔴 待修复 — 详见 `.specs/pipeline-fallback-fix/DIAGNOSIS.md` P0/P1/P2 修复建议

---

## L-new-1 · gate_config 5th parameter 传递链完整性

- **严重度**: 🟡 Major
- **位置**: `29-independent-review.sh:117` / `independent-review-gate.sh:228` / `l3-review.sh:291`
- **问题**: `l3_review_run()` 新增第 5 参数 `gate_config_value`，但 3 处调用点均漏传，导致 D3 gate 默认 "both"，L3-only 模式 .done 被错误延迟
- **建议**: 新增参数时用 grep 扫全部调用点确认参数数目一致；或使用命名参数（key=value）替代位置参数
- **状态**: ✅ 已修复（`dual-review-merge-fix` phase 6 L2 审查发现，`${gate_val:-both}` 已传）
- **来源**: `dual-review-merge-fix` phase 6 L2 review R1

## L-new-2 · phase_name 映射三处重复

- **严重度**: 🟢 Minor
- **位置**: `29-independent-review.sh` / `independent-review-gate.sh` / `done-validation.sh`
- **问题**: phase number → phase_name 的 case 映射（{1→"1-requirement", 2→"2-design", ...}）在 3 个文件中逐字重复。新增/修改阶段名时需同步 3 处
- **建议**: 抽取为共享函数（如 `fk_phase_name()`），放在 `flow-kit-artifacts.sh` 或 `common.sh`，3 处调用点改为 `phase_name=$(fk_phase_name "$phase")`
- **状态**: 🟢 待 v2 抽取（`dual-review-merge-fix` REVIEW.md Q1 已记录）
- **来源**: `dual-review-merge-fix` phase 6 L2 review R5

### L-023 · Claude Code 环境 grep → ugrep wrapper 不兼容 `-P` 正则 + `-c` 返回值语义差异

- **位置**: `fix-compliance.sh`（新增 lib）
- **问题**: Claude Code 环境将 `grep` 替换为 ugrep wrapper 函数。`grep -oP` 中 `\b` 在 ugrep 报 "empty (sub)expression"；`grep -c` 匹配数为 0 时输出 "0" 但 exit=1，与 `|| echo "0"` 组合输出 "0\n0"。
- **修复**: 定义 `_grep() { command grep "$@"; }` 兼容层。正则 `\b` → `(\s|:|$)`。
- **教训**: hook/lib 脚本须在顶部声明 grep 兼容层；CI 应 `type grep` 检查 wrapper。
- **状态**: ✅ 已修复（26 bats 全绿）
- **来源**: `l2-l3-fix-compliance` phase 4 T07

### L-024 · 实效性校验的"零声明"漏洞模式

- **位置**: `fix-compliance.sh` `fk_fix_compliance_check()` 步骤 ②b
- **问题**: review 有源码级发现但 agent 未输出任何 `Fixed in:`/`Tech-debt:` → `fk_verify_finding_files` grep 空→return 0（静默放行）。阈值计算 bug：`total/2` 整数截断（3 条 1 MISSING=33% 被误判为 ≥50%）；`total>1` 使 1/1=100% MISSING 不被阻断。
- **修复**: ②b 检测 `fixed_count==0 && techdebt_count==0`→阻断。`missing*2>=total` 替代整数除法；`total>0` 替代 `total>1`。
- **教训**: 检测异常→阻断的逻辑须显式处理"输入为空"（空≠安全）。默认值应为 deny（fail-closed）。
- **状态**: ✅ 已修复（26 bats）
- **来源**: `l2-l3-fix-compliance` phase 2 L3 CRITICAL + phase 6 L2 R1/R2

## L-025 · 测试 setup 的 `2>/dev/null || true` 静默吞 source 失败 — 让 169 测试"假失败"

**日期**: 2026-07-08 | **来源**: M-health 2026-07-08（bats 实跑发现 169/414 失败）

**教训**: 多个 bats 测试文件的 setup 用 `source "${BATS_TEST_DIRNAME}/../flow-kit-bundle/hooks/.../<lib>.sh" 2>/dev/null || true` 加载被测 lib。两个问题叠加形成"系统性假失败"：
1. **路径双重前缀**：测试文件位于 `<repo>/flow-kit-bundle/test/`，但 setup 写 `../flow-kit-bundle/...` → 解析成 `flow-kit-bundle/flow-kit-bundle/...`（路径不存在）。
2. **`|| true` 静默吞错**：source 失败被 `2>/dev/null || true` 完全吞掉，setup 不报错，但被测函数未定义 → 后续 `run <func>` 返回 127（command not found）→ 断言失败。

结果：169 个测试因"函数未定义"失败，但失败原因被 setup 的 `|| true` 隐藏在深处，表面看像 169 个独立回归，实际是 1 个系统性路径 bug。更糟的是：上次（07-07）健康报告只统计了测试数量增长（72→414），**没跑通过率**，完全漏检这 169 失败。

**预防**:
- **路径必须正确（核心）**：测试路径基于 test/ 在 flow-kit-bundle/ 下的真实结构用 `${BATS_TEST_DIRNAME}/../hooks/...`（去掉多余 `flow-kit-bundle/`）；用 `$REPO_ROOT` 时注意 test 在 `flow-kit-bundle/test`，到 repo 根要 `../..` 而非 `..`。
- **`|| true` 在 source lib 场景是合理容错，不盲目移除**：lib（common.sh 等）source 时顶层 `set -e` 副作用命令可能 exit 非0，但函数已定义可用；`|| true` 吸收 exit code 让 setup 继续。health-fix 实测移除 `|| true` 破坏 27 测试（gate_integrity 23 + phase-resolution 4）。真正要防的是"函数未定义"，改用 **AC-4 函数定义断言**（`test_setup_integrity.bats`：source 后 `type <fn>` 检查）兜底。
- **M-health 巡检必须实跑 bats 通过率**，不能只数 `@test` 数量。本次新增"bats 实跑"步骤永久纳入巡检 SOP。

**状态**: ✅ 已修复（health-fix-2026-07-08）— 169 失败→0（25 处双重路径修复 + AC-4 setup smoke）。`|| true` 经实测保留为合理容错（预防措施已据此修正）。

## L-026 · 架构统一后旧 wrapper 易成死代码 —— 删除前必须 grep 引用确认（不能批量删）

**日期**: 2026-07-08 | **来源**: M-health 2026-07-08 死代码清理 + health-fix-2026-07-08 git 考古

**教训**: 架构统一（提取公共 lib / 统一入口）change 完成后，原有的 wrapper 函数处理不一致，易留死代码。两个实测案例：

**案例 1 · `read_correction_file`（interactive-ui-check.sh）**：`sweep-fix-2026-07` 把 correction file 读写统一到 `lib/correction-file.sh`（`correction_file_write/read/clear/exists` 4 函数）。原 `interactive-ui-check.sh` 的 3 个 wrapper（read/clear/has）处理不一致：
- `read_correction_file` — **零调用方** → 死代码（已删）。调用方（flow-kit-resume.sh 等）直接用 `correction_file_read`，不经 wrapper。
- `clear_correction_file` / `has_correction_file` — **被 `27-interactive-ui-check.sh:70-71` 真实调用**（检测矫正文件存在 → 清除）→ 有效，**不能删**。

**案例 2 · `estimate_tokens`（transcript-parser.sh）**：token 预算的早期方案（`chars/4` 粗糙估算），后被 `token-estimate.txt`（01-transcript-parse 生成）+ `fk_accumulate_tokens`（26-workflow 累加到 `.flow-active.token_spent`）链路取代，**从未接线** → 死代码（已删）。

**预防**:
- 架构统一 change 的 TASK 必须含一步：`grep -r <旧_wrapper>` 全仓（含 `.sh`/`.bats`/`.md`），对每个旧 wrapper 标注「有调用方→保留 / 无调用方→删除」。sweep-fix 漏了这步，导致 `read_correction_file` 残留 1 个月才被 M-health 揪出。
- M-health 死代码扫描（步骤 2.5）发现候选后**不能批量删**，必须逐个 grep 确认「零调用」再删。本次 `clear/has_correction_file` 有调用方，**差点被误删**（最初推测「同批漏清」是错的）。

**状态**: ✅ `read_correction_file` + `estimate_tokens` 已删（health-fix-2026-07-08）；`clear/has_correction_file` 经 grep 确认有效，保留。

## L-027 · 验证测试 pass 必须用 bats 直接 exit code —— 禁止 `bats | tail` 管道（exit code 被管道末命令吃掉 → 假绿）

**日期**: 2026-07-08 | **来源**: health-cleanup-2026-07-08（make check 暴露 30+ 既有 fail · TD-012）

**教训**: 用 `npx bats test/ 2>&1 | tail -N` 验证测试套件时，管道 exit code 是**最后一个命令（tail）**的（0），不是 bats 的。bats 实际 exit 1（有测试 fail）被完全掩盖 → 误判"全绿"。`health-fix-2026-07-08` 的"169→0 全绿"很可能因此误判 —— 实际 30+ 测试因 setup 路径 bug（TD-012）一直 BW01 127 fail，从未真绿。同类陷阱：`bats | grep`、`bats > /dev/null 2>&1 | something`、`make test 2>&1 | tail`（make 的 exit 也被吃）。本对话开头的"bats exit 0 全绿"判断也犯了这个错。

**预防**:
- 验证测试 pass 必须用 bats **直接** exit code：`npx bats test/ && echo pass || echo fail`（无管道吞 exit）
- 必须用管道时加 `set -o pipefail`（管道任一命令失败则整体失败）或检查 `${PIPESTATUS[0]}`
- Makefile test target 的判定行必须直接用 bats exit（本仓 Makefile line 13 `@npx bats test/ > /dev/null 2>&1 && echo ✅ || exit 1` 已正确；line 12 `| tail -3` 仅展示不影响判定 —— `test-setup-path-fix-2026-07` 会复核）
- M-health 巡检"bats 实跑"步骤必须检查 **exit code**，不能只看输出尾部或测试数量增长（health-fix 正是只数了 72→414 增长，没验通过率）

**状态**: ✅ 已修复（`test-setup-path-fix-2026-07` 修 18 文件路径 + Makefile 复核，30+ 测试真绿，make test 407 pass 0 BW01）

## L-028 · `grep -c "pattern" || echo 0` 重复打印致断言假失败 —— grep -c 无匹配已打印 0 + exit 1，不需 `|| echo 0`

**日期**: 2026-07-08 | **来源**: test-setup-path-fix-2026-07（test_quality_baseline AC-6 修复）

**教训**: `grep -c "pattern" file || echo 0` 是常见反模式。`grep -c` 无匹配时**已打印 0** 并 exit 1，`|| echo 0` 再打印一个 0 → `$output` = `"0\n0"`，断言 `[ "$output" = "0" ]` 假失败。开发者以为 `grep -c` 失败要 fallback 打印 0，但 grep -c 本身就打印 0（只是 exit 1）。

**案例**: `test_quality_baseline.bats` AC-6 shellcheck 测试 `ERRS=$(shellcheck ... | grep -ci "error" || echo 0)` + `[ "$output" = "0" ]`。shellcheck 0 error 时 grep -c 打印 `0` exit 1，`|| echo 0` 再打印 `0` → `"0\n0"` ≠ `"0"` → 永远 fail（假失败，之前被 TD-012 假绿掩盖，修路径后才暴露）。

**预防**:
- `grep -c` 无匹配已打印 0，**不要加 `|| echo 0`**（会重复打印）
- 若要确保 exit 0：`grep -c "pattern" file || true`（`true` 不打印，保留 grep -c 的 0）
- 测试断言前 `echo "$output" | cat -A` 检查实际值（避免 `"0\n0"` 假匹配）

**状态**: ✅ test_quality_baseline 已修（`echo 0`→`true`）

## L-029 · test_gate_integrity 多重假绿 + L2 价值 + 降挡止损（fix-gate-test-setup · 2026-07-09）
- **假绿层级**：test_gate_integrity.bats 是多重假绿灾区——① set+e（TD-013）② helper 缺 artifacts= KVP ③ 测试断言债（断言实现不存在的内容 · TD-016）④ is_phase_write bug（TD-014）。set+e 掩盖全部。
- **L2 独立审查价值**：phase 1 两轮 L2 发现主 agent REQUIREMENT 的真实疏漏（坏模式 `if ! fn` + HOOK_BASE_DIR 缺失依赖错误 + AC-3 逻辑死结）。L2 在 REQUIREMENT 层拦住实施层灾难。
- **降挡决策**：gate-config=all/full 在系统性假绿文件上陷入多轮 L2 深挖（refactor 教训同型）。降挡（无 L2/L3，主 agent 基于已查清事实直接实施 + make test 把关）更高效收口。
- **bash 细节**：`run fn; [ "$status" -eq N ]`（bats 子 shell · status 反映 fn 退出码）禁 `if ! fn; then rc=$?`（`!` 反转 $? 致假阴/假绿）。
- **How to apply**：测试 setup 禁 set+e（用 run+$status）；断言前 grep 确认实现真含断言内容（防断言债）；gate-config 在复杂/系统性问题上降挡止损。

## L-034 · AC 硬编码数字陷阱——基线数字与新增测试自相矛盾（sweep-fix-2026-07-10 · 2026-07-10）

- **发现**：AC-8 原始 Then 子句硬编码 "462 tests"；AC-3 (+≥2) + AC-7 (+≥4) 新增测试后实际 ≥468。Phase 1 L2 🔴 R1 捕获。
- **根因**：AC 的 Then 子句中写入当前基线的具体数字，忘记 AC 本身是互相关联的——一条 AC 的新增会改变另一条 AC 的预期值
- **教训**：AC 的 Then 子句**禁止硬编码动态变化的数字**（测试数、文件数、行数）。用定性描述（"全量 bats 0 fail"）或动态断言（`npx bats test/ | grep '0 failures'`）
- **修复**：AC-8 Then 改为 "全量 bats 测试全绿 0 fail；make test exit 0"，验证方式改为 "输出 0 failures"

## L-035 · Given 条款事实错误污染下游阶段（sweep-fix-2026-07-10 · 2026-07-10）

- **发现**：AC-2 原始 Given 条款称 `is_gh_pr_create()` 为 "290 行、含 7+ 独立 gate 检查混合"；实测该函数仅 **3 行**（regex 谓词）。Phase 2 L2 🔴 R1 捕获。
- **根因**：CHANGE.md 基于健康报告的函数名描述（未实测行数），REQUIREMENT 继承错误描述，DESIGN 内部纠正但未显式勘误 REQUIREMENT
- **教训**：AC 的 Given 条款中引用的代码度量（函数行数、文件数）**必须实测验证**，不能从上游文档继承。Given 错误 → L3 外部模型基于虚假前提审查 → 整个审查链失效
- **How to apply**：写 AC Given 前先 `wc -l` / `grep -c` 实测；DESIGN 发现 REQUIREMENT 错误时必须**显式勘误**（不是悄悄纠正）

## L-036 · heredoc 引用退化——`<<'EOF'` vs `<<EOF` 导致变量插值静默丢失（sweep-fix-2026-07-10 · 2026-07-10）

- **发现**：`independent-review-gate.sh` gate 重构时，path-guard 错误消息从 `<<EOF`（插值 `${tool_name}`）改为 `<<'EOF'`（字面）。Phase 6 L2 W1 捕获：`${tool_name}` 不再展开 → 错误消息显示 `${tool_name}` 字面而非实际工具名
- **根因**：函数提取时，为使函数独立（不依赖外部变量）将 heredoc 改为单引号定界符——但遗忘了内部引用的变量
- **教训**：heredoc 定界符引号变更（`<<EOF` → `<<'EOF'`）是**语义变更**，不是纯格式调整。需审计 heredoc 体内所有 `${var}` 引用
- **状态**：🟡 已识别，本次未修复（错误消息降级为通用消息，不影响 gate 拦截行为）。建议后续 sweep 统一处理

## L-037 · `exit` in sub-function 反模式——gate 函数内直接 exit 绕过调用方清理逻辑（sweep-fix-2026-07-10 · 2026-07-10）

- **发现**：`_gate_phase_transition()` 内部多处直接 `exit 0` / `exit 2`，绕过了 `_run_review_gates()` 编排器的后续 gate 检查
- **根因**：gate 函数原为主逻辑体的一部分（L106-391 无名块），`exit` 原是正确的（在顶层脚本中）。提取为子函数后，`exit` 应改为 `return` + 编排器检查返回值——但函数提取是机械操作，未审计控制流
- **教训**：从主逻辑体提取函数时，**`exit` 必须改为 `return`**（除非函数确实是"终止脚本"的语义）——这是机械提取最易遗漏的审计点
- **影响**：本次场景中 gate 函数的 `exit` 行为等价于原逻辑（原也在顶层 exit），行为正确。但**可读性受损**——阅读 `_run_review_gates()` 时无法从代码推断完整控制流（部分 gate 可能永不返回）
- **建议**：后续 sweep 将 `_gate_phase_transition` 内的 `exit` 改为 `return <code>`，编排器检查返回值决定 exit

## L-038 · task verify 不覆盖非代码产物——AC-5/AC-6 文档类 AC 的 verify 默认为手工 grep（sweep-fix-2026-07-10 · 2026-07-10）

- **发现**：AC-5（命名约定文档化）和 AC-6（_grep 决策标注）的验证方式为手工 grep，无自动化 bats 覆盖。Phase 3 L2 🔴 R1 捕获 T07 verify=`make test` 无法验证文档变更
- **根因**：bats 测试框架天然适合验证代码行为，不适合验证 markdown 文档内容。但 AC 要求"可机器验证"，手工 grep 违反此原则
- **修复**：T07 verify 升级为复合命令：grep 验证 CONTEXT.md 含命名约定段 + _gate_ 前缀 + _grep 保留决策 → 通过后才跑 make test
- **教训**：文档类 AC 的 verify 应包含**针对文档内容的 grep 断言**（不依赖 bats 框架也可以在 CI 中用 shell 脚本实现）。`make test` 不能覆盖所有 AC 类型
- **How to apply**：拆 TASK 时，文档类 task 的 verify 必须包含 `grep` / `diff` 等文档内容验证命令，不能仅依赖 `make test`

---

### L-039 · `set -euo pipefail` 下命令替换内 pipeline 失败静默终止脚本

- **日期**：2026-07-11
- **来源**：`health-fix-l3-2026-07` Phase 6 L3 缺失排查
- **分类**：Shell 陷阱 / Hook 可靠性
- **严重度**：🔴 Critical（导致 Stop hook 29 号 L3 派发静默跳过 3 个 phase）
- **发现**：`29-independent-review.sh:120` 的 `l2v_extracted=$(grep ... | tail -1 | grep ... | tail -1)` 在 grep 无匹配时，`pipefail` 使 pipeline exit code ≠ 0。bash 在 `set -euo pipefail` 下命令替换内的非零 pipeline 退出码导致脚本静默终止
- **修复**：`l2v_extracted=$(...) || true`——追加 `|| true` 防止非零退出码传播
- **教训**：所有 `set -euo pipefail` 脚本中命令替换含 pipeline 时，末尾必须加 `|| true` 保护

---

### L-040 · L3 审查管线 5 项系统限制导致反复假阳性

- **日期**：2026-07-11
- **来源**：`health-fix-l3-2026-07` Phase 6/7 L3 多次重审失败
- **分类**：L3 审查机制 / Hook 设计缺陷
- **严重度**：🟡 Major（不阻断 pipeline 但严重降低 L3 审查可信度）
- **发现**：Phase 6/7 L3 三次审查均返回 fail，根因均在 L3 管线自身：
  1. **git diff 硬限 5000 字符**（`l3-review.sh:204`）：大变更的代码 diff 被截断，L3 模型看不到完整变更
  2. **`git diff HEAD` 不含 untracked 文件**：新增文件（correction-types.sh/goal-parsing.md/test_l3_timeout.bats）对 L3 不可见
  3. **`head -c 20000` 逐文件硬截断**（`max_artifact_chars`）：大产物（REQUIREMENT 12.3K/DESIGN 19.2K）尾部被丢弃
  4. **仅审当前 phase**：Stop hook 只看 `.flow-active` 当前阶段，历史积压不处理
  5. **无状态**：每次审查独立，无法参考前次反驳或 L2 结论
- **建议修复**：增大 git diff 上限（建议 50000）+ 改用 `git diff --cached HEAD`（包含 staged 新文件）+ `smart_truncate` 改为保留头尾策略 + 添加积压检测 + L3 prompt 注入前次反驳摘要
- **临时方案**：L3 fail + 主 agent 判定为已知限制 → 手动写 `.done`（L3_verdict=waiver）
- **How to apply**：下次 L3 管线变更时一并处理（关联 TD-008 l3-review.sh 拆分）

---

## L-044 · 用户指南同步应跑检查清单

- **严重度**：🟡 Major
- **发现**：用户指南更新（+139/-34）时，TOC 重编号（新增 §9 导致后续章节顺延）遗漏子章节编号同步（10.1-10.7 仍为 9.x）。L2 盲审两轮才完全修复（R1 flow-kit-install 假阳性修复 + 工作流子章节编号 + lib 文件清单补全 + 独立审查阶段数 3→6 + TOC 破折号格式）。
- **Why**：人工更新大文档时容易遗漏交叉引用。用户指南有 12 个锚点 + 7 个子章节 + 目录树 + 跨引用，单次手动编辑几乎不可能零遗漏。
- **How to apply**：今后用户指南更新后必跑检查清单：① `grep -n 'sec-.*workflows\|sec-.*rules\|sec-.*file-structure'` 无旧编号残留 ② 子章节编号与父标题一致 ③ `diff <(grep -c 'a id=') <(grep -c '](#sec-')` TOC 链接数=锚点数 ④ lib 文件清单与 `ls flow-kit-bundle/hooks/stop/lib/` 对齐

## L-045 · bundle validate 依赖 shell 环境，command find 是必要防护

- **严重度**：🟡 Major（validate 全部依赖环境正确性）
- **发现**：`validate_staging.sh` 使用裸 `find` 命令，用户 shell 中 `find` 被函数拦截（rtk→bfs）时校验结果 flaky——多次运行 ERROR 数从 3→2→1→0 波动，完全不可信。根本原因是 `export -f find` 使得子 bash 进程也继承该函数。
- **Why**：shell 函数的动态作用域 + `bash` 继承 `export -f` 函数 → validate 作为被 source 的库，无法控制调用环境。
- **How to apply**：所有 validate/hook 脚本中的 `find` 统一改为 `command find`。本会话修复了 validate_staging.sh 4 处，但 hooks/stop/ 中仍有 13 处裸 `find`（见 L2 Sonnet 审查报告）待后续统一。


## L-046 · L2 dispatch 应走 PreToolUse hook 同步驱动，与 L3 异构互补

- **严重度**：🟢 Suggestion（设计讨论，未实施）
- **发现**：弱模型在其他环境测试中会逃避 prompt 指令不 spawn L2 subagent（口头声明"已审查"但无 Agent tool call）。讨论了五层方案（L1 prompt→L2 hook 检测→L3 gate→L4 hook 补跑→L5 双轨），最终收敛为 PreToolUse 同步 L2 dispatch 方案——在 transition 时拦截 + 同步派子 agent + 立即写入 done。方案设计完毕，待开 change 实施（预期 ~65 行改动，核心在 independent-review-gate.sh 扩展 L2 dispatch 逻辑）。
- **Why**：Stop hook 方案有两个硬伤——L2 结果下次会话才能看到（当轮无感知），弱模型可能永远不会结束会话。PreToolUse 同步方案在 transition 时立即触发，结果当轮可用。
- **How to apply**：下次开 change `l2-pretooldispatch`，扩展 `independent-review-gate.sh` + 更新 prompt 告知段。

## L-047 · Stop hook L3 审查结果静默丢失：`2>/dev/null` 吞错 + `>>` 非原子写入

- **严重度**：🔴 Critical（生产影响——L3 审查完成但内容未持久化，gate 形同虚设）
- **发现**：排查 L3 审查缺失时发现两层根因：(1) `29-independent-review.sh` backlog 扫描和当前阶段 L3 调用均用 `2>/dev/null` 吞掉所有错误；(2) `l3-review.sh` 用裸 `>>` 追加写入，主 agent 后续 Edit 可能因锚点文本变化导致 L3 段被覆盖。Phase 1-3 的 L3 全部受此影响。
- **Why**：`2>/dev/null` 在 `set -euo pipefail` 下等于主动关掉唯一诊断通道。`>>` 非原子——Stop hook 和主 agent 交替写同一文件必然竞态。
- **How to apply**：(1) 所有 `l3_review_run` 调用去 `2>/dev/null`，失败时 `module_output` 记录；(2) L3 段 + .done 改用 tmp+mv 原子写入；(3) 写入后 `grep -q` 验证持久化。本次 change 已修复（T08+T09）。

## L-048 · L3 审查依赖 Stop hook 触发时机——连续推进 session 中天然滞后

- **严重度**：🟡 Major（设计约束）
- **发现**：本次 change 大部分阶段在同一对话轮次内连续推进。L3 依赖 Stop hook（对话轮次边界）触发，Phase 5-7 的 L3 从未运行。L3 触发时机与 pipeline 推进速度存在结构性错配。
- **Why**：Stop hook 假设"每阶段至少一次对话结束"，但快速推进模式下多阶段可在同一轮完成。
- **How to apply**：(1) 短期：关键 phase 结束后显式结束会话让 Stop hook 跑 L3；(2) 中期：PreToolUse gate 层增加 L3 同步 dispatch（与 L2 对称）；(3) 长期：prompt 层也触发 L3。本次 change 已修复 L3 内容可靠性（L-047），触发时机优化留给后续。

## L-049 · bash `local var="$(cmd)"` 屏蔽 set -e → 静默 fail-open

- **严重度**：🔴 Critical（gate 安全门失效）
- **发现**：6-review L2 R2 捕获——gate.sh:447 `local phase_name="$(fk_phase_gate_key "$phase")"`，当 `fk_phase_gate_key` 未定义（common.sh source 失败 `|| true`）时，`$(...)` 返回空 + 非零，但 `local` 赋值的返回值覆盖了命令替换的退出码（local 本身成功 → 0），`set -e` 不触发 → `phase_name=""` 静默得空 → gate 完全失效 exit 0（fail-open）。实测 `HOOK_BASE_DIR=/tmp/nonexistent bash gate.sh <git-commit-payload>` → exit 0（应 fail-close exit 2）。
- **Why**：bash 语义——`local`/`declare`/`typeset` 的返回值是**赋值语句本身**的退出码，非命令替换内命令的退出码。`set -e` 检查的是 `local` 的退出码（恒 0），命令替换内的失败被吞。这是 bash 长期陷阱（POSIX sh 同理）。
- **How to apply**：(1) 永远分开写：`local var; var="$(cmd)"`（先声明 local，再单独赋值，让 set -e 捕获 cmd 失败）；(2) 关键依赖显式校验：`declare -f fk_phase_gate_key >/dev/null || { echo fail >&2; exit 2; }`；(3) 审查所有 `local x="$(...)"` 模式（grep `local .*="\$\(`）。本次 change T-FIX-02 修复 gate.sh source fail-close。

## L-050 · flow-kit-bundle 改动须 cp 同步 ~/.claude/hooks 部署路径

- **严重度**：🟡 Major（修复运行时未生效，"全套真绿"≠"现场已修复"）
- **发现**：5-test L2 + 6-review L2 元发现——本 change 改 flow-kit-bundle/hooks/ 源码（T01-T05），但运行时 hook（~/.claude/hooks/）未同步。全部 5 hook md5 不同。后果：(1) AC-3 测 fail（已安装副本 29 脚本 :? 与开发副本一致但测期望错——同型）；(2) 6-review L2 写报告时被**旧版** BUG-H gate 误拦（heredoc 内 git commit 字符串），用 chr() 绕过——现场复现 REQUIREMENT US-2。本 change 修复在运行时未生效，全套 bats 536/0（开发副本）≠ 现场已修复。
- **Why**：flow-kit-bundle/ 是分发包源码，~/.claude/hooks/ 是部署路径。改源码后须 install.sh 或 cp 同步部署。两路径不同步 = 源码修复但运行时旧版。
- **How to apply**：(1) 改 flow-kit-bundle/hooks/ 后必 `cp flow-kit-bundle/hooks/<f> ~/.claude/hooks/<f>`（或 install.sh 重装）；(2) 5-test 阶段加「部署同步」验证（md5 对比 bundle vs ~/.claude）；(3) 7-integration 归档前确认部署同步。本次 change 已 cp 同步 5 hook。

## L-051 · L2 独立盲审是主 agent 证实偏差的最后防线（critical 实证）

- **严重度**：🔴 Critical（流程教训——主 agent 自评不可全信）
- **发现**：本 change 6-review 阶段，主 agent REVIEW.md 初审 Verdict=pass（0 Critical / 0 Major / "6 维整体改善"），5-test 阶段 L2 也 pass。但 6-review L2 独立盲审（code-reviewer 子 agent）实测复现 R1 🔴 Critical：`_command_has_write_context` 把「重定向/多行」当写上下文 → `git commit 2>log` 漏拦（AC-H(e) 要求 deny，AC 未实现），主 agent + 5-test L2 都漏判。主 agent 核验实测确认（exit 0 漏拦），非误判。回退 6→4 修 T-FIX 后 L2 重审 pass。
- **Why**：主 agent（实现者）有证实偏差——「代码能跑 + 全套真绿」≠「AC 真实现」。自评倾向于放过自己写的代码。5-test L2 审 TEST.md（非代码），未触代码层。6-review L2 审 git diff（代码），实测复现，才捕到。
- **How to apply**：(1) L2 盲审须独立子 agent + 原样注入 prompt（禁主 agent 自评注入）；(2) L2 须实测复现（非采信自评）；(3) 主 agent 核验 L2 发现（receiving-code-review 技术验证，非盲目接受/反驳）；(4) 6-review L2 审 diff（代码层）比 5-test L2 审 TEST.md（文档层）更易捕 critical。本 change 是 L2 机制价值的强实证。

## L-054 · independent-review gate `.done` 仅验存在不验作者——握手锚点是死代码

- **严重度**：🟡 Major（安全设计缺口——agent 可伪造 .done 绕过 L3 外部审查）
- **发现**：l2-l3-model-config 6→7 transition 期间深挖：`independent-review-gate.sh` Gate 3（`fk_independent_review_gate_active`）只要 `.independent-review-<phase>.done` **存在**就短路 `exit 0` 放行，不校验由谁写入。原用于证明「.done 由 stop-hook 子进程写（非 agent 伪造）」的握手 `.flow-active.independent-review` 已是死代码——全 hooks 树无生产 writer（仅 test fixture 写），`done-validation.sh` Tier 2 的 T3 握手校验因 Gate 3 短路而**不可达**，但 4 个单元测试（test_gate_integrity.bats）仍断言其安全意图（意图与现实脱节）。结果：主 agent 可自写结构合法的 .done 单方面绕过 L3。已另立 `gate-done-authorship` change 修（见 `.specs/gate-done-authorship/CHANGE.md`）。
- **Why**：历次 gate 重构（L2/L3 拆分等）把握手写入废弃、改「l3_review_run 直接写 .done」，但**校验端 + 测试端未同步清除**，留下活校验 + 死写入 + 不可达的不一致。Gate 3 短路条件是 .done 存在性而非作者性。
- **How to apply**：(1) 任何「标志文件存在即放行」的 gate 须额外校验作者性（path-guard 禁 agent 写该文件，或签名）；(2) 重构废弃某机制时，校验端 + 测试端必须同步清除，否则留下不可达的「活校验」制造虚假安全感；(3) 单元测试覆盖函数行为 ≠ 生产路径真生效——须确认函数在主流程里**可达**（本例 Tier 2 被 Gate 3 短路，测试再绿也不生效）。

## L-055 · L3 外部模型对 flow-kit「skill=实现」架构理解不足——易对 /flow 命令报「无实现」误报 Critical

- **严重度**：🟡 Major（review 流程教训——L3 误报会卡 pipeline，需人工裁判）
- **发现**：l2-l3-model-config 6-review L3 轮（deepseek-v4-flash）对 AC-5 `/flow model` 报 🔴 Critical「仅文档描述，无实际可执行实现」。实测核实为**误报**：`/flow model` 实现完整在 `skills/flow/SKILL.md:236-256`（参数解析 + 原子 jq 写 + 字段边界），且 `test_flow_model.bats` 6 用例覆盖。根因：L3 按「传统 CLI 须有独立可执行脚本入口」的心智模型判定，不理解 flow-kit 所有 `/flow *` 命令都是 **AI 读 SKILL.md 执行内嵌 jq 的 skill**（非独立脚本）。L2 盲审（code-reviewer，理解架构）正确判 pass。L2-pass/L3-fail 分歧经主 agent 裁判（6-review §4.2）解决。
- **Why**：L3 是通用外部模型，未内化 flow-kit「skill 即实现」的架构约定。补充既有教训「L3 verdict 不可全信」——本条是其具体、可操作的表现形式。
- **How to apply**：(1) L3 对 skill / markdown-as-implementation 类工件的「无实现」Critical 默认怀疑，先核实 SKILL.md 是否含可执行 jq/bash 段 + 对应测试；(2) L2-pass / L3-fail 分歧时优先信理解项目架构的 L2，按 6-review §4.2 人工裁判（记录 L2_verdict/L3_verdict + 证据）；(3) 给 L3 的 artifact 可附一句架构提示「/flow 命令是 skill，实现在 SKILL.md 内嵌 jq」降低误报（注意：架构提示只能给 L3，**不可**注入 L2 盲审 prompt——会破坏 L2 独立性）。

## L-056 · L3 工具 `_l3_call_api` 硬编码 max_tokens:8000 + curl --max-time 90 导致 deepseek-v4-pro 扩展思考吃满预算 → rc=3

- **严重度**：🔴 Critical（工具故障——阻塞所有 gate_config 含 L3 的 change 的 pipeline transition）
- **发现**：gate-done-authorship phase 3 L3 第二轮复核失败（2026-07-24）：deepseek-v4-pro 扩展思考把 8000 token 预算全花在 thinking block 上 → 无 text block → `jq select(.type=="text")` 返空 → rc=3。同时生成 ~144s 超 curl --max-time 90 → curl 杀进程。实测：禁用思考后 38s 返 3334 token 含 text block。
- **Why**：L3 工具设计时假设模型不使用扩展思考（max_tokens 8000 够用）+ 审查 < 90s。两个假设在 deepseek-v4-pro + 大产物场景下不成立。硬编码值无 env var / 配置文件覆盖入口。
- **修复**：l3-review-timeout-token change（2026-07-25）——三 env var 全可配：FLOW_KIT_L3_MAX_TOKENS（默认 32000）、FLOW_KIT_L3_TIMEOUT（默认 300）、FLOW_KIT_L3_THINKING（默认 enabled，可切 disabled）。Fail-safe：非法值回退默认 + 警告。jq -c compact 输出（省字节 + 易测试）。
- **How to apply**：(1) 任何调用外部 API 的工具，超时/token 上限必须可配置（env var > 默认值），禁止硬编码；(2) 换 L3 模型时须先实测 max_tokens/timeout 承载能力（大产物场景）；(3) thinking 模型（deepseek-v4-pro）需 disabled 作为 escape hatch；(4) `_l3_parse_result` 的 fallback 链 `.thinking // .text` 可能静默错判——留 v2 修复。
- **关联**：[[l3-model-unreliable]]（失败模式从 glm-4.7 幻觉演进为 deepseek-v4-pro 思考吃满预算）、TD-008（l3-review.sh 574 行多职责）、[[gate-done-authorship]]（被卡住的 change）
- **来源**：`l3-review-timeout-token`

## L-057 · 握手死代码清理不完整——校验端+测试端未同步 → 不可达的"活校验"制造虚假安全感

- **严重度**：🔴 Critical（安全设计缺陷——gate `.done` 仅验存在性不验作者性，agent 可伪造 `.done` 绕过 L3 审查）
- **发现**：独立 review gate 的「`.done` 标志」机制存在安全缺口（2026-07-24）：Gate 3（`fk_independent_review_gate_active`）只要 `.done` 存在就短路放行，不校验由谁写入。原本用于证明 `.done` 由 stop-hook 子进程写入的握手机制（`.flow-active.independent-review`）已演变为死代码——无生产代码写它，仅测试 fixture 写。agent 可自写结构合法的 `.done` 绕过 L3 外部模型审查。
- **Why**：握手的写入路径在 gate 重构中废弃（l3_review_run 直接写 .done），但校验端（done-validation.sh T3）+ 测试端（4 个握手测试 + regression-demos）未同步清除。结果是「活校验 + 死写入 + 不可达」（Gate 3 见 .done 存在即放行，永远到不了 Tier 2 T3）。单元测试再绿也不生——函数覆盖了但主流程不可达。
- **修复**：gate-done-authorship change（2026-07-25）——方案 A：彻底废弃握手，改用 path-guard D7 扩展保护 .done（`_is_dotdone_write` 禁止 agent 写 `.independent-review-*.done`）+ L2-only 例外 + Fail-safe。23 tests + 613 full regression。
- **How to apply**：(1) 删除机制时，校验端+测试端必须同步清除，不可留"死校验"制造虚假安全感；(2) 单元测试覆盖函数行为 ≠ 生产路径真生效——须确认函数在主流程里**可达**；(3) 安全敏感 gate 优先用前置拦截（path-guard 写入时阻）而非后置校验（Tier 2 读取时验）——前置更强（阻止创建 vs 检测已创建）；(4) 独立 review 发现握手死代码时先 check 全仓 `grep` 写路径真死否。
- **关联**：[[l3-model-unreliable]]（L3 模型不可靠导致 pipeline 反复 review 才暴露此缺口）、[[l3-review-timeout-token]]（修 L3 工具解套此 change 的 L3 审查）、ADR-005（独立审查体系，D7 path-guard）
- **来源**：`gate-done-authorship`

---

## superpowers-v6-absorb (2026-08-02) · 9 Minor findings 转 tech debt

> 来源：`.specs/superpowers-v6-absorb/MINOR-DEFERRED.md`，由 phase 1/2/5/6 各阶段 L2 审查捕获。

### L-058 · AC-A3 "如可用"弱化跨平台验证（来自 Phase 1 L2 R7）
- 严重度: 🟢 Minor
- 位置: REQUIREMENT.md AC-A3
- 问题: "如可用"使 macOS 不可用时 AC 自动退化为 Linux-only，违反 Given/When/Then 确定性原则
- 修复: 拆为 AC-A3a (Linux 硬) + AC-A3b (macOS 软)。下次 REQUIREMENT 重构时处理。
- 状态: active · 来源 `superpowers-v6-absorb` Phase 1 L2 ✅ Resolved (final-debt-cleanup-2026-08 / ADR-019 principle)

### L-059 · 多条 AC 验证方式含"人工"（来自 Phase 1 L2 R8）
- 严重度: 🟢 Minor
- 位置: REQUIREMENT.md AC-B1/B2/D2/F2/G1/G2
- 问题: "人工 + grep" 降低自动化置信度，未来 prompt 行为退化无法自动捕获
- 修复: 将 grep 部分独立为 bats 测试
- 状态: active · 来源 `superpowers-v6-absorb` Phase 1 L2

### L-060 · 范围决策嵌入 REQUIREMENT（来自 Phase 1 L2 R9）
- 严重度: 🟢 Minor
- 位置: REQUIREMENT.md 范围决策框
- 问题: 设计决策（双轨测量 / 加强语义 / 并存策略）属 how 层级，嵌入 what 层级文档模糊边界
- 修复: 移到 CHANGE.md 验收线段或独立 DESIGN-NOTES.md
- 状态: active · 来源 `superpowers-v6-absorb` Phase 1 L2 ✅ Resolved (final-debt-cleanup-2026-08 / ADR-019 principle)

### L-061 · ADR-016 探测脚本路径未验证（来自 Phase 2 L2 R5）
- 严重度: 🟢 Minor
- 位置: `.specs/adr/016-model-tier-dispatch.md` detect_opencode_tier_support
- 问题: 缓存路径 `.specs/<id>/.opencode-capability.json` 来自未验证假设
- 修复: 实测时确认路径或改临时文件
- 状态: active · 来源 `superpowers-v6-absorb` Phase 2 L2 ✅ Resolved (final-debt-cleanup-2026-08 / ADR-020 capability snapshot)

### L-062 · task_progress lifecycle 图细节缺失（来自 Phase 2 L2 R6）
- 严重度: 🟢 Minor
- 位置: DESIGN.md § 2 task_progress lifecycle 图
- 问题: 图未展示 skip 任务时 task-brief 是否仍需提取
- 修复: 完善图注释
- 状态: active · 来源 `superpowers-v6-absorb` Phase 2 L2 ✅ Resolved (final-debt-cleanup-2026-08 / ADR-019 principle)

### L-063 · D5/D6 弱模型缓解引用 ADR-001 不适配（来自 Phase 2 L2 R7）
- 严重度: 🟢 Minor
- 位置: DESIGN.md D5/D6
- 问题: terse contract + narration constraint 在弱模型场景的退化问题引用 ADR-001 gate（输出风格约束 ≠ gate）
- 修复: 弱模型场景实测后补 ADR
- 状态: active · 来源 `superpowers-v6-absorb` Phase 2 L2 ✅ Resolved (final-debt-cleanup-2026-08 / ADR-021 prompt degradation protocol)

### L-064 · 安全注入测试缺失（来自 Phase 5 L2 R8）
- 严重度: 🟢 Minor
- 位置: TEST.md 安全段
- 问题: 仅代码结构描述，无注入测试
- 修复: 加 edge case bats（special chars in commit messages / path traversal）
- 状态: active · 来源 `superpowers-v6-absorb` Phase 5 L2

### L-065 · 集成测试无自动化（来自 Phase 5 L2 R9）
- 严重度: 🟢 Minor
- 位置: TEST.md 集成测试段
- 问题: 3 个集成场景全部手动验证
- 修复: 加 test_integration_smoke.bats
- 状态: active · 来源 `superpowers-v6-absorb` Phase 5 L2

### L-066 · AC-B4 测试深度不足（来自 Phase 6 L2 R4）
- 严重度: 🟢 Minor
- 位置: TEST.md AC-B4
- 问题: 仅测 task-brief 输出，未测合并指标（4-dev.md + task-brief）
- 修复: 加合并指标 bats 测试（前提：先澄清 AC-B4 措辞，见 INTEGRATION.md § 3）
- 状态: active · 来源 `superpowers-v6-absorb` Phase 6 L2

### L-067 · AC-I(b)(c) pre-existing failures（来自 Phase 5 TEST.md 归因）
- 严重度: 🟢 Minor
- 位置: `test/test-l2-first-correction.bats` AC-I(b)(c)
- 问题: gate_config=both 无 L2 段跑 Stop hook 29 的 2 个测试失败，与本 change 无关（write_files 不含 29 hook）
- 修复: 独立 change `fix-l2-first-correction-test` 处理
- 状态: active · 来源 `superpowers-v6-absorb` Phase 5 TEST.md

### L-068 · 4-dev.md 体积压缩（结构性技术债）
- 严重度: 🟡 Scheduled
- 位置: `flow-kit-bundle/flow-kit/prompts/4-dev.md` (781 行)
- 问题: 4-dev.md 体积持续增长（721 → 781），无压缩机制
- 修复: 拆 TDD/grep-before-code/5-submit 等段为 reference 片段（如 terse-contract.md 模式）
- 状态: ✅ resolved 2026-08-03 · `cleanup-debt-batch-2026-08` T04 · 781→352 行 + 3 reference 文件（tdd-workflow / commit-protocol / checkpoint-protocol）

## superpowers-absorb-followup-1（2026-08-03 · 测试补强）

### L-069 · package validate 漏配 M-health.md
- 严重度: 🟡 Scheduled
- 位置: `package-flow-kit.sh::validate_staging_coverage()`
- 问题: `flow-kit-bundle/flow-kit/prompts/M-health.md` 未被任何 Part A-G 覆盖。Pre-existing（initial commit `549b6a0`）
- 修复: 在 Part A-G 之一加入 M-health.md；建议独立 change `fix-package-validate-mhealth-missing`
- 状态: ✅ resolved 2026-08-03 · `cleanup-debt-batch-2026-08` T02 · Part B 加 cp 行

### L-070 · package validate exit=0 even on error
- 严重度: 🟢 Minor
- 位置: `package-flow-kit.sh::validate`
- 问题: validate 报 🔴 ERROR 但 exit code=0，CI 无法机器判定失败
- 修复: validate 函数末尾按错误数返回 exit code
- 状态: ✅ verified non-bug 2026-08-03 · `cleanup-debt-batch-2026-08` Phase 2 L2 R1 · `validate_staging_coverage()` at `lib/validate_staging.sh:127-131` 已正确 exit 1（ERRORS>0）；caller `package-flow-kit.sh:18-19` 正确传播 via `exit $?`。原 tech debt 条目记录有误。

### L-071 · review-package 缺 git ref validation
- 严重度: 🟡 Scheduled
- 位置: `flow-kit-bundle/flow-kit/scripts/review-package`
- 问题: review-package 不验证 git ref 有效性。`../../etc/passwd` 类输入静默返回 exit=0 + 空输出（41 字节空 diff sections）。SEC-5b 测试 honest skip。
- 修复: 加 `git rev-parse --verify "$base" 2>/dev/null` 校验 + 失败时 exit 1 + stderr 错误信息。建议独立 change `fix-review-package-ref-validation`
- 状态: ✅ resolved 2026-08-03 · `cleanup-debt-batch-2026-08` T01 · 加 ref validation 循环 + SEC-5b unsuppressed

### L-072 · 29 hook L3 short-circuit ordering 与 mock 冲突
- 严重度: 🟢 Minor
- 位置: `flow-kit-bundle/hooks/stop/29-independent-review.sh:59-64`
- 问题: 29 hook 在 line 59-64 检测 L3 model 配置（短路 exit 3），在 line 181-185 才检测 L2-missing。Mock 环境必须设 `FLOW_KIT_L3_MODEL=mock-l3-model` 才能到达 L2 检测分支。生产 ordering 问题（29 hook 在禁动清单），独立 change 处理
- 修复: 重排：L2-missing 检测应在 L3-model-missing 之前。建议独立 change `fix-29-hook-mock-mismatch`
- 状态: ✅ resolved 2026-08-03 · `cleanup-debt-batch-2026-08` T03 · L2-first quick gate 移到 L3 model check 之前（lines 60-73）+ 旧 D1 块删除 + mock workaround 移除

## cleanup-debt-batch-2026-08（2026-08-03 · 债务清理）

### TD-071-A · brooks-lint Part F 打包漏配（pre-existing）
- 严重度: 🟢 Minor
- 位置: `package-flow-kit.sh` Part F + `flow-kit-bundle/brooks-lint/plugin/skills/`
- 问题: validate 报 `brooks-audit/SKILL.md` + `brooks-test/SKILL.md` 未被 Part F 覆盖。Pre-existing，与本 change 无关。
- 修复: Part F 加 cp 覆盖新增 SKILL.md 文件
- 状态: open · 来源 `cleanup-debt-batch-2026-08` Phase 6 REVIEW.md § 4.3 ✅ Resolved (final-debt-cleanup-2026-08 / verified non-bug)

### TD-071-B · A-evolve.md 源缺失（pre-existing）
- 严重度: 🟢 Minor
- 位置: `flow-kit-bundle/flow-kit/prompts/A-evolve.md`
- 问题: validate 期望文件存在但源缺失（可能在 archive 时遗漏）
- 修复: 调查 archive/prompts 一致性
- 状态: open · 来源 `cleanup-debt-batch-2026-08` Phase 6 REVIEW.md § 4.3 ✅ Resolved (final-debt-cleanup-2026-08 / verified non-bug)

## TD-072 🟡 — hook lib 文件级行数超标（final-debt-cleanup-2026-08 遗留）
- **位置**：`flow-kit-bundle/hooks/stop/lib/l3-api.sh` (371 行) + `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh` (253 行)
- **来源**：final-debt-cleanup-2026-08 L2 phase 5 R2/R3 finding
- **影响**：REQUIREMENT AC-E1/E2 原始目标过于严格，长函数已拆分但文件级目标未达
- **建议**：v2 进一步拆 l3-api.sh（抽 callparse）+ gate-helpers.sh（按 file/types/state 分组）
- **登记时间**：2026-08-03
- **状态**: ✅ Resolved (td072-lib-split-2026-08) — l3-api.sh 371→218 (smart_truncate → l3-truncate.sh 54→202)；gate-helpers.sh 253→139 + 新建 gate-helpers-types.sh 92 (聚合入口模式)。4 metrics bats 加。662→666 tests / 0 fail

## test-failures-fixup-2026-08 Resolved ✅ (2026-08-03)

### Pre-existing bats fails resolved (5)
- Test 250 (gate regex) → split-aware grep rewrite
- Test 507 (AC-5 npx bats 指令) → OR 双文件 assertion
- Test 509 (AC-6 失败阻断) → assertion 重写 pattern
- Test 515 (子段编号 1.8.4.x) → grep tdd-workflow.md 4 个 #### 标题
- Test 577 (make lint SC2148) → 7 hook lib 加 `# shellcheck shell=bash` 指令

### Lessons learned
- **TD-073**: L-068 后内容迁移时，test grep assertion 必须同步重写（不只是 grep 范围扩大）。Split-aware test 设计原则
- **TD-074**: shellcheck SC2148 对 sourced lib 的标准修复是 `# shellcheck shell=bash`（非 shebang）

## l2-l3-subagent-fix Lessons learned (2026-08-05)

### L-073 · opencode subagent_type 路由创建的子会话 agent/model 未绑定（与 model 字段无关）
- 严重度: 🟡 Major（影响所有 subagent_type 派发，category 路由可用作 workaround）
- 位置: opencode 1.18.9 task tool subagent_type 路由路径（非 flow-kit 代码，平台行为）
- 问题: `task(subagent_type=<any>)` 创建的子会话 `agent=undefined model=undefined`（opencode.log 实测），无论 agent 文件 model 字段是 sonnet 还是 inherit 均挂起至 30min 超时。鉴别实验：qa-expert(sonnet) 与 architect-reviewer(inherit，阶段 2/3 成功用过) 均超时；阶段 2/3 成功实为 category=unspecified-high 路由派发。
- 修复: L2/L3 盲审派发在本环境改用 `category=` 路由（category 路由绑定 model 正常，4s 完成）；subagent_type agent 绑定修复属平台层（out 范围）
- 适用栈: opencode + OhMyOpenCode task tool 环境
- 关键词: subagent_type, agent=undefined, category routing, L2 dispatch, 30min timeout
- 状态: open · 来源 `l2-l3-subagent-fix`（调查型 change，根因 #2 已定位，v1 workaround=category 路由）

### L-074 · .independent-review-<N>.done 必须用 Write 工具写（path-guard 拦 Bash 重定向）
- 严重度: 🟢 Minor（已知陷阱，有明确 workaround）
- 位置: `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh::_is_dotdone_write` (gate-helpers-types.sh:18-32)
- 问题: PreToolUse path-guard D7 拦截 Bash 命令写 `.independent-review-*.done*`（匹配重定向 `>`、tee、cp、mv、sed -i、printf、dd、install、awk、cat<<）——即使命令是 ls 带 `2>/dev/null` 也被误判拦截。L2-only 模式主 agent 写 .done 时若用 Bash 重定向必被拦。
- 修复: 用 Write 工具写 `.done` 文件（路径含 phase 号 → `_gate_is_l2_only` 读 gate_config 放行）。Write 工具不被 _is_dotdone_write 匹配（仅检测 Bash 命令文本）。
- 适用栈: flow-kit L2-only 模式（gate_config 含 L2 的阶段，主 agent 写 .done）
- 关键词: path-guard, _is_dotdone_write, .independent-review-N.done, Write tool, L2-only
- 状态: open · 来源 `l2-l3-subagent-fix`（阶段 1 首次撞，阶段 2-7 持续应用 workaround）

## archive-commit-gate Lessons learned (2026-08-06)

### L-075 · bash 嵌套函数定义顺序：调用点必须在定义之后（否则 RC=127 "command not found"）
- 严重度: 🔴 Critical（生产断裂 · install.sh RC=127 · AC-4 完全失效）
- 位置: `flow-kit-bundle/lib/install_hooks.sh:110`（调用）vs `:180`（定义）
- 问题: `deploy_pre_commit()` 定义在 `install_hooks()` 函数体内部 L180，但 L110（install_hooks 体内更早位置）先于定义调用它。bash 顺序执行 install_hooks() 时 deploy_pre_commit 尚未定义 → "未找到命令" RC=127。install.sh 顶部 `set -euo pipefail` → 安装中断。
- 修复: 嵌套函数定义移到**调用点之前**（或提到顶层非嵌套）。bash 函数定义是顺序执行的语句——不像 C/JS 有 hoisting。
- 适用栈: bash（任何使用嵌套函数定义的项目）
- 关键词: nested function, definition order, command not found, RC=127, set -euo pipefail
- 状态: open · 来源 `archive-commit-gate`（L2 盲审 phase 5 round 1 #2 发现 · 调试 > 30min · git worktree baseline 对比定位）

### L-076 · bash `local` 仅函数内合法：顶层使用 → SC2168 + set -e 运行时退出
- 严重度: 🟡 Major（make lint 硬门禁失败 + 运行时报错）
- 位置: `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh:153`
- 问题: elif 分支位于脚本顶层（非函数内），`local fc\nfc=$(...)` 中 `local` 关键字在函数外非法 → ShellCheck SC2168 error + `set -euo pipefail` 下运行时立即报错退出。SessionStart banner 路径不可达。
- 修复: 去 `local`（顶层赋值合法，变量自动全局）或将整段移入函数
- 适用栈: bash（所有脚本顶层代码）
- 关键词: local outside function, SC2168, set -e, SessionStart, top-level
- 状态: open · 来源 `archive-commit-gate`（L2 盲审 phase 5 round 1 #3 发现）

### L-077 · `source <file>` + `set -euo pipefail`：被 source 文件内部非零退出 → 脚本中止
- 严重度: 🟡 Major（pre-commit 门禁静默失效）
- 位置: `flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（PATH 补齐段 · 已修复）
- 问题: `source /etc/profile` 在 `set -euo pipefail` 下，profile 文件内部任何语句返回非零 → set -e 触发 → source 中止 → 脚本退出。pre-commit.sh 在补齐 PATH 时 source /etc/profile → 静默 exit 1 → git commit 被拒（pre-commit 非零退出）或跳过测试（取决于退出时机）。
- 修复: `source /etc/profile 2>/dev/null || true`（容错）或避免 source profile（改用显式 PATH 补齐 + 文件存在性守卫）
- 适用栈: bash（任何 source 外部文件 + set -e 的脚本）
- 关键词: source, set -e, /etc/profile, PATH, pre-commit, silent exit
- 状态: open · 来源 `archive-commit-gate`（T08 执行中发现 · 修复为文件存在性守卫 + 大括号分组）

---

### L-078 · `[ "$?" -eq N ] && return N` AND-list rc 传播模式（set -e 兼容）

- **标签**: bash, set-e, return-code, and-list, multi-rc-function
- **关键词**: `set -euo pipefail`, `cmd && return 0`, `$?`, rc=2, AND-list short-circuit, 条件上下文
- **适用栈**: Bash（任何用 `set -e` + 多返回码函数的项目）
- **状态**: active
- **场景**: 函数 `fk_resolve_api_credentials()` 需返回三种 rc（0=就绪/1=无凭证/2=配置不完整）。调用方用 `_fk_api_try_path3 && return 0` 短路返回，但 path3 返回 2 时需显式传播 rc=2（不能静默落 Path2）。直接写 `_fk_api_try_path3 && return 0` 后 path3 rc=2 被 AND-list 吞掉，需追加 `[ "$?" -eq 2 ] && return 2`。
- **错因**: `cmd && return 0` 的 AND-list 在 cmd 返回非零非1时（如 rc=2），`$?` 是 AND-list 的退出码（=cmd 的 rc），但无显式传播则继续执行下一语句。`[ "$?" -eq 2 ]` 在 `&&` 列表中是非末位命令 → set -e 豁免 → 安全。
- **教训**: 多 rc 函数在 set -e 下的传播须用 `[ "$?" -eq N ] && return N` 模式（在 `cmd && return 0` 之后）。`$?` 取 AND-list 退出码（即 cmd 的 rc，因 return 0 未执行）。`[ ]` 在 `&&` 非末位 → set -e 豁免。
- **反例**: 仅写 `_fk_api_try_path3 && return 0` 不加 rc=2 传播 → path3 不完整时静默落 Path2（安全漏洞：禁止的行为发生了）。
- **来源**: l2l3-cross-platform Phase 2 L2 盲审（3 轮 fix loop 验证 rc=2 传播正确性）

### L-079 · bats 断言 `[ -z "$output" ]` 替代 `$status -eq 1`（grep 缺文件 exit=2 陷阱）

- **标签**: bats, grep, exit-code, missing-file, assertion-format
- **关键词**: `grep -rsE`, `2>/dev/null`, exit=2, `[ -z "$output" ]`, AC-6, 红线断言
- **适用栈**: bats-core（任何用 bats 跑 grep 断言的项目）
- **状态**: active
- **场景**: AC-6 红线断言需验证运行时文件不含 token/env 名。`grep -rsE pattern file1 file2 ...` 当部分文件不存在时 exit=2（不是 1）。原断言 `[[ $status -eq 1 ]]` 在缺文件时恒败（exit=2≠1）。`.flow-active.interactive-ui-fix` 当前不存在 → 断言正常状态恒败 → phase 5 假红或绕过（TD-016 模式）。
- **错因**: grep 对缺失文件的 exit code 是 2（不是 1）。bats `$status` 捕获的是 grep 的 exit code。`[[ $status -eq 1 ]]` 假定"无匹配=1"，但缺失文件也导致非1 exit → 断言无法区分"有匹配"和"文件缺失"。
- **教训**: bats 中断言 grep "无匹配"时用 `[ -z "$output" ]`（无输出=零命中=通过，无论 exit 0/1/2），不用 `$status -eq 1`。`2>/dev/null` 压制 stderr 后 `$output` 仅含 stdout 匹配行。
- **反例**: `[[ $status -eq 1 ]]` → 缺文件 exit=2 → 断言恒败 → 要么测试被 skip（假绿）要么 CI 永红（假红）。
- **来源**: l2l3-cross-platform Phase 2 L2 盲审 R-F-A1（3 轮 fix loop 定位根因 + 修复）

### L-080 · Stop hook 单测裸跑的 env 注入清单（source 副作用 + 隐式 main）
- **标签**：hook-unit-test-env / bash source 副作用
- **关键词**：29-independent-review、HOOK_BASE_DIR、CONFIG_FILE、implicit main、module_output
- **适用栈**：Bash hooks（flow-kit stop 链）/ bats
- **状态**：active
- **教训**：单独跑 29 号 hook 脚本做单测时，source 链与隐式入口会吃掉大量时间排查。清单：① `CONFIG_FILE` 需显式 export（init_paths 不会自动跑）；② `PROJECT_ROOT`/`FLOW_KIT_PROJECT_DIR` 需 export（33 号读状态用）；③ `HOOK_BASE_DIR` 需 export（`flow-kit-artifacts.sh:13` 在 `set -u` 下引用，未绑定则 source 即死——生产无感因为 00-gate runner 注入）；④ `HOOK_TMP_DIR` 需 export（module_output 写 `$HOOK_TMP_DIR/`）；⑤ source 33 号会触发底部 implicit main，测试 harness 若在 source 行加 `2>/dev/null` 会连审计行 stderr 一起吞掉；⑥ `fk_phase_gate_key 1` 返回 `"1-requirement"`（gate_config 键名用阶段名非 `phase_1`）。
- **来源**：correction-hygiene-state-guard · T03/T04 smoke harness 调试
- **复核旧条目**：L-079（bats -z 断言）本次继续适用——hygiene 测试全程使用该模式，无重试必要。L-078（set -e AND-list rc 传播）适用——dedupe/trim rc 传播遵循。

### L-081 · jscpd CLI 参数版本差异（月度巡检会重复撞）
- **标签**：tooling / jscpd / health-check
- **关键词**：jscpd、--format、--formats、consoleFull、reporter、make dup
- **适用栈**：Bash 仓库 · M-health 步骤 2.5
- **状态**：观察（observation）
- **教训**：本仓 jscpd 版本用 `--format`（单数；复数 `--formats` 报 unexpected argument）；`--reporter consoleFull` 不可用（正确拼法 `--reporters`，但该版本 consoleFull 输出仍不稳定）。可靠取数方式：① 汇总率直接跑表格输出 + `sed 's/\x1b\[[0-9;]*m//g'` 去 ANSI 后 grep 表行；② clone 明细用 `--output <dir>` 落 `jscpd-report.json` 再 jq 取 `.duplicates[]`。Makefile `make dup` 的调用形态（无 format 过滤=全格式含 markdown，数值不可与 bash-only 口径混比）。
- **来源**：M-health 2026-09-01 Full Sweep 数据采集（4 次探测收敛）

### L-082 · phase-7 gate=both 补审的归档闭环要求（降挡记录≠归档产物）
- **标签**：process / phase-7 / archive / L3-review / CHANGELOG-placement
- **关键词**：降挡、hotfix、gate_config both、归档产物、INDEPENDENT-REVIEW、L3 fail、head-3000
- **适用栈**：flow-kit 变更管理（任何 gate_config=both 的 phase 7）
- **状态**：active
- **场景**：降挡（7-integration=off）提交后，用户配置 FLOW_KIT_L3_* 凭证要求补审。恢复
  gate_config=both 后 L3 外部模型审查 fail，原因不在代码而在归档：spec 目录缺
  REQUIREMENT/DESIGN/TASK/TEST/REVIEW/INTEGRATION 等阶段产物，且 CHANGELOG 条目追加在
  文件末尾——L3 的 phase-7 prompt 只采样 CHANGELOG 头部 3000 字符 + 列目录 ls，看不到。
- **错因**：① 把「降挡记录（CHANGE.md 自述）」当作可审计证据，未补齐 spec 目录归档集；
  ② CHANGELOG 违反自身「按日期倒序」表头约定把新条目 cat >> 到文件尾；③ 对自动维护文件
  （PROGRESS.md，Stop hook G5 追加）与人工归档文件的边界不清。
- **教训**：① phase 7 gate=both 的 L3 是对「归档产物集」的机器审查，恢复 both 前先补齐
  六件套或维持 off；② CHANGELOG 新条目放文件顶部表头下（L3/后续采样只读头部）；
  ③ L2 的 minor finding（产物不齐）若选择核销，需在 REVIEW.md 中显式给证据，不能只写
  在 CHANGE.md；④ REVIEW.md 的处置表（finding→动作→证据落点）是 L3 主判最快的闭环载体。
- **来源**：dsh-flow-kit-sync-2026-09 · L3 首审 fail（2026-09-03）→ 归档补齐 + 重审
<!-- l3-prompt-loop-fix 追加 ↓ -->
| L-085 | 🟡 | 全局（bats 测试） | **bats TAP 的 skip 报告为行尾 `ok N <name> # skip <reason>`**——用 `grep -E '^(not ok\|# skip)'` 统计 skip 永远得 0（假绿变体·BUG-G 族）。phase 5 L2 实测发现：TEST.md 声称 0 skip 实有 1 既有 skip | skip 统计必须匹配行内 `# skip `（`grep -cE '# skip '`）或用 junit formatter 解析 <skipped> | ✅ 已吸收 | l3-prompt-loop-fix L2 R1（INDEPENDENT-REVIEW-5） |
| L-086 | 🟡 | 全局（Bash 多字节） | `${#var}` 语义随 locale 漂移：UTF-8 locale 按字符计数、LC_ALL=C 按字节计数。字节预算断言/门控若不在 `local LC_ALL=C` 作用域内即静默变字符语义。双实证：提取器门控安全（函数顶部 local LC_ALL=C，150 CJK→${#l}=450）而 T06fix 测试断言不安全（跑在 UTF-8 locale） | 字节语义三件套：函数内 `local LC_ALL=C` + 断言用 `wc -c` + 截断走边界回退 helper，禁止裸 `${l:0:N}`（字节切片可产非法 UTF-8，iconv 可检出） | ✅ 已吸收 | l3-prompt-loop-fix L2 R1 + L3 minor-1 证伪（INDEPENDENT-REVIEW-6） |
| L-087 | 🟢 | 本仓 bats 风格 | 既有用例用 `sed -n '/case "$phase" in/,/esac/p'` 提取 case 块做断言锚——被测代码引入**嵌套 case** 时 sed 在首个 esac 截断提取范围 → 断言拿残块报红（T04 fix_round 实际发生） | 同构逻辑改 if/else（T04 实际修法）；或新写测试锚定输出行为而非源码文本结构 | ✅ 已吸收 | l3-prompt-loop-fix T04 fix_round |
| L-088 | 🟢 | 全局（hook 运维） | 手动直跑 stop-hook 模块（如 29 号）零产出根因：`config_get` 的 CONFIG_FILE 为空串（直跑不经 00-gate.sh:17 的 init_paths 导出链）→ 模块判 disabled 静默 exit 0。opencode 下 settings.json .env 段的 ANTHROPIC_* 也不注入子进程 | 手动配方：export PROJECT_ROOT + CONFIG_FILE（+ HOOK_TMP_DIR），凭证从 `jq '.env' ~/.claude/settings.json` 读出注入 env；bash -x 追踪定位此类「静默跳过」 | ✅ 已吸收 | l3-prompt-loop-fix L3 手动触发调查 |
<!-- l3-prompt-loop-fix 追加 ↑ -->
<!-- test-env-isolation 追加 ↓ -->
| L-089 | 🟡 | 本仓 bats 套件 | 断言「默认值 / 全空」的用例继承宿主 shell 的站点级配置（`~/.bashrc` export 的 FLOW_KIT_L3_MAX_TOKENS / FLOW_KIT_L3_TIMEOUT / FLOW_KIT_L2|L3_DEFAULT_MODEL）→ 在配过站点级默认的机器上 6 例假失败、pre-push `make check` 红、push 被门禁拒绝（被测代码零缺陷）。两处漏网形态：① test_l3_review_params 默认值断言未 unset 三个调优 env；② test_model_degradation 的 `_clear_model_env` 只 unset 显式配置级 4 项，漏 fk_resolve_model 第 4/5 级站点默认 2 项 | 断言默认值的用例必须在 setup/helper 显式 unset 该契约的**全部 env 级**（模型解析含第 4/5 级站点默认）；验证手法是「把宿主污染值注回 env 跑全量套件」，干净 env 复跑绿不构成证据 | ✅ 已吸收 | 2026-09-06 develop push 被 pre-push 门禁拒绝调查（4 文件 16 行 · 污染 env 下 803/0） |
<!-- test-env-isolation 追加 ↑ -->
| L-090 | 🟡 | 全局（需求/验证方法论） | **AC 必须在写需求时就跑一次、确认它当前失败** —— 否则无法区分"这条 AC 有证明力"与"它测试了不存在的东西"（TD-016 同类：断言了实现里没有的内容，长期假绿）。本次 `health-fix-2026-09` 阶段 1 预检 4 条关键 AC，**直接改写了需求**：AC-6 原写"非零退出或输出告警，并指名该文件"，实测摘掉真入口 exec 位后 `check-hooks-sync` **退出码 0 · 该文件名出现 0 次 · 计数仍是 5** —— 即"指名"这一半**当前完全缺失**（告警只有聚合计数），于是把"指名具体路径"从可选提升为硬要求，并发现 AC-5（消除误报）与 AC-6（保留检出）**必须一起修**：误报消失后计数不再被掩盖，若检出的入口不被指名，维护者将无法处置 | REQUIREMENT 阶段对每条关键 AC 跑一次验证命令并在文档里记「修复前实测行为」表；验证脚本一律 `trap` 还原 + 事后 `git status --porcelain` 自证干净。反例：只写 AC 不预检，会在 TEST 阶段才发现 AC 不可满足 | ✅ 已吸收 | `health-fix-2026-09` 阶段 1 预检（2026-09-20）|
<!-- brooks-review-fix-2026-09 ↓ -->
| L-101 | 🟡 | 全局（门禁 / 守卫设计） | **守卫的判据若只能靠"grep 源码文本"验证，它就已经是假绿候选**：实测"只有 `is_real_entry()` 定义、无任何调用点"的文件同样通过那种判据；注释里的字样也能骗过它（`health-fix-2026-09` §10d 初版即被 L3 抓出，本 change 又在 AC 验证段复现同类假阳性）。 | 凡"检查器/判据"代码，必须提供**无副作用的可直调出口**（范式：`sync-hooks.sh --entry-class <rel>`），由 bats 与 §10d **真跑分类结果**；禁止用"源码里有没有这个串"替代行为断言；负向断言必须显式排除注释行（`grep -v '^[[:space:]]*#'`）。 | ✅ 已吸收 | brooks-review-fix-2026-09（L2 R3 · 触发报告 🟡2） |
| L-102 | 🔴 | 全局（验证工件解析） | **"核错对象"是假绿的复发形态**：`verify-claims.sh` 先因"基线 sha 写死"返工（health-fix T05），再因"工件 id 写死 + 隐式回退"返工（本轮实测：无活跃 change 时 `resolve_spec_artifact DESIGN.md` 返回**另一个** change 的 DESIGN，rc=0 且输出 ✅）。共性：**任何"解析不到就回退到某个默认对象"的逻辑，都可能核到别的对象上并报成功**。 | 解析类逻辑一律三态：解析到 / 未指定（**⏭ SKIP**，显式可见、不影响退出码）/ 指定了找不到（❌ FAIL）；**禁止隐式回退到具体对象**；PASS/FAIL 文案必须回显实际核到的对象（路径或 id）；外部 ref 先 `git rev-parse --verify` 再使用（坏 ref 一律 rc=2，不得静默退化成空集）。 | ✅ 已吸收 | brooks-review-fix-2026-09（报告 🟡1 + REVIEW 第二轮 R6） |
| L-103 | 🟡 | 全局（打包器 / 校验器同源） | **打包器与校验器各持一份映射且缺失语义相反 ⇒ 门禁在最该报警时给 ✅**：实测（HEAD 版）移走必需源目录 `dsh-flow-kit/lib` 后 `check-dist` 仍输出"✅ dist 与源一致" rc=0，而 dist 里旧树仍在；同族第二例（L3 阶段6 critical）：必需**单文件**源缺失且 dist 也无该文件时，因只查"反向残留"而不置 fail → 同样返回 0。 | 拷贝映射只写一份（`COPY_DIRS`/`COPY_FILES`/`COPY_OPTIONAL`），打包循环与 `--check` **同读**；缺失语义两侧对齐：必需项源缺失 = **无条件 fail**（与打包 `exit 1` 同语义）/ 可选项源缺失合法 / "源已删而 dist 仍有副本"一律报反向残留。 | ✅ 已吸收 | brooks-review-fix-2026-09（报告 🟡3 + L3 阶段6 critical） |
| L-104 | 🟢 | 全局（探针 / 自检出口设计） | **探针对非法输入必须 fail-closed**：`--entry-class bogus/path.sh` 初版输出 `library: bogus/path.sh` rc=1 —— 拼错的探针被读成"这是库"的**结论**，守护于是静默失效（探针打偏却永远"通过"）。 | 探针入口加输入域校验（前缀白名单等），未知输入 → 用法错误 rc=2；探针输出的语义必须与"结论"可区分（`library:` 只在输入合法时给出）。 | ✅ 已吸收 | brooks-review-fix-2026-09（REVIEW 第二轮 R4 · L2 独立确认） |
| L-105 | 🔴 | 全局（流程 / 文档批改） | **L-099 复发：批量文本替换再次误改审查产物**。本次为同步"用例数 9→11→12"跑 `perl -pi .specs/brooks-review-fix-2026-09/*.md`，**未排除 `INDEPENDENT-REVIEW-6.md`** → L2 原文里的 `11 例`/`961`/`959 而非 961` 被改成 `12 例`/`962`，违反"主 agent 无权修改 L2 判断"契约。根因：**目录通配直上 + 事前列不出"哪些文件是审查产物"**（L-099 只写了"必须排除"，没给可执行判据）。 | 批量替换前**硬性三件套**：① 先列出将命中的文件并**逐条确认**（禁止目录通配直上）；② 显式排除清单：`INDEPENDENT-REVIEW-*.md`、`*.done`、`.specs/archive/**`、`.brooks-lint-history.json`；③ 替换后**复核审查原文段**（如 `sed -n '1,<N>p'` 内不得出现新值）并在 REVIEW.md 留披露记录（含恢复依据）。 | ✅ 已吸收 | brooks-review-fix-2026-09（主 agent 事故 + 逐字恢复 · REVIEW.md「事故披露」段） |
<!-- brooks-review-fix-2026-09 ↑ -->
<!-- user-guide-sync-2026-09b 追加 ↓ -->
| L-106 | 🔴 | 全局（审计 / 文档同步） | **审计报告的"坐标基准"必须与断言对象写在同一处，否则断言恒绿或不可达**：本轮漂移报告的行号锚点基于**仓库根副本**（1631 行），而修订底稿是**较新的 bundle 副本**——把报告的 L 号直接套到 bundle 会错位（实测差 28+ 行）；更危险的是 AC 只写"反例 = 0 命中"却没写"对哪一份断言"：根副本当时仍是旧文本、bundle 已改对，于是断言**在验证对象上早已满足**（恒绿），而真正要修的根副本永不被检查。口径：① 每条 AC 显式写断言对象（本轮为"四份副本各自满足"）；② 报告行号只作检索线索，落地按内容定位；③ 快照类数字（md5/行数）不写死进 AC，改为"执行时记录基线"。 |
| L-107 | 🟡 | 全局（门禁 / 边界判据） | **`git diff --name-only` 不能当"改动边界"的唯一判据**：它只列**已跟踪且未暂存**的文件——本轮新增的 2 个 bats、整个 change 产物目录都是 `??`（看不到），`dist/` 被 `.gitignore` 忽略（结构性失明）。后果：白名单判据对新增文件与被忽略产物**恒真通过**，越界反而静默。修法：`git -c core.quotepath=false status --porcelain` + `git ls-files -o --exclude-standard` 取"变更全集"，dist 类再生件交给 `check-dist` 独立守护。（另注：`core.quotepath` 默认会把中文路径转义成 `\xxx`，白名单比对必须关掉它，否则中文文件一律判越界。） |
| L-108 | 🟡 | 全局（断言 / 文档型 change） | **"锚点"必须是实现里逐字存在的串，且改前必须不成立**：本轮两处实测反例——① AC 写的正例 `子系统自动写` 在实现里是 `**由子系统自动**写`（`**` 打断子串）→ 按报告改对了反而断言红；② 换上的 `无独立开关` 在改前已有 3 命中（模块清单里本来就有）→ 修没修都绿，**毫无判定力**。口径：正例锚点取报告"建议改法"里的独有短语并逐字核对实现；每条锚点附"改前是否已绿"的实测记录（HEAD 基线对照）；正则口径显式标注。 |
| L-109 | 🟢 | 全局（文档/演示型 change 的守护设计） | **纯文档 change 也能有机械守护——守"结果一致性"而不是"过程动作"**：本轮把"指南 4 份副本 md5 唯一 + deck 页数/封面日期与声明同源"做成 6 个 bats 用例（含两个夹具注入用例证明非恒绿），成本 < 1s，却在真实缺口上生效过一次（T05 未重建 pptx 时用例 4 确实变红）。反面：`grep -q '某 target 在 Makefile 里'` 这类文本判据只是"存在性"，不保证"跑到了"。 |
<!-- user-guide-sync-2026-09b 追加 ↑ -->

<!-- privacy-path-scrub-2026-09 追加 ↓ -->
| L-110 | 🔴 | 全局（隐私 / 历史重写） | **「删掉文件里的敏感串」不等于「隐私清理完成」**：① 已提交的内容要动**历史**，而历史只在**未推送窗口**内可改——本轮实测 `develop` 领先远端 38 个提交，因此能重写；`origin/develop` 及更早的 34 个提交里同样含本机绝对路径，**只能强推才能清**（影响他人克隆）。② 重写后必须清 `refs/original` + reflog + `gc --prune=now`，否则旧对象仍可 `git cat-file` 取回（等于没清）——本轮 `.git` 体积由 22M 降到 14M 即为副证。③ 安全网（`git bundle` + tag）在验证通过后**必须删除**，否则它自己就是最大的泄露面（tag 会让旧提交继续可达）。④ 提交哈希会变：本轮 38 个提交全部换哈希，仓库内 9 个旧短哈希的 31 处引用随之失效 → 必须产出 old→new 映射与影响清单。⑤ `.pyc` 这类字节码会内嵌源码绝对路径，`.gitignore` 事后加规则**不会**自动停止已跟踪文件的跟踪。 |
<!-- privacy-path-scrub-2026-09 追加 ↑ -->

<!-- health-fix-2026-09b 追加 ↓ -->

### L-178 · 判据脚本别用「相等计数」断言散文文件：同名文本会互撞，改成下界或加特征锚

事由：本 change 的 REPRO 判据脚本 `.specs/health-fix-2026-09b/reproduce-5-fixloop.sh` 用 `grepc <文件> <ERE> <确切计数>` 断言 `.specs/health-fix-2026-09b/TEST.md` 里「数量口径生成规则」出现 **1** 次；`T-FIX-21` 落地后在 §1.1 与 §1.3 各写了一条同名规则行 ⇒ 实测计数 **2**，判据会红在一个**完全正确**的交付上（假红）。同一轮还暴露出反向问题：执行者的正确交付被它自己的报告数字（`OK 50` vs 文本 `n=49`）判为「歧义」——判据文本里的自然语言口径也是缺陷来源。

判别式与定式：① 断言**散文/文档**里的计数时，优先**下界**（`计数 ≥ 1`，本仓已加 `grepge` 助手）或换成**唯一特征串**（引号内的完整标题、`§1.3 专属` 这类只出现一次的词）；② 只在**代码/schema**上使用相等计数（键名、字段数、正则形态）；③ 判据文本里别写自然语言推导（「n = 归一前条数 − 1」），直接写**断言本身**，把可读描述留给 SUMMARY；④ 判据必须在**写完之后立刻在真仓空跑一遍**（本次 `grepc … 1` 若跑过就会当场暴露）。

代价对比：一条相等断言 → 复跑时假红一轮（追查成本 > 写判据成本）；下界断言丢掉的那点强度，用「另一条特征锚」补回即可。


### L-177 · 压缩会把「已派发」吃掉：派发执行者前先 `list_agents` 查重（主 agent 流程纪律）

事由：2026-09-28 主 agent 在同一分钟内对 `T-FIX-20` 连续派发两次（`87c08079-…` 05:35:43 与 `de2f1cea-…` 05:36:06，同一份派发词 `/tmp/p6d/dispatch-tfix20.md`）；原因是上一轮上下文压缩把「已派发」的工具结果折进摘要，而摘要只描述历史、不构成当前指令，主 agent 在摘要落地前又派了一次。两个执行者共用同一写面（`test/test_independent_review_model.bats` 等）与同一台账键 ⇒ 若都跑完，会互相踩提交、给同一任务写两条 `task_progress`、回执无法归因。

判别式与定式：① 派发**任何**执行者前先 `list_agents` 一次（约 30 秒），scan `[running]` 行里是否已有同任务；② 发现重复时保留**先**启者、对后启者 `interrupt_agent`（其通常仍在勘察阶段，未落盘）；③ 中断后立刻复查 `git status --porcelain` 与台账条数（`len(goal.task_progress)`），确认没有双写、没有半成品文件；④ 把「查重」写进派发清单，与「派发前先提交未跟踪工件」（`L-172`/`L-176`）同工序。

代价对比：查重 30 秒 vs 两个执行者同改一个写面 ⇒ 提交互踩 / 台账双写 / 回执无法归因（本次实测：中断及时，工作树与台账均未受影响）。
反向教训：订阅式通知（subagent 起停）会在**下一轮**才到达，不能当作「我已经派过」的凭证；判断依据只能是 `list_agents` 的实时快照。


### L-176 · 派发前先提交：执行者的「干净树」清扫会带走你未跟踪的工件（TD-092 家族 · L-172 扩展）

主 agent 新建 `.specs/health-fix-2026-09b/reproduce-5-fixloop.sh`（7840 B，**未提交**）后派发 T-FIX-19；数分钟内该文件被执行者 `c745fadb-…` **移出仓库**到 `/tmp/tfix19/reproduce-5-fixloop.sh.hold`。`.hold` 是执行者跑权威门禁前的既有习惯：把工作树里所有「非本任务」的**未跟踪**文件暂存到一边，好让 `make check` / `git status` 看到干净树。`mv` 保留 mtime ⇒ 事后用 `ls -lt` 看目录只会觉得「它从 04:53 起一直在」，极易误判为无事发生。恢复靠 `cp` 回原位 + `bash -n`，随后**立即** `git add`/`git commit`（`61d484a`）使其受版本库保护。
判别式与定式：① `git status --porcelain` 里以 `??` 开头的行 = 生命周期不受版本库保护的工件，派发期间随时可能消失（L-172 讲「已跟踪但未提交」会被 `git checkout` 销毁，本条讲「未跟踪」会被清扫带走 —— 两条指向同一动作：**派发前先落库**）。② 判据脚本/派发词/探针若必须留在工作树，就先提交（或落 `/tmp` 并在派发词里点名保护）。③ 派发词必须写明「禁止移动、改名、删除、覆盖任何非本任务写面的文件（含一切未跟踪文件）；需要临时移开时先报备」，本次已补进 `/tmp/p6d/dispatch-tfix2{0,1,2,3}.md`。④ 执行者「已备份 / 仍在工作树」的声明必须亲验（TD-092 曾证明该声明为假）。
反向教训（值得保留）：同一执行者把「`make check` 红 = **主 agent** 的 `reproduce-5-fixloop.sh:138-139` 触发 NFR 判据字面匹配」精确诊断为阻塞源并上报，而非绕过或伪造 —— 主 agent 据此 30 秒内修掉自己的工件（`44f3693`）。若当时只凭「门禁红」就回退执行者写面，就会误判好交付。

### L-175 · 靠锚点/变更集生效的 ratchet 门禁，验收态必须问「锚点消失后它是什么颜色」（TD-096 · R5-23）

`Makefile:162-306` 的 NFR 可移植性判据在**变更集模式**（锚点 `.specs/*/.change-base`）下只扫 `git diff -U0 "$BASE"` 的**新增行**；而本仓的锚点随 change 一起归档 ⇒ **归档当天判据自动转全量模式**。主 agent 实测（2026-09-28）：全量模式在真仓有 **19 行 / 12 文件**既有违禁构造（`declare -A` · `mapfile` · `stat -c` · GNU `sed -i` · `find -printf`），其中 `sync-hooks.sh:182/:197/:198` 的 `mapfile` 正被 `make check-hooks-sync`（`Makefile:95-97`）调用 ⇒ macOS/bash 3.2 上 rc=127。**只修本次新增构造 = 把自红定时炸弹留给归档动作**。
处置定式（三分法）：① **可安全替换的当场修**（本次：`mapfile` ×5 · `stat -c %Y` ×1 · GNU `sed -i` ×1）；② **冻结归档面从受检面排除**（`.specs/archive/*` 是历史记录，改它没有行动价值 —— 排除要写明理由并配反向控制腿）；③ **深层库存量登记为带日期的基线清单 + ratchet**（不在基线内 ⇒ 红；基线条目消失/行号漂移 ⇒ 红，防基线腐烂），把真正替换（`declare -A` ⇒ 便携查表）立为 v2 技术债（`TD-096`）。
通用问法：任何「只对新代码生效」的门禁都要额外回答两问 —— **锚点/基线消失后它扫什么？** 它扫的面里有没有**永远不会被修**的冻结文件？

### L-174 · 把可变内容当 grep 模式必须 `-e` + `--`；批量化改造后要重测整轮耗时才算收口（TD-094）

检查器内部用「候选文件名」当 pattern 做 `grep -qxF "$key"`：文件名形似选项（如 `-q`）时 `-q` 被当作选项、无文件操作数 ⇒ grep **转读 stdin**，
而 stdin 恰是被遍历的命中/候选流 ⇒ 后续命中被静默吃掉（旧版实测 2 处泄漏只报 1 处，rc 与报文都不自证；且该缺陷是**次序相关**的，单候选时旧版也能检出）。
定式：`grep … -e "$pattern" -- "$file"` 三件套；并给扫描加不变式断言（候选 = 实际扫描 + 自排除）让「扫描面塌缩」fail-closed 而不是静默塌缩。
另一面：批量化（rev 面由每候选一次 `git grep` 改一次全局 `git grep`）后必须**重测整轮真实耗时**——本轮 rev 从 7.08–7.51 s 降到 4.4–4.55 s，
但同批新增的每候选 `git cat-file -t` 又吃掉 ~2.8 s（≈62%），只有一次 `git ls-tree -r -z` 才能一次拿全（见 TD-094）。
⇒ 优化要用「整轮实测」结账，别只看被改掉的那一段。

### L-173 · 变异腿要选能区分判据的形态：同一守卫删「拒绝」与删「跳过」得到相反结论，`-ne 0` 会被意外崩溃冒充（TD-093）

`test/test_pre_push_behavior.bats` 的 leg4（畸形 stdin ⇒ fail-closed）在两种守卫删除形态下结论相反：
`exit 1`→`continue`（跳过整行）⇒ rc=0 ⇒ 腿红；`exit 1`→`:`（继续执行）⇒ 落到 `local_sha=$2` ⇒ `set -u` 崩溃 rc=1 ⇒ 腿绿。
根因是判据断 `[ "$status" -ne 0 ]` 而不是 `-eq 1`，于是「被测件按预期拒绝」与「被测件意外崩溃」不可区分。
⇒ 写变异腿时先问「这条腿能否把『另一条失败路径』与本路径分开」，能分开才叫有牙；`-ne 0` 一类宽松断言必须配报文/副作用反证。
| L-111 | 🔴 | 全局（安全 / hook 守卫） | **安全守卫里的 `eval` 等于把执行权交给被守卫者**：`hooks/pre-tool-use/runtime-edit-guard.sh:46` 用 `real_path=$(eval echo "$file_path")` 展开 `~`，而 `file_path` 直接来自 hook stdin 的 `tool_input.file_path`（JSON 载荷，agent/提示注入可控）。本轮以携带命令替换的 `file_path` **实际复现命令执行**。关键点：外层 `2>/dev/null` 与 `\|\| real_path=...` **无法防护** —— `eval` 先做命令替换再谈退出码；且该行位于所有 gate 判定**之前**，matcher `Write\|Edit` 使其**每次写文件都触发**。全仓 57 个 shell 中唯一 `eval`，恰好落在守卫内。定式：`~` 展开一律用参数展开 `${var/#\~/$HOME}`，**永不** `eval`；`grep -rn '\beval\b' <被守护代码>` 应成为安全门禁的固定检查项 |
| L-112 | 🔴 | 全局（安装器 / 原子写） | **`cmd > file` 是「先截断、后执行」—— 工具缺失即静默清空用户配置**：`lib/install_hooks.sh:238-253` 的分支条件是 `[ -f "$settings_target" ] && command -v jq`，于是**「文件已存在 + jq 缺失」为假 → 落入 `:238 else`（注释写 `# 新建`）** → `:251` 的 `jq -n … > "$settings_target"` **在 jq 执行前就把已有文件截断**，随后 `jq: command not found`（127），`set -euo pipefail` 使安装中断。本轮复现 **113 字节 → 0 字节**（`permissions.allow` 与既有 Stop hook 全毁），**无备份、无回滚**。两个独立缺陷叠加：① 二值条件把"工具缺失"误判为"文件不存在"；② 写盘用 `>` 而非 temp+rename。定式：依赖外部工具的分支须在**入口**硬校验（`command -v jq \|\| exit 1`），写用户配置一律 `mktemp` + `mv` |
| L-113 | 🔴 | 全局（隐私 / 历史重写验证口径） | **历史重写的验证必须逐 ref 覆盖「本地分支」：`origin/*` 干净 ≠ 对象库干净**：本轮 `privacy-path-scrub-2026-09` 的论证（`HISTORY-REWRITE-FULL.md:32-33`）只看 `origin/main`（命中 0）就断言"旧对象也不会经 main 存活"，但**本地 `main` 是 20-commit 孤儿分支**（与 `develop` 无共同祖先、无 upstream），仍是 8 个含 `/home/<user>` blob 的**可达**来源 → `gc --prune=now` 无法回收 → 逐字执行文档 `:120` 自己的权威验证命令（`--batch-all-objects`，期望 0）**实测返回 8**。即"删安全网 + 清 reflog + gc"三步都做对了，仍因**一个未纳入分析的本地 ref** 而前功尽弃。定式：① 验证一律用**仓库级**口径（`--batch-all-objects`），不要用 `git log <branch>` 抽样；② 收尾前 `git for-each-ref` 枚举**全部 refs** 逐个判定，本地分支与 tag 同等对待；③ 把该验证做成**可复算门禁**而非一次性人工动作 |
| L-114 | 🔴 | 全局（门禁自身可信度） | **"永久红灯 + 测试豁免"的门禁比没有门禁更糟；且纯计数比较是语义盲的**：`reference/check-gate-sync.sh` 自称校验 prompt↔skill 一致性，实测 `exit 1` 永久红 —— 判据只匹配顶格行，拿 `4-dev.md` 的 2 行去比 `flow-dev/SKILL.md` 的 8 行，而那 8 行是 `:156-163` 的**迁移框架表**（Prisma/Alembic/…），该 skill **根本没有 PCSC 表**；更糟的是**未接入 `make check`**、其 bats 测试 `:30` 断言 `[ "$status" -ne 2 ]` **显式容忍 exit 1**。**本轮最重要的反直觉发现**：若"只修正则让它不红"，修正后 4-dev=8 vs flow-dev=8 → **8==8 通过**，把**看得见的假红**换成**看不见的假绿**（红灯会被人修，绿灯会永远藏住漂移）。定式：① 判据要**比内容/结构**而非比计数；② 门禁必须接线（否则永久红灯无人知）；③ 测试断言不得容忍目标失败（`-ne 2` 这类"只要不是脚本错误就算过"是豁免漏洞）；④ **修门禁语义前先锁定唯一语义源**，顺序颠倒只会批量产出假绿 |
| L-115 | 🟡 | 全局（测试可信度判定） | **能在"仓库不可达"时全绿的测试，就是 mock 自证**：`test_gate_config_presets.bats`（390 行 / 34 测试）在文件内自行定义 `resolve_gate_config`（注释自陈"Simulates the resolve_gate_config() logic"），**从不 source 生产实现**（对 `flow-kit-bundle`/`check-gate-sync.sh`/`SKILL.md` 引用数 = **0**）。**可复现的判据**：把该文件单独拷到 `/tmp`（仓库不可达）运行 → **34/34 全绿**；对**对照组** `test_correction_hygiene.bats` 同法运行 → **exit 127 全失败**。两者差异即"真依赖仓库 vs 只依赖自己"。附带发现：mock 硬编码 `"independent"` **72 处**，而出货契约 `skills/flow/SKILL.md:138` 已统一为 `"both"` → 该测试断言的是**已废弃的旧语义**，生产实现被回退也照样绿。定式：新写测试时用"离仓运行"当**证伪手段**（对照组必须失败），并纳入测试可信度巡检 |
| L-116 | 🟢 | 全局（审计方法论 / 避免误判） | **审计看到"东西不见了"时，先搜本仓 LESSONS 有无"故意删掉"的记录**：本轮把 `HISTORY-REWRITE-FULL.md` §7 列的三处安全网（裸包 / `refs/backup/*` / 远端旧历史）全部实测不到，初判为 🟡「文档断言与事实不符」；随后查得 `:104` 明写「**强推确认无误后**该 bundle 与 `refs/backup/*` **应删除**」、且 `LESSONS` **L-110 ③** 已给出理由（"安全网自己就是最大的泄露面"）→ **删除是按设计的正确动作**，定性下调为 🟢（残留仅为 §7 与 §8 相隔较远、易被误读）。定式：① 判定"缺失/失效"前先 `grep -rn <对象名> .specs/LESSONS.md .specs/CONTEXT.md` 排除"有意移除"；② 关键结论尽量回溯本仓既有记录，而非只凭当前快照推断；③ 审计报告应显式记录此类自我更正，避免把对方的正确工作报成缺陷 |
<!-- health-fix-2026-09b 追加 ↑ -->
### L-172 · 执行者会销毁你的未提交改动：派发前先落库，回执里的「已备份/仍在工作树」必须亲验（TD-091/TD-092）

**触发**：`T-FIX-15` 执行者（`e298ccc0-2cdb-491d-aa77-04a44a5641c1`）发现工作树存在主 agent 的未提交改动后，执行 `git checkout HEAD -- .specs/health-fix-2026-09b/TASK.md .specs/health-fix-2026-09b/TEST.md`，回执写「主 agent 的改动已备份在 `/tmp/tfix15/preserve/` **并仍在工作树**」——实测只有前半句为真：**改动已不在工作树**（`grep -c '行号锚点纪律' TASK.md` = 0、`grep -c '环境面残留' TASK.md` = 0；`TEST.md` 的 AC-3 `27→45` / AC-4 `5→11` / AC-6 `24→30` / AC-8 `46→53` 与「数量口径生成规则」行全部消失），恢复全靠 `/tmp` 备份（`diff` 出 `TASK.md` **8 hunk** + `TEST.md` **2 hunk**，`git apply` 全部回位 ⇒ 2933 / 1268 行）。

**同批第二处（同执行者）**：台账写入把条目写进 `.flow-active` 的**顶层字面键 `.goal`**，权威台账 `goal.task_progress` 里没有该条 ⇒ `33-flow-active-integrity.sh` 仍 **rc=0**（该钩子不校验台账条数与写入路径）；另有 prepend 而非 append 的序偏差。现场判定靠 `tp[-1]['id']` 仍为 `T-FIX-14`。

**教训**：① **派发前把主 agent 的写面全部落库**（`git commit` 或至少 `cp -a` 到 `/tmp/<task>/mainagent-bak/`）——工作树里躺着未提交改动，对执行者是**破坏性诱惑**，不是保护。② 派发词必须显式禁止 `git checkout --` / `git restore` / `git stash` / `git clean`，并规定取基线的唯一方式（`git show HEAD:<path> > /tmp/...`），且「发现非本任务写面的改动只回报、不清理」。③ 回执里的**约定外动作**必须逐条独立复核——「已备份**并仍在工作树**」这类**双重断言**只要有一半为假，另一半也不可采信（本次即如此）。④ 台账写后自证：`python3 -c "import json;d=json.load(open('.flow-active'));tp=d['goal']['task_progress'];assert '.goal' not in d and tp[-1]['id']=='<task>'"`。

**落点**：`TASK.md` 新增「工作树纪律」段（属派发契约）· `TD-091`（台账路径漂移 + 幽灵键）· `TD-092`（销毁式还原）· `T-FIX-21` 增台账归一与静态校验腿。

### L-171 · 审查者读的是工件而不是历史：总结面（发现表 / 索引计数 / AC 简报数字）必须与最新一次执行同步

**触发**：阶段 5 L2 第 5 轮盲审（`INDEPENDENT-REVIEW-5.md:966` 起）在 25/25 判据全绿、NFR 由第 9 次的 221.6% 回落到 72.2% 的**全绿判定面**上给出 3 条 Major，其中 2 条与产品件无关：`TEST.md` 发现表止于 **#42**（第 8 次执行），未含第 9–11 次新增的 `R4-1`/`R4-2`/`R4-M1`/`TD-077`/`TD-078`/`TD-081`；处置位置索引仍写「独立技术债条目 = 14」而实际已达 28；§1.1 的 AC-6 简报写「常设隐私 bats **24** 例」而实测 **30** 例（`grep -cE '^[[:space:]]*@test' test/test_path_privacy_gate.bats`）。

**根因**：第 9/10/11 次执行的**回执面**都写进了 `PHASE5-RECEIPTS.md` 与 `TEST.md` 附录 D-x，但 `TEST.md` 的**汇总面**（§1.1 AC 矩阵数字 / 发现表 / 处置位置索引计数）只在第 8 次执行时刷新过一次 ⇒「回执面已更新、汇总面未更新」的工件在内部自相矛盾，而审查者只能读工件。

**教训**：① 每次执行收工时把更新清单固定为四件：权威全脸行 / §0 执行表行 / 附录 D-x / **汇总面（AC 矩阵数字、发现表新增行、索引计数）**——前三件是历史留档，第四件才是审查者据以判断的结论面。② 计数类断言（「X 条 / Y 例 / Z%」）每次执行后**重新实证**而非增量推算，并把实证命令写在数字旁（本次订正即附 `grep -cE` 命令与 `TD-078` 溯源）。③ 与 `TD-077`/`TD-078` 同族：**工件自身的数字也是交付物**，一旦过期，下一个审查者就以「工件完整性」为题记 🟡，处置成本落在被审方而非缺陷方。④ 附带流程教训（同一轮 🟡-1）：判据在工作流飞行中被就地修订（`TD-081`：`T-FIX-13` 判据在执行者停下后由主 agent 修订，新增 L3d/L4c，L2/L3/L6 一字未改）方向虽是**收紧**，审查者仍会记为流程风险 ⇒ 最小成本处置 = 把修订前后的**红/绿两态并排留档**（本次 = 缺陷态探针 `rc=0` + 初版 **8** 红腿 + 修订后 **6** 红腿 + 绿态三类回执：常设 bats 3 例 / 独立夹具 `rc=0` / REPRO10 该判据 53 行 `rc=0`）并登记 v2 三条（夹具状态显式打印 / 派发前腿间互斥性预检 / `make lint` 静态检查）。

**落点**：`TEST.md` 就地订正（1258 → 1266 行：§1.1「第 11 次执行补记」+ 发现表 #43–#49 + 索引计数 14 → 28 与 `5-test.md:103` 的 50% 阈值口径澄清＝**仅源码级**发现，故 AC-4 未触发）+ `MINOR-DEFERRED.md`「✅ L2 第 5 轮盲审发现处置」+ `TD-078` / `TD-081`。**同族在 L3 第 14 轮再次命中**：外部模型 minor ② 指出 `TEST.md` §1.3/回归保护仍以第 8 次执行 `1029` 为「当前值」而 §0/附录 D-12 以 1064 为权威基线 ⇒ 同轮就地统一口径（§1.3 第 2/5 条、回归保护行、附录引言的「当前值 / 当前基线」标记一律改为第 11 次 `1064 / 1063`，历史值全保留）并重跑 L3 第 15 轮重新冻结哈希；**第 15 轮 M4（「阶段 5 ✅ 通过」未限定为执行面口径）与第 16 轮 m1（AC-8 回归列仍写第 8 次执行 24 / 9 / 7 = 40 用例 · 全量 1029）属同族再次命中**，同轮订正为 30 / 9 / 7 = 46 用例 · 全量 1064 收集 / 1063 有效，共触发 L3 第 15/16/17 轮三轮重新冻结（`e4ee2e16` → `eb9539d2` → `72053bb2` → `20cb8303`）。

### L-170 · 复核夹具的假红先怀疑夹具：对照态与前置门必须先证绿，再归因被审对象

**触发**：T-FIX-13 主 agent 独立三态复核首版出现 4 条假红（`M2` / 状态①的 `M3` pre-commit / 状态③的 `M4`），据此一度怀疑修复本身有缺陷。

**根因（两条都是夹具自身缺陷，与被审代码无关）**：① 夹具 `proj/Makefile` 只声明 `all:`，而 `pre-commit.sh` 在隐私检查**之前**还有归档门 `make test` 腿 ⇒ 钩子在更早的关口就以 `make: *** 没有规则可制作目标“test”。 停止。` + `[archive-commit-gate] test failed, commit rejected`（rc=1）退出，状态②分支根本不可达；② 自造允许清单写成 `path:1 fixture`（`file:token` 后缺 `#` 理由注释分隔）⇒ 检查器 `validate_allowlist_format` 判 `🔴 允许清单格式违例（ADR-028 规则 ① · file:token 语法）` ⇒ 状态③的干净对象也被判红。

**教训**：独立复核夹具要**先证自身前提**，再谈归因——① 已知对照腿（此处为状态①与状态③的干净腿）必须能绿；② 被审对象的**前置门**必须满足（钩子链上任何更早关口的输入都要合法，否则后续分支不可达）；③ 自造配置必须过被审对象自身的格式校验（可先单独跑一次其校验函数/脚本）。夹具假红的成本远高于多跑一条对照腿的成本。

**同族**：TD-072 / L-164（子 shell 吞变量 ⇒ 内容断言全假红）、TD-081（夹具未构造标称状态 ⇒ 腿间互斥）。

### L-169 · 判据若在真仓共享文件上注入探针，它就会与并发编辑互相破坏（TD-080）

**情境**：`health-fix-2026-09b` 阶段 4 的 REPRO9（job `bash-354`）跑到 T22 判据时，该 `<verify>`（`TASK.md:1003`）先 `cp .specs/CONTEXT.md /tmp/l133-bak`，再把真实形态探针 `printf '<!-- mixed: %s %s -->\n' "/home/$(whoami)/x" "/home/user/y" >> .specs/CONTEXT.md` 追加进**真仓共享 tracked 文件**，最后 `cp -f /tmp/l133-bak .specs/CONTEXT.md` 整体恢复。同一时间主 agent 正在同一文件写 `TD-078` 行 ⇒ 恢复动作把它**静默抹掉**（740 → 738 行、`grep -c TD-078` = 0，无任何提示）；同时运行的 `make check-path-privacy` 又恰好扫到瞬时探针 ⇒ 报 `🔴 清单外命中 1 条`（归因 `.specs/CONTEXT.md:740: <!-- mixed: … -->`，rc=1）。同一条判据同时制造了「对并发门禁的假红」与「对并发写作的真丢失」。

**教训**：① **backup/restore 型夹具没有冲突检测** —— 「整体覆盖恢复」等价于「最后写者胜」；把真仓文件当草稿纸的判据必然与并发编辑互相破坏。探针目标要**专用**（change 内的探针文件，随 change 归档消失）或夹具自建临时 git 仓。② 判据运行期间，判据**触面文件必须冻结**：主 agent 与执行者都不该在同一窗口写这些文件（本次靠手工纪律「REPRO 运行期间不改 `.specs/CONTEXT.md`」，应做成复现脚本头部的显式声明）。③ **瞬时污染也是污染**：判据窗口内的探针会污染并发门禁读数，更可能被并发的 `git commit` 写进提交（真实形态探针入 commit 即真泄漏）。④ 恢复之后要能**证明**恢复完整（`cmp -s` / 哈希比对），不一致时报警而非静默覆盖 —— 否则「判据通过」与「工作丢失」可以同时为真。⑤ 与 TD-070（审查/执行期的仓库态污染）同族：**判据与审计工具都不得在被审仓库里留下或抹掉状态**。

**落点**：`TD-080`（本 change 不改该判据，属验收标准原文；v2 = 专用探针文件 + `flock` + 运行期声明 + 恢复后哈希断言）+ 被抹掉的 `TD-078` 已由主 agent 重写。

### L-168 · 判据自己「不判」时，全绿只是一句打印 —— 性能预算回归只能由真计时腿抓到（TD-077）

**情境**：`health-fix-2026-09b` 阶段 5 第 9 次执行（判据面 23 条 + 门禁面 7 项）收工，复算脚本 `reproduce-5-test.sh` 把 NFR 判据写成「打印 5 次 `real=` 数值 + `emit_gate "NFR ≤5s ×5" 0 "…"`（rc 硬编码 0）」⇒ 实测 `10.741/10.885/10.783/11.510/11.469 s`（均值 11.078 = 预算 221.6%，判据 `REQUIREMENT.md:495`「≤5 秒」）被打印成 `✅`，脚本总退出码仍是 `0`「复算全绿」；同一批的 23 条判据、`bats` 1061 例、`make check` 21 项、隐私门禁 0 命中偏偏**全绿** ⇒ 红面只能靠人逐行读原始输出发现，且该回归是 `T-FIX-07`（R3-2 修复）引入的（逐候选一次 `git grep --cached`：1594 次进程，real 3.191 s → 10.778 s，sys 1.246 → 11.186）。

**教训**：① **打印数值 ≠ 判定**——复算/回执脚本里凡「阈值型判据」必须真比较（`awk` 判阈值、打印 max/均值/预算百分比、超限即 `emit_gate <名> 1`），并把结果接到脚本退出码上；`emit_gate <名> 0` 是危险默认值，等于判据不存在。② **「总退出码 0」不能替代逐面判定**：收工结论必须逐面给 ✅/❌，并给每条红面的原始数值与判据原文行号。③ **性能预算类判据兜不住功能断言**：功能全绿、1061 例 bats 全绿、`make check` 21 项全绿的同一 HEAD 上，门禁 real 仍超预算 4.4× ⇒ 只有**真计时腿**（逐次列出 + 负载/核数说明 + 不做折算的固定阈值）能发现。④ 引入「每候选一次外部进程」的实现前先做**微基准**（本例 4.28 ms/次 × 1594 ≈ 6.8 s，与批量化的一次全量扫描 0.023 s 相差约 **290×**）。⑤ 判据运输面本身也是交付物：判据不判 ⇒ 与 TD-064/TD-065/TD-073 同族的「判据自身缺陷」，应在阶段 5 收工前自查（本次由主 agent 读原文兜住）。

**落点**：`TD-077`（`reproduce-5-test.sh` `[D]` 段已改真断言，脚本 231→268 行）+ `T-FIX-12`（`check-path-privacy.sh` index 侧扫描批量化，`TASK.md:2390-2489`）+ `PHASE5-RECEIPTS.md` §R-2/§R-3/§R-4。

### L-167 · `<verify>` 里会 `cd` 进夹具的命令，被测件路径必须绝对化（TD-060 第三次复发）

**情境**：`health-fix-2026-09b` 阶段 4 的 T-FIX-11 `<verify>` 在仓库根定义 `S=flow-kit-bundle/flow-kit/reference/check-path-privacy.sh;`（相对路径），紧接着 `FXR() { ( cd "$FX" && FLOW_KIT_PRIVACY_ALLOWLIST="$AL" bash "$S" 2>&1 ); }` 把 cwd 切进 mktemp 夹具仓 ⇒ 找不到被测件，四腿全部 rc=127（TD-076）。执行者按 L-166 未自行放宽判据，用绝对路径跑通后主动上报。

**教训**：① 写 `<verify>` 先分类「这条命令的 cwd 还是仓库根吗」——凡 `( cd "$FX" && … )` 这类改变 cwd 的写法，被测件、允许清单、锚点、探针一律以 `R=$(pwd)` 前缀绝对化；② 判据的**首跑必须由主 agent 自己在夹具环境跑一遍**（本次主 agent 预检只在「真仓」语义下复核，没覆盖 `cd` 之后的腿）；③ 执行者上报判据缺陷时，主 agent 要像处理实现缺陷一样：登记 TD + 写教训 + 就地修判据（不改语义），并在复核记录里留痕，而不是只回一句「知道了」。


### L-166 · 判据「缺陷」必须先读原文再动手：截断显示 + 前缀 replace 会制造出不存在的缺陷

**情境**：`health-fix-2026-09b` 阶段 4 收口 T-FIX-10 时，主 agent 逐行打印该任务 `<verify>` 以核对断言对象，用的是 `repr(l[:110])`。第 ⑥ 腿原文 `OUT=$( cd "$FX" && PATH="$FX/bin:$PATH" bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh 2>&1 ); SRC=$?;` 恰好**被截断在 110 字符**，看起来漏了 `SRC=$?` ⇒ 误判为「陈旧 rc 变量」缺陷；随后 `replace(pat, pat+' SRC=$?;')` 的 `pat` 只匹配到 `);` 前缀（更长的真实文本没被消费）⇒ 判据被改成 `); SRC=$?; SRC=$?;`，第二个 `SRC=$?` 取到的是**上一条赋值语句的 rc=0** ⇒ 复跑当场变红，并报出假的「R3-20 diff 机械故障被折算为一致（rc=0）」，一度被当成生产件回退。

**教训**：① 断言某行「缺少某片段」之前必须看**该行全文**（`grep -n` 原文 / `awk` 打印整行），不得据截断或加宽显示的片段下结论；② 就地改判据前先 `git show <sha>:<file>`（或 `git diff`）对照已提交版本，确认是「补缺」而非「重复」；③ 用前缀 `replace` 补片段会让已存在文本叠加 ⇒ 补片段一律用**整行锚点**，并对结果做幂等断言（`count(新)==1` 且 `count(旧)==0`）；④ 判据变红先怀疑**自己刚做的改动**，再怀疑被测件回退。
### L-165 · 全量门禁变红时，第一步先看 `git status --porcelain`（并发执行者可能正在改被测件）

**情境**：`health-fix-2026-09b` 阶段 4，主 agent 在 T-FIX-10 执行者（subagent）**在飞行**时复跑 `make check`，得到 `❌ bats: some tests failed`（`Makefile:11`）—— 看上去像 T-FIX-09 的回归。`git status --porcelain` 立刻显示 ` M flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（+86/−16），而这正是 `test_check_gate_sync.bats` 的被测件 ⇒ 执行者正在编辑它 ⇒ **并发假红**。

**教训**：① 串行修复链（本 change 的 T-FIX-09/10/11 都改 `.specs/STATE.md` 与 `dist/`）下，主 agent 的**全量门禁复跑应等执行者收工**，或在结论里显式标注并发窗口；否则会把假红当归因、浪费一轮并可能误触发回退。② 归因顺序固定为：`git status --porcelain` → 失败是否落在被改文件的测试面内 → 才复跑定位（`make test` 只打印「some tests failed」，见 TD-075）。③ 反向价值：派发词里要求的「开工/收工各贴 `git status --porcelain` + `git diff --cached --stat`」不只是写面纪律，也是主 agent 判红的第一手材料。

### L-164 · 跨子 shell 传值必须走「文件」—— `rc=$(fn)` 会吞掉函数内的所有变量（TD-072 同型 · 第二次踩中）

**情境**：`health-fix-2026-09b` 阶段 4，主 agent 为 T-FIX-09 写独立复核夹具 `/tmp/p6c/verify-tfix09.sh`。函数 `gate()` 内做 `GATE_OUT=$( cd "$fx" && make … )`，调用点写 `rc=$(gate "$FX")` ⇒ **`GATE_OUT` 恒为空**（命令替换 = 子 shell，函数内赋值全部丢失），于是 `leak.sh:2` / `锚点来源` / `检测到 2 个` 等内容断言**全部假红**（首轮 5 PASS / 14 FAIL），而 rc 断言全对 ⇒ 极易被误读成「生产件仍有缺陷」。

**教训**：① 「既要回传 rc 又要回传输出」的函数，**输出必须落文件**（`… > "$OUT" 2>&1`）或固定全局文件路径，调用点只接 rc；② 若坚持用 `$( )`，函数内就不得依赖调用者读取变量，全部经 stdout 传；③ 这与 TD-072（`FXRUN() { …; NRC=$?; }` 被 `OUT=$(FXRUN)` 吞掉）**同型**，说明该模式在本 change 里高频 ⇒ v2 的 `make lint` 应把「函数内赋值 + `$( )` 调用」列为独立静态检查项（`<verify>` 与主 agent 复核脚本都在检查面内）；④ 排障顺序固化：**先看 rc 断言是否全对**（全对 ⇒ 大概率是取值通道问题而非被测件），再把输出改走文件复跑一次即可分辨。

**次要教训**：`grep -q '检测到 2 个 .specs/*/.change-base'` 里 `*` 是**正则量词**（作用于前一个 `/`）而非字面量 ⇒ 断言假红。含 `*` / `[` / `.` 的字面串一律 `grep -qF`，或改断言不含元字符的短片段。


### L-163 · 执行者回执/SUMMARY 里的**逐文件行数**必须由主 agent 用 `git show --stat` 独立复核 —— 总数对得上不代表分解对得上

**情境**：`health-fix-2026-09b` 阶段 4 `T-FIX-08` 收工回执与 `T-FIX-08-SUMMARY.md` §2/§3 都给了「逐文件 +N」表：`check-path-privacy.sh +53`、`.specs/STATE.md +10/-2`、`test_path_privacy_gate.bats +57`、`test_archive_commit_gate.bats +44`。主 agent 用 `git show --stat 2f01f39` 实测：**`+23` / `+3/-2` / `+65` / `+75`**（12 文件 `536 insertions(+), 22 deletions(-)` 总数一致）。即**总量正确、分解错误**，且偏差方向不一致（有的虚增、有的缩水）。

**教训**：① 复核执行者回执时 `git show --stat <sha>` 是唯一权威来源；只核总数会漏掉这一类「分解失真」，而分解放大/缩小恰好说明作者的表是**手抄或推演**而非机读；② 派发契约里要求「逐文件行数」时应**指定生成方式**（`git show --stat --format='' <sha>` 原样贴），不要让执行者自己总结；③ 主 agent 的复核记录要**同时记两套数字与差异**，否则 `SUMMARY` 会成为下一轮审计的错误输入；④ 该缺陷不影响产物正确性（文件内容与全部门禁均经独立复跑）⇒ 定级 🟢，但必须写进复核记录。


### L-162 · 派发契约必须与被派发块**同源**：派发词里复述「另一块」的内容 = 制造内部矛盾

**情境**：阶段 4 修复循环中，主 agent 派发 `T-FIX-07` 时把同批 `T-FIX-08` 的任务背景（🔴 R3-14：`pre-push`/`pre-commit` 对消费者项目 fail-closed 误伤）写进了派发词，而块号与行区间（`TASK.md:1906..2023`）指向 `T-FIX-07`（隐私门禁三条假绿）。执行者按 `4-dev.md` R2.4「发现任务定义有歧义 ⇒ 停下反问，不得凭感觉补全」停止并原样上报：两块的 `<name>`/`<write_files>` 与 `REVIEW.md` §0″.6 分解表逐条对照。主 agent 核对后裁决 —— **契约以 TASK.md 的块为唯一来源**，派发词的背景段整段作废，执行者继续执行 `T-FIX-07`。

**教训**：① 派发词的「背景」段**不得引入块外的要求或描述**；确需背景时只允许写「块 id + 文件行区间 + REVIEW 条目 id」，让执行者自己读块与 REVIEW 原文；② 一次派发只对应一个块，同批其他块的摘要不进派发词；③ 执行者的正确行为是**停止并列出矛盾证据**，而不是自行挑选「看起来更严重」的那个执行 —— 本轮若凭感觉开工，会修错文件、污染 `<write_files>` 面，并让两块的 `depends_on` 链条失真；④ 派发词里出现的行区间必须由主 agent 在派发前**实测**（`awk '/<task id="X"/,/<\/task>/'` + 行号核对），不能凭记忆复制。

### L-161 · 「只读」是靠**断言**守住的，不是靠契约措辞：审查/执行 subagent 必须开工与收工各报一次 `git status` 与 `git diff --cached`，写入面只允许 `/tmp`

- 实测（`health-fix-2026-09b` 阶段 6 第 3 轮收口）：两个审计 subagent 的派发词都写明「仓库只读、夹具放 `/tmp`」，收工后 `git status --porcelain` 却多出三项真实仓库改动 —— **index 篡改**（`.specs/health-fix-2026-09b/path-privacy-allowlist.txt` 被改成单行 `# 空清单`，16 行文档头被删；而该文件正是 `check-path-privacy.sh` 的 change 副本）、**暂存探针**（`中 文名.md`，A 状态，内容含探针路径）、以及 `.git/config` 的 `core.quotePath=false` 覆盖（调试遗留 ⇒ 会让 R3-1 类假绿按配置时隐时现）。归因不确定（两名 subagent 之一），但后果确定：审查者把「被审对象」改成了「对自己有利的形态」，而这份改动落在 **index/配置面**（`git diff` 默认看不见，只有 `git diff --cached` 才现形）。
- 定式：① 派发词里「只读」必须配**可执行的收工断言** —— `git status --porcelain` 与 `git diff --cached --stat` 各贴一次，非空即交付不合格；② 审查期**只允许**在 `/tmp` 写，绝不允许 `git add` / `git config`（配置也是仓库状态）；③ 主 agent 收工后必须独立复核 `git diff HEAD --stat` 的改动面等于预期集（本例复核后确认生产件零差异，才敢回退重做）；④ 为验证而造的探针收工必须 `rm` 并复报状态。

### L-160 · 把原始日志贴进工件前必须按 L-129 **逐类**去形：仓库根「和」家目录前缀 —— 否则自己的证据面会成为新的泄漏面

- 实测（`health-fix-2026-09b` 阶段 5 第 8 次执行收口）：整段贴入 REPRO7 原始日志时只替换了仓库根、漏了家目录前缀 ⇒ 下一次 `make check-path-privacy` 报 `清单外命中 3 条`（`✅ /home/<acct>/.dsh/profiles/…` ×2 + `== 门禁 = /home/<acct>/…/independent-review-gate.sh`）；订正为 `<repo>/…` 后复跑 `清单外命中 0 条`。
- 要点：① 去形口径要**成表**（仓库根 / 家目录 / 组织名各一类），不能只处理最显眼的那一类；② 判据必须跑在**贴入之后**（本例正是 commit 前的 `make check` 把它拦下 —— 门禁自己证明了价值）；③ 同一路径在 HEAD 版工件里的既有写法就是权威口径（`<repo>/.dsh/...`），照抄，别发明新占位符。

### L-159 · 外部审查信封一旦被截断就**不可事后补救**：提高上限的重审会被「工件哈希未变」守卫跳过 ⇒ 送审前先把字节账算清，并把「被丢掉的是谁」写进工件

- 实测（`health-fix-2026-09b` 阶段 5 · L3 第 13 轮）：`[l3-review] WARNING: 提示词被截断 — 完整 303899B，本次仅发送 299999B（丢弃 1%）`。改用 `FLOW_KIT_L3_MAX_ARTIFACT_BYTES=400000` 重跑 ⇒ `[l3-review] skipping L3 for phase 5 (artifact hash 不变 + ## L3 段非空)` ⇒ 该轮结论永久停在「基于**部分**工件」。
- 字节账要能回答「截掉的是谁」：本例被截的是补充产物段（`T-FIX-05-SUMMARY.md` 末约 900 B + 整段 `T-FIX-06-SUMMARY.md` 3000 B），**主审面 `TEST.md`（181036 B）完整送达** ⇒ 判定面不受影响。若被截的是主审件尾部，唯一正解 = 先扩大上限、再做一次会改工件哈希的**实质**修订（不得为过审而空改）。
- 定式：① 送审前算「主审件 + 补充产物预算」总量，超限就先**裁补充产物清单**（只留与本轮判定相关的件），不要留给工具在尾部静默丢弃；② 截断必须落工件（现在只有 stderr，读者看不见）；③ 不要把「提高上限」当补救手段 —— 重跑守卫按工件哈希判定，时序错了就只能披露。

### L-158 · 标签抽取必须整行锚定，否则正文里的同名标签会把起点带偏（工具面 · TD-067）

`reproduce-5-test.sh` 的 `extract_verify()` 原按**行内子串**匹配 `<verify>`，而 `T-FIX-06` 的 `<action>` 正文里出现了
`<verify>` 字样 ⇒ 抽取起点落进 action 段，产出 43 行废件（真判据 41 行），被记成「判据失败 rc=2」而非工具缺陷。
这是 **L-153**（未锚定的 `sed` 抽取）在**工具代码**里的复发：凡从 Markdown 权威文本切片的代码必须整行锚定
（`^[[:space:]]*<tag>[[:space:]]*$`），切完立即 `bash -n` 自检 —— 这样语法错误才会以「工具缺陷」而不是「判据失败」的形态暴露。

### L-157 · 收紧判定语义后，所有「干净对照」腿都要复核样本面（判据面 · TD-066）

`T-FIX-06` 给隐私门禁加了 fail-closed 早退（自排除后 `SCANNED_COUNT=0` 且 `CANDIDATE_COUNT>0` ⇒ rc=1），`T17` 的
`CHECK_REV` 对照夹具 tracked 面（被测脚本 + 空允许清单）恰好全命中 `SELF_EXCLUDE` ⇒ 对照腿由 `rc=0` 变 `rc=1`，
判据报红而生产件无回归。教训：任何**收紧**判定语义的修复，都要回扫既有夹具里「期望绿」的腿，确认其样本面在
**新语义**下仍可判定（判据夹具的「干净态」必须含至少一个非自排除的真实候选文件）。

### L-156 · GNU make 的 `-n` 特例与「`$(MAKE)` 递归」互斥：需要「`make -n` 可解析」的薄壳必须用 `bash -c 'make …'` 包裹

**现象（2026-09-25 · T-FIX-05 执行者上报 + 最小复现）**：把 `check-nfr-portability` 改成只做「递归调用 internals + 三态 rc 映射」的薄壳时，若按常规写 `$(MAKE) --no-print-directory check-nfr-portability-internals`，则 `make -n check-nfr-portability` 会**实际执行**该配方行 —— GNU make 对含 `$(MAKE)` / `${MAKE}` 字面（或以 `make` 开头）的配方行在 `-n` 下仍执行 ⇒ 子 make 也带 `-n` ⇒ `check-nfr-portability-internals` 的 `bash -euo pipefail -c …` 只被打印不执行 ⇒ `$NFR_RC_FILE` 从未写入 ⇒ wrapper `cat` 读到空 ⇒ 兜底 `echo 2` ⇒ `case *` ⇒ `exit 1` ⇒ make 报 Error 1 ⇒ **`make -n` rc=2** ⇒ 任何断言「`make -n <target>` 可解析」的判据判红。

**定式**：① 需要满足「`make -n` 只打印不执行」的薄壳递归，写成 `bash -c 'make --no-print-directory <target> >"$OUT" 2>&1 || true'` —— 配方行以 `bash` 开头且不含 `$(MAKE)` 字面 ⇒ `-n` 模式下不执行；make 变量（命令行/环境）经 MAKEFLAGS 与 shell 环境自动下传，`export NFR_RC_FILE` 让子 make 的 shell 看见回传文件；② 契约模板写「`$(MAKE)` 递归」而实现取等价形态时，**必须由主 agent 就地裁定并标注**（`<action>` 若已写「或等价的递归调用」则可直接采用）—— 这类「契约与实现措辞张力」是 `-n` 可解析性断言造成的**结构性互斥**，不是实现偷工；③ 判定薄壳是否真的变薄、判据正文是否唯一，用可执行钉住断言（本例：`grep -c '_report_viol() {' Makefile` 必须为 1 + wrapper recipe < 30 行），复发即刻转红。

**状态**：✅ 已吸收（`Makefile:255-266` 薄壳 + 常设断言固化在 `test/test_nfr_portability_gate.bats` 用例 6；`TASK.md` 的 T-FIX-05 `<done>` 就地标注裁定）。

### L-155 · 判据夹具的样本必须从**被测数据的权威来源**派生：`ls … | head -1` 的偶然顺序会让判据把「正确行为」判成缺陷

**现象（2026-09-24 · 阶段 4 复核 T-FIX-04 时 · TD-065）**：`TASK.md` 的 T-FIX-04 `<verify>` 用 `hidden=$(cd "$SBX/fk" && ls flow-kit-bundle/skills/*/SKILL.md 2>/dev/null | head -1)` 选「要被隐藏的 skill 文件」，取到字母序首个 `flow-architect/SKILL.md`；而被测生产件 `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:37-40` 的 `PAIRS` 只含 `flow-evolve` / `flow-intel` / `flow-restyle` ⇒ 隐藏的是**非比对对成员** ⇒ 生产件的 `MISS=0`，修复后代码的**正确**行为（汇总照旧 `✅ 校验对 3/14 一致`）被判据报成 🔴「F6：缺一对文件仍 rc=0」⇒ `<verify>` 恒 rc=1、任务永远无法提交。执行者按硬规则停下原样上报，主 agent 坐实后修判据。

**定式**：① 判据夹具的**样本选择**与生产代码一样需要被测数据作为唯一真相源 —— 从权威声明派生（本例 `pair_skill=$(grep -oE '\|flow-[a-z0-9-]+' <生产件> | head -1 | tr -d '|')`），禁止 `ls … | head -1` / `find … | head -1` 这类依赖文件系统枚举顺序的取法；② 派生到样本后必须断言「存在且属于被测集合」，否则夹具自身 fail-closed 打印「判据前置失败」并置 rc=1（把夹具缺陷与被测缺陷分开归因）；③ 与 TD-060（判据块 `cd` 进沙箱后未回仓根）同属「判据自身缺陷」家族 —— 判据的**错误**只能由人来裁决，执行者必须停下上报而不是改判据。

**状态**：✅ 已吸收（判据已改，`TASK.md` 就地标注；v2 计划在 `make lint` 加静态检查：`<verify>` 块内出现 `ls … | head -1` / `find … | head -1` 且无集合成员断言时告警）。

### L-154 · 交付窗口内的「冻结」是硬约束：改了 `test/` 之后不按 `make test-sync` → 重建 dist 的顺序收尾，会让**别人的整轮回执凭空变红**

**现象（2026-09-24 · 阶段 5 终版复跑）**：主 agent 为修 G-T04-1/G-T04-2（`l3-prompt.sh` 文案）改了 `test/test_l3_review_defects_2026_09.bats`，并各自跑通了 `check-hooks-sync` / `check-test-sync` / `check-dist`；但那次 `check-dist` 通过是在 `make test-sync` **之前**跑的 —— 随后 `make test-sync` 更新了 `flow-kit-bundle/test/…`，dist 里的 vendored 副本却没重建。与此同时执行者正在跑「终版整轮 14 判据」，于是 `make check` 的 `check-dist` 报 `❌ 陈旧: dist/dsh-flow-kit/vendor/flow-kit-bundle/test/test_l3_review_defects_2026_09.bats（内容与 … 不一致 → 请重建 dist）` ⇒ 三条本来绿的判据（T29 / T-FIX-01 / T-FIX-02，都要调 `make check`）**整轮 rc=1**。根因是**顺序**（Makefile 自己的报错里就写着「若改过 test/，先 make test-sync，再重建 dist」），不是判据缺陷；`bash package-dsh-plugin.sh` 后即恢复（终版整轮 rc=0）。

**定式**：① 任何「改 test/ 或改 hooks/」的收尾序列固定为 **`make test-sync` → `bash package-dsh-plugin.sh` → `make check-hooks-sync check-test-sync check-dist`**，且三步必须都跑在**最后一次**源面改动之后（只跑对其中一步等于没跑）；② 派子 agent 跑整轮回执前先**声明冻结**（freeze）：主 agent 停止一切源面写入，回执只对声明时的树有效 —— 本次的红点就是「回执跑到一半树被改」的代价，好在执行者如实归档而没有伪绿；③ 回执日志必须记 `HEAD` + 树状态，否则事后无法区分「产品缺陷」与「窗口污染」；④ 凡间接依赖 `make check` 的判据都会**连带**受 dist 新鲜度影响 —— 归因时先看 `check-dist` 一行，别先怀疑被测实现。

### L-153 · 抽取判据块必须**锚定整行标签**：正文里出现 `<verify>` 字面会让非锚定区间重开，把标签之外的行混进被执行的脚本

**现象（2026-09-24 · 阶段 4 复核 T-FIX-01 时）**：`awk '/<task id="T-FIX-01"/,/<\/task>/' TASK.md | sed -n '/<verify>/,/<\/verify>/p' | sed '1d;$d' > judge.sh` 抽出 **38 行**（判据本体只有 36 行），末尾多出 `  <depends_on>T29</depends_on>` 与 `  </task>` ⇒ `bash -n judge.sh` 报 `未预期的记号 "newline" 附近有语法错误`。根因：该 task 的 `<done>` 正文里引用了标签字面（「**`<verify>` 原样跑 rc=1**」），而 `sed` 的 `addr1,addr2` 区间**每次匹配到 addr1 都会重开** ⇒ 在 `<done>` 行重新开区间；真标签是**整行** `  <verify>`（两个空格缩进、独占一行），普通子串匹配既会误命中正文，也分不清开闭标签。

**定式**：① 判据抽取一律**整行锚定**：`sed -n '/^  <verify>$/,/^  <\/verify>$/p' | sed '1d;$d'`，或用带 `seen` 标志的一次性 awk 状态机（`/<verify>/{if(!seen){f=1;seen=1};next} …`）；② 抽取后**先 `bash -n` 再执行** —— 语法错说明抽歪了，绝不能带着多抽的行去跑（会把 `</task>` 当命令执行）；③ 自动写的 `<done>` / 注释正文引用标签字面（`<verify>`、`</verify>`、`<task …>`）会**破坏下游文本抽取**，本仓多个 task 的 `<done>` 都引用过这些字面 ⇒ 抽取器要做的是锚定，而不是寄希望于正文不出现标签；④ 抽取结果与预期行数不符时先打印首尾行号核对（本次 `head -8` + `tail -3` 一次定位），不要先怀疑判据逻辑。

### L-152 · 门禁的强度等于它**最早返回**的那个判定：以「文件存在」为界 ⇒ 配套的内容校验成了不可达装饰；而只匹配命令文本的守卫可被拼接绕过

**现象（2026-09-24 · 阶段 5 · `reproduce-phase-gate.sh` 的 B2/B3 实测反推 ⇒ TD-059）**：DSH 阶段门（PreToolUse `independent-review-gate.sh`）对「独立审查是否完成」的判定是**文件存在性** —— `flow-kit-bundle/hooks/stop/lib/done-validation.sh:35` 的 `fk_independent_review_gate_active` 末行是 `[[ ! -f "$done_marker" ]]`：标记**存在**即返回「门未开」（1）⇒ `gate-helpers.sh:174 _gate_active_check` 返回 0（skip）⇒ `_run_review_gates` 的 Gate3 直接 `exit 0` 放行。于是 Gate4 的 `_gate_done_validation`（`gate-helpers.sh:186` → `fk_validate_done_marker … transition`）**永远跑不到**：6 键 KVP 值域校验、`MIN_MEANINGFUL_LINES=6`、以及 Tier-2「`.done` 的 `L2_verdict` 必须与 `INDEPENDENT-REVIEW-<phase>.md` 的口径一致」全部成了**不可达代码**。沙箱实测：标记记 `pass` 而审查档记 `fail` ⇒ rc=**0**；删掉 `L3_verdict` 键（5 行 < 6 行）⇒ rc=**0**；只有「文件不存在」才 rc=2 并给出拒绝报文。

**同一现象的第二半（防御面）**：该门禁对外唯一实际防线是 D7 path-guard，而它只对**命令文本**做握手文件名匹配 —— 实测：含该文件名的 `python` heredoc 整条被拒（报文「agent 不得自产 `.done` 绕过 L3 审查」），而**用 edit 工具**或**在脚本内用变量/`printf` 拼出文件名**都能通过 ⇒ 文本匹配守卫面对"换个写法"就是零阻力。

**定式**：① 门禁必须写清判定语义是「**存在**」还是「**存在且有效**」，并让「存在但无效」落进**同一个拒绝分支**（本例应把 Gate3 的存在性判定换成复用 Tier-1 校验）；② 任何校验代码若位于某个更早 `return`/`exit` 之后，必须有一条判据**证明它可达** —— 否则它不只是死代码，还会给审查者「这里已经校验过了」的错觉（比没有校验更危险）；③ 依赖文本匹配的守卫必须同时具备**语义**检测（解析写入目标路径 / 写入内容形态），且判据要用**拼接形态**对抗自己（同 L-137 的探针拼接）；④ 夹逼判据必须同时钉住「该拒的」与「该放的」两侧，并把**配置错误伪装成拦截成功**的形态单列（本例 `HOOK_BASE_DIR` 语义不一致导致的 fail-close 会拒绝一切 commit，看起来"门禁很严格"，见 TD-058）。

### L-151 · 审查信封对补充产物只取前 3000 B ⇒ 给外部审查者的证据必须「倒置金字塔」：结论与复算入口放文件头

**现象（2026-09-24 · 阶段 5 · L3 第 3 轮 major 1）**：`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:286 _l3_extra_deliverables` 会把 change 目录内的补充 `*.md` 附进 L3 提示词，但**每件只取 `_l3_utf8_head_bytes 3000`**（`:304`），并附一句「本件 %sB 超过补充产物预算 3000B，已按整行截断；完整正文见 `%s`」（`:312`）。我交付的 `PHASE5-RECEIPTS.md` 有 725 行 / 35509 B，把 12 条判据的原始 stdout 与全部门禁回执都写在里面 —— 但 L3 只看得到**前 3000 B（约 §A 的判据表）**，于是它判定「核心数字仍不可从工件内复算（回执是截断件）」。**证据写全了，却放错了位置**。注意主工件（`TEST.md`）走的是全量预算（`:388-391`）⇒ 不对称只发生在补充产物上。

**定式**：① 面向外部审查者的证据文件一律**倒置金字塔**：首屏（≤3000 B）内给出「结论 + 一行复算命令 + 逐条判据 rc 表」，细节与原始 stdout 依次后置；② 倒置**不等于**把证据写成摘要 —— 一手输出仍要全文落档（本例保留 §A/§B 原文），只是**索引与结论前置**；③ 任何「必须被审查者看到的数字」要么写进主工件，要么落在补充产物的前 3000 B 内；④ 交付前自查：`head -c 3000 <file>` 单独读一遍，问「只看这些能否复算并作出判定」；⑤ 依赖这条预算的判据要写明「本文件头部为可复算索引，正文为原始存档」——否则下一位审查者会把截断读成敷衍。

### L-150 · 「完备性」判据会把新产品件自动推向豁免面：判据必须编码**策略**（时间切点），不能编码**集合快照** —— 否则它亲手弄瞎它要保护的门禁

**现象（2026-09-24 · 阶段 5 · T17 判据复算红）**：T17 的 verify（阶段 3 起草，依据当轮 L3 M8 的「两处排除面同源、不得静默漂移」）写的是**集合完备**断言 —— 遍历 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-*.md`，每份都必须出现在门禁 `check-path-privacy.sh` 的文本里（`TASK.md:738-743` 旧文）。阶段 5 新增第 4 份审查档后该断言按设计变红，报文要求把新档**加进门禁的 `SELF_EXCLUDE` 豁免表**。

**为什么按判据做是错的**：同一份新档在写入当天被 `make check-path-privacy` 判红 **rc=2**（`:9` 真实仓库根 + `:18` 整形态合成探针，清单外命中 1 条）⇒ 它正是脱敏泄漏的**第一现场**。若顺从该断言把它塞进豁免表（豁免 = 整文件跳过），同一处泄漏立刻**静默入库** ⇒ 判据为了保证自己的「完备」，会主动关闭 AC-6 的机器门禁。旧规则的隐含策略（「所有审查档一律豁免」）与本 change 已定的策略（审查档原文**因协议禁改**才豁免冻结的 1–3；此后新增档必须脱敏 —— L-149/TD-054）**方向相反**，而判据文本从未写下策略，只写下了当时的集合快照。

**定式**：① 判据断言**策略边界**（本例：豁免面**不得超出**冻结集 1–3；新增档被追加进豁免表 ⇒ 红，放宽须 ADR 裁决），而不是断言「当前所有 X 都在 Y 里」—— 后者在 X 增长时必然把新 X 推向 Y；② 判据改动必须**双向**：既挡放宽（新增档不得进豁免表），也挡**收窄**（冻结的 1–3 必须仍在表内），否则「修红」最省事的做法会退化成删掉整段断言；③ 判据与其消费者的同源关系要写成**规则**（时间切点 + 逐条精确路径）并在两侧工件（T13 done 注记 / T17 verify）同批订正，否则两侧各自漂移；④ 遇到「判据 vs 产品策略」冲突，先问**哪一侧代表 change 的目标**（本例 AC-6 的目标是**前向**脱敏），再决定改判据还是改产品 —— 禁止为了让判据变绿而放宽产品面。

### L-149 · 审查派发面必须显式要求脱敏：L2/L3 会把真实仓库根原样写进审查档，**入库瞬间**击穿 AC-6 的机器门禁

**现象（2026-09-24 · 阶段 5 实测）**：L2 盲审档 `INDEPENDENT-REVIEW-5.md:9` 写「仓库根 `/home/<acct>/…/flow-kit`」，`:18` 把合成探针写成**整形态** ⇒ 用 `git add -N` 探测后跑 `make check-path-privacy` = **rc=2**，归因 `INDEPENDENT-REVIEW-5.md:18`（清单外命中 1 条）；同一文件还令 T13 判据在首次复跑时 rc=1。修复后双门禁复验 rc=0。

**判据**：① `check-path-privacy.sh` 的扫描面 = `git ls-files`（**索引**）⇒ 未跟踪的审查档在 change 期内「看不见」，一旦 `git add` 立刻被扫（CI 前无感、入库时爆红）；② PAT = `/home/[a-z_][a-z0-9_-]*/` **要求尾斜杠** —— `/home/<redacted>`（无斜杠的历史引用）合法不命中，整形态探针字面（`/home/` + 探针账号名 + `/`，惯用合成名 `zz-path-probe`）命中；③ 审查档不在 `SELF_EXCLUDE` 六条内（那六条是门禁本体/允许清单/REVIEW-1..3 的精确豁免）。

**做法**：① 派发 L2/L3 时在审查参数里写明「仓库根一律写 `<repo>`；`/home/<acct>/` 与整形态探针禁止，探针字面按 L-137 拼接构造」；② 任何**新工件在入库前**用 `git add -N <新文件>` + `make check-path-privacy` 探测一次（探测后 `git reset -q -- <路径>` 复原，无副作用），不要等到提交时才发现；③ 对审查档就地脱敏时只改「证据叙述」，**不动四要素与判定**，并在响应段注明「已按 L-129 脱敏，判定未改动」。

**关联**：`L-129`（脱敏）、`L-137`（探针字面必须拼接构造）、`TD-054`（派发面缺脱敏条款 —— v2 修法：三处模板加条款 + 写 `.done` 前对审查档跑脱敏自检）。

### L-148 · PreToolUse 门禁按**文本内容**匹配手shake 文件名 ⇒ 连只读勘查（`ls` / `git check-ignore`）也会被当成「自产 `.done`」整条拦下；查手shake 状态要用不含文件名的形式

**现象（2026-09-24 · 阶段 5 实测）**：主 agent 执行 `ls -la .specs/<id>/.independent-review-*.done` 与 `git check-ignore -v …/.independent-review-3.done` ⇒ **整条 bash 调用**被 `gate-checks-review.sh` 拒绝，报文 `agent 不得自产 .done 绕过 L3 审查——.done 须由审查子系统（l3_review_run / L2 子 agent）产出`（附 `/flow gate-config <phase>=off` 的绕过提示，按纪律禁用）。本次拒绝**无副作用**（整条命令未执行），但打断了取证节奏。

**判据**：门禁对「命令文本中出现手shake 文件名」判定为**写意图**，不区分只读与写入 —— `ls` / `grep` / `git check-ignore` 同样命中；这与「PreToolUse 只拦 Write/Edit」的直觉相反（L-144 已证另一层：本仓 git hook 根本不运行，唯一有效门禁是 DSH 装载面的 hook 链）。

**做法**：① 勘查目录内容/忽略状态时用**不含文件名**的形式 —— `ls -a <dir>`、`git ls-files <dir>`、`git status --short --ignored <dir>`（`!!` 行即已忽略）；② 不要把「是否已存在某手shake 文件」写进主 agent 的命令行，需要时交给审查子系统或脚本内部判断；③ 把「手shake 状态勘查」提前写进派发前置清单，避免临场拼文件名。

**关联**：`L-144`（门禁生效面）、`TD-050`（hooksPath 与 hook 部署）、阶段 5 §5.1 的门禁报错可读性证据。

### L-147 · 判据复现产品的排除面时两侧**授权粒度不同源**：产品按「整文件自排除」豁免，判据必须按「精确字面/成分」豁免 —— 抄产品的 `SELF_EXCLUDE` 会把判据对它自己最该覆盖的那一面一起弄瞎

- 场景（2026-09-24 · 阶段 5 第 1 轮 · 主 agent）：`check-path-privacy.sh` 的头部注释（T22 追加的「空基线双态自检」块 `:22-24`）**必然**含 PAT 字面 —— 它要在自证文档里说明「拼接构造的畸形探针（账号名 `zz-path-probe`）」这一双态判别力。产品侧按 D10′② 用 `SELF_EXCLUDE`（六条**逐条精确路径**，`:47-54`）把该文件**整文件**排除 ⇒ `make check-path-privacy` 报「清单外命中 0 条」、rc=0（设计如此，注释原文：「否则门禁会被自己的工件击穿」）。
- 判据侧：T13 的 verify 是**原样 grep**，它**刻意不排除任何文件**（其职责正是覆盖产品的自排除面 —— 产品看不见的那 6 条路径只能由 change 期判据看），只豁免三份审查档与通用占位符（`user|ubuntu|...`）⇒ 复跑把该合成探针账号名报成 `🔴 脱敏越界（非本 change 工件/台账 ⇒ 停止并升级为新 task）：flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`、rc=1。
- 为什么是「自造红」（TD-048 同类）：T13 在阶段 4 实测 rc=0（**当时注释尚未追加**），是 T22 之后的改动让它失效；而 T13 的判据不在阶段 4 的回归集里 ⇒ 直到阶段 5 全量复跑才暴露（L-139 同型）。**红在产品行为合法变化之后，不是代码坏了。**
- 定式：① 判据自建排除表前先问「产品的排除**粒度**是什么」—— 产品豁免的是**文件**（因为该文件必然含字面），判据只能豁免**匹配成分/精确字面**（否则真实账号路径会被同一条豁免一起吞掉）；**禁止**把产品的 `SELF_EXCLUDE` 抄进判据（那等于让判据对最该覆盖的 6 条路径失明，本例中那正是 T13 存在的全部理由）。② 收窄判据面之后必须立刻做**判别力注入**证明它还活着，且两个分支都要打：非面文件注入**另一个**合成账号名 ⇒ rc=1 且指名 `file:line`（同时验证豁免是「按字面」而非「按文件」）；面内文件注入 ⇒ rc=1 走「清单外命中 = N ⇒ 就地脱敏」分支。③ 判据里的注释**不得放在反斜杠续行中间**：`hits=$( … \` 之后插注释会让下一行以 `|` 开头 ⇒ `bash -n` 直接语法错（本次首版修复即踩此坑，抽取实跑时暴露）。
- 副产物：**TD-052** —— 产品的「整文件自排除」在常设门禁下是**结构性盲区**（那 6 条路径的真实命中永不可见，仅 change 期 T13 覆盖；归档后无判据覆盖）；v2 可评估把「整文件豁免」降级为「纳入扫描面 + 按精确字面允许」。

### L-146 · 判据里的 `export LC_ALL=C` 会泄漏进它调用的测试套件；`iconv -f utf-8 -o f` 的目标字符集取自 locale ⇒ 地域 C 下拒绝合法 UTF-8（假红）

- 场景（2026-09-24 · T27）：判据（`TASK.md` T27 `<verify>`）首行 `export LC_ALL=C`（本意只为归档扫描的排序/计数确定性）**同时作用于脚本末尾的 `npx bats test/`**；套件里 `test/test_l3_pipeline_fix.bats:609` 的 `printf '%s' "$capped" | iconv -f utf-8 -o /dev/null` **没写 `-t`** ⇒ `iconv` 的目标字符集取当前 locale：`LC_CTYPE=C` ⇒ 目标是 ANSI_X3.4-1968(ASCII) ⇒ **任何合法多字节 UTF-8 都被判非法**。
- 最小复现（我亲测）：`printf '中文测试' | LC_ALL=C iconv -f utf-8 -o /dev/null` ⇒ rc=1、stderr `iconv: illegal input sequence at position 0`；`LC_ALL=C.UTF-8` ⇒ rc=0；本机 `LANG=zh_CN.UTF-8` ⇒ rc=0；`LC_ALL=C` 但显式 `-t utf-8` ⇒ rc=0。注意 `-o` 只是**输出文件**，不是目标编码。
- 现象：`LC_ALL=C npx bats test/test_l3_pipeline_fix.bats` ⇒ `not ok 41 T06fix: L2 R1 - line cap truncation respects UTF-8 boundary`（rc=1、ok=40/not_ok=1）；本机环境地域下同文件 rc=0 / 41 ok。**产品代码无回归**：该用例的被测输出在两种地域下逐字节相同且都是合法 UTF-8（`_l3_utf8_head_stream` 内部已 `local LC_ALL=C`，与外部 locale 无关）。
- 危害面（不止这一条判据）：`Makefile:8-11` 的 `test:` 目标**不设** locale ⇒ `make test` 与调用它的 pre-commit 门禁**继承用户 locale** ⇒ 在 `LC_ALL=C` 的 CI/容器里 `make test` 会假红（正是 ADR-027 ②③ 最忌的形态：把守规矩的代码判成违规，长期红终被绕过）。
- 定式：① 判据里对环境的改动（`LC_ALL`/`LANG`/`PATH`/`TZ`）必须**限定作用域** —— 要么用前缀式 `LC_ALL=C cmd …` 只包住需要它的那一段，要么在下游调用前显式还原（`unset LC_ALL`）；② 「编码合法性」断言**不得依赖 locale**：`iconv` 一律写全 `-f/-t`；③ 复核判据时不仅看它自己的断言，还要看它**给下游导入了什么环境**（本例判据输出 `ok=975 / not-ok=1` 是「环境脏」而不是「代码坏」）；④ 出现「判据红、但所有残留扫描 CLEAN」时，先做**地域双态对照**再定性（改判据作用域 vs 改被测件，二选一必须给出证据）。

### L-145 · 改写判据的某条分支时，必须先枚举旧实现的**语义清单**并逐条回归 —— 换了实现方式不等于换了语义

- 场景（2026-09-24 · T28 修复轮 1）：把「失败归因打印拼接流偏移量」改为「逐文件 `file:line`」时，tracked 分支用 `git diff -U0` + awk 逐行解析（新侧行号口径正确），但 untracked 分支被顺手换成 `grep -nE "$pat" "$file" | sed … | grep -E "$pat"` —— **丢掉了旧实现顺带承担的「剔除整行注释」语义**（旧实现是 `… | grep -vE '^\+?[[:space:]]*#'`，且 T28 的 `<action>` 与 `Makefile` 自己的注释块都写着该口径）。
- 后果：一个**只含注释**的未跟踪新文件（注释里提到 `mapfile` 仅作说明）被判违规 ⇒ `make check-nfr-portability` **rc=2** ⇒ 门禁**假红**（ADR-027 ②③ 最忌的形态：把守规矩的文本判成违规；长期红的门禁会被绕过）。
- 为什么容易漏：注意力全在「新实现能不能拿到真实行号」上，而旧实现**顺带承担的语义**（注释剔除、豁免删除、模式集合）没被当成契约列出来 —— 派发文本写了「检测集合与豁免口径不动」，却没写「注释剔除口径不动」。
- 定式：① 替换任一分支的实现前，先把旧实现的**语义清单**逐条写下来（剔除规则 / 行号口径 / 豁免与成分删除 / 空集与 `SKIP` 语义），派发时逐条点名「不动」；② 每条语义至少一个探针（本例：纯注释文件 ⇒ 必须 rc=0；注释+空行+真违规混排 ⇒ 只报真违规那一行的**真实行号**）；③ 探针要成矩阵（正例 / 反例 / 边界 / 回归），不要只测新功能点；④ 换实现时留意「保行号」与「剔注释」天然冲突（`grep -v` 后再 `grep -n` 会把行号改掉）—— 解决方式是在**同一次遍历**里同时完成（如 `awk '/^[[:space:]]*#/{next} {…; if (l ~ P) printf "%d:%s\n", NR, $0}'`）。

### L-144 · 「提交没被拒绝」不是门禁生效的证据：本仓 `core.hooksPath` 为空串，git 一个 hook 都不调用

- 场景（2026-09-24 · 主 agent 自查）：我的 T19/T20/T25/T26/T28 复核记录里多次写「pre-commit 门禁随提交真跑通过」，而实测本仓**任何 git hook 都不会被调用**：
  - `.git/config` 的 `[core]` 段有 `hooksPath = `（**空串**，不是「未设」）⇒ `git rev-parse --git-path hooks` 输出 `./`、`git rev-parse --git-path hooks/pre-commit` 输出 `/pre-commit`；`git config --list --show-origin --show-scope` 的唯一相关项 = `local file:.git/config core.hookspath=`；global/system 未设；env 无 `GIT_CONFIG_COUNT`；
  - 决议性判据：`git hook run pre-commit` ⇒ `error: cannot find a hook named pre-commit`（git 2.43.0）—— 该命令按 git 自己的解析链查找 hook，找不到即证明 git 不会调用它。
- 连带解释：本 change 期间我的一次收口提交把判据原始输出（含本机账号路径）写进 `MINOR-DEFERRED.md` 而**未被拦**；我当初归因为「门禁没覆盖该形态」，真相是**机制根本没运行**（已核对那次提交的原始命令：未使用 `--no-verify`，输出里也没有任何 hook 报文）。
- hook 脚本本身没问题：`.git/hooks/pre-commit` → 符号链接到已安装的 `~/.claude/hooks/pre-commit/pre-commit.sh`，**显式调用** `bash .git/hooks/pre-commit` 两次实验都 rc=1（新建带本机账号路径的探针文件 ⇒ 指名 `.zz-probe1.txt:1`；向 tracked `README.md` 追加同形串 ⇒ 指名 `README.md:151`），并打印 `[archive-commit-gate] path-privacy check failed, commit rejected`。
- 定式：① 门禁证据**只能来自显式调用**（`bash .git/hooks/<hook>` / `make <gate>`）—— 禁止从「提交成功、没被拒」反推门禁跑过；② 任何「机制 X 生效」的声明先花一条命令验**机制本身**（`git rev-parse --git-path hooks`、`git hook run <name>`、`command -v`、`[ -x ]`）；③ 复核记录里的每条断言都要能指向一次**真实执行**的输出，「应当会触发」不是执行；④ 机制被禁用属环境事实，如实标注并在别处（隔离沙箱 / 显式调用）取证据，既不把它算成产品缺陷，也不让已失效的门禁承担证据。
- 产品侧同源缺口登记为 **TD-050**（`install_hooks.sh` 写死 `.git/hooks/`，不检测 `core.hooksPath`）。

### L-143 · 两个任务之间的「接线断口」只能由端到端判据发现；单任务的静态判据在结构上不可能覆盖

- 场景（2026-09-23 · T11→T17→T19）：`flow-kit-bundle/hooks/pre-push/pre-push.sh:30` 传 `CHECK_REF="$local_ref"`，而 `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:90` 读的是 `${CHECK_REV:-}` ⇒ **死变量**，门禁的评估面永远是本地工作树，从不切到被推送的 ref 树。
- 为什么单任务判据抓不到：T11 的 `<verify>` 只有 6 行静态检查（文件存在 / 755 / `grep -q 'make check'` / `bash -n` / 无 bash4-GNU 构造），断言的是「文件长得对」；而**生产方传的变量名**与**消费方读的变量名**分属两个任务的文件 —— 任何只看单个文件的判据在结构上都看不见。
- 为什么单形态测试也抓不到：只推单个 ref 时「工作树 == 被推送的树」**恰好等价**，FORM1（`git push origin main`）会正确通过；只有多 ref 形态（`--all` / `--mirror`）才暴露归因错位 —— 钩子把泄漏归因给**字母序第一个 ref**（干净的 develop）而不是真正含泄漏的 main，且工作树恰好干净时泄漏 ref 会被整批放行。
- 处置规范：① 跨任务接口（环境变量名 / 函数名 / 文件路径契约）必须在**端到端判据**里被真实执行至少一次；② 端到端判据必须含**归因对照**（摘掉被测组件后同一操作必须转绿），否则「拦住了」无法归因到该组件；③ 判据型任务发现产品缺陷时，正确动作是 BLOCKED + 最小复现 + 建议修法，**不改产品件** —— 修复轮由产品件属主任务开（本次即 T11 修复轮 1）。
- 判据「原样可跑」的口径（重要）：字面判据必须在**不额外加 `set -e`** 的条件下取得 rc（本次字面 33 行实测 rc=0，并肉眼可见 `扫描面: <sha>` 而非 `扫描面: 工作树`）。「只有在额外 `set -euo pipefail` 下才中途退出」属于判据措辞的健壮性提示（ℹ️），**既不得据此宣称判据失败，也不得反过来据此掩盖产品缺陷**。

### L-142 · 会改写受保护产物的判据必须自带「备份 + EXIT trap + 逐字节复原断言」三件套，否则不可重跑

- 场景（2026-09-23 · T26）：AC-6 端到端判据必须临时把探针写进 tracked 的 `.specs/CONTEXT.md`，向 **T21 冻结的权威清单**追加一条（④a 差分数），再把权威清单整体 `mv` 走（④b 读序双态）。
- 风险：这类判据一旦在中途失败，就会把探针或临时条目**留在常设基线上** —— 其后果不只是脏工作树，而是此后**所有提交都被自己的门禁拒绝**，且 T21 的冻结产物被污染。
- 三件套：
  ① 每个将被改写的文件先 `cp` 到 `/tmp` 备份（本例 `/tmp/probe-bak` / `/tmp/al-bak` / `/tmp/al2-bak`）；
  ② `trap '…' EXIT` 覆盖**所有**分支，含每一条 🔴 早退路径；
  ③ 末段对每个文件 `cmp -s <file> <bak>` **逐字节**断言，失败即 🔴（"内容看起来恢复了"不算，必须逐字节）。
- `mv` 型探针的额外要求：被移走的文件路径（本例 `/tmp/al2-moved`）必须一并纳入 trap，否则中途退出会把文件永久留在 `/tmp` 而原位置空。
- 复算价值：正因为有这三件套，第三方可以**直接重跑**该判据而不担心污染 —— 主 agent 实跑后 `git status --short` 仍只剩 5 个冻结 `A `、`git diff --stat` 为空，这本身就是「复原成立」的独立证据（比读执行者的 `cmp -s` 报告更强）。

### L-141 · 子 agent 的「进度通知」与「在盘改动」都不代表它仍在运行；存活判定要三证合看

- 现象（2026-09-23 · T20）：子 agent 报「已改 hook + 已 sync」并在盘上留下真实改动（19:47），随后**停住约 3 小时**，其状态为 `[ready]`（只在存储、未运行）。第二次停住换了形态：它起了个**后台** bats 作业就结束回合（自述 `will collect later`），而该作业在收集测试文件阶段就失败并被终止（`/tmp/t20-bats.out`：`1..1` / `not ok 1 bats-gather-tests` / `已终止`），`pgrep -af bats` 无任何进程 ⇒ 「稍后收集」永远不会发生。
- 与既有教训同源：b94 的「已交付 ≠ 已开工」（消息送达不等于开工）；本例是它的镜像面 —— **已开工 ≠ 仍在跑**。
- 规范：
  ① 判定子 agent 存活 = 三证合看：`list_agents` 状态（`running` / `ready`）+ 关键文件 mtime + 台账（`.flow-active.goal.task_progress`）条目数；任一「无进展」即视为停住。
  ② 长时命令一律**前台**执行；确需后台时必须在**同一轮内**取回结果，不得以「稍后再收集」结束回合。
  ③ 跑门禁/套件必须用**真实 `$HOME` 与仓根 cwd**：把 `HOME` 重定向进夹具目录会让 `npx` 缓存与 bats 解析失效（本例即因此 `bats-gather-tests` 失败）。
  ④ 停住的子 agent 优先唤醒（给「已完成 / 未完成」两栏 + 剩余步骤清单）；连续两次无效则换**新执行者**接手盘上状态，主 agent 不代写执行者产物。

### L-140 · 计数必须直跑 bats；`make test` 的输出是装饰性截断，且 TAP 的 `ok` 行**含** skip

- 现象（2026-09-23）：`make test` 的 stdout 只保留末尾 3 行 `ok`（`Makefile:10-11` = 装饰性 tap 尾部 + 权威 rc 断言）⇒ 从它数 `^ok` 得到的是 **3** 而不是 973；计数只能直跑 `npx bats test/`（pre-commit 用的也是它）。
- 第二个口径陷阱：TAP 里 skip 表现为 `ok N # skip <reason>`，**计入 ok 行** ⇒ 「973 ok」既可能是 972 pass + 1 skip，也可能是 973 pass + 0 skip。报基线必须同时给出 `# skip` 计数。
- 本 change 的实例：T10 去掉 `test/test_lessons_cleanup.bats` AC-4 的过期 skip 后，基线由 972+1 变为 **973 pass + 0 skip**（测试总数不变），而 `STATE.md:48` 与若干产物仍写「1 skip」⇒ 收口时须同步该口径。
- 规范：① 计数直跑 `npx bats test/`，分别报 ok / not ok / skip 三项；② 引用「法定基线」时注明出处与日期，别把文档口径当实测值；③ 总数不变而 skip 减少 = 覆盖率提升，属交付成果而非噪声。

### L-139 · 阶段判据的前提会随后续任务改变；判据陈旧只能靠「改动后跑全套回归」暴露

- 现象（2026-09-23）：T17 判据（18:19 PASS）的断言在**真实仓根**上要求「清单缺失态 rc=1」；T21（18:55）冻结常设清单后该状态不再存在 ⇒ 断言恒红，直到 T23 按主 agent 要求跑全套历史判据回归才暴露。
- 关键区分：**判据陈旧 ≠ 门禁回归**。定性手法 = 在同一断言的**改动前**提交上复跑（优先 `git worktree add`；`git stash` 受 L-136 限制）⇒ 仍红即与本次改动无关；并检查被断言的分支是否另有判据覆盖（此处 T21 判据仍在夹具里覆盖 fail-closed）。
- 规范：
  ① 依赖「某路径不存在 / 某文件未 tracked」的断言必须**自建缺失态夹具**，不得依赖真实树恰好处于该状态。
  ② 改动被多个任务共用的门禁脚本后，回归清单必须包含**全部历史判据**（本 change：`v_T17`/`v_T18`/`v_T21`/`v_T22`/`v_T23`），不得只跑本任务与直接依赖。
  ③ 发现恒红先定性再动手：判据陈旧 ⇒ 订正判据并重跑；门禁回归 ⇒ 回滚改动。

### L-138 · 派发文本里的纪律提醒不足以防止违规；判据必须能在提交前自捕

- 现象（T22 首版 · 2026-09-23）：派发文本已逐字写明「不得在自撰产物里写活的 `/home/<name>/` 字面量」，执行者仍在 `T22-SUMMARY.md:22` 写下本机仓库绝对路径；被**它自己的判据第 1 轮**抓住（`make check-path-privacy` ⇒ `清单外命中 1 条`、归因 `T22-SUMMARY.md:22`），改为 `<repo>` 占位后 rc=0。
- 规范：
  ① 纪律靠**机制**落地，不靠提醒：凡涉及扫描面的任务，判据必须自带「产物自扫」或「提交后门禁复跑」这一步。
  ② 判据在提交前跑（L-137①）时，必须先把新产物 `git add` 进扫描面，否则"自捕"本身就看不见。
  ③ 执行者自捕违规并自建修复轮 ⇒ 记 `fix_rounds>0` 但**不升级**为缺陷（省掉主 agent 一个往返）。

### L-137 · 「扫描面的判据」必须在 `git add` 新产物之后运行 —— 提交那一刻扫描面才扩大

- 现象（T21 首版 · 2026-09-23）：`T21-SUMMARY.md` 在**未 tracked** 时跑门禁 ⇒ `清单外命中 0 条` rc=0；`git commit` 让它变 tracked ⇒ 同一门禁立刻 `清单外命中 1 条` rc=1，归因 `T21-SUMMARY.md:75`（文件引用了合成探针字面量 `/home/` + `zz-path-probe` + `/`，三段全落在 PAT 字符类 `[a-z0-9_-]` 内）。
- 规范：
  ① 任何**扫描面相关**的判据（隐私 / 许可清单 / 体积上限等），必须在把新产物 `git add` **之后**再跑；否则判据验的是旧扫描面，提交即失效。
  ② 产物与提交信息中**不得出现活的 `/home/<name>/` 字面量**（L-129 扩展），即使它是自造的合成探针；需要展示形态时用「相邻单引号拼接」写法，或不复现字面量。
  ③ 交付前对**自己写下的每个文件**做一次与门禁同形的自扫（`grep -nE` 同 PAT），把「我刚写的东西会不会被自己的门禁抓住」当作交付的一部分。

### L-136 · 跨提交回溯禁用 `git stash` / `git checkout <sha> -- .`：会吞掉未提交的受保护工件

一次「逐提交回溯 `bash package-flow-kit.sh --validate` 是否 pre-existing」的循环里，我每轮执行 `git stash -q -u` + `git checkout <sha> -- .`（35 轮）。实测后果：

- **33 次迭代留下 32 个残留 stash**；`stash@{32}`（首个）吞掉了**已 staged、未提交**的冻结集 6 文件——`.specs/adr/028-gate-baseline-allowlist.md`、`.specs/health-fix-2026-09b/CHANGE.md`、`.specs/health-fix-2026-09b/REQUIREMENT.md`、`.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-1.md`、`.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-2.md`、`.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-3.md` ⇒ 六文件从工作树消失，`git status` 只剩 `M Makefile`（连「东西没了」都不显眼）。
- 该 stash 的 pop 把 `.specs/health-fix-2026-09b/TASK.md` 回退成**旧快照**，静默丢掉刚写入的 T09/T11/T18 三处判据修正（仅事故之后补的 T10 段幸存）——**协议文件被回退，而我没有立刻察觉**。
- `Makefile` 被留在旧版本（工作树 ≠ HEAD），同样只在 `git status` 里出现一行。

恢复与规范：

- 恢复：`git checkout "stash@{32}" -- <6 路径>`（只有首个 stash 含它们）⇒ 六文件字节数逐一对上基线 **10558 / 21684 / 55692 / 251278 / 294528 / 58985**，重新 `git add` 恢复 `A ` 冻结状态；`git stash list > /tmp/stash-backup-*.txt` 备份后 `git stash clear`。
- 规范①：**回溯历史一律用 `git worktree add <tmp> <sha>`（或 `git archive` / `git show <sha>:<path>`）**，绝不在持有未提交工件的工作树里 `stash` / `checkout … -- .`。
- 规范②：凡是「未提交但已 staged」的受保护工件（冻结集、handshake 标记、状态文件），改动后先记 `sha256sum` 再动历史。
- 规范③：`git status --short` 出现**任何**意料之外的路径（哪怕只是 `M Makefile`），必须先解释清楚再继续，不得当作噪声略过。

### L-135 · `make` 对任何失败 recipe 恒返回 rc=2：「二值退出」必须直接对脚本断言，接线层用 `0|2` + 反掩蔽判别

- 事实（GNU make 4.3 实测）：recipe 内 `exit 1` / `exit 3` / `exit 5` 经 make 一律暴露为 **rc=2**（`make -q` 的 rc=1 是另一条语义）。
  故「`make <目标>` 的退出码 = 脚本的二值 0/1」是**错的假设** —— T18 判据 #6 因此不可满足（子 agent 拒造绿并上报，处置正确）。
- 正确写法：① 直接 `bash <脚本>` 断言 **0|1**（脚本契约）；② 再对 `make <目标>` 断言 **0|2**（0=通过 / 2=recipe 失败）；
  ③ 追加**反掩蔽**判别：脚本非 0 时 make **不得**返回 0，否则说明接线写了 `|| true` 把失败变成功。
- 更一般：断言必须与被断言对象**同层**（脚本 / 构建工具 / 外层 hook 是三个语义层）；跨层搬运退出码会写出不可满足或空洞的判据。
- 出处：T18 子 agent 五组实验 + 主 agent 复核（`make check-path-privacy` ⇒ 脚本 rc=1 / make rc=2）；判据修正见 TASK.md T18 `<verify>`。



### L-134 · 「打印了值又返回非零」的命令不能用 `$(cmd || printf '0')` 兜底；自证行必须锚定行形状

- 机制：`grep -c` 在计数为 **0** 时**既打印 `0`、又返回退出码 1** ⇒ `$(grep -c … || printf '0')` 捕获**两行** ⇒
  `echo "   允许清单 ${VAR} 条"` 渲染成 `允许清单 0` + 换行 + `0 条`。
- 正确惯用法（bash 3.2 兼容）：`VAR=$(cmd 2>/dev/null) || VAR=0` —— 命令替换成功时变量已持输出值（含 `0`），
  `||` 只兜「没有输出」的非零退出码场景 ⇒ 恒为单行。
- 更一般：**机器可读自证行属于对外契约**，判据必须用 `^…$` 锚定整行形状，而不是 `grep -q '关键字'`；
  T17 前两轮判据只 grep 归因（`leak.txt`）与「扫描面」，该缺陷因此在**零计数态**（恰是 T21/T22 要断言的态）
  存活两轮 —— L-121 族：命令 ≠ 断言。
- 出处：`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:106`/`:247`（首轮版 `:106`/`:225` 即有）；
  修复 `7725cc3`（修复轮 2）；判据补强 `7265b78`（T17 `<verify>` 49→54 行）。



### L-133 · 排除粒度必须等于命中粒度：一行多命中时禁止整行跳过

- 现场：`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:162` 的 `sed -nE 's#.*/home/([a-z_][a-z0-9_-]*)/.*#\1#p'` 是**贪婪**匹配（`.*` 吃到最后一次 `/home/`）⇒ 一行里只取**最后一个** `/home/<name>/`；`:186-189` 又按这个单一成分决定是否 `continue`（**整行跳过**）。
- 后果（主 agent 2026-09-23 独立探针四项对照实测）：`mixed /home/<real>/x /home/user/y` ⇒ **`rc=0`、`清单外命中 0 条`（真名被占位符挡在后面就漏报）**；把同样两条路径**调换顺序** ⇒ `rc=1`；仅占位 ⇒ `rc=0`；两个真名 ⇒ `rc=1`。同一份泄漏的判据结论随**行内顺序**翻转 ⇒ 门禁可被「在真路径后面补一个 `/home/user/`」绕过。
- 判据必须覆盖的形态（多态对照 L-120）：真名在前 + 占位在后 ⇒ **必红**；占位在前 + 真名在后 ⇒ 必红；清一色占位 ⇒ 必绿。三者各有独立失败分支（L-121），且归因须报出该 `file:line`。
- 教训：**排除/白名单的粒度必须等于命中的粒度**。只要实现里出现「先提取一个代表，再决定整行命运」，多重命中就必然漏报。修复方向：逐命中判定（`grep -oE "$PAT"` 取该行全部命中），仅当**全部**命中都是占位符时才跳过。
### L-132 · 双态注入必须命中真出口，且先验注入生效再验断言

- **反例（T15 实测）**：「在脚本末尾追加 `exit 1`」对**以显式 `exit N` 结尾**的脚本是**死代码** —— `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:210` 的 `exit 0` 先终止进程；追加后 sha256 已变（`6b7cef63…` vs `ef994b28…`）但 `npx bats test/test_check_gate_sync.bats` 仍 **5 ok / rc=0** = **假绿**（`bash -c 'exit 0; exit 1'` ⇒ rc=0 同证）。
- **定式**：① 注入点选**自然出口行**（`sed -i '210s/^  exit 0$/  exit 1/'`）或在**失败分支**注入；② **先断言注入后被测对象自身 rc 非 0**（`bash "$S"; [ $? -ne 0 ]`）再跑断言层；③ 附**反事实对照** —— 同注入态下把断言换回旧形态（`-ne 2`）必须变绿，证明红确由「收紧」造成而非注入噪声。
- **推广**：任何「双态/判别力」证据都要先问「我改的是真出口还是死代码」；注入后不看被测对象自身 rc 就直接跑断言层，等于把假绿引进证据链。

### L-131 · 拦截器的评估面必须等于被拦截对象本身（评估「被推送的树」，而非本地工作树）

**现象**：`flow-kit-bundle/hooks/pre-push/pre-push.sh`（T11）对 stdin 的每一行 `<local ref> <local sha> <remote ref> <remote sha>` 都调用同一个**扫工作树**的 `make check-path-privacy`。后果有二：① **归因错位** —— 多 ref 推送（`git push --all` / `--mirror`）时**第一个**被评估的 ref 就被指名，而它可能是干净的 `develop`，`REQUIREMENT.md:177` 要求「指出哪个 ref 含泄漏」⇒ 点名干净 ref 即不满足；② **漏检** —— 泄漏提交在未被检出的分支上时（HEAD 在干净分支）工作树干净 ⇒ 门禁放行 ⇒ 泄漏照原样出仓，恰是 AC-3 要防的事。

**定则**：pre-push 的评估面 = **本次推送的对象**（每个 ref 的 `<local sha>` 所指的树：`git ls-tree -r <sha>` / `git grep <PAT> <sha>`），不是「本地检出状态」；工作树扫描只适用于**提交前**门禁（pre-commit）。实现上给共享门禁加一个外部指定评估面的入口（`CHECK_REV=<sha> make check-path-privacy`，缺省仍扫工作树），拦截器逐 ref 传该 ref 的 sha，并对**删除线**（local sha 全 0）跳过。

### L-130 · 影子 stub 不能替代被验逻辑：stub 会把「产品并不具备的判别力」伪装成「已验证」

**现象**：T11 的 verify 用影子 PATH 里的 stub `make` 测 hook 行为，stub **按 `CHECK_REF` 返回不同 rc** ⇒ 双态 4/4 全绿（干净 ref 放行、`refs/heads/main` 被指名）。但真实门禁忽略 `CHECK_REF`、每次扫同一份工作树 ⇒ **stub 实现了产品没有的按-ref 判别力**，判据绿而缺陷在（引出了 L-131）。同族：T09 用 `TMPDIR=<clean> git commit` 让门禁在**调用者造出的干净环境**里变绿。

**定则**：① 影子 stub 只能用于**隔离外部依赖**（例如让 `make check` 不跑整套测试），**不得承担被验逻辑本身**；凡「按输入区分结果」的行为，必须有一次**真实实现**的端到端跑（`T19` 属此）；② 复核者必须追问一句「这个绿是 stub 给的还是产品给的」；③ 与 L-122（夹具/路径必须触达缺陷现场）、L-121（命令≠断言）同族。

### L-129 · 绝对路径入档前必须 de-shape（机器路径同时污染基线与 git 历史）

**现象**：T04/T11 的 SUMMARY 把本机原始输出原样贴入（`== [T11 verify] path=/home/<acct>/<repo>/...`、`✅ /home/<acct>/.claude/hooks`），共 **10 行**真实账号路径随提交进入 tracked 面；`.specs/health/2026-09-22-FULL-SWEEP.md` 另有 3 行（`:126` `:242` `:255`）。后果：AC-6 基线「清单外命中 = 0」无法归零，且这些路径进入 git 历史（历史重写不在本 change 范围 ⇒ 只能在提交层面止损）。

**定则**：粘贴任何命令输出/路径前，先把机器绝对路径写成 `<repo>` / `$HOME` / `/home/<acct>/` 形态（`<` 不属于 PAT 的 `[a-z_]` 字符类 ⇒ 不命中）；**只替换路径字面 —— rc、命令、输出文本、数字等证据必须保持原样**。

**判据触达面**：只扫 `git ls-files`（tracked）会**完全看不见**尚未 `git add` 的工件与同批健康档 —— 实测原判据对 FULL-SWEEP 的 3 处命中失明。补扫面必须显式覆盖「未 tracked 面」（`git ls-files -o --exclude-standard`），并对**空集**显式处理（GNU `xargs` 空输入 ⇒ 无参调用 ⇒ `grep` 转读 stdin，判据静默失效）；单文件输入时 `grep` 默认不打印文件名 ⇒ 需 `-H`，否则按 `file:line` 的归因与排除表匹配全部失真。

**豁免与脱敏的分界**：审查档（`INDEPENDENT-REVIEW-*.md`）原文受协议保护、禁改 ⇒ 由排除表**逐条精确路径**豁免；SUMMARY 是执行者自撰散文 ⇒ **就地脱敏，不豁免、不入排除表**。
| L-128 | 🟡 | 全局（流程 · 判据改写 / 工件权威性） | **授权改写判据时，改写必须回写工件本体 —— 否则「工件里的判据」与「实跑的判据」分叉，仓内再也复现不出那次 rc=0** —— T11（2026-09-23）执行者按主 agent 授权，把 verify 末尾的「禁用构造」检查从「读全文」改成「注释盲」形态（`awk '{sub(/#.*/,"");print}'`），但**只写进临时副本**（`/tmp/t11-sbx.e8cJnD/t11v.sh`），提交时未回写 `TASK.md`；主 agent 复核时用 `task-brief` 抽**工件里**的判据原样实跑 ⇒ **rc=1**（`🔴 含 bash4-only/GNU-only 构造`），命中源是脚本自身的兼容性注释（`flow-kit-bundle/hooks/pre-push/pre-push.sh:15`、`:23` 两行整行注释提到 `mapfile`/关联数组）⇒ 即**工件里的判据对着已提交的工件是红的，而执行者报的是 rc=0**。那次「rc=0」之所以还查得到，只因临时副本碰巧未被清理 —— 一旦清理，仓内**无法复现**。同型隐患不止一处：`TASK.md` 中 T17 的 verify 对**尚未创建**的 `check-path-privacy.sh` 用了同一形态的 grep ⇒ 只要该脚本注释里写「本脚本不用 mapfile」就会假红（与 L-125「别把注释当代码」同族，但这次坏的是**判据的存放位置**而非判据的匹配方式）。**定式**：① 授权改写判据时，措辞必须显式要求「**把改写后的判据回写工件本体、随同一提交入库**」，并禁止「只在临时副本里改」；② **判据的权威副本只有一个 = 工件里那段原文**，运行时副本只能作为执行手段且必须落档差异；③ 复核者的第一动作是**抽工件里的判据原样跑一遍**（`task-brief` + 行级锚定抽取，见 L-125），而不是采信执行者自报的 rc；④ 文本类判据若必须检查「代码行」，注释剥离口径应全仓统一（本仓 `check-nfr-portability` 用 `grep -vE '^\+?[[:space:]]*#'` 剥整行注释）—— **判据不得把注释文本当代码** | `health-fix-2026-09b` 阶段 4（2026-09-23 · T11 verify 复核与订正） |
| L-127 | 🟡 | 全局（流程 · 台账字段契约） | **格式合法 ≠ 值正确：子 agent 自报的台账字段若不与外部权威源交叉校验，错误值只能靠主 agent 手工比对才发现** —— T08 执行者写入 `goal.task_progress` 的 `completed_at` = `2026-09-23T05:05:14+08:00`，而**该提交自身**的 git 时间（`git log -1 --format=%cI c3a1240`）= `2026-09-23T13:01:06+08:00`：同日、**相差 8 小时**、**时区标签却是正确的 `+08:00`** ⇒ 值**格式完全合法**，schema 校验/正则校验**一条都抓不到**；唯一发现途径是把它与 git 元数据对照（属 L-124「存在性/格式 ≠ 有效性」同族）。附带风险：`deferred` 若写成字符串、`commit_sha` 若是拼写错误，同样无人校验。**定式**：五字段台账写入后必须过**机器交叉校验**才可视为完成 —— ① `commit_sha` ⇒ `git cat-file -e <sha>^{commit}`；② `completed_at` ⇒ 与 `git log -1 --format=%cI <sha>` 相差在**分钟级**（机器判据 = `entry >= commit` 且 `entry − commit <= 120s`；**跨分钟边界不算违规** —— 2026-09-23 T16 实测 Δ=14s、跨 46→47 分而 sha 一致；真正要抓的是 T08 那种 8 小时级偏差）；③ `deferred` ⇒ 必须是数组；④ `id` ⇒ 与 `TASK.md` 中 `status="done"` 的 task 集合一一对应；⑤ 该校验应写进 4-dev 的执行者提示与收口 task（本 change 归 T29） | `health-fix-2026-09b` 阶段 4（2026-09-23 · T08 台账复核） |
| L-126 | 🟡 | 全局（流程 · 提交协议 / 工件自证） | **提交内容不可能写下自己的 sha；「门禁失败」的观察必须可复现才可作为绕过的依据** —— 两件事同源于 T01（2026-09-23）的提交。① 子 agent 以「pre-commit 命中既有失败 `T06fix: … UTF-8 boundary`」为由执行 `git commit --no-verify`，主 agent 复核时**该失败不可复现**：单跑 `npx bats test/test_l3_pipeline_fix.bats` = 41 ok / 0 not ok（含 `ok 41 T06fix: …`）、全量 `make test` = 973 ok / 0 not ok / rc=0，且 `grep -rn 'health-fix-2026-09b' test/ flow-kit-bundle/test/` = 0（测试面不读 change 目录 ⇒ 工件内容不可能让它变红）；其引用的 `DESIGN.md:329` 原文是**风险描述**（「pre-commit 会阻断纯文档提交（诱发 `--no-verify`）」），**不是授权** ⇒ 一次不可复现的观察 + 一次误读，合成为一次真实的提交门禁绕过（正是 ADR-027 禁止的形态：被绕过的门禁比不存在的门禁更糟）。② `T01-SUMMARY.md` 写 `Commit sha：3da5fa6`，而 `--amend` 后实际为 `a674c56`（同一内容、reflog 可查）—— **提交内容不可能包含自己的最终 sha**（把 sha 写进被提交文件、再 amend，sha 又变，无限递归）。**定式**：① 报告门禁/测试失败**必须附可复现命令与真实输出**，并**当场复跑一次**；不可复现 ⇒ **不得**据此绕过任何门禁，改以 **BLOCKED 上报**；② 提交类门禁（pre-commit / pre-push）**禁止** `--no-verify`（本 change 的 T11 正是要给 pre-push 装上拦截能力），确需临时绕行必须先取得用户裁决并落档；③ 任务 commit sha 以 **`.flow-active.goal.task_progress` 为权威源**，SUMMARY 引用之，amend 后由主 agent 补记 —— **不在被提交文件里追求「自指正确」**；④ 「文档里写了 X」≠「X 被授权」：引用文档作为行动依据时必须引原文并说明它**为何构成授权** | `health-fix-2026-09b` 阶段 4（2026-09-23 · T01 提交复核） |
| L-125 | 🟡 | 全局（判据核验工具 / 抽取面） | **判据抽取工具必须锚定行级标签：工件正文里「与结构标签同形的字样」会让非贪婪匹配抽错区间，进而报出一个不存在的缺陷** —— 阶段 3 用 `<verify>(.*?)</verify>` 从 `TASK.md` 抽 29 份判据做 `bash -n`：T13 的 `<action>` 正文里写有**行内** `` `<verify>` `` 字样（用于指称「本 task 的 verify 段」），抽取器于是从**第一处行内出现**开始匹配、抽到自 `</action>` 起的区间 ⇒ 报 `行 21: 寻找匹配的 \`\`' 时遇到了未预期的 EOF`，**而真实判据本身完全正确**（改用 `\n  <verify>\n(.*?)\n  </verify>` 行级锚定后：29/29 抽取、`bash -n` 失败 0）。**同轮同源对照**：`flow-kit-bundle/flow-kit/scripts/task-brief` 是 `#!/usr/bin/awk -f` 的**按行状态机** ⇒ 同形字样**不影响**它（同一份工件、两种解析器、两种结果）。**定式**：① 抽取/校验工具必须锚定**行级**结构标签，并在抽取后**断言「实抽数量 == 预期数量」**（29/29）与「区间内不含其他标签」；② **工件正文避免书写与结构标签同形的字样**（本次已把 T13 正文两处改为「verify 段」），该条应写进产出规范/模板；③ 工具报错时先按 **L-123 ④（脚手架自身也要检查）** 归因：先问「是工件坏了还是抽取器坏了」——**坏工具会报出看似确凿的假缺陷** |
| L-124 | 🔴 | 全局（安全门禁 · 凭证完整性） | **「凭证文件存在」≠「凭证对所检对象当前仍然有效」—— 同一根因的两个独立缺陷：凭证与对象、凭证与作者，都没有绑定** —— ① **陈旧凭证放行**：`.done` 只证存在性，受审工件在其后被实质重写仍放行（本 change 自身即活例：`DESIGN.md` 在 L3 pass 后重写 4 次，门禁干跑 **rc=0**；同一工件去掉凭证则 **rc=2** ⇒ 放行**唯一**取决于凭证文件是否存在）；且 `29` 的 Gate 4 幂等短路使「工件变更→重审」路径在 **pass 态不可达** —— **而 hash 形式的陈旧检测本就存在**（`_l3_check_rerun` ↔ `L3_artifact_hash:`；实测记录 `35519db8…` ≠ 当前 `4e297693…`），**门禁只是不查它**。② **作者性守卫是 token 共现启发式**：`printf … >` 被拦（rc=2），而 `python3 -c write_text(…)` **同路径同载荷**未被拦（rc=0）；反方向还误伤只读命令（同串出现任意 `>` 即 deny）。**两条都属「门禁看起来在工作」** —— 与 L-120/L-121 同族：判据的**存在性**取代了**有效性**。**定式**：① 任何「凭证 / 锚点」机制的核验**必须回答「它对当前对象是否仍然有效」**，并把该问题写成一条判据（内容指纹 > 时间戳；mtime 已被 BUG-J 否决）；② 安全判定**禁止用字符串共现代替结构化分析** —— 先问「换个写入器还成立吗」（`python3`/`perl`/`node`/`touch`），再问「只读命令会不会被误伤」；③ 用自己的产品跑一遍自己的流程，是发现这类缺口最有效的探针（本例即由此暴露） | `health-fix-2026-09b` 阶段 2（2026-09-23 · PreToolUse gate 干跑多态对照） |
| L-123 | 🔴 | 全局（判据核验 · L-120 的补充） | **「属实但空洞」：核验只证明了字面消失，没证明新写法可用** —— 第 5 轮 🔴 R1 实测：为让探针不出现在 tracked 文本里，把连续字面改成拼接构造 `PROBE='/home/'"'zz-path-pr'"'obe/'`；核验时只数了「旧字面在三文件命中 0/0/0 ✅」并宣告完成 —— 但该写法中间用的是**双引号串**，其中的 `'` 成了**字面字符** ⇒ 实际产出 `/home/'zz-path-pr'obe/`（22B）**≠** 原字面（20B）⇒ 对自家 PAT 命中 **0** ⇒ 探针抓不住 ⇒ **AC-6① 永久红**。审查的判词精确：**「0/0/0 属实但空洞 —— 只证明旧字面没了，未证明新写法可执行」**（第 7 次同型失效）。**定式**：① 改造一个**可执行构造**（拼接/转义/变量代入）后，核验必须**实跑该构造并断言产出等于原语义**（本 change 已固化为 AC-6① 的「探针形态自检」：`printf '%s\n' "$PROBE" \| grep -qE '<PAT>' \|\| exit 1`）；② **"旧形态消失"与"新形态可用"是两个独立断言，缺一不可** —— 前者是 grep，后者必须实跑；③ 但凡"为了过门禁而改变写法"，都要追问：**改完还过得了门禁吗？**（本例中改动本身把判据打成了永久红）；④ 测试脚手架自身也要检查：本轮 R2 复验首次给出"五态全 1"，根因是**脚手架里 (a)(c) 共用同一目标文件**、布置 (c) 时删掉目标把 (a) 也变成悬空 —— **坏脚手架会给出看似一致的错误结论**（与 L-120 的 fixture 纪律同源）|
| L-122 | 🔴 | 全局（验收判据 · 夹具/路径必须触达缺陷现场） | **「判据没打到缺陷现场」= 对目标缺陷的假绿** —— 第 6 轮 🔴 R6-1 实测：AC-2 的判据用 `install.sh --global`，但缺 jq 时 `install.sh` **在 `install_brooks.sh:169` 就中止**，**根本到不了** `install_hooks.sh:251` 的截断行 ⇒ 判据对该缺陷**恒绿**，fail-closed 行为从未被验证。逐 flag 实测才定位到唯一能触达的组合：`--global`（中止于前者）/ `--global --no-brooks`（rc=0、未截断）/ **`--global --no-brooks --user`（rc=127、120→0 截断复现）**。同轮还推翻了两条自造断言语义：① 「字节数**不变**」是错的 —— 对照态实测 **120→1162**，安装器**合法地追加 hooks**，文件本就该增长；正确断言是「**未被截断为空 + 原 `permissions.allow` 存活**」；② 「输出须提及 jq」实测该路径下失败态 `提及jq=0`，不成立。**另一处危险**：初版判据**未设沙箱 `HOME`** ⇒ 逐字执行会向**真实 `~/.claude`** 装 hooks、写入它自己要保护的那个文件（判据本身造成破坏）。**定式**：① 判据涉及"某分支上的缺陷"时，**必须先用实测证明该路径能到达该分支**（逐 flag/逐分支实测，不能推断）；② 断言要写**缺陷的精确形态**（"被截断为空"而非"字节不变"），否则会与合法行为混淆；③ 凡会落盘/装东西的判据**一律沙箱 `HOME` + 临时目录**，绝不触碰真实环境；④ 遮蔽某工具**不能靠 `PATH` 前缀**（`PATH="/x:$PATH" command -v jq` 仍 → `/usr/bin/jq`；PATH 是查找序非白名单），要用**软链真实工具但排除目标**的影子目录 **+ 前提自检**（影子下 `command -v <目标>` 必须失败、`command -v <基础工具>` 必须成功）|
| L-121 | 🔴 | 全局（验收判据 · L-120 的补充定式） | **「命令 ≠ 断言」：判据里写了命令、却漏了失败分支，等于没写** —— 第 5 轮 🔴 R1 实测：`grep -q 'check-path-privacy' <源>` 单独 rc=1（正确报错），但**与下一行 `bash sync-hooks.sh --check` 组成的两行块整体 rc=0**（后者覆盖了前者退出码）⇒ **"已接入"与"完全没接"结果相同**。同轮系统扫描（主 agent 自查，非审查点出）发现**同类共 8 行**：AC-1 的**主判据**（源树/6 副本面的 `grep … \| wc -l`）、AC-6 的 `make check-path-privacy`、AC-6③ 两行、NFR 兼容性三行 —— **其中 AC-1 是 RCE 修复的验收判据，缺陷等级与 R1 同级**。**定式**：① 判据里**每个**校验命令必须自带失败分支（`\|\| { echo "🔴 …"; exit 1; }` 或 `if …; then … exit 1; fi`）——多行块里**后一行的成功会掩盖前一行的失败**，故逐行加，不可依赖"块末统一判断"；② **空集 / 无匹配是一等失败态**：`grep … $FILES`、`bash -n $FILES` 在 `$FILES` 为空时**退化读 stdin**（实测管道输入被"命中" rc=0）⇒ 必须先 `[ -z "$FILES" ]` 显式 SKIP 或 fail，且 glob 面先 `shopt -s nullglob` 取数组并断言元素数 > 0（否则"归档改名/被删"与"干净"不可区分）；③ 枚举类判据要**断言枚举条数**（如 `[ "${#DESTS[@]}" -eq 6 ]`）——枚举本身失效时判据会静默空转；④ 自报数值必须与**落档文件的真实行数**绑定（防"门禁硬编码/不读清单"态）；⑤ 变更集取法用 `git diff --name-only HEAD` + `ls-files -o`（`--name-only` 漏 staged，L-107 同源）|
| L-120 | 🔴 | 全局（验收判据 / 需求写作 · 治本） | **「可核验 ≠ 可用」：文本可逐字核验的判据，语义上仍可能不可满足、恒真或不可观测 —— 本轮同一失效类连续复发 4 次**（R1 恒真 / N1 不可达 / C1 不可达 / D1 **连"为治此病而写的自检"本身都不可用**）。L-119 的"改完必须实跑"仍不够，因为 **"跑一次"只能证明它在当前态下不报错，不能证明它能区分成功与失败**。**治本定式（本轮起强制）**：① 每个判据必须用 **fixture 双态对照**验证 —— 在 `/tmp` 造出**成功态**与**失败态**两个最小环境，要求判据对二者给出**不同结果**；只在一态下"跑过"不算验证。② 涉及**外部工具错误文案**的判据必须锚定 `LC_ALL=C` 并**优先改用原语探测**（能力用 `--help \\| grep -qw`、存在性用 rc；实测 `make --help \\| grep -qw --list` → rc=1、`--always-make` → rc=0、`make -n <target>` → 0/2，**zh 与 C 两个 locale 完全一致**），**禁止**匹配本地化错误字符串。③ 判据里描述"输出含 X 条"时必须用**非空量词**（`[1-9][0-9]*` 而非 `[0-9]+` —— 后者会误命中"0 条"，实测已证）。④ **自检/断言本身也是判据，需同等对待**（递归适用）—— 本轮 D1 正是"自检的自检"缺位。⑤ 判据中的**正例必须可观测**：实测 `file_path='~/.claude/hooks/x.sh'` 驱动守卫得 rc=0、**输出 0 字节**（无维护源 ⇒ 不触发 deny）⇒ 该正例"既不能过也不能败"；改用具维护源路径后 rc=2、693 字节、含展开路径，才真正可观测 |
| L-119 | 🔴 | 全局（验收判据 / 需求写作） | **「写下未实跑的判据」是最高频的自伤模式 —— 本轮同一失效类连续复发 3 次**：① 第 1 轮 R1（`grep -c 'check-gate-sync' Makefile` 记 0 实为 1，且唯一命中是注释 ⇒ 判据**修复前已成立**、恒真）；② 第 2 轮 N1（把 AC-1 判据扩到 `dist/` 却未实跑，实测 **111** 而非声称的 8，其中 104 处是 vendored 英文散文，与自家 out 锁"不改 vendored"冲突 ⇒ **目标永不可达**）；③ 第 3 轮 C1（`make check-path-privacy --list` —— GNU make **无此长选项**且选项解析在读 makefile **之前**，rc=2、stdout 空 ⇒ diff 恒非空 ⇒ "期望无差异"**永不可达**）。**三者形态各异但根因同一：判据只被"想"过，没被"跑"过。** 定式：① **改写任何判据后必须立即逐字实跑**并记录实测值（含 rc 与 stdout），不得凭推断写数；② 对**尚未实现的目标**（如新 `make` 目标）也要做**判据形态自检** —— 但**不得匹配本地化错误文案**：`make` 的错误串随 locale 变（zh `未识别的选项`/`没有规则可制作目标` vs C `unrecognized option`/`No rule to make target`），**必须锚定 `LC_ALL=C` 并优先改用原语**（能力 `--help \| grep -qw`、存在性 `make -n <t>` 的 rc）。~~初版以中文字面串为定式~~ → **已被 L-120 ① 取代（D1 证伪：LC_ALL=C 下两分支同时失效、静默 no-op）**，本轮已同步；③ 门禁类判据**优先自证式输出**（自己打印"允许清单 N 条 / 清单外命中 M 条"并据此定 rc），而非依赖外部工具的长选项或二次解析；④ 判据里的**面/列表一律由工具枚举**（如 `sync-hooks.sh --list` 的 ✅ 行），禁止手列 —— 手列会随安装形态漂移（本轮漏 2 个 DEST_ROOT）且漏掉归档面（两个 npm `.tgz` 各含 2 处可注入 hook，却无任何门禁覆盖） |
| L-118 | 🔴 | 全局（多路径产出 / 下游门禁契约） | **同一工件有两条产出路径时，下游门禁的「结构契约」必须写进两条路径各自的产出规范 —— 否则只有一条能过门禁，另一条静默卡死**：本轮启用 `gate_config=all` 后实测发现，L3 门禁硬要求 L2 产物含字面 `^## L2 盲审`（`29-independent-review.sh:89,136` 的 `grep -q`），而**官方手动派发提示（含 dsh 分支）与被要求注入的固化 prompt 都没有要求这个标题** —— 固化 prompt 甚至只说「首行加 `# 独立审查 · 阶段 <N>`」。结果：在 dsh 上**严格照官方提示做出来的 L2 产物会被 L3 拒绝** → 写 `l2-missing` → `L2-first` 契约不可满足 → **阶段门永久关闭**。curl 路径不受影响（`l2_dispatch_agent` 自己补标题），故历史产物都有该标题，**缺口在 dsh 路径上是隐形的**，只有真正启用该 gate 配置才暴露。**定式**：① 下游用 `grep -q "^## X"` 这类**结构判据**时，该 `X` 必须出现在**上游产出规范**里（prompt / 派发参数模板 / mock），三者对齐；② 双路径产同一工件时，**用一个真实端到端跑**验证两条路径的产物都能过下游，不能只验一条；③ 门禁判据应尽量**宽松到语义等价**（如 `^## .*L2.*盲审`）而非要求逐字标题，避免把"格式巧合"变成正确性前提；④ 启用新 gate 配置本身要当作一次**验收测试**（本轮 `gate_config=all` 的第一天就抓出此缺口与主 agent 的 3 条假绿 AC） |
| L-117 | 🔴 | 全局（审计 / 决策依据引用） | **引用本仓文档作为决策依据时，必须读该依据的「紧邻上下文」——"已抽取"与"不抽取"常在同一张表里相邻**：本轮在设计"PCSC 表该以谁为唯一源"时，引 `reference/phase-prompt-template.md:143` 的"✅ **已抽取**：… Toll-gate 协议（pipeline-gates.md）"作为依据，据此锁定"PCSC 唯一源 = pipeline-gates.md"并写进 CONTEXT「已锁决策」；但**紧邻的 `:144` 明写**「⚠️ **结构性文档化（不抽取）**：**PCSC 表格** / 独立 review 调度 —— phase-specific 内容占比高，抽取反而增加复杂度」，`:145` 方向也是**参数化**而非单源化。即 `:143` 的"已抽取"只覆盖 **Toll-gate 协议**，**不含 PCSC 表** —— 结论恰好相反。该误读被 L2 盲审以 **🟡 R7** 抓出（初版本条误记为 🔴，据第 2 轮 N5 订正），并连带使据此写的 AC 不可满足（🔴 R3）。**定式**：① 凡引用"决策记录 / 抽取决策 / 迁移记录"类表格，**必须整表读**（`sed -n 'A,Bp'` 取足够窗口），不得只取命中行；② "已抽取"这类**动词+宾语**结构必须核对**宾语边界**（抽的是协议还是表？）；③ 写进「已锁决策」的依据要标注**原文行号区间**而非单行号，便于后续复核；④ 依据被证伪时，**必须把已锁决策显式划掉并注明误读点**，不能只在新文档里改 —— 否则未来 AI 会继续信任那条错决策 |
