# HISTORY-REWRITE-FULL.md — develop 全历史重写：执行单与影响面

> **本文档不复写被脱敏的字面量**，一律写作 `/home/<user>` 占位。原因：本项目已经踩过
> 「文档描述擦洗 → 自己又把串写回仓库」的自指坑（前向擦洗后仍有一轮专门修自指占位提交）。
> 机器可读的逐提交映射见同目录 `HISTORY-REWRITE-FULL-MAP.txt`（330 行）。

- change-id：`privacy-path-scrub-2026-09`
- 执行时间：2026-09-22（本机时区）
- 触发原因：`privacy-path-scrub-2026-09` 的前向擦洗只覆盖**未推送窗口**；**已推送**的
  `origin/develop` 仍有 39 个文件（30 md / 2 py / 6 pyc / 1 bak）携带本机绝对路径。
  本次把擦洗扩展到**含已推送提交的全历史**，由维护者强推。

---

## 1. 执行前基线（冻结值，重写后逐一复核）

| 项 | 值 |
|---|---|
| HEAD | `ca42e0043a9f56b4b30d79a728fd99b351c23609` |
| tip 树 | `b7002313ca5ec3117a70e3c69f8be28f42fa7829` |
| develop 提交数 | 331 |
| 跟踪文件数 | 1527 |
| 远端 `origin/develop` | `19b3463982449b6f976d1a8d4f3ed0f07e9e1e0a` |
| 领先 / 落后远端 | 41 / 0（无他人提交，强推不会覆盖别人的工作） |
| 远端标签 | 无（`git ls-remote --tags` 空）→ 只需强推分支 |

## 2. 重写范围与不动的部分

- **重写**：`refs/heads/develop` 全部 331 颗提交（含已推送的 34 颗含串提交）+
  `refs/tags/v0.3.0-gate-integrity`（注解标签，其指向的提交在重写范围内）。
- **不动**：`refs/remotes/origin/*`（远端跟踪 ref 未被我改；重写中它们仍指向旧提交）；
  `origin/main`——它与 `develop` **无共同祖先**（`git merge-base` 失败），且其树命中为 0，
  因此强推 develop 不会牵连 main，旧对象也不会经 main 存活。
- 未推送窗口此前已擦洗（41 颗提交逐树 0 命中），本次把**已推送**部分补齐。

## 3. 变换规则（三遍，逐遍可复核）

| 遍 | 过滤器 | 动作 | 结果 |
|---|---|---|---|
| 1 | `--tree-filter` + `--prune-empty` | 删除**每棵树**里的 `*.pyc` / `*.bak`；文件内容 `/home/<user>` → `~` | 331 → 330（1 颗提交被折叠，见下）|
| 2 | `--msg-filter` | 提交信息 `/home/<user>` → `~`（命中 4 颗：2 颗主题 + 2 颗正文）| 信息命中 0 |
| 3 | `--msg-filter` | 仅修措辞：信息脱敏后出现「`~ → ~`」语义失真处改用 `/home/<user>` 占位 | 可读性恢复 |

- **被折叠的 1 颗提交**：`chore(privacy-path-scrub-2026-09): 本 change 自身文档改用 /home/<user> 占位`
  （旧 `5f02fb6`）。在全历史归一后它与父树**净效应为零**，被 `--prune-empty` 正确移除；
  **无内容损失**（见 §4 的 tip 树逐字节一致证明）。
- 湿跑（clone 内）与真实仓库三次 filter-branch 产出的**新标签对象哈希完全一致**，
  证明变换是确定性的、湿跑结论可移植。

## 4. 零内容变化证明（重写只改历史，不改现状）

