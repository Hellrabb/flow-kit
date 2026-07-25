# INDEPENDENT-REVIEW-6: 阶段 6 代码审查（独立盲审）

- **Change ID**: l3-review-timeout-token
- **审查日期**: 2026-07-25
- **工件**: `git diff HEAD` + `.specs/l3-review-timeout-token/REVIEW.md`（参考 REQUIREMENT.md / DESIGN.md / TASK.md）

---

## L2 盲审

### 审查范围

- `flow-kit-bundle/hooks/stop/lib/l3-review.sh` — `_l3_call_api()` 三 env var 可配化（+50/-6 行）
- `test/test_l3_review.bats` — 删旧硬编码断言 + 新增 fallback 行为测试（+19/-46 行）
- `test/test_l3_review_params.bats` — 新增 25 个 stub curl 双路径测试（AC-1~AC-7）
- `flow-kit-bundle/test/test_l3_review.bats` / `test_l3_review_params.bats` — 双源同步（diff -q 一致，已验证）

---

### 审查结论

**Verdict: pass**（无 🔴 Critical 阻塞项）

本次代码审查发现 1 项 🟡 Major 缺口（AC-6 测试覆盖略低于 spec 要求），2 项 🟢 Minor 观察。所有发现均为可补项，不构成阻塞。代码实现质量良好，核心逻辑正确，安全性无问题。

---

### 发现明细

---

### 🟡 R1 · AC-6 测试覆盖缺口：spec 要求 12 条双路径失败安全测试，实际仅 10 条

**Symptom**: `test/test_l3_review_params.bats:161-249` — AC-6 非法值 fail-safe 测试共 10 个 @test 块，缺少 2 个双路径覆盖：
- `FLOW_KIT_L3_MAX_TOKENS=""` path2（path1 有，行 170-177）
- `FLOW_KIT_L3_TIMEOUT=xyz` path2（path1 有，行 179-186）

**Source**: `REQUIREMENT.md` AC-6 明确要求 "每条双路径各测一次"，共 6 个非法值类别（MAX_TOKENS=abc/空、TIMEOUT=xyz/空、THINKING=yes/空），每类 path1 + path2 = 12 条。当前：10 条。

**Consequence**: 低实际风险。fail-safe 解析逻辑（env var 校验 + 回退默认）在 `_l3_call_api()` 函数顶部执行，**在 Path 1/Path 2 分支之前**（l3-review.sh:350-374），两路径共享同一 `$max_tokens`/`$timeout`/`$thinking` 变量。缺失的 2 条测试覆盖的 fail-safe 行为（空 MAX_TOKENS → 回退 32000、非数字 TIMEOUT → 回退 300）已在其配对路径（path1 × MAX_TOKENS=空、path1 × TIMEOUT=xyz）及同类非法值（path2 × MAX_TOKENS=abc、path2 × TIMEOUT=空）中被充分验证。**spec 合规形式上不完整，但功能逻辑不缺**。

**Remedy**: 补 2 条测试（约 20 行）：
```bats
@test "AC-6 path2: FLOW_KIT_L3_MAX_TOKENS=空 → fallback 32000 + warning" {
  FLOW_KIT_L3_MAX_TOKENS="" \
  ANTHROPIC_AUTH_TOKEN="" ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  grep -qE 'max_tokens": ?32000' "$CAPFILE"
  grep -q "FLOW_KIT_L3_MAX_TOKENS='' 非法" "$STDERRFILE"
}

@test "AC-6 path2: FLOW_KIT_L3_TIMEOUT=xyz → fallback 300 + warning" {
  FLOW_KIT_L3_TIMEOUT=xyz \
  ANTHROPIC_AUTH_TOKEN="" ANTHROPIC_API_KEY="fake-key" \
  _call_and_capture
  grep -q -- '--max-time 300' "$CAPFILE"
  grep -q "FLOW_KIT_L3_TIMEOUT='xyz' 非法" "$STDERRFILE"
}
```

---

### 🟢 R2 · 测试辅助函数 `_call_and_capture` 通过 source 引入全量 l3-review.sh 依赖

**Symptom**: `test/test_l3_review_params.bats:34-40` — `_call_and_capture()` 用 `source "$L3_LIB" 2>/dev/null` 加载整个 l3-review.sh 库，包括 `set -euo pipefail`、`source l2-detect.sh`、以及 `smart_truncate`/`_l3_build_prompt`/`_l3_parse_result` 等 13 个未使用函数。

**Source**: 测试仅需测试 `_l3_call_api()`，但 sourced 了整个文件。`2>/dev/null` 掩盖了 source 阶段的潜在错误。

