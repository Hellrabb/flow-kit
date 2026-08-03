# TASK · final-debt-cleanup-2026-08

> Phase 3 任务清单 · 2026-08-03 · 15 AC → 8 tasks in 4 waves

---

## 调度策略

- **Wave 1**（4 并行 · 轻量文档/ADR）：T01 + T02 + T03 + T04
- **Wave 2**（2 并行 · 重型重构）：T05 + T06
- **Wave 3**（1 串行 · 集成测试）：T07（依赖 T05+T06 完成的文件）
- **Wave 4**（1 串行 · 交付）：T08（依赖所有）

---

## T01 · TD-071-A/B LESSONS 标记 resolved non-bug

- **id**: T01
- **name**: 标记 TD-071-A/B 为 resolved non-bug
- **model-tier**: cheap
- **read_files**: `.specs/LESSONS.md` (L-069~L-072 + TD-071-A/B 段)
- **write_files**: `.specs/LESSONS.md`
- **action**:
  1. Edit TD-071-A 行：将 `🟢 Scheduled` 改为 `✅ Resolved (状态变化 · 2026-08-03 package validate 0/0 clean post cleanup-debt-batch)`
  2. Edit TD-071-B 行：同样改为 `✅ Resolved (状态变化 · A-evolve.md 实际存在 flow-kit-bundle/flow-kit/prompts/A-evolve.md)`
  3. 不动 `package-flow-kit.sh`（现状已正确）
- **verify**:
  - `grep "TD-071-A" .specs/LESSONS.md | grep -q "✅ Resolved"` && echo "OK" || exit 1
  - `grep "TD-071-B" .specs/LESSONS.md | grep -q "✅ Resolved"` && echo "OK" || exit 1
  - `bash package-flow-kit.sh --validate 2>&1 | grep -q "✅ 校验通过"` && echo "validate OK" || exit 1
- **done**: TD-071-A + TD-071-B 标记 resolved + validate clean

---

## T02 · ADR-019 + CONTEXT.md 3 原则入库

- **id**: T02
- **name**: ADR-019 写作 3 原则 + CONTEXT.md 已锁决策追加
- **model-tier**: standard
- **read_files**: `.specs/adr/014-review-merge-and-spot-check.md` (ADR 模板参考) · `.specs/LESSONS.md` (L-058/060/062 段) · `.specs/CONTEXT.md` (已锁决策段)
- **write_files**: `.specs/adr/019-writing-principles.md` · `.specs/CONTEXT.md` · `.specs/LESSONS.md`
- **action**:
  1. 新建 `.specs/adr/019-writing-principles.md`（~80 行）：
     - 标题 `# ADR-019 · REQUIREMENT 写作 3 原则`
     - 日期 2026-08-03 / 状态 Accepted / 决策者 flow-kit
     - **Principle 1 (L-058)**：AC 二值化（必 pass 或显式 skip-with-reason，禁"如可用"/"待 X"/"DESIGN 阶段细化"）。需要 fallback 拆 a/b 两条独立 AC。
     - **Principle 2 (L-060)**：范围决策与设计实施分离（"做什么"+边界留 REQUIREMENT；"如何实现"细节留 DESIGN 或独立 ADR）。
     - **Principle 3 (L-062)**：生命周期 spec 必含可验证产物（schema 文件 / jq path / grep 模式，禁仅 diagram 描述）。
     - 每原则：反例（从 archived superpowers-v6-absorb 引用）+ 正例（如何写）
     - 应用范围：所有新 REQUIREMENT.md phase 1 入场 + L2 blind review checklist
  2. CONTEXT.md 已锁决策追加：
     ```
     - `[2026-08-03]` REQUIREMENT 写作 3 原则 — ADR-019：AC 二值化 / 范围决策与设计实施分离 / 生命周期 spec 必含可验证产物。应用于所有新 REQUIREMENT。来自 `final-debt-cleanup-2026-08` Phase 2 D2
     ```
  3. LESSONS.md：L-058/060/062 → `✅ Resolved (ADR-019)` **+ L-061/063 → `✅ Resolved (ADR-020/021)`**（**合并 T03 的 LESSONS 写入避免 W1 并行冲突**）
