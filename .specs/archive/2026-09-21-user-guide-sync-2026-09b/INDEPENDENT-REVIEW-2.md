# 独立审查 · 阶段 2

## L2 盲审

**Verdict**: fail

- 审查对象：`.specs/user-guide-sync-2026-09b/DESIGN.md`（209 行 · mtime 22:07:23）。交叉核对（只读）：REQUIREMENT.md v2（mtime 22:09:24）、CHANGE.md、`.specs/CONTEXT.md`、`.specs/ARCHITECTURE.md`、`.specs/adr/017|019|025|026|027`、`Makefile`、`package-dsh-plugin.sh`、`package-flow-kit.sh`、`verify-claims.sh`、`test/`、`.specs/user-guide-deck-gen/**`、`/tmp/guide-drift-report.md`、工作树 `git status/diff`。
- 独立性：**prompt 中未收到任何主 agent 自评 / 草稿 / 概述 / 辩护 → 独立性未受损**。披露：仅在一次事实核对中只读打开同目录 `INDEPENDENT-REVIEW-1.md`（内含主 agent 响应段）与 `TASK.md`；二者未改变任何结论方向（R2 因 `TASK.md:222-234` 已列第二份镜像而下调为 🟡），全部发现均由仓库实测 + DESIGN 原文独立得出。
- 实测（只读 · 快照 2026-09-21 22:11:31，期间 bundle 副本被持续改写）：四副本 `md5sum`/`wc -l` · `diff root↔bundle` 35 hunks · `bash package-dsh-plugin.sh --check` **rc=1** · `git ls-files dist | wc -l` = 0 · `diff -rq test/ flow-kit-bundle/test/` rc=0 · `grep -rn "user-guide-deck-gen\|deck_checks" Makefile verify-claims.sh test/*.bats` = 0 命中 · `deck_checks.py` 位置断言 `items[13]/items[19]` · `slides.json` 20 页 · `~/.dsh/profiles/web/.../{docs,vendor}` 两份已安装副本存在 · `soffice/pdftoppm/python-pptx/bats` 版本。
- 未复算（需确认）：`/tmp/guide-drift-report.md` 43 条逐条事实（本轮抽检 §0/D01/D43 与 N 编号）。

---

### 🔴 R1 · DESIGN 的底稿基线未冻结且已被实测证伪：D1 的「防信息损失」缓解失去可判定前提

**Severity**：🔴 Critical
**Symptom（症状）**：`DESIGN.md:28` 断言底稿 `flow-kit-bundle/FLOW-KIT-用户指南.md` = 「1632 行 · md5 `d87c6d84`…」；`DESIGN.md:70`（D1 代价）与 `DESIGN.md:171`（R2 缓解）把「根↔bundle **唯一差异就是那 2 行**、方向为根旧」写成已实测前提。快照 22:11:31 实测：该文件 = **1660 行 / md5 `61914768`**，审查窗口内已连续变更 ≥4 次（`d87c6d84`→`ad7790ae`→`411b1829`→`61914768`，行数 1632→1637→1660；22:10 快照 `git diff --numstat` = 38+/15− 且仍在增长），root↔bundle 差异 = **35 hunks（`<` 41 行 / `>` 70 行）**；`git status --porcelain` = ` M flow-kit-bundle/FLOW-KIT-用户指南.md`；dist×2 仍是 `d87c6d84` → `bash package-dsh-plugin.sh --check` **rc=1**（两条「❌ 陈旧」分别指向 `docs/` 与 `vendor/`）。底稿在主 agent 写完 DESIGN（22:07:23）之后被持续改写（22:08、22:10:36…），而 `DESIGN.md` 未再更新——与 `DESIGN.md:5` 自述「只设计，不写实现 · R3.1」及 AC-9 的「六门全绿」起点不一致。
**Source（源头）**：`DESIGN.md:199-203`（§7 自述「所有既有模块均来自实测命令 `md5sum`/`wc -l`…证据链」）；`package-dsh-plugin.sh:45`（映射载体 = bundle 副本）；`.specs/CONTEXT.md` 已锁决策 `[2026-09-20]`「改了 `flow-kit-bundle/` 任一内容后必须重跑 `package-dsh-plugin.sh` 重建 dist，否则 git 结构性失明」。
**Consequence（后果）**：D1 的覆盖前置条件（「先做 diff 双向核对，确认根副本相对 bundle 没有任何独有内容」）建立在一个已被证伪的「2 行」之上，真实差异量级差约 20 倍。按 DESIGN 字面执行的实现者面对 35 个 hunk 时，无法区分哪些是「根旧（应覆盖）」、哪些是「bundle 独有（不应由本轮吞掉）」——正是 D1/R2 声称已消除的信息损失风险。另：漂移报告的行号锚点（`L65-66`、`L1210-1212` 等）在底稿位移 +28 行后不再指向原文，D6「逐条映射到断言表」的定位依据同步失效。该偏差**不会被本 change 新增的守护发现**——四副本一致性断言比对的是同步**之后**的结果。
**Remedy（修补）**：把 `DESIGN.md:27-28` 改为带时间戳的起始快照（示例：`root 1631/fb2ff01b`、`bundle 1660/<md5>`、`dist×2 d87c6d84（已陈旧）`、`root↔bundle = N hunks / M 行，N/M 以阶段 4 动手前重跑为准`）；D1 缓解改写为可执行判据：「阶段 4 第一步：登记 `git rev-parse HEAD` + 三份 `md5sum` → 重跑 `diff` → hunk 数 > 登记值时逐条归类为「根旧」或「bundle 独有」，凡「bundle 独有」先并入底稿再覆盖根副本」；§2 管线（`DESIGN.md:131-139`）在「① 根（cp 底稿）」之前补一步「重建 dist 使 `check-dist` 复绿」。

### 🟡 R2 · DESIGN 的写入清单 / R6 白名单漏列 `flow-kit-bundle/test/` 镜像：与本 change 的 TASK 自相矛盾，会让 AC-9 越界判定误判

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:35`（会新增）只列 `test/test_guide_copy_parity.bats`；`DESIGN.md:175`（R6 白名单）写「…**1 个新 bats 文件**」。而 `Makefile:71-85` 的 `test-sync`/`check-test-sync` 要求 `test/` 与 `flow-kit-bundle/test/` 逐文件同源（实测 `diff -rq` rc=0），`check-test-sync` 是 `Makefile:106` 六门之一；`TASK.md:222-234` 已把 `flow-kit-bundle/test/test_guide_copy_parity.bats` 写进 write_files 并要求落盘后跑 `make test-sync`。
**Source（源头）**：`Makefile:79-85`（双源硬 `diff -rq`，失败即 exit 1）；`package-dsh-plugin.sh --check` 自身打印的顺序契约「若改过 test/，先 make test-sync，再重建 dist」（实跑可见）；`.specs/CONTEXT.md:468` 禁动清单（`test/` 只允许 `.bats`）。
**Consequence（后果）**：只加 `test/` 一份 → `check-test-sync` 红，AC-9「六门全绿」在阶段 4/5 不可达；而按 DESIGN 的白名单（1 个新文件）做边界核对，第二份镜像会被判「越界即失败」（R6 原文口径），两个判据互斥。`TASK.md` 已覆盖此点，故不阻塞本轮，但 DESIGN 作为阶段 2 工件的清单与 AC-9 白名单必须自洽。
**Remedy（修补）**：`DESIGN.md:35` 增列 `flow-kit-bundle/test/test_guide_copy_parity.bats`（注明「`make test-sync` 产物」）；`DESIGN.md:175` 白名单改为「**2 处**测试文件（`test/` + `flow-kit-bundle/test/`）」；§2 管线补 `make test-sync` 步骤。

### 🟡 R3 · deck 与它的断言同属「改源忘重建无人发现」的失明资产，而 D2 的守护论证只覆盖 md 副本

**Severity**：🟡 Important
**Symptom（症状）**：`flow-kit-用户指南.pptx` 与 `.specs/user-guide-deck-gen/slides.json` 均为 tracked（`git ls-files` 命中），但 `grep -rn "user-guide-deck-gen\|deck_checks" Makefile verify-claims.sh test/*.bats` = **0 命中** → 改了 `slides.json` 不重建 pptx 时，没有任何门禁可见。`DESIGN.md:72-80`（D2）为「文档副本一致性」专门新建机械断言，而 `DESIGN.md:90`（D3 代价）只承诺「slides.json 与 deck_checks 在同一 task 内改完并实跑」。
**Source（源头）**：`Makefile:112-121` 的 check-dist 设立理由原文（「`dist/` 被 gitignore → git 对它结构性失明，改了源忘了重建不会被任何既有门禁发现」）；`.specs/CONTEXT.md` 已锁决策 `[2026-09-20]`；REQUIREMENT v2 AC-6 的注入实测属**一次性人工证据**，非复发性门禁。
**Consequence（后果）**：本轮之后任何一次 `slides.json` 改动都回到「git 看得见改动、看不见陈旧」的形态；AC-6 的注入实测在阶段 5 做一次后再无触发点，24 页 deck 与 `slides.json` 长期分叉无人报警——与 D2 要消灭的失效形态同构（同一份 DESIGN 内两套标准）。
**Remedy（修补）**：在新 bat 中追加 2 条 <1s 断言：① pptx 页数 == `len(json.load(slides.json))`；② pptx 封面行日期（`Presentation` 首页文本）== 指南文首版本行日期（`grep -m1 '^> 版本:'`）。不新增 Makefile target，沿用 D2 的载体决策。

### 🟡 R4 · 守护域漏掉用户实际读到的那两份：已安装 dsh 插件副本

**Severity**：🟡 Important
**Symptom（症状）**：`~/.dsh/profiles/web/node_modules/dsh-flow-kit/docs/FLOW-KIT-用户指南.md` 与 `.../vendor/flow-kit-bundle/FLOW-KIT-用户指南.md` 实测存在（22:11 仍为 `d87c6d84`，相对底稿已陈旧）。`DESIGN.md:26-36`（§0.5.1）与 D2/AC-10 的枚举只有仓内 4 份。而 `Makefile:126-143` 的 `dsh-sync`（`rsync -a --delete`）正是把 dist 的 `docs/` + `vendor/` 同步进该目录。
**Source（源头）**：`test/test_l3_pipeline_fix.bats:548,561` —— DESIGN D2 声称「沿用该范式」，而该范式本身就包含 `global ~/.claude copy cmp-identical when present` 的**条件式已安装副本断言**；`Makefile:126-131` 注释记录插件 `docs/`+`vendor/` 的 17 处漂移已实际发生过。
**Consequence（后果）**：仓内四份全绿时，dsh 用户打开的指南副本可能仍是旧版；本 change 恰好改写了安装/更新章节（新措辞要求 `make dsh-sync`），旧副本 + 新说明叠加是最易误解的组合——即 US-1/US-2 要消灭的那类误导，只是载体换成了插件安装目录。
**Remedy（修补）**：按所沿用的既有范式加条件断言：对 `$HOME/.dsh/profiles/*/node_modules/dsh-flow-kit/{docs,vendor/flow-kit-bundle}/FLOW-KIT-用户指南.md` 逐个 `[ ! -f ] || cmp -s <bundle 副本>`；若判定超范围，则必须在 D2 显式写明「已安装副本不在守护域，理由 X」，并把 `make dsh-sync` 列为阶段 7 发布检查项。

### 🟡 R5 · dist 缺席时新断言的行为未定义，而「沿用」的范式在 fresh clone 上是硬红

**Severity**：🟡 Important
**Symptom（症状）**：`dist/` 被 `.gitignore:63` 忽略，实测 `git ls-files dist | wc -l` = **0** → 新克隆 / CI 上四份只存在两份（root + bundle）。`DESIGN.md:72-80` 与 `DESIGN.md:143-145` 写「md5 四份一致，否则 rc≠0」，却未定义缺份语义；所沿用的 `test/test_l3_pipeline_fix.bats:548` 是对 2 份 dist 路径直接 `md5sum` 再 `sort -u | wc -l == 1`（文件缺席 → `md5sum` 报错、计数 0 → 断言红），仅对已安装副本用 `[ ! -f ] ||` 降级（`:561`）。
**Source（源头）**：`package-dsh-plugin.sh` 的 `check_dist` 既有降级口径（usage `:27-35`／实现注释：「dist 不在 → 新鲜度无从谈起，提示后放行 rc=0」，但必需源侧完整性仍须核）；`REQUIREMENT.md` AC-10 Then 要求断言**非恒绿**。
**Consequence（后果）**：该取舍决定断言是「本地门禁」还是「跨机门禁」：按硬写法，fresh clone 上 `make check` 必红（哪怕文档完全正确）；按降级写法则必须在 DESIGN 中写明「dist 缺席 = skip + 提示」。实现者无论选哪一侧，都会与 DESIGN 现有文本冲突，且阶段 5 的「注入→变红→还原→复绿」实测无法区分「红是因为漂移」还是「红是因为缺 dist」。
**Remedy（修补）**：D2 增一句判据：「`[ -d dist ] || { echo 'dist 未构建 → 跳过 dist 两份比对（先跑 bash package-dsh-plugin.sh）'; skip; }`；仅当 dist 存在时要求四份 md5 唯一」；§2 管线把「重建 dist」排在「跑新 bat」之前。

### 🟡 R6 · `deck_checks.py` 的断言是位置索引，与 D3 扩页位移强耦合，D3 代价清单漏列

**Severity**：🟡 Important
**Symptom（症状）**：`deck_checks.py:56,60` 用 `items[13]` / `items[19]` 断言「页 14 含五级链字段」「页 20 含 dsh 插件 + `/flow doctor`」（对应 `slides.json` idx13 =「L2/L3 模型配置：五级解析链」、idx19 =「dsh 插件化：安装与挂载」，实测）。D3（`DESIGN.md:84-90`）要插入 4 个新专页，代价只列「页数断言、KEY_STRINGS、BANNED 全部要改」。
**Source（源头）**：`deck_checks.py:40`（`len(items) == EXPECT_PAGES` 唯一总量判据）+ `:56,60` 的位置取值；`CHANGE.md:58` 自述风险「若 `deck_checks.py` 与 slides.json 不同步会出现恒绿/恒红」。
**Consequence（后果）**：新页插在索引 13/19 之前时，两条位置断言指向别的页——内容恰好命中则**恒真**（五级链专页整页丢失也不报警），不命中则报「page14 five-tier fields missing」这类指向错误页的误导性失败。D3 的注入实测若只测页数与封面日期，抓不到这一类。
**Remedy（修补）**：改为标题/内容寻址（如 `_page_with(items, "五级")` 取首个命中页，取不到即 assert 失败），或在同一 task 内显式改索引并把 old→new 页号映射写进 TEST.md；D3 代价补一句「位置断言必须一并改索引或改寻址方式」。

### 🟡 R7 · `.specs/user-guide-deck-gen/README.md` 未列入「会修改（既有）」，但它承载本 change 必改的三处事实

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:30` 只列 `slides.json` / `deck_checks.py` / 「必要时 `layouts.py` / `build.py`」。实测同目录 `README.md:28` 写死封面日期口径「日期统一写 `2026-09-03 | github.com/hellrabb/flow-kit`」（本轮定稿 `2026-09-21`），`:32` 是旧禁词清单（缺本轮新增项），`:23-25` 的 layout 表在 D3「必要时新增 1 个 layout」后会缺项；另 `:28` 的 `hellrabb/flow-kit` 与 `deck_checks.py:51` 断言的 `hellrabbit/flow-kit`、`slides.json` 封面实际值已不一致。
**Source（源头）**：`README.md:3` 自述「本目录 tracked 入库，跨 change 维护」；`.specs/CONTEXT.md:468` 同族资产的维护范式；CONTEXT 已锁决策 `[2026-06-22]`（说明文档在重大 change 后同步）。
**Consequence（后果）**：下一轮改 deck 的人按 README 写 `2026-09-03` 或按旧禁词清单挑选措辞 → 直接踩 `deck_checks.py:15-17,50` 的 BANNED/封面断言；deck-gen 目录内出现「代码已改、说明仍旧」的二级漂移，与本 change 目标形态相同。
**Remedy（修补）**：`DESIGN.md:30` 补 `README.md`（同步封面日期口径、禁词清单、新增 layout 行，并修正 `hellrabb→hellrabbit`）；若决定不改，则在 DESIGN 写明「本轮不动，理由 X」。

