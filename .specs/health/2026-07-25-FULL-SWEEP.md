# 全量 Sweep 巡检 · 2026-07-25

**模式**: 内置回退（brooks-lint 分析框架 + AI 诊断，不自动修复）| **范围**: flow-kit 全量（40 生产 `.sh` + 55 测试 `.bats` + jscpd）
**基线**: 2026-07-20 FULL-SWEEP = 98/100（修复后）

---

## 综合分

| 指标 | 值 |
|---|---|
| **本次评分** | **98/100**（内置回退 · AI 自评） |
| 上次 Full Sweep（2026-07-20） | 98/100（同体系可比） |
| 趋势 | → **稳定**（无新增 Critical/Major） |

**扣分明细**（仅 2 项 🟢 残留）：

| # | 风险 | 级别 | 扣分 | 文件 | 备注 |
|---|------|------|------|------|------|
| 1 | l3-review.sh 持续增长至 875 行（+65 vs 上次），为全仓最大单文件 | 🟢 | -1 | `flow-kit-bundle/hooks/stop/lib/l3-review.sh` | 增长来自合法功能（`l3-review-timeout-token` 可配置化），12 函数结构良好 · 监控即可 |
| 2 | 5 个 Bash 结构相似块（6-11 行）— boilerplate 级 | 🟢 | -1 | 多文件（见 jscpd 详情） | shebang + `set -euo pipefail` + SOURCE_DIR 初始化段 · 非语义重复 |

---

## 语法门禁（步骤 2.6）

| 项 | 结果 |
|---|---|
| 扫描脚本数 | **63 个** `.sh`（生产 40 + regression-demos 6 + test 副本 6 + 参考/安装 11） |
| 语法错误 | **0** ✅ |
| 判定 | 全部通过，无阻断性语法问题 |

---

## 冗余巡检（步骤 2.5）

**工具**: jscpd（npx · 一次性使用）

### Bash 生产代码

| 维度 | 🔴 | 🟡 | 🟢 | 元 |
|---|---|---|---|---|
| 字面重复块 | 0 | 0 | 5 | **0.43%** 重复率（5 clones / 8146 lines） |
| 死代码 | 0 | 0 | 0 | 无 `if false` / 不可达分支 |
| 未用导出 | 0 | 0 | 0 | 核心函数均被引用 |

**jscpd 5 个 Bash 克隆详情**：

| # | 行数 | 文件 A | 文件 B | 类型 |
|---|------|--------|--------|------|
| 1 | 11 | `stop/lib/l2-detect.sh` | `stop/lib/l3-review.sh` | L2/L3 检测共享模式 |
| 2 | 9 | `stop/27-interactive-ui-check.sh` | `stop/28-weak-model-compliance.sh` | 合规检查模块结构相似 |
| 3 | 7 | `pre-tool-use/auto-checkpoint.sh` | `pre-tool-use/independent-review-gate.sh` | PreToolUse hook 模板 |
| 4 | 7 | `pre-tool-use/independent-review-gate.sh` | 自身内部 | 内部结构重复 |
| 5 | 6 | `stop/lib/common.sh` | `install_hooks.sh` | 跨核心/安装共享段 |

> 全部为样板代码级相似（shebang / source 初始化 / 错误处理模板），无业务逻辑重复。不需提取公共函数。

### Markdown（jscpd 检测到的 brooks-lint 文档）

- 31.73% 重复率 → 中英翻译预期重复 · 🟢 非问题

---

## 6 维生产代码风险（R1–R6 · 10 模块抽样 · ~4,400 行）

