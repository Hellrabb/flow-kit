# ADR-G4: gate-config 3/5/7 扩展 + `all` 预设 + check-gate-sync 扩展规格

- **Status**: Proposed（gate-integrity change · 2-design）
- **Date**: 2026-07-01 · 修订 2026-07-02（L2 R3 check-gate-sync 规格 + R6 措辞中性化）
- **关联 AC**: AC-4（gate-config 预设扩展）

## Context

`/flow skill` 的 PRESET_MAP（`SKILL.md:132-150`）数字映射仅 `1/2/6`，预设 `full` 仅含 1/2/6。要支持用户显式开启 3/5/7 的 L2 独立审查，需扩展映射 + 新增预设。

REQUIREMENT 锁定决策 [2026-07-01]：3/5/7 **默认 off**（`full` 不含 3/5/7，避免 pipeline token 成本爆炸），由用户显式开。

## Decision

1. **数字映射扩展**：`3→"3-task"` `5→"5-test"` `7→"7-integration"`（现有 1/2/6 不变）
2. **新增 `all` 预设**：`{"1-requirement","2-design","3-task","5-test","6-review","7-integration"}` 全 6 阶段 independent。`all` = 所有**可独立审查**的阶段（1/2/3/5/6/7，含 7-integration）；0-change（提案）/ 4-dev（执行）本质无独立 review 产物，按设计排除
3. **`full` 预设不变**：仍只含 1/2/6（默认 off 3/5/7 语义，向后兼容）
4. **双源同步 + check-gate-sync.sh 扩展规格**（L2 R3）：`SKILL.md`（指令文档 · 源 ①）+ `test_gate_config_presets.bats::resolve_gate_config()`（bash 镜像 · 源 ③）两处维护。`check-gate-sync.sh` 扩展为**语义一致性**校验（非文本段 diff）：
   ```
   # 伪代码
   skill_presets=$(extract_preset_names SKILL.md PRESET_MAP)        # grep 提取 key 集合
   bats_presets=$(extract_supported_presets test_gate_config_presets.bats resolve_gate_config)
   diff <(sort "$skill_presets") <(sort "$bats_presets") || exit 1   # 集合不等则报错
   ```

## Consequences

- **正**：用户可用 `all` 或 `1,2,3,5,6,7` 显式开 3/5/7；`full` 行为不变（向后兼容现有 goal）；数字简写统一覆盖全 6 阶段；check-gate-sync 语义 diff 能抓"SKILL.md 加预设但 bats 镜像没跟"的漂移
- **负**：PRESET_MAP 双源（SKILL.md 指令 + bats 镜像）需人工保持同步（R4），靠 check-gate-sync.sh 语义 diff 兜底
- **后续**：新增预设需改两处 + 加 bats 单测 + 验证 check-gate-sync 通过

---

> Review 回应备注：本 ADR 早期版本 `all` 预设曾被 L3（修订前 DESIGN）误判为"漏掉 7-integration"。实际 Decision#2 集合本就含 7-integration（1/2/3/5/6/7）。该误判已记录于 `INDEPENDENT-REVIEW-2.md` 主 agent 回应段，决策正文保持中性陈述（L2 R6）。
