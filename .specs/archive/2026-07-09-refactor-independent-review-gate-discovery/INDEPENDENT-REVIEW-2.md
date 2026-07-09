# 独立审查 · 阶段 2

## L2 盲审

> 固化盲审子 agent（architect-reviewer）原样产出，主 agent 未改一字。

## L2 独立盲审 · 阶段 2 设计审查

- **change-id**: refactor-independent-review-gate
- **阶段**: 2-design
- **审查工件**: `.specs/refactor-independent-review-gate/DESIGN.md`
- **独立性声明**: 未检测到主 agent 上下文注入。仅依据指定工件 + 源码独立核验。

### 🔴 F1 · TD-011 严重度与"误报"前提与实测不符（DESIGN 核心前提错误）

- **Symptom**: DESIGN §0.5.1 / REQUIREMENT US-1 / CONTEXT TD-011 条目均声称 L69 的 `&&` 被 `[[ ]]` 当逻辑与后，`is_phase_write` 会把 `ls x.tmp y` 误报为 phase write。TD-011 据此标 🔴 Critical。
- **Source**: 独立核验（对完整函数实测，非孤立测 L69）：对 `ls .flow-active.tmp bar`，**buggy 版本函数返回 rc=1（no-match），并非误报**。原因：L69 的 `&&` 短路确实使该行"恒真匹配 `.tmp+空格`"，但仅作用于 `if/elif` 链——执行 `:;` 后**仍 fall-through 到 L73-75 的 phase-target gate**。`ls .flow-active.tmp bar` 不命中 L73-75 任一条 → return 1。L73-75 才是函数级布尔返回的真正决策者。
- **Consequence**: (1) US-1 前提（"`ls x.tmp y` 被当 phase write"）实测不成立。(2) TD-011 标 🔴 依据被高估：实际后果是 SC2157 lint 告警 + L69 意图损坏，**无 gate 行为级误报/漏报可复现**。(3) AC-1「修后前者 MATCH、后者 no-match」的"前者 MATCH"在 buggy 版本也已 MATCH，AC-1 实际验证的是"no-match 不变"。
- **Remedy**: (1) 重写 US-1/AC-1：从"修误报"改为"清理 SC2157 lint + 恢复 L69 意图"。(2) TD-011 严重度降 🟡，或 7-integration 补"无法构造行为差异输入集"反证。(3) AC-1 改为断言 SC2157 清零 + L69 意图恢复。

### 🔴 F2 · 验证基础设施失效（test_gate_integrity.bats setup `set +e` 使所有断言失效）· DESIGN 未识别

- **Symptom**: DESIGN §0.5/§5 R1 假设 AC-3 sandbox + bats 回归能验证 18 处 regex 治理；AC-1/AC-2/AC-5 落点 `test_gate_integrity.bats`。但实测该文件 setup（line 30 `set +e`）使 bats 无法检测断言失败。
- **Source**: 最小复现：setup 含 `set +e` → `false`、`[ 1 -eq 0 ]`、`fn; [ $? -eq 0 ]`（fn 返 1）三条全报 "ok"。无 setup → 正确报 "not ok"。实际文件 23 tests 0 not ok（含 D10 三条预期 return 0 但实际 return 1 的 case）。
- **Consequence**: (1) AC-1/AC-2 pass 是橡皮图章。(2) AC-5 无法保证 0 BW01——本发现即新型 BW01。(3) 前置依赖 `test-setup-path-fix-2026-07` 未真正闭合 TD-012（修了路径让函数加载，但 set +e 让断言失效）。(4) DESIGN §5 R1 的 bats 回归支柱失效。
- **Remedy**: (1) DESIGN 新增 R4 🔴：setup `set +e` 破坏断言评估。(2) AC-1/AC-2 落点改到不含 set +e 的文件，或本 change 顺手修 setup（去 set +e，改 if/then/fail 或子 shell 模式吸收 return 2）。(3) AC-5 增反向断言（注入 false 后 make test 必须 non-zero）。

### 🟡 F3 · DESIGN §0.5.3 下游审计推理不精确（结论恰好正确但链条薄弱）

