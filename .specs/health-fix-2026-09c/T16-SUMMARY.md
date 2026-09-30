# T16 · C3 历史重写实录（AC-5 · 不可逆）· health-fix-2026-09c

- 执行日期：2026-10-01（阶段 4 DEV · 重写后首提交随本文件入库）
- 执行者：T16 任务会话（编排者授权，真名一律以 `/home/<redacted>` 形态记录）
- 工具：git-filter-repo 2.47.0（`~/.local/bin/git-filter-repo`，可执行）
- 起始状态：HEAD=98cfd44（develop），工作树 porcelain 净，前置 T06/T12b/T13/T15/T17 全 done

## 步序实录（⓪-⑦）

### ⓪ 保存 remote URL + 仓外组装字面量集
- `git remote get-url origin > ../push-url-pre-scrub.tmp` → rc=0，37 bytes（`git@github.com:Hellrabb/flow-kit.git`）。
- 仓外组装 `../scrub-literals.tmp`：2 条 replace-text 规则——`<HOME>==>/home/<redacted>` 与 `<HOME>/==>/home/<redacted>`（裸形态在前，先命中保行结构），chmod 600（73 bytes）。真名明文仅存在于该仓外临时文件（⑥ 已删）与 bundle 备份（仓外保留）。

### ⓪a 工作树净断言
- `git status --porcelain` 输出为空 → rc=0 通过；HEAD=98cfd44，本地分支 develop + main。

### ① 全量 bundle 备份 + verify
- `git bundle create ../backup-pre-scrub-20260929.bundle --all` → rc=0（16,323,982 bytes）。
- `git bundle verify ../backup-pre-scrub-20260929.bundle` → **rc=0**，含 refs：develop=98cfd44、main=47d80f6、origin/develop=534e3e8、origin/main=9b5dda7、tag v0.3.0-gate-integrity=9ffc804、worktrees/v23base/HEAD=8bdfa6b；「记录一个完整历史」。

### ② filter-repo 历史净化
- 实际命令：`~/.local/bin/git-filter-repo --force --replace-text ../scrub-literals.tmp` → **rc=0**，Parsed 554 commits，New history written in 3.26s，HEAD 现位于 d6ca423；origin 按预期被移除（NOTICE 记录原 URL）。
- 重写后即时回验：develop=d6ca423 / main=4c81c66 双双改写；本仓 `git grep -F "$HOME" $(git rev-list --all)` = **0 命中**；porcelain 净。
- 基线对账（ADR-031）：`flow-kit-bundle/flow-kit/reference/path-privacy-baseline.txt` 工作树零漂移（`git diff HEAD` 空）；本机重算 sha256——L_home / L_home_slash / L_pwd / L_pwd_slash 全 **MATCH**（未触发「基线漂移停下报告」例外）。

### ③ reflog expire + gc
- `git reflog expire --expire=now --all` → rc=0；`git gc --prune=now` → rc=0。
- 回验：重写前旧对象 98cfd44 已不可解析（`git cat-file -t` rc=128）——旧历史彻底清除。

### ④ 重加 remote
- `git remote add origin $(cat ../push-url-pre-scrub.tmp)` → rc=0；随后 L_remote sha256 对账 **MATCH**（基线 5/5 全对齐）。

### ⑤ force push 双分支 + 全新 clone 机检
- `git push --force origin develop main` → **rc=0**：develop `534e3e8..d6ca423`；main `9b5dda7...4c81c66`（forced update）。
- 全新 clone（**未用** --single-branch，双分支均检出）到 `mktemp -d /tmp/t16-clone-scan.XXXXXX`：
  - `git ls-remote --heads origin` → `d6ca4233fefbb4823e12b6850c65e0eed340a45a refs/heads/develop`、`4c81c66aaf5ede5d5eacb6a4d9562043d90e5662 refs/heads/main`。
  - clone 内 `git grep -F "$HOME" $(git rev-list --all)` = **0 命中**（远端两分支逐 blob 真名 = 0，AC-5 Then 达成）。
  - clone 临时目录用毕删除（exists=no）。

### ⑥ 清理仓外临时文件
- `rm -f ../scrub-literals.tmp ../push-url-pre-scrub.tmp` → rc=0；两者回验均 GONE；bundle 备份保留（16,323,982 bytes，仓外）。

### ⑦ AC-13 回归批
- `make hooks-sync` → rc=0，「全部副本已一致，无需同步」（✅ 输出中的本机绝对路径为运行时镜像路径，非 tracked 内容）。
- `grep -h '^@test' test/*.bats | wc -l` = **1179 ≥ 1116** ✅。
- 全量 `make check` → **rc=0**，横幅「✅ make check: 全部通过」；要点：check-path-privacy 清单外命中 0（候选 1674，占位符排除后命中合计 0）；check-nfr-portability 存量基线 5 条通过、无新增 bash4-only；check-flow-active-inline 427 条豁免全登记。

## 远端重写前后 SHA 对照

| 分支 | 重写前远端 | 重写后远端（ls-remote 实测） | push 形态 |
|---|---|---|---|
| develop | 534e3e8 | d6ca423（d6ca4233fefbb4823e12b6850c65e0eed340a45a） | `534e3e8..d6ca423` |
| main | 9b5dda7 | 4c81c66（4c81c66aaf5ede5d5eacb6a4d9562043d90e5662） | forced `9b5dda7...4c81c66` |

本地对照：develop 98cfd44→d6ca423；main（孤儿分支）47d80f6→4c81c66。备份锚点全量封存于 `../backup-pre-scrub-20260929.bundle`（verify rc=0）。

## verify 链（任务块原文）

执行方式：porcelain 断言要求工作树净，而本文件与 scrub-history.sh 为待提交新文件，故 verify 时将两者临时移出仓外、全链跑毕移回（保持「verify 先于收尾提交」的编排顺序）。
结果（2026-10-01，全链分步 9 断言全 rc=0）：

| 断言 | rc | 关键输出 |
|---|---|---|
| `git bundle verify ../backup-pre-scrub-20260929.bundle` | 0 | 记录一个完整历史（sha1） |
| `git ls-remote --heads origin` | 0 | develop=d6ca4233fefb…45a / main=4c81c66aaf5e…662 |
| `test -z "$(git status --porcelain)"` | 0 | 移出留痕文件后为净 |
| `git grep -F "$HOME" $(git rev-list --all) \| wc -l \| grep -qx 0` | 0 | 全历史 0 命中 |
| `make hooks-sync` | 0 | 全部副本一致 |
| `make check` | 0 | 横幅「✅ make check: 全部通过」 |
| `@test 计数 ≥1116` | 0 | 1179 |
| `test ! -f ../scrub-literals.tmp` | 0 | 不存在 |
| `test ! -f ../push-url-pre-scrub.tmp` | 0 | 不存在 |

## 偏差记录

1. **② 命令形态**：任务块写「develop 与孤儿 main 分别重写」，实际按编排者修订条款执行单次全 refs 重写（filter-repo 默认处理全部 refs，未加 --refs 拆分）——两分支均被净化已由本仓及远端 clone 双重 0 命中证实；所用命令如实记录于 scrub-history.sh。
2. **verify 顺序处理**：见上「verify 链」节——移出-跑链-移回，非任务偏差，属执行序说明。
3. 其余各步（⓪/⓪a/①/③/④/⑤/⑥/⑦）均按任务块原文执行，无 rc 异常，无不可逆步骤重试；网络面（push/clone）一次成功未触发重试。
