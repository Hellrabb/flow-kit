# DESIGN: 弱模型鲁棒性 Hook 化升级

- **Change ID**: `robustness-hook-hardening`
- **关联**: `@.specs/robustness-hook-hardening/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 纯 Bash 脚本项目（meta/distribution 类型），CONTEXT.md 已锁定技术栈。无需选型，直接沿用。

- **选定**：Bash + jq + grep/sed/awk（POSIX 工具链）
- **语言/运行时**: Bash ≥ 4.0（与现有 hook 系统一致）
- **JSON 处理**: jq（已在环境中有，`install.sh` 环境检查覆盖）
- **测试**: bats-core 1.13.0（`npx bats`，与现有 194 tests 一致）
- **部署**: 通过 `flow-kit-bundle/hooks/` 源码分发（与其他 stop hook 模块相同的 `install.sh` 安装路径）
- **关键依赖**: `common.sh`（hook 框架）、`transcript-parser.sh`（transcript 解析，按需 source）
- **理由**：项目无前端/后端/DB，仅做 hook 脚本扩展，无需引入任何新语言或运行时
- **明确排除**：不引入 Python/Node.js 做 NLP 分析（grep 正则匹配足够，350 行预算不支持复杂依赖）

---

## 0.5 既有架构对齐（brownfield 必填 · 来自 2-design 步骤 0.5 / B2 老项目护栏）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep/ls 出来的实际清单）：
- flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh（既有 · 参考模式）
- flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh（既有 · 参考 lib 结构）
- flow-kit-bundle/hooks/stop/lib/common.sh（既有框架 · 复用 module_output/init_paths 等）
- flow-kit-bundle/hooks/stop/lib/transcript-parser.sh（既有 · 复用 transcript 解析）
- flow-kit-bundle/hooks/session-start/flow-kit-resume.sh（既有 · 扩展矫正注入段）
- .claude/stop-hook.json（既有配置 · 新增模块条目）
- .specs/CONTEXT.md（既有 · 禁动清单段读取源）

新增模块：
- flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh（新 · 协调层）
- flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh（新 · 扫描逻辑库）
- test/test_weak_model_compliance.bats（新 · 测试文件）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh（v1 不改 27 号模块，仅参考其模式）
- flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh（同上）
- package-flow-kit.sh（打包脚本核心，改坏影响分发）
- flow-kit-bundle/install.sh（安装脚本，本次不改安装逻辑）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| Hook 框架（module_init / module_output / config） | `lib/common.sh` 有 | **沿用** `source lib/common.sh` + `module_enabled` + `module_output` |
| Transcript 解析（提取工具调用/消息/文件路径） | `lib/transcript-parser.sh` 有 | **沿用** `source lib/transcript-parser.sh`，追加 L3 所需的新查询函数 |
| 矫正文件管理（init / write / read / clear / retry） | `lib/interactive-ui-check.sh` 有模式 | **参考但不复用** — 统一矫正文件格式不同（`type` 字段），独立实现在 `lib/weak-model-compliance.sh` 中 |
| Stop hook 模块结构（协调层 + lib 分离） | 27-interactive-ui-check 模式已建立 | **沿用** — coordinator 脚本 `28-weak-model-compliance.sh`（薄）+ lib `weak-model-compliance.sh`（厚） |
| SessionStart 矫正注入 | `flow-kit-resume.sh` 已有 interactive-ui 矫正段 | **扩展** — 在现有 `interactive-ui-fix` block 后追加 `compliance-fix` block |

### 0.5.3 沿用模式 vs 引入新模式

```
- Hook 模块注册：**沿用** stop-hook.json modules 字典，新增 "weak_model_compliance" 条目
- 模块开关：**沿用** module_enabled() gate（Stop hook 00-gate.sh 加载前判断）
- 矫正文件：**引入新模式** — 统一 JSON 格式（type + layer + violations[]），替代 interactive-ui 的单一 gate_type 格式。理由：需支持多层级多违规聚合，未来 v2 迁移 27 号模块也走此格式
- Transcript 数据获取：**沿用** transcript-parser.sh 的已解析文件（$HOOK_TMP_DIR/tool-calls.txt, messages.txt 等）
- 错误处理：**沿用** 所有 Stop hook 的 ( ) || true subshell 保护模式（单模块崩溃不影响 hook 链）
- Stop hook 模块编号：**沿用** 两位数编号惯例（28-weak-model-compliance.sh，排在 27-interactive-ui-check 后、30-ai-analyze 前）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **统一矫正文件格式** `.flow-active.correction`（JSON，含 `type` + `layer` + `violations[]`），v1 仅写 `type: "compliance"`；27 号模块保持旧文件 `.flow-active.interactive-ui-fix`，SessionStart 并行处理两个文件 | 方案 B：两模块共用同一文件，用 type 字段区分 → 需同时改 27 号模块，范围变大且增加回归风险 | Q1 用户选 A（统一文件），但 v1 不改 27 号模块以控制风险。SessionStart 同时处理两个文件，过渡期清晰 | 两个矫正文件并存增加 SessionStart 复杂度（多一个 `if [[ -f` block，约 20 行）；v2 迁移 27 号时可删旧路径 |
| D2 | **L1 扫描范围**：CONTEXT.md 禁动清单精确匹配 + RULES.md/SYSTEM.md 通用禁动规则的模式匹配（如"禁止编造文件路径"→ 交叉验证工具调用历史） | 方案 A：仅精确匹配禁动清单 3 个路径（范围小但漏检多）| Q2 用户选 B（扩展规则）。L1 作为"规则合规"层必须覆盖规则全文，否则弱模型违反通用规则无法被 hook 捕获 | L1 与 L3 在"文件路径真实性"上存在重叠——都检查文件路径是否出现在工具调用中。设计上 L1 侧重"规则文本匹配"，L3 侧重"路径存在性验证"，两者互补不互斥 |
| D3 | **L2 自检表匹配策略**：硬编码 PCSC 自检表格式（`| # | ... | ✅ / ❌ |`），在 assistant 消息中 grep 此模式后逐行验证每行非空 | 方案 B：自动发现任意表格格式（需更复杂的解析逻辑，超出 350 行预算）| 当前 flow-kit prompt 中自检表格式统一（PCSC），硬编码匹配简单可靠。后续新 prompt 引入新表格格式时需手动追加匹配规则 | 新自检表格式需要手动更新匹配模式（v2 可做自动发现）。当前所有阶段 prompt 均使用 PCSC 格式，覆盖充分 |
| D4 | **L3 证据链验证粒度**：提取 assistant 消息中的文件路径（`flow-kit/`、`.specs/`、`src/` 等已知前缀限定的路径模式），逐一与 transcript 中 Read/Grep/Glob/Bash(ls/find) 工具调用历史交叉验证 | 方案 B：NLP 语义分析（提取"根据 X 文件"等引用模式）——超出 grep 能力和 350 行预算 | Grep 正则匹配路径模式是确定性操作，误报可控。路径模式限定已知前缀避免匹配到自然语言中的伪路径 | 无法检测模型"口头引用"（如"根据之前的分析"而不提具体路径），但这类模糊引用本身就是弱模型应避免的模式，L2 自检表已要求写具体路径 |
| D5 | **代码长度 350 行软指标**（Q3 用户选 B）：主逻辑代码 350 行目标，超出时人工判断 | 方案 A：硬门禁（≤350 行否则阻断 CI）| 用户选软指标。350 行是设计目标而非硬约束——hook 逻辑清晰度优先于行数 | 可能超出预算（估计实际 300~380 行），需在实现时主动控制复杂度（拆分辅助函数、复用 transcript-parser 解析结果） |
| D6 | **矫正文件多 session 同一 change 内的多次写入行为**：合并（append violations）而非覆盖。同一 session 不重复写（幂等——同 layer+同 rule 视为重复） | 方案 B：覆盖（每次 Stop 重写）→ 丢历史 | 合并保留完整违规历史，SessionStart 一次性展示所有违规；幂等避免同一 session 反复触发同一规则时矫正文件膨胀 | 需要读-合并-写逻辑（约 15 行 jq），略微增加复杂度 |

