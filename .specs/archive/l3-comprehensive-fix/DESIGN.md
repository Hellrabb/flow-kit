# DESIGN: L3 独立审查全面修复

- **Change ID**: l3-comprehensive-fix
- **关联**: `@.specs/l3-comprehensive-fix/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 本项目为 meta/Bash 分发包仓库（CONTEXT.md: "非标准技术栈项目"），无新栈引入。

- **语言/运行时**: Bash（`set -euo pipefail`）
- **外部依赖**: `jq`（JSON 处理）、`curl`（L3 API 调用）
- **测试**: bats-core 1.13.0（`npx bats test/`）
- **理由**: 本次 change 是对现有 flow-kit Bash hook 系统的 bug 修复，不引入新依赖或新语言
- **明确排除**: 无——本次不涉及技术栈变更

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep/ls 验证过的实际清单）：
- flow-kit-bundle/hooks/stop/29-independent-review.sh（132 行 · L3 Stop hook 入口）
- flow-kit-bundle/hooks/stop/lib/l3-review.sh（377 行 · L3 API 调用 + .done 写入）
- flow-kit-bundle/hooks/stop/lib/done-validation.sh（.done 6 键校验 lib）
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（361 行 · transition gate）
- flow-kit-bundle/hooks/session-start/flow-kit-resume.sh（252 行 · L3 结果注入 SessionStart）
- flow-kit-bundle/flow-kit/prompts/1-requirement.md（独立 review 调度段）
- flow-kit-bundle/flow-kit/prompts/2-design.md（同上）
- flow-kit-bundle/flow-kit/prompts/3-task.md（同上）
- flow-kit-bundle/flow-kit/prompts/5-test.md（同上）
- flow-kit-bundle/flow-kit/prompts/6-review.md（同上 · 2 处引用）
- flow-kit-bundle/flow-kit/prompts/7-integration.md（同上）

新增模块：
- flow-kit-bundle/hooks/stop/lib/l2-detect.sh（L2 未完成检测 + 提示生成 · 新 lib）
- test/fixtures/l3-truncation-30k.md（L3 截断测试夹具 · 新增）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/stop/00-gate.sh（gate 逻辑，不涉及独立 review）
- flow-kit-bundle/hooks/stop/30-ai-analyze.sh（频率门控 AI 分析，与独立 review 分开）
- flow-kit-bundle/flow-kit/prompts/4-dev.md（Phase 4 不触发 L2/L3，不改）
- flow-kit-bundle/hooks/stop/31-auto-advance.sh（auto_advance 逻辑，不改）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| L3 API 调用 | `l3-review.sh::l3_review_run()` | 沿用，修其内部截断逻辑 |
| .done 文件校验 | `done-validation.sh::fk_validate_done_marker()` | 沿用，确保 6 键校验一致 |
| phase 检测（pipeline 感知） | `independent-review-gate.sh:136-139`（已有 pipeline vs 单阶段分支） | **复用此模式**到 `29-independent-review.sh` 和 `flow-kit-resume.sh` |
| L3_RESULT 格式化 | `l3-review.sh::_l3_format_result()` | 沿用，确保所有输出点一致 |
| module_output 日志 | `lib/common.sh` | 沿用现有日志模式 |
| L2 盲审 prompt | `prompts/independent/L2-blind-review.md` | 沿用，不修改审查标准本身 |
| gate_config 解析 | `29-independent-review.sh:89-96`（值标准化映射） | 沿用，新 lib 复用此逻辑 |

### 0.5.3 沿用模式 vs 引入新模式

```
- Hook 模块结构：**沿用** 独立 .sh 文件 + `lib/` 共享函数 模式
- Phase 检测：**沿用但修正**——PreToolUse gate 已有 pipeline-aware 逻辑（line 136-139），
  Stop hook 和 SessionStart 目前缺失，本次补齐而非重做
- Done 文件格式：**沿用** Shell source 格式（KEY="value"），与 `l3-review.sh:282-290` 一致
- L2 触发提示：**引入新模式**——新增 `l2-detect.sh` lib，在 PreToolUse gate 和 Stop hook 中复用，
  类比 L3 的 `l3-review.sh` 共享 lib 模式。理由：L2 检测逻辑需在 3 个调用点（gate + stop + prompt）复用
