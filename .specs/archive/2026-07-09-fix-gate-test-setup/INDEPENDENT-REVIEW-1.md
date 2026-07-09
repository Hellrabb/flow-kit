# 独立审查 · 阶段 1

## L2 盲审

> 固化盲审子 agent（qa-expert）原样产出，主 agent 未改一字。

## L2 独立盲审 · 阶段 1（fix-gate-test-setup）

**Verdict**: fail（2 🔴 Critical · F1/F2）

**F1 🔴 — AC-2 指定补救模式 `if ! fn; then rc=$?` 语义损坏**：`! fn` 反转退出码，进入 then 后 `$?` 是 `! fn` 结果（恒 0），非 fn 原始 rc。S1（fn rc=2 期望 pass）→ rc=0 → not ok（假阴性）；S2（fn rc=0 期望 fail）→ !fn 假不进 then → 返回 1（结构错误）。两种方向都错，比假绿更危险（反向橡皮图章）。修复：强制 `run fn; [ "$status" -eq N ]`（实测可用）或 `set +e; fn; rc=$?; set -e` / `fn || rc=$?`。

**F2 🔴 — AC-5 不可满足 · fk_validate_done_marker 未被 setup 定义**：`fk_validate_done_marker` 定义于 `done-validation.sh:102`，setup 直接 source 的 `independent-review-gate.sh` 不含。`flow-kit-artifacts.sh:13` `source ${HOOK_BASE_DIR}/lib/done-validation.sh`，但 setup **从未设 HOOK_BASE_DIR** → source 解析 `/lib/done-validation.sh` 失败 → `|| true` 吞 → 函数未定义。TD-012 只修 GATE_SH 路径，未碰 HOOK_BASE_DIR。去 set+e 后 6 条调 fk_validate_done_marker 的测试 127 崩溃。修复：setup 加 `export HOOK_BASE_DIR="$BUNDLE_ROOT/hooks/stop"`。

**F3 🟡 — "9 条" vs 实测 15 not ok**：去 set+e 实测 15 条 not ok（非 9）。额外 6 条：#8 D9 正向(127) + #11/#12 AC-3 artifacts + #19/#20 D10 + #23 AC-6 sha256。需逐条定位归属。

**F4-F9 🟡/🟢**：双模式表述非对称（诱选坏模式）/ TD-013 诊断属实（正面）/ AC-1 双副本准确 / NFR 适配 / AC-2 标签序号 vs rc 值不一致 / AC-6 grep emoji 兜底。

## 主 agent 核验（receiving-code-review · 实测确认）

**F1 实测确认**：
```
fn(rc=2) 期望pass: if ! fn; then rc=$? → rc=0 → not ok ✗ (假阴性)
fn(rc=0) 期望fail: !fn假不进then → 结构错
对照: set+e局部 / fn||rc / run模式 → 全 ✓
```
证实 `if ! fn` 坏模式。主 agent 承认（REQUIREMENT v1 写的坏模式）。

**F2 实测确认**：
```
setup grep HOOK_BASE_DIR: 0 命中 (未设)
source artifacts+gate 后: fk_validate_done_marker 未定义 ✗
加 HOOK_BASE_DIR 后: 已定义 ✓
```
证实 setup 缺 HOOK_BASE_DIR。主 agent 承认（依赖 TD-012 假设错误，TD-012 没碰 HOOK_BASE_DIR）。

## 主 agent 处置（REQUIREMENT v2 · 全接受）

| Finding | 处置 |
|---|---|
| F1 🔴 | **Fixed in: AC-2** — 删 `if ! fn` 坏模式，强制 `run`+`$status`（附等价模式）|
| F2 🔴 | **Fixed in: AC-5（新增 US-3）** — setup 补 `HOOK_BASE_DIR` 让 done-validation.sh 加载 |
| F3 🟡 | **Fixed in: AC-6（新增）** — 额外 6 条逐条定位归属（HOOK_BASE_DIR/run 改写/归 TD-014）|
| F4 | **Fixed in: AC-2** — 单一强制模式 |
| F5-F9 🟢 | 记录（正面/轻微）|

**结论**：L2 fail + 6 条全 Fixed in（REQUIREMENT v2）。F1/F2 是主 agent REQUIREMENT v1 的真实疏漏（坏模式 + HOOK_BASE_DIR 缺失依赖错误），L2 独立审查价值兑现。v2 进 L2 复审。

---

## L2 盲审（第二轮 · 复审 REQUIREMENT v2）

> qa-expert 复审 v2。**Verdict: fail**（1 🔴 F1 · AC-3 逻辑死结）。但 F1 是真实逻辑矛盾，主 agent 接受。

**F1 🔴 — AC-3「make test 全绿」与 v1 范围矛盾**：全 v2 修复后实测仍 6 条 not ok（#8/#11/#12/#19/#20/#23）。其中 #11/#12/#23 是**测试断言与实现长期不符**（artifacts.sh 不含测试断言的 phase 正则 / F29 不含 sha256sum · set+e 假绿掩盖），#19/#20 是 is_phase_write bug（TD-014 out）。AC-3 在本 change 范围内**不可达**。

**主 agent 核验确认**（receiving-code-review）：
```
#11/#12: artifacts.sh 含 ^(1|2|3|5|6|7)$ → 0 (不含) · 含 "3-task" → 0 (不含) · GATE_SH 含 → 1
#23: F29 含 sha256sum → 0 (不含)
#8: helper write_valid_done 缺 artifacts= KVP · done-validation 强制 return 2
```
证实 test_gate_integrity.bats 是**多重假绿灾区**（set+e + #8 helper + #11/#12/#23 断言债 + #19/#20 is_phase_write）。

## 主 agent 处置（REQUIREMENT v3 · 接受 L2 F1 建议）