---

## 2. 数据流 / 架构图

```
┌──────────────────────────────────────────────────────────────────┐
│                        SESSION STOP EVENT                         │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                   ┌─────────▼──────────┐
                   │  00-gate.sh        │  module_enabled gate
                   │  (hook 链入口)      │
                   └─────────┬──────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────▼─────┐      ┌──────▼──────┐     ┌──────▼──────┐
    │ 27-iu    │      │ 28-wmc (新) │     │ 30-ai ...   │
    │ check    │      │             │     │             │
    └──────────┘      └──────┬──────┘     └─────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
       ┌──────▼──────┐ ┌─────▼─────┐ ┌──────▼──────┐
       │ L1 扫描     │ │ L2 扫描   │ │ L3 扫描     │
       │ (禁动清单   │ │ (自检表   │ │ (证据链     │
       │  + 通用规则) │ │  完整性)   │ │  真实性)    │
       └──────┬──────┘ └─────┬─────┘ └──────┬──────┘
              │              │              │
              └──────────────┼──────────────┘
                             │ violations[]
                    ┌────────▼─────────┐
                    │ 合并 + 幂等检查   │
                    │ (读旧 → 合并 →    │
                    │  去重 → 写入)     │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │ .flow-active     │
                    │ .correction      │  JSON (gitignored)
                    └──────────────────┘


┌──────────────────────────────────────────────────────────────────┐
│                       SESSION START EVENT                         │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                   ┌─────────▼──────────┐
                   │ flow-kit-resume.sh │
                   └─────────┬──────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
    ┌─────────▼──────┐ ┌─────▼────────┐    │
    │ 检查            │ │ 检查          │   │
    │ .interactive   │ │ .correction   │   │
    │ -ui-fix        │ │ (NEW)         │   │
    └────────┬───────┘ └─────┬─────────┘   │
             │               │              │
    ┌────────▼───────┐ ┌─────▼─────────┐   │
    │ 注入 UI 矫正   │ │ 注入合规矫正   │   │
    │ banner         │ │ banner         │   │
    └────────────────┘ └───────────────┘   │
                                           │
                              ┌────────────▼──────┐
                              │ 标准 resume       │
                              │ banner            │
                              └───────────────────┘
```

