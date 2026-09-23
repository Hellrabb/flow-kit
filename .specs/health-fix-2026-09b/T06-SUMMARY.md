# T06-SUMMARY · health-fix-2026-09b

## 任务与契约

- **Change**: health-fix-2026-09b · **Task**: T06（阶段 4 · Wave 2 源修复层）
- **名称**: PC2：缺 jq 时 fail-closed 且不破坏既有 `settings.json`（入口校验 + 分支订正 + 原子写）
- **Write 面**（唯一源码）：`flow-kit-bundle/lib/install_hooks.sh`
- **契约要点**（取自 task-brief T06 `<action>` + `<verify>` + `<done>`）：
  - ① `install_hooks()` 入口加 `command -v jq` 硬校验：缺失 ⇒ 立即非零退出，且**在任何写盘之前**；目标使 `command -v jq` 命中 ≥2（入口 + `:211` 分支）。
  - ② 订正 `:211` 二值条件：「文件已存在 + jq 缺失」**不得**落下方 else（注释 `# 新建`）分支。
  - ③ 落盘改 `mktemp` + `mv` 原子写 + `trap 'rm -f "$tmp"' EXIT`（DESIGN R4）。
  - 保持 `install_hooks.sh` 只由 `install.sh` source（CONTEXT 禁动清单），不新增外部 source 点。
  - `<done>`：缺 jq 时非零退出、`settings.json` 未被截断为空、原 `permissions.allow` 与 `hooks.Stop` 均存活、顶层字段集合不变、文件**逐字节未变**（`cmp`）。

## 改动面

`flow-kit-bundle/lib/install_hooks.sh`（303 → 358 行，+65/-10）：

1. **`:36-60`** 新增 top-level helper `write_settings_file_atomic() { target content }`：`tmp=$(mktemp "${target}.tmp.XXXXXX")` → `trap "rm -f '$tmp'" EXIT`（`:54`）→ `printf '%s\n' "$content" > "$tmp" && mv "$tmp" "$target"` → 成功 `trap - EXIT` 返回 0；失败 `rm -f "$tmp"` + `trap - EXIT` 返回 1。**约定与原语沿用仓内既有范式**（`hooks/stop/lib/correction-file.sh:221/257/332`、`l2-detect.sh:318/433/477`）。
2. **`:101-109`** `install_hooks()` 入口硬校验：`if ! command -v jq >/dev/null 2>&1; then echo "   ❌ 缺少依赖 jq：… 已中止（尚未做任何写盘）" >&2; return 1; fi`。用 `return 1`（非 `exit 1`）以便 install.sh 的 `set -e` 转成整体非零退出，同时不杀掉直接 source 的测试 shell。
3. **`:250`** 分支判据订正：`if [ -f "$settings_target" ] && command -v jq &>/dev/null` → `if [ -f "$settings_target" ]`（**只看文件存在性**，DESIGN D7）。
4. **`:252-259`** merge 分支内加 jq 纵深防御（`:257` 失败 ⇒ `return 1` 且原文件不动）。
5. **`:281` / `:302`** 两处落盘改走 `write_settings_file_atomic`；「新建」分支不再使用 `> "$settings_target"`（jq 结果先落变量 `created`），**截断路径彻底消失**。
6. **`:284` / `:305`** merge/新建失败由「仅打 ⚠️ 且 rc=0」改为「⚠️ + `return 1`」（fail-closed 加强，见 MINOR-DEFERRED T06-4）。
7. 未改 `REQUIREMENT.md` / `DESIGN.md`（R3.2）；未扩范围（R7.1）；diff 中新增 `source` 行数 = **0**（禁动清单）。

## `<verify>` 逐字输出（`/tmp/t06v.sh` = task XML `<verify>` 段逐字落地，`bash -n` rc=0）

```
$ bash /tmp/t06v.sh
=== T06 verify (verbatim) rc=0 ===
```

verbatim 段无正面输出（每条 🔴 分支自带 `echo 🔴 …; exit 1`），rc=0 ⇒ 全部 🔴 分支**未被触发**。为证明每条判据真的执行到、且判在了"通过侧"，另跑同动作仪表化版 `/tmp/t06v-diag.sh`（逐条打印实际判定值）：