**Consequence**: 低。当前测试通过说明无副作用冲突。若未来 l3-review.sh 顶部增加 side-effect-heavy 初始化（如网络调用、文件写入），测试可能在 source 阶段静默失败（被 `2>/dev/null` 吞掉）。`set -euo pipefail` 与 `2>/dev/null` 的组合可能掩盖 source 阶段的非零退出。

**Remedy**: 非阻塞建议。可考虑将 `_l3_call_api` 抽为独立可 source 的子文件（如 v2 的 TD-008 拆分），或至少移除 source 行的 `2>/dev/null` 以便 source 错误可见。

---

### 🟢 R3 · REVIEW.md 声称 AC-6 全覆盖，未注明 2 条测试缺口

**Symptom**: `REVIEW.md:30` — "AC-6 | Fail-safe 6 非法值回退 | T02 + 25 测试（含 R1 补 4 测试） | ✅" 声称全覆盖，未提 R1 发现的 2 条缺失。

**Source**: REVIEW.md 的 AC 覆盖表以 ✅ 标记 AC-6，但 spec 要求 12 条测试、实际 10 条。

**Consequence**: 审查文件准确性问题。主 agent 自评时未发现此偏差，可能误导后续读者认为所有 spec 要求已严格满足。

**Remedy**: 补 2 条测试后绿 ✅，或在 REVIEW.md 已知限制段注明覆盖偏差为低风险（因 shared logic before branching）。

---

### 正向确认

以下方面审查通过，无发现问题：

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 安全性：env var 注入 | ✅ PASS | 三 env var 均经类型校验（`^[0-9]+$` 正则 / `case enabled\|disabled`），仅通过 jq `--arg`/`--argjson` 安全传递到请求体，无直接字符串插值 |
| 安全性：jq 注入 | ✅ PASS | `jq -n --arg` 构造 JSON，prompt text 通过 `--arg` 传递（jq 自动转义），thinking 字段用固定字符串 `disabled` 不用变量，无 JSON 注入路径 |
| 正确性：`${VAR+x}` 检测 | ✅ PASS | 正确区分 "env var 未设" 与 "env var 设为空"，避免空值静默触发 fail-safe 警告（DESIGN 意图：仅已设但非法才警告） |
| 正确性：req_body 共享 | ✅ PASS | `req_body` 在路径分支前构造一次，两路径共用（DRY），消除了旧代码中两处各自内联 jq 构造的重复 |
| 可观测性：AC-7 | ✅ PASS | stderr 输出 `[l3-review] using max_tokens=X timeout=Y thinking=Z` 记录**解析后的实际值**（非原始 env var），正确反映 fail-safe 回退决策 |
| 测试隔离：stub curl | ✅ PASS | `export -f curl` 使 stub 在 subshell 中可用；CAPFILE 用绝对路径确保父/子 shell 共享同一捕获文件。**仅 stub curl 而非 `_l3_call_api`**，保留了请求体构造逻辑被测（遵守 REQUIREMENT Mock 策略声明） |
| 双源同步 | ✅ PASS | `diff -q test/test_l3_review.bats flow-kit-bundle/test/test_l3_review.bats` 一致；`test_l3_review_params.bats` 同理 |
| 硬编码清除 | ✅ PASS | `max_tokens:8000`（两处）、`--max-time 90`（两处）全部删除，替换为变量。`grep -q 'max_tokens:8000' l3-review.sh` 无匹配 |
| jq -c compact | ✅ PASS | `jq -nc` 输出单行 JSON，避免多行 `-d` 参数在 bash 中的空白问题（d7a3f88 经验） |
| 两路径一致性 | ✅ PASS | Path 1（aliyun 代理）和 Path 2（Anthropic 直连）均使用 `$timeout` + `$req_body`，同步修改 |

---

### 代码质量 6 维独立评估

与主 agent REVIEW.md 自评对比：

| 维度 | 主 agent 自评 | L2 独立评估 | 差异 |
|------|-------------|------------|------|
| R1 认知过载 | 🟢 | 🟢 | 一致。`_l3_call_api` 从 ~30 行增至 ~85 行，env var 解析 + req_body 构造约 40 行新增，仍在可接受范围。Fail-safe 用 case/switch 简单逻辑 |
| R2 变更传播 | 🟢 | 🟢 | 一致。仅 1 文件，签名不变，2 处调用点兼容 |
| R3 知识重复 | 🟢 | 🟢 | 一致。req_body 提取到公共变量，thinking 分支用 if/else 而非两处各自 jq |
| R4 偶然复杂 | 🟢 | 🟢 | 一致。thinking 条件分支是必要的（D3 决策），`jq -c` 是合理优化 |
| R5 依赖混乱 | 🟢 | 🟢 | 一致。2 级 env var，不引中间配置 |
| R6 领域扭曲 | 🟢 | 🟢 | 一致。变量名 domain-appropriate |

