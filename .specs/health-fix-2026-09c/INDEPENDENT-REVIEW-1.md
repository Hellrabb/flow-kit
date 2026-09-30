# 独立审查 · 阶段 1

## L2 盲审

- **审查对象**：`.specs/health-fix-2026-09c/REQUIREMENT.md`（参照 `.specs/health-fix-2026-09c/CHANGE.md`）
- **阶段**：1 · 需求审查
- **独立性声明**：输入仅含上述两份工件与固化指令，未检测到主 agent 自评 / 草稿 / 概述 / 辩护注入，独立性完整。

---

### 交叉核对结果（本阶段 L-031 替代项：AC 覆盖面 vs CHANGE「What」）

| What 项（CHANGE.md 行号） | AC 对应 | 判定 |
|---|---|---|
| 0 · C12 fail-closed（:373） | AC-8 | ✓ |
| 0b · C11 跨层闭环（:374） | AC-7 | ✓ |
| 1 · C1 沙箱化（:376） | AC-1 / AC-2 | ✓ |
| 2 · C1 加固：flock + pre-push 换装 A6（:377） | 仅 AC-1（并发结果） | ⚠️ pre-push 换装无 AC → R5 |
| 3 · C2 正则（:378） | AC-3 | ✓ |
| 4 · C3 短期脱敏（:379） | AC-4 | ✓ |
| 5 · C4 删 `\|\| true`（:380） | AC-6 | ✓ |
| 6 · C3 历史重写（:384） | AC-5 | ⚠️ 备份判据缺失 → R6 |
| 7 · C5 双侧同批（:385） | AC-7 | ✓ |
| 8 · C6 行为断言（:386） | AC-9 | ✓ |
| 9 · C7 单跑（:387） | AC-10 | ✓ |
| 10 · C10 lint（:388） | AC-10 | ✓ |
| 10b/c/d · C14-c/d/e（:389-391） | AC-12c/d/e | ✓（c 的「等」范围含糊 → R8） |
| 11 · C8-①②（:395） | **无** | 🟡 R1 |
| 12 · C8-③（:396） | **无** | 🟡 R1 |
| 13 · C8-④/PC7（:397） | **无** | 🟡 R1 |
| 14 · C9 结构化（:398） | **无** | 🟡 R2 |
| 14b · C13 载体权威（:399） | AC-11 | ✓（阈值待 2-design → R8） |
| 14c · C14-a（:400） | AC-12a | ✓ |
| 14d · C14-f/g（:401） | AC-12f；**g 无** | 🟡 R4 |
| 14e · C14-h/i（:402） | AC-12h/i | ✓ |
| 14f · C14-b 四载体三重比对（:403） | **无，且 v1/v2/out 均未收录** | 🟡 R3 |
| 15/16 · 反哺登记（:407-408） | AC-14 | ✓ |

- **「CHANGE 列出但无 AC 对应」**：5 处（What 2 之 A6、11、12、13、14、14d-g、14f）→ R1–R5
- **「AC 引入 CHANGE 未载范围」**：0 处——所有 AC 均可溯源到 CHANGE What 或验收线（:478-491），无范围蔓延
- 逐条 AC 的 Given/When/Then 三段齐全 ✓；AC-3/7/8/9/11 的**负对照（反向控制）设计**是本需求文档的显著优点，直接压制了 C2/C5/C11/C12「假绿」复发

---

### 🟡 R1 · C8-①②③④ 入 v1 但零 AC 覆盖：结构层改造免验放行

