# REQUIREMENT: 修 TD-011 · independent-review-gate regex 治理 + gate 测试 setup 修复

- **Change ID**: refactor-independent-review-gate
- **关联**: `@.specs/refactor-independent-review-gate/CHANGE.md`、`@.specs/CONTEXT.md`
- **修订**: v5 · L2 阶段 2 fail（F1/F2 🔴）+ 用户决策（维持全文件治理 + 本 change 修 setup）。**F1 叙事修正**：TD-011 无 gate 行为后果（完整函数 L73-75 兜底），降 🔴→🟡。**F2 新增**：test setup 假绿修复。

---

## 用户故事

- **US-1**（v5 修正 · L2 F1）：作为 flow-kit 维护者，我想清掉 L69 的 SC2157 lint + 恢复 atomic-write 检测器的精确意图 + 防御 TD-011 同类复发，以便 gate 代码无 lint 告警、regex 表达正确、未来若 L73-75 被改时 L69 不留隐患。**注**：完整函数 L73-75 兜底，L69 bug **无 gate 行为后果**，本 change 非"修误报"（0-change 实验2b 测孤立 regex 的方法缺陷已记 INDEPENDENT-REVIEW-2.md）。
- **US-2**：作为 flow-kit 维护者，我想让全文件 18 处 `[[ =~ ]]` 统一为"变量存 regex"风格，防御未来误写 `&&`/裸空格触发同类 bash 解析 bug。
- **US-3**（v5 新增 · F2）：作为 flow-kit 维护者，我想修掉 `test_gate_integrity.bats` setup 的 `set +e` 假绿，恢复 gate 测试套件的断言可信度（揭示 TD-012 未真正闭合）。
- **US-4**（v6 新增 · L73-75）：作为 flow-kit 维护者，我想修复 `is_phase_write` 的 L73-75 regex 顺序 bug（`\.flow-active.*\.phase=` 要求 .flow-active 在字段名前，但真实 jq 命令字段在前），恢复 gate 对 jq phase-write 的检测能力（当前对 jq 漏检 → phase-transition 检测完全失效 · 安全隐患）。

## 验收准则（AC）

### AC-1 · L69 修复 · SC2157 清零 + 意图恢复（v5 修正）

- **Given** `is_phase_write` L69 已按 DESIGN D1 修复（regex 存变量）+ L68 disable 移除
- **When** shellcheck + 审查 L69 regex
- **Then** SC1026/2203/2157 = 0（AC-4 详）；L69 regex 精确匹配 `\.tmp[[:space:]]*&&[[:space:]]*mv`（恢复 atomic-write 检测意图，非泛 `.tmp+空格`）
- **验证方式**: 见 AC-4（SC 码 grep）+ 代码审查 L69 regex 精确性（grep `local re.*tmp.*mv` 存在）

### AC-2 · 回归证据可机器验证（@regress-TD011 · 负匹配断言）

- **Given** 新增带 `@regress-TD011` 标记的 bats 用例（落点 test_gate_integrity.bats，D5 修复后断言可信）
- **When** 该用例对负匹配输入（`ls .flow-active.tmp bar`）断言 no-match（post-fix 正确行为，与 buggy 一致 · F1 证函数级不变）
- **Then** 用例存在且 pass（D5 修复后 pass/fail 可区分）
- **验证方式**: `grep -q '@regress-TD011' test/test_gate_integrity.bats && bats --filter TD011 test/test_gate_integrity.bats`（两副本同步）

### AC-3 · 全文件 regex 行为等价（动态发现 · 脚本对照）

- **Given** 治理范围 = 全文 `[[ =~ ]]` 实例（动态 `grep -nE '\[\[ .* =~ '`），post L68 移除后约 17 处无 bug + L69 bug 行
- **When** sandbox 脚本对每处跑 ≥3 类输入（正/负/边界），对照治理前后
- **Then** 17 处治理前后匹配结果 100% 一致；L69 按修复改变（精确化）。TSV 表（行内容指纹 × 输入 × 前 × 后 × diff）入 DEV-SUMMARY
- **验证方式**: sandbox 对照脚本（动态 grep + 内容指纹，行号仅 @快照参考 · L2 F3）

### AC-4 · shellcheck TD-011 SC 码清零（基线对照）

- **Given** L68 disable 移除
- **When** shellcheck
- **Then** SC1026/2203/2157 = 0；新 warning 集 ⊆ 基线 {SC1090, SC2034}（实测 8 条 · 与 TD-011 无关）
- **验证方式**: `! shellcheck ... | grep -E 'SC1026|SC2203|SC2157'` + `shellcheck ... | grep -oE 'SC[0-9]+' | sort -u`（⊆ {SC1090,SC2034}）

### AC-5 · make test 全绿 + 反向断言（v5 增 F2 防护）

- **Given** 修复 + 新测试 + D5 setup 修复已合入
- **When** `make test`
- **Then** 407 → 407+N 全 pass，0 BW01
- **验证方式**: `make test`（exit 0）+ **反向断言**（v5 · L2 F2）：临时注入一个 `false` 到测试套件后 `make test` 必须 non-zero exit（防"假绿守门员"自身失效）

