# 阶段 7 · INTEGRATION — 集成验证 + UAT + 失败诊断 + 归档

## 角色

你是 Verifier + Release。

## 输入

- `@.specs/<change-id>/REQUIREMENT.md`
- `@.specs/<change-id>/TEST.md`（含 UAT 脚本）
- `@.specs/<change-id>/REVIEW.md`
- 当前已合并/待合并的代码

## Pipeline Goal 入场检测 + 完成

进入 7-integration 后，检测 `.flow-active` 的 `goal` 字段。
解析逻辑见 `@flow-kit/reference/pipeline-goal-parser.md`。

若 `scope` = `"pipeline"` 且 `current_phase` = `"7"`：
- 展示 pipeline 横幅：4✅ → 5✅ → 6✅ → 7🔄
- 标注 "最终阶段：7-integration"

### 顶层 Goal 条件自检

7-integration 完成后，归档前，自检 `goal.condition` 是否满足：

```
顶层 Goal 条件：<goal.condition>
逐项对照：
  ✅ <条件> — 已验证（来源：<证据>）
```

全部满足 → 进入 pipeline 完成流程。

---

## 独立 review 调度（仅当本阶段 gate 开启时执行）

> ⚠️ L2 盲审必须在本阶段产物完成后、toll-gate 前完成。跳过 L2 = gate deny transition。

> **检测**：`.flow-active.goal.gate_config["7-integration"]` ∈ {`L2`,`both`}（`independent`/`true` 向后兼容映射为 `both`），或 `.claude/stop-hook.json` 的 `independent_review.phases` 含 `"7-integration"`。未开启 → 跳过本段，直接进「阶段完成自检」。

本阶段产物必须通过两层独立 review 才能 commit / 开 PR。开启时这两项操作被 PreToolUse hook 硬拦，直到你写 done 标志。

### L2 · 独立子 agent 盲审（你负责调度）

派一个**固化盲审子 agent**。**强制独立性**：prompt 字段 = 原样注入 `@flow-kit/prompts/independent/L2-blind-review.md` 全文 + 末尾的本次审查参数；**禁止**附加你的自评 / 草稿 / 概述 / "我觉得没问题"——违反 = L2 独立性失效 = 等同没做。

调用模板（仅替换 `<change-id>`，其余原样）：

    Agent tool:
      subagent_type: architect-reviewer
      description: "L2 blind review phase 7"
      prompt: |
        <原样粘贴 @flow-kit/prompts/independent/L2-blind-review.md 的完整内容>

        ## 本次审查参数
        - 阶段：7
        - change-id：<change-id>
        - 工件：读 .specs/<change-id>/ 下全部产物（参考 .specs/<change-id>/REVIEW.md、.specs/LESSONS.md、.specs/CHANGELOG.md）
        - 输出：写入 .specs/<change-id>/INDEPENDENT-REVIEW-7.md 的「## L2 盲审」段（若文件已存在含 L3 段，先读全文，将 L2 段追加到末尾再 Write——禁止直接覆写；若文件不存在则新建，首行加 `# 独立审查 · 阶段 7`）

### L3 · 外部模型审查（Stop hook 自动跑 · 你不用调度）

你本轮结束后，Stop hook 的 `29-independent-review.sh` 自动用外部模型盲审全部产物 + LESSONS.md，写 `INDEPENDENT-REVIEW-7.md` 的 L3 段 + `.flow-active.independent-review` 握手。下一轮 SessionStart 会注入报告摘要。

### 错误处理

- 若 L2 子 agent 调用失败（超时 / API error / 返回空内容）→ 输出 `❌ L2 审查失败：<原因>，pipeline 暂停，等待人工介入`，**不写 .done**
- 若 L2 返回 verdict=fail → 输出 `⛔ L2 审查 verdict: fail，pipeline 暂停`，**不写 .done**
- 若 L2 返回 verdict=pass → 输出 `✅ L2 审查通过`，继续

### 写 done（活跃 tier 都完成后）

