# REQUIREMENT: L3 审查链 5 条缺陷修复

- **Change ID**: `l3-review-defects-2026-09`
- **关联**: `@.specs/l3-review-defects-2026-09/CHANGE.md`、`@.specs/CONTEXT.md`
- **需求来源**: 外部缺陷报告 `L3-review-defects-2026-09-17.md`（用户提供）+ 用户指令
  「重新测试并过滤，再修复」。**无反问轮次**：需求边界由报告 §B1~§B5 与 §8 未覆盖声明
  直接给定，报告本身即需求基线。

---

## 用户故事

- **US-1**：作为 flow-kit 使用者，我想让阶段门禁从工件里稳定读出 L2 的结论，
  以便 L3 不会因为一个大小写问题就永远不运行、把阶段推进和 commit 全锁死。
- **US-2**：作为 flow-kit 使用者，我想让 `INDEPENDENT-REVIEW-N.md` 在任意轮次重写后
  仍是干净的，以便审查记录可以作为审计证据长期保留。
- **US-3**：作为配置 flow-kit 的项目维护者，我想让工件上限配置的名字与实际单位一致，
  以便我按字符估算时不会低估中文工件的截断风险。
- **US-4**：作为 L3 审查的阅读者，我想让发给外部模型的工件清单是完整的、且不包含
  "本项目根本不产出"的文件的缺失告警，以便审查结论不会建立在提示词自己制造的假事实上。
- **US-5**：作为在多个运行时（claude / dsh / opencode）之间切换的使用者，我想让所有
  已安装的 hooks 副本内容一致，以便同一个 change 换条路径不会得到不同结论。

## 验收准则（AC）

### AC-1 · L2 结论提取**限定 L2 层**、免疫 L3 段与大小写

- **Given** 一份同时含 `## L2 盲审`（写 `**Verdict**: fail`）与后追加的 L3 段的
  `INDEPENDENT-REVIEW-7.md`；L3 段的**最小合法结构**固定为：
  ```
  ## L3 重审（<model> 外部模型 · <ts>）
  ### 审查结论
  ```json
  {"critical":[],"verdict":"pass"}     ← 载荷；此处可插入行首 '## ' 等对抗内容
  ```
  L3_artifact_hash: <sha256>
  <!-- /L3-SECTION -->
  ```
  其中载荷内**含一行非围栏的行首 `**Verdict**: pass`**（对抗内容）——插入位置固定在
  `### 审查结论` 与 ```json 围栏之间（即 JSON 之前、`L3_artifact_hash` 行之前），
  使"载荷行位"在实现与测试间无歧义（2026-09-18 依 L3 minor 补写）。
  `<!-- /L3-SECTION -->` 是本 AC 的组成部分——不含该标记的输入属 AC-5 的无标记历史工件场景，
  其边界行为由 AC-5 规定，不由本 AC 判定。
- **When** 调用 `fk_extract_l2_verdict <file>`
- **Then** 返回 `fail`；且对 `PASS`/`Fail`/`- **Verdict**: Pass` 等写法一律返回小写枚举，
  **取值域 = {`pass`, `fail`, 空串}**（提取函数**永不**返回 `skipped`）
- **两处枚举的范围区分（2026-09-18 依 L3 重审 critical 补写 —— 原文两处口径未对齐）**：
  - **提取函数**（本 AC 与 AC-2 的 When）：值域 `{pass, fail, ""}`，空串表示"L2 段没有结论"；
  - **调用方**（`29-independent-review.sh` → `l3_review_run` 的实参）：值域
    `^(pass|fail|skipped)$`，其中 `skipped` 只在 `gate_config=L3`（L2 被**刻意**跳过）
    时由调用方**自行构造**，与提取函数无关；
  - 故 AC-1 的 `^(pass|fail|skipped)$` 约束的是**传参**，AC-2 的 `{pass, fail, 空}` 约束的是
    **提取结果**，二者不冲突、也不可互相推导。`skipped` 由 `B1-R25` 的 harness 断言（实参合法枚举）。
- **补充约束（2026-09-18 由 1-requirement 的 L2 盲审 R1 追加）**：
  - 主 agent 响应段（`## 主 agent …`）内的 Verdict 行**不得**影响结果
  - 仅含 L3 段、无 L2 段的工件**必须返回空**，不得把 L3 结论冒充 L2 结论
  - 一个工件含多轮 L2（`## L2 盲审` / `二审` / `重审` / `三审`）且与主 agent 响应
    **交替**出现时，取**最后一轮 L2**的结论，不得在首个响应处截断
  - L2 报告自身含二级子标题（如 `## 与主 agent REVIEW.md 的对照`）时，
    Verdict 落在子标题段内仍须可取
  - **L3 段内出现行首 `## ` 二级标题时**，其后 L3 正文不得进入 L2 层；
    L3 段的终点是 `<!-- /L3-SECTION -->`，不是「下一个二级标题」
    （2026-09-18 由 1-requirement 的 L2 复审 R1 追加 —— 该约束在**生产写入路径**下
    可复现，见 `B1-R16`）
  - **读侧与写侧的 L3 段边界判定必须同源**（`l3-section.sh::_l3_section_spans`），
    不得各自实现（L-031）
