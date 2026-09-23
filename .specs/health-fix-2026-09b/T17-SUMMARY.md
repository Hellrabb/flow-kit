# T17-SUMMARY · AC-6 门禁实现 `check-path-privacy.sh`

> 变更 `health-fix-2026-09b` 阶段 4（DEV）· Wave 3 · 2026-09-23
> 产物：`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（新增、可执行）
> 依 L-129：本 SUMMARY 所有本机绝对路径已 de-shape 为 `<repo>` / `$HOME` / `/home/<acct>/` 形态；rc、命令、输出文本与数字保持原样。

## 1 任务理解

实现 AC-6 的「前向脱敏有机器门禁」**可执行产物**（`check-path-privacy.sh`），覆盖：
- **PAT**（D10 定稿）：`/home/[a-z_][a-z0-9_-]*/` —— 本机绝对路径前缀。
- **通用占位符排除表**（`user` / `ubuntu` / `…`）：按「被匹配到的用户名成分」排除，**不按整行**（同行含占位符与真实路径时按行排除会漏报真实路径）。
- **自排除清单**：固定相对路径逐条精确（禁宽通配 `INDEPENDENT-REVIEW-*` / `reference/*` —— D10′② 实测通配吞掉 31 处 `<acct>` 字样含 10+ 真实账号路径，且永久无界）。
- **读序 R8**：常设路径 > change 副本 > 两者皆缺 ⇒ `exit 1` 并指名（fail-closed，**不得**当空清单放行）。
- **自证输出**：`允许清单 N 条` / `清单外命中 M 条` + `file:line` 归因；`M≠0` ⇒ 非零退出；退出码**二值 0/1**，无 SKIP（DESIGN §3 / ADR-028 决策 3）。
- **CHECK_REV 外部评估面**（L-131 · 主 agent 2026-09-23 追加）：非空时评估面切换为该 rev 的树，候选 `git ls-tree -r --name-only`，命中 `git grep -nE`，输出报 `扫描面: <rev>`；空时扫工作树、报 `扫描面: 工作树`。**注解 tag** 对象 sha 先经 `${CHECK_REV}^{commit}` 解析为 commit 再用（pre-push 对 tag 推送传入 tag 对象 sha，见 `flow-kit-bundle/hooks/pre-push/pre-push.sh:8-12`）；解析失败 ⇒ `exit 1` fail-closed。
- **bash 3.2 / macOS 兼容**：禁 `mapfile` / `declare -A` / `readlink -f|e` / `sed -i` / `grep -P`；`mktemp` + `trap` 清理临时文件。
- **判据兼容性 grep 是注释盲的**（L-125/L-128）：代码行不得出现禁用构造字面；注释里讨论这些构造不算违规（判据 `grep -vE '^[[:space:]]*#'` 剥整行注释后再匹配）。

## 2 边界复述

- **只产 1 件**：`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（可执行）。
- **不创建** `path-privacy-allowlist.txt`（T21 职责，本 task 只实现读取 + fail-closed）。
- **不改** `Makefile`（T18 职责）、**不改** `sync-hooks.sh`。
- **提交**：显式路径 `git add` + `git commit -- <paths>`；冻结集 6 文件（`.specs/adr/028*`、`.specs/health-fix-2026-09b/{CHANGE,REQUIREMENT,INDEPENDENT-REVIEW-1/2/3}.md`）已 staged、**不得夹带**、不得 `git reset` 撤出。
- `TASK.md` 只改 T17 状态行（`status="pending"`→`"done"`）。

## 3 改动（file:line 关键代码行原文）

### `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（新增，275 行）

**PAT 与占位符排除表（D10）**：
```bash
# flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:13-16
PAT='/home/[a-z_][a-z0-9_-]*/'
PLACEHOLDER_NAMES='user ubuntu acct yourname foo bar someone'
```
占位符按**用户名成分**判定（`is_placeholder_name` 逐成分比对，不按整行）：
```bash
# :118-126
is_placeholder_name() {
  local name="$1"
  local ph
  for ph in $PLACEHOLDER_NAMES; do
    [ "$name" = "$ph" ] && return 0
  done
  return 1
}
```

**自排除清单（逐条精确路径 · D8/D10′②）**：
```bash
# :30-37
SELF_EXCLUDE='
flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
.specs/health-fix-2026-09b/path-privacy-allowlist.txt
.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-1.md
.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-2.md
.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-3.md
'
```
后续阶段新增审查档时**显式追加精确路径**，禁改宽通配。

**读序 R8（fail-closed · 常设 > 副本 > 两者皆缺 ⇒ exit 1）**：
```bash
# :93-103
if [ -f "$ALLOWLIST_PERSISTENT" ]; then
  cp -- "$ALLOWLIST_PERSISTENT" "$TMP_ALLOWLIST"
  ALLOWLIST_SOURCE="$ALLOWLIST_PERSISTENT"
