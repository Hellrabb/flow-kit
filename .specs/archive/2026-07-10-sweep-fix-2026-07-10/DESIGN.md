# DESIGN: 2026-07-10 Full Sweep 统一清理

- **Change ID**: `sweep-fix-2026-07-10`
- **关联**: `@.specs/sweep-fix-2026-07-10/REQUIREMENT.md`、`@.specs/sweep-fix-2026-07-10/CHANGE.md`、`@.specs/CONTEXT.md`
- **基线评分**: 65/100 → 目标 ≥80

---

## 0. 技术栈选定

- **语言/运行时**: Bash (`set -euo pipefail`)，与项目既有栈一致（CONTEXT.md 已锁定）
- **测试**: bats-core 1.13.0 (`npx bats`)，462 tests baseline 全绿
- **关键依赖**: `jq` (JSON)、`curl` (L3 API)、`stat` (文件 mtime)
- **理由**: 纯 Bash 脚本分发包仓库，CONTEXT.md 已锁定技术栈，本次无新栈引入
- **明确排除**: 不适用（CLI/lib 项目，跳过技术栈选型）

---

## 0.5 既有架构对齐（brownfield · 来自代码实测）

### 0.5.1 本次 change 触碰的既有模块

```
维护源 (flow-kit-bundle/，唯一维护源):

修改:
- flow-kit-bundle/hooks/stop/lib/l3-review.sh           (26.1K, 598 行) — AC-1
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh  (391 行) — AC-2
- flow-kit-bundle/hooks/stop/lib/common.sh              (10.1K, 258 行)  — AC-3, AC-4
- flow-kit-bundle/hooks/stop/20-claude-md.sh            — AC-3 (check_enabled 迁移)
- flow-kit-bundle/hooks/stop/21-memory.sh               — AC-3
- flow-kit-bundle/hooks/stop/22-git.sh                  — AC-3
- flow-kit-bundle/hooks/stop/23-quality.sh              — AC-3
- flow-kit-bundle/hooks/stop/24-session.sh              — AC-3
- flow-kit-bundle/hooks/stop/25-project.sh              — AC-3
- flow-kit-bundle/hooks/stop/26-workflow.sh             — AC-3
- .specs/CONTEXT.md                                     — AC-5, AC-6
- .specs/sweep-fix-2026-07-10/CHANGE.md                 — TD-018 描述修正

新增:
- test/test_install_dry_run.bats                         — AC-7

禁动清单（本次不碰）:
- independent-review-gate.sh gate 校验顺序（禁动清单要求"不允许在中间插入其他逻辑"——本次遵守，_gate_* 顺序与原始一致）
- l3-review.sh 的其他函数（l3_review_with_timeout / l3_dispatch_prompt / l3_write_timeout_done 保持不变）
- correction-file.sh / checkpoint-lib.sh / HOOK_MODULE_NAMES（本次不修改）
```

### 0.5.2 既有抽象复用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| check 启用/禁用 guard | `common.sh::check_enabled()` (L30-40) | **沿用**：run_check() 内部调用 |
| 模块输出 | `common.sh::module_output()` (L128-133) | **沿用**：check_*_body 直接调用 |
| 模块级启用 | `common.sh::module_enabled()` (L22-27) | **沿用**：各模块入口不变 |
| L3 审查编排 | `l3-review.sh::l3_review_run()` | **重构**：拆为 4 子函数 + 编排器，签名不变 |
| Gate 检查管线 | `independent-review-gate.sh` 主逻辑 (L106-391) | **重构**：提取 7 `_gate_*` + `_run_review_gates()` |
| gate 谓词函数 | `is_phase_write` / `is_git_commit` / `is_gh_pr_create` | **沿用**：3 个简洁谓词不拆分 |
| DRY_RUN 支持 | `install_brooks.sh:29` / `install_hooks.sh:8,93,134,175` | **沿用**：已有完整 DRY_RUN，仅补测试 |
| _grep 兼容层 | `fix-compliance.sh:20` | **沿用**：防御性 shim，不修改 |

### 0.5.3 沿用模式 vs 引入新模式

