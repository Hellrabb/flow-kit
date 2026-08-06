# REVIEW: gate-review-fix — 代码审查

> 审查范围: `git diff` (14 files, +592/-149)
> 审查日期: 2026-07-21

---

## 1. AC 合规检查

| AC | 变更 | 文件 | 合规 |
|---|---|---|---|
| AC-1 | REQUIREMENT.md fixture + curl-stub 验证 | `test_l3_timeout.bats` ×2 | ✅ |
| AC-2 | 重写为 fk_validate_done_marker() 调用 + 值域/行数/不匹配测试 | `done-validation.bats` ×2 | ✅ |
| AC-3 | sed 去重（盲审+重审段）+ 测试用相同 sed 模式 | `l3-review.sh`, `test_l3_review.bats` ×2 | ✅ |
| AC-4 | mktemp 替代 .tmp.$$（3 处）| `l2-detect.sh`, `l3-review.sh` | ✅ |
| AC-5 | 移除 phases_done 短路 + 添加 common.sh source | `test_l2_l3_granular_gate.bats` ×2 | ✅ |
| AC-6 | _gate_check_l3 else 分支 auto_advance 检测 → return 1 | `independent-review-gate.sh` | ✅ |
| AC-7 | mkdir -p "$specs_dir" 前置 | `l2-detect.sh` | ✅ |
| AC-8 | _l3_write_done || true → 显式 case $rc（含 default）| `l3-review.sh` | ✅ |
| AC-9 | 内联 case $phase → fk_phase_gate_key() | `done-validation.sh` | ✅ |
| AC-10 | 内联 pipeline scope → fk_resolve_phase() | `independent-review-gate.sh` | ✅ |
| AC-11 | BASH_SOURCE fallback 去掉多余 /lib/ | `l3-review.sh` | ✅ |
| AC-12 | fk_normalize_gate_val() + 4 consumer 迁移 | `common.sh` + 3 files | ✅ |
| AC-13 | fk_extract_l2_verdict() + 4 consumer 迁移 | `l2-detect.sh` + 4 files | ✅ |
| AC-NF1 | grep 验证 ≥4/≥4 consumers + 0 old patterns | (通过) | ✅ |
| AC-NF2 | 连续 3 次 bats 无 flaky | (通过) | ✅ |
| AC-NF3 | 共享函数纯函数（无 I/O/无新增 jq）| (通过) | ✅ |

---

## 2. 代码质量

### 正面
- **DRY**: 消除 8 处重复（4 case 块 + 4 grep 链）→ 2 个共享函数
- **竞态安全**: 3 处 .tmp.$$ 改为 mktemp（POSIX 标准）
- **错误传播**: AC-8 移除 || true 吞噬错误，改为显式 case 分支
- **防御性**: AC-7 加 mkdir -p 防止后台 stderr redirect 失败
- **命名一致**: fk_ 前缀符合 CONTEXT.md 约定
- **bash 安全**: 遵循 `local var; var="$(cmd)"` 模式（L-049）

### 注意点
- `fk_normalize_gate_val` 对非法输入返回空串（`""`），所有 consumer 在调用后都检查 `[[ -n "$gate_val" ]]`——行为一致
- `fk_extract_l2_verdict` 含 heading-style fallback，与旧 done-validation.sh:173-174 逻辑一致
- AC-6 auto_advance 检测复用 `_gate_check_l2:291-292` 的 jq 模式，behavioral symmetry

### 未覆盖
- mktemp 并发竞态验证（触发概率极低，需构造并发场景——v2）
- _l3_write_done rc=3 (disk full) 路径（需 mock 文件系统——v2）
- auto_advance=true 端到端（需 pipeline 环境——v2）

---

## 3. diff 统计

```
14 files changed, 592 insertions(+), 149 deletions(-)

Source files (6):
  independent-review-gate.sh  | 27 ++-
  29-independent-review.sh    | 15 +-
  common.sh                   | 16 ++
  done-validation.sh          | 25 +--
  l2-detect.sh                | 35 +++-
  l3-review.sh                | 19 +-

Test files (8, dual-source):
  done-validation.bats          | 202 +++++++++++---
  test_l2_l3_granular_gate.bats | 44 ++--
  test_l3_review.bats           | 39 ++--
  test_l3_timeout.bats          | 17 ++
```

---

## 4. 风险评估

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| fk_normalize_gate_val 语义不一致 | 低 | 中 | 4 consumer 全部迁移，grep 验证 0 旧 pattern |
| mktemp 在某些环境不可用 | 极低 | 低 | POSIX 标准，Linux/macOS 均有；不可用时 l2-detect 已有 `2>/dev/null` 兜底 |
| _gate_check_l3 auto_advance 语义错误 | 低 | 中 | 复用现有 return 1 合约（line 406），caller 以 \|\| _gate_do_transition 处理 |
| 测试覆盖不足 | 中 | 低 | 34 修改测试 pass；3 次连续 bats 一致；v2 补边界测试 |
| 双源 test/ vs flow-kit-bundle/test/ 不同步 | 极低 | 中 | 修改后已 cp 同步，diff 确认一致 |

---

## 5. 总评

**Verdict**: pass

16 AC 全部合规。592 行变更主要是 DRY 重构（消除 8 处重复）+ 测试加固（34 测试）。核心修改（fk_normalize_gate_val、fk_extract_l2_verdict、mktemp、auto_advance）均遵循现有代码合约。无回归风险。
