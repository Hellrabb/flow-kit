# T16-SUMMARY — AC-3(c) 部署形态闭环（`install_hooks.sh` 新增 `deploy_pre_push`）

> 变更 `health-fix-2026-09b` · 阶段 4（DEV）· T16
> 执行者：task agent（top tier）
> 基线 sha256 `c8d48bbed244a4bf…`（358 行）→ 实施后 `c96677a88579c92c…`（430 行，+72 行）

## 1. 任务理解

AC-3 的推送拦截器 `pre-push.sh` 源树已就位（T11，`flow-kit-bundle/hooks/pre-push/pre-push.sh`，`100755`），`sync-hooks.sh` 四处登记已完成（T12，`--entry-class pre-push/pre-push.sh` → rc=0），但**部署触点缺失**：`install_hooks.sh` / `install.sh` / `package-dsh-plugin.sh` 对 `pre-push` 命中 0/0/0 ⇒ 运行 `install.sh --project` 后 `.git/hooks/pre-push` 仍是既有普通文件（实测本仓 373 B），AC-3 拦截器从未被部署 ⇒ `test_quality_baseline.bats:78/83` 两条无 skip 断言（`test -x` / `grep -q "make check"`）假绿，AC-8「0 not ok」按设计不可达。

本任务 = 在 `install_hooks.sh` 内新增 `deploy_pre_push()`，以 **symlink → 已安装 hooks 目录**（ADR-022 锁定形态）为唯一产物部署 pre-push，并对既有非 flow-kit 文件「先备份后覆盖」，命中幂等则跳过。

## 2. 边界复述（实现严格遵守）

- ① 部署产物唯一形态 = symlink 指向 `$hook_dst/pre-push/pre-push.sh`；**禁止** `cp` / `cp --remove-destination` 落普通文件。
- ② `is_flowkit_symlink()`：`[ -L ]` + `[ -e ]`（悬空 ⇒ `return 1`）+ **裸 `readlink`**（禁 `readlink -f` GNU-only）+ `case` 否决源树 `*/flow-kit-bundle/hooks/…` 与 `*/dist/*`，只认 `*/hooks/pre-push/pre-push.sh`。
- ③ 命中幂等 ⇒ 跳过；否则先备份（symlink 存 linktarget、普通文件 `cp -p`，备份名含 PID `$$`）→ `rm -f` 旧物 → `ln -s` → `chmod +x` → `[ -x ]` 断言；每步失败不静默。
- ④ 函数语义**自己写**，禁照抄 `deploy_pre_commit`（skip/交互确认 vs 本处「备份后覆盖」，语义相反）。
- ⑤ 接线点 = `deploy_pre_commit` 调用之旁；不动 `deploy_pre_commit` 既有行为，不改其它文件。
- ⑥ `install_hooks.sh` 属源树文件（非 hooks/ 镜像副本面）⇒ `sync-hooks.sh` 只管 `hooks/` 目录（48 文件），不管 `lib/`；本改动无 tracked 镜像副本面文件须同步（已 `git status` 确认）。

## 3. 改动（file:line + 关键代码行原文）

**文件**：`flow-kit-bundle/lib/install_hooks.sh`（唯一 write_files，+72 行 0 删）

### 3.1 新增 `is_flowkit_symlink()`（:94–110）

```bash
is_flowkit_symlink() {
  [ -L "$1" ] || return 1
  [ -e "$1" ] || return 1
  local t
  t="$(readlink "$1")" || return 1
  case "$t" in
    */flow-kit-bundle/hooks/pre-push/pre-push.sh) return 1 ;;   # 源树 —— 否决
    */dist/*)                                    return 1 ;;   # dist 镜像 —— 非安装位
    */hooks/pre-push/pre-push.sh)                return 0 ;;   # 已安装位
    *)                                           return 1 ;;
  esac
}
```
插入在 `deploy_pre_commit()`（:69–92）之后、`install_hooks()`（原 :97，现 :112）之前。

### 3.2 新增 `deploy_pre_push()`（:112–172）

