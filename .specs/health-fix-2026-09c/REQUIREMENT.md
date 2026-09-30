# REQUIREMENT: 收口 13 个 🔴 —— 测试封闭性 / 隐私门禁真实生效 / mock 契约对齐 / 门禁 fail-closed / 载体单一权威

- **Change ID**: `health-fix-2026-09c`
- **关联**: `@.specs/health-fix-2026-09c/CHANGE.md`、`@.specs/CONTEXT.md`、`@.specs/health/2026-09-29-HEALTH.md`

---

## 用户故事

- **US-1**：作为本仓维护者，我想让测试套件在并发 `make check` 下不再改写 tracked 源文件，以便巡检/门禁/开发可以并行进行而不互相污染（C1）。
- **US-2**：作为仓库所有者，我想让隐私门禁拦住真实形态的账号泄漏（无尾斜杠裸路径）并对依赖缺失 fail-closed，以便 `rc=0` 重新成为可信证据（C2/C12）。
- **US-3**：作为仓库所有者，我想让 tracked 面与全部 git 历史（含孤儿 `main`）不再含真实账号名，以便任何 clone 都拿不到该信息（C3）。
- **US-4**：作为门禁使用者，我想让 `check-gate-sync` 比对键值对集合而非名字集合、且其 bats 侧真相来自生产实现而非 mock，以便契约值漂移会转红而不是被盖章为「一致」（C5/C11）。
- **US-5**：作为 hook 维护者，我想让 L2/L3 断言走行为而非源码文本、L3 积压失败会真实告警，以便重构不被误红、失效不被误绿（C4/C6）。
- **US-6**：作为 CI-less 环境的开发者，我想让 `make test` 只跑一次、lint 按 rc 判红、JS 单测与递归同步进入 `make check`，以便一次 `make check` 覆盖面完整且可负担（C7/C10/C14-d/e）。
- **US-7**：作为 flow-kit 用户，我想让阶段内容有单一权威载体且覆盖率不足时门禁非零退出，以便从任一路径装载得到同一套强制条款（C13/C14-f）。

---

## 验收准则（AC）

> 编号与 CHANGE「What」分层对应；每条 AC 都有**一条命令**或一次受控操作可验证。反向控制 = 「修好后必须能转红」的负对照。

### AC-1 · C1 测试沙箱化（并发安全）

- **Given** `test/test_check_gate_sync.bats` 三个 T02 用例已照搬同文件 F6 范式（复制真实生产件进 `mktemp -d` 夹具），且 `flow-kit-bundle/test/` 镜像逐字节同步
- **When** 在同一 worktree 上**同时**启动 2 个 `make check`
- **Then** 两者结束后 `git status --porcelain` 中**不含任何源文件修改**（特别是 `flow-kit-bundle/skills/flow/SKILL.md`），且不存在 `$SKILL.t02-bak` 残留
- **验证方式**: `bash -c 'make check & p1=$!; make check & p2=$!; wait $p1; r1=$?; wait $p2; r2=$?; exit $((r1+r2))'` → rc=0（双跑各自成功，非仅「不脏」）；随后 `git status --porcelain | grep -v '^?? \.specs/' | wc -l` → 0

### AC-2 · C1 中断回归网（teardown 失效必须可见）

- **Given** 沙箱化后的测试（F6 范式：夹具在 `mktemp -d`，不动 tracked 文件）
- **When** 构造「teardown 前中断」场景（改写夹具后 `kill` 测试进程），随后再跑一次该测试文件
- **Then** 三段独立判据：① 被中断跑 rc≠0（中断可见，无 `|| true` 吞错）；② 中断后 `git diff --stat`（tracked 面）为空——沙箱化本身已保证 tracked 不受影响，此断言防回归；③ 中断跑遗留的 `mktemp -d` 夹具路径在测试输出中**可见**（打印夹具路径，不静默泄漏）
- **验证方式**: 新增 bats 用例：注入 `kill` → 断言 rc≠0；`git diff --stat | wc -l` = 0；输出含夹具路径行

