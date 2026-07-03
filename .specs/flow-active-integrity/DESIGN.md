# DESIGN: 将 .flow-active 状态完整性纳入 L2/L3 检查

- **Change ID**: flow-active-integrity
- **关联**: `@.specs/flow-active-integrity/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

- **选定**：Bash（`set -euo pipefail`）—— 已在 CONTEXT.md 锁定
- **理由**：flow-kit hook 系统全部用 Bash 实现，本项目无运行时依赖变更
- **明确排除**：Python/Node.js hook 重写（不改动 hook 运行时语言）

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep/ls 验证的实际清单）：
- flow-kit-bundle/hooks/stop/lib/correction-file.sh（既有 · 复用 JSON 矫正文件写入）
- flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh（既有 · 引用 PHASE_ARTIFACTS 映射）
- flow-kit-bundle/hooks/stop/stop-hook.json（既有 · 新增 33 号模块入口）
- flow-kit-bundle/flow-kit/prompts/{0-change,1-requirement,2-design,3-task,4-dev,5-test,6-review,7-integration}.md（既有 · 各阶段 PCSC 表加一项）
- flow-kit-bundle/flow-kit/GO.md（既有 · transition jq 段加自检项）
- ~/.claude/flow-kit/prompts/*.md + GO.md（user-scope 副本 · 同步修改）

新增模块：
- flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh（新 · L3 .flow-active 交叉验证）
- test/test_flow_active_integrity.bats（新 · 覆盖 6 条 AC 的检测逻辑）

需修改的既有模块（执行链接线——本 change 必须改，否则 33 号模块不会被执行）：
- flow-kit-bundle/hooks/stop/00-gate.sh（既有 · 新增 run_module 33 调用；同时补齐 31/32 遗漏的接线）
- flow-kit-bundle/hooks/stop/lib/common.sh（既有 · HOOK_MODULE_NAMES 追加 33-flow-active-integrity）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- package-flow-kit.sh（打包逻辑不改）
- flow-kit-bundle/install.sh（安装逻辑不改）
- flow-kit-bundle/hooks/stop/2{0-9}*.sh + 3{0-2}*.sh（现有 20-32 号模块逻辑不改，仅 00-gate 加接线）
- .flow-active JSON schema（R3.1 — 不加字段）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| JSON 矫正文件写入 | `correction-file.sh` — `correction_file_write()` | 沿用，新增 type=`state-integrity` |
| Phase→产物映射 | `flow-kit-artifacts.sh` — `PHASE_ARTIFACTS` | 查表引用，不硬编码 |
| .flow-active 字段读取 | `flow-kit-artifacts.sh` — `fk_flow_field()` | 沿用 |
| Stop hook 模块注册 | `stop-hook.json` — `modules.{name}.enabled` | 沿用，新增 33 号条目 |
| bats 测试框架 | `npx bats` + 既有的 `test/` 目录结构 | 沿用 |

### 0.5.3 沿用模式 vs 引入新模式

- Hook 模块：**沿用** 编号命名惯例（`NN-description.sh`）+ `stop-hook.json` 注册模式
- 错误处理：**沿用** `set -euo pipefail` + 容错跳过（不阻断 hook 链）
- 矫正文件格式：**沿用** `correction-file.sh` 的 JSON 结构（type + violations[] + written_at）
- 测试：**沿用** bats-core + `test/` 目录 + `setup()/teardown()` 模式

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **新建 33 号独立模块**，不扩展 28-weak-model-compliance | 在 28 号模块追加 .flow-active 检查逻辑 | 关注点分离：28 号做规则合规（L1/L2/L3 违规检测），33 号做状态一致性（字段↔产物交叉验证）。合并会导致 28 号职责模糊、测试困难 | 多一个 hook 模块 + 一个 stop-hook.json 条目；但每个模块更短、更可测试 |
| D2 | L2 **PCSC 表新增检查项**（各 prompt + GO.md），统一锚点文本 `".flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘"` | 每个 prompt 写不同的自检文本 | 统一锚点文本使 grep 验证可机器执行（AC-1），避免"各阶段写了但文本不同导致验证漏检" | 所有阶段用同一文本略冗余但可接受 |
| D3 | updated_at 时效性阈值默认 **24h**，env var `FLOW_ACTIVE_STALE_HOURS` 可覆盖 | 固定 24h 不可调 / 12h / session 粒度 | 24h 是合理默认（跨天未更新 = 明显异常），env var 给极端场景 escape hatch | 阈值不可自动适应项目节奏（如一周用一次的 repo），需手动设 env var |
| D4 | token_spent 检测用 **transcript grep**（`grep 'jq.*\.flow-active'` 计数 + token_spent=0 对比），**不自动统计** token 数 | 自动解析 transcript 统计实际 token 消耗（v2）/ 不做此检测 | transcript grep 简单可靠，满足 v1 目标（检测"未维护"）；自动统计涉及 transcript JSON 格式解析，复杂度高且格式可能变更 | 只能检测"是否维护过"，不能检测"值是否准确"；但后者远复杂且非 v1 目标 |
| D5 | **change_id=null 时不报警**（除非同时存在活跃 `.specs/` 子目录） | 一律报警/null 时跳过 | change_id=null 是合法初始状态（`/flow start` 后未创建 change）；只在"null + 存在产物目录"这种矛盾场景报警 | 需额外判断逻辑；但避免大量误报 |
| D6 | PCSC 自检项加在 **prompt 源文件**（`flow-kit-bundle/flow-kit/prompts/`）+ **同步到 user-scope**（`~/.claude/flow-kit/`） | 只改一处 | 两处都要生效：bundle 是维护源，user-scope 是运行时（本项目用 user-scope）；install.sh 会同步但不应依赖安装 | 每次 prompt 变更需两处同时编辑；但本项目已是这模式（见独立审查四层架构的双写要求） |

---

## 2. 数据流 / 架构图

```
Session 结束
     │
     v
