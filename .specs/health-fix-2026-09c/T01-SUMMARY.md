# T01-SUMMARY — C12 门禁运行期 fail-closed（AC-8）

change: health-fix-2026-09c · 任务: T01 · 状态: done（verify 8/8 绿）

## 改动清单（file:line 为改后行号）

### flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
- `:14-16` 头注释 fail 策略改写：jq 缺失/非法 JSON/子库函数缺失 → exit 2 拒绝放行；非管辖面（非 Bash/Write/Edit、无 .flow-active、非 review phase、gate 未开）仍 exit 0。原「jq 不可用 → exit 0 放行」与新行为矛盾，同文件内同步（越界=无）。
- `:49-62` **新增**：source 三子库后按 `:36-41` 既有 `declare -f` 范式断言 13 个关键函数（_gate_path_guard/_gate_phase_filter/_gate_active_check/_gate_done_validation/_gate_tamper_detect/fk_check_gate_config_tamper/is_phase_write/is_git_commit/_gate_check_l2/_gate_check_l3/_gate_phase_transition/_gate_do_transition/_gate_deny_reason，全部经 grep 逐名核实存在）。缺失 → `[gate] 子库加载失败…拒绝放行` exit 2。函数名单覆盖三子库+types 库各自的入口函数（AC-8 第三注入面）。注释显式注明「函数遮蔽/重定义为空体不在断言范围——declare -f 只证存在不证行为（DESIGN D4）」。
- `:79-81` 原 :64（无 .flow-active → exit 0）**保留放行** + 注释固化语义：无状态文件=非 flow-kit 管辖项目，门禁不得对外部项目生效；fail-closed 仅覆盖「有状态文件但依赖失效」。
- `:82-84` 原 :65 `jq empty || exit 0` 拆为两行 fail-close：jq 缺失 → exit 2（`[gate] jq 不可用…`）；.flow-active 非法 JSON → exit 2（`[gate] .flow-active 非法 JSON…`，报文含 R7 要求的「状态文件可能正在写入，重试一次」指引）。
- `:133-134` 原 :114 `command -v jq || exit 0` → exit 2 具名报文（`[gate] jq 不可用…无法解析 hook stdin JSON…`）。

### flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh
- `:5-6` 头注释 :5 改写：放行=非管辖面枚举；新增「拒绝: exit 2（C12: jq 缺失或 .flow-active 非法 JSON）」。
- `:12` 原 :11「DESIGN D4: fail-open」改写为「依赖失效（jq/解析）fail-closed exit 2；检查点写入失败仍 fail-open」。
- `:23`+`:27`+`:29` `_auto_ck_active_change` 返回语义扩为 0=有活跃/1=无（合法）/2=状态不可判（jq 缺失或非法 JSON）；删除 `|| echo ""` 吞错，改 `|| return 2`。
- `:66-67` 原 :64 jq 检查 → exit 2 具名报文（`[auto-checkpoint] jq 不可用…`）。
- `:77-86` 原 :74-77 无活跃分支 → `_ck_rc=0; _auto_ck_active_change … || _ck_rc=$?`（L-049 范式，set -e 安全）+ case：rc=1 放行；rc=2 → `[auto-checkpoint] .flow-active 状态不可判…` exit 2（含 R7 重试指引）。
- `:107` CK_LIB 缺失分支**保留 fail-open**（见决策记录）；注释由「fail-open（AC-5）」改为「检查点可选：checkpoint-lib 缺失不阻断工具调用，非 C12 依赖失效面」。
- `:116` 末行注释由「fail-open · 永远不阻断」改为「正常完成」。

### flow-kit-bundle/hooks/stop/lib/l3-{review,prompt,section}.sh
- `l3-review.sh:35-38`、`l3-prompt.sh:13-18`、`l3-section.sh:46-50`：各加顶层 jq 存在性断言，`command -v jq … || { echo "[l3-*] jq 不可用…" >&2; exit 1; }`——exit 1 = Stop 检查器语义（DESIGN D4）；风格对齐 common.sh:226 断言范式 + 各文件 `[模块名]` 报文前缀。
- l3-section.sh 本身零 jq 调用（纯 awk/sed/grep）——断言是 D4 明示的**链级纵深**（ADR-032，超出 AC-8 字面），代码注释已显式注明该事实。
- 执行顺序核验：gate 经 `_gate_do_transition`/`_gate_check_l3` source l3-review.sh 发生在 :133/:82 jq 检查**之后**，故 l3 库 exit 1 断言不会破坏 gate 的 exit 2 语义。

