# DESIGN: gate-review-fix — 13 条缺陷修复技术设计

> 基于 L2 盲审确认的 `/code-review max` 报告（13 条成立/2 条推翻）

---

## 0. 技术栈选定

**锁定**（与 CONTEXT.md 已锁决策一致）：
- **语言/运行时**: Bash（`#!/bin/bash`，`set -euo pipefail`）
- **测试**: bats-core 1.13.0（`npx bats`）
- **静态分析**: shellcheck（error 级别，`-e SC1091`）
- **构建**: `package-flow-kit.sh`（Part A-G）

> 纯 CLI/脚本项目，无框架/DB/前端。跳过技术栈卡片选择。

---

## 0.5 既有架构对齐

### 0.5.1 本次 change 触碰的既有模块

基于 REQUIREMENT.md 的 AC 清单，实际会修改：

**源文件（7 个）**：
| 文件 | 路径 | 修改原因 |
|---|---|---|
| `l3-review.sh` | `flow-kit-bundle/hooks/stop/lib/` | AC-3, AC-4, AC-8, AC-11 |
| `l2-detect.sh` | `flow-kit-bundle/hooks/stop/lib/` | AC-4, AC-7, AC-13 |
| `independent-review-gate.sh` | `flow-kit-bundle/hooks/pre-tool-use/` | AC-6, AC-10, AC-12 |
| `common.sh` | `flow-kit-bundle/hooks/stop/lib/` | AC-12, AC-13（新增共享函数）|
| `done-validation.sh` | `flow-kit-bundle/hooks/stop/lib/` | AC-9, AC-12 |
| `29-independent-review.sh` | `flow-kit-bundle/hooks/stop/` | AC-12, AC-13 |

**测试文件（4 个，双源同步）**：
| 文件 | 路径 | 修改原因 |
|---|---|---|
| `test_l3_timeout.bats` | `test/` + `flow-kit-bundle/test/` | AC-1 |
| `done-validation.bats` | `test/` + `flow-kit-bundle/test/` | AC-2 |
| `test_l2_l3_granular_gate.bats` | `test/` + `flow-kit-bundle/test/` | AC-5 |
| `test_l3_review.bats` | `test/` + `flow-kit-bundle/test/` | AC-3 |

**不应触碰**：
- `package-flow-kit.sh`（禁动清单）
- `flow-kit-bundle.tar.gz`（禁动清单）
- `install_hooks.sh`（PreToolUse matcher，禁动清单）
- `fk_auto_phase()` 等 gate 主逻辑（与本次无关）

### 0.5.2 沿用既有抽象

| 本次需要 | 既有 | 决定 |
|---|---|---|
| phase→gate_key 映射 | `common.sh::PHASE_GATE_KEY_MAP` / `fk_phase_gate_key()` | 沿用（AC-9 使用） |
| phase 解析 | `common.sh::fk_resolve_phase()` | 沿用（AC-10 使用） |
| done 真实性校验 | `done-validation.sh::fk_validate_done_marker()` | 沿用（AC-2 测试覆盖） |
| L2 检测 | `l2-detect.sh::l2_detect_missing()` | 沿用，不新增检测函数 |
| L3 API 调用 | `l3-review.sh::l3_review_run()` | 沿用，仅修改子函数 |
| gate 编排 | `independent-review-gate.sh::_run_review_gates()` | 沿用，仅修改 _gate_check_l3 |

### 0.5.3 沿用模式 vs 引入新模式

| 决策 | 选择 | 理由 |
|---|---|---|
| 共享函数放置 | **沿用** `hooks/stop/lib/common.sh` + `l2-detect.sh` | 遵循现有 lib 层约定；`fk_*` 公共函数放 common.sh；L2 特化函数放 l2-detect.sh |
| 函数命名 | **沿用** `fk_` 前缀（公共 API）+ `_` 前缀（模块私有） | CONTEXT.md 命名约定 |
| 临时文件 | **引入新模式** `mktemp` 替代 `.tmp.$$` 手工构造 | AC-4 要求消除竞态；mktemp 是 POSIX 标准方案 |
| 错误处理 | **沿用** `return $rc` + stderr 日志模式 | AC-8 要求显式 rc 传播 |
| Bash regex | **沿用** "变量存 regex" 风格（`local re='...'; [[ "$x" =~ $re ]]`） | CONTEXT.md 已锁决策（TD-011 教训） |

---

## 1. 技术决策

### D1 · 共享函数放置策略

