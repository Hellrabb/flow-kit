# T-FIX-13 SUMMARY — bundle 形态「检查器在 + 清单缺」fail-open 修复（R4-M1）

**change**: health-fix-2026-09b
**task**: T-FIX-13
**commit**: `ee0df5c0e4cc3f631edce85a436a667acb0a14ac`
**commit_epoch**: 1790507871（2026-09-27T19:17:51+08:00）
**completed_at**: 1790507877（Δ = 6 s ≤ 120 s）
**fix_rounds**: 0

---

## 1. 任务

bundle 形态（消费者项目里钩子与 flow-kit 的 `reference/` 同装）下，检查器 `check-path-privacy.sh` **在位**、但 `path-privacy-allowlist.txt` **缺失**（旧版安装器 / 手工 symlink / 半拷贝目录）时：

- `pre-push.sh` 的 `scan_rev()` bundle 分支（原 :87-100）与 `pre-commit.sh`（原 :69-71）都打印 `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描` —— **与实际原因不符**（检查器明明在）；
- 且该形态下 **rc=0 放行**（fail-open）：含真实形态探针的待推送对象被直接放过。

修复目标：三态区分，只对「配置缺失」（状态②）fail-closed；状态①（检查器缺失）与状态③（两者皆在）语义逐字不变。

## 2. 改动逐文件

### `flow-kit-bundle/hooks/pre-push/pre-push.sh`（+22 / -2，net +20）
`scan_rev()` 函数（:79-103 区段）的 bundle 分支：
- **原**：`[ -z "$RESOLVED_ALLOWLIST" ]` ⇒ 打印旧措辞 + `return 0`（放行）。
- **新**：`[ -z "$RESOLVED_ALLOWLIST" ]` ⇒ `echo "🔴 [pre-push] 找到路径隐私检查器但缺少允许清单：${RESOLVED_CHECKER%/check-path-privacy.sh}/path-privacy-allowlist.txt（无法确定扫描基线 ⇒ fail-closed，推送被拒绝）" >&2; exit 2`。
- **为何 `exit 2` 而非 `return 1`**：`scan_rev` 的调用方（:149-150）把任何非零返回一律归因为 `🔴 拒绝推送 <ref>：该 ref 含路径隐私泄漏`，配置缺失若走 `return 1` 会造成**归因错位**（把「缺清单」报成「泄漏」）。`exit 2` 直接终止脚本，绕过父层泄漏归因，报文明确指名「配置缺失」。
- `none` 分支（:98-100）**逐字不变**：仍打印 `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描` + `return 0`（状态①消费者兼容语义，bats:208 静态断言要求该措辞仍在文件内）。
- 函数前注释块新增三态语义说明（:75-103 区段）。

### `flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（+9 / -1，net +8）
`else` 分支内（:60-75 区段）：
- **原**：`[ -f "$ref_dir/path-privacy-allowlist.txt" ]` 为假 ⇒ `echo "ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描"`（隐式 `exit 0`，放行）。
- **新**：`echo "🔴 [archive-commit-gate] 找到路径隐私检查器但缺少允许清单：$ref_dir/path-privacy-allowlist.txt（无法确定扫描基线 ⇒ fail-closed，提交被拒绝）" >&2; exit 1`（沿用既有「提交被拒绝」语义）。
- 检查器缺失腿（:72-74 `else`）**逐字不变**：仍打印旧措辞（bats:222 静态断言）。

### `test/test_archive_commit_gate.bats`（+42 / 0，net +42）
新增 3 个用例（不删改既有 42 条断言）：
1. `pre-push.sh: 检查器在 + 允许清单缺失 ⇒ 具名 fail-closed（T-FIX-13 · R4-M1）`：静态断言报文含 `path-privacy-allowlist.txt` / `fail-closed` / `exit 2`，且不把配置缺失归因为泄漏。
2. `pre-push.sh: 状态 ② 报文不复用「检查器缺失」措辞（T-FIX-13 · 归因区分）`：断言 bundle 分支用 `缺少允许清单` 独立措辞，`未找到可用的路径隐私检查器` 仅在 none 分支（状态①）。
3. `pre-commit.sh: 检查器在 + 允许清单缺失 ⇒ 具名 fail-closed exit 1（T-FIX-13 · R4-M1）`：静态断言报文含 `path-privacy-allowlist.txt` / `fail-closed` / `缺少允许清单`，旧措辞仍在文件内。

