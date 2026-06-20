# DESIGN: 修复 pipeline toll-gate 阶段跳过漏洞

- **Change ID**: phase-skip-fix
- **关联**: `@.specs/phase-skip-fix/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 本项目为 Bash/meta 项目，技术栈已在 CONTEXT.md 锁定。不涉及技术栈变更。

- **语言/运行时**: Bash（`set -euo pipefail`）
- **测试**: bats-core 1.13.0（`npx bats`）
- **状态管理**: jq 1.6+（JSON 读写 `.flow-active`）
- **部署**: `package-flow-kit.sh` 打包 → `install.sh` 分发
- **理由**: 本次仅修改 prompt 文本 + GO.md 路由逻辑 + 新增 bats 测试，均在既有栈内，无需引入新工具

---

## 0.5 既有架构对齐

### 0.5.1 本次 change 触碰的既有模块

```
修改文件（prompt 层）：
- flow-kit/prompts/1-requirement.md（既有 · 在 toll-gate 前插入 PCSC 段）
- flow-kit/prompts/2-design.md（既有 · 在 toll-gate 前插入 PCSC 段）
- flow-kit/prompts/3-task.md（既有 · 在 toll-gate 前插入 PCSC 段）
- flow-kit/prompts/4-dev.md（既有 · 在 toll-gate 前插入 PCSC 段 + start_phase 读取已有）
- flow-kit/prompts/5-test.md（既有 · 在 toll-gate 前插入 PCSC 段 + auto_advance 适配 + start_phase 修复）
- flow-kit/prompts/6-review.md（既有 · 在 toll-gate 前插入 PCSC 段 + auto_advance 适配 + start_phase 修复）
- flow-kit/prompts/7-integration.md（既有 · 在 pipeline 完成前插入 PCSC 段 + start_phase 修复）

修改文件（路由层）：
- flow-kit/GO.md（既有 · 在第二步 Artifact Preflight Gate 后新增 Phase Completion Gate 表 + 路由拦截逻辑）

修改文件（规格层）：
- .specs/CONTEXT.md（既有 · 新增 PCSC/PCG/artifact verification 术语——已在 Phase 1 完成）

