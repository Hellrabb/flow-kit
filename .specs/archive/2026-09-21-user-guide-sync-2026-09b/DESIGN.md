# DESIGN: 用户指南与用户指南 PPT 同步至 2026-09-21 现状（第二轮）

- **Change ID**: user-guide-sync-2026-09b
- **关联**: `@.specs/user-guide-sync-2026-09b/REQUIREMENT.md`、`@.specs/user-guide-sync-2026-09b/CHANGE.md`、`@.specs/CONTEXT.md`
- **设计者角色**: Architect（只设计，不写实现 · R3.1）

---

## 0. 技术栈选定

**不需要技术栈选型**（纯文档/演示同步型 change，不引入任何新依赖）。沿用既有生成器栈，实测版本如下：

| 组件 | 版本（实测） | 用途 |
|---|---|---|
| python-pptx | 1.0.2 | 重建 `flow-kit-用户指南.pptx` |
| LibreOffice | 24.2.7.2 | `--headless --convert-to pdf` 渲染验证 |
| pdftoppm | 系统自带 | PDF 抽页转 PNG（抽检版面） |
| bats-core | 1.13.0（`npx bats`） | 新增副本一致性守护用例 |

> 依据（CONTEXT.md 已锁决策「技术栈」段）+ 本机实测（`python3 -c "import pptx"` / `soffice --version`）。

## 0.5 既有架构对齐

### 0.5.1 本次 change 会触碰的既有模块（grep/ls 实证）

**会修改（既有）**（**基线为执行时快照，不写死 md5/行数** —— v2 修订，L2 R1）：
- `FLOW-KIT-用户指南.md`（仓库根）— 同步目标之一（**执行前先登记快照**：`md5sum` + `wc -l` + `git rev-parse HEAD`）
- `flow-kit-bundle/FLOW-KIT-用户指南.md` — **本次修订底稿**（较新，含 2026-09-21 配置用户级措辞）
- `flow-kit-用户指南.pptx` — 由生成器重建
- `.specs/user-guide-deck-gen/slides.json`（20 页声明）、`deck_checks.py`（成品断言）、`.specs/user-guide-deck-gen/README.md`（**v2 补入**：其 `:28` 封面日期 `2026-09-03`、`:32` 禁词清单、`:23-25` layout 表随本轮同步；另 `:28` 的 `hellrabb/flow-kit` 与 `deck_checks.py` 断言的 `hellrabbit/flow-kit` 不一致，一并统一），必要时 `layouts.py` / `build.py`
- `README.md`、`dsh-flow-kit/README.md` — 口径核对与连改（用户已授权）
- **`.specs/CONTEXT.md`**（本 change 的术语与已锁决策沉淀）· **`.specs/CHANGELOG.md` · `.specs/STATE.md` · `.specs/LESSONS.md`**（AC-11 要求更新）—— v4.3 依阶段 3 L2 R3 补入清单
- **`.specs/archive/2026-09-21-user-guide-sync-2026-09b/**`——**对 §0.5.1「不应触碰」清单中 `.specs/archive/**` 的显式例外**：本轮归档落点即在此目录（先原位生成 `ARCHIVE-MANIFEST.txt` 再 `mv`，见 TASK T08）；历史归档目录仍为只读
- `dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md`、`dist/dsh-flow-kit/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md` — **窄路径再生**（按 `package-dsh-plugin.sh:45` 映射 `cp`，不跑全量打包；避免重写 dist 全树与生成 `.tgz`）

**会新增**：
- `test/test_guide_copy_parity.bats` + **`flow-kit-bundle/test/test_guide_copy_parity.bats`**（同源镜像 · `make test-sync` 产出 · `check-test-sync` 要求两目录逐文件一致 —— v2 补入，L2 R2）
- `.specs/user-guide-sync-2026-09b/render-preview/*.png` — 渲染抽检产物

**不应该触碰（禁动）**：
- `flow-kit-bundle/hooks/**`、`dsh-flow-kit/lib/**`、`flow-kit-bundle/skills/**`、`flow-kit-bundle/flow-kit/prompts/**`（运行时实现，diff 必须为 0 —— AC-9；**路径均为仓库真实路径**，v3 修正 · L2 R11：仓根无 `skills/`）
- `package-flow-kit.sh`、`.gitignore`、`.flow-active.goal`（CONTEXT 禁动清单）
- `test/` 下的既有 `.bats`（除新增文件外不改；避免动 964 例基线）
- `.specs/archive/**`（只读历史）

