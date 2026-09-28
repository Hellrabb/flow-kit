# T19-SUMMARY · AC-3 端到端四形态 push 拦截（隔离 bare remote 实跑）

> 变更：`health-fix-2026-09b` · 任务 T19 · 阶段 4（DEV）
> 验收：AC-3（When①②③④ + Then「指出哪个 ref 含泄漏」+ 干净 ref 不误拦）
> 本任务无仓内写面（write_files 仅 `/tmp` 沙箱）；持久产物 = 本 SUMMARY + TASK.md 状态位。

## 0. 结论

✅ **AC-3 端到端判据全部满足**。T11 修复轮 1（commit `4b2971e`）把 `pre-push.sh:30` 的 `CHECK_REF` 改为 `CHECK_REV`（传被推送对象的 local sha）后，pre-push hook 现按设计逐 ref 扫描**被推送的 ref 树**（`check-path-privacy.sh` 的 `CHECK_REV` 评估面），归因准确：

- 四形态（`push origin main` / `push --all` / `push --mirror` / `push origin --tags`）全部被拦截且报文**指名泄漏 ref**（前三个指名 `refs/heads/main`，`--tags` 指名 `refs/tags/v1`）；
- EVAL-FACE 判别子（HEAD=develop、工作树干净、泄漏仅在 main 历史树）仍被拒且指名 `main`（旧行为会整批放行）；
- ATTRIBUTION（摘掉 hook ⇒ 同一泄漏 push rc=0）证明拦截确由 hook 产生；
- CLEAN-PASS（`push origin develop` 成功 + 远端 `refs/heads/develop` 存在）证明干净 ref 不被误拦。

⚠️ **verify 脚本自身的 set -e 陷阱（非产品缺陷）**：TASK.md `<verify>` 块第 860 行 `out=$(git $form 2>&1); rc=$?;` —— 赋值语句继承 push 的 rc=1，`set -euo pipefail` 在 `rc=$?` 捕获之前就退出脚本，导致字面脚本在 FORM1 处提前终止（rc=1）。**判据本身满足**（已用 `out=$(...) || rc=$?; rc=${rc:-0}` 模式 + 带输出捕获的仪器化运行双重验证）。这是 verify 脚本的 bash set -e 语法缺陷，不反映产品故障。

## 1. 交付物

本任务无仓内文件改动（write_files = 仅 `/tmp` 沙箱操作）。持久产物：

- `.specs/health-fix-2026-09b/T19-SUMMARY.md`（本文件）
- `.specs/health-fix-2026-09b/TASK.md` 的 T19 状态位（`pending` → `done`）

沙箱夹具与复制件清单（执行后已 `rm -rf` 清理）：

| 沙箱路径 | 用途 |
|---|---|
| `$SBX/remote.git` | bare remote（`git init --bare`） |
| `$SBX/repo` | 夹具仓库（`git init` + Makefile 桩 + 分支拓扑） |
| `$SBX/home` | 假 HOME（仅用于 `install.sh --project --no-brooks` 那一命令） |

复制件（从本项目树 `$ROOT/flow-kit-bundle/flow-kit/reference/` 复制到夹具的 `flow-kit-bundle/flow-kit/reference/`）：

- `check-path-privacy.sh`（T17 真实门禁脚本，19202 B）—— 含 `CHECK_REV` 评估面入口（`check-path-privacy.sh:90` `if [ -n "${CHECK_REV:-}" ]`）
- `path-privacy-allowlist.txt`（T21 已冻结权威清单，1006 B，0 条允许）

Makefile 桩（夹具仓库根）：

```makefile
check: check-path-privacy
check-path-privacy:
	bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
```

分支拓扑：先 `develop`（干净，`clean.txt`，commit "clean fixture"）；再 `--orphan main`（与 develop 无共同祖先），在 main 上放 `leak.txt`（内容 `printf '/home/%s/leak\n' "$(whoami)"`）并打 tag `v1`。

## 2. 判据实跑（命令 + 关键输出 + rc）

仪器化捕获脚本 `/tmp/v19capture.sh`（`set -uo pipefail`，逐形态打印 rc + 实际报文 + 指名 ref 断言）：

### 桩自检（L-122/L-123）

