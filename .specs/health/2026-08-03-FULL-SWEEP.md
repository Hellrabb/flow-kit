# 全量 Sweep 巡检 · 2026-08-03

**模式**: 内置回退（brooks-lint 分析框架 + AI 诊断，不自动修复）| **范围**: flow-kit 全量（65 生产 `.sh` + 66 `.bats` 测试文件 + jscpd + shellcheck + bats）
**基线**: 2026-07-25 FULL-SWEEP = 98/100（连续两次稳定）

---

## 综合分

| 指标 | 值 |
|---|---|
| **本次评分** | **89/100**（内置回退 · AI 自评） |
| 上次 Full Sweep（2026-07-25） | 98/100 |
| 趋势 | **↓ 9 分**（新增 1 项 🔴 Critical · install_hooks 回归） |

**语法门禁**：74 个脚本 `bash -n` 全过 ✅（生产 65 + regression-demos 6 + 副本/参考 3）

**扣分明细**：

| # | 风险 | 级别 | 扣分 | 文件 | 备注 |
|---|------|------|------|------|------|
| 1 | install_hooks.sh:97 在 user scope 下引用未绑定 `PROJECT_DIR_NAME` → `set -u` 终止 → 4 个 bats 测试 fail + `--user` 安装链路断 | 🔴 | -10 | `flow-kit-bundle/lib/install_hooks.sh:97` | 由 commit `0c79f1c`（双平台拆分）引入，原硬编码 `$project/.claude/stop-hook.json` 被改为 `${project}/${PROJECT_DIR_NAME}/...`，但 `PROJECT_DIR_NAME` 仅由 `lib/paths.sh` 定义（install.sh 主入口 source），单元测试 + `--user` 模式直调不 source paths.sh |
| 2 | jscpd 5 个 Bash 样板相似块（6-11 行）— shebang/source-init 段 | 🟢 | -1 | 多文件（见冗余巡检） | 与 2026-07-25 同模式，非语义重复 |

---

## 语法门禁（步骤 2.6）

| 项 | 结果 |
|---|---|
| 扫描脚本数 | **74 个** `.sh`（生产 65 + regression-demos 6 + 参考/安装 3） |
| 语法错误 | **0** ✅ |
| 判定 | 全部通过，无阻断性语法问题 |

排除：`*/node_modules/*`、`*/.git/*`、`*/brooks-lint/plugin/*`、`*/brooks-tools/*`、`*/.claude/plugins/*`

---

## 冗余巡检（步骤 2.5）

**工具**: jscpd（npx · 一次性使用，按 TD-010 排除 brooks-lint/brooks-tools/test/regression-demos）+ AI grep fallback（未用导出 / 死代码）

### Bash 生产代码（hooks + lib + install.sh + package-flow-kit.sh · 53 文件 / 9391 行）

| 维度 | 🔴 | 🟡 | 🟢 | 元 |
|---|---|---|---|---|
| 字面重复块 | 0 | 0 | 5 | **0.37%** 重复率（35 dup lines / 9391）· 0.76% tokens |
| 死代码（不可达分支） | 0 | 0 | 0 | 无 `if false` / 裸 `return` 后语句 / 永假分支 |
| 未用导出（fk_/l2_/l3_ 函数） | 0 | 0 | 0 | 25 个公共函数全部有外部引用或测试引用 |
| 未用依赖 | n/a | n/a | n/a | 无 package.json / pyproject.toml（纯 Bash + Markdown 项目） |

**jscpd 5 个 Bash 克隆详情**（baseline 同模式 · 全部样板级）：

| # | 行数 | 文件 A | 文件 B | 类型 |
|---|------|--------|--------|------|
| 1 | 11 | `stop/lib/l2-detect.sh:111-121` | `stop/lib/l3-review.sh:234-239` | L2/L3 检测共享模式（与 07-25 相同） |
| 2 | 9 | `stop/27-interactive-ui-check.sh:26-34` | `stop/28-weak-model-compliance.sh:22-30` | 合规检查模块结构相似 |
| 3 | 7 | `pre-tool-use/auto-checkpoint.sh:63-69` | `pre-tool-use/independent-review-gate.sh:105-110` | PreToolUse hook 模板 |
| 4 | 7 | `pre-tool-use/gate-helpers.sh:69-75` | `pre-tool-use/gate-helpers.sh:85-91` | 同文件内部结构（gate-helpers-types 拆分副产品）|
| 5 | 6 | `stop/lib/common.sh:270-275` | `install_hooks.sh:66` | 跨核心/安装共享段 |