- **决策**：`fk_normalize_gate_val()` → `common.sh`；`fk_extract_l2_verdict()` → `l2-detect.sh`
- **备选**：全部放 `common.sh` → 但 `fk_extract_l2_verdict` 的 heading-style fallback 逻辑紧耦合 L2 审查格式，放 `l2-detect.sh` 更内聚
- **理由**：`fk_normalize_gate_val` 是通用 gate 值标准化（4 consumer 跨 3 文件），放 common.sh 自然；`fk_extract_l2_verdict` 是 L2 特化逻辑（3 consumer 均在 L2/L3 上下文），放 l2-detect.sh 保持模块内聚
- **代价**：consumer 需 source 两个不同文件（但现有代码已 source 两者）

### D2 · `.tmp.$$` 竞态修复方案

- **决策**：统一用 `mktemp` 替代所有手工 `.tmp.$$` 构造
- **备选**：加不同前缀（`.tmp.l2mock.$$` / `.tmp.l2bg.$$` / `.tmp.l3.$$`）→ 仍依赖 PID 唯一性，不如 mktemp 原子安全
- **理由**：`mktemp` 是 POSIX 标准，保证原子创建 + 唯一文件名；消除所有同名竞态窗口
- **代价**：3 处替换（l2-detect.sh:113, l2-detect.sh:234, l3-review.sh:459），每处 ~3 行改为 mktemp + trap cleanup

### D3 · L3 段去重实现位置

- **决策**：在 `_l3_parse_result` 中，追加新 L3 段前用 sed 删除旧 `## L3 (盲审|重审)` 段
- **备选**：在 `_l3_write_done` 中去重 → 但去重应在 parse 阶段做，write 阶段只写
- **理由**：AC-3 要求"追加前删除旧 L3 段，文件中仅保留 1 个 L3 段"；sed 删除是 bash 中最轻量的方案
- **代价**：sed 操作依赖 `## L3 ` header 格式约定；需确认下游 reader（`_l3_inject_context`、SessionStart banner）兼容

### D4 · `_l3_write_done` 错误传播

- **决策**：移除 `|| true`，改为 `case $rc in 0) ;; 1) log+return 0 ;; 3) log+return 3 ;; *) log+return $rc ;; esac`
- **备选**：仅移除 `|| true` 不加 default case → AC-8 的 R4 发现指出需 default 分支
- **理由**：AC-8 要求显式 rc 处理 + 防御性 default 分支
- **代价**：调用方 `l3_review_run` 需处理非零返回值

### D5 · `_gate_check_l3` auto_advance 兼容

- **决策**：else 分支（lines 373-379）增加 auto_advance 检测：`auto_advance=true` 时 `return 1` 触发 `_gate_do_transition`（L3 dispatch），不 `exit 2` 硬阻塞
- **备选**：新增独立 dispatch 函数 → 过度工程，`return 1` 是 `_gate_check_l3` 已有的"L3 not done → caller dispatches"合约（line 406 已有 `return 1`，caller `_gate_phase_transition:463-464` 用 `|| _gate_do_transition` 消费）
- **理由**：
  - `_gate_check_l2:290-302` 已有 auto_advance 非阻塞模式（派发 Agent + return 0）
  - `_gate_check_l3:406` 已用 `return 1` 表示"L3 not done"，caller 以 `|| _gate_do_transition` 处理
  - 无需新增退出码或函数——复用现有合约即可
  - 代码变更：在 else 分支 `exit 2` 之前插入 auto_advance 检测（读 `.flow-active.goal.auto_advance`），true 则 `echo >&2` + `return 1`
- **代价**：auto_advance=true 时 L2 agent 可能尚未写完 L2 段，`_gate_check_l3` 会走到 else 分支；此时 `return 1` 触发 `_gate_do_transition`，输出"L3 未完成"提示但不阻塞 transition——与 L2 auto_advance 的 fire-and-forget 语义一致

### D6 · 测试修复策略

- **决策**：修复现有测试的覆盖盲区（AC-1/2/5），不新增测试文件
- **理由**：CHANGE.md 明确 out="不新增 bats 测试文件"
- **代价**：仅修 existing tests，不增加新覆盖范围

---

## 2. 数据流 / 修改影响图