| 判据 | 结果 |
|---|---|
| tip 树哈希 | `b7002313ca5ec3117a70e3c69f8be28f42fa7829`（与 §1 逐字节相同）|
| `git diff --stat` 旧 tip vs 新 tip | **0 行** |
| 跟踪文件数 | 1527 = 1527 |
| 330 颗逐位置对齐逐树比较 | 51 处删除**全部只删 pyc/bak**（373 个文件位）；**非 pyc/bak 删除 = 0** |
| 路径宇宙（`ls-tree` 全历史并集，去 pyc/bak）| 旧 2170 = 新 2170；仅旧有 0 / 仅新有 0 |
| 工作区状态 | `git status` 干净（0 项）|

> 方法说明：对齐用「提交顺序 + 主题」的序列比对（difflib），不靠哈希猜测；
> 配对 330 + 折叠 1 = 旧 331，映射表内自带该断言。

## 5. 残留面扫描（逐载体穷举，不只扫树）

| 载体 | 扫描方式 | 结果 |
|---|---|---|
| 全历史树内容 | 330 颗提交逐树 `git grep` | **0** |
| 提交信息 | 330 条 `%B` 全文 | **0** |
| 标签信息 | `for-each-ref refs/tags %(contents)` | **0** |
| 路径名（文件名本身）| `ls-tree -r --name-only` | **0** |
| notes / stash / submodule | `refs/notes`、`git stash list`、`.gitmodules` | 0 / 0 / 无 |
| 作者·提交者字段 | `hellrabbit <hellrabbit@users.noreply.github.com>` | **判定非泄露，不改** |

**关于作者字段**：该地址是 GitHub 的 **noreply 隐私别名**（不含真实邮箱），且账号名
本就随公开仓库 URL `git@github.com:Hellrabb/flow-kit.git` 公开；用 `--env-filter` 改写
只会**伪造作者归属**，故不做。若将来要统一身份，应作为独立变更决策。

## 6. 哈希引用修复（重写使全部旧短哈希失效）

| 旧 | 新 | 语义 | 引用文件 |
|---|---|---|---|
| `4bc151d` | `be138c0` | L3 审查链缺陷修复提交 | `corpus-count.sh`、`test/test_l3_review_defects_2026_09.bats`、`flow-kit-bundle/test/test_l3_review_defects_2026_09.bats`（+ dist 打包件重建）|
| `817c0b1` | `ef1397b` | 配置统一用户级提交 | `test/test_guide_copy_parity.bats`、`flow-kit-bundle/test/test_guide_copy_parity.bats` |
| `693fd5c` | `a001dc9` | health-fix-2026-09 T01–T06 提交 | `.brooks-lint-history.json` |

- **非空转校验**：`corpus-count.sh` / bats 用该提交做「基线语料快照」，
  `git ls-tree -r --name-only be138c0` 可枚举 **222** 个 `INDEPENDENT-REVIEW-*.md` —— 若哈希写错，
  枚举会退化为空、断言静默变成空转，故此项单独验证。
- 历史性记录（`history-rewrite-map.txt`、`IMPACTED-REFS.md`）**保留旧哈希并加取代说明**，
  它们是「当时那次操作」的忠实记录，回填会伪造历史。
- **结构性隐患（未在本 change 实施）**：测试/脚本以**短哈希**锚定历史时点，每次重写都要人工修。
  建议后续改为「按主题解析」（`git log --grep` 定位），已登记为 lesson。

## 7. 安全网与回滚

| 安全网 | 位置 | 校验 |
|---|---|---|
| 裸包 | `~/flow-kit-backups/pre-full-rewrite-20260922-092611.bundle`（14,056,224 B）| `git bundle verify` 通过；含 `develop` / `main` / `origin/*` / `v0.3.0-gate-integrity` / `HEAD` 全部 ref |
| 本地 ref | `refs/backup/pre-full-rewrite` → 旧 tip `ca42e00` | 故意用**非 tag** ref：`--tag-name-filter` 只会移动 tag，不会动它 |
| 远端 | `origin/develop` 未动（旧历史在远端完整保留）| 强推成功前，旧历史随时可取回 |