```
[after] 前提① 影子 PATH 内 jq 可见性: <none>
[after] 前提② 影子 PATH 内 mkdir 可见性: /tmp/l2-ac2-diag-oIFxkZ/shadow/mkdir
[after] install.sh rc=1   settings.json 字节: 120 → 120
[after] cmp 逐字节 vs orig.json: 相同
[after] ✅ 非空（未被截断为空）
[after] ✅ 逐字节未变
[after] ✅ rc 非零（fail-closed）
[after] ✅ 原 permissions.allow 存活
[after] ✅ 原 hooks.Stop[0].hooks[0].command 存活
[after] ✅ 顶层字段集合不变: ["hooks","permissions"]
[after] 静态判据: command -v jq=4 处  mktemp=2 处  install_hooks.sh=358 行
[after] install.sh 输出末行:
[after]      ❌ 缺少依赖 jq：install_hooks 需要 jq 合并 settings.json，已中止（尚未做任何写盘）
```

逐条回答任务 §5 要求：

| 判据 | 实测 |
|---|---|
| `cmp` 逐字节 | `cmp -s "$SET" "$SBX/orig.json"` **rc=0（逐字节相同）**；120 B → 120 B |
| `jq -e` hooks 断言 | `jq -e '.hooks.Stop[0].hooks[0].command == "true"'` rc=0（现有 hook 存活，未被 merge/覆盖） |
| 顶层字段集合断言 | `[ "$(jq -c 'keys' "$SET")" = '["hooks","permissions"]' ]` rc=0，实测值 `["hooks","permissions"]` |
| 静态判据 | `grep -c 'command -v jq'` = **4**（≥2）· `grep -c mktemp` = **2**（≥1） |
| 前提自检 | 影子 PATH 下 jq = `<none>`、mkdir = 影子内路径（两者都来自 §verify 原文，未放宽） |

> 注：本任务 fixture 字符串实测 **120 B**；任务 `<done>`/DESIGN 记录的「122 B」出自阶段 3 的另一份 fixture 文本，字节值差异只反映 fixture 长度，不改变结论（两态对照均为 0 B 截断）。

## 双态对照（L-120 强制 · before = `git show 534e3e8:flow-kit-bundle/lib/install_hooks.sh` → `/tmp/ih-before.sh`，303 行；bundle 副本 `/tmp/t06-before-bundle`，同沙箱同 harness）

```
############ BEFORE（534e3e8 未修复） ############
[before] install.sh rc=127   settings.json 字节: 120 → 0
[before] cmp 逐字节 vs orig.json: 不同
[before] 🔴 settings.json 被截断为空
[before] 🔴 缺 jq 时 settings.json 被改写
[before] 🔴 原 permissions.allow 丢失
[before] 🔴 原 hooks 字段被破坏
[before] 🔴 顶层字段集合变化: (空串)
[before] 静态判据: command -v jq=1 处  mktemp=0 处  install_hooks.sh=303 行
```

| 观测量 | before(534e3e8) | after(工作区) | 判定 |
|---|---|---|---|
| `install.sh` rc（`--global --no-brooks --user`，影子 PATH 无 jq） | **127** | **1** | 两态都非零，但失败**时机**不同 |
| `settings.json` 字节 | 120 → **0** | 120 → **120** | ✅ 结果不同（缺陷现场被消除） |
| `cmp` vs 原副本 | 不同 | **相同** | ✅ |
| 既有 `permissions.allow` / `hooks.Stop` / 顶层 keys | 全丢 | 全存活 | ✅ |

⇒ 判据**真正触达缺陷现场**（L-122）：失败在 after 态发生在**任何写盘之前**（output 末行即入口的 ❌ 报文），before 态则先毁数据再失败。`--global --no-brooks --user` 是唯一能触达截断行的 flag 组合（阶段 3 L-122 已定式，本任务复用同一组合）。

## 正路径语义等价（L-123：改造可执行构造后必须实跑断言产出等于原语义）