**Severity**：🟡 Important
**Symptom（症状）**：REQUIREMENT.md:136 将 C8-①②③④（CHANGE.md:395-397，What 11/12/13）列入 v1，但 AC-1…AC-14 无任何一条对应
**Source（源头）**：REQUIREMENT.md:168「AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC」+ REQUIREMENT.md:22「每条 AC 都有一条命令或一次受控操作可验证」；ISO/IEC/IEEE 29148 验收准则可验证性
**Consequence（后果）**：内联引用化、第三载体合并（163 行逐字复制）、`_l2_first_deny()` 抽取这三组结构改造在 4-dev/5-test 无完成判据——`make check` 只能拦回归、证明不了「已做」；AC-13 的全绿会让未做项静默通过，后续 L2/L3 阶段审查也无锚点可查
**Remedy（修补）**：补 3 条 AC，各配一条命令：① `grep -cE 'commit-protocol' skills/flow-dev/SKILL.md` 内联块计数归零 + `4-dev.md:99-106` 内联表删除（`grep -c '#7 bats'` = 0）；② `diff <(l2-reviewer.md 载体段) <(L2-blind-review.md)` 为空或一方已引用化；③ L2-first deny 报文全仓 `grep -c 'L2-first 契约未满足'` = 1（消除 CHANGE.md:251 的两份逐字复制）

### 🟡 R2 · C9 结构化（What 14）零 AC，「允许挂 v2」亦无登记判据

**Severity**：🟡 Important
**Symptom（症状）**：REQUIREMENT.md:136 将 C9（CHANGE.md:398）列入 v1、:137 允许「显式降级挂 v2 但必须在 STATE.md 登记」——两者均无 AC 承接
**Source（源头）**：同 R1；CHANGE.md:505 风险行自认「C9 结构改造面大」须分期
**Consequence（后果）**：C9 含 4 项大改（`main()` 抽取 / 201 行 `_l3_build_prompt` 拆分 / 203 行 Makefile 内嵌 bash 外迁 / 6 计数器收敛），无 AC 则 TASK 无法排 verify 步骤、TEST 无从派生用例；「挂 v2 须登记」无判据则降级是否发生不可机器核查，两者叠加 = C9 可被无声跳过
**Remedy（修补）**：二选一：(a) 补 AC——`grep -c '^main()' 29-independent-review.sh` = 1、`tools/check-nfr-portability.sh` 存在且 `Makefile:162` 起 recipe 行数低于阈值、`_l3_build_prompt` 拆后单函数行数上限；(b) 显式移入 v2 并把「STATE.md 含 C9 降级登记条目」写成 `grep` 判据

### 🟡 R3 · C14-b（What 14f）被静默丢出全部范围层

**Severity**：🟡 Important
**Symptom（症状）**：CHANGE.md:403 列 What 14f（gate_config 4 载体 + SKILL↔bats↔`flow-state.js` 三重比对），但 REQUIREMENT.md:132-149 的 v1/v2/out 三层均未收录——v1 行（:136）只列「C14-a/f/g/h/i」，无 b
**Source（源头）**：REQUIREMENT.md:22「编号与 CHANGE『What』分层对应」；REQUIREMENT.md:137 自引用户指令「修完 = 全部 14 项入 v1」；CHANGE.md:408 已为本项登记 TD-137
**Consequence（后果）**：该项既不会做也不会被追问——范围静默缩水且无决策记录；TD-137 债在册而修复无主，下轮巡检将重复立项（违反 CHANGE.md:408「禁止重复立项」的自我要求）
**Remedy（修补）**：二选一并写明理由：补 AC-12b（三重预设名比对 + 注入一处预设名漂移断言 `check-gate-sync` 转红）；或移入 v2/out 表并给理由（如「依赖 AC-11 的 C13 权威载体方向先定，避免二次返工」）

### 🟡 R4 · C14-g 在 v1 却无 AC 子项

**Severity**：🟡 Important
**Symptom（症状）**：REQUIREMENT.md:136 v1 含 C14-g（CHANGE.md:401 之 14d 后半：`.flow-active` 解析收敛单点、消除 `Makefile:251` 手搓解析与 28 文件格式知识泄漏），但 AC-12（REQUIREMENT.md:105-111）子项为 a/c/d/e/f/h/i，无 g
**Source（源头）**：同 R1
**Consequence（后果）**：v1 承诺了 28 文件级知识收敛却无验证点——TEST 只测 AC-12f（战役目录解耦），g 项可整体不做而 AC-13 `make check` 仍全绿；`Makefile:251` 手搓 JSON 解析这一「格式一变即静默取错值」的风险原样存活
**Remedy（修补）**：补 AC-12g：断言 `Makefile` 不再内联手搓 `.flow-active` jq 解析（如 `grep -c 'jq .*\.flow-active' Makefile` = 0 或改走统一解析函数的调用断言）+ 28 文件收敛达标线（列文件清单，`grep -rln` 计数对表）

