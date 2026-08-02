# 阶段 5 · TEST — 五轮测试金字塔

> **核心思想**：测试不是"跑一下单测"，是 5 个维度的金字塔。
> 每轮按项目类型可裁剪。本 prompt 决定**做哪几轮**；具体怎么做查 `@flow-kit/reference/test-pyramid.md`。

> @see `flow-kit/reference/narration-constraint.md` — 工具调用间最多 1 行 narration
> @see `flow-kit/reference/terse-contract.md` — test report 输出遵守 terse contract

## 角色

Test Engineer。

## 输入

- `@.specs/<change-id>/REQUIREMENT.md`（AC + 非功能性需求）
- `@.specs/<change-id>/DESIGN.md`（**必读 `## 0. 技术栈选定`**——5 轮各项的工具选择必须匹配栈：JS 用 Vitest / Playwright / k6，Python 用 pytest / locust，Go 用 testing / vegeta）
- `@.specs/<change-id>/TASK.md`
- 各任务的 `*-SUMMARY.md`
- 已存在的测试代码
- `@flow-kit/reference/test-pyramid.md`（5 轮的工具 / 标准 / 清单）

## Pipeline Goal 入场检测

进入 5-test 后，检测 `.flow-active` 的 `goal` 字段：

```bash
jq -r '.goal | "\(.scope // "phase")|\(.start_phase // "4")|\(.current_phase // .start_phase // "4")|\(.phases_done // [] | join(","))|\(.auto_advance // false)"' .flow-active
```

若 `scope` = `"pipeline"` 且 `current_phase` = `"5"`：
- 展示 pipeline 横幅：4✅ → 5🔄 → 6⏸ → 7⏸
- 标注 "当前阶段：5-test"
- 若 `phase_sub_goals["5"]` 非空 → 展示 sub-goal

---

## 独立 review 调度（仅当本阶段 gate 开启时执行）

> ⚠️ L2 盲审必须在本阶段产物完成后、toll-gate 前完成。跳过 L2 = gate deny transition。

> **检测**：`.flow-active.goal.gate_config["5-test"]` ∈ {`L2`,`both`}（`independent`/`true` 向后兼容映射为 `both`），或 `.claude/stop-hook.json` 的 `independent_review.phases` 含 `"5-test"`。未开启 → 跳过本段，直接进「阶段完成自检」。

本阶段产物必须通过两层独立 review 才能切阶段 / commit / 开 PR。开启时这三项操作被 PreToolUse hook 硬拦，直到你写 done 标志。

### L2 · 独立子 agent 盲审（你负责调度）

派一个**固化盲审子 agent**。**强制独立性**：prompt 字段 = 原样注入 `@flow-kit/prompts/independent/L2-blind-review.md` 全文 + 末尾的本次审查参数；**禁止**附加你的自评 / 草稿 / 概述 / "我觉得没问题"——违反 = L2 独立性失效 = 等同没做。

调用模板（仅替换 `<change-id>`，其余原样）：

    Agent tool:
      subagent_type: qa-expert
      description: "L2 blind review phase 5"
      prompt: |
        <原样粘贴 @flow-kit/prompts/independent/L2-blind-review.md 的完整内容>

        ## 本次审查参数
        - 阶段：5
        - change-id：<change-id>
        - 工件：读 .specs/<change-id>/TEST.md（参考 .specs/<change-id>/REQUIREMENT.md、.specs/<change-id>/TASK.md）
        - 输出：写入 .specs/<change-id>/INDEPENDENT-REVIEW-5.md 的「## L2 盲审」段（若文件已存在含 L3 段，先读全文，将 L2 段追加到末尾再 Write——禁止直接覆写；若文件不存在则新建，首行加 `# 独立审查 · 阶段 5`）

### L3 · 外部模型审查（Stop hook 自动跑 · 你不用调度）

你本轮结束后，Stop hook 的 `29-independent-review.sh` 自动用外部模型盲审 TEST.md + bats 结果，写 `INDEPENDENT-REVIEW-5.md` 的 L3 段 + `.flow-active.independent-review` 握手。下一轮 SessionStart 会注入报告摘要。

### 错误处理

