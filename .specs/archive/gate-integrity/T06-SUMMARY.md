# SUMMARY: T06 - fk_validate_done_marker 两层时机校验（D1/D5/G1）

- **Change ID**: gate-integrity
- **Task ID**: T06
- **完成时间**: 2026-07-02 11:40
- **AI 角色**: Dev

---

## 做了什么（一段话）

在 `flow-kit-artifacts.sh` 新建 `fk_validate_done_marker <done_path> <phase> <change_id> <tier>`（tier=write|transition）+ helper `_fk_done_kvp`，实现 G1 Decision 2 的 4 层校验 + phases_done 短路：**Tier 1**（元数据快校验，不依赖下游产物）= phases_done 短路（D1/R11 历史兜底）→ T1 非空（挡①）→ T2 KVP（phase/change_id/written_by，挡②）；**Tier 2**（transition 后置）= T3 D7 握手锚点（`.flow-active.independent-review` written_by=stop-hook-29 + phase 匹配 + verdict 与 .done L3_verdict 一致，挡③+⑤-L3）→ T3b session_id 跨会话（挡④）→ T4 L2_verdict 与 INDEPENDENT-REVIEW-`<phase>`.md 比对（挡⑤-L2，best-effort）。全链 fail-close（D9 初步：jq/解析异常 → return 1 deny；T10 强化分段）。函数已建，**gate.sh 把 `[ -f ]` 换成调用本函数的接线不在 T06 write_files，留 T10**（fail 策略分段时一并接入）。

## ⚠️ A 决策记录（死锁解法 · 用户离键盘时 AI 最佳判断）

T05 发现的死锁（G1 T3 要求 29号 L3 握手，但 29号 artifact case 无 3/5/7 分支 → L3 跑不出 → 死锁），向用户提了 A/B/C 三选，**用户 60s 未响应（可能离键盘）**。按系统指示用最佳判断继续：

**选 A（扩 29号 artifact case 到 3/5/7）**，理由：
1. **"gate 全保留"精神**：B（T3 对 3/5/7 降级）弱化独立校验，与用户选的"gate 全保留"矛盾；A 让 3/5/7 走完整 L2+L3 不弱化
2. **change 目标**：US-2/AC-3 要 3/5/7"真接入"，A 让 L3 真跑出（AC-6 修 L3 机制即为此）
3. **架构统一**：3/5/7 与 1/2/6 同构（L2+L3），无特殊分支
4. **时序可行**：T06 写校验函数（T3 要求握手）→ T08 扩 29号 artifact case（让 3/5/7 L3 真跑出）。当前 change gate_config 只含 1/2/6，Wave 2 中途不死锁

**A 的范围影响**：T06 本身不扩范围（fk_validate_done_marker 在 artifacts.sh，T3 对全 6 阶段一致要求握手，不为 3/5/7 特殊处理）。扩 29号 artifact case 的实质改动落在 **T08**（T08 本就改 29号），已更新 T08 task description。**稍后用户回来可重新确认 A/B/C**。

## 改动文件

| 文件 | 性质 | 说明 |
|---|---|---|
| `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh` | 修改 | 新增 `fk_validate_done_marker`（~60 行）+ `_fk_done_kvp` helper，插入 fk_independent_review_gate_active 之后 |

## verify 输出（必填）

```text
# T06 verify（TASK.md 原命令）
$ bash -c 'source hooks/stop/lib/flow-kit-artifacts.sh 2>/dev/null; type fk_validate_done_marker'
✅ fk_validate_done_marker 已定义

# bash -n 语法
✅ 语法 OK

# 7 个核心逻辑测试（PROJECT_ROOT=gate-integrity 项目）
  T1 phases_done 短路(phase=1, 历史 main-agent .done): exit=0 (期望0=有效) ✅
  T2 空文件 Tier1: exit=1 (期望1=deny) ✅
  T3 KVP phase≠6: exit=1 ✅
  T4 KVP change_id≠: exit=1 ✅
  T5 Tier2 无握手(transition): exit=1 ✅
  T6 tier=write 只 Tier1: exit=0 (期望0=有效) ✅
  T7 .done 不存在: exit=1 ✅

# 部署 + L-015
$ install.sh --global --user --no-skills --no-brooks --no-brooks-tools
✅ artifacts.sh: 源=运行时一致

# 不回归
$ npx bats test/test_stop_chain.bats → 13 passed, 0 failed
```