- **Symptom**: §0.5.3 称"L175/L366 不依赖 line 69 误报"，理由"下游只消费布尔返回值"。
- **Source**: 下游确实只消费布尔返回值。但关键是**布尔返回值是否变化**——F1 实测不变，故"风险低"结论正确，但推理链条混淆"不区分哪条 regex 命中"与"不受 L69 bug 影响"。
- **Consequence**: 若未来 L73-75 被弱化，当前措辞无法预警。
- **Remedy**: 改写为"对 F1 实测枚举输入集，buggy 与 fixed 布尔返回值完全一致——这才是 AC-7 风险低依据"，AC-7 判定表把"输入集枚举"作为可机器核验内容。

### 🟢 F4 · DESIGN §0 行号漂移 1 行
- CONTEXT line 201 实为"阶段切换三道防线"，user-scope hooks 在 line 202。改 line 202 或内容锚定。

### 🟢 F5 · TD-004/005 与 regex lib 抽取关联薄弱
- TD-004=markdown 样板重复，TD-005=jq 逻辑重复，均非 regex lib 债。去除关联或注明理由。

### 已核验属实（公平记录）
DESIGN 中以下事实声明全部属实：函数行号、6 函数 regex 分布（8+6+1+1+2=18，L69 唯一 bug）、调用点 L175→_fk_phase_direction / L366→deny_reason、shellcheck 基线 6×SC1090+2×SC2034、L68 disable+TODO、报错文案 L223/246/256、D1 修复手法实测有效。**SC2157 bug 真实、D1 技术正确**——本审查 fail 不否定修复本身，否定的是 DESIGN 对其影响与验证的错误描述。

**Verdict**: fail（2 🔴 Critical：F1 核心前提错误 + F2 验证基础设施失效，使 DESIGN 风险评估与验证策略两大支柱失真）

---

## 主 agent 核验（receiving-code-review · 实测确认）

> 按 receiving-code-review 精神，对 L2 每条事实声明独立 shell 实测。**两条 🔴 均确认属实，主 agent 承认错误。**

### F1 实测确认 · 主 agent 承认

完整 `is_phase_write` 函数（从 gate 文件提取，非孤立 regex）实测各输入返回值：

```
rc=1  [真atomic-write]   echo x > .flow-active.tmp && mv .flow-active.tmp .flow-active
rc=1  [L2称不误报的]     ls .flow-active.tmp bar
rc=1  [phase写入jq]      jq ".phase=2" .flow-active > .flow-active.tmp && mv ...
rc=1  [无关命令]         ls -la
rc=1  [仅含flow-active]  cat .flow-active
```

**全部 rc=1**。包括真 atomic-write。证实：L69 命中后 fall-through 到 L73-75，函数级返回值由 L73-75（phase 字段名检测）决定，与 L69 的 `&&` bug 无关。

**根因（主 agent 自省）**：0-change 阶段实验2b 测的是**孤立的 L69 regex** `[[ "$c" =~ \.tmp...&&...mv ]]`（确实恒真 MATCH），**没有测完整 is_phase_write 函数**。导致 US-1「误报」叙事建立在错误前提上，一路传递到 REQUIREMENT/DESIGN/CONTEXT。L2 阶段 2 的完整函数实测揭穿了这个错误。**这是主 agent 0-change 实证的方法缺陷**（应测完整函数，非孤立语句）。

**结论**：TD-011 真实存在（SC2157 lint + L69 atomic-write 检测意图损坏），但**无 gate 行为级后果**（函数级返回值不变）。严重度应从 🔴 降 🟡。

### F2 实测确认 · 主 agent 承认

`test/test_gate_integrity.bats` setup line 30: `set +e  # 函数 return 2 不触发 set -e`。最小复现：

```
有 set+e setup:  false / [ 1 -eq 0 ] / fn(return 1)  → 全报 ok（假绿）
无 setup 对照:   false / [ 1 -eq 0 ]                  → 正确报 not ok
实际文件:        23 tests, 0 not ok（含应 fail 的 D10 case）
```