- 若 L2 子 agent 调用失败（超时 / API error / 返回空内容）→ 输出 `❌ L2 审查失败：<原因>，pipeline 暂停，等待人工介入`，**不写 .done**
- 若 L2 返回 verdict=fail → 输出 `⛔ L2 审查 verdict: fail，pipeline 暂停`，**不写 .done**
- 若 L2 返回 verdict=pass → 输出 `✅ L2 审查通过`，继续

### 写 done（活跃 tier 都完成后）

确认 `INDEPENDENT-REVIEW-5.md` 含所需 tier 段后执行：

    - gate_config="both" 或 "L3"：`.done` 由 l3-review.sh / Stop hook 29 写入（无需主 agent 操作）
    - gate_config="L2"（仅 L2）：主 agent 写 6 键 KVP `.done`：
      ```bash
      cat > .specs/<change-id>/.independent-review-5.done <<'DONE_EOF'
      phase=5
      change_id=<change-id>
      written_by=main-agent
      L2_verdict=<pass|fail，从 INDEPENDENT-REVIEW-5.md 提取>
      L3_verdict=skipped
      artifacts=TEST.md,TASK.md,REQUIREMENT.md,INDEPENDENT-REVIEW-5.md
      DONE_EOF
      ```

写完才能切阶段

### 修代码优先协议（l2-l3-fix-compliance）

> 处理 L2/L3 审查发现时，必须遵守以下规则。纯文档敷衍 = 过不了实效性 gate。

1. **读取 INDEPENDENT-REVIEW-5.md**，逐条审视所有 🔴/🟡 发现
2. 对每条发现输出分类标记（DESIGN §3.2 统一格式）：
   - `Fixed in: <filepath>` — 已在代码中修复，标注修改的文件路径
   - `Tech-debt: <reason>` — 无法本次修复，登记为技术债（含严重度评估 + 计划修复版本）
   - `Not-applicable: <reason>` — 不适用（如纯文档发现或误判）
3. **禁止**：仅写「已知限制」「未覆盖」「暂不处理」「已记录」等无代码变更的敷衍回应
4. **AC-4 技术债滥用防护**：若 ≥50% 的源码级发现被标记为 `Tech-debt:`，需在响应末尾输出一段显式说明——为何半数以上问题不能本次修复
5. 写回 INDEPENDENT-REVIEW-5.md 的 agent 响应段（追加，非覆写）

PCSC 追加项：所有 review 发现已处理（`Fixed in:` / `Tech-debt:` / `Not-applicable:` 分类完成）

---

### 阶段完成自检（Phase Completion Self-Check）

> ⚠️ **强制**：在进入 Toll-gate 之前，必须逐项完成以下自检。
> 任一 ❌ → **禁止进入 toll-gate**。先完成缺失项，然后重新自检。

| # | 产物/检查项 | 验证方式 | 状态 |
|---|---|---|---|
| 1 | `TEST.md` 已写入 `.specs/<change-id>/`（含测试结果） | `test -f .specs/<change-id>/TEST.md` | ✅ / ❌ |
| 2 | 本次测试范围声明（步骤 0）已明确 | 人工确认 | ✅ / ❌ |
| 3 | 声明的测试轮次均已执行 | 人工确认（对照步骤 0 声明） | ✅ / ❌ |
| 4 | 测试质量自检（1.4 段 · 6 维测试衰退风险）已完成 | 人工确认 | ✅ / ❌ |
| 5 | 覆盖率指标已记录（如适用） | `grep -c 'Coverage' TEST.md` | ✅ / ❌ |
| 6 | 回归测试登记（步骤 N）已完成 | 人工确认 | ✅ / ❌ |
| 7 | .flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘 | test -s .flow-active && jq -e '.updated_at' .flow-active >/dev/null | ✅ / ❌ |

### auto_advance 分支

- 若 `auto_advance=true`：
  - 全 ✅ → 执行 transition jq（`current_phase=6, phases_done+=["5"]`），输出"✅ 自检通过，自动进入 6-review"，加载 `@flow-kit/prompts/6-review.md`
  - 有 ❌ → **暂停 pipeline**，输出缺失清单，等待用户决定（回退/跳过/手动补齐）
- 若 `auto_advance=false`：
  - 全 ✅ → 进入 toll-gate
  - 有 ❌ → **禁止进入 toll-gate**，补齐缺失项后重新自检

