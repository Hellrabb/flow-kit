# INDEPENDENT-REVIEW-6: L2 独立盲审 · 阶段 6 (代码审查)

- **Change ID**: gate-done-authorship
- **审查阶段**: 6 (代码审查)
- **审查日期**: 2026-07-25
- **审查员**: L2 盲审子 agent (独立)

---

## L2 盲审

### 审查范围

| 文件 | 行数变化 | 说明 |
|------|----------|------|
| `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` | +55/-16 | D7 path-guard 重写: `_is_dotdone_write` + `_gate_is_l2_only` |
| `flow-kit-bundle/hooks/stop/lib/done-validation.sh` | +4/-20 | 删 T3 握手 + T3b SESSION_ID，保留 T4 L2 比对 |
| `flow-kit-bundle/hooks/stop/29-independent-review.sh` | +6/-12 | Gate 4 改用 .done 幂等，Gate 5 删 state_file 清理 |
| `flow-kit-bundle/test/test_gate_integrity.bats` | +55/-45 | D7 path-guard 改写 + AC-6 payload + AC-4 L2-only |
| `test/test_gate_integrity.bats` | +55/-45 | 同上 (外层副本，但不一致 — 见 C1) |
| `test/regression-demos/*/check.sh` | +30/-30 | 引用更新 `is_handshake_write` → `_is_dotdone_write` |
| `flow-kit-bundle/test/regression-demos/tampered-done/check.sh` | +5/-5 | 引用更新 |
| `flow-kit-bundle/test/regression-demos/forged-done/check.sh` | 未更新 | **STALE** — 仍引用 `is_handshake_write` (见 C2) |
| `flow-kit-bundle/test/regression-demos/exotic-escape/check.sh` | 未更新 | **STALE** — 仍引用 `is_handshake_write` (见 C2) |

---

### 发现

#### C1 · 🔴 Critical — test_gate_integrity.bats 双副本不同步 (bundle 缺失 T4 负向测试)

`flow-kit-bundle/test/test_gate_integrity.bats` 与 `test/test_gate_integrity.bats` 内容不一致。外层副本包含 `@test "T4 L2 裁决不匹配"` 测试 (行 99-108)，而 bundle 副本缺少该测试。bundle 副本在该位置仍然是 `@test "D9 fail-close: 畸形 snapshot"`。

**影响**: bundle 目录下的 `make test` 不会校验 T4 L2_verdict vs INDEPENDENT-REVIEW-N.md 不一致的负向路径。REVIEW.md 声明的 "23 tests 全绿" 可能仅在外层 `test/` 下验证通过，bundle 内实际只有 22 个测试。

**证据**:
```
$ diff flow-kit-bundle/test/test_gate_integrity.bats test/test_gate_integrity.bats
+154 added, -143 removed, ~4 modified
# bundle 副本缺失:
# @test "T4 L2 裁决不匹配: .done L2_verdict=pass 与 INDEPENDENT-REVIEW.md L2 verdict=fail → transition deny return 2"
```

**修复**: 将 `flow-kit-bundle/test/test_gate_integrity.bats` 同步到与 `test/test_gate_integrity.bats` 一致的内容；或建立符号链接/单一来源消除双副本维护问题。

---

#### C2 · 🔴 Critical — bundle-internal regression demos 未更新 (2/3 文件引用已删除函数)

以下 bundle 副本仍然引用已删除的 `is_handshake_write` 函数:

- `flow-kit-bundle/test/regression-demos/exotic-escape/check.sh` — 9 处引用 `is_handshake_write`，含函数调用 `is_handshake_write "$EXOTIC_CMD"` (L25)
- `flow-kit-bundle/test/regression-demos/forged-done/check.sh` — 5 处引用 `is_handshake_write`，含依赖检测 grep (L14)

由于 `is_handshake_write` 已从 `independent-review-gate.sh` 删除并重命名为 `_is_dotdone_write`:
- 依赖检测 grep `is_handshake_write` 在 gate.sh 中无匹配 → 打印 "PENDING" → exit 0 **静默跳过**
- 这些回归 demo 实际上已经失活，不会执行任何断言

