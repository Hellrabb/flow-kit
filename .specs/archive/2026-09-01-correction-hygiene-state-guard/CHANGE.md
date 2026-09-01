# CHANGE · correction-hygiene-state-guard

## Why（为什么做）

chisel_env 现场调查（2026-08-31）发现 flow-kit stop-hook 链的两个真实缺陷，造成「L2 似乎没拉起」的误判表象：

1. **correction 只增不清**：`33-flow-active-integrity.sh::_fai_append_violation`（L249-288，追加语句在 L276）采用读-合并-写模式，只追加永不清除——17 天（2026-08-14 → 2026-08-31）累积 50 条 violation（43 条重复 corrupt_json + 6 条陈旧 artifact_missing + 1 条）；且 `29-independent-review.sh` 写入的 `l2-missing` flag（L24-30）**没有任何设计内清除路径**（对照：L3 的 model-missing 有 `write_model_missing_clear` 退场机制，L2 的 l2-missing 没有；仅靠 28 号 compliance 轮换覆写的巧合清场，非确定性机制）。陈旧 correction 让每次查看都像「L2 缺失」。
2. **外来状态文件静默短路 + 刷屏**：chisel_env 运行时实测 `.flow-active` 为 **YAML 格式**（与 chisel-skill 自身文档 `SKILL.md:142` 声明的「JSON」不一致，实际写入源待 2-design 确认）。flow-kit hook 链（29 号 L38 / 33 号 L25）用 `jq empty` 判定——非 JSON 时 29 号**静默短路**（gate 无声消失，与 2026-08-14 根因 #1「格式不匹配 → gate 静默消失」同构），33 号**每次 Stop 追加一条 corrupt_json**（实测 46 次），stop-hook-report 持续报「JSON 格式无效」。两个系统对同一状态文件的归属没有守卫。

## What（做什么）

- **F1 · correction 卫生**：
  - `_fai_append_violation` 增加去重（同 `check`+`field` 只保留最新一条）与容量上限（violations ≤ 10 条，FIFO 淘汰）——**作用域仅限 state-integrity 类条目**（以 33 号自身写入的 check 名集合界定），compliance 类条目（28 号写入）不参与去重与容量淘汰（沿 ADR-013 compliance 优先精神；数组级条目保留为本 change 新决策）
  - 33 号新增「健康清零」：当 `.flow-active` 为合法 flow-kit JSON 且本轮全部检查通过时，清空 correction 中的 state-integrity 类 violation（corrupt_json / change_id_dangling / **change_id_null_with_dirs** / phase_artifact_missing / pipeline_* / stale_updated_at / token_spent_unmaintained——完整枚举对齐 33 号实际写入的 9 种 check 名）
  - 29号新增 `l2-missing` 退场：确认 IR 文件已含 `## L2 盲审` 段（或 gate 非 both）时清除 l2-missing flag，对齐 `write_model_missing_clear` 既有范式
- **F2 · 外来状态让位守卫**：
  - **33 号**在 `jq empty` 失败时**不再静默追加 corrupt_json**，改为：判定为「非 flow-kit 状态文件」（其他流程系统如 chisel-skill 所有）→ 跳过 pipeline 检查 + **一并清空既有 state-integrity 类 violation**（这些条目源自对非 JSON 文件的误判，外来接管后全部失效；l2-missing / model-missing / compliance 保留）+ correction 写一条**去重的** `foreign-state` note（同 check 只写一次）+ stop-hook-report 提示一次
  - **29 号**在 `jq empty` 失败时保持静默退出（`exit 0` 行为显式化，不写 correction、不参与清空）——外来让位的全部动作归 33 号单一 actor，保证「恰 1 条 note」成立
  - **绝不转换/覆盖/删除外来状态文件**；只有 flow-kit 自己写的 JSON 才受 pipeline 检查管辖

## 影响面

- `flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh`（去重/容量/健康清零/foreign-state yield）
- `flow-kit-bundle/hooks/stop/29-independent-review.sh`（jq 失败 yield 改造 + l2-missing 退场）
- `flow-kit-bundle/hooks/stop/lib/correction-file.sh`（新增共享去重 helper 函数，**不改既有 4 函数签名**，不触发两调用方同步要求）
- 新增 bats：`test/test_correction_hygiene.bats`（去重/容量/健康清零/l2-missing 退场/foreign-state 单条化）+ 双源同步
- 部署面（integration 阶段）：`~/.claude/hooks/stop/` + `~/.config/opencode/hooks/stop/`（CC + opencode 双平台，同 l2l3-cross-platform 先例）

