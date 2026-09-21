# DESIGN: 绝对路径脱敏与历史清理

- **Change ID**: privacy-path-scrub-2026-09

## 0. 技术栈

不需要选型。工具链：`git grep` / `sed` / `git rm --cached` / **`git filter-branch`**（内建）+ `git gc`。

## 0.5 既有架构对齐

- **触碰**：49 个已跟踪文本文件（40 md / 2 py / 1 bak + 归档文本）· `.gitignore` · git 对象库（37 个未推送提交）
- **复用既有抽象**：沿用仓库既有的「唯一维护源 + 逐级上溯解析仓库根」范式；`.gitignore` 已有 `*.pyc`/`__pycache__/`，只需补 `*.bak`
- **禁动清单核对**：`.gitignore` 在 CONTEXT 禁动清单内（「不允许 AI 顺手重写」）→ 本 change **显式声明例外**：只**追加**一条 `*.bak` 规则，不删改既有行（diff 可复核）；运行时实现（`hooks/**`、`lib/**`、`skills/**`、`prompts/**`）一律不动
- **不引入新依赖**（filter-repo 未安装，不装）

## 1. 决策

### D1 · 用 `git filter-branch` 而非 `git filter-repo`
- 备选：(a) `pip install git-filter-repo`；(b) 内建 `filter-branch`；(c) 只做前向脱敏不碰历史
- 理由：用户已选「清历史」；(b) 零新增依赖、37 个提交规模足够（实测可接受）；(a) 需联网装包，且 filter-repo 默认要求 fresh clone（`--force` 有坑）
- 代价：`filter-branch` 有已知坑（需 `FILTER_BRANCH_SQUELCH_WARNING=1`、需手清 `refs/original`/reflog）→ 缓解：先做 bundle+tag 安全网，逐条验证，最后统一 gc

### D2 · 替换策略：字面 `~` → `~`
- 备选：(a) 替换为 `~`；(b) 替换为 `$HOME`；(c) 删除整行
- 理由：(a) 在文档语境最自然、零语义损失；(b) 在 md 里不自然；(c) 会丢信息
- 代价：`tools/pptx-light-sync.py` 等**代码**里的字符串会变成 `"~/..."`（Python 不展开 `~`）→ 缓解：该脚本为**已登记的 stale 工具**（`pptx-light-sync` 引用了过期的 19 页/旧日期），本 change 将其改为 `os.path.expanduser()` 形式并在 LESSONS 登记

### D3 · 路径清理优先级：先前向、后历史
- 理由：工作区改完才能形成一个「干净」的提交；历史重写放在最后，且只对 `origin/develop..HEAD` 生效（已推送部分不动）
- 代价：重写后哈希变化 → 需 old→new 映射（D4）

### D4 · 可追溯性：产出映射与被影响引用清单
- 理由：仓库内大量文档以短哈希引用近期提交（如 `5583e2a`/`27ab400`），重写后失效；不登记会制造「查不到」的坑
- 代价：需额外一次全仓扫描

### D5 · 安全网生命周期：验证后**删除**
- 理由：tag/bundle 会让旧对象继续可达——不删除等于「隐私清理」不成立
- 代价：删除后无法回退到重写前（缓解：删除**前**完成 AC-1~AC-4 全部验证）

## 2. 管线

```
① 安全网：git bundle --all → /tmp + tag pre-scrub-backup
        ↓
② 前向脱敏（工作区）：49 文件字面替换 → 代码文件语义化改写
        ↓
③ 停止跟踪：git rm --cached 6×.pyc + 1×.bak → .gitignore 追加 *.bak
        ↓
④ 提交（light profile：1 个原子提交）
        ↓
⑤ 历史重写：filter-branch --tree-filter（文本替换）+ --index-filter（移除 pyc/bak）→ origin/develop..HEAD
        ↓
⑥ 清理：删 refs/original → reflog expire → gc --prune=now
        ↓
⑦ 验证：AC-1/2/3/4 实跑 + 产出映射（AC-5）
        ↓
⑧ 归档：.specs/archive/<日期>-privacy-path-scrub-2026-09/ + 提交
        ↓
⑨ 安全网删除：tag + bundle → 复核旧对象不可达
```

## 4. 风险

| # | 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|---|
| R1 | `sed` 误伤非目标内容 | 低 | 文本损坏 | 只替换字面量 `~`；改后逐文件 diff + `make check` 回归 |
| R2 | 重写后旧对象仍可恢复 | **中（若漏步）** | 隐私清理失效 | 强制三段清理（refs/original / reflog / gc --prune=now），并用 `git cat-file -e <old-blob>` 复核 |
| R3 | 哈希引用失效 | 高（必然） | 文档指向不存在的提交 | D4 映射 + `IMPACTED-REFS.md` |
| R4 | filter-branch 中断/异常 | 低 | 仓库状态混乱 | 先 bundle 全量备份；失败可 `git reset --hard pre-scrub-backup` 回滚 |
| R5 | 误改代码语义（py） | 中 | 脚本不可运行 | 代码文件逐个语义化改 + `python3 -m py_compile` 复核 |

## 5. 不在范围内

- 已推送历史的重写（需强推）
- vendor 上游公开邮箱
- 给 `.specs/**` 脚本做「路径变量化」重构（v2）

## 9. 架构沉淀建议

**有**：给仓库加一条**防复发门禁**——`git grep -lE '/home/[a-z]'` 命中即失败（v2 落地，本 change 只登记）。已写入 `.specs/CONTEXT.md` 术语/决策区。
