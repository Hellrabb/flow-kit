# 独立审查 · 阶段 3

## L2 盲审

### 独立验证

| # | 检查项 | grep/read 实证 | 状态 |
|---|--------|---------------|------|
| 1 | 8 任务 7 字段 | `grep -c '<task' TASK.md` = 8；id/name/read_files/write_files/action/verify/done/depends_on 各 8 处 | ✅ |
| 2 | 波次 DAG 无环 | T04←T02,T03 / T05←T01 / T06←T02,T03 / T07←T04,T05,T06 / T08←T07（TASK.md:37,109,133,155,179,203）；parallel="true" 仅 T01-T06（L16/40/72/89/112/136），T07/T08 顺序 | ✅ |
| 3 | write_files 边界 | 12 文件全在 DESIGN §0.5.1 修改/新增清单；禁动清单（gate 核心链 / checkpoint-lib / .flow-active.goal / PRESET_MAP / package-flow-kit.sh Part A-E/G）零 write 碰撞 | ⚠️ 见 R1 |
| 4 | verify 可执行性 | 8 条 verify 均为 bash -n / grep / test 真实命令，非描述文字 | ⚠️ 见 R4/R6 |
| 5 | Plan-Conflict Scan | id T01-T08 唯一；depends_on 均存在且为真实 task；parallel 任务互无依赖（T04/T05/T06 独立） | ⚠️ 见 R11 |
| 6 | 跨工件一致性 | D1→T05 / D2→T01 / D3→T02+T04 / D4→T06 / D5→T03 / D6→T07；AC-1→T07, AC-2→T01/T05, AC-3→T02/T03/T04/T06, AC-4→T05, AC-5→T08 全落 done | ⚠️ 见 R3 |
| 7 | read_files 完整性 | 每任务 read ⊇ write + import 模块（T02: common/correction-file/correction-types）+ DESIGN 复用项（32/28 先例）+ CONTEXT.md | ✅ |
| 8 | F1-F8 修复传递 | F1 主链 ✅(T02 3a) / F2 2 参签名 ✅（对齐 correction-file.sh:47 实证 `path=$1 data=$2`）/ F3 git 锚点 ✅ / F3-residual 三条件 ✅ / F4 type-guarded clear ✅（对齐 write_model_missing_clear:132-144 实证）/ F6 jq 括号 ✅(T06) / F8 snake_case ✅（对齐 33 先例 + stop-hook.json 11 个既有 snake key） | ⚠️ 见 R2 |

### 发现（🟡/🟢）

### 🔴 R1 · pre-commit.sh 无打包/安装路径：AC-2/AC-4 端到端不可达
**Severity**：🔴 Critical
**Symptom**：T01 write `flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（TASK.md:25），T05 仅加 `deploy_pre_commit()` symlink 函数（TASK.md:126）。实证全仓扫描：install_hooks.sh 只有 stop/lib/session-start/pre-tool-use/config 四段复制（L77-130），**无 pre-commit 复制段**；package-flow-kit.sh Part C（L88-136）逐目录 cp，**无 pre-commit 规则**；`hooks/pre-commit/` 目录当前不存在。ADR-022 定义 symlink 目标 = 已安装 hooks 目录（`~/.claude/hooks/pre-commit/pre-commit.sh`），但没有任何机制把该文件送到那里。
**Source**：ADR-022「symlink → 已安装 hooks 目录」+ REQUIREMENT AC-2/AC-4（L-020 三处接线之外还有文件投递要求）+ DESIGN §0.5.1（`package-flow-kit.sh:95-103` 列入「修改」段但 TASK write_files 未含 → TASK↔DESIGN 不一致）+ L-031 教训（DESIGN 清单不可全信，需全仓扫描）。
**Consequence**：bundle 不含 pre-commit.sh；安装后 `.git/hooks/pre-commit` 是悬空 symlink，用户首次 `git commit` 即报 `cannot run .git/hooks/pre-commit: No such file or directory` 而失败——pre-commit 门禁不是「拒绝坏 commit」，而是「拒绝一切 commit」。AC-2/AC-4 验收必然 fail。
**Remedy**：T05 write_files 追加两处投递路径：① install_hooks.sh 新增 pre-commit 安装段（`mkdir -p "$hook_dst/pre-commit"` + `install_file "$SCRIPT_DIR/hooks/pre-commit/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"`，对齐 session-start 段先例）；② package-flow-kit.sh 声明禁动例外（参照 superpowers-v6-absorb Part F 先例），Part C 追加 `cp "$HOOK_SRC/pre-commit/"*.sh "$STAGING/hooks/pre-commit/"`。T05 action step 5 的「只读不写」声明与 DESIGN 0.5.1「修改」清单矛盾，须二选一显式化。

### 🟡 R2 · T02 单阶段分支 F1 修复传递不完整（${PROJECT_ROOT} 缺失）
**Severity**：🟡 Important
**Symptom**：TASK.md:61（T02 3c）伪代码 `arch_dir=ls -t .specs/archive | head -1` / `stat -c %Y` / `git log -1 --format=%ct` 全部无 `${PROJECT_ROOT}` 前缀、无 `cd`；对比 DESIGN D3（DESIGN.md:108-111）为 `${PROJECT_ROOT}/.specs/archive/` + `cd "${PROJECT_ROOT}" && git log` + `|| echo 0` 兜底。
**Source**：F1 修复契约（run_check 零参回调，common.sh:55 实证 `"$body_fn"` 不传参 → body 内必须全用 PROJECT_ROOT）+ DESIGN D3 原文。
**Consequence**：弱模型照抄伪代码 → hook 由 00-gate.sh 以任意 cwd 调起（run_module 不 cd）→ `ls -t .specs/archive` 指向错误目录、`stat` 失败、`git log` 在非仓库目录失败 → 单阶段分支恒判不触发（AC-3 单阶段 Given 失效），且 `bash -n`（T02 verify）无法发现。
**Remedy**：T02 3c 逐项对齐 DESIGN D3：`arch_dir=$(ls -t "${PROJECT_ROOT}/.specs/archive/" 2>/dev/null | head -1)`、`arch_mtime=$(stat -c %Y "${PROJECT_ROOT}/.specs/archive/$arch_dir" 2>/dev/null || echo 0)`、`last_commit_ts=$(cd "${PROJECT_ROOT}" && git log -1 --format=%ct 2>/dev/null || echo 0)`。

### 🟡 R3 · T07 action 缺 ARCHIVE_BASE_SHA 记录（D7/AC-1 Given 未传递）
**Severity**：🟡 Important
**Symptom**：TASK.md:169-176 T07 action 五项内容（git add / 拆分 commit / PCSC / 弱模型防护）无 ARCHIVE_BASE_SHA；DESIGN D6+D7（DESIGN.md:157,167）明确「记录 ARCHIVE_BASE_SHA（git rev-parse HEAD）到 STATE.md」，REQUIREMENT AC-1 Given（REQUIREMENT.md:26）同要求。
**Source**：AC-1 Given 硬条件 + DESIGN D7（R10 修复：记 STATE.md 不写 .flow-active.goal）。
**Consequence**：归档起点锚定缺失 → AC-1 验证方式 `git log ${ARCHIVE_BASE_SHA}..HEAD`（REQUIREMENT.md:44）无法执行，归档 commit 与 4-dev 任务级 commit 不可区分，AC-1 验收不可验证。
**Remedy**：T07 action step 1 开头补「归档 mv 后 `ARCHIVE_BASE_SHA=$(git rev-parse HEAD)` 记录到 STATE.md」（对应 DESIGN D6 首行）。

### 🟡 R4 · T08 verify 管道吃 exit code + 未断言 ≥692 基线（TD-012 教训重演）
**Severity**：🟡 Important
**Symptom**：TASK.md:201 `[ "$(npx bats test/ 2>&1 | grep -c '^not ok')" = "0" ]` —— `npx` 的退出码被管道吞掉，且无 `^ok ≥ 692` 断言；REQUIREMENT AC-5 验证方式（REQUIREMENT.md:174-178）要求退出码 0 + 0 fail + ≥692 ok 三项。
**Source**：CONTEXT.md TD-012「`bats|tail` 管道吃 exit code 误判全绿」教训（已修复项，明确禁止此模式）+ AC-5 三断言。
**Consequence**：`npx bats` 启动失败或 bats 崩溃（错误走 stderr、stdout 无 `not ok`）→ `grep -c` 输出 0 → verify 假绿放行；或测试被删减到 <692 也放行 → AC-5 回归防线（基线 692/692）失效，与 TD-012 同源事故复发。
**Remedy**：按 AC-5 原文替换：`npx bats test/ > /tmp/bats-out.txt 2>&1; rc=$?; [ "$rc" = "0" ] && [ "$(grep -c '^not ok' /tmp/bats-out.txt)" = "0" ] && [ "$(grep -c '^ok' /tmp/bats-out.txt)" -ge "692" ]`。

### 🟡 R5 · T04 done「module_enabled 默认 true」事实错误
**Severity**：🟡 Important
**Symptom**：TASK.md:108 done 写「module_enabled 默认 true（对应 AC-3 hook 注册链路）」；实证 common.sh:22-26 `module_enabled()` 用 `config_get ".modules[\"${mod}\"].enabled" "false"` —— 默认 **false**。
**Source**：DESIGN R3 修复前提「无模板条目 → 34 号静默禁用（module_enabled() 默认 false，common.sh:25）」——T04 加模板条目正是为了让默认启用成立。
**Consequence**：done 验收标准与实现语义相反 → 执行者据此误判「不用加模板条目」或删除条目，34 号静默禁用（R3 修复的 bug 复活），AC-3 链路断裂而 verify（grep 存在性）仍绿。
**Remedy**：done 改为「stop-hook.json 模板新增 archive_commit_check 条目 → 新安装默认启用（module_enabled 默认 false，模板条目使其生效）」。

### 🟢 R6 · T07 verify 不覆盖 commit-protocol.md 变更
**Severity**：🟢 Minor
**Symptom**：TASK.md:177 verify 仅 grep `7-integration.md`（'5\.1' + '归档'），action step 2 的 commit-protocol.md 分类移动（R13 修复）无任何 verify → 该步可被跳过而 verify 仍绿。
**Source**：阶段 3 checklist「verify 可机器验证」+ R13 修复完整性。
**Consequence**：R13（归档 commit 分类移修改段）验收无据，commit-protocol.md 漂移不被发现。
**Remedy**：verify 追加 `&& grep -q '归档' flow-kit-bundle/flow-kit/reference/commit-protocol.md`。

### 🟢 R7 · T03 action 漏 `readonly`
**Severity**：🟢 Minor
**Symptom**：TASK.md:82 action 写「追加 CORRECTION_TYPE_ARCHIVE_UNCOMMITTED="archive-uncommitted"」无 readonly；DESIGN D5（DESIGN.md:151）有 `readonly`；correction-types.sh:20-21 既有常量均 readonly。
**Source**：CONTEXT.md 已锁决策「所有 shell 脚本常量命名规范 — readonly UPPER_SNAKE_CASE」。
**Consequence**：新常量可被运行时意外覆盖；verify（grep 常量名）不拦截。
**Remedy**：action 改为「追加 `readonly CORRECTION_TYPE_ARCHIVE_UNCOMMITTED="archive-uncommitted"`」。

### 🟢 R8 · T01 action 未指定 chmod +x
**Severity**：🟢 Minor
**Symptom**：TASK.md:35 verify 要求 `test -x pre-commit.sh`，但 action 五步（L28-33）无 chmod；git hook 执行依赖可执行位。
**Source**：T01 verify 自身约束。
**Consequence**：执行者照 action 走完 → verify `test -x` 失败；或部署链路（install_file）虽补位但 verify 与 action 不一致。
**Remedy**：action 追加 `chmod +x flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（对齐 28/32 等既有模块部署惯例）。

