# 独立审查 · 阶段 5

## L2 盲审

### 综述

审查了 `REQUIREMENT.md`（8 条 AC）、`TEST.md`（测试矩阵）、`test/test_l2_l3_granular_gate.bats`（12 个测试用例）、`done-validation.sh`（核心库）、`29-independent-review.sh`（L3 hook）、`independent-review-gate.sh`（gate 拦截）、`SKILL.md`（flow skill 预设）。运行了目标测试文件（12/12 通过）和全量测试套件（321/321 通过）。

### 详细发现

---

- **Verdict**: fail
- **Severity**: Critical
- **Finding**: AC-5 规定的 `--l2-only` 和 `--l3-only` 命令行标志在 flow skill 中完全不存在。对整个代码库（排除 `.specs/` 文档目录）搜索 `l2-only`、`l3-only`、`--l2-only`、`--l3-only` 均无匹配。`REQUIREMENT.md` 将此功能归类为 "v1 本次必做"（第 81 行），但实现缺失。`CHANGELOG.md` 第 4 行声称 "flow skill --l2-only/--l3-only" 已交付，构成具误导性的文档。
- **Recommendation**: 在 `SKILL.md` 中添加 `--l2-only` 和 `--l3-only` 标志的解析逻辑。更新 `/flow goal` 用法说明，在两个标志任一存在时覆盖 gate_config 值（`--l2-only` -> `"L2"`，`--l3-only` -> `"L3"`）。添加 bats 测试验证：`--l2-only` 结果是 `gate_config["6-review"] = "L2"`，`--l3-only` 结果是 `"L3"`。修正 CHANGELOG 或添加 TODO 标记以反映真实状态。

---

- **Verdict**: fail
- **Severity**: Major
- **Finding**: AC-4 要求 flow skill 在解析 `review` 预设时写入 `gate_config["6-review"] = "both"`（而非 `"independent"`）。`SKILL.md` 第 139-155 行的预设定义仍将全部值设为 `"independent"` -- 例如，`review -> {"6-review":"independent"}`。虽然后向兼容的映射（`done-validation.sh` 将 `"independent"` 视为 `"both"`）在功能上掩盖了此问题，但明确的合同要求是*写入* `"both"`。TEST.md 声称 AC-4 验证状态为 "verified (doc)"，但文档本身仍显示旧值。
- **Recommendation**: 将 `SKILL.md` 第 139-155 行的预设定义为 `"both"`：`review -> {"6-review":"both"}`，`full -> {"1-requirement":"both","2-design":"both","6-review":"both"}`，其他同理。确保所有 9 个及以上预设同步更新。为 AC-4 添加 bats 测试，或者更新 gate-config 预设测试（测试 #92-123）以断言 `"both"` 而非带映射的 `"independent"`。

---

- **Verdict**: fail
- **Severity**: Major
- **Finding**: AC-6 规定当 `gate_config["6-review"] = "L2"` 时，29 号 hook 必须跳过外部模型调用，并且不写入 L3 段。29 号 hook 包含正确的门控逻辑（第 33 行：`fk_independent_review_gate_active "$phase" "L3"`），但仅通过 `bash -n` 进行语法验证。不存在行为级 bats 测试来验证：(a) hook 在 L3 关闭时跳过，(b) hook 在 L3 或 both 开启时运行，(c) 跳过时发出正确的日志消息（"L3 skipped (gate_config L3 not active for phase N)"），(d) 跳过时 INDEPENDENT-REVIEW-N.md 中没有写入 L3 段。
- **Recommendation**: 添加 bats 测试，通过设置 `.flow-active` 为 `gate_config = "L2"` 并验证 29 号 hook 退出 0 且不写入 L3 产物来模拟 29 号 hook 执行。添加另一个测试，使用 `gate_config = "L3"` 来验证 hook 继续执行（在模拟环境中）。至少，添加一个测试验证当 `fk_independent_review_gate_active "6" "L3"` 返回 1 时 hook 退出码为 0。

---

- **Verdict**: pass
- **Severity**: Minor
- **Finding**: AC-1（L2-only）、AC-2（L3-only）、AC-3（both/向后兼容）、AC-7（done skipped 值域）、AC-8（全量回归）的测试覆盖充分。12 个 bats 测试验证了三种模式的值映射、L2/L3 激活与失活、边界情况（缺失 gate_config、无效阶段、无效值）以及 L2_verdict/L3_verdict 的 skipped 值。全量套件 321 个测试全部通过，确认无回归。
- **Recommendation**: 无需操作。这些 AC 已正确覆盖。

---

