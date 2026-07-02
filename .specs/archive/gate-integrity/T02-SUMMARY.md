# T02-SUMMARY · check-gate-sync.sh 追加 gate-config 预设名 set-diff 校验段

- **Change**: gate-integrity
- **Task**: T02（Wave 1 · 并行 · 独立文件）
- **AC**: AC-4（gate-config 预设双源同步 · check-gate-sync 语义 diff 兜底）
- **完成**: 2026-07-02

## 改动清单

| 文件 | 角色 | 改动 |
|---|---|---|
| `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` | 维护源（唯一源）| 追加 `check_gate_config_sync()` 函数 + 调用（+55/-0，纯追加）|
| `flow-kit-bundle/test/test_check_gate_sync.bats` | 新增测试套 | 5 个用例（基线一致 / 注入假预设 / 删真预设 / 英文注释不误报 / 可执行）|
| `.specs/gate-integrity/TASK.md` | 任务定义 | T02 read/write_files 路径修正 + verify 工作目录修正（R7.1）|

运行时 `~/.claude/flow-kit/reference/check-gate-sync.sh` 经 `install.sh --global` 部署同步（L-015 合规）。

## R7.1 边界修正（TASK.md 原路径错误）

TASK.md T02 原列路径 **错误**（实证：`flow-kit-bundle/scripts/` 目录不存在）：

| 字段 | TASK.md 原值（错）| 实证正确值 |
|---|---|---|
| read_files / write_files | `flow-kit-bundle/scripts/check-gate-sync.sh` | `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（CONTEXT.md:96 为准）|
| verify | `cd flow-kit-bundle && npx bats test/test_check_gate_sync.bats` | `npx bats flow-kit-bundle/test/test_check_gate_sync.bats`（从仓库根，测试用 `flow-kit-bundle/` 相对路径）|

## 实现内容（对应 G4 ADR Decision #4 · L2 R3）

1. **追加而非替换**：保留现有 `check_pair()`（4-dev↔flow-dev toll-gate 协议校验，被 `test_quality_baseline.bats` AC-2 依赖），新增 `check_gate_config_sync()` 平行校验段
2. **语义 set-diff（非文本段 marker）**：
   - `extract_skill`：sed 提取 SKILL.md `预设名映射表（PRESET_MAP）` 段 → grep `^[[:space:]]*#[[:space:]]*[a-z][a-z0-9-]*[[:space:]]+→`（**→ 约束**只认 `# name →` 格式，忽略段内英文注释防误报）→ sort -u
   - `extract_bats`：sed 提取 `resolve_gate_config` 的 `case` 分支 → grep `^    [a-z]` → `tr '|' '\n'` 拆别名 → sort -u
   - `diff <(skill) <(bats)` 非空 → ERRORS+=1（计入整脚本 exit 1）
3. **容错**：文件缺失 WARNING 跳过（与 `check_pair` 一致，不 exit 2）

## verify 结果

```
npx bats flow-kit-bundle/test/test_check_gate_sync.bats
→ 1..5  全 ok（0 回归）
  ok 1 check-gate-sync.sh 存在且可执行
  ok 2 基线 SKILL↔bats 预设名一致 → 9 预设
  ok 3 注入假预设（有 →）→ 报漂移 + 列出 fake-preset
  ok 4 删除真预设 design → 报漂移
  ok 5 英文注释（无 →）不误报（不依赖文本段 marker）
```

回归（3 套 47 tests）：**仅 1 not ok = AC-7（pre-existing，见下）**，AC-2 / T01 的 26 tests 全过。

## pre-existing 观察（非 T02 引入 · 超范围记录）

- **AC-7 `test/ ↔ flow-kit-bundle/test/ 一致` pre-existing fail**：两目录早 drift（`test_correction_file.bats`/`test_flow_kit_resume.bats`/`test_stop_report_reminder.bats` 早已 flow-kit-bundle 独有；T01 的 `test_gate_config_presets.bats` 9.9K 也没同步到 test/ 7.9K）。T02 的 `test_check_gate_sync.bats` 遵循 T01 惯例只放 flow-kit-bundle/test/ 源，**未新增 fail 用例**（AC-7 计数不变），属 TASK.md T14"12 预存失败不计"范畴
- **toll-gate 段基线 PCSC 漂移**（4-dev.md=9 行 vs flow-dev/SKILL.md=8 行）：check_pair 既有逻辑报警，非 T02 引入，超 T02 范围

→ 建议 T14 或独立 task 统一处理 test/ 双源同步 + PCSC 行数核对

## 6 维自查（本 task 性质：脚本追加 + 测试，生产 hook 代码未触及）

| 维度 | 结论 |
|---|---|
| 沿用既有抽象（R6.4） | ✅ 复用 `check_pair` 的 ERRORS 累加 + echo 风格 + 文件缺失容错模式 |
| 一致性 | ✅ 与现有 check_pair 输出风格一致（🔍/✅/🔴 emoji + 缩进）|
| 向后兼容 | ✅ 保留 toll-gate 校验（AC-2 不破坏）；现有调用方（make check）行为不变 |
| 边界正确性 | ✅ set-diff 提取逻辑沙箱三重验证（基线 MATCH / 注入假预设 DRIFT / 删真预设 DRIFT / 英文注释不误报）|
| 测试覆盖 | ✅ 5 用例覆盖 done 标准（一致 / 漂移 / 不依赖 marker）|
| 🔴 已修 / 🟡 已记 / 🟢 可省 | 🟢 无 🔴；pre-existing AC-7 drift 已记（超范围）|

## LESSONS 查阅（R1.8）

- **L-014（🟢 active）**：已查阅并应用。`extract_skill` grep 用 `[a-z0-9-]`（连字符末尾安全）+ `[[:space:]]` POSIX 类，避免 `\]` 字符类转义陷阱；sed/grep 正则用单引号包裹（bats 端 `case "$value"` 含 `$` 必须单引号防展开）
- **L-015（🔴 active）**：已查阅并遵守。write_files 仅 `flow-kit-bundle/` 源路径；改完跑 `install.sh --global` 部署；`diff 源 ↔ ~/.claude/ 运行时` = IDENTICAL ✓（check-gate-sync.sh + SKILL.md 复核）
- 无其他 active 条目命中

## 越界检查（R6.5）

```
git diff --stat（T02 范围）：
  flow-kit-bundle/flow-kit/reference/check-gate-sync.sh | 55 ++++++++++++++（纯追加）
  flow-kit-bundle/test/test_check_gate_sync.bats        | 新文件（untracked）
```
- 改动文件 = write_files 列（check-gate-sync.sh 源 + 新测试）+ TASK.md（R7.1 路径修正）
- **0 越界**：未改 toll-gate 校验段 / 其他 task 文件 / hooks / 禁动清单（package-flow-kit.sh / tar.gz / .gitignore）
- SKILL.md fake-preset 计数 = 0（测试 teardown 还原成功，无污染）

## L-015 合规说明

- **维护源**：`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`
- **部署**：`bash flow-kit-bundle/install.sh --global`（install_core 部署 reference/）
- **验证**：`diff 维护源 ~/.claude/flow-kit/reference/check-gate-sync.sh` → **IDENTICAL** ✅

## 未做（范围外 · 后续 task）

- test/ 双源同步（T14 / 独立 task）
- toll-gate 段 PCSC 行数核对（超 T02）
- hook 阶段判定扩 3/5/7（T05-T11）
