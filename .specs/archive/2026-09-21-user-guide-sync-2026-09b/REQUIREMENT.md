# REQUIREMENT: 用户指南与用户指南 PPT 同步至 2026-09-21 现状（第二轮）

- **Change ID**: user-guide-sync-2026-09b
- **关联**: `@.specs/user-guide-sync-2026-09b/CHANGE.md`、`@.specs/CONTEXT.md`
- **上游输入**: 漂移审计报告 `/tmp/guide-drift-report.md`（43 条：14🔴 / 23🟡 / 6🟢 + §2 的 11 条候选新增 N1–N11 + §0 的独立发现 N12）；该报告为**只读实测产物**，全部结论带 `文件:行号` 证据。
- **修订记录**:
  - **v4（2026-09-21）**— 吸收阶段 1 L2 第三轮 R20–R26 与第四轮 R27–R34（落地位置逐条标注）：**R20** AC-9 判据换 `git status --porcelain` + `ls-files -o` 并补白名单（`.specs/CONTEXT.md` / `CHANGELOG` / `STATE` / `LESSONS` / change 目录 / vendor 测试镜像）；**R21+R27+R28** AC-2/AC-3 锚点逐条改为**与实现逐字一致且改前不成立**的字面串（D01/D03/D10/D13/D22/D43）；**R22** D33 反例改整格原文；**R23** D26 段落级 + D30 独有短语；**R24** 附录 A 母本声明；**R25** AC-10 修复命令按 target 分派（installed 用 `make dsh-sync`）；**R26/R30** 删除写死行号；**R31** 附录 A 回填 D30/D33；**R32** D19/D34/D36 锚点字面化；**R33** 补「其余 D 项承载」说明行；**R34** AC-9 补 `.specs/archive/**`；**R35–R39（第五轮）**：AC 表锚点补齐（D01/D19/D32/D36/D37/D38/D41 + AC-4 N3/N9）、AC-3 计数改可复算式、附录 A 回填 D34/D36 并把抽取器升级为**逐锚点等值**、修订记录补 R34、TEST.md 计数以实跑为准。
  - v3（2026-09-21）— 吸收阶段 1 L2 第二轮 R12–R19：**R12** 断言对象改为「四份副本同跑」（反例 = 四份各自 0 命中），并在 AC-2/AC-3 前置「根副本已与 bundle 对齐（T04 后）」；**R13** 明确锚点类别规则 + 9 条不可达锚点逐条改写为用户可见措辞；**R14** 修 D16/D18/D22/D30/D33 的泛词锚点；**R15** AC-5 不再写死 md5/行数（改「执行时记录基线」）；**R16** D43 补独立断言；**R17** AC-9 冻结路径改为仓库真实路径 + 白名单补 `flow-kit-bundle/test/` 同源副本；**R18** 表格转义管道修正；**R19** 定义「比较逻辑计时」的被测命令。
  - v2（2026-09-21）— 吸收阶段 1 L2 首轮 R1–R11（AC-10 Given 事实纠正、AC-4 锚点口径、AC-11 降挡、AC-2/AC-3 反例内联、AC-6/AC-9 deck 冻结、AC-1 日期豁免、AC-8 固定表；R7/R9/R10/R11 折入，R8 人工半段入 MINOR-DEFERRED）。

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想按指南操作时拿到的行为与 2026-09 的实现一致，以便不因过期路径/开关/默认值白折腾甚至误判（例：按旧文档去改项目级 `stop-hook.json`，实际配置自 2026-09-21 起只在用户级生效）。
- **US-2**：作为 flow-kit 维护者，我想指南 + PPT + 副本一次性同步到同一版本，以便不再出现「根副本与 bundle 副本分叉且无门禁守护」这种静默漂移。
- **US-3**：作为需要把 flow-kit 讲给别人听的用户，我想 PPT 能覆盖新增的安装面 / L3 审查链 / 质量门禁三块能力，以便演示材料与文档同一口径。

## 验收准则（AC）

### AC-1 · 版本与日期口径统一

- **Given** 当前日期口径三处不一致：`FLOW-KIT-用户指南.md:3`（版本行）= `2026-09-03`、`:1380`（分节「最后同步日期」）= `2026-07-13`、deck 封面 = `2026-09-03`（`deck_checks.py:50` 断言）
- **When** 本轮同步完成
- **Then**
  - 指南**版本行**与**分节「最后同步日期」**两处 = `2026-09-21`；deck 封面日期行 = `2026-09-21`
  - 全文对 `20260713` / `2026-07-13` **零命中**
  - `2026-09-03` 仅允许出现在**历史陈述句**中（原文摘录：「2026-09-03 起 L2/L3 模型按 `fk_resolve_model` 五级解析链解析」——这是 ADR-012/013 的生效时间锚，**不得改写为 09-21，也不得删除**；**行号不写死**，以实跑时当前值为准 · v4 · R26）