```
- Hook 模块架构：**沿用** numbered chain (00-33) + lib/ 共享函数库（ADR-003）
- check 函数模式：**沿用** check_enabled → read → evaluate → module_output 四阶段（新增 run_check() 消除重复，不改模式）
- L3 审查调用：**沿用** l3_review_run() 签名 + l3_review_with_timeout() 包装
- PreToolUse gate：**沿用** 7 步顺序检查管线（仅提取为命名函数，不改顺序/逻辑）
- 数据传递：**沿用** stdout 捕获（与现有 _fk_phase_direction 风格一致）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | `l3_review_run()` 拆为 4 子函数 + 编排器，全部留在 `l3-review.sh` 同一文件 | 拆文件（TD-008 方案）| 函数级拆分解决当前最大痛点（307→50行编排器），拆文件留给 TD-008 独立 change | 文件仍 ~610 行；但函数职责清晰、可独立测试 |
| D2 | `independent-review-gate.sh` 主逻辑提取为 7 `_gate_*` + `_run_review_gates()` 编排器 | 不拆（维持原样）| 290→40行编排器显著降低认知负荷；禁动清单要求"不允许在中间插入其他逻辑"——_gate_* 顺序严格保持 | `_gate_phase_transition` ~179行仍偏大，但 L2+L3 逻辑紧密耦合不宜再拆（ADR-002）|
| D3 | `run_check()` 放在 `common.sh`，紧接 `check_enabled()` 之后 | 独立 lib 文件 | common.sh 已被所有 hook 模块 source；`run_check()` 是 `check_enabled()` 的自然升级，就近放置 | common.sh 增加 ~10 行 |
| D4 | `run_check()` 第三参数仅支持 `precondition_file`（文件存在性检查），不支持任意命令 | 支持 `precondition_cmd`（eval 执行）| YAGNI：30 个 check 无一需要任意命令；eval 引入安全风险 | 若未来需要可在不破坏 API 下加第 5 参数 |
| D5 | `_grep` 保留不修改 | 移除 | `_grep` 是 Claude Code 环境防御性 shim（ugrep alias 不支持 `-P`），非死代码。**证据**：宿主机 `ugrep` 未安装；GNU grep 3.11 正常；`grep -P` 在宿主机可用。但在 CC 运行时环境中 `grep` 被 alias 到 ugrep（不支持 `-P`），`_grep() { command grep "$@"; }` 绕过此 alias。Claude Code 环境中移除会导致 fix-compliance.sh 的 `-oP` flag 失败 | 无代码变更 |
| D6 | `write_failed_state` 直接删除 + CONTEXT.md 条目更新 | 标记 deprecated 保留一版本 | 全仓 0 调用，21 行死代码无保留价值 | 若未来有失败状态持久化需求需从头实现 |
| D7 | `check_*_body` 命名约定（如 `check_c1_body`）| 其他命名（如 `_check_c1_impl`）| 与现有 `check_*` 前缀一致，`_body` 后缀明确表示内部实现 | 30 个新函数名，搜索结果噪音轻微增加 |

---

## 2. 架构变更图

### 2.1 l3-review.sh 重构后结构

```
l3-review.sh (598 → ~610 行, 10 函数)
├── _l3_format_result()          [不变]
├── smart_truncate()             [不变]
├── _l3_build_prompt()           [NEW · ≤80行]
├── _l3_call_api()               [NEW · ≤35行]
├── _l3_parse_result()           [NEW · ≤80行]
├── _l3_write_done()             [NEW · ≤55行]
├── l3_review_run()              [重构为编排器 · ≤50行]
├── l3_review_with_timeout()     [不变]
├── l3_write_timeout_done()      [不变]
├── l3_dispatch_prompt()         [不变]
```

### 2.2 independent-review-gate.sh 重构后结构

```
independent-review-gate.sh (391 → ~420 行)
├── 辅助谓词函数 (L23-103)        [不变]
│   ├── is_handshake_write()         [3行谓词]
│   ├── fk_check_gate_config_tamper() [16行]
│   ├── is_phase_write()             [18行]
│   ├── _fk_phase_direction()        [8行]
│   ├── is_git_commit()              [2行]
│   └── is_gh_pr_create()            [3行 · 不拆]
├── _gate_path_guard()           [NEW · ~18行]
├── _gate_phase_filter()         [NEW · ~9行]
├── _gate_active_check()         [NEW · ~7行]
├── _gate_done_validation()      [NEW · ~7行]
├── _gate_tamper_detect()        [NEW · ~11行]
├── _gate_phase_transition()     [NEW · ~179行]
├── _gate_deny_reason()          [NEW · ~18行]
├── _run_review_gates()          [NEW 编排器 · ≤40行]
└── main entry block             [精简为 ~20行]
```

### 2.3 check_* 模块迁移后结构（以 22-git.sh 为例）

```
22-git.sh (223 → ~240 行)
├── module_enabled "git"         [不变]
├── check_c1_body()              [NEW · 从 check_c1 提取逻辑]
├── check_c1() { run_check ... } [重构 · 1行]
├── check_c2_body()              [NEW]
├── check_c2() { run_check ... } [重构]
├── check_c3_body()              [NEW]
├── check_c3() { run_check ... } [重构]
├── check_c4_body()              [NEW]
├── check_c4() { run_check ... } [重构]
└── check_c1; check_c2; ...      [调用点不变 · 模块末尾]
```

### 2.4 run_check() 数据流

```
check_c1()                          ← 模块调用入口（1行包装）
  └─ run_check "git" "C1" "" check_c1_body
       ├─ check_enabled "git" "C1"  ← 沿用现有 guard（common.sh）
       ├─ [[ -f "$HOOK_TMP_DIR/..." ]] ← precondition（可选，仅当第3参数非空）
       └─ check_c1_body             ← 实际逻辑（同文件内函数引用）
            ├─ ... read state ...
            ├─ ... evaluate ...
            └─ module_output "info" "C1" "msg"  ← 沿用现有输出（common.sh）
