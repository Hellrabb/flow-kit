# T06-SUMMARY — C3 短期脱敏（AC-4 · T04 后）

- **task**: T06「C3 短期脱敏 tracked 30 行」（AC-4，depends_on T04=863c82a）
- **执行者**: 阶段 4 DEV 子代理（fresh context，只做 T06）
- **日期**: 2026-09-30
- **本文所有路径均以 `/home/<acct>` 脱敏定式书写**（本任务即脱敏任务，SUMMARY 不得含真名）

## 0. 结论

T04 版门禁（PAT 路径段边界形态）自跑 = **清单外命中 48 条**（非派发预告的 47，非任务块旧文的"6 文件 30 行"；以实跑输出为准）。全部处置完毕后：

| verify | 结果 |
|---|---|
| ① `test "$(git grep -lF "$HOME" \| wc -l)" -eq 0`（tracked 面） | **rc=0 通过** |
| ② `test "$(grep -rlF "$HOME" .specs/health-fix-2026-09c/ \| grep -v '\.done$' \| wc -l)" -eq 0`（09c 入库面） | **rc=0 通过** |
| ③ `bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` → rc=0（编排者增补终判据） | **rc=0 通过（清单外命中 0 条）** |

## 1. 自跑门禁原始输出（脱敏后摘录）

首跑（处置前，逐字摘录计数行；归因行含真名，不原文引用，见下方归因统计表）：

```text
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*([^a-z0-9_-]|$)）
   扫描面: 工作树（git index：已 add / 已提交）
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   候选文件 1639 个
   实际扫描 1637 个
   自排除 2 个
   index 侧 26 条
   不可读候选 0 个
   命中合计 48 条（含占位符排除后）
   清单外命中 48 条
🔴 清单外命中 48 条（非允许清单命中 ⇒ 阻塞，ADR-027 ②③ / ADR-028 决策 2）
rc=1
```

**48 条归因（按 file 统计的命中行，脱敏后的机理分类）**：

| 类别 | 文件 | 命中行数 | 说明 |
|---|---|---|---|
| 真名（字面 `/home/<acct>` 原文） | `.specs/health/2026-09-22-FULL-SWEEP.md` | 11 | 与任务块 AC-4 清单一致 |
| 真名 | `.specs/archive/2026-09-28-health-fix-2026-09b/INDEPENDENT-REVIEW-2.md` | 9 行（12 处，含 2 处 `~root` 展开复合形态 → `/home/<acct>root`） | 09b IR-2 归档副本不在 SELF_EXCLUDE（豁免只精确匹配归档前路径 `.specs/health-fix-2026-09b/...`） |
| 真名 | 同目录 `INDEPENDENT-REVIEW-1.md` | 6 | 同上 |
| 真名 | `.specs/STATE.md` | 2 | 与任务块一致 |
| 真名 | `.specs/CONTEXT.md` / `.specs/LESSONS.md` | 各 1 | 与任务块一致（30 行口径：11+9+6+2+1+1=30，与 09c IR-2:233 记录的 AC-4 基线吻合） |
| 真名（旧 de-shape 变体，名字中段插 `*`/`…`） | 同目录 `T13-SUMMARY.md` | 3 | T13 的 09b 时代 de-shape 形态不敌 T04 广义边界类，仍命中 |
| 合成示例名（`alice` / `test` / `zz-*`） | 09b 归档 IR-2 | 5 行（7 处） | 09b 审查档用作 PAT 漏报样例的人名/夹具字面；`test`、`alice` 被门禁脚本注释**明确禁止**加入 PLACEHOLDER_NAMES（09b IR-2/IR-3 裁决），只能改内容形态 |
| 同上 | 09b 归档 IR-3 | 1 | `HOME=/home/⟨test⟩` 夹具字面引用（原为无 ⟨⟩ 夹具字面） |
| 同上 | 09b 归档 IR-7 | 4 行（5 处） | `/home/⟨zz-uat-probe⟩` 探针字面引用（原为无 ⟨⟩ 字面） |
| 同上 | `.specs/health-fix-2026-09c/T04-SUMMARY.md` | 1 | T04 自己写的示例 `/home/⟨alice-doc⟩/x`（`alice-doc` 不在占位符表 ⇒ 原无 ⟨⟩ 形态命中；`/home/fooBar` 提取 `foo` 属占位符不命中） |
| index 侧陈旧副本重复归因 | CONTEXT/LESSONS/STATE | 4 | 门禁扫 index∪磁盘并集：这三文件 index 里是旧行号版（569↔580 等），磁盘是新行号版，同一内容两侧各归因一次 |

