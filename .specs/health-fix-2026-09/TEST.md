# TEST — health-fix-2026-09（阶段 5）

- **Change ID**: health-fix-2026-09
- **关联**: `@.specs/health-fix-2026-09/REQUIREMENT.md`（11 条 AC）、`TASK.md`（8 任务）、`DESIGN.md`
- **测试日期**: 2026-09-20

---

## 1. 测试矩阵（AC → 用例 → 结果）

| AC | 用例 | 方式 | 结果 |
|---|---|---|---|
| AC-1 | 改源不重建 → `make check` 变红并指名 | `verify/ac1.sh` | ✅ PASS |
| AC-2 | dist 一致 → `check-dist` 放行（反例保护） | `verify/ac2.sh` | ✅ PASS |
| AC-3 | `install.sh` 注入语法错误 → `make lint` 抓到 | `verify/ac3.sh` | ✅ PASS |
| AC-4 | `make lint` 自报清单覆盖率 100% | `verify/ac4.sh` | ✅ PASS |
| AC-4b | 排除集与契约**结构性一致**（组件集双向比对） | `verify/ac4b.sh` | ✅ PASS |
| AC-4c | 扫描集 ∪ 契约排除集 == 全仓 `.sh` 集 | `verify/ac4c.sh` | ✅ PASS |
| AC-5 | 健康态 `缺可执行位` 计数 0 且 rc=0 | `verify/ac5.sh` | ✅ PASS |
| AC-6 | 真入口摘 exec 位 → 检出并**指名** | `verify/ac6.sh` | ✅ PASS |
| AC-7 | 全量回归六项 | `verify/ac7.sh` | ✅ PASS |
| AC-8 | 夹具实跑后工作区 + dist 文件集 + dist 权限位 三项无变化 | `verify/ac8.sh` | ✅ PASS |
| AC-9 | 三载体可追溯理由注释 | `verify/ac9.sh` | ✅ PASS |

> **AC-4b 覆盖缺口已消解（L3 阶段5 C2 → 本轮补 `verify/ac4b.sh`）**：初版登记「AC-4b 无独立机器断言」，本轮回补结构性夹具（组件集双向比对，实测可抓「静默新增」与「静默删除」两个方向）。原专节已并入 §1 的口径变更史。

**功能轮覆盖率：11/11 条 AC 均有可执行夹具**。

| 口径 | 值 |
|---|---|
| AC 总数 | 11（AC-1..AC-9、AC-4b、AC-4c） |
| 有独立可执行夹具的 AC | **11 条** → `verify/ac1..ac9.sh` + `ac4b.sh` + `ac4c.sh`（共 **11** 个夹具） |
| 无机器断言的 AC | **0 条** |

> **口径变更史（留痕，勿删）**：
> ① 初版写「11/11 AC = 100%」但当时**只有 9 个夹具、AC-8 是散文** → **不实**（L2 阶段5 R1 抓出）；
> ② 修 AC-8 后仍写「10/11」（因 **AC-4b 确无夹具**）→ 与 §2 标题的「100%」**自相矛盾**（L3 阶段5 C1 抓出）；
> ③ **本轮补 `verify/ac4b.sh`**（结构性判据：排除集组件集 vs 契约表，双向可证伪）→ 覆盖达 **11/11**，矛盾消解。

> **⚠️ 本行曾写「11/11 AC = 100%（每条 AC ≥ 1 条可执行用例）」—— 与同文件 AC-4b 标注的「⚠️ 无独立机器断言」自相矛盾，属覆盖声明不实。** 由 L3 阶段 5 以 Critical 抓出，已按上表更正。

> **L2 阶段5 R1 的处置留痕**：该断言初版为「11/11 AC = 100%（每条 AC ≥ 1 条可执行用例）」，但当时 `verify/` 只有 **9** 个夹具（无 ac8.sh），AC-8 的"方式"列写「见 §4」散文 —— **自述与事实不符**。已补 `verify/ac8.sh`（三项基线比对：git 工作区 / dist 文件集 / **dist 权限位**），夹具数 9 → **10**，该断言现成立。

### AC-6 的强度说明（如实）

DESIGN D5 定案 exec 告警**维持 advisory**（不升级 fail），故 AC-6 断言的强度是「**输出指名该文件**」而非「非零退出」—— 测试按该强度如实断言，未放宽、未夸大。

---

## 2. 五轮金字塔

### 第 1 轮 · 功能（**11/11 AC 均有可执行夹具** —— 见 §1 覆盖口径与变更史）

见 §1。全部 **11** 个夹具**实跑**通过（非纸面断言；`ac4b.sh` / `ac8.sh` 为后续审查补入，见 §1 变更史）。

### 第 2 轮 · 性能