elif [ -f "$ALLOWLIST_CHANGE" ]; then
  cp -- "$ALLOWLIST_CHANGE" "$TMP_ALLOWLIST"
  ALLOWLIST_SOURCE="$ALLOWLIST_CHANGE"
else
  echo "🔴 允许清单缺失（fail-closed，不得当空清单放行）："
  echo "   常设路径: ${ALLOWLIST_PERSISTENT}"
  echo "   change 副本: ${ALLOWLIST_CHANGE}"
  echo "   扫描面: ${SCAN_SURFACE}"
  exit 1
fi
```

**CHECK_REV 解析（含注解 tag · 主 agent 追加）**：
```bash
# :75-82
RESOLVED_REV=$(git rev-parse --verify --quiet "${CHECK_REV}^{commit}" 2>/dev/null || true)
if [ -z "$RESOLVED_REV" ]; then
  echo "🔴 CHECK_REV 无法解析为 commit（fail-closed）：${CHECK_REV}"
  echo "   git rev-parse --verify --quiet '${CHECK_REV}^{commit}' 失败"
  echo "   扫描面: ${CHECK_REV}（未解析）"
  exit 1
fi
SCAN_SURFACE="$RESOLVED_REV"
```

**候选枚举与命中检索（双态：工作树 / rev）**：
```bash
# :111-118
if [ -n "$RESOLVED_REV" ]; then
  git ls-tree -r --name-only "$RESOLVED_REV" -- > "$TMP_CANDIDATES" 2>/dev/null
else
  git ls-files -- > "$TMP_CANDIDATES" 2>/dev/null
fi
```
rev 模式命中检索（剥 `<rev>:` 前缀再归因 · 夹具断言输出含 `leak.txt`）：
```bash
# :169-185
if [ -n "$RESOLVED_REV" ]; then
  local raw
  raw=$(git grep -nE "$PAT" "$RESOLVED_REV" -- "$file" 2>/dev/null || true)
  [ -z "$raw" ] && return 0
  printf '%s\n' "$raw" | while IFS= read -r hitline; do
    local stripped
    stripped="${hitline#"${RESOLVED_REV}:"}"
    local p l c
    p="${stripped%%:*}"
    local rest="${stripped#*:}"
    l="${rest%%:*}"
    c="${rest#*:}"
    uname=$(extract_username "$c")
    if [ -n "$uname" ] && is_placeholder_name "$uname"; then
      continue
    fi
    printf '%s:%s:%s\n' "$p" "$l" "$c" >> "$TMP_HITS"
  done
```

**自证输出与退出码（二值 0/1 · 无 SKIP）**：
```bash
# :258-275
echo "🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=${PAT}）"
echo "   扫描面: ${SCAN_SURFACE}"
echo "   允许清单来源: ${ALLOWLIST_SOURCE}"
echo "   允许清单 ${ALLOWLIST_COUNT} 条"
echo "   命中合计 ${HITS_TOTAL} 条（含占位符排除后）"
echo "   清单外命中 ${HITS_OUT_OF_ALLOWLIST} 条"
if [ "$HITS_OUT_OF_ALLOWLIST" -ne 0 ]; then
  echo "🔴 清单外命中 ${HITS_OUT_OF_ALLOWLIST} 条（非允许清单命中 ⇒ 阻塞，ADR-027 ②③ / ADR-028 决策 2）"
  exit 1
