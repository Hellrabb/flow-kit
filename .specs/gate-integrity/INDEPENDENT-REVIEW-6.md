# 独立审查 · 阶段 6

> session: gate-integrity-L2-6

## L2 盲审

### 审查方法与独立性声明

本审查完全基于指定工件独立进行：
- 逐 AC 对照 REQUIREMENT.md 的 6 条 AC，交叉验证 DESIGN.md 的 12 项决策（D1-D10），逐文件阅读 16 个 diff 文件的全部内容
- 7 个回归 demo 的 check.sh 全部审查
- 手工验证 23 test_gate_integrity.bats + 5 test_check_gate_sync.bats + 26 test_gate_config_presets.bats 的断言覆盖和逻辑合理性
- 全量跑 `npx bats test/` 和 `npx bats flow-kit-bundle/test/` 确认回归状态

主 agent 的 REVIEW.md 结论为 PASS，0 Critical / 0 Major / 1 Minor。我的独立审查**得出不同结论**：主 agent 漏判了 1 项 Major 和 1 项 Minor，详细见下方 R1、R2。没有找到 Critical。

---

### 🔴 Critical

无。

---

### 🟡 R1 · 主 agent 漏判：29.sh L3 verdict 提取未校验合法值域，未解析 verdict 时可导致 fail_count 失实 + 门禁语义退化

**Symptom（症状）**：文件 `flow-kit-bundle/hooks/stop/29-independent-review.sh:193-198`

```bash
extracted=$(echo "$content" | sed -n '/```json/,/```/p' | sed '1d;$d' 2>/dev/null || echo "")
[ -n "$extracted" ] || extracted="$content"
verdict=$(echo "$extracted" | jq -r '.verdict // "unknown"' 2>/dev/null || echo "unknown")
# ...
fc_l3=0; [ "$verdict" = "fail" ] && fc_l3=1
```

问题在于 verdict 值域只校验了 `"fail"` 分支，未校验是否为合法枚举值 `{"pass", "fail"}`。当 jq 因为 JSON 格式问题解析失败（如 model 未严格遵循 JSON 指令、或 sed 提取到残缺 JSON），verdict 取默认值 `"unknown"`：

- `[ "$verdict" = "fail" ]` 对 `"unknown"` 为 false → `fc_l3=0`
- 握手文件以 `status:"done", fail_count:0` 写入
- Gate 4 幂等检查下次 Stop hook 看到 `status="done"` → L3 不再重跑该阶段
- `.done` 内的 `L3_verdict` 可以写 `"unknown"`，与握手的 `verdict:"unknown"` 一致 → T3 一致性检查通过

**Source（源头）**：DESIGN 未定义 verdict 值域合法性校验。29.sh 的 jq `// "unknown"` 默认值 + 握手写回 made it possible for an unparseable verdict to be treated as "done" with zero fail count。

**Consequence（后果）**：L3 模型因任意原因（prompt 格式问题、模型非预期输出、网络截断）产生无法解析的输出时，系统不会触发 `max_failures_before_bypass` 重试或告警，L3 门禁在该阶段永久静默退化——握手表征"已完成"，但实际上没有收到合法 pass/fail 判定。

**Remedy（修补）**：
在写握手文件之前，加 verdict 值域检查。伪代码：

```bash
# AFTER verdict extraction
case "$verdict" in
  pass|fail) ;;   # 合法，继续
  *)
    module_output "warning" "IR" "L3 独立 review 无法解析 verdict（got: ${verdict}），记为失败"
    write_failed_state "$state_file" "$phase"
    exit 0
    ;;
esac
```

这样：
- `verdict ∉ {pass, fail}` 时视为 L3 调用失败（`write_failed_state` 递增 fail_count，不写 status="done"）
- Gate 4 幂等检查看到 status != "done"，下次 Stop hook 会重试
- `max_failures_before_bypass` 正确激活

---

### 🟢 R2 · 主 agent 漏判：`.goal-snapshot.json` 的快照写入时机与后续 `/flow gate-config` 脱节