### 🟡 R5 · What 2 的 pre-push 换装（A6）无 AC 承接

**Severity**：🟡 Important
**Symptom（症状）**：CHANGE.md:377「`.git/hooks/pre-push` 改为调用 `flow-kit-bundle/hooks/pre-push/pre-push.sh`（C8 的 A6 项）」随止血层入 v1（REQUIREMENT.md:134「并发闸（1/2）」），但 AC-1 只验「并发后工作树不脏」，未验 pre-push 是否真换装
**Source（源头）**：同 R1；CHANGE.md:252 A6 行自证危害——现 `.git/hooks/pre-push` 是裸 `make check`，「每次并发 push 检查都会再犯」C1 污染
**Consequence（后果）**：A6 不做则并发 push 通路继续放大 C1 污染；且 AC-1 的验证用 `make check & make check & wait` 直接触发、绕过 pre-push 路径，该缺陷对全部 AC 不可见
**Remedy（修补）**：补一条 AC：断言 `.git/hooks/pre-push` 调用 `flow-kit-bundle/hooks/pre-push/pre-push.sh`（grep 内容断言或 dry-run 行为断言）；并在 AC-1 或该 AC 中补一路经 pre-push 的等价并发触发（如 `git push --dry-run` ×2）

### 🟡 R6 · 历史重写（AC-5）缺备份 / 回滚类 NFR

**Severity**：🟡 Important
**Symptom（症状）**：REQUIREMENT.md:153-159 非功能段与 AC-5（:52-57）均无「重写前全量备份」判据；依赖段（:163）只列工具可用性，假设①（:164）只要求用户已确认
**Source（源头）**：ISO/IEC/IEEE 29148——不可逆操作须与数据完整性/恢复需求成对出现；CHANGE.md:503 自认「重写历史影响所有协作者」「不可逆」，缓解仅「遵循既有流程 + 通知」，无备份验收
**Consequence（后果）**：`filter-repo` + `gc --prune=now` 一旦正则误判（二进制误改、编码异常、`main` 重写顺序错），86 个旧对象删除后无退路——唯一恢复源是远端旧推送，而远端随后就被强推覆盖；此时泄漏没除掉、历史先毁了
**Remedy（修补）**：补 NFR + AC-5 前置判据：重写前 `git bundle create ../backup-pre-scrub-<date>.bundle --all` 且 `git bundle verify` rc=0（或全量 mirror clone 到仓外）；AC-5 Then 增「备份存在且可 verify」前置；把「develop 与孤儿 main 分别重写」的顺序写成显式步骤而非一句 Given

### 🟢 R7 · AC-2 首个断言在沙箱化后恒真，「kill 时点」无确定性构造

**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT.md:31-36——Then 第一支「源文件不残留修改」在 AC-1（沙箱化）成立后对任何实现恒真；「夹具改写后 kill」无 sentinel 等确定性手段
**Source（源头）**：Kaner 等《Testing Computer Software》——不能失败的断言不是测试
**Consequence（后果）**：派生用例可能写成「必然绿」形式（`git diff --stat` 恒空），回归网虚设；kill 靠 sleep 撞时点则用例抖动
**Remedy（修补）**：改写 Then 为双断言：kill 生效证明（夹具内文件确被改）+ tracked 面恒净 + 注入还原失败（夹具置只读）断言非零退出；kill 用 sentinel 文件轮询构造

### 🟢 R8 · 多处验证口径偏软，TEST 派生前需硬化

