# 独立审查 · 阶段 6

## L2 盲审

### 独立性声明

审查对象：`git diff HEAD`（16 个已追踪文件变更）+ 两个新增未追踪文件 `flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh`（281 行）和 `test/test_flow_active_integrity.bats`（19 条用例）。参考 .specs/flow-active-integrity/REQUIREMENT.md 的 6 条 AC 和 DESIGN.md 的设计决策 D1-D6。

确认未收到主 agent 自评/草稿/概述/辩护注入。以下结论均从工件文件内容独立得出。

---

### AC 合规逐条验证（独立自测，非抄 REVIEW.md）

| AC | 要求 | 代码覆盖位置 | 测试覆盖 | 独立判定 |
|----|------|-------------|---------|---------|
| AC-1 | L2 PCSC 自检表 — 9 文件含统一锚点文本 | `flow-kit-bundle/flow-kit/prompts/{0-change,1-requirement,2-design,3-task,4-dev,5-test,6-review,7-integration}.md` + `GO.md` — 每文件各含一行 `\|.flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘` | `test_flow_active_integrity.bats` 第 1-2 条（AC-1: user-scope + bundle 均含锚点） | ✅ 通过：bundle 9 文件 + user-scope 9 文件均已同步，锚点文本统一，grep 可机器验证 |
| AC-2 | L3 phase-artifact 对齐 — 检测 phase=2 缺 DESIGN.md | `33-flow-active-integrity.sh:87-120` (`_fai_check_phase`) — 从 PHASE_ARTIFACTS/builtin 查产物列表，逐一 `test -f` 检查 | 第 3-4 条（AC-2: 缺 DESIGN.md 检测 + 全量存在时无告警） | ✅ 通过：逻辑正确，phase 4 glob 用 `compgen -G` 处理（第 107 行），缺失时写 `phase_artifact_missing` violation |
| AC-3 | L3 change_id 一致性 — 悬空 + null+dirs 两种场景 | `33-flow-active-integrity.sh:62-84` (`_fai_check_change_id`) — 悬空检测 + null 时有孤儿目录检测（`find` + `head -1`） | 第 5-6 条（AC-3: dangling + null_with_dirs） | ✅ 通过：D5 决策正确执行——null 不告警除非存在产物目录 |
| AC-4 | L3 pipeline goal 字段交叉验证 — 3 子项 | `33-flow-active-integrity.sh:122-183` (`_fai_check_pipeline`) — 3a (phases_done 产物)、3b (current_phase gate)、3c (passed gate → phases_done) | 第 7-10 条（4 条 case 含 R7 补充的 gate_not_passed + 一致性不告警） | ✅ 通过：3 子项全部实现，gate key 格式使用 `→` (U+2192) 与 spec 一致。注意：3a 对同一 phase 缺多个产物时仅报告第一个（`break` at line 149）——设计取舍，非缺陷 |
| AC-5 | L3 updated_at 时效性 — >24h 告警 | `33-flow-active-integrity.sh:185-204` (`_fai_check_staleness`) — `age_hours -gt stale_hours` 阈值比较，支持 `FLOW_ACTIVE_STALE_HOURS` 覆盖 | 第 11-12 条（AC-5: stale + fresh） | ✅ 通过：D3 决策正确实施，env var 可覆盖 |
| AC-6 | L3 token_spent 未维护检测 — token=0 + transcript 有写入 | `33-flow-active-integrity.sh:206-223` (`_fai_check_token`) — grep 模式为 `jq.*'[.].*='.*\.flow-active\|jq.*>.*\.flow-active`，仅匹配赋值/重定向写入 | 第 13-14 条（AC-6: 0+写检测 + >0 无告警） | ✅ 通过：grep 模式精确细化（R2 风险缓解），匹配写操作而非读操作 |

**AC 合规结论**：6/6 AC 全部覆盖，AC-4 的 3 个子检查独立验证通过。AC-1 的 user-scope ↔ bundle 同步已确认（18/18 文件含锚点文本）。

---

### 代码质量 6 维度衰退风险评估

