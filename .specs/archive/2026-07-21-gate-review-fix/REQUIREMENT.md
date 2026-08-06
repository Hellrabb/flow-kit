# REQUIREMENT: gate-review-fix

> 需求来源：`/code-review max` 报告 → L2 独立盲审复核确认的 13 条缺陷。
> 本文件将 L2 盲审结论转化为可机器验证的验收准则（AC）。

---

## AC-1 · test_l3_timeout.bats timeout 路径真实覆盖

**Given** `test_l3_timeout.bats` 的 timeout-01 / timeout-02 测试  
**When** 测试执行时  
**Then**
- `setup()` 创建 `${WORKSPACE}/.specs/test-change/REQUIREMENT.md` fixture（内容 ≥ 1 行）
- `l3_review_run` 完整执行到 `_l3_call_api` → curl stub 被调用
- `timeout-01`（curl 退出码 28）断言 `.done` 文件未写入（verdict=timeout）
- `timeout-02`（curl HTTP 非 200）断言 `.done` 文件未写入（API error）
- 两测试不再因无工件而提前退出（`return 3` before curl）

## AC-2 · done-validation.bats 真正测试 fk_validate_done_marker

**Given** `done-validation.bats` 测试文件  
**When** 测试执行时  
**Then**
- 至少 1 个测试 `source done-validation.sh` + 调用 `fk_validate_done_marker`
- 至少 1 个测试验证 6 行最低行数检查（`[[ "${dlines:-0}" -ge "$MIN_MEANINGFUL_LINES" ]]`）
- 至少 1 个测试验证 phase/change_id KVP 匹配（不符 → return 2）
- 至少 1 个测试验证 L2_verdict/L3_verdict 值域校验（非法值 → return 2）
- 测试不通过 `source .done` 文件为 bash 脚本的方式绕开函数

## AC-3 · _l3_parse_result L3 段去重（含下游兼容）

**Given** `INDEPENDENT-REVIEW-1.md` 已含 2 个历史 `## L3 盲审` 段  
**When** `_l3_parse_result` 追加新的 L3 段  
**Then**
- 旧 L3 段（`## L3 盲审` / `## L3 重审`）在追加前被删除
- 文件中仅保留 1 个 `## L3` 段（新追加的）
- L2 段和主 agent 响应段不受影响
- `_l3_inject_context` 仍可正常读取去重后的 L3 段（检测到 `^## L3 (盲审|重审)`）
- SessionStart banner 在包含 INDEPENDENT-REVIEW-N.md 时仍正常显示 L3 各阶段完成状态

## AC-4 · .tmp.$$ 竞态修复（全面覆盖）

**Given** `l2-detect.sh`（行 113 mock + 行 234 后台 dispatch）和 `l3-review.sh:459` 均使用 `${review_md}.tmp.$$` 命名临时文件  
**When** 任一路径写同一 `INDEPENDENT-REVIEW-N.md`  
**Then**
- `l2-detect.sh:113`（mock 模式）：临时文件前缀改为 `.tmp.l2mock.$$`
- `l2-detect.sh:234`（后台 dispatch）：临时文件前缀改为 `.tmp.l2bg.$$`
- `l3-review.sh:459`（L3 前台）：临时文件前缀改为 `.tmp.l3.$$`
- 三处前缀互异，不会因同名 `.tmp.$$` 产生竞态
- 或统一使用 `mktemp` 替代所有手工 `.tmp.$$` 构造

## AC-5 · test_l2_l3_granular_gate.bats 值域验证不被短路

**Given** `test_l2_l3_granular_gate.bats` 测试 L2_verdict=skipped / L3_verdict=skipped  
**When** 测试执行时  
**Then**
- `.flow-active` fixture 不含 `phases_done`（避免短路）
- `fk_validate_done_marker` 完整执行到 L2_verdict/L3_verdict 的值域正则校验逻辑（即 `[[ "$k_l2v" =~ ^(pass|fail|skipped)$ ]]` 和 `[[ "$k_l3v" =~ ...` 分支）
- `L2_verdict=skipped` 通过值域校验 `^(pass|fail|skipped)$`
- `L3_verdict=skipped` 通过值域校验 `^(pass|fail|timeout|error|skipped)$`

