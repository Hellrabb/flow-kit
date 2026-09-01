# T04-SUMMARY — correction-hygiene-state-guard 卫生机制测试

Change: `correction-hygiene-state-guard` (ADR-024) · Task: **T04** · Discipline: flow-dev (single task)
Status: **IMPLEMENTED（测试全绿 × 10，含 1 项主代理回归偏差需主代理处置，见 [Deviations](#deviations)）**

---

## 1. What（做了什么）

T04 要求：为 `correction-hygiene-state-guard`（state-integrity 卫生机制：去重/容量/清零/外来让位/l2-missing 退场/写入保护）编写双源 BATS 测试，逐项覆盖 TASK.md T04 全部 action item（AC-1/2/3/4/5/6/7/9/10 + R1），并验证 Makefile check-validate 权威行。全部测试**驱动真实脚本代码**（33-flow-active-integrity.sh / 29-independent-review.sh / lib/correction-file.sh），被测单元零 mock；fixture 全部 mktemp 隔离 + teardown 清理。

## 2. Files（写入了哪些文件）

| 文件 | 内容 | 状态 |
|---|---|---|
| `test/test_correction_hygiene.bats` | 10 个 @test（AC-1/2/3/4a/4b/5,6/9/7/10 + R1） | 新增，10/10 绿 |
| `flow-kit-bundle/test/test_correction_hygiene.bats` | 与上 identical（`make test-sync` 生成） | 新增，双源 diff 一致 |
| `Makefile` | **仅验证 item 0，未改动** | 权威行已在（见下） |

Makefile item 0（check-validate L43-46，已存在，逐字验证，未添加）：
```make
check-validate:
	@echo "📦 make check-validate: package staging coverage..."
	@bash package-flow-kit.sh --validate 2>&1 | tail -5
	@bash package-flow-kit.sh --validate > /dev/null 2>&1 && echo "✅ validate: staging coverage OK" || { echo "❌ validate: coverage check failed"; exit 1; }
```
（权威行 `@bash package-flow-kit.sh --validate > /dev/null 2>&1 && echo "✅ validate: staging coverage OK" || { echo "❌ validate: coverage check failed"; exit 1; }` 位于第 46 行。）

## 3. Test cases（AC 映射 1:1）

| # | @test | AC/动作项 | 验证点（真实实现驱动） |
|---|---|---|---|
| 1 | `AC-1: 同 check+field 连写 3 条 → violations 仅剩最新 1 条` | AC-1 | source 33 后调 `_fai_append_violation` ×3（同 check=corrupt_json、同 field=.flow-active）→ COUNT=1、MSG=third（最新）、type=state-integrity |
| 2 | `AC-2: 白名单 12 条不同 field → 10 条 FIFO + compliance 保留不占配额` | AC-2 | 12 wl + 2 compliance（R1/R2）→ WL=10、FIRST=field_03（最旧 2 淘汰）、LAST=field_12、COMP=2、TOTAL=12（compliance 不占配额） |
| 3 | `AC-3: 健康清零 — 全检查通过 → 白名单清空 + l2-missing/compliance 保留 + 审计行` | AC-3 | 合法 .flow-active（change_id null + 空 .specs + updated_at 0 + token_spent 1）→ 3 条 wl 清空、type 仍 `l2-missing+state-integrity`、R1 保留、stderr 含 `state-integrity cleared 3 items` |
| 4 | `AC-4a: 退场纯 type l2-missing → 整文件 rm + 审计（gate_config=L2 无 IR → R2 插入点证明）` | AC-4 And | 端到端跑 29（env HOOK_BASE_DIR/PROJECT_ROOT/FLOW_KIT_PROJECT_DIR/CONFIG_FILE/HOOK_TMP_DIR）：gate_config=**L2**（≠both）+ 无 IR 文件仍触发退场 → **correction 文件被 rm**（rm 分支）+ stderr `[29-l2-retire] clearing l2-missing (was: l2-missing)` — 证明 M0 块在 Gate 3 之前执行（R2 插入点） |
| 5 | `AC-4b: 退场合并标签 → type 剥离为 state-integrity + violations 保留` | AC-4 And | 合并标签 `l2-missing+state-integrity` → type 变 `state-integrity`、violations jq -c 逐字节不变、审计 `(was: l2-missing+state-integrity)` |
| 6 | `AC-5/6: 外来 YAML → 无 corrupt_json 追加 + 白名单清空 + 恰 1 条 foreign_state + type 剥离为 l2-missing + compliance 保留` | AC-5/AC-6 | 外来 YAML .flow-active：无 corrupt_json（陈旧清空+不再追加）、type → `l2-missing`、恰 1 条 foreign_state、**再跑仍 1 条**（幂等 · D6 去重键=check）、R1 保留、stderr 外来提示 |
| 7 | `AC-9: chisel_env 场景 — 50 条陈旧单轮收敛` | AC-9 | YAML .flow-active + 50 violations（43 corrupt_json + 6 phase_artifact_missing，field 全互异，type 合并标签）→ 单轮：violations=2（1 foreign_state + 1 compliance）、type=`l2-missing`；再跑仍 2（后续 Stop 零新增） |
| 8 | `AC-7: 外来 .flow-active 跑 33 号前后 sha256 + mtime 逐字节一致` | AC-7 | 只读不触碰：sha256sum + stat -c %Y 前后一致 |
| 9 | `AC-10: compliance 条目在清零/外来/退场路径后逐字节不变` | AC-10 | 三路径（健康清零 / 外来让位 / l2-missing 退场）各取 `jq -c` compliance 条目前后逐字节相等 |
| 10 | `R1: 写入保护 — _write_l2_missing_correction 不覆写既有 compliance 条目` | R1 (D8) | 预置 type=compliance → `sed -n '/^_write_l2_missing_correction()/,/^}/p'` 抽取真实函数 + source correction-file.sh，PROJECT_ROOT=fixture 调用 → 文件 jq -c 逐字节不变、type 仍 compliance |

## 4. Verify（真实运行输出 · verbatim）

**① make test-sync + 双源一致**
```
🔄 make test-sync: test/ → flow-kit-bundle/test/ ...
✅ test 双源已同步
DUAL_SOURCE_CONSISTENT
```

**② 新测试（test/ + flow-kit-bundle/test/ 双源各跑一次）**
```
$ bats test/test_correction_hygiene.bats        → 1..10，ok 1..10（全绿）
$ bats flow-kit-bundle/test/test_correction_hygiene.bats → ok 1..10（全绿）
```

**③ make check 四门结果（timeout 600s）**
```
make test:          763 ok / 1 not ok —— 唯一失败为预存测试 #193（非本任务文件引入，见 Deviations）
make lint:          ✅ shellcheck: no errors found
make check-validate: ✅ validate: staging coverage OK（权威行生效）
make check-test-sync: ✅ test 双源一致
```

**④ 全量测试计数**
```
ok lines:  763
not ok:    1（= 预存 test_flow_active_integrity.bats:244 "NFR: handles corrupt JSON .flow-active"）
```

## 5. 6-dim 自评

| 维度 | 评级 | 说明 |
|---|---|---|
| 正确性 | ✅ | 10/10 绿；全部断言为强断言（精确计数、jq -c 逐字节、sha256+mtime、rm 存在性），无 `2>/dev/null || true` 吞错 |
| 双源一致 | ✅ | test/ ↔ flow-kit-bundle/test/ `diff -rq` 一致 + check-test-sync 通过 |
| 覆盖映射 | ✅ | TASK.md T04 每个 action item ≥1 条测试，AC 编号直接进 @test 名（可追溯） |
| 真实实现驱动 | ✅ | 33/29 以子进程真实入口运行（`bash 33-... "$@"` 实参=fixture 绝对路径）；_fai_append_violation 走 source 真实脚本；R1 用 sed 抽取 29 号真实函数体 |
| 幂等性 | ✅ | AC-5/6 与 AC-9 显式"再跑一次"断言（foreign_state 不重复、数组长度不变）；AC-7 文件哈希不变 |
| 隔离性 | ✅ | 每测试 mktemp 新 fixture + teardown rm -rf；`cd $FIXTURE` 使脚本相对默认路径解析到 fixture（避开仓库根既有 .flow-active）；无跨测试共享状态 |

## 6. Boundary R6.5

- **写入边界**：本次仅写入 `test/test_correction_hygiene.bats`、`flow-kit-bundle/test/test_correction_hygiene.bats`（make test-sync 生成）、Makefile（仅验证 item 0，**未改动**）。其余文件零触碰。
- **断言边界**：未弱化任何断言换通过；所有断言对应 ADR-024 既定行为（FIFO=10、foreign_state 去重键=check、compliance 免配额、合并标签剥离语义）。
- **作用域边界**：未在 TASK.md 标记 T04 done（主代理复核后统一标记）。
- **行为边界验证**（R2 插入点证明已纳入测试）：AC-4a 以 gate_config=L2（Gate 3 会 skip）仍触发退场 → 证明 M0 块位于 Gate 3 之前。

## 7. Deviations（偏差）

**唯一偏差（预存，非本任务引入，需主代理处置）：**
- `test/test_flow_active_integrity.bats:244`「NFR: handles corrupt JSON .flow-active」失败（全量 763/764 中唯一）。
- **根因**：ADR-024 实现（D5：「不再追加 corrupt_json」）deliberately 移除了旧行为 —— 旧 33 号对损坏 .flow-active 追加 `corrupt_json`（message=".flow-active is not valid JSON"，`git show HEAD` 可证）；新实现改走外来让位分支（foreign_state note + 中文措辞）。该已提交测试断言旧行为，与 D5 结构性冲突，**任何实现下都不可能再通过**（即使内容以 `{` 开头命中损坏措辞，message 也是中文且 check=foreign_state）。
- **为何不修**：`write_files` 约束 = 3 个文件 ONLY；test_flow_active_integrity.bats 不在授权写入范围；R5.3 禁止弱化断言。该测试应由主代理在阶段 6 复核时同步更新（改为断言 foreign_state note 或损坏措辞）。
- 其余 3 门（lint / validate / 双源 diff）全绿；make check 整体失败仅因此 1 条预存 stale 测试。

## 8. Report（数据汇总）

- **测试数**：新增 10（双源各 10）；全量 764，763 通过
- **新测试通过率**：10/10（test/ 与 flow-kit-bundle/test/ 均绿）
- **make check**：test ✗(1 预存 stale) · lint ✅ · check-validate ✅ · check-test-sync ✅
- **Deviation**：1（test_flow_active_integrity.bats:244，D5 行为变更使旧断言失效，超出本任务写入范围）

## 主 agent 验证补充（2026-09-01 03:50）

- 独立复跑：`bats test/test_correction_hygiene.bats` → 10/10，双源 diff -q identical
- **全量回归发现 1 处旧断言冲突并修复**：test_flow_active_integrity.bats @test "NFR: handles corrupt JSON .flow-active"（L237）断言旧行为（corrupt JSON → append corrupt_json + "not valid JSON" message）。本 change F2/D5 规格化变更后行为为外来让位（AC-5 不再追加 corrupt_json；AC-6 恰 1 条 foreign_state note；AC-7 .flow-active 只读）。属"测试断言更新至新 AC"（R5.1 派生），非删减弱化（R5.3 合规）。已更新断言（含 sha256 只读校验）并双源同步。
- make check 四门最终结果：bats **764/764** + shellcheck 0 error + validate 302 项 0 漏配 + test 双源一致 ✅