fi
echo "✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）"
exit 0
```

## 4 判别力与复原真实输出

原始脚本 sha256 = `ab34082e1f7d31fce7593b482828b7eddd9cf7313a4ec6db5fe344a65809f585`。三条针对性注入（L-132 定式：注入**真出口**、先验注入生效、对应断言变红、彻底复原）：

### 注入 1：fail-closed 真出口失效（L101 `exit 1`→`exit 0`）
- 注入：`sed -i '101s/  exit 1/  exit 0/'`（两者皆缺分支）。
- 注入后脚本自测（无 allowlist）：`rc=0`（原 `rc=1`）—— 注入命中真出口。
- verify 夹具对应断言变红：
  ```
  inject1 verify rc=1
  🔴 清单缺失态 rc=0 ≠ 1（fail-closed 未实现）
  ```
- 复原：`cp /tmp/t17_orig.sh`；`sha256sum` = `ab34082e…`（与原值一致）；`git diff -- <S>` 为空。

### 注入 2：rev 模式命中检索失效（L173 `git grep` PAT → `ZZZ_NOMATCH_INJECT2`）
- 注入：rev 模式 `git grep` 的 PAT 改为永不匹配字面。
- 注入后 verify 夹具对应断言变红（rev 模式扫不到历史树泄漏 → rc=0）：
  ```
  inject2b verify rc=1
  🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
     扫描面: <rev-sha>
     允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
     允许清单 0 条
     命中合计 0 条（含占位符排除后）
     清单外命中 0 条
  ✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
  🔴 CHECK_REV 漏检：仅存在于历史树里的泄漏未判红（rc=0）
  ```
- 复原：`sha256sum` = `ab34082e…`；`git diff` 为空。

### 注入 3：自排除含宽通配（L32 追加 `reference/*`）
- 注入：`SELF_EXCLUDE` 内将 `path-privacy-allowlist.txt` 改为 `reference/*`（D10′② 违规）。
- 注入后 verify 夹具对应断言变红：
  ```
  inject3 verify rc=1
  🔴 排除表含宽通配（禁；已剔除整行注释：脚本注释里写「不得用 reference/*」不算违规 —— L-125 族）
  ```
- 复原：`sha256sum` = `ab34082e…`；`git diff` 为空。

三条注入均命中**真出口**（非死代码）、对应断言变红、每次彻底复原（sha256 回原值 + git diff 空）。

## 5 门禁输出

| 门禁 | 命令 | 结果 |
|---|---|---|
| 单元测试 | `make test` | `ok 973 CF-03: clear_compliance_correction removes the file` / `✅ bats: all tests passed` / `rc=0`（973 ok / 0 not ok） |
| shellcheck | `make lint` | `✅ shellcheck: no errors found` / `rc=0`（含 `check-path-privacy.sh`，bash 3.2 兼容无 bash4/GNU-only） |
| hooks 同步 | `make check-hooks-sync` | `✅ hooks 副本一致（漂移 0）` / `rc=0` |
| hooks --check | `bash sync-hooks.sh --check` | `✅ hooks 副本一致（漂移 0）` / `rc=0` |
| T17 verify（工件原样抽取实跑） | `task-brief … T17 \| awk … \| bash` | `rc=0`（32 行判据全绿，见 §4） |

- `make check` / `make check-dist` 预期红（T24 收口）—— 不修、不据此判失败。
- `make check-path-privacy` 目标属 T18，此刻不存在 —— 不据此判失败。
- 全程未用 `--no-verify`。

## 6 六维自查

1. **判据触达缺陷现场**：CHECK_REV 双态夹具（历史树泄漏、工作树干净）真实触达 rev 模式检索与 fail-closed 解析分支；三条注入分别命中 fail-closed 出口、rev 检索出口、宽通配判定，对应断言变红。
2. **注释剥离口径统一**：脚本自排除清单与占位符表用代码行（非注释）；verify 判据 `grep -vE '^[[:space:]]*#'` 剥整行注释后再匹配禁用构造/宽通配（L-125/L-128）。
3. **二值退出码**：`exit 0`（清单外命中 0）/ `exit 1`（fail-closed / 清单外命中 ≠0）；无 SKIP 态（ADR-028 决策 3）。
4. **bash 3.2 兼容**：无 `mapfile`/`declare -A`/`readlink -f|e`/`sed -i`/`grep -P`（shellcheck + verify 双证）；`mktemp`+`trap` 清理临时文件；占位符判定用 `for … case` 而非关联数组。
5. **读序 fail-closed**：常设 > 副本 > 两者皆缺 ⇒ `exit 1` + 指名路径；不得当空清单放行（注入 1 证伪）。
6. **排除表完备性**：`.specs/health-fix-2026-09b/` 下实际存在的 3 份审查档逐条列在 `SELF_EXCLUDE`（verify L11-15 断言 `n_ir≥1` 且每份 `grep -qF` 命中）。

## 7 TDD 声明

判据（T17 `<verify>` 32 行）**由主 agent 2026-09-23 定稿并写入 `TASK.md` 工件本体**（L-128：判据权威副本 = 工件原文）。本执行者：
- 从工件**原样抽取**实跑（`task-brief` awk 行级锚定，L-125），`rc=0`；
- 三条判别力注入均先验注入生效（脚本自测 rc 变化）再验断言变红（L-132）；
- 未删任何断言换绿；未发现夹具未达缺陷位的情形。

## 8 遗留

- **无**遗留：`path-privacy-allowlist.txt` 由 T21 创建；`make check-path-privacy` 接线由 T18；pre-commit 源接线由 T20；pre-push 拦截器（T19）将逐 ref 传 `<local sha>` 给 `CHECK_REV` —— 本 task 已提供该入口（含注解 tag 解析）。
- **注解 tag 解析**（主 agent 追加要求）：实现见 §3 `RESOLVED_REV=$(git rev-parse --verify --quiet "${CHECK_REV}^{commit}" …)`；解析失败 fail-closed；下游 `ls-tree`/`grep`/`扫描面` 报告一律用解析后 commit sha。

---

## 9 修复轮（2026-09-23 · L-133 排除粒度）

### 缺陷
主 agent 独立探针发现**漏报**（file:line：`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:162` 旧 `extract_username` + `:186-189` 旧 `continue`）：`extract_username` 用**贪婪** `sed`（`s#.*/home/([a-z_][a-z0-9_-]*)/.*#\1#p`）⇒ 一行只取**最后一个** `/home/<name>/`；再据此**单一**成分决定是否 `continue` ⇒ **整行**跳过。同行「真名在前、占位在后」时真名被整行放过（D10′② 漏报类）。已登记 `.specs/LESSONS.md` **L-133** 与 `MINOR-DEFERRED.md`。