> 全部为样板代码级相似（shebang / source 初始化 / 错误处理模板 / 内部小重复），无业务逻辑重复。不需提取公共函数。

**Markdown**（jscpd 检测到的 brooks-lint 文档）：31.73% 重复率 → 中英翻译预期重复 · 🟢 非问题

### Fallback 维度（未跑 vulture/staticcheck —— Bash 项目不适用）

- **死代码 grep 抽样**：`if false` / `return; <代码>` / 注释代码块 — **0 命中** ✅
- **未用导出 grep**：25 个 `fk_/l2_/l3_` 函数全部有外部 ref 或 test ref ✅（其中 6 个仅测试引用：`fk_check_doc_only_diff`、`fk_classify_source_files`、`fk_file_nonempty`、`fk_flow_field`、`fk_validate_flow`、`fk_verify_finding_files` — 均合规）
- ⚠️ 标注：Bash 项目无标准化死代码工具（vulture/staticcheck 不适用），以上为 AI grep 抽样，精度低于专用工具

---

## 6 维生产代码风险（R1–R6 · 10 模块抽样 · 拆分后实际文件 ~4,303 行）

> 抽样原则：覆盖本周期改动最频繁的 5 模块（git log 排序）+ 拆分后新产生的关键 lib + 主编排器。

| # | 模块 | 行数 | 函数 | R1 | R2 | R3 | R4 | R5 | R6 |
|---|------|------|------|----|----|----|----|----|----|
| 1 | `flow-kit-artifacts.sh` | 374 | 10 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 2 | `weak-model-compliance.sh` | 353 | 8 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 3 | `common.sh` | 350 | 18 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 4 | `l2-detect.sh` | 302 | 4 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 5 | `fix-compliance.sh` | 302 | 6 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 6 | `l3-review.sh`（slim 编排器）| 239 | 4 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 7 | `interactive-ui-check.sh` | 237 | 6 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 8 | `l3-api.sh`（拆分新）| 222 | 5 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 9 | `l3-truncate.sh`（拆分新）| 202 | 3 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 10 | `independent-review-gate.sh`（slim）| 118 | 3 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |

**逐维分析**：

- **R1 认知负荷** 🟢：所有抽样模块函数粒度合理（平均 ~35 行/函数）。**重大改进**：原最大文件 `l3-review.sh` 875 行 → 拆为 5 文件（slim 239 + l3-prompt 155 + l3-api 222 + l3-truncate 202 + l3-done 99），`l3_review_run()` 从 307 行 → ~90 行编排器（调用 4 子函数）。原 `independent-review-gate.sh` 597 行 → 拆为 4 文件（slim 118 + gate-helpers 139 + gate-helpers-types 92 + gate-checks-basic 171 + gate-checks-review 93）。TD-008/017/018 全部闭合。
- **R2 变更传播** 🟢：拆分后扇入更分散 — slim 编排器依赖子 lib，子 lib 依赖 `common.sh`。所有模块通过 `common.sh` 星型拓扑共享基础设施。
- **R3 知识重复** 🟢：jscpd 0.37%（baseline 0.43% → 略降）。5 个克隆全为样板。拆分本身没引入新重复。
- **R4 意外复杂度** 🟢：无推测性抽象、无未使用的配置系统、无 middle-man 模式。严格 YAGNI。
- **R5 依赖失序** 🟢：拆分后依赖方向清晰 — lib 子模块（l3-prompt/api/truncate/done）→ l3-review slim 编排器 → hook 主模块（29/pre-tool-use）→ common.sh。无循环依赖（grep cycle 检测的 1 命中是 `l3-review.sh:152` 的自 source，bash 重定义函数无副作用，非真环）。
- **R6 领域模型失真** 🟢：拆分后命名一致（`_l3_*` 私有 / `l3_*` 公共 / `_gate_*` gate 内部），与 CONTEXT.md「函数命名前缀」表完全对齐。

**6 维生产代码无新发现风险** ✅。拆分整体优秀。

---

## 6 维测试代码风险（T1–T6 · 全量 66 个 .bats · 691 cases）

| 维度 | 结果 | 备注 |
|---|---|---|
| T1 测试可读性 | 🟢 | `@test` 描述清晰表达场景与预期，bats 惯例 |
| T2 测试脆性 | 🟢 | setup/teardown 隔离良好，验证行为而非实现细节 |
| T3 测试重复 | 🟢 | 共享 setup 已提取 helper（test_common_setup 等） |
| T4 Mock 滥用 | 🟢 | Bash 测试以真实 fs 操作为主，mock 极少 |
| T5 覆盖率幻觉 | 🟡 | **691 cases · 4 fail**（全部在 install_hooks DRY_RUN · 见 Critical #1）。但 `make test` 真实运行未掩盖，发现机制有效 |
| T6 架构匹配 | 🟢 | 单元 + smoke + 集成三层（test_common / test_stop_chain / test_hook_integration），金字塔比例健康 |