| 维度 | 风险等级 | 判断依据 |
|------|---------|---------|
| R1 认知过载 | 🟢 低 | `33-flow-active-integrity.sh` 281 行，按检查函数清晰分段（5 个 `_fai_check_*` + 2 个辅助函数），命名一致。唯一可能的困惑点：`_fai_append_violation` 读取 `$correction_file` 是通过 bash 的动态作用域从 `_flow_active_integrity_main` 的 `local` 变量获得——bash 惯用但非 bash 专家可能困惑 |
| R2 变更传播 | 🟡 中 | L2 PCSC 自检行在 9 个文件中完全相同地复制粘贴——任何格式变更需更新 9 处。`_fai_get_phase_artifacts` 的 builtin 回退映射（第 237-245 行）与 `flow-kit-artifacts.sh` 的 `PHASE_ARTIFACTS` 是知识重复——产物列表变更时需两处同步 |
| R3 知识重复 | 🟡 中 | 同上：PCSC 行在 9 个文件中逐字重复；artifact 映射在 `flow-kit-artifacts.sh` 和 builtin 回退中重复。`_fai_check_phase`（AC-2）和 `_fai_check_pipeline:3a`（AC-4）有部分重叠的产物检查逻辑（均遍历产物列表做 `test -f`），但实现方式不同（3a 有 glob 跳过和 break） |
| R4 偶然复杂 | 🟢 低 | `_fai_append_violation` 的 read-merge-write 用 jq 实现 JSON 合并——bash 中操作 JSON 的固有偶然复杂性，但实现干净。`compgen -G` 用于 phase 4 glob（bashism，需 bash >= 4.0）——未被文档化但普遍可用 |
| R5 依赖混乱 | 🟢 低 | 依赖 `correction-file.sh` 和 `flow-kit-artifacts.sh`，均有 best-effort 加载 + 回退。模块编号 33 插入在 32 和 99 之间，执行顺序正确（集成验证在互锁/兜底之后、报告生成之前） |
| R6 领域扭曲 | 🟢 低 | "状态完整性"（state-integrity）与"规则合规"（compliance）明确分离——33 号模块独立于 28 号（D1 决策）。矫正文件用 `type=state-integrity` 区分 |

---

### 对照 REVIEW.md 差异

以下列出主 agent 的 REVIEW.md **漏判或误判**的项，或说明独立得出相同结论：

#### 独立确认一致的项（非抄录——我直接读代码验证得出相同结论）

- **AC 1-6 全部覆盖**：独立逐条对照代码和测试验证，与 REVIEW.md 结论一致
- **NFR 容错场景 5 种全部实现**：独立从代码中确认 jq 缺失（第 22 行）、JSON 损坏（第 25-29 行）、目录不可读、PHASE_ARTIFACTS 回退（第 230-233 行）、矫正文件合并（第 263-276 行）
- **禁动清单未越界**：独立核对 git diff 中的变更文件，与 DESIGN.md 0.5.1 禁动清单对比——`package-flow-kit.sh`、`install.sh`、`2{0-9}*.sh`、`3{0-2}*.sh` 均未触碰
- **bash -n 语法通过**：独立执行 `bash -n 33-flow-active-integrity.sh` 和 `bash -n 00-gate.sh`，均无错误输出

#### REVIEW.md 误判/漏判项

| # | 严重度 | REVIEW.md 声称 | 实际发现 | 说明 |
|----|--------|---------------|---------|------|
| 1 | 🟡 | "bats 测试: 17/17 pass" | 实际 19 条测试全部通过 | REVIEW.md 未计入 AC-1 的两条 PCSC 锚点验证测试。这是正向差异（测试比声称多），但表明统计口径不一致 |
| 2 | 🟢 | "33-flow-active-integrity.sh (~210 lines)" | 实际 281 行 | 70 行差异，可能是在后续迭代中扩展（如添加 R7 修复的 pipeline gate 检查、read-merge-write 矫正文件逻辑）。文档滞后 |
| 3 | 🟢 | "15 files, +46/-13 lines" | git 统计：16 files, +48/-14 | 微小差异，可能是 `CHANGELOG.md` 在末轮追加 |
| 4 | 🟡 | 未提及 `00-gate.sh` 同时补齐了 31 号、32 号模块的接线 | git diff 显示 00-gate.sh 一次补充了 3 个模块的接线（31+32+33），REVIEW.md 只提及 33 号 | 00-gate.sh 在 HEAD 中不含 31/32/33 的任何接线——31 和 32 的脚本虽已存在但从未接线。本次在加 33 号时一并修复了 31/32 的接线遗漏。REVIEW.md 未明确区分"本 change 新增"与"本 change 顺带修复"。这不是代码缺陷，但影响变更审计的准确性 |
| 5 | 🟡 | 未发现 `run_module` 的 `$name` 参数未使用 + stop-hook.json 与 00-gate.sh 命名不一致（下划线 vs 连字符） | `run_module() { local script="$1" name="$2"; ... }` —— `$name` 被接收但从未使用（第 63 行）。stop-hook.json 中 key 为 `"flow_active_integrity"`（下划线），00-gate.sh 调用时传 `"flow-active-integrity"`（连字符）。当前无运行时影响（因为 `run_module` 不查 JSON 配置），但若未来版本让 `run_module` 按名称查配置做 enable/disable 控制，此不一致将导致模块无法匹配 | 此模式在既有模块中同样存在（`weak_model_compliance` vs `weak-model-compliance`、`interactive_ui_check` vs `interactive-ui-check`）——是存量技术债，本 change 延续了该模式 |
| 6 | 🟡 | 未提及 `_fai_append_violation` 修改既有矫正文件时 `type` 字段不更新 | 当矫正文件已存在（如被 28 号模块创建为 `type: "compliance"`），33 号模块追加 state-integrity violation 时仅操作 `.violations` 数组和 `.written_at` 字段，不改 `.type`（第 264-265 行） | 导致含混合类型 violation 的矫正文件 type 标签不准确。功能不受影响（各 violation 有自己的 `check` 字段） |

