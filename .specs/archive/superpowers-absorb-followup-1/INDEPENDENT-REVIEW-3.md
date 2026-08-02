## L2 盲审

### TASK.md 审查 · superpowers-absorb-followup-1

> 审查范围：TASK.md（4 任务/3 波次）/ DESIGN.md / REQUIREMENT.md / CHANGE.md
> 审查基线：flow-kit Phase 3 TASK 七要素 + checklist + AC 全覆盖

---

### 发现项

#### 🔴 #F1 · AC-E2（性能 ≤5s）无任务实现

**Symptom**: AC-E2 要求 `time npx bats test/test_scripts_security.bats test/test_integration_smoke.bats` wall-clock ≤5s，但没有任何 task 的 `action` 步骤包含 `time` 测量，也没有任何 task 的 `verify` 命令做时间断言。

**Source**: T04 `done` 字段提到 "AC-E2 (新测试 ≤5s)" 但 T04 的 `action`（1-4 步）只做 sync + diff + 全量 bats + package validate，无一包含 `time` 指令。T01/T02 也未覆盖性能测量。

**Consequence**: AC-E2 无法被自动化验证——性能回归不被任何 gate 捕获。REQUIREMENT.md 的非功能需求（NFR-性能）落空。

**Remedy**: 在 T04 `verify` 中追加：
```bash
SECONDS=0; npx bats test/test_scripts_security.bats test/test_integration_smoke.bats; [ "$SECONDS" -le 5 ] || { echo "AC-E2 FAIL: elapsed ${SECONDS}s > 5s"; exit 1; }
```
或在 T04 `action` 中加步骤 4.5 实现上述检查。

---

#### 🟡 #F2 · T03 verify 缺少 git diff 机器断言

**Symptom**: T03 `verify` 块中 `git diff --name-only` 仅以注释标注期望（`# 期望：仅 test/*.bats 文件`），无 `grep`/`exit code` 断言。执行 `git diff --name-only` 的 exit code 永远是 0（不管 diff 内容），无法区分合规与违规。

**Source**: T03 verify (L114-118):
```bash
npx bats test/test-l2-first-correction.bats
# 期望：全绿（包括 AC-I a/b/c）
git diff --name-only
# 期望：仅 test/*.bats 文件
```
`git diff --name-only` 仅输出 diff 文件列表，不判断内容。AC-C1 的硬约束（"不含 29 hook/lib 改动"）靠人眼读，不靠 exit code。

**Consequence**: 实施者或 reviewer 依赖手动检查 git diff 输出判断 AC-C1 合规；自动化 pipeline/CI 无法据此判断 pass/fail。

**Remedy**: 追加断言行：
```bash
git diff --name-only | grep -vE '^(test/|flow-kit-bundle/test/)' | grep -q . && { echo "AC-C1 FAIL: diff touches non-test files"; exit 1; } || true
```

---

#### 🟡 #F3 · T02 action 路径描述与 read_files 不一致

**Symptom**: T02 `action` 步骤 5/7 使用短相对路径（`GO.md`、`6-review.md`）描述 grep 操作，但 `read_files` 中对应文件路径为 `flow-kit-bundle/flow-kit/GO.md` 和 `flow-kit-bundle/flow-kit/prompts/6-review.md`。两处路径粒度不一致。

**Source**: T02 action L69-73:
```
5. INT-3: grep `prompts/[0-9]` GO.md → `grep -c ≥ 10`
6. INT-4: `! grep -qE 'Round [123]' 6-review.md`
```
与 read_files (L57-61) 的完整路径不一致。action 用短路径但 bats 测试需完整路径。

**Consequence**: 实施者可能直接用短路径写 bats 测试，导致测试在非预期 CWD 下跑时 fail 或 grep 错误的文件。

**Remedy**: action 描述中统一使用完整前缀路径：`flow-kit-bundle/flow-kit/GO.md`、`flow-kit-bundle/flow-kit/prompts/6-review.md`、`flow-kit-bundle/flow-kit/prompts/4-dev.md`。

---

#### 🟡 #F4 · T01 verify 使用已废弃的 `-a` 操作符

**Symptom**: T01 `verify` 块 (L45) 中 `test ! -e /tmp/flow-kit-sec-test -a ! -e /tmp/flow-kit-sec-test-2` 使用 POSIX 已废弃的 `-a`（逻辑与）操作符。POSIX.1-2017 将 `-a`/`-o` 标记为 obsolescent，复杂表达式中可能产生歧义解析。

**Source**: L45:
```bash
test ! -e /tmp/flow-kit-sec-test -a ! -e /tmp/flow-kit-sec-test-2  # teardown 清理
```

**Consequence**: 严格 POSIX 兼容 shell（dash/ash）下可能行为不可预测；bash 当前兼容但无法保证长期不弃用。

**Remedy**: 替换为 `&&` 链式写法：
```bash
! test -e /tmp/flow-kit-sec-test && ! test -e /tmp/flow-kit-sec-test-2
```

---

#### 🟢 #F5 · T01/T02/T03 write_files 仅含 test/ 源（不含 flow-kit-bundle/test/ 双源）

**Symptom**: T01/T02/T03 的 `write_files` 均只列出 `test/` 下文件，未包含 `flow-kit-bundle/test/` 对应副本。双源同步全部推迟到 T04。

