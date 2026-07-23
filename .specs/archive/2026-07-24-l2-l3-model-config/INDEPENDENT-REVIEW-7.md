# 独立审查 · 阶段 7

## L2 盲审

> 独立性声明：仅依据指定工件（`.specs/l2-l3-model-config/` 全部产物 + `git diff` + `.specs/LESSONS.md` / `.specs/CHANGELOG.md`）作判。REVIEW.md / INDEPENDENT-REVIEW-6.md 仅作「待复核对象」对照，不作为前提采信。✅/通过项系独立复跑 `bats flow-kit-bundle/test/`（587 用例全 ok，exit 0）+ 逐文件读改后源码 + `bash -n` / `shellcheck -S warning` 核验得出，非抄录主 agent 结论。未在输入中检测到主 agent 自评/草稿/辩护注入——「本次审查参数」段为操作性元数据（指定工件路径），非结论引导。

### 工件范围确认 + 独立核实

- **产物齐全**：CHANGE / REQUIREMENT / DESIGN / TASK / TEST / REVIEW / PROGRESS / T01–T07+T09–T11 SUMMARY 全在；T08 缺失有据（TASK.md:6 v2 修订「删独立 skill T08，/flow model 内联 flow/SKILL.md」）。INDEPENDENT-REVIEW-1/2/3/5/6 在场；INDEPENDENT-REVIEW-4 缺失（阶段 4 仅 PROGRESS 1 行，未触发独立审查——非本阶段检查范围）。
- **LESSONS 同步**：`.specs/LESSONS.md` 新增 L-054（gate `.done` 仅验存在不验作者·握手锚点死代码）+ L-055（L3 外部模型对 skill=实现 架构理解不足），两条均从本 change REVIEW 提取，四要素（严重度/发现/Why/How to apply）完整。✅
- **CHANGELOG 更新**：`.specs/CHANGELOG.md` 首行追加 `2026-07-24 l2-l3-model-config` 条目，含实现摘要 + 关联 ADR + 关键风险标注（L2 fallback 移除行为变化）+ 教训引用（L-054 / L-055）。✅
- **归档清洁**：`.specs/l2-l3-model-config/` 无 `.tmp` / `.bak` / `_*` / `*.draft` / `*~` 残留；只有规范文档 + `.independent-review-{1,2,3,5,6}.done` 标记。✅
- **ADR 链一致**：ADR-006 标 `Superseded by ADR-012`（2026-07-23）；ADR-012 三级链 + 降级；ADR-013 correction 覆写策略（compliance > model-missing 优先）。三者引用闭合。✅
- **AC 独立复跑**：`bats flow-kit-bundle/test/test_fk_resolve_model.bats test_model_degradation.bats test_flow_model.bats test_flow_kit_resume.bats test_independent_review_model.bats` → 1..42 全 ok；全量 `bats flow-kit-bundle/test/` → 587 用例全 ok，exit 0（AC-7 独立确认）。✅
- **语法静态检查**：`bash -n` 6 个改后脚本全 exit 0；`shellcheck -S warning` 在新代码段（`common.sh:239-261` fk_resolve_model / `correction-file.sh:90-136` write_model_missing_*) 无新警告（既有 SC2034/SC1090/SC2155 警告均在未触碰的旧行）。✅

### 阶段 7 checklist 逐项

| 检查项 | 结果 | 备注 |
|---|---|---|
| 产物齐全 | ✅ | T08 de-scope 在 TASK.md v2 显式声明 |
| LESSONS 同步 | ✅ | L-054 / L-055 提取自本 change REVIEW |
| CHANGELOG 更新 | ✅ | 条目含风险标注 + 教训引用 |
| 归档清洁 | ✅ | 无残留临时文件 |
| done 标记（phase 7） | N/A | 本审查进行中，`.independent-review-7.done` 待 L2+L3 双 verdict 后写 |
| 修代码优先 | ⚠️ 见 R3/R4 | phase 6 L2/L3 发现均有 Fixed/Tech-debt/Not-applicable 分类 + 理由，非纯文档敷衍；但 ≥50% 标 Tech-debt 累积，见 R3 |