Stop Hook Chain (00-gate → ... → 32-fallback-guard → 33-flow-active-integrity)
     │
     v
33-flow-active-integrity.sh
     │
     ├─(1) 读 .flow-active ── jq 解析 change_id / phase / task_id / goal / token_spent / updated_at
     │       │
     │       ├─(2) 读 PHASE_ARTIFACTS ── source flow-kit-artifacts.sh
     │       │
     │       ├─(3) 交叉验证 ─┐
     │       │               ├─ check_change_id:   .specs/<change_id>/ 存在？
     │       │               ├─ check_phase:       .specs/<change_id>/<phase产物> 存在？
     │       │               ├─ check_pipeline:    phases_done ↔ gates ↔ 产物 三者自洽？
     │       │               ├─ check_staleness:   updated_at 在 FLOW_ACTIVE_STALE_HOURS 内？
     │       │               └─ check_token:       token_spent=0 但 transcript 含 jq .flow-active？
     │       │
     │       └─(4) 任一失败 → correction_file_write(type="state-integrity", violations=[...])
     │
     v
correction-file.sh ── 写入 .flow-active.correction
     │
     v
SessionStart 下一轮 ── flow-kit-resume.sh 注入矫正 banner
```

## 3. 关键状态机

本 change 无新增状态机。33 号模块是纯检测逻辑（输入 .flow-active → 输出 violations[]），无状态流转。

## 4. ADR 索引

本次决策均可逆（调整 hook 模块编号、改阈值、调整检测粒度），不产生不可逆 ADR。

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **误报过多**：合法的中间状态被判为漂移（如 phase=2 但 DESIGN.md 正在写尚未落盘） | 用户对矫正文件疲劳，忽视真正问题 | 中 | 矫正文件 type=`state-integrity` 独立分类，不影响 compliance 矫正；Phase 检测只查"必须产物"（已定义在 PHASE_ARTIFACTS），不查可选文件 |
| R2 | **transcript grep 假阳性**：transcript 中 `jq.*\.flow-active` 匹配到的是读操作（如 `jq '.phase' .flow-active`）而非写操作 | token_spent 检测误报 | 低 | grep 模式细化为 `jq '.*=' .flow-active` 或 `jq.*>.*\.flow-active`（写操作特有模式） |
| R3 | **hook 链性能退化**：33 号模块 I/O 过多（读 .flow-active + 遍历 .specs/ + 读 transcript） | Stop hook 总耗时增加 | 低 | 全部本地文件读取，jq 操作 < 100ms；transcript 仅在 token_spent=0 时才 grep（短路优化）；总预期 < 200ms |
| R4 | **PHASE_ARTIFACTS 未定义阶段**：phase=0 或 phase=2a 在 PHASE_ARTIFACTS 中无直接映射 | 交叉验证跳过这些阶段时漏检 | 低 | 检测到未定义阶段时写 info 日志（不报警）；phase 0 和 2a 产物少且常人工执行，跳过可接受 |
| R5 | **bundle 与 user-scope 不同步**：只改了一处 prompt，另一处漏改 | 安装后 L2 自检不一致 | 中 | D6 决策：两处同步编辑；`make check` 已含打包完整性校验（L-012）可检测遗漏 |

## 6. 不在范围

- token_spent 自动统计（v2）
- `/flow doctor` 扩展自动修复漂移（v2）
- 实时文件监控（out）
- .flow-active JSON schema 变更（out）
- 跨 session 趋势分析（out）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `hooks/stop/33-flow-active-integrity.sh` | `.flow-active` 字段与磁盘产物交叉验证 | 每次 session 结束时自动运行 | 未来若 .flow-active 新增字段，在此模块追加验证函数即可，不改框架 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| .flow-active 完整性检测归属 | 独立 33 号模块（非 28 号扩展） | Hook 模块组织方式 | 低——合并回 28 号约 30min 工作量 |
| token_spent 检测粒度 | v1 仅检测"是否维护"，不验证准确性 | token_spent 字段使用方式 | 低——v2 可升级为自动统计 |

### 9.3 新增 / 修改的跨模块契约

```
- 矫正文件新增 type="state-integrity"，与现有 "compliance"/"interactive-ui" 并列
- 33 号模块依赖 correction-file.sh 的 correction_file_write() 函数签名不变
- env var FLOW_ACTIVE_STALE_HOURS（默认 24），33 号模块读取，其他模块不感知
```

### 9.4 新增 / 升级的依赖

无新增外部依赖。33 号模块复用既有 lib（correction-file.sh、flow-kit-artifacts.sh）和标准工具（jq、grep）。

### 9.5 禁动清单变化

```
- 新增禁动：flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh（本 change 产物，后续不应被无关 change 修改）
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
