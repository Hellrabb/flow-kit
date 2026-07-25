# 独立审查 · 阶段 2

---

## L2 盲审

### 🟡 R1 · ADR-008/D7 归属错误：DESIGN D6 引用不正确

**Symptom（症状）**：DESIGN.md 第 80 行： "ADR-008 已定义 D7 path-guard 的 Bash/Write/Edit 拦截机制。本 change 仅改变 D7 的保护目标（握手 → .done），不改变 D7 机制本身——属于 ADR-008 的 scope 内演进，不需要新 ADR"
以及第 172 行： "触及既有 ADR-008（Correction File 系统 + 状态完整性）的 D7 path-guard 定义"

**Source（源头）**：ARCHITECTURE.md ADR-005（独立审查体系）的决策文本中提到过 D7 path-guard，但 ADR-008 的标题和决策文本是 "Correction File 系统 + 状态完整性"（统一 JSON 矫正文件、.flow-active 交叉验证、checkpoint 双层防护），不包含 path-guard D7 的定义。D7 的实际定义在 `independent-review-gate.sh` 的 `_gate_path_guard()` 函数（第 178-199 行）和文件头注释（第 9-13 行）中，不在任何 ADR 中。

**Consequence（后果）**：任何后续维护者按 DESIGN D6 指引去读 ADR-008 理解 D7 机制时，会找到矫正文件系统文档而非 path-guard 文档——造成理解偏差，降低架构文档可信度。若未来有人基于此错误引用做 ADR 状态变更（deprecate ADR-008 认为它也废弃了 D7），可能意外破坏 path-guard。

**Remedy（修补）**：
```diff
- | D6 | **不新增 ADR（本 change 属既有 ADR-008 的扩展）** | 新增 ADR-011（gate .done 作者性模型） | ADR-008 已定义 D7 path-guard 的 Bash/Write/Edit 拦截机制。...
+ | D6 | **不新增 ADR（本 change 属既有 ADR-005 的扩展）** | 新增 ADR-011（gate .done 作者性模型） | ADR-005（独立审查体系）的决策文本中引用 D7 path-guard 机制。D7 的实际定义在 independent-review-gate.sh 的 _gate_path_guard() 函数。本 change 仅改变 D7 的保护目标（握手 → .done），不改变 D7 机制本身——属于 ADR-005 scope 内演进，不需要新 ADR。...
```

同样修正第 172 行（"详见 ARCHITECTURE.md § 3 ADR-008" → "详见 ARCHITECTURE.md § 3 ADR-005"）。

---

### 🟡 R2 · L2-only 例外信号路径未定义：D3 实现细节缺失

**Symptom（症状）**：DESIGN.md D3 决定 "L2-only 例外：fail-open（gate_config 读取失败时放行）"，但未定义 `_is_dotdone_write()` 如何获取 gate_config 值来判断是否适用 L2-only 例外。`.independent-review-*.done` 的文件名中含阶段号（如 `.independent-review-6.done` 中的 `6`），但：
- 阶段号需从 Bash 命令字符串或 Write/Edit 的 file_path 中解析提取
- 提取后需关联到 `.flow-active.goal.gate_config` 中的对应 key（如 `"6-review"`）
- DESIGN.md 未指定解析策略（从 file_path glob 提取 vs 从 `fk_resolve_phase` 读当前阶段 vs 其他）

**Source（源头）**：DESIGN.md 0.5.2 表 "gate_config 值读取" 行仅说"新增 L2-only 例外判定需读 gate_config，沿用既有 jq 模式"，但未说明**从何处读取阶段号**来组装 gate_config key。`fk_resolve_phase` 返回当前 `.flow-active` 阶段，而 agent 可能写**未来阶段的 .done**（如 phase 5 时写 phase 6 的 .done 做提前准备）——此时读当前阶段会得出错误的 gate_config。

