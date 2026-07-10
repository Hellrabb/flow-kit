# 独立审查 · 阶段 1

## L2 盲审

### 🔴 R1 · AC-4 验证准则自相矛盾：可机器验证性缺失

**Symptom（症状）**：REQUIREMENT.md:42-44，AC-4 的 Then 子句
```
`grep -c '^| 日期 | Change ID | 摘要 | LESSONS |$' .specs/CHANGELOG.md` 返回 1（仅保留顶部那一行作为分隔标识，或全部统一为同一种格式）
```
"返回 1" 与该句括号内 "或全部统一为同一种格式" 互斥——当选择"全部统一为紧凑单行 pipe 格式"时，该独立表头行不再存在，grep 必然返回 0。若 grep 返回 0，审查者无法判断这是"通过（选择了第二方案）"还是"失败（格式未统一）"——因为 AC 未为第二方案提供独立可验证谓词。

**Source（源头）**：本项目 REQUIREMENT.md:113 自定规则 "AC 是 TEST 阶段派生用例的唯一来源"；Gherkin Given/When/Then 规范要求 Then 子句为单一、可判定的布尔谓词。此处 Then 子句同时描述两个互斥结果却共用一个 grep 表达式，违反了可验证性。

**Consequence（后果）**：TEST 阶段无法为 AC-4 编写确定性的 pass/fail 断言。若实现者选择"全部统一"方案，grep 返回 0 将被误判为 AC-4 失败，导致无效回退或人工争议。该 AC 实际上不可自动验收。

**Remedy（修补）**：将 AC-4 拆为两个互斥子 AC，各自携带独立验证谓词：

```markdown
### AC-4a · BW02 — CHANGELOG.md 格式统一（保留分隔行）
- **Given** .specs/CHANGELOG.md 当前混存两种格式
- **When** 将下部标准表头格式条目改写为紧凑单行 pipe 格式，保留顶部格式标识行
- **Then** 全文件仅有一条独立表头行，其余条目均为紧凑单行 pipe 格式
- **验证方式**:
  `grep -c '^| 日期 | Change ID | 摘要 | LESSONS |$' .specs/CHANGELOG.md` 返回 1
  AND `grep -c '^| 202[0-9]' .specs/CHANGELOG.md` 前后一致

### AC-4b · BW02 — CHANGELOG.md 格式统一（消除分隔行）
- **Given** .specs/CHANGELOG.md 当前混存两种格式
- **When** 将所有条目（含原标准表头格式）统一为紧凑单行 pipe 格式，且不保留任何独立表头行
- **Then** 全文件无独立表头行，所有条目均为紧凑单行 pipe 格式
- **验证方式**:
  `grep -c '^| 日期 | Change ID | 摘要 | LESSONS |$' .specs/CHANGELOG.md` 返回 0
  AND 所有以 `| 202` 开头的行均符合紧凑单行 pipe 格式（正则：`^\| 202[0-9].*\| .*\| .*\| .*\|$`）
```

---

### 🟡 R2 · CHANGE.md 验收线 AC 编号错误：将 AC-2 误标为 AC-6

**Symptom（症状）**：CHANGE.md:41
```
- AC-6 resume banner 测试调用真实 sourceable 函数（非 jq 模拟）
```
在 REQUIREMENT.md 中，AC-6 属于 BW03（双源测试同步，REQUIREMENT.md:53-58）；banner 函数测试调用真实函数是 **AC-2**（BW01，REQUIREMENT.md:25-30）。

**Source（源头）**：单一事实来源原则——CHANGE.md 的验收线应精确引用 REQUIREMENT.md 的 AC 编号，否则下游 DEV/TEST/REVIEW 阶段将以错误编号追踪实现和测试。

**Consequence（后果）**：DEV 阶段若以 CHANGE.md 的验收线为 checklist，可能将 BW03 的同步机制误当作 banner 测试来验证，造成验收遗漏或重复工作。REVIEW 阶段对照 AC 编号做合规检查时产生混淆。

**Remedy（修补）**：CHANGE.md:41 修改为：
```
- AC-2 resume banner 测试调用真实 sourceable 函数（非 jq 模拟）
```

---

### 🟡 R3 · AC-6 When 子句包含未决设计选择，违反单一验收谓词