### 🟢 R8 · 上游 CHANGE.md 的副本计数（三处）与 AC-5（四份）口径不一致，DESIGN 未登记该差

**Severity**：🟢 Minor
**Symptom（症状）**：`CHANGE.md:22` 列 `flow-kit-bundle/…`、`dist/dsh-flow-kit/docs/…` 与根文件（3 条路径），`CHANGE.md:52` 写「**三处**指南副本逐字节一致」；而 `REQUIREMENT.md` AC-5、`DESIGN.md:135-138` 均为四份（含 `dist/dsh-flow-kit/vendor/flow-kit-bundle/…`，实测该文件存在）。
**Source（源头）**：`find . -name "FLOW-KIT-用户指南.md"` 实测仓内恰 4 份；`DESIGN.md:32` 已把 vendor 路径写入再生映射。
**Consequence（后果）**：阶段 7 归档核对若照 CHANGE.md 的「三处」执行，会漏检 vendor 那一份——正是本次 `--check` rc=1 报出的第二条。
**Remedy（修补）**：`CHANGE.md:22,52` 的「三处」改「四处」并列出 vendor 路径（纯口径修正，无实现影响）。按 ADR-017 记入 `.specs/user-guide-sync-2026-09b/MINOR-DEFERRED.md`，不入 fix loop。

---

### L-031 锚点扫描（独立全仓 · 不信 DESIGN §0.5.1 清单）

