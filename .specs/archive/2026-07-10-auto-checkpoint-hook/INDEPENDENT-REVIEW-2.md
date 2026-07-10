# 独立审查 · 阶段 2

## L2 盲审

### 🔴 R1 · PreToolUse 目录命名与既有架构冲突：`hooks/pre-tool/` 应改为 `hooks/pre-tool-use/`

**Symptom（症状）**：DESIGN.md 全文（§ 0.5.1、§ 0.5.2、§ 0.5.3、§ 2 数据流图、§ 9.1/9.3、D6）将新 hook 置于 `hooks/pre-tool/auto-checkpoint.sh`，新目录命名为 `hooks/pre-tool/`。

**Source（源头）**：ARCHITECTURE.md § 2.1 模块表明确记载 PreToolUse 模块路径为 `hooks/pre-tool-use/`。实际磁盘目录为 `flow-kit-bundle/hooks/pre-tool-use/`（含已有 `independent-review-gate.sh`）。`install_hooks.sh:68-70` 和 `install_hooks.sh:128` 均使用 `pre-tool-use/` 路径片段注册已有 hook。CONTEXT.md 域语言条目 "L3 前置（L3 front-loading）"（第142行）同样引用 `PreToolUse hook（transition jq 拦截点）`，对应目录即 `pre-tool-use/`。

**Consequence（后果）**：
1. hook 文件被创建到不存在的 `hooks/pre-tool/` 目录，与 `install_hooks.sh` 的安装路径 `$hook_dst/pre-tool-use/` 不匹配
2. `install.sh`（或 `install_hooks.sh`）若按 DESIGN 注册 `hooks/pre-tool/auto-checkpoint.sh`，settings.json 会指向不存在的文件，hook 永不触发
3. 若强行创建 `hooks/pre-tool/` 目录，将产生两个 PreToolUse 目录（`pre-tool/` + `pre-tool-use/`），破坏项目结构一致性
4. AC-8（安装脚本集成）直接失败——hook 注册路径无效，`jq '.hooks.PreToolUse[] | select(contains("auto-checkpoint"))'` 会返回空
5. 整个 auto-checkpoint 功能部署后完全不可用——这是 AC-1 到 AC-6 的**全量 spec 合规失败**

**Remedy（修补）**：
全局替换 DESIGN.md 中所有 `hooks/pre-tool/` 为 `hooks/pre-tool-use/`：
- `hooks/pre-tool/auto-checkpoint.sh` → `hooks/pre-tool-use/auto-checkpoint.sh`
- `hooks/pre-tool/（新目录）` → 删除此条目（目录已存在，无需新建）
- D6 install.sh 注册路径 → `hooks/pre-tool-use/auto-checkpoint.sh`
- § 2 数据流图 → `hooks/pre-tool-use/auto-checkpoint.sh`
- § 9.1/9.3 所有引用同步修正

同时对照 `install_hooks.sh:128` 的注册模式（`bash "${settings_hook_path}/pre-tool-use/independent-review-gate.sh"`），确保新 hook 的注册命令格式、matcher（需评估是否复用 `"Bash|Write|Edit"` 还是缩减为 `"Write|Edit"`）与既有模式一致。

---

### 🟡 R2 · 未讨论与既有 PreToolUse hook `independent-review-gate.sh` 的交互

**Symptom（症状）**：DESIGN.md 未提及新建的 `auto-checkpoint.sh` 将与同一个 PreToolUse 钩子链中已存在的 `independent-review-gate.sh` 同时触发。两 hook 均在 Write/Edit 调用时执行。

**Source（源头）**：ARCHITECTURE.md § 2.1 模块表列出 PreToolUse 当前承载 `independent-review-gate.sh`（path-guard + gate 真实性校验 + auto-checkpoint 兜底——注意"auto-checkpoint 兜底"已在此模块描述中出现）。`install_hooks.sh:138` 注册 matcher 为 `"Bash|Write|Edit"`。CONTEXT.md 禁动清单（第332行）标注 `independent-review-gate.sh` 为 gate 核心链，禁止无关 change 修改。