- 干净态（develop，工作树仅 `clean.txt`）：`make check-path-privacy` → 扫描面=工作树，清单外命中 0 条 → **rc=0 ✅ 绿**
- 泄漏态（main，工作树含 `leak.txt`）：`make check-path-privacy` → 扫描面=工作树，清单外命中 1 条，归因 `leak.txt:1: /home/<acct>/leak` → **rc=2 ✅ 红**

### 部署

`HOME="$SBX/home" bash "$ROOT/flow-kit-bundle/install.sh" --project "$SBX/repo" --no-brooks` → `.git/hooks/pre-push` 存在（symlink → `$SBX/repo/.claude/hooks/pre-push/pre-push.sh`）✅

### 四形态（每形态 rc + 指名 ref）

| 形态 | rc | 扫描面序列 | 指名 ref | 结论 |
|---|---|---|---|---|
| `git push origin main` | 1（非 0 ✅） | main 树（`9add73…`）→ 命中 1 | `refs/heads/main` ✅ | 拦截 + 指名 main |
| `git push --all`（HEAD=main） | 1（非 0 ✅） | develop 树（`540887…`）→ 命中 0 放行 → main 树（`9add73…`）→ 命中 1 | `refs/heads/main` ✅ | **修复点**：逐 ref 扫描，归因 main（上一轮错位指名 develop） |
| `git push --mirror` | 1（非 0 ✅） | develop 树 → 放行 → main 树 → 命中 1 | `refs/heads/main` ✅ | 拦截 + 指名 main |
| `git push origin --tags` | 1（非 0 ✅） | v1 注解 tag → `${CHECK_REV}^{commit}` 解析 → main 树 → 命中 1 | `refs/tags/v1` ✅ | 拦截 + 指名 v1 |

各形态报文摘要（去 shape 后）：

```
FORM1/2/3:
  🔴 拒绝推送 refs/heads/main：该 ref 含路径隐私泄漏（make check-path-privacy 未通过）
  error: 无法推送一些引用到 '<remote>'
FORM4:
  🔴 拒绝推送 refs/tags/v1：该 ref 含路径隐私泄漏（make check-path-privacy 未通过）
  error: 无法推送一些引用到 '<remote>'
```

FORM2 关键 trace（修复证据）：hook 逐行读 stdin，先收 `refs/heads/develop` → `CHECK_REV=<develop-sha>` make → 扫描面=`540887…`（develop 树）→ 清单外命中 0 条 → rc=0 放行；再收 `refs/heads/main` → `CHECK_REV=<main-sha>` make → 扫描面=`9add73…`（main 树）→ 清单外命中 1 条 `leak.txt:1: /home/<acct>/leak` → rc=2 → 报文指名 `refs/heads/main` 拒绝。

## 3. 桩自检与归因对照

- 桩自检：干净态绿（清单外命中 0 条，rc=0）/ 泄漏态红（清单外命中 1 条，rc=2）✅
- ATTRIBUTION（归因对照）：
  1. `mv .git/hooks/pre-push "$SBX/pre-push.off"`（摘掉 hook）
  2. `git push origin main` → **rc=0** ✅（泄漏 push 成功，证明拦截确由 hook 产生，非夹具自身故障）
  3. `mv "$SBX/pre-push.off" .git/hooks/pre-push`（恢复 hook）
  4. `git -C "$SBX/remote.git" update-ref -d refs/heads/main`（清远端残留）

## 4. 评估面判别子与干净 ref 放行

### EVAL-FACE 判别子（L-131）

`git checkout -q develop`（工作树干净，泄漏只在 main 的历史树里）后 `git push --all`：

- 扫描面序列：develop 树（`540887…`）→ 命中 0 放行 → main 树（`9add73…`）→ 命中 1
- **rc=1 ✅**（仍被拒，未整批放行）
- 报文指名 `refs/heads/main` ✅（归因准确，非工作树扫面错位）

这证明 hook 扫的是**被推送的 ref 树**而非共享工作树——正是 T17 `CHECK_REV` 评估面入口的设计目的（TASK.md:714）。

### CLEAN-PASS（干净 ref 放行）

`git checkout -q develop; git push origin develop`：

