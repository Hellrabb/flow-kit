# T02 — C4 恢复积压 L3 失败告警（AC-6）

- **变更**: health-fix-2026-09c
- **任务**: T02（TASK.md:68-89）
- **日期**: 2026-09-30
- **状态**: done（verify 4/4 通过；SUMMARY 就位，待 wave 汇总）

## 做了什么

修复 `flow-kit-bundle/hooks/stop/29-independent-review.sh` `_l3_scan_backlog` 中 C4 缺陷：
原 `l3_review_run … || true` 把 rc 吞成 0，后续 `if [ "$bl_rc" != "0" ]` 告警分支恒为死码
——积压 L3 失败静默无告警。按 DESIGN D6「前置捕获」改法（L2 r4 R5 修订版，非裸删）：

1. 失败 rc 用 `|| bl_rc=$?` 前置捕获（**不是**裸删 `|| true`——:13 `set -euo pipefail` 下
   裸删会让脚本在失败点直接终止、warning 永不打印，AC-6 不成立）；
2. 失败分支 `module_output "warning" "IR" "backlog L3 failed for phase …"` 实际执行（对齐
   AC-6 原文的 warning 级；通道=module_output，见下方偏差记录①）；
3. rc 不吞：首个失败 rc 存入 `bl_fail_rc`，函数末尾 `return "$bl_fail_rc"` → 经 :231 顶层
   未防护调用 + set -e 转为脚本退出码（透传信号，非阻断——Stop 链兜底 =
   00-gate.sh:71 `run_module … || true`，模块 rc 非致命，兜底逻辑不受影响）；
4. 首失败后继续扫描（3-cap 逐次补扫语义保留）；多个失败时逐相位各出一条 warning，
   透传首个失败 rc。

新建 bats 测试（root 与 bundle 镜像双份，逐字节相同）注入失败 `l3_review_run`
（沙箱 HOOK_BASE_DIR 复制生产 lib 后函数覆写），断言 warning 实际写入 + rc 透传，
含成功反向控制。

## 改动清单（文件:行）

| 文件 | 位置 | 内容 |
|---|---|---|
| `flow-kit-bundle/hooks/stop/29-independent-review.sh` | :11-12 | 头注释修正：原「任何路径都 exit 0」已失真（:156 有 exit 3）且不再覆盖新语义；改为「00-gate 兜底 + exit 3 + backlog rc 透传」 |
| `flow-kit-bundle/hooks/stop/29-independent-review.sh` | :196 | `local count=0` → `local count=0 bl_fail_rc=0`（透传载体） |
| `flow-kit-bundle/hooks/stop/29-independent-review.sh` | :201-217 | 核心修复：D6 前置捕获注释块 + `local bl_rc=0` / `… \|\| bl_rc=$?` + 保留原 warning 文案 + `bl_fail_rc` 首败记录 + 函数末 `return "$bl_fail_rc"` |
| `test/test_l3_backlog_alarm.bats` | 新文件（124 行） | 4 用例：失败主断言 / 成功反向控制 / 多积压相位 / 积压选择门完好 |
| `flow-kit-bundle/test/test_l3_backlog_alarm.bats` | 新文件 | 上者的逐字节镜像（`cmp` 验证通过；手动双写，未跑 make test-sync） |

29 脚本其余 14 处 `|| true` 未动（本任务只修 backlog 这一处）。

## verify 真实输出

规定命令 `npx bats test/test_l3_backlog_alarm.bats`：

```
1..4
ok 1 AC-6: backlog L3 失败 → warning 实际写入 + rc 透传（D6 前置捕获，非裸删）
ok 2 AC-6 反向控制: backlog 成功 → 无 backlog warning 且 rc 0（主路径正常走完）
ok 3 AC-6: 多积压相位逐个告警（首败不中止扫描），首个失败 rc 透传
ok 4 AC-6: gate 未开启 L3 的相位不入积压 → 无 backlog 告警、rc 0（主路径失败仍 exit 0 属既有语义）
```

**4/4 通过。**（stderr 仅 `npm notice run npx` 噪音。）

补充 RED 证明（TDD 纪律；一次性临时文件于 /tmp，未触碰仓库树）：把新测试用例指向
`git show HEAD:` 的修复前脚本重跑 →