### 0.5.2 对齐既有抽象（防重复实现）

| 本次需要 | 既有有没有？ | 决定 |
|---|---|---|
| 生成 pptx | `.specs/user-guide-deck-gen/build.py` + `layouts.py` + `theme.py`（上次同步建立，tracked） | **沿用**，只扩 `slides.json` 与（必要时）新增 1 个 layout |
| 成品断言 | `deck_checks.py`（页数/日期/禁词/关键串） | **沿用并扩展**断言集（新页数、新禁词、新关键串） |
| 四副本一致性检查 | `test/test_l3_pipeline_fix.bats:548` 已有「in-repo copies share one md5」范式 | **沿用该范式**，不新造机制 |
| 副本再生 | `package-dsh-plugin.sh:44-48` 的 `COPY_OPTIONAL` 映射（bundle → dist docs，v4 修正 · L2 R17；`COPY_FILES` 是 :38-43 的另一张表）+ `rsync` 打包 | **沿用**，只跑既有入口 |
| 全量回归 | `make check` 六门（test/lint/check-validate/check-test-sync/check-hooks-sync/check-dist） | **沿用**，不新增 Makefile target |
| 文档一致性的事实基线 | 无既有机制（漂移报告是一次性产物） | **新建**：报告留 `/tmp`，结论落 REQUIREMENT/TASK 断言表（不引入第二份长期文档） |

### 0.5.3 沿用模式 vs 引入新模式

- **四副本同步**：**沿用**「单一底稿 → 机械拷贝」模式（同 `sync-hooks.sh` 的「唯一维护源 → 多副本」思路），**不引入**「自动从源码生成指南」的新模式（出范围，见 REQUIREMENT `out`）。
- **守护位置**：**沿用**「测试层断言」模式（同 `test_l3_pipeline_fix.bats` 的 md5 一致性用例），**不引入**新的 Makefile 门禁 target —— 理由见 D2。
- **deck 扩页**：**沿用**既有的声明式 `slides.json` + layout 复用，**不引入**新的 deck 引擎。
- **断言驱动**：**沿用**本仓「反例 grep + 正例 grep + 注入变红」的既有验证范式（`verify-claims.sh` / 各 bats 的既有写法）。

---

## 1. 决策清单（每条含备选 / 理由 / 代价）

### D1 · 修订底稿 = `flow-kit-bundle/FLOW-KIT-用户指南.md`

- **备选**：(a) 以根副本为底稿；(b) 以 bundle 副本为底稿；(c) 两份分别手改后再对齐。
- **理由**：实测 bundle 副本含 2026-09-21「配置统一用户级」的措辞（`5583e2a` 只改了它），根副本落后 2 行（漂移报告 §0 的 diff 证据）。以旧副本为底稿会把正确措辞改回去——这是**信息损失型**错误，不可接受。
- **代价**：根副本需以 bundle 为源整体覆盖（丢掉根副本可能存在的、bundle 没有的独有修订）→ 缓解（**v3 修订 · L2 R9**）：
  1. **冻结点的定义**：底稿冻结 = **T01/T02 均 done 且底稿 `mtime` 稳定不再变化**；达到冻结点后登记快照（`git rev-parse HEAD` + 四份的 `md5sum`/`wc -l`/`mtime`）并**重跑 `diff`**；此后若底稿再被写入，则**上次归类作废**，必须重新登记与归类。
  2. **归类判据**：逐条把每个 hunk 归为「根旧」或「bundle 独有」；出现「bundle 独有」条目须逐条确认其来源（本轮新改 / 历史两副本分叉）。
  3. **量级基准**（**以阶段 4 重跑为准**，不写死）：历史快照（2026-09-21 22:11 前）仅 2 行差异；本轮修订期实测 **65 hunks / root 独有 123 行 / bundle 独有 169 行**——差异远大于历史快照是**预期**（根副本停在 2026-09-03，bundle 已被本轮改写），**量级大本身不是异常信号**；判据是「每个 hunk 都能归类」，而不是「hunk 数是否等于某个值」。

### D2 · 副本一致性守护落在 `test/*.bats`，**不进** Makefile / verify-claims.sh