证实：`set +e` 关闭 bats 的 errexit 失败检测 → 断言失败不触发 test fail → 假绿。AC-1/AC-2/AC-5 落点该文件的 pass 无法验证任何东西。

**这是比 TD-011 更严重的基础设施问题**，且揭示 `test-setup-path-fix-2026-07` 未真正闭合 TD-012（修了路径让函数加载，但 set +e 让断言失效，假绿性质不变）。

### 主 agent 处置（pending 用户决策）

F1/F2 改变 change 性质，需用户定方向（见对话）。主 agent 不擅自决定范围调整。

---

## L2 盲审（第二轮 · 复审 DESIGN v2）

> 独立盲审子 agent（architect-reviewer）复审 DESIGN v2，原样产出。Verdict: **fail**（2 新 🔴）。

**F1 🔴 — D5/AC-5 矛盾**：D5（去 set+e）会暴露 D10 测试期望错误（D10 期望 is_phase_write return 0，实测 rc=1，set+e 假绿一直掩盖）→ D10 变红 → AC-5 全绿无法达成。DESIGN 对此沉默。

**F2 🔴 — L73-75 诊断错误 + is_phase_write 非功能**：DESIGN v2「L73-75 兜底」叙事被推翻。L73-75 regex `\.flow-active.*\.phase=` 要求 .flow-active 在 phase 字段名**之前**，但典型 jq 命令布局相反（字段名在前）→ L73-75 从不匹配 → is_phase_write 对所有现实 phase-write 命令漏检 → **gate phase-transition 检测对 jq 完全失效**（仅靠 git commit/gh pr create 兜底）。比 TD-011 严重得多的预存在 bug。

**F3 🟡 / F4 🟡 / F5-F6 🟢**：D5 修复复杂度低估（去 set+e 需绑定 if/then/fail 重构，否则 17 测试 rc=127 崩溃）/ D4 不立 ADR 理由偏弱 / F1 观测值准确但论据需随 F2 修正。

## 主 agent 核验（第二轮 · 实测确认）

**F2 实测确认**：
```
典型 jq 命令（字段在前）:
  jq '.phase=5' .flow-active                          → L73=0 L74=0 L75=0  (全不匹配)
  jq '.goal.current_phase="2"' .flow-active           → L73=0 L74=0 L75=0
  jq '.phase=2' .flow-active > .tmp && mv ... .flow-active → L73=0 L74=0 L75=0
反序命令(.flow-active 在前, 非真实):
  echo x > .flow-active.phase=5                       → L73=1  (匹配)
```
证实：L73-75 regex 顺序要求 .flow-active 在前，与真实 jq 命令布局相反 → **is_phase_write 对真实命令漏检**。

**F1 实测确认**：D10 测试（test_gate_integrity.bats L212/218）期望 is_phase_write「拦 .phases_done / .phase= 写」(return 0)，但 is_phase_write 对这些输入 rc=1（L73-75 漏检）→ D10 假绿。

**4 层发现图景**（本 change 越查越深）：
1. TD-011: L69 `&&` bug → SC2157 lint + 意图损坏（**无行为后果** · 降 🟡）
2. setup `set+e` → 测试断言失效（假绿）· 阻塞验证
3. D10 测试期望错（return 0 vs 实际 rc=1）→ 假绿掩盖 · D5 修 setup 必暴露
4. **L73-75 regex 顺序 bug → is_phase_write 对 jq 漏检 → gate phase-transition 检测失效**（严重安全隐患 · 比 TD-011 严重得多）

第 3-4 层耦合：修 setup（D5）→ 暴露 D10 → D10 根因是 L73-75 漏检 → 不修 L73-75 则 D10 无法正确 + gate 仍失效。本 change 已无法在原 scope（TD-011 bugfix）内收口。需用户定收口策略（见对话）。

---

## L2 盲审（第三轮 · 复审 DESIGN v3）

> architect-reviewer 复审 DESIGN v3。Verdict: **fail**（2 新 🔴）。但本次主 agent 核验后发现 **L2 在正确语境下成立**（变量化），增量修订。