**注意**: `flow-kit-bundle/test/regression-demos/tampered-done/check.sh` 已正确更新（仅此 1/3 被更新）。

**对比**: 外层 `test/regression-demos/exotic-escape/check.sh` 和 `test/regression-demos/forged-done/check.sh` 已正确更新。

**修复**: 将三个 bundle-internal regression demos 全部同步到与对应外层 `test/regression-demos/` 版本一致。

---

#### M1 · 🟡 Major — forged-done/check.sh 测试逻辑与方案 A 不匹配 (依赖已删除的 T3)

`test/regression-demos/forged-done/check.sh` (外层已更新引用，但逻辑未适配):

```bash
# L21-31: 创建 .done fixture 缺失 artifacts 和 session_id
phase=6
change_id=test-change
written_by=review-subagent
written_at=2026-07-02T00:00:00Z
L2_verdict=pass
L3_verdict=pass
# 注：无 .flow-active.independent-review 握手文件 → T3 握手锚点缺失

# L37: 断言原因错误
# 断言：伪造 KVP + 无真实握手 → Tier 2 T3 握手缺失 → deny exit 2
```

**分析**: 
- 方案 A 下 `fk_validate_done_marker` 不校验 T3 握手 (已删除)
- 但该 .done fixture 缺少 `artifacts=` 键 → Tier 1 T5 检查失败 → 仍返回 rc=2
- **测试通过但原因错误**: rc=2 来自 `[[ -n "$k_artifacts" ]] || return 2` (T5)，而非注释声称的 "T3 握手锚点缺失"
- 注释和断言文本具有误导性，且 fixture 未测试 `written_by` 字段本身不受 T3 验证这一事实

**修复**: 
1. 更新 fixture 使 .done 包含完整的 6 键 KVP（含 `artifacts=REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-6.md`）
2. 无 INDEPENDENT-REVIEW-6.md 文件 → T4 L2_verdict 比对 best-effort 放行 → rc=0
3. 此时应重新设计测试: 由于方案 A 取消了 T3 作者性校验，`forged-done` 测试的原始语义（"伪造 KVP + 无真实握手 → deny"）不再成立
4. 建议改为测试: 合法 KVP 但 L2_verdict 与 INDEPENDENT-REVIEW-N.md 不一致 → T4 deny (当前 T4 负向测试已在 test_gate_integrity.bats 中覆盖)

---

#### M2 · 🟡 Major — tampered-done/check.sh fixture 写入废弃的握手文件 (逻辑与方案 A 不匹配)

`test/regression-demos/tampered-done/check.sh` (外层) 和 `flow-kit-bundle/test/regression-demos/tampered-done/check.sh` (bundle):

```bash
# L29-32: 写入了废弃的 .flow-active.independent-review 握手文件
cat > "$TMP/.flow-active.independent-review" <<'EOF'
{"phase":"6","status":"done","verdict":"pass","written_by":"stop-hook-29","written_at":"2026-07-02T00:00:00Z"}
EOF
```

**分析**:
- 该握手文件在方案 A 下**不会被任何代码读取** (`fk_validate_done_marker` 的 T3 段已删除)
- .done fixture 同样缺少 `artifacts=` 键 → 测试返回 rc=2 的实际原因是 T5 artifacts 缺失
- 测试断言声称 "T4 verdict 比对不一致" 但实际未经过 T4 段 (T5 已提前返回 2)
- `.flow-active.independent-review` 文件路径在方案 A 中已废弃

**修复**: 
1. 删除 `.flow-active.independent-review` 握手文件写入代码
2. 使 .done fixture 包含完整 KVP（含 artifacts、session_id）
3. 创建 INDEPENDENT-REVIEW-6.md 使 T4 正向通过
4. 或改为测试 T4 L2_verdict 不一致的场景 (与 M1 统一，且已在 test_gate_integrity.bats T4 测试中覆盖)

---

#### M3 · 🟡 Major — exotic-escape/check.sh (外层) 仍测试旧的握手文件路径

`test/regression-demos/exotic-escape/check.sh` (外层):

