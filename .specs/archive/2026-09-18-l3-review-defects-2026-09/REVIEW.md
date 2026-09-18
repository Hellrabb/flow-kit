# REVIEW: L3 审查链五类缺陷修复（双轮审查 · spec 合规 + 代码质量）

- **Change ID**: `l3-review-defects-2026-09`
- **关联**: `@.specs/l3-review-defects-2026-09/REQUIREMENT.md`、`DESIGN.md`、`TASK.md`、`DEV-SUMMARY.md`、`TEST.md`
- **独立审查记录**: `INDEPENDENT-REVIEW-1.md`（阶段 1/3）、`INDEPENDENT-REVIEW-2.md`（阶段 2）、
  `INDEPENDENT-REVIEW-3.md`（阶段 3）、`INDEPENDENT-REVIEW-5.md`（阶段 5）、`INDEPENDENT-REVIEW-6.md`（本阶段）、
  `INDEPENDENT-REVIEW-7.md`（阶段 7）——每份由 L2 盲审（全新上下文子 agent）+ L3（真实外部 API）双轨产出。
- **时间戳语义（防"时间倒挂"误读）**：`INDEPENDENT-REVIEW-*.md` 由审查子系统在工件定稿**之后**追加，
  其 mtime 必然 **≥** 工件 mtime；绑定关系以记录内的 `L3_artifact_hash:` 行为准，**不以 mtime 判断**。
- **阶段 4 无独立审查记录（有意）**：`gate_config` 只含六键 `1-requirement / 2-design / 3-task / 5-test / 6-review / 7-integration`，
  阶段 4（开发）不在其中 → 不存在 `INDEPENDENT-REVIEW-4.md` 与对应锚点；`DEV-SUMMARY.md` 是它的产物。
- **不产出 `INTEGRATION.md`（有意）**：本项目阶段 7 的验收产物是 `UAT.md` + CHANGELOG 更新；这也正是 §B4 的修复点
  （清单"存在才列"，不再硬编码 INTEGRATION.md 造成假缺失）。
- **severity gating（ADR-017）**：🔴 Critical 阻塞 toll-gate；🟡 Important 进入 fix loop；
  🟢 Minor 只登记 `MINOR-DEFERRED.md`（**M1–M47**）不进 fix loop。

---

## 第一轮 · Spec 合规审查

### 1.1 AC 覆盖（逐条）

| AC | 实现锚点 | 验证 | 结论 |
| --- | --- | --- | --- |
| AC-1 L2 层限定 + 免疫 L3 段/大小写 | `l2-detect.sh::_fk_l2_scope`（62-64 调 `_l3_section_spans`）+ 三层提取 | B1-R2[1-4]、B2-R9/R11/R13/R17/R18/R19 | ✅ 合规 |
| AC-2 活语料零非枚举 + 每份空值可归因（数值预算 ≤8 只对**基线语料**） | 同上 + `L2-EMPTY-ATTRIBUTION.md`（`corpus-count.sh --attribution` 机械再生） | 「AC2: 活语料零非枚举 + 每份空值可归因」→ 现场 `234 108 139 139 8 0`、`base_empty=8`、清单 8 行 | ✅ 合规 |
| AC-3 §B1 五行回归 | 同上 | B1-R1 | ✅ 合规 |
| AC-4 重写幂等（标记/围栏/空行） | `l3-section.sh` + `l3-api.sh::_l3_parse_result` | B2-R2/R6/R7/R10 | ✅ 合规 |
| AC-5 无标记历史件清除 | `_l3_spans_impl` 的 `stop==0` 分支 | B1-R21、B2-R3/R4/R12 | ✅ 合规 |
| AC-6 上限=字节 | `29-independent-review.sh` 解析链 | B3-R4/R5 | ✅ 合规 |
| AC-7 旧键可用 + DEPRECATED | 同上 | B3-R1..R3 | ✅ 合规 |
| AC-8 产物清单不截断 | `l3-prompt.sh::_l3_build_prompt` + `_l3_extra_deliverables` | B4-R1、B7-R1..R4 | ✅ 合规 |
| AC-9 必备件 MISSING 严格 | 必备 6 件循环 | B4-R2/R4 | ✅ 合规 |
| AC-10 副本零漂移 | `sync-hooks.sh`（7 落点 × 四类树） | B5-R1..R5；`--check` 漂移 0 | ✅ 合规（含反向残留） |
| AC-11 结构门槛 + 双源同步 | `Makefile`、`test_lib_split_metrics.bats` | `make check-test-sync`；l3-api.sh **250/250** | ✅ 合规 |
| AC-12 空值可观测告警 | `29-independent-review.sh:274-275` | B1-R25/R26/R27 | ✅ 合规 |