**Critical 1 🔴 — L71 `\>[^=]` 变量化触发 GNU 单词边界**：L2 声称 `\>` 是单词边界。主 agent 初测**内联** `\>[^=]` → no-match（看似 L2 错）。但深究发现 **D2 全文件治理把 L71 改变量化** `re='\>[^=]'` → regex 引擎收到原始 `\>` → **GNU 单词边界**（"hello world" MATCH）。变量化语境下 L2 对：纯读 phases_done 误判 phase write（return 0，应 1）。

**主 agent 核验铁证**（receiving-code-review：初反应反驳，深究后确认 L2 对）：
```
内联 [[ c =~ \>[^=] ]]  → "hello world" no-match   (bash 转义 \> → 字面 >)
变量  re='\>[^=]'; [[ c =~ $re ]]  → "hello world" MATCH  (regex 收到 \> → 单词边界)
D6 + L71变量化(\>[^=])  → 纯读phases_done return 0 ✗ (复现 L2 Critical1)
修复 [>][^=] 字符类    → 全 ✓ (纯读 return 1 / atomic return 0)
```

**Critical 2 🔴**：D6+L71变量化后 D10 pure-read case FAIL（依赖 Critical 1）。修 L71（`[>][^=]`）解决。

**处置**：接受 Critical 1/2。DESIGN v4 增 D8（L71 变量化用 `[>][^=]`）+ L71 重分类"变量化 bug 修复" + R6（全文件治理改变 regex 行为）+ LESSONS（`\>` 内联 vs 变量）。sandbox 修复版端到端全 ✓。

**反思**：本 change DESIGN 阶段 L2 三轮，每轮揭穿一层（L73-75 顺序 → setup 假绿 → L71 变量化边界）。这是 gate 代码的深层系统性问题。L2 独立审查的价值在此充分体现——主 agent 单独难以发现这些跨语境 regex 细节。

---

## L2 盲审（第四轮 · 复审 DESIGN v4）

> architect-reviewer 复审 DESIGN v4。**Verdict: pass** ✅（无 🔴 Critical）。核心修复 D6/D8 经实测铁证成立。4 项 finding（3 🟡 + 1 🟢）均为范围/声明不完整，建议实施前修订。

**Finding 1 🟡 — D5 实施范围低估**：去 set+e 实测断裂 13 项（非只 D10），需改 9 条期望非零测试体（AC-1 ①-⑥ + D9 + D7 #17-18 + D10 #21）。
**Finding 2 🟡 — R5 对 Case A 失效**：`_fk_phase_direction` L85 grep 抓不到双引号+转义 jq filter（`current_phase = \"7\"`）→ noop → 裸 transition 放行。pre-existing `_fk_phase_direction` 限制（禁动）。
**Finding 3 🟡 — D8 遗漏 L30**：`is_handshake_write` L30 同款 `\>[^=]`，D8 只修 L71。
**Finding 4 🟢 — §2 图漏 noop 分支**。

## 主 agent 处置（第四轮 · 全接受 · DESIGN v5）

| Finding | 处置 |
|---|---|
| F1 | **Fixed in: D5** — 测试体改写清单扩为 9 条（AC-1 ①-⑥ + D9 + D7 #17-18 + D10 #21）|
| F2 | **Fixed in: R5 caveat + LESSONS** — Case A 限制（`_fk_phase_direction` pre-existing · 禁动 · 本 change 不修）记 LESSONS，7-integration 评估独立 change |
| F3 | **Fixed in: D8** — 扩为"L30 + L71 所有 `\>[^=]` 变量化用 `[>][^=]`" |
| F4 | **Fixed in: §2 图** — 补 rollback/noop/forward 三分支 + noop 放行注释 |

**结论**：L2 pass + 4 finding 全 Fixed in（DESIGN v5）。核心修复（D1 L69 / D6 L73-75 / D8 L30+L71 / D5 setup）经 4 轮 L2 + sandbox 实测铁证成立。DESIGN v5 进 L3 + toll-gate 2→3。

---

## L3 盲审（glm-4.7 外部模型 · 2026-07-09 02:12）