### Toll-gate 5→6（测试完成后）

**测试所有轮次完成，TEST.md 已生成后。**

检查 `auto_advance`：
- 若 `true` → 已在「阶段完成自检」段处理（全 ✅ 自动 transition，有 ❌ 暂停）。**不再进入本 toll-gate 交互**。
- 若 `false` → **停下来。必须等待用户回复。禁止自动继续。**

输出 TOLL-GATE：
```
🚦 Toll-gate 5→6：测试已完成。
✅ TEST.md 已生成，覆盖率报告已出
是否进入审查阶段（6-review）？
  1. 继续 → 进入 6-review（current_phase=6, phases_done+=["5"]）
  2. 暂停 → 保留状态，稍后 `/flow-go 继续` 恢复
  3. ⬅️ 回退 → 回到 <建议目标>（默认 4-dev；--from 0 时可回退到 0/1/2/3/4）
```

用户选 1 → transition：
```bash
jq --arg ts "$(date -Iseconds)" \
  '.goal.current_phase = "6" | .phase = "6" | .goal.phases_done += ["5"] | .goal.gates["5→6"] = "passed" | .updated_at = $ts' \
  .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
```
然后加载 `@flow-kit/prompts/6-review.md`。

用户选 3 → **Phase 回退（通用化，见下方「Pipeline: 测试执行失败回退」步骤 4 的 jq 模板）**：
默认 $TARGET="4"（向后兼容）；`--from 0` 时 AI 按 toll-gate 发现的问题类型建议目标（参考失败分类表），用户确认后执行通用回退 jq。

### Pipeline: 测试执行失败回退

**当测试执行过程中发现失败（非 toll-gate，而是测试报错/断言失败）：**

若当前处于 pipeline goal 模式（`scope="pipeline"`），在进入常规失败诊断前，**先展示 pipeline rollback 选项**：

#### 步骤 1 · 读取 pipeline 状态

```bash
jq -r '.goal | "\(.start_phase // "4")|\(.current_phase // .start_phase // "4")|\((.phases_done // []) | join(","))"' .flow-active
```

#### 步骤 2 · 生成可回退目标列表

`rollback_targets = [start_phase .. current_phase-1]`（仅可回退到已走过的阶段）。
- `--from 4`, current=5 → 可回退目标 = [4]
- `--from 0`, current=5 → 可回退目标 = [0,1,2,3,4]

#### 步骤 3 · 失败分类表（AI 按现象建议回退目标）

| 失败现象 | 建议回退目标 |
|---|---|
| 测试断言失败 / 代码 bug | 4-dev（最常见）|
| AC 未覆盖或无法满足（需求层问题）| 1-requirement（仅当 start_phase ≤ 1）|
| 测试用例设计缺陷（漏边界，task 拆解问题）| 3-task（仅当 start_phase ≤ 3）|
| 其他 / 不确定 | 4-dev（默认兜底）|

> 建议目标必须在 rollback_targets 内（start_phase 之后）。若建议目标 < start_phase（如 start_phase=4 时建议回 1），则不可选，降级为回退到 start_phase。

#### 步骤 4 · 展示 + 用户确认

```
⚠️ 5-test 发现测试失败（<N> 个失败）
   失败现象：<AI 根据测试输出判断，如「断言失败」「AC 无法满足」>
   💡 建议回退到：<建议阶段名>（<理由>）
   可回退目标：<rollback_targets>

Pipeline 模式 — 请选择：
  1. 就地修复 → 留在 5-test，修复后重跑
  2. ⬅️ 回退（默认建议：<建议目标>）→ current_phase=<目标>, phases_done 移除该目标之后的阶段
  3. 跳过失败测试 → 继续 6-review（不推荐，记录已知问题）
```

用户选 2（确认建议或手动指定其他可回退目标）→ **Phase 回退（通用化 jq，$TARGET 为选定目标）**：