- **验证方式**: `bats test/test_l3_review_defects_2026_09.bats -f B1`（不写例数——计数会随 AC 增长漂移）

### AC-2 · 提取结果在全部历史工件上只产出合法枚举

- **Given** 仓库 `.specs/` 下全部 `INDEPENDENT-REVIEW-*.md`（本 change 期间实测 224 份；
  该数随本 change 自身的审查文件增长而增长，故以"全部"为准、数字仅作快照）
- **When** 逐份调用 `fk_extract_l2_verdict`
- **Then** 每份结果 ∈ {`pass`, `fail`, 空}，**零**非枚举值
- **空值预算（2026-09-18 依 L2 盲审 R1 修订）**：AC-1 的「限定 L2 层」落地后，
  有 **8 份**工件的**L2 段本身不含任何 verdict** —— 修复前这 8 份的值来自 L3 段
  （或主 agent 自审段），正是本 change 要消除的"L3 冒充 L2"。故空值由 0 变为 8 是
  **正确化**而非回归，且下游 4 个消费点对空值均回落 `fail`（不阻塞）。
  本 AC 要求空值数 **≤ 8 且每份可归因**，**归因清单是本 change 的具体交付物**：
  `@.specs/l3-review-defects-2026-09/L2-EMPTY-ATTRIBUTION.md`，每份空值一行，格式
  `<归档相对路径> | <旧实现取值> | <旧值来源段> | <L2 段内锚定 verdict 行数>`。
  （2026-09-18 依 L3 major 修订：原文把清单推给 `2-design`，导致本 AC 在阶段 1 内不可判定。
  现改为本工件内的固定路径交付物。）
  **下游对空值的处理（2026-09-18 依 L2 盲审 R3 更正措辞）**：4 个消费点均**不阻塞**，
  但机制不同 —— 3 处（`gate-checks-review.sh` / `l3-review.sh::l3_dispatch_prompt` /
  `29-independent-review.sh`）显式回落 `fail`；`done-validation.sh` 的 T4 走既有
  best-effort **放行**（`[[ -z "$md_v" || ... ]] || return 2`，空值直接跳过比对）。
- **验证方式**: `for f in $(find .specs -name 'INDEPENDENT-REVIEW-*.md'); do ...; done`

### AC-3 · 报告 §B1 的自包含复现改变结论

- **Given** 报告 §B1 给出的 5 行临时工件
- **When** 调用 `fk_extract_l2_verdict`
- **Then** 输出 `fail`（修复前实测输出 `PASS`）
- **验证方式**: `bats test/test_l3_review_defects_2026_09.bats -f "B1-R1"`

### AC-4 · L3 段重写幂等：任意轮次后无残留

