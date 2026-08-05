# 独立审查 · 阶段 3

## L2 盲审

- 审查对象：`.specs/l2-l3-subagent-fix/TASK.md`
- 参考：REQUIREMENT.md（AC-1..AC-5）· DESIGN.md（§0.5.1/§0.5.2/§5/D1-D6）· CHANGE.md · CONTEXT.md（禁动清单）
- 日期：2026-08-05
- 方法：任务 7 字段核验 / write_files 边界核验 / 波次与并行冲突 / verify 可执行性与语义 / done↔AC 映射 / read_files 覆盖 / AC 全覆盖 / 禁动清单 / model-tier

### 核验通过项（简记）

- 7 字段齐全：T01-T08 全部含 id/name/read_files/write_files/action/verify/done ✓
- write_files 无禁动清单文件；T07 写 l2-detect.sh（DESIGN §0.5.1 触碰模块 + D5③ 预研）与 `~/.config/opencode/agents/qa-expert.md`（D5② 预研）均有 DESIGN 授权 ✓
- 波次无环：W1 并行 T01-T05 写 5 个互异 EVIDENCE-N 文件，无同文件并行写 ✓
- done 全部映射 AC：T01-04→AC-1 各环节、T05→AC-1(claude)+AC-2、T06→AC-1/2/3、T07→AC-4、T08→AC-5，无 AC 漏任务 ✓
- 禁动清单行为：无任务直写 .flow-active（T07 经 /flow model、T08 声明经 /flow 维护）；不触碰 gate 核心链写操作；T05 对 ~/.claude/agents 纯读 ✓
- 事实锚点核验：agent_type 映射（l2-detect.sh:72-76 = 1/5 qa-expert, 2/3/7 architect-reviewer, 6 code-reviewer）✓；gate-checks-basic.sh:40/53/62/90 调 l2_dispatch_* ✓；l3-api.sh:20-21 直连变量 ✓；ADR-020 三层模型选择 ✓；710 @test（STATE.md 662/662 基线）✓
- model-tier 全 standard：调查/合成/回归任务均属多文件标准工作，无错配 ✓

### 发现

🔴 F1 ｜ T08 verify 退出码语义反转，AC-5「0 fail」门禁失效 ｜ 证据：TASK.md:197 `npx bats test/ 2>&1 | grep -c '^not ok'`——grep -c 在 0 命中时 exit 1、≥1 命中时 exit 0，与期望判定完全相反 ｜ 影响：测试真有 fail 时 verify 反过（假绿，TD-012 已修过的管道 exit code 陷阱同类）；0 fail 时 verify 反不过（pipeline 死锁）｜ 建议：verify 改为 `[ "$(npx bats test/ 2>&1 | grep -c '^not ok')" = "0" ]` 或直接判 npx bats 退出码

🟡 F2 ｜ T06 verify 未强制五段结构与阈值，AC-1 验收空洞 ｜ 证据：TASK.md:155 仅四环节锚点 grep 且 grep -c ≥1 命中即 exit 0，「输出 ≥ 4」阈值不生效；REQUIREMENT.md:22 要求的 `^## (现象矩阵|根因链|双平台差异矩阵|风险分级修复方案|受影响模块清单)` ≥5 检查只写在 action 文本未入 verify ｜ 影响：五段缺段或锚点仅 1 处也能过 verify ｜ 建议：verify 补 `[ "$(grep -cE '^## (现象矩阵|根因链|双平台差异矩阵|风险分级修复方案|受影响模块清单)' ROOT-CAUSE.md)" -ge 5 ]` 且锚点计数 ≥4

🟡 F3 ｜ T03 read_files 缺 qa-expert.md 与 l2-detect.sh，action 却依赖二者实测 ｜ 证据：TASK.md:69-77 read_files 仅 6 prompt + L2-blind-review.md，:82 action 要求「qa-expert 声明 model: sonnet 是否可解析」+「与 l2-detect.sh agent_type 映射三方一致」｜ 影响：执行者无读权限依据，结论易凭猜测，调查证据链断 ｜ 建议：read_files 补 `~/.config/opencode/agents/qa-expert.md` 与 `flow-kit-bundle/hooks/stop/lib/l2-detect.sh`

🟡 F4 ｜ T02 read_files 不覆盖 gate 链实际 source 依赖 ｜ 证据：TASK.md:49-54 只列 5 个 gate 文件；而 independent-review-gate.sh:31 source common.sh、gate-checks-basic.sh:40 source l2-detect.sh（:53/62/90 即调查对象调用点）、gate-helpers.sh:112 引 done-validation.sh，均不在 read_files ｜ 影响：集成实测时缺链上函数上下文，易把「source 失败/函数未定义」误判为平台不可达 ｜ 建议：read_files 补 common.sh、l2-detect.sh、done-validation.sh

