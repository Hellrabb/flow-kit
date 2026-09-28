# T26-SUMMARY · AC-6 端到端判据：探针必须被抓住 + 自报↔落档绑定 + 差分数（防硬编码）

- **Change ID**: `health-fix-2026-09b`
- **Task ID**: T26（Wave 6 · model-tier=top）
- **关联**: `@.specs/health-fix-2026-09b/TASK.md`、`@.specs/health-fix-2026-09b/REQUIREMENT.md`（AC-6）、`@.specs/health-fix-2026-09b/DESIGN.md`（D4/D10′/R8 读序）
- **执行**: 阶段 4（DEV）· 2026-09-23

---

## 0. 结论

✅ **AC-6 端到端判据全部实跑通过**。本任务是**判据实跑型任务**：把 `TASK.md` T26 `<verify>` 块（L1141–1171）从原文原样抽取后执行，如实留档。**未修改任何产品件**。

三个**临时**对象（`.specs/CONTEXT.md`、`flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt`、`.specs/health-fix-2026-09b/path-privacy-allowlist.txt`）均在探针期间临时写入/移位，成功与失败分支均先备份后恢复，末段三条 `cmp -s` 证明三者与备份**逐字节一致**——T21 冻结产物未被污染。

判据未暴露产品缺陷；无需主 agent 裁决修法。

---

## 1. 交付物

本任务是**判据实跑型任务**，**没有产品件**。`write_files` 列出的三个对象均为**临时**对象，已全部逐字节复原：

| 临时对象 | 路径 | 作用 | 复原断言 |
|---|---|---|---|
| 探针注入点 | `.specs/CONTEXT.md` | ① 探针 `<!-- probe: '/home/''zz-path-pr''obe/' -->` 临时追加到 :708 | `cmp -s .specs/CONTEXT.md /tmp/probe-bak` ✅ |
| 权威清单（读序第一） | `flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt` | ④a 临时追加 `'/home/''zz-path-pr''obe-differential':1`；④b 临时 `mv` 移位 | `cmp -s "$AL2" /tmp/al2-bak` ✅ |
| change 副本（读序第二） | `.specs/health-fix-2026-09b/path-privacy-allowlist.txt` | ④b 在位态 | `cmp -s "$AL" /tmp/al-bak` ✅ |

**持久产物**：本 SUMMARY + `TASK.md` 的 T26 状态位（`pending` → `done`）。

---

## 2. 判据实跑（命令 + 输出 + rc）

> 执行环境：`cd /home/<acct>/unisoc/flow-kit`（仓根 cwd）+ 真实 `$HOME`（`/home/<acct>`）+ `export LC_ALL=C`。全部前台执行，无后台作业。

### 2.1 原语自检（⓪）

```bash
make --help | grep -qw -- '--always-make'   # ✅ 命中
rc=0; make -n check-path-privacy >/dev/null 2>&1 || rc=$?   # rc=0
make -n check | grep -q 'check-path-privacy' # ✅ 命中
```
- `--always-make` 正例命中 ✅
- `make -n check-path-privacy` **rc=0**（目标已实现，非 rc=2）
- `make check` 含 `check-path-privacy` ✅

### 2.2 探针注入必被抓住（①）

```bash
PROBE='/home/''zz-path-pr''obe/'   # 拼接构造，禁 /home/<user> 形态
printf '%s\n' "$PROBE" | grep -qE '/home/[a-z_][a-z0-9_-]*/'  # ✅ 自检命中
printf '\n<!-- probe: %s -->\n' "$PROBE" >> .specs/CONTEXT.md
if make check-path-privacy; then ... echo "🔴 未抓住探针"; exit 1; fi   # 非 0 ⇒ 抓住
```
输出（探针态）：
```
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 1 条（含占位符排除后）
   清单外命中 1 条
   ── 清单外命中归因（file:line）──
   .specs/CONTEXT.md:708: <!-- probe: '/home/''zz-path-pr''obe/' -->
🔴 清单外命中 1 条（非允许清单命中 ⇒ 阻塞，ADR-027 ②③ / ADR-028 决策 2）
```
- **探针被抓住**：`make check-path-privacy` 非 0 退出，且指名 `.specs/CONTEXT.md:708`（file:line 定位） ✅
- 探针拼接产出 `'/home/''zz-path-pr''obe/'`（21B，无双引号字面污染）✅

### 2.3 健康态 rc=0（②）

```bash
make check-path-privacy || { echo "🔴 门禁自身在健康态未通过"; exit 1; }
```
输出：
```
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
```
- **健康态 rc=0** ✅

### 2.4 自报↔落档绑定（⑤）

