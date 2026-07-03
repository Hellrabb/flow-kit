# 独立审查 · 阶段 3

## L2 盲审

### 🔴 R1 · T04 stop-hook.json 路径错误 + 模块命名不一致：配置写入错误位置，模块将永不被启用

**Symptom（症状）**：
- TASK.md T04 `read_files`（行 154）和 `write_files`（行 163）均指向 `flow-kit-bundle/hooks/stop/stop-hook.json`
- 该文件在仓库中不存在（`ls flow-kit-bundle/hooks/stop/stop-hook.json` 返回 "No such file"）
- 实际配置文件位于 `flow-kit-bundle/hooks/config/stop-hook.json`（由 `install_hooks.sh:72` 安装到 `.claude/stop-hook.json`）
- `common.sh:90-92` 的 config 加载逻辑读的是 `.claude/stop-hook.json`，该文件由 `hooks/config/stop-hook.json` 安装而来
- T04 提出的模块 key `"33-flow-active-integrity"` 带编号前缀，与既有模块命名不一致（`claude-md`、`weak_model_compliance`、`independent_review` 均不带编号前缀）
- T04 verify（行 177）同样检查错误的路径 `flow-kit-bundle/hooks/stop/stop-hook.json`

**Source（源头）**：DESIGN 0.5.1 同样写错路径（"flow-kit-bundle/hooks/stop/stop-hook.json（既有 · 新增 33 号模块入口）"）。`module_enabled()` 在 `common.sh:22-27` 从 CONFIG_FILE 查表，key 必须匹配。现有模块 key 规范：文件名为 `NN-name.sh`，config key 为 `name`（不包含 NN- 前缀）。

**Consequence（后果）**：
- T04 写入 `hooks/stop/stop-hook.json` 后，`install_hooks.sh` 不会拷贝该文件到 `.claude/stop-hook.json`（install 只拷贝 `hooks/config/stop-hook.json`）
- 运行时 `module_enabled` 无法找到模块 key → 返回 false（默认值）→ 33 模块立即 `exit 0`，所有检测逻辑永不执行
- AC-2 到 AC-6 要求的 L3 hook 交叉验证实质上未实现（代码存在但无法被触发）
- 即使路径修正，若 key 带 `33-` 前缀而模块内部调用 `module_enabled "flow-active-integrity"`，也会 key 不匹配导致同样结果

**Remedy（修补）**：

(1) 修正 T04 `read_files` 和 `write_files` 路径：
```
Before: flow-kit-bundle/hooks/stop/stop-hook.json
After:  flow-kit-bundle/hooks/config/stop-hook.json
```

(2) 修正 T04 `action` 中的 JSON 条目，去掉编号前缀：
```json
Before:
"33-flow-active-integrity": {
  "enabled": true,
  "description": ".flow-active 状态完整性交叉验证（L3）"
}

After:
"flow-active-integrity": {
  "enabled": true,
  "checks": []
}
```
（注：新增 `checks` 字段——现有所有模块条目均有 `checks` 数组；`description` 字段非既存约定，可保留但不被 `module_enabled` 消费）

(3) 修正 T04 `verify` 中的路径：
```
Before: jq -e '.["33-flow-active-integrity"].enabled == true' flow-kit-bundle/hooks/stop/stop-hook.json
After:  jq -e '.modules["flow-active-integrity"].enabled == true' flow-kit-bundle/hooks/config/stop-hook.json
```
（注：JSON 结构是 `.modules.<key>.enabled`，不是 `.["key"].enabled`）

---

### 🔴 R2 · 缺少 hook 执行链接线任务：33 模块创建后无任何机制触发执行

**Symptom（症状）**：
- `00-gate.sh:74-111` 是 Stop hook 链的唯一入口，所有模块通过硬编码 `run_module` 调用
- 00-gate.sh 当前调用了 01、20-30、99 号模块，但**未调用** 31（auto-advance）、32（fallback-guard）、以及计划中的 33
- TASK.md 中没有任何任务负责将 33 模块加入 00-gate.sh 的 `run_module` 调用列表
- 也没有任务将 `"33-flow-active-integrity"` 加入 `common.sh:225-230` 的 `HOOK_MODULE_NAMES` 数组（该数组被 `install_hooks.sh:48-51` 用于安装模块脚本文件）
- DESIGN 0.5.1 将 00-gate.sh 列入「禁动清单」（"gate 逻辑不变"），与 AC 要求矛盾

**Source（源头）**：
- AC-2 到 AC-6 的开头均为 "When Stop hook ... 执行 .flow-active 交叉验证"
- DESIGN 数据流图显示 "Stop Hook Chain (00-gate → ... → 32-fallback-guard → **33-flow-active-integrity**)"
- `common.sh:225-230` 的 `HOOK_MODULE_NAMES` 是安装时的模块列表（决定哪些 .sh 文件被安装）；`00-gate.sh:62-70` 的 `run_module` 调用是运行时的模块列表（决定哪些模块被执行）。两者独立，需分别更新

