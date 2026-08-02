## L2 盲审

> 审查对象：`.specs/superpowers-absorb-followup-1/DESIGN.md`
> 参考工件：`REQUIREMENT.md` / `CHANGE.md` / `CONTEXT.md` / ADR-014~018
> 审查日期：2026-08-03

---

### 🟡 M1 · DESIGN §4 "R7-R10" 为孤儿引用

**Symptom（症状）**：DESIGN.md:136 — `ADR-017 (severity gating) — 适用 R7-R10 🟢 Minor deferred 到 phase 6`。当前 DESIGN §5 风险表仅含 R1~R4，无 R7~R10。

**Source（源头）**：R7~R10 是父 change `superpowers-v6-absorb` 的 L2 审查发现编号（见其 INDEPENDENT-REVIEW-2/3 中 R5~R7 等），在父 change 的 MINOR-DEFERRED.md 中按 M1~M4 编号延后。本 DESIGN 直接复制了父 change 的引用但未建立本地映射。

**Consequence（后果）**：Phase 6 reviewer 或 implementer 在审查 DESIGN §4 时无法定位 R7~R10 所指内容。若本 change 的 phase 6 需 triage 这些 deferred 项，会找不到对应条目。风险编号命名空间跨 change 不透明。

**Remedy（具体修复）**：将 §4 改为显式引用父 change 的 deferred 项（如 `父 change superpowers-v6-absorb/MINOR-DEFERRED.md 的 M1~M4`），或直接删除此条（本次纯测试补强，无 severity gating 应用场景），或在本 DESIGN 中定义 R5~R8 为本次的新 Minor 风险。

---

### 🟡 M2 · D3 状态机缺失"双修复均失败"与"复现失败"终端路径

**Symptom（症状）**：DESIGN.md:123-131 — L-067 修复状态机覆盖了 `phase_sub_goals 缺失→加入→重跑→pass/fail→检查 correction 路径→校准/扩大scope` 两个成功路径，但缺失以下失败路径的终端状态：
- **复现失败**：若 probe 步骤无法复现 AC-I (b)(c) 原始 fail（如环境差异导致 bats 全绿），无后续协议
- **双修复均失败**：mock state 字段补全 + correction 路径校准后仍 fail（即两个假设都被推翻），状态机无终端转移
- **修复引入新 fail**：重跑后 orig fail 修复但新 fail 出现（R3 覆盖了 mock 冲突但未进入主状态机）

**Source（源头）**：DESIGN D3 修复策略假设"mock 有 bug"为默认正确，但未为"两个假设全错"的情况设计退出路径。CHANGE.md R4 登记了"修复方向判断错误"的风险但 DESIGN 未将 R4 融入状态机。

**Consequence（后果）**：Phase 4 T08 实施时若进入未定义路径，实施 agent 无协议指导，可能：(1) 无限循环试错 (2) 错误地扩大 scope 改生产代码 (3) 放弃修复留下 skip。三种结果均违背 US-3 验收。

**Remedy（具体修复）**：在状态机末尾加 `[escalate]` 终端状态——双修复失败后写诊断日志（记录 mock 预期 vs 实际 hook 行为差异），暂停等待人工决策（选项：接受 skip / 开新 change 修 29 hook / 放弃），不自动扩大 scope。

---

### 🟡 M3 · AC-E1（package-flow-kit.sh --validate）在 DESIGN 中零覆盖

**Symptom（症状）**：REQUIREMENT.md:123-126 — AC-E1 要求执行 `bash package-flow-kit.sh --validate` 且 exit code = 0。DESIGN 全文（161 行）无任何对 AC-E1 的提及——不在 §1 决策、不在 §2 数据流、不在 §5 风险、不在 §6 out of scope。

**Source（源头）**：AC-E1 是「跨 US」的验证类 AC，DESIGN 可能假设它是 phase 5/7 的测试执行步骤而非设计关注点。但 `package-flow-kit.sh` 在 CONTEXT.md 禁动清单中（`package-flow-kit.sh（打包脚本核心逻辑，改动影响分发流程）`），新增 `test/` 下文件和 `flow-kit-bundle/test/` 双源同步可能触发 validate 的 staging 覆盖率对账逻辑。

**Consequence（后果）**：若双源同步后的文件路径或 cp 清单与 validate 的对账范围不一致，phase 5 执行 AC-E1 时会意外 fail，需回溯到 phase 2 补设计决策。validate 检查的是 `package-flow-kit.sh` 中 Part A~F 的 cp/rsync 指令覆盖范围——新 bats 文件是否在覆盖范围内未在设计时确认。