```bash
printed=$(make check-path-privacy | grep -oE '允许清单 [0-9]+ 条' | grep -oE '[0-9]+')
filed=$(grep -cvE '^[[:space:]]*(#|$)' "$AL2")
[ "$printed" = "$filed" ] || ...
```
- **printed=0 filed=0** ✅（自报条数 = 权威清单有效行数，绑定一致）

### 2.5 差分数·读序双态（④a / ④b）

#### ④a 向权威清单追加一条 ⇒ 自报条数必须增大

```bash
printf '/home/''zz-path-pr''obe-differential/:1\n' >> "$AL2"   # 追加到权威清单（读序第一）
n2=$(make check-path-privacy | grep -oE '允许清单 [0-9]+ 条' | grep -oE '[0-9]+') || true
cp -f /tmp/al2-bak "$AL2"
[ "${n2:-0}" -gt "$printed" ] || ...
```
- **printed=0 → n2=1**（差分成立：改权威清单后自报随之变化，门禁真读清单非硬编码） ✅

#### ④b 权威缺失 + 副本在位 ⇒ rc=0（读序双态）

```bash
mv "$AL2" /tmp/al2-moved   # 移走权威清单
make check-path-privacy >/dev/null 2>&1 || { mv -f /tmp/al2-moved "$AL2"; echo "🔴 ④b..."; exit 1; }
mv -f /tmp/al2-moved "$AL2"
```
- **④b rc=0**（权威缺失 + 副本在位 ⇒ 门禁放行，与 T21 已断言的「两份皆缺 ⇒ rc=1」**两态可区分** ⇒ 读序已实现） ✅

### 2.6 末段三条 cmp -s（逐字节复原）

```bash
cmp -s "$AL2" /tmp/al2-bak || { echo "🔴 权威清单未逐字节恢复"; exit 1; }
cmp -s "$AL" /tmp/al-bak || { echo "🔴 change 副本未逐字节恢复"; exit 1; }
cmp -s .specs/CONTEXT.md /tmp/probe-bak || { echo "🔴 CONTEXT.md 未逐字节恢复"; exit 1; }
```
- 权威清单 AL2 逐字节复原 ✅
- change 副本 AL 逐字节复原 ✅
- CONTEXT.md 逐字节复原 ✅

### 2.7 收尾断言

```bash
make check-path-privacy | grep -qE '清单外命中 0 条'   # ✅ 命中
grep -q 'check-path-privacy' flow-kit-bundle/hooks/pre-commit/pre-commit.sh   # ✅ 命中
bash sync-hooks.sh --check   # ✅ rc=0，镜像文件数 48，漂移 0
```

---

## 3. 门禁与回归表

| 检查项 | 命令 | rc | 结果 |
|---|---|---|---|
| T26 verify 全量 | （见 §2 全部断言） | 0 | ✅ 全通过 |
| 回归 v_T17 | `bash /tmp/vblocks/v_T17.sh` | 0 | ✅ |
| 回归 v_T18 | `bash /tmp/vblocks/v_T18.sh` | 0 | ✅ |
| 回归 v_T20 | `bash /tmp/vblocks/v_T20.sh` | 0 | ✅ |
| 回归 v_T21 | `bash /tmp/vblocks/v_T21.sh` | 0 | ✅ |
| 回归 v_T22 | `bash /tmp/vblocks/v_T22.sh` | 0 | ✅ |
| 回归 v_T23 | `bash /tmp/vblocks/v_T23.sh` | 0 | ✅ |
| 回归 v_T25 | `bash /tmp/vblocks/v_T25.sh` | 0 | ✅ |
| make lint | `make lint` | 0 | ✅ shellcheck no errors |
| make check-hooks-sync | `make check-hooks-sync` | 0 | ✅ 漂移 0 |
| sync-hooks --check | `bash sync-hooks.sh --check` | 0 | ✅ 镜像文件数 48 |
| make check-path-privacy | `make check-path-privacy` | 0 | ✅ 清单外命中 0 条 |
| 全量 bats | `cd 仓根 && npx bats test/` | 0 | ✅ 973 ok / 0 not ok / 0 skip |

> bats 基线 2026-09-23 实测 **973 ok / 0 not ok / 0 skip** —— 本任务实测完全一致，**无退化**。

---

## 4. 判别力与反例

### 4.1 探针被抓住的证据

探针 `'/home/''zz-path-pr''obe/'` 注入 `.specs/CONTEXT.md:708` 后，`make check-path-privacy` **非 0 退出**，且报文指名归因行：
```
.specs/CONTEXT.md:708: <!-- probe: '/home/''zz-path-pr''obe/' -->
🔴 清单外命中 1 条（非允许清单命中 ⇒ 阻塞，ADR-027 ②③ / ADR-028 决策 2）
```
这是 AC-6① 的**判别力证据**：探针被抓住并指名路径，而非静默放行。探针恢复后健康态即转绿（rc=0 + `清单外命中 0 条`），证明红绿差异**仅由探针引起**，非环境噪声。