**范围合规**：v1 全覆盖，无范围蔓延；out-of-scope（v2 项）均登记为 M 编号（M7/M8/M17/M36/M37/M38）。

### 1.2 与报告 §B1–§B5 的对应

| 报告缺陷 | 独立复测 | 修复 | 回归 |
| --- | --- | --- | --- |
| §B1 提取抽错 verdict（取到 L3 段/JSON/大小写） | 五行临时件复现 | 限定 L2 层 + 行首锚定 + 末次 + 小写归一 | B1（27 例） |
| §B2 L3 段重写按标题截断、无结束标记 | 载荷含行首 `## ` 复现 | 显式结束标记 + 写入侧转义（ADR-026） | B2（21 例） |
| §B3 `max_artifact_chars` 名"字符"实"字节" | CJK 件被截 2/3 | 改名 + 保留旧键 + 5 处载体写明 | B3（7 例） |
| §B4 阶段 7 清单 `head -30` + 硬编码 INTEGRATION.md | 41 条目目录漏 14 | 全量清单 + 必备/补充分离 | B4（4 例）+ B7（5 例） |
| §B5 安装树不同步 | 7 份 prompt 副本/`~/.claude/hooks`/`~/.config/opencode/hooks` 陈旧 | `sync-hooks.sh` 四类树 × 7 落点 + 门禁 | B5（5 例） |

### 1.3 需要方向决策的偏差

| # | 偏差 | 决策 | 状态 |
| --- | --- | --- | --- |
| 1 | `package-flow-kit.sh` 属禁动清单，本次改了 heredoc 文档串 | 事中登记（§0.5.1 + M10 + 回滚方案） | 已接受 |
| 2 | 修复期扩大了边界：`pre-tool-use/**` 三文件（M36/M37） | 补登 §0.5.1；理由 = L3 critical 要求"贴入路径可执行拦截" | 已接受 |
| 3 | 项目级 cap 20000 → 200000 | 依据：`DESIGN.md` 30535B 被截 45% 且结论翻转 | 已接受 |

---

## 第二轮 · 代码质量审查（6 维衰退风险）

### 🔴 R1 · 偶然复杂：转义 ↔ 还原的**方向耦合**（唯一未完全闭合项）
- **位置**：`l3-section.sh::_l3_escape_payload` ↔ `l2-detect.sh::_l2_unescape_payload`
- **症状**：写侧为保护结构性解析器转义行首；读侧的**内容级**路径（`## Verdict` 标题形）需要还原。
- **后果**：还原按格式识别，无法区分"写侧转义"与"载荷原文自带 `\## `"（M38）——后者会被错误还原。
- **Remedy**：哨兵化转义（写侧 `\##` → `\\##` 或不可打印前缀），读侧按哨兵还原。
- **现状**：语料 0 例命中；已登记 M38 + DESIGN §D13，**不阻塞**（严重度 🟡 上限：影响面是"载荷恰好
  含行首 `\## `"的假还原，不会造成段边界伪造）。

### 🟡 R2 · 知识重复：段边界判定的三处形态
- `_l3_section_spans`（唯一来源）、`_fk_l2_scope` 的内联降级（lib 缺失时才可达）、`_l3_spans_impl`
  的历史件分支（`stop==0`）。两侧判据已同源（`## L2 `/`## 主 agent`/`## L3 ` 或 EOF）。
