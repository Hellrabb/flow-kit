# REQUIREMENT · final-debt-cleanup-2026-08

> Phase 1 · 2026-08-03 · 全部 10 项债务收尾

---

## § 1 用户故事

### US-1 · Quick packaging fixes
作为 flow-kit 维护者，我希望 TD-071-A + TD-071-B 两个 pre-existing 打包漏配被修复，使得 `package-flow-kit.sh --validate` 报 0 ERROR + 0 WARNING。

### US-2 · Archived lessons 妥善关闭
作为 flow-kit 用户，我希望 L-058 + L-060 + L-062 三条归档文档教训被正式关闭（不再以 `active` 状态悬挂），通过 ADR 固化为未来 writing 标准。

### US-3 · Spec/verification 缺口填补
作为 flow-kit 设计者，我希望 L-061 (OpenCode task 工具实测) + L-063 (弱模型退化缓解) 通过实测或 ADR 文档化方式填补——两条 spec 缺口通过可验证的 ADR 或实测文档关闭。

### US-4 · AC-B4 测试深度补齐
作为 flow-kit 测试者，我希望 L-066 AC-B4 测试覆盖合并指标（4-dev.md + task-brief 一起加载），不止测 task-brief 单独输出。

### US-5 · 结构性技术债清理
作为 flow-kit 后续维护者，我希望 TD-008 + TD-017 + TD-018 三项长函数/多职责 lib 被拆分为符合行数上限的单一职责子模块。

---

## § 2 验收准则（AC）

### 类别 A · Quick fixes (US-1)

**AC-A1** (TD-071-A brooks-lint Part F)
- `Given` package-flow-kit.sh Part F (lines 504-530)
- `When` 执行 `bash package-flow-kit.sh --validate`
- `Then` stderr/stdout 不再出现 `brooks-audit/SKILL.md` 或 `brooks-test/SKILL.md` 漏配 ERROR
- 验证方式: `bash package-flow-kit.sh --validate 2>&1 | grep -E "brooks-(audit|test)/SKILL"` 返回空

**AC-A2** (TD-071-B A-evolve.md)
- `Given` flow-kit-bundle/flow-kit/prompts/A-evolve.md 状态（源文件存在 OR 缺失）
- `When` 执行 `bash package-flow-kit.sh --validate`
- `Then` 不再出现 A-evolve.md 相关 WARNING
- 验证方式: `bash package-flow-kit.sh --validate 2>&1 | grep "A-evolve"` 返回空
- 决策（DESIGN D1）: 若源文件存在 → 加 cp；若源文件不存在 → 从 validate 期望清单移除

### 类别 B · Archived lessons 关闭 (US-2)

**AC-B1** (ADR-019 创建)
- `Given` L-058 + L-060 + L-062 三条教训已收集
- `When` 写 `.specs/adr/019-requirement-writing-principles.md`
- `Then` ADR 含 3 条原则（每条对应一个 L-XXX）+ 反例 + 正例
- 验证方式: `test -f .specs/adr/019-requirement-writing-principles.md` + `grep -c "^## " .specs/adr/019-*.md` ≥ 4

**AC-B2** (LESSONS.md 状态更新)
- `Given` ADR-019 已写入
- `When` 更新 `.specs/LESSONS.md` L-058/060/062 三条
- `Then` 三条状态字段从 `active` → `✅ addressed via ADR-019`
- 验证方式: `grep -c "addressed via ADR-019" .specs/LESSONS.md` ≥ 3

### 类别 C · Spec/verification (US-3)

**AC-C1** (L-061 OpenCode task 工具实测)
- `Given` OpenCode 当前会话
- `When` 主 agent 调用 task 工具派一个 simple subagent
- `Then` ADR-020（或 ADR-016 update）记录实测结果：OpenCode 是否支持 task-level model switching / 派发的 subagent 是否能用配置的 model
- 验证方式: 
  - `test -f .specs/adr/020-opencode-task-tool-verification.md`
  - `grep -E "^timestamp: 2026-08-0[3-9]" .specs/adr/020-*.md` 返回 1+ 行（实测日期）
  - `grep -c "^verdict:" .specs/adr/020-*.md` ≥ 1（明确 verdict 行）
  - `grep -c "supported\|not supported\|partial" .specs/adr/020-*.md` ≥ 1（结论分类）

**AC-C2** (L-063 弱模型缓解 ADR)
- `Given` 弱模型实测环境不可用（minimax-m2.7 / qwen3.6-35b-a3b 无 API）
- `When` 写 `.specs/adr/021-weak-model-prompt-degradation.md`
- `Then` ADR 含：退化模式分类（output verbose / chain-of-thought break / format ignore）+ 缓解策略（structural rigidity only / no nagging）+ 未来实测触发条件
- 验证方式: `test -f .specs/adr/021-weak-model-prompt-degradation.md` + `grep -c "^## " .specs/adr/021-*.md` ≥ 4

