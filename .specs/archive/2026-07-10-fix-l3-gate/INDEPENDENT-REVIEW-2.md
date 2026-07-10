# 独立审查 · 阶段 2

## L2 盲审

### 🔴 R1 · D5 type handling unspecified：transition jq 引入 `.phase` 数值类型但未分析既有类型与消费者兼容性

**Symptom（症状）**：DESIGN.md §3.3 的 transition jq 修改为 `.phase = ($next | tonumber)`（数值），而 `.goal.current_phase = $next` 因 `--arg` 保持字符串类型。DESIGN.md 全文未分析当前 `.phase` 字段的既有类型（是字符串还是数值），也未说明 `fk_resolve_phase()`——ARCHITECTURE.md 与 CONTEXT.md 均标注为"唯一 phase 读取点"——是否已对两种类型做归一化处理。AC-4 自身亦暴露此分裂：`"N+1"` 用于 current_phase，`N+1`（裸数字）用于顶层 phase。

**Source（源头）**：类型一致性原则。同一个语义值（阶段编号）在两个字段中以不同 JSON 类型存储，任何跨字段比较（jq `==`、bash 数值运算）都可能因类型不匹配静默失败。ADL（Architecture Decision Log）中无对此类型分裂的明确决策记录。

**Consequence（后果）**：若 `fk_resolve_phase()` 或 gate 脚本中存在 jq 表达式对 `.phase` 做字符串比较（如 `select(.phase == "3")`），数值 `3` 不等于字符串 `"3"`，jq 匹配失败 → phase 解析静默返回空 → gate 误判当前阶段 → pipeline 状态混乱。后果严重但需特定条件触发（jq 严格类型比较路径）。中等概率，高影响。

**Remedy（修补）**：
1. 在 DESIGN.md §3.3 或新增 §3.5 中，追加对 `.phase` 既有类型的分析（grep 确认当前 `.phase` 是字符串还是数值）。
2. 若既有 `.phase` 已是数值：文档化此事实，确认 `fk_resolve_phase()` 兼容。
3. 若既有 `.phase` 是字符串：改为 `.phase = $next`（与 `current_phase` 同类型），避免类型分裂。
4. 无论哪种情况，建议 transition jq 统一两字段类型，降低未来维护者的认知负担。

---

### 🟡 R2 · D1 重审触发存在 TOCTOU 竞态：工件正在写入时 mtime 已更新但内容未完整

**Symptom（症状）**：DESIGN.md §3.1 的重审检测逻辑用 `stat -c %Y` 比较产物 mtime 与 review 文件 mtime。若主 agent 正在 `Write`/`Edit` 工具调用中写入产物文件，文件系统可能在内容完全落盘前更新 mtime。此时 hook 触发 L3，读到的产物内容可能截断或不完整。

**Source（源头）**：TOCTOU（Time-of-Check-Time-of-Use）经典并发问题。文件系统 mtime 不保证"内容已完整写入"语义——仅保证"inode 被修改过"。

**Consequence（后果）**：L3 基于不完整内容审查 → 可能产生误判（假 fail 或假 pass）。假 fail 会阻塞 pipeline（配合 D4 的"fail 不写 .done"），用户需手动重试。概率低（主 agent 写入与 hook 触发需恰好重叠），但后果中等。

**Remedy（修补）**：
1. 在 mtime 比较后、L3 API 调用前，增加一步文件大小稳定性检查：连续两次 `stat -c %s`（间隔 0.1s），若大小变化则等待重试（最多 3 次，共 0.3s）。
2. 或在 DESIGN.md 风险表中新增此项风险并评估概率（文档化即可，v1 不强制实现）。

---

### 🟡 R3 · D5 修改面可能大于枚举范围：rollback transition jq 与 skill 层 jq 模板未列入 §3.4

**Symptom（症状）**：DESIGN.md §3.4 枚举了 5 个 prompt 文件 + GO.md 的 transition jq 修改，但 AC-5 要求回退放行，且 CONTEXT.md 记载 pipeline 回退逻辑涉及 transition jq。回退时若使用不同 jq 模板（或 `fk_auto_phase` 直接操作 `.flow-active`），其 `.phase` 同步可能遗漏。此外，skills 层的 transition jq（如 `flow/SKILL.md` 中的 `generate_gates()` 或 goal 子命令的 transition 逻辑）是否也需同步未评估。