**Symptom（症状）**：REQUIREMENT.md:57
```
- **When** 实现自动同步机制（Makefile target `make test-sync` 或 `flow-kit-bundle/install.sh` 符号链接方案）
```
"When" 子句内嵌了两个互斥的实现方案（"或"），但未明确哪个方案是本 AC 的验收目标。若实现者选择方案 A 而测试者按方案 B 验收，则 AC 无法闭合。

**Source（源头）**：AC 的 When 应描述**单一可执行的前置动作**，而非枚举未收敛的设计选项。设计决策应在 DESIGN 阶段由 ADR 锁定，而非作为 AC 歧义来源。另见项目假设段（REQUIREMENT.md:108）"BW03 优先 Makefile target 方案"——该假设已暗示了选择，但 AC 正文未体现此优先级。

**Consequence（后果）**：TEST 阶段不知道应该用 `make test-sync` 还是 `install.sh --symlink` 来触发 When 动作，测试脚本需覆盖两条路径，增加了无谓的测试矩阵和假阳性风险。

**Remedy（修补）**：在 REQUIREMENT.md 假设段已声明"优先 Makefile target"的前提下，将 AC-6 的 When 子句固化为：
```markdown
- **When** 实现 Makefile target `make test-sync` 并在 `make check` 中集成调用
```
若后续 DESIGN 阶段决定用 install.sh symlink 方案，则应在该阶段更新 AC-6 的 When 子句（通过 CHANGE 流程），而非在 AC 中保留未决议的"或"。

---

### 🟢 R4 · AC-1 验证命令使用未定义占位符

**Symptom（症状）**：REQUIREMENT.md:22
```
- **验证方式**: `diff <(before.sh) <(after.sh)` 或 bats 测试对比 stdout
```
`before.sh` 和 `after.sh` 不是项目中存在的文件/脚本名，是占位符。验证命令本身无法直接执行。

**Source（源头）**：AC 验证方式应引用项目中实际可执行的命令或明确如何构造比较对象。

**Consequence（后果）**：轻微——TEST 阶段需自行推导命令含义，不会导致验收失败但增加了理解摩擦。实际影响小，因为 bats 测试方式已作为备选验证列在同一行。

**Remedy（修补）**：将验证方式改为具体可执行命令：
```markdown
- **验证方式**: 运行重构前的 `flow-kit-resume.sh` 与重构后的版本（均传入相同模拟输入），`diff` 比较二者 stdout；或通过 bats 测试对比
```
或直接删除前半段 `diff <(before.sh)...`，仅保留 bats 验证（因 AC-2/AC-3 已覆盖 bats 路径）。

---

### 🟢 R5 · 缺少错误处理非功能性需求

**Symptom（症状）**：REQUIREMENT.md:90-96 非功能性需求段对所有类别除性能/兼容性外标注"无"。但此次变更引入三个新的故障面：
- BW01：lib 文件缺失或 source 失败时，`flow-kit-resume.sh` 行为未定义
- BW03：同步失败（权限、磁盘满、符号链接冲突）时的回退策略未定义
- BW03：`make check` 检测到不同步后的用户指导信息未定义

**Source（源头）**：非功能性需求应覆盖健壮性（robustness）——系统在异常输入/环境下的降级行为。当前 NFR 段未考虑新引入组件的故障模式。

**Consequence（后果）**：低风险——BW01 的 lib 缺失会在 shell source 阶段直接报错退出（bash 默认行为），不会静默损坏数据；BW03 同步失败在 Makefile target 中自然以非零退出码传播。但这些行为是"碰巧正确"而非"显式设计"的，缺少文档化契约。

**Remedy（修补）**：在非功能性需求段补充一条健壮性条目：
```markdown
- **健壮性**: BW01 lib 文件缺失时 `flow-kit-resume.sh` 应以非零退出码 + 可读错误信息终止；
  BW03 同步失败时 `make test-sync` 应以非零退出码终止，不静默覆盖目标文件；
  `make check` 检测不同步时应在 stderr 提示用户运行 `make test-sync`
```
或标注 "无新增健壮性要求——依赖 bash errexit / Makefile 默认错误传播" 以表明已评估且接受现有行为。

---

