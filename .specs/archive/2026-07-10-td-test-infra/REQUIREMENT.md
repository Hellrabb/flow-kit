# REQUIREMENT: TD-010 jscpd 工具化 + TD-002 stop 链覆盖核实/补

- **Change ID**: td-test-infra
- **关联**: `@.specs/td-test-infra/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想把 jscpd 重复率扫描约定固化为 `make dup` 命令，以便不再靠人记忆加 `--ignore`，避免打包进来的第三方 brooks-lint/brooks-tools 污染重复率（0.91% 误报）。
- **US-2**：作为 flow-kit 维护者，我想确认 stop 链 13 个无 test 主脚本的真实覆盖缺口，以便含业务检查逻辑的脚本（secrets detection / artifact 验证）有可信测试保障，或缺口被明确记录而非盲区。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · make dup 固化 jscpd 约定

- **Given** Makefile 含 `dup` target（独立，不进 `check`），其 recipe 命令带 `--ignore '**/brooks-lint/**,**/brooks-tools/**,**/test/**,**/regression-demos/**'`
- **When** 跑 `make dup`
- **Then** jscpd 已装 → 扫描自有代码重复率（结果走 stdout）+ **exit 0**（仅报告，不门禁；门禁显式留 v2）；jscpd 未装 → stderr 含 `jscpd` 字样的 skip 提示 + **exit 0**（不影响 `make check`）
- **验证方式**（L3-critical：校验在 dup target 下 + 行为，非全局字样）:
  - 行为：`make dup; echo "exit=$?"` → exit 0（已装扫描 / 未装 stderr 含 jscpd skip）
  - ignore 校验（提取 dup recipe）：`awk '/^dup:/{f=1;next} f&&/^[^[:space:]#].*:[^=]/{f=0} f' Makefile` 输出含 `--ignore` 且含 `brooks-lint`/`brooks-tools`/`test`/`regression-demos` 4 个模式（校验配置在 dup target 内，而非 Makefile 任意位置）

### AC-2 · TD-002 覆盖结论

- **Given** 读 `test_stop_chain.bats` + `test_stop_report_reminder.bats` + 全部 `test/*.bats`
- **When** 分析每个 stop 主脚本覆盖：**覆盖判定**（沿用 `test_stop_chain.bats` 范式 · source 不可行）= 已有 `bash-n + shebang + grep 关键函数` smoke ⇒ **covered**；仅 `bash-n`（test_smoke_syntax）⇒ **partial**；无 ⇒ **gap**
- **Then** 产出**结构化 17 行表**（列：主脚本名 / 分类[business|coord|aggrep] / 覆盖状态[covered|gap] / 对应 test 文件:行号），记入 `.specs/td-test-infra/SUMMARY.md`
- **验证方式**（L3-critical：精确计数 + 内容校验，非仅文件存在）:
  - `test -f .specs/td-test-infra/SUMMARY.md`
  - `[ "$(grep -cE '^\| (00-|01-|2[0-9]-|3[0-9]-|99-)[a-z-]+ \| (business|coord|aggrep) \| (covered|partial|gap) \|' .specs/td-test-infra/SUMMARY.md)" -eq 17 ]`（17 数据行，每行含 `脚本名 | 分类 | covered/partial/gap |`；covered=bash-n+grep smoke / partial=仅 bash-n / gap=无；表头不计）

### AC-3 · TD-002 关键脚本补 smoke（条件性 · 仅 AC-2 发现 [business] 类缺口时）

- **Given** AC-2 覆盖表中标 [business] 且状态 [gap] 的主脚本（见下方分类表）
- **When** 给这些脚本补 smoke（每个：`bash -n` 语法 + shebang 校验 + **grep 关键函数名/模式存在**，沿用 `test_stop_chain.bats` 范式 · source 不可行）
- **Then** 新 smoke bats 全绿；双源同步
- **验证方式**: `bats test/` 全绿 0 fail + `diff -r test/ flow-kit-bundle/test/` 退出 0（双源一致 · 替代原悬空 AC-7 · R1）
- **17 脚本分类（v1 边界 · R4）**：
  - **[business]**（v1 补缺口）：22-git（C4 secrets）/ 23-quality / 26-workflow（G1 artifact）/ 27-interactive-ui-check / 28-weak-model-compliance / 29-independent-review / 30-ai-analyze / 33-flow-active-integrity
  - **[coord]**（v1 不补，留 v2）：00-gate / 01-transcript-parse / 20-claude-md / 21-memory / 24-session / 25-project / 31-auto-advance / 32-fallback-guard
  - **[aggrep]**（v1 不补）：99-report
- **注**: v1 上限 8 个 [business] 缺口；超出或 [coord] 缺口转 v2
- **止损条款（L3-major · 防范围蔓延）**: smoke 严格限定 = 语法（`bash -n`）+ source 成功 + 调 1 个内部检查函数断言返回码。若某 [business] 脚本因**内部逻辑复杂**导致 smoke 失败、且修复需改脚本逻辑（超出 smoke 范围），允许标 `skip` + 注明原因 + 列 v2，**不强制 `bats` 全绿阻塞交付**。
- **路径定义（L3-minor）**: `diff -r test/ flow-kit-bundle/test/` 的 `flow-kit-bundle/` = 项目根下打包源目录（STATE.md 已锁定 hooks 唯一源）

### AC-4 · CONTEXT 校准 + 全量回归

- **Given** TD-010/002 完成
- **When** 更新 CONTEXT TD-010（「已纳入 SOP」→「已固化为 `make dup`」）+ TD-002（覆盖结论 / ✅）
- **Then** CONTEXT 描述与实测一致；`bats test/` 全绿
- **验证方式**: `grep TD-010\|TD-002` CONTEXT.md + `bats test/` exit 0

---

## 范围切分

### v1（本次必做）

- TD-010：Makefile 加 `dup` target（独立，不进 `check`）
- TD-002：调查 test_stop_chain 覆盖 + 给**关键业务脚本**补 smoke（若缺口）

### v2（下一轮考虑，不本次）

- TD-002 若缺口大、v1 只补关键脚本，纯协调/聚合脚本的 smoke 留 v2
- `make dup` 未来若想强制重复率门禁，可纳入 `check`（本次刻意不做——jscpd 未装不应致 check fail）

### out（永远不做）

- TD-004 / TD-005 / TD-008（其他技术债，等机会型，不本次）
- 给全部 17 个主脚本都补 smoke（YAGNI——按业务价值按需补，不为覆盖率而覆盖率）

---

## 非功能性需求

- **性能**: 无（`make dup` 手动跑，不进构建关键路径）
- **可访问性**: 无
- **安全**: 无（jscpd 只读扫描；smoke test 不改生产代码）
- **兼容性**: GNU make + jscpd 5.0.11（已打包于 brooks-tools）；jscpd 未装时 graceful skip。jscpd 版本 ≠ 5.0.11 时 warn 但不 fail（输出格式不保证跨版本稳定，仅供人工查看 · R7）
- **可观测性**: `make dup` 扫描结果走 stdout，skip/警告走 stderr；输出重复率 + Top 克隆块（R7）

## 依赖与假设

- jscpd 已装（`/home/hellrabbit/.local/bin/jscpd`）或 package 内 brooks-tools 离线版可用
- 假设 `test_stop_chain.bats` / `test_stop_report_reminder.bats` 能反映 stop 链组装覆盖（AC-2 核实此前提）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
