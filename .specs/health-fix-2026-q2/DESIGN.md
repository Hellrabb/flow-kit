# DESIGN: 修复 M-health 2026-06-20 的 2 项 🟡 技术债

- **Change ID**: health-fix-2026-q2
- **关联**: `@.specs/health-fix-2026-q2/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

> **精简说明**：本 change 无架构决策（CHANGE.md 已确认无新 ADR / 无模块拆分），DESIGN 压缩为「既有抽象对齐 + 决策清单 + 风险」。跳过技术栈卡片（沿用既有 Bash + jq + bats 栈）。

---

## 0. 技术栈选定

> 沿用既有栈，无变更。

- **语言**: Bash（`set -euo pipefail` 仅 hook 模块，库文件不加 — 与 `flow-kit-artifacts.sh:8` 注释一致）
- **测试**: bats-core 1.13.0（`npx bats`）+ jq
- **依赖**: 无新增

---

## 0.5 既有架构对齐

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（仅修改 jq 表达式 + 新增测试文件，不改逻辑）：
- flow-kit-bundle/flow-kit/prompts/5-test.md（入场 jq 微调）
- flow-kit-bundle/flow-kit/prompts/6-review.md（入场 jq 微调）
- flow-kit-bundle/flow-kit/prompts/7-integration.md（入场 jq 微调）

新增模块：
- test/test_flow_artifacts.bats（新建 · hooks smoke test）
- test/test_common.bats（增量 · 补 2+ 边界用例）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/stop/lib/*.sh（不改 hook 逻辑，只加测试）
- flow-kit-bundle/hooks/stop/*.sh（同上）
- flow-kit-bundle/skills/flow/SKILL.md（上次 change 已改完）
- flow-kit-bundle/flow-kit/GO.md（同上）
- flow-kit-bundle/flow-kit/prompts/4-dev.md（同上 · 已含 start_phase）
- package-flow-kit.sh / install.sh / lib/*.sh（本次无关）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 入场 jq 一致性格式 | `4-dev.md:81` / `GO.md:257` 已用 `current_phase // .start_phase // "4"` | **沿用** — 把 5/6/7 改成同样的格式 |
| bats 测试 fixture pattern | `test/test_common.bats` setup（mktemp + CONFIG_FILE + skip_if_no_jq） | **沿用** — 新 `test_flow_artifacts.bats` 复用相同 setup 结构 |
| jq 字段读取纯函数 | `flow-kit-artifacts.sh:16 fk_flow_field()` | **沿用** — 测试它（source 后直接调） |
| 文件非空检查纯函数 | `flow-kit-artifacts.sh:24 fk_file_nonempty()` | **沿用** — 测试它 |
| flow 状态校验纯函数 | `flow-kit-artifacts.sh:215 fk_validate_flow()` | **沿用** — 测试基础路径 |

### 0.5.3 沿用模式 vs 引入新模式

```
- 测试组织：**沿用** test_common.bats 的 setup/teardown（mktemp 隔离 + skip_if_no_jq）
- 断言风格：**沿用** [[ ... ]] 直接断言 jq 输出（与 test_flow_goal.bats 一致）
- jq fallback 表达式：**沿用** 4-dev.md/GO.md 的 `current_phase // .start_phase // "4"` 形式
- 测试边界构造：**沿用** 预置最小 .flow-active JSON 到 mktemp 目录的 pattern
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | 5/6/7 入场 jq 用 `current_phase // .start_phase // "4"`（与 4-dev 一致） | A) 只加 `start_phase` 不加双重 fallback / B) 完全重写 jq | 选双重 fallback：start_phase 缺失→current_phase 缺失→"4"，最大兼容性（旧数据、中间状态都覆盖） | jq 表达式略长，但语义明确，与已 ship 的 4-dev/GO 完全对齐 |
| D2 | `test_flow_artifacts.bats` 测纯函数而非整链 | A) 测整个 26-workflow.sh hook 执行 / B) 只测纯函数 | 选 B：纯函数（fk_flow_field/fk_file_nonempty）无副作用、可隔离、可单测；整链测试需 mock git/hooks 环境，ROI 低且脆弱 | 不覆盖 fk_auto_phase/fk_boundary_check 等依赖外部状态的函数（留 v2） |
| D3 | `fk_flow_field` 测试构造 fixture 而非真实 .flow-active | A) 指向真实项目 .flow-active / B) mktemp 构造最小 JSON | 选 B：测试可重复、不依赖当前项目状态、CI 友好 | 需手动构造 fixture（5-10 行 JSON），但换来隔离性 |
| D4 | common.sh 边界补全选哪些 | A) config_get 缺失文件 + check_enabled disabled module / B) 覆盖所有未测函数 | 选 A：这两个是已测函数的**边界路径**（当前测试只覆盖 happy path），补全边界即满足 AC-3 | hook_init/init_paths 涉及全局状态，暂不测（v2） |
| D5 | 不改 hook 库逻辑 | A) 顺便重构 fk_artifact_check / B) 只加测试 | 选 B：本 change 是 health-fix（补测试 + 一致性），重构属另一个 change 的职责 | 不消除代码内潜在问题（但 jscpd 已确认无冷败） |