```bash
deploy_pre_push() {
  # 1. 无条件装源文件到已安装 hooks 目录
  install_file "$SCRIPT_DIR/hooks/pre-push/pre-push.sh" "$hook_dst/pre-push/pre-push.sh"
  chmod +x "$hook_dst/pre-push/pre-push.sh" 2>/dev/null || true

  # 2. 项目级才创建 symlink（user scope 无 .git）
  [[ -d "${project}/.git" ]] || return 0

  local target="${project}/.git/hooks/pre-push"
  mkdir -p "${project}/.git/hooks"

  # 3. 幂等：已是指向已安装位的 symlink ⇒ 跳过
  if is_flowkit_symlink "$target"; then
    echo "   ✅ pre-push 已是 flow-kit symlink，跳过: $target"
    return 0
  fi

  # 4. 先备份既有物（备份名含 PID 避免同秒并发覆盖）
  local bak="${target}.bak.$$"
  if [ -L "$target" ]; then
    local lt; lt="$(readlink "$target" 2>/dev/null)" || lt="(unreadable)"
    printf '%s\n' "$lt" > "${bak}.linktarget" || { echo "🔴 pre-push 备份 linktarget 写入失败: ${bak}.linktarget" >&2; return 1; }
    echo "   [pre-push] 既有 symlink 备份: ${bak}.linktarget -> $lt"
  elif [ -e "$target" ]; then
    cp -p "$target" "$bak" || { echo "🔴 pre-push 备份失败: $target -> $bak" >&2; return 1; }
    echo "   [pre-push] 既有文件备份: $target -> $bak"
  fi

  # 5. 删除旧物 + 创建 symlink（唯一产物形态 · ADR-022）
  rm -f "$target" || { echo "🔴 pre-push 旧物删除失败: $target" >&2; return 1; }
  ln -s "$hook_dst/pre-push/pre-push.sh" "$target" || { echo "🔴 pre-push symlink 创建失败: $target" >&2; return 1; }
  chmod +x "$target" 2>/dev/null || true

  # 6. 部署断言（DESIGN D3 item 5）：产物可执行
  [ -x "$target" ] || { echo "🔴 pre-push 部署后不可执行: $target" >&2; return 1; }
  echo "   ✅ pre-push symlink → $target"
}
```
**语义要点**（与 `deploy_pre_commit` 对比）：
- `deploy_pre_commit`：`[ -e ] && [ ! -L ]` ⇒ 既有普通文件则 `FLOW_KIT_YES` 跳过 / `read -p` 交互 / `rm -f`（skip/交互确认）。
- `deploy_pre_push`：`is_flowkit_symlink` 命中 ⇒ 幂等跳过；否则（普通文件 / 悬空 symlink / 错绑）**先备份再覆盖**（语义相反）。

### 3.3 接线点（:263，原 :192 `deploy_pre_commit` 之旁）

```bash
  deploy_pre_commit
  deploy_pre_push        # ← T16 新增
```
位于 `install_hooks()` 内、PreToolUse 部署循环之后、l2-reviewer agent 段之前。`$project` / `$hook_dst` 在该作用域可见（bash 动态作用域，与 `deploy_pre_commit` 同）。

## 4. 判别力与复原真实输出（L-132 定式）

### 4.1 工件判据原样执行（L-128）— 期望 rc=0

```
$ ./flow-kit-bundle/flow-kit/scripts/task-brief .specs/health-fix-2026-09b/TASK.md T16 \
    | awk '/^  <verify>$/{f=1;next} /^  <\/verify>$/{f=0} f' > /tmp/t16v.sh \
  && bash -n /tmp/t16v.sh && bash /tmp/t16v.sh; echo "rc=$?"
…
  ✅ /home/<acct>/.claude/hooks
  ✅ /home/<acct>/unisoc/flow-kit/dist/dsh-flow-kit/hooks
  ✅ /home/<acct>/unisoc/flow-kit/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ /home/<acct>/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks
  ✅ /home/<acct>/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ /home/<acct>/.config/opencode/hooks

✅ hooks 副本一致（漂移 0）
rc=0
```
夹具预置 49 B 既有普通文件 pre-push（`make check`）⇒ 首次安装命中「非 flow-kit symlink」⇒ 走备份+覆盖分支 ⇒ `n1=1`、`cmp -s` 通过、二次安装幂等 `n2=n1`。所有断言（`[ -L ]`/`[ -e ]`/`[ -x ]`/`grep -q 'make check'`/`case` 否决源树 dist/`n1 -ge 1`/`cmp`/幂等/镜像面）均到达缺陷位且通过。