确认 `INDEPENDENT-REVIEW-7.md` 含所需 tier 段后执行：

    - gate_config="both" 或 "L3"：`.done` 由 l3-review.sh / Stop hook 29 写入（无需主 agent 操作）
    - gate_config="L2"（仅 L2）：主 agent 写 6 键 KVP `.done`：
      ```bash
      cat > .specs/<change-id>/.independent-review-7.done <<'DONE_EOF'
      phase=7
      change_id=<change-id>
      written_by=main-agent
      L2_verdict=<pass|fail，从 INDEPENDENT-REVIEW-7.md 提取>
      L3_verdict=skipped
      artifacts=REVIEW.md,TEST.md,TASK.md,DESIGN.md,REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-7.md
      DONE_EOF
      ```

写完才能 commit / 开 PR。L3 连续失败 ≥3 次（Stop 报告会提示「允许手动绕过」）时，可凭提示手动 touch 继续，不强制卡死。

### 修代码优先协议（l2-l3-fix-compliance）

> 处理 L2/L3 审查发现时，必须遵守以下规则。7-integration 特殊点：归档前最后一道审查，L2/L3 发现的问题**必须在归档前修复**，不可推迟到"下一轮 change"。

1. **读取 INDEPENDENT-REVIEW-7.md**，逐条审视所有 🔴/🟡 发现
2. 对每条发现输出分类标记（DESIGN §3.2 统一格式）：
   - `Fixed in: <filepath>` — 代码已修复，标注修改的文件路径
   - `Tech-debt: <reason>` — 登记为技术债（仅限严重度🟢 Minor 或已有独立 change 跟踪的🟡项）
   - `Not-applicable: <reason>` — 不适用（如纯文档发现或误判）
3. **禁止**：将 🔴 Critical 或 🟡 Major 发现推迟到"下一轮 change"。归档前必须修复或在 LESSONS.md 中显式记录 + 开新的 change 跟踪
4. **AC-4 技术债滥用防护**：若 ≥50% 的源码级发现被标记为 `Tech-debt:`，需在响应末尾输出显式说明
5. 写回 INDEPENDENT-REVIEW-7.md 的 agent 响应段（追加，非覆写）

PCSC 追加项：所有 review 发现已处理（`Fixed in:` / `Tech-debt:` / `Not-applicable:` 分类完成），且无推迟到下一轮 change 的 🔴/🟡 项

---

### 阶段完成自检（Phase Completion Self-Check）

> ⚠️ **强制**：在 Pipeline 完成之前，必须逐项完成以下自检。
> 任一 ❌ → **禁止执行 pipeline 完成**。先完成缺失项，然后重新自检。

| # | 产物/检查项 | 验证方式 | 状态 |
|---|---|---|---|
| 1 | 全量自动化测试通过（步骤 1 全套） | `npx bats test/`（或等价命令）退出码 0 | ✅ / ❌ |
| 2 | UAT 引导已完成（步骤 2） | 人工确认 | ✅ / ❌ |
| 3 | 失败诊断已完成（步骤 3，如有失败） | 人工确认 | ✅ / ❌ |
| 4 | LESSONS.md 提名已完成（步骤 4） | 人工确认 | ✅ / ❌ |
| 5 | 顶层 Goal 条件自检通过 | 逐项对照 `goal.condition` | ✅ / ❌ |
| 6 | 全部上游阶段产物均存在（CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW） | `test -f .specs/<change-id>/*.md` | ✅ / ❌ |
| 7 | TASK.md 中所有 T-FIX-XX 任务状态 = done（无 pending T-FIX，归档前必须全部关闭） | `grep -c 'T-FIX.*status="pending"' .specs/<change-id>/TASK.md` 输出 0 | ✅ / ❌ |
| 8 | 归档已完成：`.specs/<id>/` → `archive/` + `STATE.md` last_change_archived 已更新 + `CHANGELOG.md` 已追加 | 人工确认 | ✅ / ❌ |
| 8a | **CHANGELOG LESSONS 列已同步**：若步骤 4 产出了新 L-NNN → CHANGELOG 该行列明 `L-NNN`；若步骤 4 无提名 → CHANGELOG 该行写 `—`。禁止步骤 4 有提名但 CHANGELOG 写 `—` | `grep -c "L-NNN" .specs/CHANGELOG.md` 与 `grep -c "L-NNN" .specs/LESSONS.md` 一致 | ✅ / ❌ |
| 9 | Sub-goal 汇总已完成（AC-12，若 `phase_sub_goals` 非空） | 人工确认 | ✅ / ❌ |
| 10 | PR 已提交（如适用） | 人工确认 | ✅ / N/A |
| 11 | .flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘 | test -s .flow-active && jq -e '.updated_at' .flow-active >/dev/null | ✅ / ❌ |