**Consequence（后果）**：实现者（AI 或人）在写 `_is_dotdone_write()` 时需自行决定阶段号来源，可能选错策略导致：
- 用 `fk_resolve_phase` → L2-only 用户写**下一阶段** .done 时被误拦（死锁）
- 用 file_path glob 提取 → 需额外解析逻辑，增加复杂度
- gate_config key 组装错误（`"6-review"` vs `"6"`）→ gate_config 查找失败 → fail-open 放行所有写（过度宽松）

**Remedy（修补）**：在 DESIGN.md 0.5.2 表或 D3 决策段中补充信号路径：
```
阶段号来源：从 Write/Edit 的 $file_path 或 Bash 的 $cmd 中通过 glob 提取
  file_path match: *.independent-review-<N>.done → phase=N
  cmd match: 同 glob 提取 N
gate_config key 组装：使用 PHASE_GATE_KEY_MAP["$N"] 映射（如 6→"6-review"）
gate_config 值读取：jq -r '.goal.gate_config["6-review"] // "off"' "$flow_file"
  读取失败（jq error / flow_file 不存在 / key 缺失）→ fail-open → 放行
```
明确指定 `PHASE_GATE_KEY_MAP` 为组装 gate_config key 的单一来源（符合 `[2026-07-11]` 已锁决策）。

---

### 🟡 R3 · 风险清单事实错误：R1 声称 dd of= 未覆盖，但 is_handshake_write 已覆盖

**Symptom（症状）**：DESIGN.md R1（第 181 行）: "exotic write 路径（perl -i / python -c / dd of=）留 v2 加密签名"
但 `independent-review-gate.sh` 第 50 行 `is_handshake_write()` 函数明确包含：
```bash
[[ "$c" =~ dd[[:space:]].*of= ]] && return 0
```

**Source（源头）**：`is_handshake_write()` 的注释（第 39 行）说 "v1 非穷尽：挡常见 > / >> / tee / cp / mv / sed -i / printf / dd of= / install / awk / heredoc"——注释本身就把 dd of= 列为已覆盖。DESIGN.md R1 的列表与源码注释矛盾。

**Consequence（后果）**：风险清单的可信度降低。读者看到 R1 错误后可能怀疑其他风险的评估准确性。实现者若误信 R1 而尝试为 dd of= 添加额外覆盖，会引入无意义复杂度。不影响安全性（dd of= 实际已被覆盖），但影响文档质量。

**Remedy（修补）**：
```diff
- | R1 | **实现风险**：`_is_dotdone_write()` glob 匹配遗漏 exotic write 路径（perl -i / python -c / dd of=） | ...
+ | R1 | **实现风险**：`_is_dotdone_write()` glob 匹配遗漏 exotic write 路径（perl -i / python -c） | ...
```
从 exotic 列表中移除 dd of=（其已在 v1 覆盖）。另外，R1 描述 "dd of=" 时用词 "遗漏" 也不准确——`is_handshake_write` 已覆盖，`_is_dotdone_write` 继承同一写路径匹配器后自然也覆盖。

---

### 🟡 R4 · .done KVP 键数与架构文档不一致：6 键 vs 8 键

**Symptom（症状）**：REQUIREMENT.md 假设 ".done 6 键 KVP 格式不变（phase/change_id/written_by/L2_verdict/L3_verdict/artifacts）"，CONTEXT.md 术语表 "done 6 键 KVP" 也列 6 键。但 ARCHITECTURE.md § 4.1 .done 文件 KVP 格式实际列出 8 个字段：
```
phase / change_id / written_by / written_at / L2_verdict / L3_verdict / session_id / artifacts
```
额外的 `written_at` 和 `session_id` 两个字段不在 "6 键" 定义中。DESIGN.md 第 187 行 R5 提到 `written_by` 值不统一，但未澄清 6 键 vs 8 键的差异。

**Source（源头）**：CONTEXT.md 术语表 "done 6 键 KVP" 条目（第 136 行）与 ARCHITECTURE.md § 4.1 契约格式（第 233-244 行）不一致。`done-validation.sh` 第 18 行 `MIN_MEANINGFUL_LINES=6` 是最小行数阈值（非键数），可能掩盖了键数差异。

