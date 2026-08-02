# 独立审查 · 阶段 1

---

## L2 盲审

### 🟡 R1 · US-5 缺硬性 AC 支撑：元故事无专用验收准则

**Severity**：🟡 Important

**Symptom**：REQUIREMENT.md:22-23 US-5 声明"作为维护者，我希望 5 项债务在一次 pipeline 内完成，避免 5 次重复 phase 0-3-7 开销"，但 AC 列表（类别 A–F，共 13 条）中无任一条 AC 验证"5 项修复在同一 change pipeline 内完成"。AC-F1（全量 bats 0 fail）验证质量但不验证批次交付。

**Source**：1-requirement 审查 checklist 第 1 条——"每条 US 至少有一条硬性 AC（非参考性、非 deferrable）支撑"。US-5 有 0 条对应 AC，属直接违反。flow-kit 当前无"change 边界验证"机制（如检查 git log 在同一 change-id 下是否包含所有 fix bullets），故此 gap 的系统级覆盖成本较高。

**Consequence**：实际风险低——change 结构（单 CHANGE.md 含 5 fix bullet）已隐含批次交付。但形式上：若未来有多项债务清理但回退为分拆 change，REQUIREMENT 层无 AC 举报此退化。

**Remedy**：补一条 AC-F4（或并入 AC-F1 扩展 Then 条件），例如：

```
**AC-F4** 批次交付验证
- Given 本 change 的所有改动已 commit
- When grep CHANGE.md "## What" 段的 fix bullet 数 + 对每个 fix bullet 对应的改动做 git log --grep
- Then 所有 fix 在同一 change-id 的 commit 历史中出现
- 验证方式: bats 测试 grep CHANGE.md + git log --oneline
```

若认为 AC-F1（全量 bats）已间接验证——因为所有 5 项改动的 bats 测试在同一 test suite 中跑——则应在 REQUIREMENT.md 显式标注"US-5 由 AC-F1 间接覆盖"并说明理由。当前无此标注。

---

### 🟡 R2 · AC-E2 anchor 集未穷举："等"字使 AC 范围不可判定

**Severity**：🟡 Important

**Symptom**：REQUIREMENT.md:89 Then 条件写"既有 anchor（`## 1.4` / `## 5` / `## 6` / `## 8` 等）全部存在"。`等`（etc.）使 anchor 集合不可判定——DESIGN/DEV 阶段无法凭此 AC 确定恰好需要保留哪些 header。验证方式仅说"grep -c"但未指定预期 count。

**Source**：1-requirement AC 可测性原则——Given/When/Then 的 Then 必须是可客观判定真/伪的布尔条件。`等`引入的开放性使 Then 不可自动判定（bats 脚本无法对"不知道有多少个的剩余 anchor"做 assert）。

**Consequence**：DESIGN 阶段可能在 4-dev.md 重写时遗漏非列出的既有 anchor，但 AC-E2 不会 fail（因为"等"涵盖了任意未列出的 anchor）——测试假绿。既有回归测试可能退化而未被 AC 捕获。

**Remedy**：
1. 穷举 4-dev.md 中所有必须保留的段落 header 为完整列表（不含 `等`），例如 grep `^## ` 4-dev.md 获取全部 header，列入 Then
2. 验证方式改为 `grep -c -f <anchor-list>` 并断言 count = N（精确匹配）
3. 或者在 Then 中声明"4-dev.md 改造前后的 `## ` header 集合 diff = 0"（grep 全量 header 做 set comparison）

---

### 🟢 R3 · AC 数量自检错误：声明 16 实则 13

**Severity**：🟢 Minor

**Symptom**：REQUIREMENT.md:184 自检行写"✅ 16 AC 全部 Given/When/Then"。实际 AC 数为 13（类别 A:2 + B:1 + C:2 + D:2 + E:3 + F:3 = 13）。差异 3 可能来自将 AC-A1 的三条 Then 子条件 (1)(2)(3) + AC-D1 的两条 Then 子条件 (1)(2) 各计为独立 AC——但子条件属于同一 AC，不构成独立验收准则。

**Source**：事实准确性——自检声明应与实际内容一致。

**Consequence**：无功能影响，但破坏 REQUIREMENT.md 自检段可信度。下游阶段引用"16 AC"作完成度指标时产生错误基数。

**Remedy**：将 `16 AC` 改为 `13 AC`（或显式标注"13 AC + 5 sub-conditions"以保留子条件可见性）。

---

### 🟢 R4 · NFR 性能指标无对应 AC——无法验证

**Severity**：🟢 Minor

**Symptom**：REQUIREMENT.md:148-149 列出 3 项性能 NFR（新增 bats ≤5s 单测、review-package 延迟 ≤10ms、4-dev.md 有效内容 ≤15KB），但 AC 列表中无任一条 AC 验证这些指标。AC-E1 仅验证行数（≤500 行），不验证实际 token 大小。≤5s 和 ≤10ms 两项无任何 AC 或测量指示。

**Source**：1-requirement NFR 审查——"NFR 完整：性能 / 安全 / 兼容性 / 可观测 是否覆盖？"覆盖 ≠ 验证。列出 NFR 但无验证路径 = 覆盖表象。

**Consequence**：实际风险低——安全/兼容性/可观测 NFR 均有隐式覆盖（bats 测试查 exit code；禁动清单 exception 由 AC-F3 验证）。性能 NFR 中 ≤15KB 可能由 token 测量协议（参考性指标不卡 toll-gate）豁免；≤5s 和 ≤10ms 属于微小优化，超标不造成功能退化。但若作为硬性 NFR 则需验证路径。

**Remedy**：二选一：
1. 标注性能 NFR 三项均为"参考性"（不卡 toll-gate），与双轨协议一致
2. 为 ≤5s 和 ≤10ms 补 AC（bats 测试加 `time` 断言或 `date +%s%N` 差值）

---

**Verdict**: pass
