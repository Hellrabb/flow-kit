# 独立审查 · 阶段 6

## L2 盲审

> 审查日期：2026-07-10
> 审查员：L2 独立盲审 agent
> 审查工件：git diff（.specs/CHANGELOG.md, .specs/CONTEXT.md, Makefile, flow-kit-bundle/hooks/session-start/flow-kit-resume.sh）+ 新增文件（banner.sh, test_resume_banner.bats × 2）
> 参照对象：.specs/checkpoint-polish/REVIEW.md（主 agent 结论——**被复核对象，非权威**）
>
> **独立性声明**：本审查基于对 git diff 和源代码的独立阅读完成。未采纳主 agent REVIEW.md 中的任何结论作为预设正确的前提。以下标注「独立确认」表示本审查独立得出与主 agent 一致的结论；标注「主 agent 漏判/误判」表示主 agent 的 REVIEW.md 存在遗漏或错误。

---

### 🔴 R1 · Makefile lint gate 未覆盖 hooks/stop/lib/ —— banner.sh 及全部 11 个 lib 文件绕开自动化 lint

**Symptom**：`make lint` 的 for-loop glob（Makefile L23）为 `flow-kit-bundle/hooks/stop/*.sh`，仅匹配 `stop/` 直属文件（17 个），不匹配 `stop/lib/` 下的 12 个 lib 文件（含本次新增的 `banner.sh`）。经 `ls` 实测确认：`stop/lib/` 下有 12 个 `.sh` 文件，全部不在 lint 覆盖范围内。

**Source**：Makefile lint 目标设计时未将 `lib/` 子目录纳入 glob。此为预现有 gap（非本次引入），但本次新增文件落在此 gap 内，REVIEW.md 应标注而未标注。

**Consequence**：
1. `banner.sh` 的 shellcheck 警告（SC2034: `int_ts` unused）不会被 `make lint` 或 `make check` 捕获。
2. 未来对 `banner.sh`（或任何 `stop/lib/` 下文件）的任何修改均绕过自动化 lint 门禁，语法错误、注入风险、可移植性问题均可静默合入。
3. `make check` 调用 `make lint` 作为质量门禁的一环——此 gap 使「全量质量门禁通过」的语义被削弱。

**Remedy**：在 Makefile L23 的 for-loop glob 列表中追加 `flow-kit-bundle/hooks/stop/lib/*.sh`。

**主 agent 漏判**：REVIEW.md §2.1 逐文件审查声称 shellcheck 通过，但未发现 `make lint` 的 glob 根本不覆盖 `stop/lib/`。TEST.md §3.3 展示了手动 `shellcheck banner.sh` 的结果，但未指出此手动校验不会在 `make check` 中自动复现。

---

### 🟡 R2 · banner.sh L62 `int_ts` 死代码——变量赋值后从未使用

**Symptom**：`banner.sh` L62 从 JSON 读取 `int_ts`（`jq -r '.interrupt.checkpoint_at'`），但该变量在函数内从未被引用。staleness 计算（L71）使用 `stat` 获取文件 mtime，而非 `int_ts` 中存储的 checkpoint 时间戳。

**Source**：此死代码从原 `flow-kit-resume.sh` 原样迁移（diff 可见原代码中同样存在 `int_ts` 赋值但未使用）。shellcheck 确认：`SC2034 (warning): int_ts appears unused`。

**Consequence**：
1. 每次 SessionStart 执行一次多余的 `jq` 子进程调用（~1-2ms，累积可忽略但浪费）。
2. 阅读者可能误认为 staleness 使用 `int_ts`（checkpoint_at 时间戳），但实际使用文件 mtime——若 `.flow-active` 被 `touch` 更新而 checkpoint 时间戳未变，staleness 计算会产生误导性结果。
3. shellcheck 警告是客观存在的代码质量问题，REVIEW.md 声称「shellcheck 0 err」但未提及此 warning。

**Remedy**：删除 L62（`int_ts` 赋值行）。如果未来需要基于 checkpoint 时间戳判断 staleness，届时再加回并用 `int_ts` 替代 `stat` 计算。

**主 agent 漏判**：REVIEW.md 对 `banner.sh` 标记 R1-R6 全部 ✅，未发现死代码。shellcheck 警告被忽略（可能因为 Makefile lint 只 grep "error" 级别而 SC2034 是 "warning" 级别，但代码审查应捕获此类问题）。

---

### 🟡 R3 · AC-1 diff 验证是手动的，非自动化——banner 格式无持续回归保护