**Verdict**: fail

---

## 主 agent 响应

### R1 · AC-4 验证准则自相矛盾 → Fixed in: REQUIREMENT.md AC-4
- **行动**：将 AC-4 Then 子句固化为"消除独立表头行"方案（`grep -c` 返回 0），移除括号内的"或"分支歧义。验证方式拆为两条独立可判定命令。
- **变更**：REQUIREMENT.md L38-44

### R2 · CHANGE.md AC 编号错误 → Fixed in: CHANGE.md L41
- **行动**：`AC-6` → `AC-2`
- **变更**：CHANGE.md L41

### R3 · AC-6 When 未决设计选择 → Fixed in: REQUIREMENT.md AC-6
- **行动**：When 子句固化为 `make test-sync` 单一方案，与假设段"优先 Makefile target"对齐
- **变更**：REQUIREMENT.md L57

### R4 · AC-1 验证占位符 → Fixed in: REQUIREMENT.md AC-1
- **行动**：`diff <(before.sh) <(after.sh)` → 明确描述为运行重构前后脚本对比 stdout
- **变更**：REQUIREMENT.md L22

### R5 · 缺失健壮性 NFR → Fixed in: REQUIREMENT.md 非功能性需求
- **行动**：新增「健壮性」条目，覆盖 BW01 lib 缺失、BW03 同步失败、`make check` 不同步提示三种故障面
- **变更**：REQUIREMENT.md L91-94

**修正后自评**：全部 🔴🟡🟢 发现均已修复，AC-4 歧义已消除，所有 AC 现在可机器验证。请求 L2 重审确认。

---

## L2 重审

### 上一轮 5 项修复独立验证

逐条核实 REQUIREMENT.md 和 CHANGE.md 当前内容（文件快照 @ 2026-07-10）。

#### R1 · AC-4 Then 子句歧义 → ✅ 已修复

- **AC-4 Then**（REQUIREMENT.md L43）：`grep -c '^| 日期 | Change ID | 摘要 | LESSONS |$' .specs/CHANGELOG.md` 返回 0。单一可判定谓词，无"或"分支，无括号内备选方案。
- **验证方式**（L44）：两条独立命令——(a) 表头行计数为 0，(b) 条目行计数前后一致。二者均可独立判定 pass/fail。
- **结论**：AC-4 现在可机器验证，歧义已消除。

#### R2 · CHANGE.md AC 编号错误 → ✅ 已修复

- **CHANGE.md L40**：`AC-2 resume banner 测试调用真实 sourceable 函数（非 jq 模拟）`。编号正确，与 REQUIREMENT.md AC-2（BW01 bats 测试）一致。
- **结论**：AC 编号错误已修正。

#### R3 · AC-6 When 子句未决设计选择 → ✅ 已修复

- **AC-6 When**（REQUIREMENT.md L56）：`实现 Makefile target make test-sync 并在 make check 中集成调用`。单一方案，无"或 install.sh"。
- **结论**：When 子句已固化为单一可执行动作。

#### R4 · AC-1 验证方式占位符 → ✅ 已修复

- **AC-1 验证方式**（REQUIREMENT.md L23）：`运行重构前的 flow-kit-resume.sh 与重构后版本（传入相同 .flow-active 模拟数据），diff 比较二者 stdout；或通过 bats 测试对比`。无 `before.sh`/`after.sh` 占位符，引用真实脚本名，动作描述具体可执行。
- **结论**：验证方式现在是可执行的（虽非一行命令，但操作步骤明确）。

#### R5 · 缺失健壮性非功能性需求 → ✅ 已修复

- **非功能性需求段**（REQUIREMENT.md L97）：`健壮性: BW01 lib 文件缺失时 flow-kit-resume.sh 应以非零退出码 + 可读错误信息终止；BW03 同步失败时 make test-sync 应以非零退出码终止、不静默覆盖目标文件；make check 检测不同步时应在 stderr 提示用户运行 make test-sync`。
- **结论**：三种故障面均已文档化，健壮性契约明确。

---

### 新发现问题（本轮独立盲审）

以下问题为上一轮审查和后续修复中均未覆盖的新发现。

---

#### 🟡 N1 · CHANGE.md 验收线未随 AC 修复同步更新：目标名错误 + 仍保留已排除备选方案