## 范围排除（不做）

- 不支持 YAML 解析/转换（不引 yq/pyyaml 依赖进 hook 链）——外来格式一律让位，不解读
- 不改 chisel-skill 的状态约定，不触碰 chisel_env 仓库任何文件（本 change 只修 flow-kit 分发包 + 运行时部署）
- 不改 `.flow-active` 的 JSON schema
- 不动 gate 核心链语义（independent-review-gate.sh / fk_validate_done_marker / 00-gate.sh）
- 不修 30-ai-analyze.sh 凭证链（不同域，v2 候选维持）
- 不改 31-auto-advance.sh / 32-fallback-guard.sh / 34-archive-commit-check.sh 的 `jq empty || exit 0` 静默跳过——三者是 pipeline 专用模块，外来状态时静默跳过本就是期望行为，不写 foreign-state note（避免多模块每 Stop 重复 note）
- 不重做 l2l3-cross-platform 已交付内容（平台翻转/共享凭证函数等保持不变）

## 例外登记（禁动清单冲突声明 · 仿 cleanup-debt-batch-2026-08 格式）

- **例外（correction-hygiene-state-guard · 2026-08-31）**：`29-independent-review.sh` 允许修改 jq 失败分支（L36-40 yield 改造）与新增 l2-missing 退场逻辑（对齐 `write_model_missing_clear` 范式）——本 change 即以该行为修改对象之一；其余 gate 校验核心链部分（.done 校验、gate 判定语义）保持禁动
- **说明**：`33-flow-active-integrity.sh` 禁动条款为「不应被**无关** change 修改」——本 change 即以 33 号 correction 卫生为主题，属"有关"修改；同条款先例（cleanup-debt-batch 例外）格式登记以保持审计链完整

## 验收线

1. bats 新增用例全绿：去重（同 check+field 收敛为 1 条）、容量（>10 FIFO）、健康清零（合法 JSON + 全通过 → state-integrity 类清空）、l2-missing 退场（IR 含 L2 段 → flag 清除）、foreign-state 单条化（YAML 输入 → 恰好 1 条 foreign-state note，重复 Stop 不增加）
2. 既有全量回归不劣化：bats 全绿（基线 752+）+ make check 四门 + 双源一致
3. chisel_env 场景模拟：YAML .flow-active + 陈旧 correction（50 条）输入 → 新 hook 首轮收敛（state-integrity 类清空 + 恰 1 条 foreign-state note），后续 Stop 零新增

## 风险

- **误清有效 l2-missing**：缓解——仅在确认 IR 文件含 `## L2 盲审` 段或 gate_config 非 both 时清除；清除动作写一行 stderr 审计
- **外来状态误判**（flow-kit 自己的 JSON 被写坏被判为 foreign）：缓解——jq empty 为唯一判据（JSON 语法错误=foreign 处理但 note 文案区分「非 flow-kit 格式或已损坏」）；flow-kit 写入路径全部走 jq，语法损坏概率极低；correction note 保留原始错误供人工判断
- **健康清零过早**（检查通过但当轮仍有其他模块要写 correction）：缓解——33 号清零仅限自己管辖的 state-integrity 类 check 名集合，不碰 l2-missing/model-missing/foreign-state
- **去重/容量误伤 compliance 条目**（violations[] 数组由 28 号 compliance 与 33 号 state-integrity 混写）：缓解——去重与 FIFO 上限仅作用于 state-integrity 类条目（按 check 名集合界定），compliance 条目原样保留（沿 ADR-013 compliance 优先精神；violations[] 数组级条目保留为本 change 新决策，2-design 独立论证）
- **双平台部署漂移**：缓解——integration 阶段 md5 双侧校验（同上 change 流程）

## 架构层影响声明

无项目级架构变更（hook 模块内健壮性修复 + 既有 correction-file 范式延伸），0.4 预检未命中，不走 A-architect。