### 四项对照实测（主 agent 独立夹具，非复述第一轮证据）
| 夹具行内容 | 期望 | 第一轮实测 | 修复后实测 |
|---|---|---|---|
| `mixed /home/<real>/x /home/user/y`（真名在前、占位在后） | rc=1 | **rc=0 / `清单外命中 0 条` ⇒ 漏报** | **rc=1** ✓（归因含 `mixed.txt`） |
| `B /home/user/y /home/<real>/x`（顺序对调） | rc=1 | rc=1 ✓ | rc=1 ✓ |
| `C /home/user/y`（仅占位） | rc=0 | rc=0 ✓ | rc=0 ✓ |
| `D /home/<real>/x /home/<real>/y`（两个真名） | rc=1 | rc=1 ✓ | rc=1 ✓ |

⇒ 第一轮结论随**行内顺序**翻转；修复后四项全对。

### 修复实现
新增 `line_all_hits_placeholder`（逐命中判定，替换旧 `extract_username` + 单成分 `continue`）：
```bash
# flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:170-194（修复后）
line_all_hits_placeholder() {
  local content="$1"
  local hits any_real=0
  hits=$(printf '%s\n' "$content" | grep -oE "$PAT" 2>/dev/null || true)
  [ -z "$hits" ] && return 1   # 无命中 ⇒ 不跳过
  local h uname
  while IFS= read -r h; do
    [ -z "$h" ] && continue
    uname=$(printf '%s\n' "$h" | sed -nE 's#^/home/([a-z_][a-z0-9_-]*)/$#\1#p')
    if [ -z "$uname" ] || ! is_placeholder_name "$uname"; then
      any_real=1
      break
    fi
  done <<EOF
$hits
EOF
  [ "$any_real" -eq 0 ]
}
```
两处调用点（rev 模式 `:212`、工作树模式 `:230`）改为 `if line_all_hits_placeholder "$c"; then continue; fi` —— 仅当该行**全部**命中都是占位符才跳过，否则按 `file:line` 记命中。bash 3.2 兼容（`grep -oE`、here-doc、无 `mapfile`/`declare -A`）。