### 4.2 ④a 差分数（防硬编码）

- 改前：`printed=0`（权威清单 0 条有效条目）
- 向权威清单追加 `'/home/''zz-path-pr''obe-differential':1` 后：`n2=1`
- **差分 = 1 > 0**：门禁的对外表现（自报条数）随清单内容变化 ⇒ **门禁真读清单，非硬编码常量**。若门禁硬编码一个常量，改清单后自报不变 ⇒ 差分=0 ⇒ 判据红——本断言覆盖了「自报↔落档绑定」无法区分的硬编码态。

### 4.3 ④b 读序两态（常设 > 副本）

| 态 | 权威清单 | change 副本 | rc | 判据 |
|---|---|---|---|---|
| 健康态 | 在位 | 在位 | 0 | ✅ |
| ④a 差分态 | 在位（追加 1 条） | 在位 | 0（自报=1） | ✅ 差分成立 |
| **④b 读序态** | **缺失（mv 走）** | **在位** | **0** | ✅ 读序生效 |
| T21 双缺态 | 缺失 | 缺失 | 1 | ✅ fail-closed |

④b 与 T21 的「两份皆缺 ⇒ exit 1」**两态 rc 可区分**（0 vs 1）⇒ **读序「常设 > 副本」已实现**，非按任一清单存在即放行、也非两份皆缺才阻塞的不可区分态。

---

## 5. 6 维自查（书本驱动）

### 5.1 沿用既有抽象 grep（R6.4）

本任务是**判据实跑型任务**，`action` 不涉及新写代码能力，而是**实跑既有 T17/T21/T22/T23 定稿的门禁脚本**。grep 同类抽象：

```bash
grep -n 'check-path-privacy' Makefile                          # 命中（T18 接线点）
grep -n 'check-path-privacy' flow-kit-bundle/hooks/pre-commit/pre-commit.sh  # 命中（T20 源接入）
ls flow-kit-bundle/flow-kit/reference/check-path-privacy.sh     # 存在（T17/T22/T23 定稿）
ls flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt   # 存在（T21 权威冻结）
ls .specs/health-fix-2026-09b/path-privacy-allowlist.txt       # 存在（T21 副本冻结）
```
- 门禁目标 `check-path-privacy`、门禁脚本、允许清单（权威+副本）**均已存在**，本任务只实跑其判据，**不新建任何抽象** ✅

### 5.2 破坏性变更（R4.6 / 1.8）

本任务 `diff` 命中：
- 删除既有代码 ≥ 5 行？**否**（无代码删除）
- 改公共导出签名？**否**
- 改公共 API？**否**
- 删除文件 / 重命名导出符号？**否**

⇒ **不触发破坏性变更协议**。本任务对三个临时对象的改写是**受控临时改写**（先备份 → 探针期间 → 恢复 + `cmp -s`），非永久性破坏。

### 5.3 R1 认知过载

单步函数 ≤ 50 行 / 嵌套 ≤ 3 层：**不适用**（无新代码，verify 块为顺序断言） ✅

### 5.4 R2 变更传播

本次 diff 仅涉及 `T26-SUMMARY.md`（新增）+ `TASK.md`（T26 状态位 pending→done 单行）⇒ **无越界** ✅

### 5.5 R3 知识重复

无粘贴逻辑到 2+ 处 ✅

### 5.6 R5 依赖混乱

无 import 倒置 ✅

### 5.7 R6 领域扭曲

变量名 `printed`/`filed`/`n2`/`AL2` 均为判据域语义（自报条数/落档条数/差分后条数/权威清单）✅

### 5.8 越界检查（R6.5 / 5）

```
✅ TASK 声明的 write_files：
  - .specs/CONTEXT.md（临时）
  - flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt（临时）
  - .specs/health-fix-2026-09b/path-privacy-allowlist.txt（临时）

✅ 实际 diff 涉及（提交后）：
  - .specs/health-fix-2026-09b/T26-SUMMARY.md（新增 · 持久产物）
  - .specs/health-fix-2026-09b/TASK.md（T26 状态位单行改动）

→ 0 越界 ✅
```
三个临时对象均**已逐字节复原**（末段 `cmp -s`），不会出现在提交 diff 中。

---

## 6. 遗留

无遗留。判据未暴露产品缺陷；T21 冻结产物（权威清单）未被污染；三个临时对象均逐字节复原。T26 的 `depends_on`（T18, T21）均已 done。下游 T19（夹具复制终稿门禁脚本与已冻结清单）与 T24（重建分发件）可在本任务完成后开工。