**L2 独立评估与主 agent 自评在 6 维上完全一致，无漏判或误判。**

---

### 关于 REVIEW.md 的独立考量

主 agent REVIEW.md 判定本 change 为 pass，L2 独立审查确认此结论有效。REVIEW.md 中的 AC 覆盖表（10/10 ✅）**形式上过于乐观**——AC-6 的 spec 要求 12 条双路径测试但实现仅 10 条。此偏差为形式合规问题而非功能缺陷（fail-safe 逻辑在路径分支前共享，见 R1 分析），不影响 pass 判定，但应在 REVIEW.md 中注明。

其他 REVIEW.md 声明经过独立核实：
- "AC-8 全量 bats 0 fail" — 未在本审查中重跑 `make test`（属阶段 5 已验证），不重复验证
- "AC-9 端到端冒烟（手动）" — 手动验证，不进自动化回归，合理
- "AC-10 静默错判验证" — T01 探针已完成，fallback 行为测试（test_l3_review.bats L36-43）记录了静默错判行为但未修 fallback（Out of Scope），处置合理

---

## L2 审查元信息

- **审查者**: 独立盲审员（L2 code-reviewer agent）
- **审查依据**: git diff HEAD + REQUIREMENT.md + DESIGN.md + TASK.md + REVIEW.md
- **审查耗时**: 一次全量审查（含代码阅读 + 交叉验证 + 测试分析）
- **发现统计**: 🔴 0 | 🟡 1 | 🟢 2
- **Verdict**: pass

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-25 03:52）

> 自动生成于 2026-07-25 03:52。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "test_l3_review_params.bats",
      "issue": "AC-6 fail-safe 非法值回退测试未覆盖 path2（FLOW_KIT_L3_MAX_TOKENS=空字符串 和 FLOW_KIT_L3_TIMEOUT=xyz）",
      "why": "REVIEW 承认 path2 缺失，但 fail-safe 逻辑在路径分支前共享，实际风险低；然而缺少正式测试，违反 spec 全覆盖要求。",
      "fix": "补充 path2 非法值测试用例：设 FLOW_KIT_L3_MAX_TOKENS=''（空字符串）和 FLOW_KIT_L3_TIMEOUT='xyz'，验证 stderr 警告且实际使用默认值 32000/300。"
    },
    {
      "file": "test_l3_review_params.bats",
      "issue": "AC-10 静默错判探针未实现",
      "why": "REVIEW 提及 T01 探针但工件中无对应测试代码；当前测试仅记录 fallback 行为，未验证改进或逃生舱（disabled thinking）有效性。",
      "fix": "补充探针测试：模拟 thinking block 吃满 token 无 text block 的响应，断言 fallback 链不会静默输出思考内容当 verdict（或至少记录日志），并验证 disabled thinking 模式下直接返回 text block。"
    }
  ],
  "minor": [
    {
      "file": "test_l3_review_params.bats",
      "issue": "FLOW_KIT_L3_THINKING 非法值回退未测试",
      "why": "代码处理了非法值回退并输出 stderr 警告，但测试仅覆盖 enabled/disabled，未覆盖未知字符串（如 invalid123）",
      "fix": "补充测试：设 FLOW_KIT_L3_THINKING='invalid'，验证 stderr 警告且请求体不含 thinking 字段（即回退 enabled 默认）"
    },
    {
      "file": "工件整体",
      "issue": "AC-8（全量 bats 0 fail）和 AC-9（端到端冒烟）未附验证证据",
      "why": "REVIEW 声明 make test 606 ok 及冒烟 rc=1，但工件中无日志或结果文件佐证，无法独立确认。",
      "fix": "包含测试运行日志或冒烟验证记录（如截图、stderr 输出、退出码记录）"
    }
  ],
  "verdict": "pass",
  "summary": "代码实现符合 AC-1~AC-7，env var 可配化（max_tokens/timeout/thinking）功能正确，请求体用 jq 构造安全，测试 stub curl 双路径设计合理。存在两处 major 测试覆盖缺口（AC-6 path2 非法值回退、AC-10 探针）和两处 minor 补充问题（thinking 非法值测试缺失、验证证据未附）。无 critical 安全/功能阻塞缺陷，整体质量合格。"
}
```

L3_artifact_hash: 19c9cd6371923b868f6e24c0102f38b21a32d3d6ebed5fb0ea765820114c10c8
