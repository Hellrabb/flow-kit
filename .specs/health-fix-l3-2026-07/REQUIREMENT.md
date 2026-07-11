# REQUIREMENT — L3 审计子系统健康修复

- **Change ID**: `health-fix-l3-2026-07`
- **关联**: `@.specs/health-fix-l3-2026-07/CHANGE.md`、`@.specs/CONTEXT.md`
- **触发来源**: `.specs/health/2026-07-11-L3-AUDIT-HEALTH.md`（评分 72/100）

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想拆分 `_gate_phase_transition()` 和 `fk_fix_compliance_check()` 等超长函数，以便后续修改任一职责时只需理解 40~60 行而非 120~300 行。
- **US-2**：作为 flow-kit 用户，我想消除 correction-file ↔ interactive-ui-check ↔ weak-model-compliance 三向依赖环，以便改一个模块不会意外破坏另一个。
- **US-3**：作为 flow-kit 开发者，我想补齐 L3 timeout 路径的 bats 测试覆盖，以便 CI 能可靠捕获 L3 API 超时的回归。
- **US-4**：作为 AI agent，我想消除 prompt 中重复的 jq goal 解析逻辑和 phase_name 硬编码映射，以便新阶段加入时不需要同步修改多处。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 长函数拆分 ≤ 60 行

- **Given** `independent-review-gate.sh` 含 `_gate_phase_transition()`（~175 行，含 3 个 gate 检查块）和 `l3-review.sh` 含 `smart_truncate()`（112 行）/ `_l3_parse_result()`（82 行）/ `_l3_build_prompt()`（85 行）/ `fk_fix_compliance_check()`（126 行）
- **When** 按职责拆分为子函数（每个 ≤ 60 行），且 `_gate_phase_transition` 保留为编排器（仍命名 `_gate_phase_transition`，仅含调度逻辑，≤ 50 行）
- **Then** 拆分后逐函数验证每函数 ≤ 60 行（`_gate_phase_transition` 编排器 ≤ 50 行）；`npx bats test/` 全量通过；`bash -n` 零报错
- **验证方式**: 用 grep -n 定位函数起止行差值计数（将 `<func>` 替换为实际函数名，`<file>` 替换为源文件路径）：`start=$(grep -n "^<func>()" <file> | cut -d: -f1); end=$(grep -n "^[a-zA-Z_]" <file> | awk -F: -v s="$start" '$1>s{print; exit}'); echo "$((end - start)) lines"`，或手工 wc -l 确认；`make test`（全量 bats 回归）；`bash -n`（语法门禁，见 AC-4）

### AC-2 · 依赖环消除

- **Given** `correction-file.sh` ↔ `interactive-ui-check.sh` ↔ `weak-model-compliance.sh` 三向 source 依赖环（可通过 `grep -r "source.*correction-file.sh\|source.*interactive-ui-check.sh\|source.*weak-model-compliance.sh" hooks/` 交叉检测确认）
- **When** 提取共享类型/接口到 `correction-types.sh`（轻量文件，仅常量 + 类型定义），三方改为依赖 `correction-types.sh` 而非相互 source
- **Then** 依赖检测不再报告该三向循环；`bash -n` 三文件全部通过；现有 correction 读写测试 0 fail
- **验证方式**: `grep -r "source.*correction-file.sh\|source.*interactive-ui-check.sh\|source.*weak-model-compliance.sh" flow-kit-bundle/hooks/` 确认无相互引用；`npx bats test/` 全量通过

### AC-3 · 行为零回归

- **Given** 本次改动涉及 10 个 `.sh` 源文件（见 AC-4 文件清单）+ 1 个 `.bats` 测试文件（`test/test_l3_timeout.bats` 新增）+ 2 个 `.md` prompt 文件（6-review.md / 7-integration.md）
- **When** 所有代码修改完成
- **Then** `npx bats test/` 全量通过（exit 0），含新增 timeout 测试，0 failures
- **验证方式**: `npx bats test/` 返回 exit 0，输出 `0 failures`
- **性能回归检测**（轻量）: 修改前后各执行 `time npx bats test/test_independent_review_gate.bats`，耗时差异 ≤ 200ms（非硬门禁，偏差 >200ms 时人工判断）
- **参考**: L3 相关测试范围 = `test/test_l3_*.bats` + `test/test_independent_review_gate.bats` + `test/test_fix_compliance.bats`（可通过 `grep -l "l3\|independent.review" test/*.bats` 确认覆盖）

### AC-4 · bash -n 语法门禁

- **Given** 本次修改的 10 个 `.sh` 源文件：
  1. `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`
  2. `flow-kit-bundle/hooks/stop/29-independent-review.sh`
  3. `flow-kit-bundle/hooks/stop/lib/l3-review.sh`
  4. `flow-kit-bundle/hooks/stop/lib/fix-compliance.sh`
  5. `flow-kit-bundle/hooks/stop/lib/done-validation.sh`
  6. `flow-kit-bundle/hooks/stop/lib/common.sh`
  7. `flow-kit-bundle/hooks/stop/lib/correction-file.sh`
  8. `flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh`
  9. `flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh`
  10. `flow-kit-bundle/hooks/stop/lib/transcript-parser.sh`
  （来源：CHANGE.md § 触碰模块）
