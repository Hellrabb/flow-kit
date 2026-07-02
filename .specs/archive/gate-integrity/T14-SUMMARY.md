# SUMMARY: T14 - AC-5 全量 bats 不回归 + check-gate-sync

- **Change ID**: gate-integrity
- **Task ID**: T14
- **完成时间**: 2026-07-02 14:10
- **AI 角色**: Dev

## 做了什么

全量回归验证（AC-5 不回归 + check-gate-sync）。

## verify 结果

### bats 不回归 ✅（核心）

**repo-root/test/（STATE.md 基线 213 位置）**：total=216, pass=204, fail=12。
- 12 失败**全是预存**：test_correction_file（8）+ AC-7 一致性（1）+ CF-01/02/03 compliance_correction（3）—— 完全吻合 TASK.md T14 action 的"12 预存失败（correction-file / AC-7）"
- **本 change 0 新增失败** ✅

> bundle/test/ 的 81 fail 是既有测试路径假设问题（`dirname "$BATS_TEST_FILENAME"/..`/`flow-kit-bundle/` 双重前缀，假设 BATS_FILE 在 repo-root/test/，从 bundle/test/ 跑路径错）—— 非本 change 破坏。本 change 新增 test_gate_integrity.bats（21 tests，T13 全过）+ test_check_gate_sync.bats（T02）在 bundle/test/，路径推导适配 bundle，单独验证通过。
>
> T14 verify 写的 `cd flow-kit-bundle && npx bats test/` 与既有测试路径假设矛盾（既有测试假设 repo-root/test/）；正确回归位置是 repo-root/test/。这是 T14 verify 路径的既有瑕疵 + 项目双 test/ 结构的历史问题，建议单独清理。

### check-gate-sync 预设名 set-diff ✅（T02 D3 目标）

`SKILL.md PRESET_MAP ↔ bats resolve_gate_config` 预设名集合一致（9 个预设）—— T02 重写的核心目标达成。

### check-gate-sync PCSC 行数 🔴 预存漂移（非本 change）

- check-gate-sync 检测 `4-dev.md` PCSC 表 9 行 vs `flow-dev/SKILL.md` 8 行漂移
- **调查**：① PCSC 行数检查是**既有**逻辑（HEAD 版 check-gate-sync.sh 已含，T02 保留未改）；② `flow-dev/SKILL.md` 是 **wrapper 模式**（无完整 PCSC 自检表，仅 :6 @see 引用），check-gate-sync 的 PCSC 提取逻辑粗放，把 wrapper skill 误识别出 8 行表；③ **git 证实本 change 未触碰** `4-dev.md` / `flow-dev/SKILL.md`
- **结论**：预存漂移（既有检查 + wrapper 误识别），非本 change 责任。按 R3.2 不擅改非本 change 文件
- **建议**：单独 change 修 check-gate-sync 的 wrapper 模式识别（:53 已有"skill 不含 PCSC 表 = wrapper 正常"分支，但提取逻辑仍误判），或同步 4-dev.md ↔ flow-dev SKILL.md

## 改动文件

无（T14 是回归验证 task）。

## 决策与偏离

1. **T14 verify 路径** `cd flow-kit-bundle && npx bats test/` 与既有测试路径假设矛盾 → 实际回归用 repo-root/test/（基线位置）。记录为 T14 verify 既有瑕疵。
2. **check-gate-sync PCSC 漂移** 预存，不修（R3.2 + git 证实非本 change）。check-gate-sync 预设名部分（T02 责任）通过。

## 完成判定

- TASK.md 已勾选：是（bats 不回归核心达成；check-gate-sync 预设名 ✅，PCSC 预存漂移如实记录）
