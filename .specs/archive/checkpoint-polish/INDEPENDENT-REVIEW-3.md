# 独立审查 · 阶段 3

## L2 盲审

### 🟡 R1 · AC-3 全量回归验证无对应 task verify：`npx bats test/` 未出现在任何任务的可机器执行 verify 中

**Symptom（症状）**：TASK.md 共 5 个任务（T01-T05），其 verify 链为：T01 `bash -n`、T02 `bash -n`、T03 `npx bats test/test_resume_banner.bats`、T04 `grep -c` 计数、T05 `make test-sync && make check-test-sync`。所有 verify 均可机器执行，但没有一条执行全量测试套件 `npx bats test/`（或等效的 `make test`）。REQUIREMENT.md AC-3 明确要求"`npx bats test/` 退出码 0"作为 BW01 重构后回归证明。

**Source（源头）**：REQUIREMENT.md AC-3："Given BW01 重构完成 / When 运行 `npx bats test/` / Then 全量 bats 测试 0 fail（与重构前一致）"。阶段 3 审查准则："所有 AC 是否有对应 task？"

**Consequence（后果）**：T02 修改 `flow-kit-resume.sh` 后仅通过语法检查（`bash -n`），未触发任何实际执行路径。若 T02 引入运行时 bug（如 source 路径错误、函数调用参数传递错误导致 banner 输出异常），`bash -n` 不会捕获，T03 的单元测试（仅覆盖 `build_resume_banner()` 独立调用）也不一定捕获——因为 T03 不测试 `flow-kit-resume.sh` 的集成行为。全量回归的缺失意味着 BW01 的集成缺陷会穿过 task phase，直到后续 INTEGRATION 阶段才暴露，增加返工成本。

**Remedy（修补）**：在 T03 的 `<verify>` 末尾追加全量回归调用：
```
npx bats test/test_resume_banner.bats --formatter tap && npx bats test/ --formatter tap | tail -1 | grep -q '0 failures' && echo "✅ 全量回归通过"
```
或者将全量回归作为 T02 的 verify 替代现有 `bash -n`-only 验证（语法检查可作为 verify 第一段，全量 bats 作为第二段）。后者更合理，因为 T02 是 BW01 的最终集成任务，其 done 意味着 BW01 整体完成。

---

### 🟡 R2 · AC-1 逐字符一致性验证被降级为"手动 diff"：T02 verify 仅做语法检查，不执行输出对比

**Symptom（症状）**：TASK.md T02 `<done>` 写明"banner 输出与重构前逐字符一致（AC-1 手动 diff 验证）"，但 T02 `<verify>` 仅为 `bash -n flow-kit-bundle/hooks/session-start/flow-kit-resume.sh && echo "✅ syntax OK"`。AC-1 要求的 `diff <(old) <(new)` 逐字符对比被标记为"手动"，未转化为可机器执行的 verify 命令。

**Source（源头）**：REQUIREMENT.md AC-1："SessionStart hook 输出的 banner **逐字符**与重构前一致 / 验证方式: 运行重构前与重构后版本 `diff` 比较二者 stdout"。阶段 3 审查准则："每条 verify 是否可机器执行（非'人工确认'空话）？"——`done` 中的"手动 diff"正是此类空话。

**Consequence（后果）**：即使 T02 的 `bash -n` 通过且 T03 的 bats 测试通过，banner 输出仍可能存在细微差异（如多余空行、宽度填充不一致、字段顺序变化）。T03 的测试断言字段"存在性"而非"逐字符一致"，不覆盖格式精度。若 SessionStart hook 的下游消费者（Claude Code 会话恢复 UI）对 banner 格式敏感，差异可能导致渲染异常。

**Remedy（修补）**：T02 `<verify>` 改为包含实际输出对比（构造一个统一的 `.flow-active` fixture，跑旧版 `flow-kit-resume.sh.orig` 和新版各一次，diff 二者 stdout）：
```bash
# 前置条件：T01 已完成（保留旧版 flow-kit-resume.sh 的 git 副本）
cp flow-kit-bundle/hooks/session-start/flow-kit-resume.sh /tmp/resume.old
# ... T02 完成修改 ...
# verify:
bash -n flow-kit-bundle/hooks/session-start/flow-kit-resume.sh || exit 1
# 使用同一 fixture 对比新旧输出
diff <(bash /tmp/resume.old) <(bash flow-kit-bundle/hooks/session-start/flow-kit-resume.sh) &&
  echo "✅ AC-1: banner 逐字符一致"
```
若 fixture 构造复杂（需模拟 `.flow-active` 上下文），则最小实现为：T03 的 verify 中增加一条测试专门做 `diff` 对比（在 bats 中用 `run` 捕获新旧输出并断言相等）。

---

### 🟡 R3 · AC-5 条目数量守恒未入 T04 verify 链：verify 只输出最终计数，不做前后对比

**Symptom（症状）**：TASK.md T04 `<verify>` 为：
```
grep -c '^| 日期 | Change ID | 摘要 | LESSONS |$' .specs/CHANGELOG.md | xargs test 0 -eq && grep -c '^| 202[0-9]' .specs/CHANGELOG.md && echo "✅ CHANGELOG format unified"
```
第一个 `grep -c` 验证独立表头行 count == 0（AC-4 已覆盖）。第二个 `grep -c '^| 202[0-9]'` 仅输出最终条目数到 stdout，用作布尔表达式（非零即 pass），**未与重构前条目数做相等性比较**。AC-5 要求"条目数量不变 / `grep -c '^| 202[0-9]'` 前后一致"，但前后对比仅在 T04 `<action>` 第 5 步为人工检查（"验证 grep -c ... 前后条目数一致"），不在 verify 中。