**Source（源头）**：ADR-004（Pipeline Goal 机制）记载"pipeline 逻辑分散在 GO.md + 7 个 prompt + 2 个 skill + 3 个 hook 模块"。DESIGN.md §3.4 仅覆盖了 prompts + GO.md + 1 个 hook 模块（31-auto-advance.sh），未覆盖 skill 层和回退路径。

**Consequence（后果）**：遗漏路径上的 transition 不同步 `.phase` → AC-4 部分路径失败 → `29-independent-review.sh` 读到过期 `.phase` → L3 误触发或漏触发。概率中等（取决于遗漏路径是否实际被使用），影响中等。

**Remedy（修补）**：
1. 在 DESIGN.md §3.4 末尾或实施前，执行 `grep -rn 'goal.current_phase\|\.phase\s*=' flow-kit-bundle/skills/ flow-kit-bundle/hooks/` 全仓扫描，列出所有 phase 写入点。
2. 将扫描结果补充到 §3.4 的修改清单中，逐项标注"需同步"或"不需要（原因）"。
3. 特别关注回退 transition 路径（rollback jq）是否被覆盖。

---

### 🟡 R4 · R2 风险缓解引用未验证机制：`FLOW_KIT_SKIP_L3` 存在性未确认

**Symptom（症状）**：DESIGN.md §5 R2 缓解措施写道"用户可通过 `FLOW_KIT_SKIP_L3=1` 跳过 L3"。但 DESIGN.md 全文未引用任何代码证据确认该环境变量在当前代码库中已实现且功能正常。

**Source（源头）**：缓解措施的有效性依赖于所述机制真实存在。若 `FLOW_KIT_SKIP_L3` 是计划中但未实现的功能，则 R2 的实际风险敞口大于评估值。

**Consequence（后果）**：若 L3 API 频繁超时且 `FLOW_KIT_SKIP_L3` 不存在，用户无法快速绕过 → pipeline 持续阻塞 → 用户体验严重恶化。概率取决于 L3 API 稳定性（当前标记为"中"）。

**Remedy（修补）**：
1. `grep -rn 'FLOW_KIT_SKIP_L3' flow-kit-bundle/` 确认该机制已实现。
2. 若不存在：在 DESIGN.md §5 R2 中更新缓解措施为实际可用的绕过方式（如手动 `touch .done` 或 `gate_config` 临时切换为 L2-only），并文档化绕过步骤。
3. 考虑在本次 change 中同步实现 `FLOW_KIT_SKIP_L3` 支持（若工作量小），或明确记录为已知限制。

---

### 🟡 R5 · D2 追加策略与 D3 verdict 读取的契约未闭合：section header 差异可能导致解析器遗漏重审 verdict

**Symptom（症状）**：DESIGN.md §3.1 规定重审段使用 `## L3 重审` header（区别于首次审查的 `## L3 盲审`），而 §1 D3 的 verdict 解析策略为"grep verdict 取最后匹配"。若既有的 verdict 解析器硬编码了 `## L3 盲审` 作为锚点（例如使用 awk 按 section 提取后再 grep），则新增的 `## L3 重审` 段内的 verdict 会被忽略。

**Source（源头）**：契约一致性原则。生产者（l3_review_run 写入）和消费者（gate 读取）必须对齐 section header 格式。D3 的文字描述暗示文件级 grep（无 section 锚定），但 DESIGN.md 未引用既有解析代码确认此行为。

**Consequence（后果）**：重审 verdict 被静默忽略 → gate 始终读取首次审查的 verdict → 即使重审 pass，pipeline 仍被旧 fail verdict 阻塞 → 整个 D1/D2 重审机制形同虚设。概率取决于既有解析器实现（若已是文件级 grep 则无问题），但 DESIGN.md 未做此验证。

**Remedy（修补）**：
1. 在 DESIGN.md §3.1 或 §1 D3 处追加一句：引用既有 verdict 解析代码路径和行号，确认其使用文件级 grep 而非 section 锚定。
2. 若既有代码有 section 锚定：同步修改解析逻辑，或将重审段 header 统一为 `## L3 盲审`（加子标题区分）。
3. 建议新增一项 AC：L3 重审后的 verdict 能被 gate 正确读取。

---

### 🟡 R6 · 缺失测试策略段：DESIGN.md 无验证计划

**Symptom（症状）**：DESIGN.md 全文无测试策略或验证计划段。REQUIREMENT.md 各 AC 的"验证方式"描述了手动验证步骤，但未转化为自动化测试用例。本 change 涉及 5 项行为变更（mtime 检测、追加写入、条件 .done、transition jq 四字段同步、verdict 解析），每项均需回归保护。