**Consequence（后果）**：
- T01 产出 `33-flow-active-integrity.sh`、T04 产出 config 后，该文件**永不被执行**
- install_hooks.sh 不会安装该文件（不在 HOOK_MODULE_NAMES 中），00-gate.sh 不会调用它
- 即便绕过 install 手工部署，00-gate.sh 未硬编码调用，模块依然是死代码
- AC-2 到 AC-6 的 L3 hook 交叉验证实质上无法实现
- 注：模块 31、32 当前也有同样的问题（文件存在但未被 00-gate.sh 调用），这是一个既存的系统性问题，本 change 应一并解决或被明确排除

**Remedy（修补）**：

方案 A（推荐——最小变更、解决 31/32/33 三者）：新增一个任务 T05：
- `read_files`: `flow-kit-bundle/hooks/stop/00-gate.sh`, `flow-kit-bundle/hooks/stop/lib/common.sh`
- `write_files`: `flow-kit-bundle/hooks/stop/00-gate.sh`
- action: 在 00-gate.sh 中 `# 30 — AI deep analysis` 之后、`# 99 — Report generation` 之前追加：
  ```bash
  # 31 — Auto-advance (pipeline mode)
  run_module "${HOOK_BASE_DIR}/31-auto-advance.sh" "auto-advance"

  # 32 — Fallback guard (fallback mode completion)
  run_module "${HOOK_BASE_DIR}/32-fallback-guard.sh" "fallback-guard"

  # 33 — .flow-active integrity cross-validation
  run_module "${HOOK_BASE_DIR}/33-flow-active-integrity.sh" "flow-active-integrity"
  ```
- verify: `grep -q '33-flow-active-integrity' flow-kit-bundle/hooks/stop/00-gate.sh`
- depends_on: T01
- 同步更新 DESIGN 0.5.1 禁动清单——将 00-gate.sh 从禁动中移除（仅本次 change 允许修改，后续重新列入禁动）

方案 B（更干净但范围更大）：将 00-gate.sh 重构为动态迭代 `HOOK_MODULE_NAMES`，替换所有硬编码 `run_module` 调用。此方案同时解决 31/32/33 及未来模块的接线问题，但触及面更广。

---

### 🟡 R3 · T02 GO.md 的 action 与 verify 不一致：verify 期望全文锚点，action 仅要求加注释

**Symptom（症状）**：
- T02 `action`（行 95-96）：要求 GO.md "在每个 phase transition 的 jq 命令块附近加注释 `# L2: 确认 .flow-active 已通过上方 jq 写入磁盘`"
- T02 `verify`（行 101）：`grep -l '\.flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘' ~/.claude/flow-kit/GO.md` —— 要求 GO.md 包含完整的 PCSC 锚点文本（含括号、详细字段列表）
- 注释文本 `# L2: 确认 .flow-active 已通过上方 jq 写入磁盘` 不包含 verify 所检查的完整锚点文本

**Source（源头）**：AC-1 verify（REQUIREMENT.md 行 37）要求 "总数 ≥ 9（8 个阶段 prompt + GO.md）"——GO.md 被计入必须含锚点文本的文件之一。但 GO.md 无 PCSC 表格结构（它是个路由文档），不适合加完整的表格行。

**Consequence（后果）**：
- 若实施者严格遵循 action → GO.md 只含注释，不含锚点文本 → verify 计为 8 个文件（仅 prompts），不满足 `grep -q '9'` → verify 失败
- 若实施者遵循 verify → 需在 GO.md 某处塞入完整的 PCSC 行锚点，但 GO.md 无适合位置（该文档无 PCSC 表）→ 锚点文本突兀
- 两种路径互相矛盾，增加实施摩擦

**Remedy（修补）**：

选择 A（保持 verify 不变，修正 action）：T02 `action` 中 GO.md 部分改为「在 GO.md 的自检段（行 463-471 "自检（产出路由声明前）"）追加一条：
```
- [ ] .flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘（test -s .flow-active && jq -e '.updated_at' .flow-active >/dev/null）
```」
这样 GO.md 含完整锚点文本，verify 可命中。

选择 B（保持 action 不变，修正 verify）：T02 `verify` 改为分别检查——prompts 8 个文件含锚点文本（计数 = 8），GO.md 含注释文本（单独检查）。AC-1 的 verify 也需要同步调整。

推荐选择 A——修改成本最小，且 GO.md 的自检段本就是放检查项的位置。

---

### 🟡 R4 · T03 缺少 NFR 可靠性测试用例：jq 不可用 / JSON 损坏 / 目录遍历失败 / 回退映射 均无测试覆盖

**Symptom（症状）**：
- T03 测试用例清单（行 122-144）仅覆盖 AC-2 到 AC-6 的正常/异常检测逻辑
- 未覆盖以下 REQUIREMENT.md NFR-可靠性（行 112）明确要求的容错场景：
  - jq 不可用 → 跳过检查（不崩溃）
  - `.flow-active` JSON 格式损坏 → 写入矫正文件 + 跳过
  - `.specs/` 目录遍历失败 → 跳过该阶段检查
  - `PHASE_ARTIFACTS` 未加载 → 回退到内置最小映射