- **Given** 载荷含行首 `## ` 的 L3 审查结果，且工件已有旧 L3 段
- **When** 连续执行 ≥4 轮「删旧段 → 追加新段」（生产函数 `_l3_parse_result`）
- **Then** 工件中 `^## L3 ` 恰 1 个、结束标记恰 1 个、`^---$` 恰 1 条、
  **L3 段内** `^``` ` 恰 2 条（写入方产生的那一对，配平）、
  **L3 段内**空行数不随轮次增长（口径 = 该段行区间内的空行计数，不含段外；
  2026-09-18 依 L3 minor 明确范围）、旧轮次内容与 hash 零残留
- **验证方式**: `bats test/test_l3_review_defects_2026_09.bats -f "B2-R6"`

### AC-5 · 无标记的历史工件仍可清除 L3 段

- **Given** 不含 `<!-- /L3-SECTION -->` 的历史工件（含 `## L3 盲审` 段）
- **When** 调用 `_l3_strip_sections`
- **Then** L3 段被完整清除，且其后的其它段落内容不被误删
- **验证方式**: `bats test/test_l3_review_defects_2026_09.bats -f "B2-R3" -f "B2-R4"`

### AC-6 · 工件上限：规范键名生效、单位语义与文档一致

- **Given** 项目级 `stop-hook.json` 配 `independent_review.max_artifact_bytes = 60000`
- **When** 对 UTF-8 全中文工件（90000 字节 / 30000 汉字）执行截断
- **Then** 输出 60000 **字节**（= 20000 汉字）；解析链 `_BYTES` > `_CHARS` > 历史直调 > 20000 成立
  （可观测口径：`B3-R4` 对解析链字面量断言 + `B3-R2`/`B3-R3` 对四级取值的实际行为断言）；`README` / `dsh-flow-kit/README` / 配置模板 / `l3.env.example`
  四处均写明"单位=字节"与 CJK ÷3
- **验证方式**: `bats test/test_l3_review_defects_2026_09.bats -f B3`

**载体路径（2026-09-18 依 L3 major 补写：文档交付物不在本 change 目录内，故在此给出可核路径）**：

| # | 载体 | 断言 |
| --- | --- | --- |
| ① | `README.md` | 含"字节"+「CJK ÷3」 |
| ② | `dsh-flow-kit/README.md`（分发包） | 同上 |
| ③ | `.flow-kit/stop-hook.json`（配置模板的 schema 注释） | 键名 `max_artifact_bytes` + 单位说明 |
| ④ | `flow-kit-bundle/flow-kit/l3.env.example` | 同上（第五处载体 `package-flow-kit.sh` 的收尾横幅由 `B3-R5b` 断言） |

以上四处由 `npx bats -f B3-R5 test/test_l3_review_defects_2026_09.bats` 逐处断言（键名 + 单位 + ÷3 三要素）。

### AC-7 · 旧配置键仍可用且给出迁移提示

- **Given** 项目级配置只写旧键 `independent_review.max_artifact_chars = 60000`
- **When** 29 号模块解析工件上限
- **Then** 取到 60000（行为与修复前一致），并向 stderr 打印含 `DEPRECATED` 的迁移提示
- **验证方式**: `bats test/test_l3_review_defects_2026_09.bats -f "B3-R3"`

### AC-8 · 阶段 7 产物清单完整、不产生假缺失

- **Given** 一个**由测试合成**的阶段 7 change 目录（33 个编号文件 + 8 个标准产物 = 41 条目；
  现实 change 目录的最大条目数见 5-test 实测 —— 仓库中不存在 41 条目的真实目录）
- **When** 调用 `_l3_build_prompt 7 <dir> 200000`
- **Then** 41 个条目名全部出现在提示词中；**不含** `INTEGRATION.md === MISSING`；
  存在的 `UAT.md` 被列出；缺失的 `MINOR-DEFERRED.md` 不被列出
- **验证方式**: `bats test/test_l3_review_defects_2026_09.bats -f B4`

### AC-9 · 必备产物的 MISSING 语义未被削弱

- **Given** 41 条目目录，但删掉必备的 `TASK.md`
- **When** 构造阶段 7 提示词
- **Then** 仍输出 `=== TASK.md === MISSING`（门禁强度不因 AC-8 而下降）
- **验证方式**: `bats test/test_l3_review_defects_2026_09.bats -f "B4-R4"`

### AC-10 · 全部 hooks 副本内容一致，且漂移可被门禁拦下

