# TEST — user-guide-sync-2026-09b

- **Change ID**: user-guide-sync-2026-09b
- **关联**: `@.specs/user-guide-sync-2026-09b/REQUIREMENT.md`（AC 唯一来源）、`DOSSIER`：`.specs/user-guide-sync-2026-09b/{CHANGE,DESIGN,TASK,DEV-SUMMARY}.md`
- **执行时间**: 2026-09-21 22:1x–22:3x（+08:00）
- **执行者**: 主 agent（命令逐条实跑，输出原样贴入）

---

## 0. 轮次声明（步骤 0 · 强制）

| 轮 | 内容 | 本次是否执行 | 理由 |
|---|---|---|---|
| 1 · 功能 | AC 断言矩阵 + 成品断言 + 副本一致性 | ✅ 执行 | 本 change 的全部验收面都在这一轮 |
| 2 · 性能 | 新增守护的 md5 比较耗时（AC-10 NFR < 1s） | ✅ 执行 | 有 NFR 承诺就必须有实测 |
| 3 · 安全 | 「指南不得写入真实 token」反例（AC-4 N1 附） | ✅ 执行 | 文档型 change 唯一的安全面 |
| 4 · 兼容性 | 三平台（claude / dsh / opencode）路径与命令口径 + 渲染字体替代说明 | ✅ 执行 | 指南面向三平台；deck 渲染字体在本机为替代字体（M7） |
| 5 · 可观测性 | 无（纯文档/演示，无运行时日志/指标/告警） | ⏭ 跳过 | 显式声明：本 change 不产生运行时行为 |

---

## 1. AC 覆盖矩阵（AC → 用例 → 实跑结果）

| AC | 用例/断言 | 实跑证据 | 结果 |
|---|---|---|---|
| AC-1 版本与日期口径 | verify-ac.sh：版本行 `> 版本: 2026-09-21`、分节日期、`20260713`/`2026-07-13` 清零、`2026-09-03` 仅历史句 | §2 输出「断言通过：128 / 失败 0」；`2026-09-03` 唯一命中为「…起」历史锚点 | ✅ |
| AC-2 14 条 🔴 | verify-ac.sh：14 组反例（0 命中）+ 正例（≥1 命中），**四份副本同验** | 同上（含 `Bash\|Write\|Edit` 与 path-guard；`.flow-active` 握手字段措辞已改为不含旧键名） | ✅ |
| AC-3 过期项（29 条） | verify-ac.sh：有旧措辞者逐条反例 + 正例 | 同上 | ✅ |
| AC-4 候选新增 N1–N13 + N12 | `verify-ac.sh` AC-4 段（**分段计数见 §2**：AC-4 段 23 条 + 段外安全反例 1 条） | §2 实时输出 | ✅ |
| AC-5 四副本一致 | `md5sum` 四路径 → 唯一值；`package-dsh-plugin.sh --check` rc；`make dsh-sync` 后 `diff -rq dist ↔ 已装插件` | 见 §4 | ✅ |
| AC-6 deck 重建 + 扩页 + 断言有效性 | `build.py` + `deck_checks.py`；两组注入实测；每张新专页按标题断言 | 见 §3 | ✅ |
| AC-7 渲染验证 | `soffice → pdf → pdftoppm` 24 PNG；`read_image` 抽检封面 + 21/22/23/24 + 改动页 | 见 §3.3 | ✅（含 M7 字体替代口径） |
| AC-8 README 口径 | DEV-SUMMARY 的 6 行核对表 + `T03-verify-OK` | 见 §5.2 | ✅ |
| AC-9 改动边界与回归 | `git status/diff` 白名单比对；禁动域 diff = 0；`make check` 六门 | 见 §5 | ✅ |
| AC-10 副本守护 | `npx bats test/test_guide_copy_parity.bats`（**8 用例**）+ 注入实测 + 计时 | 见 §4.3 / §6 | ✅ |
| AC-11 独立审查与归档（可复现命令：`bash .specs/user-guide-sync-2026-09b/run-l3.sh <phase> pass both`；L2 由子代理写入 `INDEPENDENT-REVIEW-<N>.md`；锚点文件由 `l3_review_run` 写入） | L2 盲审（多轮 fix loop）+ L3 外部模型；归档产物 | 见 `INDEPENDENT-REVIEW-*.md` 与阶段 7 | ⏳ 由阶段 6/7 闭合 |

---

## 2. AC 断言矩阵实跑（`bash .specs/user-guide-sync-2026-09b/verify-ac.sh`，rc=0）

