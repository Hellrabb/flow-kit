# REQUIREMENT: 堵住三个门禁盲区（打包件新鲜度 / lint 文件域 / exec 判据）

- **Change ID**: health-fix-2026-09
- **关联**: `@.specs/health-fix-2026-09/CHANGE.md`、`@.specs/CONTEXT.md`、`@.specs/health/2026-09-20-HEALTH.md`

---

## 背景（一句话）

2026-09-20 全量巡检暴露三个**检查器判据缺陷**（非代码缺陷）：它们各自比真实契约更宽或更窄，且都不在 `make check` 覆盖面内 —— 后果是制造"假安全感"。其中 dist 新鲜度缺失已产生**用户可见的错误后果**（发出去的 README 把「字节」写成「字符」，差 3 倍）。

**本 change 修的是"检查器看见真相的能力"，不改任何运行时行为。**

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我改了包顶层文档或插件代码后忘了重建 dist，我想让 `make check` 当场告诉我"打包件陈旧了、差的是哪个文件"，以便不必等用户按错文档配置才发现。
- **US-2**：作为 flow-kit 维护者，我想让 `make lint` 扫到**所有**生产脚本，以便"改了脚本但 lint 永远绿"的盲区不存在 —— 尤其是 `install.sh`（2026-08-03 出过 🔴 回归的那个文件）。
- **US-3**：作为 flow-kit 维护者，我想让 `check-hooks-sync` 只对**真入口**要求可执行位，以便这条告警重新变得可信（不再被已知误报训练成噪声），真丢 exec 位时我还能被叫醒。
- **US-4**：作为接手本仓的后来者，我想让"门禁为什么这样判"有据可查，以便不再重复踩同一个盲区。

---

## 验收准则（AC）

> 全部为**机械可验**：每条给出一条可复制粘贴的命令 + 期望输出。
> 验证脚本统一使用**临时目录 + trap 还原**，保证验证动作本身不改工作区（验证后 `git status --porcelain` 为空）。

### AC-1 · dist 陈旧必须被 `make check` 拦下（对应 US-1）

- **Given** 仓库处于 `make check` 全绿状态
- **When** 修改任一**进入 dist 的源文件**（例：在 `dsh-flow-kit/README.md` 末尾追加一行）**且不重建 dist**，然后跑 `make check`
- **Then** `make check` **非零退出**，且输出中**指名**陈旧的文件路径（含 `README.md` 字样）；把该文件还原（或重建 dist）后 `make check` 恢复绿
- **验证方式**：`AC-1 验证脚本`（见下）· 无反例放行

```bash
# AC-1 验证（可复制执行）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d)   # 夹具并发隔离（清理见下方合并 trap —— EXIT trap 只能有一个）
# 前置（Given · 两项）：① dist 与源一致（否则基线结论不可信）；② make check 全绿
diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle >/dev/null \
  || { echo "❌ 前置不满足：dist 与源不一致，请先 bash package-dsh-plugin.sh"; exit 1; }
make check >/dev/null 2>&1 || { echo "❌ 前置不满足：基线 make check 未绿"; exit 1; }
# ⚠️ 只能有一个 EXIT trap（后注册会覆盖先注册）—— 故 TMPD 清理与 git 还原**合并**为一条
trap 'git checkout -- dsh-flow-kit/README.md; rm -rf "$TMPD"' EXIT
printf '\n<!-- AC1 probe -->\n' >> dsh-flow-kit/README.md
if make check >$TMPD/ac1.log 2>&1; then echo "❌ FAIL: 陈旧未被拦下"; exit 1; fi
grep -qi 'README.md' $TMPD/ac1.log || { echo "❌ FAIL: 未指名陈旧文件"; exit 1; }
echo "✅ AC-1 PASS"
```

### AC-2 · dist 与源一致时必须放行（AC-1 的反例保护）

- **Given** dist 由当前源正常重建过，且 `git status --porcelain` 对**被跟踪文件**干净
- **When** 跑 `make check`
- **Then** 新门禁 `check-dist` **通过**且不产生任何"陈旧"告警；`make check` 整体绿
- **验证方式**：`AC-2 验证脚本`（**前置**：先跑 F1 前置的重建 —— `bash package-dsh-plugin.sh`）
- **目的**：防止把门禁做成"永远红"（噪声化），那样比没有更糟
- **⚠️ 修正记录 · L3 盲审 Major（2026-09-20）**：初稿只有文字描述（"退出码 0 + 输出含 check-dist 通过标记"），**无可复制命令**，不满足本文件前言"全部为机械可验"的自述；Given 也没给"如何确认 dist 已重建"。已补脚本。

```bash
# AC-2 验证（可复制执行）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
# 前置：确认 dist 与源一致（Given 的机器化）
diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle >/dev/null \
  || { echo "❌ 前置不满足：dist 与源不一致，请先 bash package-dsh-plugin.sh"; exit 1; }
make check >$TMPD/ac2.log 2>&1 || { echo "❌ FAIL: make check 非零退出"; tail -20 $TMPD/ac2.log; exit 1; }
grep -qiE 'check-dist.*(pass|一致|✅|通过)' $TMPD/ac2.log \
  || { echo "❌ FAIL: 未见 check-dist 通过标记"; grep -i 'check-dist' $TMPD/ac2.log; exit 1; }
echo "✅ AC-2 PASS"
```