- **Verdict**: pass
- **Severity**: Minor
- **Finding**: 测试文件存在路径健壮性问题：每个测试通过 `source "$DONE_VALIDATION_LIB" 2>/dev/null || true` 加载库。若库路径错误或文件缺失，source 静默失败（stderr 被抑制，`|| true` 吞掉退出码）。后续对 `fk_independent_review_gate_active` 或 `fk_validate_done_marker` 的 `run` 调用将失败，并显示 "command not found" 错误（`$status` 变为 127，看起来像是 gate 失活），而非显式测试失败。实际上，库路径正确，此问题无影响，但防御性较弱。
- **Recommendation**: 移除 `2>/dev/null` 抑制，改为 `source "$DONE_VALIDATION_LIB"`，不加 `|| true`。若文件缺失，bats 将报出清晰的预检失败而非静默通过。

---

### 测试执行结果

```
# 目标测试文件
npx bats test/test_l2_l3_granular_gate.bats
1..12
ok 1 gate_val 'independent' maps to both (backward compat)
ok 2 gate_val 'true' maps to both (backward compat)
ok 3 gate_val 'invalid' maps to empty (gate off)
ok 4 L2-only: L2 active, L3 not
ok 5 L2-only: any tier (tier='') is active
ok 6 L3-only: L3 active, L2 not
ok 7 L3-only: any tier (tier='') is active
ok 8 both: L2 and L3 both active
ok 9 no gate_config: all tiers return 1
ok 10 invalid phase returns 1
ok 11 L2_verdict=skipped is accepted (L3-only mode)
ok 12 L3_verdict=skipped is accepted (L2-only mode)

# 全量回归
npx bats test/
1..321 -- 全部通过，0 失败
```

### 覆盖矩阵（逐 AC）

| AC | 描述 | 覆盖率 | 状态 |
|----|------|--------|------|
| AC-1 | L2-only 模式 | bats（测试 #204-205）| 已覆盖 |
| AC-2 | L3-only 模式 | bats（测试 #206-207）| 已覆盖 |
| AC-3 | both/independent/true 向后兼容 | bats（测试 #201-202, #208）| 已覆盖 |
| AC-4 | flow skill 预设默认 both | SKILL.md 仍写入 "independent"，非 "both" | 未实现 |
| AC-5 | --l2-only / --l3-only 标志 | SKILL.md 中不存在标志 | 未实现 |
| AC-6 | 29 号 hook L3 跳过 | 仅 bash -n；无行为测试 | 测试缺口 |
| AC-7 | gate done skipped 值域 | bats（测试 #211-212）| 已覆盖 |
| AC-8 | 全量无回归 | 321/321 测试通过 | 已覆盖 |

### 实现状态（代码 vs 需求）

| 组件 | 需求 | 状态 |
|------|------|------|
| `fk_independent_review_gate_active` 三级参数 | AC-1, AC-2, AC-3 | 已实现，已测试 |
| `done-validation.sh` skipped 值域 | AC-7 | 已实现，已测试 |
| `29-independent-review.sh` L3 门控 | AC-6 | 已实现（代码正确），未测试 |
| `independent-review-gate.sh` done 检查 | AC-7 | 已实现 |
| flow skill 预设（review -> both） | AC-4 | 仍写入 "independent" |
| flow skill --l2-only/--l3-only 标志 | AC-5 | 不存在 |

---

L2_verdict=fail

---

## L3 盲审（外部模型 · 2026-07-06）

测试执行状态：`npx bats test/` — 321 tests, 0 failures（全绿通过）

### 审查结论

```json
{"verdict":"fail","summary":"AC-1/2/3/7/8 覆盖且通过；AC-4 预设映射已更新但测试辅助函数未同步；AC-5 和 AC-6 缺少自动化行为测试；严重问题是所有 6 个阶段 prompt 的「写 done」段在 L2-only/L3-only 场景下指令错误——仍要求 L2+L3 两段都出现才写 done，与 AC-7 的分层判定矛盾，会导致 L2-only 模式下主 agent 无限等待 L3。非功能性需求的性能可观测性未验证。SKILL.md /flow gate-config 文档未更新 L2/L3/both 三值。"}
```

### 发现

- **严重度**: Major
- **发现**: 所有 6 个阶段 prompt（1-requirement.md、2-design.md、3-task.md、5-test.md、6-review.md、7-integration.md）的「写 done」段仍写"确认 INDEPENDENT-REVIEW-N.md 同时含 L2 段 + L3 段后执行"。在 L2-only 模式下，L3 不会被写入（29 号 hook 跳过），AI 按此指令将永远等待 L3 段出现导致无限阻塞。此问题直接影响 AC-7（gate 拦截按 tier 判定 done）的运行时正确性——代码层的 fk_validate_done_marker 已接受 skipped 值域，但 prompt 层未通知主 agent 这一变化。
- **建议**: 将 6 个 prompt 的「写 done」段改为条件说明，如：「确认 INDEPENDENT-REVIEW-N.md 含 L2 段（L2-only 模式不要求 L3）或同时含 L2+L3（both/L3 模式）后执行。」具体措辞需根据 gate_config 值动态判断，或在段落中注明：「L2-only 模式：只需 L2 段即可 touch done；L3-only 模式：只需 L3 段；both 模式：需两段。」