**Symptom（症状）**：
- `SKILL.md:128-131` 和 `SKILL.md:169-172` 在 `--pipeline` 和 `--pipeline --gate-config` 命令中写快照
- 但若 pipeline 创建后用户/agent 通过 `/flow gate-config`（不带 `--pipeline`）调整 gate_config，快照不会更新
- `fk_check_gate_config_tamper` 会用旧快照对比新 gate_config → 报篡改

**Source（源头）**：DESIGN D8 决策定义了快照机制但未定义"快照刷新"通路。SKILL.md 的快照写入仅在 goal 创建时执行一次。

**Consequence（后果）**：合法 gate_config 调整被误报为篡改。影响程度：低——deny 消息（gate.sh:143-146）已提示用户可"手动更新 .goal-snapshot.json 并 commit"，且这种调整在 pipeline 运行中不常见。但用户体验差，且可能阻塞合法流程。

**Remedy（修补）**：
1. 短期：在 `/flow gate-config` 命令处理逻辑中，更新 `.flow-active.goal.gate_config` 后同步写入 `.goal-snapshot.json`
2. 或：在 `fk_check_gate_config_tamper` 前加一层 check——若快照的 `created_at` 时间与 `.flow-active` 的更新时间差超过阈值（如 24h），提示而非 deny（兼容人工调整）

---

### 🟢 R3 · 与主 agent 一致的发现：SKILL.md snapshot `created_at: now` 使用 Unix epoch 而非 ISO 格式

**Symptom（症状）**：`SKILL.md:130` 和 `SKILL.md:171` 使用 `created_at: now`（Unix epoch 秒数），与 G3 ADR 中 `.goal-snapshot.json` 的契约预期（ISO 8601）不一致。

**Source（源头）**：jq 的 `now` 函数返回 Unix 时间戳（浮点秒），而项目其他时间字段（如 `.flow-active.independent-review` 的 `written_at`）使用 `date -Iseconds`（ISO 8601）。

**Consequence（后果）**：一致性影响仅视觉/调试层面——`fk_check_gate_config_tamper` 不校验 `created_at`，无功能影响。

**Remedy（修补）**：改为 `created_at: (now | strftime("%Y-%m-%dT%H:%M:%S%z"))`，与其他时间字段格式一致。优先级低，可随下次快照修改一并处理。

→ 此发现与主 agent REVIEW.md 的 Minor 项完全一致。我独立得出该结论（基于 G3 ADR 契约交叉比对），非抄自主 agent。

---

### AC 逐条验证总结（独立于主 agent）

| AC | 覆盖状态 | 独立验证方法 | 与主 agent 的差异 |
|---|---|---|---|
| AC-1 | PASS | fk_validate_done_marker 全 6 类威胁逐一验证 T1-T4 + 7 demo UAT 全绿 | 一致。但发现主 agent 未提 R1（verdict 值域） |
| AC-2 | PASS | pipeline-gates.md 扩至 7 gate key + skipped-subprocess demo | 一致 |
| AC-3 | PASS | 5 站点 grep 验证 + bats 4 测试全绿 | 一致 |
| AC-4 | PASS | 26 test_gate_config_presets 全绿 + `all` 预设含 3/5/7 + `full` 不含 | 一致 |
| AC-5 | PASS | 216 tests / 204 pass / 12 预存失败；bats flow-kit-bundle/test/ 增量全部通过 | 一致 |
| AC-6 | PASS | CONFIG_FILE 回退 + sha256sum + >> 追加 + fail_count 随 verdict | 一致。R1 是对 verdict 提取健壮性的补充发现 |

---

### 主 agent REVIEW.md 漏判 / 误判记录

| 项 | 严重度 | 主 agent 判定 | 本审查判定 | 说明 |
|---|---|---|---|---|
| R1 | 🟡 Major | 未发现 | 🟡 Major: 漏判 | 29.sh verdict 值域未校验，详见 R1 四要素 |
| R2 | 🟢 Minor | 未发现 | 🟢 Minor: 漏判 | .goal-snapshot.json 更新脱节，详见 R2 四要素 |
| SKILL.md created_at | 🟢 Minor | 已发现 | 🟢 Minor: 一致 | 独立得出相同结论 |

---

**Verdict**: pass

注：R1（Major）虽不构成 Critical，但 L3 门禁在模型输出不可解析时会静默退化，建议在 merge 前修复或明确记录为 accepted risk。
