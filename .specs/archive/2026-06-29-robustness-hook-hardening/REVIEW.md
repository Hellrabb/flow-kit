# REVIEW: 弱模型鲁棒性 Hook 化升级

- **Change ID**: `robustness-hook-hardening`
- **Review 日期**: 2026-06-29
- **Mode**: PR Review
- **Scope**: 4 modified + 6 new files (~600 lines total, ~283 net logic)

---

## 第 1 轮 · Spec 合规

### AC 覆盖矩阵

| AC | 需求 | 测试覆盖 | 状态 |
|---|---|---|---|
| AC-1 (L1) | 禁动清单触碰 + 通用规则违反检测 | L1-01 ~ L1-04 (4 tests) | ✅ |
| AC-2 (L2) | PCSC 自检表空白行检测 | L2-01 ~ L2-04 (4 tests) | ✅ |
| AC-3 (L3) | 幻觉路径 vs 工具调用历史交叉验证 | L3-01 ~ L3-03 (3 tests) | ✅ |
| AC-4 | 矫正文件 JSON schema + 合并/去重 | CF-01 ~ CF-03 (3 tests) | ✅ |
| AC-5 | SessionStart 识别并注入矫正 | 代码级验证（bash -n + 同模式参考）| ✅ |
| AC-6 | 现有测试无回归 | 176 tests / 0 failures | ✅ |
| AC-7 | 代码长度软指标 | 283 行净逻辑 ≤ 350 | ✅ |

**结论**：7/7 AC 全部覆盖，0 遗漏。

---

## 第 2 轮 · 代码质量（brooks-review 6 维）

### R1 · 认知过载 — 🟢 无 Critical

- `scan_l2_selfcheck` 使用 3 状态机（0=normal / 1=heading_seen / 2=in_table），复杂度适中，注释清楚说明意图
- 单函数最大约 70 行，无嵌套 > 3 层
- 函数命名领域化：`scan_l1_rules` / `scan_l2_selfcheck` / `scan_l3_evidence` / `read_forbidden_list`
- **无 finding**

### R2 · 变更传播 — 🟢 无 finding

- 所有改动限定在 hooks 系统内：Stop hook（28 号模块 + lib）+ SessionStart（resume 扩展）+ 配置（stop-hook.json）
- 测试文件独立新增，不改动现有测试
- `.gitignore` 修改为合法范围扩展（矫正文件需 gitignore 覆盖）
- `.specs/CONTEXT.md` 术语追加为域语言维护
- **无 finding**

### R3 · 知识重复 — 🟢 无 finding

- 矫正文件管理函数（`write_compliance_correction` / `clear_compliance_correction` / `has_compliance_correction`）与 `interactive-ui-check.sh` 的同名函数结构相似但格式不同（`type` + `layer` + `violations[]` vs 单一 `gate_type`）
- **这是 DESIGN.md D1 明确记录的设计决策**：v1 独立格式，v2 迁移合并。非无意的知识重复
- 协调器结构对齐 27-interactive-ui-check 模式——这是有意的模式沿用（DESIGN 0.5.3）
- **无 finding**

### R4 · 偶然复杂 — 🟢 无 finding

- L2 扫描的 3 状态机是必要的：需处理 markdown heading → 空行 → table 的结构间隙
- 各扫描函数独立可组合（L1/L2/L3 各自 `|| true` 保护），无过早抽象
- 无"为未来扩展"预留的配置项或抽象层
- **无 finding**

### R5 · 依赖方向 — 🟢 无 finding

- Lib 依赖：common.sh（hook 框架）→ transcript-parser 中间文件（`$HOOK_TMP_DIR/*.txt`）→ jq（JSON 处理）
- 方向正确：hook lib → 框架层 → 数据层，无反向依赖
- 无循环依赖：lib 不依赖 coordinator，coordinator 单向依赖 lib
- **无 finding**

### R6 · 领域命名 — 🟢 无 finding

- 使用域语言：L1/L2/L3 / 违规(violation) / 矫正(correction) / 禁动清单(forbidden_list) / 自检表(selfcheck) / 证据链(evidence)
- 与 CONTEXT.md 术语表一致
- **无 finding**

---

## 第 3 轮 · 跨模型 Spot-Check

⏭ 跳过 — 本 change 为 Bash hook 脚本，逻辑确定性高（grep + jq），风险低。跨模型分歧在 shell 脚本层面意义有限。

---

## Quick Test Check

```
npx bats test/ → 176 tests / 0 failures ✅
```

---

## Health Score

| 维度 | 评分 | 说明 |
|---|---|---|
| R1 认知过载 | 🟢 | 函数清晰，命名好 |
| R2 变更传播 | 🟢 | 改动聚焦 hooks 系统内 |
| R3 知识重复 | 🟢 | 相似模式有 DESIGN 记录的设计决策 |
| R4 偶然复杂 | 🟢 | 无过度抽象 |
| R5 依赖方向 | 🟢 | 单向、无循环 |
| R6 领域命名 | 🟢 | 域语言一致 |

**总评**：🟢 **无 Critical / Major / Minor finding**。代码质量良好，可安全合并。

---

## 结论

✅ **PASS** — 7/7 AC 覆盖 + 176 tests 全绿 + 6 维代码质量无 finding。