### AC-6 · TD-011 标 resolved（降 🟡）+ 禁动清单授权注脚

- **Given** AC-1~5,8 全过（7-integration）
- **When** 更新 CONTEXT.md
- **Then** ① TD-011 标 ✅ resolved **且严重度 🔴→🟡**（附 F1 实测说明：完整函数 L73-75 兜底，无 gate 行为后果）；② 禁动清单 independent-review-gate.sh 核心链条目加授权注脚；③ 无残留硬行号
- **验证方式**: `grep -E 'TD-011.*🟡.*resolved' .specs/CONTEXT.md` + 授权注脚 + `! grep -E '(禁动清单|forbidden).*(line|行)[: ]*[0-9]|\b349\b|\b353\b'`

### AC-7 · 调用链下游审计（v5 修正推理 · F3）

- **Given** is_phase_write 调用点（L175/366）
- **When** `grep -rn 'is_phase_write' flow-kit-bundle/`
- **Then** 调用图 + 二元判定表入 DEV-SUMMARY。**判定依据（v5 · F3）**：对 F1 实测枚举输入集，buggy 与 fixed 布尔返回值完全一致（非"不区分哪条 regex 命中"的空话）
- **验证方式**: 调用图 grep + 判定表入 DEV-SUMMARY（含 buggy/fixed 返回值对照列）

### AC-8 · gate 测试 setup 修复（v5 新增 · F2）

- **Given** `test/test_gate_integrity.bats` + `flow-kit-bundle/test/test_gate_integrity.bats`（两副本同步）
- **When** 按 DESIGN D5 修复：setup 去 `set +e` + D10 测试体改 `if is_phase_write ...; then 预期分支; else fail; fi`（吸收 return 2，恢复 errexit 检测）
- **Then** setup 不含 `set +e`；测试体用 if/then/fail 模式；bats 断言失败可被检测（F2 假绿消除）
- **验证方式**: `! grep 'set +e' test/test_gate_integrity.bats` + `bats test/test_gate_integrity.bats`（D5 修复后，人为注入 `false` 必报 not ok · 配合 AC-5 反向断言）

### AC-9 · L73-75 regex 修复 · gate 检测恢复（v6 新增 · L73-75 顺序 bug）

- **Given** `is_phase_write` L73-75 已按 DESIGN D6 修复（去 `.flow-active.*` 前缀，只测字段名 `\.phase=` / `\.goal\.current_phase=` / `\.goal\.phases_done`）
- **When** 传入真实 jq phase-write（`jq '.phase=2' .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active` / current_phase / phases_done）
- **Then** return 0（gate 检测 · **之前漏检 return 1**）；非 phase 字段 jq（`.foo=1`）仍 return 1
- **验证方式**: bats（新增 `@regress-L73` case）+ sandbox 对照（修复版已实测全 ✓）

### AC-10 · D10 测试修正 · 期望可达（v6 新增）

- **Given** D10 测试体已按 D5/D7 改 `if is_phase_write ...; then 预期; else fail; fi` + setup 去 `set +e` + L73-75 修复（AC-9）
- **When** `bats test/test_gate_integrity.bats`
- **Then** D10 期望 return 0 **现在可达**（is_phase_write 对 jq phase-write return 0 · AC-9）；全 23 测试反映真实行为，无假绿
- **验证方式**: `bats test/test_gate_integrity.bats`（D10 pass + 人为注入 `false` 必 not ok · AC-5 反向断言）

---

## 范围切分

### v1（本次必做）
- L69 修复（变量存 regex · D1）+ L68 disable 移除（AC-1/4）
- 18 处 regex 中 17 处无 bug 统一变量存（AC-3）
- **test_gate_integrity.bats setup 修复（D5 · F2）**（AC-8）
- 补 @regress-TD011 atomic-write case（AC-2）
- make test 全绿 + 反向断言（AC-5）
- 调用链审计（AC-7）
- 7-integration 标 TD-011 🟡 resolved（AC-6）

### v2（下一轮）
- 共享 regex lib 抽取（`_shared/` · 关联 TD-004/005 目录目标）
- 基线 warning 清理（SC1090/SC2034）
- macOS bash 3.2 smoke
- gate shellcheck CI 门禁

### out（永远不做）
- 改 gate 校验顺序 / transition 方向逻辑 / 换 AST 解析

---

## 非功能性需求
- **性能**：无（regex 纳秒级，变量存与内联等同）
- **可访问性**：无
- **安全**：gate 安全护栏，修复提升代码正确性（lint 清零）。无新增风险
- **兼容性**：Linux bash 5 已验证；macOS 3.2 理论兼容（v2 smoke）
- **可观测性**：报错文案不变（L223/246/256）

## 依赖与假设
- **依赖**：test-setup-path-fix-2026-07（407 测试加载）· **v5 注**：F2 揭示该 change 未真正闭合 TD-012（set+e 假绿），本 change AC-8 补闭合
- **假设**：无上游依赖 L69 误报行为（AC-7 实测：buggy/fixed 返回值一致）
- **假设**：bash `[[ =~ $re ]]` 跨版本行为一致

---

> AC 是 TEST 阶段派生用例的唯一来源。v5 已闭合 L2 阶段 2 的 F1/F2/F3。