`/tmp/t06-pos-diag.sh <bundle> <tag>`：jq **可用**（真实 PATH）+ 沙箱 HOME，跑两轮（第 2 轮验幂等），归一化沙箱路径后 `jq -S` 全量比对 before/after：

| fixture | before rc / 字节 | after rc / 字节 | 幂等 sha 相同 | 残留 tmp 文件 | 归一化 JSON diff |
|---|---|---|---|---|---|
| `existing`（含 `permissions.allow` + 既有 `Stop` hook） | 0 / 1162 | 0 / **1162** | yes / yes | 0 / 0 | **逐行等价（diff rc=0）** |
| `absent`（无 settings.json，走"新建"分支） | 0 / 944 | 0 / **944** | yes / yes | 0 / 0 | **逐行等价（diff rc=0）** |

两态：`hooks 事件=["PreToolUse","Stop"]`、`各事件条目数=[2,3]`（existing）/ `[1,3]`（absent）、第 2 轮打印「已存在于」4 次（4 条接线幂等跳过）。⇒ 原子写**未改变任何可观测产出**，也未留临时文件（`trap - EXIT` 生效）。

**副作用实测**（登记 MINOR-DEFERRED T06-1/T06-2）：
- 权限 `stat -c %a`：644 → **600**（`mktemp` 默认 0600、`mv` 保留临时文件 mode）。
- `settings.json` 为 symlink 时：`[ -L ]` yes → **no**（`mv` 覆盖链接本身；link 目标仍留旧内容 40 B）。

## 沿用抽象的 grep 结果（R6.4 · 写码前实测）

```
$ grep -rn 'command -v jq' flow-kit-bundle/hooks flow-kit-bundle/lib --include='*.sh'
hooks/session-start/flow-kit-resume.sh:10:if command -v jq &>/dev/null; then
hooks/session-start/stop-report-reminder.sh:21:if command -v jq &>/dev/null; then
hooks/stop/lib/interactive-ui-check.sh:52 / :66:  if command -v jq &>/dev/null; then
hooks/stop/lib/common.sh:86:  if command -v jq &>/dev/null; then
hooks/stop/lib/common.sh:226:  command -v jq >/dev/null 2>&1 || return 1
hooks/stop/33-flow-active-integrity.sh:23:  command -v jq >/dev/null 2>&1 || return 0
hooks/pre-tool-use/auto-checkpoint.sh:64:  command -v jq >/dev/null 2>&1 || exit 0
hooks/pre-tool-use/independent-review-gate.sh:114:  command -v jq >/dev/null 2>&1 || exit 0
lib/install_brooks.sh:24 / :148 / :192:  if command -v jq &>/dev/null; then
（命中 9 文件 16 行）
```

⇒ 入口校验**沿用既有原语** `command -v jq >/dev/null 2>&1`（`common.sh:226` / `auto-checkpoint.sh:64` 同款），未自创探测方式。

```
$ grep -rn 'mktemp' flow-kit-bundle --include='*.sh' | grep -v install_hooks.sh   # 33 处
hooks/stop/lib/correction-file.sh:115/144/221/257/332:  tmp=$(mktemp "${path}.tmp.XXXXXX") || return 1 … mv
hooks/stop/lib/l2-detect.sh:318/433/477、l3-api.sh:99/168、l3-prompt.sh:499（同族范式）
（EXIT trap 唯一先例：lib/validate_staging.sh:40 `trap 'rm -f "$EXPECTED_FILE_LIST"' EXIT`；install.sh 不 source 它
 ⇒ install 路径无既有 EXIT trap，成功后 `trap - EXIT` 不会覆盖调用方 trap）
```

⇒ 原子写**沿用既有 `mktemp "${path}.tmp.XXXXXX"` + `mv` 范式**，仅按 DESIGN R4 增补 `trap` 清理（既有 11 处无 trap）。

```
$ grep -rn 'write_settings_file_atomic' --include='*.sh' --include='*.bats' . | grep -v install_hooks.sh | wc -l
0                                  # 新 helper 名全仓无冲突
$ git diff flow-kit-bundle/lib/install_hooks.sh | grep -c '^+.*source'
0                                  # 未新增外部 source 点（禁动清单）
```

## 门禁实跑（全部真实执行）