- Prompt 中 L2 调度段：**沿用但加固**——在「独立 review 调度」段增加 gate-style 的自动化检测提示，
  降低主 agent 跳过 L2 调度的概率
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 | 覆盖 AC |
|---|---|---|---|---|---|
| D1 | L3 header 统一为 `## L3 盲审` | 统一为 `## L3 外部模型审查` | `l3-review.sh` 已写 `## L3 盲审`，改动面最小：`flow-kit-resume.sh:138` 一处 grep 改为主匹配 `## L3 盲审`，同时以 `\|\|` 追加旧 header `## L3 外部模型审查` 作为兼容回退（历史文件仍可识别） | header 名称不如"外部模型审查"自解释，但 CONTEXT.md:84 已有"L3 盲审"定义，不造成歧义 |
| D2 | 智能截断：`head -c` → `awk` 状态机保留标题+AC | 改为 `head -n`（按行数截断，但可能切断标题/AC 中间）| 标题行是结构锚点，AC 行是审查核心——这两者完整保留才能让 L3 做有意义的判断。普通 `head -n` 可能恰好在标题/AC 行中间切断 | 实现复杂度从 1 行变为 ~30 行 awk；极端长 AC（单条 > 2000 chars）可能仍被截断 |
| D3 | Stop hook phase 检测：改用 pipeline-aware 逻辑 | 统一用 `max(.phase, .goal.current_phase)` | AC-7 的 R3 审查发现 `max()` 在 `.phase` 过期残留时误判。pipeline-aware 优先级选择（pipeline → current_phase，否则 → .phase）在 PreToolUse gate 已验证可行 | pipeline 模式判断依赖 `.goal.scope` 字段准确性 |
| D4 | L2 被动触发：PreToolUse gate + Stop hook 均检测 L2 缺失并输出提示 | 仅在 PreToolUse gate 拦截；仅在 Stop hook 提示；仅在 prompt 指令加固 | 双层兜底：gate 拦 transition（前置），stop hook 提醒（后置），prompt 加固（进行中）。任何一层单独都不够可靠 | 新增 `l2-detect.sh` lib（~50 行），3 个调用点各加 3~5 行 |
| D5 | L2 提示含一键 Agent 命令模板（选项①）+ 选项②③交互设计 | 仅提示"请派 L2" | 选项①降低派发门槛。选项②③交互设计见 §2.2——②跳过 L2 写 .skip-L2-<phase> 标记 + FLOW_KIT_SKIP_L2=1 确认风险；③回退等待即为当前 gate 默认 deny 行为 | 命令模板硬编码在 hook 中，prompt 变更时需同步更新（缓解：模板含注释指向 L2-blind-review.md 路径） |
| D6 | L3 API 不可用降级：独立于 gate 的 timeout→放行策略 | 阻塞 pipeline 直到 API 恢复 | 韧性要求（REQUIREMENT.md NFR）+ CONTEXT.md:189 已锁决策：外部依赖故障不阻断工作流。L3 是"第二意见"，L2 已提供一层审查 | L3 不可用时 pipeline 在只有 L2 审查的情况下继续，风险由 L2 承担 |
| D7 | fk_resolve_phase() 统一函数提升为 v1 必做 | 保持 3 处各自内联 pipeline-aware 逻辑 | R4 风险警告 3 处散落修改必然导致未来回归——v1 抽取共享函数，bats 测试覆盖两种模式 | 需改 3 处调用点，每处 ~3-5 行 | AC-7 |

---

## 2. 数据流 / 架构图

### 2.1 L2/L3 完整触发链路（修复后）

```
Phase N 产物完成
     │
     ├─→ PreToolUse gate（切阶段 / commit / PR 时）
     │     ├─ is_phase_write? ──→ 方向判定（forward/rollback/noop）
     │     ├─ forward:
     │     │   ├─ gate_config=both + L2 缺失 ──→ ⛔ deny + 输出 L2 派发提示（含 Agent 命令模板）
     │     │   ├─ L2 已完成 + gate_config 含 L3 ──→ ⏳ l3_review_with_timeout(30s)
     │     │   │   ├─ L3 pass/fail ──→ 写 .done ──→ ✅ 放行
     │     │   │   └─ L3 timeout/error ──→ 写 timeout .done ──→ ✅ 放行（韧性降级）
     │     │   └─ gate_config=L2-only + L2 done ──→ ✅ 放行
     │     └─ rollback/noop ──→ ✅ 直接放行
     │
     └─→ Stop hook 29-independent-review.sh（session 结束时）
           ├─ Gate 1-3: 模块启用 + flow-kit 活跃 + phase 合法
           ├─ 【修复点 D3】phase 检测: pipeline? → current_phase : .phase
           ├─ Gate 4-5: 幂等检查 + .done 存在检查
           ├─ 【修复点 D4】L2 检测:
           │   ├─ gate_config=both + L2 缺失 ──→ 输出 L2 派发提示 ──→ exit 0
           │   └─ L2 完成 / L3-only ──→ 继续
           └─ l3_review_run() ──→ L3 API 调用 ──→ 写 .done

SessionStart hook flow-kit-resume.sh（新 session 启动时）
     │
     ├─ 读 .done 文件
     ├─ 【修复点 D1】grep "## L3 盲审"（而非 "## L3 外部模型审查"）
     ├─ 【修复点 D3】pipeline? → current_phase : .phase
     └─ 输出 L3_RESULT: verdict=... summary=... report=...
```

