# DESIGN: L2/L3 双层审查结果合并写入

- **Change ID**: `dual-review-merge-fix`
- **关联**: `@.specs/dual-review-merge-fix/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 锁定自 `CONTEXT.md` 已锁决策。本项目为 flow-kit 分发包仓库，非传统软件项目。

- **语言/运行时**: Bash（`set -euo pipefail`）
- **测试**: bats-core 1.13.0（`npx bats`）
- **关键依赖**: `jq`（JSON 处理）、`awk`（文本剥离）、`curl`（L3 API 调用）
- **理由**: 本 change 仅修改既有 hook 脚本 + prompt markdown，不引入新语言/框架/依赖
- **明确排除**: 无新技术栈——纯 Bash 修复

---

## 0.5 既有架构对齐（brownfield · B2 老项目护栏）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep/ls 实际清单）：
- hooks/stop/29-independent-review.sh（既有 · L3 Stop hook 入口）
- hooks/stop/lib/l3-review.sh（既有 · L3 API 调用 + .done 写入共享 lib）
- hooks/stop/lib/done-validation.sh（既有 · .done 6 键 KVP 真实性校验）
- hooks/pre-tool-use/independent-review-gate.sh（既有 · PreToolUse 硬拦截 + L3 前置）
- flow-kit/prompts/independent/L2-blind-review.md（既有 · 固化盲审指令）
- flow-kit/prompts/{1-requirement,2-design,3-task,5-test,6-review,7-integration}.md（既有 · 各阶段 prompt）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- hooks/stop/lib/common.sh（共享工具函数，不改）
- hooks/stop/30-ai-analyze.sh（AI 分析 hook，与独立审查无关）
- hooks/stop/33-flow-active-integrity.sh（状态完整性校验，不改）
- package-flow-kit.sh（打包脚本，不改）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| gate_config 读取 + tier 判定 | `done-validation.sh:fk_independent_review_gate_active()` | 沿用（已含 phase_name 映射 + L2/L3/both 解析） |
| .done 6 键 KVP 写入 | `l3-review.sh:l3_review_run()` 的 `cat > "$done_tmp" <<DONE_EOF` | 沿用格式，扩展 L2_verdict 值域为 `skipped`（调用方传入） |
| .done 真实性校验 | `done-validation.sh:fk_validate_done_marker()` | 沿用（`skipped` 值域已支持，无需修改） |
| L3 追加写入（`>>` + awk 剥离） | `l3-review.sh:174-198` | 沿用（当前行为正确） |
| transition 方向检测 | `independent-review-gate.sh:_fk_phase_direction()` | 沿用 |
| L3 前置同步调用 | `independent-review-gate.sh` 的 forward 分支 | 沿用（加 L2-wait 检查） |
| L2 盲审子 agent 调度 | 各阶段 prompt 的 L2 段 | 沿用调度模板，修改输出指令 |

### 0.5.3 沿用模式 vs 引入新模式

```
- gate_config 双源读取（.flow-active > stop-hook.json）：**沿用** 既有 fk_independent_review_gate_active()
- .done 原子写入（tmp → mv）：**沿用** 既有的 l3-review.sh 模式
- L3 power 等 stripping（awk /pattern/{stop} !stop）：**沿用** 既有 l3-review.sh 的 F3 修复
- L2 追加写入语义：**引入新模式**（此前 prompt 只说"写入"，不约束 append；本次在 L2-blind-review.md 明确 append-first 策略）
- L2-only .done KVP 写入：**引入新模式**（此前 prompt 说 `touch .done` 产出空文件；本次改为写 6 键 KVP，由主 agent 通过 bash heredoc 写入）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **L2-wait gating**：29 号 hook **与 `independent-review-gate.sh`（PreToolUse forward 分支）** 在 gate_config="both" 时检查 L2 段是否存在，不存在则跳过 L3 并拒绝写 .done | A) 不在 hook 层加锁，纯靠 prompt 约束 B) hook 层硬拦（选此） | B 是唯一可靠方案——prompt 层无法阻止 Stop hook 在 session 结束后独立运行。hook 层用 `grep -q "^## L2 盲审"` 检测，O(1) 本地文件操作，无额外延迟 | L2 子 agent 崩溃后 L3 永久阻塞 → 缓解：连续 3 次 session 后输出"建议关闭 gate 或手动补 L2"的提示（v1 不做自动降级） |
| D2 | **L3-only 默认值修正**：gate_config="L3" 时 `l2_verdict` 默认 `skipped`（非 `fail`） | A) 保持 `fail` 默认（向后兼容优先） B) 改为 `skipped`（语义正确优先，选此） | `L2_verdict=fail` 在 L3-only 模式下语义错误——L2 是刻意不跑而非失败。`skipped` 精准表达"本 tier 未启用"，与 AC-7 对齐 | 下游消费者需识别 `skipped`——`done-validation.sh` 的值域已支持 `skipped`（line 137），无需额外改动 |
| D3 | **L2-only .done 由主 agent 写 6 键 KVP**：替代 `touch .done` | A) hook 层自动检测 L2 完成后写 .done B) prompt 指令让主 agent 写（选此） | A 需要新增 hook 模块（复杂度↑）；B 是 prompt 层最小改动——主 agent 已能读取 L2 子 agent 输出并提取 verdict。代价：依赖主 agent 遵循 prompt（弱模型可能跳步），但 `done-validation.sh` 的 fail-close 校验确保空文件/skip 无法绕过 | 主 agent 不遵循指令写 KVP → .done 无法通过校验 → pipeline 卡住。缓解：SessionStart resume 检测到 L2 段存在但 .done 缺失时，注入矫正 banner |
| D4 | **L2 追加写入策略**：子 agent 先读文件检测已有 L3 段，有则追加，无则新建 | A) 强制子 agent 用 `>>` shell 追加 B) L2-blind-review.md 指令明确 append-first（选此） | 子 agent 通过 Agent 工具调度，无直接 shell 访问。B 在固化 prompt 中增加 append-first 指令（"若文件已存在，先读取全文，将你的 L2 段追加到末尾再 Write；不要覆盖已有内容"），实现成本最低 | 子 agent 忽略指令直接覆写 → 与当前行为相同（无回归），且 L3 可重新追加（Stop hook 幂等补跑） |