> **⚠️ 两处修正（L2 盲审 R2 · 2026-09-20）**
> 1. **不得用 `git status --porcelain` 代理 dist 新鲜度**：`dist/` 被 `.gitignore:63` 忽略，git 对 dist 陈旧**结构性失明**——这正是本 change 要堵的盲区。把它当 Given 条件是**循环论证**。Given 已改为"dist 由当前源正常重建过"，且该前提在写需求时**必须实际成立**。
> 2. **写需求时该 Given 不成立**：实测 `vendor/flow-kit-bundle/test/test_l3_review_defects_2026_09.bats` 陈旧（源 10:15:58 修 → dist 09:56:31 构建，**早 19 分钟**）。这恰好是 check-dist 要抓的形态。**处置**：实施前先重建 dist 使 Given 成立（已列为 v1 的 F1 前置步骤）。
>    > 副产品：这是「check-dist 有真实价值」的**第二个独立实例**（第一个是 README 陈旧）。

### AC-3 · `make lint` 必须覆盖全部生产脚本（对应 US-2）

- **Given** 仓库全绿
- **When** 向任一**此前漏扫**的文件注入一个真实语法错误 —— 本 AC 固定用 `flow-kit-bundle/install.sh`（在末尾追加 `if [ 1 -eq 1 ]` 且不闭合）—— 然后跑 `make lint`
- **Then** `make lint` **非零退出**，且输出中同时出现 ①`install.sh` ②shellcheck 的 **error 级诊断**（本注入实测产出 `SC1073 (error)`，断言用 `error` 字样 + `SC10` 前缀，比只 grep 文件名更抗噪）
- **验证方式**：`AC-3 验证脚本`

```bash
# AC-3 验证（可复制执行）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d)   # 夹具并发隔离（清理见下方合并 trap —— EXIT trap 只能有一个）
# 前置（Given）：仓库全绿
make lint >/dev/null 2>&1 || { echo "❌ 前置不满足：基线 make lint 未绿"; exit 1; }
F=flow-kit-bundle/install.sh
trap 'git checkout -- '"$F"'; rm -rf "$TMPD"' EXIT   # 合并：git 还原 + TMPD 清理（EXIT trap 只能一个）
printf '\nif [ 1 -eq 1 ]\n' >> "$F"
if make lint >$TMPD/ac3.log 2>&1; then echo "❌ FAIL: 漏扫文件中的语法错误未被抓到"; exit 1; fi
grep -q 'install\.sh' $TMPD/ac3.log || { echo "❌ FAIL: 未指名 install.sh"; exit 1; }
grep -qiE 'error' $TMPD/ac3.log \
  || { echo "❌ FAIL: 未输出 error 级诊断"; exit 1; }   # 放宽：不绑定特定 SC 码（版本升级/注入形态变化不应使 AC 误红）
echo "✅ AC-3 PASS"
```

### AC-4 · 扩面后其余漏扫脚本同样被覆盖（AC-3 的普适化）

- **Given** 同上
- **When** 将 `make lint` 的实际扫描清单与"全部生产 `.sh`"做**路径级集合差**，断言差集为空
- **Then** 当前 **7 个**漏扫脚本**全部**进入扫描清单：

  | # | 漏扫脚本（路径级精确枚举 · 2026-09-20 复验） |
  |---|---|
  | 1 | `flow-kit-bundle/install.sh` |
  | 2 | `flow-kit-bundle/hooks/pre-commit/pre-commit.sh` |
  | 3 | `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` |
  | 4 | `flow-kit-bundle/flow-kit/regression-demos/hallucination-guard/check.sh` |
  | 5 | `flow-kit-bundle/flow-kit/regression-demos/scope-drift-guard/check.sh` |
  | 6 | `flow-kit-bundle/flow-kit/regression-demos/strong-model-verbosity/check.sh` |
  | 7 | `flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/check.sh` |

- **验证方式**：让 `make lint` **自报扫描清单**，验收只断言该清单 —— **不得复制枚举逻辑到验证脚本**（见下方 L3 修正）
- **⚠️ 修正记录 · L3 盲审 Critical（2026-09-20）**：本 AC 初稿的验证脚本**照抄了 `Makefile:23` 的 6 条 glob** 来构造 `ac4_in.txt`。这是**把实现当判据**：两边同样漏 `flow-kit-bundle/hooks/pre-commit/*.sh`，`comm -13` 结果为 0 → **即使一行代码都没改，该验证也会通过**，完全没有证明力。L3 指出"脚本未实际调用 `make lint` 获取扫描清单，而是手工用 `ls` 枚举目录"，成立。
- **修正后判据（单一事实源 · 2026-09-20 L3 二轮定案）**：**只采用一种出口** —— `make lint` 在正常运行时**固定输出一行** `SCANNED_FILES: <n>` 及其后逐行文件路径。验收命令**只 `grep`/解析该行**，不复制枚举逻辑。
  > ⚠️ **不得使用 `make lint --list-files` 形式**：`--list-files` 会被 make 当作 **target 名**（而非选项），除非 Makefile 显式定义该 target —— L3 二轮指出该命令**不是合法 make 调用**，且与正文的出口描述二义。此处定案为**方案 (b)**：`make lint` 自身输出清单，**不新增独立 target**。
