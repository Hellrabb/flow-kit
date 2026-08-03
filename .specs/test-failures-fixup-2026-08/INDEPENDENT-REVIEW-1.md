# 独立审查 · 阶段 1

> change-id: `test-failures-fixup-2026-08` · L2 盲审 · 2026-08-03
> 审查工件：`.specs/test-failures-fixup-2026-08/REQUIREMENT.md`（参考 CHANGE.md）
> 独立契约：仅读工件 + 交叉引用文件（test/test_gate_integrity.bats、test/test_lessons_cleanup.bats、Makefile、4-dev.md、reference/tdd-workflow.md、pre-tool-use/ 4 文件、stop/lib/l3-*.sh、archive/final-debt-cleanup-2026-08/REQUIREMENT.md）

## L2 盲审

### 审查范围与方法

对 REQUIREMENT.md 的 9 条 AC（A1/B1/B2/B3/C1/D1/D2/E1/E2）逐条做了可行性验证：将 AC 声称的修复机制（grep 范围扩大 / shellcheck 指令 / diff 命令）对照**当前磁盘上的实际内容**执行，验证"该修复能否真正使目标测试从 fail 变 pass"。

实跑证据：
- `npx bats --count test/` = **662**（AC-D2 数字一致 ✓）
- 7 个新 hook lib 文件当前均无 `# shellcheck shell=bash`，shellcheck 各报 SC2148；前置指令后 SC2148 归零（AC-C1 机制有效 ✓）
- 正则 `^(1|2|3|5|6|7)$` 当前**仅存在于** `gate-helpers.sh:212`（AC-A1 目标内容已定位 ✓）
- `diff test/test_*.bats flow-kit-bundle/test/test_*.bats` 实测报错 `diff: 多余的操作对象`（AC-D1 命令不可执行 ✗）

### Checklist 结论

- [ ] All ACs have Given/When/Then complete — **不通过**（B2/B3 的 Then 无法达成，见 C1/C2）
- [ ] AC verifiable via bats / shell command — **不通过**（D1 命令语法错误）
- [ ] Scope decision documented with rationale — 通过（§3 两条均有理由）
- [ ] NFR mapped to verify method — **不通过**（C1 的 verify 存在假绿路径；Performance 无测量法）
- [ ] v1/v2/out explicit — 通过（§4）
- [ ] Test grep strategy ("OR" semantics) clearly specified — **不通过**（B1 子断言 OR 语义二义；A1 OR 范围过宽）

---

### 🔴 C1 · AC-B3 修复机制不成立——"1.8.4.x" 编号在任何目标文件中都不存在

- **Symptom**: AC-B3（REQUIREMENT.md:37-38）声称"grep 范围扩大为 4-dev.md OR tdd-workflow.md 即 pass"，但被测测试 test_lessons_cleanup.bats:230-236 的断言是 `grep -c "1\.8\.4\.[1-4]"` ≥ 4（子段 1.8.4.1 ~ 1.8.4.4）。实跑确认：**4-dev.md 无任何 "1.8.4" 子段编号**（L-068 压缩后标题只剩 1.0/1.4/2/3/4/5/6/7.1/7.2，见 `flow-kit-bundle/flow-kit/prompts/4-dev.md` 标题清单），**tdd-workflow.md 亦无 "1.8.4"**（grep 空，其对应内容改用 `#### 自动 bats 执行` / `#### 结果判定` / `#### 结果写入 SUMMARY` / `#### L2 自检 gate 填空` 标题，见 `reference/tdd-workflow.md:179-206`）。即使范围扩到两文件，测试 515 依然 fail。
- **Source**: REQUIREMENT.md:37-38 的"验证"行直接沿用旧测试的断言假设（"编号正确"暗示编号存在于某处），未核实 L-068 压缩后编号是否保留；CHANGE.md:46 同时声明"无 prompt / hook 逻辑变更"，堵死了向 tdd-workflow.md 补回编号的路径。
- **Consequence**: 执行阶段按 AC-B3 实现"扩大 grep 范围"后测试 515 仍红；要么被迫改断言（偏离 AC 验收文字），要么被迫改 tdd-workflow.md 内容（违反 CHANGE.md §4 影响面声明）。AC 无法按字面验收。
- **Remedy**: 重写 AC-B3 断言目标为 tdd-workflow.md 实际存在的 4 个 `####` 子段标题（或将其视为"断言改写"而非"范围扩大"，在 CHANGE.md 影响面中显式登记 test 断言修改）。同时修正 AC-B3 引用的行号：**"子段编号"测试在 test_lessons_cleanup.bats:230-236，非 :175-185**（:175-185 实为 AC-6 失败阻断测试体）。

### 🔴 C2 · AC-B2 第二子断言无解——`修复.*测试失败|重跑.*bats` 在 4-dev.md 与 tdd-workflow.md 中均不存在