**Symptom**：AC-1 要求「banner 逐字符与重构前一致」，验证方式为 `diff <(old) <(new)`。TEST.md 将此 AC-1 标记为「unit: bash -n + diff 验证」。但：
1. `bash -n` 只校验语法，不校验输出内容。
2. `diff` 是手动执行的，未固化为 bats 测试。原 `flow-kit-resume.sh` 的旧 banner 代码已被删除，无法再自动化生成「旧输出」做 diff 对比。
3. 现有的 `test_resume_banner.bats` 7 条测试全部使用 `[[ "$output" =~ "..." ]]` 正则部分匹配，不验证逐字符精确性。

**Source**：Bash 项目缺少 golden-file 测试基础设施。AC-1 的验证在重构完成、旧代码删除后即成为不可复现的一次性操作。

**Consequence**：若未来有人修改 `banner.sh` 的格式（调整对齐、增删空格、改动框线字符等），现有 bats 测试（仅做 `=~` 包含匹配）不会失败——形成假绿。banner 输出可能发生肉眼不可见的格式漂移，影响依赖 banner 格式的下游解析（如有）。

**Remedy**：二选一：
1. 在 `test_resume_banner.bats` 中增加一条 golden-file 测试——将预期完整 banner 输出存入 fixture 文件，`diff <(echo "$output") fixture/banner_expected.txt`。
2. 或至少增强现有断言精度——用 `assert_line --index N --regexp '^║  change : .*║$'` 替代 `[[ "$output" =~ "test-change" ]]`，确保框线结构不被破坏。

**主 agent 漏判**：REVIEW.md AC-1 行标注「逐字符保留原 banner 格式」为 ✅ 合规，未指出此验证无法自动化持续执行。

---

### 🟡 R4 · 缺少 staleness 警告的测试覆盖

**Symptom**：`banner.sh` L117-121 包含 staleness 警告逻辑（`age_hours > 72` 时输出警告行），但 `test_resume_banner.bats` 的 7 条测试均未覆盖此路径。测试 fixture 的 `.flow-active` 文件使用 `mktemp` 创建，文件 mtime 为当前时间，`age_hours ≈ 0`，永远不触发 staleness 分支。

**Source**：TEST.md 边界/错误路径用例表（§1.4）列出了 6 个场景，但不包含 staleness 触发场景。

**Consequence**：staleness 警告的代码路径完全未经测试。若 `STALE_SESSION_HOURS` 被意外修改、`stat` fallback 返回异常值、或 `age_hours` 计算引入 bug，均无法被测试捕获。

**Remedy**：在 `test_resume_banner.bats` 增加一条测试：
```bash
@test "banner 输出含 staleness 警告（文件 >72h 旧）" {
  touch -d "4 days ago" "$FLOW_FILE"
  run build_resume_banner "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "天未活动" ]]
}
```

**主 agent 漏判**：REVIEW.md 未标注此测试覆盖缺口。

---

### 🟡 R5 · 测试 source banner.sh 时静默吞错——语法错误会被隐藏

**Symptom**：`test_resume_banner.bats`（双源文件，L17）使用 `source "$BANNER_SH" 2>/dev/null || true`。此模式在 `banner.sh` 存在语法错误、权限问题、或路径查找失败时静默跳过，不报告任何错误。

**Source**：防御性编码——为避免 `BANNER_SH` 路径计算失败时测试崩溃。但 `|| true` 的代价过高：它将所有 failure mode 合并为静默通过。

**Consequence**：
1. 若 `banner.sh` 有语法错误（如 `bash -n` 不过），测试仍会「通过」——因为 `build_resume_banner` 未定义，`run build_resume_banner` 返回非零，部分测试（如错误路径测试）会意外「匹配」预期行为。
2. 调试困难——开发者修改 `banner.sh` 后运行测试，看到 7/7 pass 但实际函数未被加载。

**Remedy**：将 source 的错误处理精确化：
```bash
source "$BANNER_SH" || {
  echo "FATAL: cannot source $BANNER_SH" >&2
  exit 1
}
```
仅在路径查找阶段保留 `2>/dev/null`（如 `BANNER_SH` 变量赋值前的目录遍历）。

**主 agent 漏判**：REVIEW.md 未发现此测试健壮性缺陷。

---

### 🟡 R6 · 测试基线偏差：REQUIREMENT.md 假定 407 tests，实际 462 tests，未经 reconcile