- **备选**：(a) 新增 `make check-guide-sync` target + 挂进 `make check`；(b) 并入 `verify-claims.sh`；(c) 新增一个 bats 用例（`make test` 覆盖）。
- **理由**：
  1. 既有范式已在测试层（`test_l3_pipeline_fix.bats` 的 md5 一致性用例），(c) 与之一致；
  2. `make check` 已 6 门，本轮只补守护不重构门禁链（ADR-027 的口径：门禁只提高可见性，不轻易扩张面）；
  3. `verify-claims.sh` 的语义是「核对 change 的响应段声明」，与「跨 change 的产物一致性」不是同一件事，塞进去会污染判据（`verify-claims` 的三态 ✅/❌/⏭ 语义会被稀释）；
  4. bats 用例天然可做「注入 → 变红 → 还原 → 复绿」的**行为级**验证，满足 AC-10 的「非恒绿」要求。
- **守护域与降级语义（v2 补全 · L2 R3/R4/R5）**：
  - **必有**：仓库内四份 `FLOW-KIT-用户指南.md`（根 / bundle / dist docs / dist vendor）md5 唯一值 = 1；
  - **条件性（dist 缺席）**：`dist/` 被 `.gitignore` 忽略（fresh clone 不存在）→ dist 相关两份断言**显式 SKIP 并打印原因**（沿用 `check-dist` 的降级口径），不静默通过也不硬红；`root ↔ bundle` 这条边**永远执行**；
  - **条件性（installed copy，v3 收窄 · L2 R10）**：`~/.dsh/profiles/${DSH_PROFILE:-web}/node_modules/dsh-flow-kit/{docs,vendor}/FLOW-KIT-用户指南.md` **存在时**必须与 dist 一致（沿用 `test_l3_pipeline_fix.bats:561` 的「when present」范式）——**守护域与 `Makefile:133-134` 的 `DSH_PROFILE ?= web` 同源**，不扫全部 profile（否则第二个装过插件的 profile 永远对不齐且 `make dsh-sync` 修不了 → `make check` 第一门恒红）；由阶段 4 的 `make dsh-sync` 对齐（**仓库外副作用，仅插件目录**，计划内）；
  - **新增 · deck 新鲜度（R3）**：`flow-kit-用户指南.pptx` 页数 == `len(slides.json)`，且**封面日期串 == 指南版本行的日期**（口径统一为「与指南版本行同名日期」，不在断言里二次写死 `2026-09-21`）——这是与 md 副本同构的失效形态（改 `slides.json` 忘重建 pptx 无人发现），故并入同一守护。**降级语义（v3 · L2 R12）**：`pptx` 文件不存在 **或** `python3 -c "import pptx"` 失败（fresh clone / 无 python-pptx 的 CI）→ 该组断言**显式 SKIP 并打印原因**，不静默通过也不硬红；**时序约束**：阶段 4 中「重建 pptx」必须早于任何 `make test`/`make check` 运行（否则「改了 slides.json 还没重建」的窗口会让第一门必红）；
  - 断言粒度为**一次性比较**，不重复 `check-dist` 的逐文件遍历；bats 用例文件本身须 `make test-sync` 镜像到 `flow-kit-bundle/test/`（R2）。
- **代价**：`make check` 与 `make test` 都会跑它（`test` 是 `check` 的第一门），断言失败信息只在 bats TAP 输出里出现，不如独立 target 显眼 → 缓解：用例标题写明 `guide copy parity`，失败信息指名**哪两份**副本不一致 + 给出修复命令（`cp flow-kit-bundle/FLOW-KIT-用户指南.md <target>`）。

### D3 · deck 扩页结构：20 → 24 页（净增 4）

- **备选**：(a) 严格 20 页只换内容；(b) 扩 4 页（安装面 / L3 审查链 / 质量门禁 / 版本与副本口径）；(c) 大幅扩到 28+ 页。
- **理由**：用户 2026-09-21 明确选择「大幅扩页（+4 以上，新增安装面/L3/门禁专页）」。选 (b) 的 4 页是因为它们对应本轮**四个用户最容易踩坑**的主题，且能各自独立成页（叙事完整）：
  1. **安装面**：`--global` 不含 hooks、`--project` 配置仍走用户级、dsh 插件 `make dsh-sync`
  2. **L3 审查链**：凭证三 Path（缺凭证 → 门禁死锁）、熔断 bypass、工件上限 80000 字节（÷3 换算）
  3. **质量门禁**：`make check` 六门 + `check-dist` / `hooks-sync` / `verify-claims` 各自保什么
  4. **版本与副本口径**：四副本一致性、版本日期口径、纯文档 change 的验证方式
