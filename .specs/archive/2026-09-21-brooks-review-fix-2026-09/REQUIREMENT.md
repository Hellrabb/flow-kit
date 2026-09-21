# REQUIREMENT: 修掉「门禁守卫自身」的三处假绿（+ 三处可维护性）

- **Change ID**: brooks-review-fix-2026-09
- **关联**: `@.specs/brooks-review-fix-2026-09/CHANGE.md`、brooks-review 报告 `@.specs/health/2026-09-21-BROOKS-REVIEW.md`、修复记录 `@.specs/health/2026-09-21-BROOKS-REVIEW-FIXES.md`

---

## 背景（一句话）

独立复核（`brooks-review`）发现：刚交付的门禁守卫自身有**三处假绿** —— 工件解析会核错 change、
新门禁无行为级回归保护、打包映射缺失语义与打包侧相反；本 change 逐条修掉并给出**修复前失败 / 修复后通过**的双向取证。

## 用户故事

- **US-1**（维护者）：作为维护者，我跑 `make verify-claims` 时，希望**知道它到底核了哪个 change** —— 核不到就明说"未核对"，而不是拿另一个 change 的工件给我 ✅。
- **US-2**（维护者）：作为维护者，我希望新装的 `check-dist` / 真入口判据在**任何一次 `make test`** 里被真跑验证，而不是只有一份随 change 归档冻结的夹具。
- **US-3**（维护者）：作为维护者，我希望"打包映射"只有一份，且"源缺失"在打包与检查两侧语义一致 —— 否则门禁会在最该报警时给 ✅。

## 验收准则（AC）

> 每条 AC 均含「**修复前实测行为**」（L-090：AC 必须在写需求时证明它当前是失败的）与可复制执行的验证段。

### AC-1 · 无活跃 change 时，工件断言**显式声明未核对**，且不得核任何别的 change（对应 US-1）

- **Given**：仓库无 `.flow-active`（或未传 `<change-id>`）
- **When**：`bash verify-claims.sh`
- **Then**：§8 / §9 / §10c 三行输出以 `⏭` 开头且文案含"未指定 change"；**输出中不出现** `l3-review-defects-2026-09`；退出码 0。

**修复前实测行为**：`resolve_spec_artifact DESIGN.md` → `.specs/archive/2026-09-18-l3-review-defects-2026-09/DESIGN.md`（**rc=0**），
§8/§9/§10c 据此输出 ✅（且文案不含 change id）→ 核的是**另一个 change**。

```bash
# AC-1 验证（可复制执行 · 注意：脚本内部含 make check，单次约 4 分钟）
out=$(bash verify-claims.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL: 退出码 $rc"; exit 1; }
[ "$(printf '%s' "$out" | grep -c '⏭')" -ge 3 ] || { echo "FAIL: SKIP 行 < 3"; exit 1; }
printf '%s' "$out" | grep -q 'l3-review-defects-2026-09' && { echo "FAIL: 仍在核别的 change"; exit 1; }
# 三态之三：指定了但找不到 → 必须 FAIL（非静默回退）
bash verify-claims.sh ghost-change-2099 >/dev/null 2>&1; [ $? -ne 0 ] || { echo "FAIL: ghost id 未 FAIL"; exit 1; }
# 三态之二：指定已归档的真 change → 必须解析到它自己的工件
bash verify-claims.sh health-fix-2026-09 2>&1 | grep -q '.specs/archive/2026-09-21-health-fix-2026-09/DESIGN.md' \
  || { echo "FAIL: 未解析到目标 change 的工件"; exit 1; }
echo "AC-1 PASS"
```

### AC-2 · 新门禁的行为级回归保护在 `make test` 里可被复算（对应 US-2）

- **Given**：`test/` 与 `flow-kit-bundle/test/` 双源一致
- **When**：`npx bats test/test_gate_freshness.bats`
- **Then**：14 例全绿；且其中至少 8 例是**真跑命令看退出码/输出**（陈旧 dist → rc=1 且指名；源目录缺失 → rc=1；`--entry-class` 分类正确；拼错前缀 → rc=2；坏 `<base-ref>` → rc=2）。

