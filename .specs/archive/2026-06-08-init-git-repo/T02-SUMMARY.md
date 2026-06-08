# T02-SUMMARY: 编写 README.md

- **Change ID**: `init-git-repo`
- **Task ID**: `T02`
- **状态**: ✅ done

---

## 做了什么

按 TASK.md T02 规范编写 README.md，3 个二级标题：
1. **仓库用途** — flow-kit 分发包仓库简介
2. **目录结构** — tree 列出所有关键文件用途
3. **开发规范** — 命名约定（kebab-case/snake_case）+ Conventional Commits + 分支策略 + 错误处理 + 技术债跟踪
4. **快速开始** — 一条命令打出新 bundle

沿用 CONTEXT.md 已锁偏好（命名/提交格式/错误处理）。

## 改动文件

- `README.md`（新建）

## verify 输出

```
$ grep -c "^## " README.md
3
```
→ ≥ 3 ✅

## 6 维自查（R6.4）

纯文档任务，无生产代码改动。跳过 TDD + 6 维 self-review。

## 越界检查（R6.5）

- TASK write_files：`README.md`
- 实际 diff：`README.md`（新建）
- 越界：0 ✅