### 新建（逐字节相同镜像，`cmp` 验证通过）
- `test/test_fail_closed.bats`（154 行，8 用例）
- `flow-kit-bundle/test/test_fail_closed.bats`（同上）

## verify 真实输出

`npx bats test/test_fail_closed.bats`（仓库根）与 `cd flow-kit-bundle && npx bats test/test_fail_closed.bats`（镜像位）均 **8/8 ok，exit 0**：

```
1..8
ok 1 AC-8① gate: jq 遮蔽 → exit 2 拒绝放行（具名报文）
ok 2 AC-8① auto-checkpoint: jq 遮蔽 → exit 2 拒绝放行（具名报文）
ok 3 AC-8② gate: .flow-active 非法 JSON → exit 2 拒绝放行（具名报文）
ok 4 AC-8② auto-checkpoint: .flow-active 非法 JSON → exit 2 拒绝放行（具名报文）
ok 5 AC-8③ gate: 子库关键函数缺失（declare -f 断言面）→ exit 2 拒绝放行
ok 6 反向控制 gate: 正常输入 → exit 0（新断言不误伤）
ok 7 反向控制 auto-checkpoint: Read 工具（非编辑）→ exit 0
ok 8 反向控制 auto-checkpoint: Write + 合法 .flow-active → exit 0 且 checkpoint 正常写入
```

覆盖 AC-8 三注入面（①影子 PATH ×2 hook ②非法 JSON ×2 hook ③函数缺失）+ 反向控制 ×3（含 :64 保留放行语义与 checkpoint 正常写入）。技术要点：jq 遮蔽按 L-127 定式（影子目录软链真实工具但排除 jq、PATH 整体替换 + 前提自检 jq 不可见/dirname 在场）；断言 stderr 内容把失败钉在判据域内（L-091，如 grep "jq 不可用"/"_gate_check_l2 未定义"）；期望非零退出用 `rc=0; cmd || rc=$?` 捕获（L-049 / test_gate_integrity.bats:6 既有约定——bats set -e 会把预期 exit 2 当失败中止）。BUNDLE_ROOT 向上查找范式沿 test_auto_checkpoint.bats:11-17（双镜像位均可跑，已实证）。

另：5 个改动 shell 文件 `bash -n` 语法全过；jq 在场时 source l3-section/l3-prompt 断言静默通过（不误伤）。

## 破坏性变更（flow-dev 1.8）

**运行时语义反转**：两 PreToolUse hook 的依赖失效面从 fail-open（exit 0 静默放行）→ fail-closed（exit 2 拒绝放行）。影响面：
- 环境 jq 缺失或 .flow-active 损坏时，原本静默放行的 Bash/Write/Edit 调用现在被 **block**（报文含修复指引）。这是 C12/AC-8 的设计意图，但对「依赖装了一半还照常干活」的使用者是行为变化。
- 引用面（grep）：independent-review-gate.sh 被 test_review_gate_validity / test-is-git-commit-structural / test_gate_integrity / test_l3_review_defects_2026_09 等引用；auto-checkpoint.sh 被 test_auto_checkpoint 引用。
- **已实证的连带红（须 5-test 阶段或编排者处置）**：`test/test_auto_checkpoint.bats` 用例 8/9（:129-137/:139-149，AC-5「corrupt JSON → exit 0 不阻断」）现在 **not ok**（实测 exit 2，报文即新 fail-closed 报文）——该文件不在 T01 write_files，未动；这两例断言的正是 C12 刻意反转的旧 fail-open 契约，应改为断言 exit 2（连同其镜像 flow-kit-bundle/test/）。其余 11/13 例仍绿。test_review_gate_validity.bats:142「无 .flow-active 放行」与 :64 保留语义一致，不受影响。

## 决策与偏差记录