**Symptom（症状）**：CHANGE.md L42
```
- `make test` 或 `install.sh` 自动处理双源测试同步
```
该行存在两处与 REQUIREMENT.md 的冲突：
1. 目标名错误：写作 `make test`，但 AC-6 固化为 `make test-sync`（同步目标），AC-7 固化为 `make check`（检测目标）。`make test` 在项目中通常指运行测试套件，而非同步测试文件。
2. 仍保留 `install.sh` 备选方案：上一轮 R3 已将 AC-6 的 When 子句固化为单一 `make test-sync` 方案，CHANGE.md 验收线未同步删除 `install.sh` 引用。

**Source（源头）**：上一轮修复仅更新了 REQUIREMENT.md 的 AC-6 正文（R3）和 CHANGE.md 的 AC 编号（R2），遗漏了 CHANGE.md 验收线第3条的内容更新。属部分修复——修复了编号错但保留了内容错。

**Consequence（后果）**：REVIEW/INTEGRATION 阶段对照 CHANGE.md 验收线做 gate 检查时，可能：
- 错误地验收 `make test` 行为（而实际需要的是 `make test-sync` 和 `make check`）
- 允许实现者采用 install.sh symlink 方案（该方案已在 AC 层面被排除）
- 验收线与 AC 之间的不一致导致下游争议

**Remedy（修补）**：CHANGE.md L42 修改为：
```
- `make test-sync` 自动同步双源测试文件；`make check` 检测不同步并以非零退出
```
或拆为两条以匹配 AC-6 和 AC-7：
```
- `make test-sync` 同步 test/ → flow-kit-bundle/test/
- `make check` 检测双源测试不同步并以非零退出
```

---

#### 🟡 N2 · REQUIREMENT.md 范围描述与假设段仍保留已排除备选方案，与 AC-6 矛盾

**Symptom（症状）**：
- **v1 范围描述**（REQUIREMENT.md L75）：`BW03：test/ ↔ flow-kit-bundle/test/ 自动同步机制（Makefile target 或 install.sh symlink）`
- **假设段**（REQUIREMENT.md L109）：`BW03 优先 Makefile target 方案（make test-sync），备选 install.sh symlink`

两处均保留了 install.sh symlink 作为备选/并列选项，但 AC-6 When 子句（L56）已固化为唯一方案 `make test-sync`。若实现者按范围描述或假设段的"备选"指示实施了 install.sh symlink，则 AC-6 必然失败（`make test-sync` 不存在）。

**Source（源头）**：与 N1 同源——R3 修复了 AC 正文但未级联更新同一文件内的范围描述段和假设段。同一文件内出现自相矛盾：AC 说"只做 make test-sync"，v1 范围和假设说"可以做 install.sh symlink"。

**Consequence（后果）**：
- 实现者在范围描述段读到"或 install.sh symlink"，可能选择该方案实施，导致 AC 验证失败
- 单一文件内的自相矛盾降低了 REQUIREMENT.md 作为单一事实来源的权威性
- 若 REVIEW 阶段不同评审人阅读不同段落，可能对同一 change 的合法实现方案产生分歧

**Remedy（修补）**：
- L75 改为：`BW03：test/ ↔ flow-kit-bundle/test/ 自动同步机制（Makefile target make test-sync + make check 集成）`
- L109 改为：`BW03 采用 Makefile target 方案（make test-sync），通过 make check 集成检测；不引入新依赖工具`

---

#### 🟢 N3 · AC-7 Then 子句括号内"或"引入轻微双选项歧义

**Symptom（症状）**：AC-7 Then（REQUIREMENT.md L64）
```
- **Then** `make check`（或 `make test-sync-check`）检测到差异并以非零退出码报错
```
括号内 `或 make test-sync-check` 为 Then 子句引入了两个可判定目标（`make check` 或 `make test-sync-check`）。虽然在当前上下文中两者等价（都是检测同步状态），但 Then 子句应为单一可判定谓词。

**Source（源头）**：`make test-sync-check` 可能是一个尚未定义的备选 target 名称，在 Then 子句中作为"等价替代"出现但未被 AC-6 或 v1 范围描述引用。