| 门禁 | rc | 关键输出 |
|---|---|---|
| `bash -n flow-kit-bundle/lib/install_hooks.sh` | 0 | — |
| `./sync-hooks.sh` | 0 | `✅ 全部副本已一致，无需同步`（6 面） |
| `bash sync-hooks.sh --check` | 0 | `✅ hooks 副本一致（漂移 0）` |
| `make check-hooks-sync` | 0 | `✅ hooks 副本一致（漂移 0）` |
| `make check-test-sync` | 0 | `✅ test 双源一致` |
| `make check-dist`（改源后首跑） | **2** | `❌ 陈旧: dist/dsh-flow-kit/vendor/flow-kit-bundle/lib/install_hooks.sh（内容与 …/flow-kit-bundle/lib/install_hooks.sh 不一致 → 请重建 dist）` |
| `bash package-dsh-plugin.sh` → `make check-dist` | 0 / 0 | `✅ check-dist: dist 与源一致` |
| `make dsh-sync` | 0 | `✅ 已同步（web profile）` |
| 安装镜像逐字节（`cmp`） | 0 | `~/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/lib/install_hooks.sh` = 18695 B，与源逐字节一致 |
| `make test` | **0** | TAP 末行 `ok 973 CF-03: clear_compliance_correction removes the file`、`✅ bats: all tests passed`（0 not ok） |

**bats 数字与基线一致**：基线 973 ok / 0 not ok / rc=0 → 本任务实测 **973 ok / 0 not ok / rc=0**（无变化，无需解释差异）。

**工艺空洞（登记 MINOR-DEFERRED T06-5）**：`./sync-hooks.sh` 的 `collect_rel_paths` 只枚举 `hooks/{stop,stop/lib,pre-tool-use,session-start,pre-commit}` + `flow-kit/prompts/**` + opencode agent ⇒ **`lib/install_hooks.sh` 不在同步面内**，`漂移 0` 对它无覆盖力；`lib/**` 源改动必须 `bash package-dsh-plugin.sh` + `make dsh-sync` 才能让 `check-dist` 绿、安装镜像新（本次实测：不同步则 check-dist rc=2）。`dist/` 被 `.gitignore:63` 忽略 ⇒ 上述同步**不进入 git 边界**（0 越界）。

## 6 维自查（R1–R6 内置快查；brooks-lint 未安装 → 路径 B）

| 维度 | 结果 | 说明 |
|---|---|---|
| R1 认知过载 | 🟡 已知接受 | 新增 helper 21 行（单层 if + 单层 if，嵌套 ≤2）；`install_hooks()` 本体 +11 行（总数 224 → 235 行，**超 50 行属 pre-existing**，本次未新增嵌套层）；`_install_hook_wiring` 4 处写盘/报错分支收敛为 2 次 helper 调用，认知单元**减少** |
| R2 变更传播 | ✅ | 源码 diff 仅 `flow-kit-bundle/lib/install_hooks.sh` 1 文件；新增 top-level 名 `write_settings_file_atomic` 全仓 0 冲突；未新增 source 点；dist/安装镜像同步属 gitignore 构建产物 |
| R3 知识重复 | ✅ | 原子写由「2 处内联 `>` 写盘」收敛为 1 个 helper，并复用既有 `mktemp+mv` 范式与 `command -v jq` 原语；未复制粘贴 |
| R4 偶然复杂 | 🟡 已知接受 | `trap "rm -f '$tmp'"` 需**立即展开**（局部变量），已加 SC2064 disable + 注释说明；`trap - EXIT` 撤销在 install 路径安全（实测无既有 EXIT trap）。属 DESIGN R4 强制要求的复杂点，非投机扩展 |
| R5 依赖混乱 | ✅ | 无新依赖（jq 本就是硬依赖，现已**显式**化）；无反向依赖；`install_hooks.sh` 仍只被 `install.sh` source |
| R6 领域扭曲 | ✅ | 命名沿用领域词：`settings_target` / `settings.json` / `merge` / `新建` / `hook 接线` |