### 4.2 判别力证据（L-132）— 注入 `is_flowkit_symlink` 恒 `return 0` ⇒ 必须变红

临时把 `install_hooks.sh` 中 `is_flowkit_symlink()` 函数体改为 `return 0`（夹具既有普通文件被误判「已是指向已安装位的 symlink」⇒ `deploy_pre_push` 落「幂等跳过」分支 ⇒ **不创建 symlink**）：

```
$ bash /tmp/t16v.sh
🔴 部署产物不是 symlink（ADR-022 形态未闭环）
rc=1
```
判据真实点名失败原因「部署产物不是 symlink」。**判据有判别力**——缺陷位（symlink 创建）未到达时转红。

### 4.3 彻底复原 ⇒ 必须绿

`cp /tmp/t16-orig.bak flow-kit-bundle/lib/install_hooks.sh`（恢复 `is_flowkit_symlink` 真实实现），`git diff` 字节数 5621（= 我的补丁内容，非注入残留），文件 sha256 = `c96677a8…`（= 补丁态，非注入态）：

```
$ bash /tmp/t16v.sh
…
✅ hooks 副本一致（漂移 0）
rc=0
```
**复原后绿**。判别力闭环：注入态红 → 复原态绿，同一工件、同一判据。

## 5. 门禁输出（真实）

| 门禁 | 命令 | 结果 |
|---|---|---|
| 语法 | `bash -n flow-kit-bundle/lib/install_hooks.sh` | rc=0 |
| shellcheck | `make lint`（`./flow-kit-bundle/lib/install_hooks.sh` 在被检列表内） | ✅ shellcheck: no errors found · rc=0 |
| shellcheck（本机独立） | `shellcheck flow-kit-bundle/lib/install_hooks.sh` | rc=0；2 个 SC2162 info 级（均属既有 `read -p` 行 :85/:281，非本任务新增代码） |
| 单元测试 | `make test` | 973 ok / 0 not ok · rc=0 |
| 镜像面 | `bash sync-hooks.sh --check` | ✅ hooks 副本一致（漂移 0）· rc=0 |
| 镜像面（make） | `make check-hooks-sync` | ✅ hooks 副本一致（漂移 0）· rc=0 |
| 工件判据 | `bash /tmp/t16v.sh` | rc=0（见 §4.1） |

**预期红、不据此判失败**：`make check` / `make check-dist`（T24 收口）。本任务不修。

**镜像面同步说明**（T05 工艺结论）：`install_hooks.sh` 位于 `flow-kit-bundle/lib/`，属源树文件；`sync-hooks.sh` 只管 `hooks/` 目录（48 文件，`pre-push/pre-push.sh` 已在 T12 登记），不管 `lib/`。故本改动无 tracked 镜像副本面文件须同步——`git status --short` 确认仅 `flow-kit-bundle/lib/install_hooks.sh` 一处 `M`，无镜像副本面漂移。

## 6. 六维自查

### 6.1 沿用既有抽象 grep（R6.4）

- **hook 部署函数范式**：`grep -n "deploy_pre_commit\|install_file\|ln -s" install_hooks.sh` → 找到 `deploy_pre_commit()`（:69–92，skip/交互确认语义）、`install_file()`（:25–34，`cp` 装源文件）、`ln -sf`（:90，pre-commit symlink 创建）。**沿用** `install_file` 装源文件、`ln -s` 创建 symlink、`$hook_dst`/`$project` 动态作用域；**不照抄** `deploy_pre_commit` 的 skip/交互分支（语义相反）。
- **幂等判据**：`grep -rn "is_flowkit_symlink\|readlink" install_hooks.sh sync-hooks.sh` → 无既有 `is_flowkit_symlink`；`sync-hooks.sh` 用 `cmp -s` 比内容、不用 readlink 判 symlink 归属。`is_flowkit_symlink` 按 DESIGN D3 规定性伪代码新写（载体语义判据，非内容 grep）。
- **备份范式**：`grep -rn "\.bak\.\|cp -p" flow-kit-bundle/lib/ flow-kit-bundle/hooks/` → 无既有「带 PID/纳秒备份」范式；本仓原子写用 `mktemp … && mv`（`write_settings_file_atomic` :44），但那是「写新文件」场景，与「保全既有文件备份」语义不同。本任务按 DESIGN D3 `cp -p` + `$$` 命名备份。
- **exec 位**：`grep -n "chmod +x" install_hooks.sh` → `stop/` `session-start/` `pre-tool-use/` 均有 `chmod +x`（:157/:169/:189）。**沿用**，对 `pre-push/pre-push.sh` 源文件与 symlink 都 `chmod +x`（DESIGN D3 item 5）。