| # | 模块 | 行数 | 函数 | R1 | R2 | R3 | R4 | R5 | R6 |
|---|------|------|------|----|----|----|----|----|----|
| 1 | `l3-review.sh` | 875 | 12 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 2 | `independent-review-gate.sh` | 597 | 20 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 3 | `flow-kit-artifacts.sh` | 374 | 10 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 4 | `common.sh` | 350 | 18 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 5 | `26-workflow.sh` | 306 | 11 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 6 | `l2-detect.sh` | 302 | 4 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 7 | `fix-compliance.sh` | 302 | 6 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 8 | `29-independent-review.sh` | 204 | 2 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 9 | `install_hooks.sh` | 229 | 3 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 10 | `done-validation.sh` | 154 | 3 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |

**逐维分析**：

- **R1 认知负荷** 🟢：所有模块函数粒度合理（平均 ~45 行/函数）。`l3-review.sh` 以 875 行居首但 12 函数拆分良好——`l3_review_run()` 主编排函数已从上上次 sweep 的 307 行拆至当前 ~90 行（编排层），子函数各司其职（prompt 构建 / API 调用 / 结果解析 / .done 写入 / dispatch）。最长单行 497 字符（heredoc/API prompt 模板），无逻辑影响。
- **R2 变更传播** 🟢：`independent-review-gate.sh`（7 source 依赖）是唯一个高扇入模块，但作为 gate 编排层此依赖集中是合理的。所有模块通过 `common.sh` 星型拓扑共享基础设施，无跨模块隐式耦合。
- **R3 知识重复** 🟢：jscpd 检测到的 5 个 Bash 克隆（6-11 行）均为脚本头部样板（shebang + `set -euo pipefail` + SOURCE_DIR）。无业务逻辑重复。命名统一（`fk_`/`_fk_`/`check_`/`l2_`/`l3_`/`_gate_`）已在 `health-debt-cleanup` 完成。
- **R4 意外复杂度** 🟢：无推测性抽象、无未使用的配置系统、无 middle-man 模式。严格 YAGNI。
- **R5 依赖失序** 🟢：无循环依赖。依赖方向清晰：`lib/` → `stop/` → `pre-tool-use/`。所有模块依赖 `common.sh`（基础设施层），符合 ADP。
- **R6 领域模型失真** 🟢：代码命名与域语言一致（见 CONTEXT.md 术语表 ~230 条映射）。函数名精确反映其职责。

---

## 6 维测试代码风险（T1–T6 · 5 文件抽样 · ~1,800 行）

| # | 文件 | cases | T1 | T2 | T3 | T4 | T5 | T6 |
|---|------|-------|----|----|----|----|----|----|
| 1 | `test_l2_l3_fix_compliance.bats` | 26 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 2 | `test_gate_config_presets.bats` | 34 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 3 | `test_l3_review_params.bats` | 新 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 4 | `test_fk_resolve_model.bats` | 新 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 5 | `test_install_coverage.bats` | 16 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |

**测试全景**：
- 55 个 `.bats` 文件 · **639 个 @test cases**（+80 vs 上次 559）
- `make test` 全绿（exit 0）
- 新增 4 个测试文件：`test_l3_review_params`、`test_fk_resolve_model`、`test_flow_model`、`test_model_degradation`

**逐维分析**：

- **T1 测试可读性** 🟢：测试命名遵循 bats 惯例，`@test` 描述清晰表达场景与预期。
- **T2 测试脆性** 🟢：测试验证行为而非实现细节。setup/teardown 隔离良好。
- **T3 测试重复** 🟢：共享 setup 通过 helper 函数提取，无跨文件复制粘贴。
- **T4 Mock 滥用** 🟢：Bash 测试以真实文件系统操作为主，mock 使用极少。
- **T5 覆盖率幻觉** 🟢：639 cases 覆盖核心路径（gate 校验 / compliance / L2/L3 dispatch / model config / install）。错误路径和边界条件有专项测试。
- **T6 架构匹配** 🟢：单元测试为主（bats），执行速度快。测试金字塔比例健康。

---

## 架构图