**Consequence（后果）**：若实现者按 "6 键" 理解来构造或校验 .done，可能遗漏 `written_at` 和 `session_id` 字段。当前 `done-validation.sh` Tier 1 校验用 `MIN_MEANINGFUL_LINES=6`（最小行数），8 行的 .done 能通过——但如果未来有人基于 "6 键" 假设将阈值收紧为恰好 6，8 键 .done 会误判失败。

**Remedy（修补）**：DESIGN.md 中显式声明实际 .done KVP 为 8 键（与 ARCHITECTURE.md § 4.1 一致），并加注 "6 键" 术语为历史简称（指核心 6 键不含元数据字段 written_at/session_id）。更新 R5 段使其引用 8 键格式。可选择同步更新 CONTEXT.md 术语表（在 gate-done-authorship 追加段中注明实际 8 键）。

---

### 🟡 R5 · _is_dotdone_write glob 匹配覆盖范围未分析：可能引入新误报

**Symptom（症状）**：DESIGN.md D5（第 79 行）仅说 ".done 文件名含 phase 号（glob `*.independent-review-*.done`），匹配比握手文件名（精确 `.flow-active.independent-review`）稍复杂"，未分析 glob 通配符引入的新误报风险。

具体而言：
- 旧模式 `.flow-active.independent-review` 是**精确子串**匹配——文件名固定，误报仅出现在命令涉及该特定文件时
- 新模式 `*.independent-review-*.done` 是**双通配**匹配——`*` 可匹配任意路径前缀和任意阶段号，意味着任何命令提及**任意 change 的任意阶段** .done 文件都会触发后续写路径检测

例如：`grep -l pass .specs/old-change/.independent-review-2.done > /dev/null` 在新模式下会匹配 glob 然后匹配 redirect 模式 → 误拦截（旧模式不会，因为不涉及 `.flow-active.independent-review`）。

**Source（源头）**：`is_handshake_write()` 第 43 行 `[[ "$c" == *.flow-active.independent-review* ]]` 是精确子串；替换为 `[[ "$c" == *.independent-review-*.done* ]]` 后匹配面扩大。D5 承认 "稍复杂" 但未量化误报增长。

**Consequence（后果）**：Bash 工具中任何涉及 `.independent-review-*.done` 的读操作（grep/cat/head/tail/diff）若碰巧同时含 redirect 或 tee 等写模式，会被误拦截。虽不常见（读 .done + 重定向到其他文件的组合较少），但比旧模式概率高。轻则 agent 工具调用被拒需重试（体验降级），重则 pipeline 中自动化步骤失败（若 agent 不重试）。

**Remedy（修补）**：在 DESIGN.md D5 取舍代价列或风险段补充：
```
误报面分析：新模式 `*.independent-review-*.done*` 匹配范围大于旧模式 `.flow-active.independent-review`。
但 .done 文件通常在 `.specs/<id>/` 下，agent 读 .done 内容时若同时重定向（如 `grep pass .done > results.txt`）
会被误拦。缓解：① path-guard fail-open（误拦不卡死，agent 可重试改方式）② 如误报率过高，v2 考虑
细化匹配（仅拦截 `>` 重定向到 .done 本身的操作，放行读取+写到其他文件）。
```
此为现有机制缺陷的延续（`is_handshake_write` 同样有误报可能），非新引入，但应在 DESIGN 中诚实记录。

---

### 🟢 R6 · R3 风险概率评估缺少验证路径：仅声称"hook 接线不改变此假设"

**Symptom（症状）**：DESIGN.md R3（第 183 行）称 "l3_review_run 在 Stop hook 进程内运行，不经过 PreToolUse——path-guard 天然不拦截。但需确认 install 后的 hook 接线不改变此假设"。概率标 "极低" 但未给出**如何**确认接线不改变的验证步骤。