### auto_advance 分支

- 若 `auto_advance=true`：全 ✅ → 执行 pipeline 完成流程（`goal.status="done", phases_done+=["7"]`）；有 ❌ → 输出缺失清单，等待用户决定
- 若 `auto_advance=false`：全 ✅ → 进入 pipeline 完成；有 ❌ → **禁止执行 pipeline 完成**，补齐缺失项后重新自检

### Pipeline 完成（AC-8）

```
🎯 Pipeline Goal 完成：<goal.condition>
   经过阶段：4 → 5 → 6 → 7
   总 turns：<N>
   设定于：<active_since>
```

```bash
jq --arg ts "$(date -Iseconds)" \
  '.goal.status = "done" | .goal.phases_done += ["7"] | .updated_at = $ts' \
  .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
```

### Sub-goal 汇总（AC-12）

若 `phase_sub_goals` 非空 → 汇总展示各阶段 sub-goal 达成：
```
4-dev: ✅ <sub-goal 4>
5-test: ✅ <sub-goal 5>
6-review: ✅ <sub-goal 6>
7-integration: ✅ <sub-goal 7>
```

完成后建议用户运行 `/flow goal clear` 清除 pipeline 状态。

## 你的职责

### 1. 跑全套自动化

- 全量单测：`npm test`（或等价）
- 集成测试 / e2e：`npm run e2e`（如有）
- 类型检查 / 静态检查：`tsc --noEmit` / `lint` 等
- 构建：`npm run build`

**贴出每条命令的真实输出**到产出中。任何失败立即进入「失败诊断」。

### 2. 引导人工 UAT

逐条读 TEST.md 的 UAT 脚本，向用户提问形如：

> UAT-1：深色模式手动切换。请按以下步骤操作：……
> 通过 / 失败 / 描述问题：

记录每条 UAT 的结果到 `.specs/<change-id>/UAT.md`。

### 3. 失败诊断（自动 + 人工）

任何失败（自动测试或 UAT）：

**若当前处于 pipeline goal 模式**（`scope="pipeline"`），先展示 pipeline rollback 选项：

#### 失败分类表（AI 按问题类型建议回退目标）

| 失败现象 | 建议回退目标 |
|---|---|
| 集成测试失败 / 代码 bug | 4-dev（最常见）|
| UAT 揭示 AC 错误（需求层问题）| 1-requirement |
| 集成时发现架构缺陷（撞 ADR）| 2-design |
| 部署 / 环境配置问题 | 4-dev（重新执行）|
| 其他 / 不确定 | 4-dev（默认兜底）|

> 建议目标必须在 `[start_phase .. current_phase-1]` 内（仅可回退到已走过的阶段）。
> `--from 4`（默认）时，可回退目标仅 [4]，建议即回 4（向后兼容）。
> `--from 0` 时，可回退到 0/1/2/3/4，AI 按失败类型建议。

```
⛔ 7-integration 失败：<失败描述>

   失败现象：<AI 判断，如「UAT 揭示 AC 错误」「集成失败」>
   💡 建议回退到：<建议阶段名>（<理由>）
   可回退目标：<rollback_targets = [start_phase .. 6]>

Pipeline 模式 — 请选择：
  1. 修复后继续 → 留在 7-integration，诊断 + fix-plan + 修复 + 重跑
  2. ⬅️ 回退（默认建议：<建议目标>）→ current_phase=<目标>, phases_done 移除该目标之后的阶段
  3. 放弃本次 pipeline → goal.status = "aborted"
```

用户选 2（确认建议或手动指定其他可回退目标）→ **Phase 回退（通用化 jq，$TARGET 为选定目标）**：

