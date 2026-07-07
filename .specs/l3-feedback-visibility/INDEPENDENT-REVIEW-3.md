
---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-07 11:44）

> 自动生成于 2026-07-07 11:44。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [],
  "minor": [
    {
      "file": "工件整体",
      "issue": "任务拆解声称覆盖 AC-1/2/3/5/6 + AC-4，但未提供 REQUIREMENT.md 原文进行比对，无法从工件自身确认全量 AC 已覆盖。",
      "why": "作为独立审查员，缺少需求规格，无法验证任务拆解是否完整覆盖所有 Acceptance Criteria。",
      "fix": "建议在工件中显式列出所有 AC 编号及对应任务映射，或附上 REQUIREMENT.md 摘要以供审查。"
    },
    {
      "file": "T04 / T05 verify",
      "issue": "verify 命令 `npx bats ...` 依赖于本地安装的 bats 运行时，未在工件中声明环境前提。",
      "why": "在隔离的审查环境中，若缺少 npx/bats 可能导致 verify 无法执行或误判为失败。",
      "fix": "在任务描述或顶层 README 中注明测试依赖（如 Node.js, bats 版本），或使用 shell 原生断言替代。"
    },
    {
      "file": "T01 verify",
      "issue": "`grep -qE 'pass\\|fail\\|error'` 正则表达式的转义方式在部分 shell 或 grep 版本下可能匹配不到预期的 case 模式。",
      "why": "期望验证文件包含 `pass|fail|error` 字面字符串，但实际 case 模式中竖线是 shell 语法分隔符，文件内容可能为 `pass|fail|error)` 而该正则可能因转义处理不一致导致匹配失败或误匹配。",
      "fix": "改用更精确的 grep 模式，例如 `grep -E 'pass\\|fail\\|error\\)'` 或直接搜索 `case.*pass.*fail.*error` 以匹配 case 语句结构。"
    }
  ],
  "verdict": "pass",
  "summary": "任务拆解清晰，depends_on 依赖无环，write_files 边界明确不越界，各 task 的 verify 基本可执行且可证伪。存在少量 minor 问题：无法确认 AC 全覆盖（缺需求原文）、测试依赖未声明、T01 verify 正则可能不精确。整体设计合理，无 critical 或 major 缺陷。"
}
```

---

## L2 盲审（Claude deepseek-v4-pro[1m] 内部模型 · 2026-07-07）

### 审查范围
- 工件：`.specs/l3-feedback-visibility/TASK.md`
- 参考：`.specs/l3-feedback-visibility/REQUIREMENT.md`、`.specs/l3-feedback-visibility/DESIGN.md`

---

### 🟡 R1 · 验证可机器执行性：T05 verify 管道吞没 bats 退出码

**Symptom（症状）**：T05 verify（TASK.md:259-261）：
```bash
npx bats test/ --filter-tags '' 2>&1 | tail -5
# 确认输出含 "0 failures"
```
管道 `| tail -5` 会吞没 `npx bats` 的退出码，verify 命令**始终返回 0**（`tail` 成功即成功）。实际验证依赖注释中的"人工确认"，违反阶段 3 checklist 中「verify 是否可机器执行（非"人工确认"空话）」的要求。

**Source（源头）**：REQUIREMENT.md 验收准则均要求「验证方式」可机器执行（如 AC-1 的 `grep -qiE ...`、AC-2 的三步 create+check）。T05 作为全量回归验证任务，其 verify 应同样可自动判定 pass/fail。

**Consequence（后果）**：CI/自动化场景中 T05 永远"通过"，即使 bats 有 failures。全量回归失去自动化门禁意义，需人工介入才能发现回归问题。

**Remedy（修补）**：改为直接依赖 bats 退出码：
```bash
# Before
npx bats test/ --filter-tags '' 2>&1 | tail -5
# After
npx bats test/ --filter-tags ''
```
bats 自身在有任何 failure 时返回非零退出码，无需额外 grep。如果确实需要摘要输出，可用 `tee` 保留退出码：
```bash
npx bats test/ --filter-tags '' 2>&1 | tee /dev/stderr | tail -5
# 依赖管道前段 bats 的 PIPESTATUS，或改用：
npx bats test/ --filter-tags '' 2>&1; exit_code=$?; [ "$exit_code" -eq 0 ] || exit "$exit_code"
```

---

### 🟡 R2 · 安全 NFR 覆盖缺口：T02 移除 2>/dev/null 后 stderr 泄露未验证

**Symptom（症状）**：T02 action（TASK.md:83-85）移除 `l3_review_with_timeout ... 2>/dev/null` 中的 `2>/dev/null`，理由为"安全过滤由 _l3_format_result 的白名单字段保证"。但 REQUIREMENT.md 安全 NFR（第 107 行）明确约束"不泄露以下内容到 agent 可见上下文：API key、内部 endpoint、文件系统绝对路径、API 响应原文（raw response body）"。T02 的 `_l3_format_result()` 仅保护 stdout 上的 `L3_RESULT:` 行，移除 `2>/dev/null` 后 `l3_review_run()` 内部的 `>&2` 日志（含 curl 连接错误——可能泄露 endpoint URL——以及 jq 解析错误——可能泄露部分 API 响应原文）将直接进入 agent 可见的 stderr 通道。T04 测试场景中**没有任何用例验证 stderr 不泄露敏感字段**。

**Source（源头）**：REQUIREMENT.md「非功能性需求 - 安全」第 107 行。DESIGN.md D5 决策仅讨论了 `L3_RESULT:` 行白名单过滤，未评估 stderr 通道的泄露风险。

**Consequence（后果）**：若 L3 API 调用失败（网络抖动、endpoint 迁移），curl 的 stderr 错误信息（通常包含完整 URL）将暴露在 agent 上下文。Agent 可能照抄该 URL 到代码或文档中，造成内部 endpoint 泄露。概率中等，但影响符合安全 NFR 的「不泄露」红线。

**Remedy（修补）**：二选一：
1. **保留 2>/dev/null，将内部日志单独重定向**：`l3_review_with_timeout ... 2>/dev/null || true` 保持不变，但在 `l3_review_run()` 内部将诊断日志写入专用日志文件（如 `.specs/<change_id>/l3-debug.log`）而非 stderr。
2. **保留移除 2>/dev/null，但在 T04 增加 stderr 安全测试**：验证当 L3 调用失败时，stderr 输出不含 `https?://`（endpoint URL 模式）和 `"verdict"`（响应原文 JSON 片段）。同时在 REQUIREMENT.md 安全 NFR 中增加 stderr 约束。