- **代价**：页数断言、KEY_STRINGS、BANNED 全部要改（`deck_checks.py`），旧断言失效期间存在「断言与成品不同步」的窗口 → 缓解：slides.json 与 deck_checks 在**同一个 task** 内改完并实跑，禁止只改一侧（TASK 的 verify 强制）。**另（v2 补 · L2 R6/R7）**：① `deck_checks.py` 现有的**位置索引断言**（`items[13]` / `items[19]`）与扩页位移耦合 → 改为**按标题寻址**（`by_title`），并在 TEST.md 记录 old→new 页号；② `.specs/user-guide-deck-gen/README.md` 属必改资产（`:28` 封面日期 `2026-09-03`、`:32` 禁词表、`:23-25` layout 表），且其 `:28` 的 `hellrabb/flow-kit` 与 `deck_checks.py` 断言的 `hellrabbit/flow-kit` 已不一致 → 本轮统一为 `hellrabbit/flow-kit`。

### D4 · 日期口径统一为 `2026-09-21`

- **备选**：(a) 保留 `2026-09-03` 三个位置各自的原值；(b) 统一 `2026-09-21`（本轮同步日）；(c) 三个位置都改成「最后同步：见 git log」。
- **理由**：(a) 正是漂移报告 D43 指出的自相矛盾；(c) 对读者不友好（读者要 `git log` 才能知道版本）。指南版本号的服务对象是「读者判断这份文档有多新」，统一日期最直观。
- **代价**：下次同步若不改日期，会再次出现「日期不变但内容变了」→ 缓解：把「三处日期一致」写成 AC-1 的机械断言（`grep` 三处），并登记进 LESSONS 供下次同步复用。

### D5 · README / dsh README 发现过时口径 → **直接连改**（用户已授权）

- **备选**：(a) 只登记不改；(b) 连改；(c) 另开 change 改。
- **理由**：用户 2026-09-21 明确授权；且 README 是同一受众的入口文档，本轮已掌握全部事实基线（漂移报告），另开 change 要重建上下文，成本更高。
- **代价**：改动面扩大到非「用户指南两件套」→ 缓解：AC-8 要求 README 的每条改动都在 TEST 的「README 核对表」里有条目 + 证据行号；无证据的改动不允许。

### D6 · 修订方式：以「漂移清单逐条映射到断言表」驱动，不逐段重写

> **坐标基准（v3 补 · L2 R9-④）**：漂移报告的**行号锚点基于仓库根副本**（报告头部写明审计对象 = 根 `FLOW-KIT-用户指南.md` 1631 行；抽检 D01 `L65-66`、D43 `L1380` 只在根副本命中，bundle 对应位置已是新文本）。落到 bundle 底稿时**必须按内容检索定位，不得把报告 L 号直接套到 bundle** 上。

- **备选**：(a) 通篇重写指南；(b) 按 43 条漂移 + 12 条新增逐条定点修订；(c) 只改 🔴 的 14 条。
- **理由**：(a) 会丢掉大量仍然正确的既有内容并制造新漂移；(c) 无法满足 AC-3/AC-4。(b) 使「每条改动都有出处与验证」成为可能——这是纯文档 change 唯一能机械复算的形态。
- **代价**：43+12 条逐一核对耗时，且清单本身可能不全（漂移报告是抽样审计，非全量形式化验证）→ 缓解：TEST 阶段额外做一次「反向抽查」（随机抽 10 段现行正文，人工核对是否与实现一致），把抽样风险显式登记。

### D7 · 不新增 ADR（本轮无「以后可能被推翻」的项目级决策）

- **备选**：(a) 为 D2 写一条 ADR「文档副本一致性守护落在测试层」；(b) 不写。
- **理由**：判断标准是「可逆性低 / 影响面广」。D2 的选择是**可逆的小决策**（将来要进门禁链，加 1 行 Makefile 即可），且已有 ADR-027（门禁判据）覆盖「门禁只提高可见性」的同类语义，无需再记一条同族决策。
- **代价**：若未来有人问「为什么副本守护不在 `make check` 的显式 target 列表里」，需要读 DESIGN 而非 ADR → 已登记本段 + LESSONS。