- **Remedy**：降级分支已在 DESIGN D7/M8 声明为"唯一获准例外"，并由 B2-R3/R12/R17 锁定行为。

### 🟡 R3 · 变更传播：`l3-api.sh` 逼近 250 行结构门槛
- 新增 fail-closed 后曾达 257 行 → 压回 **250/250**（`AC-B1-metric` 绿）。
- **Remedy**：下一次再往该文件加逻辑必须先拆分（`_l3_parse_result` 的写入段可外移）。

### 🟢 R4 · 认知过载：`l3-section.sh` 三类职责（标记/转义/区间）
- 244 行、注释占比高；拆分会把"单一事实源"变成三个 import 点，净复杂度更高 → **接受**。

### 🟢 R5 · 依赖混乱
- 无新增第三方依赖（`awk`/`sed`/`grep`/`jq`/`sha256sum` 均为既有工具链），DESIGN §9.4 声明。

### 🟡 R6 · 领域扭曲（流程层）：本 change 自己的开发流程复发了 §B5
- 18:36–18:52 改了 4 个 hook 源却漏跑 `./sync-hooks.sh` → 6 棵副本跑旧代码（L2 八审 critical①）。
- **Remedy**：把"改源 → `sync-hooks.sh && make test-sync`"写进 `TEST.md` 的回归保护段与 DEV-SUMMARY
  的 verify 段；`make check` 已含 `check-hooks-sync`（漏跑会在门禁暴露）。

---

## 第三轮 · UI 视觉审查

**N/A** —— 本 change 无 UI 产物（纯 CLI/hook 工具链）。

---

## 第四轮 · 补充审查

### 4.1 跨模型分歧（ADR-014 Critical-Triggered Spot-Check）

| 议题 | L2 盲审（子 agent） | L3（deepseek-v4-flash-0731） | 处置 |
| --- | --- | --- | --- |
| 贴入路径是否算"已收口" | 判 critical（仅提示词约束 = 把安全交给自觉） | 判 critical（同） | **采纳**：升级为 PreToolUse 可执行拦截（M36/M37） |
| 转义是否覆盖全部写入方 | 指出"两个写入方"表述遗漏贴入路径 | 指出 `_l3_parse_result` 无 fail-closed | **采纳**：D11 穷举 5 行 + 双写入方守卫 |
| 无标记历史件终点 | 实测泄漏（伪 `## ` 切段） | 判 major（与 AC-1 冲突） | **采纳**：终点收紧 + B2-R17/R18/R19 |
| `---` + 伪标题残余 | 断言"已知残余"不假装闭合 | 三轮均判 critical 直到拦截落地 | **采纳**：三层防御（转义 / PreToolUse / 写后自检） |
| 提示词补充产物清单 | — | 判 major（AC-2 交付物"未交付"） | **采纳**：M34 全量 `*.md`（该指控源于我方输入缺口） |

**分歧结论**：两轨模型在本 change 的**关键判断上一致**（贴入路径必须强制、残余必须显式登记），
无"一轨通过一轨否决"的冲突项；差异主要在**措辞与证据粒度**（L3 常给错行号并要求更严格的形式化）。

### 4.2 复验工具的可信度（自查发现的两次"假绿"）

| # | 问题 | 处置 |
| --- | --- | --- |
| 1 | `verify-claims.sh` check 5 曾是恒真断言（BRE 把 `(盲审\|重审)` 当字面量） | 注入真裸正则验证（检出 1 处）；排除注释行 |
| 2 | `B7-R4` 曾假绿（bash 报错文本携带载荷 → 断言在 stderr 命中） | 内层丢弃 stderr + 新增 `B7-R5` 静态钉住 |
| 3 | `sync-hooks.sh` 参数解析只看 `$1`，`--check --strict-orphans` 第二参数被静默忽略 | 改逐参数解析（B5-R5 抓到） |
| 4 | **`TASK.md` 全表 verify 的"计划行下限"恒失败**（`awk '/^1\.\./{exit ($2>=N)?0:1}'`：TAP 计划行是单 token `1..27`，`$2` 为空串 → 断言恒假 → 每个 verify 永远 exit 1，**从未真正跑通过**） | 全表改 `awk -F'[.][.]' '/^1\.\./{exit ($2+0>=N)?0:1}'`；并把 14 个 `<verify>` 块**逐条实跑**取证（12 PASS 首轮暴露 2 处断言写错 → 修后 14/14 PASS）。与第 2 项同源教训：**断言必须能被观察到失败**，否则"已验"是空话 |