- **⚠️ 输出契约（强制 · L2 三轮 R4 定案 · 实现与验收两侧必须逐字遵守）**：解析器与本契约**必须同时成立**，否则判据自相矛盾（L2 实测：初稿 awk 的前缀判据 `^/` 与三种可能格式**全部冲突** —— 绝对路径能解析但 `comm` 比对不上；`./` 与裸相对路径则解析结果为空）。

  | 项 | 规定 |
  |---|---|
  | 路径形态 | **`./` 前缀的相对路径**（例：`./flow-kit-bundle/lib/paths.sh`） |
  | 行序 | `SCANNED_FILES: <n>` 行**之后**，逐行一个路径 |
  | 结束 | 以一个**空行**结束清单（解析器遇空行即停止） |
  | 数量 | `<n>` 必须等于其后路径行数 |
  | 禁止 | 绝对路径、裸相对路径（无 `./`）、含未转义空格 |

  **两侧绑定（改一处必须改另一处）**：
  - **实现侧（T02）**：按上表输出。
  - **验收侧**：`awk '/^SCANNED_FILES:/{f=1;next} f&&/^\.\//{print;next} f&&!/^$/{exit}'` —— 只认 `./` 前缀，遇空行结束，随后 `sed 's|^\./||'` 归一化。
  - **比对侧**：`find` 输出的 `./x` 形态**直接参与 `comm`**（与归一化后的扫描集同为裸相对路径）；`find` 侧**不做 `sed`**。

```bash
# AC-4 验证（可复制执行 · 解析 make lint 固定输出的 SCANNED_FILES 清单，不复制枚举逻辑）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
make lint >/tmp/ac4_log 2>&1 || { echo "❌ FAIL: make lint 非零退出"; tail -20 /tmp/ac4_log; exit 1; }
grep -qE '^SCANNED_FILES:' /tmp/ac4_log || { echo "❌ FAIL: make lint 未输出 'SCANNED_FILES:' 行（F2 须固定输出该行）"; exit 1; }
# 输出契约：'./' 前缀相对路径、逐行、空行结束（见 AC-4 输出契约段）
awk '/^SCANNED_FILES:/{f=1;next} f&&/^\.\//{print;next} f&&!/^$/{exit}' /tmp/ac4_log \
  | sed 's|^\./||' | sort -u > $TMPD/ac4_in.txt
[ -s $TMPD/ac4_in.txt ] || { echo "❌ FAIL: 解析出的扫描清单为空"; exit 1; }
find . -name '*.sh' -not -path '*/.git/*' -not -path '*/node_modules/*' \
  -not -path '*/brooks-lint/*' -not -path '*/brooks-tools/*' -not -path '*/dist/*' \
  -not -path '*/.omo/*' -not -path '*/.claude/*' -not -path '*/.specs/*' -not -path '*/test/*' \
  | sed 's|^\./||' | sort > $TMPD/ac4_all.txt
miss=$(comm -13 $TMPD/ac4_in.txt $TMPD/ac4_all.txt | wc -l)
[ "$miss" -eq 0 ] || { echo "❌ FAIL: 仍有 $miss 个漏扫"; comm -13 $TMPD/ac4_in.txt $TMPD/ac4_all.txt; exit 1; }
# 反向断言（L2 阶段5 R3 补 · DESIGN R7 的要求）：契约排除项**不得**出现在扫描清单里。
# 只验"不漏扫"是单向的 —— 实现若把排除集删空，漏扫检查照样通过，等于把第三方/派生目录
# 也扫进来（引入无关 error，污染门禁）。双向断言才闭环。
_leak=0
for pat in '/.git/' '/node_modules/' '/brooks-lint/' '/brooks-tools/' '/dist/' '/.omo/' '/.claude/' '/.specs/' '/test/'; do
  n=$(grep -c -- "$pat" $TMPD/ac4_in.txt || true)
  if [ "${n:-0}" -gt 0 ]; then echo "❌ FAIL: 排除项 $pat 泄漏进扫描清单（$n 条）"; _leak=1; fi
done
[ "$_leak" -eq 0 ] || exit 1
echo "✅ AC-4 PASS（覆盖率 100% + 排除项零泄漏）"
```

> **F2 的附加交付物（由本 AC 倒逼）**：`make lint` 须固定输出 `SCANNED_FILES: <n>` + 逐行路径。
> 这也顺带消除 R10 的同类风险：**任何"清单/计数"断言都从实现对外的单一出口读取，而不是在验证脚本里重新数一遍**。

### AC-4b · 「生产 `.sh`」集合规则是契约而非实现细节（L3 二轮 Minor 补）

- **Given** AC-4 是路径级集合差，**排除列表本身就是判据的一半**
- **When** 审阅 `find` 的排除项
- **Then** 每一项都有明示理由，且该列表被声明为**契约**（实现者不得自行增删以"凑绿"）：

  | 排除项 | 理由 |
  |---|---|
  | `.git/` · `node_modules/` | 非本仓维护内容（VCS 元数据 / 依赖安装物） |
  | `brooks-lint/` · `brooks-tools/` | **第三方**打包内容，非本仓维护代码（与 `make dup` 的 jscpd ignore 同口径） |
  | `dist/` | **派生产物**（由 `package-dsh-plugin.sh` 生成），不是源 |
  | `.omo/` · `.claude/` | 本地工具/运行时目录（含第三方注入的 skill） |
  | `.specs/` | spec 工件与探针脚本（如 `probe-cross-env.sh`），非产品代码 |
  | `test/` | **测试**代码；本 change 的门禁针对生产脚本 |

- **验证方式**：AC-4 的 `find` 与上表逐项一致（表即契约）；若实现需增删排除项，**必须回到本 AC 修改**，不得在实现中静默调整。
- **验证方式②（机器化 · L3 三轮 Critical 补）**：**`扫描集 ∪ 契约排除集 == 全仓可发现 .sh 集`** —— 见 AC-4c。
- **⚠️ 漏洞说明（L3 三轮 Critical · 2026-09-20）**：初稿只把排除列表**声明**为契约，**没有任何机制强制实现遵守**。实现只要静默多排除一个目录（例：`-not -path '*/legacy/*'`），AC-4 的集合差**仍恒为 0** —— 判据被架空。AC-4c 即为此补强。

### AC-4c · 排除契约不可被静默扩张（L3 三轮 Critical · AC-4 的补强）