**修复前实测行为**：两侧各 70 个 `.bats` 中 `grep -rl "package-dsh-plugin\|check-dist\|sync-hooks.sh --check"` = **0 命中**；
唯一跨归档存活的 §10d ②④ 是**源码文本 grep** —— 实测"只有 `is_real_entry()` 定义、无任何调用点"的文件同样判通过（rc=0，假绿）。

```bash
# AC-2 验证
npx bats test/test_gate_freshness.bats 2>&1 | tail -3   # 期望 ok 1..14
# 行为判据在位（§10d 走自检出口，不再 grep 源码文本）
grep -q -- '--entry-class' verify-claims.sh || { echo "FAIL: 行为判据缺失"; exit 1; }
# 文本判据不得复活（负向断言 · **必须排除注释行** —— 弃用说明注释里保留着旧判据原文；
# 用 `>/dev/null` 而非 `-q`：本仓 `set -o pipefail` 下 `grep -q` 命中即退会给上游发 SIGPIPE → 假失败 L-024）
grep -v '^[[:space:]]*#' verify-claims.sh | grep -E "grep -qE '\^\[\[:space:\]\]\*is_real_entry" >/dev/null && { echo "FAIL: 文本判据复活"; exit 1; }
echo "AC-2 PASS"
```

### AC-3 · 打包映射单一化，且"源缺失"在打包与检查两侧语义一致（对应 US-3）

- **Given**：夹具内 `dist` 由打包脚本正常生成（基线 rc=0）
- **When**：移走任一**必需**源目录（如 `dsh-flow-kit/lib`）后再 `--check`
- **Then**：rc=1，输出含"源目录缺失"，且指明 dist 侧仍有旧副本；还原后 rc=0。

**修复前实测行为**（HEAD 版脚本 + 同款夹具）：移走 `dsh-flow-kit/lib` → **`✅ check-dist: dist 与源一致` rc=0**（假绿），
`dist/dsh-flow-kit/lib/a.js` 陈旧树仍在 —— 因为该映射对命中 `[ -d "$src" ] || continue` 整对跳过（连同反向残留检查）。

```bash
# AC-3 验证（真跑在夹具上，不碰仓库工作区 —— 用例即 test/test_gate_freshness.bats 的 3/4/7）
npx bats test/test_gate_freshness.bats --filter "必需源目录" 2>&1 | tail -2
npx bats test/test_gate_freshness.bats --filter "反向残留"   2>&1 | tail -2
# 单一映射（结构断言）：COPY_DIRS 只被"打包循环"与"检查循环"各读一次
[ "$(grep -c 'COPY_DIRS\[@\]' package-dsh-plugin.sh)" -eq 2 ] || { echo "FAIL: 映射不再单一"; exit 1; }
# 产物等价（重构不改产物）：重构后立即重建的整树哈希 = 重构前基线
bash package-dsh-plugin.sh >/dev/null && bash package-dsh-plugin.sh --check
echo "AC-3 PASS"
```

### AC-4 · 同一理由不再被写两遍（对应 🟢1）

```bash
[ "$(grep -c 'dist/ 被 .gitignore 忽略' Makefile)" -eq 1 ] || { echo "FAIL: Makefile 重复"; exit 1; }
[ "$(grep -c '10c. DESIGN §0.5.1 覆盖全部被改文件' verify-claims.sh)" -eq 1 ] || { echo "FAIL: §10c 标题重复"; exit 1; }
echo "AC-4 PASS"
```

**修复前实测行为**：`Makefile:113-114` 两行连续注释同义；`verify-claims.sh:189-190` 两行**逐字相同**。

### AC-5 · 真入口判据可被外部直调，分类正确（对应 🟢2）

```bash
# AC-5 验证
check(){ bash sync-hooks.sh --entry-class "$1" >/dev/null 2>&1; [ $? -eq "$2" ] || { echo "FAIL: $1 期望 rc=$2 实得 $?"; exit 1; }; }
check pre-tool-use/independent-review-gate.sh 0
check stop/00-gate.sh 0
check pre-tool-use/gate-helpers.sh 1
check stop/lib/common.sh 1
bash sync-hooks.sh --entry-class >/dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL: 缺参数未 fail-closed"; exit 1; }
echo "AC-5 PASS"
```