| 项 | 实测 |
|---|---|
| `time bash package-dsh-plugin.sh --check` × 3 | **0.61s / 0.61s / 0.60s**（中位数 **0.61s**） |
| NFR 门槛 | ≤ **2s** → **通过**（余量 ~3.3×） |
| 实测夹具 | 当前仓库（dist 全量 525 文件，vendor 含 `test/`） |
| `make check` 整体 | 4m12s（受 `make test` 主导；新增 check-dist 占 0.61s，可忽略） |

> **诚实修正（含方向更正 · L3 阶段5 minor3）**：DESIGN §2.3 曾据「4 条 `diff -rq`」把 check-dist 估计为 **13ms**；真实实现是**逐文件 `cmp` 遍历**，实测 **0.61s**。
> **方向说明（避免歧义）**：0.61s **比 13ms 慢**，是后者的 **47 倍**（即原估计**快了 47 倍**、严重偏低），**不是**「快 47 倍」。结论不变：0.61s **仍远优于 2s 门槛**（余量约 3.3×）。

### 第 3 轮 · 安全（只读契约）

| 断言 | 结果 |
|---|---|
| `--check` 前后 dist `mtime` | 未变 ✅ |
| `--check` 前后 dist 文件数 | 525 → 525 ✅ |
| `--check` 后 `git status --porcelain dist/` | 0 项 ✅ |
| 未知参数 `--bogus` | rc=**2** + usage（fail-closed，不静默忽略）✅ |
| 退化为"重建"的风险 | 已阻断（`--check` 在 `node -p` **之前**分流；输出无 `==> packaging` 横幅）✅ |
| **dist 内容哈希**（L3 阶段5 M5 补：比 mtime/文件数更强） | 运行前后 `find dist -type f -exec md5sum {} + \| sort -k2 \| md5sum` **一致** ✅ |
| 实施证据 | `--check` 路径只调 `check_dist()`，其函数体**可执行代码零写操作**（纯 `find`+`cmp`+`printf`）；grep `\bcp\b\|\bchmod\b\|\brm\b\|\bmkdir\b` 命中 2 处，**均为注释**（一处说明映射与第 1-5 步的 `cp` 同源，一处说明为何不比 mode）—— 已逐条核对 |

**这一轮针对的是本 change 自身的核心风险**：一个"只读"契约若退化成"照常重建并 exit 0"，就会变成**篡改被检查对象**的假门禁（L-097 记录的既有隐患）。已实测排除。

### 第 4 轮 · 兼容性

| 断言 | 结果 |
|---|---|
| 是否用 GNU 专属选项（`cmp --`、`find -printf`、`head -n -`） | **0 处** ✅ |
| `cmp -s`（POSIX，GNU/BSD 语义一致） | 2 处 · 沿用 `sync-hooks.sh` 既有先例 ✅ |
| 工具缺失优雅降级（shellcheck 未装 → 提示 + 非阻塞） | 保留 ✅ |
| dist 不存在 → 提示 + `exit 0` | 实测 ✅（T01 边界测试） |
| 新依赖 | **零**（仅 coreutils）✅ |

### 第 5 轮 · 可观测性（失败信息可定位）

注入一处源改动后 `--check` 的输出：

| 断言 | 结果 |
|---|---|
| 指名**具体文件路径** | 「❌ 陈旧: …/dist/dsh-flow-kit/README.md」✅ |
| 给出**修复命令** | 「→ 修复: bash package-dsh-plugin.sh」✅ |
| 给出**操作顺序提示** | 「若改过 test/，先 make test-sync，再重建 dist」✅ |
| 反向残留场景指名 | 「❌ 反向残留: …/hooks/__probe__/ghost.sh」✅ |

---

## 3. AC-7 全量回归（与 t=0 基线对比）

| 指标 | 基线（本 change 前） | 现在 | 判定 |
|---|---|---|---|
| `make test` | 950 ok / 0 not ok / 1 skip | **950 / 0 / 1** | ✅ 无退化 |
| `make lint` error 级 | 0 | **0** | ✅ |
| `make check-validate` | 漏配 0 / 源缺失 0 | **0 / 0** | ✅ |
| `make check-test-sync` | 一致 | **一致** | ✅ |
| `make check-hooks-sync` | 漂移 0 | **漂移 0** | ✅ |
| `make verify-claims` | 13 ✅ / 0 ❌ | **13 / 0** | ✅ |
| `make check` 门数 | **5** | **6** | ✅ 按设计增加 |

**6 门的组成**（`Makefile:105` 的 `check:` 依赖，按序）：

```
check: test  lint  check-validate  check-test-sync  check-hooks-sync  check-dist
       ①     ②        ③                 ④                ⑤           ⑥(新增)
```

> **`make verify-claims` 不属于这 6 门** —— 它是**独立 target**（`Makefile:86`），不被 `check:` 依赖，
> 故 pre-push 的 `make check` **不会**跑它。本表把它单列，是因其为本 change 的回归指标（F6 耦合项），
> **不代表它是门禁之一**。
| `make check` 整体 | rc=0 | **rc=0** | ✅ |