- **Symptom**: AC-B2（REQUIREMENT.md:34-35）要求关键词 `阻断|暂停流程|禁止进入` **+** `修复.*测试失败|重跑.*bats` 在 4-dev.md 或 tdd-workflow.md 命中即 pass。实跑：`阻断/暂停流程/禁止进入` 命中 tdd-workflow.md:196 ✓；但 `修复.*测试失败|重跑.*bats` 在两文件中 **0 命中**——该文本仅存在于 `flow-kit-bundle/skills/flow-dev/SKILL.md:331`（"提示'修复后重跑 npx bats test/'"），不在 AC 指定的任一文件中。
- **Source**: 测试 test_lessons_cleanup.bats:182 的断言 pattern 是为旧 4-dev.md 全文写的；L-068 抽取时该句未进入 tdd-workflow.md。AC-B2 仅做"范围扩大"，未核对目标内容是否齐全。
- **Consequence**: 按 AC 实现的测试 509 依旧 fail（第二子断言必挂）→ 同 C1 的被迫偏离路径。
- **Remedy**: AC-B2 需明确"断言改写"：将第二子断言改为 tdd-workflow.md 实际存在的文本（如 :196 的 `暂停流程，禁止进入 toll-gate` 或 `阻断：输出失败测试清单`）；或在 CHANGE.md 影响面登记向 tdd-workflow.md 补充该句（即允许 prompt 内容变更）。

### 🔴 C3 · AC-D1 验证命令语法错误——glob 展开后 diff 无法执行

- **Symptom**: AC-D1（REQUIREMENT.md:48）`When 运行 diff test/test_*.bats flow-kit-bundle/test/test_*.bats`。实测：两侧 glob 各展开为 ~60 个文件，`diff` 收到 >2 个操作数直接报错 `diff: 多余的操作对象 "test/test_checkpoint.bats"`，永远无法输出"为空"。
- **Source**: 未区分"diff 两个目录"与"diff 两个文件"——bats 测试在 `test/` 与 `flow-kit-bundle/test/` 各有 60 个文件（ls 确认），glob 通配不适用于双文件 diff。
- **Consequence**: AC-D1 无法执行 = 不可测试；双源一致性（本 change 修改 4 个测试文件后必须同步到 flow-kit-bundle/test/）失去验收手段。
- **Remedy**: 改为 `diff -r test flow-kit-bundle/test`（目录级递归 diff），或逐文件 loop（`for f in test/test_*.bats; do diff "$f" "flow-kit-bundle/${f#test/}"; done`）。AC 文字需写可执行命令。

### 🔴 C4 · AC-E1 悬空引用——"REQUIREMENT AC-F4 阈值"在本文档中不存在

- **Symptom**: AC-E1（REQUIREMENT.md:54）"≥1 commit + ≥4 files touched（REQUIREMENT AC-F4 阈值）"。本 REQUIREMENT.md 无任何 AC-F*（§2 只有 A/B/C/D/E 五类、E 类到 E2 为止）。全仓 grep 确认 "AC-F4" 仅存在于归档 `.specs/archive/final-debt-cleanup-2026-08/REQUIREMENT.md:145`。
- **Source**: 从旧 change 照搬验收文字时未改写引用，造成"本文档内引用一个不存在的 AC"。
- **Consequence**: 阈值的来源与含义无法在本工件内验证（scope 溯源断裂）；"≥4 files touched"对本 change（4 测试 + 7 lib = 11+ 文件）是恒真式，作为验收准则无区分度。
- **Remedy**: 改写为显式引用（`ARCHIVE final-debt-cleanup-2026-08 REQUIREMENT.md AC-F4`）或直接把阈值来源写成本 change 的实际改动面（≥4 files + ≥1 commit），并说明此阈值仅为 delivery 最低要求。

---

### 🟡 M1 · AC-A1 "4 文件任一命中"断言过弱——不钉文件、不查重复、与 TD-016 教训相悖

- **Symptom**: AC-A1（REQUIREMENT.md:24-26）"regex 在上述 4 文件之一出现即可 pass"。实跑：该正则当前**仅存在于 gate-helpers.sh:212**（`[[ "$phase" =~ ^(1|2|3|5|6|7)$ ]]`），其余 3 文件（含独立入口 independent-review-gate.sh）0 命中。且被测测试 test_gate_integrity.bats:152-156 目前只 grep `$GATE_SH` 单文件（setup :20 定义），AC 未描述多文件 grep 的测试实现方式。
- **Source**: 把"内容没有消失"（OR 网）当成了"内容接线正确"。TD-016 的教训（test_gate_integrity.bats 曾断言实现不存在的东西、set+e 假绿掩盖）正是此模式。
- **Consequence**: 若正则未来被复制到第 2 个文件（DRY 违规）测试仍绿；若移动到第 5 个文件（再次拆分）恰好落在 4 文件外则测试误报 fail；测试无法回答"phase 过滤逻辑是否仍挂在 gate 链上"。
- **Remedy**: 断言收紧为"**恰好** 1 of 4 文件命中"（既防消失也防重复），或直接钉死 `gate-helpers.sh`；AC 中补充测试实现方式（对 4 文件循环 grep 计数）。

### 🟡 M2 · AC-B1 "3 个子断言在任一文件命中即 pass"语义二义

