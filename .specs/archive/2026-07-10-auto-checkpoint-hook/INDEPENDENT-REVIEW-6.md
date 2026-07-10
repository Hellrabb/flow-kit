# 独立审查 · 阶段 6

## L2 盲审

- **审查日期**: 2026-07-10
- **Change ID**: `auto-checkpoint-hook`
- **审查工件**: `git diff`（6 个已追踪文件变更 + 3 个新文件）+ `.specs/auto-checkpoint-hook/REVIEW.md`
- **参考文件**: REQUIREMENT.md, TASK.md, DESIGN.md

---

### AC 覆盖逐条复核

以下每条 AC 独立对照代码/测试验证，不采信 REVIEW.md 的结论。

#### AC-1 · Write 前自动 checkpoint

**代码验证**：`auto-checkpoint.sh:66-67` — stdin 读 JSON → jq 解析 `tool_name`；`:70` — `_auto_ck_is_edit_tool` case 匹配 `Write`；`:80` — 提取 `tool_input.file_path`；`:91` — `checkpoint_write "$file_path" "编辑 $file_path" ""`。

**测试验证**：`test_auto_checkpoint.bats:39-52` — pipe Write JSON → bash auto-checkpoint.sh → 断言 `active_file=="src/main.sh"`, `last_action=="编辑 src/main.sh"`, `checkpoint_at` 非空, `failing_check==""`。`:54-58` — 额外验证 `updated_at` 变更。

**结论**：覆盖充分。

#### AC-2 · Edit 前自动 checkpoint

**代码验证**：`:70` — `_auto_ck_is_edit_tool` case 匹配 `Edit`；其余逻辑与 AC-1 共享同一写入路径。

**测试验证**：`test_auto_checkpoint.bats:65-74` — pipe Edit JSON → 断言 `active_file=="src/config.sh"`, `last_action=="编辑 src/config.sh"`。

**结论**：覆盖充分。

#### AC-3 · 无活跃 change 静默跳过

**代码验证**：`:75` — `_auto_ck_active_change ".flow-active"`；若返回 1 → `exit 0`。`_auto_ck_active_change()` 函数（`:23-30`）：检查文件存在 + jq 读取 `change_id`，空/null → 返回 1。

**测试验证**：
- `test_auto_checkpoint.bats:80-87` — 删除 `.flow-active` 后触发 → exit 0 + 文件未被创建。
- `test_auto_checkpoint.bats:89-96` — `change_id=null` 预设已有 interrupt → 触发后 `active_file` 保持 `"old.sh"` 不变。

**结论**：覆盖充分。

#### AC-4 · 非 Write/Edit 工具不触发

**代码验证**：`:70` — `_auto_ck_is_edit_tool` case 仅匹配 `Write|Edit`；其余 → `exit 0`。

**测试验证**：
- `test_auto_checkpoint.bats:102-108` — Read 工具 pipe → `active_file` 保持 `"before.sh"` 不变。
- `test_auto_checkpoint.bats:111-117` — Bash 工具 pipe → 同上。

**结论**：覆盖充分。

#### AC-5 · Fail-open（重点关注）

AC-5 的验证方式要求：
> (a) Write：断言目标文件被创建 (b) Edit：断言目标文件被修改 (c) 两条路径 hook 退出码均为 0（fail-open）

当前测试 `test_auto_checkpoint.bats:123-133`：
```bats
@test "AC-5: corrupt .flow-active JSON → exit 0 (Write path)" {
  echo "not json" > .flow-active
  echo '{"tool_name":"Write","tool_input":{"file_path":"test.sh"}}' | bash ./auto-checkpoint.sh
  [[ "$?" -eq 0 ]]  # fail-open
}
```

**仅验证了 (c)**——退出码为 0。未验证 (a) "目标文件被创建" 和 (b) "目标文件被修改"。AC 的验证意图是端到端：证明 corrupt JSON 不会导致 Write/Edit 操作被阻断。当前测试只验证 hook 自身容错，未验证"阻断未发生"的后果（即文件写入仍然成功）。

**Severity**: 🟡 Major — 测试未达 AC 原文要求的验证精度。hook 外部行为（Write/Edit 是否真的执行成功）未被证实。