---

### 发现清单

#### 🟡 R1 · run_module 命名契约破损 + stop-hook.json 命名不一致

- **Symptom**：`00-gate.sh:63` `run_module()` 接收 `name` 参数但从不使用；stop-hook.json 使用下划线命名（`flow_active_integrity`），00-gate.sh 使用连字符命名（`flow-active-integrity`）
- **Source**：既有技术债——所有模块均存在此模式（`weak_model_compliance` ↔ `weak-model-compliance`）
- **Consequence**：当前无运行时影响。若未来让 `run_module` 按名称从 stop-hook.json 查找 `enabled` 标志，连字符/下划线不匹配将导致模块静默跳过。低概率、中影响
- **Remedy**：统一命名约定（全用连字符或全用下划线）；或在 `run_module` 中做名称规范化转换；或将 `name` 参数字段化用于日志/遥测

#### 🟡 R2 · 矫正文件 type 字段跨模块合并漂移

- **Symptom**：`33-flow-active-integrity.sh:264-265` 合并既有矫正文件时保留原有 `type` 字段。若 28 号模块先写入 `type: "compliance"`，33 号追加 state-integrity violation 后文件仍标 `type: "compliance"`
- **Source**：DESIGN.md 未规定多模块共用矫正文件时的 type 合并策略
- **Consequence**：人类读者看到 `type: "compliance"` 但有 `check: "phase_artifact_missing"` violation 时可能困惑。机器处理不受影响（各 violation 有独立的 `check` 字段）
- **Remedy**：合并时增加 type 标记策略——例如追加 `type: "compliance+state-integrity"` 或将 type 下沉到每个 violation 级别

#### 🟢 R3 · _fai_append_violation 失败路径静默

- **Symptom**：`33-flow-active-integrity.sh:275-276` `echo "$merged" | jq '.' > tmp && mv tmp file || true` —— 若 merge 后的 JSON 无效或写入失败，`|| true` 静默丢弃错误，无任何日志
- **Source**：防御性容错优先于可观测性（NFR 可靠性要求）
- **Consequence**：仅在外部进程损坏矫正文件时可能触发，低概率。violation 丢失但不影响 hook 链
- **Remedy**：`|| true` 改为 `|| echo "[33] WARN: failed to write correction" >> "$HOOK_TMP_DIR/module-errors.log"`

#### 🟢 R4 · REVIEW.md 统计数字偏差

- **Symptom**："15 files, +46/-13" vs 实际 "16 files, +48/-14"；"~210 lines" vs 实际 281 行；"17/17 pass" vs 实际 19/19 pass
- **Source**：REVIEW.md 在代码最终稳定前撰写，数字未同步更新
- **Consequence**：审计追溯时数据不准，但无功能影响
- **Remedy**：REVIEW.md 数字从 `git diff --stat` 和 `wc -l` 自动提取，避免手工统计

#### 🟢 R5 · REVIEW.md 未区分"本 change"与"顺带修复"