**Source（源头）**：ADR-007（质量基础设施）要求"每次改 hook/lib 需要同步更新 .bats 测试"。DESIGN.md 作为 2-design 阶段产物，应规划测试用例映射。

**Consequence（后果）**：无测试策略 → 实现后仅靠手动验证 → 回归风险高 → 后续 change 可能破坏本次修复而不自知。ADR-007 的 `make check` 门禁不会捕获新增逻辑的回归。

**Remedy（修补）**：
在 DESIGN.md 追加 §7 测试策略，至少包含：
1. 新增 bats 测试文件 `test/test_fix_l3_gate.bats`（或扩展现有测试文件）
2. 每项 AC 到测试用例的映射表（AC-1 → mtime 检测测试、AC-2/3 → .done 条件写入测试、AC-4 → transition jq 四字段测试、AC-5 → 回退放行测试）
3. 标注哪些测试需要 mock L3 API（网络调用），哪些可以纯文件系统测试

---

### 🟢 R7 · R1 stat 跨平台兼容方案未给出具体实现

**Symptom（症状）**：DESIGN.md §5 R1 缓解措施为"先测 `stat -c %Y` 是否可用，不可用则 fallback 到 `stat -f %m`；或直接用 `date -r <file> +%s` 跨平台"。但 §3.1 的伪代码仅使用了 `stat -c %Y` 无 fallback 逻辑。设计文档未给出跨平台兼容函数的签名或伪代码。

**Source（源头）**：可移植性设计原则。Bash 脚本的跨平台兼容不应推迟到实现阶段才"顺手处理"。

**Consequence（后果）**：在 macOS 上测试或使用时，stat 语法不兼容导致 mtime 获取失败 → `|| echo "0"` fallback → artifact_mtime=0 → 永不触发重审。影响范围限于 macOS 用户（当前概率低），但 DESIGN.md 作为设计文档应明确处理方式。

**Remedy（修补）**：
在 DESIGN.md §3.1 中补充跨平台 mtime 获取的辅助函数签名：
```bash
_get_file_mtime() {
  local f="$1"
  if stat -c %Y "$f" 2>/dev/null; then return 0; fi   # Linux
  if stat -f %m "$f" 2>/dev/null; then return 0; fi   # BSD/macOS
  date -r "$f" +%s 2>/dev/null || echo "0"            # POSIX fallback
}
```
并在重审检测段引用此函数替代裸 `stat -c %Y`。

---

### 🟢 R8 · D2 追加文件增长无预警机制

**Symptom（症状）**：DESIGN.md §5 R3 将文件增长归档完全推迟到 v2（"不在范围" §6 首条）。但未设定任何 v1 内的预警阈值或监控手段。若某阶段因反复修改触发 10+ 次重审（如用户与 L3 来回拉锯），文件可能增长到数百 KB。

**Source（源头）**：防御性设计原则。即使不实现完整归档，也应有基本的安全网。

**Consequence（后果）**：极端情况下 review 文件过大 → L3 prompt 构造时 `head -c` 截断可能截在重审段中间 → L3 读到不完整历史 → 审查质量下降。概率低（重审触发条件严格），但无检测机制意味着问题只能事后发现。

**Remedy（修补）**：
在 `l3_review_run()` 追加写入前增加大小检查：
```bash
local review_size=$(stat -c %s "$review_md" 2>/dev/null || echo 0)
if [ "$review_size" -gt 51200 ]; then  # 50KB
  echo "[l3-review] WARNING: review file exceeds 50KB (${review_size} bytes), consider manual cleanup" >&2
fi
```
此检查零成本，可在 v1 实现而不必等到 v2。

---

### 🟢 R9 · D4 设计未处理既有 fail .done 文件的清理/兼容

**Symptom（症状）**：DESIGN.md §3.2 将 .done 写入改为"仅 pass 时写入"，但未讨论磁盘上已存在的、由旧代码写入的 `L3_verdict=fail` 的 .done 文件应如何处理。这些"遗留 fail .done"在新 gate 逻辑下仍会被读取并可能被误判为有效放行凭证。

**Source（源头）**：向后兼容性原则。行为变更需考虑存量数据的迁移或兼容策略。