---

## 2. 数据流 / 架构图

### both 模式（正常路径）

```
主 agent 产阶段产物
       │
       ▼
派 L2 子 agent ──Write──> INDEPENDENT-REVIEW-<N>.md
  (L2-blind-review.md          │
   append-first 指令)          ▼
       │               [## L2 盲审 段]
       ▼
主 agent 尝试 transition (phase write)
       │
       ▼
PreToolUse hook ──检测 L2 段存在──> 调 l3_review_run()
                                         │
                                    awk 剥离旧 L3 + >> 追加新 L3
                                         │
                                         ▼
                                  INDEPENDENT-REVIEW-<N>.md
                                    [## L2 盲审 + ## L3 盲审]
                                         │
                                    cat > .done (6 键 KVP)
                                         │
                                         ▼
                                  transition 放行 → phase N+1
```

### L2-only 模式

```
主 agent 产阶段产物
       │
       ▼
派 L2 子 agent ──Write──> INDEPENDENT-REVIEW-<N>.md
       │                    [## L2 盲审 段]
       ▼
主 agent 确认 L2 段存在
       │
       ▼
主 agent grep verdict ──> cat > .done
                          (L2_verdict=pass|fail,
                           L3_verdict=skipped,
                           written_by=main-agent)
       │
       ▼
transition 放行
```

### L3-only 模式

```
主 agent 产阶段产物
       │
       ▼
PreToolUse / Stop hook 29
       │
       ▼
29-independent-review.sh
  ├─ gate_config="L3" → L2-wait 检查跳过（AC-1 仅对 "both" 生效）
  ├─ L2 段不存在 → l2_verdict="skipped"（不是 "fail"）
  └─ 调 l3_review_run() → 写 L3 段 + .done(L2=skipped, L3=pass|fail)
       │
       ▼
transition 放行（PreToolUse）/ 下轮 SessionStart resume（Stop hook）
```

---

## 3. 关键状态机：.done 生命周期

