# T01-SUMMARY · AC-4 PRESET_MAP 扩展 + all 预设 + 数字映射 3/5/7

- **Change**: gate-integrity
- **Task**: T01（Wave 1 · 并行 · 独立文件）
- **AC**: AC-4（gate-config 预设 / 数字映射扩展，默认 off）
- **完成**: 2026-07-02

## 改动清单

| 文件 | 角色 | 改动 |
|---|---|---|
| `flow-kit-bundle/skills/flow/SKILL.md` | 维护源（源①） | PRESET_MAP 注释表 + 数字映射注释（+2/-1） |
| `flow-kit-bundle/test/test_gate_config_presets.bats` | 测试镜像（源③） | resolve_gate_config 镜像 + 用例（+58/-4） |
| `.specs/gate-integrity/TASK.md` | 任务定义 | T01 read/write_files + action + done 边界修正（R7.1） |

运行时 `~/.claude/skills/flow/SKILL.md` 经 `install.sh --global` 部署同步（非手动改，L-015 合规）。

## 实现内容（对应 G4 ADR Decision #1-3 + AC-4）

1. **数字映射扩展**：`3→3-task` / `5→5-test` / `7→7-integration`（1/2/6 不变）
2. **新增 `all` 预设**：`{1-requirement, 2-design, 3-task, 5-test, 6-review, 7-integration}` 全 6 阶段 independent
3. **`full` 预设不变**：仍只含 1/2/6（默认 off 3/5/7，向后兼容）
4. **双源同步**：SKILL.md 规格（源①）+ bats resolve_gate_config 镜像（源③）语义一致；check-gate-sync.sh 语义 diff 兜底（T02 范围）

## verify 结果

```
cd flow-kit-bundle && npx bats test/test_gate_config_presets.bats
→ 1..26  全 ok（原 20 + 新增 6，0 回归）
```

新增用例（全绿）：
- #9 AC-4 preset `all` → 6 keys 含 3/5/7
- #10 AC-4 `full` 排除 3/5/7（default off）
- #19 AC-4 numeric `3` → 3-task
- #20 AC-4 numeric `5` → 5-test
- #21 AC-4 numeric `7` → 7-integration
- #22 AC-4 numeric `1,2,3,5,6,7` → 6 keys（= all）

修正用例：#26 invalid numeric `7`→`4`（7 现合法；4-dev 按设计排除，无独立 review 产物）；#11 "all 8 presets"→"all 9 presets"（遍历列表加 `all`）。

## 6 维自查（本 task 性质：规格注释 + 测试镜像，无生产 hook 代码变更）

> 生产 hook 代码（independent-review-gate.sh 等）属 T05-T11 范围，本 task 未触及。6 维聚焦规格/测试维度。

| 维度 | 结论 |
|---|---|
| 沿用既有抽象（R6.4） | ✅ 扩展 resolve_gate_config 既有 case + 数字 case 模式，未另起炉灶 |
| 一致性（四源） | ✅ SKILL.md 规格 ↔ bats 镜像 ↔ G4 ADR ↔ AC-4 四源语义一致 |
| 向后兼容 | ✅ `full` 不变；既有 goal（含 full）行为不破坏 |
| 边界正确性 | ✅ 0/4 排除（无独立 review 产物）；3/5/7 含；invalid numeric 4 仍拒 |
| 测试覆盖 | ✅ 6 新用例覆盖 all / full 排除 / 数字 3/5/7 / 1,2,3,5,6,7；invalid 4 |
| 🔴 已修 / 🟡 已记 / 🟢 可省 | 🟢 无 🔴：规格 + 测试改动，无生产代码缺陷 |

## LESSONS 查阅（R1.8）

- **L-015（🔴 active）**：已查阅。本 task write_files 原列运行时副本 `~/.claude/skills/flow/SKILL.md`，违反 L-015。**方案 A 修正**：write_files 改为只写维护源 `flow-kit-bundle/skills/flow/SKILL.md`，运行时由 install.sh 部署同步。与 L-015 原案（improve-independent-review 直接改运行时）的差异：**动手前主动检出冲突 → 改源不改进运行时**，未重蹈覆辙。TASK.md T01 边界已同步修正（R7.1）。
- 无其他 active 条目命中。

## 越界检查（R6.5）

```
git diff --stat（T01 范围）：
  flow-kit-bundle/skills/flow/SKILL.md               | 3 +-
  flow-kit-bundle/test/test_gate_config_presets.bats | 62 +++++--
```
- 改动文件 = write_files 列（SKILL.md 维护源 + test bats）+ TASK.md（R7.1 授权边界修正，untracked）
- **0 越界**：未改 hooks / 其他 task 文件 / 其他 skill
- 运行时 `~/.claude/skills/flow/SKILL.md` 经 install.sh 部署（非 git 仓库内手动改）

## L-015 合规说明

- **维护源**：`flow-kit-bundle/skills/flow/SKILL.md`（唯一 SKILL 写入点）
- **部署**：`bash flow-kit-bundle/install.sh --global`（`install_skills` 函数 lib/install_skills.sh:11 显式含 `skills/flow/`）
- **验证**：`diff 维护源 ~/.claude/skills/flow/SKILL.md` → **完全一致** ✅
- **运行时抽查**：PRESET_MAP 含 all + 数字 3/5/7（:136 / :145）

## 未做（范围外 · 后续 task）

- check-gate-sync.sh 重写为 set-diff（T02）
- hook 阶段判定扩 3/5/7（T05-T11）
- pipeline-gates.md 全链扩展（T03）