### 类别 D · AC-B4 测试 (US-4)

**AC-D1** (AC-B4 addendum + 测试)
- `Given` archived superpowers-v6-absorb REQUIREMENT.md AC-B4 措辞模糊
- `When` 在该 REQUIREMENT.md 末尾加 `## Addendum 2026-08-03 (final-debt-cleanup-2026-08)` 段，重写 AC-B4 措辞为可测条件
- `Then` 新增 bats 测试 `test/test_combined_metrics.bats` 测 (4-dev.md + task-brief typical output) 合并大小
- 验证方式: 
  - `grep -A 20 "Addendum 2026-08-03" .specs/archive/superpowers-v6-absorb/REQUIREMENT.md | grep -c "AC-B4"` ≥ 1
  - `grep -A 20 "Addendum 2026-08-03" .specs/archive/superpowers-v6-absorb/REQUIREMENT.md | grep -E "(Given|When|Then|wc -c|≤|byte)" | wc -l` ≥ 3（addendum 含可测措辞标志）
  - `test -f test/test_combined_metrics.bats`
  - `npx bats test/test_combined_metrics.bats` 全 pass

### 类别 E · 重构 (US-5)

**AC-E1** (TD-008 + TD-017 l3-review.sh 拆分)
- `Given` flow-kit-bundle/hooks/stop/lib/l3-review.sh 875 行
- `When` 拆分为单一职责子模块（具体文件数/命名由 DESIGN D4 决定，建议 4 子库）
- `Then`:
  - `wc -l flow-kit-bundle/hooks/stop/lib/l3-review.sh` ≤ 200 行（编排层）
  - 各子库文件 ≤ 250 行
  - 拆分后总行数 ≤ 1500 行（含 source 语句/函数签名 overhead）
  - `npx bats test/` 全量 pass (0 fail，target ≥657)
- 验证方式: `wc -l` 检查 + bats 全量回归
- 注: 具体子库名（如 l3-detect.sh / l3-dispatch.sh / l3-truncate.sh / l3-format.sh）由 DESIGN §1 决定

**AC-E2** (TD-018 independent-review-gate.sh 拆分)
- `Given` flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh::is_gh_pr_create 290 行
- `When` 拆为单一职责 gate 函数（具体函数数/命名由 DESIGN D5 决定，建议 7-8 个 _gate_* 函数）
- `Then`:
  - 入口函数（is_gh_pr_create 或重命名的等价物）≤ 50 行（仅做命令分类 + 调用编排器）
  - 编排器（如 _run_review_gates）≤ 100 行
  - 各 gate 检查函数 ≤ 60 行
  - `npx bats test/` 全量 pass
- 验证方式: 函数级 wc -l + bats 全量回归
- 注: 具体函数命名由 DESIGN §1 决定

**AC-E3** (重构安全性 - 集成测试)
- `Given` TD-008/017/018 拆分可能破坏 PreToolUse + Stop hook 关键路径
- `When` 跑全量 bats
- `Then` 所有现有 l3/gate 测试 pass + 新增至少 3 个集成测试覆盖关键场景
- 验证方式: 
  - 新增 `test/test_l3_review_lib_integration.bats` (3+ tests: API mock + truncation head/tail + format consistency)
  - 新增 `test/test_gate_orchestration_integration.bats` (3+ tests: phase transition + commit + PR create 各 1)
  - `npx bats test/test_l3_review_lib_integration.bats test/test_gate_orchestration_integration.bats` 全 pass
  - **source overhead check**: `bash -c 'time (for f in flow-kit-bundle/hooks/stop/lib/l3-*.sh; do source "$f"; done)' 2>&1 | grep real | grep -E "0m0\.[0-5]" ` 显示 ≤500ms（覆盖 NFR Performance）
  - **no new network calls**: `grep -rE "curl|wget|nc " flow-kit-bundle/hooks/stop/lib/l3-*.sh flow-kit-bundle/hooks/pre-tool-use/*.sh | grep -v "^Binary" | wc -l` 不增长（baseline: 当前 count）

### 类别 F · Delivery (meta)