- **验证方式**:
  ```bash
  # 回归确认（T04 后可跑；四份副本逐一执行，任一份不满足即 fail）
  for f in FLOW-KIT-用户指南.md flow-kit-bundle/FLOW-KIT-用户指南.md \
           dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md \
           dist/dsh-flow-kit/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md; do
    grep -q '^> 版本: 2026-09-21' "$f" || echo "FAIL version-line: $f"
    grep -q '最后同步日期\*\*: 2026-09-21' "$f" || echo "FAIL section-date: $f"
    test "$(grep -c '20260713\|2026-07-13' "$f")" = 0 || echo "FAIL stale-version: $f"
    test "$(grep -n '2026-09-03' "$f" | grep -vc '起')" = 0 || echo "FAIL 09-03-not-historical: $f"
  done
  ```
  TEST.md 记录「日期锚点白名单」：**只登记原文摘录 + 判据，不写死行号**（行号以实跑时的当前值为准 · v4 · R26——三份文档曾出现 `:916/:946`、`:922/:952`、实测 `:998` 三套行号）。**修订期以 bundle 副本为准**，四份同跑在 T04 对齐之后。

### AC-2 · 14 条 🔴 事实错误全部修正（反例锚点内联）

- **Given** 漂移报告列出 14 条 🔴；每条都有明确的**旧措辞**（可作反例）与**新措辞**（可作正例）
- **When** 逐条按报告「建议改法」修订
- **Then**
  - **断言对象 = 四份副本各自满足**（反例在每一份都 0 命中，正例在每一份都 ≥1 命中）——单一副本通过不算通过（v3 修订，R12）
  - **前置条件**：跑本矩阵前，根副本须已与 bundle 对齐（T04 的 `cp`）；对齐前只核 bundle 副本，且必须记录基线
  - **already-fixed 条目**（实测 bundle 副本中反例已为 0：D01 `核心引擎 + skills + brooks-lint + hooks`、D08 `--sub-goal-4`）→ 标 `already-fixed`：**仍须核对根副本同串归零**（T04 对齐后四份同验），不得因 bundle 已绿而免检
  - 下表每行的「反例」在四份副本中 **0 命中**、「正例」**≥1 命中**；反例一律用 `grep -F` 字面匹配

| # | 反例（= 0 命中 · 四份同验 · 字面 `grep -F`） | 正例（≥ 1 命中 · 四份同验 · **字面串**；正则须在格内显式标注 `regex:`） |
|---|---|---|
| D01 | `核心引擎 + skills + brooks-lint + hooks` | `brooks-tools` + `需再加` + `--user`（三串都要命中 · v4.1） |
| D08 | `--sub-goal-4` | `SUB_GOAL_4`（或「进入阶段 4 自动从 AC 提取」表述） |
| D09 | `.specs/lessons/` | `.specs/LESSONS.md` |
| D10 | `ARCHIVE.md` | `UAT.md` + `archive/<YYYY-MM-DD>-<change-id>/`（**v4 · R28：主表/正文/`verify-ac.sh` 三处统一为这一套；正文 `:1405` 的旧占位写法已一并正式化，使锚点唯一**） |
| D11 | `三轮审查` | `单轮合并审查` |
| D16 | `项目根 \`ARCHITECTURE.md\``（**收窄**：必须含文件名，避免误伤 `.flow-active`/`.specs/` 的合法「项目根」表述） | `.specs/ARCHITECTURE.md` |
| D19 | `pre_tool_use_gates.auto_checkpoint` | `占位块` + `代码未消费`（**v4 · R32：两串都要命中**，与 `verify-ac.sh` 的判据实现一致；删掉实测 0 命中的「此键当前无实际作用」） |
| D20 | `此字段仅作末级兜底` | `已废弃` + `l3-default=` |
| D21 | `.flow-active.independent-review`（作为审查产物锚点） | `.independent-review-<phase>.done` |
| D22 | `允许手动绕过` | `由子系统自动` + `L3_verdict=skipped`（**v4：改用实现中的真实子串**——`**由子系统自动**写` 里的 `**` 会打断「子系统自动写」，故锚点取 `由子系统自动`；白名单：配置键行 `max_failures_before_bypass` 允许保留） |
| D23 | `` matcher: `Bash`， ``（**收窄**：仅当后接「gate_config 命中的阶段」这半句语境，v3 改为按整句匹配） | `` `Bash|Write|Edit` `` **或** 三串分别 ≥1（`Bash` / `Write` / `Edit` 同句式） |
| D31 | `随 flow-kit bundle 分发` | `不由 flow-kit bundle 分发` |
| D33 | **整格原文**（按整格 `grep -F`）：`` \| 阶段名 \| `1-requirement` / `2-design` / `6-review` \| 开启独立 review（L2+L3） \| `independent` / `true` / `off` / `false` \| ``（**v4 · R22**：4 个旧值串单独**不参与断言**——报告的建议改法本身要求写入「旧值 `independent`/`true` 自动映射、`false` 视为 `off`」，单串 0 命中不可满足） | `both` + `L2` + `L3`（同句共现；`off` 不作断言） |
| D34 | `编辑 .claude/stop-hook.json`（旧「方式 C」指令句；**v4.5 · R1：原反例 `.claude/stop-hook.json` 是正例 `~/.claude/stop-hook.json` 的子串 → 两向不可能同时成立**） | `~/.claude/stop-hook.json` + `~/.dsh/stop-hook.json` + `~/.config/opencode/stop-hook.json`（三条**字面路径**都要命中） |