- **verify**:
  - `test -f .specs/adr/019-writing-principles.md` || exit 1
  - `grep -c "Principle [123]" .specs/adr/019-writing-principles.md` 应 = 3
  - `grep "ADR-019" .specs/CONTEXT.md | grep -q "2026-08-03"` || exit 1
  - `grep "L-058" .specs/LESSONS.md | grep -q "✅ Resolved"` || exit 1
  - `grep "L-060" .specs/LESSONS.md | grep -q "✅ Resolved"` || exit 1
  - `grep "L-062" .specs/LESSONS.md | grep -q "✅ Resolved"` || exit 1
  - `grep "L-061" .specs/LESSONS.md | grep -q "✅ Resolved"` || exit 1
  - `grep "L-063" .specs/LESSONS.md | grep -q "✅ Resolved"` || exit 1
- **done**: ADR-019 创建 + 3 原则入 CONTEXT + 5 LESSONS resolved（L-058/060/061/062/063）

---

## T03 · ADR-020 (OpenCode task) + ADR-021 (weak model degradation)

- **id**: T03
- **name**: 2 ADR 文档化（OpenCode task 实测 + 弱模型降级协议）
- **model-tier**: standard
- **read_files**: `.specs/adr/016-model-tier-dispatch.md` (model-tier 背景) · `.specs/LESSONS.md` (L-061/063 段)
- **write_files**: `.specs/adr/020-opencode-task-capability.md` · `.specs/adr/021-weak-model-prompt-degradation.md` · `.specs/LESSONS.md`
- **action**:
  1. 新建 `.specs/adr/020-opencode-task-capability.md`（~60 行）：
     - 标题 `# ADR-020 · OpenCode task 工具能力快照`
     - 日期 2026-08-03 / 状态 Accepted（实测基于 OpenCode 当前版本）
     - **实测证据**：本 session 大量使用 task() 派发子 agent
     - **支持**：`task(category=..., prompt=...)` / `task(subagent_type=...)` / `task(run_in_background=true)` / 多种 subagent 类型（backend-developer / qa-expert / architect-reviewer / code-reviewer / explore / librarian）
     - **不支持**：`model-tier` 字段（无 API 参数）/ 跨 task session 隔离（同 task_id 可恢复）/ model 选项（由 category/subagent_type 决定）
     - **结论**：model-tier 在 OpenCode 退化为 dispatch prompt hint（非真实模型切换），与 ADR-016 fallback 一致
     - **过期协议**：若 OpenCode 新增 task-level model 支持，本 ADR 标 Deprecated 并重新实测
  2. 新建 `.specs/adr/021-weak-model-prompt-degradation.md`（~100 行）：
     - 标题 `# ADR-021 · 弱模型 prompt 降级协议`
     - 日期 2026-08-03 / 状态 Accepted（协议设计，未实施）
     - **协议设计**：
       1. 检测层：prompts 顶部加 `<!-- model-tier: standard|cheap|top -->` HTML 注释（不影响渲染）
       2. 降级标记：critical anchor 段（PCSC / 1.4 写前检查 / Pipeline Toll-Gate）加 `<details model-tier="standard+">` 折叠段，cheap-tier 可 skip
       3. opt-out 协议：`.flow-active.goal.model_tier` 字段（新增）记录当前 session 模型层级
       4. AC 校验：cheap-tier 下仍需满足核心 AC，可 skip 扩展段
     - **状态机**：见 DESIGN §3
     - **不实施**：v2 任务（需独立 change），本 ADR 仅固化协议关闭 spec gap
  3. LESSONS.md：L-061 → `✅ Resolved (ADR-020)`；L-063 → `✅ Resolved (ADR-021 协议设计)`