---

## 2. 数据流 / 架构图

### 2.1 AC-1 jq 微调（无逻辑变化）

```
当前 5-test/6-review/7-integration 入场：
  jq -r '.goal | "\(.scope // "phase")|\(.current_phase // "4")|..."'
                                            ^^^^^^^^^^^^
                                            硬编码 fallback

改为（与 4-dev.md:81 一致）：
  jq -r '.goal | "\(.scope // "phase")|\(.start_phase // "4")|\(.current_phase // .start_phase // "4")|..."'
                                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                            双重 fallback
```

### 2.2 AC-2 artifacts 测试数据流

```
bats setup
  │ mktemp -d → $TEST_TMPDIR
  │ source flow-kit-artifacts.sh
  │ export PROJECT_ROOT="$TEST_TMPDIR"
  ▼
test fk_flow_field
  │ 构造 $TEST_TMPDIR/.flow-active（含已知字段）
  │ 调 fk_flow_field "change_id" → 断言返回值
  │ 删 .flow-active → 调 fk_flow_field "x" "default" → 断言返回 "default"
  ▼
test fk_file_nonempty
  │ 写 10 行文件 → fk_file_nonempty 返回 0
  │ 写 1 行文件 → fk_file_nonempty 返回 1
  │ 不存在 → 返回 1
  ▼
teardown: rm -rf $TEST_TMPDIR
```

---

## 3. 关键状态机

无（本 change 不引入状态机）。

---

## 4. ADR 索引

无。所有决策 D1-D5 均可逆（jq 表达式 / 测试文件均可后续调整），无不可逆架构决策。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | `fk_flow_field` source 时可能因依赖 `PROJECT_ROOT` 未设而行为异常 | 测试报错 | 中 | bats setup 中显式 `export PROJECT_ROOT="$TEST_TMPDIR"`（D3） |
| R2 | `fk_validate_flow` 依赖较多字段，基础路径测试可能触发副作用（写文件/exit） | 测试污染 | 中 | 先读函数体确认是否纯读（只读不写才能单测）；若有 exit/写副作用 → 只测其返回码而非内部逻辑 |
| R3 | AC-1 jq 改动破坏现有 4-dev/GO 行为（误改） | pipeline 路由异常 | 低 | 只动 5/6/7 三个文件，diff 严格限定为 jq fallback 表达式；改完跑全量测试验证 |
| R4 | bats source 库文件时 `set -euo pipefail` 与库文件冲突 | setup 失败 | 低 | 库文件本身不加 pipefail（注释已说明），bats 默认环境可 source |

---

## 6. 不在范围

- hooks 100% 行覆盖（v2）
- fk_auto_phase / fk_stale_check / fk_boundary_check 测试（依赖 git/文件系统，v2）
- transcript-parser.sh 测试（v2）
- hook 重构（不在 health-fix 范围）

---

## 9. 架构沉淀建议

本 change 无架构层面沉淀建议（纯测试补充 + jq 一致性微调，不引入可复用抽象、不锁新技术决策、不改公共契约、不加依赖、不动禁动清单）。整段写：**本 change 无架构层面沉淀建议**。

---

> 本文件不包含完整代码实现。函数签名可，函数体不行。