- **D08 处置口径（实测优先）**：漂移报告 §4 保留「`--sub-goal-N` 是否被隐式解析」为未确认；本 AC 采信**全仓 grep 实测结论**（`--sub-goal-4` 仅命中指南自身，实现只认 env `SUB_GOAL_4..7`）。TEST.md 必须记录复验命令 `grep -rn "sub-goal-" flow-kit-bundle/ dsh-flow-kit/` 的输出，且**若复验推翻结论则按实测改写**。
- **验证方式**: TASK.md 附录 A 的逐行 grep 断言（本轮实跑输出记入 TEST.md），反例用 `grep -F` 字面匹配避免正则误伤。

### AC-3 · 🟡/🟢 过期项修正（29 条，含反例锚点）

- **Given** 漂移报告列出 23 条 🟡 + 6 条 🟢
- **When** 逐条按报告建议修订
- **Then** 每条体现报告给出的现行事实；**凡报告中存在明确旧措辞的条目一律补反例断言**（下表），其余仅留正例并显式标注「无反例锚点」。断言对象与前置条件同 AC-2（四份同验、根副本先对齐）。**白名单**：`max_failures_before_bypass` 的配置键说明行允许保留「绕过」语义词（它是配置键名的一部分，不是旧口径的「手动绕过」）。

| # | 反例（= 0 命中 · 字面 `grep -F`） | 正例（≥ 1 命中 · **字面串**；正则须在格内显式标注 `regex:`） |
|---|---|---|
| D03 | `仅安装 hooks（需配合 --project）` | `仅安装 hooks + \`.specs/STATE.md\` 模板`（**v4 · R21：带回反引号**，与实现 `:89` 逐字一致） |
| D04 | `若走 dsh plugin add/update 重装`（**v4.6 · 阶段 3 L2 第七轮 R4**：原反例串在四份副本 `:124` 仍 1 命中——它现在是**合法的条件句**（「若走 … 重装，重装后需再跑一次」），故反例改用旧的首选更新路径整句；判据实现在 `verify-ac.sh` 同步） | `make dsh-sync` |
| D12 | `<title>任务标题</title>` | `<name>` + `<read_files>` + `<write_files>` |
| D13 | `只在同波次内` | `同波次内不应有` + `跨波次必须显式声明`（**v4 · R27：与实现 `:623` 逐字一致**；旧写法两串在正文均 0 命中） |
| D14 | `🟡 Major`（作阶段 6 现行分级） | `Important` |
| D18 | `- **标准**（默认）：全维诊断`（**v4.6 · R6 注明**：旧措辞是**整段删除**，故该反例的判定力等价于「不写回即绿」——保留为回归护栏；真正的判定力在正例三串） | `快速体检` + `完整审计` + `单维深挖`（报告原文措辞） |
| D26 | （**无反例锚点** · v4.2 依 L3 critical 修订：旧清单是列表结构，无法用单一 `grep -F` 字面串表达） | **段落级正例**：`awk '/^### SessionStart Hook/{f=1} f&&/^### /&&!/^### SessionStart Hook/{f=0} f'` 抽取 SessionStart 段后，段内必须命中 `archive-uncommitted`（全文件级 grep 改前即绿——pre-commit 段本就有该串） |
| D30 | `"31-auto-advance": true` | `31 号由 ` + `goal.auto_advance` + `驱动`（**v4 · R23**：`无独立开关` 改前已 3 命中，无判定力；改用报告建议改法的**独有短语**） |
| D32 | （无反例锚点） | `skill 文件` 与 `生成的 deck 工程结构` |
| D36 | `stop-hook.json           # stop hook 配置`（项目级树中的该行） | `配置不在项目里` + `stop-hook.json`（**v4 · R32：字面化**） |
| D37 / D38 | （无反例锚点） | **八串都要命中**（不是任一）：`l3-api.sh` · `l3-done.sh` · `l3-prompt.sh` · `l3-section.sh` · `l3-truncate.sh` · `runtime-adapter.sh` · `gate-helpers.sh` · `gate-checks-review.sh` |
| D41 | （无反例锚点） | `requirement-review` / `spec-test` / `task-test` |
| D43 | `2026-07-13` | `regex:^> 版本: 2026-09-21` 与 `regex:最后同步日期\*\*: 2026-09-21`（**v4 · R21：显式标注为正则**，字面 `grep -F` 不成立） |

