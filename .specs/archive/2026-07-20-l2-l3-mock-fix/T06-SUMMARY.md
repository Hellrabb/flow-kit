# T06-SUMMARY — AC-T 全套 bats 真绿 + AC-3 范围外基线修测

- **Task**: T06 (AC-T) — 全套 bats 真绿（基线不破坏 + T01-T05 新增全过）
- **Change**: l2-l3-mock-fix
- **关联**: REQUIREMENT AC-T / TASK T06
- **状态**: ✅ 全套真绿（exit=0，536 ok / 0 fail / 0 BW01）

## verify 结果

| 检查 | 结果 |
|---|---|
| 全套 bats `npx bats test/` | ✅ EXIT=0，536 ok / **0 not ok** / 0 BW01 |
| AC-3 基线（l2-l3-test-defect 遗留） | ✅ 修测后 pass（原 fail 237 → ok） |

## AC-3 范围外基线修测（用户授权 T06 内顺手修）

**根因**：`test_independent_review_model.bats:45` AC-3 测期望 29/30 都用 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-...}`（fallback 模式），但 29-independent-review.sh:59 实际用 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:?...}`（**强制模式，缺失报错**）。`:?` 是 l2-l3-test-defect（commit fb78235「G/L3-model/INT-6 修复」）**故意引入**的（强制 L3 模型必须定义），AC-3 测没跟上 29 的设计变更 → 测/实现分歧 → fail。

**修测**（反映真实设计，非改实现）：
- 29：`:?` 强制（env-var-first，模型必须定义，无 fallback）
- 30：`:-` fallback（env var > config > default）
- AC-3 grep pattern 从 `ANTHROPIC_DEFAULT_HAIKU_MODEL:-` 改为 ERE `ANTHROPIC_DEFAULT_HAIKU_MODEL:[-?]`（匹配 `:?` 或 `:-`，env-var-first with modifier）

## 改动清单

| 文件 | 改动 |
|---|---|
| test/test_independent_review_model.bats | AC-3（line 45-54）：grep pattern `:-` → ERE `:[-?]` + 注释说明 29 `:?` / 30 `:-` 设计分歧 |
| flow-kit-bundle/test/test_independent_review_model.bats | AC-7 一致性同步 |

## 6 维 self-review（T06 验证 task · 简化）

1. **正确性** ✅：全套 536/0（AC-3 修测后真绿，含 T01-T05 新增 5 测文件）
2. **复用** ✅：AC-3 沿用原测结构（仅扩 pattern），未重写
3. **简单性** ✅：pattern 扩为 `:[-?]` 字符类（+1 字符），净最小改动
4. **效率** ✅：N/A（验证 task）
5. **可读性** ✅：AC-3 注释说明 `:?` 强制 vs `:-` fallback 的设计分歧 + T06 修测缘由
6. **测试质量** ✅：AC-3 现反映 29 真实设计（强制 env var），不再是测/实现分歧

## 越界检查（R6.5 / R7.1）

- ✅ T06 仅验证 + 1 个范围外修测（用户授权），未改实现代码（29/30 脚本未碰）
- ✅ R7.1 扩范围（AC-3 修测）已在 TASK done 字段 + 本 SUMMARY 记录
- ✅ 未改本 change T01-T05 的实现（26-workflow / gate.sh / l3-review / common / 29 均未再动）

## 扫 LESSONS（1.5 · R1.8）

- **L-027**（bats 禁 `|tail`/`;echo EXIT` 吞 exit）：T06 verify 用 `> log; ec=$?` 存真 exit + `grep -c '^not ok'` 摘要，非吞 exit；全套 EXIT=0 真实

## 遗留

- 无（T06 全套真绿，AC-3 基线已修）
- **Wave 3 剩余**：T07（NFR-1 性能实测填阈值）→ T08（NFR-2 bash 兼容实测）· 串行