### AC-3 · C2 隐私正则收紧（真实形态必须命中）

- **Given** `check-path-privacy.sh` 的 `PAT` 已放宽到路径段边界（不再强制尾斜杠），且 `PLACEHOLDER_NAMES` 白名单与 6 条 `SELF_EXCLUDE` 保留
- **When** 用裸 `/home/<realname>`（无尾斜杠）探针与 `` `/home/<realname>` ``（反引号包裹）探针测试
- **Then** 两种探针均**命中**且 rc≠0；同时 `/home/<acct>/`、`/home/<user>` 占位符**不**误伤（负对照通过）
- **验证方式**: `test/test_path_privacy_gate.bats` 新增用例（含修正 `:35` 探针自带尾斜杠问题）；门禁 rc 断言

### AC-4 · C3 tracked 面脱敏（依赖 AC-3 完成后执行）

- **Given** AC-3 已生效（新泄漏会被拦）
- **When** 把 6 个 tracked 文件的 30 行真名替换为 `/home/<acct>` 定式并提交
- **Then** `git grep -nE '/home/<realname>' -- .`（tracked 面）= **0 行**；`make check-path-privacy` rc=0
- **验证方式**: `git grep -cE '/home/<realname>' | wc -l` → 0（脱敏后的正则实测）

### AC-5 · C3 历史重写（含孤儿 main · 不可逆操作带备份判据）

- **Given** tracked 面已清零（AC-4）；已核实远程形态：origin（URL 含所有者真名，**真值不入任何 tracked 文件**——步骤 0：`git remote get-url origin` 捕获后存仓外临时文件 `../push-url-pre-scrub.tmp`），**同时含 `develop` 与 `main` 两分支**（2026-09-29 实测 `git ls-remote --heads origin`）；重写前已建全量备份：`git bundle create ../backup-pre-scrub-20260929.bundle --all` 且 `git bundle verify ../backup-pre-scrub-20260929.bundle` rc=0（备份留在仓外，重写验证通过前不删）
- **When** 按**显式顺序**执行：⓪ 捕获远程 URL 存仓外（见 Given）→ ① 重写 `develop`（`git filter-repo --replace-text`）→ ② 单独重写孤儿 `main`（同一替换文件）→ ③ `git reflog expire --expire=now --all && git gc --prune=now` → ④ **重加远程** `git remote add origin "$(cat ../push-url-pre-scrub.tmp)"`（filter-repo 默认移除 origin 配置，缺此步强推必败）→ ⑤ 强推**两分支** `git push --force origin develop main` → ⑥ 删除仓外 URL 临时文件
- **Then** 本地 `git rev-list --all --objects` 逐 blob 扫描该真名串 = **0 个对象**；强推后从远端**全新 clone**（clone 全分支，`--single-branch` 禁用）重跑同一逐 blob 扫描，`develop` 与 `main` 两分支各自 = 0（远端复核不以本地 ref 为准）
- **验证方式**: 逐 blob `git cat-file` 扫描脚本 = 0 命中（本地仓库级 + 远端 clone 各一遍，两分支分开计数）；`test -f ../backup-pre-scrub-20260929.bundle && git bundle verify ../backup-pre-scrub-20260929.bundle` rc=0；远端 `git ls-remote --heads origin` 两分支 tip 均已前移

### AC-6 · C4 积压告警恢复

- **Given** `29-independent-review.sh:200` 已删 `|| true`（`$?` 可被捕获）
- **When** 注入一次 L3 backlog 失败（构造 `_l3_scan_backlog` 路径的错误）
- **Then** `module_output "warning" "IR" "backlog L3 failed for phase …"` **实际打印**（当前永不打印）
- **验证方式**: bats 注入用例断言 stderr 含该告警

### AC-7 · C5+C11 契约闭环（解析上提 + 键值对比较 + 反向控制）