- **其余 D 项承载说明（v4 · R33）**：报告 43 条中，D02/D05/D06/D07/D15/D17/D24/D25/D27/D28/D29/D35/D37/D38/D39/D40/D42 共 **17 条**没有独立反例锚点（多为「缺项补全」型）。它们的承载如下，**不另立 AC 行**：
  - 与 AC-4 的 N 项同源：D24→N8（`runtime-edit-guard`）· D25→N2（`max_artifact_bytes`）· D26 已在表内
  - 由 TASK.md 附录 A 的正例行承载：D02（安装选项表补项）· D05（`v0.2.0`）· D37/D38（`stop/lib` 与 `pre-tool-use` 清单补项）· D40（`~/.local/bin`）· D41（预设名）
  - 由正文修订直接体现、无独立断言：D15/D35/D39/D42（**v4.5 · R1：D06/D07/D29 已补独立断言，移出本行**）
  - **计数口径（v4.1 · 可复算式）**：AC-2 表 14 行 = 报告 14 条 🔴；AC-3 表 **13 行**覆盖 **14 个 D 项**（D37/D38 合并一行）；本说明覆盖 **15 条**（列出 17 条，减去已在表内的 D37/D38）→ 14 + 15 = **29 条** = 报告 23 🟡 + 6 🟢 ✅。集合断言：`AC-2 ∪ AC-3 ∪ 本说明 = 报告 §1 的 43 条 D 项全集`（由 `check-appendix-superset.py` 对附录 A 做逐锚点比对间接守护）
- **D33 的未转义原文（v4.2 依 L3 minor 修订）**：AC 表内需转义管道以维持表格结构；机械执行请用下面的**未转义完整行**（`grep -F` 用）：
  ```
  | 阶段名 | `1-requirement` / `2-design` / `6-review` | 开启独立 review（L2+L3） | `independent` / `true` / `off` / `false` |
  ```
- **验证方式**: TASK.md 附录 A + TEST.md 断言矩阵（逐条实跑输出）

### AC-4 · 候选新增项就位（N1–N11 + N12 分列）

- **Given** 报告 §2 表格有 **N1–N11** 共 11 行，报告 §0 另有独立发现 **N12**（副本一致性门禁）
- **When** 本轮同步
- **Then** N1–N11 各自落地。**锚点类别规则（v3 · R13）**：锚点必须是**用户在配置文件 / 目录树 / 命令行 / 正文里真的能看到**的串——配置键名（`max_artifact_bytes`）、hook 入口脚本名（`runtime-edit-guard`）、命令（`make dsh-sync`）、路径（`l3.env`）、概念措辞（`占位块` / `path-guard` / `凭证`）都属此类；**仅排除内部契约标记**（如 `<!-- /L3-SECTION -->`、KDF/签名行）——它们不进指南。正例锚点在本轮**由修订创建**（改前 0 命中、改后 ≥1 命中属正常，不视为「不可达」）。