```
## 断言矩阵实跑（verify-ac.sh · 2026-09-21T23:16:42+08:00）

副本集合（存在者参与断言）：
  - FLOW-KIT-用户指南.md
  - flow-kit-bundle/FLOW-KIT-用户指南.md
  - dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md
  - dist/dsh-flow-kit/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md

### AC-2 · 14 条 🔴（反例 = 0 / 正例 ≥1 · 四份同验）

### AC-3 · 过期项（反例 = 0 / 正例 ≥1）

### AC-1 · 版本与日期口径

### AC-4 · 候选新增项（N1–N13）

### 分段计数（按 AC · 供 REPORT/REVIEW 直接引用）
  AC-1   通过 4   失败 0
  AC-2   通过 39  失败 0
  AC-3   通过 59  失败 0
  AC-4   通过 23  失败 0

### 结果
- 参与副本：4 份（每条断言对**每一份存在的副本**各判一次）
- 段外单元：3（AC-1 regex 版本行/分节日期 合 1 · AC-1「2026-09-03 仅历史句」1 · AC-4 安全反例 1）——分段计数之和不含这 3 项
- 断言通过：128
- 断言失败：0
```

> **集合断言的检测力边界（v4.4 · 阶段 5 L2 R4 更新）**：`check-appendix-superset.py` 当前口径是「AC 表**每个可抽锚点**都必须出现在附录 A」（逐锚点等值；无可抽锚点的注释格**显式计入「跳过」并列出明细**）。它仍**不**校验同句共现，也**不**校验字面 vs 正则——后者由 `verify-ac.sh` 的判据实现承担。TEST.md 不作超出该口径的声明。

实时输出（v4.4）：

```
$ python3 .specs/user-guide-sync-2026-09b/check-appendix-superset.py
检查单元格：58 个；跳过（无可抽锚点）：20 个；附录 A 缺失：0 个
  跳过明细：D23 正例 · D33 反例 · D18 反例 · D26 反例 · D32 反例 · D37 / D38 反例 · D41 反例 · N1–N12 各自的反例格（AC-4 无「反例」列语义）
```

> 覆盖范围（v4.4）：行正则改为 `\b` 后，**AC-4 的 12 个 N 行**也被扫到（此前只扫 27 行）；切格改为「按未转义 `|` 切分」，D23/D33 这类含 `\|` 或代码跨度的格子不再被静默跳过。
>
> v4 修订（阶段 1 L2 第三轮 R21/R22/R23 + 第四轮 R27/R28/R32）：D01/D03/D10/D22/D30/D43 的锚点改为与实现逐字一致的字面串；D26 改为**段落级**断言（SessionStart 段内）；D33 改为**整格原文**反例（4 个旧值串单独不参与断言）；正则锚点显式标注 `regex:`。母本一致性由上面的集合断言守护。

> 断言器设计：反例用 `grep -F`（字面匹配，避免正则元字符误伤）；**四份副本各自断言**（单一副本通过不算通过）；dist 缺席时按 DESIGN D2 的降级口径跳过该副本并在输出中列出参与集合。

---

## 3. deck（AC-6 / AC-7）

### 3.1 成品断言

```
$ python3 .specs/user-guide-deck-gen/deck_checks.py
deck_checks OK: 24 pages, banned=0, all pages non-empty, 24 titles addressable, keys present
```

- **页数 24**（20 → 24，净增 4，既有 20 页顺序不变；新页追加末尾）
- 新专页：21「安装面：作用域与入口」· 22「L3 审查链：凭证 · 熔断 · 工件上限」· 23「质量门禁：make check 六门」· 24「版本与副本口径」
- 断言已按 v3 口径改造：**按标题寻址**（`by_title`，不再用 `items[13]`/`items[19]` 硬编码下标）；每张新专页有标题级关键串断言；`BANNED` 含 `.specs/lessons/`、`项目级 stop-hook.json`、`三轮审查`、`20000 字节`、`归档（ARCHIVE）`（原恒真的 `ARCHIVE.md` 已替换）；`slides.json` 允许合法的 `ARCHIVE-MANIFEST.txt`

### 3.2 断言有效性实测（注入 → 变红 → 还原 → 复绿）

```
注入 1（新专页标题改名 → 重建）：
  KeyError: '质量门禁：make check 六门'   （deck_checks.py:95 by_title[T_MAKE]）
  → rc=1 ✅（证明"页缺失/改名"会被抓到）
还原：deck_checks OK → rc=0；slides.json md5 回到 8903a97a0351cf57da332bec83ae3108

注入 2（封面日期改 2026-09-03 → 重建）：
  AssertionError: cover date missing      （deck_checks.py:68）
  → rc=1 ✅
还原：deck_checks OK → rc=0
```

### 3.3 渲染抽检（AC-7 两段式）

**机检**：`soffice --headless --convert-to pdf` → `pdftoppm -png -r 80` → **24 张 PNG**（`render-preview/slide-01..24.png`）；PDF 页数 = PPT 页数 = 24，无空页。