推荐方案 1——更安全且改动更小。方案 2 的 stderr 过滤在 Bash 层难以做到 100% 可靠。

---

### 🟢 R3 · T02 verify 重复断言

**Symptom（症状）**：T02 verify（TASK.md:98-104）中第 99 行和第 103 行均为：
```bash
grep -q '_l3_format_result' flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
```
完全相同的 grep 命令出现两次。疑似复制粘贴残留。

**Source（源头）**：阶段 3 checklist「verify 可验证性」——重复断言不引入错误但浪费执行周期，且可能掩盖某一行的本意（例如原应检查不同的条件）。

**Consequence（后果）**：无功能影响。但若未来维护者修改其中一行而忘记另一行，可能产生不一致的验证逻辑。

**Remedy（修补）**：删除重复行（保留第 99 行，删除第 103 行）：
```bash
# 删除 TASK.md 第 103 行（重复的 grep -q '_l3_format_result' ...）
```

---

### 🟢 R4 · T04 AC-1 正则验证用例 underspecified

**Symptom（症状）**：T04 action 场景 5（TASK.md:196-198）：
```
5. F1 PreToolUse stdout 测试：
   - 模拟 L3 完成后 stdout 含 L3_RESULT 行
   - L3_RESULT 行格式匹配 AC-1 grep 验证正则
```
仅说"匹配 AC-1 grep 验证正则"，但未写出具体的 bats 断言。AC-1 的验证正则（REQUIREMENT.md:22）为：
```
grep -qiE '^l3_result: verdict=(pass|fail|timeout|error) summary=.+ report=.+'
```
该正则有三个潜在问题：(a) 大小写不敏感（`-i`），`L3_RESULT` 与 `l3_result` 均匹配——AC-1 规范要求 `L3_RESULT` 大写，但 grep 会放过小写；(b) `summary=.+` 允许 summary 为纯空格（`.` 匹配空格）；(c) `report=.+` 不要求 `.md` 后缀。测试实现者可能照抄该宽松正则，导致 AC-1 的实际约束被虚化。

**Source（源头）**：AC-1 自身验证正则过于宽松，T04 未补充更严格的 bats 断言（如精确匹配 verdict 值域、summary 非空、report 以 `.md` 结尾且为相对路径）。

**Consequence（后果）**：T04 测试可能"通过"但对 AC-1 实际无约束力。例如输出 `l3_result: verdict=pass summary= report=`（空 summary 和 report）也会通过 AC-1 正则，但不符合 AC-1 Given/When/Then 描述的语义。

**Remedy（修补）**：在 T04 action 场景 5 中明确断言规范：
```
- L3_RESULT 行格式：（以下正则精确匹配，非 -i）
  echo "$output" | grep -qE '^L3_RESULT: verdict=(pass|fail|timeout|error) summary=.+ report=.+[.]md$'
- summary 字段非空（至少 1 个非空白字符）
- report 为相对路径（不以 / 开头），以 .md 结尾
- verdict 值全小写（与 done-validation.sh 值域一致）
```

---

### 🟢 R5 · T04 缺少 AC-5 transition exit code 验证

**Symptom（症状）**：AC-5（REQUIREMENT.md:66-68）验证方式第 2 条明确要求「检查 transition exit code = 0」。T04 测试场景覆盖了超时降级的 L3_RESULT 行输出（隐含在场景 2-3 的降级测试中），但**没有任何测试用例显式检查 transition/hook 退出码**。T02 实现中保留了 `|| true`（TASK.md:85），理论上确保 exit code 0，但没有测试证明这一点。