| # | 归属小节 | 用户可见 grep 串（改后 ≥1） |
|---|---|---|
| N1 L3 凭证（必配） | §7「L3 凭证」 | `FLOW_KIT_L3_AUTH_TOKEN` · `ANTHROPIC_AUTH_TOKEN` · `l3.env` · `死锁` |
| N2 工件上限 | §7「配置文件」 | `max_artifact_bytes` · `80000` · `字节` |
| N3 门禁六门 | §7 pre-commit / §12 质量门禁处 | `check-dist` · `check-validate` · `check-hooks-sync`（`六门` 为可选措辞，不作断言） |
| N4 hooks 副本漂移 | 同 N3 | `hooks-sync` · `check-hooks-sync` |
| N5 dsh-sync | §2.4 | `make dsh-sync` · `DSH_PROFILE` |
| N6 verify-claims | 同 N3 | `verify-claims` |
| N7 `/flow l2-review` | §4 子命令表 | `/flow l2-review` |
| N8 runtime-edit-guard | §7 PreToolUse 表 | `runtime-edit-guard` |
| N9 path-guard 拒写 `.done` | §7「独立 Review 机制」（与 N7 同节，不单列小节） | `path-guard`（或「拒绝主 agent 直写 `.done`」等价表述） |
| N10 L3 段契约 + 前轮反馈优先 | §7「独立 Review 机制」 | `ADR-025` **+** `前轮反馈`（后果句必检串 · v4.2 依 L3 major 修订） |
| N11 不可信载荷边界 | §7「独立 Review 机制」 | `ADR-026` **+** `不可信`（后果句必检串：外部模型返回内容被视为不可信输入 · v4.2 依 L3 major 修订） |
| N12 副本守护 | 由 AC-10 承载（不进指南正文） | 见 AC-10 |
| N13 三平台口径 | §7「配置文件」/ §12 全局树 | `~/.claude/stop-hook.json` · `~/.dsh/stop-hook.json` · `~/.config/opencode/stop-hook.json`（**v4.5 · R1：兼容性 NFR 的 AC 落点**） |

- **安全反例（N1 附，折入 L2 R9）**：`grep -nE '(sk-[A-Za-z0-9]{8,}|AUTH_TOKEN=.{16,})' <四份副本>` → **0 命中**（指南只写变量名与加载方式，绝不写真实 token）
- **验证方式**: 上表逐串 `grep -c` ≥1；安全反例四份逐一跑

### AC-5 · 四份副本逐字节一致（含同步顺序）

- **Given**（v3：**不写死 md5 / 行数**，改为「执行时记录基线」· R15）当前四份副本**不一致**：根副本停留在上一轮同步（2026-09-03）的内容，bundle 副本已被本 change 持续改写，dist 两份跟随上一轮打包 → 执行开始时先记录四份的快照（`md5sum` + `wc -l` + `mtime`）作为基线证据
- **When** 同步完成
- **Then**
  - 四份 md5 **唯一值 = 1**（与快照对比，证明同步确实发生）
  - 同步方向显式固定：**底稿 = `flow-kit-bundle/FLOW-KIT-用户指南.md`**（`package-dsh-plugin.sh:45` 的 `COPY_OPTIONAL` 映射源就是它）→ 覆写根副本 → 按同一映射**窄路径 `cp`** 到 dist 两份（`bash package-dsh-plugin.sh --check` 由红转绿）。**只改根副本会让 `check-dist` 转红**（该门禁逐文件 `cmp` 比对 bundle→dist）
- **验证方式**: `md5sum` 四路径 | `awk '{print $1}'` | `sort -u` | `wc -l` = 1；且 `bash package-dsh-plugin.sh --check` rc=0

### AC-6 · deck 重建 + 扩页 + 断言有效性实测

- **Given** 现行 `slides.json` 20 页；`deck_checks.py` 的 `EXPECT_PAGES=20`、封面断言 `2026-09-03`、旧 `KEY_STRINGS`/`BANNED`
- **When** 运行生成器重建 `flow-kit-用户指南.pptx`
- **Then**
  - 页数 ≥ **24**（净增 ≥4），含 4 张新专页（**标题与关键串固定如下** · v4.2 依 L3 major 修订，使「删页」实测可复现）：
    | 专页标题（唯一标识） | 该页必检关键串（≥1） |
    |---|---|
    | `安装面：作用域与入口` | `make dsh-sync` |
    | `L3 审查链：凭证 · 熔断 · 工件上限` | `FLOW_KIT_L3_AUTH_TOKEN` |
    | `质量门禁：make check 六门` | `check-dist` |
    | `版本与副本口径` | `2026-09-21` |
    有效性实测口径：**删除上述四页中的任意一页**（改标题或删条目）→ `deck_checks.py` 必须 rc≠0（标题寻址 KeyError 或关键串缺失）→ 还原复绿
  - 封面日期 `2026-09-21`
  - **新断言清单显式登记**（写入 TEST.md）：① 页数下限 24；② 封面日期；③ **四张**新专页各自的 ≥1 关键串；④ `BANNED` 至少含本轮修掉的旧措辞（`.specs/lessons/`、项目级 `stop-hook.json`、`三轮审查`、`20000 字节`、**`归档（ARCHIVE）`**——不用恒真的 `ARCHIVE.md`，v3 修订 · R7）；⑤ 逐页非空
  - **断言有效性实测**（对照 AC-10 同标准）：删掉 `slides.json` 中任一专页 → `deck_checks.py` 必须 rc≠0 → 还原 → 复绿；改封面日期 → 必须 rc≠0 → 还原 → 复绿。两组结论记入 TEST.md