### 2.2 修复前后对比

```
BEFORE（4 个 bug）:
  Stop hook ──→ 读 .phase（可能=0）──→ Gate 3 fail ──→ L3 永不触发 ❌
  SessionStart ──→ grep "L3 外部模型审查" ──→ 找不到 header ──→ 静默跳过 ❌
  L3 prompt ──→ head -c 20000 硬截断 ──→ 不完整内容 ──→ 假阳性 ❌
  L2 ──→ 全靠主 agent 读 prompt 手动派 ──→ 经常跳过 ❌

AFTER（修复后）:
  Stop hook ──→ pipeline-aware phase 检测 ──→ 正确触发 ✅
  SessionStart ──→ grep "L3 盲审" ──→ 找到 header ──→ 注入 L3_RESULT ✅
  L3 prompt ──→ awk 智能截断（保留标题+AC）──→ 告知模型截断上下文 ✅
  （注: API 端可能按自身 token 限制二次截断，截断叠加效应仍存在，但智能截断+上下文告知后模型会更审慎）
  L2 ──→ PreToolUse gate + Stop hook 双层检测 ──→ 输出一键派发提示 ✅
```

---


### 2.2 AC-5 选项②③交互设计

PreToolUse hook 是无状态拦截器——只能 deny 或 allow。选项②和③需通过标记文件 + 环境变量实现状态传递：

| 选项 | 用户动作 | hook 行为 | 状态传递机制 |
|---|---|---|---|
| ① 派 L2 | 复制粘贴 Agent 命令 | deny + 输出命令模板 | 无状态（一次性提示） |
| ② 跳过 L2 | 设置 `FLOW_KIT_SKIP_L2=1` 环境变量 | 写 `.skip-L2-<phase>` 标记文件 → 下次 gate 检查时标记存在 + env var 已设 → 放行 | `.skip-L2-<phase>`（标记文件）+ `FLOW_KIT_SKIP_L2`（确认信号） |
| ③ 回退等待 | 完成 L2 后重新执行 transition | deny + 提示"完成 L2 后重新执行 transition 即可" | 无状态（当前 gate 默认行为） |

实现约束：
- `.skip-L2-<phase>` 标记文件写入 `.specs/<change_id>/` 目录，不入 git（与 `.done` 同级）
- `FLOW_KIT_SKIP_L2=1` 作为显式风险确认信号，防止 agent 静默跳过
- gate 日志输出跳过原因（含标记文件路径 + 环境变量名）供 SessionStart 回放

### 2.3 智能截断算法规范（D2 实现细节）

```
输入: artifact_text (完整产物), max_chars (字符上限)
输出: truncated_text, truncation_meta

算法（两遍扫描）:

第 1 遍 · 索引收集:
  headers = []           # (lineno, level, title_text)
  ac_lines = set()       # Given/When/Then 行号集合
  FOR each line IN artifact_text:
    IF line matches /^##\s/ OR /^###\s/:
      headers.append( (lineno, level, line) )
    IF line matches /^\*\*Given\*\*|^\*\*When\*\*|^\*\*Then\*\*/:
      ac_lines.add(lineno)

第 2 遍 · 按标题段填充:
  output = ""
  remaining = max_chars
  FOR each (hdr_line, hdr_text) IN headers:
    section_text = 从 hdr_line 到下一个 header 之间的全部内容
    # 强制保留: 标题行 + AC 行
    mandatory = hdr_text + 该段内所有 ac_lines 对应的行
    mandatory_len = len(mandatory)
    IF remaining >= mandatory_len:
      output += mandatory + section_text 中非 mandatory 部分填充至 remaining
    ELSE:
      output += mandatory[:remaining]  # 极端情况: 至少保留标题行
    remaining = max_chars - len(output)
    IF remaining <= 0: BREAK

截断标记:
  truncation_meta = f"[截断] 原始: {original_size} chars → 截断后: {truncated_size} chars"
  IF 有被移除的章节:
    removed_sections = [h for h in headers if h not in output]
    truncation_meta += f" | 被截去的章节: {', '.join(removed_sections)}"
  ELSE:
    truncation_meta += " | 所有章节已保留（内容被压缩）"
```

