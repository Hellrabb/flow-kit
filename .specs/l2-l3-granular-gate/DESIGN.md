# DESIGN: L2/L3 独立审查开关拆分

- **Change ID**: `l2-l3-granular-gate`
- **关联**: `@.specs/l2-l3-granular-gate/REQUIREMENT.md`、`@.specs/CONTEXT.md`

---

## 0. 技术栈选定

锁定为 Bash（延续既有栈，无变更）。关键依赖：jq、bats。

## 0.5 既有架构对齐

### 0.5.1 触碰模块

```
触碰模块（grep 验证）：
- flow-kit-bundle/hooks/stop/lib/done-validation.sh（fk_independent_review_gate_active）
- flow-kit-bundle/hooks/stop/29-independent-review.sh（L3 调度）
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（done 拦截）
- flow-kit-bundle/flow-kit/prompts/1-requirement.md（L2 调度段）
- flow-kit-bundle/flow-kit/prompts/2-design.md（L2 调度段）
- flow-kit-bundle/flow-kit/prompts/3-task.md（L2 调度段）
- flow-kit-bundle/flow-kit/prompts/5-test.md（L2 调度段）
- flow-kit-bundle/flow-kit/prompts/6-review.md（L2 调度段）
- flow-kit-bundle/flow-kit/prompts/7-integration.md（L2 调度段）
- ~/.claude/skills/flow/SKILL.md（/flow goal --gate-config 预设表）

禁动清单（不碰）：
- L2-blind-review.md（盲审 prompt 内容不变）
- l3-review.sh（L3 外部模型调用实现不变）
- stop-hook.json 格式（v1 不改持久化配置格式）
- .done 文件 KVP 格式
```

### 0.5.2 沿用模式

| 本阶段需要 | 既有 | 决定 |
|---|---|---|
| gate 开关判定 | `fk_independent_review_gate_active` | 沿用，新增 tier 参数 |
| L3 调度 | `29-independent-review.sh` | 沿用，加 L3 开关检测 |
| done 拦截 | `independent-review-gate.sh` | 沿用，done 检查按 tier 适配 |
| 预设解析 | `flow` skill `/flow goal --gate-config` | 沿用，新值校验 + flag |

---

## 1. 决策清单

| # | 决策 | 备选 | 理由 | 代价 |
|---|---|---|---|---|
| D1 | gate_config 值为三字符串 `"L2"`/`"L3"`/`"both"` | a) 三字符串 b) 独立布尔 key `{l2:true,l3:false}` | 字符串与现有 `"independent"` 值风格一致，jq 读取路径不变（`.goal.gate_config[$pn]`），改动最小 | 无法独立控制两个维度的额外参数（当前不需要） |
| D2 | `"independent"`/`"true"` → `"both"` 映射在 `fk_independent_review_gate_active` 内 | a) 解析层映射 b) 写入时规范化 | 解析层映射保证向后兼容，已有 `.flow-active` 文件无需迁移 | 每次读取多做一次字符串比较（O(1)） |
| D3 | `fk_independent_review_gate_active` 新增可选 `tier` 参数 | a) 可选参数 (`"L2"`/`"L3"`/`""`) b) 拆成两个函数 | 单函数减少重复代码；`tier=""` 保持原行为（任一开启即返回 0），gate 拦截逻辑不变 | 调用方需多传一个参数 |
| D4 | 29 号 hook 通过 `fk_independent_review_gate_active "$phase" "L3"` 检测 | a) 复用 fk_* 函数 b) 独立读取 jq | 复用已有函数，单一判定源，避免 gate_config 解析逻辑分散 | 29 号需 source done-validation.sh（已通过 flow-kit-artifacts 聚合入口满足） |

---

## 2. 架构图

### gate_config 值流转

```
/flow goal --gate-config review --l2-only
        │
        v
  flow skill 解析
    "review" → 预设 {"6-review": "both"}
    --l2-only → 覆盖 {"6-review": "L2"}
        │
        v
  .flow-active.goal.gate_config["6-review"] = "L2"
        │
        ├─→ prompt L2 调度段: gate_config["6-review"] ∈ {"L2","both"}? → spawn 子 agent
        │
        ├─→ fk_independent_review_gate_active "6" "L3" → return 1 (L3 off)
        │       └─→ 29-independent-review.sh: L3 未开启 → skip
        │
        └─→ independent-review-gate.sh:
              fk_independent_review_gate_active "6" "" → return 0 (L2 active)
              → 只检查 L2 done，不要求 L3 done
```

### 三值判定表

| gate_config 值 | L2 跑? | L3 跑? | done 要求 |
|---|---|---|---|
| `"L2"` | ✅ | ❌ | L2 done |
| `"L3"` | ❌ | ✅ | L3 done |
| `"both"` | ✅ | ✅ | L2 + L3 done |
| `"independent"` | ✅ | ✅ | L2 + L3 done |
| `"true"` | ✅ | ✅ | L2 + L3 done |
| 其他/空 | ❌ | ❌ | 无 |

---

## 3. ADR 索引

无不可逆决策（gate_config 值扩展为向后兼容的增量变更）。

---

## 4. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | 已有 `.flow-active` 中 `gate_config` 值为 `"true"`（布尔历史遗留），映射遗漏 | L2/L3 均不触发 | 低 | `"true"` 在三值判定表中映射为 both |
| R2 | prompt L2 调度段改了但某阶段 prompt 漏改 | 漏改的阶段 L2 开关失效 | 中 | grep 全量扫描 6 个 prompt 的 L2 调度段，bats 验证 |
| R3 | `--l2-only` + `--l3-only` 同时传入 | 冲突 | 低 | flow skill 解析时后者覆盖前者 + 打印 warning |

---

## 5. 不在范围

- `stop-hook.json` 持久化配置格式变更（v2）
- `/flow gate-config` 子命令的 `--l2-only`/`--l3-only` flag（v2）
- L2 盲审 prompt 内容修改
- L3 外部模型选择逻辑修改

---

## 9. 架构沉淀建议

### 9.1 新增可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `fk_independent_review_gate_active <phase> [tier]` | 按 tier 判定独立审查开关（L2/L3/any） | gate 拦截、prompt 调度、hook 判断 | 所有需要读 gate_config 的地方统一用此函数 |

### 9.2 新增项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| gate_config 值规范 | `"L2"` / `"L3"` / `"both"`（三值字符串） | 所有读取 gate_config 的组件 | 低——字符串扩展向后兼容 |

### 9.5 禁动清单变化

```
- 新增禁动: gate_config 值不允许写入 "independent"（已废弃，保留读取兼容）
            新代码必须写 "both"
```