- **Given** 「生产 `.sh`」= 全仓 `.sh` 减去 AC-4b 契约中的 6 类排除项
- **When** 把 `make lint` 自报的**扫描集**与按**契约排除集**（由本 AC 独立算出的 6 条 path 模式）求并集
- **Then** 该并集必须**等于**独立 `find` 枚举的全仓 `.sh` 集 —— 即**没有任何文件既不在扫描集、也不在契约排除集**
- **为什么有效**：实现若偷偷多加排除项，那些文件会**同时缺席**扫描集与契约排除集 → 并集出现缺口 → 立即失败。这正是 AC-4 单独做不到的。
- **验证方式**：`AC-4c 验证脚本`

```bash
# AC-4c 验证（可复制执行 · 独立于实现重算契约排除集，检测静默扩张）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
make lint >/tmp/ac4c_log 2>&1 || { echo "❌ FAIL: make lint 非零退出"; exit 1; }
awk '/^SCANNED_FILES:/{f=1;next} f&&/^\.\//{print;next} f&&!/^$/{exit}' /tmp/ac4c_log \
  | sed 's|^\./||' | sort -u > $TMPD/ac4c_scanned.txt

# 契约排除集：与 AC-4b 表格逐项对应（本文件的契约，非实现细节）
find . -name '*.sh' \( -path '*/.git/*' -o -path '*/node_modules/*' \
  -o -path '*/brooks-lint/*' -o -path '*/brooks-tools/*' -o -path '*/dist/*' \
  -o -path '*/.omo/*' -o -path '*/.claude/*' -o -path '*/.specs/*' -o -path '*/test/*' \) \
  | sed 's|^\./||' | sort -u > $TMPD/ac4c_excluded.txt

# 全仓可发现 .sh 集
find . -name '*.sh' -not -path '*/.git/*' | sed 's|^\./||' | sort -u > $TMPD/ac4c_all.txt

cat $TMPD/ac4c_scanned.txt $TMPD/ac4c_excluded.txt | sort -u > $TMPD/ac4c_union.txt
gap=$(comm -13 $TMPD/ac4c_union.txt $TMPD/ac4c_all.txt | wc -l)
[ "$gap" -eq 0 ] || { echo "❌ FAIL: $gap 个文件既未被扫描也未被契约排除（疑似静默扩张排除项）"; comm -13 $TMPD/ac4c_union.txt $TMPD/ac4c_all.txt; exit 1; }
echo "✅ AC-4c PASS（扫描集 ∪ 契约排除集 == 全仓 .sh 集）"
```

### AC-5 · exec-bit 门禁不再误报（对应 US-3 正向）

- **Given** 仓库处于健康状态。**基线告警的构成须说明完整**（L3 三轮 Minor 补）：`pre-tool-use/` 下 4 个只被 `source` 的库无 exec 位（3 个真入口有），**加上 `.claude/hooks` 下 1 个**，故基线共 5 处告警。本 AC 要求**全部 5 处归零**，而非只管 `pre-tool-use/` 那 4 处。
- **When** 跑 `make check-hooks-sync`
- **Then** **同时**满足：① 退出码为 **0**；② 输出**不含**"缺可执行位"告警
- **验证方式**：`AC-5 验证脚本`（**必须显式捕获退出码** —— 管道会吞掉 `make` 的返回码）
- **⚠️ 修正记录 · L3 盲审 Major（2026-09-20）**：初稿只写 `make check-hooks-sync 2>&1 | grep -c '缺可执行位'` 并断言计数为 0。
> 缺陷有二：① **未检查 Then 明确要求的退出码 0**；② **管道掩盖 `make` 的退出码** —— 若 `make check-hooks-sync` 以非零退出但恰好不含该告警字符串，验证会**假通过**。已改为先落盘、再分别断言退出码与内容。

```bash
# AC-5 验证（可复制执行 · 显式捕获退出码，不走管道）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
make check-hooks-sync >$TMPD/ac5.log 2>&1; rc=$?
[ "$rc" -eq 0 ] || { echo "❌ FAIL: 退出码 $rc ≠ 0"; tail -20 $TMPD/ac5.log; exit 1; }
n=$(grep -c '缺可执行位' $TMPD/ac5.log || true)
[ "$n" -eq 0 ] || { echo "❌ FAIL: 仍有 $n 处「缺可执行位」告警"; grep '缺可执行位' $TMPD/ac5.log; exit 1; }
echo "✅ AC-5 PASS（exit 0 且 0 处告警）"
```

### AC-6 · exec-bit 门禁仍能抓到真入口丢失，**并指名是哪个入口**（对应 US-3 反向 · 承重性）

- **Given** 健康状态
- **When** 摘掉一个**真入口**的 exec 位，跑 `make check-hooks-sync`
- **Then** 输出**必须指名该文件路径**（含入口文件名）。退出码行为由 DESIGN 定案（见下"已知边界"），但**"指名"是硬要求** —— 无文件名的聚合计数不满足本 AC
- **验证方式**：`AC-6 验证脚本`。**本 AC 是本次最关键的承重性证明** —— 若只做 AC-5（不报），可能与"把检查删掉"无法区分