**人工抽检**（`read_image` 实际看图）：封面 + 21/22/23/24（四张**新增**专页，风险最高）+ 改动页 10/11/16/19（分别对应「阶段 6 单轮合并审查」「阶段 7 归档表述」「Stop Hook 用户级配置」「gate_config 值域」四处**语义改动**） —— 结论：无空页、文字不出框（末行距底边仍有余量）、中文无缺字方框；`✅/❌` 渲染正常；`~/.config/flow-kit/l3.env` 全路径完整。

> **口径留痕（M7）**：`theme.py` 声明 `Times New Roman` / `宋体`，本渲染机 `fc-list` 对两者均无命中，实际由 Noto Serif/Sans CJK 兜底 —— 因此本次排版抽检是**替代字体度量**，不能等同于目标环境（装有宋体）的最终观感。已登记 MINOR-DEFERRED M7。

---

## 4. 副本一致性（AC-5 / AC-10）

### 4.1 四副本 md5（唯一值 = 1）

```
$ md5sum FLOW-KIT-用户指南.md flow-kit-bundle/FLOW-KIT-用户指南.md \
         dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md \
         dist/dsh-flow-kit/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md | awk '{print $1}' | sort -u | wc -l
1
$ bash package-dsh-plugin.sh --check
✅ check-dist: dist 与源一致        (rc=0)
$ make dsh-sync && diff -rq dist/dsh-flow-kit ~/.dsh/profiles/web/node_modules/dsh-flow-kit | wc -l
✅ 已同步（web profile）
0
```

**覆盖前基线快照**（T04 记录，不写死进 AC）：根 `fb2ff01b`/1631 行 · bundle `17efc398`/1693 行 · dist×2 `d87c6d84`/1632 行 → 覆盖后四份统一为 `17efc398` 的后续版本（详见 DEV-SUMMARY T04）。

### 4.2 窄路径再生说明

不跑全量 `package-dsh-plugin.sh`（会重写 dist 全树 + 生成 `.tgz`），按 `package-dsh-plugin.sh:45` 的 `COPY_OPTIONAL` 映射 `cp` 三处：dist docs 指南、dist vendor 指南、dist README（T03 改了源）、dist vendor 的 `test/` 新用例。`--check` 由红转绿证明窄路径与打包映射**同源**。

### 4.3 守护实跑

```
$ npx bats test/test_guide_copy_parity.bats
1..8
ok 1 guide parity: 仓内四份副本（root + bundle + dist×2）md5 唯一值 = 1
ok 2 guide parity: 版本日期口径一致（版本行 == 分节日期）且旧版本号清零
ok 3 guide parity guard is not vacuously green: 夹具注入 1 字节漂移必须判定不一致
ok 4 deck freshness: pptx 页数 == slides.json 页数，封面日期 == 指南版本行日期
ok 5 deck freshness guard is not vacuously green: 夹具页数不一致必须判定失败
ok 6 installed dsh plugin guide copy cmp-identical when present
ok 7 guide parity guard covers the dist-absent path: 用**真实指南副本**搭 root+bundle 两份布局，一致→通过；对真实内容注入 1 字节→必须检出
ok 8 deck content parity: deck_checks 全部断言生效 + slides.json 每页标题都出现在 pptx 文本中
```

> **v4.1 · 阶段 2 L2 第四轮 R23 处置**：用例 8 把 `deck_checks.py` 的**全部**断言（页数 / 禁词 / 关键串 / by_title 专页 / 封面日期 / 逐页非空）接进 `make test`（进而 `make check`），并新增 **title 级内容一致性**（slides.json 每页标题必须出现在 pptx 文本中）。注入实测：把第 21 页标题改成「质量门禁：注入测试标题」→ 用例 8 **not ok**（`titles=24 missing=1` / `MISSING: …`）→ 还原后复绿。此前只比页数 + 封面日期，改内容页文字不会被发现。

> **v4.1 · 阶段 5 L2 R1 处置**：用例 7 是**新增**的——它专门覆盖 `dist/` 缺席（fresh clone）时的「只有 root+bundle 两份」分支，用夹具注入 1 字节漂移证明该分支**确实比较并检出**（实测：两份一致 → rc=0；注入后 → rc≠0 且报告指名）。守护现在 8/8。

**非恒绿证据**：用例 3 在夹具里注入 1 字节漂移 → 比较逻辑判定不一致并指名；用例 5 同理（2 页 vs 1 页）。用例 4 在 T05 尚未重建 pptx 时**确实变红**（`pptx 页数(20) != slides.json 页数(24)`），重建后复绿——即守护在真实缺口上生效过，不是装饰。

**镜像**：`make test-sync` 已把该文件同步到 `flow-kit-bundle/test/`（`diff -rq test/ flow-kit-bundle/test/` 无输出）。

---

## 5. 回归与边界（AC-8 / AC-9）

### 5.1 `make check` 六门

（结果见 §5.3 —— 由后台全量运行补齐）

