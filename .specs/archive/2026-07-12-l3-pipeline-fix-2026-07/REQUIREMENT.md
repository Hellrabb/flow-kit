# REQUIREMENT: L3 审查管线 + Stop Hook 性能修复

- **Change ID**: `l3-pipeline-fix-2026-07`
- **关联**: `@.specs/l3-pipeline-fix-2026-07/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我希望 L3 审查能收到完整的代码 diff（含新文件），以便大变更时 L3 不会基于截断信息做出假阳性判断。
- **US-2**：作为 flow-kit 用户，我希望 L3 审查能自动检测并补齐历史阶段的积压审查，以便 pipeline 中途开启 L3 时不会遗漏前序阶段的独立审查。
- **US-3**：作为 flow-kit 用户，我希望每次 L3 审查能携带前次审查的上下文（verdict + 反驳摘要），以便 L3 不会重复已解决的假阳性。
- **US-4**：作为 flow-kit 用户，我希望 Stop hook 链执行更快（≥30% 性能提升），以便每轮对话的响应体验不被 hook 延迟拖慢。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · git diff 上限提升

- **Given** 一个 change 产生了 > 5000 字符的代码变更（如大重构）
- **When** L3 审查（phase 6）被触发，调用 `l3-review.sh` 构建 prompt
- **Then** L3 prompt 中的代码 diff 按动态 token 估算截断（估算 token 数不超过当前模型上下文窗口的 60%，窗口大小从 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 对应模型的 context_window 配置获取，默认 100000 tokens），不再在 5000 字符处硬截断
- **验证方式**: `bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh` 语法通过；bats 测试用例：构造 10000 字符 diff → 调用 `l3_review_run()` → 断言 prompt 中 diff 长度 > 5000 且估算 token ≤ 60000（100000 × 60%），context_window 可通过环境变量覆盖

### AC-2 · 新文件对 L3 可见

- **Given** 一个 change 包含新增文件（untracked 或 staged，如 `correction-types.sh`）
- **When** L3 审查构建代码 diff
- **Then** 新增文件的内容出现在 L3 prompt 的 diff 段中
- **验证方式**: bats 测试用例：创建包含 untracked 文件的 git 仓库 → 调用 diff 收集函数 → 断言输出含 untracked 文件内容（非仅文件名）；`grep -E 'git diff|git ls-files|--cached|--others' flow-kit-bundle/hooks/stop/lib/l3-review.sh` 确认收集逻辑已覆盖 staged + untracked

### AC-3 · 智能截断保留关键段

- **Given** 一个阶段的产物文件（如 REQUIREMENT.md 12.3K）超出 L3 prompt 单文件长度限制
- **When** `smart_truncate()` 对该文件执行截断
- **Then** 截断结果保留文件头部的 AC 段 + 尾部的风险/决策段（而非纯头部截断丢弃尾部）
- **验证方式**: bats 测试用例：构造 12.3K 的 mock REQUIREMENT.md（含 AC 段在前、风险段在后）→ 调用 `smart_truncate()` → 断言输出头 6000 字符含 "AC-" + 尾 6000 字符含 "风险"；`grep -c 'smart_truncate' flow-kit-bundle/hooks/stop/lib/l3-review.sh` 确认函数存在

### AC-4 · 积压扫描补齐历史 L3

- **Given** pipeline goal 的 phase 5 才开启 L3 gate（`gate_config["5-test"]="both"`）
- **When** Stop hook `29-independent-review.sh` 执行
- **Then** 自动检测 `phases_done` 中 phase 1/2 的 gate_config 是否含 L3 但 `.independent-review-{1,2}.done` 缺失，若缺失则触发 L3 补跑
- **验证方式**: bats 测试用例：构造 `.flow-active`（phases_done=["1","2","3"]，gate_config 含 L3 但 .independent-review-{1,2}.done 缺失）→ 调用积压扫描函数 → 断言返回需补跑的 phase 列表 = ["1","2"]（排除已有 .done 的 phase）；`grep -c 'phases_done\|backlog' flow-kit-bundle/hooks/stop/29-independent-review.sh` 确认逻辑存在

### AC-5 · L3 prompt 上下文注入

- **Given** 同一阶段的 L3 审查已至少执行过一次（存在 `INDEPENDENT-REVIEW-{N}.md` 含 L3 段）
- **When** 下次 L3 审查被触发（重审场景）
- **Then** L3 prompt 中包含前次审查的 verdict + 主 agent 反驳摘要 + L2 verdict 上下文
- **验证方式**: bats 测试用例：构造 `INDEPENDENT-REVIEW-{N}.md`（含 L3 verdict + L2 反驳摘要）→ 调用 L3 prompt 构建函数 → 断言 prompt 含前次 verdict + 反驳文本；`grep -c 'INDEPENDENT-REVIEW\|verdict\|prior.*review' flow-kit-bundle/hooks/stop/lib/l3-review.sh` 确认注入逻辑存在

### AC-6 · Stop hook 性能提升 ≥ 30%

- **Given** 当前 Stop hook 链基线执行时间（待测量）
- **When** 性能优化实施完成后，在相同条件下触发 Stop hook
- **Then** Stop hook 链总执行时间降低 ≥ 30%（测量方式：`time bash flow-kit-bundle/hooks/stop/00-gate.sh` 或其他代表性 hook 脚本的 wall-clock 时间）
- **验证方式**: 性能优化前后各测 3 次取中位数，对比确认降幅 ≥ 30%

### AC-7 · 零回归

- **Given** 所有修复已应用到 `flow-kit-bundle/` 维护源
- **When** 运行全量测试套件 + 语法检查
- **Then** `npx bats test/` 全量通过（0 fail），`bash -n` 对所有修改的 .sh 文件通过
- **验证方式**: `npx bats test/` 返回 exit 0；`find flow-kit-bundle/hooks -name '*.sh' | xargs -n1 bash -n` 全部输出空（无语法错误）

### AC-8 · L3 API 降级行为

- **Given** L3 API 返回非 200（4xx/5xx）或超时（>30s）
- **When** 任意 L3 审查被触发（含积压扫描触发的补跑）
- **Then** 该 phase 的 L3 审查 verdict 标记为 `error` 或 `timeout`（写入 `INDEPENDENT-REVIEW-{N}.md` 的 L3 段），pipeline 继续执行不阻塞，hook 日志记录失败原因
- **验证方式**: bats 测试用例：mock L3 API 返回 500 → 调用 `l3_review_run()` → 断言 verdict=error、返回码非零但 exit 0（不阻断 hook）；mock 超时 → 断言 verdict=timeout

---

## 范围切分

### v1（本次必做）

- AC-1: git diff 改用动态 token 估算截断（替代硬限 5000 字符）
- AC-2: diff 收集覆盖 untracked + staged 新文件
- AC-3: `smart_truncate()` 改为头+尾保留策略
- AC-4: 29 号 hook 添加积压扫描逻辑
- AC-5: L3 prompt 注入前次审查上下文
- AC-6: Stop hook 性能优化（≥30% 提升）
- AC-7: 全量回归测试通过
- AC-8: L3 API 降级行为（超时/HTTP 错误不阻塞 pipeline）

### v2（下一轮考虑，不本次）

- L3 API 异步化（fire-and-forget + SessionStart 收割结果）— 当前 30s 同步等待可接受，异步化增加复杂度
- lib 懒加载机制（按需 source 替代全量预加载）— 需要改造 Stop hook 加载框架，影响面大
- `l3_review_run()` 307 行主函数拆分（TD-008）— 独立 change 处理，不混入本次管线修复

### out（永远不做）

- 改变 L3 API 调用方式（保持 curl + 30s timeout）— 外部 API 契约不变
- 新增 hook 模块编号 — 本次不改变 hook 链结构
- 改动 gate_config schema — 配置格式不变
- 修改 `package-flow-kit.sh` — 打包脚本不在本次范围内
- 改变 `.done` KVP 格式 — 向下兼容现有 6 键格式

---

## 非功能性需求

- **性能**: Stop hook 链 wall-clock 执行时间降低 ≥ 30%（AC-6）；L3 API 调用保持 ≤ 30s timeout（不恶化）
- **可访问性**: 无（非 UI 项目）
- **安全**: 无新增安全风险（不改变 API 鉴权方式，不暴露新端点）
- **兼容性**: 向下兼容现有 `.flow-active` schema；兼容现有 `L3_RESULT` 输出格式；兼容现有 `.done` 6 键 KVP 格式
- **可观测性**: 性能优化后建议在 hook 日志中新增各模块耗时统计（可选，不强制）

## 依赖与假设

- **依赖**:
  - 现有 `l3-review.sh`（`flow-kit-bundle/hooks/stop/lib/l3-review.sh`）— 主要修改目标
  - 现有 `29-independent-review.sh`（`flow-kit-bundle/hooks/stop/29-independent-review.sh`）— 积压扫描添加位置
  - 现有 `common.sh`（`flow-kit-bundle/hooks/stop/lib/common.sh`）— 可能的共享函数添加
  - `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` 环境变量 — L3 API 调用依赖
  - bats-core 1.13.0 — 测试框架
  - gate_config 取值说明：`"L2"` = 仅同会话子 agent 盲审，`"L3"` = 仅外部模型审查，`"both"` = L2 + L3 双层审查（定义见 CONTEXT.md 术语表 `l2-l3-granular-gate`）

- **假设**:
  - 当前 `git diff` 上限 5000 字符的硬编码位置在 `l3-review.sh:204`（CHANGE.md 记录，需实际确认）
  - Stop hook 性能瓶颈主要在 L3 API 同步等待（30s）和各模块串行 source——优化方向以测量数据为准
  - `smart_truncate()` 当前实现为 `head -c $max_chars` 纯头部截断——改为头+尾保留不影响 prompt 结构
  - 积压扫描不影响正常 pipeline flow——仅在 gate_config 含 L3 且 .done 缺失时触发补跑