**Consequence（后果）**：若用户在工作目录中有旧 .done 文件（`L3_verdict=fail`），新的 gate 逻辑读取到后：若 gate 仅检查 .done 存在性（PCG 层），仍会放行；若 gate 检查 verdict 值，正确处理。但 DESIGN.md 未明确 gate 的 .done 读取行为是否也同步修改为"读取并校验 verdict=pass"。这是一个文档缺口。概率低（存量场景有限），影响中等。

**Remedy（修补）**：
1. 在 DESIGN.md 中明确 gate 侧对 .done 的读取校验逻辑：读取后不仅检查文件存在，还需验证 `L3_verdict=pass`。
2. 若 gate 侧已有此校验，引用代码位置确认。
3. 考虑在 l3_review_run 开头增加存量清理：若检测到既有 .done 且其中 L3_verdict != pass，删除该 .done（可选，取决于对用户工作流的侵入性容忍度）。

---

**Verdict**: fail

> 存在 1 项 🔴 Critical（R1：transition jq 引入 `.phase` 数值类型但未分析既有类型与消费者兼容性），构成设计缺陷，须在进入实现阶段前修复。6 项 🟡 Major 和 3 项 🟢 Minor 可在实现阶段陆续处理。

---

## L2 盲审（第二轮）· R1 修复验证 + 新问题检测

### 🟢 R1-FIXED · transition jq 类型一致性：`.phase = $next`（string）已与 `.goal.current_phase` 统一

**Symptom（症状）**：DESIGN.md §3.3 的 transition jq 当前为 `jq --arg next "$next_phase" ... '.goal.current_phase = $next | .phase = $next | ...'`。因为 `--arg` 天然产生 JSON string，`.phase` 与 `.goal.current_phase` 现在同为 string 类型。Round 1 的 `tonumber` → number 分裂已消除。

**Source（源头）**：DESIGN.md §3.3 修改 + §3.3 末尾新增「类型一致性」注释段。`fk_resolve_phase()`（`common.sh:243`）使用 `jq -r` 输出原始字符串后 bash `[[ "$phase" =~ ^[0-7]$ ]]` 比较，与 JSON 类型无关——兼容性分析正确。

**Consequence（后果）**：无。Round 1 🔴 R1 已解决。

**Remedy（修补）**：无需修补。但见下方 N1/N2/N3——修复本身引入了文档层面的新问题。

---

### 🟡 N1 · 类型分析注释的事实错误：`.phase` 既有类型声明与代码证据矛盾

**Symptom（症状）**：DESIGN.md §3.3 末尾「类型一致性」注释段声明 "`.phase` 当前在 `.flow-active` 中是 JSON number（如 `2`），而 `.goal.current_phase` 是 JSON string（如 `"2"`）"。代码证据显示：
- `26-workflow.sh:88`：`jq ".phase = \"$next_phase\""` —— 转义引号产生 JSON **string**（如 `"2"`）
- `31-auto-advance.sh:92-93`：pipeline 模式下**完全不更新** `.phase`（仅写 `.goal.current_phase` / `.goal.phases_done` / `.goal.gates`）

`.phase` 的实际 JSON 类型取决于最后写入它的代码路径：单阶段模式（26-workflow.sh）写为 string；pipeline 模式（31-auto-advance.sh）从未写入 `.phase`，故 `.phase` 保持 `.flow-active` 创建时的初始类型（可能是 number 也可能是 string，取决于创建代码——但 DESIGN.md 未引用创建代码确认）。

**Source（源头）**：设计文档的事实断言应基于代码 grep 证据。CONTEXT.md §既有抽象索引 明确标注 `fk_resolve_phase()` 是"唯一 phase 读取点"，但未记载 `.phase` 的写入类型。DESIGN.md 的"当前是 number"声明未附带 grep 输出或文件:行号引用。

**Consequence（后果）**：若实现者信任 DESIGN.md 的类型分析并基于"`.phase` 当前是 number"做额外兼容处理（如迁移逻辑），可能写出不必要的类型转换代码。实际风险低（`fk_resolve_phase` 使用 `jq -r` 已兼容两种类型），但文档可信度受损。

**Remedy（修补）**：
1. 在 DESIGN.md §3.3 注释段中标注实际 grep 证据：`26-workflow.sh:88` 写为 string；pipeline 模式（`31-auto-advance.sh:93`）当前不写 `.phase`。
2. 修正声明为："`.phase` 的既有 JSON 类型取决于写入路径——`26-workflow.sh` 写为 string，pipeline 模式下 `.phase` 未被 transition 更新。本修改统一为 string。"

---