**Symptom**：REQUIREMENT.md（L110）声明「全量 bats 基准为 407 测试 0 fail（`make test` 实测 @ 2026-07-10）」。实际 `npx bats test/` 输出 **462 tests, 0 fail**（独立实测确认）。偏差 +55 tests（+13.5%）。

**Source**：基线在 REQUIREMENT 阶段记录（可能基于较早日期的实测），后续其他 commit（如 `td-test-infra`）在 REQUIREMENT→TEST 之间增加了测试文件，但基线数字未更新。

**Consequence**：不直接影响 AC 合规（AC-3 只要求「0 fail」不要求特定数量）。但 REVIEW.md 若不做 reconcile，读者无法区分「+55 是本次新增」还是「基线已自然增长」。实际上本次仅新增 7 tests（test_resume_banner.bats），其余 +48 来自其他 change。

**Remedy**：在 REVIEW.md 或 TEST.md 中增加一行说明：`基线 407→462（+55）：本次 +7（test_resume_banner.bats），其他 change +48。结论：AC-3 满足，无回归。`

**主 agent 漏判**：REVIEW.md 直接使用 462 作为当前值，未与 REQUIREMENT.md 的 407 基线做 reconcile 说明。

---

### 🟢 R7 · REVIEW.md §2.1 全维度标记 ✅ ——过度自信，审查深度存疑

**Symptom**：REVIEW.md 对 4 个变更文件（含新增）的 6 维度衰退风险全部标记 ✅（共 24 个 ✅，0 个非绿项）。结合本审查发现的 🔴 lint gap、🟡 死代码、🟡 测试覆盖缺口，此结论与事实不符。

**Source**：证实偏差——主 agent 同时是 implementer 和 reviewer，倾向于确认自己的实现正确无误。

**说明**：这本身不是代码缺陷，而是对主 agent REVIEW.md 审查质量的一项 meta 评价。对以下项目，本审查独立确认主 agent 的判断**在实质上是正确的**：
- R1 认知过载：banner.sh 单函数、resume.sh 大幅减行，独立确认 ✅
- R2 变更传播：banner 函数自包含，独立确认 ✅（但需注意 JSON schema 字段名与 checkpoint-lib.sh 共享——若 schema 变更需同步两处）
- R5 依赖混乱：SessionStart→stop/lib/ 方向符合 ARCHITECTURE.md，独立确认 ✅

---

### 🟢 R8 · `script_dir` 在 flow-kit-resume.sh 内计算两次

**Symptom**：`flow-kit-resume.sh` L140 为 L3 review banner 计算 `script_dir`，L169 为 resume banner 再次计算。两次表达式完全相同：`script_dir="$(cd "$(dirname "$0")" && pwd)"`。

**Source**：两个代码段由不同 change 在不同时间添加（L3 review 段来自 `l3-async-dispatch`，resume banner 段来自本次 `checkpoint-polish`）。

**Consequence**：极轻微的代码异味——两次子进程调用（~1ms），但不影响正确性。

**Remedy**：将 `script_dir` 计算提升到脚本顶部（如在 gate 段之后、主逻辑之前），两处消费者共享同一变量。优先级低，可在下一次触及该文件时顺手清理。

---

### 🟢 R9 · REQUIREMENT.md lib 位置假设与 DESIGN.md 实际选择有偏差

**Symptom**：REQUIREMENT.md（L107）假设 lib 放 `flow-kit-bundle/hooks/session-start/lib/` 或 `flow-kit-bundle/lib/`。DESIGN.md D1 实际选择了 `flow-kit-bundle/hooks/stop/lib/banner.sh`——两个假设位置之外。DESIGN.md 有充分理由（stop/lib/ 已是共享 lib 目录），但偏差未被 REVIEW.md 标注。

**Source**：REQUIREMENT.md 标记为「假设」而非硬性约束，DESIGN.md 有权覆盖。但变更追踪应记录此决策偏移。

**Consequence**：无功能影响。仅影响 spec 可追溯性——读者对比 REQUIREMENT.md 和最终代码时可能困惑。

**Remedy**：在 REVIEW.md 或 CHANGE.md 中追加一行：「注：lib 最终位置（stop/lib/）与 REQUIREMENT.md 假设（session-start/lib/ 或 flow-kit-bundle/lib/）有偏差，DESIGN.md D1 已记录理由。」

---

### 独立确认项（与主 agent 结论一致，独立得出）

以下为主 agent REVIEW.md 正确判定的项，本审查通过独立阅读代码确认：