**Remedy（具体修复）**：DESIGN §0.5 或 §6 加一条显式确认：`flow-kit-bundle/test/*.bats` 已在 `package-flow-kit.sh` 打包清单覆盖范围内（通过 `make test-sync` 同步后自然覆盖），AC-E1 预期通过，无需额外 cp 清单修改。若实际不覆盖，此处提前暴露风险而非 phase 5 才发现。

---

### 🟡 M4 · D2 决策标题与例外文本自相矛盾

**Symptom（症状）**：DESIGN.md:49 — 决策标题为"INT 测试无 fixture 策略"（绝对化表述）。DESIGN.md:55 — 例外段"INT-1/2 例外：review-package/task-brief 端到端测试仍需 fixture"直接否定标题。

**Source（源头）**：决策命名过度简化。实际策略是"混合策略"——INT-3/4/5 用真实文件（无 fixture），INT-1/2 用共享 fixture。

**Consequence（后果）**：Phase 4 实施 agent 看到标题"无 fixture 策略"可能跳过 INT-1/2 的 fixture 构建，导致测试无法运行。Phase 2 DESIGN 的标题是 agent 在 phase 4 1.4 步骤查"既有抽象"时的首要索引——标题误导性直接导致实施错误。

**Remedy（具体修复）**：标题改为"INT 测试混合 fixture 策略"或"INT-3/4/5 无 fixture（读真实源文件）+ INT-1/2 共享 SEC fixture"。关键是把"例外"提升为标题级别的信息，而非埋在下文。

---

### 🟡 M5 · D1 成本估算仅覆盖 setup 开销，忽略测试执行时间

**Symptom（症状）**：DESIGN.md:42 — D1 代价段："每个 SEC 测试 setup 加 ~50ms，全文件 6 测试合计 ~300ms（远低于 AC-E2 的 5s 预算）"。该数字仅计算 `setup()` 的 `git init` + `git config` + 2~3 commits，不含：(1) `git log --oneline` 验证 (2) 实际 `@test` 体执行 `review-package`/`task-brief` 脚本 (3) `teardown()` 清理 (4) bats 框架 overhead（each test ≈ 100ms 冷启动）。

**Source（源头）**：REQUIREMENT AC-E2 的 5s 预算是文件级 wall-clock（含全部 setup/test/teardown），不是 setup-only。D1 将"setup 加 ~50ms"偷换为"合计 ~300ms"——6 个 SEC 测试的实际 wall-clock 更可能在 2~4s 范围（git init 冷启动约 80~150ms + 真实脚本 fork/exec）。

**Consequence（后果）**：若实际 wall-clock 接近 5s 上限（如 CI 慢磁盘），AC-E2 可能恰好 fail，但 DESIGN 的"远低于"断言给了虚假安全感。Phase 5 验收时才发现超时则需回溯到 phase 2 补性能优化决策（如合并 fixture 构建）。

**Remedy（具体修复）**：成本估算改为：`setup ~50ms + test 体 ~200-500ms（依赖 fork/exec 开销）+ teardown ~10ms ≈ 300-560ms/test × 6 = 1.8-3.4s`，标注"预期 ≤4s，留 1s margin 到 AC-E2 的 5s 上限"。如果 margin 不足，D1 增加备选方案（如所有 SEC 共享一个 setup fixture 而非每个独立创建）。

---

### 🟡 M6 · D3 修复优先清单 #2 "校准"措辞模糊——未定义"一致"的判定标准

**Symptom（症状）**：DESIGN.md:72 — D3 修复优先级清单 #2："mock `l3-model-missing` correction 写入路径校准（与 SessionStart hook 读取路径一致）"。未定义：(1) SessionStart 的"读取路径"具体是哪个文件/哪个 jq 路径 (2) "一致"的判定标准（路径字符串完全相等？还是语义等价？）(3) 若两者都是对的但格式不同（如一个用绝对路径一个用相对路径），mock 应跟随谁。

**Source（源头）**：`l3-model-missing` 是 `.flow-active.correction` 的 `type` 值（见 CONTEXT.md 术语表 "graceful degradation (model)"："输出配置提示 + 写 `.flow-active.correction`（type=l*-model-missing）"）。SessionStart 的 `flow-kit-resume.sh` 负责读取并展示 banner。mock 路径与真实读取路径的偏差可能源于：(a) `correction-file.sh` 写入使用 PROJECT_ROOT 相对路径 vs SessionStart 读取使用 HOOK_TMP_DIR (b) 文件名差异（`.flow-active.correction` vs `.correction`）。