### 4.3 安全审查

见 `TEST.md` §3（载荷伪造边界 = A03/A08；秘钥扫描无命中；shellcheck 0 error）。

---

## 第五轮 · 阶段 6 的 L3（2026-09-19 04:46）结论处置

| # | 发现（严重度） | 处置 | 证据（可复跑） |
| --- | --- | --- | --- |
| 1 | 自检判据④「签名 ↔ 转义行」未**绑定**，且一律 advisory（🔴 critical①） | 判据④ 升级为**两级精确判据**：文件**有**签名且仍有转义行首落在签名区间之外 → **fail-closed**（自检失败 → 拒发凭证 + 落 correction）；文件**完全没有**签名 → 保留 advisory（常规 `\## L2 盲审（N审）` 引用风格，读侧全程不解码，无害） | `B10-R11`（绑定 → rc=1 + stderr 含「签名与转义行未绑定」）、`B10-R9`（无签名 → advisory）；**语料探针**：`find .specs -name '*.md'` 979 份，fail-closed 形态命中 **0** 份 → 不误伤 |
| 2 | `_gate_l3_decode_payload` 在解码器不可用时 `cat` 透传并返回 0（🔴 critical②，fail-open） | 改为 **fail-closed**：两条候选路径都拿不到解码器 → stderr 明确报错 + `return 3`；调用方 `_gate_path_guard` 视为「无法验证解码后形态」→ **rc=2 拒绝** + 专门提示（`./sync-hooks.sh` / `/flow doctor`）；顺带修 minor：`${HOOK_BASE_DIR:-}` 空值展开成 `/lib/...`、source 失败后不再 `break` 而是继续试下一路径 | `B9-R17`（无解码器 → `decode_rc=3` 且 `guard_rc=2`） |
| 3 | `29-independent-review.sh` 的 `A \|\| B && C` 结合为 `(A\|\|B) && C` → 撤销**成功**也写「撤销失败」correction（🟡 major） | 改显式 `if ! l3_invalidate_done ...; then ...; fi` | `B10-R10`（语义对照 `old=[C]` / `new=[]` + 接线钉住旧写法不残留） |
| 4 | UAT-2 ④ 的预期行不可执行（L3 侧读成 `预期：s`）（🟡 major） | 预期文本改 ASCII 关键字表述：`rc=2 且 stderr 含 "L3 载荷守卫"`；⑤ 去重复行并写明「无签名才是安全引用」。**并登记为流水线观察**：该行原文含 ⛔/… 等非 ASCII 装饰符，疑似提示词侧被截断成 `预期：s` | UAT.md §UAT-2（本轮改） |
| 5 | 套件 `run` 默认合并 stderr → 内容断言可被 stderr 报错文本满足（假绿）（🔴 阶段 5 的 L3 04:42 critical + 🟡 本轮 major） | **全量审计并统一**：87 处 `run` → `run --separate-stderr`（并声明 `bats_require_minimum_version 1.5.0`）；断言约定写入文件头：内容断言只看 `$output`，stderr 断言显式用 `$stderr`。**修正 4 处原本靠 stderr 泄漏"通过"的断言** | 改后首轮实跑即暴露 `B10-R2`/`B10-R3`/`B10-R9`/`B3-R7`/`B6-R1` 五处（`[[ "$output" == *"段尾"* ]]` 之类）→ 全部改 `$stderr`；现套件 **112 ok / 0 not ok** |
| 6 | **提示词容量边界**：阶段 6 的 L3 04:5x 直接 `verdict=error` —— `jq: 参数列表过长`（🔴 流水线缺陷，非工件缺陷） | 根因：Linux 单个 argv 上限 `MAX_ARG_STRLEN = 128 KiB`，而 cap 已提到 200000B，提示词却仍作为 argv 传给 `jq`/`curl`。修法：工件落临时文件 + jq `--rawfile`（传文件名）；请求体与 L2 载荷改走 stdin（`--data-binary @-`）；**顺带**给补充产物的 3000B 截断加**留痕**（上一行 4 的根因：截断不留痕 → 审查员读成"工件命令不完整"） | `B11-R1`（受控 git 仓库造 >131072B diff → 提示词仍构造成功）、`B11-R2`（静态钉住三处接线不被回退）、`B11-R3`（超预算留痕，且小件不误报）；实测阶段 1/2/3/5/7 提示词 43/84/59/30/41 KB，阶段 6 = 200000B（cap） |
| 8 | 判据④ 的 awk 失败处理只判 `rc>=2`（🔴 06:1x critical） | awk 的退出码语义与 grep **不同**（rc=1 没有"无匹配"含义）→ 任何非零都 fail-closed；顺带按 minor 拆开 `_rc_esc`/`_rc_sig` 两个 rc 变量 | `B11-R6`（静态钉住 `-ne 0` + 独立 rc）；`l3-section.sh` 源码 |
| 9 | 撤销失败且 correction 写入器不可用时**静默**（🟡 major） | `29-independent-review.sh` 增 else 分支：CRITICAL + `/flow doctor` 指引 | `B11-R6` 静态钉住 |
| 10 | 截断留痕写死 `.specs/<change-id>/`（🟡 major）+ 整行截断在无尾随换行时失效（🟢 minor） | 留痕改用**真实** `${artifacts_dir}/${_b}`；整行截断改 `sed '$d'`（无条件丢掉可能不完整的末行） | `B11-R3`/`B11-R4`/`B11-R6` |
| 11 | `mktemp` 失败未检查（🟡 major，3 处） | l3-api.sh / l3-prompt.sh / l2-detect.sh 均加显式失败分支（清理 + 非 0 + stderr） | `B11-R6` 静态钉住；`l3-api.sh` 仍 **250/250** |
| 12 | 计数口径（TEST.md 115/941 vs CHANGELOG 118/944 等）（🟡 major） | 全库统一到**同一快照时点**的现场实测值（当前口径：缺陷套件 **119**、全量 **945**，快照 2026-09-19 06:4x）；§3.4 的 `/tmp` 夹具补齐前置命令；M41/M42 引用直接给出定义位置 | 见 §总结 门禁行 |