### 5.2 README 核对表（AC-8，6 行固定表）

| # | 条目 | 证据行号 | 结论 | 改动 / 未改理由 |
|---|---|---|---|---|
| 1 | 安装入口与作用域 | `README.md`（快速开始段）、`flow-kit-bundle/install.sh:145` | **改** | 原 `bash install.sh /path/to/project` 会被脚本拒绝（"必须指定 --global 或 --project"）→ 换成三条正确示例 + 警告；补 `--global` 不含 hooks 的口径 |
| 2 | 配置路径单一源 | `README.md:121-129`、`dsh-flow-kit/README.md:38-39,77-78` | 不改 | 两份均已写「用户级唯一一份（2026-09-21 起，项目级不再生成/读取）」 |
| 3 | 工件上限单位与默认值 | `README.md:121-130`、`dsh-flow-kit/README.md:77-84` | 不改 | `max_artifact_bytes` / 80000 / **字节** / ÷3 换算 / 旧名废弃 均已在位 |
| 4 | L3 凭证与熔断 | `README.md:101-119`、`dsh-flow-kit/README.md:61-75` | 不改 | 三 Path 优先链、rc 语义、死锁后果、systemd drop-in 均已在位 |
| 5 | dsh 插件更新入口 | `README.md`（新增「dsh 插件」段）、`dsh-flow-kit/README.md:96-109` | **改** | 新增 `make dsh-sync`（含 `DSH_PROFILE`）与「为何不能只靠 `sync-hooks.sh`」；dsh README 同步流程补该步骤 + pnpm 重装后需重跑 |
| 6 | dist README 与源的同步关系 | `dsh-flow-kit/README.md:101-109` | **改** | 明确 dist 产物不手工编辑、改源后按映射刷新，并补 `--check` 配套说明 |

### 5.3 全量门禁

```
$ make check > .specs/user-guide-sync-2026-09b/make-check.log 2>&1; echo rc=$?
rc=0
# 日志全文（103 行）已落盘：.specs/user-guide-sync-2026-09b/make-check.log
# 关键行摘录：
✅ shellcheck: no errors found
✅ validate: staging coverage OK（实际文件 314 项 · 漏配 0 · 源缺失 0）
✅ test 双源一致
✅ hooks 副本一致（漂移 0 · 6 个副本根）
✅ check-dist: dist 与源一致
╔════════════════════════════════════════════════════╗
║  ✅ make check: 全部通过                           ║
╚════════════════════════════════════════════════════╝
（日志：`.specs/user-guide-sync-2026-09b/make-check.log`，**末行恒为 `make check rc=$?`，行数随 Makefile 输出变化**（v4.5 · 阶段 5 L2 R6：此文件会被每次 `make check` 原地重写，故不把行数当判据，只看末行 rc）。
**口径订正（v4.4 · 阶段 5 L2 R5）**：该日志**不含逐用例行**——`Makefile` 的 `test` target 用
`npx bats test/ --formatter tap | tail -3` 摘要 + `> /dev/null` 权威判 rc，故「守护 8/8 ok」不是日志证据，
而是 `npx bats test/test_guide_copy_parity.bats` 单独实跑的证据；「红时可复算失败用例名」这一承诺**不成立**，
已登记 MINOR-DEFERRED M22）
```

**AC-9 边界判据实跑**（`bash .specs/user-guide-sync-2026-09b/verify-boundary.sh`，rc=0）：