```bash
# goal 字段结构及常用 jq 查询见 @flow-kit/reference/goal-parsing.md
TARGET=<用户确认的目标，如 "4" 或 "2" 或 "1">
PHASES_DONE=$(jq -c '.goal.phases_done // []' .flow-active)
REMOVE=$(jq -n --arg target "$TARGET" --argjson done "$PHASES_DONE" \
  '[$done[] | select((. | tonumber) > ($target | tonumber))]')
jq --arg target "$TARGET" --argjson remove "$REMOVE" --arg ts "$(date -Iseconds)" \
  '.goal.current_phase = $target | .goal.phases_done -= $remove | .updated_at = $ts' \
  .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
```
然后加载 `@flow-kit/prompts/<对应阶段>.md>`（4-dev / 3-task / 2-design / 1-requirement 之一）。

> **向后兼容**：`--from 4` 时，$TARGET 默认 "4"，REMOVE=[5,6,7]，行为与改造前的 `current_phase="4" | phases_done-=["5","6","7"]` 完全一致。

**非 pipeline 模式**（或无 goal）按以下流程：

1. 切到「Diagnose 子角色」，定位 root cause（不是症状）
2. 产出 fix-plan：追加到 `TASK.md`，编号 `T-FIX-XX`，含完整 verify
3. 回到 `@flow-kit/prompts/4-dev.md` 执行修复
4. 修完回到本步重跑

**R2.6**：自动重试 ≤ 3 轮。第 3 轮仍失败必须停下来要求人工决策。

### 4. 提名 LESSONS（在 ARCHIVE 之前必跑，对应 R1.8）

扫本次 change 的所有 `*-SUMMARY.md`「决策与偏离」段，以及任何遗留的 `*-PROGRESS.md`「已排除方案」段。
按 `@flow-kit/templates/LESSONS.md` 末尾的「提名条件」筛选：

- 调试 / 试错耗时 > 30 分钟 → 提名
- 错因不局限于本任务、其它任务也会撞 → 提名
- 6 个月内有合理概率被再次尝试 → 提名
- 否则不入库（避免污染）

把入选的失败按 LESSONS.md 的条目格式追加到 `.specs/LESSONS.md`，编号续上 `L-NNN`，必须填齐：标签 / 关键词 / 适用栈 / 状态。
**复核**：扫一眼现有 active 条目，看是否有本次 change 让它们 `superseded` 或 `deprecated`，标注上。

**⚠️ 强制同步**：向 `LESSONS.md` 追加新条目后，**立即**更新 `.specs/CHANGELOG.md` 中本 change 行的 LESSONS 列——把新编号（如 `L-013`）填入。不要等到步骤 5 归档时才做——那时容易遗漏。若本轮无提名，LESSONS 列写 `—`。

### 5. 归档（ARCHIVE）

全部通过后：

- 把 `.specs/<change-id>/` 移动到 `.specs/archive/<YYYY-MM-DD>-<change-id>/`
- 在 `.specs/CHANGELOG.md` 里追加一行（日期 / change-id / 一句话摘要 / LESSONS 条目编号）。**LESSONS 列强制**：回读步骤 4 的产出——若步骤 4 向 `LESSONS.md` 追加了 `L-NNN`，则此列填入 `L-NNN`；若步骤 4 判定无提名，则填 `—`。**禁止步骤 4 有产出但此处写 `—`**
- 更新仓库根的 `STATE.md`
- **不要归档 `.specs/LESSONS.md`**——它是项目级常驻文件，跨 change 累积

#### 5.0 归档后清理与扫描（L-013 双向校验 · 强制）

> ⚠️ **L2 自检 gate**：以下两步必须在归档 mv 完成后立即执行。跳过任一步 → PCSC 自检 ❌，禁止 toll-gate。

##### 5.0.1 清理工作目录

归档 mv 完成后，确认 PROGRESS.md 已存在于 archive 目标目录，然后删除原工作目录：

```bash
# 确认 PROGRESS.md 已入 archive
test -f ".specs/archive/$(date +%Y-%m-%d)-<change-id>/PROGRESS.md" && \
  rm -rf ".specs/<change-id>/"
```

**双重确认规则**（防误删，对应 R4 风险缓解）：
1. `test -f` 确认 PROGRESS.md 存在于 archive 目标目录
2. archive 目录名必须匹配当前 change-id
3. 在执行 rm 前**列出待删目录内容**给用户确认（`ls -la .specs/<change-id>/`）

##### 5.0.2 扫描未归档的已完成 change