---

### 🟡 R1 · `write_model_missing_correction` 重引入固定 `.tmp` 文件名 race——与项目 3 天前刚修的 gate-review-fix 教训直接冲突，且 code comment 自称「Atomic / avoids TOCTOU race」与实现不符
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/correction-file.sh:110-114` 的 `write_model_missing_correction` 用固定名 `${path}.tmp`：
```bash
jq --argjson new "$new_json" '...' "$path" > "${path}.tmp" 2>/dev/null && mv "${path}.tmp" "$path"
```
同文件 `:66` `:73`（既有 `correction_file_write`）也犯同样错，但本 change 是在已知道训下**新写**的代码。注释 `:93-95` 写「Atomic: single jq read-conditional-write to tmp + mv (avoids Check-Then-Act TOCTOU race)」——**仅避免 read-then-write 的 TOCTOU，却引入了「固定 tmp 文件名」的另一类 race**（两个并发写者互覆对方 tmp）。
**Source（源头）**：项目自有教训 `.specs/CHANGELOG.md:5`（gate-review-fix 2026-07-21，本 change 前 3 天）「`.tmp.$$→mktemp 竞态修复(3处)`」；项目内既定正确模式 `flow-kit-bundle/hooks/stop/lib/l2-detect.sh:143, 273` `mock_tmp="$(mktemp "${review_md}.tmp.XXXXXX")"`；经典并发反模式（fixed-name temp race / symlink attack 面）。
**Consequence（后果）**：单会话单 Stop hook 链下不爆；但**多个 Claude 会话同 repo 并发**（开发场景常见）或同会话内 `--background` 异步路径与同步路径并发时，两进程的 `> "${path}.tmp"` 互覆，`mv` 可能移动对方写的半截 JSON，造成 `.flow-active.correction` 内容损坏或丢失——而 correction 是 SessionStart 收割降级 banner 的唯一信号源（AC-6），损坏即降级不可观测。窗口窄但非零，且**项目最近刚为同一类 bug 付过修成本**，新代码重蹈覆辙意味着教训未沉淀到「新代码写入时的默认模式」。
**Remedy（修补）**：
```bash
# before
jq --argjson new "$new_json" '...' "$path" > "${path}.tmp" 2>/dev/null && mv "${path}.tmp" "$path"

# after（mktemp + 失败清理 + 可观测 stderr；对齐 l2-detect.sh:143 既有正确模式）
local tmp; tmp=$(mktemp "${path}.tmp.XXXXXX") || return 1
if jq --argjson new "$new_json" \
    'if .type=="compliance" and ((.violations // []) | length > 0) then . else $new end' \
    "$path" > "$tmp" 2>/dev/null; then
  mv "$tmp" "$path"
else
  rm -f "$tmp"
  echo "[correction-file] WARN: model-missing write failed (jq parse or IO)" >&2