- **When** 对每个文件执行 `bash -n`
- **Then** 所有文件零报错
- **验证方式**: `for f in flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh flow-kit-bundle/hooks/stop/29-independent-review.sh flow-kit-bundle/hooks/stop/lib/l3-review.sh flow-kit-bundle/hooks/stop/lib/fix-compliance.sh flow-kit-bundle/hooks/stop/lib/done-validation.sh flow-kit-bundle/hooks/stop/lib/common.sh flow-kit-bundle/hooks/stop/lib/correction-file.sh flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh flow-kit-bundle/hooks/stop/lib/transcript-parser.sh; do bash -n "$f" || echo "FAIL: $f"; done` 无 FAIL 输出

### AC-5 · DRY 消除 — phase_name 映射

- **Given** `common.sh` 中无集中 phase_name 映射，多个 hook/prompt 中硬编码 `case "$phase" in 1) ... "1-requirement" ;;` 片段
- **When** 在 `common.sh` 新增 `declare -A PHASE_GATE_KEY_MAP` 关联数组（`[1]="1-requirement" [2]="2-design" ...`）
- **Then** 至少 2 处硬编码替换为查表调用；`bash -n common.sh` 通过；`npx bats test/test_common.bats` 全量通过
- **验证方式**: `grep -c "1-requirement" hooks/stop/lib/common.sh` 确认仅声明处出现；grep 硬编码 case 段确认替换

### AC-6 · DRY 消除 — prompt jq goal 解析

- **Given** `6-review.md` 和 `7-integration.md` 中 goal 解析 jq 逻辑（~30 行/处）逐字重复
- **When** 抽取为 `flow-kit/reference/goal-parsing.md` 共享片段，两 prompt 改为 `@see` 引用
- **Then** 两 prompt 中不再含完整 jq goal 解析代码块；`make check` 通过
- **验证方式**: `for f in flow-kit-bundle/flow-kit/prompts/6-review.md flow-kit-bundle/flow-kit/prompts/7-integration.md; do grep -q "goal.scope\|goal.current_phase\|goal.start_phase" "$f" && echo "FAIL: $f still contains jq goal parsing" && exit 1; done; echo "OK: both prompts cleaned"`；`make check` 通过

### AC-7 · timeout 路径测试补齐

- **Given** `l3-review.sh` 的 `l3_review_run()` 含 30s timeout 逻辑，但 `test/` 中无 timeout 专项测试。Mock 方案：bats 测试通过设置 `CURL_TIMEOUT` 或覆盖 `curl` 为 stub 函数（返回特定退出码），模拟超时/网络错误场景
- **When** 新增 `test/test_l3_timeout.bats`，覆盖：① L3 API 超时 → verdict=timeout（mock curl 返回 28）② L3 API 网络错误 → verdict=error（mock curl 返回 7）③ timeout/error 后 `.done` 不写入（验证 `.independent-review-<N>.done` 的 mtime 不晚于测试开始时间或文件不存在）
- **Then** 3 个场景全部通过；`npx bats test/test_l3_timeout.bats` 返回 exit 0
- **验证方式**: `npx bats test/test_l3_timeout.bats`

### AC-8 · self-sourcing 修复 + 死代码清理

- **Given** `l3-review.sh:511` 使用 `source "$0"` self-sourcing 脆弱模式；CHANGE.md 列出 3 个待清理死代码函数——`estimate_tokens()`（`transcript-parser.sh:130`·全仓零引用）、`read_correction_file()`（`interactive-ui-check.sh:199`·生产无调用·已确认废弃·TD-009）、`file_not_empty()`（`common.sh:163`·仅测试用·已清理·TD-009）。后两项已在 2026-07-09 清理周期移除，本次仅需确认无残留并清理 CONTEXT.md 清理窗口条目
- **When** ① `source "$0"` 替换为 `source "$HOOK_BASE_DIR/lib/l3-review.sh"` 绝对路径 ② 移除 `estimate_tokens()` 函数定义 + 注释块 ③ 确认 `read_correction_file()` / `file_not_empty()` 无残留引用 ④ 从 CONTEXT.md 清理窗口专列移除 3 条目
- **Then** `bash -n l3-review.sh` / `bash -n transcript-parser.sh` / `bash -n common.sh` 通过；grep 确认不再含 self-sourcing 和 3 死函数
- **验证方式**: `grep 'source "\$0"' l3-review.sh` 无匹配；`grep -E 'estimate_tokens|read_correction_file|file_not_empty' transcript-parser.sh interactive-ui-check.sh common.sh` 无匹配；CONTEXT.md 清理窗口专列为空