**修复前实测行为**：判据定义在 `for root in DEST_ROOTS`（7 次迭代）循环体内，外部无法直调，只能 grep 源码文本；
`--entry-class` 不存在（未知参数 → rc=2）。

### AC-6 · `_changed` 不再叠三条 git 命令，rename 不取旧名（对应 🟢3）

```bash
# AC-6 验证：旧命令组合不得存在（**排除注释行** —— 弃用说明注释里保留着旧取法原文）；正向取集可复算
grep -v '^[[:space:]]*#' verify-claims.sh | grep -E 'git status --short.*awk' >/dev/null && { echo "FAIL: 旧的 status+awk 取法仍在"; exit 1; }
grep -q 'git ls-files --others --exclude-standard' verify-claims.sh || { echo "FAIL: 未跟踪文件取法缺失"; exit 1; }
B=6e8468e^; n=$({ git diff --name-only "$B" HEAD; git diff --name-only HEAD; git ls-files --others --exclude-standard; } \
  | grep -E '\.(sh|bats)$|Makefile$' | grep -vE '^\.specs/' | sort -u | wc -l)
[ "$n" -ge 5 ] || { echo "FAIL: 改动集异常（$n）"; exit 1; }
echo "AC-6 PASS"
```

**修复前实测行为**：`git diff --name-only HEAD` 已含 staged+unstaged，其后又叠 `--cached` 与
`git status --short | awk '{print $2}'`（同一信息三遍）；rename 行 `R  old -> new` 取 `$2` = **旧名**。

### AC-7 · 全量门禁不退化（承重 AC）

- **Given**：`dist` 与源一致、双源 test 已同步
- **When**：`make check`
- **Then**：6 门全绿；bats **964 ok / 0 not ok**（基线 950 + 本 change 新增 12）；`bash verify-claims.sh` exit 0 且 ❌=0。

```bash
# AC-7 验证
make check || { echo "FAIL: make check 未通过"; exit 1; }
bash verify-claims.sh >/tmp/ac7_vc.log 2>&1; rc=$?
grep -E '复验结果' /tmp/ac7_vc.log
[ "$rc" -eq 0 ] || { echo "FAIL: verify-claims rc=$rc"; exit 1; }
grep -q '❌ [1-9]' /tmp/ac7_vc.log && { echo "FAIL: 存在 ❌"; exit 1; }
echo "AC-7 PASS"
```

**修复前实测行为**（同 change 未修时）：`make check` 4m03s 全绿但 bats 950、新门禁 0 覆盖；
`bash verify-claims.sh` 的 §8/§9/§10c 核的是 l3-review-defects 的工件（见 AC-1）。

## 范围切分

### v1（本次必做）

AC-1 … AC-7（六处修复 + 全量门禁不退化）。

### v2（下一轮考虑，不本次）

- 把 `DESIGN §0.5.1` 的"被改文件契约"做成可解析结构（YAML front-matter），使 §10c 双向可核（防"清单漏项"与"清单虚列"）
- `check-dist` 增加"映射自检"：从打包步骤的实际 `cp` 调用反推映射，与 `COPY_*` 表比对（彻底消除信息泄漏）

### out（永远不做）

- ❌ 把 `verify-claims.sh` 改成通用断言 DSL / 插件化（收益不明，维护成本确定）
- ❌ 为 `--check` 增加自动重建或写入能力（破坏只读契约）

## 非功能性需求

- **性能**：`check-dist` 仍 ≤2s（实测 0.60s）；新增 14 例 bats 的单次运行 ≤30s（夹具为最小树，实测 ~10s）
- **只读性**：`package-dsh-plugin.sh --check`、`sync-hooks.sh --check`、`sync-hooks.sh --entry-class` 三个模式**零写盘**
- **可复算**：所有 AC 的验证命令可原地复制执行，不依赖人工判断
- **兼容性**：`.brooks-lint-history.json` / 归档夹具 `ac7.sh` 的既有解析不受 `⏭` 追加影响（正则非锚定）

## 依赖与假设

- 假设 1：`node` 与 `npx bats` 在开发机可用（既有前提，本 change 不新增依赖）
- 假设 2：`git` 可用（`§10c` 依赖 `git diff` / `git ls-files`，既有前提）
- 假设 3：`.flow-active` 由 flow-kit 维护（本 change 自身即在该状态下开发）