**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT.md:57（AC-5「远端同步复核」无方法）；:92（AC-10「调用计数（或运行时长对比）」二选一且后者证据力弱）；:107（AC-12c「:561-564 **等**」未定 11 文件全量还是样板）；:85（AC-9「或仅存行为语义断言」无边界）；:96-98（AC-11 阈值与白名单机制待 2-design，但 Then 已预设「两载体同小节集合」结论）；依赖段（:161-164）未收录 CHANGE.md:504 的 C5 内部顺序（先改门禁值比较、再改 mock）
**Source（源头）**：ISO/IEC/IEEE 29148——验收准则须有客观 pass/fail 判据
**Consequence（后果）**：TEST 阶段这些条目的用例质量取决于执行者自由裁量，异人异机结果不同；C5 顺序遗漏则触发 CHANGE.md:504 预警的「改 mock 值连带真红」
**Remedy（修补）**：AC-5 补「从 origin 全新 clone 重跑逐 blob 扫描 = 0」；AC-10 固定 PATH shim 计数法；AC-12c 写明 11 文件清单或「至少 1 文件 + 其余登记」；AC-9 给残留白名单正则；AC-11 待 2-design 回填阈值后修订措辞；依赖段补 C5 内部顺序一行

### 🟢 R9 · AC-1 只验「不脏」不验「双绿」

**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT.md:29 验证命令未断言两个并发 `make check` 各自 rc=0
**Source（源头）**：ISO/IEC/IEEE 29148——验收判据须覆盖 When 声明场景的完整结果
**Consequence（后果）**：并发下若一方因锁竞争/资源冲突失败退出，AC-1 仍通过——并发正确性的另一半（互不干扰**且都成功**）被遗漏
**Remedy（修补）**：验证命令追加双 rc 捕获断言：`rc1/rc2` 分别落文件后 `[ "$rc1" = 0 ] && [ "$rc2" = 0 ]`

---

**Verdict**: pass

（0 🔴 / 6 🟡 / 3 🟢。无 Critical：未发现范围蔓延、矛盾 AC 或不可验证的空话型条款；6 条 🟡 集中于同一根因——v1 承载的部分 What 项无 AC 承接（R1–R5）与不可逆操作缺备份判据（R6），建议在进入 2-design 前修订 REQUIREMENT.md。3 条 🟢 按 Severity Gating 协议由主 agent 写入 `.specs/health-fix-2026-09c/MINOR-DEFERRED.md`。）

---

## 主 agent 响应（阶段 1 · 对 L2 盲审 · 2026-09-29）

> 逐条 `Fixed in:` / `Tech-debt:` / `MINOR-DEFERRED:`。全部修订发生在 REQUIREMENT.md v2（本段之后、L3 之前的版本），L3 盲审对象 = 修订版。

- **R1（C8-①②③④ 零 AC）** — **Fixed in:** REQUIREMENT.md 新增 `AC-15`（三件各配 grep/diff 命令：① `commit-protocol` 内联块归零 + `4-dev.md:99-106` 内联表删除（`grep -c '#7 bats'` = 0）；② `flow-kit-l2-reviewer.md` ↔ `L2-blind-review.md` 163 行复制段 diff 为空或一方引用化；③ `_l2_first_deny` 报文全仓计数 = 1）
- **R2（C9 零 AC 且降级无判据）** — **Fixed in:** 采纳 Remedy (b)：C9 **显式降级 v2**（v2 表新增四项 + 理由），新增 `AC-16`（STATE.md 登记条目 grep 判据，含「v2/降级」字样，不静默缩水）
- **R3（C14-b 静默丢出范围层）** — **Fixed in:** 采纳「补 AC」分支：`AC-12` 新增 **b 子项**（SKILL↔bats↔dsh JS 三处预设名集合比对 + 注入漂移必须转红的反向控制）；v1 结构层行显式列 `C14-a/b/f/g/h/i`；不挂 v2（AC-11 已在本 change 内定权威方向，无二次返工问题）
- **R4（C14-g 无 AC 子项）** — **Fixed in:** `AC-12` 新增 **g 子项**（`grep -c 'jq .*\.flow-active' Makefile` = 0 + 内联解析文件数收敛到 DESIGN 定稿的显式白名单，基线 28）
- **R5（pre-push 换装无 AC）** — **Fixed in:** 新增 `AC-17`（`.git/hooks/pre-push` 内容 grep 断言 + 本地裸仓双 `git push --dry-run` 并发 rc=0 + 状态净）；v1 止血层行补「pre-push 换装」
- **R6（历史重写缺备份 NFR）** — **Fixed in:** `AC-5` 重写为三段显式顺序（develop → 孤儿 main → reflog expire+gc），Given 增备份判据（`git bundle create --all` + `verify` rc=0，备份留仓外、判据全绿前不删）；Then 增「从远端全新 clone 重跑逐 blob 扫描 = 0」；非功能段新增 **数据完整性** 条目（不可逆操作与备份/回滚成对）
- **R7（AC-2 恒真断言 + kill 时点）** — **MINOR-DEFERRED:** MINOR-DEFERRED.md M1（TEST 派生时按 Remedy 双断言 + sentinel 落实）
- **R8（软判定口径）** — **部分 Fixed in + MINOR-DEFERRED:** AC-5 远端复核与依赖段 C5 内部顺序两处已就地硬化（REQUIREMENT.md v2）；其余三处（AC-10 计数法固定 / AC-9 白名单正则 / AC-11 阈值待 2-design）记 MINOR-DEFERRED.md M2，由 2-design 与 TEST 阶段承接
- **R9（AC-1 只验不脏不验双绿）** — **Fixed in:** AC-1 验证方式改为显式捕获 `r1/r2` 并断言双 rc=0（`wait $p1; r1=$?; wait $p2; r2=$?; exit $((r1+r2))`）

