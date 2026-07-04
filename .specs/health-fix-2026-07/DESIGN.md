# DESIGN: 2026-07 健康修复

- **Change ID**: `health-fix-2026-07`
- **关联**: `@.specs/health-fix-2026-07/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

- **选定**：Bash（延续既有技术栈）
- **运行时**: Bash 4.4+ with `set -euo pipefail`
- **测试**: bats-core 1.13.0 (`npx bats`)
- **静态分析**: shellcheck（error 级别，`-e SC1091`）
- **关键依赖**: jq（JSON 处理）、git
- **理由**：本项目是 Bash 分发包仓库，不改技术栈。本次改动仅涉及 lib 重组 + markdown 引用提取，无需新依赖
- **明确排除**：不引入 Python/Node.js 替代 Bash（过度工程，当前规模 Bash 足够）

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep 验证的实际清单）：
- flow-kit-bundle/hooks/stop/lib/correction-file.sh（63 行，4 函数）
- flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh（236 行，12 函数）
- flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh（351 行，8 函数）
- flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh（515 行，13 函数）
- package-flow-kit.sh（610 行，1 函数 + 线性打包流程）
- flow-kit-bundle/flow-kit/prompts/6-review.md
- flow-kit-bundle/flow-kit/prompts/7-integration.md

新增模块：
- flow-kit-bundle/hooks/stop/lib/done-validation.sh（从 flow-kit-artifacts.sh 拆出）
- flow-kit-bundle/lib/validate_staging.sh（从 package-flow-kit.sh 拆出）
- flow-kit-bundle/flow-kit/reference/pipeline-goal-parser.md

禁动清单（与本次无关，AI 不许"顺手"碰）：
- common.sh（HOOK_MODULE_NAMES 注册机制 · L-020 独立跟踪）
- stop hook 主链脚本（00-gate ~ 99-report，仅作为调用方被 grep 验证，不改动代码）
- install.sh（安装流程不涉及）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 矫正文件 JSON 读写 | `correction-file.sh` 有（4 函数） | 沿用，但升级 `correction_file_write` 加 `merge` 策略 |
| done marker 校验 | `flow-kit-artifacts.sh` 有（3 函数） | 沿用函数签名，搬到 `done-validation.sh` |
| pipeline goal 解析 | 无共享抽象（6-review / 7-integration 各自内联） | **新建** `pipeline-goal-parser.md` 共享 reference |
| staging 覆盖校验 | `package-flow-kit.sh` 有 `validate_staging_coverage()` | 沿用，搬到 `lib/validate_staging.sh` |

### 0.5.3 沿用模式 vs 引入新模式

```
- lib 模块组织：**沿用** 既有 lib/ 目录扁平结构（source HOOK_BASE_DIR/lib/xxx.sh）
- 拆分策略：**引入新模式** → 聚合入口（aggregate entry）：主文件 source 子库后 re-export
                  理由：Bash 无模块系统，聚合入口是保持向后兼容的最小代价方案
- correction file 写入：**升级既有** → overwrite 策略加 merge 策略
                        理由：双方竞争同一文件的根因就是 overwrite
```

### 0.5.4 循环依赖复查结论

> 2026-07-04 健康报告标记 L-021 为"🔴 循环依赖：correction-file ↔ interactive-ui-check ↔ weak-model-compliance"。
> 经代码级复查（grep `source` / `. ` / 函数调用），实际依赖方向为干净 DAG：
>
> ```
> correction-file.sh (leaf — 零依赖)
>     ↑ source
>     ├── interactive-ui-check.sh
>     └── weak-model-compliance.sh
> ```
>
> 原扫描 grep 匹配了 `correction-file.sh:6` 的注释文本（`# correction files. Both interactive-ui-check.sh and weak-model-compliance.sh`）作为"反向引用"，产生误报。
> **真实问题**不是循环依赖，而是双方通过 `correction_file_write(overwrite)` 竞争 `.flow-active.correction` 同一文件。修复方向从"打破循环依赖"调整为"merge 策略防数据覆盖"。

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | `correction_file_write` 新增 `merge` 策略 | a) merge 策略 b) 每个调用方独立文件 c) 改为 append-only log | merge 策略最小改动，保持 JSON 结构，调用方代码改 1 行（`"overwrite"` → `"merge"`） | merge 逻辑按 `gate_type + tool` 去重，若将来有新的去重维度需扩展 |
| D2 | `done-validation.sh` 仅拆 1 个子库而非 3 个 | a) 拆 3 库（原 REQUIREMENT）b) 拆 1 库 c) 不拆 | 仅 Tier A（3 函数/独立调用方）有清晰边界；Tier B（10 函数/同调用方 26-workflow）拆分只增复杂度无收益 | 若将来 Tier B 也出现独立调用方，可再拆 |
| D3 | 聚合入口模式保持向后兼容 | a) 聚合入口（主文件 source 子库）b) 修改所有调用方 source 路径 | 聚合入口零调用方改动，`done-validation.sh` 对 29/31/pre-tool-use 透明 | 主文件增加 1 行 `source`，轻微增加间接层 |
| D4 | jq goal 解析提取为 markdown reference 而非 `.sh` 脚本 | a) markdown reference b) 独立 `.sh` 脚本 c) 不提取 | prompt 文件引用 markdown 更自然（同 `@flow-kit/reference/` 下其他文件的惯例）；`.sh` 脚本只能在 bash 上下文执行 | markdown 引用依赖 AI 正确加载，无自动化强制 |

---

## 2. 架构图

### 改动前