| 锚点 | 全仓命中 | 分类 |
|---|---|---|
| `FLOW-KIT-用户指南.md` 副本 | `find` = 仓内 4 份（root / bundle / dist docs / dist vendor）；仓外 2 份（`~/.dsh/profiles/web/node_modules/dsh-flow-kit/{docs,vendor/…}`） | 仓内 4 份 DESIGN 已列；**仓外 2 份未列 → R4** |
| `test/` ↔ `flow-kit-bundle/test/` 双源 | `Makefile:71-85`（实测 rc=0）；`TASK.md:222-234` 已列镜像 | **DESIGN §0.5.1/R6 未列 → R2** |
| deck 资产族 | `flow-kit-用户指南.pptx`(tracked) · slides.json(20 页) · deck_checks.py · build.py · layouts.py · theme.py · utils/* · **README.md** | 前 5 项 DESIGN 已列；`theme.py`/`utils` 本轮无改动证据（不列为发现）；**README.md 未列 → R7** |
| deck 断言门禁接线 | `grep -rn "user-guide-deck-gen\|deck_checks" Makefile verify-claims.sh test/*.bats` = 0 | **无守护 → R3** |
| 指南的其他引用点 | `package-dsh-plugin.sh:45`（映射，DESIGN 已列）· `flow-kit-bundle/lib/validate_staging.sh:117`（`KNOWN_SKIP` 含指南，故 `check-validate` 对指南不做覆盖校验）· `test/test_gate_freshness.bats:31`（夹具）· `README.md` / `dsh-flow-kit/{README,DESIGN}.md` / `.specs/*` | 无「DESIGN 列出但未改」项；`validate_staging.sh:117` 说明「指南不在打包覆盖门禁内」，即四份一致性只能靠本 change 新增断言（支持 R3/R4 的守护域讨论） |
| DESIGN 列出且已改 / 列出未改 | `git status`：仅 `flow-kit-bundle/FLOW-KIT-用户指南.md`(M) 与 `.specs/CONTEXT.md`(M)；无「DESIGN 列出但未改」 | 「DESIGN 漏列且未改」= R2/R7；「DESIGN 漏列但**已**改」= 底稿本身（见 R1） |

**Verdict**: fail

---

## 主 agent 响应（阶段 2 · L2 首轮 R1–R8 · 2026-09-21）

| # | Sev | 处置 | 动作 |
|---|---|---|---|
| R1 | 🔴 | **Fixed in: DESIGN.md §0.5.1 + D1 + §2 管线（v2）** | ① §0.5.1 删除写死的 md5/行数，改为「基线为执行时快照（`git rev-parse HEAD` + `md5sum` + `wc -l`）」；② D1 缓解改写为「阶段 4 先登记快照 → 重跑 `diff` → **逐条归类每个 hunk** 为根旧/bundle 独有；hunk 数本身不是异常信号，未归类的 hunk 才是」；③ §2 管线补入窄路径 dist 再生（使 `check-dist` 由红转绿）与 installed 副本同步步骤 |
| R2 | 🟡 | **Fixed in: DESIGN.md §0.5.1（v2）** | 「会新增」补 `flow-kit-bundle/test/test_guide_copy_parity.bats`（`make test-sync` 产出，`check-test-sync` 要求两目录一致）；TASK T06 同步已含该文件 |
| R3 | 🟡 | **Fixed in: DESIGN.md D2 守护域 + REQUIREMENT AC-10 + TASK T06（v2/v3）** | 新增 **deck 新鲜度断言**：pptx 页数 == `len(slides.json)`、封面日期串 == 指南版本行日期（`python-pptx`，<1s），并入 `test_guide_copy_parity.bats` 用例 4 |
| R4 | 🟡 | **Fixed in: DESIGN.md D2 + REQUIREMENT AC-10 + TASK T06** | 守护域补 `~/.dsh/profiles/*/node_modules/dsh-flow-kit/{docs,vendor}/FLOW-KIT-用户指南.md`：**存在时**必须与 dist 一致（沿用 `test_l3_pipeline_fix.bats:561` 的 when-present 范式），由阶段 4 `make dsh-sync` 对齐（仓库外副作用，计划内） |
| R5 | 🟡 | **Fixed in: DESIGN.md D2 + REQUIREMENT AC-10** | 明确降级语义：`dist/` 缺席（fresh clone）时 dist 相关两份断言**显式 SKIP 并打印原因**（沿用 `check-dist` 口径），`root↔bundle` 边**永远执行**；不采用硬 md5 恒红写法 |
| R6 | 🟡 | **Fixed in: DESIGN.md D3 代价 + TASK T05** | 写死「`deck_checks.py` 位置索引改为**按标题寻址**（`by_title`）」，并要求 TEST.md 记录 old→new 页号 |
| R7 | 🟡 | **Fixed in: DESIGN.md §0.5.1 + D3 + TASK T05** | `.specs/user-guide-deck-gen/README.md` 列入「会修改」（`:28` 日期、`:32` 禁词表、`:23-25` layout 表），并统一 `hellrabb/flow-kit` → `hellrabbit/flow-kit`（与 `deck_checks.py` 封面断言一致） |
| R8 | 🟢 | **Tech-debt: MINOR-DEFERRED M5** | `CHANGE.md` 的「三处副本」与 AC-5「四份」口径不一致 → 属 CHANGE 历史文本，按 ADR-017 登记 MINOR-DEFERRED，阶段 7 triage 时一并决定是否回填 |

**复审请求**：DESIGN.md v2 已按 R1–R7 重写（§0.5.1 快照口径、D1 缓解、D2 守护域与降级、D3 索引与 README、§2 管线）。R8 入 MINOR-DEFERRED。

---

## L2 盲审（第二轮）

**Verdict**: fail

- 审查对象：`.specs/user-guide-sync-2026-09b/DESIGN.md`（219 行 · mtime 22:13:14）。仅对**当前现状**独立判定；不采信文件内及同目录任何既往轮次结论。
- 独立性：**prompt 中未收到任何主 agent 自评 / 草稿 / 概述 / 辩护 → 独立性未受损**。披露：为执行「先读全文再追加」的写入约束，只读打开了本文件，其中含第一轮 L2 段与主 agent 响应段（属历史轮次）；本轮全部发现由 DESIGN 原文 + 仓库实测独立得出，未沿用其任何结论（R1/R2/R5/R6 判定与首轮**不同**）。
- 实测快照（只读 · 2026-09-21 22:11–22:16）：
  - 四副本：root `fb2ff01b`/1631 · bundle `a0119f75`/1666（**审查期间持续改写**：1632→1660→1666，22:15:22 仍在变）· dist×2 `d87c6d84`/1632 → `md5sum … | sort -u | wc -l` = **3**
  - `diff root↔bundle` = **65 hunks**（`<` 123 行 / `>` 169 行）；`git diff --numstat` bundle = **165+/120−**
  - `bash package-dsh-plugin.sh --check` **rc=1**（dist×2 陈旧）；`check-test-sync` / `check-hooks-sync` / `check-validate` 均 rc=0；`test/`↔`flow-kit-bundle/test/` 71↔71 rc=0
  - `deck_checks.py` 现为 `items[13]`/`items[19]` 位置断言；`slides.json` 20 页；`deck_checks.py` rc=0；pptx 封面 = `2026-09-03 | github.com/hellrabbit/flow-kit`
  - `.flow-active`：`current_phase=0` · `phases_done=[]` · 七道门全 pending
  - 字体：`fc-list` 无 `宋体` / `Times New Roman`；`fc-list :lang=zh` = 89 项（有 Noto Serif/Sans CJK 兜底）
- 未复核（无判据 · 显式标注）：漂移报告 43 条的**逐条事实**（本轮仅核其坐标基准与 §0）；deck 渲染版面（尚未重建）。

---

### 🔴 R9 · D1 的「仅 2 行方向性差异」缓解前提与当前实测差 ≥30 倍（2 行 → 65 hunks），且底稿未冻结——按 DESIGN 字面执行者会在错误量级上做归类

**Severity**：🔴 Critical
**Symptom（症状）**：`DESIGN.md:70`（D1 代价缓解）写「**本轮实测仅 2 行方向性差异**」。独立实测（22:11→22:16，多次复跑）：`diff FLOW-KIT-用户指南.md flow-kit-bundle/FLOW-KIT-用户指南.md` = **65 hunks / root 独有 123 行 / bundle 独有 169 行**；`git diff --numstat` 对 bundle 副本 = **165+/120−**；bundle 副本 mtime 从 22:08 一路变到 **22:15:22**（本报告落笔时仍在变），而 `.flow-active` 仍是 `current_phase=0 / phases_done=[]`。同段「hunk 数必然大于历史基线——**hunk 数本身不是异常信号**」的措辞把两个不同量混为一谈：该 diff 的 hunk 数**就是**基线分叉本身，不是「本轮改写的产物」。`DESIGN.md:69` 的「根副本落后 2 行（漂移报告 §0 的 diff 证据）」是对报告历史快照的引用——报告 §0 记 2 行（root@1631/bundle@1632），但同一份报告写就后底稿立即被改写，DESIGN 未登记这一位移。
**Source（源头）**：`DESIGN.md:199-203`（§7 自述「所有既有模块均来自实测命令…证据链」+「未引用任何未验证的路径或抽象」）；REQUIREMENT v3 AC-5（「执行时记录基线」·R15）+ AC-2 前置（「对齐前只核 bundle 副本，且必须记录基线」）；ADR-019（写作原则：具体、可验证）。
**Consequence（后果）**：① 按 `DESIGN.md:70` 字面执行的实现者在阶段 4 看到 65 hunks 时，缺乏「这是预期量级」的判据，只能二选一：误判为异常而中止覆盖（本 change 的核心动作被卡住），或跳过归类直接 `cp`（正是 D1/R2 声称已消除的信息损失路径）；② 「冻结点」不存在——底稿在被审 DESIGN 定稿后仍被改写，任何登记过的基线在下一次写入后即失效，归类结论不可复算；③ 该偏差不会被本 change 新增的任何守护发现（四副本断言比对的是同步**之后**的结果）。
**Remedy（修补）**：`DESIGN.md:69-70` 改为带坐标基准的表述，例如：「根↔bundle 差异量级**以阶段 4 动手时重跑为准**（历史快照 2 行，2026-09-21 22:1x 实测 65 hunks / 123+169 行——**差异已远大于历史快照，量级不是异常信号**）」；并在 D1 缓解首句加冻结判据：「**冻结点** = T01/T02 的 `status=done` 且底稿 mtime 不再变化；冻结后登记三份 `md5sum`/`wc -l` 并重跑 `diff`，此后任何对底稿的写入都作废上次归类、必须重跑」；同时删/改「hunk 数必然大于历史基线」这半句（hunk 数即分叉量，非增量指标）。另建议在 D6 补一句坐标基准：「漂移报告的行号锚点基于**仓库根副本**（报告头 `审计对象` = 根副本 1631 行；抽检 D01 `L65-66`/D43 `L1380` 均只在根副本命中，bundle 对应处已是新文本）——**不得把报告的 L 号直接套到 bundle 底稿上**」。
**备注**：本轮不判 Critical 的理由已逐条核过——DESIGN v2 **未**写死任何 md5/行数（`grep -n "1631\|1632\|1666\|d87c6d84\|a0119f75\|fb2ff01b"` = 0 命中）、§0.5.1 已声明「基线为执行时快照」、`DESIGN.md:70` 已要求「逐条归类每个 hunk」。缺陷面收窄为**前提表述失实 + 缺冻结语义**，可只改 DESIGN 文本闭合。

### 🟡 R10 · D2 installed-copy 守护用 `~/.dsh/profiles/*/` 通配，比 `make dsh-sync` 的实际作用域宽——多 profile 机器上恒红

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:83` 定义 installed 副本守护域为 `~/.dsh/profiles/*/node_modules/dsh-flow-kit/{docs,vendor}/FLOW-KIT-用户指南.md`（**所有** profile）。而 `Makefile:136-137` 的 `dsh-sync` 只写 `DSH_PLUGIN_DIR = $(HOME)/.dsh/profiles/$(DSH_PROFILE)/node_modules/dsh-flow-kit`，`DSH_PROFILE ?= web`（单值、无通配）；`Makefile:136` 的 `dsh-sync: check-dist` 也只覆盖这一个 profile。实测本机 `ls ~/.dsh/profiles/` = `dsh-tui` / `web` / …，其中只有 `web` 装了插件（`dsh-tui/node_modules` 无 `dsh-flow-kit`）。
**Source（源头）**：本 change 自己的降级原则（`DESIGN.md:82` 「dist 缺席 → 显式 SKIP」·`DESIGN.md:83` 「installed 副本**存在时**必须一致」）+ `Makefile:136-137`（唯一同步入口的单 profile 事实）；同类「范围大于机制」缺陷在本 change 首轮已就同类结构（dist 缺席）改过一次。
**Consequence（后果）**：本机因只有 `web` 装了插件而**恒绿**——缺陷不可见；一旦用户在第二个 profile 装过插件，该 profile 的副本不在 `dsh-sync` 作用域内、永远对不齐 → `make check` 第一门恒红，且失败信息会指向一个**修不了**的路径（`make dsh-sync` 不动它），与 AC-10「非恒绿」的可复算语义相反。反之若有意守护全部 profile，则 `dsh-sync` 必须循环所有 profile，DESIGN 未定义。
**Remedy（修补）**：把 `DESIGN.md:83` 的守护域收窄到机制能力内：`${HOME}/.dsh/profiles/${DSH_PROFILE:-web}/node_modules/dsh-flow-kit/{docs,vendor}/FLOW-KIT-用户指南.md`（与 `Makefile:136-137` 同源），或显式写明「守护全部 profile + `dsh-sync` 改为遍历 `~/.dsh/profiles/*`」并同步改 `Makefile`（后者已越本 change 白名单，需先扩 AC-9）。二选一必须写进 DESIGN，不能留通配符。

### 🟡 R11 · AC-9 越界判据含**不存在**的路径且漏掉**真实**路径：`skills/**`（仓根）证伪，`flow-kit-bundle/skills/**` 未列入

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:39` 禁动清单写「`flow-kit-bundle/hooks/**`、`dsh-flow-kit/lib/**`、**`skills/**`**、`flow-kit-bundle/flow-kit/prompts/**`（运行时实现，diff 必须为 0 —— AC-9）」。实测：仓根**无** `skills/`（`ls -d skills` → rc=2「没有那个文件或目录」；顶层仅 `adr/ dist/ dsh-flow-kit/ flow-kit-bundle/ test/ tools/`），而**真实存在且需冻结**的是 `flow-kit-bundle/skills/`（`ls -d flow-kit-bundle/skills` 命中；REQUIREMENT AC-9 与 CHANGE.md「范围排除」都写的就是这条真路径）。
**Source（源头）**：REQUIREMENT AC-9（「以下路径（**仓库真实路径** · v3 修正 · R17）的 diff = 0：… `flow-kit-bundle/skills/**` …」——同一份上游已明确要求「真实路径」）；L-031 通用必查项（不信 DESIGN 清单、独立全仓扫描）。
**Consequence（后果）**：AC-9 的机械判据若照 DESIGN 文本落成脚本，`git diff --name-only -- … skills …` 对一个不存在的路径返回空 → **永远通过**，`flow-kit-bundle/skills/**` 的实际改动不会被告警。本 change 当前未动 skills，故不构成现实损害；但 AC-9 是本 change 唯一的边界门禁，判据含「结构性恒真项」正是 D2/AC-10 要消灭的同一失效形态（同一份 DESIGN 内两套标准）。
**Remedy（修补）**：`DESIGN.md:39` 的 `skills/**` → `flow-kit-bundle/skills/**`（与同段 `flow-kit-bundle/hooks/**`、`flow-kit-bundle/flow-kit/prompts/**` 的真实路径写法对齐）；`DESIGN.md:205`（AC-9 映射行）与 `DESIGN.md:185`（R6 白名单）同步核一遍路径存在性。

### 🟡 R12 · 新守护把 `make check` 第一门绑上 pptx + python-pptx + slides.json，而本轮只为 dist 定义了降级语义

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:84`（`deck 新鲜度（R3）`）要求 bats 用例内「`flow-kit-用户指南.pptx` 页数 == `len(slides.json)`」并读**封面日期串**（`DESIGN.md:84` 写「封面日期串 == 指南版本行日期」；TASK T05 `:199`/AC-6 写的是「封面日期 `2026-09-21`」——两种口径本身也不一致）。该断言进入 `test/`，由 `Makefile:9-11` 的 `make test` 收集，而 `Makefile:106` 的 `make check` 第一门就是 `test`。DESIGN 的降级语义（`DESIGN.md:82`）**只**为 `dist/` 缺席定义（SKIP + 打印原因），对 pptx / `slides.json` / `python-pptx` 三者缺席均无定义。
**Source（源头）**：REQUIREMENT AC-10「断言**非恒绿**：注入 1 字节漂移 → 变红 → 还原 → 复绿」（要求红/绿成因可归因）；`DESIGN.md:82` 已确立的降级范式（缺件 → 显式 SKIP 而非硬红）；已锁决策「不引入任何新依赖」（`DESIGN.md:11`）——而 `python-pptx` 正是新增的**测试期**依赖。
**Consequence（后果）**：① 未装 `python-pptx` 的机器（fresh clone / 换机 / CI）上 `make check` 第一门红，且红因是环境而非文档漂移——阶段 5 的「注入→变红」实测将无法区分该类红；② 生成器只在**阶段 4** 跑（`DESIGN.md:140-146` 管线），而旧 pptx 是 tracked 的 20 页：任何在「改 `slides.json` 之后、重建 pptx 之前」执行 `make check` 的时点（含阶段 3 收尾、阶段 4 中途）都会红——DESIGN 未声明这一时序约束，实现者可能在阶段 3 结束时就撞上无法解释的红。
**Remedy（修补）**：`DESIGN.md:84` 的 deck 断言补降级分支：`[ -f flow-kit-用户指南.pptx ] || skip "pptx 未生成（先跑 build.py）"`、`python3 -c "import pptx" || skip "python-pptx 缺失（pip install python-pptx）"`；并在 §2 管线（`DESIGN.md:139-146`）显式加一条时序约束：「**重建 pptx 必须早于**跑 `make test`/`make check`；`slides.json` 与 pptx 的页数不一致属**预期中间态**，仅允许在阶段 4 内存在」。同时统一断言口径：封面日期串比对用「与指南版本行同名日期」，不要与 AC-6 的硬编码 `2026-09-21` 双写（双写会在下一轮同步时自相矛盾）。

### 🟢 R13 · 首轮 R7 要求修的 README 行本身是**会破表**的 Markdown

**Severity**：🟢 Minor
**Symptom（症状）**：`DESIGN.md:30` 要求把 `.specs/user-guide-deck-gen/README.md:28` 的 `hellrabb/flow-kit` 统一为 `hellrabbit/flow-kit`。该行实测为：「日期统一写 \`2026-09-03 | github.com/hellrabb/flow-kit\` 封面行与内容页无需重复。」——`|` 未转义且该行位于正文段落（非表格单元格，故当前尚未破表），改写后仍是裸管道符。`deck_checks.py:51` 断言的是 `hellrabbit/flow-kit`（正确）。
**Source（源头）**：ADR-019（写作原则：具体、可验证）；REQUIREMENT v3 R18（「表格转义管道修正」——同一类已知问题已在上游修过一次）。
**Consequence（后果）**：本轮改写该行时若不转义，未来若把它移入表格即破表；读者/生成器解析 `|` 仍可能误判列边界。影响面小、不阻塞。
**Remedy（修补）**：改写为「日期统一写 \`2026-09-21\` + 封面行 URL `github.com/hellrabbit/flow-kit`」（URL 移出反引号内的 `|` 串），或写成 `2026-09-21 \| github.com/hellrabbit/flow-kit`。按 ADR-017 记入 `MINOR-DEFERRED.md`，不入 fix loop。

### 🟢 R14 · R4 的缓解（「发现丢字则回退到既有 theme 字体族」）无落点：theme 指定的两款字体本机都不存在

**Severity**：🟢 Minor
**Symptom（症状）**：`DESIGN.md:183`（R4 缓解）写「发现丢字则回退到既有 theme 字体族，不换字体」。实测 `theme.py:29-31` 的 `EN_FONT="Times New Roman"` / `ZH_FONT="宋体"` 在当前渲染机 `fc-list` 中**均无命中**（`fc-list :lang=zh` = 89 项，靠 Noto Serif/Sans CJK 与 AR PL 系列兜底）。「回退到既有 theme 字体族」= 回退到同样缺失的两款字体，无落点。
**Source（源头）**：`theme.py:28-31`（字体为**字名字符串**，最终渲染由打开方决定）；REQUIREMENT NFR「可访问性：deck 渲染须满足无缺字/无溢出」。
**Consequence（后果）**：AC-7 的 PDF/PNG 抽检是在 **Noto CJK 替代字体**下测的——替代字体的字宽/行高与真实 PowerPoint（SimSun/Times）不同，抽检通过不保证目标环境不溢出、抽检失败也可能是替代字体所致。这不是实现缺陷，而是**验证工具的已知局限**，须在 TEST 留痕，否则会被当成结论用。
**Remedy（修补）**：R4 缓解改为可执行版本：「回退候选 = `Noto Serif CJK SC`（本机实测存在），或接受 LibreOffice 替代字体并在 TEST.md 记录『板式结论基于 Noto CJK 替代，非 SimSun 度量』」。按 ADR-017 记入 `MINOR-DEFERRED.md`。

---

### L-031 锚点扫描（独立全仓 · 不信 DESIGN §0.5.1 清单）

| 锚点 | 全仓命中（实测） | 分类 |
|---|---|---|
| 指南四副本载体 | `md5sum` 四路径 = 3 个唯一值（root `fb2ff01b` / bundle `a0119f75` / dist×2 `d87c6d84`）；`git ls-files` 三份 tracked（dist 被 `.gitignore` 忽略，`git ls-files dist` = 0） | DESIGN §0.5.1 基本列全（根、bundle、dist×2）；**基线量级失实 → R9** |
| 副本一致性守护接线 | `grep -rn "用户指南" Makefile verify-claims.sh sync-hooks.sh package-flow-kit.sh` = **0 命中** | 确无守护，支持 D2 的必要性（无「列出未改」项） |
| dist 打包映射 | `package-dsh-plugin.sh:45` `COPY_OPTIONAL`（bundle→`docs/`）+ `:41` README→`$PKG_DIR/README.md`；`--check` 实测 **rc=1**（两条「陈旧」指 docs/vendor） | DESIGN §0.5.1 已列；**只改 bundle 会让 `check-dist` 转红**，DESIGN 已在 AC-5/D2 覆盖 |
| `test/` ↔ `flow-kit-bundle/test/` | 71 ↔ 71，`diff -rq` rc=0；`Makefile:79-85` 双源硬判；`make test` 只跑 `test/` | **R2（首轮）已闭**：DESIGN `:35` 与 `:85` 已补第二份镜像 |
| deck 资产族 | tracked = `pptx` + `slides.json`/`deck_checks.py`/`build.py`/`layouts.py`/`theme.py`/`README.md`/`utils/*` | §0.5.1 已列 pptx/slides.json/deck_checks/README（**R7 已闭**） |
| deck 断言方式 | `deck_checks.py:49,56,60` 仍是 `items[0]/items[13]/items[19]` **位置**断言；`slides.json` 20 页 | DESIGN `:96` 已写「改为按标题寻址」→ **R6 已闭**（文本层；实现期须真改） |
| 禁动路径存在性 | 仓根 `skills/` **不存在**；真实路径 `flow-kit-bundle/skills/` 存在 | **DESIGN 漏列且判据恒真 → R11** |
| 指南在打包校验中的状态 | `flow-kit-bundle/lib/validate_staging.sh:117` `KNOWN_SKIP` 含 `/FLOW-KIT-用户指南\.md$` → `check-validate` 对指南**不做**覆盖校验 | 佐证 D2 守护域的必要性；DESIGN 未引此证据（非缺陷，属可选补强） |
| 「DESIGN 列出但未改」 | `git status`：` M .specs/CONTEXT.md`、` M flow-kit-bundle/FLOW-KIT-用户指南.md`；`.specs/user-guide-sync-2026-09b/` untracked | 无 |
| 流程状态 | `.flow-active`：`current_phase=0` / `phases_done=[]` / 七门 pending —— 而底稿 mtime **22:15:22（仍在变）** | 底稿在阶段 2 未闭合时已被持续改写 → **R9 的冻结语义缺口** |

**Verdict**: fail


---

## 主 agent 响应（阶段 2 · L2 第二轮 R9–R14 · 2026-09-21）

| # | Sev | 处置 | 动作 |
|---|---|---|---|
| R9 | 🔴 | **Fixed in: DESIGN.md D1 缓解（v3）+ D6 坐标基准（v3）** | ① 量级表述改为「**以阶段 4 重跑为准**（历史快照 2 行；22:1x 实测 65 hunks / root 独有 123 行 / bundle 独有 169 行）」并删除「hunk 数必然大于历史基线」的混淆句；② 新增**冻结点定义**：底稿冻结 = T01/T02 均 done 且 mtime 稳定 → 登记快照（HEAD/md5/行数/mtime）→ 重跑 diff；**此后底稿再被写入则上次归类作废**；③ 判据改为「每个 hunk 都能归类」，不以 hunk 数等于某值为判据；④ D6 补**坐标基准**：漂移报告行号锚点基于**仓库根副本**（报告头 1631 行），落到 bundle 底稿必须按内容检索定位、不得直接套 L 号 |
| R10 | 🟡 | **Fixed in: DESIGN.md D2 + REQUIREMENT AC-10（v3）** | installed-copy 守护域收窄为 `~/.dsh/profiles/${DSH_PROFILE:-web}/…`，与 `Makefile:136-137` 的 `DSH_PROFILE ?= web` 同源；不扫全部 profile（避免第二个装过插件的 profile 恒红且 `make dsh-sync` 修不了） |
| R11 | 🟡 | **Fixed in: DESIGN.md §0.5.1 + §2 边界（v3）** | `skills/**` → `flow-kit-bundle/skills/**`（两处），与 REQUIREMENT AC-9 及 `git diff --name-only` 验证命令同源；已核全段其余路径（`flow-kit-bundle/hooks`、`dsh-flow-kit/lib`、`flow-kit-bundle/flow-kit/prompts`）在仓根均存在 |
| R12 | 🟡 | **Fixed in: DESIGN.md D2 + REQUIREMENT AC-10（v3）** | deck 新鲜度断言补降级语义：`pptx` 缺失 **或** `python3 -c "import pptx"` 失败 → 该组**显式 SKIP 并打印原因**；§2 管线加**时序约束**「重建 pptx 必须早于任何 `make test`/`make check`」；封面日期口径统一为「== 指南版本行的日期」（断言内不再二次写死 `2026-09-21`） |
| R13 | 🟢 | **Tech-debt: MINOR-DEFERRED M6** | deck-gen README 裸 `\|` 的破表隐患登记 M6，本轮改写时顺手处理但不单列验收 |
| R14 | 🟢 | **Tech-debt: MINOR-DEFERRED M7** | `theme.py` 字体（Times New Roman / 宋体）在本机 `fc-list` 无命中 → AC-7 抽检实为**替代字体度量**，已在 MINOR-DEFERRED M7 留痕，TEST.md 记录该口径；换字体不属本 change |

**复审请求**：DESIGN.md v3 已按 R9–R12 重写（D1 冻结点与量级基准、D6 坐标基准、D2 installed-copy 域与 deck 降级/时序、§0.5.1/§2 真实路径）。R13/R14 入 MINOR-DEFERRED（M6/M7）。

---

## L2 盲审（第三轮）

**Verdict**: fail

- 审查对象：`.specs/user-guide-sync-2026-09b/DESIGN.md`（224 行 · md5 `38b55cae` · mtime 22:16:24；22:16–22:20 全程未再变更）。交叉核对（只读）：`REQUIREMENT.md`（md5 @22:20）· `TASK.md`（md5 `0cc1b703`）· `DEV-SUMMARY.md` · `CHANGE.md` · `MINOR-DEFERRED.md` · 指南四副本 · `package-dsh-plugin.sh` · `Makefile` · `test/test_guide_copy_parity.bats` · `.specs/user-guide-deck-gen/*` · `/tmp/guide-drift-report.md` · `.flow-active`。
- 独立性：**prompt 中未收到任何主 agent 自评 / 草稿 / 概述 / 辩护 → 独立性未受损**。披露：按「先读全文再追加」的写入约束只读打开了本文件（含第一/二轮 L2 段与两段主 agent 响应，属历史轮次）；本轮结论全部由 DESIGN 原文 + 仓库实测独立得出。
- **跨轮重叠披露**（避免把旧结论当新发现）：R15 与第二轮 R9 同族（本轮定位在**未被修补的第二处**，证据换成本 change 自己的 DEV-SUMMARY）；R16 与第一轮 R2 同族（本轮证据面扩到 `dist/…/README.md`、change 产物目录、`.specs/CONTEXT.md`）；R20 与第二轮 R10 同族（本轮焦点是**未同步的 TASK.md**，非 DESIGN 文本本身）。R17 / R19 / R21 为本轮新发现。
- 实测快照（只读 · 22:16:50–22:20:20。**审查期间仓库被并发改写 ≥3 次**：四副本 md5 22:18:36 `17efc398` → 22:20:03 `86057b9c`、`TASK.md` 22:18 与 22:20 两次变更）：
  - 四副本 md5 唯一值 = 1（1693 行 ×4）；仓外 `~/.dsh/profiles/web/node_modules/dsh-flow-kit/{docs,vendor}` 同哈希 = 已由 `make dsh-sync` 对齐
  - `npx bats test/test_guide_copy_parity.bats` = **6/6 ok**；`python3 deck_checks.py` = `deck_checks OK: 24 pages … 24 titles addressable` rc=0；pptx 24 页 / `slides.json` 24 页
  - 16 条 AC-2/AC-3 反例串（`grep -F`）四副本复扫 = **全 0**（22:18 时 `.flow-active.independent-review` 尚 1 命中 → 窗口内被修掉，见 R18）
  - `bash package-dsh-plugin.sh --check` rc=0；`git diff --name-only -- flow-kit-bundle/hooks dsh-flow-kit/lib flow-kit-bundle/skills flow-kit-bundle/flow-kit/prompts` = 0；`git ls-files dist` = 0；`diff -rq test/ flow-kit-bundle/test/` rc=0
  - `.flow-active`：`current_phase=0` / `phases_done=[]` / 七门 pending —— 而 T01–T06 的产物已落盘（DEV-SUMMARY 22:17、新 bats 22:17、pptx 22:17）。账本与工作树不一致，非 DESIGN 文本缺陷，登记备查
- 未复核（无判据 · 显式标注）：漂移报告 43 条的逐条事实（本轮仅核 §0 头部、§8/§11 分布行与坐标基准）；AC-6/AC-7 的注入与渲染结论（`TEST.md` 尚未产出）。

---

### 🔴 R15 · §4 R2 的「本轮实测仅 2 行方向性差异」与同文档 D1 及本 change 的 DEV-SUMMARY 相差 ≈62 倍 —— 第二轮 R9 的修补只落在 D1

**Severity**：🔴 Critical
**Symptom（症状）**：`DESIGN.md:186`（R2 缓解）写「覆盖前 `diff` 双向核对并留证据（**本轮实测仅 2 行方向性差异**）」，并把该风险概率评为「低」；`DESIGN.md:69`（D1 理由）同样以「根副本落后 2 行」作现状陈述。而同文档 `DESIGN.md:73`（D1 缓解 · v3）已写「本轮修订期实测 **65 hunks / root 独有 123 行 / bundle 独有 169 行**」；本 change 自己的 `.specs/user-guide-sync-2026-09b/DEV-SUMMARY.md:59` 记录覆盖前归类 = **125 行 root-only / 187 行 bundle-only**。同一文档对同一实测事实的两处口径比 = 2 : 125（≈62×）。第二轮 L2 R9（🔴）的处置声明为「Fixed in: DESIGN.md D1 缓解（v3）+ D6 坐标基准（v3）」——§4 风险表这一行未被触碰。
**Source（源头）**：`DESIGN.md:214-218`（§7 自述「所有『既有模块』均来自实测命令…证据见 §0.5.1」= 全文档引用须可复核）；L-031 通用必查项（一次修订必须扫**全部同串落点**，只改一处 = 漏改类）；REQUIREMENT AC-5 Given（「执行开始时先记录四份快照…作为基线证据」= 量级本身是设计输入）。
**Consequence（后果）**：R2 是「覆盖根副本」这一不可逆动作在 DESIGN 里的唯一风险条目，其**概率值**与缓解措辞都建立在已被实测证伪的量级上（0.016×）。按 `:186` 复核的实现者不会预期 125 行 root-only 内容；而 `DEV-SUMMARY.md:59` 只给「全部归为根旧 / bundle 新」的结论、不附逐 hunk 清单，复核者无法从 DESIGN 侧得知该结论需按 125/187 的规模检查。另：漂移报告的行号锚点（`L65-66`、`L1380` 等）在底稿 +62 行后已位移，DESIGN 只在 D6（`:115`）声明了坐标基准，R2 未引用该约束。**偏差不会被本 change 新增的任何守护发现**（四副本断言比对的是同步**之后**的结果）。
**Remedy（修补）**：① `DESIGN.md:186` → 「覆盖前 `diff` 双向核对并留证据（量级以阶段 4 重跑为准：漂移报告快照期 2 行；本轮实测 **125 行 root-only / 187 行 bundle-only**，逐条归类见 DEV-SUMMARY T04）」；② `DESIGN.md:69` 的「根副本落后 2 行」加限定词「漂移报告快照期（2026-09-21 22:11 前）」；③ R2 缓解末补一句指向 `DEV-SUMMARY.md:50-59` 的归类证据。**本项为纯文本修正，不推翻任何阶段 4 已完成动作**（归类已执行并留痕，实际未造成信息损失）。

### 🟡 R16 · R6 白名单与 AC-9 不一致且不完整：漏第二份 bats 镜像 / `dist/…/README.md` / change 产物目录 / `.specs/CONTEXT.md`（后者已实际改写 20 行）

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:190`（R6 缓解 = AC-9 的越界判据）写白名单「…pptx、**1 个新 bats 文件**）；越界即失败」。逐项对账（22:20 实测）：① `flow-kit-bundle/test/test_guide_copy_parity.bats` 已于 22:17 落盘（`diff -rq test/ flow-kit-bundle/test/` rc=0）—— §0.5.1`:35` 已列两份，R6 仍写 1 个；② AC-9 白名单（`REQUIREMENT.md:167-173`）含 `dist/dsh-flow-kit/README.md`（本轮已窄路径再生，`DEV-SUMMARY.md` T04 记录 `cp dsh-flow-kit/README.md dist/…`），R6 只写「两份 README」；③ AC-9 含 `.specs/user-guide-sync-2026-09b/**`（本轮必然变化：本文件、DEV-SUMMARY、`render-preview/*.png`、`verify-ac.sh`），R6 未列 —— 按 R6 字面，change 自身产物即「越界即失败」；④ `.specs/CONTEXT.md` 实际已改（`git diff --stat` = **20 insertions**，块首尾均带 `user-guide-sync-2026-09b` 标记，DESIGN §9`:224` 亦自述「已写入 CONTEXT.md 术语表」），而 §0.5.1`:26-36`「会修改（既有）」与 R6 均未列，AC-9 白名单也不含该路径 → AC-9 的机械判据（`git diff --name-only` vs 白名单）在**当前工作树上必然 fail**。
**Source（源头）**：L-031 通用必查项（DESIGN 写入清单必须覆盖真实 `git diff`）；`REQUIREMENT.md:167-173`（AC-9 白名单原文）；`DESIGN.md:35`（§0.5.1 已按第一轮 R2 补第二份镜像 —— 修补未同步到 R6）。
**Consequence（后果）**：① AC-9 是本 change「纯文档边界」唯一的机械门禁，R6 版白名单同时（a）把本 change 自己的产物判越界、（b）放过真实存在的 `.specs/CONTEXT.md` 改写 —— 判据两向都错；② 阶段 5/7 若照 R6 执行边界核对，只能得到一个人工解释才能通过的结论，正是 D2/AC-10 要消灭的「判据不可机械复算」形态；③ 第一轮 R2 的同类修补（只改 §0.5.1、未改白名单）已复发一次。
**Remedy（修补）**：R6 白名单改为与 AC-9 同源的一行（或直接写「白名单 = REQUIREMENT AC-9 的列表，不在此复述」）；对 `.specs/CONTEXT.md` 必须显式二选一并写进 DESIGN：纳入白名单（连同 AC-9 一起改），或写明「框架级架构沉淀产物，不在 AC-9 比对域」+ 给出比对命令的排除规则。

### 🟡 R17 · §0.5.2「沿用既有抽象」表把 bundle→dist docs 的映射写成 `COPY_FILES` —— 真实标识符是 `COPY_OPTIONAL`

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:51` 写「`package-dsh-plugin.sh:45` 的 **`COPY_FILES`** 映射（bundle → dist docs）+ `rsync` 打包 | **沿用**」。实测 `package-dsh-plugin.sh`：`:44-48` 的 `COPY_OPTIONAL=( "$BUNDLE_DIR/FLOW-KIT-用户指南.md:$PKG_DIR/docs/FLOW-KIT-用户指南.md" … )` 才是指南映射（`:45` 即该行）；`:38-43` 的 `COPY_FILES` 是 `$SRC_DIR`（`dsh-flow-kit/`）→`$PKG_DIR` 的 4 个顶层文件（`package.json` / `cordis.patch.yml` / `README.md` / `DESIGN.md`），与「bundle → dist docs」无关；`:27-28` 注释明确区分「必需（COPY_DIRS/COPY_FILES）」与「可选（COPY_OPTIONAL）」。
**Source（源头）**：`DESIGN.md:44-53`（§0.5.2 表的自述用途 = 证明「既有有没有」→ 防重复实现）；`DESIGN.md:217`（§7 声称这些引用「均已 `grep`/`read` 验证存在，未引用任何未验证的路径或抽象」）；ADR-019（具体、可验证）。
**Consequence（后果）**：该表是实现者「沿用哪条既有映射」的入口判据，误名会把沿用目标指向另一组变量：按 DESIGN 文本抄 `COPY_FILES` 得到的映射**不含指南**。`TASK.md:164` 用的是 `COPY_OPTIONAL`（正确）→ DESIGN 与 TASK 在此互相矛盾，任何一侧作复核基准都会把另一侧判错。
**Remedy（修补）**：`DESIGN.md:51` 的 `COPY_FILES` → `COPY_OPTIONAL`（`package-dsh-plugin.sh:44-48`，`:45` 为指南行）；`:32` 的同款引用保持同一写法。

### 🟡 R19 · §6 的 AC-4 承载行指向不存在的小节：DESIGN 全文没有 N1–N11 的归属

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:205` 写「| AC-4 候选新增 N1–N11 | D6 + **§1 各条归属小节** |」。全文（md5 `38b55cae`）`grep -n "N1…N11"` **仅命中该行本身**；§1（`:64-126`）是 D1–D7 决策清单，D3 只列 deck 的 4 张新专页 —— 均无 N1–N11 的落点。而 AC-4（`REQUIREMENT.md:96-115`）逐条指定了归属小节（§7「L3 凭证」/ §7「配置文件」/ §2.4 / §4 子命令表 / §7 PreToolUse 表 / §7「独立 Review 机制」/ §12）与用户可见 grep 串，另附 N1 的安全反例。
**Source（源头）**：`REQUIREMENT.md:96-118`（AC-4 归属表与安全反例）；`DESIGN.md:199-213`（§6 的存在意义 = AC ↔ 设计决策双向可追溯）；ADR-019。
**Consequence（后果）**：AC-4 的 11 条候选新增 + 安全反例在 DESIGN 层没有可追溯承载，阶段 5 核对只能回退 `TASK.md` 附录 A；且「§1」在本文档内指决策清单，读者会去找一个不存在的小节。实测 11 串当前全部 ≥1 命中（`FLOW_KIT_L3_AUTH_TOKEN` 2 · `max_artifact_bytes` 1 · `check-dist` 1 · `verify-claims` 1 · `/flow l2-review` 1 · `runtime-edit-guard` 2 · `path-guard` 3 · `ADR-025` 1 · `ADR-026` 1 · `make dsh-sync` 3 · `DSH_PROFILE` 1）——即产物与 DESIGN 的表述无关，判据与产物各走各的。
**Remedy（修补）**：`:205` 改为「D6 + `TASK.md` 附录 A 的 N1–N11 断言表（归属小节见 REQUIREMENT AC-4）」；若要 DESIGN 自洽，补一张 11 行的 N → 指南小节 映射表（可直接搬 AC-4 表）。

### 🟡 R20 · DESIGN v3 的 installed-copy 守护域收窄未同步到 TASK.md（下游仍写 `profiles/*` 通配，实现已按 DESIGN 走）

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:86`（v3 · L2 R10）把守护域收窄为 `~/.dsh/profiles/${DSH_PROFILE:-web}/node_modules/dsh-flow-kit/{docs,vendor}/FLOW-KIT-用户指南.md`（与 `Makefile:133-134` 的 `DSH_PROFILE ?= web` 同源）。实测**实现跟的是 DESIGN**：`test/test_guide_copy_parity.bats:149` = `local prof="${DSH_PROFILE:-web}"`。而 `TASK.md`（md5 `0cc1b703` · 22:20）`:241` 仍写「`~/.dsh/profiles/*/node_modules/…` **存在时**必须与 dist 一致」；`:238` 仍写用例 2 = 「版本行 = 分节日期 = **期望日期常量**」，而 `DESIGN.md:87` 明确「口径统一为『与指南版本行同名日期』，**不在断言里二次写死** `2026-09-21`」。
**Source（源头）**：L-031 通用必查项（修订某口径后，**所有读取该口径的工件必须同步**；典型场景即「新增字段名 → 所有读取方同步」）；`DESIGN.md:86` 与 `TASK.md:241` 是同一断言的两种规格。
**Consequence（后果）**：DESIGN（阶段 2）与 TASK（阶段 3）对同一守护给出**不同域**：按 TASK 字面重做/复核该用例会重现 R10 的恒红缺陷（第二个装过插件的 profile 永远对不齐、`make dsh-sync` 修不了）；反向，以 TASK 为准审查实现，会把正确的 `${DSH_PROFILE:-web}` 判为不符。TASK 的阶段 3 L2（`INDEPENDENT-REVIEW-3.md`，22:11–22:18）在 DESIGN v3（22:16:24）之前完成，该差无人覆盖。
**Remedy（修补）**：`TASK.md:241` 的通配改 `${DSH_PROFILE:-web}`，并在 T06 的 done 条件写同一域；`TASK.md:238` 按 `DESIGN.md:87` 改为「版本行 == 分节日期（不二次写死日期）」——或反向在 DESIGN 里承认三处常量断言，二选一，不留双规格。

### 🟢 R18 · AC-2 D21 的「零命中」断言未定义「已废弃」说明句的豁免口径（实例已在审查窗口内消失）

**Severity**：🟢 Minor
**Symptom（症状）**：AC-2（`REQUIREMENT.md:62`）规定 D21 反例 `.flow-active.independent-review` 在四份副本 **0 命中**且「反例一律用 `grep -F` 字面匹配」。22:18 实测 `flow-kit-bundle/FLOW-KIT-用户指南.md:987` = **1 命中**（原句：「旧版方案里的 `.flow-active.independent-review` 握手文件已废弃」，属合法说明句）；22:19–22:20 复测该串在四份副本均 0 —— 窗口内被改写闭合，故**当前无现存违规**。DESIGN 侧 D6（`:113-119`）与 §6（`:204`）把 AC-2/AC-3 映射为「逐条映射到断言表」，未定义「反例串只出现在『已废弃』说明句」时的处置，而 AC-1（`2026-09-03` 历史锚点）与 AC-3（`max_failures_before_bypass`）都已有同类白名单机制。
**Source（源头）**：`REQUIREMENT.md:50`（「反例一律用 `grep -F` 字面匹配」）+ `REQUIREMENT.md:27` / `:76`（AC-1/AC-3 的既有豁免范式）；ADR-019。
**Consequence（后果）**：下一轮同族改写（任何「旧机制已废弃」的说明句）会让该机械断言不可解释地变红，或诱发事后改口径 —— 即 D2/D3 要消灭的「断言与成品不同步」。
**Remedy（修补）**：D6 补一句口径：「反例断言的对象是**用户可见的旧口径措辞**；『旧机制已废弃』说明句如必须命名旧串，登记进 TEST.md 豁免白名单（与 AC-1 的 `2026-09-03`、AC-3 的 `max_failures_before_bypass` 同处理）」。按 ADR-017 记入 `MINOR-DEFERRED.md`，不入 fix loop。

### 🟢 R21 · §7「证据链」三处引用不实：哈希已不存在 / `Makefile:6` 是空行 / `Makefile:136-137` 位移 3 行

**Severity**：🟢 Minor
**Symptom（症状）**：`DESIGN.md:216` 写「证据见 §0.5.1 **行号与哈希**」，而 §0.5.1（`:24-42`）自 v2 起已按第一轮 R1 明确「基线为执行时快照，**不写死 md5/行数**」——全文无任何哈希；`:217` 把 `Makefile:6` 列为「已 `grep`/`read` 验证存在」的第 4 个引用，实测 `Makefile:6` 是**空行**（`.PHONY` 在 `:5`，六门 `check:` 在 `:106`），且 DESIGN 全文再无 `Makefile:6` 的实质引用（自我指涉）；`:86` 引「`Makefile:136-137` 的 `DSH_PROFILE ?= web`」，实测该变量在 `:133`（`:136-137` 是 `dsh-sync: check-dist` 与其 echo 行）。同款误引已存在于 `REQUIREMENT.md:183`。
**Source（源头）**：`DESIGN.md:214-218`（§7 的存在意义 = R6.1 证据链可复核）；ADR-019（具体、可验证）。
**Consequence（后果）**：§7 是弱模型据以信任 DESIGN 全部引用的唯一入口；三处引用中两处指向空行/错行、一处指向已删除的字段，「未引用任何未验证的路径或抽象」这句自证失效（`COPY_FILES` 误名即同一失效的实例，见 R17）。
**Remedy（修补）**：`:216` 删「与哈希」；`:217` 的 `Makefile:6` 改 `Makefile:106`（六门）或删除；`:86` 的 `Makefile:136-137` 改 `Makefile:133-134`（`REQUIREMENT.md:183` 同改）。按 ADR-017 记入 `MINOR-DEFERRED.md`。

---

### L-031 锚点扫描（独立全仓 · 不信 DESIGN §0.5.1 清单）

| 锚点 | 全仓命中（实测 · 22:16–22:20） | 分类 |
|---|---|---|
| 指南四副本载体 | `md5sum` 四路径唯一值 = 1（22:18 `17efc398` → 22:20 `86057b9c`，均 1693 行）；仓外 `~/.dsh/profiles/web/…/{docs,vendor}` 同哈希 | §0.5.1`:27-32` + D2`:86` 已列全 → 无漏 |
| 实际改动面 vs DESIGN 写入清单 | `git status`：` M .specs/CONTEXT.md` · `slides.json` · `build.py` · `deck_checks.py` · `.specs/user-guide-deck-gen/README.md` · 根指南 · `README.md` · `dsh-flow-kit/README.md` · bundle 指南 · `pptx`；`?? .specs/user-guide-sync-2026-09b/` · `test/test_guide_copy_parity.bats` · `flow-kit-bundle/test/test_guide_copy_parity.bats` | 「列出且已改」= 除 CONTEXT.md 外全部（含 pptx / deck 生成器 / dist README 窄路径再生）；「**漏列但已改**」= `.specs/CONTEXT.md`（20 insertions）→ **R16**；「列出但未改」= 无；「漏列且未改」= 无 |
| 副本守护接线 | `grep -rn "用户指南" Makefile verify-claims.sh` = **0**；新用例由 `npx bats test/` 目录收集（实跑 6/6 ok） | D2 的「落测试层、不进门禁」已按设计落地 → 无「列出未改」 |
| AC-2/AC-3 反例锚点（16 串） | 四份副本 `grep -F` 全 = 0（22:18 时 `.flow-active.independent-review` = 1） | 窗口内自愈 → **R18**（仅口径缺口，无现存违规） |
| 禁动路径存在性 | 仓根 `skills/` **不存在**；`flow-kit-bundle/{skills,hooks,flow-kit/prompts}`、`dsh-flow-kit/lib` 均存在；`git diff --name-only -- <四条禁动路径>` = **0** | DESIGN`:39` v3 已修正 → 第二轮 R11 闭合 |
| 引用行号有效性 | `package-dsh-plugin.sh:45` ✓（`COPY_OPTIONAL` 内）· `test_l3_pipeline_fix.bats:548` / `:561` ✓ · `Makefile:136-137` ✗（→ `:133-134`）· `Makefile:6` ✗（空行） | → **R21**；`COPY_FILES` 误名 → **R17** |
| deck 资产族 | pptx（24 页 · tracked）· `slides.json`（24）· `deck_checks.py`（`by_title` 寻址 · rc=0）· deck-gen `README.md`（`:28` 日期已改 `2026-09-21`、禁词表已扩）· `build.py` 已改 · `layouts.py`/`theme.py`/`utils` 未改 | §0.5.1`:30` 已列；R6/R7（第一轮）闭合，无漏项 |
| N1–N11 锚点 | 11 串全部 ≥1 命中（见 R19 Consequence） | 产物达标，但 DESIGN 层归属缺失 → **R19** |
| 流程状态 | `.flow-active`：`current_phase=0` / `phases_done=[]` / 七门 pending；而 DEV-SUMMARY（22:17）、新 bats（22:17）、pptx（22:17）、render-preview/*.png（22:17）均已落盘 | 账本与工作树不一致（非 DESIGN 文本缺陷，登记备查） |

**Verdict**: fail

---

## 主 agent 响应（阶段 2 · L2 第三轮 R15–R21 · 2026-09-21）

| # | Sev | 处置 | 动作 |
|---|---|---|---|
| R15 | 🔴 | **Fixed in: DESIGN.md §4 风险表 R2 行（v4）** | 删去「本轮实测仅 2 行方向性差异」的过期判据，改为「**量级以阶段 4 重跑为准**（历史快照 2 行；本轮实测 125 行 root-only / 187 行 bundle-only，归类结论见 `DEV-SUMMARY.md` 的 T04 段）」——承认第二轮只改了 D1、漏改 §4（L-031 类漏改） |
| R16 | 🟡 | **Fixed in: DESIGN.md §4 风险表 R6 行（v4）+ REQUIREMENT AC-9（v4）** | R6 白名单改为「**= REQUIREMENT AC-9 的列表（不复述）**」，判据换 `git status --porcelain` + `git ls-files -o --exclude-standard`；AC-9 白名单已补 `.specs/CONTEXT.md`、`.specs/{CHANGELOG,STATE,LESSONS}.md`、`dist/.../test/*.bats`，并声明 dist 其余再生件由 `make check-dist` 守护 |
| R17 | 🟡 | **Fixed in: DESIGN.md §0.5.2（v4）** | `COPY_FILES` → **`COPY_OPTIONAL`**（`package-dsh-plugin.sh:44-48`），与 TASK 口径一致 |
| R19 | 🟡 | **Fixed in: DESIGN.md §6 验收映射（v4）** | AC-4 承载行改为「D6 + **REQUIREMENT AC-4 的归属表** + TASK 附录 A 的 N 断言表」，不再指向不存在的「§1 各条归属小节」 |
| R20 | 🟡 | **Fixed in: TASK.md T06 action（v4）** | ① installed-copy 守护域改为 `~/.dsh/profiles/${DSH_PROFILE:-web}/…`（与 `Makefile:133-134` 同源，删掉 `profiles/*` 通配）；② 用例 2 的「期望日期常量」改为「两处相等、不二次写死日期」（与 DESIGN D2 同口径）；③ 失败信息附 `make dsh-sync`（不得建议 `cp` 运行时副本） |
| R18 | 🟢 | **Tech-debt: MINOR-DEFERRED M9** | D21「已废弃说明句」的豁免口径缺口（实例已在窗口内自愈）→ 登记 M9 |
| R21 | 🟢 | **Tech-debt: MINOR-DEFERRED M10** | DESIGN §7 证据链三处引用不实（`§0.5.1 行号与哈希`、`Makefile:6` 空行、`Makefile:136-137` 应为 `133-134`）→ 登记 M10，本轮已顺手修正 `Makefile:133-134` 一处（其余按 Minor 处理） |

**复审请求**：DESIGN v4 已按 R15–R20 重写，TASK T06 同步 v4 口径。R18/R21 入 MINOR-DEFERRED（M9/M10）。

---

## L2 盲审（第四轮）

**审查对象**：`.specs/user-guide-sync-2026-09b/DESIGN.md` 当前现状（224 行，sha256 前 8 位 `38c465eb`，mtime `22:24:33`）。
**独立性声明**：本节结论全部由本轮独立复算得出——对 DESIGN 每条可判定断言做全仓实测，未采信任何主 agent 自评、草稿、概述或历史轮次结论；仓库内既有 `## 主 agent 响应` 段与本文档既有轮次仅为会话记录，不作为本轮判据。
**本轮实测基线（供复核）**：四份指南 md5 唯一值 = 1；`deck_checks.py` rc=0（24 页）；`bash package-dsh-plugin.sh --check` rc=0；`test/test_guide_copy_parity.bats` 6/6 绿；全量 bats **971 例**（新增 6 例，基线 965 无删除）；`verify-boundary.sh` rc=0，禁动域 diff = 0；`time md5sum <四路径>` real = 0.002s（NFR < 1s 成立）。

### 🟡 R22 · DESIGN 的「会修改 / 会新增」清单不完整，且未处置同产物竞写者（L-031 漏改类）

**Severity**：🟡 Important
**Symptom（症状）**：`DESIGN.md:26-36` 的「会修改（既有）」清单 vs 实测工作区变更集（`git -c core.quotepath=false status --porcelain`）差异三类：
- **漏列但已改**：`dsh-flow-kit/README.md` 未出现在「会修改」清单（只以「README.md、dsh-flow-kit/README.md — 口径核对与连改」一句带过，但未登记其 dist 侧再生件 `dist/dsh-flow-kit/README.md`）、`.specs/user-guide-deck-gen/build.py`（清单写「必要时 build.py」= 条件式，实测已改）……
- **既未列会改、也未列禁动**：`tools/pptx-light-sync.py`（tracked，非 `.specs/archive/**`）。该脚本硬编码 `PPTX = "~/unisoc/flow-kit/flow-kit-用户指南.pptx"`（`tools/pptx-light-sync.py:14`），docstring 声明「验证 slide 数 = **19**」「slide 1 日期 **2026-07-13 → 2026-07-24**」（`:2-5`、`:55-57`），与实际 24 页 / `2026-09-21` 完全脱节；它是**与 `build.py` 争写同一受版本控制的交付产物**的历史入口，DESIGN 全篇未登记其存在性、归属与处置。
- **未列会新增**：`.specs/user-guide-sync-2026-09b/` 下实测存在 `verify-boundary.sh`、`check-appendix-superset.py`（均为本轮新增脚本，`ls -la` 可见），DESIGN §0.5.1「会新增」只写了 bats ×2 + `render-preview/*.png`。
> **反向核对（本轮无漏改）**：AC-9 白名单逐条手算全部命中、无越界项；`flow-kit-bundle/test/test_guide_copy_parity.bats` 与 `test/` 全等，`make check-test-sync` 通过；禁动域 `git diff --name-only -- flow-kit-bundle/hooks dsh-flow-kit/lib flow-kit-bundle/skills flow-kit-bundle/flow-kit/prompts | wc -l` = 0。

**Source（源头）**：L-031 教训（DESIGN §0.5.1 触碰模块清单不完整 → 按清单执行者漏改）+ `ADR-019` 写作原则（图表/清单须引用可验证产物）+ 本仓「单一维护源」原则（同一交付产物不得有两个并存写入者，见 `CONTEXT.md` 的 `sync-hooks.sh`／`HOOK_MODULE_NAMES` 单一源范式）。
**Consequence（后果）**：本轮后果可控（`deck_checks.py` 页数断言 + 新 deck 新鲜度用例都可捕捉竞写结果），但**定级偏乐观**：`tools/pptx-light-sync.py` 是仓库内可见、可直接执行、且 README 世代相传的「同步 pptx」入口——任何人（含后续 change 的弱模型）按原名检索并执行它，会就地重写受版本控制的 `flow-kit-用户指南.pptx`（并留下 `.bak`），把本轮重建成果打回 19 页口径；清单缺项同时会让下一次 change 的「触碰模块」分析继承这份不完整基线，属同一失效模式的复发条件。
**Remedy（修补）**：① §0.5.1「会修改（既有）」按实测补全，并把条件式改为事实式：`dsh-flow-kit/README.md` + `dist/dsh-flow-kit/README.md`（窄路径再生）、`.specs/user-guide-deck-gen/build.py`（本轮已改）；② 显式处置竞写者——推荐在 §5「不在范围内」加一行并同步 CONTEXT 术语表：

```
- `tools/pptx-light-sync.py`（2026-07-24 一次性补丁脚本，硬编码 path / 19 页 / 2026-07-24）：
  已由 `.specs/user-guide-deck-gen/` 声明式生成器取代 → 本轮**不执行、不修改**；
  长期处置 = 删除或在文件头加 `# DEPRECATED（2026-09-21）：请改用 build.py + deck_checks.py`。
```

③「会新增」补 `.specs/<id>/verify-*.sh`、`.specs/<id>/check-*.py`（同源证据脚本，白名单前缀已覆盖）。
**主 agent 处置**：Fixed in / Tech-debt: / Not-applicable:

### 🟡 R23 · 「deck 新鲜度」守护只覆盖页数与封面日期，正文漂移不受守护——正是 D2 声称要守的失效形态

**Severity**：🟡 Important
**Symptom（症状）**：`test/test_guide_copy_parity.bats:104-124` 只断言 `pptx 页数 == len(slides.json)` 且 `封面日期 == 指南版本行日期`；`DESIGN.md:87` 声称这「是与 md 副本同构的失效形态（改 `slides.json` 忘重建 pptx 无人发现）」。**实测证伪该覆盖**：只改写内容页文字（不动页数、不动封面）后，既有断言手法的等价复算结果仍是 `pages == 24 ? True`、`cover date == 2026-09-21 ? True`（实验产物 `/tmp/L2v4/flow-kit-用户指南.pptx`，3 处形状被替换为「已被就地改写的过期措辞」）。即 D3 的 4 张新专页里任何一句正文被改错/回滚而未重建，守护**全绿**。
**Source（源头）**：AC-10 的「断言**真的会被跑到**且**非恒绿**」要求 + `ADR-027`（门禁只提高可见性）的反向含义——**看不见的漂移不因门禁存在而可见**；本仓既有 `test_l3_pipeline_fix.bats:548` 的范式是 md5 级比较，非「计数级」。
**Consequence（后果）**：deck 与指南正文逐轮分叉且无声（deck 的 `KEY_STRINGS`/`BANNED` 全在**未进门禁**的 `deck_checks.py` 里，`Makefile` 无任何 target 调它；`grep -n 'pptx\|deck' Makefile` 无命中）。爆点：下一次 change 只改 md 不改 `slides.json`/deck → 演示材料与文档不同口径，而 `make check` 6 门全绿（与 5583e2a 的 root↔bundle 静默漂移同构）。
**Remedy（修补）**：把守护从「计数级」提升到「内容级」，用**已存在的**比较函数即可（无需新依赖）：在 `test/test_guide_copy_parity.bats` 增加一条用例，把 deck 文本指纹与 `slides.json` 派生期望值比较——

```python
# deck 侧：slide_texts() 已存在于 deck_checks.py，可直接复用
import deck_checks as dc, hashlib
h = hashlib.sha256("\n".join(t for _, t in dc.slide_texts()).encode()).hexdigest()
# 期望值 = build.py 从 slides.json 渲染出的同一文本（或：把 deck_checks.py 的
# KEY_STRINGS/BANNED 断言集搬进该 bats 用例，使「改了 slides.json 没重建」必红）
```

最小可行版：`python3 .specs/user-guide-deck-gen/deck_checks.py` 的 rc 纳入该 bats 用例（D2 已论证「不新增 Makefile target」，但**调用既有脚本**不违反 D2 的结论）——当前实测指纹 `deck textual sha256[:16] = 185c8a86e88206ab` / `slides.json sha256[:16] = 72f05ea95134cbed`，可直接作为回归基准。
**主 agent 处置**：Fixed in / Tech-debt: / Not-applicable:

### 🟢 R24 · deck 页数口径三处不一致：`EXPECT_PAGES=24`（等值）严于 AC-6 / CONTEXT / NFR 的「≥24（净增 ≥4）」

**Severity**：🟢 Minor
**Symptom（症状）**：`.specs/user-guide-deck-gen/deck_checks.py:23` 为 `EXPECT_PAGES = 24`，`:53` 为 `assert len(items) == EXPECT_PAGES`；而 `DESIGN.md:91`（D3 标题「20 → 24 页（净增 4）」）、`DESIGN.md:94`（措辞为「选 (b) 的 4 页」）与上游 `REQUIREMENT.md:134`（AC-6「页数 ≥ **24**（净增 ≥4）」）、`CONTEXT.md:643`（「净增 ≥4」）口径为下限式；`TASK.md:355-360` 的 deck 断言表写的是「`EXPECT_PAGES` | ≥ 24」——**与文件实际值不等**。
**Source（源头）**：`ADR-019` 写作原则（范围决策属 DESIGN，且须单一事实源）+ 本仓「断言不得严于 AC」的既有口径（门禁判据与 AC 对齐，见 `ADR-027` 与 health-fix 的「判据过窄/过宽」教训）。
**Consequence（后果）**：留下一个**假红**引信——将来按 AC-6 合规地加到 25 页，`deck_checks.py` 与用例 4 会失败，而 AC 本身是满足的；判据与 AC 的偏差没有任何一处文字承认它是**有意收窄**。当前不产生任何错误结论（24 == 24），故不阻塞。
**Remedy（修补）**：二选一并只留一处事实源——(a) 判据改下限：`assert len(items) >= EXPECT_PAGES`，`EXPECT_PAGES = 24` 语义改为「下限」；(b) 若确要「本轮恰好 24」，则在 D3 与 TASK 断言表写明「`EXPECT_PAGES` 为**等值断言**，与 AC-6 的 ≥24 刻意不同，理由=…」，避免下游按 TASK 表（≥24）实现出不一致判据。
**主 agent 处置**：Fixed in / Tech-debt: / Not-applicable:

### 🟢 R25 · `guide_parity_ok` 的「存在副本 < 2 份 ⇒ 返回 0」是真空通过分支，AC-10 的硬要求「root ↔ bundle 永远执行」在代码里没有对应的显式断言

**Severity**：🟢 Minor
**Symptom（症状）**：`test/test_guide_copy_parity.bats:37` `[ "${#present[@]}" -ge 2 ] || return 0`；`:72-74` 仅在 dist 缺席时 `echo NOTE`。用例 1 因此存在「0 份或 1 份存在 → 直接通过」的真空绿路径。实测用例 4（deck）与用例 6（installed）已有 `skip` 语义，用例 1 没有。
**Source（源头）**：AC-10「`root ↔ bundle` 这条边**永远执行**」+ 本仓既有范式 `test_l3_pipeline_fix.bats:561`（`when present` + `skip`，不是静默 return 0）+ 恒绿防范（`ADR-027`）。
**Consequence（后果）**：真被触发时（仓库处于半拷贝状态，例如 `cp` 中断/子集导出——恰是 `validate_staging.sh:117` 明确允许 `FLOW-KIT-用户指南.md` 被 skip 的形态），守护静默通过，人看到的是 6 个绿点。
**Remedy（修补）**：在用例 1 内加一条前置断言，把「应有几份」显式化：

```bash
[ -f "$REPO_ROOT/flow-kit-bundle/$GUIDE_NAME" ] || { echo "bundle 副本缺失——root↔bundle 边无法执行"; return 1; }
# 或对 present < 2 的情况改用 skip "仅 N 份副本存在，无比较对象"（与用例 4/6 同语义）
```

**主 agent 处置**：Fixed in / Tech-debt: / Not-applicable:

### 🟢 R26 · deck 产物字节级不可复现（zip entry 时间戳入档），受版本控制的 pptx 每次重建必然产生二进制 churn

**Severity**：🟢 Minor
**Symptom（症状）**：连续两次 `python3 .specs/user-guide-deck-gen/build.py` 产物**逐字节相同**（md5 `1ea3aa1d07bad7b4…`，两次一致），但与重建前的受控版本 md5 `604354c46f01c825…` 不同；解包对比 **84 个 entry 全部逐字节相同**（`diff -rq` 无输出），差异只在 zip 元数据：`zipfile.ZipFile(...).infolist()[0].date_time` = `(2026,9,21,22,27,2)`（旧）vs `(2026,9,21,22,30,58)`（新），所有 entry 共享该单一时间戳。故「产物内容可复现」成立，「文件字节可复现」不成立。
**Source（源头）**：DESIGN §7 证据链要求（引用可验证产物）+ 本仓对**受版本控制的生成物**的既有期待（`FLOW-KIT-用户指南.md` 四副本用 md5 判等——同法不能用于 pptx）。
**Consequence（后果）**：`git status` 恒显示 `M flow-kit-用户指南.pptx`，二进制 diff 无法人工复核「内容是否真的变了」；runbook（`build.py` → commit）会把无内容变化的 churn 一起提交，长期掩盖真实内容变更。当前不影响任何 AC。
**Remedy（修补）**：二选一——(a) `build.py` 收尾时用固定时间戳改写 zip（normalize）：`SOURCE_DATE_EPOCH=0` 语义的重写，或改用 `python-pptx` 保存后以 `zipfile` 重打包并把所有 `date_time` 置为常量；(b) 在 `.specs/user-guide-deck-gen/README.md` 写明「pptx 为不可复现二进制，复核看 `deck_checks.py` + 内容指纹（`185c8a86e88206ab`）而非字节 diff」，把复核方式固化成可执行指令。
**主 agent 处置**：Fixed in / Tech-debt: / Not-applicable:

---

**本轮无 🔴 Critical。** 已实测闭合的项（本轮独立复算，非引用他人结论）：四份副本 md5 唯一值 = 1（AC-5）；`check-dist` rc=0（AC-5 后段）；AC-9 白名单逐条 ⊆ 且禁动域 diff = 0；`deck_checks.py` 24 页 + BANNED 双查（deck 文本 + `slides.json` 源文本）rc=0（AC-6）；新守护 6 用例全绿且含两组「注入→变红」夹具（AC-10 非恒绿）；全量 971 例无退化；`time md5sum` 0.002s（NFR）。

**Verdict**: pass

**第四轮复审请求**：R22–R26 全为 🟡/🟢，不阻塞 toll-gate。建议优先处置 **R23**（唯一一条会让「本轮已验证的证明链」失效的缺口：它使 AC-6/AC-7 的成品断言留在门禁之外，deck 内容漂移无声）与 **R22 的 `tools/pptx-light-sync.py` 归属**（唯一一条会**反向覆盖**本轮成果的入口）。R24–R26 可按 Severity Gating 入 `MINOR-DEFERRED.md`。

---

## 主 agent 响应（阶段 2 · L2 第四轮 R22–R26 · 2026-09-21）

> 本轮 **Verdict: pass** —— 首个通过的设计审查。以下为 🟡/🟢 的处置（按 Severity Gating 均不阻塞 toll-gate）。

| # | Sev | 处置 | 动作 |
|---|---|---|---|
| R22 | 🟡 | **Fixed in: DESIGN §5「不在范围内」+ MINOR-DEFERRED M16** | ① 在 §5 显式登记竞写者 **`tools/pptx-light-sync.py`**（docstring 声明「19 页 / 2026-07-13→07-24」且硬编码本机路径，执行会就地重写受版本控制的 pptx）→ 本轮**不执行、不修改**，建议 v2 加 DEPRECATED 头；② §0.5.1 清单完整性缺口登记 M16（change 目录脚本在 AC-9 白名单前缀内，不影响边界判据） |
| R23 | 🟡 | **Fixed in: `test/test_guide_copy_parity.bats` 新增用例 8 + TEST.md** | ① 把 `deck_checks.py` 的**全部**断言接进 `make test`（进而 `make check`）——此前它确实不在任何门禁里（你的实测成立）；② 新增 **title 级内容一致性**：`slides.json` 的每页标题必须出现在 pptx 文本中。**注入实测**：改第 21 页标题 → 用例 8 `not ok`（`titles=24 missing=1` + `MISSING: …`）→ 还原复绿；③ 剩余缺口（只改**正文文字**而不动标题/关键串）已在 M14 注明并保留 v2 |
| R24 | 🟢 | **Not-applicable（有意为之）+ MINOR-DEFERRED M15** | `EXPECT_PAGES=24` 的 `==` 断言比较的是 **slides.json 与 pptx 两个产物之间**的页数（生成器契约），不是对 AC 下限「≥24」的断言；AC-6 的下限由独立用例承担。登记 M15 说明该口径，避免被读成「与 AC 冲突」 |
| R25 | 🟢 | **Fixed in: 用例 7（上一轮已加）+ 函数注释** | `present < 2 ⇒ return 0` 分支现已由**用例 7**（只造 root+bundle 两份 + 注入漂移）显式覆盖；`guide_parity_ok` 注释写明「≥2 份就必须比较」。你与阶段 5 的 R1 指向同一处，两轮处置合并 |
| R26 | 🟢 | **Tech-debt: MINOR-DEFERRED M14** | pptx 字节不可复现（zip `date_time` 入档）→ 守护**只断页数/封面/标题/关键串，不做 md5 断言**（否则每次重建假红）；消除 churn 需在 `build.py` 固定 zip 时间戳，属 v2 |

**关于你的验证副作用**：`build.py` 的改写已由你逐字节还原（md5 `604354c4…`）。本轮我又跑过一次重建（因 `slides.json` 于 22:2x 有合法修订）——当前 `deck_checks.py` rc=0、bats 8/8、`check-dist` rc=0，pptx 内容与 `slides.json` 一致（标题级已由用例 8 机械验证）。

**复审请求**：实跑证据 —— bats **8/8 ok**（新增 deck content parity）· `verify-ac.sh` 86/0 · 集合断言 45/0 · `verify-boundary.sh` rc=0 · `check-dist` rc=0。

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-21 22:35）

> 自动生成于 2026-09-21 22:35。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "DESIGN.md",
      "issue": "D1 与 §4 R2 给出的本轮实测差异行数不一致（D1: root 独有 123 行 / bundle 独有 169 行；R2: root-only 125 行 / bundle-only 187 行），且两处都声称「本轮实测」，未说明以哪个为准。",
      "why": "执行者在核对量级基准时会遇到矛盾数字，无法确定当前真实差异规模；虽然文档声明以阶段 4 重跑为准，但同一文档内部不一致仍会导致误解并削弱设计依据的可信度。",
      "fix": "在 D1 中删除具体行数，仅保留「以阶段 4 重跑为准」的判据；或统一两处数字并注明测量时点（如阶段 2 预测 vs 阶段 4 实测）。"
    },
    {
      "file": "DESIGN.md",
      "issue": "D1 的防信息损失缓解只要求「逐条归类」并确认 bundle 独有来源，但没有明确当发现 root-only（根独有）内容时应如何处理（保留合并 / 丢弃 / 记录），覆盖根副本时 root-only 修订仍可能被静默丢弃。",
      "why": "指南文档可能包含仅在根副本中存在的独有修订，若直接以 bundle 整体覆盖根副本，这些内容会丢失；缓解措施没有给执行者明确的操作指令，只能依赖事后人工 git diff 发现，未达到「防信息损失」的目标。",
      "fix": "在 D1 中增加「根独有内容处置」条款：逐条识别 root-only hunks，若系有效修订则合并入 bundle 底稿后再覆盖，并登记到证据；若确认为过期内容则记录理由后删除。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN.md",
      "issue": "D2 中「必有：四份 md5 唯一值 = 1」与「dist 缺席时相关两份断言 SKIP」同时出现，造成「必有」语义矛盾；实际必有的是 root↔bundle 边，而非四份。",
      "why": "fresh clone 时 dist 不存在，四份 md5 断言不可能执行，但「必有」字面要求四份一致，执行者可能困惑该断言是否应该失败。",
      "fix": "将「必有」改为「必有 root↔bundle 一致；dist 相关两份按条件性 SKIP」以减少歧义。"
    },
    {
      "file": "DESIGN.md",
      "issue": "D2 的 installed copy 断言只规定「存在时必须与 dist 一致」，未说明 dist 缺席时该断言是否 SKIP 或如何处理；当 installed copy 存在但 dist 不存在（如旧安装残留）时行为未定义。",
      "why": "会产生不可判定的测试路径，执行者无法预知预期的 pass/fail。",
      "fix": "补充：若 dist 缺席，则 installed copy 断言同样 SKIP 并在 SKIP 原因中说明「dist 未生成，无法比较」。"
    },
    {
      "file": "DESIGN.md",
      "issue": "D2 将 deck 新鲜度（pptx 页数/日期）并入名为 guide_copy_parity 的 bats 用例，但守护名称与内容不完全一致；若未来维护者只看文件名可能误解守护范围。",
      "why": "文件命名应反映职责，避免抽象层次混乱。",
      "fix": "将用例重命名为 test_guide_sync_parity.bats 或在文件头部注释明确覆盖 md 副本、deck 新鲜度、installed copy 三类守护。"
    }
  ],
  "verdict": "pass",
  "summary": "DESIGN 整体结构清晰，沿用既有抽象并给出合理缓解；主要问题在于 D1 差异数据内部不一致及根独有内容处置不明确，但未构成阻塞性 critical，可在执行阶段修正。"
}
```

L3_artifact_hash: 0307210ae1e05e40e23ecd2e42b6f6fec01eaa1b8e6b31d17cc9add95d34dbd2

<!-- /L3-SECTION -->