### 🟢 R9 · DESIGN/TASK 将 package-flow-kit.sh 相关段标为「Part D」，实证在 Part C
**Severity**：🟢 Minor
**Symptom**：DESIGN.md:23「package-flow-kit.sh:95-103 — Part D 自动纳入新模块」+ TASK.md:129「Part D 自动纳入 34」；实证 package-flow-kit.sh:88 header「Part C: Stop Hook 系统」，HOOK_MODULE_NAMES 循环在 L95-103（Part C 内），Part D（L139）是配置文件模板。
**Source**：package-flow-kit.sh 实际分节。
**Consequence**：定位错误在 R1 修复（需改 Part C）时若按「Part D」搜索会找错位置；当前只读无行为影响。
**Remedy**：DESIGN 0.5.1 + T05 action step 5 改标「Part C」。

### 🟢 R10 · T02 done 标注「对应 AC-1/AC-3」应仅 AC-3
**Severity**：🟢 Minor
**Symptom**：TASK.md:68 done「对应 AC-1/AC-3」；AC-1（归档 commit）是 T07 的 prompt 层 5.1 范围，T02 是 Stop hook 检测（AC-3）。
**Source**：REQUIREMENT AC 职责划分。
**Consequence**：done 归因混乱，无行为影响。
**Remedy**：改「对应 AC-3」。

### 🟢 R11 · T02 对 T03 的常量软依赖未声明
**Severity**：🟢 Minor
**Symptom**：T02 action 3e/3f 使用 CORRECTION_TYPE_ARCHIVE_UNCOMMITTED（T03 定义），DAG 中 T02/T03 同波次并行且 T02 无 depends_on；`bash -n`（T02 verify）不检查未绑定变量。
**Source**：波次 DAG 定义（T02/T03 parallel）。
**Consequence**：仅当 34 号在 T03 done 前被触发才出错（实际 T08 前必然双 done），风险极低；但弱模型在 T03 前执行 T02 时 `set -u` 下运行会炸。
**Remedy**：可选——T02 depends_on 补 T03，或在 T02 action 注明「常量由 T03 提供，缺省先建占位」。

### 🟢 R12 · install_hooks.sh/package-flow-kit.sh 降级 fallback 列表不含 34
**Severity**：🟢 Minor
**Symptom**：install_hooks.sh:81-82 与 package-flow-kit.sh:103-112 的硬编码 HOOK_MODULE_NAMES fallback 列表（common.sh source 失败时启用）均无 34-archive-commit-check。
**Source**：既有降级模式（非本 change 引入）。
**Consequence**：common.sh 不可用的退化环境（安装时）34 号不打包/不安装；主路径（source common.sh）正常。
**Remedy**：可选——T04 声明例外同步两处 fallback 列表（需 touch install_hooks.sh/package-flow-kit.sh，若采纳并入 R1 的 write_files 调整）。

**Verdict**: fail

fail 依据（🔴 R1）：pre-commit.sh 无打包/安装投递路径 → AC-2/AC-4 端到端不可达；DESIGN 0.5.1 列 package-flow-kit.sh 为「修改」而 TASK write_files 未含，属 L-031 类漏改。

---

## 主 agent 响应（L2 盲审 fail → 修复汇报 · 1🔴+5🟡+5🟢 Fixed / 1🟢 Deferred）

- **🔴 #1** Fixed in TASK.md T05: write_files 加 package-flow-kit.sh + action step 2 deploy_pre_commit() 追加 install_file 复制（先复制源文件到安装目录再 symlink · 非悬空）+ action step 4 package-flow-kit.sh Part C 追加 pre-commit glob cp 行 + fallback 列表加 34（声明禁动例外）
- **🟡 #2** Fixed in TASK.md T02 3b+3c: 全路径 ${PROJECT_ROOT} + cd + || echo 0（对齐 DESIGN D3）
- **🟡 #3** Fixed in TASK.md T07 action step 1: 追加「记录 ARCHIVE_BASE_SHA=$(git rev-parse HEAD) 到 STATE.md」
- **🟡 #4** Fixed in TASK.md T08 verify: 改为先存输出文件 + 检查 exit code $rc=0 + not ok=0 + ok≥692 三条件（防 TD-012 假绿）
- **🟡 #5** Fixed in TASK.md T04 done: 改为「module_enabled 默认 false，模板条目使其对新安装 enabled」
- **🟢 #6** Fixed in TASK.md T07 verify: 加 ARCHIVE_BASE_SHA grep + commit-protocol grep
- **🟢 #7** Fixed in TASK.md T03 action: 加 readonly
- **🟢 #8** Fixed in TASK.md T01 action: 加 shebang + set -euo pipefail + chmod +x
- **🟢 #9** Deferred: Part D→C 标签在 DESIGN 层面修正（4-dev 实施时确认实际行号）
- **🟢 #10** Fixed in TASK.md T02 done: AC-1→AC-3
- **🟢 #11** Fixed in TASK.md T05 action step 4: fallback 列表追加 34-archive-commit-check