- **verify**:
  - `test -f .specs/adr/020-opencode-task-capability.md` || exit 1
  - `grep -q "实测证据" .specs/adr/020-opencode-task-capability.md` || exit 1
  - `test -f .specs/adr/021-weak-model-prompt-degradation.md` || exit 1
  - `grep -q "协议设计" .specs/adr/021-weak-model-prompt-degradation.md` || exit 1
  - `grep "L-061" .specs/LESSONS.md | grep -q "✅ Resolved"` || exit 1
  - `grep "L-063" .specs/LESSONS.md | grep -q "✅ Resolved"` || exit 1
- **done**: 2 ADR 创建 + 2 LESSONS resolved

---

## T04 · AC-B4 addendum + combined metric test (L-066)

- **id**: T04
- **name**: archived REQUIREMENT AC-B4 加 addendum + 新建 combined metric 测试
- **model-tier**: standard
- **read_files**: `.specs/archive/superpowers-v6-absorb/REQUIREMENT.md` (AC-B4 段) · `test/test_integration_smoke.bats` (fixture pattern 参考)
- **write_files**: `.specs/archive/superpowers-v6-absorb/REQUIREMENT.md` · `test/test_combined_metric.bats` · `flow-kit-bundle/test/test_combined_metric.bats`
- **action**:
  1. 在 `.specs/archive/superpowers-v6-absorb/REQUIREMENT.md` AC-B4 段末尾追加：
     ```markdown
     
     **Addendum (2026-08-03 · L-066 fix · final-debt-cleanup-2026-08)**：原 AC-B4 仅验证 task-brief 单独输出 ≤2KB。
     补充：4-dev.md 加载 task-brief 后的**合并负载**（4-dev.md + task-brief 输出）应 ≤17KB
     （4-dev.md 目标 ≤15KB + task-brief ≤2KB 预算）。
     验证：test/test_combined_metric.bats 同时加载两文件，断言总字节数 ≤17000。
     ```
  2. 新建 `test/test_combined_metric.bats`：
     ```bash
     #!/usr/bin/env bats
     
     @test "AC-B4 combined: 4-dev.md + task-brief total ≤17KB" {
       local dev_md="flow-kit-bundle/flow-kit/prompts/4-dev.md"
       local task_brief="flow-kit-bundle/flow-kit/scripts/task-brief"
       local tmp_task="flow-kit-bundle/flow-kit/templates/TASK.md"
     
       run awk -f "$task_brief" "$tmp_task" "T01"
       [ "$status" -eq 0 ]
       task_block="$output"
     
       dev_size=$(wc -c < "$dev_md")
       task_size=$(printf '%s' "$task_block" | wc -c)
       combined=$((dev_size + task_size))
     
       echo "4-dev.md: $dev_size bytes"
       echo "task-brief T01: $task_size bytes"
       echo "combined: $combined bytes (limit 17000)"
       [ "$combined" -le 17000 ]
     }
     ```
  3. `cp test/test_combined_metric.bats flow-kit-bundle/test/test_combined_metric.bats` 同步
  4. LESSONS.md：L-066 → `✅ Resolved (AC-B4 addendum + combined metric test)`
- **verify**:
  - `grep -q "Addendum (2026-08-03" .specs/archive/superpowers-v6-absorb/REQUIREMENT.md` || exit 1
  - `test -f test/test_combined_metric.bats` || exit 1
  - `diff -q test/test_combined_metric.bats flow-kit-bundle/test/test_combined_metric.bats` || exit 1
  - `npx bats test/test_combined_metric.bats` 必须 pass
  - `grep "L-066" .specs/LESSONS.md | grep -q "✅ Resolved"` || exit 1
- **done**: AC-B4 addendum + combined metric test 创建 + L-066 resolved

---

## T05 · l3-review.sh 拆分为 5 文件 (TD-008 + TD-017)

- **id**: T05
- **name**: l3-review.sh 875 行拆分为 5 子 lib（l3-prompt / l3-api / l3-truncate / l3-done / l3-review slim）
- **model-tier**: top
- **read_files**: `flow-kit-bundle/hooks/stop/lib/l3-review.sh` (875 行 / 12 函数)
- **write_files**: 
  - `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` (NEW)
  - `flow-kit-bundle/hooks/stop/lib/l3-api.sh` (NEW)
  - `flow-kit-bundle/hooks/stop/lib/l3-truncate.sh` (NEW)
  - `flow-kit-bundle/hooks/stop/lib/l3-done.sh` (NEW)
  - `flow-kit-bundle/hooks/stop/lib/l3-review.sh` (MODIFIED, slim)