```
## AC-9 边界核对（git status --porcelain + 未跟踪）
  ✅ .specs/CHANGELOG.md
  ✅ .specs/CONTEXT.md
  ✅ .specs/LESSONS.md
  ✅ .specs/user-guide-deck-gen/README.md
  ✅ .specs/user-guide-deck-gen/build.py
  ✅ .specs/user-guide-deck-gen/deck_checks.py
  ✅ .specs/user-guide-deck-gen/slides.json
  ✅ FLOW-KIT-用户指南.md
  ✅ README.md
  ✅ dsh-flow-kit/README.md
  ✅ flow-kit-bundle/FLOW-KIT-用户指南.md
  ✅ flow-kit-用户指南.pptx
  ✅ .specs/user-guide-sync-2026-09b/
  ✅ flow-kit-bundle/test/test_guide_copy_parity.bats
  ✅ test/test_guide_copy_parity.bats
  （已核对 15 条 · 忽略瞬态 0 条）

## 未跟踪新增（git ls-files -o --exclude-standard）
  ✅ .specs/user-guide-sync-2026-09b/.l3-attempts-3
  ✅ .specs/user-guide-sync-2026-09b/CHANGE.md
  ✅ .specs/user-guide-sync-2026-09b/DESIGN.md
  ✅ .specs/user-guide-sync-2026-09b/DEV-SUMMARY.md
  ✅ .specs/user-guide-sync-2026-09b/INDEPENDENT-REVIEW-1.md
  ✅ .specs/user-guide-sync-2026-09b/INDEPENDENT-REVIEW-2.md
  ✅ .specs/user-guide-sync-2026-09b/INDEPENDENT-REVIEW-3.md
  ✅ .specs/user-guide-sync-2026-09b/INDEPENDENT-REVIEW-5.md
  ✅ .specs/user-guide-sync-2026-09b/INDEPENDENT-REVIEW-6.md
  ✅ .specs/user-guide-sync-2026-09b/MINOR-DEFERRED.md
  ✅ .specs/user-guide-sync-2026-09b/REQUIREMENT.md
  ✅ .specs/user-guide-sync-2026-09b/REVIEW.md
  ✅ .specs/user-guide-sync-2026-09b/TASK.md
  ✅ .specs/user-guide-sync-2026-09b/TEST.md
  ✅ .specs/user-guide-sync-2026-09b/UAT.md
  ✅ .specs/user-guide-sync-2026-09b/check-appendix-superset.py
  ✅ .specs/user-guide-sync-2026-09b/make-manifest.sh
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-01.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-02.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-03.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-04.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-05.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-06.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-07.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-08.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-09.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-10.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-11.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-12.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-13.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-14.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-15.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-16.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-17.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-18.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-19.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-20.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-21.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-22.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-23.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-24.png
  ✅ .specs/user-guide-sync-2026-09b/run-l3.sh
  ✅ .specs/user-guide-sync-2026-09b/sync-counters.sh
  ✅ .specs/user-guide-sync-2026-09b/verify-ac.sh
  ✅ .specs/user-guide-sync-2026-09b/verify-boundary.sh
  ✅ flow-kit-bundle/test/test_guide_copy_parity.bats
  ✅ test/test_guide_copy_parity.bats

## 禁动域 diff（必须为 0）
  禁动域改动文件数: 0

## dist 再生件（由 make check-dist 守护，git 结构性看不见）
  ✅ check-dist rc=0

✅ 边界核对通过
```

> 判据为 `git -c core.quotepath=false status --porcelain`（含未跟踪新增）+ `git ls-files -o`，**不是** `git diff --name-only`——后者对未跟踪文件与被 `.gitignore` 忽略的 dist/ 结构性失明（v4 修订 · 阶段 1 L2 R20）。

> 变更集以紧邻上方的 `verify-boundary.sh` 实时输出为准（v4.4 · 阶段 5 L2 R3：此前另贴的 `git status --short` 块只有 13 行，与判据的 15 条不同源，已删除）。

禁动域 diff = 0：

```
$ git diff --name-only -- flow-kit-bundle/hooks dsh-flow-kit/lib flow-kit-bundle/skills flow-kit-bundle/flow-kit/prompts | wc -l
0
```

---

## 6. 性能轮（AC-10 NFR）

被测命令（逐字，3 次中位数；不含 `npx`/bats 启动、不含 python-pptx）：

```
$ TIMEFORMAT='%3R s'; for i in 1 2 3; do time md5sum <四路径> > /dev/null; done
0.002 s
0.002 s
0.002 s
```
（`/usr/bin/time -f %e` 只有两位小数 → 三次全 0.00 无法证明命令真跑；改用 `TIMEFORMAT='%3R'` 得 0.002 s，分辨力足够 —— 阶段 5 L2 R7。）

→ 单次比较中位数 **0.002 s** < 1 s ✅（守护粒度为四份 md5 一次性比较，不重复 `check-dist` 的逐文件遍历）。

> **AC-10 的 NFR 定义（v4.5 · 阶段 5 L3）**：「< 1 s」约束的是**单次比较逻辑**（`md5sum` 四路径），不是整个 bats 文件——后者含 8 个用例、两次 `python-pptx` 解析与 `deck_checks.py` 全断言，实测中位数 **4.184 s**（见 §10.2 ③）。两个口径都已列出，验收以**单次比较 < 1 s** 为准。

---

## 6.1 D08 复验（AC-2 处置口径要求记录）

```
$ grep -rn -- "sub-goal-" flow-kit-bundle/ dsh-flow-kit/ | grep -v "FLOW-KIT-用户指南.md"
（无输出）
```

→ 实现侧（`flow-kit-bundle/` 与 `dsh-flow-kit/`）**不存在** `--sub-goal-N` flag；`/flow goal` 只认 env `SUB_GOAL_4..7`，子目标由阶段 4 从 AC 自动提取。AC-2 采纳的实测结论成立（`--sub-goal-4` 在四份指南副本中 0 命中）。

## 7. 安全轮（AC-4 N1 附）

```
$ grep -nE '(sk-[A-Za-z0-9]{8,}|AUTH_TOKEN=.{16,})' <四份副本>   → 0 命中（verify-ac.sh 内置该反例）
```