小计：磁盘真名 30 行 + de-shape 变体 3 行 + 合成示例 11 行 + index 陈旧重复 4 行 = **48**，全部对账相符。

## 2. 逐文件替换表（实际执行）

替换定式：真名 → `/home/<acct>`（`~root` 复合形态 → `/home/<acct>root`）；T13 旧 de-shape 变体 → `/home/<acct>`；合成示例名 → `/home/⟨name⟩`（**⟨⟩ 标记紧跟 `/home/` 之后**——T04 广义边界类下，09b 时代"名字中段插 ⟨⟩"的旧定式已失效，`⟨` 必须落在 `[a-z_]` 首字符位之前才不命中 PAT）。

| 文件 | 替换行数 | 替换处数 | 内容 |
|---|---|---|---|
| `.specs/health/2026-09-22-FULL-SWEEP.md` | 11 | 11 | 真名 → `/home/<acct>` |
| `.specs/archive/2026-09-28-health-fix-2026-09b/INDEPENDENT-REVIEW-2.md` | 14 | 19 | 真名 9 行 12 处（含 2 处 → `/home/<acct>root`）+ 合成 5 行 7 处（⟨alice⟩×3、⟨zz⟩-path-、⟨zz-path-probe⟩、⟨test⟩×2） |
| 同上 `INDEPENDENT-REVIEW-1.md` | 6 | 6 | 真名 → `/home/<acct>` |
| 同上 `INDEPENDENT-REVIEW-3.md` | 1 | 1 | `HOME=/home/⟨test⟩` |
| 同上 `INDEPENDENT-REVIEW-7.md` | 4 | 5 | `/home/⟨zz-uat-probe⟩` |
| 同上 `T13-SUMMARY.md` | 3 | 3 | 旧 de-shape 变体 → `/home/<acct>`（`/home/<acct>*` 一处保留 `*` 以示前缀义） |
| `.specs/STATE.md` | 2 | 2 | 真名 → `/home/<acct>` |
| `.specs/CONTEXT.md` | 1 | 1 | 真名 → `/home/<acct>` |
| `.specs/LESSONS.md` | 1 | 1 | 真名 → `/home/<acct>` |
| `.specs/health-fix-2026-09c/T04-SUMMARY.md` | 1 | 1 | `/home/⟨alice-doc⟩/x`（授权见 §4） |
| `.specs/health-fix-2026-09c/INDEPENDENT-REVIEW-2.md`（未跟踪） | 1 | 1 | `:233` 真名 → `/home/<acct>`（任务块 write_files 原列项；仅改磁盘，未 git add，理由见 §5） |
| **合计** | **45 行** | **51 处** | 11 个文件 |

只动命中字符串本身，行内其余内容未改（sed 精确串替换 + 编辑前后 grep 对账）。

## 3. 删除文件清单（用毕删除，含真名路径、无保留价值）

| 文件 | 性质 | 授权 |
|---|---|---|
| `.specs/health-fix-2026-09c/write-done-1.sh` | 阶段 1 一次性 .done 辅助脚本（.done 已落盘） | 任务块 write_files 原列 + 用毕删除 |
| `.specs/health-fix-2026-09c/write-done-2.sh` | 阶段 2 同性质 | 同上 |
| `.specs/health-fix-2026-09c/write-done-3.sh` | 阶段 3 同性质（.done-3 已落盘） | **任务块未列，本派发指令明示授权**（"3 号是同性质的阶段 3 辅助脚本"） |

三个脚本均为未跟踪文件，直接 `rm`，无 git 面影响。

## 4. 授权扩展登记（超出任务块冻结 write_files 的部分，出处=本派发指令）