---

## L2 盲审（v2 重审）

### v1 发现核实（🔴#1 + 5🟡 + 5🟢 逐条 grep 实证）

| # | 发现 | grep 实证 | 状态 |
|---|------|----------|------|
| 🔴#1 | pre-commit 部署路径（write_files + install_file 复制 + Part C glob） | TASK.md:123-126 write_files 含 package-flow-kit.sh（⚠️ 路径错，见 N2）；TASK.md:131 `install_file "$src/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"` 先复制后 symlink ✅ 但 `$src` 未定义（见 N1🔴）；TASK.md:135 Part C glob `cp "$HOOK_SRC/pre-commit/"*.sh "$STAGING/hooks/pre-commit/"` ✅（package-flow-kit.sh:88/99-112 实证） | ⚠️ 部分修复 → N1+N2 |
| 🟡#2 | T02 3b/3c ${PROJECT_ROOT} 前缀 | TASK.md:62-63：`[ -d "${PROJECT_ROOT}/.specs/archive" ]` / `ls -t "${PROJECT_ROOT}/.specs/archive/"` / `cd "${PROJECT_ROOT}" && git log -1 --format=%ct 2>/dev/null \|\| echo 0` | ✅ Fixed |
| 🟡#3 | T07 ARCHIVE_BASE_SHA→STATE.md | TASK.md:181 `记录归档起点 ARCHIVE_BASE_SHA=$(git rev-parse HEAD) 到 STATE.md`（D7 · AC-1 Given） | ✅ Fixed |
| 🟡#4 | T08 verify 三条件 | TASK.md:208 `rc=$?; [ $rc -eq 0 ] && [ "$(grep -c '^not ok' /tmp/acg-bats.out)" = "0" ] && [ "$(grep -c '^ok ' /tmp/acg-bats.out)" -ge 692 ]` | ✅ Fixed |
| 🟡#5 | T04 done 默认 false | TASK.md:110「module_enabled 默认 false，模板条目使其对新安装 enabled」；common.sh:25 实证 `config_get ".modules[..].enabled" "false"` | ✅ Fixed |
| 🟢#6 | T07 verify commit-protocol | TASK.md:184 含 `grep -q 'ARCHIVE_BASE_SHA'` + `grep -q '归档.*修改段\|修改段.*归档' commit-protocol.md` | ✅ Fixed |
| 🟢#7 | T03 readonly | TASK.md:84 `readonly CORRECTION_TYPE_ARCHIVE_UNCOMMITTED`；correction-types.sh:20-21 实证既有常量均 readonly | ✅ Fixed |
| 🟢#8 | T01 shebang+chmod | TASK.md:29 `#!/bin/bash + set -euo pipefail`；TASK.md:35 `chmod +x pre-commit.sh` | ✅ Fixed |
| 🟢#9 | Part D→C 标签 | TASK.md:135 已改「Part C（非 D · L88-103）」（package-flow-kit.sh:88 实证 Part C header）；DESIGN.md:23 仍「Part D」→ 残留 N6 | ⚠️ Deferred 残留 |
| 🟢#10 | T02 done AC-3 | TASK.md:70「对应 AC-3 · **L2 #10：AC-1→AC-3**」 | ✅ Fixed |
| 🟢#11 | T05 fallback 列表 | TASK.md:135「fallback 列表（L103-112）追加 34」（package-flow-kit.sh:104-112 实证 fallback 存在）；install_hooks.sh:81 fallback 列表未提 → N4 | ⚠️ 半修复 |

### 回归扫描

#### 🔴 N1 · deploy_pre_commit 伪代码引用未定义变量（$src/$git_dir/$target）：install 在 set -u 下必崩，AC-4 部署链路断
**Severity**：🔴 Critical
**Symptom**：TASK.md:131 `install_file "$src/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"`；TASK.md:132 `echo "...existing pre-commit: $target, skipped"`；TASK.md:133 `ln -sf "$hook_dst/pre-commit/pre-commit.sh" "$git_dir/hooks/pre-commit"`。实证 install_hooks.sh 全文件：`src` 仅存在于 install_file() 的 local 作用域（install_hooks.sh:23），`git_dir`/`target` 零定义（grep -c = 0）；install.sh:6 为 `set -euo pipefail`，sourced lib 继承该选项。按字面执行：`$src` 空 → `install_file "/pre-commit.sh"` → cp 失败 → set -e abort；`$git_dir`/`$target` 未绑定 → set -u abort。T05 verify（TASK.md:137）仅 `bash -n` + grep 'FLOW_KIT_YES'/'deploy_pre_commit'，语法层全绿不拦截。另：2c 的 `[ -f .git/hooks/pre-commit ]` 是相对路径（cwd 依赖）。
**Source**：F1 修复同源教训（run_check 零参回调要求 body 全用 PROJECT_ROOT env）——task 伪代码必须引用目标文件真实存在的变量；既有惯例 `install_file "$SCRIPT_DIR/hooks/..."`（install_hooks.sh:84/96）。ADR-022「每项目部署」——pre-commit 仅 project 模式部署。
**Consequence**：install.sh 三调用点（L218/242/252）追加 deploy_pre_commit 后，任何模式安装到该步即 abort（user 模式还会在 `$HOME/.git` 不存在的路径上 ln 失败）→ AC-4 验收 fail；verify 全绿不拦截——与 v1 🔴#1（部署断 + verify 绿）同型复发。
**Remedy**：TASK.md:131-133 改为 `local target="${project}/.git/hooks/pre-commit"`（对齐 install_hooks() 的 `$project` 参数）+ `install_file "$SCRIPT_DIR/hooks/pre-commit/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"` + `ln -sf "$hook_dst/pre-commit/pre-commit.sh" "$target"` + 2c 条件改 `[ -f "$target" ]`；并注明 deploy_pre_commit 仅在 project 模式调用点（L218/252）追加，user 模式（L242 `install_hooks "$HOME" "user"`）不部署。

#### 🟡 N2 · write_files 路径错误 `flow-kit-bundle/package-flow-kit.sh` + T05 verify 无打包半环覆盖：🔴#1 的 Part C glob 无兜底
**Severity**：🟡 Important
**Symptom**：TASK.md:119/125 写 `flow-kit-bundle/package-flow-kit.sh`——实证 `ls flow-kit-bundle/package-flow-kit.sh` 不存在，文件在仓库根（package-flow-kit.sh:88「Part C: Stop Hook 系统」/ L99-103 HOOK_MODULE_NAMES loop / L104-112 fallback）；REQUIREMENT.md:161 同错（跨工件传染）。T05 verify（TASK.md:137）不含 package-flow-kit.sh 任何检查。
**Source**：L-031 教训（DESIGN 清单不可信，需全仓扫描定位真实路径）+ 阶段 3 checklist「verify 可机器验证 / 覆盖完整性」。
**Consequence**：弱模型按 write_files 路径改错文件（或新建同名文件），根 package-flow-kit.sh 未加 pre-commit glob → bundle 仍不含 pre-commit.sh → v1 🔴#1 打包半环静默回归，verify 全绿放行。
**Remedy**：TASK.md:119/125 + REQUIREMENT.md:161 路径改 `package-flow-kit.sh`；T05 verify 追加 `&& grep -q 'hooks/pre-commit' package-flow-kit.sh`。

#### 🟡 N3 · T05 action 缺 D8 交互询问分支：非 --yes 模式静默覆盖用户既有 pre-commit（AC-4 向后兼容未实现）
**Severity**：🟡 Important
**Symptom**：TASK.md:132 仅展开 `[ "${FLOW_KIT_YES:-0}" = "1" ]` 单分支；DESIGN D8（DESIGN.md:174-183）有 `read -p "...overwrite? (y/N)"` + `rm -f "$target"` 守卫。AC-4（REQUIREMENT.md:129）要求「询问用户（交互式）或跳过并输出确切提示（非交互式 --yes）」。非 --yes 安装遇用户既有 pre-commit：TASK 无指令 → 弱模型落 2d `ln -sf` 直接覆盖。
**Source**：AC-4 向后兼容契约（不静默覆盖既有 hook）+ DESIGN D8。
**Consequence**：用户自定义 pre-commit 被静默替换（数据丢失）；T05 verify 仅 grep 函数名/flag，无法检测分支缺失。
**Remedy**：action 补 else 分支：`read -p "[archive-commit-gate] existing pre-commit at $target, overwrite? (y/N) " ans; [ "$ans" = "y" ] || return 0; rm -f "$target"`，对齐 DESIGN D8。