### AC-9 · 29-independent-review.sh 函数化

- **Given** `29-independent-review.sh` 主逻辑为线性脚本（非函数化），含 L2 完成检测 / gate 值解析 / L3 派发 三职责
- **When** 提取 `_check_l2_complete()` / `_resolve_gate_value()` / `_dispatch_l3_review()` 三个函数
- **Then** 主逻辑变为 3 个函数调用 + 编排层（≤ 30 行）；`bash -n 29-independent-review.sh` 通过；Stop hook 行为不变
- **验证方式**: `grep -c "^_check_l2_complete\|^_resolve_gate_value\|^_dispatch_l3_review" 29-independent-review.sh` ≥ 3；`npx bats test/` L3 相关 128 tests 0 fail

---

## 范围切分

### v1（本次必做）

- AC-1 长函数拆分：`_gate_phase_transition()` → `_gate_check_l2()` / `_gate_check_l3()` / `_gate_do_transition()`
- AC-1 长函数拆分：`fk_fix_compliance_check()` → 编排层 + 复用现有子阶段函数
- AC-1 长函数拆分：`smart_truncate()` → 按 header/artifact/CHANGELOG/优先级拆子函数
- AC-1 长函数拆分：`_l3_parse_result()` → 解析/校验/归档分离
- AC-1 长函数拆分：`_l3_build_prompt()` → system/user/artifact 三段
- AC-2 依赖环消除：提取 `correction-types.sh`
- AC-3 行为零回归：`npx bats test/` 全量通过
- AC-4 bash -n 语法门禁
- AC-5 DRY phase_name 映射
- AC-6 DRY prompt jq goal 解析
- AC-7 timeout 路径测试补齐
- AC-8 self-sourcing 修复 + 死代码清理
- AC-9 29-independent-review.sh 函数化

### v2（下一轮考虑，不本次）

- `l3-review.sh` 进一步拆分为 `l3-detect.sh` / `l3-dispatch.sh` / `l3-truncate.sh` 三子库（TD-008，当前 574 行拆为 3 文件后每文件 ~190 行——成本/收益比不够，先完成 v1 基础拆分）
- `is_gh_pr_create()` 主逻辑体拆分（TD-018 已在 v1 通过 `_gate_phase_transition` 拆分解耦；`is_gh_pr_create` 自身 3 行谓词不拆，但其调用方主逻辑体独立拆分延后——当前独立 review gate 链改动风险高，需更充分的回归测试覆盖后再拆）

### out（永远不做）

- 不新增 hook 模块编号（不改变 Stop hook 01-33 编号和加载顺序）
- 不改动 gate 校验逻辑本身（只重构函数结构，行为不变）
- 不修改 `.flow-active` schema（字段结构保持稳定）
- 不修改 `package-flow-kit.sh` 打包脚本
- 不修改 `install.sh` / `install_hooks.sh` 安装脚本

---

## 非功能性需求

- **性能**: 无显著影响（纯重构，不改变运行时复杂度；函数调用级拆分引入的额外 bash 函数调用开销预计 <100ms/hook 调用，可在 AC-3 bats 全量测试中附带 `time` 对比确认）
- **可访问性**: 无（非 UI 项目）
- **安全**: 无新增攻击面（不引入外部依赖，不改 API 调用方式）
- **兼容性**: 所有修改保持 Bash 4.2+ 兼容（现有最低要求）；不引入 bash 5.0+ 特性
- **可观测性**: `l3-review.sh` 保持现有 stderr 日志输出格式不变；新增 timeout 测试覆盖超时路径日志

## 依赖与假设

- **依赖**: 所有修改仅在 `flow-kit-bundle/` 维护源上进行；`bats-core 1.13.0` 可用（`npx bats`）；`bash -n` 可用
- **假设**: 现有 407 个 bats 测试在修改前全绿（上次 `make test` @ 2026-07-10 确认 0 fail）
- **假设**: `l3-review.sh` 的 `l3_review_run()` main 函数在 v1 不拆分——仅拆分其调用的子函数（`_l3_build_prompt` / `_l3_parse_result` / `smart_truncate`）
- **假设**: 拆环只提取类型/常量到 `correction-types.sh`，不改动三模块核心逻辑
- **假设**: `done-validation.sh`（CHANGE.md 触碰列表第 5 项）为**被动变更**：因 AC-2 解环引入 `correction-types.sh` 后，`done-validation.sh` 需调整 source 路径（从 source `correction-file.sh` 改为 source `correction-types.sh`），属 AC-2 实施副作用，不需独立 AC
- **假设**: 死代码 `estimate_tokens()` 确认全仓零引用后可安全删除（CONTEXT.md 清理窗口专列已记录）；`read_correction_file()` / `file_not_empty()` 已在 2026-07-09 清理周期移除，本次仅确认无残留

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