### 🟡 N2 · DESIGN.md 内部类型不一致：§3.3 写 string，§3.4 写 number

**Symptom（症状）**：
- DESIGN.md §3.3（31-auto-advance.sh 修改）：`.phase = $next` → `--arg next "$next_phase"` → JSON **string** `"3"`
- DESIGN.md §3.4（prompt 模板修改）：`.phase = 2` / `.phase = 3` / `.phase = 4` → jq 数值字面量 → JSON **number** `3`

`31-auto-advance.sh` 和 prompt 中的 transition jq 是同一语义操作的不同执行路径（hook 自动推进 vs 主 agent 手动 jq）。若两条路径对同一字段写入不同类型，pipeline 生命周期中 `.phase` 将在 string 和 number 之间反复切换。

**Source（源头）**：类型一致性原则。同一字段在所有写入路径必须使用一致的 JSON 类型。DESIGN.md 作为单一设计文档，应在所有修改点统一类型决策。

**Consequence（后果）**：若 pipeline 中某次 transition 由 `31-auto-advance.sh` 执行（写 string `"3"`），下次由 prompt 中的主 agent 手动 jq 执行（写 number `4`），`.phase` 的类型在 JSON 中交替变化。虽然 `jq -r` 读取时两者均输出纯数字文本，但任何直接做 jq 数值比较的代码（如 `.phase > 2`）在遇到 string 值时会因类型不匹配静默失败（jq 中 `"3" > 2` 在 jq 1.6+ 会尝试类型转换，但行为依赖版本）。

**Remedy（修补）**：
1. 统一决策：全部使用 string（将 §3.4 的 prompt jq 改为 `.phase = "2"` 等，即 jq string 字面量）——**推荐**，与 §3.3 的 `--arg` 机制一致。
2. 或统一为 number：将 §3.3 改为 `--argjson next "$next_phase"`（需要上游保证 `$next_phase` 是裸数字），§3.4 保持 `.phase = 2`。
3. 无论选哪种，在 DESIGN.md 中显式声明类型决策并确保所有修改点一致。

---

### 🟡 N3 · AC-4 与 DESIGN.md 类型决策矛盾：REQUIREMENT 说 number，DESIGN 说 string

**Symptom（症状）**：REQUIREMENT.md AC-4 原文：
> `.flow-active` 中四个字段更新为一致值：`goal.current_phase = "N+1"`、顶层 `phase = N+1`、...

注意 `goal.current_phase = "N+1"` 带引号（string），而 `phase = N+1` 不带引号（number）。AC-4 自身就暴露了类型不一致的意图。DESIGN.md §3.3 将 `.phase` 写为 string，直接违背了 AC-4 的 `phase = N+1`（number）规格。

**Source（源头）**：REQUIREMENT 和 DESIGN 之间的一致性契约。DESIGN.md 可以覆盖 REQUIREMENT.md 的决定，但必须在 DESIGN.md 中显式标注"覆盖 AC-4 的类型规格"并给出理由。

**Consequence（后果）**：测试阶段（phase 5）将基于 AC-4 编写测试用例——若测试者遵循 AC-4 原文，会断言 `.phase` 为 number 类型，而实现产生的是 string，测试将失败。即便测试基于 DESIGN.md 调整，AC-4 作为"TEST 阶段派生用例的唯一来源"（REQUIREMENT.md 末尾注释），其内容与实际设计不一致会导致测试用例编写时产生混淆。

**Remedy（修补）**：
1. 在 DESIGN.md §3.3 或 §1 D5 中显式声明：本设计覆盖 AC-4 的类型规格——`phase` 字段统一使用 JSON string 类型（而非 AC-4 原文的 number），理由为与 `.goal.current_phase` 类型一致、且 `fk_resolve_phase()` 已兼容。
2. 同步更新 REQUIREMENT.md AC-4，将 `phase = N+1` 改为 `phase = "N+1"`（加引号），或标注"最终类型以 DESIGN.md §3.3 为准"。

---

### 🟡 R2-UNRESOLVED · TOCTOU 竞态：工件 mtime 检测与内容完整性之间无保护窗口

**Symptom（症状）**：Round 1 R2 指出的 TOCTOU 问题在 DESIGN.md 中仍未处理。§3.1 重审检测仅比较 mtime，无任何内容稳定性检查。§5 风险表也未列入此项。

**Source（源头）**：TOCTOU 经典并发问题。文件系统 mtime 更新不保证内容已完整写入。