- **验证方式**: `python3 .specs/user-guide-deck-gen/build.py && python3 .specs/user-guide-deck-gen/deck_checks.py` → `deck_checks OK`；注入/还原两轮实跑

### AC-7 · 渲染验证（机检 + 人工两段）

- **Given** 环境有 LibreOffice 24.2 + pdftoppm
- **When** 对重建后的 deck 做 `soffice --headless --convert-to pdf` + `pdftoppm` 抽页
- **Then**
  - **机检**：PDF 页数 = PPT 页数；每页 PNG 尺寸一致且非纯白（无空页）；产物落在 `.specs/user-guide-sync-2026-09b/render-preview/`
  - **人工**：固定抽检清单 = 封面 + **4 张**新专页（标题见 AC-6 表）+ 末页，逐页核「文字是否溢出框外 / CJK 是否缺字方框」，结论与文件路径记入 TEST.md（v4.2 依 L3 major 修订：原写「3 张」与 AC-6 的 4 张不一致）
- **验证方式**: `pdfinfo`（或 `pdftoppm` 计数）比对页数 + `identify`/PIL 检查 PNG 尺寸与非空；人工项留结论

### AC-8 · README / dsh README 口径核对与处置（固定表）

- **Given** `README.md`（L3 段在 `:101-129`：凭证 + `max_artifact_bytes` 单位）与 `dsh-flow-kit/README.md` 可能与 2026-09 后续 change 漂移；实测 `README.md` 全文**无** `make check` / 门禁枚举 → 该项不作为核对项
- **When** 逐条核对
- **Then** TEST.md 出现一张固定表，每行 = `条目 | 证据行号 | 结论（改 / 不改） | 改动的旧→新措辞`，条目固定为：
  1. 安装入口与作用域（`--global` 是否含 hooks；`--project` 配置口径）
  2. 配置路径单一源（用户级三平台路径）
  3. 工件上限单位与默认值（字节 · 80000 · 旧名 `max_artifact_chars` 已废弃）
  4. L3 凭证与熔断（三 Path · bypass 语义）
  5. dsh 插件更新入口（`make dsh-sync`）
  6. dsh 侧 `docs/README` 与源 `README` 的同步关系（dist 产物不手工编辑）
  「不改」的行必须给出**未改理由**（≥1 句），不允许空白
- **验证方式**: 表存在且 6 行齐全；改动行有对应 diff

### AC-9 · 改动边界与回归（白名单 · v4 修正判据）

- **Given** 本 change 定性为纯文档/演示同步
- **When** 完成全部修订
- **Then** 工作区**全部变更路径**（含新增/未跟踪与 dist 再生件）落在白名单内：
  - 指南四副本：`FLOW-KIT-用户指南.md`、`flow-kit-bundle/FLOW-KIT-用户指南.md`、`dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md`、`dist/dsh-flow-kit/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md`
  - `flow-kit-用户指南.pptx`、`.specs/user-guide-deck-gen/{slides.json,deck_checks.py,build.py,layouts.py,README.md}`
  - `README.md`、`dsh-flow-kit/README.md`、`dist/dsh-flow-kit/README.md`
  - `test/test_guide_copy_parity.bats` + `flow-kit-bundle/test/test_guide_copy_parity.bats` + `dist/dsh-flow-kit/vendor/flow-kit-bundle/test/test_guide_copy_parity.bats`（同源镜像 / 窄路径映射产出）
  - **`.specs/CONTEXT.md`**（本 change 术语与已锁决策沉淀）· **`.specs/CHANGELOG.md` · `.specs/STATE.md` · `.specs/LESSONS.md`**（AC-11 要求更新）· **`.specs/user-guide-sync-2026-09b/**`**（change 产物）· **`.specs/archive/**`**（阶段 7 归档落点 · v4 · R34）
  - `dist/` 其余再生件由 `make check-dist` 守护（`.gitignore` 忽略，git 结构性看不见）
  且以下路径的 diff **= 0**：`flow-kit-bundle/hooks/**`、`dsh-flow-kit/lib/**`、`flow-kit-bundle/skills/**`、`flow-kit-bundle/flow-kit/prompts/**`；`make check` 六门全绿
- **验证方式**（**v4 · R20：`git diff --name-only` 看不到新增文件与被忽略的 dist，故换判据**）:
  ```bash
  # ① 变更全集 = 已跟踪修改（含暂存）+ 未跟踪新增
  git status --porcelain | awk '{print $2}'      # 必须逐条 ⊆ 上面的白名单集合
  git ls-files -o --exclude-standard             # 未跟踪新增同验（bats ×2 / change 目录）
  # ② 禁动域 diff = 0
  git diff --name-only -- flow-kit-bundle/hooks dsh-flow-kit/lib flow-kit-bundle/skills flow-kit-bundle/flow-kit/prompts | wc -l   # 期望 0
  # ③ 全量门禁
  make check
  ```
  判据时点：**阶段 5 结束前**（其后 AC-11 的归档动作仍限同一白名单）