🟡 F5 ｜ T07 verify 不验证 AC-4 核心证据（实测拉起 + diff 无禁动文件） ｜ 证据：TASK.md:177 仅 `grep -c 'risk: low'`（≥1 即过，含 T06 存量条目，不证明实施发生）；REQUIREMENT.md:42-43 要求「实测记录写入 DEV-SUMMARY.md + git diff --stat 核对不含禁动模块」｜ 影响：未实施/空清单分支也能通过 verify，AC-4 门禁形同虚设 ｜ 建议：verify 补 `test -s DEV-SUMMARY.md` + grep 真实拉起记录 + `git diff --stat` 禁动文件排除核对

🟢 F6 ｜ EVIDENCE-*.md 未登记于 DESIGN §0.5.1 新增产物 ｜ 证据：TASK.md:18 wave 注释引入 EVIDENCE-N-*.md，DESIGN.md:46-47 新增产物仅列 ROOT-CAUSE.md/DEV-SUMMARY.md ｜ 影响：写盘边界与 DESIGN 声明不一致（均在 change 目录内，影响低）｜ 建议：DESIGN 补列 EVIDENCE-N 系列产物

🟢 F7 ｜ R1/R2/R3 标签与 DESIGN §5 风险表 R1-R6 撞号 ｜ 证据：TASK.md:108 「R1 修复」= 模型绑定层验证（同 DESIGN D1），而 DESIGN.md §5 风险表 R1 = claude code 不可复现（R6 才标「R1 修复对象」）；T04/T05 的 R2 亦双义（脱敏 vs agent diff）｜ 影响：跨阶段对齐歧义 ｜ 建议：改用「风险 R6/R2」或 D1 候选编号

---

Verdict: fail

---

## L2 盲审（重审）

Verdict: pass

L2 blind review phase 3 re-review: pass — F1-F7 全部核实已修复

- F1 (🔴→✅)｜TASK.md:202 verify 改为 `[ "$(npx bats test/ 2>&1 | grep -c '^not ok')" = "0" ]` — 捕获输出做字符串比较而非依赖 grep 退出码：0 fail=pass、≥1 fail=fail，退出码反转消除，语义正确
- F2 (🟡→✅)｜TASK.md:160 verify 双条件 `&&` 串联：五段 `^## (现象矩阵|根因链|双平台差异矩阵|风险分级修复方案|受影响模块清单)` ≥5 + 四环节锚点 ≥4，与 REQUIREMENT.md:22 AC-1 验证逐字一致；ROOT-CAUSE.md 缺失时 `[ "" -ge 5 ]` exit 2 亦失败，无空洞
- F3 (🟡→✅)｜TASK.md:80-81 read_files 补 `flow-kit-bundle/hooks/stop/lib/l2-detect.sh` + `~/.config/opencode/agents/qa-expert.md`，与 action 实测依赖闭合
- F4 (🟡→✅)｜TASK.md:54-56 read_files 补 common.sh / l2-detect.sh / done-validation.sh，覆盖 gate 链 source 依赖链
- F5 (🟡→✅)｜TASK.md:182 verify 三条件：`test -s DEV-SUMMARY.md` &&（`拉起|spawn` OR `不适用` 空清单分支）&& `git diff --stat` 禁动文件排除，覆盖 AC-4 非空/空双分支
- F6 (🟢→✅)｜DESIGN.md:48-52 §0.5.1 补列 EVIDENCE-1..5，文件名与 T01-T05 write_files 一一对应
- F7 (🟢→✅)｜T04/T05 改名「盲审发现 R1/R2」、T06 引用「MINOR-DEFERRED 台账 R3」，与 DESIGN §5 风险表 R1-R6 命名空间隔离，跨阶段无撞号

结构复扫（无新增 Critical / Important）：XML 8 任务字段齐全闭合；波次无环（T06←T01-05 · T07←T06 · T08←T07,T06）；id 唯一；write_files 均在 DESIGN 范围内（T07 写 l2-detect.sh / qa-expert.md 有 D5 授权，无禁动清单文件）；T08 依赖 T07,T06 与 read_files 一致；全部 8 个 verify 可执行、无裸 grep -c、无退出码反转。

新增发现（均 🟢 Minor，不阻塞）：
- 🟢 ｜ TASK.md:182 禁动排除正则缺 `done-validation`（fk_validate_done_marker 所在，属 gate 核心链）与 `gate-helpers`；且 `git diff --stat` 仅查 unstaged。T07 write_files 已限域故实际风险低；建议补 `done-validation|gate-helpers`（如需连 staged 可改 `git diff HEAD --stat`）
- 🟢 ｜ TASK.md:202 若 npx bats 本身启动失败（无 stdout 输出），grep -c 计 0 → `"0" = "0"` 假绿。0 fail 与"bats 没跑起来"不可区分；建议 `[ "$(npx bats test/ 2>&1 | tee /dev/stderr | grep -c '^not ok')" = "0" ]` 或另断言 npx bats 退出码
- 🟢 ｜ TASK.md:180 与 DESIGN.md:141 引用「R7 台账空分支」，但 DESIGN §5 风险表仅 R1-R6、R7 无定义（两文档一致，低风险）；建议补一行定义或改述为「空清单分支」
