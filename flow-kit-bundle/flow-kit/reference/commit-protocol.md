# 提交协议 — diff 边界 verify · 原子提交 · SUMMARY

> 本文件是 4-dev 阶段提交完成协议的**单一源**。4-dev.md 通过 `@see reference/commit-protocol.md` 引用此处。
> 修改提交协议时，**只改这一处**。

---

## 提交前 diff 边界 verify（强制 · 对应 R6.5 / B3 老项目护栏）

> 防"AI 顺手改了别的"。提交前必须验证 diff 范围 ⊆ TASK 的 `write_files`。

### 跑 diff 检查

```bash
# 列出实际 diff 涉及的文件
git diff --name-only HEAD
git diff --cached --name-only       # 含 staged
git status --short                  # 含 untracked
```

### 比对 TASK 的 write_files

把上面输出与 `TASK.md` 当前 task 的 `<write_files>` 字段比对：

```
✅ TASK 声明的 write_files：
   - src/features/notifications/NotificationCenter.tsx
   - src/features/notifications/useNotifications.ts
   - src/features/notifications/__tests__/*

✅ 实际 diff 涉及：
   - src/features/notifications/NotificationCenter.tsx
   - src/features/notifications/useNotifications.ts
   - src/features/notifications/__tests__/NotificationCenter.test.tsx

→ 0 越界 ✅
```

或者：

```
⚠️ 越界检测：

✅ TASK 声明的 write_files：
   - src/features/notifications/*

❌ 实际 diff 越界文件：
   - src/components/Layout.tsx（DESIGN 0.5.1 「禁动清单」中的文件）
   - src/api/admin/users/route.ts（不在 write_files 范围内）

→ 必须停下来：
   选项 1. 撤销越界改动（git checkout -- <files>）
   选项 2. 更新 TASK 的 write_files（须人工同意，相当于扩范围）
   选项 3. 把越界改动拆成新 task / 新 CHANGE
```

### 验证结果写入 SUMMARY「越界检查」段

即使 0 越界也要写：

```
✅ 越界检查（R6.5）：
   - TASK write_files：3 项
   - 实际 diff 涉及：3 项
   - 越界：0
```

**禁止**："顺手修了个 bug" / "看到这里很丑就改了"——必须开新 task 或新 CHANGE。

---

## 原子提交（R4.1）

提交格式：
```
<type>(<change-id>): <task-id> <subject>
```
例：`feat(add-dark-mode): T03 add ThemeContext provider`

代码 + 测试同次提交（或紧邻的下次提交）。

---

## 写 SUMMARY

使用 `@flow-kit/templates/SUMMARY.md` 模板，填到 `.specs/<change-id>/<task-id>-SUMMARY.md`。
内容：做了什么 / 改了哪些文件 / verify 输出 / **6 维自查输出**（brooks-review 或内置回退结果）/ 是否触发新 fix-plan。

---

## 标记完成

回到 `TASK.md`，把对应任务的 `done` 字段标记为已完成（保留时间戳）。

---

## task_progress 写入（ADR-015）

每个 task 完成（verify 通过）后，jq append 到 `.flow-active`：

```bash
jq --arg id "$current_task" \
   --arg sha "$(git rev-parse --short HEAD 2>/dev/null || echo '')" \
   --argjson fix_rounds 0 \
   --argjson deferred '[]' \
   --arg ts "$(date -Iseconds)" \
   '.goal.task_progress += [{
     id: $id,
     commit_sha: $sha,
     fix_rounds: $fix_rounds,
     deferred: $deferred,
     completed_at: $ts
   }]' .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
```

字段严格匹配 ADR-015 schema（5 字段：id / commit_sha / fix_rounds / deferred / completed_at），不允许扩展。

**向后兼容**（AC-F1）：旧 `.flow-active` 无 `task_progress` 字段 → jq `+= [{...}]` 自动创建数组，不报错。

---

## Hook 兼容性自检（33-flow-active-integrity）

写入 task_progress 后，确认 33-flow-active-integrity hook 不会误报：
- 旧 `.flow-active`（无 task_progress 字段）：hook 应当 graceful skip（当前实现）
- 新 `.flow-active`（有 task_progress）：hook 字段集检查通过
- 字段集违反（缺 id 等）：v1 不校验，v2 留

---

## 归档 commit（7-integration 步骤 5.1 · 非任务级 commit）

归档 commit 是 7-integration 阶段专属，**不属于任务级 commit**（4-dev 的本协议主体）。分类规则：

- **fix**：归档的 change 产出包含 bug 修复 / 行为变更
- **docs**：归档的 change 产出仅含文档 / prompt / 配置变更
- **chore**：归档元数据（CHANGELOG / STATE / LESSONS sync）

拆分上限：≤ 3 个原子提交。AC-1 验证方式：`git log $ARCHIVE_BASE_SHA..HEAD --oneline` 行数 ≤ 3 且类型 ∈ {fix, docs, chore}。

> **协议源声明补充**（archive-commit-gate change · L-023）：归档 commit 分类从「复用任务级 commit 协议」明确移到「7-integration 阶段专属修改段」，消除分类漂移。