指南只写变量名与加载方式（`FLOW_KIT_L3_AUTH_TOKEN` / `ANTHROPIC_AUTH_TOKEN` / `~/.config/flow-kit/l3.env` 模板引用），未出现任何真实凭证形态。✅

---

## 8. 兼容性轮

| 面 | 检查 | 结果 |
|---|---|---|
| claude | 指南中 claude 路径（`~/.claude/stop-hook.json`、`ANTHROPIC_AUTH_TOKEN`） | ✅ 均有明确表述 |
| dsh | `~/.dsh/stop-hook.json`、`make dsh-sync`、插件 `docs/` 副本、`FLOW_KIT_L3_*` Path3 优先 | ✅ |
| opencode | `~/.config/opencode/stop-hook.json`、桥接插件口径 | ✅ |
| 渲染字体 | 本机无宋体/Times New Roman → Noto CJK 替代（M7 留痕） | ⚠️ 已留痕，非本 change 可修 |

---

## 9. 反向抽查（DESIGN D6 抽样风险缓解）

随机抽 10 条现行正文，逐条回到源码/结构核对：

| # | 抽查点（指南） | 核对对象 | 实测 | 一致 |
|---|---|---|---|---|
| 1 | §2.2 `--self-test` 选项 | `install.sh` | 3 处命中（usage / 解析 / 自检段） | ✅ |
| 2 | §7 模块表 12 键 ↔ `modules` | `hooks/config/stop-hook.json` | `keys \| length` = **12** | ✅ |
| 3 | §7 `max_artifact_bytes` 缺省 80000 | 同上 | `80000` | ✅ |
| 4 | §7 PreToolUse matcher | `lib/install_hooks.sh` | `PreToolUse" "Bash\|Write\|Edit"` | ✅ |
| 5 | §12 `stop/lib` 19 个库 | `ls hooks/stop/lib/` | 19 | ✅ |
| 6 | §12 `pre-tool-use` 7 文件 | `ls hooks/pre-tool-use/` | 7（3 入口 + 4 库） | ✅ |
| 7 | §4 `/flow` 子命令枚举 | `dsh-flow-kit/lib/flow-state.js` | `start\|stop\|phase\|task\|checkpoint\|goal\|gate-config\|model\|l2-review\|doctor` | ✅ |
| 8 | 附录预设名 17 项 | `skills/flow/SKILL.md` PRESET_MAP | 17 | ✅ |
| 9 | §2.4 插件版本 v0.2.0 | `dist/dsh-flow-kit/package.json` | `0.2.0` | ✅ |
| 10 | §5 阶段 7 产出（UAT.md） | `prompts/7-integration.md` 输出段 | 含 `UAT.md` | ✅ |

**10/10 一致**（第 1 项首轮 grep 模式写错导致假阴性，已用正确模式复测）。

---

## 10. UAT 脚本（可脚本化部分 + 人工部分）

```bash
# UAT-1：四副本一致 + 打包件新鲜
md5sum FLOW-KIT-用户指南.md flow-kit-bundle/FLOW-KIT-用户指南.md \
       dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md \
       dist/dsh-flow-kit/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md | awk '{print $1}' | sort -u | wc -l   # 期望 1
bash package-dsh-plugin.sh --check                                                                          # 期望 rc=0

# UAT-2：断言矩阵
bash .specs/user-guide-sync-2026-09b/verify-ac.sh   # 期望：断言失败 0

# UAT-3：守护
npx bats test/test_guide_copy_parity.bats           # 期望 8/8 ok
python3 .specs/user-guide-deck-gen/deck_checks.py   # 期望 deck_checks OK: 24 pages

# UAT-4（人工）：打开 flow-kit-用户指南.pptx，翻到 21–24 页，确认
#   ① 安装面页写明 --global 不含 hooks；② L3 页写明凭证缺失会死锁、工件上限 80000 字节；
#   ③ 门禁页列出六门；④ 版本页写明四副本一致与同步顺序；⑤ 全片无「三轮审查」「ARCHIVE.md」字样。
```

---

## 10.1 L3 外部模型审查的处置（阶段 5 · 2026-09-21 23:15）

| L3 发现 | 处置 |
|---|---|
| fresh-clone 分支只用自造夹具证明 | **已修**：用例 7 改用**真实指南副本**搭 fresh-clone 布局（root + bundle 两份真实文件），再对真实内容注入 1 字节 |
| 用例 2 未断言 AC-1 的「2026-09-03 仅历史句」规则 | **已修**：用例 2 补该断言（与 `verify-ac.sh` 同规则） |
| UAT 与 TEST 计数互相矛盾（106 vs 129） | **已修**：UAT 改为**引用式**（不复制数字），并在 UAT 表补 `rc` 列 |
| `make-check.log` 只有 `tail -3` 摘要，红时无法复算失败用例名 | **已修**：T07 增列 `bats-full.log`（全量 TAP 逐用例） |
| 边界判据读活工作树（命令会改写产物） | **口径留痕**：TEST.md 记录判据时点（阶段 5 结束前）+ 瞬态夹具显式归类；pristine-clone 判据属 v2（MINOR-DEFERRED M23） |