### 结构复扫

| 检查项 | 实证 | 状态 |
|---|---|---|
| 8 任务 | T01-T08（grep -c '<task' TASK.md = 8） | ✅ |
| 7 字段 | 每 task 含 id/name/read_files/write_files/action/verify/done/depends_on 全部 | ✅ |
| 波次 DAG 无环 | W1: T01-T03[P]；W2: T04←T02,T03 / T05←T01 / T06←T02,T03（[P]）；W3: T07←T04,T05,T06；W4: T08←T07；depends_on 均指向真实 task | ✅ |
| write_files ⊂ DESIGN §0.5.1 | 12 文件全在修改/新增清单（T05 的 package-flow-kit.sh 路径错误除外，见 N2）；read ⊇ write | ✅ |
| 禁动零碰撞 | gate 核心链 / checkpoint-lib / .flow-active.goal（D7 记 STATE.md 不写 goal）/ PRESET_MAP 零 write；package-flow-kit.sh 禁动例外已显式声明（TASK.md:135）；correction-file.sh 4 函数签名只读不写 | ✅ |
| verify 可执行 | 8 条均为 bash -n / grep / test 真命令，非描述文字 | ✅ |
| Plan-Conflict Scan | id 唯一；parallel 任务互无依赖（T02↔T03 软依赖未声明，见 N5） | ✅ |
| 跨工件一致性 | AC-1→T07 / AC-2→T01+T05 / AC-3→T02+T03+T04+T06 / AC-4→T05 / AC-5→T08 全落 done；D1-D8→T05/T01/T02+T04/T06/T03/T07 接线对齐 | ✅ |

残留（v1 🟢 未闭环）：
- 🟢 N4 · R12 半修复：install_hooks.sh:81 fallback 列表（实证存在 `HOOK_MODULE_NAMES=(00-gate ... 99-report)`）未含 34；T05 step 4 仅覆盖 package-flow-kit.sh L103-112。Remedy：T05 action 补「install_hooks.sh:81 fallback 追加 34-archive-commit-check」。
- 🟢 N5 · R11 未处置：T02 depends_on 仍空（TASK.md:71），3e/3f 依赖 T03 常量。Remedy：T02 depends_on 补 T03（或注明占位）。
- 🟢 N6 · #9 Deferred 残留：DESIGN.md:23 仍「Part D 自动纳入新模块」（实证 Part C L88），与 TASK.md:135 的 Part C 修正不一致。Remedy：4-dev 实施前修 DESIGN 标签。

**Verdict**: fail

fail 依据（🔴 N1）：T05 deploy_pre_commit 伪代码引用 `$src`/`$git_dir`/`$target` 三个 install_hooks.sh 中零定义的变量（实证），按字面执行 install.sh（set -euo pipefail）必 abort → AC-4 部署链路断；T05 verify（bash -n + grep）全绿不拦截——v1 🔴#1（部署断 + verify 绿）同型复发。修复路径 N1 Remedy（4 行变量替换 + project 模式限定）。

---

## 主 agent 响应（L2 v2 fail → 修复汇报 · 1🔴+2🟡 Fixed / 3🟢 Fixed）

- **🔴 N1** Fixed in TASK.md T05 action step 2: deploy_pre_commit 变量对齐 install_hooks.sh 既有约定（$SCRIPT_DIR 源路径 非 $src · $project 目标 非 $git_dir · local target 定义）
- **🟡 N2** Fixed in TASK.md T05 read_files/write_files: package-flow-kit.sh 路径从 flow-kit-bundle/ 修正为仓库根 + verify 加 grep 'pre-commit.*\.sh' package-flow-kit.sh
- **🟡 N3** Fixed in TASK.md T05 action step 2c: D8 既有冲突检测完整分支（[ -e && ! -L ] guard + FLOW_KIT_YES skip + read -p 交互询问 + rm -f）
- **🟢 N4** Fixed in TASK.md T05 action step 4: install_hooks.sh:81 fallback 列表同步追加 34
- **🟢 N5** Fixed in TASK.md T02 depends_on: 空 → T03（CORRECTION_TYPE 常量运行时依赖）

---

## L2 盲审（v3 重审）

### v2 发现核实

| # | 发现 | grep 实证 | 状态 |
|---|------|----------|------|
| 🔴N1 | deploy_pre_commit 变量对齐（$SCRIPT_DIR 非 $src · $project/local target 非 $git_dir/$target） | TASK.md:130 `local target="${project}/.git/hooks/pre-commit"` / :131 `install_file "$SCRIPT_DIR/hooks/pre-commit/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"` / :136 `ln -sf "$hook_dst/pre-commit/pre-commit.sh" "$target"`；install_hooks.sh:37 实证 `local project="$1"`、:84 实证 `$SCRIPT_DIR`、:55 实证 `local hook_dst`，`$src` 仅 :23 install_file() local 作用域 | ⚠️ 变量层 Fixed → 调用点限定缺失（见回归 🔴R1） |
| 🟡N2 | write_files 路径 `package-flow-kit.sh`（非 flow-kit-bundle/）+ verify 含打包 grep | TASK.md:119/125 `package-flow-kit.sh`（无前缀）；glob 实证 flow-kit-bundle/package-flow-kit.sh 不存在、根 package-flow-kit.sh:88「Part C」实证；TASK.md:140 verify 含 `grep -q 'pre-commit.*\.sh' package-flow-kit.sh` | ✅ Fixed |
| 🟡N3 | 2c D8 完整分支（guard + 交互 + rm -f） | TASK.md:133-135 `[ -e "$target" ] && [ ! -L "$target" ]` + FLOW_KIT_YES skip + `read -p "flow-kit: 既有 pre-commit 存在，覆盖？(y/N) " ans` + `[ "$ans" = "y" ] \|\| { echo skipped; return 0; }` + `rm -f "$target"` | ✅ Fixed |
| 🟢N4 | install_hooks.sh:81 fallback 列表同步 | TASK.md:138「install_hooks.sh:81 fallback 列表同步追加 34-archive-commit-check」；install_hooks.sh:81 实证 fallback 数组存在且无 34 | ✅ Fixed |
| 🟢N5 | T02 depends_on T03 | TASK.md:71 `<depends_on>T03</depends_on>` | ⚠️ Fixed → 引入波次声明矛盾（见回归 🟡R3） |

### 回归扫描

#### 🔴 R1 · T05 step 3 未限定 project 模式：user 模式安装（L242 + L218 user-scope）在 `ln -sf ${HOME}/.git/hooks/pre-commit` 失败 → set -e abort，AC-4 user 场景断
**Severity**：🔴 Critical
**Symptom**：TASK.md:137「install.sh:218/242/252 install_hooks() 调用点追加 deploy_pre_commit 调用」无任何 project 限定。实证 install.sh:242 `install_hooks "$HOME" "user"`（--global --user 模式）、:218 `install_hooks "$TARGET_PROJECT" "$HOOK_SCOPE"`（--project ~ --hooks-only 时 scope=user）。按 TASK 字面执行：user 模式 deploy_pre_commit → `local target="${HOME}/.git/hooks/pre-commit"` → 2c guard `[ -e "$target" ]` false（~/.git 通常不存在）→ 2d `ln -sf` 报 `No such file or directory` → install.sh:6 `set -euo pipefail`（sourced lib 继承）→ **整个安装 abort**。
**Source**：v2 N1 Remedy 原文明确要求「deploy_pre_commit 仅在 project 模式调用点（L218/252）追加，user 模式（L242 install_hooks "$HOME" "user"）不部署」——v3 只修了变量层，调用点限定未传递；AC-4 Given 含「全新安装（install.sh --user 或项目级）」。ADR-022「每项目部署」。
**Consequence**：--global --user 或 --project ~ --hooks-only 安装到 deploy 步即 abort → AC-4 user-install 场景验收 fail；即使 ~/.git 恰好存在，也会在用户 home 仓库误装 pre-commit 门禁（语义污染）。T05 verify（bash -n + grep FLOW_KIT_YES/deploy_pre_commit）全绿不拦截——与 v2 N1（install 断 + verify 绿）同型复发。
**Remedy**：T05 step 3 改「仅 project 模式调用点追加（install.sh:252 + :218 当 scope=project）；user 模式（:242 及 :218 user-scope）不部署」；或 deploy_pre_commit 首行加 `[ "$scope" = "project" ] \|\| return 0` 守卫（scope 取 install_hooks() 既有参数 `$2`）。