### 新旧 sha256
| 版本 | sha256 |
|---|---|
| 第一轮（缺陷版，HEAD `e4dd4f8`） | `ab34082e1f7d31fce7593b482828b7eddd9cf7313a4ec6db5fe344a65809f585` |
| 修复轮（本提交） | `2d424d5af619fb311f60be748baf542a89d1bb59cfcfcd51282a55f02d8f66da` |

### 判别力注入与复原证据（L-132 · 命中真出口）
- **注入**：把 `line_all_hits_placeholder` 函数体退回旧单成分判定（`sed` 取首/末命中 + `is_placeholder_name` 决定整行跳过）。
- **注入后脚本自测**（`mixed.txt` 夹具）：`rc=0` / `命中合计 0` / `清单外命中 0 条` ⇒ 漏报复现（注入生效，命中 buggy 真出口）。
- **verify 夹具对应断言变红**：
  ```
  injected verify rc=1
  🔍 … 命中合计 0 … 清单外命中 0 条
  ✅ 清单外命中 0 条（…）
  🔴 同真名+占位同行被整行放过（排除粒度 ≠ 命中粒度 · L-133）
  ```
- **复原**：`cp /tmp/t17_fix.sh`；`sha256sum` = `2d424d5a…`（与修复值一致）。

### 工件判据原样抽取实跑
`task-brief … T17 | awk … | bash`（49 行，含 L33-49 排除粒度判别子）⇒ **rc=0**。

### 门禁输出
| 门禁 | 命令 | 结果 |
|---|---|---|
| 单元测试 | `make test` | 973 ok / 0 not ok / rc=0 |
| shellcheck | `make lint` | `✅ shellcheck: no errors found` / rc=0 |
| hooks 同步 | `make check-hooks-sync` | `✅ hooks 副本一致（漂移 0）` / rc=0 |
| hooks --check | `bash sync-hooks.sh --check` | `✅ hooks 副本一致（漂移 0）` / rc=0 |

### 取证（第 5 条 · 临时空清单下 M 与归因全集）
- 临时建空文件 `.specs/health-fix-2026-09b/path-privacy-allowlist.txt`（`允许清单 0 条`）⇒ 跑 `bash …/check-path-privacy.sh` ⇒ **`M=0` / `清单外命中 0 条` / rc=0**。即 T13 脱敏后工作树基线干净，**无此前被整行跳过而新浮现的命中**（修复改的是「同行多命中」判定逻辑，不改变单命中行的归因）。
- 旁证（临时 in-repo tracked 泄漏 `_t17_probe_leak.txt:1: leak probe /home/<acct>/secret`）⇒ `rc=1` / `命中合计 1 条` / `清单外命中 1 条` / 归因 `_t17_probe_leak.txt:1: …` —— 逐命中判定确实抓住真名。
- 取证后删除临时文件：`git status --short` 仅余冻结集 6 `A ` + 脚本 ` M`（无 `path-privacy-allowlist.txt` 残留，属 T21 产物）。

### 第一轮三条注入为何没抓到它
第一轮三条注入（fail-closed 出口 / rev 检索 / 宽通配）**均不涉及「一行多命中」维度**（L-122 族：判据没打到缺陷现场）。verify 夹具的命中行都是**单命中**形态（`leak.txt:1`、`/home/<real>/x`），从未构造「真名 + 占位同行」⇒ 单成分判定对单命中行行为正确，bug 被夹具形态掩盖。主 agent 补强的 L33-49 判别子正是补上这个维度。