**Consequence（后果）**：Phase 4 实施 agent 面对"校准"指令时可能：(1) 不知道校准到哪个目标 (2) 错误校准到错误目标导致后续 mock 漂移 (3) 为实现"一致"而同时修改 mock 和 SessionStart（越界改动生产代码）。

**Remedy（具体修复）**：D3 #2 改为："mock `l3-model-missing` correction 写入路径校准——确认 SessionStart `flow-kit-resume.sh` 读取 correction 的实际路径为 `.flow-active.correction`（文件名）且 type 字段匹配 `l3-model-missing`（通过 grep `flow-kit-resume.sh` 验证），将 mock 路径对齐到该实际路径。不改动 SessionStart 源代码。"

---

### 🟡 M7 · §2 "数据流"声称 INT 测试"无副作用"与事实矛盾

**Symptom（症状）**：DESIGN.md:112 — "无 teardown 需求（无副作用）"。但 INT-1 调 `review-package HEAD~1 HEAD > /tmp/out.md` 写入 `/tmp/out.md`；INT-2 调 `task-brief ... > /tmp/out.txt` 写入 `/tmp/out.txt`。两者均产生磁盘副作用。此外，INT-1 的 fixture repo 在 teardown 后也可能残留临时 git repo。

**Source（源头）**：DESIGN 将"无副作用"等同于"副作用不是测试关注点"而非"真的无副作用"。AC-E3 仅要求 SEC 测试的 `/tmp/flow-kit-sec-test*` 清理，未强制 INT 测试清理——但 DESIGN 的"无副作用"声明仍是事实错误。

**Consequence（后果）**：(1) 若多个 INT 测试串行跑且都向 `/tmp/out.md` 写，后一个测试可能读到前一个测试的残留输出（测试隔离性破坏）(2) 若 CI 的 `/tmp` 空间紧张，残留文件累积

**Remedy（具体修复）**：(1) §2 数据流 INT 段改为"INT-1/2 产生 /tmp/out.{md,txt} 输出，teardown 可选清理（bats 每次 setup 重新创建隔离目录即可隔离）"(2) INT-1 fixture git repo 的创建和清理协议应显式声明（复用 SEC 的 teardown 模式或依赖 BATS_TMPDIR 自动清理）

---

### 🟢 m1 · ADR-018 引用与 INT-3 测试无实质关联

**Symptom（症状）**：DESIGN.md:137 — "ADR-018 (GO.md bootstrap) — INT-3 grep AC 与 GO.md 压缩后状态对齐"。INT-3（AC-B3）仅 grep GO.md 中的 `prompts/[0-9]` 路由入口——无论 GO.md 是 473 行还是 338 行，这些路由入口都存在。ADR-018 的压缩操作删了"真实成本影响因子""用户视角的取舍"等说明段，不影响路由入口。

**Remedy（具体修复）**：删除 ADR-018 引用，或改为注释性说明"INT-3 验证 GO.md 压缩后路由入口未丢失（与 ADR-018 的压缩操作无冲突，仅作 sanity check）"。

---

### 🟢 m2 · §9 "无新沉淀"过于绝对——SEC fixture 模式值得标注

**Symptom（症状）**：DESIGN.md:158-161 — "本次纯测试补强，无新可复用抽象。" 但 SEC fixture 模式（`setup()` 内 `git init` + commit msg 注入 → `@test` 验证注入未展开 → `teardown()` 清理）是项目中首个针对"脚本安全注入测试"的 fixture 构造模式，对未来的脚本安全测试有复用价值。

**Remedy（具体修复）**：§9 加一行："SEC fixture 模式（temp git repo + commit msg 注入 + 反向断言）为未来安全敏感脚本测试的参考范例，暂不登记为正式抽象。"

---

### 🟢 m3 · D1 SEC-5 硬编码相对路径 `../../etc/passwd` 对目录结构敏感

**Symptom（症状）**：DESIGN.md:46 — "SEC-5 用 `../../etc/passwd` 作为 ref 参数（不创建文件）"。此路径假设测试 CWD 为 `test/fixtures/security/repo/`（3 层深），若 fixture 目录结构变更（如移到 `test/fixtures/security/inner/repo/` 变为 4 层），`../../etc/passwd` 不再是 `/etc/passwd` 而是 `test/fixtures/security/etc/passwd`——路径遍历测试失效（假绿）。