约束：
- 硬约束 (a): 所有 `##`/`###` 标题行必须出现在 output 中（即使内容被截）
- 硬约束 (b): 所有 Given/When/Then AC 行必须完整保留（非截断）
- 降级: 单条 AC Given/When/Then 超过 2000 chars → 保留但标注 `[AC 超长，可能不完整]`
- 截断标记作为 prompt 首段注入，L3 模型在审查前先看到上下文限制

## 3. 关键状态机

### 3.1 Phase 检测决策树（修复后 · 跨 3 个 hook 统一）

```
输入: .flow-active JSON
     │
     ├─ goal.scope == "pipeline" AND goal.current_phase ∈ {1,2,3,5,6,7}?
     │   YES ──→ 使用 goal.current_phase
     │   NO  ──→ 降级: 使用 .phase
     │
     └─→ 用于: Gate 3（Stop hook）/ SessionStart 注入 / L2 检测
```

### 3.2 .done 生命周期

```
                    ┌──────────────────────────┐
                    │  .done 不存在             │
                    │  gate deny transition     │
                    └──────────┬───────────────┘
                               │ L2 完成 + L3 完成
                               ▼
                    ┌──────────────────────────┐
                    │  .done 写入（6 键 KVP）   │
                    │  written_by=pre-tool-use- │
                    │  gate 或 l3-review.sh     │
                    └──────────┬───────────────┘
                               │
                    ┌──────────┴───────────┐
                    │                      │
                    ▼                      ▼
          ┌──────────────┐      ┌──────────────────┐
          │ gate 放行     │      │ Stop hook Gate 5  │
          │ transition OK │      │ 检测到 .done →    │
          └──────────────┘      │ skip + "skipped"   │
                                │ 日志               │
                                └──────────────────┘
```

---

## 4. ADR 索引

本次 change 不产生不可逆的架构决策。所有决策（D1-D7）均为现有机制的 bug 修复或补齐，不改变 L2/L3 独立审查的核心协议。

如未来引入"L2 全自动触发（v2）"或"L3 模型切换策略（v2）"，届时再写 ADR。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | L3 header 修改后，已有 `INDEPENDENT-REVIEW-*.md` 文件（旧 header `## L3 外部模型审查`）在 SessionStart 仍不可见 | 历史 L3 结果在新 session 不展示 | 低（历史文件数量少，且旧 header 在人工查看时仍可读） | `flow-kit-resume.sh` 同时 grep 新旧两种 header（`## L3 盲审` OR `## L3 外部模型审查`），向后兼容 |
| R2 | 智能截断的 awk 状态机在极端格式（如无标题的纯文本 REVIEW.md）下可能退化到等价 `head -c` | 截断优化失效，回到硬截断 | 低（flow-kit 产物均为 markdown，必有标题） | 降级：awk 无匹配时 fallback 到保留前 N 行 + 告知模型"以下为完整文件前 N 行" |
| R3 | L2 一键 Agent 命令模板的硬编码参数（subagent_type、description）与 L2-blind-review.md 中定义不一致 | 派发的 agent 使用了错误的 agent type | 中（prompt 文件独立维护，hook 中模板可能过期） | 命令模板末尾标注来源文件路径 + "如参数有变请参考 L2-blind-review.md" |
| R4 | pipeline-aware phase 检测改 3 处（Stop hook / SessionStart / L2 detect），若未来新增第 4 处 phase 读取点，可能忘记应用同样逻辑 | 新 hook 重蹈覆辙 | 中 | 将 phase 检测逻辑提取为 `lib/common.sh` 的 `fk_resolve_phase()` 函数，所有 hook 统一调用；未用此函数的新增 phase 读取在 code review 时拦截 |
| R5 | L3 API 依赖外部服务，网络/鉴权故障时 pipeline 在仅有 L2 的情况下继续 | 缺少独立的外部视角审查 | 中 | SessionStart 注入时标注"L3 unavailable (timeout/error), relying on L2 only"；v2 加 L3 重试机制 |
| R6 | L3 API 可能按自身 token 限制二次截断已智能截断的 prompt，截断叠加效应可能仍导致部分假阳性 | 假阳性未完全消除 | 低（智能截断后告知模型上下文不完整，模型会降低武断标记 critical 的概率） | 在截断提示中明确告知模型"信息不完整，请优先标记确定性问题"，减少不确定环境下的武断 critical |