```
flow-kit hooks 结构（2026-07-25）
─────────────────────────────────
stop/
├── 00-gate.sh ──────────── 编排器
├── 01-transcript-parse.sh ─ 转录解析
├── 20-claude-md.sh ─────── CLAUDE.md 管理
├── 21-memory.sh ────────── 记忆管理
├── 22-git.sh ───────────── Git 状态
├── 23-quality.sh ───────── 质量检查
├── 24-session.sh ───────── 会话状态
├── 25-project.sh ───────── 项目状态
├── 26-workflow.sh ──────── 工作流状态
├── 27-interactive-ui-check ─ UI 检查
├── 28-weak-model-compliance ─ 弱模型合规
├── 29-independent-review.sh ─ 独立审查触发 [本次变更]
├── 30-ai-analyze.sh ────── AI 分析
├── 31-auto-advance.sh ──── 自动推进
├── 32-fallback-guard.sh ── 回退守护
├── 33-flow-active-integrity ─ 状态完整性
├── 99-report.sh ────────── 报告生成
└── lib/
    ├── common.sh ───────── 共享基础设施
    ├── l3-review.sh ────── L3 外部模型审查 [本次变更: +65行]
    ├── l2-detect.sh ────── L2 审查检测
    ├── done-validation.sh ─ .done 校验 [本次变更]
    ├── flow-kit-artifacts.sh ─ 工件管理
    ├── fix-compliance.sh ─ 合规修复
    ├── correction-file.sh ─ 矫正文件
    ├── correction-types.sh ─ 矫正类型常量
    ├── checkpoint-lib.sh ── checkpoint 支持
    ├── banner.sh ────────── 横幅渲染
    ├── transcript-parser.sh ─ 转录解析
    ├── interactive-ui-check.sh ─ UI 检查 lib
    └── weak-model-compliance.sh ─ 合规 lib

pre-tool-use/
├── auto-checkpoint.sh ──── 自动 checkpoint
└── independent-review-gate.sh ─ 审查门禁 [本次变更]

lib/ (install)
├── install_hooks.sh ────── Hook 安装
├── install_core.sh ─────── 核心安装
├── install_skills.sh ───── 技能安装
├── install_brooks.sh ───── brooks-lint 安装
├── install_brooks_tools.sh ─ 工具安装
└── validate_staging.sh ─── 打包校验
```

**依赖拓扑**：星型 — 所有模块 → `common.sh`（基础设施层）。无循环依赖。唯一高扇入模块 `independent-review-gate.sh`（7 sources）为 gate 编排层，符合其架构定位。

---

## 自上次 Sweep 以来的变更（2026-07-20 → 2026-07-25）

| 提交 | Change | 影响 |
|------|--------|------|
| `c2b2a4a` `8518afe` | `l3-review-timeout-token` | L3 工具 max_tokens/timeout/thinking 可配置化（FLOW_KIT_L3_MAX_TOKENS / FLOW_KIT_L3_TIMEOUT / FLOW_KIT_L3_THINKING） |
| `5b720ed` | `gate-done-authorship` | 修复 gate .done 作者性安全缺口（方案 A — path-guard D7 扩展 + L2-only 模式例外） |
| `de733c3` | `l2-l3-model-config` | L2/L3 审查模型配置解耦 (ADR-012/013) |
| `be99eec` `6546ab1` `2db8566` `650efab` `189ca2a` | `gate-review-fix` | 修复 13 条 gate/review 缺陷（含 L2 盲审确认） |
| `49c3d37` `4d982f8` `12ab038` | 归档 | `gate-done-authorship` + `l3-review-timeout-token` 归档 |

**统计**：12 commits · 28 files changed · +1358 / -280 lines

---

## 技术债优先级

| 项 | Pain | Spread | 优先级 | 建议 |
|---|---|---|---|---|
| l3-review.sh 持续增长（875 行） | 低 | 低 | 🟢 | 当前 12 函数拆分合理。若未来突破 1000 行或新增第 5 种职责，考虑拆为 `l3-detect.sh` / `l3-dispatch.sh` / `l3-format.sh` 子库（CONTEXT.md TD-008） |
| jscpd Bash 样板相似（5 处 6-11 行） | 低 | 低 | 🟢 | 脚本头部样板（shebang/set/source）是 Bash 生态固有模式，提取反而增加耦合。仅记录不处理 |