- **Given** 预设名/值解析已提到生产 `.sh`（测试与 `check-gate-sync.sh` 双侧 source 同一实现），mock 72 处（实测 2026-09-29 引号口径，L3 重审 r3 m3 修订：原「90+」系口径滞留）`"independent"` 已改 `"both"`
- **When** ① 正常态跑 `make check-gate-sync`；② 反向控制：把任一预设值从 `both` 改回 `independent`
- **Then** ① rc=0 且比对的是**键值对集合**（非名字集合）；② 门禁**必须转红**（rc≠0）
- **验证方式**: `grep -c '"independent"' test/test_gate_config_presets.bats` → 0；反向控制 bats/手工注入用例转红；`grep -rn 'resolve_gate_config' --include='*.sh'` 返回生产实现（不再是纯注释）

### AC-8 · C12 门禁运行期 fail-closed

- **Given** `independent-review-gate.sh` 三个子库已补 `declare -f` 存在性断言，`:114`/`:65` 的 `|| exit 0` 已改 `exit 2` + 具名报文
- **When** ① 从 PATH 遮蔽 `jq`；② 把 `.flow-active` 写成非法 JSON；③ 删掉/改名 `gate-helpers.sh` 任一导出函数
- **Then** 三种情况门禁均**拒绝放行**（exit 2，具名报文），不再静默 `exit 0`
- **验证方式**: bats 反向控制 ×3（PATH 隔离 / 非法 JSON / 函数缺失）断言 exit 2

### AC-9 · C6 行为断言替换（双向不失真）

- **Given** 32 处源码文本断言（5 个 bats 文件）已改为行为断言
- **When** ① 重命名 `$content` → `$payload`（行为不变）；② 删除 `_l3_escape_payload` 的调用点（行为破坏）
- **Then** ① 测试**不红**；② 测试**转红**
- **验证方式**: 双向探针实测（先做 `test_l3_review_defects_2026_09.bats` 的 18 处）；改后残留白名单机检——`grep -rn "grep -q '.*\$content" test/*.bats | grep -vE ':(#|.*#) 行为断言' | wc -l` = 0（允许保留的行必须带 `# 行为断言` 标记注释，白名单即该注释本身，无主观裁量）

### AC-10 · C7 单跑 + C10 lint 语义化

- **Given** `Makefile` 已合并 `test` 目标为一次 bats（`PIPESTATUS[0]` 判红）；lint 改 `shellcheck -S error` 按 rc 判红且缺工具 fail-closed
- **When** 跑 `make test`（含故意注入一个失败用例的对照）与 `make lint`
- **Then** bats 只执行**一次**（调用计数可证）；注入失败时 `make test` rc≠0；缺 shellcheck 时 `make lint` **失败而非跳过**
- **验证方式**: `PATH` shim 法计数 `npx bats` 调用次数（shim 目录前置进 PATH，计数文件行数 = 1；不使用时长对比这类软判据）；`PATH` 遮蔽 shellcheck 断言 rc≠0

### AC-11 · C13 权威载体 + 覆盖率门禁（需 DESIGN 确认方向）

- **Given** 2-design 已定单一权威载体（CHANGE 建议 **prompts**，回归面最大），skills 为生成物或登记白名单
- **When** 跑 `make check-skills-sync`（**载体修订 2026-09-29 · L3 阶段 2 对账**：原文挂 `check-gate-sync`，但 C13 覆盖判据的设计落点是新建门禁 `check-skills-sync.sh`（DESIGN D2/D5，落 reference/ 随 ADR-030 豁免）——机制不变，载体更名，显式对账非静默偏离）
- **Then** 覆盖率低于阈值（目标 14/14，允许白名单登记的显式分叉）时 **rc≠0**；「覆盖率不足」从打印信息升级为失败条件；反向实例（`### 步骤 2.6` 只在 skill 载体）消除（**判据修订 2026-09-29 · L2 阶段 3 r2 R1 对账**：原文「两载体同小节集合」与薄壳化判据（权威正文在薄壳载体归一化行集交集 comm=0）**互斥**——薄壳载体按设计不含正文小节，判据更正为「载体映射完整 + 权威正文不双写」：每个 prompt 有且仅有一个 SKILL 薄壳 @see 指向 + 薄壳内权威正文残留 = 0；skill 独有条款须先并入权威 prompt 或显式登记弃用（TASK T12a 步骤 ① 处置清单），杜绝静默蒸发）
- **验证方式**: `check-skills-sync.sh` 覆盖对计数 + rc 断言；把一个 prompt 小节删掉必须转红（反向控制）