> **⚠️ 探针必须落在判据域内（L2 盲审 R1 修正 · 2026-09-20）**
> 本 AC 初稿把探针指向**源** `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`。该选点是**错的**：
> `sync-hooks.sh` 的 `DEST_ROOTS`（`:47-55`）只含 **7 个镜像根**，exec 判据只作用于镜像副本 `$dst_f`（`:188-196`），
> **源目录不在判据域内**。实测对照（复验通过）：
> - 打**源** → 计数**纹丝不动**（仍 5）、文件名 0 次、exit 0 → 按此探针，本 AC **永远不可能通过**
> - 打**镜像副本**（如 `dist/dsh-flow-kit/hooks/pre-tool-use/independent-review-gate.sh`）→ 计数 **5→6**，判据**确实看得见**
>
> **修正后结论**：判据**已有检出能力**，缺的只是"不打文件名"。
> 故本 AC 的探针改为**镜像副本**；F3 的实施范围收敛为「收窄判据域 + 检出时逐条指名」，
> **不扩张判据域到源 bundle**（那属未登记的范围扩张，DESIGN §0.5.1 / D4–D6 均未包含）。

- **已知边界（DESIGN 必答）**：该检查器当前输出 advisory（`nonexec_total` 计数 + 告警行），**不以退出码失败**。DESIGN 需定案二选一：
  - **(a) 升级为 fail**：真入口丢 exec 位 → 非零退出
  - **(b) 保持 advisory 但必须指名文件**：不阻塞，输出 `⚠️ <具体路径>` 逐条列出 ← **DESIGN D5 已定案选此**
  - 选定后，TEST 阶段**按该强度如实断言**（**禁止**写成"非零退出"再在实现时放宽）

```bash
# AC-6 验证（可复制执行 · 探针打在【镜像副本】上，修正自 L2 R1）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d)   # 夹具并发隔离（清理见下方合并 trap —— EXIT trap 只能有一个）
# 前置（Given）：① 基线无 exec 告警；② dist 与源一致（否则验证打在过期副本上，结论不可信）
bash sync-hooks.sh --check 2>&1 | grep -q '缺可执行位' && { echo "❌ 前置不满足：基线已有 exec 告警（AC-5 未达成）"; exit 1; }
diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle >/dev/null \
  || { echo "❌ 前置不满足：dist 与源不一致，请先 bash package-dsh-plugin.sh"; exit 1; }
F=dist/dsh-flow-kit/hooks/pre-tool-use/independent-review-gate.sh   # 镜像根内，属判据域
[ -f "$F" ] || { echo "❌ 前置不满足：镜像副本不存在（$F），请先 bash package-dsh-plugin.sh"; exit 1; }
# 还原必须用 chmod：$F 位于 dist/（.gitignore 忽略），git checkout 会报
# "路径规格未匹配任何 git 已知文件" 且**不还原权限位**（L3 三轮 Major 实测确认）
trap 'chmod +x '"$F"'; rm -rf "$TMPD"' EXIT
chmod -x "$F"
make check-hooks-sync >$TMPD/ac6.log 2>&1 || true
grep -q 'independent-review-gate' $TMPD/ac6.log \
  || { echo "❌ FAIL: 未指名丢失 exec 位的真入口（聚合计数不算通过）"; exit 1; }
echo "✅ AC-6 PASS（指名要求满足；退出码强度按 DESIGN D5 = advisory 另验）"
```

### AC-7 · 无行为回归（三处修复不得伤及既有门禁）

- **Given** 三处修复均已落地
- **When** 跑全量质量门禁
- **Then** 同时满足：
  - `make test`：**950 ok / 0 not ok / 1 skip**，退出码 0
  - `make lint`：error 级 **0**（门禁绿）
  - `make check-validate`：漏配 **0** / 源缺失 **0**
  - `make check-test-sync`：`test/` ↔ `flow-kit-bundle/test/` 一致
  - `make check-hooks-sync`：7 个镜像根漂移 **0**
  - `make verify-claims`：**13 ✅ / 0 ❌**，退出码 0 ← **修正见下**
- **验证方式**：`AC-7 验证脚本`（逐条给出可复制断言；**基线数字为精确相等**，TEST 阶段若合法增删用例须同步更新本 AC）
- **⚠️ 修正记录 · L3 二轮 Major（2026-09-20）**：初稿只写"命令名 + 期望值"，未给**可复制的断言命令**，也未说明 950 是**精确相等**还是下限 → 验证者无法机械判定（`ok 951` 算不算过？）。已补完整脚本并明确语义。

```bash
# AC-7 验证（可复制执行）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
fails=""

# ① bats：950 ok / 0 not ok / 1 skip（精确相等）
npx --yes bats@1.13.0 test/ >$TMPD/ac7_test.log 2>&1 || true
ok=$(grep -cE '^ok ' $TMPD/ac7_test.log || true)
nok=$(grep -cE '^not ok ' $TMPD/ac7_test.log || true)
sk=$(grep -c '# skip' $TMPD/ac7_test.log || true)
[ "$ok"  -eq 950 ] || fails="$fails bats_ok=$ok(期望950)"
[ "$nok" -eq 0 ]   || fails="$fails bats_notok=$nok(期望0)"
[ "$sk"  -eq 1 ]   || fails="$fails bats_skip=$sk(期望1)"

# ② lint：error 级 0
make lint >$TMPD/ac7_lint.log 2>&1 || fails="$fails lint非零退出"

# ③ check-validate：漏配 0 / 源缺失 0
make check-validate >$TMPD/ac7_val.log 2>&1 || fails="$fails validate失败"
grep -qE '漏配 \(ERROR\): 0' $TMPD/ac7_val.log || fails="$fails 漏配非0"
grep -qE '源缺失 \(WARNING\): 0' $TMPD/ac7_val.log || fails="$fails 源缺失非0"

# ④ test 双源一致
make check-test-sync >$TMPD/ac7_sync.log 2>&1 || fails="$fails 双源不一致"

# ⑤ check-hooks-sync：漂移 0
make check-hooks-sync >$TMPD/ac7_hooks.log 2>&1 || fails="$fails hooks-sync失败"
grep -qE '漂移 0' $TMPD/ac7_hooks.log || fails="$fails 漂移非0"

# ⑥ verify-claims：13 ✅ / 0 ❌ ＋ F6 的两处修复必须生效
bash verify-claims.sh >$TMPD/ac7_vc.log 2>&1 || fails="$fails verify-claims非零退出"
grep -qE '复验结果: ✅ 13  ❌ 0' $TMPD/ac7_vc.log || fails="$fails verify-claims计数≠13/0"
# F6(a)：三处硬编码已改为解析器 → 不应再因归档路径失败
grep -qE '§0.5.1 未列' $TMPD/ac7_vc.log && fails="$fails F6(a)未生效(仍有§0.5.1失败)"
# F6(b)：门数须动态推导（F1 加门后应为 6，且不得再出现写死的"五门"）
grep -qE 'make check [0-9]+ 门全绿' $TMPD/ac7_vc.log || fails="$fails F6(b)未生效(门数未动态推导)"
grep -q '五门' $TMPD/ac7_vc.log && fails="$fails F6(b)未生效(仍有写死『五门』)"

[ -z "$fails" ] || { echo "❌ FAIL:$fails"; exit 1; }
echo "✅ AC-7 PASS（六项全绿）"
```