#### 🔴 R2 · validate_staging.sh:54 Part C pattern 列表漏列 pre-commit/：pre-commit.sh 落盘后 `package-flow-kit.sh --validate` / `make check` 打包完整性校验必 fail（L-031 漏改类）
**Severity**：🔴 Critical
**Symptom**：T01 新建 flow-kit-bundle/hooks/pre-commit/pre-commit.sh + T05 加 Part C cp 行后，实证 validate_staging.sh:54 Part C 解析仅 `stop/*.sh stop/lib/*.sh session-start/*.sh pre-tool-use/*.sh` 四 glob（无 pre-commit/）；:117 KNOWN_SKIP 不含 pre-commit；:121-129 `comm -13` → `🔴 ERROR: 漏配！实际文件未被任何 Part 覆盖 — …/hooks/pre-commit/pre-commit.sh` → exit 1。package-flow-kit.sh:17-20 实证 `--validate` 入口调 validate_staging_coverage；CONTEXT「make check = test + lint + 打包校验」。
**Source**：L-031 教训（DESIGN §0.5.1 清单不可信，需全仓扫描跨文件一致性锚点）——validate_staging.sh 的 Part C pattern 列表即「DESIGN 漏列且未改」类；L-012 打包完整性校验契约。
**Consequence**：7-integration 跑 make check（或 --validate）必 fail，且 8 条 task verify（bash -n / grep）无一覆盖 → 集成阶段才爆；TASK.md T05 read_files/write_files 均不含 validate_staging.sh，弱模型按清单执行不会主动修。
**Remedy**：T05 read_files/write_files 补 `flow-kit-bundle/lib/validate_staging.sh`；action step 4 追加「validate_staging.sh:54 Part C 解析段追加 `"$BUNDLE_DIR/hooks/pre-commit/"*.sh` glob」；verify 追加 `&& grep -q 'hooks/pre-commit' flow-kit-bundle/lib/validate_staging.sh`。

#### 🟡 R3 · 波次 DAG 声明矛盾：T02 depends_on T03 但 parallel="true" + Wave 1 并行声明 → 并行竞态下 34 脚本引用未定义常量
**Severity**：🟡 Important
**Symptom**：TASK.md:8「Wave 1 (parallel): T01[P], T02[P], T03[P]」+ :42 T02 `parallel="true"`，但 :71 T02 `<depends_on>T03</depends_on>`（v3 新加）。T02 与 T03 同波次声明并行 + 声明依赖并存——并行派发器按 wave 声明同时派 T02/T03，T02 先于 T03 完成时：34-archive-commit-check.sh 3e/3f 引用 `$CORRECTION_TYPE_ARCHIVE_UNCOMMITTED`（T03 才定义），`set -u` 下运行 abort（或写空 type JSON）。
**Source**：阶段 3 checklist「依赖图是否无环？可并行部分是否已标 [P]？」——parallel 任务必须互无依赖；DESIGN D3 F2/F4 依赖该常量。
**Consequence**：T02 的 verify 仅 `bash -n`（不检查未绑定变量）→ 竞态产物坏脚本全绿通过；依赖 T03 的 3e/3f 语义在串行执行下恰好正确，问题只在并行派发时爆——波次声明即派发契约，二者矛盾必须消除。
**Remedy**：Wave 1 改 `T01[P], T03[P]`（T02 去 parallel 标记，随 T03 后串行执行），或 T02 移 Wave 2 首项（T04/T06 ← T02,T03 依赖不变，仍无环）。

#### 🟢 R4 · T05 step 2b 注释「install_file 含 chmod」事实错误
**Severity**：🟢 Minor
**Symptom**：TASK.md:131 注释「install_file 含 chmod」；实证 install_hooks.sh:22-31 install_file() 仅 `mkdir -p + cp`，chmod 均由调用方显式执行（:85/:97/:107 `chmod +x ... 2>/dev/null \|\| true`）。
**Source**：install_hooks.sh 既有部署惯例。
**Consequence**：部署后 pre-commit.sh 可执行位依赖 cp 的源 mode 继承（T01 chmod +x 源 + umask 默认 022 → 755 可执行，实际可用），但若未来源可执行位丢失 → git 静默忽略 pre-commit hook（gate 关而不报错）。
**Remedy**：注释改「对齐既有惯例：install_file 后显式 chmod +x」，deploy_pre_commit 补 `chmod +x "$hook_dst/pre-commit/pre-commit.sh" 2>/dev/null \|\| true`。

#### 🟢 R5 · T01 read_files 引用 flow-kit-bundle/Makefile 不存在
**Severity**：🟢 Minor
**Symptom**：TASK.md:20 `flow-kit-bundle/Makefile`；glob 实证 flow-kit-bundle/Makefile 无文件（pre-commit.sh 运行时检查的是目标项目 Makefile，bundle 本身无 Makefile）。
**Consequence**：read 落空，无行为影响；但弱模型可能困惑「参考 Makefile 但读不到」。
**Remedy**：改仓库根 `Makefile` 或删除该 read 项。

### 结构复扫

| 检查项 | 实证 | 状态 |
|---|---|---|
| 8 任务 7 字段 | grep -c '<task' = 8；每 task id/name/read_files/write_files/action/verify/done/depends_on 齐全 | ✅ |
| 波次 DAG 无环 | T02←T03 / T05←T01 / T04,T06←T02,T03 / T07←T04,T05,T06 / T08←T07，无环 | ✅（波次声明与 T02 parallel 矛盾见 🟡R3） |
| write_files ⊂ DESIGN §0.5.1 | 12 文件全在修改/新增清单（T05 package-flow-kit.sh 路径已修正为根） | ✅（validate_staging.sh 漏列见 🔴R2） |
| 禁动零碰撞 | gate 核心链 / checkpoint-lib / .flow-active.goal / PRESET_MAP 零 write；package-flow-kit.sh Part C 例外已显式声明（TASK.md:138） | ✅ |
| verify 可执行 | 8 条均为 bash -n / grep / test 真命令 | ✅ |
| 跨工件一致性 | AC-1→T07 / AC-2→T01+T05 / AC-3→T02+T03+T04+T06 / AC-4→T05 / AC-5→T08 全落 done；D1-D8 接线对齐 | ⚠️ 残留见 N6/N7 |

残留（非阻塞）：
- 🟢 N6 · REQUIREMENT.md:161 仍 `flow-kit-bundle/package-flow-kit.sh`（v2 N2 曾标注「跨工件传染」，仅 TASK 侧修复）——REQUIREMENT 为只读参考，不影响执行，建议后续顺手修。
- 🟢 N7 · DESIGN.md:23 仍「Part D 自动纳入新模块」（实证 Part C L88/97）——v2 N6 deferral 已登记，TASK.md:135 已正确改 Part C，DESIGN 残留待 4-dev 前修。
- 🟢 N8 · REQUIREMENT.md:260 禁动例外声明范围（仅「HOOK_MODULE_NAMES 同步段」）窄于 T05 实际触碰（Part C pre-commit glob cp + fallback 列表）——例外声明应扩为「HOOK_MODULE_NAMES 同步段 + Part C pre-commit 打包段」。

**Verdict**: fail

fail 依据（2🔴）：① R1——v2 N1 只修了变量层，调用点限定（user 模式不部署）未传递，user 模式安装 set -e abort，AC-4 user 场景断，verify 全绿不拦截；② R2——validate_staging.sh:54 Part C pattern 列表漏列 pre-commit/（L-031 漏改类），pre-commit.sh 落盘后 --validate / make check 必 fail，TASK read/write/verify 全未覆盖。

---

## 主 agent 响应（L2 v3 fail → 修复汇报 · 2🔴+1🟡 Fixed / 3🟢 Fixed+Deferred）