---

## 2. 数据流 / 管线图

```
                    ┌──────────────────────────────────────────┐
                    │ 漂移审计（一次性 · 只读）                 │
                    │ /tmp/guide-drift-report.md                │
                    │ 43 条漂移 + 12 条候选 + 双副本分叉发现     │
                    └───────────────┬──────────────────────────┘
                                    │ 逐条 → TASK 断言表（正例/反例）
                                    ▼
   ┌────────────────────────────────────────────────────────────────┐
   │ 底稿：flow-kit-bundle/FLOW-KIT-用户指南.md（较新 · D1）         │
   │   → 定点修订（§1/2/3/4/5/6/7/9/10/12 + 附录）                  │
   └───────────────┬───────────────────────────────┬────────────────┘
                   │                               │
        ┌──────────▼───────────┐        ┌──────────▼───────────────┐
        │ 四副本对齐            │        │ deck 重建                 │
        │ ① 根（cp 底稿）       │        │ slides.json 20→24 页      │
        │ ② bundle（底稿）      │        │ build.py → .pptx          │
        │ ③ dist/docs（窄路径 cp）│       │ deck_checks.py 断言       │
        │ ④ dist/vendor（窄路径 cp）│      │ soffice → PDF → PNG 抽检  │
        │ ⑤ 可选：make dsh-sync │        │ ⑥ deck-gen README 同步     │
        │   （installed 副本）  │        └──────────┬───────────────┘
        └──────────┬───────────┘                   │
                   │                               │
                   ▼                               ▼
   ┌──────────────────────────────┐   ┌────────────────────────────┐
   │ test/test_guide_copy_parity  │   │ render-preview/*.png        │
   │ .bats（新增 · AC-10）        │   │ （抽检证据 · AC-7）         │
   │ 四份 md5 + dist 缺席 SKIP     │   └────────────────────────────┘
   │ + installed(when present)     │
   │ + deck 新鲜度（页数/日期）    │
   └──────────┬───────────────────┘
              │  须 make test-sync 镜像到 flow-kit-bundle/test/
              ▼
   ┌──────────────────────────────────────────────────────────────┐
   │ make check（6 门）：test(含新用例) → lint → check-validate      │
   │   → check-test-sync → check-hooks-sync → check-dist           │
   └──────────────────────────────────────────────────────────────┘
```

**边界（本 change 不进入的区域）**：`flow-kit-bundle/hooks/**` 运行时链、`flow-kit-bundle/flow-kit/prompts/**` 引擎指令、`flow-kit-bundle/skills/**` 技能包装器、打包脚本逻辑本身（只**执行**，不修改）。

**关键状态机（无）**：本 change 无运行时状态机。

## 3. ADR

**本轮不新增 ADR**（理由见 D7）。相关既有 ADR 的延续关系：
- **ADR-017**（Minor 单一路径）：本轮 L2/L3 的 Minor 发现仍写 `MINOR-DEFERRED.md`，延续。
- **ADR-027**（门禁只提高可见性，不改变红绿语义）：D2「副本守护落在测试层、不扩张门禁面」延续其口径。
- **ADR-019**（写作原则）：本轮指南修订的措辞遵循（具体、可验证、不写空话）。

## 4. 风险（≥3 条 + 缓解）