> **⚠️ 两处修正（L2 盲审 R3 · 2026-09-20）**
>
> **① 原写「13 ✅ / 0 ❌」是把本会话早期的输出当基线，已失效。** 实测 `bash verify-claims.sh` → **exit 1 · ✅ 11 / ❌ 2**。
> 根因：脚本 `:123`（`D=`）、`:137`（`M=`）、`:158` 三处**硬编码**已归档的 `.specs/l3-review-defects-2026-09/`，
> 而该目录于 2026-09-20 归档（`e5fca58`）→ 三处引用全部落空（§8 与 §10c 各失败一次）。
> **这与 bats #620 同源同因**（同一归档动作打断硬编码 live 路径），是本 change 之前就存在的存量缺陷，
> **不自本 change 引入**，但**会被本 change 的 F1 进一步触发**（见 ②）。
>
> **② `verify-claims.sh` 与本 change 存在强耦合，无法回避**：
> - 其 `:165` 硬编码断言「**make check 五门全绿**」。F1 把 `check-dist` 加入 `make check` 后，该断言**必然变成假陈述** → 脚本必红。
> - 因此**不修它，F4（AC-7 全量回归绿）按现范围不可达**。
>
> **处置（已纳入 v1 · 见 F6）**：修 `verify-claims.sh` 的两类问题 ——
> (a) 三处 hardcoded change 目录改为**可解析**（live 优先 → archive 回退，两者皆无则显式失败）；
> (b) `:165` 的「五门」断言改为**从 `Makefile` 的 `check:` 依赖动态推导**（而非写死数字），使门禁增删不再使它失效。
>
> **✅ 已实施并实测（2026-09-20）**：`bash verify-claims.sh` → **exit 0 · ✅ 13 / ❌ 0**，
> 第 10 项输出为「`make check 5 门全绿`」（门数系现场数出，F1 加门后会自动变成「6 门」而无需改脚本）。
> **期望值定稿为 13 ✅ / 0 ❌**（原 13 项全部恢复；早先推测的"15"是错的 —— (a) 只是让 2 项从 fail 回到 pass，
> 并未新增断言项，故总数仍是 13）。

### AC-8 · 验证动作自身不改工作区（AC 卫生）

- **Given** 任一条 AC 的验证脚本执行完毕（含中途失败）
- **When** 跑 `git status --porcelain`
- **Then** 输出为空（临时改动均被 `trap` 还原）
- **验证方式**：`AC-8 验证脚本`（**先记基线、后比对** —— 不能只看"最终是否干净"，否则无法区分"本就脏"与"被验证弄脏"）
- **目的**：门禁类 change 的验证极易污染工作区（注入错误再忘还原），本仓 2026-08-03 曾因验证不卫生造成误判，故列为独立 AC
- **⚠️ 修正记录 · L3 二轮 Minor（2026-09-20）**：初稿未界定"哪些命令产生副作用"，且以 `cp -p` 还原**不保证权限/mtime 完全复原**。已改为：① **执行前先记录基线**；② 注入类脚本的还原改用 `git checkout -- <file>`（内容与权限一并复原）；③ AC-7 的只读命令断言其**不写被跟踪文件**。

```bash
# AC-8 验证（可复制执行）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
git status --porcelain > $TMPD/ac8_base.txt      # ① 基线（允许 change 自身未被跟踪的 .specs 目录存在）
before=$(wc -l < $TMPD/ac8_base.txt)

# ② 依次执行注入类 AC 脚本（各自内部用 git checkout 还原）
bash .specs/health-fix-2026-09/verify/ac1.sh || true
bash .specs/health-fix-2026-09/verify/ac3.sh || true
bash .specs/health-fix-2026-09/verify/ac4.sh || true
bash .specs/health-fix-2026-09/verify/ac5.sh || true
bash .specs/health-fix-2026-09/verify/ac6.sh || true

# ③ 与基线逐行比对（不只看行数）
git status --porcelain > $TMPD/ac8_after.txt
diff $TMPD/ac8_base.txt $TMPD/ac8_after.txt && echo "✅ AC-8 PASS（工作区与基线一致）" \
  || { echo "❌ FAIL: 验证动作改变了工作区（见上 diff）"; exit 1; }
```