遍历 `.specs/` 下所有非 `archive` 子目录，检出满足以下全部条件的 change：
- 目录下存在 REVIEW✅ 或 REVIEW PASS 标记（`grep -l 'REVIEW.*✅\|REVIEW.*PASS' .specs/<dir>/*.md`）
- TASK.md 中所有 task 状态为 done（`grep -c 'status.*done'` 等于总 task 数）
- 该 change 不在 `archive/` 中（`test ! -d .specs/archive/*<dir>`）

命中则输出警告：

```
⚠️ 归档扫描：以下 change 已完成但未归档，建议跑 /flow-go 上线：
   - <dir1>（REVIEW✅ / TASK 全 done / 未在 archive 中）
   - <dir2> ...
```

未命中则输出 `✅ 归档扫描：无遗漏 change。`

##### 5.0.3 L2 自检 gate 填空

```
归档后清理与扫描自检：
  [ ] 5.0.1 PROGRESS.md 已确认在 archive 中：test -f .specs/archive/<date>-<id>/PROGRESS.md
  [ ] 5.0.1 工作目录已删除：test ! -d .specs/<id>/
  [ ] 5.0.2 孤儿扫描已跑：已遍历 .specs/ 下所有非 archive 目录
  [ ] 5.0.2 扫描结果：✅ 无遗漏 / ⚠️ 有 N 个未归档 change（已贴出清单）
```

#### 5.1 项目级架构文档同步（不在本步做 · 走 A-evolve）

本 change 的 `DESIGN.md § 9 架构沉淀建议` **不在归档时立即合并到 `CONTEXT.md`**。原因：单个 change 视角窄，容易把临时决策错升项目级。

正确做法：

- 归档时只把 `DESIGN.md` 原样移入 `archive/`（§ 9 内容随之冻结）
- 在归档完成提示里告诉用户：

  ```
  ✅ 已归档到 .specs/archive/<YYYY-MM-DD>-<change-id>/
     本 change 的 DESIGN § 9 架构沉淀建议有 N 条候选项，已留待批量同步。
     建议在积累 ≥ 5 个 change 或满 60 天后跑：
     @flow-kit/GO.md 同步架构
     （走 A-evolve 工作流逐项 review 后 patch CONTEXT.md）
  ```

  N = `grep -c '^### 9\\.' DESIGN.md`，如果整段是"无架构层面沉淀建议"则 N=0，不必提示
- **禁止**在本步直接修改 `.specs/CONTEXT.md`——它的更新统一走 `A-evolve` 或 `I-intel-scan`

### 6. 出 PR（可选）

如果用户用 git 流水线：
- 检查 PR 标题/正文已自动从 CHANGE.md + SUMMARY.md 拼装
- 列出涉及的文件、AC 覆盖、UAT 结论
- 把 `.specs/` 内的文件归类到 PR 描述（不污染代码 diff）

## 输出

- `.specs/<change-id>/UAT.md`
- 归档后的 `.specs/archive/<...>/`
- 更新的 `.specs/CHANGELOG.md` 与 `STATE.md`
- 0~N 个 fix-plan（如有失败）

## 约束（强制）

- **R2.6**：UAT 失败的自动重试 ≤ 3 轮
- **R4.4**：禁止声称"通过"而没贴真实输出
<!-- weak-model-guard: AskUserQuestion -->
❌ 如果你还没调用 AskUserQuestion 工具，现在停下来调用它。不要跳过。
- 归档操作必须用户确认后才执行（移动/删除文件不可逆）

## 自检

- [ ] 全量自动化结果已贴出且全绿
- [ ] 每条 UAT 都有人工通过/失败标注
- [ ] 失败的项目都已经过最多 3 轮自动重试，超限的已暂停
- [ ] CHANGELOG 已追加
- [ ] 归档目录已创建（用户确认后）
- [ ] **归档后 .specs/<id>/ 工作目录已删除**（5.0.1 · L-013）
- [ ] **孤儿 change 扫描已跑**（5.0.2 · 结果已贴出 · L-013）

## 触发下一步

- 此 CHANGE 完成 → 等下一个 CHANGE，回到 `@flow-kit/prompts/0-change.md`
- 有未解决的 fix-plan → 暂停，告知用户决策