**AC-F1** (双源 sync)
- `Given` 类别 A-E 修改的 test/*.bats
- `When` 执行 `make test-sync`
- `Then` `diff -q test/ flow-kit-bundle/test/` 仅 .bats 文件差异
- 验证方式: `make test-sync && diff -qr test/ flow-kit-bundle/test/ 2>&1 | grep -v "^Only in.*fixtures\|^Only in.*regression"` 返回空

**AC-F2** (package validate clean)
- `Given` 全部修改完成
- `When` 执行 `bash package-flow-kit.sh --validate`
- `Then` exit code 0 + 0 ERROR + 0 WARNING
- 验证方式: `bash package-flow-kit.sh --validate; echo "exit=$?"` 显示 exit=0

**AC-F3** (CONTEXT.md 同步)
- `Given` 新增 4 个 l3-* lib + 7+ 个 _gate_* 函数 + 3 个新 ADR + 禁动 exception
- `When` 更新 `.specs/CONTEXT.md`
- `Then`:
  - 既有抽象索引追加 4 个 l3-* lib + 7+ 个 _gate_* 函数
  - 已锁决策追加 ADR-019/020/021 引用
  - 禁动清单追加 l3-review.sh 拆分后 4 子库 + independent-review-gate.sh 重构后内部函数
- 验证方式: `grep -c "l3-detect.sh\|l3-dispatch.sh\|l3-truncate.sh\|l3-format.sh" .specs/CONTEXT.md` ≥ 4

**AC-F4** (commit threshold)
- `Given` 全部 AC A-E 通过
- `When` phase 7 commit
- `Then` ≥1 commit + ≥4 files touched
- 验证方式: `git log --oneline --grep="final-debt-cleanup-2026-08" | wc -l` ≥ 1 + `git diff --name-only HEAD~1 | wc -l` ≥ 4

**AC-F5** (回归 0 退化)
- `Given` baseline 657/657 bats pass
- `When` 全部修改完成
- `Then` `npx bats test/` 0 fail
- 验证方式: `npx bats test/ 2>&1 | tail -3` 显示 "0 failures"

---

## § 3 范围决策

- **TD-008/017 一起做**: 同一文件 l3-review.sh，分开做会重复 source 验证成本
- **TD-018 单独 task**: 不同文件 (independent-review-gate.sh)，但同 wave 并行
- **AC-B4 addendum 模式**: 在 archived REQUIREMENT.md 加 `## Addendum` 段而非改原内容（保 archive 不可变惯例，仅追加）
- **OpenCode task 实测**: 本 session 内调用 task 工具派 subagent，记录实际行为作为 ADR-020 evidence
- **弱模型场景**: 不实测，纯 spec ADR-021（minimax/qwen API 不可用）
- **禁动 exception 写入流程** (L072 fix 先例扩展):
  - TD-008/017 涉及 `flow-kit-bundle/hooks/stop/lib/l3-review.sh`（CONTEXT.md 禁动清单 l3-review.sh 条目）
  - TD-018 涉及 `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` + `gate 校验核心链`
  - **流程**:
    1. **CHANGE.md §5 Risks** 已记录每项禁动条目的 exception 理由（R1 + R2）
    2. **DESIGN 阶段** 在 §0.5 架构对齐段引用此 exception
    3. **4-dev 1.4 步骤** 读 CHANGE.md R1/R2 + DESIGN §0.5 exception 后执行修改
    4. **AC-F3** 验证修改后 CONTEXT.md 禁动清单追加新结构条目（4 子库 + 7+ 函数）
  - 参照 L-072 fix exception 格式（CHANGE.md / CONTEXT.md 入库）
  - **Meta 矛盾处理**: 禁动清单本身的"追加新条目"操作不属于禁动（禁动只针对"修改既有条目"）。本 change 仅追加（l3 子库 / gate 子函数），不修改既有"l3-review.sh"条目语义（条目扩展为"l3-review.sh 及其拆分后子库"）

---

## § 4 v1 / v2 / out

- **v1**: 全部 10 项（5 group）
- **v2**: 无
- **out**: 无

---

## § 5 NFR

- **Performance**: 单测 ≤5s（验证: AC-E3 集成测试加 `SECONDS=0 ... [ $SECONDS -le 5 ]`）; l3-review.sh 拆分后 source overhead ≤500ms（验证: AC-E3 source overhead check）
- **Security**: 拆分后 lib 不引入新网络调用（验证: AC-E3 no new network calls check）
- **Maintainability**: 拆分后函数命名遵循 CONTEXT.md `fk_/l3_/_l3_/_gate_` 前缀规范（验证: phase 6 review）
- **Testability**: 新增集成测试覆盖 PreToolUse + Stop hook 关键路径（验证: AC-E3）

---

## § 6 Self-check

- [ ] 5 用户故事清晰且不重叠 ✓
- [ ] 15 AC 全部 Given/When/Then 完整 ✓ (A1/A2/B1/B2/C1/C2/D1/E1/E2/E3/F1/F2/F3/F4/F5)
- [ ] 范围决策有理由（含禁动 exception 流程）✓
- [ ] NFR 可测（均映射到 AC verify 段）✓
- [ ] v1/v2/out 明确 ✓