🔴 0 · 🟡 2（R1 pre-existing 函数长度、R4 trap 立即展开 —— 均已注明可接受/已注释）· 🟢 3（T06-3 DRY_RUN 行为、T06-4 失败 rc 加强、T06-5 同步面工艺空洞）→ 全部登记 `.specs/health-fix-2026-09b/MINOR-DEFERRED.md`。

## TDD 声明

**bats 载体：文件级存在，AC-2 判据级不存在。**
- 存在：`grep -rln 'install_hooks' test/*.bats` = `test_install_dry_run.bats:32/47`、`test_install_coverage.bats:51…267`、`test_archive_commit_gate.bats:104-109/140/155`（均走 `DRY_RUN=true` 或静态提取，**在 DRY_RUN 早退点之前就 return，覆盖不到写盘路径**）。
- 不存在：「缺 jq / 遮蔽 PATH」用例 = 0；`settings.json` 相关 bats 断言仅 `test_install_dry_run.bats:20-39`（DRY_RUN 不变性）。新增一条 AC-2 用例须改 `test/**`，**不在本 task 的 write_files**（任务 §4 明令不新增测试文件）。
- ⇒ 按任务 §4 以 **verify 全文逐字实跑 + fixture 双态对照**承担，替代证据 5 条：
  1. `/tmp/t06v.sh`（XML `<verify>` 逐字）rc=0，含 8 条自带 `exit 1` 的 🔴 分支（L-121）；
  2. 仪表化版逐条打印实际判定值（上表）——证明判据执行到且判在通过侧，非空集恒真；
  3. 双态对照（L-120）：before 120→0 B / after 120→120 B，两态结果不同；
  4. 正路径语义等价（L-123）：existing/absent 两 fixture 归一化 JSON 逐行等价，`make test` 973 ok 未变；
  5. `bash -n` rc=0 + 静态判据（`grep -c` 两态 1/0 → 4/2）。
- **建议（不在本任务写面）**：由 T25「副本面收口」或阶段 5 补一条 bats 用例，直接复用 `/tmp/t06v-diag.sh` 的影子 PATH 构造，断言 `rc≠0` + `cmp` 逐字节 + 既有 hook 存活（现有 3 个 bats 文件只覆盖 DRY_RUN 分支，是本 task 无法 TDD 先行的唯一原因）。

## 越界检查（R6.5）

```
✅ 越界检查（R6.5）：
   - TASK write_files：1 项（flow-kit-bundle/lib/install_hooks.sh）
   - 实际 diff 涉及（本任务提交面）：4 项
       flow-kit-bundle/lib/install_hooks.sh          ← write_files
       .specs/health-fix-2026-09b/TASK.md            ← 任务授权（仅 T06 status: pending→done）
       .specs/health-fix-2026-09b/T06-SUMMARY.md     ← 任务授权（新建）
       .specs/health-fix-2026-09b/MINOR-DEFERRED.md  ← 任务授权（追加）
   - 越界：0
```

未提交面（进入本任务前已存在的 workspace 变更，非 T06 产物，**不 add**）：
- `M .specs/CONTEXT.md`、`M .specs/STATE.md`
- `?? .specs/adr/028-gate-baseline-allowlist.md`、`.specs/health-fix-2026-09b/{CHANGE.md,INDEPENDENT-REVIEW-1..3.md,REQUIREMENT.md}`、`.specs/health/2026-09-22-FULL-SWEEP.md`
`git add` 只列显式路径（上述 4 项）；**未使用** `git commit --no-verify`（L-126）。

## 遗留/移交项

- **T25 / 阶段 5 建议**：补 AC-2 bats 用例（见 TDD 声明建议段）。
- **v2（PC13 / §0.5.2 原子写统一）**：mode 保留（T06-1）、symlink 解析（T06-2）、`lib/**` 纳入 sync-hooks 面（T06-5）。
- **构建产物已同步**：`dist/` 重建 + `make dsh-sync`（安装镜像 18695 B 逐字节一致）；二者均 gitignore，不入库。
- **工作区无临时产物残留**：`/tmp` 沙箱（`/tmp/l2-ac2-*`、`/tmp/t06-pos-*`）不属仓库；`git status --short` 无新增未跟踪文件。