- **Symptom**: AC-B1（REQUIREMENT.md:30-32）"3 个子断言 … 在任一文件命中即 pass"。测试 test_lessons_cleanup.bats:144-158 是 3 个独立 `grep -q`（`npx bats test/` / `npx bats --version` / `0 failures`）。"任一文件命中"可读作：① 每个子断言各自在 ≥1 文件命中（3 greps × 2 文件），或 ② 三个子断言须落在同一文件。"OR" 的组合粒度未定义。
- **Source**: AC 文字把"文件 OR"与"断言 OR"混写；内容上三子断言均存在于 tdd-workflow.md:185/188/195，①语义可实现，②语义在当前内容分布下亦可行（三者同文件），故歧义暂时无害——但验收标准必须无歧义。
- **Consequence**: 未来 4-dev.md / tdd-workflow.md 内容再移动时，两个不同语义产生不同测试结果，验收时无法判定实现是否符合 AC。
- **Remedy**: 明确写为"每个子断言在 4-dev.md 或 tdd-workflow.md 至少一文件命中"（逐断言 OR，各断言独立）。

### 🟡 M3 · AC-C1 验证方法存在假绿路径——`make lint` 在 shellcheck 缺失时静默跳过

- **Symptom**: AC-C1（REQUIREMENT.md:42-44）验证方式为 `make lint` → exit=0。Makefile:16-21 在 `shellcheck` 未安装时输出 WARNING 并**直接跳过**（`Skipping lint (non-blocking)`），exit 仍为 0。
- **Source**: verify 方法选用了"缺依赖时 graceful skip"的聚合 target，而非直接断言 7 文件首行含指令。
- **Consequence**: 在未装 shellcheck 的环境（Makefile 注释明言 RTK proxy 下 command -v 不稳定）AC-C1 恒绿——7 文件 SC2148 未修也能"通过验收"，复刻 577 号 fail 的假绿风险。
- **Remedy**: 验证命令改为逐文件直接跑 `shellcheck -e SC1091 <file>`（缺 shellcheck 时报错而非跳过），或增加 bats 断言（grep 7 文件首行含 `# shellcheck shell=bash`）。机制本身已验证有效（前置指令后 SC2148 归零），问题仅在验证入口。

### 🟢 S1 · §6 Self-check 计数自相矛盾

- **Symptom**: REQUIREMENT.md:87 "8 AC 全部 Given/When/Then 完整 ✓" 但括号内列出 **9 个** AC（A1/B1/B2/B3/C1/D1/D2/E1/E2 = 9）。
- **Source**: 复制模板时未同步数字。
- **Consequence**: 无功能影响，但自我审查的严谨性存疑（与 US-1 "测试基线可信度"主题背道而驰）。
- **Remedy**: 改为 "9 AC"。

### 🟢 S2 · AC-D2 "662 ok" 魔法数字 + 无增量验证步骤

- **Symptom**: AC-D2（REQUIREMENT.md:50）"662 ok / 0 fail"。662 已实测确认（`npx bats --count test/`）；但数字会随测试增减漂移；且本 change 修改 4 个测试文件，若改写引入新 fail，AC-D2 只在全量收尾时暴露，无"先单跑被改文件、再全量"的中间闸。
- **Source**: 基线数字硬编码 + 验收粒度只有全局门。
- **Consequence**: 维护成本：下个 change 加 3 个测试，此处数字即过期；调试成本：4 文件改动引入的新 fail 与"基线恢复"混在同一批输出里。
- **Remedy**: AC 以"0 fail"为硬门槛，662 标注为"当前基线（会漂移）"；建议补充"被改 4 个测试文件单独跑绿"为前置子断言。

---

### 综合评估

- **范围决策**（§3）：两条决策均有理由，方向正确（DRY + sourced lib 语义）。
- **v1/v2/out**（§4）：清晰。
- **US → AC 映射**：US-2/US-3 与 A1/B1/B2/B3 对齐，但 B2/B3 的"验证"行与磁盘实况不符（C1/C2）——这是本工件最严重的系统性问题：**AC 描述的是"扩大 grep 范围"这一动作，而非"测试转绿"这一可证结果**，且未核对目标文件内容是否真的承载断言内容。CHANGE.md §4 "无 prompt / hook 逻辑变更"声明与 B2 的可满足性冲突。
- **正向确认**：AC-C1 修复机制实测有效；AC-D2 的 662 基线真实；AC-B1 内容可满足（tdd-workflow.md:185/188/195）；AC-A1 目标内容已定位（gate-helpers.sh:212）。

**Verdict**: fail

> 4 条 🔴 Critical（B2/B3 断言无解、D1 命令不可执行、E1 悬空引用）使本工件无法按字面进入 phase 2。修订方向：B2/B3 改为"断言改写"并在 CHANGE.md 影响面登记测试断言变更；D1 改为 `diff -r`；E1 修正引用或自述阈值来源；A1/B1 补 OR 语义与实现方式；C1 验证入口改为逐文件 shellcheck。