**Consequence（后果）**：
1. 执行顺序不明确——如果 gate 脚本先执行并 deny 了工具调用，checkpoint 脚本是否仍应执行？如果顺序相反，checkpoint 在 gate 拒绝前写入是否为无效操作？
2. 两个 PreToolUse hook 均访问 `.flow-active`（gate 脚本读 phase/change_id，checkpoint 脚本写 interrupt），增加了 § 5 R2 描述的竞态窗口——但 R2 仅考虑了 Stop hook 并发，未考虑双 PreToolUse hook 并发
3. 组合延迟增加——用户每次 Write/Edit 前需等两个 hook 串行执行
4. 若 CC hook 框架不支持同一 matcher 上多个 hook 的确定性排序，行为不可预测

**Remedy（修补）**：
在 DESIGN 中新增一节 "与既有 PreToolUse hook 的交互"，明确：
1. CC PreToolUse hook 链的执行模型（串行/并行？同 matcher 的多个 hook 按 registration 顺序执行？）
2. `auto-checkpoint.sh` 应在 gate 之前还是之后执行（建议之前——checkpoint 是纯记录，gate 是拦截；先 checkpoint 再 gate 更安全）
3. matcher 评估：`auto-checkpoint.sh` 的 matcher 是否应缩窄为 `"Write|Edit"`（排除 Bash）以减少不必要的触发？当前 gate 脚本的 `"Bash|Write|Edit"` matcher 包含了 Bash 是因为 gate 需要拦截 `jq` 命令，但 checkpoint 对 Bash 调用无意义（AC-4 排除了非 Write/Edit 工具）
4. 两 hook 同时访问 `.flow-active` 的竞态分析（都使用 `jq → .tmp → mv` 原子写入，理论上安全但需确认 CC hook 调度不引入交叉执行）

---

### 🟡 R3 · 未显式引用被推翻的 CONTEXT.md 已锁决策 `[2026-07-04]`

**Symptom（症状）**：DESIGN.md D2 和 § 9.2 将 checkpoint 去重策略从"30s 去重窗口"改为"不启用（移除去重）"，标注推翻代价为"低"。但未显式引用被推翻的 CONTEXT.md 已锁决策条目。

**Source（源头）**：CONTEXT.md § 已锁决策 第225行：`[2026-07-04] auto-checkpoint 双层防护 — prompt 指令 + PreToolUse hook 兜底，去重窗口 30s（同 file+同 type）。checkpoint 写入必须通过 checkpoint_write() 函数。来自 user-guide-update`。该条目明确锁定了 30s 去重窗口。同时 CONTEXT.md 域语言 "auto-checkpoint" 条目（第154行）已更新为"不去抖"，与锁定决策形成**文件内自相矛盾**。

**Consequence（后果）**：
1. 未来维护者读 CONTEXT.md 时会看到两个互相矛盾的描述（域语言说"不去抖"，已锁决策说"30s 去重窗口"），无法确定哪个是真实状态
2. 按架构治理规范，推翻已锁决策需 A-evolve 流程——DESIGN § 9.2 虽记录了变更但未走 A-evolve 标记，下次 CONTEXT.md 清理时可能被误恢复
3. `user-guide-update` change 的原始设计意图被静默覆盖，缺乏审计追踪

**Remedy（修补）**：
1. DESIGN § 9.2 显式引用：`推翻 CONTEXT.md 已锁决策 [2026-07-04]（user-guide-update）中的 30s 去重窗口`
2. CONTEXT.md 已锁决策条目更新为：`[2026-07-10] auto-checkpoint 双层防护 — ... 去重策略：不启用（移除去重）。推翻 [2026-07-04] 的 30s 去重窗口决定。来自 auto-checkpoint-hook`（或追加新条目并标注旧条目 deprecated）
3. 同步修正 CONTEXT.md 域语言 "auto-checkpoint" 条目与已锁决策的一致性——当前域语言已说"不去抖"但决策还是"30s"，必须统一