- **🔴 R1** Fixed in TASK.md T05 action step 2: deploy_pre_commit 开头加 scope guard `[ "${scope:-}" = "user" ] && return 0`（仅 project 模式部署 · user 模式 project=$HOME 无 .git 目标）
- **🔴 R2** Fixed in TASK.md T05: write_files 加 validate_staging.sh + action step 5 追加 `:54 Part C pattern 列表加 pre-commit/*.sh` + verify 加 grep validate_staging.sh
- **🟡 R3** Fixed in TASK.md 波次声明: Wave 1 改 T01[P],T03[P]→T02（T02 串行 T03 后）+ T02 parallel 属性删除
- **🟢 R4** Fixed in TASK.md T05 step 2b: 注释从「install_file 含 chmod」改为「install_file 仅 cp 无 chmod · 依赖 T01 step 6 chmod +x + cp mode 继承」
- **🟢 R5** Fixed in TASK.md T01 read_files: 删 flow-kit-bundle/Makefile（实证不存在）
- **🟢 N6** Deferred: REQUIREMENT.md:161 路径残留（4-dev 前修）
- **🟢 N7** Deferred: DESIGN.md:23 Part D 标签残留（4-dev 前修）
- **🟢 N8** Deferred: REQUIREMENT.md:260 禁动例外声明范围扩为「HOOK_MODULE_NAMES 同步段 + Part C pre-commit 打包段」（4-dev 前修）

---

## L2 盲审（v4 重审）

### v3 发现核实

| # | 发现 | grep 实证 | 状态 |
|---|------|----------|------|
| 🔴R1 | scope guard | TASK.md:130 `[ "${scope:-}" = "user" ] && return 0` 存在；但调用点（TASK.md:138「install.sh:218/242/252 追加 deploy_pre_commit 调用」）处 `$scope` 不可见 → 见回归 🔴R4 | ⚠️ Partial |
| 🔴R2 | validate_staging pattern | TASK.md:124 write_files 含 `flow-kit-bundle/lib/validate_staging.sh`；:140 step 5 追加 `"$BUNDLE_DIR/hooks/pre-commit/"*.sh` glob；:142 verify `grep -q 'pre-commit' validate_staging.sh`；实证 validate_staging.sh:54-55 现仅 4 glob（stop/lib/session-start/pre-tool-use）待补 | ✅ Fixed |
| 🟡R3 | 波次声明 | TASK.md:8 `Wave 1 (parallel): T01[P], T03[P] → T02`；TASK.md:41 T02 无 parallel 属性（`<task id="T02" status="pending" model-tier="standard">`）；:70 `<depends_on>T03</depends_on>`；DAG T02←T03→T04/T06 无环 | ✅ Fixed |

### 回归扫描

#### 🔴 R4 · scope guard 空转：调用点与守卫的作用域前提矛盾，字面执行 install 全模式 abort（v3 R1 同型复发）
**Severity**：🔴 Critical
**Symptom**：TASK.md:130 守卫 `[ "${scope:-}" = "user" ] && return 0` 要生效，`$scope` 必须在调用处可见；但 TASK.md:138 规定「install.sh:218/242/252 install_hooks() 调用点追加 deploy_pre_commit 调用」。实证：install.sh 全文件**零**小写 `scope`（grep 零命中，仅 HOOK_SCOPE 大写 L17/125/218/241/252）；`scope`/`project`/`hook_dst` 均为 install_hooks() 的 local（install_hooks.sh:37/38/55），动态作用域仅覆盖 install_hooks 函数体及其子调用——install_hooks 返回后即消失。按字面执行（L242 `install_hooks "$HOME" "user"` 后跟调用）：`${scope:-}`="" → 守卫恒 false 不 return → `local target="${project}/.git/hooks/pre-commit"`（$project 空 → `/.git/hooks/pre-commit`）→ 2b `install_file ... "$hook_dst/pre-commit/pre-commit.sh"`（$hook_dst 空 → `mkdir -p /pre-commit` 权限拒绝）→ install.sh:6 `set -euo pipefail` **abort**。T05 verify（TASK.md:142：bash -n + grep FLOW_KIT_YES/deploy_pre_commit/pre-commit）全绿不拦截。
**Source**：v3 R1 Remedy 原文要求「deploy_pre_commit 仅在 project 模式调用点追加」——其成立前提是函数在 install_hooks() 体内调用（动态作用域拿 $scope）；v4 只加了守卫未落实调用位置。CONTEXT「protect the weakest」——task 伪代码必须字面可执行，不能靠执行者猜调用上下文。AC-4 Given 含 user 模式全新安装。
**Consequence**：弱模型按 step 3 字面在三处 install.sh 调用点（其中 L242 即 user 模式）追加调用 → 任何模式安装（含 --project、--hooks-only）到 deploy 步必 abort；user 模式 AC-4 场景断——与 v3 R1「install 断 + verify 绿」完全同型，第 4 轮复发。
**Remedy**：二选一。①（推荐）step 3 改「在 install_hooks() 函数体内追加调用（stop-hooks 安装循环后、函数结束前）——$scope/$project/$hook_dst 为其 local，动态作用域下 deploy_pre_commit 直接可见；install.sh:218/242/252 仅作三种模式说明，不追加调用」；② 给函数显式签名 `deploy_pre_commit "$project" "$scope" "$hook_dst"` 并在 install.sh 三调用点传 `"$TARGET_PROJECT" "$HOOK_SCOPE" ...`（需先让 install_hooks 输出 hook_dst，改动更大）。另：verify 追加调用点检查（如 grep 'deploy_pre_commit' 于安装段内），否则 R1 类缺陷第 5 轮仍全绿。

### 结构复扫

| 检查项 | 实证 | 状态 |
|---|---|---|
| 8 任务 7 字段 | T01-T08 各含 id/name/read_files/write_files/action/verify/done/depends_on（grep -c '<task' = 8） | ✅ |
| 波次 DAG 无环 | T02←T03（:70）/ T04←T02,T03 / T05←T01 / T06←T02,T03 / T07←T04,T05,T06 / T08←T07；W2 并行组 T04/T05/T06 互无依赖 | ✅ |
| write_files ⊂ DESIGN §0.5.1 | 14 文件；**validate_staging.sh 不在 DESIGN 0.5.1 清单**（v3 R2 修复仅进 TASK）→ 见 🟢R6；余全对齐 | ⚠️ |
| 禁动零碰撞 | gate 核心链 / checkpoint-lib / .flow-active.goal / PRESET_MAP 零 write；package-flow-kit.sh 禁动例外显式声明（TASK.md:139）；HOOK_MODULE_NAMES 条件禁动由 T04+T05 同步满足；commit-protocol 仅动归档段不碰任务级 | ✅ |
| verify 可执行 | 8 条均为 bash -n / grep / test 真命令（T08 三条件：rc=0 + not ok=0 + ok≥692，防 TD-012） | ✅ |
| 跨工件一致性 | AC-1→T07 / AC-2→T01+T05 / AC-3→T02,T03,T04,T06 / AC-4→T05 / AC-5→T08 全落 done；D1-D8 接线对齐 | ⚠️ 见 🟢R7/R8 |
| 回归项核查 | T01 shebang+set -euo pipefail+chmod ✅（:28-35）/ T02 ${PROJECT_ROOT}+cd+\|\| echo 0 ✅（:61-62）/ T03 readonly ✅（:83）/ T04 done「默认 false」✅（:109，common.sh:25 实证）/ T06 jq 括号修复 ✅（:160）/ T07 ARCHIVE_BASE_SHA→STATE.md ✅（:186）/ T08 verify ✅（:213） | ✅ |

残留（🟢，非阻塞）：
- 🟢 R5 · T05 read_files 缺 validate_staging.sh：write_files（:124）含而 read_files（:115-120）不含 → write ⊄ read，违反阶段 3「read ⊇ write」惯例。
- 🟢 R6 · DESIGN §0.5.1 未列 validate_staging.sh：v3 R2 修复只进 TASK 未同步 DESIGN（4-dev 1.4 按 DESIGN 范围核对会误判越界）。
- 🟢 R7 · 行号锚点漂移：00-gate.sh 33 号 run_module 实际 L119（非 L120）、99-report 实际 L121（非 L123）；flow-kit-resume.sh l2-missing elif 实际 L146（非 L147）、else 实际 L151（非 L152）。位置描述（「33 后、99 前」/「l2-missing 后、else 前」）正确，无行为影响；DESIGN.md:23「Part D」标签残留（v3 N7 已登记未处置）。
- 🟢 R8 · AC-3 单阶段 Given 漂移：REQUIREMENT.md:85「mtime > active_since」vs TASK:62 实现「arch_mtime > last_commit_ts」（git 锚点）。DESIGN D3 F3 注明确有依据（checkpoint bump 干扰），属有意偏差，REQUIREMENT 待同步。