## AC-6 · _gate_check_l3 auto_advance 感知

**Given** `.flow-active.goal.auto_advance = true` + `gate_config[N] = "both"` + L2 段缺失  
  + `_gate_check_l2` 已在 auto_advance 下返回 0（fire-and-forget dispatch，当前已正确实现，无需修改）  
**When** 控制流到达 `_gate_check_l3` 的 else 分支  
**Then**
- `_gate_check_l3` else 分支**不**执行 `exit 2`
- 改为输出日志 + return 1（触发 `_gate_do_transition` 调 L3 dispatch prompt）
- 整体不阻塞 transition（与 auto_advance 非阻塞契约一致）

## AC-7 · l2_dispatch_agent specs_dir 存在性保证

**Given** `l2_dispatch_agent` 被调用，`$specs_dir` 可能不存在  
**When** 函数开始执行  
**Then**
- 函数在文件操作前执行 `mkdir -p "$specs_dir"`（或等效的目录存在性保证）
- 后台 stderr redirect `2>"${specs_dir}/.l2-dispatch-N.log"` 不因目录缺失而失败

## AC-8 · _l3_write_done 错误显式传播

**Given** `_l3_write_done` 返回非零（磁盘满 / 权限拒绝 → rc=3；非 pass verdict → rc=1）  
**When** `l3_review_run` 处理返回值  
**Then**
- `|| true` 移除，改为显式 `case $rc in` 分支（含 default）
- rc=0: 继续正常流程
- rc=1: 日志 "verdict non-pass, .done not written"
- rc=3: 日志 "CRITICAL: .done write failed" + `return 3` 向上传播错误
- `*)` : 日志 "UNEXPECTED: _l3_write_done rc=$rc" + `return $rc` 向上传播（防御性，避免静默吞噬未来新增退出码）

## AC-9 · done-validation.sh 使用 fk_phase_gate_key()

**Given** `fk_independent_review_gate_active` 需要 phase→name 映射  
**When** 函数执行  
**Then**
- 内联 `case "$phase" in ... esac`（9 行）被替换为 `phase_name="$(fk_phase_gate_key "$phase")"`
- `[ -n "$phase_name" ] || return 1` 保持对 phase 0/4 的排除
- `fk_phase_gate_key` 文档注释从 "5 执行消费者" 更新为 "6 执行消费者"

## AC-10 · _gate_phase_filter 使用 fk_resolve_phase()

**Given** `_gate_phase_filter` 需要解析当前 phase  
**When** 函数执行  
**Then**
- 自实现的 pipeline scope 检测（`goal.scope → goal.current_phase / .phase`，5 行）被替换为 `phase=$(fk_resolve_phase 2>/dev/null || echo "?")`
- `fk_resolve_phase` 的额外校验（pipeline phase [0-7] 值域、无效时回退 `.phase`）生效

## AC-11 · _l3_build_prompt fallback 路径修正

**Given** `HOOK_BASE_DIR` 未设，`l3-review.sh` 被 standalone source  
**When** `_l3_build_prompt` Phase 6 构造 `_common_lib` 路径  
**Then**
- `BASH_SOURCE[0]` 回退路径不再追加 `/lib/common.sh`（因为文件本身已在 `lib/` 下）
- 正确路径为 `<dirname(BASH_SOURCE[0])>/common.sh` 而非 `.../lib/lib/common.sh`
- `fk_estimate_tokens` 可正常 source，token 感知截断分支正常进入

## AC-12 · fk_normalize_gate_val() 共享函数