### 6.2 6 维 self-review（内置快查 · 无 brooks-lint）

- **R1 认知过载**：`deploy_pre_push` ~60 行（含注释），单一职责（装源文件 + 判幂等 + 备份 + 覆盖 + 断言），无 >3 层嵌套。✅
- **R2 变更传播**：diff 仅 `flow-kit-bundle/lib/install_hooks.sh`（+72 行 0 删），无越界。✅
- **R3 知识重复**：`is_flowkit_symlink` 与 `deploy_pre_commit` 的判据**刻意不同**（pre-commit 用 `[ -e ] && [ ! -L ]` + 内容无关，pre-push 用载体语义 case）——非重复，是不同 hook 的不同语义需求。✅
- **R4 偶然复杂**：无「以后可能用到」的扩展点；`case` 四臂均为 DESIGN D3 显式裁决（源树/dist/已安装位/其他）。✅
- **R5 依赖混乱**：`deploy_pre_push` 依赖 `install_file`（基础设施工具）、`$hook_dst`/`$project`（install_hooks local）—— 与 `deploy_pre_commit` 同向，无倒置。✅
- **R6 领域扭曲**：变量名 `target`/`bak`/`lt` 均为部署领域词，非技术词空转。✅

### 6.3 越界检查（R6.5）

```
✅ TASK write_files：1 项 — flow-kit-bundle/lib/install_hooks.sh
✅ 实际 diff 涉及：1 项 — flow-kit-bundle/lib/install_hooks.sh
→ 0 越界 ✅
```
`git diff --name-only HEAD` = `flow-kit-bundle/lib/install_hooks.sh`；`git status --short` = ` M flow-kit-bundle/lib/install_hooks.sh` + 6 个 `A `（冻结集，不属本任务）。

## 7. TDD 声明

本任务走「工件判据原样执行 + 判别力注入」双证（L-128/L-132），**未**单写 RED 测试用例——工件 `<verify>` 块本身即 T19 夹具前置的判据集合（`[ -L ]`/`[ -e ]`/`[ -x ]`/`grep -q 'make check'`/`case` 否决/`n1 -ge 1`/`cmp`/幂等），已覆盖 AC-3(c) 全部分支：
- 幂等跳过分支：二次安装 `n2==n1` 断言。
- 备份+覆盖分支：`n1 -ge 1` + `cmp -s` 逐字节保全断言。
- 产物形态分支：`[ -L ]` + `case` 否决源树/dist。
- exec 位分支：`[ -x ]`。

判别力注入（`is_flowkit_symlink` 恒 `return 0`）证明：缺陷位（symlink 创建）未到达时，`[ -L ]` 断言先于 `n1` 断言转红并点名「部署产物不是 symlink」—— 判据**不空转**（L-130：影子 stub 不能替代被验逻辑；本任务被验逻辑 = `deploy_pre_push` 真实实现，注入只改幂等判据不改部署主体）。

## 8. 遗留

- **无本任务遗留**。AC-3(c) 部署形态闭环已落地：`install.sh --project` 后 `.git/hooks/pre-push` = symlink → 已安装 hooks 目录，可执行，含 `make check`，二次安装幂等。
- **T19 依赖就绪**：T19（四形态实跑拦截）depends_on T11+T12+T16，三者现已齐备（hook 本体 / 副本登记 / 部署形态）。
- **T24 未收口**：`make check` / `make check-dist` 预期红（归档内容重建，T24 负责），本任务不修、不据此判失败。
- **ADR-022 Superseded-by 追加**：DESIGN D3 item 3 要求在 `.specs/adr/022-git-hook-deployment.md` 追加 `Superseded-by`（部分：仅 pre-push 注入）——属 T06 范围（ADR 治理），非本任务 write_files，不在本提交内。