**本轮附带发现的套件级陷阱（写入用例约定）**：bats 会对**测试名**做 `eval`（`bats-core/test_functions.bash::bats_test_function` 的 `eval printf -v test_description`）——
用例标题里出现反引号会被当成命令替换执行：本 change 曾因标题含 `` `A||B&&C` `` 导致**整个套件每次加载**都打印 `A: 未找到命令`/`B: 未找到命令`（与被筛选的用例无关，极易误判为环境问题）。
约定：**测试名内禁止反引号与 `$`**（新用例 `B10-R10` 已按此改写并记录原因）。

## 总结

| 维度 | 结论 |
| --- | --- |
| **Spec 合规** | ✅ AC-1–AC-12 全部实现且有回归（缺陷套件 **119 ok / 0 not ok**（快照 2026-09-19 06:4x）；全量套件同轮现算，见下方门禁行）。**AC-1..AC-12 → 任务 → 复验命令 → 用例 ID 的零空白矩阵**已写入 `TASK.md`（含可跑的空白自检，实测零输出）。 |
| **代码质量** | 🟡 1 项 Important 未闭合（R1 转义/还原方向耦合 → M38）；3 项 🟢/🟡 已收敛或声明例外 |
| **Critical（历史项）** | 已落地为代码 + 回归：M32/M34/M36/M37、D13、写入侧 fail-closed、AC-2 活语料判据 |
| **Minor** | 47 项登记 `MINOR-DEFERRED.md`（M1–M47），按 ADR-017 不进 fix loop |
| **门禁（2026-09-19 06:2x 实测）** | TASK.md 的 14 个 `<verify>` 块**逐条实跑 14/14 PASS**（含 `make check` 五门、`npx bats`、`verify-claims.sh` 13/13、`./sync-hooks.sh --check` 漂移 0、`corpus-count.sh` → `234 108 139 139 8 0`）；缺陷套件 119 ok / 0 not ok；全量套件 945 ok / 0 not ok（快照 2026-09-19 06:4x） |
| **遗留** | M38（哨兵化转义）、M44（连续反斜杠编码语义 —— 待实测后定"已定义"或"未闭合"）、M46（守卫"验证转义来源"= 评审翻转）、M47②（签名一致性判据为 advisory）、M7/M8（历史兼容路径） |
| **Toll-gate 6→7**（判定方法 · **不复制易失状态**） | 判定依据：① 六个受门禁阶段的锚点 `.specs/<id>/.independent-review-{1,2,3,5,6,7}`（此处省略后缀）由 `l3_review_run` 写出、`written_by=pre-tool-use-gate`，且 L2 + L3 双 pass；② PreToolUse 门禁 `independent-review-gate.sh` 在缺失锚点时**拒绝** commit/切阶段（实测 rc=2，见 `B9-*`/门禁自测）；③ **现状请看当时的锚点**（`ls .specs/<id>/` 或 `/flow goal`）—— 本节**不再枚举"哪几个 fail"**：06:2x 的 L3 已两次因"状态行过期/自相矛盾"判缺陷（本文件第 8–12 行是当时的处置记录）。 |