**Given** 4 处 gate_val 标准化逻辑语义不一致（Pattern A `gate.sh:456` 含 L2|L3|both 直通；Pattern B `29:134,174` + `done-validation.sh:66` 仅 backward-compat 别名映射）  
**When** gate_val 需要标准化  
**Then**
- `common.sh` 新增 `fk_normalize_gate_val()` 函数，实现完备语义：
  - `independent|true` → `both`（backward-compat 别名）
  - `L2|L3|both` → 原值直通
  - 其他值 → `""`（未知值视为未开启）
- `independent-review-gate.sh:456`、`29-independent-review.sh:134,174`、`done-validation.sh:66` 全部改为调用该函数
- 函数签名：`fk_normalize_gate_val <raw_value>` → stdout（echo 标准化后的值）
- 所有 consumer 行为不变——标准化结果与原 case 语句等价

## AC-13 · fk_extract_l2_verdict() 共享函数

**Given** 3 处代码重复 `grep -iE 'verdict[^a-z]*[:：]' ... | tail -1 | grep -ioE 'pass|fail' | tail -1`  
**When** L2 verdict 需要从 `INDEPENDENT-REVIEW-N.md` 中提取  
**Then**
- `l2-detect.sh` 或 `common.sh` 新增 `fk_extract_l2_verdict()` 函数
- `independent-review-gate.sh:421`、`29-independent-review.sh:181`、`l3-review.sh:755` 全部改为调用该函数
- 函数含 heading-style fallback（`grep -iA 2 '^##.*Verdict'`，来自 done-validation.sh:173-174 的现有逻辑）

---

## AC-NF1 · 共享函数 consumer 完整性（回归安全）

**Given** `fk_normalize_gate_val` 和 `fk_extract_l2_verdict` 在 `common.sh` / `l2-detect.sh` 中定义  
**When** 所有已识别 consumer 完成迁移  
**Then**
- `grep -rn 'independent|true).*gate_val="both"' flow-kit-bundle/hooks/` 返回零匹配（旧 pattern 完全消除）
- `grep -rn 'fk_normalize_gate_val' flow-kit-bundle/hooks/` 返回 ≥4 处调用
- `grep -rn 'fk_extract_l2_verdict' flow-kit-bundle/hooks/` 返回 ≥3 处调用

## AC-NF2 · 全量 bats 测试通过且无 flaky

**Given** 修改后的 `test_l3_timeout.bats`、`done-validation.bats`、`test_l3_review.bats`、`test_l2_l3_granular_gate.bats`  
**When** 连续 3 次执行 `npx bats flow-kit-bundle/test/ test/`  
**Then**
- 每次结果全 pass（无 intermittent failure）
- 无新增 skip（除非有文档化的已知限制）
- `package-flow-kit.sh` 打包成功

## AC-NF3 · Gate 执行无性能回退

**Given** gate dispatch 路径已修改（`_gate_check_l3` auto_advance、共享函数调用替代内联 case/grep）  
**When** 在同一 change 上执行 phase transition（不含网络 I/O）  
**Then**
- jq 调用次数不增加（共享函数不应引入重复 jq 读取）
- `fk_normalize_gate_val` 和 `fk_extract_l2_verdict` 为 pure function（无 I/O、无 side effect）

---

## 范围切分

**v1（本次·全部 13 条）**：以上 AC-1 至 AC-13 全部在本 change 中修复

**v2（未来）**：
- L2 dispatch 从 PreToolUse 移出的架构决策（当前是 concern boundary 讨论，非 bug）
- PROJECT_ROOT 防御性显式化（L2 判定为"脆弱但非当前 bug"）
- `.done` 文件 heredoc 改为 printf（L2 判定为"防御性加固，当前 grep 已保护"）

**out（明确不做）**：
- 新增 bats 测试文件（只修复现有测试覆盖盲区）
- 修改 `L2-blind-review.md` prompt 模板
- 修改 gate 架构（如 gate 顺序、gate 框架抽象）