```
not ok 1 … `[ "$status" -eq 7 ]' failed
ok 2 …
not ok 3 … `[ "$status" -eq 9 ]' failed
ok 4 …
```

恰好两个失败路径用例在旧代码上红（warning 未写、rc 被吞成 0），控制用例仍绿——证明
测试真实检测 C4 缺陷，非空转断言。

镜像一致性：`cmp test/test_l3_backlog_alarm.bats flow-kit-bundle/test/test_l3_backlog_alarm.bats`
静默通过（逐字节相同）。

## 6 维自查（R1-R6 内置快查）

- **R1 认知过载** ✅：`_l3_scan_backlog` 修复后 ~43 行（原 ~34），仍单一职责；无新嵌套层级。
- **R2 变更传播** ✅：diff 仅 `_l3_scan_backlog` 区 + :11 头注释（头注释与本缺陷直接相关：
  原句断言「任何路径都 exit 0」因 rc 透传进一步失真）。与并行任务（C8 载体收敛，动
  :138/:239）无行重叠。
- **R3 知识重复** ✅：未复制逻辑；warning 文案为 AC-6 原文钦定，保持一致。
- **R4 偶然复杂** ✅：仅加 `bl_rc`/`bl_fail_rc` 两个局部变量 + 1 个 if；无多余抽象。
- **R5 依赖混乱** ✅：无新依赖方向；`module_output`（common.sh:177-182）与主路径 rc 捕获
  先例（:323-331 `… && rc=0 || rc=$?` → warning → exit 0）同构沿用。
- **R6 领域扭曲** ✅：命名 `bl_rc`/`bl_fail_rc`（backlog 领域词），与文件内 `bl_*` 前缀惯例一致。

✅ 沿用既有抽象 grep（R6.4）：
- 告警输出通道：`grep -n 'module_output "warning"' flow-kit-bundle/hooks/stop/29-independent-review.sh`
  → 主路径 :329 同级 warning 先例 → 沿用（同为 IR 检查、TD-023 级别纪律）
- rc 捕获范式：`grep -n 'rc=\$?' 同文件` → :323 `l3_review_run … && rc=0 || rc=$?` 先例 → 沿用等价形态
- 测试注入范式：既有 `test/test-l2-first-correction.bats`（REAL_ROOT 上溯 + 沙箱 env 前缀
  PROJECT_ROOT/HOOK_BASE_DIR/HOOK_TMP_DIR/CONFIG_FILE + bash 实跑 29）→ 沿用，加 lib 覆写注入

无 🔴 必修项；无 🟡 记录项。

## 越界检查（R6.5）

- TASK write_files：`flow-kit-bundle/hooks/stop/29-independent-review.sh`、
  `test/test_l3_backlog_alarm.bats`、`flow-kit-bundle/test/test_l3_backlog_alarm.bats`
- 实际写入：以上 3 项 + 本 SUMMARY（交付物）= 4 项
- **越界：0**（工作树中其他已修改文件均属同波次并行任务，非本会话所写；未跑
  make test-sync / check-test-sync，未 git commit，未改 .flow-active / TASK.md / 其他任务文件）

## 偏差 / 疑问记录

1. **AC-6 验证通道**：REQUIREMENT.md AC-6 散文写「stderr 含告警」，但 29 号的模块告警
   通道按 D6/架构是 `module_output`（写 `$HOOK_TMP_DIR/independent-review.txt`，
   common.sh:177-182；29 实跑无 stderr 汇聚路径）。测试按 D6 钦定通道断言文件内容，
   视规格散文为松动表述。若 5-test 阶段按字面 stderr 断言会对不上，需回看。
2. **用例数 4**（任务说 3-5 个）：失败主断言 / 成功控制 / 多相位 / 选择门各一。
3. **头注释顺带修正**（:11）：原句在 :146 已失真（模型缺失 exit 3，先前任务引入），
   本次因 rc 透传进一步失真才重写该句——属本任务语义必需的最小改动，非顺手修。
4. verify 之外补跑了 RED 证明与 `cmp` 镜像校验（均只读仓库或 /tmp 临时文件）。