**测试全景**：
- 66 个 `.bats` 文件 · **691 个 @test cases**（+52 vs baseline 639）
- `make test` 实跑：**687 pass / 4 fail / exit 1**
- 4 fail 全部为 install_hooks DRY_RUN user scope（test 327/328/337/338） — 同一 root cause（Critical #1）
- `make lint`（shellcheck error level）：**0 errors** ✅
- 失败集中在 install_hooks.sh — 生产代码 bug，非测试代码 bug

**新增测试文件（自 baseline）**：
- `test_combined_metric.bats`（INT-COMBINED-1 token 测量）
- `test_task_brief.bats`
- `test_severity_format.bats`
- `test_scripts_security.bats`
- 其他 hooks/tests 同步更新

---

## 架构图（拆分后 · 2026-08-03）

```
flow-kit hooks 结构（拆分后）
─────────────────────────────────
stop/
├── 00-gate.sh ──────────── 编排器
├── 01-transcript-parse.sh
├── 20-claude-md.sh ─────── CLAUDE.md
├── 21-memory.sh
├── 22-git.sh
├── 23-quality.sh
├── 24-session.sh
├── 25-project.sh
├── 26-workflow.sh
├── 27-interactive-ui-check.sh
├── 28-weak-model-compliance.sh
├── 29-independent-review.sh ── L3 兜底
├── 30-ai-analyze.sh
├── 31-auto-advance.sh
├── 32-fallback-guard.sh
├── 33-flow-active-integrity.sh
├── 99-report.sh
└── lib/
    ├── common.sh (350) ──────── 共享基础设施 ★
    ├── flow-kit-artifacts.sh (374)
    ├── weak-model-compliance.sh (353)
    ├── l2-detect.sh (302)
    ├── fix-compliance.sh (302)
    ├── l3-review.sh (239) ────── slim 编排器 [拆分新]
    │   ├─ source → l3-truncate.sh (202) [拆分新]
    │   ├─ source → l3-prompt.sh (155) [拆分新]
    │   ├─ source → l3-api.sh (222) [拆分新]
    │   └─ source → l3-done.sh (99) [拆分新]
    ├── interactive-ui-check.sh (237)
    ├── transcript-parser.sh (128)
    ├── done-validation.sh (154)
    ├── banner.sh (126)
    ├── checkpoint-lib.sh (83)
    ├── correction-file.sh (145)
    └── correction-types.sh (24)

pre-tool-use/
├── independent-review-gate.sh (118) ─ slim 编排器 [拆分新]
│   ├─ source → gate-helpers.sh (139) [拆分新]
│   │   └─ source → gate-helpers-types.sh (92) [td072 拆分]
│   ├─ source → gate-checks-basic.sh (171) [拆分新]
│   └─ source → gate-checks-review.sh (93) [拆分新]
├── auto-checkpoint.sh (108)
└── runtime-edit-guard.sh (87) [0c79f1c 新增]

session-start/
├── flow-kit-resume.sh
└── stop-report-reminder.sh

lib/ (install)
├── install.sh
├── install_hooks.sh (214) ─── 🔴 含本次回归点
├── install_core.sh
├── install_skills.sh
├── install_brooks.sh
├── install_brooks_tools.sh
├── install_agents_md.sh
├── paths.sh [0c79f1c 新增 · PLATFORM/PROJECT_DIR_NAME 等共享变量]
└── validate_staging.sh
```

**依赖拓扑**：星型 — 所有模块 → `common.sh`（基础设施层）。无循环依赖。
**拆分收益**：原最大单文件 875 行 → 最大 374 行（flow-kit-artifacts.sh）。`l3_review_run()` 从 307 行 → ~90 行编排器。`is_gh_pr_create`（原 290 行）→ 拆为 4 个 gate-checks 文件。

---

## 自上次 Sweep 以来的变更（2026-07-25 → 2026-08-03）

**19 个 commits**（含归档），主要变更：