**Source（源头）**：R3 的缓解措施 "需确认 install 后的 hook 接线不改变此假设" 只是一个提醒，没有对应的 AC 或测试计划来验证。

**Consequence（后果）**：若 install 脚本接线改变（如未来将 l3_review_run 的调用移到 PreToolUse 上下文），此假设失效时无人察觉——L3 写 .done 被 path-guard 误拦，pipeline 死锁。虽然概率确实极低，但缺乏验证机制。

**Remedy（修补）**：在 AC-2 或 AC-6 的测试中增加 1 个用例：模拟 l3_review_run 写 .done 的场景，验证 path-guard 不拦截。或在 DESIGN.md R3 缓解列中引用具体的安装验证步骤（如 `make test` 中已有测试覆盖此路径则注明测试编号）。

---

### 🟢 R7 · D2 后置兜底讨论不完整：未提 done-validation Tier 1 本身可作为轻量兜底

**Symptom（症状）**：DESIGN.md D2 取舍代价列说 "若 path-guard 被绕过（hook bug / 环境异常），无后置兜底"，R4 也重复 "path-guard 被绕过时无后置兜底"。但实际上 `done-validation.sh` Tier 1（元数据快校验：非空 + KVP + 值域校验）在 transition 时仍然执行——它能拦截**空文件**和**格式错误的 .done**。只是不验证**作者性**（谁写的）。

**Source（源头）**：DESIGN.md 2.2 图显示 Tier 1 仍保留（"Tier 1 元数据快校验"），但 D2 和 R4 的文字描述暗示 "无任何后置兜底"，表述过度悲观。

**Consequence（后果）**：误导读者认为删除 T3 后 transition 完全没有防线。实际 Tier 1 仍提供基本的格式正确性校验。不影响设计决策本身，但文档准确性受影响。

**Remedy（修补）**：修改 D2 取舍代价和 R4 描述，将 "无后置兜底" 改为 "无后置**作者性**兜底（Tier 1 元数据校验仍提供格式有效性基础防护，但不再验证写入者身份）"。

---

**Verdict**: pass

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-24 02:26）

> 自动生成于 2026-07-24 02:26。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "DESIGN (威胁模型/风险段)",
      "issue": "未覆盖通过硬链接间接写 `.done` 的绕过方式",
      "why": "Agent 可通过 Bash tool 执行 `ln` 创建硬链接指向 `.done` 文件，然后通过写硬链接修改 `.done` 内容。由于写硬链接的目标路径不匹配 `.independent-review-*.done` 模式，path-guard 无法拦截。威胁模型 T2 仅考虑了子目录 mv，风险段 R1 列举的 exotic 路径（perl -i / python -c / dd of=）未包含 `ln`。该缺口可能导致安全绕过。",
      "fix": "在威胁模型中新增条目（如 T8）描述硬链接绕过，并评估是否扩展 `_is_dotdone_write()` 检测 `ln` 命令或对硬链接目标的写操作；或在风险段明确此风险（可归入 v2 范围，但当前 v1 未覆盖）。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN (9.2 新增/改变的项目级技术决策)",
      "issue": "决策描述未明确兼容既有 `.done` 文件中 `written_by` 历史值（如 `stop-hook-29`）",
      "why": "虽然 R5 说明 Tier1 仅检查非空，但决策条目本身缺少向后兼容的显式声明，可能误导后续维护者认为必须统一 `written_by` 值。",
      "fix": "在 9.2 对应行补充一句话：既有 `.done` 文件（含 `written_by=stop-hook-29` 等历史值）不作修改，正常放行。"
    }
  ],
  "verdict": "pass",
  "summary": "设计文档 ADR 决策合理、理由充分，与既有架构对齐良好，抽象层次得当。但威胁模型/风险段遗漏了硬链接间接写 .done 的绕过方式，属于 major 问题，建议补充。整体方案通过独立盲审。"
}
```

L3_artifact_hash: a46dd29e7d9d27c8bdf90a70b628c4bdcfa9309a9d07791551bb627cc29313ba