**新门禁的负向能力（"不是恒绿"的证明）**：

| 注入 | 结果 |
|---|---|
| 改源不重建 → `check-dist` | rc=1，指名文件 ✅ |
| dist 反向残留 | rc=1，指名路径 ✅ |
| vendor `test/` 陈旧（本次真实事故形态） | rc=1，指名 `vendor/.../test/*.bats` ✅ |
| 向 7 个漏扫脚本之一注入语法错误 → `lint` | rc=1，指名 ✅ |
| 摘真入口 exec 位 → `hooks-sync` | 输出指名该入口 ✅ |
| 摘库文件 exec 位 → `hooks-sync` | **不报**（收窄正确）✅ —— 可复现：`chmod -x dist/dsh-flow-kit/hooks/pre-tool-use/gate-helpers.sh && make check-hooks-sync; chmod +x …`；此断言是 AC-6 的**反例保护**（证明判据是「收窄」而非「删除」） |

**判据有真实证明力**：每条新门禁都实测过"注入 → 变红 → 还原 → 恢复绿"，**没有一条是恒绿**。

---

## 4. AC-8 验证卫生

**10** 个夹具实跑完毕后（`ac8.sh` 自身即断言本项）：

```
$ git status --porcelain
（仅本 change 的预期改动：Makefile / package-dsh-plugin.sh / sync-hooks.sh / verify-claims.sh
  + .specs 工件；**无夹具残留**）
```

**还原方式**（按目标是否被 git 跟踪区分，已实测各自有效）：
- 被跟踪文件（`README.md` / `install.sh`）→ `git checkout -- <file>`（内容与权限一并复原）
- 被忽略文件（`dist/**.sh`）→ `chmod +x`（`git checkout` 对 ignore 文件报错且不还原权限 —— 已实测确认）

---

## 5. UAT 脚本（可复现，逐条可跑）

```bash
cd ~/unisoc/flow-kit

# UAT-1 · 核心能力：陈旧必须被拦
bash .specs/health-fix-2026-09/verify/ac1.sh      # 期望 ✅ AC-1 PASS

# UAT-2 · 反例保护：一致必须放行
bash .specs/health-fix-2026-09/verify/ac2.sh      # 期望 ✅ AC-2 PASS

# UAT-3 · lint 覆盖率
bash .specs/health-fix-2026-09/verify/ac4.sh      # 期望 ✅ AC-4 PASS
bash .specs/health-fix-2026-09/verify/ac4c.sh     # 期望 ✅ AC-4c PASS

# UAT-4 · exec 判据两向
bash .specs/health-fix-2026-09/verify/ac5.sh      # 期望 ✅ AC-5 PASS
bash .specs/health-fix-2026-09/verify/ac6.sh      # 期望 ✅ AC-6 PASS

# UAT-5 · 回归与注释
bash .specs/health-fix-2026-09/verify/ac3.sh      # 期望 ✅ AC-3 PASS
bash .specs/health-fix-2026-09/verify/ac9.sh      # 期望 ✅ AC-9 PASS
bash .specs/health-fix-2026-09/verify/ac7.sh      # 期望 ✅ AC-7 PASS（实测 379.3s ≈ 6m19s）
bash .specs/health-fix-2026-09/verify/ac4b.sh     # 期望 ✅ AC-4b PASS（排除集结构性一致）
bash .specs/health-fix-2026-09/verify/ac8.sh      # 期望 ✅ AC-8 PASS（卫生：含 6 个注入类夹具，实测约 12 分钟）

# UAT-6 负向前置（L3 阶段5 M3 补）：证明 check-dist 非恒绿
# 注意：**不用 git stash**（L3 阶段5 major3）—— stash 会连带隐藏工作区既有改动，
# 且失败时被 `|| true` 静默吞掉，可能污染后续 make check 的基线。
printf '\n<!-- negative probe -->\n' >> dsh-flow-kit/README.md
make check-dist 2>&1 | tail -2                     # 期望 rc≠0 且指名 README.md
git checkout -- dsh-flow-kit/README.md             # 精确还原该文件（内容+权限）
bash .specs/health-fix-2026-09/verify/ac2.sh       # 期望 ✅ AC-2 PASS（基线已恢复）

# UAT-6 · 全量门禁
make check                                        # 期望 rc=0 · 6 门全绿
```

**实测耗时（L2 阶段5 R2 修正）**：