**Source（源头）**：AC-5 第 67 行「检查 transition exit code = 0」。

**Consequence（后果）**：若未来的代码变更意外移除了 `|| true` 或引入了非零退出码，不会有测试捕获。可能导致超时场景下 transition 被阻塞——这正是 AC-5 明确要求避免的。

**Remedy（修补）**：在 T04 action 场景 3（超时降级测试）或场景 5（PreToolUse stdout 测试）中增加：
```
超时场景：模拟 l3_review_with_timeout 超时 → 验证
  1. L3_RESULT: verdict=timeout 输出
  2. 函数/脚本退出码 = 0（transition 不被阻塞）  ← 新增
```

---

### 🟢 R6 · T01 verify: `verdict.*error` grep 过于宽泛

**Symptom（症状）**：T01 verify 第 3 条（TASK.md:63）：
```bash
grep -q 'verdict.*error' flow-kit-bundle/hooks/stop/lib/l3-review.sh
```
该模式可匹配多种非目标字符串，例如：
- 注释：`# verdict explanation: error handling`
- 变量名：`l3_verdict_error_count=0`
- 字符串拼接：`echo "verdict=${verdict}_error"`

均不表示第四层故障降级逻辑已正确实现。

**Source（源头）**：阶段 3 checklist「verify 可验证性」——verify 应可证伪（false 意味着实现不完整）。过度宽泛的 grep 提供虚假安全感。

**Consequence（后果）**：若实现者仅添加了 `# verdict error handling` 注释而未真正实现第四层降级，verify 仍会通过。AC-6 畸变降级逻辑可能实际上缺失。

**Remedy（修补）**：缩小匹配范围，精确匹配第四层降级的核心逻辑：
```bash
# Before
grep -q 'verdict.*error' flow-kit-bundle/hooks/stop/lib/l3-review.sh
# After — 匹配降级赋值行
grep -qE 'l3_verdict="error"|l3_verdict=error' flow-kit-bundle/hooks/stop/lib/l3-review.sh
```
或同时验证降级后的固定 summary 文本：
```bash
grep -q 'L3 结果解析失败（verdict 不可用）' flow-kit-bundle/hooks/stop/lib/l3-review.sh
```

---

### 覆盖完整性总览

| AC | 覆盖任务 | 状态 |
|---|---|---|
| AC-1 (PreToolUse 反馈可见) | T01 (F3 提取) + T02 (F1 输出) | 覆盖 |
| AC-2 (SessionStart 注入恢复) | T03 (F2 检测+输出) | 覆盖 |
| AC-3 (两条路径格式一致) | T01 (_l3_format_result) + T02/T03 (共用) | 覆盖 |
| AC-4 (全模式兼容) | T04 场景 7 + T02 gate_config 逻辑 | 覆盖 |
| AC-5 (超时降级不阻塞) | T01 (超时 done 扩展) + T04 降级测试 | 覆盖（exit code 验证缺失见 R5） |
| AC-6 (畸变降级反馈) | T01 (第四层降级) + T04 场景 8 | 覆盖 |

### 依赖图验证

```
T01 ──→ T02[P]
   │
   └──→ T03[P]
          │
          ▼
         T04 ──→ T05
```
- 无环 ✅
- 可并行部分已标 `[P]` ✅
- 跨 wave 顺序正确（Wave 1→2→3→4）✅

### 禁动清单验证

DESIGN §0.5.1 禁动清单：
- `29-independent-review.sh` — 未触碰 ✅
- `correction-file.sh` — 未触碰 ✅
- `flow-kit-artifacts.sh` — 未触碰 ✅
- `package-flow-kit.sh` — 未触碰 ✅

所有 write_files 均不在禁动清单中 ✅。

### 任务粒度评估

| 任务 | 预估变更行数 | ≤200? |
|---|---|---|
| T01 | ~50 (新增 summary 提取 + 降级 + 格式化 + done 扩展) | ✅ |
| T02 | ~20 (移除 2>/dev/null + 新增 _l3_format_result 调用) | ✅ |
| T03 | ~40 (替换检测逻辑 + source + banner 修改) | ✅ |
| T04 | ~150 (新建 bats 文件，8 个场景) | ✅ |
| T05 | 0 (仅验证) | ✅ |

---

**Verdict**: pass

**总评**：任务拆解结构清晰，依赖无环，波次划分合理，所有 AC 均已映射到对应 task，禁动清单严格遵守，write_files 边界明确。发现 2 个 🟡 Major（T05 verify 不可机器执行 + stderr 安全泄露未验证）和 4 个 🟢 Minor（重复断言/underspecified 测试/缺失 exit code 测试/宽泛 grep），均在可修复范围内。建议在 4-dev 实施前修复 R1（T05 verify）和至少评估 R2（stderr 安全）的风险接受度。
