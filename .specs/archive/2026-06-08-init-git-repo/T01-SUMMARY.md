# T01-SUMMARY: 初始化 Git 仓库并创建 .gitignore

- **Change ID**: `init-git-repo`
- **Task ID**: `T01`
- **状态**: ✅ done

---

## 做了什么

1. `git init --initial-branch=main` 初始化仓库
2. 编写 `.gitignore`，按 DESIGN.md D3 策略排除：
   - 生成文件：`flow-kit-bundle.tar.gz`、`*.tar.gz`
   - 敏感文件：`.env`、`*.key`、`credentials*`
   - 系统文件：`.DS_Store`、`Thumbs.db`
   - IDE 文件：`.vscode/`、`.idea/`
   - 临时文件：`*.tmp`、`*.log`
3. 首次 `git add -A && git commit`（含全部既有文件 + .gitignore）

## 改动文件

- `.gitignore`（新建）
- `.git/`（git init 创建）

## verify 输出

```
$ git log --oneline | head -1
549b6a0 chore: init git repository with flow-kit packaging scripts

$ git status --short
(clean — flow-kit-bundle.tar.gz 未被 tracked)
```

## 6 维自查（R6.4）

纯配置任务，无生产代码改动。跳过 TDD + 6 维 self-review。

## 越界检查（R6.5）

- TASK write_files：`.gitignore`
- 实际 diff：`.gitignore`（新建）、`.git/`（git init 自动创建）
- 越界：0 ✅
