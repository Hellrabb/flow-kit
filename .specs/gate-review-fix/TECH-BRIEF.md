# TECH-BRIEF: 13 条 L2 确认发现的源码级修复手冊

> 本文件为非阶段产物，仅作 `clear` 后快速恢复上下文用。
> 每条 = 源码行号 + 触发条件 + 修复方向。AC 号对应 REQUIREMENT.md。

---

## P0 · 测试覆盖盲区

### #1 (AC-1) · test_l3_timeout.bats timeout 路径零覆盖
- **文件**: `flow-kit-bundle/test/test_l3_timeout.bats:48`（镜像：`test/test_l3_timeout.bats:48`）
- **根因**: `setup()` 创建 `${WORKSPACE}/.specs/test-change/` 但无 `REQUIREMENT.md`
- **源码链**: `l3_review_run` → `_l3_build_prompt` (l3-review.sh:321) → `[ -n "$artifact" ] || return 3`
- **修复**: `setup()` 加 `echo "# Test" > "${WORKSPACE}/.specs/test-change/REQUIREMENT.md"`

### #2 (AC-2) · done-validation.bats 零覆盖
- **文件**: `flow-kit-bundle/test/done-validation.bats`（57 行，镜像：`test/done-validation.bats`）
- **根因**: 全部 4 个测试 `source "$TEST_TMPDIR/.done"` 为 bash，不调用 `fk_validate_done_marker`
- **修复**: 改写为 `source done-validation.sh` + 构造 `.done` fixture + 调用 `fk_validate_done_marker` + 断言 rc

### #3 (AC-5) · test_l2_l3_granular_gate.bats 短路
- **文件**: `flow-kit-bundle/test/test_l2_l3_granular_gate.bats:147,167`
- **根因**: `.flow-active` fixture 含 `"phases_done":["6"]` → `fk_validate_done_marker` (done-validation.sh:114) 短路 return 0
- **修复**: fixture 去 `phases_done`，让值域 regex 真正执行

---

## P1 · Correctness Bugs

### #4 (AC-3) · _l3_parse_result L3 段累积重复
- **文件**: `l3-review.sh:460-485`
- **根因**: `cat "$review_md" > "$tmp_review"` 完整复制旧文件（含旧 L3 段），然后 `>>` 追加新 L3 段
- **修复**: 追加前 `grep -vE '^## L3 (盲审|重审)' "$review_md" > "$tmp_review"` 或等效去重
- **下游兼容**: `_l3_inject_context` (l3-review.sh:200) 用 `grep -A1 '"verdict"'` 读 L3 段；SessionStart banner 用 `grep -qE '^## L3 (盲审|重审)'`

### #5 (AC-4) · .tmp.$$ 三路竞态
- **文件**: `l2-detect.sh:113`（mock） + `l2-detect.sh:234`（后台） + `l3-review.sh:459`（L3 前台）
- **根因**: 三处都用 `${review_md}.tmp.$$`，subshell 中 `$$` 保留父 PID
- **修复**: 分别改为 `.tmp.l2mock.$$` / `.tmp.l2bg.$$` / `.tmp.l3.$$` 或统一用 `mktemp`

### #6 (AC-6) · _gate_check_l3 else 与 auto_advance 矛盾
- **文件**: `independent-review-gate.sh:374-380`
- **根因**: `_gate_check_l2` (行 293-302) 在 auto_advance 下 return 0（不阻塞），但 `_gate_check_l3` else 分支（行 374）无条件 exit 2
- **修复**: else 分支加 auto_advance 感知：读 `jq -r '.goal.auto_advance'` → 若 true 则输出日志 + return 1（触发 `_gate_do_transition` dispatch prompt），非 exit 2

### #7 (AC-7) · l2_dispatch_agent 缺目录存在性保证
- **文件**: `l2-detect.sh:105,254`
- **根因**: 参数校验后直接构造 `${specs_dir}/.l2-dispatch-${phase}.log`，未 `mkdir -p`
- **修复**: 行 109 后加 `mkdir -p "$specs_dir"`

### #8 (AC-8) · _l3_write_done 错误吞噬
- **文件**: `l3-review.sh:669-670`
- **根因**: `_l3_write_done ... || true` 吞噬所有返回值（rc=1: 非 pass 不写；rc=3: 写入失败）
- **修复**:
```bash
_l3_write_done ...; local wrc=$?
case $wrc in
  0) ;;  # success
  1) echo "[l3-review] verdict non-pass, .done not written" >&2 ;;
  3) echo "[l3-review] CRITICAL: .done write failed" >&2; return 3 ;;
  *) echo "[l3-review] UNEXPECTED: _l3_write_done rc=$wrc" >&2; return $wrc ;;
esac
```