## 主 agent 响应（阶段 1 · 对 L3 盲审 · 2026-09-29）

- **Major #1（AC-2 还原路径子句 post-fix 不可判 + 断言对象含混）** — **Fixed in:** REQUIREMENT.md AC-2 重写为三段独立可机检判据：① kill 注入跑 rc≠0；② 中断后 `git diff --stat` = 0 行（防回归断言——锁定「沙箱化不被回退」，非恒真）；③ 夹具路径在测试输出可见（mktemp 泄漏不静默）。「还原路径失败」子句删除（其所指机制已被 AC-1 消除，属遗留措辞）。
- **Major #2（AC-5 远端覆盖不完整：origin 孤儿 main + filter-repo 剥离 remote）** — **Fixed in:** AC-5 重写：Given 增已核实远程形态（`git ls-remote --heads origin` 实测：origin 同时含 develop+main）；When 显式五步——① filter-repo develop → ② 单独重写孤儿 main → ③ reflog expire + gc → **④ 重加 `git remote add origin git@github.com:<OWNER>/flow-kit.git`（filter-repo 默认移除 origin 配置）** → **⑤ `git push --force origin develop main`（两分支）**；Then 远端全新 clone（全分支，禁 `--single-branch`）逐 blob 扫描 develop 与 main **各自 = 0**。
- **Minor #3（AC-9/10/15①②「或」型弱臂）** — **Fixed in:** 全部改单一机检谓词：AC-9 = 残留行必须带 `# 行为断言` 注释（`grep -v` 该注释后计数 = 0，白名单即注释本身）；AC-10 = 定死 PATH shim 计数法，删时长对比臂；AC-15① = `grep -c 'commit-protocol'` 与 `grep -c '@see.*commit-protocol'` 两计数相等（所有残留命中必须恰为 @see 行）；AC-15② = 正文 diff 为空（单一权威正文），「两份正文并存」显式禁止，改法 TASK 阶段定一。
- **Minor #4（AC-12-c 位点/文件口径混用）** — **Fixed in:** 明确双计数「11 位点 / 11 文件（一一对应）」，清单锚点仍外置 HEALTH 附录 C。
- **Minor #5（AC-14 销账基线与载体）** — **Fixed in:** 销账载体定死 `.specs/STATE.md`（报告不作载体）；TD 基线 = **132**（2026-09-29 实测 `grep -c '^| TD-' .specs/CONTEXT.md`），增量须编号连续且与 TD-115…138 不重复。
- **Minor #6（AC-12-f/NFR 下游白名单未登记）** — **Fixed in:** NFR-安全扩一条：`PLACEHOLDER_NAMES` 白名单随 AC-3 正则放宽一并扩全，`check-path-privacy.sh` 头部注释登记「下游误报处置入口」grep 锚点。

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-29 13:55）