**Consequence（后果）**：与 Round 1 R2 相同。概率低（主 agent Write 与 hook 触发需恰好重叠），但后果中等（L3 基于截断内容审查 → 假 fail 阻塞 pipeline）。

**Remedy（修补）**：与 Round 1 R2 相同。在 §5 风险表中新增此项，或在 §3.1 伪代码中增加可选的稳定性等待逻辑。

---

### 🟡 R3-PARTIAL · 修改面枚举仍不完整：§3.4 未覆盖 skills 层和回退路径

**Symptom（症状）**：Round 1 R3 指出 skills 层 transition jq 和回退路径可能遗漏。DESIGN.md §5 风险 R4 新增了缓解措施——"实施前 grep 扫描所有 transition jq 写入点"——但扫描被推迟到实现阶段，设计阶段未产出扫描结果。§3.4 的修改清单仍仅覆盖 prompts + GO.md + 31-auto-advance.sh。

**Source（源头）**：ADR-004 记载 pipeline 逻辑分散在 "GO.md + 7 个 prompt + 2 个 skill + 3 个 hook 模块"。DESIGN.md 当前覆盖了 7 个 prompt（§3.4 表列 5 个但描述说覆盖 1/2/3/5/6）+ GO.md + 1 个 hook 模块（31-auto-advance.sh）= 最多 7 处。但 2 个 skill（`flow/SKILL.md` 的 `generate_gates()` 等）和剩余 hook 模块（如 `26-workflow.sh:88` 也写 `.phase`——已在 N1 中发现）未被评估。

**Consequence（后果）**：与 Round 1 R3 相同。遗漏路径上的 transition 不同步 `.phase` → AC-4 部分路径失败。

**Remedy（修补）**：与 Round 1 R3 相同。在 DESIGN.md 中执行 grep 扫描并将结果补充到 §3.4。特别关注 `26-workflow.sh:88`（本轮新发现——它已写 `.phase` 为 string，但走的是单阶段模式路径，与 pipeline transition 是不同代码路径，需评估是否需要同步修改）。

---

### 🟢 R5-RESOLVED · verdict 解析契约：gate 已使用文件级 grep + tail -1（无需修补）

**Symptom（症状）**：Round 1 R5 担心 gate 的 verdict 解析器可能硬编码 `## L3 盲审` 作为 section 锚点。代码审查确认：`independent-review-gate.sh:341` 使用 `grep -iE 'verdict[^a-z]*[:：]' "$review_md" | tail -1`——文件级 grep（无 section 锚定）取最后匹配行。`## L3 重审` 段内的 verdict 会被正确读取。

**Source（源头）**：`independent-review-gate.sh:341`。Code evidence confirms file-level grep, not section-anchored.

**Consequence（后果）**：无。R5 为假阳性——既有代码已兼容追加写入的重审 verdict。

**Remedy（修补）**：建议在 DESIGN.md §1 D3 中追加代码引用（`independent-review-gate.sh:341`）以闭合此契约验证。当前 DESIGN.md 仅描述了策略（"grep verdict 取最后匹配"）但未引用实际代码路径。

---

### 🟢 R7/R8/R9-RESIDUAL · Round 1 的 3 项 🟢 Minor 仍未处理

Round 1 的 R7（stat 跨平台兼容）、R8（文件增长预警）、R9（遗留 fail .done 兼容）在 DESIGN.md 中仍未处理。严重度均为 🟢 Minor，可在实现阶段解决，不阻塞设计通过。

- **R7**：§3.1 伪代码仍用裸 `stat -c %Y`；§5 R1 风险已提及跨平台但伪代码未落地
- **R8**：追加写入前无文件大小检查；§5 R3 推迟到 v2
- **R9**：`.done` 写入策略改为"仅 pass"后，存量 `L3_verdict=fail` 的 .done 文件处理策略未讨论

---

**Verdict**: pass

> Round 1 🔴 R1 已修复（`.phase` 与 `.goal.current_phase` 类型统一为 string）。未发现新的 🔴 Critical 问题。3 项新 🟡 Major 问题（N1：类型分析注释与代码证据矛盾；N2：§3.3/§3.4 内部类型不一致；N3：AC-4 与 DESIGN 类型决策矛盾）需在进入实现前修正。Round 1 剩余 2 项 🟡 Major（R2 TOCTOU、R3 修改面扫描）建议在实现阶段一并处理。3 项 🟢 Minor（R7/R8/R9）不阻塞。