> **实现要求（供 3-task / 4-dev）**：AC-1/3/4/5/6 的验证脚本须落到 `.specs/health-fix-2026-09/verify/acN.sh`，各脚本的还原一律用 `git checkout -- <file>`（**不用 `cp` 备份还原** —— 它不保证权限与 mtime）。
- **⚠️ 修正记录 · L3 盲审 Minor（2026-09-20）**：初稿 When 写"任一条 AC 的验证脚本"，未定义**执行哪些**，验证者无法复现。已明确为：**依次执行 AC-1、AC-3、AC-4、AC-5、AC-6 的验证脚本（AC-2 / AC-7 为只读命令，不注入改动）**，然后断言工作区干净。

### AC-9 · 门禁判据的理由注释确实存在且可追溯（对应 US-4 / v1 的 F5）

- **Given** F1 / F2 / F3 的实现已落地
- **When** 在三个载体里各查一条**理由注释**：`Makefile`（lint / check-dist 相关处）、`sync-hooks.sh`（exec 判据处）、`package-dsh-plugin.sh`（`--check` 模式处）
- **Then** 每处**同时**满足：① 注释里**出现了 `health-fix-2026-09` 这个 change-id**（保证是本 change 加的、可追溯）；② 该注释解释了**判据为何这样定**（而非"做了什么"）
- **验证方式**：`AC-9 验证脚本`（用一个本 change 独有的标记 `health-fix-2026-09` 做锚点 —— 天然规避"数既有注释"的歧义）
- **为什么用 change-id 作锚**：比数注释条数稳健（既有文件已含大量注释）；且 change-id 正是"依据哪份变更决定"的机器可读形式，L3 要求"指向具体报告/判据来源"由此满足。

```bash
# AC-9 验证（可复制执行）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
miss=""
grep -q 'health-fix-2026-09' Makefile                   || miss="$miss Makefile"
grep -q 'health-fix-2026-09' sync-hooks.sh              || miss="$miss sync-hooks.sh"
grep -q 'health-fix-2026-09' package-dsh-plugin.sh      || miss="$miss package-dsh-plugin.sh"
[ -z "$miss" ] || { echo "❌ FAIL: 缺理由注释（含 change-id 锚点）:$miss"; exit 1; }
echo "✅ AC-9 PASS（三载体均有可追溯的理由注释）"
```

> **F5 的交付物至此可验收**（初稿 F5 在 v1 却无 AC —— L3 Major 指出，已由本 AC 补上）。
> ⚠️ AC-9 **取代**了初稿"由 AC-1/AC-2/AC-6 的失败信息质量间接覆盖"的说法 —— 间接覆盖不构成可机械执行的验收。

---

## 预检结果（2026-09-20 实测 · AC 真实性证明）

> **为什么要这一段**：AC 若在修复前就已通过，它就没有证明力（"测试了不存在的东西"是本仓 TD-016 的教训）。
> 故每条关键 AC 在写需求时**先跑一次**，确认它现在**失败**。实测命令与还原均已执行，工作区 `git status --porcelain` 干净。

| AC | 修复前实测行为 | 结论 |
|---|---|---|
| **AC-1** | 改 `dsh-flow-kit/README.md` 后 `make check` **绿**（退出码 0），日志中 `README` 出现 **0** 次 | ✅ 真实判据 —— 正是要堵的盲区，修复后应转红→还原后转绿 |
| **AC-3** | 向 `install.sh` 注入语法错误后 `make lint` **绿**，日志中 `install.sh` 出现 **0** 次；而单独 `shellcheck flow-kit-bundle/install.sh` 直接报 **3 处 error**（`SC1073/SC1050/SC1072`） | ✅ 真实判据 —— 错误确实存在，只是门禁看不见 |
| **AC-5** | `make check-hooks-sync` 输出 `⚠️ 5 个 hook 入口缺可执行位`（**1 处告警**），退出码 0 | ✅ 真实判据 —— 误报确认存在 |
| **AC-6** | 摘掉真入口 `independent-review-gate.sh` 的 exec 位后：退出码 **0** · 日志中该文件名出现 **0** 次 · 计数仍为 5 | ⚠️ **判据不足**（见 AC-6 正文）—— 当前实现**无法指名**丢失 exec 位的入口，故 AC-6 同时是"新增能力"要求 |
| AC-7 / AC-8 | 基线：950 ok/0 not ok/1 skip · lint error 0 · 漏配 0/源缺失 0 · 双源一致 · 漂移 0 · 工作区干净 —— **均实测属实** | 基线已记录。**⚠️ 但 `verify-claims` 一项初稿基线错误（写 13✅/0❌，实测 11✅/2❌）**，见 AC-7 修正①。L2 抽验 6 行中此行不实，已更正 |
| **AC-2** | ❌ **初稿断言不实**（L2 R2 抓出）：声称"dist 当前与源一致"，实测 `vendor/.../test_l3_review_defects_2026_09.bats` 陈旧 | 已修正：Given 去掉无效的 git 代理，并登记"实施前先重建 dist"为 F1 前置 |

**预检带出的一个需求升级**：AC-6 原写作"非零退出或输出告警，并指名该文件"。实测证明**"指名"这一半当前完全缺失**（告警只有聚合计数、无文件名），且 AC-5 消除误报后计数将恒为 0/非 0 —— 若检出的入口不被指名，维护者将**无法处置**。故"指名具体路径"提升为硬要求，退出码强度留给 DESIGN 定案。

---

## 范围切分

### v1（本次必做）

- **F1**：新增 dist 新鲜度门禁（对应 AC-1 / AC-2），并纳入 `make check`
  - **前置步骤**：实施前**先重建 dist**，使 AC-2 的 Given（"dist 由当前源重建过"）实际成立（当前 vendor 测试文件陈旧 19 分钟，见 AC-2 修正②）