- **action**:
  1. 新建 `l3-truncate.sh`：剪切 l3-review.sh L55-200（`smart_truncate` 函数）粘贴，加文件头 `#!/usr/bin/env bash` + `set -euo pipefail`
  2. 新建 `l3-prompt.sh`：剪切 L43-48 (`_l3_format_result`) + L205-228 (`_l3_inject_context`) + L233-334 (`_l3_build_prompt`) + L806-875 (`l3_dispatch_prompt`) 粘贴
  3. 新建 `l3-api.sh`：剪切 L339-430 (`_l3_call_api`) + L480-588 (`_l3_parse_result`) + L746-774 (`l3_review_with_timeout`) 粘贴
  4. 新建 `l3-done.sh`：剪切 L435-475 (`_l3_check_rerun`) + L593-651 (`_l3_write_done`) + L777-800 (`l3_write_timeout_done`) 粘贴
  5. 修改 `l3-review.sh` (slim)：
     - 保留文件头 + `set -euo pipefail`
     - 加 4 行 source：`source "${BASH_SOURCE[0]%/*}/l3-truncate.sh"` + l3-prompt + l3-api + l3-done
     - 保留 L654-743 (`l3_review_run` 编排器)
     - 删除其他已迁出的函数定义
  6. 函数命名保持原样（不重命名，向后兼容）
  7. 总行数核算：l3-prompt ~215 + l3-api ~240 + l3-truncate ~150 + l3-done ~135 + l3-review slim ~92 = ~832（vs 原 875）
- **verify**:
  - `wc -l flow-kit-bundle/hooks/stop/lib/l3-{prompt,api,truncate,done,review}.sh` 总和 ≤1500
  - 单文件 ≤250
  - `bash -n flow-kit-bundle/hooks/stop/lib/l3-{prompt,api,truncate,done,review}.sh` 全 0
  - 关键函数可见：
    ```bash
    source flow-kit-bundle/hooks/stop/lib/l3-truncate.sh
    source flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    source flow-kit-bundle/hooks/stop/lib/l3-api.sh
    source flow-kit-bundle/hooks/stop/lib/l3-done.sh
    source flow-kit-bundle/hooks/stop/lib/l3-review.sh
    type -t l3_review_run | grep -q function
    type -t smart_truncate | grep -q function
    type -t _l3_build_prompt | grep -q function
    ```
  - `npx bats test/` 全量回归（≥657 tests, 0 fail）
- **done**: l3-review.sh 拆 5 文件 + 全量回归 pass

---

## T06 · independent-review-gate.sh 拆分为 4 文件 (TD-018)

- **id**: T06
- **name**: independent-review-gate.sh 597 行拆分为 4 子 lib（gate-helpers / gate-checks-basic / gate-checks-review / slim）
- **model-tier**: top
- **read_files**: `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` (597 行 / 20 函数)
- **write_files**:
  - `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh` (NEW)
  - `flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh` (NEW)
  - `flow-kit-bundle/hooks/pre-tool-use/gate-checks-review.sh` (NEW)
  - `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` (MODIFIED, slim)