**Source**: T01 write_files = 2 文件（test/ 侧）；T02 = 1 文件（test/ 侧）；T03 = 1 文件（test/ 侧）。T04 独占所有 `flow-kit-bundle/test/` 写入。

**Consequence**: 若 T04 被跳过或失败，`flow-kit-bundle/test/` 与 `test/` 产生漂移。仅靠单一兜底任务（T04）承担同步职责。

**Remedy**: 这是有意的架构选择（T04 作为 sync gate），非结构性缺陷。建议在 T04 `done` 条件中显式声明"若 T04 未通过则整个 change 视为 incomplete"以降低单点风险。**不阻塞 pass**。

---

#### 🟢 #F6 · 范围声明 "完全不动" 措辞与前序 read_files 矛盾

**Symptom**: TASK.md § 范围与约束 (L11) 声明 `禁止触碰: … flow-kit-bundle/hooks/*` 且 `本次完全不动禁动清单内文件`，但 T03 `read_files` (L94-95) 列出 `flow-kit-bundle/hooks/stop/29-independent-review.sh` 和 `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh`。T02 `read_files` 同样列出 `flow-kit-bundle/flow-kit/prompts/*`。

**Source**: "不动" 在中文语境可理解为 "不修改"（正确）或 "不访问"（过严）。read_files 仅声明"只读"，与 write_files 约束一致，但与 "完全不动" 措辞有歧义。

**Consequence**: 新加入的 reviewer 或 AI 可能误解 "完全不动" 为 "完全不能读"，导致 T02/T03 实施受阻。

**Remedy**: 将 "本次完全不动禁动清单内文件" 改为 "本次不修改禁动清单内文件（允许只读引用）"。

---

### Checklist 逐项结论

| # | 检查项 | 结论 | 备注 |
|---|---|---|---|
| 1 | 每 task 含 id/name/read_files/write_files/action/verify/done 七要素 | ✅ | 4 任务全部 7 要素齐全 |
| 2 | Task 间依赖（wave 结构）无循环依赖 | ✅ | Wave1(parallel) → Wave2(T03 dep T01) → Wave3(T04 dep all) — 无环 |
| 3 | 每个 task 的 verify 是可执行 bash 命令 | ⚠️ | T03 的 `git diff --name-only` 无断言（#F2） |
| 4 | read_files/write_files 与 CHANGE.md 范围一致 | ⚠️ | T02 路径粒度不一致（#F3）；范围措辞歧义（#F6） |
| 5 | 无 task 触及禁动清单内文件（写入） | ✅ | 所有 write_files 仅 `test/` + `flow-kit-bundle/test/`，不写 prod 文件 |
| 6 | 覆盖所有 REQUIREMENT AC | 🔴 | AC-E2（性能 ≤5s）无 task 实现（#F1） |
| 7 | model-tier 字段存在 | ✅ | T01/T02/T04: standard, T03: top |
| 8 | verify 命令含可识别 success criteria | ⚠️ | T03 的 git diff 缺断言（#F2） |
| 9 | write_files 双源（test/ + flow-kit-bundle/test/） | 🟢 | 有意识推迟到 T04（#F5），非缺陷 |

---

### 裁决

**Verdict**: 🔴 **FAIL**

**理由**: #F1（AC-E2 没有任何 task 实现）是 🔴 Critical — REQUIREMENT 中明确定义的验收准则完全缺失实现覆盖，属于规格与任务清单的 gap。

**计数**: 🔴×1 / 🟡×3 / 🟢×2

**修复方向**: 在 T04 中追加性能测量步骤/verify 命令即可消除 🔴。其他 🟡 项可在 phase 4 实施时顺手修。

---

## 主 agent 响应

### 🔴 F1 (AC-E2 性能无实现) · Fixed
- Fixed in: T04 verify 段补 `SECONDS=0 ... [ "$ELAPSED" -le 5 ]` 性能断言（结构性硬门槛）

### 🟡 F2 (T03 verify git diff 缺断言) · Fixed
- Fixed in: T03 verify 段补 grep -vE 反向断言：除 `^(test/|flow-kit-bundle/test/)` 外若有文件改动则 exit 1

### 🟡 F3 (T02 action 路径不一致) · Fixed
- Fixed in: T02 action INT-1~INT-5 全部改用完整路径 `flow-kit-bundle/flow-kit/scripts/...` / `flow-kit-bundle/flow-kit/GO.md` / `flow-kit-bundle/flow-kit/prompts/6-review.md` / `flow-kit-bundle/flow-kit/prompts/4-dev.md`

### 🟡 F4 (test -a 废弃) · Fixed
- Fixed in: T01 verify 改为 `! test -e ... && ! test -e ...`（POSIX 合规）

### 🟢 F5 (双源同步单点归 T04) · Deferred
- 接受架构决策：T04 专门负责双源同步。phase 6 MINOR-DEFERRED.md 登记

### 🟢 F6 (范围声明"完全不动"语义模糊) · Deferred
- 接受：DESIGN § 6 已明确"不修生产代码"，"完全不动"是 TASK.md 措辞简化。phase 6 文档措辞清理

---

**Fix loop verdict**: 1🔴 + 3🟡 全部 fixed；2🟢 deferred。Phase 3 可放行至 3→4 transition。