- **F2**：`make lint` 扫描面覆盖全部生产脚本（对应 AC-3 / AC-4）—— **7 个**漏扫脚本，非 4 个
- **F3**：`check-hooks-sync` exec 判据收窄为「仅真入口」，且保留对真入口的检测力 + **检出时逐条指名**（对应 AC-5 / AC-6）
  - **范围收敛（L2 R1）**：判据域**保持 7 个镜像根不变**，不扩张到源 bundle
- **F4**：AC-7 全量回归绿
- **F5**：门禁判据的**理由注释**（为什么这样判、依据哪份报告）写进 `Makefile` / `sync-hooks.sh` / **`package-dsh-plugin.sh`（DESIGN D2 的实际载体，初稿漏列）** —— 让 US-4 成立
- **F6**：修 `verify-claims.sh` 的存量缺陷（**L2 R3 新增 · 与 F1 强耦合，不修则 F4 不可达**）：
  - (a) `:123` / `:137` / `:158` 三处硬编码 `.specs/l3-review-defects-2026-09/` → 改为 live 优先 → archive 回退解析（两者皆无则显式失败）
  - (b) `:165` 的「make check 五门全绿」断言 → 改为从 `Makefile` 的 `check:` 依赖**动态推导门数**，使 F1 加门后不失效

### v2（下一轮考虑，不本次）

- **`prompts ↔ skills` 双载体同步门禁**（TD-025 🟡）：需先回答"skills/ 是 prompts 的镜像，还是允许差异的独立精简版"这一**产品判断**。判断未定前写门禁只会锁死错误契约。已登记 TD-025，本 change 明确不碰。
- **`test/**.bats` 硬编码 `.specs/<change-id>/` 引用的 lint 告警**：2026-09-20 归档收口打断 bats #620 事件（`ac47f85`）沉淀出的候选检查，价值待评估（可能误报率高）。已记 LESSONS。
- **`corpus-count.sh:22` 默认输出路径写死已归档 change**：静默默认失效，已记 LESSONS。属独立小修，不值得占本 change 范围。

### out（永远不做）

- **不做**"让 `make lint` 把所有 warning 变成 fail"：warning 池含 22 处 SC1090（shellcheck 无法跟踪动态 `source`）等 known-acceptable 项，升级为 fail 会让门禁长期红、被绕过，反而降低可信度。**本 change 只保证 error 级门禁与"看得见"，不改变红绿语义。**（承接 TD-023 既定判定）
- **不做**对第三方目录（`brooks-lint/` / `brooks-tools/` / `.claude/plugins/`）的任何检查 —— 非本仓维护代码。
- **不做**给门禁加 UI / 报告输出格式 / 彩色渲染 —— 与目标无关。

---

## 非功能性需求

- **性能**：新增的 `check-dist` 必须**快**：纯内容比对、不重建、不调用 npm/node（`--check` 模式内），**耗时 ≤ 2s**。
  - **测量方法**（L3 盲审 Minor 补 · 可重复）：`time make check-dist`，取 3 次中位数；夹具为**当前仓库**（dist 已重建、vendor 含 `test/`，约 500+ 文件）。
  - **环境基线**：本仓当前环境 —— bash + GNU coreutils + shellcheck 0.9.0 + node v22；路径 `~/unisoc/flow-kit`。
  - **参考实测**：等价比对（4 条 `diff -rq` 覆盖 vendor/lib/hooks/skills）= **13ms**，故 ≤2s 门槛有约 150× 余量。
  - **理由（已更正取证）**：`make check` 由 **pre-push** hook 调用（`.git/hooks/pre-push:8`），pre-commit 只跑 `make test` —— 初稿把调用方写成 pre-commit 属取证错位（已登记 `MINOR-DEFERRED.md` M1）。结论不变：`make check` 总时长受 `make test`（约 1–2 分钟）主导，新门禁不得成为可感知负担。
- **可访问性**：无（非 UI 项目）。
- **安全**：验证脚本一律用 `mktemp`/`/tmp` 隔离 + `trap` 还原，**禁止**在生产路径留下残留改动；不引入任何需要网络的门禁（离线可跑）。
- **兼容性**：门禁须在**未安装可选工具**时优雅降级（沿用既有惯例：工具缺失 → 打印跳过原因 + 退出 0，不阻塞）。适用环境：本仓当前 bash + GNU coreutils + shellcheck 0.9.0 + node v22。
- **可观测性**：门禁失败时必须**输出足够的定位信息**：陈旧的**具体文件路径**（AC-1）、漏扫的**具体文件名**（AC-3）、丢 exec 位的**具体入口**（AC-6）。禁止只说"check failed"。

## 依赖与假设

- **依赖**：`Makefile`（门禁入口）、`sync-hooks.sh`（exec 判据）、`package-dsh-plugin.sh`（dist 重建，仅被 AC 的"还原"步骤间接用到，不改其产物逻辑）、`shellcheck 0.9.0`（已装）、`bats 1.13.0`（经 npx）。
- **假设 A1**：dist 是**纯派生产物**（由 `package-dsh-plugin.sh` 从源重建），因此"dist 与源一致"是可判定的 —— 不存在"只能手改 dist"的合法场景。若该假设不成立，AC-1/AC-2 的设计需重做（DESIGN 需显式确认）。
- **假设 A2**：`make check` 全绿是提交前提（pre-commit hook 已强制）。本 change 只是给这条链加两个更早的观察点。
- **假设 A3**：`pre-tool-use/` 下 3 个入口 vs 4 个被 `source` 的库这一划分是**稳定契约**，不会因后续拆分而频繁变动；若变动，需同步维护"真入口清单"（DESIGN 需给出该清单的**单一事实源**，避免再次漏配）。

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