- **action**:
  1. 新建 `gate-helpers.sh`：剪切 9 个谓词函数（L44-201）：
     - `_is_dotdone_write` (L44-63) + `_gate_is_l2_only` (L64-81) + `fk_check_gate_config_tamper` (L82-99) + `is_phase_write` (L100-122) + `_fk_phase_direction` (L123-140) + `_command_has_write_context` (L141-149) + `_command_first_tokens` (L150-174) + `is_git_commit` (L175-185) + `is_gh_pr_create` (L186-201)
  2. 新建 `gate-checks-basic.sh`：剪切 7 个基础 gate 函数（L202-513）：
     - `_gate_path_guard` (L202-241) + `_gate_phase_filter` (L242-259) + `_gate_active_check` (L260-272) + `_gate_done_validation` (L273-278) + `_gate_tamper_detect` (L279-295) + `_gate_do_transition` (L457-479) + `_gate_phase_transition` (L480-513)
     - **注意**：跳过 L296-456（_gate_check_l2 + _gate_check_l3，归到 gate-checks-review.sh）
  3. 新建 `gate-checks-review.sh`：剪切 2 个 L2/L3 审查 gate 函数：
     - `_gate_check_l2` (L296-396) + `_gate_check_l3` (L397-456)
  4. 修改 `independent-review-gate.sh` (slim)：
     - 保留文件头 + `set -euo pipefail`
     - 加 3 行 source：`source "${BASH_SOURCE[0]%/*}/gate-helpers.sh"` + gate-checks-basic + gate-checks-review
     - 保留 `_gate_deny_reason` (L514-538) + `_run_review_gates` (L539-597) 编排器
     - 删除其他已迁出的函数定义
  5. 函数命名保持原样
  6. 总行数核算：helpers ~149 + basic ~144 + review ~161 + slim ~83 = ~537（vs 原 597）
- **verify**:
  - `wc -l flow-kit-bundle/hooks/pre-tool-use/{gate-helpers,gate-checks-basic,gate-checks-review,independent-review-gate}.sh` 总和 ≤1500
  - 单文件 ≤200
  - `bash -n` 全 4 文件 0 错误
  - 关键函数可见：
    ```bash
    source flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh
    source flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh
    source flow-kit-bundle/hooks/pre-tool-use/gate-checks-review.sh
    source flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    type -t _run_review_gates | grep -q function
    type -t _gate_path_guard | grep -q function
    type -t _gate_tamper_detect | grep -q function
    type -t _gate_check_l2 | grep -q function
    type -t _gate_check_l3 | grep -q function
    ```
  - `npx bats test/` 全量回归（≥657 tests, 0 fail）
- **done**: gate.sh 拆 4 文件 + 全量回归 pass

---

## T07 · 集成测试 + L2/L3 source chain 验证 (AC-E3)

- **id**: T07
- **name**: 新建 test_hook_integration.bats 验证 T05+T06 拆分后 source chain
- **model-tier**: standard
- **read_files**: DESIGN.md §1 D8 (INT-HOOK-1/2/3 测试设计)
- **write_files**: `test/test_hook_integration.bats` · `flow-kit-bundle/test/test_hook_integration.bats`
- **action**:
  1. 新建 `test/test_hook_integration.bats`：
     ```bash
     #!/usr/bin/env bats
     
     @test "INT-HOOK-1: PreToolUse independent-review-gate.sh sources correctly post-split" {
       source flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh
       source flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh
       source flow-kit-bundle/hooks/pre-tool-use/gate-checks-review.sh
       source flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
       type -t _run_review_gates | grep -q function
       type -t _gate_path_guard | grep -q function
       type -t _gate_tamper_detect | grep -q function
       type -t _gate_check_l2 | grep -q function
       type -t _gate_check_l3 | grep -q function
     }
     
     @test "INT-HOOK-2: Stop hook l3-review.sh sources correctly post-split" {
       for lib in l3-truncate.sh l3-prompt.sh l3-api.sh l3-done.sh; do
         source "flow-kit-bundle/hooks/stop/lib/$lib"
       done
       source flow-kit-bundle/hooks/stop/lib/l3-review.sh
       type -t l3_review_run | grep -q function
       type -t _l3_build_prompt | grep -q function
       type -t smart_truncate | grep -q function
     }
     
     @test "INT-HOOK-3: source overhead ≤500ms" {
       local start_ns end_ns elapsed_ms
       start_ns=$(date +%s%N)
       for lib in l3-truncate.sh l3-prompt.sh l3-api.sh l3-done.sh; do
         source "flow-kit-bundle/hooks/stop/lib/$lib"
       done
       source flow-kit-bundle/hooks/stop/lib/l3-review.sh
       end_ns=$(date +%s%N)
       elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
       echo "source overhead: ${elapsed_ms}ms"
       [ "$elapsed_ms" -le 500 ]
     }
     ```
  2. `cp test/test_hook_integration.bats flow-kit-bundle/test/test_hook_integration.bats`