> 自动生成于 2026-09-29 13:55。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-5 的 Then 断言「强制更新对象并存 + hook 从远端全新 clone」依赖远端已变更的事实，但 AC-4 只做提交、AC-5 的 When 包含强推，因此「强推后远端复核」不是问题；但 AC-5 的 Given 要求「origin = git@github.com:<OWNER>/flow-kit.git」及「已确认历史重写」均属外部环境事实，工件本身未提供该远端可访问/可操作的证据；若审查者无法连接该远端，AC-5 的远端复核不可验证。",
      "why": "AC 的可验证性要求一条命令或一次受控操作可在工件环境中执行；远端可达性、协作者确认、bundle 留仓外等外部前置条件无法由工件自身保证，审查/测试环境若离线则该 AC 无法执行。",
      "fix": "把远端复核改为「若远端可达则执行，否则以本地 clone 自检 + 记录跳过原因」或提供远端可达性的基线证据；或将远端复核判据降为 v1 交付的一部分但明确需人工/环境前置确认。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-9 的残留白名单机检命令 `grep -rn \"grep -q '.*\\$content\" test/*.bats | grep -vE ':(#|.*#) 行为断言' | wc -l` = 0 的语义可能有歧义：该命令只检查含 `grep -q '.*$content` 的行，但 AC-9 声称「32 处源码文本断言（5 个 bats 文件）已改为行为断言」，没有给出全量残留断言的统一机检口径；允许保留的行必须带 `# 行为断言` 标记注释，但该注释本身无法证明该行是行为断言而非文本断言。",
      "why": "AC 的可验证性要求无歧义；如果白名单判据只是行尾注释标记，那么任何文本断言都可以通过加注释通过机检，反向控制只能证明部分探针转红，不能证明全部 32 处已改。",
      "fix": "给出可机检的全量断言分类清单（例如按 bats 文件列出 32 处定位，逐一标注行为断言/文本断言，并配 grep 计数），或把「残留文本断言」的判据定义为可执行的行为探针集合而不是注释标记。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-7 的 When②「把任一预设值从 both 改回 independent」与 AC-7 的 Given「mock 90+ 处 independent 已改 both」自洽，但反向控制没有说明在哪个载体改（bats mock？生产 .sh？SKILL？），且 AC-12-b 的预设名集合一致性是「集合」比较，AC-7 是「键值对值」比较，两个 AC 对同一 gate_config 的载体漂移判据可能互相干扰：若反向注入改的是 SKILL 中的值，AC-12-b 只查集合名、AC-7 只查值，可能一个转红一个不转红，验证命令不唯一。",
      "why": "AC 的可验证性要求受控操作明确；反向控制没有指定注入位点，不同位点会触发不同 AC 的不同判据，无法确定 AC-7 的「门禁必须转红」是哪一个门禁、哪一条比较逻辑。",
      "fix": "在 AC-7 中明确反向注入的载体与位点（例如改 test/test_gate_config_presets.bats 中某一预设值），并指出对应门禁名（check-gate-sync）及预期报错；同时说明与 AC-12-b 集合比较的区分（值漂移 vs 名漂移）。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-10 的「bats 只执行一次」用 PATH shim 计数 `npx bats` 调用次数，但 AC-10 的 When 是「跑 make test（含故意注入一个失败用例的对照）与 make lint」，若 Makefile 的 `test` 目标内部有递归或包装（例如通过 bash -c、npx --yes、子 make），PATH shim 只拦截 npx bats 的直接调用，不能证明 bats 套件本身只执行一次（例如 test 目标可能先跑一次 bats 再跑一次 check-test-sync，或 recipe 中多次 `npx bats` 但其中一次不带 `test/` 路径）。",
      "why": "AC 要求「调用计数可证」且明确不使用时长的软判据，但没有给出计数文件应等于 1 的完整证据链；若 Makefile 中另有间接调用 bats 的路径（如 check-test-sync 触发子目录 bats），计数可能 >1 或无法捕获。",
      "fix": "在 AC-10 中明确计数 shim 的放置路径与计数对象（例如 `PATH=/tmp/shim:$PATH make test` 且 shim 记录 `npx bats` argv，断言只有一个 `npx bats test/` 调用），并说明 `make check` 中同一套件不重复计数（或把计数范围限定为单个 `make test` 目标）。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-15 ② 的机检命令 `diff <(grep -v '^#' <载体A>) <(grep -v '^#' <载体B>)` 除去 frontmatter/标题行后为空，但 AC-15 ② 同时要求「单一权威正文 + 另一方整段替换为 `@see` 引用；不允许两份正文并存」；若一方已替换为 @see，则两份文件行数/内容必然不同，diff 不会为空（除非两文件都只有 @see 或都为空）。该机检命令与目标状态矛盾。",
      "why": "AC 的可验证性要求机检与目标一致；当前写的 diff 判据实际会拒绝「一方整段替换为 @see」的期望结果，导致验收永远失败或需要人为绕过。",
      "fix": "改为机检「两份文件中不存在超过 N 行的相同正文段」（例如用 `diff <(grep -v '^#' A) <(grep -v '^#' B) | wc -l` 大于阈值，或 `grep -c '@see.*L2-blind-review'` = 1），并明确两份文件的总行数差异或唯一权威方判定。"
    }
  ],
  "minor": [
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-15 ① 的计数相等判据：`grep -c 'commit-protocol'` = `grep -c '@see.*commit-protocol'` 允许 `@see` 引用行存在，但未定义 `@see` 引用行的目标载体是否必须存在且同步；若目标文件缺失或漂移，本 AC 仍绿。",
      "why": "AC 要求单一权威载体，但引用完整性未纳入机检。",
      "fix": "增加 `test -f` 目标文件断言，或要求 `@see` 行中的相对路径可解析。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-12-c 的双计数口径「11 个位点分布在 11 个文件（全量清单以 HEALTH 报告附录 C 为准）」依赖外部报告附录 C 作为唯一清单，而本提示词工件（REQUIREMENT.md）未提供附录 C 内容；审查者无法独立核对 11 个位点是否齐备。",
      "why": "AC 的可验证性要求清单在工件内可查；外部报告可能更新或不可得。",
      "fix": "把 11 个位点清单直接内联到 AC-12-c（文件:行号），或将附录 C 作为本工件附件提供。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-14 的 TD 基线 132 与「新增 TD 与 TD-115…TD-138 不重复」存在编号语义冲突：TD-115…TD-138 已占 24 个编号，若基线 132 是 CONTEXT.md 当前编号，执行期新增 TD 从哪个编号开始未定义；「编号连续」与「与 TD-115…TD-138 不重复」同时成立需要明确 start。",
      "why": "AC 的可验证性要求计数命令结果稳定；编号起点不明确会导致终值判断主观。",
      "fix": "在 AC-14 中写明执行期新增 TD 的起始编号（例如 TD-139）或改为「新增行必须引用 TD-xxx 且该编号不在基线集合中」。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-12-f 说 `check-path-privacy.sh` 不再硬编码 `.specs/health-fix-2026-09b/`，但 AC-4 与 AC-3 的验证命令 `make check-path-privacy` 没有给出该命令在装进用户项目后如何定位仓库根/配置路径；若脚本脱离本仓运行，路径解耦的验收缺少独立测试。",
      "why": "AC 的「该脚本会被装进用户项目」是部署面声明，但 AC 本身只在本仓验证，缺少用户项目场景的机检验证。",
      "fix": "增加一条命令：在临时目录复制脚本与最小 fixture，运行脚本并断言不引用旧路径（例如 `grep -rn 'health-fix-2026-09b' <script>` = 0），或添加一个 bats 用例覆盖非本仓工作目录。"
    }
  ],
  "verdict": "pass",
  "summary": "AC 整体可验证且范围切分合理，但 AC-15② 的机检判据与目标状态自相矛盾、AC-7/AC-9/AC-10 的反向控制与计数口径仍有歧义，需在 TEST 阶段前修口。"
}
```

L3_artifact_hash: 20f3d06318743894acd7b6af0ef56c15f0b12dc3f368e75fe0e96b17fb864906

<!-- /L3-SECTION -->