**关键边界**：
- hook 模块**只读取** transcript（`$TRANSCRIPT_PATH`）和 `.specs/`（CONTEXT.md），**不写入**任何源码文件
- 矫正文件 `.flow-active.correction` 的**唯一写入者**是 28 号模块，**唯一读取并清除者**是 SessionStart flow-kit-resume.sh
- L1/L2/L3 扫描之间**完全独立**，任一层失败不影响其他层（各自 `|| true` 保护）

---

## 3. 关键状态机

### 矫正文件生命周期

```
                  ┌──────────┐
                  │ 不存在   │ ◄──── 初始状态 / SessionStart 已清除
                  └────┬─────┘
                       │ Stop: L1/L2/L3 检测到违规
                       ▼
                  ┌──────────┐
                  │ 存在     │ ──── Stop: 新违规 → 合并追加 (幂等去重)
                  │ (有违规) │
                  └────┬─────┘
                       │ Stop: 本次无违规 + 旧违规可能已修复
                       ▼
              ┌────────┴────────┐
              │                 │
        ┌─────▼──────┐  ┌──────▼─────┐
        │ 模型已修复  │  │ 违规仍存在  │
        │ → 清除文件  │  │ → 保留文件  │
        └────────────┘  └────────────┘
              │                 │
              ▼                 ▼
         SessionStart      SessionStart
         无矫正 banner     注入矫正 banner
         正常 resume       + 清除文件
```

> **"模型已修复"判断**：当 Stop 检测到 0 违规 + 矫正文件存在时，清除矫正文件（认为模型在后续 turn 中自我纠正了）。这要求 Stop hook 每次都跑 L1/L2/L3 扫描（不仅当矫正文件存在时）。

---

## 4. ADR 索引