**Remedy**: AC-5 Write 路径测试在 hook 执行后 `touch "$TEST_DIR/test.sh"` 并断言文件存在（模拟 Write 工具执行后果）；Edit 路径测试先创建目标文件 → 执行 hook → 再修改文件内容 → 断言内容已变。

#### AC-6 · 恢复精度验证（重点关注）

AC-6 原文：
> When 调用 SessionStart hook `flow-kit-resume.sh` 检测到 `interrupt` 非空，生成 resume banner
> 验证方式: (b) 调用 `flow-kit-resume.sh` 的 resume banner 生成函数，(c) 断言其 stdout 包含三字段值

当前测试 `test_auto_checkpoint.bats:139-157`：
```bats
@test "AC-6: interrupt contains all three fields for resume" {
  echo '{"tool_name":"Write","tool_input":{"file_path":"hooks/checkpoint.sh"}}' | bash ./auto-checkpoint.sh
  active_file=$(jq -r '.interrupt.active_file' .flow-active)
  last_action=$(jq -r '.interrupt.last_action' .flow-active)
  checkpoint_at=$(jq -r '.interrupt.checkpoint_at' .flow-active)
  [[ -n "$active_file" ]]
  [[ -n "$last_action" ]]
  [[ -n "$checkpoint_at" ]]
  [[ "$active_file" == "hooks/checkpoint.sh" ]]
  [[ "$last_action" == *"hooks/checkpoint.sh"* ]]
  [[ "$checkpoint_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}
```

**测试仅验证了 AC-6 的步骤 (a)**——预设 interrupt（通过触发 hook 写入），但**完全未执行 (b) "调用 flow-kit-resume.sh 的 resume banner 生成函数"** 和 **(c) "断言其 stdout 包含三字段值"**。

测试只是用 jq 直接读 `.flow-active` 的 interrupt 字段——这验证的是"写入端正确"，而非 AC-6 真正关心的"恢复端正确"（即 resume 路径能读取并展示这些字段）。

**REVIEW.md 对此判为 `✅`**，描述为 "三字段写入 + bats 验证 ISO8601 格式"——这是误判。AC-6 的核心语义是验证 resume/recovery 链路，而非仅仅验证中断数据写入。

**Severity**: 🔴 Critical — AC-6 覆盖不完整；这是功能完整性问题，不是测试风格问题。若 `flow-kit-resume.sh` 的 resume banner 生成函数存在 bug（如 jq 字段名写错、路径解析错误），当前测试无法发现。

**Remedy**: 测试中 source `flow-kit-resume.sh` 并调用其 resume banner 生成函数，捕获 stdout，断言包含 `active_file`、`last_action`、`checkpoint_at` 三个字段的**实际值**（而非仅非空）。

#### AC-7 · 文档完整性

**验证**：`SKILL.md:236-254` — 新增"自动 checkpoint（PreToolUse hook）"段，包含：触发条件、触发工具、写入字段（四字段含 `failing_check`）、恢复方式、与手动关系、安装说明。覆盖 AC-7 要求的 (a)(b)(c) 三点。

**结论**：覆盖充分。

#### AC-8 · 安装脚本集成

**代码验证**：
- `install_hooks.sh:73-76` — 文件复制（`cp auto-checkpoint.sh` → `pre-tool-use/`）+ `chmod +x`。
- `install_hooks.sh:170-206` — settings.json 的 PreToolUse 数组追加（matcher: `"Write|Edit"`），含去重检测、新建空数组、DRY-RUN 支持。

**结论**：覆盖充分。

#### AC-9 · checkpoint-lib 去重移除

**代码验证**：`checkpoint-lib.sh` — 无 `checkpoint_dedup_check` 函数、无 `CHECKPOINT_DEDUP_WINDOW` 变量、`checkpoint_write()` 体内无 dedup 调用。

**测试验证**：
- `test_auto_checkpoint.bats:163-188` — 连续两次 Write / 两次 Edit 均 exit 0 + `checkpoint_at` 不同。
- `test_checkpoint.bats:62-109` — 三个测试验证无 dedup 行为（同文件两次写入均成功、不同 action type 覆盖、不同文件切换）。

**结论**：覆盖充分。去重代码已彻底删除，无 dead code 残留。

---

### 代码质量 6 维衰退风险评估

#### R1 · 认知过载（Cognitive Overload）