```bash
# L22: exotic 向量仍针对 .flow-active.independent-review
EXOTIC_CMD='python3 -c "open(\".flow-active.independent-review\",\"w\").write(\"forged-handshake\")"'
```

**分析**:
- 方案 A 下保护对象改为 `.independent-review-*.done`，不再是 `.flow-active.independent-review`
- 但 exotic 逃逸测试仍针对旧的握手文件路径
- 外层副本仅更新了函数名引用 (`is_handshake_write` → `_is_dotdone_write`)，但未更新目标文件路径
- 实际上 `_is_dotdone_write` 字符串匹配检查的是 `.independent-review-*.done`，所以这个 exotic 命令**无论如何都不会被匹配到** — 无论函数名是否更新

**修复**: 将 exotic 命令的目标路径改为 `.independent-review-6.done`，使其测试实际的保护对象。

---

#### m1 · 🟢 Minor — `_gate_is_l2_only` fail-open 策略需文档强调

```bash
# independent-review-gate.sh:64-75
_gate_is_l2_only() {
  local phase_num="$1" cwd="${2:-$PWD}"
  local flow_file="${cwd}/.flow-active"
  [[ -f "$flow_file" ]] || return 0  # 无 .flow-active → fail-open 放行
  local phase_name
  phase_name=$(fk_phase_gate_key "$phase_num" 2>/dev/null || echo "")
  [[ -n "$phase_name" ]] || return 0  # phase_name 解析失败 → fail-open 放行
  ...
}
```

- fail-open 路径 (无 `.flow-active`、phase_name 解析失败) 会导致 L2-only 例外被**误放行** (agent 在 L3/both 模式下写 .done 也被放行)
- 这是 DESIGN D3 的显式决策 ("gate_config 读取失败 → fail-open 放行")，已在 REVIEW.md 已知限制 #3 记录
- 但发生场景 (`.flow-active` 缺失时 agent 仍尝试写 .done) 的实际攻击面很小，因为同一次 session 中 `.flow-active` 缺失意味着 gate 本身也不生效

---

#### m2 · 🟢 Minor — `cat <<` heredoc 匹配范围过宽

```bash
# independent-review-gate.sh:56
[[ "$c" == *"cat <<"* ]] && return 0
```

- 该模式匹配命令字符串中任意位置出现 `cat <<`，包括 heredoc 内容中含 `.independent-review-N.done` 的情况
- 例如: `cat <<'EOF'\nbackup .independent-review-6.done\nEOF` 会被误判为写 .done
- 实际风险极低: 此类命令在生产环境中极少见，且误拦只会导致 exit 2 deny（fail-safe）

---

#### m3 · 🟢 Minor — test_gate_integrity.bats 双副本维护 (技术债)

存在两份完全独立的 `test_gate_integrity.bats` 副本 (`test/` 和 `flow-kit-bundle/test/`)，C1 已导致它们不同步。长期来看应建立单一来源（符号链接或引用）。当前 250+ 行手工同步容易再次出现分歧。

---

### Spec 合规对照

| AC | 状态 | 说明 |
|----|------|------|
| AC-1 agent 伪造 .done 被拦截 | ⚠️ 部分 | D7 path-guard 6 测试通过，但 bundle 回归 demo 2/3 静默跳过 |
| AC-2 合法 .done 放行 | ✅ | D9 正向测试通过 |
| AC-3 握手死代码清理 | ⚠️ 部分 | 生产代码 grep 通过（仅注释残留），但 test fixtures 仍有 `is_handshake_write` 引用 |
| AC-4 L2-only 例外 | ✅ | AC-4 测试通过 (exit 0) |
| AC-5 既有测试改写 | ❌ fail | bundle 副本 `exotic-escape`/`forged-done` 未更新 → 静默 PENDING (C2) + `test_gate_integrity.bats` 不同步 (C1) |
| AC-6 payload 集成 | ⚠️ 部分 | AC-6 payload 测试通过，但 bundle `test_gate_integrity.bats` 缺失 T4 负向测试 |
| AC-7 全量 bats 0 fail | ⚠️ 待验证 | 需在 bundle 目录下验证 `make test` (修复 C1/C2 后重新验证) |

---

### 代码质量 6 维