---

## 6. 不在范围

- Phase 4 引入 L2/L3（保持设计决策）
- L2 全自动触发（v2）
- L3 模型切换策略（v2）
- L3 API 重试 + 指数退避（v2）
- L2/L3 结果结构化 diff（v2）
- Stop hook 架构重构（本次只修 29 号模块，不拆/不合其他模块）

---


---

## 7. 测试策略

### 7.1 测试层次

| 层次 | 工具 | 覆盖范围 | 新增测试 |
|---|---|---|---|
| 单元测试 | bats-core | 独立函数（截断算法、phase 检测、done 校验） | ~10 tests |
| 集成测试 | bats-core | hook 脚本端到端（mock API、文件系统） | ~6 tests |
| 回归测试 | bats-core + `npx bats test/` | 现有 94 tests 不退化 | 0（验证现有） |
| 手动验证 | 人工 | AC-2 L3 假阳性控制、AC-5 交互流程 | 见 AC 验证方式 |

### 7.2 新增 bats 测试清单

| 测试文件 | 覆盖内容 | 对应 AC |
|---|---|---|
| `test/l3-truncation.bats` | awk 截断算法：30KB fixture → 断言所有 `##`/`###` 标题行保留 + Given/When/Then AC 行保留 + 输出大小 ≤ max_chars | AC-2 |
| `test/phase-resolution.bats` | fk_resolve_phase()：pipeline mode + current_phase=5 → 期望 5；单阶段 mode + .phase=3 → 期望 3；pipeline + current_phase=5 + .phase=6（过期残留）→ 期望 5（不取 max） | AC-7 |
| `test/l2-detect.bats` | l2_detect()：L2 未完成（无 INDEPENDENT-REVIEW-*.md L2 段）→ 返回非零；L2 完成 → 返回 0；L3-only mode → 返回 0（跳过 L2 检测）| AC-4 |
| `test/done-validation.bats` | fk_validate_done_marker()：6 键齐全 → pass；缺 L3_verdict → fail；缺 L3_summary（非 6 键）→ pass | AC-6 |
| `test/l3-header-detect.bats` | SessionStart header grep：`## L3 盲审` 匹配成功；`## L3 外部模型审查` 兼容匹配成功；无 header → 静默跳过 | AC-1 |

### 7.3 回归安全

- 每次修改后运行 `npx bats test/` 确保现有 94 tests 不退化
- CI/pre-push hook 集成 `make check`（含 test + lint + 打包校验）
- 新增测试必须在 CI 中通过才能合并

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `hooks/stop/lib/l2-detect.sh` | L2 审查完成状态检测 + 一键派发命令生成 | 任何需要检测 L2 是否完成的 hook（gate / stop / session-start） | v1 交付 · 新增 hook 需要 L2 感知时统一调用 `l2_detect()` |
| `lib/common.sh::fk_resolve_phase()` | pipeline-aware 的 phase 解析（统一 `.phase` vs `.goal.current_phase` 的选择逻辑） | 任何需要读取当前 phase 的 hook | v1 交付 · 所有 hook 用此函数替代直接 `jq -r '.phase'`（见 D7） |

### 9.2 新增的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| phase 检测统一入口（v1 已实施） | `fk_resolve_phase()` 为唯一 phase 读取点 | 所有 Stop / SessionStart / PreToolUse hook | v1 已实施——D7 决策，3 处 hook 已改为调用此函数 |
| L2 检测共享 lib（v1 已实施） | `l2-detect.sh` 为 L2 状态检测唯一入口 | PreToolUse gate + 29 号 hook + 各阶段 prompt 调度段 | v1 已实施——D4 决策，3 个调用点已集成 |

### 9.3 禁动清单变化

```
- 新增禁动：禁止直接 jq -r '.phase' 读取阶段——用 fk_resolve_phase() 替代
- 新增禁动：禁止在 hook 中硬编码 L2 Agent 派发命令——用 l2-detect.sh 生成
```
