# T01-SUMMARY: /flow goal CLI 扩展

- **Task**: T01 — `/flow goal` CLI 扩展：--pipeline + --gate-config + pipeline 展示
- **Change ID**: pipeline-goal
- **完成时间**: 2026-06-18T15:20:00+08:00

---

## 做了什么

修改 `flow-kit-bundle/skills/flow/SKILL.md`，扩展 `/flow goal` 子命令：

1. **JSON schema 扩展**（实现细节段）：goal 新增 7 个 pipeline 字段：`scope` / `current_phase` / `phases_done` / `gates` / `gate_config` / `auto_advance` / `phase_sub_goals`

2. **`/flow goal <条件> --pipeline`**：新增 `--pipeline` flag，写入完整 pipeline goal schema（scope="pipeline", current_phase="4", phases_done=[], gates={3 toll-gates}, gate_config={}, auto_advance=false, phase_sub_goals={}）

3. **`/flow goal <条件> --pipeline --gate-config '<JSON>'`**：新增 `--gate-config` 参数，先 `jq empty` 验证 JSON 有效性，再用 `--argjson` 合并写入 gate_config

4. **`/flow goal`（无参数）展示扩展**：
   - Pipeline goal → 展示进度条（4✅→5🔄→6⏸→7⏸）+ toll-gate 状态 + auto_advance
   - 单阶段 goal → 保持原有展示不变（向后兼容）

5. **`/flow goal clear`**：行为不变（goal=null 清除所有字段）

6. **`/flow doctor`**：goal schema 验证扩展至 pipeline 字段

## 改了哪些文件

| 文件 | 变更 |
|---|---|
| `flow-kit-bundle/skills/flow/SKILL.md` | 修改 4 处：JSON schema + `/flow goal` 无参数 + `/flow goal <条件>` + `/flow doctor` |

## verify 输出

```
=== Test: --pipeline flag writes correct schema ===
{ "scope": "pipeline", "current_phase": "4", "phases_done_len": 0, "gate_4_5": "pending", "auto_advance": false }

=== Test: --gate-config jq expression ===
{ "gate_config_6_review_perf": "critical", "gate_config_6_review_lint": "warn" }

=== Test: backward compat (no --pipeline, old format) ===
{ "scope": "phase", "condition": "pnpm test" }
```

全部通过 ✅

## 6 维自查

- **R1 认知过载**：N/A（纯配置/文档改动，无函数逻辑）
- **R2 变更传播**：仅修改 SKILL.md goal 相关 4 段，未越界
- **R3 知识重复**：pipeline goal 的 jq 写入复用既有的 `--arg` + `.tmp + mv` 原子模式
- **R4 偶然复杂**：`--gate-config` 的 `--argjson` 是 jq 原生能力，无过度工程
- **R5 依赖混乱**：N/A（Bash skill 文件，无 import 依赖）
- **R6 领域扭曲**：gate key 使用 `4→5`（Unicode 箭头），语义清晰

## 沿用既有抽象 grep（R6.4）

- jq 原子写入：沿用 `.tmp && mv` 模式（SKILL.md line 64/73/95/106/118）→ 沿用 ✅
- CC 版本检测：沿用 `claude --version 2>/dev/null | head -1`（SKILL.md line 98）→ 沿用 ✅
- jq bracket 引用：LESSONS L-011 警告过连字符 key 问题，gate key `4→5` 用 `.["4→5"]` 语法 → 已遵循 ✅

## 越界检查（R6.5）

- TASK write_files：`flow-kit-bundle/skills/flow/SKILL.md`
- 实际 diff 涉及：仅该文件（CONTEXT.md 来自 phase 1，integrate-goal-command 删除是既有 git 状态）
- 越界：0 ✅