| 提交 | Change | 影响 |
|------|--------|------|
| `1506537` | `final-debt-cleanup-2026-08` | **重大**：一次性闭合 TD-008/017/018 三大拆分债（l3-review 875→5 文件 / independent-review-gate 597→4 文件）+ 7 项其他债 |
| `b7b6048` | `cleanup-debt-batch-2026-08` | L-072 fix + archive prior changes |
| `c5539a9` | `td072-lib-split-2026-08` | gate-helpers 进一步拆出 gate-helpers-types.sh（6 函数） |
| `ce482c4` | `test-failures-fixup-2026-08` | 修复 5 个 pre-existing bats 失败 + split-aware test 设计原则 |
| `123ca08` `276c0ac` | `debt-audit-resolve-2026-08` | 8+4 项流程规范债务闭合（含 TD-002/003/004/005/006/007 v2 deferred） |
| `1dca070` | `superpowers-v6-absorb`（部分归档） | 吸收 superpowers v6.0/6.1 经验（review-package / task-brief / severity gating / progress ledger） |
| `0c79f1c` | `feat(platform)` | 🔴 **本次回归源** — claude/opencode 双平台兼容安装器，引入 `lib/paths.sh` + `PROJECT_DIR_NAME` 变量；改写 install_hooks.sh L97 时未加 user-scope guard |

**统计**：19 commits · 文件大小分布健康化（最大 875 → 374）· 测试 +52 cases · 但 `0c79f1c` 引入回归未被自身测试捕获。

---

## 🔴 Critical 详情：install_hooks.sh:97 user-scope 回归

**位置**：`flow-kit-bundle/lib/install_hooks.sh:97`

**Bug 代码**：
```bash
install_file "$SCRIPT_DIR/hooks/config/stop-hook.json" "${project}/${PROJECT_DIR_NAME}/stop-hook.json"
```

**根因**（git log 精确定位）：
- `2e745b7`（2026-06-16 health-fix）原始代码：`"$project/.claude/stop-hook.json"` — 硬编码 `.claude`，两种 scope 都能跑
- `0c79f1c`（2026-08-03 platform-split refactor）改写为 `"${project}/${PROJECT_DIR_NAME}/stop-hook.json"` — `PROJECT_DIR_NAME` 由新增的 `lib/paths.sh` 定义（install.sh 主入口 source），但 install_hooks.sh 在以下两种调用路径下不会 source paths.sh：
  1. 单元测试直接 `source install_hooks.sh` → 变量未绑定 → `set -u` exit 1
  2. `install.sh --user` 走 user-scope 分支 → 同上

**症状**：
1. **4 个 bats 测试 fail**（test 327/328/337/338）：
   - `install_hooks DRY_RUN user scope: exit 0 and output contains [DRY-RUN]`
   - `install_hooks DRY_RUN user scope: mentions .claude/hooks`
   - `install_hooks DRY_RUN: no settings.json mutation`
   - `install_hooks DRY_RUN: output contains [DRY-RUN] messages`
2. **`install.sh --user` / `install.sh --project X --hooks-only --user` 链路断**（exit 1）
3. 副作用：runtime-edit-guard.sh 的安装（line 177-183）位于 L97 之后，因 L97 exit 永远不会执行 — 不仅是 user scope，**任何 scope 下 runtime-edit-guard.sh 都装不上**

**实测证据**（dry-run 输出截尾）：
```
[DRY-RUN] cp .../auto-checkpoint.sh -> /pre-tool-use/auto-checkpoint.sh
/home/.../install_hooks.sh: 行 97: PROJECT_DIR_NAME: 未绑定的变量
EXIT=1
```

**设计层根因**：
- `stop-hook.json` 是**项目级**配置开关（行内注释：`# 配置文件（项目级 stop-hook.json 开关）`），本就不该在 user scope 写
- 双平台拆分应同时加 `if [ "$scope" != "user" ]` 守卫，但被遗漏

**建议修复**（health-fix change 实施 · 本报告不改代码）：
```bash
# 配置文件（项目级 stop-hook.json 开关）
if [ "$scope" != "user" ]; then
  install_file "$SCRIPT_DIR/hooks/config/stop-hook.json" "${project}/${PROJECT_DIR_NAME}/stop-hook.json"
fi
```

**验证 AC**：
- `make test` exit 0，691/691 全绿
- 手跑 `install_hooks.sh` user scope dry-run exit 0
- 手跑 `install_hooks.sh` project scope dry-run 仍写出 stop-hook.json

---

## 技术债优先级