### AC-12 · C14 收口项（八件）

- **Given** 以下各项已修
- **When** 逐项验证
- **Then**：
  - **a（死代码）**：`jq_atomic_write` 从 `common.sh` 删除；其余 6 个零引用函数删或登记「测试专用」；`grep -rn 'jq_atomic_write' flow-kit-bundle/hooks/` = 0（**对账标注 2026-09-29 L2 阶段 3 R6**：机检域收窄为生产 hooks 面——`.specs` 文档面（CHANGE/LESSONS/CONTEXT 等历史登记处）10+ 处命中不算，否则判据恒红不可达；dist/ 镜像随打包再生不计）
  - **b（gate_config 多载体一致性）**：预设名集合在 SKILL（`skills/flow/SKILL.md`）↔ bats（`test_gate_config_presets.bats`）↔ `dsh-flow-kit` JS 状态机三处**比对为同一集合**；反向控制：注入一处预设名漂移（任一载体改名一个预设），门禁必须 rc≠0（**对账修订 2026-09-29 · L3 阶段 3 m1 + 重审 r2 m6**：「三处」为 09-20 巡检口径滞留；载体面以 **DESIGN §9.3 为准**——五载体 = SKILL（skills/flow/SKILL.md）/ test_gate_config_presets.bats / flow-state.js PRESET_MAP（:20 起，实测 17 键）/ gate-helpers.sh:26 内联值域 / **FLOW-KIT-用户指南.md :1585 枚举**（17 项）；check-gate-sync.sh 内建集合为**实现载体**（承载别名折算表与比对逻辑，随门禁钉住），统一对账与反向控制由 TASK T17 五载体集合比对承载，本处三处为其子集，判据不因载体数放宽）
  - **c（读机器态）**：读机器态软跳过点改显式 `skip`（打印原因）或硬断言，**双计数口径**：**11 个位点**分布在 **11 个文件**（**权威源修订 2026-09-29 · L2 阶段 3 r2 R11 对账**：全量清单以 **TASK T05 全变体严格谓词重算**为准（含 `[ ! -f "$HOME` / `[ -d` 安装态探测 / HOME 夹具自包含豁免 / 变量间接形态——赋值 `X="$HOME/…"` 下游同辖，如 test_l3_review_defects_2026_09.bats:973-974）；HEALTH 报告附录 C 仅为种子，实测偏差以重算为准并回写 CHANGE 登记——原「以 HEALTH 附录 C 为准」废止）；位点↔文件一一对应，逐位点处置：改 skip 或改断言，不静默；`make test` 输出可区分「真过」与「跳过」
  - **d（同步口径）**：`Makefile:76` 的 `test-sync` 递归化，与 `:84` `diff -rq` 同口径——门禁提示的修复命令**真能修好**子目录漂移
  - **e（JS 单测）**：`package-dsh-plugin.sh` 的 `--check` 在 `node --test` **之后**退出，4 个 `*.test.mjs` 进入 `make check` 链
  - **f（战役目录解耦）**：`check-path-privacy.sh` 不再硬编码 `.specs/health-fix-2026-09b/`（该脚本会被装进用户项目）
  - **g（`.flow-active` 解析收敛）**：`Makefile` recipe 不再内联手搓 `.flow-active` 解析（**机检修订 2026-09-29 · L2 三审 R5**：原锚 `grep -c 'jq .*\.flow-active' Makefile` = 0 实测当前已成立——:250-253 是 while/read/case 手搓形态本无 jq 字样，恒绿零鉴别力；改双锚 `grep -cE 'done < \.flow-active|\[ -f \.flow-active \]' Makefile` = 0（实测当前 = 2）+ 正向断言 `grep -c 'flow-active-query' Makefile` ≥ 1）；生产 `.sh` 内联解析 `.flow-active` 的文件数收敛到显式白名单（白名单在 DESIGN 定稿，每条给理由；**基线以附录 A 严格谓词重建后回填 N 为准**——巡检宽松 grep=43 / 人工判读 28 均不可直接用，ADR-031 决策 3）
  - **h/i（skip 与 SHA）**：7 处降级 skip 改显式；`be138c0` 硬编码改动态取或删；仓根 2 份陈旧 tarball 清理