**Source（源头）**：REQUIREMENT.md 行 112："可靠性: 以下异常场景必须容错处理，不崩溃、不阻断 Stop hook 链"。T01 `action` 行 41 明确列出这些错误处理要求。

**Consequence（后果）**：
- NFR 可靠性要求无法通过自动化验证——未来重构可能破坏容错逻辑而无人知晓
- 这些场景虽然在生产中概率低（jq 通常可用），但一旦触发（如 JSON 手工编辑出错）会导致 hook 链崩溃，阻断正常 hook 流程
- 同样严重的是：若实现未正确处理这些场景，问题可能在数月后才在生产中暴露

**Remedy（修补）**：T03 追加 4 条测试用例：
```
NFR-1 (jq-unavailable):
  - test_jq_unavailable_skip: 将 jq 重命名为 jq.bak → 运行 33 模块 → 验证 exit 0，矫正文件无新增

NFR-2 (json-corruption):
  - test_corrupted_flow_active: 写入 `{broken json` 到 .flow-active → 运行 33 → 验证矫正文件含 "corrupt" 类型记录 + exit 0

NFR-3 (specs-traversal-failure):
  - test_specs_dir_unreadable: chmod 000 .specs/ → 运行 33 → 验证不崩溃 + 输出 stderr 含 skip 信息

NFR-4 (phase-artifacts-fallback):
  - test_fallback_mapping: 清除 PHASE_ARTIFACTS 关联数组 → source 仅内置映射 → 验证 check_phase 仍能检测缺失产物
```

---

### 🟢 R5 · T01 任务粒度偏大：5 个检测函数 + 编排器 + 多种错误处理可能超 200 行

**Symptom（症状）**：T01 `action`（行 32-45）在一个任务内描述了：5 个独立检测函数、主编排器、jq 不可用容错、JSON 损坏容错、.specs 遍历失败容错、read-merge-write 矫正文件合并、PHASE_ARTIFACTS 回退映射、路径脱敏。估算总代码量 110-260 行。

**Source（源头）**：阶段 3 checklist "单 task 是否 ≤ 200 行变更？"（指导性建议，非硬性约束）。

**Consequence（后果）**：若超出 200 行，review 难度增加，但所有功能属于同一文件同一关注点（状态完整性验证），拆分可能导致跨 task 依赖。

**Remedy（修补）**：可接受的风险。若实施后实际代码 > 250 行，考虑将 NFR 容错逻辑拆到独立的 `trap`/`cleanup` 段或抽取到 lib 函数。当前不强制拆分。

---

### 🟢 R6 · T02 verify 仅覆盖 user-scope 9 个文件，bundle 源 9 个文件验证后移到 T04

**Symptom（症状）**：T02 `write_files` 列出 18 个文件（user-scope 9 + bundle 9），但 `verify`（行 101）仅 grep 检查 user-scope 的 9 个文件（`~/.claude/flow-kit/prompts/{0-change,...,7-integration}.md ~/.claude/flow-kit/GO.md`）。bundle 源的 9 个文件在 T04 通过 `diff -q` 验证一致性。

**Source（源头）**：无 spec 违规——T04 确实负责验证双写一致性（行 173）。但 T02 的 verify 仅部分覆盖其 write_files，依赖下游 T04 补全验证。

**Consequence（后果）**：T02 可 mark done 但 bundle 文件未写——需等 T04 执行才暴露。若 T04 跳过或被阻塞，bundle 不一致会遗漏。

**Remedy（修补）**：T02 verify 可追加 `&& diff ...` 检查 user-scope vs bundle 一致性（与 T04 去重），或明确标注「部分验证，完整验证见 T04」。

---

### 🟢 R7 · T03 AC-4 测试用例缺一项：current_phase gate 未 passed 的负面测试

**Symptom（症状）**：AC-4 要求三项检查之一：`current_phase` 对应的前一个 gate 状态为 `"passed"`。T03 列出 3 条 AC-4 case（行 131-134），但没有「current_phase=2, gate "1→2"=pending → 报警」的负面测试。

**Source（源头）**：AC-4（REQUIREMENT.md 行 59）："current_phase...对应的前一个 gate...状态为 passed。任一不一致 → 写入矫正文件"。

**Consequence（后果）**：若 check_pipeline 实现遗漏了 gate 状态检查，无法被测试捕获。轻微但 AC 覆盖有缺口。

**Remedy（修补）**：追加一条 case：`test_pipeline_current_phase_gate_not_passed: current_phase="2", gates["1→2"]="pending" → 矫正文件含 gate 不一致告警`。

---

**Verdict**: fail

---


---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-03 21:58）

> 自动生成于 2026-07-03 21:58。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[],"minor":[],"verdict":"pass","summary":"任务拆解覆盖了所有AC（AC-1至AC-6），depends_on依赖无环，每个task的verify可执行且能证伪，write_files边界清晰无越界，波次划分合理。"}
```