```
AC-12 (fk_normalize_gate_val)
  common.sh [NEW] ───→ independent-review-gate.sh:456
                   ├──→ 29-independent-review.sh:134,174
                   └──→ done-validation.sh:66

AC-13 (fk_extract_l2_verdict)
  l2-detect.sh [NEW] ──→ independent-review-gate.sh:421
                      ├──→ 29-independent-review.sh:181
                      └──→ l3-review.sh:755

AC-4 (.tmp.$$ → mktemp)
  l2-detect.sh:113 ──  mock 模式临时文件
  l2-detect.sh:234 ──  后台 dispatch 临时文件
  l3-review.sh:459  ──  L3 前台临时文件

AC-3 (L3 段去重)
  l3-review.sh::_l3_parse_result ──→ INDEPENDENT-REVIEW-N.md (sed 删除旧段 → 追加新段)
                                 ──→ _l3_inject_context (读取)
                                 ──→ SessionStart banner (显示)

AC-8 (错误传播)
  l3-review.sh::_l3_write_done ──→ l3_review_run (调用方处理 rc)

AC-6 (auto_advance)
  independent-review-gate.sh::_gate_check_l3 ──→ _run_review_gates

AC-7 (mkdir -p)
  l2-detect.sh::l2_dispatch_agent ── 前置 mkdir -p "$specs_dir"

AC-9 (fk_phase_gate_key)
  done-validation.sh::fk_independent_review_gate_active ── 内联 case → fk_phase_gate_key()

AC-10 (fk_resolve_phase)
  independent-review-gate.sh::_gate_phase_filter ── 内联逻辑 → fk_resolve_phase()

AC-11 (fallback 路径)
  l3-review.sh::_l3_build_prompt ── BASH_SOURCE[0]/../common.sh (去掉多余 lib/)
```

---

## 3. ADR

本 change 不引入新的不可逆架构决策。所有修改均在 ADR-005（独立审查体系）框架内，属 bugfix + DRY 重构。

> 无需新增 ADR 文件。

---

## 4. 风险

| # | 风险 | 类型 | 缓解 |
|---|---|---|---|
| R1 | `fk_normalize_gate_val` 语义未对齐导致 gate 误判 | 实现风险 | AC-12 已明确完备语义（L2/L3/both 直通）；4 consumer 逐个迁移 + bats 验证 |
| R2 | `fk_extract_l2_verdict` heading fallback 逻辑遗漏 | 实现风险 | AC-13 要求含 heading-style fallback；对照 done-validation.sh:173-174 现有逻辑 |
| R3 | 共享函数引入后 consumer 遗漏更新 | 回归风险 | AC-NF1 要求 grep 验证旧 pattern 零匹配 + 新函数 ≥4/≥3 处调用 |
| R4 | L3 段去重 sed 破坏文件格式 | 数据风险 | AC-3 含下游 reader 兼容性验证；bats 测试覆盖 |
| R5 | mktemp 在 CI 环境不可用 | 上线风险 | mktemp 是 POSIX 标准，Linux/macOS 均有；如不可用则 fallback 到前缀方案 |
| R6 | `_gate_check_l3` return 1 语义被误解为"gate fail" | 实现风险 | 确认 `_run_review_gates` 调用方对 return 1 的处理；AC-6 明确"不阻塞 transition" |

---

## 5. 不在范围内

- L2 dispatch 从 PreToolUse 移出的架构决策（CHANGE.md out）
- PROJECT_ROOT 防御性显式化（L2 判定为"脆弱但非 bug"）
- `.done` 文件 heredoc 改为 printf（L2 判定为"防御性加固"）
- 新增 bats 测试文件（只修复现有）
- 修改 `L2-blind-review.md` prompt 模板
- 修改 gate 架构（gate 顺序/框架抽象）

---

## 9. 架构沉淀建议

### 9.1 新增可复用抽象

| 抽象 | 位置 | 签名 | 复用场景 |
|---|---|---|---|
| `fk_normalize_gate_val()` | `common.sh` | `fk_normalize_gate_val <raw_value>` → stdout | 任何需要标准化 gate_config 值的地方（未来新增 gate consumer） |
| `fk_extract_l2_verdict()` | `l2-detect.sh` | `fk_extract_l2_verdict <review_md_path>` → stdout（pass/fail/""） | 任何需要从 INDEPENDENT-REVIEW-N.md 提取 L2 verdict 的地方 |

### 9.2 项目级技术决策

- **临时文件策略**：全项目统一用 `mktemp` 替代手工 `.tmp.$$` 构造（本次仅修 3 处已知竞态点，其余 `.tmp.$$` 用法的迁移留给后续 sweep）

### 9.3 跨模块契约

- `fk_normalize_gate_val()` 输出契约：`independent|true → both` / `L2|L3|both → 原值` / 其他 → `""`（空字符串）
- `fk_extract_l2_verdict()` 输出契约：`pass` / `fail` / `""`（未找到），含 heading-style fallback

### 9.4 依赖变动

无（不新增外部依赖，mktemp 是 POSIX 标准工具）

### 9.5 禁动清单变动

无需新增禁动项。以下既有禁动项继续有效：
- `independent-review-gate.sh` + `29-independent-review.sh` + `fk_validate_done_marker` — gate 校验核心链
- 禁止直接 `jq -r '.phase'` — 用 `fk_resolve_phase()`
- `l3-review.sh` — 不允许绕过直接调 curl API
- gate_config 值 — 不允许写入 `independent`（已废弃）