- **Given** 以下 **7 处**副本（`sync-hooks.sh` 的 `DEST_ROOTS`，按此顺序）：
  ① `flow-kit-bundle/hooks`（唯一源，不自我比对）② `<repo>/.claude/hooks`
  ③ `~/.claude/hooks` ④ `dist/dsh-flow-kit/hooks`
  ⑤ `dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks`
  ⑥ `~/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks`
  ⑦ `~/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks`
  —— 其中 ②④⑤ 在仓库内、③⑥⑦ 为用户级安装。**镜像范围 = ②~⑦ 共 6 处**（① 是源）；
  `~/.claude` 等用户级副本在 `--check` 中**不存在即跳过**（全新环境不因缺它而失败），
  故该 AC 在 CI 中不依赖宿主安装状态。
- **When** 执行 `./sync-hooks.sh --check`
- **Then** 退出码 0 且报告漂移 0；反向构造一处缺失副本时**必须**非零退出（断言非恒真）
- **验证方式**: `make check-hooks-sync` + `bats test/test_l3_review_defects_2026_09.bats -f B5`

### AC-11 · 结构门槛与既有质量门禁不回退

- **Given** 修复引入新 lib 文件 `l3-section.sh`
- **When** 执行 `make check`
- **Then** 以下结构门槛**逐条**仍通过（2026-09-18 依 L3 major 展开，原文只写「等」）：① `lib/l3-api.sh ≤ 250 行`；② `scripts/check-structure.sh` 的全部既有断言；③ `hooks/stop/` 单文件行数门禁；④ `make check-lint`（shellcheck）零 error；
  打包 `--validate` 漏配 0；`test/` ↔ `flow-kit-bundle/test/` **双源一致**
  （基准：`test/` 为权威源，`flow-kit-bundle/test/` 是分发副本；同步责任在本 change ——
  提交前跑 `make test-sync`；`make check-test-sync` 是**只读**比对，不一致即非零退出，
  不会自动修复）；全量 bats 0 fail
- **验证方式**: `make check`

### AC-12 · 提取失败时的门禁语义已定义且可见

（2026-09-18 由 1-requirement 的 L2 盲审 R3 追加）

- **Given** 一份含 `## L2 盲审` 段但段内不含任何 verdict 行的 `INDEPENDENT-REVIEW-7.md`
- **When** 29 号模块走完「提取 → `l3_review_run`」
- **Then**
  1. 提取结果为空时，向 stderr 打印**显式可观测告警**（含 `L2 verdict not found` 字样），
     **不得**静默降级；
  2. 传给 `l3_review_run` 的值仍为合法枚举（沿用既有 `fail` 保守默认），
     不触发 `^(pass|fail|skipped)$` 校验失败 → 不造成 US-1 抱怨的"锁死且看不出原因"
- **验证方式**: `bats test/test_l3_review_defects_2026_09.bats -f 'B1-R2[567]'`
  （**行为 harness**：真跑 29 号模块，断言 stderr 与传给 `l3_review_run` 的**实参**；
  `B1-R27` 为变异自证。2026-09-18 依 L2 复审/三审/四审 R2 升级，`B1-R15` 降为附加烟测）

---

## 范围切分

### v1（本次必做）

- AC-1 ~ AC-12 全部（AC-12 为 2026-09-18 依 1-requirement 的 L2 盲审 R3 追加）。

### v2（下一轮考虑，不本次）

- **按字符/字素截断工件**（§B3 的第 2 方案）：需同时重新评估 API 请求体上限与超时，
  并给 `max_artifact_bytes` 与 `max_artifact_chars` 定义优先级，属独立 change。
- **历史 `.done` 的 `L2_verdict` 回溯校正**：需先解决 PreToolUse 守卫"禁止主 agent 改
  `.done`"与"修正历史记录"的冲突（可能要开一个受审计的迁移脚本入口）。
- **`pre-tool-use/*.sh` 源文件与副本的 exec 位不一致**（源 664 / 副本 755，HEAD 中已存在）：
  属安装器契约层面的清理，与本次缺陷无关。

### out（永远不做）

- **让 `L2_verdict` 参与放行判定**（例如要求 L2 必须 pass 才允许写 `.done`）：本项目
  双层的设计是 L2 留证、L3 决定放行，改判定语义属产品决策而非缺陷修复。