---

### 🟡 R4 · `checkpoint_dedup_check()` 移除后将成为零引用死代码，与 D2 "供外部显式调用" 的声称矛盾

**Symptom（症状）**：D2 决策声称 "`checkpoint_dedup_check()` 函数保留不删（供外部显式调用）"。但实际代码分析显示该函数**仅在 `checkpoint_write()` 内部被调用**（`checkpoint-lib.sh:33`），仓库中无任何其他调用方。移除 `checkpoint_write()` 内部调用后，该函数零引用、零调用方。

**Source（源头）**：代码审计——`grep -rn "checkpoint_dedup_check" flow-kit-bundle/` 仅返回 `checkpoint-lib.sh:33`（内部调用）和 `checkpoint-lib.sh:65`（函数定义）。无外部运行时调用方，无测试单独覆盖。D2 的取舍代价段 "供外部显式调用" 缺乏现实基础。

**Consequence（后果）**：
1. 保留一个零调用方的函数是纯死代码——违反 D2 自身的取舍声明
2. 新开发者读 `checkpoint-lib.sh` 看到 `checkpoint_dedup_check()` 会困惑：这个函数还在用吗？谁在用？
3. R3 将死代码风险评为 "低概率" 是低估——死代码不会自我清理，长期积累增加维护负担
4. `CHECKPOINT_DEDUP_WINDOW` 变量同样变为零引用死配置

**Remedy（修补）**：
两种方案：
- **方案 A（推荐）**：彻底删除 `checkpoint_dedup_check()` 函数和 `CHECKPOINT_DEDUP_WINDOW` 变量。既然无外部调用方，"供外部显式调用"是假需求。D2 改为 "删除去重逻辑（`checkpoint_dedup_check()` 函数和 `CHECKPOINT_DEDUP_WINDOW` 变量一并移除）"。
- **方案 B**：保留函数但标记 `# DEPRECATED: 零调用方，保留仅供将来可能的显式调用。若无外部使用需求，v2 删除。` 且 D2 取舍代价改为"函数零引用保留为 deprecated 死代码，v2 评估删除"。

同时更新 test_checkpoint.bats 中依赖去重行为的测试用例（如有），确保测试与新的不 dedup 行为一致。

---

### 🟡 R5 · R1 风险缓解措施为推测性 fallback，未经 CC PreToolUse 协议验证

**Symptom（症状）**：DESIGN § 5 风险表 R1 的缓解措施写 "hook 中加字段名 fallback（`file_path || path || filename`）"。但 DESIGN 正文 § 2 数据流图直接假定 `tool_input.file_path` 可用且精确。两处互相矛盾：数据流图假设协议确定，风险表承认协议不确定。

**Source（源头）**：CC PreToolUse hook stdin JSON 协议的实际字段名未在 DESIGN 中引用任何官方文档或实测证据。§ 0.5.3 写 "参照 `independent-review-gate.sh` 模式"，但 gate 脚本处理的是 Bash 命令字符串（正则匹配 `jq` 命令），不解析 `tool_input` 的详细字段——所以实际上**没有可参照的先例**。`file_path || path || filename` 是纯推测，未经验证。

**Consequence（后果）**：
1. 若 CC 实际用的是 `file_path`（如数据流图假设），fallback 无害但冗余
2. 若 CC 实际用的是其他字段名（如 `path`、`absolute_path`、`file`），且 fallback 列表不包含——checkpoint 写入空 `active_file`，AC-1/AC-2 恢复精度受损
3. 以"实测为准"而不设计，是不完整的设计——DESIGN 阶段应确定协议，实现阶段不应猜测