## 10.2 L3 证据补全附录（阶段 5 · 23:2x）

**① AC-7 渲染的像素级证据**（`PIL` 实跑）

```
PNG 数=24 尺寸集合={(1067, 600)} 非纯白页=24/24
$ pdffonts /tmp/deck-render2/flow-kit-用户指南.pdf | head -5
BAAAAA+LiberationSerif-Bold     TrueType  emb=yes
CAAAAA+NotoSerifCJKsc-Bold      Type 1    emb=yes
DAAAAA+LiberationSerif          TrueType  emb=yes
EAAAAA+NotoSerifCJKsc-Regular   Type 1    emb=yes
$ fc-match "宋体" → NotoSerifCJK-Regular.ttc: "Noto Serif CJK SC"
$ fc-match "Times New Roman" → LiberationSerif-Regular.ttf: "Liberation Serif"
```
→ 「无空页」（24/24 非纯白）与「尺寸一致」是**机检**；「无缺字」在**替代字体**（Noto/Liberation）下成立，目标环境装宋体后的观感不在此证据范围内（M7）。

**② 安全轮扩面**（凭证模板 + 三棵树，精化模式排除 `AUTH_TOKEN="${VAR}"` 这类正常代码）

```
$ grep -rlE "(AUTH_TOKEN=['\"]?[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{20,})" \
      .claude/l3.env.example flow-kit-bundle dist/dsh-flow-kit dsh-flow-kit | wc -l
0
```
（首版粗模式 `AUTH_TOKEN=.{16,}` 命中 21 个文件——全部是 `FK_API_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN}"` 这类变量引用，属误报；已精化并进 `verify-ac.sh`。）

**③ 性能轮（守护整体计时）**

```
$ TIMEFORMAT='%3R s'; for i in 1 2 3; do time npx bats test/test_guide_copy_parity.bats >/dev/null; done
4.866 s / 4.184 s / 3.351 s → 中位数 4.184 s
```
→ NFR「比较逻辑 < 1s」指**单次比较**（实测 0.002 s）；**整个 bats 文件**（8 用例，含两次 python-pptx 解析与 deck_checks 全断言）约 4.2 s。两者口径不同，均已列出以免混用。

**④ 守护的收集链（AC-6/AC-10 的守卫为何有效）**

```
$ sed -n '8,11p' Makefile
test:
	@echo "🧪 make test: running bats..."
	@npx bats test/ --formatter tap 2>&1 | tail -3
	@npx bats test/ > /dev/null 2>&1 && echo "✅ bats: all tests passed" || { echo "❌ bats: some tests failed"; exit 1; }
$ grep -n "check: test" Makefile → 106:check: test lint check-validate check-test-sync check-hooks-sync check-dist
```
→ `test/` 全目录收集 ⇒ 本 change 新增的 8 个用例由 `make test` 执行，而 `test` 是 `make check` 第一门。

**⑤ UAT 内联**：`UAT-B1~B4` 的完整核对内容见同目录 `UAT.md`（本文件不复制；`UAT.md` 为人工确认的唯一入口，含 21 页–24 页逐页要点、README 两处改动、M1–M23 全表）。

**⑥ 集合断言「跳过格」的正当性**：跳过 21 格全部是**注释格**（如 `D33 反例` 的「整格原文」、`N1–N13` 的「反例」列在 AC-4 语义下不存在）——见脚本实时输出的「跳过明细」逐格列名；这些格的锚点由 `verify-ac.sh` 的对应断言承担（如 D33 的正例 `both/L2/L3`、N13 的三条路径）。

**⑦ 反向抽查的逐字命令**：

```
1) grep -c -- '--self-test' flow-kit-bundle/install.sh            → 3
2) jq '.modules | keys | length' flow-kit-bundle/hooks/config/stop-hook.json → 12
3) jq -r .independent_review.max_artifact_bytes …                  → 80000
4) grep -o 'PreToolUse" "Bash[^"]*"' flow-kit-bundle/lib/install_hooks.sh → PreToolUse" "Bash|Write|Edit"
5) ls flow-kit-bundle/hooks/stop/lib/ | wc -l                      → 19
6) ls flow-kit-bundle/hooks/pre-tool-use/ | wc -l                  → 7
7) grep -o 'start|stop|phase[^)]*' dsh-flow-kit/lib/flow-state.js  → start|stop|phase|task|checkpoint|goal|gate-config|model|l2-review|doctor
8) grep -cE '^     # [a-z-]+ +→' flow-kit-bundle/skills/flow/SKILL.md → 17
9) jq -r .version dist/dsh-flow-kit/package.json                   → 0.2.0
10) grep -A4 '^## 输出' flow-kit-bundle/flow-kit/prompts/7-integration.md | grep -c 'UAT.md' → 1
（首轮第 1 项用错模式 `'"--self-test"'`（带引号）→ 0 命中，属假阴性；改用 `grep -c -- '--self-test'` 后得 3。）
```