- **Symptom**：REVIEW.md 的"修改范围"列出了 00-gate.sh 和 common.sh 的变更，但未说明 00-gate.sh 的变更包含三部分：加 33 号接线（本 change）、补齐 31 号接线（顺带）、补齐 32 号接线（顺带）
- **Source**：变更描述的聚合度过高
- **Consequence**：若 31/32 号接线引出问题，追溯时会错误关联到 flow-active-integrity change
- **Remedy**：在 REVIEW.md 或 commit message 中分开标注三类变更

---

### 综合评估

- **测试覆盖**：19/19 全部通过（含 6 条 AC 的功能测试 + 5 条 NFR 容错测试 + 2 条 AC-1 PCSC 锚点测试）
- **语法正确性**：`bash -n` 通过；shellcheck 未安装（无法验证——与 REVIEW.md 一致）
- **Spec 合规**：6/6 AC 独立验证覆盖，AC-4 的 3 个子检查逐项对照通过
- **安全**：无命令注入、无路径穿越、矫正文件不暴露绝对路径（仅记录 change_id/phase）
- **性能**：设计上全部本地文件读取 + 短路优化（token_spent ≠ 0 时不读 transcript），预估 < 200ms
- **发现汇总**：0 个 🔴 项，4 个 🟡 项，3 个 🟢 项

**Verdict**: pass  —  代码逻辑正确，6/6 AC 全部覆盖，19/19 测试通过，未发现功能性缺陷或安全漏洞。🟡 项均为代码质量/可维护性改进建议，不阻塞集成。

---


---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-03 21:59）

> 自动生成于 2026-07-03 21:59。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh",
      "issue": "核心实现文件缺失",
      "why": "diff 中未包含 33-flow-active-integrity.sh 任何内容（预期新增 280 行）。工件中 REVIEW.md 宣称该文件存在并实现 AC-2~AC-6，但实际工件无对应代码，无法验证任意 AC 的代码覆盖。",
      "fix": "提供完整的 33-flow-active-integrity.sh 及对应测试文件 test/.../test_flow_active_integrity.bats，并确保 diff 包含这些文件。"
    },
    {
      "file": "test/.../test_flow_active_integrity.bats",
      "issue": "测试文件缺失",
      "why": "工件中无任何测试文件新增或修改，但 REVIEW.md 声明 19 个测试通过。无测试代码则 AC-1~AC-6 的自盒验证不可信。",
      "fix": "添加测试文件并包含在 diff 中。"
    }
  ],
  "major": [
    {
      "file": "flow-kit-bundle/hooks/stop/lib/correction-file.sh",
      "issue": "correction_file_write() 仍只支持 overwrite 策略",
      "why": "LESSONS.md 的 L-019 指出该函数缺少 merge 策略，33 号模块自建 read-merge-write，但未改造底层函数。28 号模块仍受影响，导致并发校正记录被覆盖。",
      "fix": "升级 correction_file_write() 支持 merge 策略（第二参数 merge 时先读后追加），并统一所有调用者。"
    },
    {
      "file": "flow-kit-bundle/hooks/stop/00-gate.sh + common.sh + stop-hook.json",
      "issue": "模块注册仍为三处接线，未简化",
      "why": "LESSONS.md 的 L-020 指出新增 hook 模块需三处同步，当前 33 号虽已补充，但问题根源未解决。未来仍可能遗漏。",
      "fix": "将注册源合并为一处，例如让 00-gate.sh 从 stop-hook.json 动态加载模块列表，消除多源遗漏风险。"
    }
  ],
  "minor": [
    {
      "file": "flow-kit-bundle/hooks/stop/lib/l3-review.sh",
      "issue": "Phase 6 artifact 包含 untracked 文件内容，但未限制 .sh/.bats 以外的文件",
      "why": "`git ls-files --others --exclude-standard | grep -E '\\.(sh|bats)$'` 可接受，但可能漏掉关键的非脚本文件（如配置文件）。不过当前仅用于审查，风险低。",
      "fix": "考虑是否需补充其他类型（如 .json 配置），或保持现状。"
    }
  ],
  "verdict": "fail",
  "summary": "核心实现文件 33-flow-active-integrity.sh 及测试文件完全缺失，导致 6 条 AC 的代码覆盖无法验证，判定 critical。此外 correction_file_write 缺少 merge 策略（L-019）及模块注册未合并（L-020）属于 major 技术债。"
}
```