**Verdict**: fail

fail 依据（🔴 R4）：scope guard 的生效前提（调用处于 install_hooks() 动态作用域内）与 TASK step 3 声明的调用点（install.sh:218/242/252，$scope/$project/$hook_dst 均不可见）矛盾——字面执行守卫恒 false，全模式 install 到 deploy 步 set -e abort，user 模式 AC-4 断；verify（bash -n + grep）全绿不拦截。v3 R1「install 断 + verify 绿」第 4 轮同型复发，本次是调用位置层面而非变量层面。

---

## 主 agent 响应（L2 v4 fail → 修复汇报 · 1🔴 Fixed）

- **🔴 R4** Fixed in TASK.md T05 action step 3: deploy_pre_commit 调用位置从 install.sh:218/242/252（调用点 · $scope/$project/$hook_dst 不可见 → guard 空转）改为 **install_hooks() 函数体内**（install_hooks.sh · stop hooks 段之后 · 动态作用域 $scope/$project/$hook_dst 可见 · scope guard 生效）

---

## L2 盲审（v5 重审）

### v4 发现核实

| # | 发现 | grep 实证 | 状态 |
|---|------|----------|------|
| 🔴R4 | deploy_pre_commit 调用位置 → install_hooks() 函数体内（非 install.sh:218/242/252 调用点） | TASK.md:138 step 3：「在 **install_hooks() 函数体内**（install_hooks.sh）调用——stop hooks 安装段之后追加 `deploy_pre_commit`…**禁止**在 install.sh:218/242/252 调用点调用」；install_hooks.sh:37 `local project="$1"` / :38 `local scope="${2:-project}"` / :55 `local hook_dst` 实证（locals 在函数体内对被调函数可见 = bash 动态作用域 → scope guard 生效）；install.sh:218 `install_hooks "$TARGET_PROJECT" "$HOOK_SCOPE"` / :242 `install_hooks "$HOME" "user"` / :252 `install_hooks "$TARGET_PROJECT" "$HOOK_SCOPE"` 实证即三调用点 | ✅ Fixed |

### 回归扫描

（v5 引入 1🔴 + 1🟡）

#### 🔴 S1 · scope guard 全量阻断 user-scope 部署：AC-4「install.sh --user」Given 的 Then 未实现 + ADR-022 用户目标路径永不落盘 + CONTEXT 标准流（user-scope hooks）项目无门禁
**Severity**：🔴 Critical
**Symptom**：TASK.md:130 step 0 守卫 `[ "${scope:-}" = "user" ] && return 0` 位于 deploy_pre_commit 首行 → scope=user 时**复制与 symlink 全部跳过**。实证可达性：install.sh:125 `--user) HOOK_SCOPE="user"` + :218（--hooks-only）/ :252（--project）`install_hooks "$TARGET_PROJECT" "$HOOK_SCOPE"` → `bash install.sh --project X --user` 即 `install_hooks "$X" "user"`（hook_dst=$USER_HOOKS_DIR，install_hooks.sh:58-60 实证）→ 守卫 return 0 → X 的 pre-commit 门禁**不部署**。同时 `install.sh --global --user`（L242）也跳过复制 → `~/.claude/hooks/pre-commit/pre-commit.sh` **永不落盘**。
**Source**：REQUIREMENT AC-4 Given「全新安装（install.sh --user 或项目级）」→ Then「部署 pre-commit hook 脚本」；DESIGN D1/ADR-022「symlink → 已安装 hooks 目录（user: `~/.claude/hooks/pre-commit/pre-commit.sh`）」——user 目标路径是部署契约的一部分；CONTEXT 已锁「user-scope hooks 统一 — hooks 只装 user scope，项目级不接线」（user-scope 即标准流）。
**Consequence**：标准流（--project --user / --hooks-only --user）项目**静默无门禁**（无报错、verify 全绿），L-023「commit-time 测试门禁」在本 change 主打流不闭合；ADR-022 user 目标 `~/.claude/hooks/pre-commit/` 结构性不可达——任何按 D1 指向它的 symlink 必悬空；AC-4 --user Given 分支的 Then（部署）字面未实现。与 v1 🔴#1「部署断」同类：设计层面而非执行层面断。
**Remedy**：守卫语义拆分——**复制恒执行**（user scope → `$USER_HOOKS_DIR/pre-commit/` 落盘，对齐 ADR-022 user 目标；project scope → `$hook_dst/pre-commit/`），**仅 symlink 按 .git 存在性守卫**：
```
deploy_pre_commit() {
  install_file "$SCRIPT_DIR/hooks/pre-commit/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"   # 恒执行
  local target="${project}/.git/hooks/pre-commit"
  [ -d "${project}/.git" ] || return 0        # 守卫：~/.git 不存在 → 不 ln（防 v3 R1 abort）；项目有 .git → 正常 ln
  ...2c/2d 冲突检测 + ln -sf 不变
}
```
三场景自洽：L242（$HOME 无 .git）→ 仅复制不 ln ✅；`--project X --user` → 复制到 ~/.claude/hooks/pre-commit/ + symlink X/.git/hooks → user 目标 ✅；`--project X` → 复制到 X/.claude/hooks/ + symlink ✅。若 v1 明确排除 user-scope 流，则 REQUIREMENT AC-4 Given + DESIGN D1/ADR-022 必须显式声明（当前三工件互相矛盾，不能靠「执行者猜」）。

#### 🟡 S2 · T05 verify 无调用位置检查：v4 R4 Remedy 明确要求未落实，「install 断 + verify 绿」缺陷类第 5 轮仍可全绿回归
**Severity**：🟡 Important
**Symptom**：TASK.md:142 verify = `bash -n install.sh && bash -n install_hooks.sh && grep -q 'FLOW_KIT_YES' install.sh && grep -q 'deploy_pre_commit' install_hooks.sh && grep -q 'pre-commit.*\.sh' package-flow-kit.sh && grep -q 'pre-commit' validate_staging.sh`——`grep 'deploy_pre_commit'` 只验证函数**定义存在**，若执行者把调用放回 install.sh:218/242/252（R4 禁止模式），定义仍在 install_hooks.sh → verify 全绿。
**Source**：v4 R4 Remedy 原文「另：verify 追加调用点检查（如 grep 'deploy_pre_commit' 于安装段内），否则 R1 类缺陷第 5 轮仍全绿」——v5 未落实；阶段 3 checklist「verify 可机器验证」。
**Consequence**：R4 修复无回归护栏——4 轮同型复发（变量层→调用点层→调用位置层）已验证 verify 空白是缺陷复发的温床；本轮修复正确但下轮改 install.sh 时可能静默回退。
**Remedy**：verify 追加机器可验证的禁令检查：`&& ! grep -q 'deploy_pre_commit' flow-kit-bundle/install.sh`（R4 禁止 install.sh 调用点 → install.sh 全文件不得含该字符串，grep 可判）。

### 结构终扫