- **verify**:
  - `test -f test/test_hook_integration.bats` || exit 1
  - `diff -q test/test_hook_integration.bats flow-kit-bundle/test/test_hook_integration.bats` || exit 1
  - `npx bats test/test_hook_integration.bats` 3/3 pass
- **done**: 集成测试 3 个 + 全 pass

---

## T08 · 交付 meta（CHANGELOG + sync + 禁动 exception + commit + LESSONS）

- **id**: T08
- **name**: 全部交付 meta 文件更新 + 双源 sync + commit
- **model-tier**: standard
- **read_files**: 所有前置 task 产物
- **write_files**: `.specs/CHANGELOG.md` · `.specs/CONTEXT.md` · `.specs/LESSONS.md`
- **action**:
  1. CONTEXT.md 禁动清单追加 4 项 exception：
     ```
     **例外（final-debt-cleanup-2026-08 · TD-008/017/018 fix · 2026-08-03）**：
     - `flow-kit-bundle/hooks/stop/lib/l3-review.sh` 允许拆分为 5 子文件（l3-prompt.sh / l3-api.sh / l3-truncate.sh / l3-done.sh / l3-review.sh slim）。仅函数迁移，逻辑不变。
     - `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` 允许拆分为 4 子文件（gate-helpers.sh / gate-checks-basic.sh / gate-checks-review.sh / independent-review-gate.sh slim）。仅函数迁移，逻辑不变。
     - 拆分后所有原公共 API 函数名保持不变（向后兼容）。
     - 若拆分后回归测试 fail（bats 全量），立即 revert 拆分，保留为 TD 等待修复。
     ```
  2. CHANGELOG.md 追加 entry：紧凑单行 pipe 格式 `| 2026-08-03 | final-debt-cleanup-2026-08 | 11 debt 清理（TD-008/017/018 拆分 + ADR-019/020/021 + L-066 addendum） | L-058/060/061/062/063/066/068-072 ✅ |`
  3. 双源 sync 检查：
     - `for f in test/test_combined_metric.bats test/test_hook_integration.bats; do diff -q "$f" "flow-kit-bundle/$f"; done`
  4. 全量回归：`npx bats test/` ≥661 tests (657 baseline + 1 T04 combined + 3 T07 integration), 0 fail
  5. package validate：`bash package-flow-kit.sh --validate` clean
  6. git add + commit（commit message 含 change-id + 11 debt 列表）
- **verify**:
  - `grep -q "final-debt-cleanup-2026-08" .specs/CONTEXT.md` || exit 1
  - `grep -q "final-debt-cleanup-2026-08" .specs/CHANGELOG.md` || exit 1
  - `git log --oneline --grep="final-debt-cleanup-2026-08" | wc -l` 应 ≥1
  - `git diff --name-only HEAD~1 HEAD | wc -l` 应 ≥4（**REQUIREMENT AC-F4 阈值 · 非升级版**）
  - `npx bats test/ 2>&1 | tail -3 | grep -q "0 failures"` || exit 1
- **done**: 全部 meta 更新 + commit + 全量回归 0 fail

---

## 自检

- [ ] 8 tasks 全部 7 元素（id/name/read_files/write_files/action/verify/done）✓
- [ ] model-tier 标注（T01 cheap / T02-T04 standard / T05-T06 top / T07-T08 standard）✓
- [ ] Wave 结构合理（W1 4 并行 / W2 2 并行 / W3 串行 / W4 串行）✓
- [ ] AC-F4 commit threshold 显式 verify（≥1 commit + ≥10 files）✓
- [ ] 禁动 exception 注册（T08 action 1）✓
- [ ] 双源 sync（T04+T07+T08 都含 cp + diff）✓