本 change 无不可逆架构决策。唯一值得记录的取舍是统一矫正文件格式，但这属于 flow-kit hook 系统内部格式演进，不影响外部接口。不单独写 ADR。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **L3 路径匹配误报**：模型回复中的自然语言片段被误识别为文件路径（如"参考 flow-kit/prompts 目录"），导致虚假 L3 违规 | 矫正 banner 提示模型做不必要的"补 grep"，浪费一轮 turn | 中 | 路径模式限定已知前缀（`flow-kit/`、`.specs/`、`src/`、`test/`、`~/.claude/`），要求路径含 `/` 且至少两级深度；误报仍可能发生但不阻断流程（矫正 banner 为建议性） |
| R2 | **transcript 格式变更**：CC transcript JSONL 格式变动导致 jq 提取失败或字段名变化 | L1/L2/L3 扫描静默失败（不写入矫正），漏检违规 | 低 | 所有 transcript 解析通过 transcript-parser.sh 的已解析中间文件（`$HOOK_TMP_DIR/*.txt`），而非直接 jq transcript。transcript-parser.sh 变更时由该模块维护者统一适配，本模块间接受益 |
| R3 | **jq 不可用**：目标环境未安装 jq | 矫正文件 JSON 构建失败，SessionStart 解析失败，合规检测完全失效 | 低 | `install.sh` 环境检查已覆盖 jq；若 jq 缺失，`28-weak-model-compliance.sh` 降级为纯文本矫正文件（fallback 格式：`TYPE|LAYER|RULE|FIX`），SessionStart 检测 JSON 解析失败时输出警告并跳过（不阻断 resume） |
| R4 | **长期债务：规则模式硬编码**：L1/L2 的匹配模式（禁动清单格式、自检表格式）硬编码在 lib 中 | 当 CONTEXT.md 禁动清单格式或 prompt 自检表格式变化时，hook 检测失效 | 中 | 在 test 文件中加入"格式契约测试"——验证 CONTEXT.md 禁动清单段和 prompt 自检表的实际格式是否与 lib 中硬编码的模式一致。不一致时测试 fail 提醒更新 lib |
| R5 | **矫正文件与 interactive-ui-fix 冲突**：两个矫正文件同时存在时，SessionStart 注入两个 banner 可能让弱模型信息过载 | 弱模型在两个矫正指令间混淆，可能只执行其中一个 | 低 | 两个 banner 串行输出（compliance 在前，interactive-ui 在后），各有独立的优先级标记。v1 概率低（两种违规通常不会同时触发），v2 合并文件后自然解决 |

---

## 6. 不在范围

- 不做实时检测（hook 只在 session 边界执行）
- 不迁移 27-interactive-ui-check.sh 到统一矫正文件格式（v2）
- 不引入 retry_count 机制到 compliance 矫正文件（v1 每次检测到就注入，不追踪连续跳过次数；v2 对标 interactive-ui 的 retry 策略）
- 不做 L2 自检表格式的自动发现（新 prompt 引入新表格格式时需手动更新匹配规则）
- 不做 L1 规则模式的自动提取（不从 RULES.md/SYSTEM.md 自动解析规则，硬编码已知规则模式）
- 不改动现有 prompt 文件（prompt 护栏保持不变，hook 是第二道兜底防线）

---

## 9. 架构沉淀建议（本 change 完成后供 `A-evolve` 同步用 · 软约束）

### 9.1 新增的可复用抽象（建议 append 到 CONTEXT「既有抽象索引」段）

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh` | 弱模型合规 scanning 函数库：L1 禁动清单检测 / L2 自检表完整性 / L3 证据链真实性 | 任何需要验证模型回复合规性的 hook 或脚本 | 函数粒度：`scan_l1_forbidden()` / `scan_l2_selfcheck()` / `scan_l3_evidence()` / `read_forbidden_list()` / `extract_paths_from_message()` 均可独立调用 |
| `.flow-active.correction`（JSON 格式） | 统一矫正文件格式：`type` + `layer` + `violations[]` | 任何 Stop hook 检测到需要跨 session 传递矫正指令的场景 | v2 迁移 27 号模块写入此文件（`type: "interactive-ui"`），替代旧 `.flow-active.interactive-ui-fix` |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 矫正文件统一格式 | JSON `{type, layer, violations[], written_at}` | 所有 Stop hook 模块的矫正文件写入 + SessionStart 的矫正注入 | 低——仅 flow-kit 内部 hook 系统，无外部依赖。推翻只需改 JSON schema + 两个读写端 |

### 9.3 新增 / 修改的跨模块契约

```
- 矫正文件 .flow-active.correction 的 JSON schema（新增）：
  { "type": "compliance", "layer": "L1|L2|L3", "violations": [{"rule": "...", "location": "...", "fix": "..."}], "written_at": "ISO8601" }
- SessionStart flow-kit-resume.sh 的合规矫正 banner 格式（新增）：
  ╔══════════════════════════════════════╗
  ║  ⚠️ 合规矫正：上轮弱模型违规          ║
  ║  L1/L2/L3: <违规描述>                ║
  ║  修复动作: <具体指令>                ║
  ╚══════════════════════════════════════╝
```

### 9.4 新增 / 升级的依赖

无。不引入新依赖（仅使用既有 Bash + jq + grep/sed/awk）。

### 9.5 禁动清单变化

```
- 新增禁动：无（本 change 不新增禁动文件）
- 解禁：无
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