**Consequence（后果）**：极轻微——验证方式（L65）仅测试 `make check` 路径，不会导致验收歧义。但若后续有人新增 `make test-sync-check` target 而行为与 `make check` 不同，则该 Then 子句将不可判定。

**Remedy（修补）**：删除括号内容，固化为：
```
- **Then** `make check` 检测到差异并以非零退出码报错
```
或将 `make test-sync-check` 明确为 `make check` 的内部依赖（而非并列选项）。

---

#### 🟢 N4 · CHANGE.md 验收线遗漏 AC-1 引用

**Symptom（症状）**：CHANGE.md 验收线（L38-43）共 4 条：
1. AC-2 resume banner 测试调用真实 sourceable 函数
2. CHANGELOG.md 全文件统一格式
3. `make test` 或 `install.sh` 自动处理双源测试同步
4. 全量 bats 不退化

其中 BW01 的核心交付件——**AC-1（抽取 banner 生成函数为独立 sourceable 函数）**——未出现。验收线覆盖了 AC-2（测试该函数）和 AC-3（全量回归），但遗漏了 AC-1（函数本身的存在）。

**Source（源头）**：验收线为高层摘要，非 AC 的 1:1 映射，但 AC-1 作为 BW01 的唯一产出物（AC-2 和 AC-3 分别是该产出物的测试和回归验证），应在验收线中有对应条目。

**Consequence（后果）**：轻微——由于 AC-2 依赖 AC-1（Given 子句要求 "AC-1 的 sourceable 函数已就位"），验收 AC-2 时自然会验证 AC-1。但 REVIEW 阶段若仅按验收线逐条打勾，可能遗漏对 AC-1 产物的直接审查（如 lib 文件位置、source 路径、函数签名等）。

**Remedy（修补）**：在 CHANGE.md 验收线中补充：
```
- AC-1 banner 生成逻辑抽取为独立 sourceable 函数，SessionStart 输出逐字符不变
```

---

### 重审 Verdict

上一轮 5 项发现（R1-R5）**全部有效修复**。AC-4 歧义消除、AC 编号修正、AC-6 When 固化、AC-1 验证方式具体化、健壮性 NFR 补全——均可独立验证通过。

本轮新发现 4 项：
- **🟡 N1**（CHANGE.md 验收线未同步）和 **🟡 N2**（REQUIREMENT.md 内部自相矛盾）为同一根因的级联表现——R3 修复了 AC 正文但未级联更新同文件其他段落和 CHANGE.md。这两项构成一致性风险：若下游按非 AC 段落实施，将导致验收失败。
- **🟢 N3**（AC-7 Then 轻微歧义）和 **🟢 N4**（验收线遗漏 AC-1）为文档完整性改进。

**Verdict**: **pass（条件性）**——建议修复 N1 和 N2 后进入 DESIGN 阶段。N3 和 N4 可在后续阶段修复，不阻塞推进。

---

## 主 agent 最终响应（重审后）

### N1 · CHANGE.md 验收线未同步 → Fixed in: CHANGE.md L42
- **行动**：`make test 或 install.sh` → `make test-sync 自动同步双源测试文件；make check 检测不同步并以非零退出`
- **变更**：CHANGE.md L42

### N2 · REQUIREMENT.md 内部不一致 → Fixed in: REQUIREMENT.md L75, L109
- **行动**：v1 范围描述去 `或 install.sh symlink`；假设段去 `备选 install.sh symlink`
- **变更**：REQUIREMENT.md L75, L109

### N3 · AC-7 Then 轻微双选项 → 接受，不阻塞
- **理由**：`(或 make test-sync-check)` 为备选 target 名提示，不影响可验证性。DESIGN 阶段收敛为单一 target 名后此括号自然消失。

### N4 · 验收线遗漏 AC-1 → 接受，不阻塞
- **理由**：AC-1 是 BW01 核心交付件，但 AC-2 的 Given 子句依赖 AC-1 产物已就位，验收 AC-2 时自动覆盖 AC-1。REVIEW 阶段会对照 REQUIREMENT.md 全量 AC 逐条检查，不以 CHANGE.md 验收线为唯一来源。

**修正后 Verdict**: pass — 全部 🔴🟡 发现已修复，可进入 DESIGN 阶段。
