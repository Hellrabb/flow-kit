# REVIEW — user-guide-sync-2026-09b

- **Change ID**: user-guide-sync-2026-09b
- **形态**: 阶段 6 **单轮合并审查**（spec 合规 A + 6 维衰退风险 B + 界面/演示维度 C 在同一次 pass 内判定；🔴 Critical 才追加跨模型 spot-check —— ADR-014）
- **审查对象**: 本次 change 的**终态 diff**（工作区 vs `HEAD`）+ `.specs/user-guide-sync-2026-09b/` 全部产物
- **角色红线（R3.3）**: 本阶段只产报告与修复任务，不当场改代码/文档

---

## 1. A 维度 · Spec 合规（AC-1 – AC-11 逐条）

| AC | 判据 | 证据（实跑） | 结论 |
|---|---|---|---|
| AC-1 版本与日期口径（4 条 + 2 条段外 regex） | 版本行 = 分节日期 = 2026-09-21；`20260713`/`2026-07-13` 四份 0；`2026-09-03` 仅历史句 | `verify-ac.sh`：AC-1 段 5 条断言全过（含 2 条 regex 口径） | ✅ |
| AC-2 14 条 🔴 | 14 组反例（四份 0）+ 正例（四份 ≥1） | `verify-ac.sh` AC-2 段 **39 条**断言全过（分段计数） | ✅ |
| AC-3 过期项（29 条） | 有旧措辞者逐条反例 + 正例 | `verify-ac.sh` AC-3 段 **37 条**断言全过（分段计数） | ✅ |
| AC-4 N1–N11 + N12 | **23 条**用户可见锚点 + 1 条段外安全反例（无真实 token 形态） | `verify-ac.sh` AC-4 段全过 | ✅ |
| AC-5 四副本一致 | md5 唯一值 = 1；`--check` rc=0；`make dsh-sync` 后与已装插件差异 0 | TEST.md §4.1 | ✅ |
| AC-6 deck 重建 + 扩页 + 断言有效性 | 24 页；`deck_checks OK`；两组「注入→红→还原→绿」 | TEST.md §3.1/§3.2 | ✅ |
| AC-7 渲染验证 | 24 PNG；抽检封面 + 21–24 + 改动页无溢出/缺字 | TEST.md §3.3（含 M7 字体替代口径） | ✅（带口径留痕） |
| AC-8 README 口径 | 6 行固定核对表（3 改 3 不改，均带证据行号） | TEST.md §5.2 | ✅ |
| AC-9 改动边界与回归 | `verify-boundary.sh` rc=0（含未跟踪文件）；禁动域 diff = 0；`make check` 六门全绿 | TEST.md §5.3 | ✅ |
| AC-10 副本守护 | 8 用例全绿；非恒绿两例（夹具）；用例 4 曾在真实缺口上变红后复绿；计时 **0.002 s**（`TIMEFORMAT='%3R'`） | TEST.md §4.3/§6 | ✅ |
| AC-11 独立审查与归档（阶段 5：L2 pass + L3 四轮 findings 处置后按熔断 bypass 结案，审计段见 IR-5 的 `## L3 重审（bypass）`；阶段 1/2：L2+L3 双 pass） | 各阶段 `INDEPENDENT-REVIEW-<N>.md` 的 L2/L3 段 + `.done`；归档与 CHANGELOG/STATE/LESSONS | 见本阶段与阶段 7（本轮以 **L2 多轮 fix loop + L3 外部模型** 闭环） | ⏳ 阶段 7 收口 |

**Spec 合规结论**：AC-1 – AC-10 全部满足；AC-11 在阶段 7 完成归档动作后闭合。

---

## 2. B 维度 · 6 维衰退风险（书本驱动）

| 维 | 风险 | 观察 | 判定 |
|---|---|---|---|
| **R1 认知过载** | 指南 1693 行 / 12 章，本轮 +183/−122 行；L3 审查链与门禁两段信息密度最高 | 目录与 `<a id=…>` 锚点齐备；新增「L3 凭证（必配）」「仓库质量门禁」两节自成段落，未把长表塞进既有段 | 🟢 可接受（无新增结构债） |
| **R2 变更传播** | 同一事实在 **4 份指南副本 + 2 处 dist 镜像 + deck + README** 中重复 | 本轮新增 `test/test_guide_copy_parity.bats`（四副本 + deck 新鲜度）覆盖了「改一处忘一处」的主路径；README 与指南的重复仍靠人工 | 🟡 已收敛（见 §4 F1） |
| **R3 知识重复** | 「80000 字节」「用户级配置」「单轮合并审查」在指南 / README / deck 三处各有一份表述 | 本轮以「AC 表为母本 + 附录 A 超集集合断言 + deck_checks KEY_STRINGS」把**可机械核对的部分**固定；不可机械核对的部分（措辞粒度）登记为 v2 | 🟡 部分缓解 |
| **R4 偶然复杂** | `.specs/user-guide-deck-gen/` 是自建生成器（theme/layouts/build/checks 四件） | 本轮只扩 `slides.json` 与 `deck_checks.py`，未改 `theme.py`/`layouts.py`；把位置索引断言换成 `by_title` 寻址**降低了**插页耦合 | 🟢 改善 |
| **R5 依赖混乱** | 新增依赖 | 无（沿用 python-pptx / LibreOffice / pdftoppm / bats-core） | 🟢 无 |
| **R6 领域扭曲** | 指南术语须与实现一致 | 43 条漂移逐条修正后，权威实现（`prompts/6-review.md` 的「单轮合并审查」、`stop-hook.json` 的 12 键、`l3-review.sh` 的 80000）与文档一致；范围外残留 3 处已登记 M8 | 🟢（范围外残留已留痕） |