| 检查项 | 实证 | 状态 |
|---|---|---|
| 8 任务 7 字段 | grep -c '<task' TASK.md = 8；每 task 含 id/name/read_files/write_files/action/verify/done/depends_on（T01-T08 逐条核对） | ✅ |
| 波次 DAG 无环 | Wave 1: T01[P],T03[P]→T02（T02 串行 T03 后 · :8 声明 + :41 无 parallel 属性 + :70 depends_on T03）；Wave 2: T04←T02,T03 / T05←T01 / T06←T02,T03（[P] 互无依赖）；Wave 3: T07←T04,T05,T06；Wave 4: T08←T07；无环 | ✅ |
| write_files ⊂ DESIGN §0.5.1 | 13 文件；12 在修改/新增清单；`validate_staging.sh`（TASK.md:124）不在 DESIGN §0.5.1（v4 🟢R6 未处置 · 残留）；package-flow-kit.sh 路径已修正为根（:125） | ⚠️ 残留 🟢 |
| 禁动零碰撞 | gate 核心链 / checkpoint-lib / .flow-active.goal / PRESET_MAP 零 write；package-flow-kit.sh 禁动例外显式声明（TASK.md:139 · Part C pre-commit glob + fallback 34）；HOOK_MODULE_NAMES 条件禁动由 T04+T05 三处同步满足（common.sh / install_hooks.sh:81 / package-flow-kit.sh:104-112 fallback 均覆盖） | ✅ |
| verify 可执行 | 8 条均 bash -n / grep / test 真命令；T08 三条件（rc=0 + not ok=0 + ok≥692 · TD-012 防）✅；T07 含 commit-protocol grep ✅；唯一缺口 = S2（T05 调用位置） | ⚠️ 见 S2 |
| 跨工件一致性 | AC-1→T07（ARCHIVE_BASE_SHA→STATE.md · :186）/ AC-2→T01（四分支+chmod · :27-35）+T05 / AC-3→T02,T03,T04,T06 / AC-4→T05 / AC-5→T08 全落 done；D1→T05 / D2→T01 / D3→T02+T04 / D4→T06 / D5→T03 / D6+D7→T07 接线对齐；00-gate.sh 锚点实测 33=L120 / 99=L123（T04 声明精确） | ✅ |
| 回归项核查 | T02 ${PROJECT_ROOT}+cd+\|\| echo 0 ✅（:62，对齐 install_hooks.sh 实证）/ T03 readonly ✅（:83，correction-types.sh:20-21 实证）/ T04 done「默认 false」✅（:109，common.sh:25 实证）/ T05 Part C 变量实证（HOOK_SRC:93 / STAGING:13）✅ / T06 jq 括号 ✅（:160） | ✅ |

残留（🟢 非阻塞，均先轮已登记未处置）：① DESIGN §0.5.1 未列 validate_staging.sh（v4 R6）；② DESIGN.md:23「Part D」标签残留（v2 N6/v3 N7）；③ REQUIREMENT.md:161 `flow-kit-bundle/package-flow-kit.sh` 路径残留（v2 N6）；④ REQUIREMENT AC-3 单阶段 Given（active_since）vs 实现（git commit ts）漂移——DESIGN D3 F3 注明的有意偏差（v4 R8）。

**Verdict**: fail

fail 依据（🔴 S1）：scope guard `[ "${scope:-}" = "user" ] && return 0` 全量阻断 user-scope 部署——`install.sh --project X --user` / `--hooks-only --user`（CONTEXT 已锁标准流）项目静默无 pre-commit 门禁，AC-4「install.sh --user」Given 的 Then（部署）字面未实现；`~/.claude/hooks/pre-commit/pre-commit.sh`（DESIGN D1/ADR-022 user 目标）永不落盘，ADR-022 部署模型结构性不可达。v4 R4 本身（调用位置）✅ Fixed，但守卫语义与 ADR-022/AC-4 矛盾在 v5 新暴露。修复路径：复制恒执行 + symlink 按 `[ -d "${project}/.git" ]` 守卫（S1 Remedy 三场景自洽）。

---

## 主 agent 响应（L2 v5 fail → 修复汇报 · 1🔴+1🟡 Fixed）

- **🔴 S1** Fixed in TASK.md T05 action step 2.0: scope guard 从 `[ "${scope:-}" = "user" ] && return 0`（全量阻断 user-scope → ~/.claude/hooks/pre-commit/ 永不落盘 → ADR-022 user 目标不可达）改为 `[ -d "${project}/.git" ] || return 0`（基于 .git 存在性 · user-global L242 project=$HOME 无 .git → skip · project L218/252 含 .git → 部署 · scope=user 时 hook_dst=USER_HOOKS_DIR 正确落盘）
- **🟡 S2** Fixed in TASK.md T05 verify: 追加 `! grep -q 'deploy_pre_commit' flow-kit-bundle/install.sh`（调用位置检查 · 确保 deploy_pre_commit 在 install_hooks.sh 不在 install.sh · 防 R4 类回归）

---

## L2 盲审（v6 重审）

### v5 发现核实

| # | 发现 | grep 实证 | 状态 |
|---|------|----------|------|
| 🔴S1 | guard .git-based | TASK.md:130 `[ -d "${project}/.git" ] || return 0`（grep `\.git.*return 0` 命中；scope-based guard 已移除） | ✅ Fixed |
| 🟡S2 | verify 调用位置 | TASK.md:142 verify 含 `! grep -q 'deploy_pre_commit' flow-kit-bundle/install.sh`（grep `!.*deploy_pre_commit.*install\.sh` 命中） | ✅ Fixed |

**S1 三方实证**（非仅文本）：
- install.sh:242 `install_hooks "$HOME" "user"`（user-global · project=$HOME 无 .git）→ guard return 0 → **skip 不 abort**（回归扫描关键）
- install.sh:218（hooks-only）/ :252（project 模式）`install_hooks "$TARGET_PROJECT" "$HOOK_SCOPE"`（含 .git）→ 正常部署
- install_hooks.sh:37-38 `local project="$1"` / `local scope="${2:-project}"`、L55-68 `hook_dst`（user→`$USER_HOOKS_DIR` / project→`${project}/.claude/hooks`）→ deploy_pre_commit 在函数体内调用（TASK step 3）动态作用域可见；scope=user 时 pre-commit.sh 落盘 `~/.claude/hooks/pre-commit/pre-commit.sh`（=ADR-022 user 目标）→ ADR-022 用户目标路径可达

**S1 Remedy 执行链完整**：step 2.0 guard（0）→ `local target`（a）→ `install_file` 先复制（b · install_hooks.sh:22-33 实证仅 cp 无 chmod，TASK 正确标注依赖 T01 step 6 chmod +x + cp mode 继承）→ D8 冲突检测（c）→ `ln -sf` 指向已落盘文件（d）→ 无悬空 symlink。step 3 显式禁止 install.sh:218/242/252 调用点调用（$project/$hook_dst 不可见 → guard 空转 + unset 变量 → 全模式 abort），与 S2 verify 互相印证。

### 回归扫描

**无新增 🔴🟡**：
- user-global L242 正确 skip：guard return 0 短路于任何 install_file/ln 之前，不 abort、不产生半成品
- ln -sf 幂等（ADR-022 幂等部署）；D8 既有非 symlink 文件检测分支保留（--yes 跳过 / 交互询问）
- step 2b 先复制后链接 → v4 R1 悬空 symlink 类问题无回归
- S2 `! grep deploy_pre_commit install.sh` 与 step 3 约束一致，无逻辑矛盾

### 结构终扫

| 项 | 实证 | 状态 |
|---|---|------|
| 8 任务 7 字段 | `grep -c '<task '` = 8；name/read_files/write_files/action/verify/done/depends_on 各 8 处 | ✅ |
| DAG 无环 | T01,T03(w1) → T02(←T03) → T04,T06(←T02,T03)、T05(←T01) → T07(←T04,T05,T06) → T08(←T07)；parallel 仅 w1/w2 | ✅ |
| write_files ⊂ DESIGN §0.5.1 | 11/12 命中（含 T05 四文件）；validate_staging.sh 仍不在 §0.5.1（🟢 v4 R6 已登记）；DESIGN.md:23「Part D」标签 vs 实际 Part C L88（🟢 v2 N6 已登记）——均非新增 | ⚠️ 旧🟢 |
| 禁动零碰撞 | package-flow-kit.sh Part C 触碰有显式例外声明（TASK:139 · 对齐 superpowers-v6-absorb 先例）；gate 核心链 / checkpoint-lib / .flow-active.goal / PRESET_MAP 零 write | ✅ |
| verify 可执行 | 8 条全为 bash -n / grep / test / npx bats 机器命令 | ✅ |
| 跨工件 | D1→T05 / D2→T01 / D3→T02+T04 / D4→T06 / D5→T03 / D6+D7→T07；AC-1→T07, AC-2→T01,T05, AC-3→T02,T03,T04,T06, AC-4→T05, AC-5→T08 全落 done；锚点精确（common.sh:270 HOOK_MODULE_NAMES · install_hooks.sh:81 fallback · validate_staging.sh:54 Part C patterns · pkg Part C L88-103 + fallback L103-112 实测） | ✅ |

**Verdict**: pass