---

- **严重度**: Major
- **发现**: AC-5（--l2-only/--l3-only flag）仅有 SKILL.md 中的文档化注释（第 162-165 行、第 174-176 行），没有任何自动化测试验证这两个 flag 实际生效。test_gate_config_presets.bats 中搜索 l2-only、l3-only 无匹配。该行为的正确执行完全依赖 AI 正确解读 SKILL.md 注释——这是通过 prompt 工程而非代码保证的，无法在 CI 中验证。REQUIREMENT.md 将此归类为 v1 必做（第 81 行），但验收手段仅为文档审阅（TEST.md 标注 "✅ (文档)"）。
- **建议**: (a) 在 test_gate_config_presets.bats 中新增测试，模拟 --l2-only 和 --l3-only 的覆写逻辑：解析预设 -> 调用覆写 -> 断言 gate_config 值变为 "L2"/"L3"。(b) 考虑将 flag 解析逻辑从 prompt 注释移至可测试的 shell 函数，或至少提供可引用的伪代码。

---

- **严重度**: Major
- **发现**: 非功能性需求「可观测性：29 号 hook 日志注明 L3 skipped 或 L3 running」部分实现。29-independent-review.sh 第 34 行在 L3 跳过时输出日志，但「L3 running」分支无对应日志。此外，L2-only 模式下 29 号 hook 静默 exit 0，主 agent 无法从日志感知为何无 L3 段产生。无测试验证日志输出。非功能性需求「性能：L2-only 模式不应触发外部 API 调用」在代码层面正确实现但无自动化回归保护。
- **建议**: (a) 在 29 号 hook exit 0 之前增加日志，注明 L2-only 模式已识别。(b) 新增 bats 测试模拟 L2-only 配置，捕获 hook 输出并断言含 "skipped" 字样。(c) 在 SKILL.md 中补充说明：L2-only 模式下 29 号 hook 静默跳过是预期行为。

---

- **严重度**: Minor
- **发现**: /flow gate-config 子命令的文档（SKILL.md 第 223 行）未更新以包含新值 L2/L3/both。当前仅列出旧值 independent/true/off/false。用户无法通过 /flow gate-config 6-review=L2 设定细粒度开关——这是 v1 范围的需求。
- **建议**: 更新 SKILL.md 第 223 行的合法值列表为：「independent（或 true）= 开启两阶段独立 review（等同 both）；L2 = 仅子 agent 盲审；L3 = 仅外部模型盲审；both = 两层都开；off（或 false）= 关闭」。同时更新后续的 jq 示例以反映三值支持。

---

- **严重度**: Minor
- **发现**: test_gate_config_presets.bats 的 resolve_gate_config 测试辅助函数（第 42-48 行）预设值仍使用 "independent" 而非 "both"。例如 full -> {"1-requirement":"independent",...}。虽因 done-validation.sh 的向后兼容映射在功能上无差异，但测试数据与 SKILL.md 文档（SKILL.md 第 138-155 行已统一为 "both"）不一致。CHANGELOG.md 标注 AC-4 为 "flow skill 预设默认 both" 但测试仍断言旧值。
- **建议**: 更新 resolve_gate_config 测试辅助函数，将所有预设的返回值从 "independent" 改为 "both"，以与 SKILL.md 文档保持一致。同时更新断言，确认 json value 为 "both"。

---

- **严重度**: Minor
- **发现**: AC-6（29 号 hook L3 跳过）仅通过 bash -n 语法验证，无行为级 bats 测试。具体缺失：(a) hook 在 L3 关闭时是否正确跳过 (b) hook 在 L3 或 both 开启时是否继续 (c) 跳过时日志消息是否正确。虽然代码审查确认 29 号 hook 第 33-36 行的门控逻辑正确，但缺少回归保护。
- **建议**: 新增 bats 测试：设置 .flow-active 的 gate_config["6-review"]="L2"，source 29-independent-review.sh 的 gate 段，验证 exit 0 且 stderr 含 "skipped"。

---

- **严重度**: Informational
- **发现**: 正向：AC-1（L2-only）、AC-2（L3-only）、AC-3（both/向后兼容）、AC-7（done skipped 值域）、AC-8（全量回归）均覆盖充分。12 个新增 bats 测试 + test_gate_config_presets.bats 的组合验证了三种模式的值映射、fk_independent_review_gate_active 的三 tier 判定、边界情况（缺失 gate_config、无效阶段、无效值）以及 done marker 的 skipped 值域验收。全量 321 测试无回归。核心库 done-validation.sh 实现正确：L2/L3/both 三值解析清晰，backward compat 映射完备。29-independent-review.sh 的 L3 gate 检查（第 33-36 行）逻辑正确。independent-review-gate.sh 的 done 判定适配了 skipped 值域。6 个 prompt 的 L2 检测条件已更新为 {L2,both}。
- **建议**: 无需操作，继续保持。

---

L3_verdict=fail