- **在 `INDEPENDENT-REVIEW-N.md` 之外另建 L3 结果存储**：ADR-010 已锁定结果落
  `## L3` 段 + `L3_artifact_hash` 元数据行，不另起载体。

---

## 非功能性需求

- **性能**: 无新增硬指标。约束：`_l3_strip_sections` 对 < 50KB 的审查文件为单次 awk
  全量读，不得引入外部进程调用（已满足：纯 awk）。
- **可访问性**: 无（非 UI 变更）。
- **安全**: 不变更凭证路径；`.done` 的作者性校验（Tier 4）语义不变。
- **兼容性**: 必须同时兼容 ADR-009 的两种布局——**Gen-1**（L3 段在前、L2 段在后）
  与 **Gen-2**（L2 段在前、L3 段后追加）；必须兼容无结束标记的历史工件；
  必须兼容旧配置键 `max_artifact_chars` 与旧环境变量。
- **可观测性**: §B3 的旧键迁移必须在 stderr 留痕；§B5 的漂移检测必须在 `make check`
  中可见（非静默通过）。

## 依赖与假设

- **依赖**：`git`（副本漂移检测的 `cmp` 基线）、`awk`（POSIX 子集）、
  `jq`（配置解析，既有依赖）、`bats`（测试，经 `npx`）。
- **依赖**：ADR-010 已锁定的 `## L3 (盲审|重审)` 正则与 `L3_artifact_hash` 元数据行不变。
- **假设**：`.specs/archive/` 下 222 份历史工件在本 change 期间不变（用于 AC-2 基线）。
- **假设**：`install_hooks.sh` 的安装文件集（`stop/<module>.sh`、`stop/lib/*.sh`、
  `pre-tool-use/*.sh`、`session-start/{flow-kit-resume,stop-report-reminder}.sh`、
  `pre-commit/pre-commit.sh`）是 §B5 副本比对的权威范围；可执行位由该安装器负责。

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。

---

## 附 A · AC ↔ 验证用例映射（含实现锚点）

> 本附为 **L3 重审 major ④（缺映射表）** 的交付物，同时把"如何核"从"读 REQUIREMENT 文本"
> 变成"读锚点 + 跑用例"。

| AC | 实现锚点（file:line / 函数） | 用例 | 实测结论 |
| --- | --- | --- | --- |
| AC-1 L3 段不冒充 L2 | `lib/l2-detect.sh::_fk_l2_scope`（62-64 行调用 `_l3_section_spans`） | B1-R2[1-4]、B2-R9、B2-R11、B2-R13 | 对抗构造（段内行首 `## ` + `**Verdict**: pass`）→ 仍取 L2 的 `fail` |
| AC-2 语料零非枚举 / 空值 ≤8 / 可归因 | `lib/l2-detect.sh::fk_extract_l2_verdict` | 「AC2: 语料全量复算」 | 224 份工件 → 空值 8、非枚举 0；逐行对齐 `L2-EMPTY-ATTRIBUTION.md` |
| AC-3 §B1 五行回归 | 同上 | B1-R1 | 修复前 PASS / 修复后 fail |
| AC-4 围栏恰 2 条、零残留 | `lib/l3-section.sh`、`lib/l3-api.sh::_l3_parse_result` | B2-R2、B2-R6、B2-R7、B2-R10 | 连跑 5 轮：工件字节稳定、标记恰 1、围栏恰 2 |
| AC-5 无标记历史件仍可清除 | `lib/l3-section.sh::_l3_spans_impl`（`stop==0` 分支） | B1-R21、B2-R3、B2-R4 | 历史件完整清除且不误删后续段落 |
| AC-6 工件上限=字节 | `lib/l3-review.sh` 解析链 | B3-R4、B3-R5、B3-R5b | `_BYTES` > `_CHARS` > 历史直调 > 20000 |
| AC-7 旧键可用 + DEPRECATED | `29-independent-review.sh` §B3 | B3-R1..R3 | 子串断言 `DEPRECATED`，旧键仍生效 |
| AC-8 产物清单不截断 | `lib/l3-prompt.sh::_l3_build_prompt` | B4-R1..R4 | 41 条目全量；缺失只对**必备**件报 MISSING |
| AC-9 必备件 MISSING 语义 | `lib/l3-prompt.sh::_l3_build_prompt`（必备 6 件循环） | B4-R2、B4-R4 | 必备件缺失仍报 MISSING；非必备件不报 |
| AC-10 副本零漂移 | `sync-hooks.sh`（16 处镜像） | B5-R1..R4 | 漂移 0；B5-R4 自证"能发现漂移" |
| AC-11 双源同步 | `Makefile` `check-test-sync` | `make check-test-sync` | 只读比对门禁（写入同步是 `make test-sync`，刻意不进 `check`） |
| AC-12 空值可观测告警 | `29-independent-review.sh:274-275` | B1-R25、B1-R26、B1-R27 | 空值 → stderr 含 `L2 verdict not found` 且实参仍为合法枚举；有值 → 零告警；变异 → 被抓 |