---

## 3. C 维度 · 演示/界面

- **deck 视觉一致性**：4 张新专页沿用既有 `band` 版式与 `theme.py` 配色，未引入新版式；`deck_checks.py` 的 `by_title` 断言保证「页缺失/改名」必红。
- **渲染**：LibreOffice 24.2.7.2 → PDF → PNG ×24；抽检无溢出/缺字；`✅/❌` 字形正常。
- **口径留痕（M7）**：本机 `fc-list` 无 `Times New Roman` / `宋体`，实际由 Noto CJK 兜底 → 本次排版结论是**替代字体度量**，不等同目标环境观感（已登记，不阻塞）。

---

## 4. 发现清单（严重度分级 · ADR-017）

| # | Sev | 发现 | Source | Consequence | Remedy | 处置 |
|---|---|---|---|---|---|---|
| F1 | 🟡 Important | 指南 ↔ deck ↔ README 三处的**同一事实**（80000 字节 / 用户级配置 / 六门）无机械一致性守护：四副本有守护，deck 只守「页数 + 封面日期 + 关键串存在」，不守「与指南同值」 | AC-10 的守护域边界（DESIGN D2 只覆盖 md 副本与 deck 新鲜度） | 下次改指南的数值（如默认上限）时，deck 可能仍印旧值而无人发现 | ① 短期：`deck_checks.py` 的 `KEY_STRINGS` 已含 `80000`/`check-dist` 等，可再加「数值取自指南」的提取比对；② 登记 v2（与 M2「deck_checks 进 make check」同批） | Tech-debt: MINOR-DEFERRED（并入 M2 范围） |
| F2 | 🟡 Important | 范围外残留：`三轮审查` 仍存于 `skills/flow-review/SKILL.md`、`flow-kit/README.md`、`templates/REVIEW.md:73`，与指南新口径不一致 | 阶段 1/3 L2 的 L-031 扫描（两次独立命中） | 用户加载的 flow-review 技能标题与指南矛盾 | 另开 change `phase6-review-wording-2026-09`（AC-9 冻结域，本轮不越界） | Tech-debt: M8（已登记，含跟进 change-id） |
| F3 | 🟢 Minor | `.specs/user-guide-deck-gen/README.md` 的 layout 表未随本轮更新（本轮未新增版式，故无内容可改） | 阶段 2 L2 R7 要求列入会修改清单 | 读者可能以为有新版式 | 已在 README 注明「4 页全用 band，无需新版式」 | Fixed in: T05（README 同步） |
| F4 | 🟢 Minor | DESIGN §7 证据链两处引用不实（`Makefile:6` 空行等） | 阶段 2 L2 第三轮 R21 | 轻微误导后续读者 | 阶段 7 归档前顺手清理 | Tech-debt: M10 |

**无 🔴 Critical** → 不触发跨模型 spot-check（ADR-014 口径）。

---

## 5. 修复任务（T-FIX）

- **T-FIX-01（v2 候选 · 不阻塞归档）**：把「deck 关键数值与指南同源」做成断言（F1）——与 M2（`deck_checks.py` 进 `make check`）同批实施。
- 本轮**无必须修复项**：F1/F2 均已登记且不阻塞；F3 已修；F4 归档前清理。

---

## 5.1 审查链现状（阶段 6 终审 · 2026-09-21 23:3x）

| 阶段 | L2 | L3 | 锚点 |
|---|---|---|---|
| 1 需求 | 第五轮 **pass** | **pass** | `.independent-review-1` 锚点已写 |
| 2 设计 | 第四轮 **pass** | **pass** | `.independent-review-2` 锚点已写 |
| 3 任务 | 第七轮（进行中） | 5 轮 findings 处置后**熔断 bypass**（审计段） | `.independent-review-3` 锚点已写 |
| 5 测试 | 第五轮 **pass** | 4 轮 findings 处置后**熔断 bypass**（审计段） | `.independent-review-5` 锚点已写 |
| 6 审查 | 本阶段 | 见下 | — |

> 两处 bypass 均为**框架熔断的透明降挡**（`L3_verdict=skipped` + 审计段，不伪装 pass），根因与重试方式见 `TEST.md` §10.3 与 MINOR-DEFERRED M23–M26。

## 6. 结论

- **spec 合规**：AC-1 – AC-10 全绿（`verify-ac.sh` **128 通过 / 0 失败**，分段 AC-1 4 · AC-2 39 · AC-3 59 · AC-4 23 + 段外 3；含 `make check` 六门全绿、边界核对通过）；AC-11 待阶段 7 归档动作闭合。
- **衰退风险**：2 🟡（均为**记录型**，不影响本轮交付）+ 2 🟢；无 🔴。
- **Verdict**：**pass**（无 🔴 Critical）→ 可进入阶段 7 INTEGRATION。