| # | 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|---|
| R1 | **修订漏项**：43 条漂移 + 12 条新增靠人工逐条落，存在「改了正文但同义旧措辞在别处残留」 | 高 | 读者仍被误导；AC-2/AC-3 假绿 | TEST 断言表**正例 + 反例**成对：反例 = 旧措辞 grep 必须 0 命中（含同义变体）；再做 10 段反向抽查（D6） |
| R2 | **副本回退风险**：以 bundle 为底稿覆盖根副本，可能吞掉根副本独有内容 | 低 | 静默信息损失 | 覆盖前现场 `diff` 并逐条归类并留证据（**量级以阶段 4 重跑为准**：历史快照 2 行；本轮实测 125 行 root-only / 187 行 bundle-only，归类结论见 `DEV-SUMMARY.md` 的 T04 段 · v4 修订 · L2 R15，删去「仅 2 行」的过期判据）；覆盖后 `md5sum` 四份唯一 + `git diff` 人工过一遍根副本 |
| R3 | **deck 断言与成品不同步**：改页数不改断言（或反之）→ 恒绿/恒红 | 中 | 验证失效（假 pass / 假 fail） | slides.json 与 deck_checks.py 同一 task 内改完并实跑；断言做「注入 → 变红 → 还原 → 复绿」实测（同 AC-10 手法） |
| R4 | **渲染环境差异**：LibreOffice 字体缺失导致 CJK 丢字/溢出，本地通过但他人打开不同 | 中 | 演示事故 | 渲染 PDF + 抽 PNG 抽检（封面 + 3 新专页 + 末页）；发现丢字则回退到既有 theme 字体族，不换字体 |
| R5 | **L3 凭证/模型不可用**：外模型审查降级为 model-missing 或 bypass | 中 | 独立审查链缺口 | 按既有降挡口径透明记录（不伪造 pass）；必要时 `~/.config/flow-kit/l3.env` 显式 source 后手工跑 `l3_review_run` |
| R6 | **范围蔓延**：README 连改 + 新增测试使 change 不再是「纯文档」 | 中 | 边界模糊，AC-9 难判定 | **白名单 = REQUIREMENT AC-9 的列表（不复述，避免两处漂移 · v4 修订 · L2 R16）**，判据同步改用 `git status --porcelain` + `git ls-files -o --exclude-standard`（`git diff` 看不到新增文件与被忽略的 dist）；`.specs/CONTEXT.md`（本 change 术语沉淀）与 `.specs/{CHANGELOG,STATE,LESSONS}.md`（AC-11 要求更新）已在 AC-9 白名单内；dist 由 `make check-dist` 守护 |

## 5. 不在范围内（本次设计不解决，但未来需要）

- 指南正文的**结构化抽取**（把「配置键 / 命令 / 路径」抽成机器可读清单，供门禁直接比对实现）——本轮仍靠 grep 断言，属 v2。
- `flow-kit-技术设计.pptx` 与 `flow-kit-ecosystem-guide.md` 的同步（另开 change）。
- 指南的多语言版本。
- **`tools/pptx-light-sync.py`（既有一次性工具）**：docstring 声明「19 页 / 日期 2026-07-13 → 2026-07-24」且硬编码本机路径，**执行会就地重写受版本控制的 `flow-kit-用户指南.pptx`**。本轮**不执行、不修改**它（阶段 2 L2 第四轮 R22）；如需保留应加 DEPRECATED 头，属 v2。
- `install.sh --self-test` 的文档化（实现侧未定型）。

## 6. 验收映射（AC → 设计决策）

| AC | 由哪些设计决策承载 |
|---|---|
| AC-1 日期口径 | D4 |
| AC-2 / AC-3 逐条修订 | D6（断言表驱动） |
| AC-4 候选新增 N1–N11 | D6 + **REQUIREMENT AC-4 的归属表**（v4 修正 · L2 R19：原文指向不存在的「§1 各条归属小节」）+ TASK 附录 A 的 N 断言表 |
| AC-5 四副本一致 | D1 + §2 管线 |
| AC-6 deck 扩页 | D3 |
| AC-7 渲染验证 | §2 管线 + R4 缓解 |
| AC-8 README 口径 | D5 |
| AC-9 改动边界 | §0.5.1 禁动清单 + R6 白名单 |
| AC-10 副本守护 | D2 + `test/test_guide_copy_parity.bats` |
| AC-11 独立审查与归档 | 各阶段 L2/L3（gate_config=all）+ 阶段 7 归档 |

## 7. 弱模型鲁棒性检查（R6.1 证据链）

- 本节所有「既有模块」均来自实测命令：`md5sum` / `wc -l` / `ls` / `grep -n`（证据见 §0.5.1 行号与哈希）；
- 所有引用到的既有文件（`deck_checks.py` / `test_l3_pipeline_fix.bats:548` / `package-dsh-plugin.sh:45` / `Makefile:106`（`check:` 六门依赖行））均已 `grep`/`read` 验证存在，未引用任何未验证的路径或抽象；
- 未使用「最佳实践」类空话表述。

## 9. 架构沉淀建议

本 change 无架构层面沉淀建议（纯文档/演示同步，未新增可复用抽象、未改跨模块契约、未动依赖）。

> 唯一候选「漂移清单驱动文档同步」的范式已写入 CONTEXT.md 术语表（`漂移清单（drift inventory）`），属术语而非架构契约，故此处记「无建议」。