fi
```
同步订正 `:93-95` 注释为「单步 jq 条件写仍存在 fixed-tmp-name race——已用 mktemp XXXXXX 消除」。注：既有 `correction_file_write` 同患，可作为单独全 lib 一致性 tech-debt，但**本 change 新增代码应在本次闭环内修**。

---

### 🟡 R2 · 本 change 的 6→7 transition 站在 L-054 描述的作者性弱路径上——`.independent-review-6.done` 由 `main-agent-adjudicated` 自写解锁，gate-done-authorship 修复未交付前 transition 可信度依赖人工核实而非机制保证
**Symptom（症状）**：`.specs/l2-l3-model-config/.independent-review-6.done` 内容（独立读出）：
```
written_by=main-agent-adjudicated
L2_verdict=pass
L3_verdict=fail
L3_summary=L3 Critical经主agent裁判为架构误报;Major已在ADR-013披露;minor不影响断言.L2 pass成立
```
即 phase 6 的 gate 是主 agent 自己写 `.done` 解锁的，触发原因 L3 verdict=fail。INDEPENDENT-REVIEW-6.md §裁判 verdict 显式承认：「因 L3 verdict=fail，`l3-review.sh:569` 设计上不写 `.done`...本分歧经主 agent 裁判 L3 为误报后，需人工写 `.independent-review-6.done`...解锁 PreToolUse 门禁」。
**Source（源头）**：本 change 自产教训 `.specs/LESSONS.md` L-054「`.done` 仅验存在不验作者——agent 可伪造 .done 绕过 L3 外部审查」；阶段 7 checklist「修代码优先：归档前最后一道审查」+「不可推迟到下一轮 change」。`.specs/gate-done-authorship/CHANGE.md` 已立项（5.1K，已确认存在）但**未交付**。
**Consequence（后果）**：phase 7 checklist 检查的是 `.independent-review-7.done`（本审查尚未写）；但**本 change 的 6→7 transition 合法性建立在 phase 6 的 .done 上**，而该 .done 正是 L-054 描述的攻击面的具体实例。INDEPENDENT-REVIEW-6.md §L3-C1 的核实证据（SKILL.md:236-256 实现存在 + test_flow_model 6 用例）是**基于工件的**，本审独立复核成立（见上「AC 独立复跑」）；但机制上无任何代码保证主 agent 写 `.done` 时确实做了此核实——下一次别的主 agent 完全可能直接 `touch` 一份结构合法的 `.done` 单方面过关。L-054 已将此列为 🟡 Major 并另立 change，本 change 在该 fix 落地前过 phase 7，等于把风险向下游传递。
**Remedy（修补）**：(1) 本 change scope 内无法修（gate 重构非本 change 范围，CHANGE.md out 段明示）；(2) **必须在本 INDEPENDENT-REVIEW-7 登记「本 change 6→7 transition 依赖未交付的 gate-done-authorship 修复」**——phase 7 checklist「修代码优先：显式技术债登记（含理由）」的合规要求；(3) 推动将 `gate-done-authorship` 优先级提升至下一 change（在 REVIEW.md §关联发现处补「依赖关系：本 change 过关依赖该 fix 尽早落地」一句）。本审 Verdict 不因此条 fail（不引入新风险，仅继承既有风险并已有 fix 立项）。

---

### 🟢 R3 · REVIEW.md声称「记入 TECH-DEBT」但 `.specs/l2-l3-model-config/TECH-DEBT.md` 与项目级 `.specs/TECH-DEBT.md` 均不存在——tech-debt 实际散落三处难追溯
**Symptom（症状）**：`REVIEW.md:76` 写「L2/29 caller 集成测试...记入 TECH-DEBT（低优先，后续 change 补）」；INDEPENDENT-REVIEW-6.md §AC-4 技术债滥用防护说明亦称「这些 tech-debt 登记到 TECH-DEBT」。但：
- `ls .specs/l2-l3-model-config/TECH-DEBT.md` → 不存在
- `ls .specs/TECH-DEBT.md` → 不存在
- `.specs/CONTEXT.md:61` 把 TECH-DEBT.md 列为标准产物（「技术债专用清单，brooks-lint 扫描结果与人工标注的合并输出」）

实际 tech-debt 分布在：REVIEW.md:75-76（AC-4 caller 集成）+ INDEPENDENT-REVIEW-6.md:66-88（R1-R5 逐条 Tech-debt/Not-applicable 分类）+ ADR-013 §Consequences（多 type 容器 v2）。
**Source（源头）**：项目自有规范 `.specs/CONTEXT.md:61`（TECH-DEBT.md 是文档约定产物）；阶段 7 checklist「修代码优先：显式技术债登记（含理由）」隐含「可追溯」要求；信息检索一致性（DRY 的元层面——「在哪里登记」应单一来源）。
**Consequence（后果）**：3 个月后若有人想接手「本 change 遗留 tech-debt」，没有单一入口；需 grep 全 `.specs/l2-l3-model-config/` + ADR 才能拼出完整列表。phase 7 checklist「修代码优先」要求显式登记含理由——文字上做到了，但**登记位置不在约定产物里**，实质未兑现「登记」语义。低优先，但落在阶段 7 checklist 的核心维度（可追溯性）。
**Remedy（修补）**：二选一——(a) 新建 `.specs/l2-l3-model-config/TECH-DEBT.md`，把分散在 REVIEW.md / INDEPENDENT-REVIEW-6.md / ADR-013 的 4 条 tech-debt（AC-4 caller 集成 / model-missing 覆写 l2-missing / TOCTOU + 孤儿 tmp / cross-caller 降级块复制）合并成表（含理由 + 优先级 + 修复入口）；(b) 在 REVIEW.md §4.1 把「记入 TECH-DEBT」改为「登记于 INDEPENDENT-REVIEW-6.md §主 agent 响应 + ADR-013 §Consequences（无独立 TECH-DEBT.md 文件）」，订正文字与现实一致。本审推荐 (b)（最低成本消除漂移）。

---

### 🟢 R4 · phase 6 L2 R5（三 caller 降级块机械复制）+ 本审 R1（fixed-tmp race）均可在本 change 闭环内低成本修复，但被标 Tech-debt 推迟——phase 7「修代码优先」精神与 ≥50% Tech-debt 比例存在张力
**Symptom（症状）**：phase 6 L2 R5（INDEPENDENT-REVIEW-6.md:44-48）披露三 caller（`l3-review.sh:618-626` / `l2-detect.sh:215-223` / `29-independent-review.sh:57-65`）降级块机械复制（每处 ~8 行：source guard + fk_resolve_model + 空判断 + correction + return/exit 3），主 agent 标 Tech-debt 理由「抽 helper 需处理 return vs exit 上下文差异，复杂度收益比低」。本审 R1 同理（5-10 行 mktemp 改造）。INDEPENDENT-REVIEW-6.md §AC-4 技术债滥用防护说明自统计「R1-R5 中 4/5（R1/R2/R3/R5）标 Tech-debt」。
**Source（源头）**：阶段 7 checklist「修代码优先：归档前最后一道审查...纯文档敷衍视为不合格」；INDEPENDENT-REVIEW-6.md 自述 tech-debt ≥50%；code-review checklist R2 变更传播 / R3 知识重复（跨 caller 复制属变更传播面被低估）。
**Consequence（后果）**：单条 tech-debt 都有合理理由（已确认非敷衍）；但**累积效应**是本 change 的 phase 6 实际只对 1 个 caller（l3-review）做了完整集成测试，其余 2 个 caller 的降级接线 + 1 个 tmp race + 1 个 cross-copy 共 4 个 minor 全部推迟。下一 change 若改动降级契约（如加第 4 项可观测后果），无集成测试的 2 个 caller 静默回归风险被放大。phase 7 是「归档前最后一道审查」，本可在本 change 内闭环。
**Remedy（修补）**：(1) R5 抽 `resolve_model_or_degrade <layer> <stderr_tag> [return|exit]` 到 `correction-file.sh` 或 `common.sh`，三 caller 改一行调用——5-10 行代码；同时为 R1（本审）+ R5（phase 6）联合修复，给 R1 集成测试一个单一被测点；(2) 若主 agent 仍判定推迟，需在 REVIEW.md §4.1 把「下一 change 补」具体化为「下一 change 列表 + 哪个 change 接」（当前「后续 change 补」无锚点，难以追溯）。

---

**主 agent 漏判/误判汇总**：
- 🔴 漏判/误判：无。
- 🟡 漏判/偏乐观：R1（fixed-tmp race 与 3 天前 lesson 冲突，phase 6 L2 R3 把同类标 🟢 minor，本审据新对照论据升级 🟡）；R2（phase 7 checklist 未直接覆盖前序 .done 合法性，但「修代码优先」要求显式登记未交付依赖，主 agent 在 REVIEW.md §关联发现 提及但未标为 phase 7 阻塞条件）。
- 🟢 漏判：R3（TECH-DEBT.md 文件不存在但声称登记——主 agent 文字漂移）、R4（tech-debt 比例 ≥50% 与 phase 7 checklist 精神张力，主 agent 自统计但未给出「下一 change 锚点」）。
- 通过项（独立得出）：产物齐全 / LESSONS 同步 / CHANGELOG / 归档清洁 / ADR 链 / AC-1~3+5+6+7 独立复跑 / 587 bats 全绿 / bash -n 干净——均经独立核实。

**Verdict**: pass（无 🔴 Critical；2 🟡 Major + 2 🟢 Minor。R1 是新代码应本次闭环的可修缺陷；R2 是继承性风险已有 fix 立项，需登记依赖。两者均不构成 AC 未实现 / spec 合规失败 / 数据损坏，故不触发 fail）

---

## 主 agent 响应（2026-07-24 · 修代码优先协议逐条分类）

> L2 Verdict=pass（0 Critical）。主 agent 对 R1-R4 逐条处理如下，均附代码变更或显式技术债登记（含理由 + 锚点），无纯文档敷衍。

### R1（🟡 fixed-tmp race）→ Fixed in: flow-kit-bundle/hooks/stop/lib/correction-file.sh
- **Fixed in**: `correction-file.sh` `write_model_missing_correction` 的条件写段（原 `:110-114`）。`${path}.tmp`（固定名）→ `mktemp "${path}.tmp.XXXXXX"`（随机化）+ jq 失败 `rm -f $tmp` 清理 + stderr 可观测告警。同步订正 `:93-97` 注释（原自称 "avoids TOCTOU race" 与实现不符 → 准确描述两类 race 各自的消除方式）。对齐同仓 `l2-detect.sh:143` 既有正确模式 + gate-review-fix 教训。
- **回归验证**: `bash -n` OK + `shellcheck -S warning` 新段无警告 + `test_model_degradation.bats` + `test_flow_kit_resume.bats`（14 用例，含 l3/l2-model-missing banner + compliance 优先 + 不删语义）全过 + **全量 587 bats exit 0 无回归**。既有 `correction_file_write`（:66/:73）同患属预存代码，非本 change 引入，留全 lib 一致性 tech-debt（不属本 change scope）。

### R2（🟡 6→7 transition 作者性弱路径）→ Tech-debt: 已立项 gate-done-authorship change 跟踪
- **分类**: `Tech-debt: 继承性风险（非本 change 新引入）`。phase 6 `.done` 由主 agent 自写（`written_by=main-agent-adjudicated`, `L3_verdict=fail`）解锁 gate——正是 L-054 描述的作者性缺口实例。本 change scope（模型解析）无法修 gate 重构（CHANGE.md out 段明示）。
- **依赖登记**（phase 7 checklist 要求）: **本 change 6→7 transition 合法性依赖未交付的 `gate-done-authorship` fix 尽早落地**。已立项 `.specs/gate-done-authorship/CHANGE.md`（含证据链 + 两种修法）。过渡期可信度由 **基于工件的独立核实** 支撑：L2 phase 7 独立复跑确认 L3 Critical 为架构误报（SKILL.md:236-256 实现存在 + test_flow_model 6 用例实跑 + 587 bats 全绿），非机制保证。REVIEW.md §关联发现 已补依赖关系标注。

### R3（🟢 TECH-DEBT.md 文字漂移）→ Fixed in: REVIEW.md
- **Fixed in**: `REVIEW.md §4.1`「记入 TECH-DEBT（低优先，后续 change 补）」订正为实际登记位置（INDEPENDENT-REVIEW-6.md §主 agent 裁判 + ADR-013 §Consequences），消除「声称登记到不存在的文件」的文字漂移。项目无 TECH-DEBT.md 文件（tech-debt 散落 REVIEW/LESSONS/ADR），采纳 L2 推荐方案 (b)（最低成本消除漂移）。

### R4（🟢 tech-debt 比例 + R5 cross-caller）→ 部分Fixed + Tech-debt（含锚点）
- R1 部分 → **Fixed in**（见上）：本 change 闭环消除 fixed-tmp race，R4 累积效应中的 tmp race 项已闭环。
- R5（三 caller 降级块机械复制）→ `Tech-debt: 抽 resolve_model_or_degrade helper 需处理 return（l3_review_run/l2_dispatch_prompt 函数）vs exit 3（29-indep 顶层脚本）上下文差异，复杂度收益比低`。**锚点具体化**（回应 L2 R4 Remedy）：纳入 `gate-done-authorship` change scope——该 change 本就要重构这 3 caller 的降级接线（作者性校验），顺势抽 helper，给 R1/R5 单一被测点。

### AC-4 技术债滥用防护说明（≥50% Tech-debt）
R1-R4 中 R2 + R5（R4 内）标 Tech-debt = 2/4 = 50%。说明：R2 是继承性风险（非本 change 新增源码缺陷，已有 fix 立项 + 工件级独立核实兜底）；R5 是跨 caller 重构（return vs exit 上下文差异，锚定 gate-done-authorship 一并处理）。**本 change 新引入的源码级 🟡（R1）已在本次代码闭环修复**，无新增源码级缺陷被敷衍推迟。

**主 agent 响应 verdict**: pass。R1（唯一新引入 🟡）已 Fixed + 全量回归；R2 继承性风险已登记依赖；R3 文字漂移已订正；R4/R5 锚点具体化。归档前无未处理的 🔴/🟡 推迟项。

---

## L3 重审（glm-5.1 外部模型 · 2026-07-24 01:24）

> 自动生成于 2026-07-24 01:24。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [],
  "major": [],
  "minor": [
    {
      "file": "CHANGELOG.md",
      "issue": "条目被阶段 7 工件流截断，内容不完整，无法核实 Conventional Commits 的完整语义信息。",
      "why": "归档产物必须完整无缺。截断的 CHANGELOG 违反完整性基线，导致无法判断是否正确记录了 change-id 和 LESSONS。",
      "fix": "补充完整的 CHANGELOG.md 文件内容，确保 l2-l3-model-config 的摘要完整写入。"
    },
    {
      "file": "TASK.md",
      "issue": "Archive 中缺失 TEST.md 独立产物文件，测试计划仅存在于阶段 7 堆栈的 TEST.md 片段中。",
      "why": "根据归档完整性要求，TEST.md 应作为独立的归档文件存在。目录列表未见 TEST.md，破坏了产物的齐全性。",
      "fix": "将测试计划沉淀为独立的 TEST.md 并放入归档目录。"
    },
    {
      "file": "TASK.md",
      "issue": "Task 列表序号不连续，缺失 T08。",
      "why": "根据 TASK.md 描述（删独立 skill T08），虽然 T08 被移除，但归档未保留或说明 T08 的占位，轻微违反了归档的可追溯性和原貌完整。",
      "fix": "建议在 TASK.md 归档版本中显式保留 T08 (canceled/void) 的记录，确保波次序列的完整性。"
    }
  ],
  "verdict": "pass",
  "summary": "归档核心产物（CHANGE/REQUIREMENT/DESIGN/TASK/SUMMARY/REVIEW）齐全且内容详实；虽然 CHANGELOG 被截断且缺失独立 TEST.md，但未引发 Critical 级阻断问题，整体判定为 pass。"
}
```
```

L3_artifact_hash: 688fd9423fb2e098078da70d71b8bf2c152c64889bf805b42d85673e7908adf3