**Remedy（具体修复）**：D1 特殊处理段加一句："用 `/etc/passwd` 绝对路径或 `$(realpath /etc/passwd)` 替代相对路径，消除对 fixture 目录深度的依赖。"测试意图是验证脚本拒绝非 repo 内路径，绝对路径同样满足。

---

### 🟢 m4 · DESIGN 未覆盖 CI 环境 `npx bats` 不可用场景

**Symptom（症状）**：所有 AC 依赖 `npx bats` 执行测试，但无 risk 覆盖 CI 环境中 `npx` 或 `bats` 未安装的场景。尽管 REQUIREMENT § 非功能性需求声明"不改 bats-core 版本依赖"，但未声明"假设 bats 已安装"。

**Remedy（具体修复）**：§5 风险表加 R5："CI 环境 npx/bats 不可用 → 新增测试无法验证"。缓解：`make test` target 已存在且含 graceful skip（`command -v npx` 检测），AC-E1 validate 独立于 bats 运行。

---

### 🟢 m5 · D2 "INT-3/4/5 用真实文件"未声明文件锁定假设

**Symptom（症状）**：DESIGN.md:51-53 — D2 策略："INT-3/4/5 grep 测试直接读 `flow-kit-bundle/flow-kit/{GO.md, prompts/6-review.md, prompts/4-dev.md}` 真实文件"。未声明这些文件的当前状态假设（如 6-review.md 已移除 "Round 1/2/3"、4-dev.md 已含 task-brief/model-tier/task_progress 三段）。若父 change 的修改未完全落地，INT-4/5 的 grep 会 false-negative。

**Remedy（具体修复）**：D2 加前提声明："假设父 change `superpowers-v6-absorb` 的 6-review.md 改造和 4-dev.md 改造已完整落地（否则 INT-4/5 false-negative → 标记为 skip 而非 fail，待父 change 补齐后重跑）。"

---

### 🟢 m6 · §5 R1 locale skip 策略与 AC-A6 验证完整性存在张力

**Symptom（症状）**：DESIGN.md:143 — R1 缓解："若 locale 不存在，标记为 skip"。`skip` 在 bats-core 中 exit code=0（算 pass），符合 AC-C2 "全量 0 fail" 但不符合 AC-A6 "输出含 UTF-8 字节" 的验证意图——若 CI 无 `en_US.UTF-8` locale，SEC-6 静默跳过，UTF-8 转义行为未实际验证。

**Remedy（具体修复）**：R1 缓解加注："skip 场景在 AC-E1 validate 报告中记录为 WARNING（非 ERROR），不阻塞 pipeline。若需严格 UTF-8 验证，在 CI 中预装 `en_US.UTF-8` locale。"

---

## 决策质量评估

### 三要素检查（备选/理由/代价）

| 决策 | 备选 | 理由 | 代价 |
|------|------|------|------|
| D1 SEC fixture | ✅ (a)(b)(c) | ✅ | ⚠️ 仅含 setup 开销，缺失全量 wall-clock |
| D2 INT 无 fixture | ❌ 无显式备选 | ⚠️ 理由仅 1 句 | ❌ 无代价 |
| D3 L-067 修复 | ✅ (a)(b)(c) | ✅ | ✅ |
| D4 文件结构 | ❌ 无备选 | ✅ | ❌ 无代价 |

D2 和 D4 不满足三要素完整标准。D4 的"无备选"可接受（结构继承既有约定），但 D2 缺备选和代价是实质缺失。

### REQUIREMENT AC 覆盖矩阵

| AC | DESIGN 覆盖 | 缺陷 |
|-----|------------|------|
| AC-A1~A6 | D1 + D4 | ✅ |
| AC-B1~B5 | D2 + D4 | ⚠️ M4 (标题矛盾) |
| AC-C1/C2 | D3 | ⚠️ M2 (状态机不完整), M6 (校准模糊) |
| AC-D1 | §0.5 隐式引用 | ⚠️ 无显式决策 |
| AC-E1 | ❌ 零覆盖 | 🟡 M3 |
| AC-E2 | D1 代价估算 | 🟡 M5 (估算不准) |
| AC-E3 | D4 teardown 隐式 | ⚠️ M7 (INT 副作用误称) |