> 自动生成于 2026-07-09 02:12。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [
    {
      "file": ".flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh",
      "issue": "D8 变量化引入的 GNU 单词边界破坏逻辑",
      "why": "将内联正则 `\\>[^=]` 变量化存为 `re='\\>[^=]'` 会导致 Bash 在某些上下文（如 `[[ $c =~ $re ]]` 或 `grep -E $re`）将 `\\>` 解释为 GNU 单词边界（Word Boundary）而非字面 `>` 字符。这将导致 `is_handshake_write` 和 `is_phase_write` 对包含字母的命令（如 `jq`）产生误判，破坏 gate 的安全性。",
      "fix": "严格遵守 D8 决策，所有涉及 `>`（重定向）匹配且需变量化的场景，必须使用字符类 `[>][^=]` 替代 `\\>[^=]`。需检查 L30 (`is_handshake_write`) 和 L71 (`is_phase_write`) 的实际修改是否符合此要求，确保 `\\>` 没有以字面形式出现在变量赋值中。"
    },
    {
      "file": ".flow-kit-bundle/test/test_gate_integrity.bats",
      "issue": "测试框架仍存在 `set +e` 遗留风险或断言不严谨",
      "why": "虽然 D5 决策去除 `set +e`，但若测试体仍依赖 `$?` 或 `run` 后未严格校验 `$status`（即存在 `echo "pass"` 惯性），则 L73-75 修复带来的“return 0”正确结果仍可能被误判（如原 D10 逻辑）。必须验证 D5/D7 的实施是否彻底清除了所有 `[ $? -eq 0 ]` 的隐式通过路径。",
      "fix": "对照 D5/D7，审查所有 `is_phase_write` 相关测试用例，确保使用显式 `[ \"$status\" -eq 0 ]` 或 `if ! is_phase_write ...; then fail; fi` 模式，彻底移除任何可能导致假绿的旧测试模式。"
    }
  ],
  "major": [
    {
      "file": ".flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh",
      "issue": "L71 和 L30 修复的一致性依赖人工复核",
      "why": "D8 指出 L30 和 L71 存在相同的变量化 bug。审查工件显示 L71 是核心修复点，而 L30 是全局治理的一部分。若 L30 未按 D8 同步修复为 `[>][^=]`，`is_handshake_write` 将失效，导致 handshake 写入漏检。",
      "fix": "确认 L30 (`is_handshake_write`) 的 regex 变量定义已同步修改为 `[>][^=]`，而非保留错误的 `\\>[^=]`。"
    },
    {
      "file": ".flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh",
      "issue": "L69 修复后的上下文兼容性",
      "why": "L69 修复涉及 `.tmp&&mv` 的原子写检测。若修复后的 regex 变量化逻辑与 L73-75 的 `phase` 字段检测在逻辑上存在重叠或互斥（例如某些复合命令同时触发两者），需确保 `return` 路径清晰，不产生非预期的 `return 1`。",
      "fix": "验证 L69 修复后的 regex 在真实 `jq` 命令（含 `>` 字符）中不会误判，确保 `.tmp&&mv` 检测与后续的 phase 字段检测互不干扰。"
    }
  ],
  "minor": [
    {
      "file": ".specs/adr/002-l3-frontloading.md",
      "issue": "文档 ADR-002 状态为 proposed 与工件引用的强一致性冲突",
      "why": "工件上下文中多次引用 ADR-002 的决策（如 L3 前置），但 ADR-002 标记为 `proposed`。在盲审视角下，依赖一个未正式采纳的决策作为 gate 行为变更的依据，存在合规性风险。",
      "fix": "确认 ADR-002 的实际状态。若作为设计依据，应更新状态为 `accepted` 或 `implemented`；若仅为讨论稿，不应作为变更的授权依据。"
    }
  ],
  "verdict": "fail",
  "summary": "Fail：L71/L30 变量化引入的 GNU 单词边界 bug（D8）属于逻辑倒退风险，且测试清理（D5/D7）存在假绿残留风险，必须通过 sandbox 验证确保 `[>][^=]` 修正已落实且测试覆盖回归。"
}
```
```