**评估**: 🟢 低风险。`auto-checkpoint.sh` 仅 96 行，函数职责清晰（`_auto_ck_active_change` / `_auto_ck_is_edit_tool` / `_auto_ck_resolve_lib`），主逻辑直线式。

**注意点**: `_auto_ck_resolve_lib()` 三级 fallback 路径（`:47-51`）——安装路径 → 开发目录结构 → 同目录。虽然三级 fallback 本身是防御性设计，但在生产环境中总是命中第一级，后两级的存在增加了阅读时的认知负担。**判断**: 合理防御，不变。

#### R2 · 变更传播（Change Propagation）

**评估**: 🟡 中风险。`install_hooks.sh:170-206`（auto-checkpoint 注册）与 `:132-168`（gate 注册）结构相同——30 行重复逻辑。若 PreToolUse JSON 接线格式未来变更，需修改两处。REVIEW.md 认为"抽函数需要 4+ 参数不如直写清晰"——这是一个有争议的判断。当前两段代码的差异点仅为：matcher 字符串、命令路径、日志前缀。若抽为 `_register_pre_tool_use_hook "$matcher" "$cmd_path" "$log_label"`，三参数即可覆盖。

**影响**: 新增第三个 PreToolUse hook 时，会触发第三次复制粘贴。

**Remedy**: 考虑抽取 `_register_pre_tool_use_hook()` 函数，参数化 matcher + command + label。若不抽，至少在代码块间添加注释说明"与 gate 注册段结构一致，修改时同步更新"。

#### R3 · 知识重复（Knowledge Duplication）

**评估**: 🟡 中风险。两个位置存在文件复制：
1. `test/test_checkpoint.bats` 与 `flow-kit-bundle/test/test_checkpoint.bats` — 内容完全一致，均为 git 追踪文件。git status 显示双源 pattern 已存在（TD-012 路径根治注释说明"双源 test/ 与 flow-kit-bundle/test/ 同一份代码都正确"）。
2. `test/test_auto_checkpoint.bats` 同时出现在 `test/` 和 `flow-kit-bundle/test/`（当前均为 untracked `??`）。

**影响**: 两份 test_checkpoint.bats 已在本次 change 中同时修改（git diff 证实），但 test_auto_checkpoint.bats 的双源未在 git diff 中体现（均为 untracked）。一旦提交，未来维护需同时更新两处。

**Remedy**: 确认双源策略是否为长期设计。若是，需在 TASK.md 或 CONTEXT.md 中明确登记"所有 test/*.bats 需同步更新 `flow-kit-bundle/test/` 对应文件"。或考虑用 Makefile target / symlink 消除复制。

#### R4 · 偶然复杂（Accidental Complexity）

**评估**: 🟢 低风险。`auto-checkpoint.sh` 的 `BASH_SOURCE[0] == "${0}"` 守卫模式、`set -euo pipefail`、三级 lib 路径 fallback——均为项目既有范式，非本次引入的新复杂度。

**注意**: `auto-checkpoint.sh:68` — `INPUT=$(cat)` 读全部 stdin 后再两次 jq 解析（`:67` 解析 tool_name, `:80` 解析 file_path），可优化为单次 jq 解析两个字段。但 stdin JSON 极小（< 500 bytes），性能影响可忽略。

#### R5 · 依赖混乱（Dependency Chaos）

**评估**: 🟢 低风险。
- `auto-checkpoint.sh` → `checkpoint-lib.sh`（source）：已通过三级 fallback 路径解析。
- `checkpoint-lib.sh` → jq：已在 hook 入口处 `command -v jq` 检查。
- `install_hooks.sh` → jq：已在写入逻辑中 `command -v jq` 检查。

依赖方向清晰，无循环依赖。

#### R6 · 领域扭曲（Domain Distortion）

**评估**: 🟢 低风险。域概念使用一致：`interrupt` / `checkpoint` / `change_id` / `phase` / `failing_check` 与 CONTEXT.md 域语言表一致。`checkpoint_write` 函数签名 `(file, desc, failing_check)` 在 PreToolUse 路径和 prompt 层手动路径中语义一致。

---

### REVIEW.md 漏判/误判事项

以下为主 agent REVIEW.md 中遗漏或判断不完全准确的项：