### `flow-kit-bundle/test/test_archive_commit_gate.bats`（+42 / 0，net +42）
`make test-sync` 镜像，内容与 `test/test_archive_commit_gate.bats` 逐字节一致。

### `.specs/STATE.md`（+2 / -1，net +1）
基线计数行更新：`1061 ok` → `1064 ok`（T-FIX-11 基线 1061 + T-FIX-13 新增 3）；新增 T-FIX-13 演进条目。

### `dist/`（重建，gitignore，不纳入提交）
`package-dsh-plugin.sh` + `package-flow-kit.sh` 重建；`make check-dist` 确认 dist 与源一致。

## 3. 判据复跑原文（`bash /tmp/p6d/verify-tfix13.sh`）

### 先红基线（修复前 · 6 条红腿，与主 agent 公布一致）
```
   （L2 pre-push rc=0）ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描
ℹ️ 项目 Makefile 未声明 check 目标：跳过
🔴 L2a 允许清单缺失时 pre-push 仍 rc=0（fail-open 未修）
🔴 L2b 报文未指名缺失的允许清单路径
🔴 L2c 报文复用了「检查器缺失」措辞（原因不符）
   （L2 pre-commit rc=0）ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描
🔴 L2e 允许清单缺失时 pre-commit 仍 rc=0
🔴 L2f pre-commit 报文未指名允许清单路径
🔴 L2g pre-commit 报文复用旧措辞
T-FIX-13 verify rc=1
```
（注：首轮派发时 verify 夹具另有 L2d 与 L5 对同态同输入互斥缺陷 → TD-081；主 agent 修订判据后 L5 红腿消失，仅余 6 条缺陷态红腿。）

### 修复后（rc=0，全绿）
```
   （L2 pre-push rc=2）🔴 [pre-push] 找到路径隐私检查器但缺少允许清单：/tmp/tmp.Kmsun2ruvd/hooks/../reference/path-privacy-allowlist.txt（无法确定扫描基线 ⇒ fail-closed，推送被拒绝）
   （L2 pre-commit rc=1）🔴 [archive-commit-gate] 找到路径隐私检查器但缺少允许清单：/tmp/tmp.Kmsun2ruvd/hooks/../reference/path-privacy-allowlist.txt（无法确定扫描基线 ⇒ fail-closed，提交被拒绝）
T-FIX-13 verify rc=0
```
无任何 🔴 行。L0a/L0b 语法 OK；L2a-L2g 缺陷态 fail-closed 全绿；L3a-L3c 检查器缺失态 rc=0+旧措辞全绿；L3d 夹具切「两者皆在」态；L4 干净 rc=0 / L4c pre-commit 泄漏 rc≠0 / L5 泄漏 rc≠0+归因「含路径隐私泄漏」全绿；L6a/L6b 静态断言 + L6c bats 套件全绿。

## 4. 反向控制三条（全部满足）

| # | 条件 | 期望 | 实测 | 结果 |
|---|------|------|------|------|
| (a) | 检查器缺失（ref_dir 内无 check-path-privacy.sh） | rc=0 + 旧措辞 | pre-push `o3` rc=0 含 `未找到可用的路径隐私检查器`；pre-commit `o4` rc=0 | ✅ L3a/L3b/L3c 绿 |
| (b) | 两者皆在 + 干净对象 | rc=0 | pre-push `o5` rc=0（L3d 后 allowlist 在位，空清单 + 0 命中 = 合法空基线 rc=0） | ✅ L4 绿 |
| (c) | 两者皆在 + 真泄漏（探针已 add/已提交） | rc≠0 且报文指名 ref 与 `file:line` 归因 | pre-push `o6` rc≠0 且含 `含路径隐私泄漏`（父层 :150 归因）；pre-commit `o7` rc≠0（L4c） | ✅ L4c/L5 绿 |