| Finding | 处置 |
|---|---|
| F1 🔴 | **Fixed in: AC-3** — 改「v1 范围内全绿 + 范围外 skip 归因」+ AC-6 逐条归属 |
| #8 | **v1 修** helper write_valid_done 补 artifacts= KVP |
| #11/#12/#23 | **skip + 归 TD-016**（测试断言债 · 已追加 CONTEXT TD 表）|
| #19/#20 | **skip + 归 TD-014**（is_phase_write bug）|
| F2/F3/F4（AC-2 grep 多行/注释 run 误判）| 4-dev 实施时处理 |

**结论**：test_gate_integrity.bats 多重假绿（TD-013 set+e + #8 helper + TD-016 断言债 + TD-014 is_phase_write）。本 change（fix-gate-test-setup）收口 = 修 TD-013 + #8 + setup HOOK_BASE_DIR + 测试体 run，范围外 skip 归因。REQUIREMENT v3 进 L2 复审。

---

## L3 盲审（glm-4.7 外部模型 · 2026-07-09 10:58）

> 自动生成于 2026-07-09 10:58。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [
    {
      "file": "REQUIREMENT",
      "issue": "AC-6 Scope Creep（v1/范围蔓延）",
      "why": "AC-6（Given/Then）明确要求 '#8' 归属修复由 'v1 修' 且 'helper write_valid_done 补 artifacts=x,y'（属于修改源码 helper），但在「范围切分 v1」中仅包含 '测试体改 run+status'，未包含修改源码 helper。AC 需求（修源码）与 v1 范围（仅修测试）不一致，导致工件不可执行。",
      "fix": "将 'helper write_valid_done 补 artifacts' 补入「范围切分 v1」；或从 AC-6 中移除对 '#8' 代码修复的要求（若仅做测试断言 skip）。",
      "issue": "AC-6 Actionability Defect（可执行性缺陷）",
      "why": "AC-6 中 '#11/#12/#23' 条目的 Then 条件是 'skip + 归 TD-016'。'Skip' 通常是执行动作，而 '归 TD-016' 是外部管理动作。Given/When/Then 格式无法验证 '归 TD-016'（如何验证 link 是否存在？）。",
      "fix": "将 '#11/#12/#23' 的 Then 修改为可验证的技术条件，例如 'grep \"# TD-016\" test_gate_integrity.bats'，验证代码中已存在对应的 skip 标记和注释。",
      "issue": "AC-1/ACTION-2 逻辑缺失（依赖断层）",
      "why": "AC-1 要求 '去 set+e'，AC-2 要求 '改 run + status'。但在 '去 set+e' 后，原有的 'if ! fn' 模式若无 AC-2 的修改，会导致脚本在遇错时直接 exit（set -e 效应），可能破坏流程。工件未描述 'Given set+e is removed' 到 'Then tests pass' 之间的中间状态验证（AC-2 未完成前 AC-1 会导致全红？）。",
      "fix": "在 AC-1 或 AC-2 中补充 'Simultaneous patch' 或确保原子性的验证步骤，明确 AC-1 与 AC-2 必须同时合入方可验证 'AC-3'。"
    }
  ],
  "major": [
    {
      "file": "REQUIREMENT",
      "issue": "AC-5 验证方式覆盖不足",
      "why": "AC-5 验证方式仅检查 `type fk_validate_done_marker`（定义存在）。未验证函数调用是否成功，仅避免了 127 错误。若函数内部依赖 `$HOOK_BASE_DIR` 的路径计算（如 `source` 其他文件），可能定义存在但运行报错（如 'No such file directory'），但这未包含在 AC 中。",
      "fix": "增加验证步骤：在 bats 中执行 `fk_validate_done_marker` 一个无害调用或 mock 调用，确认运行时无报错。"
    },
    {
      "file": "REQUIREMENT",
      "issue": "Scope Definition Ambiguity（v1 定义歧义）",
      "why": "AC-5 要求 'setup 补 HOOK_BASE_DIR'（涉及源码修改）。但 Scope v1 描述为 'setup 补 HOOK_BASE_DIR' 和 '测试体改 run'。'setup' 既指测试文件的 setup 代码，也可能指被测源码的 setup。结合 AC-5（source done-validation.sh），此修改属于源码环境注入，Scope v1 描述应明确区分 '修改 test setup' 与 '修改 source env'。",
      "fix": "在 Scope v1 中明确 '修改 test_gate_integrity.bats 的 setup 块' 和 '确保测试环境变量 HOOK_BASE_DIR' 是两个独立动作。"
    }
  ],
  "minor": [
    {
      "file": "REQUIREMENT",
      "issue": "AC-2 验证正则潜在漏报",
      "why": "AC-2 验证方式 grep `run .+; .*status.*-eq`。若代码使用 `run fn; [ $? -eq N ]`（使用 $? 而非 $status），符合 '等价' 要求但会被正则漏报。",
      "fix": "验证正则增加 `$?` 分支，或仅依赖禁用坏模式 `! grep 'if !'` 的结果。"
    },
    {
      "file": "REQUIREMENT",
      "issue": "AC-1 验证方式路径单一",
      "why": "AC-1 验证方式仅检查 `test/test_gate_integrity.bats`。Given 提及 '两副本'，验证方式应包含 bundle 路径（`flow-kit-bundle/test/...`）以确保双修。",
      "fix": "验证方式增加 `|| ! grep ... flow-kit-bundle/test/...` 逻辑。"
    }
  ],
  "verdict": "fail",
  "summary": "AC-6 的需求（修 helper 源码）与 v1 范围（仅修测试）存在实质性冲突，导致工件不可直接执行（Scope Creep）；AC-6 中包含非技术性断言（归因 TD-016），违反可验证性原则。"
}
```
```