## 6 维自查（生产代码改动 · 内置快查 · T06 新函数故较 T05 详）

- 🟢 **R1 认知过载**：fk_validate_done_marker ~60 行（含注释），**偏 50 行边界**。但属 G1 Decision 2 设计的 4 层线性校验链（tier 参数控制深度），无深嵌套、注释密度高、可读。拆成 _fk_tier1/_fk_tier2 会增间接层而收益有限。**接受**。
- 🟢 **R2 变更传播**：仅改 artifacts.sh（write_files），纯新增函数，不动既有 fk_independent_review_gate_active 等。
- 🟢 **R3 知识重复**：`_fk_done_kvp`（grep KVP from .done）与既有 `fk_flow_field`（jq from .flow-active JSON）载体不同（.done 是 KVP 文本，.flow-active 是 JSON），非重复。
- 🟢 **R4 偶然复杂**：tier 参数（write/transition）是 G1 两层时机的必要设计，无多余扩展点。
- 🟢 **R5 依赖混乱**：依赖 PROJECT_ROOT 全局 + jq——与既有 fk_flow_field / fk_artifact_check 同模式（library 约定调用方设 PROJECT_ROOT）。
- 🟢 **R6 领域扭曲**：phase / change_id / done_path / hs_verdict / l3v 全领域词。

### 已知接受 + 理由

- 🟡→接受 **R1 函数 60 行偏边界**：G1 设计的线性 4 层校验，拆分增间接层无收益。

### 已知小问题

- 🟢 **gate.sh 接线待 T10**：fk_validate_done_marker 已建但 gate.sh:54 仍是 `[ -f "$done_marker" ]`。接线（替换为 fk_validate_done_marker 调用 + fail-close）在 T10 fail 策略分段时做。T06 verify 只要求函数存在（已满足）。
- 🟢 **T4 .md verdict 比对 best-effort**：.md 格式多变时 grep 提取不到 verdict → 不挡（放行）。这是 G1 v1 立场（⑤-L2 v1 靠比对提高成本，v2 加密）。T13 bats 会覆盖明确格式。

## 数据库迁移

N/A。

## 越界检查（必填）

```
✅ 越界检查（R6.5）：
  - TASK write_files：1 项（flow-kit-artifacts.sh）
  - T06 实际引入改动：1 项（新增 fk_validate_done_marker + _fk_done_kvp）
  - 越界：0
```

## 破坏性变更

N/A。纯新增函数，无删除/无改既有函数签名/无改公共接口。既有 fk_independent_review_gate_active 等未动。

## 决策与偏离

1. **A 决策（死锁解法）**：见上方「A 决策记录」。T06 函数本身不扩范围，3/5/7 死锁的实质解法（扩 29号 artifact case）落在 T08。
2. **gate.sh 接线不在 T06**：T06 write_files 仅 artifacts.sh。gate.sh 的 `[ -f ]` → fk_validate_done_marker 接线 + fail-close 留 T10（T10 改 gate.sh + artifacts.sh 做 fail 策略分段，自然包含接线）。
3. **phases_done 短路实证兜底**：现有 `.independent-review-1.done` / `-2.done` 是 `written_by=main-agent`（dogfood 历史产物，note 自述"fk_validate_done_marker 尚未实现"）。T06 函数对它们会 Tier 1 KVP 过（written_by 非空）但 Tier 2 握手/verdict 失败——所幸 phases_done 短路（phase 1/2 ∈ phases_done）先于 Tier 2 放行，与 G1 R11"历史 .done 靠短路接受"一致。

## 是否触发新工作

- [ ] 触发新 fix-plan
- [x] 固化 A 决策到 T08 task description（扩 29号 artifact case 到 3/5/7）
- [x] 记录 gate.sh 接线遗留 → T10
- [ ] 触发 CONTEXT.md 更新

## 完成判定

- TASK.md 中对应任务已勾选：是（本 SUMMARY 后勾选）
- 提交 hash：未提交（Wave 2 串行进行中）