1. **auto-checkpoint 的 CK_LIB 缺失（:107）与 checkpoint_write 失败（:112-114）保留 fail-open**：DESIGN 0.5.1 对 auto-checkpoint 点名的 fail-open 转换点是「jq 失败/解析失败」；checkpoint-lib 缺失/写失败属「检查点可选」业务语义（DESIGN D6/auto-checkpoint 原设计），不在 AC-8 三注入面内。头注释如实分层（放行=非管辖枚举 / 拒绝=依赖失效面），避免过度声明。
2. **gate 头注释 :14-15 改写**（同文件内）：任务书未点名，但原文与新行为直接矛盾，留下即成陈旧注释缺陷；已在上方改动清单记录。
3. **镜像双写方式**：未跑 `make test-sync`（并行竞态禁令）；先写 test/ 版本，`cp` 单文件到 flow-kit-bundle/test/（只触碰本任务自己的新文件，无竞态），`cmp` 证逐字节相同，且镜像位实跑 8/8 绿。
4. **auto-checkpoint stdin 解析吞错点（:69/:82 `|| echo ""`）未转 fail-closed**：stdin tool_name/file_path 解析失败不在 AC-8 注入面（AC-8② 明指 `.flow-active`）；非任务面，未动。
5. l3-review.sh 内部 `timeout … bash -c 'source l3-review.sh; …'`（:216 附近）会在子 shell 重跑顶层断言——jq 在场时无影响，无需改。

## 6 维自查

| 维 | 结果 | 说明 |
|---|---|---|
| R1 函数>50行/嵌套>3 | 🟡 | `_run_review_gates` 51→56 行（含注释/空行；DESIGN D2 ≤40 预算改前已超）。新增均为状态入口 fail-closed 守卫，嵌套≤2 层，无处拆分获益（守卫必须位于 flow_file 取用点）。无 🔴。 |
| R2 越界 | ✅ | 仅 write_files 10 文件中的 7 个（gate-helpers/gate-checks-basic/gate-checks-review 三文件本次无需改动——断言加在编排器侧）+ 本 SUMMARY + 2 个新建测试文件。见下方越界检查。 |
| R3 重复粘贴 | 🟡 | jq 断言单行在 5 个文件重复：每文件是独立 fail-closed 面，共享守卫会在「依赖未验证前引入新 source 依赖」（鸡生蛋）；且沿 common.sh:226 既有 per-site 惯例。接受。 |
| R4 多余抽象 | ✅ | 零新函数/零新文件级抽象；l3-section 断言看似多余（零 jq 调用）但为 D4 明示链级纵深，注释已注明。 |
| R5 依赖反向 | ✅ | 只加固既有依赖（jq/三子库），无新增依赖边；l3 三库经链路本就依赖 jq。 |
| R6 命名 | ✅ | `_gate_fn`/`_auto_ck_rc`/`_make_shadow_bin` 符合各文件内部下划线惯例；报文沿 `[gate]`/`[auto-checkpoint]`/`[l3-*]` 模块前缀惯例。 |

## 越界检查（git status --porcelain）

本任务改动（与 write_files 一致 + 新建测试）：
- `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`、`auto-checkpoint.sh`
- `flow-kit-bundle/hooks/stop/lib/l3-review.sh`、`l3-prompt.sh`、`l3-section.sh`
- `test/test_fail_closed.bats`、`flow-kit-bundle/test/test_fail_closed.bats`（新建）
- `.specs/health-fix-2026-09c/T01-SUMMARY.md`（本文件）

非本任务（并行任务与既有 spec 工件，未触碰）：`.specs/CONTEXT.md`/`LESSONS.md`/`STATE.md`（M）、`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（M）、`flow-kit-bundle/hooks/stop/29-independent-review.sh`（M）、`test(|flow-kit-bundle/test)/test_check_gate_sync.bats`（M）、`test(|flow-kit-bundle/test)/test_path_privacy_gate.bats`（M）、`.specs/adr/030|031|032-*.md`、`.specs/health/2026-09-29-HEALTH.md`、`.specs/health-fix-2026-09c/`（??，含本 SUMMARY）。未跑 `make check-test-sync` / `make test-sync`；无 git commit。