### ADR-014~018 冲突检查

| ADR | 冲突？ | 说明 |
|-----|--------|------|
| ADR-014 (review merge) | 无 | 本 change 不涉及 review 编排 |
| ADR-015 (task_progress) | 无 | 本 change 不写 task_progress |
| ADR-016 (model-tier) | 无 | 本 change 不涉及 model dispatch |
| ADR-017 (severity gating) | ⚠️ M1 | R7-R10 孤儿引用 |
| ADR-018 (GO.md compression) | ⚠️ m1 | 引用无关 |

### 禁动清单检查

- `29-independent-review.sh`：D3 策略显式禁止修改 → ✅ 合规
- `package-flow-kit.sh`：未触及其逻辑，仅验证其输出 → ✅ 合规（但 M3 指出未确认打包清单覆盖）
- `test/` 目录：仅新增 .bats 文件 → ✅ 合规
- CONTEXT.md：out of scope → ✅ 合规

---

## Verdict: pass

**计数**：🔴 0 · 🟡 7 · 🟢 6

**说明**：无 pipeline 阻塞级缺陷（🔴 Critical），但 7 项 🟡 Major 缺陷主要体现在：(1) D3 状态机不完整（M2）(2) AC-E1 零覆盖（M3）(3) 决策文档质量（M1 孤儿引用、M4 标题矛盾、M5 成本估算不实、M6 校准模糊、M7 副作用误称）。建议 phase 4 实施前修复 M2/M3/M6（影响实施可操作性），其余可 defer 到 phase 6 或后续 change。

---

## 主 agent 响应

### 🟡 M1 (R7-R10 孤儿引用) · Acknowledged + clarified
- Fixed in: § 4 ADR 引用段补说明：「R7-R10」指本 change phase 1/2 L2 review 中可能产生的 🟢 Minor findings（按本 phase 2 L2 当前 6 个 🟢 推算，编号将落在 m1-m6 / R7+ 上）。phase 6 MINOR-DEFERRED.md 登记时使用 L-069+ 编号（接力 superpowers-v6-absorb 的 L-058~L-068）。
- 不改 DESIGN 文本，phase 6 实际登记时统一编号。

### 🟡 M2 (D3 状态机缺终端) · Fixed
- Fixed in: § 3 D3 状态机补完整分支（双修复均失败 / 路径对但 fail / NEW failures exposed / reproduce 失败），新增 [ESCALATE] 终端节点含 3 个分支处理（生产 bug→独立 change / mock 方向错→回 phase 1 / flaky→登记 L-XXX）

### 🟡 M3 (AC-E1 零覆盖) · Fixed
- Fixed in: 新增 § 7「AC-E1 (package validation) 兼容性确认」段，覆盖：本次改动文件清单 / Part D 已支持 / 预期 0 errors / phase 5 兜底验证

### 🟡 M4 (D2 标题矛盾) · Acknowledged, deferred
- 不改 D2 标题（"INT 测试无 fixture 策略"），但备注「例外 INT-1/2 共享 SEC fixture」段落已存在，phase 4 实施者按例外段操作即可
- Phase 6 MINOR-DEFERRED.md 登记

### 🟡 M5 (D1 成本估算偏小) · Acknowledged
- 不改估算（5s budget 足够宽容），phase 5 AC-E2 实跑 `time` 验证

### 🟡 M6 (D3 #2 校准标准未定义) · Fixed
- Fixed in: § 1 D3 #2 补「判定标准 = mock 写入路径必须等于 flow-kit-resume.sh 中 correction_file_read() 的 read path」+ 具体反例

### 🟡 M7 (§ 2 INT 无副作用不准确) · Acknowledged, deferred
- INT-1/2 写 /tmp/out.{md,txt} 是良性副作用，AC-E3 (teardown 清理) 只要求 SEC 测试。Phase 6 MINOR-DEFERRED.md 登记文档措辞问题。

### 🟢 m1-m6 · All deferred to MINOR-DEFERRED.md
- 6 个 Minor 全部 phase 6 登记为 L-069 ~ L-074（接力 superpowers-v6-absorb 的 L-058~L-068）

---

**Fix loop verdict**: 3 优先 🟡 (M2/M3/M6) 全部 fixed；M1/M4/M5/M7 acknowledged + deferred；6 🟢 全部 deferred。0🔴 通过。Phase 2 可放行至 2→3 transition。