### 诚实性声明（本报告的自查 · 2026-09-19 04:0x 更新）

- 本节的"Critical（历史项）"**仅指历史 critical 已落地为代码 + 回归**，不代表当前各阶段门禁已通过。
  当前锚点 **3/6**：阶段 **1/5/7** = pass；阶段 **2/3/6 = fail**（结论时点 2026-09-19 03:46 /
  2026-09-18 22:18 / 2026-09-18 22:47）。阶段 2 的「转义/还原歧义」仍为 **M38**（Tech-debt）。
- **22:3x 版本的 toll-gate 行曾写"2/3/6 的 critical 均已逐条处置"——该表述已作废**：它把"已派人修"
  当成了"已闭合"，且阶段 6 那条的根因（文件级签名门控）当时仍有残余。已按 ADR-017 改为逐条列
  「已闭合 / 残余 / 归属」。
- **数字口径**：本文件出现的 `ok/not ok` 都是**带时点的快照**；被断言的不变量只有两条 ——
  `not_ok=0` 与"缺陷套件 ≥119 例"。现场复算：`npx bats test/`、`npx bats test/test_l3_review_defects_2026_09.bats`、
  `bash corpus-count.sh`、`bash verify-claims.sh`。
- 阶段 6 的 L2 盲审结论（`L2-ROUND-P6.json`）指出的数字与路径问题已修正；
  **L3 结论未产出前，本报告不宣称通过**。
- **阶段 3 的自查新发现（04:0x，此前无任何评审发现）**：TASK.md 里所有 verify 的"TAP 计划行下限"
  取值写法有误 —— 计划行是**单 token**（`1..27`），`$2` 为空串，比较恒假 → **该 verify 永远 exit 1**，
  即表里的复验命令**从未真正跑通过**。已全表改为 `awk -F'[.][.]' '/^1\.\./{exit ($2+0>=N)?0:1}'`
  并逐条实跑取证（见 TASK.md「补档追加说明」）。与 `B7-R4` 的"假绿"同源：
  **断言必须能被观察到失败**，否则"已验"是空话。