| 项 | Pain | Spread | 优先级 | 建议 |
|---|---|---|---|---|
| install_hooks.sh:97 user-scope 回归（本次 Critical） | 高 | 中（影响所有 --user 安装） | 🔴 **本月内修** | 加 scope 守卫；归入 health-fix-2026-08 change |
| runtime-edit-guard.sh 安装被 L97 阻断（Critical 副作用） | 中 | 低（依赖 L97 修复） | 🔴 **同 Critical** | L97 修复后自动恢复，无需独立动作 |
| jscpd 5 Bash 样板相似块 | 低 | 低 | 🟢 | 与 baseline 同模式 · Bash 生态固有 · 不处理 |

---

## 行动建议

- 🔴 **Critical · 本月内修**（1 项 · 合并 1 个 health-fix change）：
  1. **install_hooks.sh:97 user-scope 守卫**（同时解锁 runtime-edit-guard.sh 安装链路）→ 开 `health-fix-2026-08` change，2 行修复
- 🟡 **Scheduled · 本季度修**：无
- 🟢 **Monitored · 仅记录**（1 项）：
  1. jscpd Bash 样板相似（5 处 · 非语义重复 · 不处理，沿用 07-25 决议）

---

## 与上次对比

| 维度 | 2026-07-25 Full Sweep | 2026-08-03 Full Sweep（本次） |
|------|----------------------|---------------------------|
| 🔴 Critical | 0 | **1**（install_hooks 回归） |
| 🟡 Major | 0 | **0** |
| 🟢 Minor | 2 | **1**（jscpd 样板） |
| 综合分 | 98（自评） | **89（自评）** ↓ 9 |
| 语法门禁 | 63/0 | **74/0** ✅（+11 脚本，全过） |
| shellcheck | 未跑 | **0 errors** ✅ |
| bats 测试 | 639/0 | **691/4 fail** ⚠️（+52 cases，4 fail 同源 Critical） |
| bash jscpd 重复率 | 0.43% | **0.37%**（略降） |
| 生产最大单文件 | 875（l3-review.sh） | **374**（flow-kit-artifacts.sh） ✅ 大幅改善 |
| 公共函数未用导出 | 0 | **0** ✅ |
| 架构循环依赖 | 0 | **0** ✅ |

**趋势**: **↓ 退化**（-9 分）。退化原因单一 — commit `0c79f1c` 双平台拆分引入 install_hooks user-scope 回归。其他维度全部持平或改善：
- ✅ 拆分债（TD-008/017/018）全部闭合 — 最大文件 875 → 374
- ✅ 测试 +52 cases（691 vs 639）
- ✅ jscpd 略降（0.43% → 0.37%）
- ✅ shellcheck 0 errors
- ✅ 语法门禁 +11 脚本全过
- ⚠️ install_hooks 回归未被自身测试在 commit 时捕获（4 fail 测试已存在但被 commit 跳过验证）

**关键改进**（自上次 sweep）：
1. `final-debt-cleanup-2026-08`：一次性闭合 3 项重大拆分债（TD-008/017/018）+ 7 项其他债
2. `td072-lib-split-2026-08`：gate-helpers 进一步职责拆分
3. `debt-audit-resolve-2026-08`：闭合 12 项流程规范债
4. `superpowers-v6-absorb`：吸收 review-package / task-brief / severity gating / progress ledger 等优化
5. 测试覆盖 +52 cases

---

## 总结

本项目代码质量在 baseline 98/100 的极高水准上**首次出现退化**，退化为**单一可定位根因**：

- 🔴 Critical: **1**（install_hooks.sh:97 user-scope 回归，由 `0c79f1c` 引入）
- 🟡 Major: 0
- 🟢 Minor: 1（监控项）
- Bash 字面重复: 0.37%（持续低水平）
- 测试: 691/4-fail（4 fail 全同源 Critical）
- 语法门禁: 74/0 ✅
- shellcheck: 0 errors ✅
- 架构: 星型拓扑 · 无循环依赖 · 拆分后扇入更分散

**修复路径**：开 `health-fix-2026-08` change，2 行修复（加 `if [ "$scope" != "user" ]` 守卫），修复后预期回归 98~99/100。

**预防建议**（记录到 LESSONS）：
- 双平台拆分类重构必须**为每条路径分支验证两种 scope**（user/project），不能只测主入口
- `make test` 应作为 commit 前置硬门禁（`0c79f1c` 提交时 4 个 fail 测试已存在但被跳过验证）

**下次巡检建议**: 修复 Critical 后 1 个月（约 2026-09-03）

---

*巡检模式: 内置回退 · 评分: AI 自评（brooks-lint 分析框架） · 建议装 brooks-lint 获取标准化评分*