```
interactive-ui-check.sh ──source──> correction-file.sh <──source── weak-model-compliance.sh
        │                              │ (overwrite)                      │ (overwrite)
        │                              v                                  │
        └────────────────────> .flow-active.correction <─────────────────┘
                                       ▲
                         双方 overwrite 竞争同一文件
                         后写者销毁先写者数据

flow-kit-artifacts.sh (515 lines, 13 funcs, 1 file)
        ├── fk_artifact_check ──> 26-workflow.sh
        ├── fk_auto_phase ──> 26-workflow.sh
        ├── fk_independent_review_gate_active ──> 29-independent-review, 31-auto-advance, pre-tool-use
        ├── fk_validate_done_marker ──> 31-auto-advance, pre-tool-use
        └── ... 9 more funcs ──> 26-workflow.sh

package-flow-kit.sh (610 lines)
        └── validate_staging_coverage() (lines 19-140, embedded)
```

### 改动后

```
interactive-ui-check.sh ──source──> correction-file.sh <──source── weak-model-compliance.sh
        │                         ┌─ overwrite                        │
        │  write(merge)           │  write(merge)                     │  write(merge)
        v                         v                                   v
        └──────────────────> .flow-active.correction <────────────────┘
                              ▲ read-merge-write
                              └─ merge 策略: 读现有 → 去重追加 → 写回
                                双方数据不再互相销毁

flow-kit-artifacts.sh (~370 lines, aggregate entry)
        │  source done-validation.sh
        ├── fk_artifact_check ──> 26-workflow.sh
        ├── fk_auto_phase ──> 26-workflow.sh
        ├── ... 9 more funcs ──> 26-workflow.sh
        └── (re-exports fk_independent_review_gate_active, fk_validate_done_marker)

done-validation.sh (~140 lines, NEW)
        ├── fk_independent_review_gate_active ──> 29/31/pre-tool-use
        ├── _fk_done_kvp
        └── fk_validate_done_marker ──> 31/pre-tool-use

package-flow-kit.sh (~490 lines)
        │  source lib/validate_staging.sh
        └── validate_staging_coverage (delegated)

lib/validate_staging.sh (~122 lines, NEW)
        └── validate_staging_coverage()
```

---

## 3. ADR 索引

本次无不可逆架构决策（均为既有模式内的重构）。不新增 ADR。

---

## 4. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | merge 策略的 `gate_type + tool` 去重维度不全，将来新调用方引入新维度导致重复 | 矫正文件出现重复条目（非数据丢失） | 低 | 去重逻辑集中在 `correction_file_write` 单一函数内，扩展只需改一处 |
| R2 | `done-validation.sh` 拆分后，某调用方未通过聚合入口 source 而直接 source 子库，绕过将来的聚合逻辑 | 函数重复定义 / 版本不一致 | 低 | 子库文件头注释写"通过 flow-kit-artifacts.sh 聚合入口加载，不建议直接 source" |
| R3 | validate_staging_coverage 搬家后 `$SCRIPT_DIR` 路径解析错误 | --validate 模式产出错误结果 | 中 | 新 lib 用 `BASH_SOURCE[0]` 自定位而非依赖调用方的 `$SCRIPT_DIR` |
| R4 | pipeline-goal-parser.md 为 markdown 引用，AI 可能未加载导致解析逻辑缺失 | prompt 行为退化 | 低 | reference 文件名语义明确；grep 验证作为 AC-3 的硬验证 |

---

## 5. 不在范围

- L-019: `correction_file_write` overwrite→merge 策略升级（本次 D1 正是修这个，但与 L-019 的"所有调用者统一受益"描述一致，可视作同步修复）
- L-020: Stop hook 三处接线合并为单一注册源
- L-018: `fk_accumulate_tokens` 双重赋值清理
- flow-kit-artifacts.sh 其余 10 个函数的进一步拆分（无独立调用方，拆分无收益）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `flow-kit-bundle/hooks/stop/lib/done-validation.sh` | done marker 真实性校验（KVP 验签 + session_id 匹配 + 防伪造） | 独立 review gate / auto-advance / pre-tool-use 检查 done 文件 | 任何需要验证 `.done` 文件合法性的场景 |
| `flow-kit-bundle/lib/validate_staging.sh` | 打包 staging 覆盖校验（bundle 目录树 vs Part A~G 指令对账） | `package-flow-kit.sh --validate` | 独立调用，不依赖打包主流程上下文 |
| `flow-kit-bundle/flow-kit/reference/pipeline-goal-parser.md` | pipeline goal 字段解析（jq 一行提取 scope/start_phase/current_phase/phases_done/auto_advance） | 各阶段 prompt 入场检测 goal 状态 | 任何需要读 `.flow-active.goal` 的 prompt 或脚本 |

### 9.2 新增的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 聚合入口模式（aggregate entry） | Bash lib 拆分时主文件 source 子库后 re-export，调用方不改 source 路径 | 所有 lib 拆分场景 | 低——退回到直接 source 子库只需改调用方 |

### 9.3 新增的跨模块契约

```
- correction_file_write() 签名扩展：第三个参数 strategy ∈ {"overwrite"(default), "merge"}
  merge 策略契约: 读现有 JSON → 取 .violations 数组 → 按 gate_type+tool 去重 → 追加新条目 → 写回
- fk_validate_done_marker / fk_independent_review_gate_active / _fk_done_kvp 搬至 done-validation.sh
  通过 flow-kit-artifacts.sh 聚合入口保持可用，外部调用方无需感知
```

### 9.4 新增依赖

无新增外部依赖。

### 9.5 禁动清单变化

```
- 新增禁动: flow-kit-bundle/hooks/stop/lib/done-validation.sh 不建议直接 source，
            通过 flow-kit-artifacts.sh 聚合入口加载（注释写在文件头）
```