- **rc=0 ✅**（干净 ref 未被误拦）
- hook trace：先 `CHECK_REV=<develop-sha>` 扫 develop 树 → 命中 0 → 再扫工作树（`扫描面: 工作树`，此时 HEAD=develop 工作树无 leak）→ 命中 0 → 落到 `make check` → rc=0
- 远端 ref 存在性证据：`git -C "$SBX/remote.git" rev-parse --verify refs/heads/develop` → 返回 sha `5408874440bba6ee81c63d8f1c270090dd203c06` ✅
- git 输出：`* [new branch] develop -> develop`

## 5. 门禁与回归表

| 门禁 / 回归 | 命令 | 结果 |
|---|---|---|
| bats 全量 | `npx bats test/` | **973 ok / 0 not ok / 0 skip** ✅（基线一致） |
| make lint | `make lint` | `✅ shellcheck: no errors found` rc=0 ✅ |
| make check-hooks-sync | `make check-hooks-sync` | `✅ hooks 副本一致（漂移 0）` rc=0 ✅ |
| sync-hooks.sh --check | `bash sync-hooks.sh --check` | `✅ hooks 副本一致（漂移 0）` rc=0 ✅ |
| make check-path-privacy | `make check-path-privacy` | `✅ 清单外命中 0 条` rc=0 ✅ |
| v_T11.sh（pre-push 影子 stub） | `bash /tmp/vblocks/v_T11.sh` | rc=0 ✅ |
| v_T17.sh（CHECK_REV 双态夹具） | `bash /tmp/vblocks/v_T17.sh` | rc=0 ✅ |
| v_T20.sh | `bash /tmp/vblocks/v_T20.sh` | rc=0 ✅ |
| v_T25.sh | `bash /tmp/vblocks/v_T25.sh` | rc=0 ✅ |
| v_T26.sh | `bash /tmp/vblocks/v_T26.sh` | rc=0 ✅ |

## 6. 6 维自查（R1-R6）

本任务无生产代码改动（仅沙箱验证 + SUMMARY + TASK.md 状态位），按 flow-dev skill「纯文档/纯配置任务可跳过 6 维 brooks-review」处理，但仍做轻量自查：

- **R1 认知过载**：无新代码，N/A
- **R2 变更传播**：仅改 TASK.md 一行 status + 新增 SUMMARY，无越界 ✅
- **R3 知识重复**：无逻辑粘贴，N/A
- **R4 偶然复杂**：无新抽象，N/A
- **R5 依赖混乱**：无新依赖，N/A
- **R6 领域扭曲**：SUMMARY 变量名用领域词（ref / sha / 拦截 / 归因），N/A

### 沿用既有抽象 grep（R6.4）

本任务验证逻辑直接复用既有产物，无新抽象：

- `check-path-privacy.sh`（T17）：grep `CHECK_REV` → `check-path-privacy.sh:90` 已实现评估面切换入口 → 沿用
- `pre-push.sh`（T11 修复轮 1）：grep `CHECK_REV` → `pre-push.sh:30` 已传 local sha → 沿用
- `install.sh` / `install_hooks.sh`（T16）：部署 symlink 机制 → 沿用
- 无新建脚本（仅沙箱内临时夹具，执行后清理）

## 7. 遗留

- **C7 干净 clone 复现属 v2**（MINOR-DEFERRED.md C7）：本 task 不承担「干净 clone 上拦截仍生效」的验证，仅验四形态被拦 + 干净 ref 放行。载体可复现性 = 「由 `install_hooks.sh` 部署 + `sync-hooks.sh --check` 校验」（ADR-022 symlink），非「clone 即有」。
- **verify 脚本 set -e 陷阱**（非阻断，记录备查）：TASK.md `<verify>` 块第 860/864/869 行的 `out=$(git $form 2>&1); rc=$?;` 模式在 `set -euo pipefail` 下会因赋值语句继承 push 的非零 rc 而提前退出。判据本身满足（仪器化 + set-e 修复版双重验证）。若后续修订 TASK.md verify 块，建议把 `out=$(cmd); rc=$?` 改为 `out=$(cmd) || rc=$?; rc=${rc:-0}`。
- 无产品件遗留问题（T11 修复轮 1 已闭环）。
