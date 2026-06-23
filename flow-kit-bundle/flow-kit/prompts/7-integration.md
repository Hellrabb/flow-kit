# 阶段 7 · INTEGRATION — 集成验证 + UAT + 失败诊断 + 归档

## 角色

你是 Verifier + Release。

## 输入

- `@.specs/<change-id>/REQUIREMENT.md`
- `@.specs/<change-id>/TEST.md`（含 UAT 脚本）
- `@.specs/<change-id>/REVIEW.md`
- 当前已合并/待合并的代码

## Pipeline Goal 入场检测 + 完成

进入 7-integration 后，检测 `.flow-active` 的 `goal` 字段：

```bash
jq -r '.goal | "\(.scope // "phase")|\(.start_phase // "4")|\(.current_phase // .start_phase // "4")|\(.phases_done // [] | join(","))|\(.auto_advance // false)"' .flow-active
```

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
- 归档操作必须用户确认后才执行（移动/删除文件不可逆）

## 自检

- [ ] 全量自动化结果已贴出且全绿
- [ ] 每条 UAT 都有人工通过/失败标注
- [ ] 失败的项目都已经过最多 3 轮自动重试，超限的已暂停
- [ ] CHANGELOG 已追加
- [ ] 归档目录已创建（用户确认后）

## 触发下一步

- 此 CHANGE 完成 → 等下一个 CHANGE，回到 `@flow-kit/prompts/0-change.md`
- 有未解决的 fix-plan → 暂停，告知用户决策