| 维度 | 评估 | 说明 |
|------|------|------|
| R1 认知过载 | 🟢 | `_is_dotdone_write` 继承 11 种写模式清晰，`_gate_is_l2_only` 单一职责 |
| R2 变更传播 | 🟡 降级 | 双副本 test 文件未完全同步 (C1)；3/4 regression demos 中 2 个 bundle 副本未更新 (C2) |
| R3 知识重复 | 🟡 降级 | test_gate_integrity.bats 双副本维护 (m3)；regression demos 双副本 (C2) |
| R4 偶然复杂 | 🟢 | 方案 A 设计简洁，T3/T3b 删除后代码路径清晰 |
| R5 依赖混乱 | 🟢 | path-guard 前置 + Tier 1/2 后置层次分明 |
| R6 领域扭曲 | 🟢 | `.done` 作者性 / L2-only 例外 / 架构天然隔离 均领域术语一致 |

---

### Verdict: fail

**理由**: 存在 2 个 Critical 问题:
1. **C1**: `test_gate_integrity.bats` 双副本不同步 — bundle 副本缺失 T4 负向测试
2. **C2**: `flow-kit-bundle/test/regression-demos/exotic-escape/check.sh` 和 `forged-done/check.sh` 仍引用已删除的 `is_handshake_write` 函数 — 两个回归 demo 静默跳过

以上问题违反 **AC-5** (既有测试全部改写) 和 **AC-7** (全量 bats 0 fail — bundle 内测试未完成同步)。

---

### 修复建议 (优先级排序)

1. **P0 (C1)**: 同步 `flow-kit-bundle/test/test_gate_integrity.bats` 内容到与 `test/test_gate_integrity.bats` 完全一致
2. **P0 (C2)**: 将 `flow-kit-bundle/test/regression-demos/exotic-escape/check.sh` 和 `forged-done/check.sh` 内容同步到与对应外层 `test/regression-demos/` 版本一致
3. **P1 (M1)**: 重构 `forged-done/check.sh` 测试语义使其符合方案 A: fixture 包含完整 KVP，测试 T4 L2_verdict 不一致场景 (替代已废弃的 T3 handshake 语义)
4. **P1 (M2)**: 清理 `tampered-done/check.sh` 中废弃的 `.flow-active.independent-review` 握手文件写入代码，使 fixture 包含完整 KVP
5. **P1 (M3)**: 更新 `exotic-escape/check.sh` exotic 命令目标路径为 `.independent-review-6.done`
6. **P2**: 修复后执行 `make test` 在 bundle 目录下验证 AC-7 (全量 0 fail)

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-25 16:35）

> 自动生成于 2026-07-25 16:35。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[],"minor":[{"file":".specs/l3-review-timeout-token/CHANGE.md（删除）","issue":"设计文档被删除，但工件中未附带对应代码实现或迁移说明","why":"缺少证据表明CHANGE.md和DESIGN.md中的设计已被其他文档吸收或已实现，可能导致后续维护者丢失上下文","fix":"要么保留删除前的文件作为历史记录，要么在PROGRESS.md或REQUIREMENT.md中明确标注设计已迁移或已实现"},{"file":".specs/gate-review-fix/PROGRESS.md","issue":"所有新增条目的review verdict均为"?"，未填入实际结果","why":"进度记录不完整，无法反映真实审查状态，降低可追溯性","fix":"执行实际审查后更新verdict字段，或删除无实际值的占位条目"},{"file":"主agent REVIEW.md","issue":"审查结论依赖部分不可验证的断言（如全量bats 0 fail）","why":"作为独立审查工件，缺乏测试日志或执行证据，无法独立确认AC合规","fix":"附加关键测试的日志输出或覆盖率快照以支撑断言"}],"verdict":"pass","summary":"工件整体无严重缺陷，PROGRESS.md更新和设计文档删除操作本身合理，但缺少迁移证据和完整记录；主agent的REVIEW.md逻辑自洽但缺乏独立验证所需证据。建议补充上下文或清理无效进度记录。"}
```

L3_artifact_hash: 5e33ceaad92c1e08143cf3ad441ded4f1368c5634713ffa6dce7fde420c310db