新增文件：
- test/test_phase_gate.bats（新 · toll-gate 自检段 + GO.md PCG 测试）
- .specs/phase-skip-fix/CHANGE.md（新 · Phase 0 产出）
- .specs/phase-skip-fix/REQUIREMENT.md（新 · Phase 1 产出）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- package-flow-kit.sh（打包脚本核心逻辑）
- install.sh / flow-kit-bundle/lib/*（安装脚本，与本次修复无关）
- .claude/hooks/*（hook 系统，与本次修复无关）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| JSON 状态读写 | jq（`.flow-active` 操作） | 沿用——所有 transition/回退 jq 命令保持现有模式 |
| 测试框架 | bats-core 1.13.0（`test/`） | 沿用——新测试文件放 `test/`，命名 `test_phase_gate.bats` |
| prompt 模板结构 | 各 `flow-kit/prompts/*.md` 现有结构 | 沿用——PCSC 插入在「你的职责」段之后、「Pipeline Toll-Gate」段之前 |
| GO.md 路由表 | `flow-kit/GO.md` 第二步 Artifact Preflight Gate | 扩展——在既有表后新增 Phase Completion Gate 表 |
| toll-gate 交互模式 | 现有「停下来。必须等待用户回复」+ jq transition | 沿用——不改交互模型，PCSC 是 toll-gate 的前置条件 |
| auto_advance | 4-dev 选项 4 → `auto_advance=true` → 5/6 检查 | 适配——保留现有 auto_advance 行为，在 auto-transition 前嵌入 PCSC |

### 0.5.3 沿用模式 vs 引入新模式

```
- 状态管理：**沿用** jq 临时文件 + mv 原子写入模式（`.flow-active.tmp` + `mv`）
- prompt 结构：**沿用** 现有 markdown 层级（## 角色 / ## 输入 / ## 你的职责 / ## Pipeline Toll-Gate）
- 测试模式：**沿用** bats `@test` 命名约定 + `setup/teardown` 模式
- Phase Completion Gate：**引入新模式** → 理由：GO.md 此前只有「进入阶段的 artifact preflight」，没有「退出阶段的 artifact check」。本质是 preflight 的对称扩展
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **PCSC 放在 prompt 内**（「你的职责」之后、「Pipeline Toll-Gate」之前） | 放在 GO.md 路由层统一检查 | prompt 内自检可结合具体阶段上下文（如"TEST.md 应包含 5 轮测试结果"），比 GO.md 的纯文件存在性检查更细粒度 | AI 可能跳过 prompt 指令——这是 D2 存在的原因 |
| D2 | **PCG 放在 GO.md 路由层**（第二步 Artifact Preflight Gate 之后） | 外部 Stop Hook 脚本 | GO.md 每次路由必加载，无需额外安装或维护 hook 配置；与既有 Artifact Preflight Gate 对称，学习成本低 | 仅检查文件存在性，不检查文件内容完整性（如空文件可通过检查） |
| D3 | **auto_advance 保留但嵌入 PCSC** | 移除 auto_advance 选项 | auto_advance 是用户主动选择的全自动模式（设计行为），移除会降低效率。嵌入 PCSC 后：全 ✅ 自动过渡，有 ❌ 暂停 | auto_advance 快的好处保留，但产物缺失时会中断自动流 |
| D4 | **PCSC 产物清单与 PCG 产物清单保持完全一致** | 各自独立维护 | 单一真源避免不一致。若后续某阶段产物变化，只需改一处（prompt 自检段），PCG 表同步更新 | 两份清单仍需手动同步——bats 测试（AC-5）可检测不一致 |
| D5 | **不引入新文件格式或 schema** | JSON/YAML 产物清单配置 | 保持简单：产物清单硬编码在 prompt 和 GO.md 中，无外部配置文件 | 修改产物清单需改源码（prompt），但 flow-kit 阶段产物极少变化，实际代价很低 |
| D6 | **TD-003 修复采用统一 fallback 模式** `current_phase // .start_phase // "4"` | 各 prompt 各自处理 | 与 GO.md 和 4-dev.md 已用模式一致，减少认知差异 | start_phase 缺失时仍 fallback 到 "4"，对 `--from 0` pipeline 行为无影响（此时 start_phase 必然存在） |

---

## 2. 数据流 / 架构图

### 双层防护流程（正常路径）

```
User runs /flow-go 继续（pipeline goal mode）
         │
         ▼
    ┌── GO.md 路由 ──┐
    │                │
    │  Phase Completion Gate（第二层）
    │  检查 phase N 产物是否存在？
    │     │
    │     ├─ 缺失 ──> ❌ 拒绝路由，输出缺失清单 → user fixes
    │     │
    │     └─ 存在 ──> ✅ 放行，加载 Phase N+1 prompt
    └────────────────┘
         │
         ▼
    Phase N+1 prompt 执行工作...
         │
         ▼
    ┌── Phase N+1 prompt ──┐
    │                       │
    │  Phase Completion Self-Check（第一层）
    │  逐项自检产物 ✅/❌
    │     │
    │     ├─ 有 ❌ ──> 禁止进入 toll-gate → 补齐缺失项 → 重新自检
    │     │
    │     └─ 全 ✅ ──> 进入 toll-gate
    │                    │
    │                    ├─ auto_advance=true ──> 自动 transition → 回到 GO.md
    │                    ├─ 用户选 1 ──> transition jq → 回到 GO.md
    │                    └─ 用户选 2 ──> 暂停
    └───────────────────┘
```

### auto_advance=true 分支

```
Phase N prompt 完成工作
         │
         ▼
    PCSC 自检
      │
      ├─ 全 ✅ ──> ✅ "自检通过，自动进入 Phase N+1" → transition jq → GO.md
      │
      └─ 有 ❌ ──> 🛑 暂停 pipeline
                   输出缺失清单
                   等待用户决定：
                     1. 补齐后重试
                     2. 跳过（手动设置 phases_done）
                     3. 回退到建议阶段
```

---

## 3. 关键状态机

本 change 不引入新状态机。PCSC 和 PCG 都是无状态的检查点。现有的 `.flow-active.goal` 字段（`current_phase` / `phases_done` / `gates` / `auto_advance`）不变。

---

## 4. ADR 索引

本次无需要独立 ADR 的决策。D1-D6 的可逆性均为低——若 PCSC/PCG 方案效果不理想，回滚只需移除 prompt 中的自检段和 GO.md 中的 PCG 表。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **AI "假装"通过 PCSC 自检**：AI 标注全 ✅ 但实际未检查文件 | 第一层防护失效，但第二层（GO.md PCG）仍会拦截 | 中 | 双层防护互补；PCG 独立于 prompt，AI 无法控制 GO.md 路由逻辑 |
| R2 | **空文件绕过**：AI 创建空的 TEST.md / REVIEW.md 以通过检查 | 产物存在但内容为空，阶段未真正完成 | 低 | PCSC 自检项可要求"内容非空"（如 `test -s` 代替 `test -f`）。本次先做 `test -f`，v2 可加内容深度校验 |
| R3 | **change_id 为空时 PCG 失败**：GO.md 路由时 `.flow-active.change_id` 为 null | PCG 无法定位产物路径 `.specs/<id>/`，检查失败 | 低 | PCG 仅在 pipeline goal 模式触发（此时 change_id 必然已设）。加 guard：若 change_id 为空 → 跳过 PCG + 警告 |
| R4 | **prompt 文件修改引入格式错误**：插入 PCSC 段时破坏既有 prompt 结构 | 阶段 prompt 无法正常渲染，AI 行为异常 | 低 | 每个修改均在既有 `## Pipeline Toll-Gate` 标题前插入，不改变其他段结构；bats 测试验证 prompt 结构完整性 |

---

## 6. 不在范围

- PCSC 不检查产物内容深度（如 TEST.md 中的测试覆盖率是否 ≥ 80%），只检查文件存在性
- PCG 不检查 `.specs/<id>/` 之外的文件（如 `src/` 代码变更是否正确）
- 不引入外部 hook 脚本做第三层防线
- 不改变 toll-gate 的交互模式（仍是 AI 提示 + 用户选择 1/2/3）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

本 change 无新增可复用抽象。PCSC 和 PCG 是 flow-kit 内部机制，不对外暴露 API。

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 阶段产物验证策略 | 双层防护（prompt PCSC + GO.md PCG） | 所有 pipeline goal 执行 | 低——回滚只需移除 prompt 自检段和 GO.md PCG 表 |

### 9.3 新增 / 修改的跨模块契约

```
- flow-kit/prompts/*.md：新增「阶段完成自检」段，位置统一为「## Pipeline Toll-Gate」标题之前
- flow-kit/GO.md：新增「Phase Completion Gate」段，位置为第二步 Artifact Preflight Gate 表之后
- 产物清单：各阶段必须产物定义（见 § 2 PCG 表），prompt PCSC 与 GO.md PCG 必须一致
```

### 9.4 新增 / 升级的依赖

无。所有修改均在既有 Bash + jq + bats 栈内。

### 9.5 禁动清单变化

```
- 新增禁动：无
- 解禁：无
```