### AC-10 · 副本一致性守护（防复发 · 真实缺口 = root↔bundle）

- **Given**（**v2 纠正**）`bundle → dist` 两条边**已有守护**：`package-dsh-plugin.sh` 的 `COPY_OPTIONAL`/`COPY_DIRS` 映射由 `--check` 逐文件 `cmp -s` 比对，且已挂在 `Makefile` 的 `check-dist`（属 `make check` 第 6 门）——即「bundle 改了但 dist 没重建」今天就会被检出。
  **无守护的是 `root ↔ bundle` 这条边**（真相：`5583e2a` 只改了 bundle 副本，根副本落后 2 行，四份 md5 分裂为 2 值，而 `make check` 全绿）
- **When** 本 change 增加守护
- **Then**
  - 存在**可失败**的机械断言，覆盖 `root ↔ bundle ↔ dist×2` **四份整体一致**（md5 唯一值 = 1），失败信息**指名**哪两份不一致；修复命令按 target 类型给（**v4 · R25**）：仓内三份用 `cp flow-kit-bundle/FLOW-KIT-用户指南.md <target>`；**已安装插件目录（`~/.dsh/profiles/${DSH_PROFILE:-web}/node_modules/dsh-flow-kit/…`）的权威入口是 `make dsh-sync`**（`DSH_PROFILE=<名>` 覆盖）——**不得**对该目录附 `cp` 建议（那等于直改运行时副本，`runtime-edit-guard` 会 deny）
  - **降级语义明确（v3 · R5/R12）**：`dist/` 不存在（fresh clone，被 `.gitignore` 忽略）时，dist 相关两份断言**显式 SKIP 并打印原因**（沿用 `check-dist` 口径），`root ↔ bundle` 边**永远执行**；`~/.dsh/profiles/${DSH_PROFILE:-web}/node_modules/dsh-flow-kit/{docs,vendor}` 两份**存在时**必须与 dist 一致（「when present」范式，R4；**守护域与 `Makefile` 中 `DSH_PROFILE ?= web` 该行同源（按文本定位，不写死行号）**，不扫全部 profile——否则第二个装过插件的 profile 永远对不齐且 `make dsh-sync` 修不了），不存在则 SKIP
  - **新增 deck 新鲜度断言（v3 · R3/R12）**：`flow-kit-用户指南.pptx` 页数 == `len(slides.json)`，且**封面日期串 == 指南版本行的日期**（口径统一，不在断言里二次写死日期）；`pptx` 不存在或 `python3 -c "import pptx"` 失败（fresh clone / 无 python-pptx 的 CI）→ 该组断言**显式 SKIP 并打印原因**；时序约束：阶段 4 中「重建 pptx」必须早于任何 `make test` / `make check`
  - 断言落在 `test/test_guide_copy_parity.bats`（DESIGN D2）+ 同源镜像 `flow-kit-bundle/test/test_guide_copy_parity.bats`（`make test-sync` 产出），且**真的会被跑到**：`make test` 以 `npx bats test/` 全目录收集 → 由 `make check` 第一门执行；验收以**行为**证明（实跑该用例文件通过 + 注入漂移后整条断言 rc≠0），不以「Makefile 里出现某字符串」这类文本判据代替
  - 断言**非恒绿**：注入 1 字节漂移 → 变红 → 还原 → 复绿（实测记录入 TEST.md）
  - **耗时证据（v3 定义被测命令 · R19）**：`time md5sum <四路径>` 的 real 值（3 次中位数，**不含** `npx`/bats 进程启动、不含 python-pptx 读取），须 < 1s；断言粒度为**四份 md5 一次性比较**，不重复 `check-dist` 的逐文件遍历
- **验证方式**: `npx bats test/test_guide_copy_parity.bats`；注入/还原两轮；`time md5sum` ×3 记录

### AC-11 · 独立审查与归档闭环（含降挡口径）