- **验证方式**: 每项一条命令（grep 计数 / make 目标 rc / `ls *.tar.*` 为空）

### AC-13 · 总门禁与用例数

- **Given** 全部 AC 落地
- **When** 跑 `make check`
- **Then** **rc=0 全绿**（C2→C3 之间的「合法红」窗口已闭合）；bats 用例数 **≥ 1116**（起点，净增不减）；`check-test-sync` / `check-hooks-sync` / `check-dist` 镜像零漂移
- **验证方式**: `make check; echo $?` → 0；`npx bats test/ --formatter tap | tail -1` 用例计数

### AC-14 · 反哺销账

- **Given** 全部修完
- **When** 对照 `.specs/health/2026-09-29-HEALTH.md` 的 13 个 🔴 与附录 D 的 4 条新 🔴
- **Then** 逐条销账（载体定死：`.specs/STATE.md` 活跃变更段，报告不作为销账载体）；本 change 执行期间**新增 🔴 = 0**；新增 TD 与 TD-115…TD-138 不重复且逐条登记
- **验证方式**: `grep -c 'C[0-9].*已修复' .specs/STATE.md` ≥ 14（逐条销账行）；TD 基线 = **132**（`grep -c '^| TD-' .specs/CONTEXT.md`，2026-09-29 实测），执行期增量全部登记且编号连续、与 TD-115…TD-138 无重复（`grep -c '^| TD-'` 终值 ≥ 132 且抽查新增行）

### AC-15 · C8 结构层三件（内联引用化 / 第三载体合并 / deny 抽取）

- **Given** What 11/12/13（C8-①②③④）已实施
- **When** 逐项机械验证
- **Then**：
  - ① **commit-protocol 内联块归零**：`flow-kit-bundle/skills/flow-dev/SKILL.md` 的 `commit-protocol` 内联块删除（机检：`grep -c 'commit-protocol' flow-kit-bundle/skills/flow-dev/SKILL.md` = `grep -c '@see.*commit-protocol' flow-kit-bundle/skills/flow-dev/SKILL.md`，即所有残留命中行必须恰为 `@see` 引用行，两计数相等）；`flow-kit-bundle/flow-kit/prompts/4-dev.md:99-106` 内联表删除（**机检修订 2026-09-29 · L2 三审 R2**：原锚 `'#7 bats'` 全仓 0 命中——表用 `| 7 |` 行格式，恒绿；改锚 `grep -c '1\.8 触发时 bats' flow-kit-bundle/flow-kit/prompts/4-dev.md`，实测当前 = 1 → 删表后 = 0）；**恒真对账锚标注（L3 重审 r2 m8 修订 2026-09-29）**：① 内 commit-protocol 双计数锚在 SKILL 侧实测 0 命中时呈 0=0 空真——其作用是**防回归**（薄壳化后 SKILL 若残留非 `@see` 的 commit-protocol 行即失配转红），非独立验收判据；判据力由删表锚 `1.8 触发时 bats`=0 与 ②③ 承载（TASK T11 done 所引标注即本条）
  - ② **第三载体合并**：`flow-kit/.opencode/agent/flow-kit-l2-reviewer.md` 与 `flow-kit/prompts/independent/L2-blind-review.md` 的 163 行逐字复制段消除（**机检修订 2026-09-29 · L3 阶段 2 对账 + L2 重审 R4 归一化**，与 DESIGN D7 单一判据对齐：两侧各经 `grep -vE '^[[:space:]]*$\|^---$\|^```'` 滤平凡行（空行/`---`/代码栅栏）+ `sort -u` 后，`comm -12 … | wc -l` = 0——权威正文段与引用文件全文**无平凡行噪声的公共内容行**为零；未滤形态 0 不可达（37 空行 + 6「重点：」+ 3 栅栏必公共）；原文「diff grep -v '^#』为空」判据作废——opencode 侧保留 frontmatter/装配参数段，整文件 diff 恒非空，不可机检）；**不允许两份正文并存**，改法 = 引用侧整段替换为 `@see` 引用 + 装配参数 + 触发说明（TASK 只做提取替换，无裁量）
  - ③ **`_l2_first_deny()` 抽取**：L2-first deny 报文全仓出现次数 = 1（`grep -rn 'L2-first 契约未满足' flow-kit-bundle/ | wc -l` = 1，消除两份逐字复制；**机检修订 2026-09-29 · L2 三审 R3**：当前计数 = 4（生产 29-independent-review.sh:138,:239 ×2 + 测试 test-l2-first-correction.bats:55-56 ×2），仅生产抽取后恒 = 3 不可达 1——同批把测试两处字面量改拼接构造（`'L2-first ''契约未满足'` 形态，断言引用 `_l2_first_deny` 产物），生产 2→1 + 测试字面量 2→0，合计 = 1）