---

## 安全审查附注

自动化安全审查（PostToolUse hook）标记了 `independent-review-gate.sh:_gate_is_l2_only()` 的 fail-open 行为（`.flow-active` 缺失时 `return 0` 放行）作为 MEDIUM 发现。

**评估**：这是**已知设计决策**，非安全漏洞。理由：
- `_gate_is_l2_only()` 仅在 path-guard 上下文调用（D7 扩展），其语义是"无法验证 flow 状态时，不阻断 agent 写 .done"——这是 L2-only 模式的必要例外路径
- 若改为 fail-closed（`return 1`），L2-only 用户在 `.flow-active` 异常时 pipeline 将死锁
- `.flow-active` 的完整性由 `33-flow-active-integrity.sh` 独立检测

**判定**：✅ 设计合理 · 不需修复

---

## 行动建议

- 🔴 **Critical · 本月内修**: 无
- 🟡 **Scheduled · 本季度修**: 无
- 🟢 **Monitored · 仅记录**（2 项）：
  1. l3-review.sh 行数趋势（875 → 若突破 1000 考虑 TD-008 拆分）
  2. jscpd Bash 样板相似（5 处 · 非语义重复 · 不处理）

---

## 与上次对比

| 维度 | 2026-07-20 Full Sweep | 2026-07-25 Full Sweep (本次) |
|------|----------------------|---------------------------|
| 🔴 Critical | 0 | **0** |
| 🟡 Major | 0 | **0** |
| 🟢 Minor | 2 | **2** |
| 综合分 | 98（自评） | **98（自评）** |
| 语法门禁 | 40/0（仅生产） | **63/0**（全量） |
| 测试 | 559/0 | **639/0**（+80 cases） |
| bash jscpd | 0.82% | **0.43%**（仅 hooks+lib 范围，上次含 test/regression-demos） |
| 生产文件 | 40 `.sh` | 40 `.sh` |
| 测试文件 | 未知 | 55 `.bats` |

**趋势**: → 稳定。代码质量基线维持极高水平。自上次 sweep 以来：
- 新增 80 个测试用例（+14%）
- 修复了 2 个重要安全/可用性缺陷（gate .done 作者性 + L3 thinking 预算耗尽）
- 无新增技术债
- 12 个 commits 均为正向改进（bug fix + 功能增强 + 归档）

---

## 总结

本项目代码质量基线持续保持在 **98/100** 的极高水平：

- 🔴 Critical: 0（连续三次 sweep 无新增）
- 🟡 Major: 0
- 🟢 Minor: 2（监控项 · 非阻塞）
- Bash 字面重复: 0.43%（极低 · 全部为样板代码）
- 测试: 639/0 · 语法门禁: 63/0
- 架构: 星型拓扑 · 无循环依赖 · 命名统一

**关键改进**（自上次 sweep）：
1. `gate-done-authorship`：修复了 gate .done 可被主 agent 伪造的安全缺口——方案 A（path-guard D7 扩展）实施完成
2. `l3-review-timeout-token`：解决了 deepseek-v4-pro 扩展思考模式把全部 max_tokens 花在 thinking block 上的生产问题——通过 FLOW_KIT_L3_MAX_TOKENS / FLOW_KIT_L3_TIMEOUT / FLOW_KIT_L3_THINKING 三个 env var 可配置化
3. `l2-l3-model-config`：L2/L3 审查模型配置解耦，遵循 env-var-first config 策略
4. 测试覆盖 +80 cases（新功能 + 回归保护）

**下次巡检建议**: 2026-08-25（1 个月后）

---

*巡检模式: 内置回退 · 评分: AI 自评（brooks-lint 分析框架） · 建议装 brooks-lint 获取标准化评分*