```

---

## 4. ADR 索引

### ADR-001 · l3_review_run 子函数数据传递：stdout 捕获

- **Context**: l3_review_run 拆分为 4 子函数后，需传递 prompt_text、JSON content、verdict、summary
- **Decision**: prompt_text 和 content 用 stdout 捕获 (`var=$(_l3_build_prompt ...)`)；`_l3_parse_result` 通过 stdout 输出 `VERDICT=<v>\nSUMMARY=<s>` 格式，编排器解析
- **Alternatives**: 全局变量（`set -e` 下可能被意外清空）；临时文件（I/O 开销 + 清理负担）
- **Consequences**: jq `--arg` 可安全处理特殊字符；格式解析简单可靠

### ADR-002 · _gate_phase_transition 不进一步拆分

- **Context**: `_gate_phase_transition` ~179 行是最长的提取函数
- **Decision**: 保持为一个函数，不拆为 `_gate_l2_wait` + `_gate_l3_dispatch`
- **Reasons**: L2 和 L3 逻辑紧密耦合（L2 完成状态决定 L3 派发）；拆分需额外状态传递和重复 gate_config 读取；禁动清单要求"不允许在中间插入其他逻辑"
- **Consequences**: ~179行块偏大但逻辑连贯；AC-2 已满足（≥4 _gate_* 函数 + ≤40行编排器）

### ADR-003 · run_check() 不支持 precondition_cmd

- **Context**: REQUIREMENT.md 描述 `run_check(name, enabled_check, condition, message)` 含 4 参数
- **Decision**: 仅支持 precondition_file（相对 HOOK_TMP_DIR 的文件名），不支持任意 condition 命令
- **Reasons**: YAGNI——30 个 check 无一需要任意命令，所有前置条件都是文件存在性检查
- **Consequences**: 若未来需要可在不破坏 API 下加第 5 参数或通过 BODY_FUNCTION 自行处理

### ADR-004 · check_*_body 命名约定

- **Context**: 迁移后每个 check 拆为 1 行包装 + body 函数
- **Decision**: body 命名为 `check_<id>_body`（如 `check_c1_body`）
- **Reasons**: 与现有 `check_*` 前缀一致，`_body` 后缀明确内部实现，可搜索性保持
- **Consequences**: 30 个新函数名，grep 结果中 body 函数与原包装函数相邻

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | l3_review_run 拆分破坏 L3 审查流 | L3 审查静默失败，pipeline 可能跳过门禁 | 中 | 全量 bats 回归（test_l3_review / test_fix_l3_gate / test_l2_l3_fix_compliance 覆盖 pass/fail/timeout/api_error 四路径）|
| R1b | PreToolUse 重构引入性能退化 | 每次 tool call 增加延迟 | 低 | 拆分前后各跑 10 次 `time bash -c 'source independent-review-gate.sh && _run_review_gates'` 取中位数对比（REQUIREMENT NFR 要求 ±5% 容差）；bats smoke test 确认总延迟可接受 |
| R2 | gate 重构破坏 PreToolUse 拦截 | phase transition 绕过独立审查 | 中 | gate-integrity bats（18 tests + D8 tamper 检测）全部通过；手工 PreToolUse smoke test |
| R3 | run_check() 迁移引入个别 check 行为偏差 | 某 hook 模块输出不一致 | 低 | 每模块有对应 bats 覆盖；迁移为机械操作（仅删 guard 行，不改逻辑）|
| R4 | _gate_phase_transition 179 行可维护性 | 后续修改该 block 仍需理解全函数 | 低 | AC-2 已达成；进一步拆分的收益为负（见 ADR-002）；文档注释标注各子段 |
| R5 | DRY_RUN 测试环境差异 | CI 环境缺少依赖导致测试 skip/fail | 低 | DRY_RUN 模式不执行实际安装，仅验证输出和副作用；不依赖外部工具 |
| R6 | `is_gh_pr_create` 描述修正延迟 | 后续维护者基于错误描述查找错误目标 | 低 | CHANGE.md 已修正；DESIGN.md 明确标注 correction |

---

## 6. 不在范围

- TD-008 `l3-review.sh` 按职责拆文件（574 行拆为 `l3-detect.sh` / `l3-dispatch.sh` / `l3-truncate.sh`）
- `install_hooks()` / `install_brooks_lint()` 函数体拆分
- 批量重命名：按 AC-5 文档规则落地到代码（`_fai_*` → 统一前缀）
- CONTEXT.md「既有抽象索引」全量审计
- `_gate_phase_transition()` 进一步拆分（见 ADR-002）
- DRY_RUN 测试扩展至部分安装/重复安装场景

---

## 9. 架构沉淀建议

### 9.1 新增可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `common.sh::run_check()` | check 统一包装（guard + precondition + body dispatch）| 新增 hook check | 所有 stop hook 模块新增 check 时使用 |
| `l3-review.sh::_l3_build_prompt()` | L3 prompt 构造（按 phase 收集 artifact + checklist）| L3 审查 | — |
| `l3-review.sh::_l3_call_api()` | L3 API 调用（双路径）| L3 审查 | — |
| `l3-review.sh::_l3_parse_result()` | L3 响应解析（重审检测 + 三层 verdict 提取 + 降级）| L3 审查 | — |
| `l3-review.sh::_l3_write_done()` | L3 .done 写入（含 D3 both 检查）。**跨模块契约**：必须遵守 ARCHITECTURE.md §4.1 的 6 键 KVP 格式（phase / change_id / written_by / L2_verdict / L3_verdict / artifacts），否则 `fk_validate_done_marker` 拒绝放行 → pipeline 死锁 | L3 审查 | — |
| `independent-review-gate.sh::_run_review_gates()` | Gate 编排器（7 步管线）| PreToolUse gate | — |

### 9.2 新增项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| `_grep` 保留 | KEEP（防御性 shim）| fix-compliance.sh | 低：移除后 CC 环境中 `-P` regex 可能失败 |
| `write_failed_state` 移除 | REMOVED（死代码）| common.sh | 低：未来如需失败状态持久化可重新实现 |
| `is_gh_pr_create` 不拆分 | 3 行谓词保持不变 | independent-review-gate.sh | 低：若未来需要扩展 gh CLI 检测可在此函数内加判断 |
| `run_check()` 不与 precondition_cmd | YAGNI，仅支持文件检查 | common.sh | 低：加第 5 参数即可扩展 |

### 9.3 新增命名约定（追加到 CONTEXT.md § 命名约定）

| 前缀 | 含义 | 可见性 | 使用场景 |
|---|---|---|---|
| `fk_` | flow-kit 公共 API | 跨文件可调用 | 被多个模块/脚本调用的导出函数 |
| `_fk_` | flow-kit 模块私有 | 文件内可见 | 当前文件内部辅助函数 |
| `check_` | hook check 入口 | 模块内 | Stop hook 检查入口，现统一通过 `run_check()` 调用 |
| `l2_` / `_l2_` | L2 审查相关 | 跨文件 / 文件内 | L2 审查检测/派发函数 |
| `l3_` / `_l3_` | L3 审查相关 | 跨文件 / 文件内 | L3 审查 API/派发 + L3 子步骤函数 |
| `_gate_` | Gate 检查步骤 | independent-review-gate.sh 内部 | 独立 gate 检查步骤函数 |
| `_fai_` | (遗留，待统一) | 文件内 | 旧 flow-kit-artifacts.sh 内部函数，v2 统一为 `_fk_` |

### 9.4 禁动清单变化

```
- 新增禁动：common.sh::run_check() 签名——修改需同步 6 模块
- 新增禁动：independent-review-gate.sh::_gate_*() 7 函数顺序——不可重排
- 新增禁动：l3-review.sh::_l3_*() 4 子函数返回格式——编排器依赖
- 解除：write_failed_state 定义已删除，CONTEXT.md 条目已移除
```