- **验证方式**: 上述三条 grep/diff 命令各自计数断言

### AC-16 · C9 显式降级 v2（登记可机检，不静默缩水）

- **Given** C9 四项结构改造（`main()` 抽取 / `_l3_build_prompt` 拆分 / Makefile 内嵌 bash 外迁 / 计数器收敛）已显式移入 v2（决策理由：改造面大，与本 change 在同一批文件上的 C4/C6 修复叠加 churn，回归风险不成比例——CHANGE 风险表 :505 自认「须分期」）
- **When** 检查 `.specs/STATE.md` 活跃变更段
- **Then** 含一条 C9 降级登记条目：四项内容 + 降级理由 + 承接去向（v2 / 下一轮 change），格式可 grep
- **验证方式**: `grep -n 'C9' .specs/STATE.md` 命中登记条目且同行含「v2」或「降级」字样

### AC-17 · pre-push 换装（A6 · 并发污染的 push 通路关闭）

- **Given** `.git/hooks/pre-push` 已从裸 `make check` 换装为调用 `flow-kit-bundle/hooks/pre-push/pre-push.sh`，且该脚本内部走 flock 并发闸
- **When** ① grep 检查 `.git/hooks/pre-push` 内容；② 向本地裸仓（`git clone --bare` 夹具）**并发**发起 2 次 `git push --dry-run`
- **Then** ① 内容含对 `pre-push.sh` 的调用；② 两次 dry-run 各自 rc=0 且结束后 `git status --porcelain` 无源文件改动（push 通路不再放大 C1 污染）
- **验证方式**: grep 内容断言 + bats 夹具（本地裸仓 + 双 dry-run + 状态断言）

---

## 范围切分

### v1（本次必做）

- 止血层：C12 fail-closed（0）、C11+C5 跨层闭环（0b/7）、C1 沙箱化 + 并发闸 + pre-push 换装（1/2）、C2 正则（3）、C3 tracked 脱敏（4）、C4 删 `|| true`（5）
- 收口层：C3 历史重写含孤儿 `main`（6，带备份判据）、C6 行为断言（8）、C7 单跑（9）、C10 lint（10）、C14-c/d/e（10b/10c/10d）
- 结构层：C8-①②③④（11/12/13）、C13 载体权威化（14b，**方向经 2-design 定**）、C14-a/b/f/g/h/i（14c–14f）
- 反哺层：TD/LESSONS 登记（15/16）——用户指令「修完」= 全部 14 项有 v1 交付或**显式登记的降级**；**C9 已显式降级挂 v2**（AC-16 判据：STATE.md 登记，理由 = 改造面大 + 同文件 churn 叠加，CHANGE :505 自认须分期）

### v2（下一轮考虑，不本次）