```
                    ┌─────────┐
                    │ 不存在   │
                    └────┬────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
    gate=both        gate=L2        gate=L3
          │              │              │
          ▼              ▼              ▼
   L2 先完成        L2 完成        L3 完成
   L3 后完成        主 agent        l3_review_run()
   l3_review_run()  写 KVP .done   写 KVP .done
   写 KVP .done         │              │
          │              │              │
          └──────────────┼──────────────┘
                         ▼
                    ┌─────────┐
                    │ 已存在   │──> fk_validate_done_marker()
                    └─────────┘     ├─ Tier1: 非空 + 6行 + KVP 全 + 值域合法
                                    ├─ Tier2(transition): 握手锚点 + session_id
                                    └─ 通过 → transition 放行
```

---

## 4. ADR 索引

本 change 不引入新的不可逆架构决策。所有改动均在既有 gate_config / .done / L2-L3 框架内。若后续需要 ADR：

- `.specs/adr/` 不新增（本次改动可逆，回滚方式：还原 4 个文件的 git diff）

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | 29 号 hook 加 L2-wait 后，L2 子 agent 崩溃导致 L3 永久阻塞（both 模式） | pipeline 卡在当前阶段 | 低 | 3 次 session 后 Stop hook 日志输出"建议 /flow gate-config <phase>=L3 降级或手动补 L2"；v2 加自动降级 |
| R2 | 主 agent 不遵循 L2-only 的 KVP .done 写入指令（弱模型跳步），仍执行 `touch .done` | .done 空文件 → `fk_validate_done_marker()` 拒绝 → pipeline 卡住 | 中 | SessionStart resume 检测 L2 段存在但 .done 缺失/无效时注入矫正 banner；`done-validation.sh` 的 fail-close 确保空 .done 绝不放行 |
| R3 | `l2_verdict=skipped` 新增值域被下游消费者（如 30-ai-analyze.sh）误读 | AI 分析报告误判为 L2 失败 | 低 | `skipped` 语义明确（"本 tier 未启用"），与 `fail`（"发现问题"）无歧义。`done-validation.sh` 值域已支持（line 137），无需改下游 |
| R4 | 既有 `INDEPENDENT-REVIEW-<N>.md` 文件格式不标准（L2/L3 段顺序异常）导致 awk 剥离误删 L2 内容 | L2 审查结果丢失 | 极低 | L3 的 `awk '/^## L3 盲审/{stop=1} !stop{print}'` 仅在命中 `## L3 盲審` marker 后才剥离，正常格式 L2 段在前不受影响。如 marker 缺失则 awk 保留全文 → L3 追加后文件变大但不丢数据 |
| R5 | 旧 `.done` 文件中 `L2_verdict=fail`（L3-only 场景，修复前产物）语义不精确——L2 是未启用非失败 | 下游消费者（如 30-ai-analyze.sh）若区分解读可能误判 | 极低 | `done-validation.sh` 值域同时接受 `pass\|fail\|skipped`，旧文件通过校验无功能回归。旧文件数量有限且随 pipeline 推进自然被覆盖，无需迁移脚本 |

---

## 6. 不在范围

- 不新增 hook 模块（如 L2-done-auto-writer.sh）——v1 靠 prompt + 现有 hook 兜底
- 不改动 30-ai-analyze.sh 的 AI 分析逻辑
- 不引入 L2/L3 审查结果的 diff/merge 智能合并
- Phase 4（实施阶段）的独立审查——phase 4 不在 gate_config 体系内

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

本 change 无新增可复用抽象。

### 9.2 新增/改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| L2_verdict 值域扩展 | `{pass, fail, skipped}`（原 `{pass, fail}`） | `.done` 文件的 KVP 格式 + `done-validation.sh` 校验 | 低——`skipped` 已存在于 `done-validation.sh:137` 的值域正则中，属于补齐语义空缺 |

### 9.3 新增/修改的跨模块契约

```
- .done 文件 L2_verdict 字段值域: pass|fail|skipped（skipped 语义："本 tier 未启用，非失败"）
- .done 文件 L3_verdict 字段值域: pass|fail|timeout|error|skipped（无新增，已支持）
- 29-independent-review.sh: gate_config="both" 时新增 L2-wait 前置检查，L2 段不存在 → 跳过 L3
```

### 9.4 新增/升级的依赖

无新增依赖。

### 9.5 禁动清单变化

无变化。

---
> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