- **Given** pipeline `gate_config` 六阶段全 `both`（1/2/3/5/6/7）、`auto_advance=true`
- **When** 各阶段产物完成后
- **Then**
  - 每阶段 `INDEPENDENT-REVIEW-<N>.md` **必含 `## L2 盲审` 段**（子代理盲审）；阶段 1 的 L2 首轮 verdict=fail → 已按 R1–R11 修复并**重跑 L2**，最终以**最后一轮** L2 结论为准
  - L3 段由 `l3_review_run` 产出（6 键 KVP `.done` + L3 段）。**降挡可接受但必须留痕**：凭证不可用 / 超时 / 连续 fail 达阈值时，接受以 `l3-bypass` / `timeout` 锚点 + `L3_verdict=skipped` 的审计段替代，并在 TEST/REVIEW 显式登记「降挡原因 + 重试方式（删除 `.specs/<id>/.l3-attempts-<phase>` 后重跑）」
  - 「阶段 6 双轨 pass（非 bypass）」**仅在凭证可用时**成立；若降挡，则以「L2 pass + L3 审计段（含原因）」作为归档条件，且 REVIEW.md 必须写明
  - 最终归档至 `.specs/archive/2026-09-21-user-guide-sync-2026-09b/`，并更新 `CHANGELOG.md` / `STATE.md` / `LESSONS.md`
- **验证方式**: `ls .specs/<id>/.independent-review-*.done` + 各 `INDEPENDENT-REVIEW-*.md` 的最后一轮 verdict 行 + `STATE.md.last_change_archived`

---

## 范围切分

### v1（本次必做）

- AC-1 ~ AC-11 全部。
- 指南全量修订：§1 组件表口径、§2 安装面、§3 核心概念、§4 命令表、§5 生命周期（阶段 3/4/6/7）、§6 横向命令、§7 Stop Hook（PreToolUse/SessionStart/配置块/L2-L3 机制/凭证）、§9 ppt skill 归属、§10 工作流示例、§12 文件结构索引、附录 gate_config 参考。
- deck 扩页重建（≥24 页）+ 生成器与断言同步 + 断言有效性实测。
- 四副本一致性 + 新增机械守护（`test/test_guide_copy_parity.bats`）。
- README / dsh README 口径核对与连改（固定表）。

### v2（下一轮考虑，不本次）

- `flow-kit-技术设计.pptx` 同步（另一受众，需独立 change）。
- `flow-kit-ecosystem-guide.md` 全量重写（生态清单）。
- 指南的 ADR 索引章节（把 `.specs/adr/` 001–027 映射进指南附录）——本轮只在相关小节内联引用 ADR 编号。
- `install.sh --self-test` 的文档化（实现侧未定型，不写进指南）。
- 把 `deck_checks.py` 接入 `make check`（本轮只做「断言有效性实测」，不新增门禁 target —— DESIGN D2 口径）。

### out（永远不做）

- 把指南正文改写成英文或双语（当前无此诉求，成本高）。
- 让指南正文自动从源码生成（维护源仍是人工 md；本轮只补「副本一致」这一层机械守护）。
- 在指南里复制 `hooks/**` 实现细节（指南定位是用户视角，不逐行解释实现）。

---

## 非功能性需求

- **性能**: 新增守护的**md5 比较** < 1s（被测命令逐字：`time md5sum <四路径>` 的 real，3 次中位数；不含 `npx`/bats 启动、不含 python-pptx 读取），记入 TEST.md。
- **可访问性**: deck 渲染须满足「无缺字 / 无溢出」；正文字号不小于既有生成器基线（不改 `theme.py` 基线）。
- **安全**: 指南描述 L3 凭证时**不得写入任何真实 token**（只写变量名与加载方式，模板引用 `.claude/l3.env.example`）；反例断言见 AC-4。
- **兼容性**: 指南同时面向 Claude Code / dsh / OpenCode 三平台，涉及路径与命令处必须标明平台差异（不得只写其一）。**落点（v4.2 依 L3 major 修订）**：由 AC-4 的三平台路径断言承载——`~/.claude/stop-hook.json` · `~/.dsh/stop-hook.json` · `~/.config/opencode/stop-hook.json` 三条字面路径都必须出现（AC-4 N13）。
- **可观测性**: 无。

## 依赖与假设

- 依赖：python-pptx ≥ 1.0.2（实测 1.0.2）、LibreOffice ≥ 24.2（实测 24.2.7.2）、pdftoppm、bats-core（`npx bats`）。
- 依赖：漂移报告 `/tmp/guide-drift-report.md`（本轮唯一事实基线；其结论若被实测推翻，以实测为准并在 TEST/REVIEW 记录——D08 即此类的已知候选）。
- 假设：`flow-kit-bundle/FLOW-KIT-用户指南.md` 为较新基线（含 2026-09-21 配置用户级措辞），根副本落后 2 行 → 修订以 bundle 副本为底稿（AC-5 固定该方向）。
- 假设：L3 外部模型可用（站点默认 `FLOW_KIT_L3_DEFAULT_MODEL=deepseek-v4-flash-0731`）；凭证缺失时按 AC-11 的降挡口径透明记录，不伪造 pass。

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