**⑧ AC-8 的 README 实际改动**（`git diff -- README.md` 摘要，完整 diff 见工作区）

```diff
- tar xzf flow-kit-bundle.tar.gz
- cd flow-kit-bundle && bash install.sh /path/to/target-project
+ tar xzf flow-kit-bundle.tar.gz
+ cd flow-kit-bundle
+ bash install.sh --global                 # 核心引擎 + skills + brooks-lint + brooks-tools（默认不含 hooks）
+ bash install.sh --global --user          # 同上 + 用户级 hooks（推荐）
+ bash install.sh --project <目标项目路径>  # 项目级：hooks + settings + .specs 模板（配置仍走用户级）
+## dsh 插件（DeepSeek Harness）
+ bash package-dsh-plugin.sh
+ dsh plugin --profile <profile 名> add file:<仓库路径>/dist/dsh-flow-kit
+ make dsh-sync                            # 默认 profile=web；DSH_PROFILE=<名> make dsh-sync 覆盖
```

## 10.3 阶段 5 的 L3 降挡记录（AC-11 口径要求）

**事实**：阶段 5 的 L3 外部模型（`deepseek-v4-flash-0731`）共跑 **4 轮**（23:15 / 23:1x / 23:2x / 23:3x），**每轮 findings 均已处置**：

| L3 轮次 | 主要发现 | 处置 |
|---|---|---|
| 1 | fresh-clone 只用自造夹具；用例 2 缺 AC-1 规则；UAT 与 TEST 计数矛盾；日志无逐用例 | 用例 7 改用**真实副本**；用例 2 补规则；UAT 改引用式；T07 增 `bats-full.log` |
| 2–3 | AC-7 缺像素级证据；安全轮未扫模板/树；跳过格未说明；抽查无原始输出；计时口径；README 无 diff；§4.3 与实现不符；M2/M3 表述冲突 | 见 §10.2 的 8 项证据附录（PNG 统计 / `pdffonts` / 凭证模板扫描 / 逐字抽查命令 / 守护收集链 / README diff） |
| 4 | AC-9 边界判据在**活工作树**上执行（`make check`、`make dsh-sync`、渲染、窄 dist 再生都会改写树内产物） | **结构性口径项**：已登记 MINOR-DEFERRED **M23**；判据时点与瞬态归类已写入 §5.3 与脚本输出。pristine-clone 判据属 v2 |

**降挡方式**：按框架熔断设计（`independent_review.max_failures_before_bypass` = 3，ADR-005 降级路径），由 **`l3_review_run` 子系统自动**写入阶段 5 的**审查锚点文件**（`L3_verdict=skipped`）并在 `INDEPENDENT-REVIEW-5.md` 追加 **`## L3 重审（bypass · 23:24）`审计段**——**不伪装 pass**。
**重试方式**：删除阶段 5 的尝试计数旁路文件后重跑 `bash .specs/user-guide-sync-2026-09b/run-l3.sh 5 pass both`。
**口径声明**：本 change 的阶段 5 结论 = **L2 第五轮 pass + L3 四轮 findings 全处置 + 熔断 bypass（审计留痕）**；不主张「L3 pass」。

## 11. 未覆盖项与残余风险

| # | 项 | 状态 | 说明 |
|---|---|---|---|
| 1 | 排版的人工判据（溢出/缺字） | 部分自动 | 机检覆盖页数/非空/尺寸；「是否溢出框外」仍需人眼 → MINOR-DEFERRED M1 |
| 2 | `deck_checks.py` **未做成独立门禁 target** | 未做（v2） | 注意：其**断言已通过用例 8 进 `make test`**（`test/` 全目录收集）；M2 指的是「独立 target」这一形态 → M2 |
| 3 | 副本守护**未做成独立门禁 target** | 未做（v2） | 现落在 `test/test_guide_copy_parity.bats`（由 `make check` 第一门 `test` 覆盖，链见 §10.2 ④）→ M3 |
| 4 | 「三轮审查」在 3 个范围外载体（skills/ 引擎 README/模板）仍存留 | 范围外 | AC-9 冻结；登记 M8 + 跟进 change `phase6-review-wording-2026-09` |
| 5 | 渲染字体为替代字体（无宋体/Times New Roman） | 环境限制 | M7 留痕，不可当最终观感结论 |
| 6 | pptx 字节级不可复现（内嵌时间戳） | 已知 | 守护只断页数/封面日期/文本，**不**对 pptx 做 md5 断言（否则假红） |