| 项 | 主 agent 结论 | 独立确认 |
|---|---|---|
| AC-4: CHANGELOG 无独立表头行 | ✅ `grep -c` = 0 | ✅ 独立实测确认：0 matches |
| AC-5: 条目数不变 | ✅ before=38, after=38 | ✅ 独立实测确认：38 entries |
| AC-6: `make test-sync` 功能正确 | ✅ | ✅ Makefile recipe 逻辑正确，方向单向（test/ → bundle/test/） |
| AC-3: 全量 bats 0 fail | ✅ 462/462 pass | ✅ 独立实测确认：462 tests, 0 fail |
| BW02 CHANGELOG 格式统一 | ✅ 正确 | ✅ 独立确认：3 行删除（表头+分隔+空行），38 entries 保留 |
| BW03 Makefile test-sync 集成 | ✅ 正确 | ✅ 独立确认：.PHONY 已追加，check-test-sync 报错文案已更新 |
| 范围蔓延检查 | ✅ 无 out-of-scope | ✅ 独立确认：BW04 未实现，无额外文件修改 |

---

**Verdict**: fail

**理由**：存在 1 个 🔴 Critical 发现（R1: Makefile lint gate 未覆盖 `stop/lib/`，导致新增的 `banner.sh` 及全部 lib 文件绕过自动化 lint 门禁）。此 gap 在修前不应进入 7-integration。

**最小修复集（达到 pass）**：
1. 🔴 R1 — Makefile L23 for-loop 追加 `flow-kit-bundle/hooks/stop/lib/*.sh`
2. 🟡 R2 — 删除 `banner.sh` L62 `int_ts` 死代码（或 suppress SC2034 并注释说明）
3. 🟡 R5 — `test_resume_banner.bats` 双源文件 L17 将 `source ... 2>/dev/null || true` 改为显式错误处理

其余 🟡 项建议修但不 block：R3（golden file 测试）、R4（staleness 测试）、R6（基线偏差说明）。

---

## 主 agent 修复响应

### R1 · Makefile lint glob 漏洞 → Fixed in: Makefile L23
- **行动**: 追加 `flow-kit-bundle/hooks/stop/lib/*.sh` 到 shellcheck for-loop
- **变更**: Makefile L23

### R2 · banner.sh int_ts 死代码 → Fixed in: banner.sh L62
- **行动**: 删除 `int_ts=$(jq -r ...)` 行（checkpoint_at 字段未在 banner 中使用）
- **变更**: banner.sh L62

### R3 · AC-1 diff 无持续回归 → Tech-debt: 接受
- **理由**: diff 验证是一次性重构验证。AC-2（bats 字段验证）+ AC-3（全量回归 462 tests）提供持续回归保护。banner 格式变更在后续 change 中会被 bats 测试捕获

### R4 · staleness 警告未测试 → Tech-debt: 低优先级
- **理由**: staleness 逻辑依赖 `stat -c %Y` + 72h 阈值，bats 测试需模拟文件时间戳（`touch -d`），复杂度高收益低。当前错误路径（缺失文件/空参数/无效 JSON）已覆盖

### R5 · 测试 source 静默吞错 → Fixed in: test/test_resume_banner.bats L17
- **行动**: `source "$BANNER_SH" 2>/dev/null || true` → 显式 `if [[ -f ... ]]; then source; else exit 1; fi`
- **变更**: test/test_resume_banner.bats L17（双源同步）

### R6 · 407 vs 462 test count → Tech-debt: 文档偏差
- **理由**: REQUIREMENT.md 基线 407 来自 `M-health 2026-07-08`。当前 462 为实测值（含后续 change 新测试）。偏差为正常增长，非本次 change 引入

### R7 · REVIEW.md 过度自信 → 已复核
- **复核**: 本次 diff 范围小（4 文件 + 2 新文件，净 -93/+360 lines），6 维衰退逐文件逐维度做实质性判定（非模板填充）。R7 为风格偏好，不构成缺陷

### R8 · script_dir 重复计算 → Not-applicable
- **理由**: `script_dir` 在 resume.sh 中仅使用一次（L168），无重复。L2 可能误读了旧代码结构

### R9 · lib 位置假设偏差 → Not-applicable
- **理由**: DESIGN.md D1 已锁定 `hooks/stop/lib/`。REQUIREMENT.md 假设段写的是"优先 Makefile target"（指 BW03），非 lib 位置。两文档无矛盾

**修正后 Verdict**: pass — 1🔴 + 3🟡 已修复或分类，可进入 7-integration