### #9 (AC-13) · _l3_build_prompt fallback double-lib/
- **文件**: `l3-review.sh:267`
- **根因**: `${BASH_SOURCE[0]}` 已在 `.../stop/lib/` 下，再追加 `/lib/common.sh` → `.../stop/lib/lib/common.sh`
- **修复**: 改为 `${HOOK_BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/common.sh`（去 `/lib` 前缀）

---

## P2 · DRY 重构

### #10 (AC-9) · done-validation.sh 重复 phase 映射
- **文件**: `done-validation.sh:42-50`
- **现状**: 硬编码 `case "$phase" in 1) phase_name="1-requirement" ;; ... esac`（9 行）
- **修复**: 替换为 `phase_name="$(fk_phase_gate_key "$phase")"` + `[ -n "$phase_name" ] || return 1`
- **注意**: `fk_phase_gate_key` 文档注释 "5 执行消费者" → "6 执行消费者"

### #11 (AC-10) · _gate_phase_filter 重复 fk_resolve_phase
- **文件**: `independent-review-gate.sh:206-211`
- **现状**: 自实现 pipeline scope 检测（5 行）
- **修复**: `phase=$(fk_resolve_phase 2>/dev/null || echo "?")`（common.sh 已 source）

### #12 (AC-12) · fk_normalize_gate_val() 提取
- **文件**: `independent-review-gate.sh:456` + `29-independent-review.sh:134,174` + `done-validation.sh:66`
- **关键**: 4 处语义**不等价**—gate.sh:456 有 `L2|L3|both` 直通（Pattern A），其他 3 处没有（Pattern B）
- **修复**: 新函数实现完备语义（`independent|true→both` + `L2|L3|both→直通` + `其他→""`），所有 consumer 替换后行为不变

### #13 (AC-13) · fk_extract_l2_verdict() 提取
- **文件**: `independent-review-gate.sh:421` + `29-independent-review.sh:181` + `l3-review.sh:755`
- **现状**: `grep -iE 'verdict[^a-z]*[:：]' ... | tail -1 | grep -ioE 'pass|fail' | tail -1`
- **修复**: 新函数含 heading fallback（`grep -iA 2 '^##.*Verdict'`，从 done-validation.sh:173-174 提取）

---

## P3 · 效率 / 清理

### #14 (AC-11) · L3 API 在 rerun check 前调用
- **文件**: `l3-review.sh:658,662`
- **根因**: `_l3_call_api` (Step 2, 行 658) 先于 `_l3_parse_result` → `_l3_check_rerun` (Step 3, 行 438)
- **修复**: 将 `_l3_check_rerun` 移到 `_l3_call_api` 之前作为 early-out

### #15 · 29-independent-review.sh 重复 gate_val 读取
- **文件**: `29-independent-review.sh:131-137` + `29-independent-review.sh:170-177`
- **根因**: 同文件内两次 jq 读取 + case 标准化，~30 行间隔
- **修复**: 删除行 170-177，复用行 131-137 的 `$gate_val`

### #16 (AC-NF1) · jq_atomic_write 死代码
- **文件**: `flow-kit-artifacts.sh:371`
- **根因**: `.updated_at = now | .updated_at = (now | strftime(...))` 第一赋值被第二覆盖
- **修复**: 删除 `.updated_at = now |`

---

## 测试验证 (AC-NF2)

```bash
# 全量 bats（含修复后的 4 个文件）
npx bats flow-kit-bundle/test/ test/

# 共享函数完整性 (AC-NF1)
grep -rn 'independent|true).*gate_val="both"' flow-kit-bundle/hooks/  # 期望 0 匹配
grep -rn 'fk_normalize_gate_val' flow-kit-bundle/hooks/              # 期望 ≥4
grep -rn 'fk_extract_l2_verdict' flow-kit-bundle/hooks/             # 期望 ≥3

# 打包验证
bash package-flow-kit.sh
```

## 关键文件路径速查

| 源文件 | 行数 | 涉及修复 |
|---|---|---|
| `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` | 551 | #6, #11, #12, #13 |
| `flow-kit-bundle/hooks/stop/lib/l2-detect.sh` | 263 | #5, #7, #13 |
| `flow-kit-bundle/hooks/stop/lib/l3-review.sh` | 810 | #4, #5, #8, #9, #13, #14 |
| `flow-kit-bundle/hooks/stop/lib/common.sh` | 307 | #12 |
| `flow-kit-bundle/hooks/stop/lib/done-validation.sh` | 180 | #10, #12 |
| `flow-kit-bundle/hooks/stop/29-independent-review.sh` | 213 | #12, #13, #15 |
| `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh` | 374 | #16 |
| `flow-kit-bundle/test/test_l3_timeout.bats` | 108 | #1 |
| `flow-kit-bundle/test/done-validation.bats` | 57 | #2 |
| `flow-kit-bundle/test/test_l2_l3_granular_gate.bats` | 184 | #3 |
| `flow-kit-bundle/test/test_l3_review.bats` | 139 | #4 测试修正 |