1. `.specs/archive/2026-09-28-health-fix-2026-09b/INDEPENDENT-REVIEW-7.md`（4 行）——派发指令明示。
2. 同目录 `INDEPENDENT-REVIEW-3.md`（1 行）——派发指令明示。
3. 同目录 `T13-SUMMARY.md`（3 行）——派发指令明示。
4. `write-done-3.sh` 删除——派发指令明示。
5. `.specs/health-fix-2026-09c/T04-SUMMARY.md:21`（1 行合成示例）——不在任务块清单，但派发指令定调"以实跑门禁输出为准"+ verify ③ 门禁 rc=0 为完成判据，该行是 48 条命中之一，属 09c 收尾复扫处置面（能脱敏的脱敏）。
6. 对全部命中文件执行 `git add`（10 个已跟踪文件）——见 §5 偏差说明。

## 5. 偏差与说明

1. **命中数 48 ≠ 派发预告 47 ≠ 任务块旧文 30**：以实跑为准（派发指令明示）。47→48 的差异大概率来自预告统计未含 index 侧陈旧副本重复归因（4 行）或 09c T04-SUMMARY:21 的取舍；30 行口径只数磁盘真名行，与 AC-4 基线自洽。
2. **合成示例名不能走占位符表或允许清单**：门禁脚本 `PLACEHOLDER_NAMES` 注释明确禁止加 `test`（09b IR-3 裁决：夹具字面改不命中形态，禁入排除表）与 `alice`（09b IR-2 以其作真名漏报样例，入表即与该审查结论反向）；允许清单新增亦无授权且违背 fail-closed 纪律。故按脚本"下游误报处置②"就地改内容形态：`/home/⟨name⟩`。
3. **git add（未 commit）**：门禁内容面 = index∪磁盘并集，仅改磁盘不 add 则 index 陈旧副本仍判红（首跑 4 行重复归因即此机理）。`git add` 10 个已跟踪的编辑文件是 verify ③ 的必要条件；commit 仍为禁项，归波末编排者。
4. **09c INDEPENDENT-REVIEW-2.md 只改磁盘、未 add**：该文件未跟踪；若由本任务 add，会把 63KB 审查档首次纳入门禁扫描面，越权扩大验证面。真名已除（verify ② 过），入库时的门禁检查归波末编排者。波末风险已探测：09c 全目录（除 .done）PAT 复扫（排除占位符）= **0 命中**，入库面当前即净。
5. **`.l3-attempts-2`**：派发指令点名的可疑文件，实测内容仅 2 字节（"1"），无真名，未动。
6. **裸 GitHub 用户名（`github.com/<acct>/flow-kit` 等）不在处置面**：门禁 PAT 只认 `/home/` 前缀，verify ①②只 grep `$HOME` 字面；且 2026-06-22 安全审计（`.specs/archive/2026-06-22-security-privacy-audit/SECURITY-REPORT.md:181-185`）已裁决 GitHub 用户名属公开信息、保持现状风险可接受。未动。
7. **TDD 不适用**：纯文本字符串替换任务，无可执行行为面，无测试先行可言；质量保障 = 前后 grep 对账 + 门禁三段 verify。
8. **6 维自查简化为越界检查**（派发指令）：改动面 = 11 文件 45 行 51 处 + 3 删除 + git add 10 文件，全部落在 §4 授权面内；未 commit、未动 `.flow-active`、未动 TASK.md、未动任何 `.done`、未跑 make test-sync/check-test-sync。✔
9. **处置后门禁自证行**（终跑）："index 侧 21 条"为占位符表内命中（如 `/home/user` 等教程写法，按命中成分排除，非泄漏），"命中合计 0 条（含占位符排除后）"。

## 6. verify 三段真实输出（终态，逐字）

```text
$ test "$(git grep -lF "$HOME" | wc -l)" -eq 0; echo rc=$?
rc=0
```

```text
$ test "$(grep -rlF "$HOME" .specs/health-fix-2026-09c/ | grep -v '\.done$' | wc -l)" -eq 0; echo rc=$?
rc=0
```

```text
$ bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh; echo rc=$?
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*([^a-z0-9_-]|$)）
   扫描面: 工作树（git index：已 add / 已提交）
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   候选文件 1639 个
   实际扫描 1637 个
   自排除 2 个
   index 侧 21 条
   不可读候选 0 个
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
rc=0
```

三条全过。AC-4 达成：tracked 面真名 = 0，本 change 目录（即将入库面）真名 = 0，T04 版门禁全绿。