**Source（源头）**：REQUIREMENT.md AC-5："`grep -c '^| 202[0-9]' .specs/CHANGELOG.md` 前后一致"。阶段 3 审查准则：verify 应可机器执行。

**Consequence（后果）**：若 T04 的格式统一操作不慎删除条目行（如 sed 表达式过宽误匹配），verify 会通过——只要仍有至少一条 `^| 202[0-9]` 记录即可（`grep -c` 返回非零则 `&&` 链通过）。条目丢失不会被自动检测，需依赖开发者人工比对数数，人工遗漏风险真实存在（DESIGN.md R2 亦将此列为已知风险）。

**Remedy（修补）**：T04 `<verify>` 改为先快照重构前条目数再对比：
```bash
BEFORE=$(grep -c '^| 202[0-9]' .specs/CHANGELOG.md.bak 2>/dev/null || grep -c '^| 202[0-9]' .specs/CHANGELOG.md)
# T04 执行...
AFTER=$(grep -c '^| 202[0-9]' .specs/CHANGELOG.md)
HEADER_COUNT=$(grep -c '^| 日期 | Change ID | 摘要 | LESSONS |$' .specs/CHANGELOG.md)
test "$HEADER_COUNT" -eq 0 && test "$BEFORE" -eq "$AFTER" && echo "✅ CHANGELOG format unified (${AFTER} entries, no header)"
```
需要 T04 `<action>` 第 1 步（备份到 `.bak`）在 verify 前完成。

---

### 🟢 R4 · T01/T02 done 条件含非机器验证声明："不产生副作用"/"功能不退化"不在 verify 中

**Symptom（症状）**：T01 `<done>` 声明"可从 shell source 且不产生副作用"；T02 `<done>` 声明"SessionStart hook 功能不退化"。两者均不在各自 `<verify>` 中体现——T01 verify 仅 `bash -n`，T02 verify 仅 `bash -n`。

**Source（源头）**：阶段 3 审查准则要求 verify 可机器执行。done 条件作为"完成定义"允许包含描述性声明，但核心功能验证应进入 verify 链。

**Consequence（后果）**：低影响。T03 的 bats 测试间接验证了 source 无副作用（setup 中 source banner.sh 后文件系统无污染）和 banner 函数行为正确。若未来 T03 被跳过或失败，这些声明就成为无机器背书的空断言。

**Remedy（修补）**：可选改进：(a) T01 verify 追加 `source flow-kit-bundle/hooks/stop/lib/banner.sh && declare -f build_resume_banner >/dev/null && echo "✅ sourceable"`；(b) 将 T02 done 中的"功能不退化"映射到 T03 verify 的全量回归（见 R1 remedy）。

---

### 🟢 R5 · T05 verify 不验证 check-test-sync 错误提示文本更新

**Symptom（症状）**：TASK.md T05 `<action>` 第 3 步要求"check-test-sync 的报错信息追加提示 `请运行 make test-sync`"。T05 `<verify>` 为 `make test-sync && make check-test-sync && echo "✅ test-sync OK"`——仅验证 target 存在且可执行，不验证错误消息文本是否已更新。

**Source（源头）**：action 中描述的变更未全部映射到 verify。

**Consequence（后果）**：低影响。若开发者遗漏第 3 步，`make check-test-sync` 仍能检测不同步并以非零退出（行为正确），只是错误消息不含修复提示。对用户体验有微弱影响——用户看到不同步报错但不知道运行 `make test-sync` 修复。AC-7 要求"在 stderr 提示用户运行 `make test-sync`"，所以理论上这是一个 AC 覆盖缺口，但 T05 verify 可通过（`make check-test-sync` 本身仍以非零退出）。

**Remedy（修补）**：T05 `<verify>` 追加一段文本检查：
```bash
make test-sync && ! make check-test-sync 2>&1 | grep -q 'make test-sync' && echo "✅ check-test-sync prompts make test-sync" || { echo "❌ error message missing"; exit 1; }
```
注意：`make check-test-sync` 在同步后应退出 0（一致），此时无错误消息。需先制造不一致来测试错误消息。或者改为：grep Makefile 中 check-test-sync recipe 是否含 `make test-sync` 字符串。

---

**Verdict**: pass

不存在 🔴 Critical 发现。三条 🟡 Major 集中在 verify 覆盖缺口：AC-3 全量回归无人认领（R1）、AC-1 逐字符 diff 被降级为手动（R2）、AC-5 计数守恒未入 verify 链（R3）。两条 🟢 Minor 涉及 done 条件口头支票（R4）和错误消息验证遗漏（R5）。

任务分解的整体结构质量良好：5 个任务按 BW01/02/03 清晰划分，双波次编排（Wave 1 = T01+T04+T05 可并行，Wave 2 = T02+T03 可并行且正确声明了 T01 依赖），依赖图无环，`read_files`/`write_files` 约束到位，所有 write_files 均在 DESIGN.md 和 CONTEXT.md 禁动清单之外。所有 verify 命令均可机器执行（无"人工审查"作为 verify 本身）。改进重点在将 AC-level 的验证承诺下沉为 task-level 的可执行 verify。