```bash
# 计算需移除的阶段：TARGET 之后到当前的所有已完成阶段
TARGET=<用户确认的目标，如 "4" 或 "2" 或 "1">
PHASES_DONE=$(jq -c '.goal.phases_done // []' .flow-active)
REMOVE=$(jq -n --arg target "$TARGET" --argjson done "$PHASES_DONE" \
  '[$done[] | select((. | tonumber) > ($target | tonumber))]')
jq --arg target "$TARGET" --argjson remove "$REMOVE" --arg ts "$(date -Iseconds)" \
  '.goal.current_phase = $target | .goal.phases_done -= $remove | .updated_at = $ts' \
  .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
```
然后加载 `@flow-kit/prompts/<对应阶段>.md`（4-dev / 3-task / 2-design / 1-requirement / 0-change 之一）。

> **向后兼容**：`--from 4`（默认）时，可回退目标仅 [4]，建议即回 4，行为与改造前一致。

### Sub-goal 自检（AC-12）

测试完成后，若 `phase_sub_goals["5"]` 存在 → 逐项对照，✅/⚠️ 标注。

## 你的职责

### 步骤 0 · 声明本次走哪几轮（强制）

在 `TEST.md` 开头**显式输出适用矩阵**，对照 `test-pyramid.md` 末尾的「适用矩阵」表，按项目类型决定每轮是「✅ 必跑 / ⚠️ 部分 / ❌ 跳过」。

格式：

```
## 本次测试范围声明

| 轮次 | 状态 | 范围 | 跳过理由（如跳过）|
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 AC | — |
| 第 2 轮 · 性能 | ✅ 必跑 | Lighthouse + bundle size | — |
| 第 3 轮 · 安全 | ⚠️ 部分 | 依赖 + 秘钥扫描 | 内部工具，OWASP 减项 |
| 第 4 轮 · 兼容 | ✅ 必跑 | Chrome/Firefox/Safari | 不需要 IE |
| 第 5 轮 · 可观测 | ❌ 跳过 | — | CLI 工具，无运行时 |
```

**禁止**没声明就跳过任何轮次。每个 ❌ 必须有理由。

---

### 第 1 轮 · 功能测试（Functional）

#### 1.1 测试矩阵

每条 AC 映射到测试用例：

| AC | 类型（unit/integration/e2e/manual）| 用例文件 / UAT 编号 | 状态 |
|---|---|---|---|
| AC-1 | unit | `theme.test.ts` | ✅ |
| AC-2 | e2e | `theme.e2e.ts` | 🟡 待补 |
| AC-3 | manual | UAT-1 | — |

**强制**：每条 AC ≥ 1 条覆盖。空缺必须解释。

#### 1.2 UAT 脚本（无法自动化的 AC）

```
UAT-1：<场景>
  前置：<状态>
  步骤：1. ... 2. ... 3. ...
  期望：- ... - ...
  通过/失败：
```

#### 1.3 覆盖率与边界

- 跑 `<test-cmd> --coverage`，贴输出
- 关键路径行覆盖 ≥ 项目门槛（默认 80%；core 模块 ≥ 90%）
- 边界值用例（空 / 极大 / 极小 / Unicode / null）≥ 3 条
- 错误路径必须有显式测试

> 工具与反模式详见 `test-pyramid.md` 第 1 节。

#### 1.4 测试质量自检 · 6 维测试衰退风险

> 覆盖率达标 ≠ 测试写得好。本步检查「测试本身」的衰退风险。

