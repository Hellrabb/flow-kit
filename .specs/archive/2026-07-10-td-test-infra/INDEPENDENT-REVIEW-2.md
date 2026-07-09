# 独立审查 · 阶段 2

## L2 盲审

**审查对象**：`.specs/td-test-infra/DESIGN.md`（参考 REQUIREMENT.md / CONTEXT.md）
**独立性声明**：仅依据工件 + 对既有产物（Makefile / test_stop_chain.bats / test_smoke_syntax.bats / hooks/stop/*.sh）只读核验。未接受主 agent 自评。

### 🟡 R1 · smoke 方法与既有同类 smoke 产物直接冲突 + AC-2 覆盖定义与既有范式脱节
- **Symptom**：DESIGN D2/§2 定 smoke = "bash-n + source + 1 函数断言"；但 `test_stop_chain.bats:6-7` 明确"无法 source，用 bash-n+grep"，且已覆盖 22/24/26/99。DESIGN §0.5.1 列其为"读，核实覆盖"却未实际读。
- **Source**：证据优先；既有产物实证反驳 DESIGN 核心 smoke 方法。
- **Consequence**：source-based → 8 脚本 source 失败 → AC-3 止损大面积触发 → TD-002 交付价值近 0；或悄悄回退 bash-n+grep 违反 DESIGN 明文。
- **Remedy**：DESIGN D2 改 bash-n+shebang+grep（方案 A · 对齐既有）；AC-2 覆盖定义补"bash-n 级 smoke 视作 covered"。

### 🟢 R2 · §4 风险表未追踪 D1 代价（重复率静默退化）
- **Symptom**：D1 自陈代价"重复率退化不被 check 捕获"，但 §4 三条风险无一对应。
- **Remedy**：§4 加 R4（重复率静默退化 + 缓解）。

### 🟢 R3 · §2 数据流低估 AC-2（grep 无法判定"调内部函数"）
- **Symptom**：§2 写"grep test/*.bats"，但 AC-2 覆盖判定需确认调用内部函数，grep 只能找 source 语句。
- **Remedy**：§2 细化"grep 定位 → 读 test 体确认"。

**Verdict**: pass（1 🟡 建议进 3-task 前响应；无 🔴 不阻断）

---

## 主 agent 响应（L2）

全部 `Fixed in DESIGN.md / REQUIREMENT.md`：

| 发现 | 行动 |
|---|---|
| R1 🟡 smoke 方法冲突 | Fixed：DESIGN D2 改 **bash-n+shebang+grep**（沿用 test_stop_chain · source 不可行）；§0.5.1 补"已读 test_stop_chain（覆盖 22/24/26/99）+ test_smoke_syntax（全 bash-n）"；§0.5.2 smoke 范式修正；§2 数据流修正；REQUIREMENT AC-2 覆盖定义补 covered/partial/gap（bash-n 级）+ AC-3 smoke 方法改 bash-n+grep |
| R2 🟢 §4 未追踪 D1 代价 | Fixed：§4 加 R4（重复率静默退化 · 人工定期 make dup + v2 threshold）|
| R3 🟢 §2 低估 AC-2 | Fixed：§2 细化（grep 定位候选 → 读 test 体确认）|

**关键收益**：R1 核实提前完成 AC-2 的核心发现——`test_stop_chain.bats` 已覆盖 22/24/26/99、`test_smoke_syntax.bats` 全 bash-n，故 17 主脚本语法层已全覆盖，真实缺口 = [business] 脚本中**缺 bash-n+grep 关键函数 smoke** 者（非 13 个全裸）。

无 Tech-debt / Not-applicable。

---

## L3 盲审（glm-4.7 外部模型 · 2026-07-09 23:50）

> 自动生成于 2026-07-09 23:50。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [
    {
      "file": "DESIGN.md (Section 1, D2)",
      "issue": "Smoke 测试范式论证存在矛盾",
      "why": "D2 理由中声称 stop 脚本依赖注入导致「无法在 bats 中直接 source」，但随后提出的解决方案却包含「bash -n」和「grep」。从严格的逻辑来看，bash -n（语法检查）并不依赖 source，grep（文本搜索）也不依赖 source。若依赖注入是阻碍 source 的唯一原因，则不应作为拒绝 source-based 的理由，除非存在逻辑与语法两方面的双重依赖未在设计中披露。",
      "fix": "修正 D2 理由：明确区分「运行时逻辑测试」（需 source，被环境依赖阻断）与「语法结构测试」（无需 source，仅 bash-n/grep）。声明本次变更仅覆盖语法结构层（L6），逻辑层由实际 hook 覆盖，从而理顺因果。"
    }
  ],
  "major": [
    {
      "file": "DESIGN.md (Section 0.5.1, TD-002)",
      "issue": "现有测试覆盖分析结论与后续决策不一致",
      "why": "0.5.1 明确指出 `test/test_smoke_syntax.bats` 已实现对 AC-4（全仓库 .sh 语法门禁）的**全覆盖**。然而在数据流（Section 2）中，TD-002 却计划通过 grep 再次扫描候选并生成 SUMMARY.md。这造成了数据流/动作与 0.5.1 证据的脱节：如果已有全覆盖，为何需要再次扫描核实？是全覆盖定义不准确，还是数据流描述冗余？",
      "fix": "核实 TD-002 的真实范围。若仅需补 stop 脚本的 grep 检查，应在 0.5.1 中明确 `test_smoke_syntax.bats` 不覆盖 stop 脚本的内容检查（尽管覆盖了语法），或者修正数据流描述，限定 grep 扫描仅针对 stop 脚本目录。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN.md (Section 1, D2)",
      "issue": "变量引用歧义",
      "why": "理由中提到「L2 R1 指出」，但 L2（子 agent）审查结果通常不属于既定架构事实。在独立审查中，引用此类外部争议点作为核心设计理由显得证据链不稳定。",
      "fix": "移除对 L2 R1 的引用，直接基于既有的 `test_stop_chain.bats` 源码（L6-7）作为事实依据来支撑范式选择。"
    }
  ],
  "verdict": "fail",
  "summary": "决策 D2 的逻辑推演存在明显的因果断裂（用 source 阻断解释 bash-n 选择），且 TD-002 的扫描动作与既有证据（全覆盖）存在冲突，需修正理由的一致性。"
}
```

---

## 主 agent 响应（L3）

L3 verdict=fail（critical: D2 因果断裂）。全部 `Fixed in DESIGN.md`：

| 发现 | 行动 |
|---|---|
| L3-critical D2 逻辑矛盾（用 source 阻断解释 bash-n 选择）| Fixed：D2 重写——分层明确（smoke=语法/结构层，逻辑层由 hook 覆盖）；`bash -n`/grep 本不依赖 source，"无法 source"是**逻辑层**测试的限制而非结构层 smoke 的理由 |
| L3-major 0.5.1 vs §2 冲突（语法全覆盖 vs 再扫描）| Fixed：§2 限定——语法层（bash-n）已全覆盖无需再扫；缺口仅在**内容层**（grep 关键函数），grep 仅针对 stop 脚本目录 |
| L3-minor D2 引用「L2 R1 指出」 | Fixed：D2 理由改为直接基于 `test_stop_chain.bats:6-7` 源码事实，移除「L2 R1 指出」外部引用 |

无 Tech-debt / Not-applicable。**待 L3 重审。**
```