| 组 | 实测 | 说明 |
|---|---|---|
| ac1 | **492.8s（8m13s）** | 内含 **2 次全量 `make check`**（其中 `make test` 约 2.5 分钟/次），输出进 /dev/null → 前 8 分钟屏幕无输出 |
| ac2 | **243.0s（4m03s）** | 含 1 次 `make check` |
| ac2/ac4/ac4c/ac5/ac6/ac9 | 合计见下 | 大多 <1s；ac4c/ac4 约 1s |
| **UAT-1..5（除 ac7）合计** | **约 12m43s** | 初版写"约 4 分钟"，**实测差 3.2 倍**，已更正 |
| ac7 | **379.3s（6m19s）** | 六项回归含 bats 全量 |
| UAT-6（`make check`） | **4m13.5s** | 与 §3 的 4m12s 同量级（同一命令，波动 1.5s） |

> **耗时差异说明（L3 阶段5 minor1）**：`ac7`（6m19s）比 `make check`（4m12s）**更慢**，因为 `ac7` 除六项断言外**再单独跑一遍 bats 全量**（`npx bats test/`），而 `make check` 内部的 `make test` 已含 bats —— 即 ac7 ≈ bats×2 + 其余五项 + make check 的重叠部分。二者不是同一场景，差异属**设计使然**（ac7 要独立留证，不依赖 make check 的通过与否）。

> **诚实记录**：初版把 UAT 耗时估为"约 4 分钟"，与自身 §3 记录的 `make check`=4m12s **自相矛盾**（ac1 单独就含 2 次全量 make check）。已按实测更正。

---

## 6. 未覆盖 / 已知限制（如实登记，不掩盖）

| 项 | 说明 |
|---|---|
| **真入口清单漂移** | DESIGN R4/§6 已登记：本 change 交付"判据正确 + 假阳性消除 + 检出时指名"，**不交付"清单永不漂移"**。新增 `pre-tool-use` 入口若忘记登记 `PTU_ENTRIES`，将漏检。缓解：白名单处有显式注释要求登记。 |
| **`verify-claims.sh` §10c 的已提交场景** | 基线改为"工作区改动"后，**已提交**的本 change 改动不在检查范围（开发期语义）。若需覆盖已提交改动，需提交前跑该脚本。已在脚本注释中说明。 |
| **性能估计偏差（已全量清账）** | ① DESIGN 曾估 check-dist 为 13ms，实测 **0.61s**；② DESIGN 同表曾估 `make check` 为"约 60–120s"，实测 **4m13.5s**。两处估计方法（抽样 `diff -rq` / 直觉）均低估。**生产载体的假陈述已清除**：`Makefile:118` 原写"实测 13ms 量级"已改为"实测 **0.61s**"（13ms 仅作为"设计期估计偏低"的解释性引用保留）。 |
| **夹具并发隔离（本次新发现并修复）** | 初版夹具共用固定 `/tmp/ac*.log`，**无法并发执行**（会互相覆盖）—— 本次实测中一度因此让 ac8 的结论不可信（我并发手改 Makefile 时 ac8 在跑）。已为全部 10 个夹具注入 `TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT`，并**并发实测 ac4 + ac4c 双双 PASS** 验证隔离生效。 |
| **`vendor/` 权限位** | 打包脚本的 `chmod` 只作用于包顶层，vendor 内副本权限不镜像源。**零功能影响**（vendor 是冻结审计副本，运行时从不执行），已在 M-health 报告中判定，本 change 未处理。 |

---

## 7. 原始输出留证

| 证据 | 位置 |
|---|---|
| **11** 个夹具实跑输出 | 本文件 §1 表格 + `DEV-SUMMARY.md`（`ac8.sh` 为 L2 阶段5 R1 后补） |
| §4 卫生断言的**实际输出** | 下方「卫生留证」块（L3 阶段5 M4 补） |

### 卫生留证（`ac8.sh` 全部夹具跑完后，独占执行）

```
$ git status --porcelain
 M Makefile            # 本 change 的 R4 修复（13ms → 0.61s）
 M verify-claims.sh    # 本 change 的 R7 修复（空集语义 + 计数）
?? .specs/adr/010-gates-surface-not-threshold.md
?? .specs/health-fix-2026-09/

$ find dist -type f | wc -l          → 534   （基线 534，未变）
$ find dist -type f -printf '%m %p\n' | sort | md5sum  → 与基线一致（权限位未变）
```

即：**无任何夹具残留**；仅本 change 自身的两处诚实性修复。
`ac8.sh` **自身即断言这三项**（git 工作区 / dist 文件集 / dist 权限位），故该卫生性是**机器可验**的，非人工转述。
| AC-7 六项 | 本文件 §3 |
| `make check` 完整输出 | 4m12s · rc=0（**可复现命令**：`make check`；本 change 未落盘 .log 文件 —— 初版指向"任务执行记录"属**不可复现的引用**，已更正为命令本身） |
| 性能计时 | 本文件 §2（0.61s 中位数） |
| 越界检查 | `DEV-SUMMARY.md` §越界检查 |
