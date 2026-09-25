# T-FIX-07 Summary — 隐私门禁三个假绿面（R3-1/R3-2/R3-30）+ 同文件 6 🟡 + R3-31

## 1. 任务

阶段 6 第 3 轮对抗式审计 🔴 R3-1/R3-2/R3-30（隐私门禁三个假绿面：引号化路径 / index×磁盘内容错位 / rev 模式同样假绿）+ 同文件 6 🟡（R3-3…R3-8）+ 🟡 R3-31（自证语义）。

修复 `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` 的枚举面（core.quotePath 引号化路径静默跳过）、内容面（工作树只读磁盘 ⇒ staged 泄漏+工作树改干净 ⇒ 假绿）、自证面（SCANNED_COUNT 先增后扫 ⇒ 无法区分被豁免与被漏扫），并收敛 6 条 🟡（清单键归一化 / 清理数组 / mktemp 登记 / rc 断言 / NUL 记录切分 / 注释口径统一）。

## 2. 提交

- **修复提交 sha**: `20847e10b614373823dcecbc4832dad2b0404658`
- **%cI**: `2026-09-25T14:07:09+08:00`
- **git show --stat**:
  ```
   flow-kit-bundle/flow-kit/reference/check-path-privacy.sh | 305 +++++++++++++++------
   1 file changed, 223 insertions(+), 82 deletions(-)
  ```
- **写回提交 sha**: 见本块末尾台账（单独一次提交）。

## 3. 改动文件与行数

| 文件 | 变化 |
|------|------|
| `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | +223/-82（594→722 行） |
| `test/test_path_privacy_gate.bats` | 未修改（既有 24 例全绿，无新增断言） |
| `.specs/STATE.md` | 未修改（bats 基线 1029 不变） |
| `dist/` | gitignored，已由 `package-dsh-plugin.sh` 重建 |

## 4. 红→绿证据

### RED（修复前）

verify 脚本 `/tmp/tfix7-verify.sh` 在修复前跑出 9 条 not-ok：

```
🔴 R3-1/R3-30：未见 NUL 安全读循环（grep 'read -r -d' 失败）
🔴 枚举未见 -z（git ls-files / git ls-tree 无 -z）
🔴 未见「不可读」自证字段
🔴 坏态① 非ASCII 名 rc=0（假绿）
🔴 坏态② staged-leak rc=0（假绿）
🔴 坏态③ rev+非ASCII rc=0（假绿）
🔴 坏态④ colon-name rc=0 或文件名切坏
🔴 坏态⑤ 不可读 rc=0（假绿）
🔴 好态① 缩进清单 rc=1（假红）
```

既有 bats 常设网：`1..24`，**23 ok / 1 not ok**（#20 `F5 好态：临时文件被清理` 失败 — R3-4 TMP_FILES 字符串词分裂）。

### GREEN（修复后）

verify 脚本 EXIT=0，全部断言通过：

```
   （诊断）坏态① 非ASCII 名 rc=1
   （诊断）坏态② staged-leak rc=1
   （诊断）坏态③ rev+非ASCII rc=1
   （诊断）坏态④ colon-name rc=1
   （诊断）坏态⑤ 不可读 rc=1
   （诊断）好态① 缩进清单 rc=0
   （诊断）好态② colon-clean rc=0
   （诊断）好态③ TMPDIR 含空格残留=0 件
bats: 1029 ok / 0 not-ok / count=1029
```

既有 bats 常设网：`1..24`，**24 ok / 0 not ok**。

## 5. 判据复跑（verify 原样完整输出）

```
   （诊断）坏态① 非ASCII 名 rc=1
   （诊断）坏态② staged-leak rc=1
   （诊断）坏态③ rev+非ASCII rc=1
   （诊断）坏态④ colon-name rc=1
   （诊断）坏态⑤ 不可读 rc=1
   （诊断）好态① 缩进清单 rc=0
   （诊断）好态② colon-clean rc=0
   （诊断）好态③ TMPDIR 含空格残留=0 件
