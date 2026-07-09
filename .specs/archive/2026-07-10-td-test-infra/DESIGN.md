# DESIGN: TD-010 jscpd 工具化 + TD-002 stop 链覆盖核实/补

- **Change ID**: td-test-infra
- **关联**: `@.specs/td-test-infra/REQUIREMENT.md`、`@.specs/CONTEXT.md`

> **设计性质声明**：本 change 为测试/工具基础设施加固，**无新技术栈选型、无架构变更、无可逆性低的决策**。0₋ 架构预检不命中，技术栈已锁（Bash/Make/bats/jscpd）。本 DESIGN 聚焦既有架构对齐 + 决策理由 + 风险。

---

## 0. 技术栈选定

**已锁**（来自 CONTEXT.md / STATE.md，无需卡片）：
- Bash 脚本项目（flow-kit 分发包仓库）
- GNU make（Makefile 已存在 test/lint/check targets）
- bats-core 1.13.0（npx · 407 tests）
- jscpd 5.0.11（已打包于 brooks-tools，离线可用；`/home/hellrabbit/.local/bin/jscpd`）

无新栈引入。

## 0.5 既有架构对齐（brownfield · 证据来自 grep/ls）

### 0.5.1 本次 change 触碰的既有模块

```
本次 change 会触碰：
- `Makefile`（既有 · 加 dup target）
- `test/test_stop_chain.bats`（既有 · **已读**：L4 覆盖 22-git/24-session/26-workflow/99-report；L6-7 明确"无法 source，用 bash-n+shebang+grep"）
- `test/test_smoke_syntax.bats`（既有 · **已读**：AC-4 全仓库 .sh `bash -n` 门禁 → 17 主脚本语法层**已全覆盖**）
- `test/test_stop_report_reminder.bats`（既有 · 读，核实覆盖）
- `test/*.bats` 全量（既有 · grep 分析 source/smoke 关系）
- `flow-kit-bundle/test/test_stop_chain.bats` + `flow-kit-bundle/test/test_stop_report_reminder.bats`（双源镜像）
- `flow-kit-bundle/hooks/stop/*.sh`（既有 · 17 主脚本 · 按需补 smoke 的对象，不改其源）

会新增（仅 AC-3 触发时）：
- `test/test_stop_<script>_smoke.bats` + `flow-kit-bundle/test/` 镜像（新 smoke 文件）

不应该触碰但 AI 容易"顺手改"的：
- `flow-kit-bundle/hooks/stop/*.sh` 源码（STATE 锁定 hooks 唯一源 · smoke 只 source 不改）
- `flow-kit-bundle/brooks-lint/` + `brooks-tools/`（第三方 · 禁动）
- `flow-kit-bundle/hooks/stop/lib/*.sh`（lib 已有独立 test · 不在本次范围）
```

### 0.5.2 对齐既有抽象

| 本次需要 | 既有有没有？ | 决定 |
|---|---|---|
| Makefile target 模式 | `test:`/`lint:`/`check:` 既有 | **沿用**同风格（`@`前缀 + `command -v` 探测）|
| bats smoke 模式（stop 主脚本）| `test_stop_chain.bats` 既有（**bash-n + shebang + grep 关键函数**，非 source · 因脚本依赖运行时环境）| **沿用** |
| 双源同步 | AC-7 约定 + `check-test-sync` target | **沿用**（test/ + flow-kit-bundle/test/ 镜像）|
| stop 主脚本测试 | `test_stop_chain.bats` 既有（待核实覆盖范围）| **先读再定**（AC-2）|

### 0.5.3 沿用 vs 引入

- Makefile target 风格：**沿用**（`@npx`/`@command -v` 既有范式）
- smoke 验证范围：**沿用** bats `run`+`$status` 模式
- 无新模式引入

## 1. 技术决策

### D1 · `make dup` 独立 target，不纳入 `check`
- **备选**：纳入 `check`（强制重复率门禁）
- **选择**：独立 target
- **理由**：jscpd 是可选依赖（未装时 `check` 不应 fail）；重复率是参考指标非硬门禁（CONTEXT 已锁）
- **代价**：重复率退化不会被 `make check` 自动捕获（v2 可加 `--threshold` + 纳入 check）

### D2 · smoke 仅覆盖语法/结构层（bash-n + shebang + grep），运行时逻辑由 hook 覆盖
- **备选**：运行时逻辑测试（source 脚本 + 调函数断言）
- **选择**：`bash -n`（语法）+ shebang 校验（结构）+ grep 关键函数名（结构完整性）
- **理由**：分层明确——smoke 范围严格限定为**语法/结构层**（与 `test_stop_chain.bats:6-7` 既有范式一致，该文件声明 stop 脚本采用"语法检查 + grep 关键函数名验证"）。运行时逻辑测试（source 脚本 + 调函数）属**逻辑层**，需 Claude Code 运行时环境（lib/common.sh 路径 hook 注入），由实际 hook 调用覆盖，不纳入 smoke。注：`bash -n`/grep 本就不依赖 source，"无法 source"是**逻辑层**测试的限制而非结构层 smoke 的理由——本设计选结构层是因为逻辑层已由 hook 覆盖
- **代价**：smoke 不验运行时行为（检查函数实际返回），运行时 bug 由 hook 调用暴露

### D3 · 无新 ADR
- 决策均可逆（改 target / 改 smoke 范围），无可逆性低决策 → 不立 ADR

## 2. 数据流

```
TD-010:
  make dup → command -v jscpd ─┬─ 已装 → jscpd --ignore brooks → stdout 报告 + exit 0
                              └─ 未装 → stderr "jscpd skipped" + exit 0

TD-002（范围明确 · L3-major）:
  读 test_stop_chain.bats（已覆盖 22/24/26/99 的 grep 关键函数 · **内容层**）+ test_smoke_syntax.bats（全 bash-n · **语法层已全覆盖 17 脚本**）
    → 语法层（bash-n）已全覆盖，无需再扫；缺口仅在**内容层**（grep 关键函数 smoke）
    → grep **仅针对 stop 脚本目录**（确认哪些主脚本已有 grep 关键函数 smoke · test_stop_chain 已覆盖 22/24/26/99）→ SUMMARY.md 17 行表（covered[有 grep 关键函数]|partial[仅 bash-n]|gap）
    → [business]+[partial/gap] → 补 grep 关键函数 smoke（沿用 test_stop_chain · D2）
    → 双源同步（test/ ↔ flow-kit-bundle/test/，diff -r 验证）
```

## 3. ADR

无（D3）。

## 4. 风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | jscpd 版本漂移致输出格式变（下游解析断）| 版本 ≠ 5.0.11 时 warn 不 fail；输出仅供人工（AC-1 NFR）|
| R2 | smoke 范围蔓延到脚本重构（改逻辑）| AC-3 止损条款：失败若需改逻辑 → skip + v2，不强制全绿 |
| R3 | 双源同步遗漏（test/ 改了 flow-kit-bundle/test/ 没改）| AC-3 `diff -r` 验证 + AC-7 双源一致 |
| R4 | 重复率静默退化（D1 代价：非 check 门禁，退化无自动信号）| 人工定期 `make dup` + v2 评估 `--threshold` 纳入 check |

## 5. 不在范围

- TD-004/005/008（其他技术债，见 REQUIREMENT out）
- lib 内部逻辑测试增强（lib 已有独立 test）

## 9. 架构沉淀建议

**本 change 无架构层面沉淀建议**。

`make dup` 约定已在 1-requirement 阶段写入 CONTEXT.md「已锁决策」（2026-07-09 条），无需额外 A-evolve 沉淀。无新可复用抽象 / 无跨模块契约 / 无依赖变动 / 无禁动清单变动。