## 5. 门禁摘要

| 门禁 | 结果 |
|------|------|
| `bash -n pre-push.sh` / `bash -n pre-commit.sh` | ✅ 语法 OK（L0a/L0b） |
| `bash /tmp/p6d/verify-tfix13.sh` | ✅ rc=0（全绿，无 🔴） |
| `npx bats test/test_archive_commit_gate.bats` | ✅ 45 ok / 0 not-ok（原 42 + T-FIX-13 新增 3） |
| `npx bats test/`（全量） | ✅ 1064 ok / 0 not-ok / 0 skip（T-FIX-11 基线 1061 + 3） |
| `make test-sync` | ✅ test 双源已同步 |
| `./sync-hooks.sh` | ✅ 6 镜像 12 文件，漂移 0 |
| `bash package-dsh-plugin.sh` | ✅ done（dist/dsh-flow-kit + .tgz） |
| `bash package-flow-kit.sh` | ✅ done（exit 0） |
| `make check-hooks-sync` | ✅ 6 镜像漂移 0 |
| `make check-test-sync` | ✅ test 双源一致 |
| `make check-dist` | ✅ dist 与源一致 |
| `make check` | ✅ 21 项全绿 rc=0 |
| `core.hooksPath` | 空（本仓未设 hooksPath ⇒ 提交时钩子未自动校验，所有门禁手工跑） |

## 6. 遗留风险

1. **状态②报文绝对路径暴露**：fail-closed 报文含 `${RESOLVED_CHECKER%/check-path-privacy.sh}/path-privacy-allowlist.txt` 的绝对路径（如 `/tmp/.../reference/path-privacy-allowlist.txt`）。在消费者项目部署形态下，该路径是随包安装路径（非本机用户路径），不构成隐私泄漏；但若 hook 部署在含本机用户名的路径下（如 `/home/<user>/.dsh/.../hooks/`），报文会暴露该路径。权衡：fail-closed 拒绝场景下用户需要知道「缺哪个文件」才能修复，指名绝对路径是可观测性（NFR）要求；且 `check-path-privacy.sh` 自身的 `file:line` 归因也暴露路径。风险可接受，与既有门禁口径一致。

2. **`exit 2` 绕过 `scan_rev` 调用方的后续逻辑**：状态②下 pre-push 直接 `exit 2`，不继续处理后续 ref 行、不跑项目 Makefile check 目标。这是预期行为（配置缺失时继续处理无意义），但意味着多 ref 推送时，若第一个 ref 就触发状态②，后续 ref 不被扫描。与既有 `exit 1`（泄漏 / 畸形输入）行为一致，无新增风险。

3. **TD-081（判据夹具缺陷）已由主 agent 修订**：首轮派发的 verify 脚本 L2d（配置缺失不报泄漏）与 L5（泄漏要报泄漏）对同一 `$LSHA`、同一「检查器在+清单缺」夹具态互斥。主 agent 已在 TASK.md 原地修订（L3d 切「两者皆在」态 + L4c 新增 pre-commit 反向控制），重抽到 `/tmp/p6d/verify-tfix13.sh`（sha256 `242fa9c4...`）。本执行者未自行放宽判据，按修订后判据执行。

4. **dist/ gitignore**：`dist/` 被 `.gitignore` 忽略，不纳入提交（符合任务块 `<write_files>` 列 dist/ 为「重建」产物）。`make check-dist` 确认 dist 与源一致，但 dist 不在版本控制内 —— 这是既有约定，非本任务引入。

5. **既有 bats 42 条断言零回退**：新增 3 条用例均为新增，未删改既有 42 条（含 bats:208/:222 的 `未找到可用的路径隐私检查器` 静态断言）。
