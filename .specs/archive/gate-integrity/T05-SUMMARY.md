# SUMMARY: T05 - AC-3 阶段判定 + case 5 站点同步扩 3/5/7（D6）

- **Change ID**: gate-integrity
- **Task ID**: T05
- **完成时间**: 2026-07-02 11:23
- **AI 角色**: Dev

---

## 做了什么（一段话）

按 G2 ADR + AC-3 Then + DESIGN D6，把独立 review gate 的阶段判定从硬编码 `^(1|2|6)$` 同步扩到 `^(1|2|3|5|6|7)$`，覆盖 grep 实证的 **5 站点**（3 正则 + 2 case phase_name 映射）：`independent-review-gate.sh:39` 正则 + `:56-64` case、`29-independent-review.sh:33` 正则、`flow-kit-artifacts.sh:109` 正则 + `:115-123` case。动态读 `.flow-active.goal.gate_config["<phase_name>"]` 的逻辑在 `fk_independent_review_gate_active`（artifacts.sh:124-134）**本已实现**（双源：gate_config 优先 + stop-hook.json 回退），T05 只需让 3/5/7 能进入该函数（扩前置正则）+ 能映射到 phase_name（扩 case），无需新增判定逻辑。改完跑 install.sh 部署到 ~/.claude 运行时（L-015）。

## 改动文件

| 文件 | 性质 | 说明 |
|---|---|---|
| `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` | 修改 | :39 正则扩 + :56-64 case 补 3-task/5-test/7-integration（站点 1+2）|
| `flow-kit-bundle/hooks/stop/29-independent-review.sh` | 修改 | :32-33 Gate 3 正则扩 + 注释同步（站点 3）|
| `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh` | 修改 | :109 正则扩 + :115-123 case 补 3/5/7（站点 4+5）|

> 注：`29-independent-review.sh` 的 git diff 另含 AC-6 前置修复（`>>` 追加 / `fail_count` 随 verdict / 不 dump 原始 `$ai_response` / L3 盲审标题改写）——这部分 session 开始前已在工作树（TASK.md L9 注明"AC-6 三处修复…已在树，本 TASK 不重复"），**非 T05 引入**，但在 29号 ∈ write_files 文件范围内。

## verify 输出（必填）

TASK.md 给的 verify `grep -L '3|5|7' <3 files> || echo "all 5 sites updated"` **本身有 bug**（见「决策与偏离」），改用等价正确验证：

```text
# 1) bash 语法（3 文件）
$ bash -n gate.sh && bash -n 29-independent-review.sh && bash -n flow-kit-artifacts.sh
gate.sh: 语法 OK / 29号: 语法 OK / artifacts.sh: 语法 OK

# 2) 扩正则实证（站点 1/3/4 · 每文件 ≥1 行）
$ grep -nE '1\|2\|3\|5\|6\|7' <3 files>
gate.sh:39:[[ "$phase" =~ ^(1|2|3|5|6|7)$ ]] || exit 0
29号:33:[[ "$phase" =~ ^(1|2|3|5|6|7)$ ]] || exit 0
artifacts.sh:109:  [[ "$phase" =~ ^(1|2|3|5|6|7)$ ]] || return 1

# 3) case 新分支实证（站点 2/5 · gate.sh + artifacts.sh 各 3 分支）
phase_name="3-task" / "5-test" / "7-integration" → 各文件各 1 匹配 ✅

# 4) 不回归 bats
$ npx bats test/test_stop_chain.bats         → 13 passed, 0 failed
$ npx bats test/test_gate_config_presets.bats → 39 passed（含 AC-4 数字 3/5/7 映射 + all 预设）

# 5) 部署 + L-015 一致性
$ install.sh --global --user --no-skills --no-brooks --no-brooks-tools
$ diff 源 vs ~/.claude/ 运行时 → 3 文件全一致 ✅
```

## 6 维自查（生产代码改动 · 内置快查）

> T05 改动机械（5 处扩分支，每处 1-3 行，纯增加），且 Wave 2 共 7 个串行 task；选用内置 R1~R6 快查而非逐 task 跑 /brooks-review。后续含实质新逻辑的 task（T06 新建函数 / T09 新建检测）将跑 /brooks-review。

- 🟢 **R1 认知过载**：未新增函数，仅扩 case 分支 + 正则。最长改动段（artifacts.sh case）9 行。无函数 > 50 行 / 嵌套 > 3 层。
- 🟢 **R2 变更传播**：仅改 write_files 内 3 文件，无无关模块波及。
- 🟢 **R3 知识重复**：case phase_name 在 gate.sh + artifacts.sh 两处镜像——这是 **DESIGN D6 明确的"多源镜像"决策**（grep 实证 5 站点，靠 bats T13 + check-gate-sync.sh 兜底漂移），非复制粘贴式重复。
- 🟢 **R4 偶然复杂**：只加必要分支，无"以后可能用到"的扩展点。0/4 仍按设计排除（无独立 review 阶段）。
- 🟢 **R5 依赖混乱**：hook 脚本无跨层 import。
- 🟢 **R6 领域扭曲**：phase_name 用领域词（3-task / 5-test / 7-integration），非 data/info。