- **C9 结构化四件**（本次显式降级，AC-16 登记）：`main()` 抽取 / 201 行 `_l3_build_prompt` 拆分 / Makefile 内嵌 bash 外迁 / 计数器收敛
- CHANGE「范围排除」表的存量 🟡：TD-121（done-validation 条件 skip）、TD-122（T3 表驱动化）、TD-123（T1 smoke 清理，依赖 C10 后的职责边界）、TD-126（跨语言契约测试）、TD-124/TD-131（dist CI required 化）
- `flow-kit-bundle.tar.gz` 的 `check-tarball-freshness` 门禁（CHANGE 标注「待 2-design 决定」）

### out（永远不做）

- 引入 CI/CD（基础设施决策，`CONTEXT.md:30` 明确本仓无 CI；超范围）
- 8 组 ≤12 行 shell 字面重复的抽取（0.487% 持平基线，LESSONS 已登记「已评估不处置」）
- 把 `prompts`/`skills` 载体**合并成单一物理文件**（保持双载体形态，只定权威方向 + 门禁——用户使用面不变）

---

## 非功能性需求

- **性能**: `make test` 耗时较基线**减半**（消除 2×1116 双跑）；`make check` 总时长不得显著劣化（新增比对/单测的代价 ≤ 1 分钟量级）
- **可访问性**: 无（无 UI）
- **安全**: 隐私门禁与 PreToolUse 门禁统一 **fail-closed**（依赖缺失/输入非法 → 拒绝而非放行）；分发面（`flow-kit-bundle/`、`test/`、`dsh-flow-kit/`、tarball）真名保持 0；`PLACEHOLDER_NAMES` 白名单随 AC-3 正则放宽一并**扩全**（覆盖下游项目常见占位形态），并在 `check-path-privacy.sh` 头部注释登记「下游误报处置入口」（grep 可见锚点），分发出去的门禁行为变化对下游项目有可发现的说明面
- **数据完整性**: 历史重写（AC-5）为不可逆操作，必须与备份/回滚能力成对——重写前 `git bundle --all` 全量备份且 `verify` rc=0；备份在重写判据全绿前不删除（回滚 = 从 bundle 重新 clone）
- **兼容性**: 既有 `check-nfr-portability` 全绿（bash/jq 可移植面不收窄）；`git filter-repo` 重写后远端 `origin/develop` 强推流程与协作者通知按 `privacy-path-scrub-2026-09` 既有流程
- **可观测性**: L3 backlog 失败告警真实打印（C4）；测试 skip 必须显式并打印原因（C14-c/h）；`make check` 各门禁输出保留「覆盖数/通过数」汇总行

## 依赖与假设

- **依赖**: `git filter-repo`（C3 中期，本机可用或可安装）；`npx bats`（既有）；`shellcheck`（既有 0.9.0）；`flock`（并发闸，util-linux 自带）；`git bundle`（备份，git 自带）
- **内部顺序依赖（C5 改序，来自 CHANGE 风险表 :504）**: 先改 `check-gate-sync` 的**值比较逻辑**（键值对集合），**再**改 mock 值（`independent`→`both`）——反序会让 mock 改动连带真红，被误判为门禁缺陷
- **假设**: ① 用户已确认历史重写（`develop` 已推送，需强推 + 协作者通知；孤儿 `main` 单独重写；备份 bundle 留仓外）；② C13 权威载体按 CHANGE 建议取 **prompts**，最终在 2-design 定稿；③ `common.sh:408` 生产契约（`independent→both`）为**只读参照**不改语义，改的是 mock 与门禁侧；④ 6 个部署根 hooks 镜像在改动 hooks 后须经 `sync-hooks.sh` 再同步，`check-hooks-sync` 门禁会强制（**对账修订 2026-09-29 · L3 阶段 3 M2 + 重审 r2 m7**：再同步已从隐式假设显式编码为任务排程——T09④ `make hooks-sync` + T11/T13/T14 verify 各自收口 + T16⑦ 终判前兜底，覆盖全部改 hooks 的波次（含 W6 T13——independent-review-gate.sh 属 sync 镜像集），check-hooks-sync 不再有先行漂移窗口）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
