# 独立审查 · 阶段 5

## L2 盲审

### 🔴 R1 · 性能轮缺失：5 轮金字塔缺少"性能"且无跳过理由
**Symptom**: `TEST.md` 的 5 轮结构为：功能测试（bats-core）→ 回归安全 → 安全 → 兼容性 → 可观测性。阶段 5 固化指令要求 5 轮金字塔为"功能/性能/安全/兼容/可观测"。TEST.md 用"回归安全"替代了"性能"，且未对跳过性能轮做任何说明。
**Source**: `REQUIREMENT.md` 非功能性需求明确要求"性能: hook 执行延迟 < 10ms（jq 更新 ~200 字节 JSON），不可被用户感知"。DESIGN.md D7 也量化了两 hook 串行延迟"增加约 < 10ms"。这是一个声明的 NFR，但在 TEST.md 中零覆盖、零理由。
**Consequence**: 声明的性能 NFR（< 10ms）从未被验证。若未来 checkpoint-lib.sh 引入慢路径（如额外的 jq 操作、文件 I/O 阻塞），10ms 阈值可能被突破而无人察觉。
**Remedy**: 二选一：(a) 在轮 2 位置新增性能轮，至少包含一条测试：测量 hook 端到端执行时间（`time bash auto-checkpoint.sh < input.json`）并断言 < 50ms（保守阈值，留足安全裕度）；或 (b) 明确标记"跳过硬理由"：jq 原子写入 ~200 字节 JSON 在典型硬件上确定性 < 5ms，无需专门性能测试，回归安全轮的全量 bats 通过已隐含证明无性能退化。

### 🟡 R2 · AC-7 覆盖不完整：缺少恢复方式说明的验证
**Symptom**: `TEST.md` 测试矩阵中 AC-7 的行内容为"自动机制说明存在 + 三字段含义"。但 AC-7 的 Then 子句明确要求三项：(a) PreToolUse hook 自动机制，(b) interrupt 三字段含义，(c) **如何读取 interrupt 恢复**（`/flow` 无参数展示 / resume 自动注入）。
**Source**: `REQUIREMENT.md` AC-7: "文档说明：(a) ... (b) ... (c) 如何读取 interrupt 恢复（`/flow` 无参数展示 / resume 自动注入）"。
**Consequence**: 即便 SKILL.md 缺少恢复操作说明，当前测试矩阵也不会捕获到这个缺口。用户可能知道 interrupt 被写入了，但不知道如何用它恢复。
**Remedy**: AC-7 测试行追加第三个断言项："恢复方式说明存在"，grep 应额外匹配 `/flow` 或 `resume` 关键词。或新增一条独立测试用例专门验证恢复说明。

### 🟡 R3 · AC-6 测试描述粒度过粗，无法确认覆盖了 AC 验证方法
**Symptom**: `TEST.md` 中 AC-6 的测试用例描述为"interrupt contains all three fields for resume"，仅一行。AC-6 的验证方式明确要求三步：(a) 预设 interrupt 值到 `.flow-active`，(b) 调用 `flow-kit-resume.sh` 的 resume banner 生成函数，(c) 断言其 stdout 包含三个字段的**值**（不仅仅是字段存在，而是字段值如 `"src/hooks/checkpoint.sh"` 被输出）。
**Source**: `REQUIREMENT.md` AC-6: "验证方式: `bats test` —— (a) 预设 interrupt 值到 `.flow-active`，(b) 调用 `flow-kit-resume.sh` 的 resume banner 生成函数，(c) 断言其 stdout 包含 `${active_file}` 和 `${last_action}` 和 `${checkpoint_at}` 三个字段的值"。
**Consequence**: 若实际测试仅检查 `.flow-active.interrupt` 字段存在（而非 banner 输出的字段值），则 AC-6 未真正验证——resume banner 可能静默丢弃 checkpoint 数据而测试放行。
**Remedy**: 细化 AC-6 测试用例描述，明确写出测试步骤：(a) preset interrupt → (b) invoke resume banner function → (c) assert banner stdout contains field values。或在测试矩阵中拆分 AC-6 为两个子用例："checkpoint 三字段写入验证" + "resume banner 输出验证"。

### 🟢 R4 · 容量 NFR 无对应测试用例
**Symptom**: `REQUIREMENT.md` 非功能性需求声明容量约束：`active_file` 最长 4096 字符、`last_action` 截断至 200 字符、interrupt JSON 总大小 < 1KB。TEST.md 测试矩阵中无任何一行覆盖这些容量边界。
**Source**: `REQUIREMENT.md` 非功能性需求 § 容量。
**Consequence**: 边界情况（超长路径名 > 4096、超长 action > 200）的行为未经验证。若 checkpoint-lib.sh 的截断逻辑存在 off-by-one 或未截断 bug，生产环境可能写入畸形 JSON 导致后续 jq 解析失败。
**Remedy**: 在功能轮或兼容轮中追加 1-2 条边界测试：超长路径名（> 4096）→ 断言截断或拒绝；超长 action（> 200）→ 断言截断至 200 字符。

### 🟢 R5 · UAT-1 路径引用与 AC-8 不一致
**Symptom**: UAT-1 的 bash 命令引用 `.claude/settings.local.json`，而 AC-8 和 `install_hooks.sh` 的实际写入目标是 `.claude/settings.json`。
**Source**: `TEST.md` UAT-1 命令: `jq '.hooks.PreToolUse[] | ...' .claude/settings.local.json` vs `REQUIREMENT.md` AC-8: "检查 `.claude/settings.json`"。
**Consequence**: 若 reviewer 严格按 UAT-1 操作，读取 `settings.local.json` 可能为空或不存在，导致误判安装失败。
**Remedy**: UAT-1 中 `settings.local.json` 改为 `settings.json`，与 AC-8 和实际安装脚本保持一致。

---

**Verdict**: fail

理由：🔴 R1（性能轮缺失且无跳过理由）是阶段 5 固化指令的硬性要求——5 轮金字塔的每轮必须填写或声明跳过理由。TEST.md 的 AC 覆盖（9/9）、回归安全（454/0/0）、fail-open 防护和兼容性验证质量均高，但性能轮缺口阻止直接 pass。建议按 R1 Remedy 选项 (b) 补一行跳过硬理由即可通过。