以 [brooks-lint](https://github.com/hyhmrright/brooks-lint) 提出的 6 个测试衰退风险为诊断维度（源于《xUnit Test Patterns》/《The Art of Unit Testing》/《How Google Tests Software》/《Working Effectively with Legacy Code》四本书）：

| 编号 | 衰退风险 | 诊断问题 |
|---|---|---|
| T1 | Test Obscurity 测试晦涩 | 读这个测试能马上看出「它在验证什么」吗？ |
| T2 | Test Brittleness 测试脆弱 | 重构实现会让这个测试坏掉吗（但行为仍正确）？ |
| T3 | Test Duplication 测试重复 | 同一个场景是否被多个测试换个姿势验证？ |
| T4 | Mock Abuse Mock 滥用 | mock 是否遮蔓了真实问题 / 是否 mock 了不属于被测单元的东西？ |
| T5 | Coverage Illusion 覆盖率幻觉 | 覆盖率高但 assertion 空 / 只验证不报错？ |
| T6 | Architecture Mismatch 架构错配 | 测试层级是否与架构匹配（不该用 e2e 验证的点被拿 e2e 验）？ |

##### 路径 A · 装了 brooks-lint（首选）

```
/brooks-test            # 测试套件质量审查
```

输出使用 4 要素格式（Symptom / Source / Consequence / Remedy），原样贴入 `TEST.md` 的「测试质量自检」段。

##### 路径 B · 未装 brooks-lint（内置清单）

逐个维度检查，命中任一项记下测试文件列表：

- [ ] **T1**：测试名不是 Given/When/Then 结构，读不出场景 → 重命名
- [ ] **T2**：测试断言实现细节（调用了哪个内部函数、某变量是某值）而非外部行为 → 改验证输入输出
- [ ] **T3**：多个测试只不过改了输入数值，其他一样 → 改参数化（table-driven / parametrize）
- [ ] **T4**：mock 了被测单元本身 / mock 了本可走真的依赖 → 去 mock
- [ ] **T5**：测试只调用了函数但没断言 · 仅有 `expect(x).toBeDefined()` 这种空断言 → 补真实断言
- [ ] **T6**：能用单测验证的逻辑被拿 e2e 验证 / 应用层逻辑被拿集成测验证 → 下移一层

命中 ≥ 1 项 → 本轮技术债记事（记入 TEST.md 的「测试质量记事」段，按优先级排入 backlog 或当圈修复）。命中 ≥ 3 项 → 本次 release 前必修。

> 工具与反模式详见 `test-pyramid.md` 第 1 节、6 维衰退详见 [brooks-lint · brooks-test skill](https://github.com/hyhmrright/brooks-lint)。

---

### 第 2 轮 · 性能测试（Performance）

#### 2.1 性能预算确认

从 `REQUIREMENT.md` 的「非功能性需求」提取性能预算。**没有就停下来**，让用户先补。

#### 2.2 前端性能（Web 项目）

- Lighthouse CI 跑关键路由：LCP / CLS / INP / TBT
- Bundle Analyzer：主包 + 路由分包大小
- 与上一版基线对比，**禁止退步**

#### 2.3 后端 / API 性能

- k6 / locust 在 N 倍业务 QPS 下的关键 API：p95 / p99 / 错误率
- 数据库慢查询审计（`EXPLAIN ANALYZE` 关键查询）
- 检测 N+1（ORM 项目必查）

#### 2.4 通过标准

逐项对照预算，输出"✅ 达标 / ❌ 退步 X% / ⚠️ 接近阈值"，**不允许"性能良好"这种空话**。

> 工具、默认阈值、反模式详见 `test-pyramid.md` 第 2 节。

---

### 第 3 轮 · 安全测试（Security）

#### 3.1 依赖漏洞扫描

```bash
npm audit --production       # 或 pip-audit / govulncheck / cargo audit
trivy image <image>          # 容器镜像扫描
```

通过：无 high / critical。命中必须修或显式接受（含理由）。

#### 3.2 秘钥扫描

```bash
trufflehog filesystem .      # 或 gitleaks detect
```

通过：0 命中。命中必须**立即 rotate** 对应密钥（不只是删 commit）。

#### 3.3 静态扫描（SAST）

Semgrep / CodeQL / Bandit 选一。无 high；medium 有处理记录。

#### 3.4 OWASP Top 10 清单

逐项标 ✅ 已测 / ❌ 不适用 / 🟡 待补：

- A01 越权 / A02 加密失败 / A03 注入 / A04 不安全设计
- A05 配置错误 / A06 漏洞组件 / A07 鉴权 / A08 数据完整性
- A09 日志监控（→ 第 5 轮）/ A10 SSRF

> 工具与反模式详见 `test-pyramid.md` 第 3 节。

---

### 第 4 轮 · 兼容性测试（Compatibility）

#### 4.1 前端跨浏览器 / 跨设备（Web 项目）

- 桌面：Chrome / Firefox / Safari / Edge（最新 2 个版本）
- 移动：iOS Safari / Android Chrome
- 视口：360 / 768 / 1024 / 1440 至少跑过

工具：Playwright 多 browser；可选 BrowserStack / LambdaTest。

#### 4.2 数据迁移测试（涉及 schema 变更必跑 · 关联 4-dev 1.7 / R4.5）

**前置**：本任务在 4-dev 步骤 1.7 已生成迁移文件（如未生成，回退到 dev 阶段——R4.5 违规）。在 SUMMARY.md「数据库迁移」段 trace 文件路径，本步对这些文件做端到端验证。

- [ ] 迁移文件路径已 trace（来自 `<task-id>-SUMMARY.md`「数据库迁移」段）
- [ ] 在**生产数据快照**上预演迁移脚本（不能只在 dev 数据上跑）
- [ ] 实测耗时 → 决定是否需要 maintenance window（> 30s 的 ALTER TABLE 必走窗口）
- [ ] **回滚脚本（down）就位且测过**：跑 up → 跑 down → 数据 / schema 复原 → 再跑 up
- [ ] 双写期 / 灰度方案有验证步骤（破坏性变更必填）
- [ ] 加 NOT NULL 字段：旧行 backfill 已验证（不能依赖 DEFAULT 在迁移期就位）
- [ ] 改字段类型：cast 不丢数据 / 不截断 / 不溢出已验证

#### 4.3 跨版本 / 跨编码

- [ ] 旧 schema 数据能否被新代码正确读写
- [ ] API 版本兼容（v1 客户端访问 v2 服务端）
- [ ] UTF-8 / UTF-16 / 不同 locale

> 工具与反模式详见 `test-pyramid.md` 第 4 节。

---

### 第 5 轮 · 可观测性验证（Observability）

> 不是"测系统"，是"测系统能不能被观测"。上线后看不到 = 故障无法定位。

#### 5.1 日志验证

- [ ] 关键路径入口 / 出口 / 异常都有 log
- [ ] 含 trace-id，结构化（JSON）
- [ ] **不含 PII / 秘钥 / token**（grep 验证）
- [ ] 错误日志含足够上下文

#### 5.2 指标 / 追踪

- [ ] 业务关键 metric 有打点（转化率 / 错误率 / 关键时长）
- [ ] RED 指标覆盖关键 endpoint
- [ ] 跨服务 trace 串通（如有分布式调用）

#### 5.3 告警 + 健康检查

- [ ] 关键失败有告警 + runbook 链接
- [ ] `/health` 区分 liveness / readiness
- [ ] 无噪音告警

> 工具与反模式详见 `test-pyramid.md` 第 5 节。

---

### 步骤 N · 回归测试登记

本次新加 / 修复的测试用例，统一登记到 `TEST.md` 末尾，方便未来 grep 找到。

## 输出

- `.specs/<change-id>/TEST.md`（用 `@flow-kit/templates/TEST.md` 模板，含 5 轮报告段）
- 性能 / 安全扫描的原始输出贴入或链接到附件

## 约束（强制）

- **R5.1**：测试用例从 AC 派生，不从实现派生
- **R5.2**：bug 修复必伴随回归测试，加入 LESSONS
- **R5.3**：禁止通过删除 / 弱化测试来"修复"失败
- **R5.4**（新）：不允许跳过任何轮次而没有显式理由（在范围声明里写明）
- **R5.5**（新）：性能 / 安全 / 兼容轮次的"通过 / 失败"必须基于**可量化指标**或工具输出，不允许"看起来没问题"
- AC 覆盖优先于行覆盖

## 自检

- [ ] 范围声明已输出，5 轮状态都明确
- [ ] 第 1 轮：每条 AC 有覆盖 + 覆盖率达标 + 边界用例 ≥ 3 + **测试质量 6 维自检过**
- [ ] 第 2 轮：性能预算逐项对比 + 与上版基线对比
- [ ] 第 3 轮：依赖 / 秘钥 / SAST / OWASP 各有处理记录
- [ ] 第 4 轮：跨浏览器 / 数据迁移 / 跨版本按需跑过
- [ ] 第 5 轮：日志 / 指标 / 告警 / 健康检查清单逐项验证
- [ ] 跳过的轮次都有理由
- [ ] 测试新增的用例已登记

## 触发下一步

- 任何轮次发现 🔴 问题 → 回到 `@flow-kit/prompts/4-dev.md` 修复（产 fix 任务）
- 全部通过 → `@flow-kit/prompts/6-review.md`（review 阶段会再检查 5 轮都做了）