**Remedy（修补）**：
1. 在 DESIGN 中增加一个小子节 "PreToolUse stdin JSON 协议确认"，引用 CC 官方文档或实际测试结果（`echo '{"tool_name":"Write","tool_input":{"file_path":"/x/y"}}' | jq '.tool_input.file_path'` 验证）
2. 若无法在 DESIGN 阶段确认，标注为 "待 4-dev 阶段实测确认" 并提升 R1 风险概率为 "高"（当前标"中"是低估）
3. 一旦确认实际字段名，移除推测性 fallback，直接使用确认的字段名——fallback 掩盖协议不明确，不如硬失败 + 明确错误日志

---

### 🟢 R6 · § 0.5.3 "参照 `~/.claude/hooks/pre-tool-use/` 结构" 自身使用正确命名，暴露 DESIGN 命名不一致

**Symptom（症状）**：DESIGN § 0.5.3 写着 "参照用户 scope 的 `~/.claude/hooks/pre-tool-use/` 结构"，其中目录名正确使用了 `pre-tool-use/`。但 DESIGN 其余各处均使用 `pre-tool/`。同一个段落内的前后不一致说明命名选择是疏忽而非有意。

**Source（源头）**：DESIGN § 0.5.3 自身的文字即证据——作者知道正确路径是 `pre-tool-use/` 但在决定新 hook 路径时未沿用。

**Consequence（后果）**：与 R1 同源但影响较轻——主要是文档内部一致性问题，不直接导致功能失败。

**Remedy（修补）**：随 R1 修复一并修正。§ 0.5.3 的 "引入新模式" 条目改为：`PreToolUse 目录：沿用 hooks/pre-tool-use/（已有目录），本次新增 auto-checkpoint.sh。模式参照 independent-review-gate.sh 的 stdin 解析 + install_hooks.sh 的注册方式`。

---

### 🟢 R7 · § 5 风险 R2 仅考虑 Stop hook 竞态，未考虑双 PreToolUse hook + Stop hook 的三方竞态

**Symptom（症状）**：DESIGN § 5 风险 R2 描述 "`.flow-active` 在 hook 触发时被其他进程（Stop hook）同时写入 → jq 写入竞态"，概率评为"低"。但没有考虑本次新增的 PreToolUse hook 与已有 PreToolUse hook（`independent-review-gate.sh`）同时访问 `.flow-active` 的场景。

**Source（源头）**：风险分析应覆盖所有 `.flow-active` 的并发写入方。当前写入方包括：PreToolUse `auto-checkpoint.sh`（写 interrupt）、PreToolUse `independent-review-gate.sh`（读 phase/change_id，写 goal.gates）、Stop hook 链（多个模块写不同字段）、prompt 层手动 `/flow checkpoint`。R2 仅考虑了 Stop hook 一个来源。

**Consequence（后果）**：风险矩阵不完整——实际竞态窗口比描述的更大。但由于所有写入方都使用 `jq → .tmp → mv` 的原子替换模式，实际数据损坏概率仍低。主要是文档准确性问题。

**Remedy（修补）**：更新 R2 描述为 "`.flow-active` 在 hook 触发时被其他进程（Stop hook、其他 PreToolUse hook、prompt 层手动操作）同时写入"。缓解措施补充："所有写入方均使用 jq 原子写入（.tmp → mv）降低窗口；下一次编辑立即覆盖，丢失可控"。概率保持"低"（原子写入模式确实使实际风险低），但描述更完整。

---

**Verdict**: fail

> 存在 1 条 🔴 Critical：R1（PreToolUse 目录命名 `hooks/pre-tool/` 与既有架构 `hooks/pre-tool-use/` 冲突）。该问题导致 hook 文件路径、安装注册路径、settings.json 配置全部指向不存在的位置，auto-checkpoint 功能部署后完全不可用，AC-1 至 AC-8 全量 spec 合规失败。此为阻塞性问题，必须在 4-dev 实现前修正 DESIGN.md。
