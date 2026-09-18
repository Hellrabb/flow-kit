# REVIEW: L3 审查链五类缺陷修复（双轮审查 · spec 合规 + 代码质量）

- **Change ID**: `l3-review-defects-2026-09`
- **关联**: `@.specs/l3-review-defects-2026-09/REQUIREMENT.md`、`DESIGN.md`、`TASK.md`、`DEV-SUMMARY.md`、`TEST.md`
- **独立审查记录**: `INDEPENDENT-REVIEW-1.md`（阶段 1/3）、`INDEPENDENT-REVIEW-2.md`（阶段 2）、
  `INDEPENDENT-REVIEW-3.md`（阶段 3）、`INDEPENDENT-REVIEW-5.md`（阶段 5）、`INDEPENDENT-REVIEW-6.md`（本阶段）、
  `INDEPENDENT-REVIEW-7.md`（阶段 7）——每份由 L2 盲审（全新上下文子 agent）+ L3（真实外部 API）双轨产出。
- **severity gating（ADR-017）**：🔴 Critical 阻塞 toll-gate；🟡 Important 进入 fix loop；
  🟢 Minor 只登记 `MINOR-DEFERRED.md`（**M1–M42**）不进 fix loop。

---

## 第一轮 · Spec 合规审查

### 1.1 AC 覆盖（逐条）

| AC | 实现锚点 | 验证 | 结论 |
| --- | --- | --- | --- |
| AC-1 L2 层限定 + 免疫 L3 段/大小写 | `l2-detect.sh::_fk_l2_scope`（62-64 调 `_l3_section_spans`）+ 三层提取 | B1-R2[1-4]、B2-R9/R11/R13/R17/R18/R19 | ✅ 合规 |
| AC-2 语料零非枚举 / 空值 ≤8 且可归因 | 同上 + `L2-EMPTY-ATTRIBUTION.md` | 「AC2: 语料全量复算」→ `224 98 129 129 8 0` | ✅ 合规（8/8 归因） |
| AC-3 §B1 五行回归 | 同上 | B1-R1 | ✅ 合规 |
| AC-4 重写幂等（标记/围栏/空行） | `l3-section.sh` + `l3-api.sh::_l3_parse_result` | B2-R2/R6/R7/R10 | ✅ 合规 |
| AC-5 无标记历史件清除 | `_l3_spans_impl` 的 `stop==0` 分支 | B1-R21、B2-R3/R4/R12 | ✅ 合规 |
| AC-6 上限=字节 | `29-independent-review.sh` 解析链 | B3-R4/R5/R5b | ✅ 合规 |
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
| §B3 `max_artifact_chars` 名"字符"实"字节" | CJK 件被截 2/3 | 改名 + 保留旧键 + 5 处载体写明 | B3（8 例） |
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

### 4.3 安全审查

见 `TEST.md` §3（载荷伪造边界 = A03/A08；秘钥扫描无命中；shellcheck 0 error）。

---

## 总结

| 维度 | 结论 |
| --- | --- |
| **Spec 合规** | ✅ AC-1–AC-12 全部实现且有回归（缺陷套件 **98 ok / 0 not ok**；全量 **924 ok / 0 not ok**，均为 2026-09-18 现算，数字随用例增长漂移，只断言 `not_ok=0`） |
| **代码质量** | 🟡 1 项 Important 未闭合（R1 转义/还原方向耦合 → M38）；3 项 🟢/🟡 已收敛或声明例外 |
| **Critical（历史项）** | 已落地为代码 + 回归：M32/M34/M36/M37、D13、写入侧 fail-closed、AC-2 活语料判据 |
| **Minor** | 42 项登记 `MINOR-DEFERRED.md`（M1–M42），按 ADR-017 不进 fix loop |
| **门禁（2026-09-18 21:0x 实测）** | `make check` 五门全绿；`npx bats test/` **926 ok / 0 not ok**；`./sync-hooks.sh --check` 漂移 0；`bash verify-claims.sh` 13/13 |
| **遗留** | M38（哨兵化转义）、M7/M8（历史兼容路径）、M17（外部写盘通道的兜底依赖 Stop 侧自检） |
| **Toll-gate 6→7**（21:0x 复核） | ⛔ **暂不放行（pending）** —— 阶段 5 / 7 的 L3 = pass（阶段 5 已写 `.done`）；阶段 2 = fail（1C：伪标记可绕过 → **已收紧守卫**，待重审）、阶段 3 = fail（4C：TASK 依赖语义 → 已补说明，待重审）、阶段 6 = fail（1C：解码对历史文本非单射 → 登记 M43，待响应） —— 依 ADR-017，须先满足：① 阶段 2 的最新 L3 为 `fail`（2 critical：文档口径自相矛盾【已按 49be722 统一】、转义/还原歧义 M38），处置与重审未完成；② 阶段 3/5/6/7 的 L2 均为 `fail`（已逐条响应，见各 `INDEPENDENT-REVIEW-N.md`），其 L3 轮次**尚未运行**。 |

### 诚实性声明（本报告的自查）

- 本节的"Critical 0"**仅指历史 critical 已落地**，不代表当前各阶段门禁已通过；阶段 2 的三轮 L3 结论
  分别是 19:04 / 19:15 / 19:26 / 19:43 的 `fail`，最后一次的 2 条 critical 中「文档口径矛盾」已由
  commit `49be722` + 本次 DESIGN 统一（§D11 最终形态）闭合，「转义/还原歧义」仍为 **M38**（Tech-debt）。
- 阶段 6/7 的 L2 盲审结论（`L2-ROUND-P6/P7.json`）指出的数字与路径问题已在本轮修正；
  其 L3 轮次与结论未产出前，本报告不宣称通过。