**残余收口演进（2026-09-18 · 阶段 2 的 L3 critical ①）**：#3 手工贴入路径原为**提示词约束**，
现升级为 **PreToolUse 可执行拦截**（`_gate_is_unescaped_l3_paste`：未转义的「`---`+`## L3 …`」
块写入评审文件即 `exit 2`；子系统自写块与已转义引用放行）——回归 `B9-R1..R6`。
**仍存在的边界**：绕过 PreToolUse 的写入通道（例如 `Bash` 重定向）不在拦截范围内；
无标记历史件走 AC-5 兼容规则（`B2-R12` 语料现算 100% 有 `---` 前导，数字以 `corpus-count.sh` 为准）。
两条均登记于 ADR-026 与 MINOR-DEFERRED。

## 附 B · 阶段 1 审查发现处置台账（L3 重审 · 2026-09-18 18:33）

> 供下一轮审查直接核对，不依赖 200B 的注入摘要。

| 编号 | L3 判定 | 我方核对 | 证据 |
| --- | --- | --- | --- |
| critical ① | `l2-detect.sh:44-52` 的 L3 段结束判定仍按"下一个二级标题" | **Not-applicable**：该区间是 `_fk_l2_scope` 的文档注释；实现在 62-64 行调用 `_l3_section_spans` | `sed -n '44,52p'`（注释）、`sed -n '62,64p'`（调用）、B2-R9 |
| critical ② | 仅含 L3 段的工件会把段内 `**Verdict**: pass` 当 L2 结论 | **Not-applicable**：有标记时实测返回空 | `/tmp/c2-only-l3.md` → `wc -c` = 0；B1-R2x |
| critical ③ | AC-12 空值告警"静默缺失"（锚在 56-60 行） | **Not-applicable**：56-60 行是 Gate 1/2；告警在 274-275 行 | B1-R25/R26/R27 |
| major ① | `_l3_section_spans` 提前终止分支与 AC-1 冲突 | **Not-applicable**：`## ` 分支仅在 `stop==0`（无标记历史件）执行 | `_l3_spans_impl` 源码 + B2-R3 |
| major ② | AC-2 归因清单未交付 | **Fixed in:** M34 —— 清单此前**未进提示词**（白名单缺项）；已改全量 `*.md` | `L2-EMPTY-ATTRIBUTION.md` + B7-R1..R4 |
| major ③ | 多轮 L2 / 主 agent 段标题正则未定义 | **Fixed in:** 附 A 第 1 行给出锚点与枚举 | 语料复算 224 份 |
| major ④ | 缺 AC↔用例映射表 | **Fixed in:** 本附 A | — |
| major ⑤ | AC-4 围栏计数与 AC-1 对抗内容冲突 | **Not-applicable**：转义后载荷不可能贡献行首围栏 | B2-R10 |
| major ⑥ | `###` 子标题归属未定义 | **Fixed in:** 段内 `###` 及更低级属 L3 正文（只有行首 `## ` 触发边界） | B2-R1/R6 |
| minor ×9 | 见 INDEPENDENT-REVIEW-1.md「主 agent 响应」§5 | 逐条已改/已补/已说明 | 同节 |

**本轮附带修复（自查发现，非 L3 指出）**：M32 陈旧 `.done` 撤销（B6-R1..R6）、
写入侧 fail-closed（B2-R15/R16）、`l2-detect.sh` 论证注释瘦身（降低误读面）。