| 项目 | REVIEW.md 判断 | L2 独立判断 | 依据 |
|---|---|---|---|
| AC-6 验证完整性 | ✅ 通过 | 🔴 **未通过** — 测试缺失 resume banner 调用验证 | AC-6 原文明确要求验证 resume 路径输出，当前仅验证写入端 |
| AC-5 验证完整性 | ✅ 通过 | 🟡 **部分通过** — 缺少文件创建/修改断言 | AC-5 原文明确要求 (a) Write 断言目标文件被创建 (b) Edit 断言目标文件被修改 |
| 代码重复 (install_hooks.sh) | "不抽公共函数……不建议重构" | 🟡 **建议重评** — 30 行高度相似代码，未来新增 hook 会继续复制 | 三参数函数可消除重复；若坚持不抽，需添加同步注释 |
| 双源测试文件 | 未提及 | 🟡 **遗漏** — test/ 与 flow-kit-bundle/test/ 双源 pattern 需明确登记 | test_checkpoint.bats 双源已同步修改，test_auto_checkpoint.bats 双源均为 untracked |
| empty file_path 防护 | 未提及 | 🟡 **遗漏** — `auto-checkpoint.sh:91` 未对空 `file_path` 做防护 | stdin 若缺 `tool_input.file_path`，会写入 `active_file: ""`，污染 interrupt |

---

### DESIGN D1-D7 对齐复核

| DESIGN | 代码验证 | 状态 |
|---|---|---|
| D1 (PreToolUse) | `auto-checkpoint.sh` 作为 PreToolUse hook | ✅ |
| D2 (删除 dedup) | `checkpoint-lib.sh` 无 dedup 函数/变量/call | ✅ |
| D3 (全阶段 0~7) | 仅检查 `change_id` 非 null，不限 phase | ✅ |
| D4 (Fail-open) | 所有异常路径 exit 0 | ✅ |
| D5 (failing_check="") | `checkpoint_write "$file" "编辑 $file" ""` | ✅ |
| D6 (matcher Write\|Edit) | `install_hooks.sh:181` matcher `"Write|Edit"` | ✅ |
| D7 (gate 共存) | 两个独立 PreToolUse 条目，不同 matcher，串行执行 | ✅ |

---

### 额外发现

#### F1 · checkpoint-lib.sh DESIGN 注释编号与 DESIGN.md 不一致

`checkpoint-lib.sh:9` 注释写 `# DESIGN D6: 不启用去重`，但 DESIGN.md 中对应决策编号为 **D2**（"移除去重逻辑"）。DESIGN D6 在 DESIGN.md 中是 "matcher 为 `Write|Edit`"。

**Severity**: 🟢 Minor — 注释自洽（lib 内部的 D1-D6 是其自身设计注释体系），但与外部 DESIGN.md 编号冲突会误导后续读者。

**Remedy**: 统一 checkpoint-lib.sh 注释中的 DESIGN 编号到 DESIGN.md 体系，或使用独立编号前缀如 `CP-D1`。

#### F2 · auto-checkpoint.sh 设计注释中的 D-numbering 同样不一致

`auto-checkpoint.sh:10-12` 注释中的 D1/D3/D4/D6 混合了 checkpoint-lib.sh 和 DESIGN.md 两套编号。D1/D3/D4 可能来自 DESIGN.md（PreToolUse/全阶段/Fail-open），但 D6 又来自 lib 内部的"D6: 不去抖"。

**Severity**: 🟢 Minor — 建议统一到 DESIGN.md 体系或使用明确前缀。

---

### Verdict: fail

**理由**：AC-6 的测试覆盖不完整——缺少 resume banner 函数的调用验证，这是功能正确性缺口。AC-5 的测试精度也低于 AC 原文要求。在 AC-6 修复前，不应标记本阶段为"通过"。

**修复优先级**：
1. 🔴 AC-6：补充 `flow-kit-resume.sh` resume banner 函数调用测试（T04 补测）
2. 🟡 AC-5：补充 Write 路径文件创建断言 + Edit 路径文件修改断言（T04 补测）
3. 🟡 双源测试文件策略文档化（CONTEXT.md 或 TASK.md 登记）
4. 🟢 DESIGN 注释编号统一
5. 🟢 `file_path` 空值防护