bats: 1029 ok / 0 not-ok / count=1029
```

### make check-path-privacy（真实仓）

```
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/)
   扫描面: 工作树（git index：已 add / 已提交）
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   候选文件 1595 个
   实际扫描 1589 个
   index 侧 13 条
   不可读候选 0 个
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
```

### make check（总门禁）

```
✅ make check: 全部通过
```

含 check-path-privacy（绿）、check-nfr-portability（✅ 无 bash4-only / GNU-only）、check-hooks-sync（漂移 0）、check-test-sync（一致）、check-dist（一致）。

## 6. 残留与未验证

- **无残留**：所有 🔴（R3-1/R3-2/R3-30）+ 🟡（R3-3…R3-8 + R3-31）均已修复并通过 verify。
- **test_path_privacy_gate.bats 未新增断言**：既有 24 例（含 F1 坏态/F2 好态候选数/F5 静态）全绿，判别力基准不回退；verify 脚本的 8 个夹具态（5 坏态 + 3 好态）覆盖了 R3-1/R3-2/R3-30/R3-7/R3-3/R3-4 的双态判别。
- **bats 基线 1029 不变**：未新增/删除用例，STATE.md 无需更新。
- **core.quotePath 残留**：`.git/config` 的 `core.quotePath=false`（INDEPENDENT-REVIEW-6 ④ 疑早前调试所设）未触碰（L-161 禁改 .git/config）；修复后枚举改 -z + NUL 读循环，对 quotePath 不再依赖（无论 true/false 均 NUL 安全）。

## 7. 自查六维

| 维度 | 结论 |
|------|------|
| **R1 认知** | 任务边界 = T-FIX-07 块（R3-1/R3-2/R3-30 + R3-3…R3-8 + R3-31），未越界到 T-FIX-08（R3-14 pre-push/pre-commit）。用户 m00001 「R3-14」背景文字经 parent m00031 裁决为笔误，已忽略。 |
| **R2 变更传播** | 只改 `check-path-privacy.sh`（write_files ⊆ 契约）；test 文件未改（既有例全绿）；STATE.md 未改（计数不变）；dist gitignored。diff 边界 verify 通过。 |
| **R3 知识重复** | R6.4 grep 确认仓库内无既有 NUL-safe 抽象（`read -r -d` / `ls-files -z` 等 0 命中）→ 新构造授权（DESIGN 0.5）。 |
| **R4 偶然复杂** | `parse_grep_null` / `record_hit` / `register_tmp` 抽出为函数，避免内联重复；TMP_HITS 改 NUL 分隔避免 : 切坏。 |
| **R5 依赖混乱** | 无新增外部依赖；仅用 git/grep/sed/printf 内建 + bash 3.2 兼容构造（普通数组、while read -d ''，禁 mapfile/nameref）。 |
| **R6 领域扭曲** | 隐私门禁 fail-closed 语义不回退：F-19（M=0 && N>0 ⇒ exit 1）、F-20（mktemp return 1 + 调用点 || exit 1）、ADR-027 ②③ 均保持。NUL 安全是域内正确做法（git -z 输出本就是为路径安全设计）。 |

## 8. 关键技术发现

- **bash 命令替换剥 NUL**：`raw=$(git grep --null ...)` 丢失所有 NUL 字节 ⇒ 输出退化为无分隔符串。**必须**将 git grep --null 输出落临时文件，再 `parse_grep_null "$TMPFILE"`。
- **git grep --null 格式**：`<path>\0<line>\0<content>\n`（三条 NUL 分隔 path/line，换行分隔不同命中）；rev 模式前缀 `<rev>:<path>`，--cached 模式仅 `<path>`。经 `od -c` 实测确认。
- **git grep --cached 参数序**：`--cached` 必须在首个非选项参数（PAT）之前：`git grep --cached -naE --null "$PAT" -- "$file"`（错误序 `git grep -naE --cached "$PAT"` 会报 "选项 '--cached' 必须在其他非选项参数之前"）。
- **TMP_HITS 格式**：改 NUL 分隔三段 `<path>\0<line>\0<content>\0`，汇总循环 `while IFS= read -r -d '' f` 按 NUL 取字段，避免含 `:` 文件名被 `IFS=:` 切坏（R3-7 根因：旧 `IFS=: read -r f l c` 把 `docs/a:b.md:1:content` 切成 f=docs/a l=b.md ⇒ 不可归因 ⇒ 永久假红）。

## 台账（task_progress 五字段）

```json
{
  "id": "T-FIX-07",
  "commit_sha": "20847e10b614373823dcecbc4832dad2b0404658",
  "fix_rounds": 0,
  "deferred": [],
  "completed_at": "2026-09-25T14:07:25+08:00"
}
```

- **Δ = completed_at − %cI = 16 s ≤ 120 s** ✓
- **deferred = []**（ADR-015）✓