回滚（任一步出错）：`git clone ~/flow-kit-backups/pre-full-rewrite-20260922-092611.bundle restored/`
→ 在 `restored/` 校验后重新推送。**强推确认无误后**该 bundle 与 `refs/backup/*` 应删除（§8）。

## 8. 强推指令（维护者执行）

```bash
git push --force-with-lease=develop:19b3463982449b6f976d1a8d4f3ed0f07e9e1e0a origin develop
```

- 用**显式期望值**而不是裸 `--force-with-lease`：本机 `origin/develop` 跟踪 ref 仍指向旧 tip，
  显式 A 值语义最明确（远端若已变成别的值会直接拒绝，不会误覆盖）。
- 强推后收尾（把「旧对象仍可达」这个尾巴彻底切掉）：

```bash
git fetch origin                       # 远端跟踪 ref 指向新历史
git update-ref -d refs/backup/pre-full-rewrite
git reflog expire --expire=now --all && git gc --prune=now
# 权威验证：对象库里任何对象都不再含该串
git cat-file --batch-all-objects --batch-check='%(objectname) %(objecttype)' \
  | awk '$2=="blob"{print $1}' | git cat-file --batch | grep -ac '/home/<user>占位外的真实前缀'   # 期望 0
rm -f ~/flow-kit-backups/pre-full-rewrite-*.bundle   # 确认无误后再删
```

- **远端残留（诚实边界）**：GitHub 侧旧提交在强推后变成不可达对象，按 SHA 可能短期仍可访问
  （服务端 gc 前）；若存在来自这些提交的 PR，`refs/pull/*` 会继续固定它们。
  如需确定性清除，需向 GitHub Support 申请 gc / 删除相关 PR ref——这不在本机可控范围。
- 旧 **fork / 他人克隆**里的历史无法回收，本机只能保证 `origin` 指向新历史。

## 9. 未纳入本次的残留（需再次决策）

| 串 | HEAD 命中 | 性质 |
|---|---|---|
| `hellrabbit`（**裸词**，不含 `/home/` 前缀）| 19 文件 / 40 行 | 与已公开 GitHub 账号名同形；多为归档审计报告对被审计事实的复述 |
| `unisoc` | 33 文件 / 87 行 | **组织/雇主线索**：项目路径写作 `~/unisoc/flow-kit`，前缀已归一但目录名保留 |
| `/home/ubuntu` | 3 文件 / 3 行 | 通用示例路径，非本机用户 |

- 这三项**不在本次批准的替换规则内**（本次规则 = `/home/<user>` → `~` + 移除 pyc/bak）。
- 扩展它们意味着**同时改动当前工作区内容**（HEAD 树会变），属于新的前向变更，
  需要新的一轮「前向提交 + 全历史重写 + 门禁」，因此单列出来等决策。
- 量化命令（避免把串写进文档）：`PAT=$(printf '/home/%s' "$(id -un)")` 之外的裸词/组织名
  请从 `git remote get-url origin` 与项目父目录名推导后传入 `git grep -c`。

---

## 附：验证命令清单（可复跑）

```bash
# 1) 三面命中
for c in $(git rev-list develop v0.3.0-gate-integrity); do git grep -lF "$PAT" $c -- .; done | wc -l   # 0
git log develop --format='%H%n%B' | grep -cF "$PAT"                                                    # 0
git rev-list --objects develop v0.3.0-gate-integrity | grep -cE '\.(pyc|bak)$'                         # 0
# 2) 零内容变化（对照 §1 基线）
git rev-parse develop^{tree}    # b7002313ca5ec3117a70e3c69f8be28f42fa7829
git status --porcelain | wc -l  # 0
# 3) 引用哈希可解析且非空转
git ls-tree -r --name-only be138c0 | grep -cE '\.specs/.*INDEPENDENT-REVIEW-.*\.md$'                   # 222
```