### 已知接受 + 理由

无 🟡 Major。

### 已知小问题

- 🟢 **TASK.md verify 命令 BRE bug**：`grep '3|5|7'`（无 `-E`）在 BRE 下 `|` 为字面竖线，永远查不到字面串 `3|5|7`（文件含 `1|2|3|5|6|7`，无连续 `3|5|7`）→ 该 verify 无法判定"已扩"。已在 SUMMARY 用正确验证替代，**不擅改 TASK.md**（R3.2）。建议 T14 或后续把 verify 修为 `grep -nE '1\|2\|3\|5\|6\|7'` 或直接查 case 分支。

## 数据库迁移

N/A（Bash hook 改动，无 schema）。

## 越界检查（必填）

```
✅ 越界检查（R6.5）：
  - TASK write_files：3 项（gate.sh / 29号 / artifacts.sh）
  - T05 实际引入改动：3 项（5 站点全在 write_files 内）
  - 越界：0
  - 注：工作树 29号 另含 AC-6 前置修复（session 前在树，非 T05 引入），文件级仍在 write_files 内
```

## 破坏性变更

N/A。判定未命中：扩正则 + 加 case 分支属**增加**（非删除 ≥5 行 / 非改公共接口签名 / 非改公共 API / 非删文件）。gate 的外部可观测行为（exit code）对 1/2/6 不变；3/5/7 是新增可达路径（且默认 off，gate_config 不含即放行）。

## 决策与偏离

1. **TASK.md verify 命令 BRE bug**（见「已知小问题」）：用 `grep -nE '1\|2\|3\|5\|6\|7'` + case 分支 grep 替代，等价且正确。
2. **动态读 gate_config 无需新增**：G2 ADR Decision 2 要求"动态读 gate_config"，实证发现 `fk_independent_review_gate_active`（artifacts.sh:105-139）**早已实现**双源动态读（gate_config 优先 + stop-hook.json 回退）。T05 的"阶段判定改动态读"实际只需扩前置正则让 3/5/7 能进入该函数，无需重写判定逻辑。这与 G2 ADR Consequences"加新阶段只改 gate_config 不改正则"一致（正则扩后，加阶段 = 改 gate_config）。

## ⚠️ 关键发现 · 传递给 T06（死锁预警 · 不阻塞 T05）

**29号 artifact 拼接 case（:77-104）无 3/5/7 分支**。数据流推演：
- T05 后，phase=3 + gate_config 含 `3-task=independent` → 29号 Gate 3（:33）放行 → `fk_independent_review_gate_active(3)` 返回 0（gate 生效）→ 但 artifact case 无 3 分支 → `artifact=""` → `[ -n "$artifact" ] || exit 0`（:105）→ **L3 不产出，握手文件不写**。
- **当前（T05 后、T06 前）不死锁**：done 校验仍是 `[ -f ]`（gate.sh:54），用户可 `touch .done` 绕过（这正是 AC-1 威胁①要消灭的，T06 才堵）。
- **T06 引入握手校验后会死锁**：T06 Tier 2 T3 要求 `.flow-active.independent-review written_by=stop-hook-29`，而 29号对 3/5/7 跑不出握手 → done 永远无效 → commit 永远被拦。

**T06 必须二选一决策**（按 R7.1，到 T06 真正阻塞时处理，非 T05 范围）：
- (A) 扩 29号 artifact case 到 3/5/7（3→TASK.md / 5→TEST.md / 7→archive+CHANGELOG）—— 让 L3 真正产出
- (B) T06 Tier 2 T3 对 3/5/7 降级（只要求 L2 子 agent 盲审，不要求 L3 握手）

TASK.md 无任何 task 覆盖 29号 artifact case 扩展，属设计遗漏。已在 task list T06 description 标注。

## 是否触发新工作

- [ ] 触发新 fix-plan（已追加到 TASK.md）
- [x] 发现设计问题（29号 artifact case 死锁），已记录传递给 T06，**未暂停**（T05 本身不阻塞，死锁在 T06 才暴露）
- [ ] 触发 CONTEXT.md 更新

## 完成判定

- TASK.md 中对应任务已勾选：是（本 SUMMARY 后勾选）
- 提交 hash：未提交（Wave 2 串行进行中，按既定不逐 task 提交）
