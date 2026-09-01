# REVIEW — correction-hygiene-state-guard

> 审查日期：2026-09-01 · 审查人：主 agent（Sisyphus）+ L2 盲审（quick/deepseek-v4-flash）
> 审查范围：git diff（8 tracked 文件）+ 2 个 untracked（test_correction_hygiene.bats 双源 + 本 change spec 产物）

## 第一轮 · Spec 合规审查

| AC | 实现 | 测试覆盖 | 判定 |
|---|---|---|---|
| AC-1 去重 | `correction_file_dedupe()` correction-file.sh（check+field 保最新，白名单类 only） | hygiene T1 + integrity NFR | ✅ |
| AC-2 容量 backstop | `correction_file_trim()`（先去重后 FIFO 保末 10，compliance 不计配额） | hygiene T2 | ✅ |
| AC-3 健康清零 | 33 号 `_fai_clear_whitelist`（合法 JSON+全通过 → 清白名单类；审计行 stderr） | hygiene T3 + smoke S2 | ✅ |
| AC-4 l2-missing 退场 | 29 号 M0 块（IR 含 `## L2 盲审` 或 gate≠both → strip/rm；Gate 3 前置） | hygiene T4a/T4b + smoke | ✅ |
| AC-5 外来让位判定 | 33 号 jq empty 失败 → yield（29 静默 exit 0；31/32/34 保持） | hygiene T5 + integrity NFR | ✅ |
| AC-6 外来清空+note | 33 号外部分支（清白名单 + strip_type + 去重 foreign_state note） | hygiene T6 + smoke S3 | ✅ |
| AC-7 绝不触碰外来文件 | 33 号对 .flow-active 零写路径（grep 证空）；sha256 实测不变 | hygiene T7 + UAT-1 | ✅ |
| AC-8 回归 | make check 四门 764/764（含 10 新用例）+ 双源 diff 一致 | make check 实跑 | ✅ |
| AC-9 chisel_env 场景 | 真实 YAML .flow-active + 真实 50 条 correction → 首轮收敛 50→1 | UAT-1（Phase 5 实测） | ✅ |
| AC-10 compliance 保护 | sk-*/Bearer/ANTHROPIC 0 命中；compliance 字节保留（jq -c 比较） | hygiene T10 + T9 | ✅ |

- 范围蔓延检查：diff 文件 ⊆ TASK write_files（29/33/correction-file.sh/test×2 双源/Makefile[T04 授权]/CONTEXT.md[REQUIREMENT 授权]/specs 产物）。**例外**：README.md +2 行为工作区杂改（非本 change，见 R-1）。
- 架构触碰：无（未动 gate 核心链校验顺序、31/32/34 未改、PRESET_MAP 未改）。

## 第二轮 · 代码质量审查（内置 6 维 · brooks-lint 未装回退路径 B）

- **R1 认知过载** ✅ 无发现 — dedupe/trim/strip_type 各单职责 ≤40 行；33 号 main 经 `_fai_*` helper 化，主流程扁平。
- **R2 变更传播** ✅ 无发现 — 白名单单一源 `CORRECTION_STATE_INTEGRITY_CHECKS`（readonly），33/29/测试均引用之；改 check 名只动一处。
- **R3 知识重复** ✅ 已闭环 — Phase 5 F1（29 M0 内联 jq strip）已修为共享 `correction_file_strip_type`，fallback 内联已删（L2 复核确认零命中）。
- **R4 偶然复杂** ✅ 无发现 — JIT source（29 号）有注释论证（Stop 链常规路径零开销，仅裸跑需要）；fail-open 语义全链一致。
- **R5 依赖混乱** ✅ 无发现 — 29/33 → correction-file.sh 单向依赖，无环。
- **R6 领域扭曲** ✅ 无发现 — foreign_state / whitelist / retirement 术语与 CONTEXT.md 域语言一致。

### 发现清单

**R-1 🟢 Minor · 工作区杂改混入 diff**（R2 变更传播 · Pragmatic Programmer · Dead Code/Dörfler 边界卫生）
- **Symptom**：`git diff README.md` 含 `+// test change 1786860884` `+live-test`（L100-101），非本 change 产物（Phase 2 盲审已标记为 R5）。
- **Source**：Hunt & Thomas · The Pragmatic Programmer · 「Don't Live with Broken Windows」。
- **Consequence**：混入 Phase 7 提交将污染 change 边界，归档后无法追溯该行来源。
- **Remedy**：Phase 7 提交前 `git checkout -- README.md` 还原（本 change 不携带此文件）。

**R-2 🟢 Minor · 29 号 M0 块职责密度**（R1 · Code Complete · 高扇出函数）
- **Symptom**：29 号 M0 块（写入保护 + 退场检测 + JIT source）约 90 行，职责 3 项。
- **Source**：McConnell · Code Complete · 第 7.4 节高内聚。
- **Consequence**：下次触碰 29 号时认知成本上升（已登记 MINOR M10 迁移计划）。
- **Remedy**：M10 已登记（下次触碰 29 时抽 `_l2_missing_lifecycle()` 子函数）。本次不动（刚过 3 轮盲审，重排风险 > 收益）。

## 第三轮 · UI 视觉审查

**跳过声明**：本 change 为 Bash hooks / bats 测试项目，无任何用户可见 UI 文件（.css/.tsx/.html 等 0 命中）。按 flow-review 规则后端项目跳过第三轮。

## 第四轮 · 补充审查

- **4.1 技术债评估**：未命中（非里程碑/季度大版本/重构项目；CONTEXT 技术债段 30 天内更新过）→ 跳过。
- **4.2 跨模型 spot-check**：未命中全部触发条件（无安全/认证改动、无并发/分布式、无 >80 行单一新函数、覆盖率上升非下降）→ 跳过。

## 严重度汇总

| 严重度 | 数量 | 明细 |
|---|---|---|
| 🔴 Critical | 0 | — |
| 🟡 Major | 0 | — |
| 🟢 Minor | 2 | R-1（Phase 7 还原 README）/ R-2（M10 已登记，本次不动） |

## 结论

**Verdict: pass** — 10/10 AC 实现且有测试覆盖；无范围蔓延（README 杂改已定位处理路径）；6 维零命中；无 Critical/Major。可进入 INTEGRATION。
