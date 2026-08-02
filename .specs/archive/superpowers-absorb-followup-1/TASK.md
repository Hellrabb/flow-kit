# TASK · superpowers-absorb-followup-1

> 4 任务 / 3 波次 · 全部为测试补强 · 无生产代码改动

---

## 范围与约束

- **read_files**: REQUIREMENT.md / DESIGN.md / CHANGE.md / `flow-kit-bundle/flow-kit/scripts/{review-package,task-brief}` / `test/test-l2-first-correction.bats` / `test/fixtures/`
- **write_files**: 仅 `test/*.bats` + `test/fixtures/security/*` + `flow-kit-bundle/test/*.bats`（双源同步后）
- **禁止触碰**: `flow-kit-bundle/flow-kit/scripts/*` / `flow-kit-bundle/flow-kit/prompts/*` / `flow-kit-bundle/hooks/*` / `Makefile` / `package-flow-kit.sh`
- **禁动清单 exception**: 无（本次完全不动禁动清单内文件）

---

## Wave 1（并行 · 2 任务）

### T01 · test_scripts_security.bats + fixture
**id**: T01
**name**: 新建 SEC 注入测试（6 cases）+ fixture 临时 git repo
**model-tier**: standard

**read_files**:
- `flow-kit-bundle/flow-kit/scripts/review-package`
- `flow-kit-bundle/flow-kit/scripts/task-brief`
- `.specs/superpowers-absorb-followup-1/REQUIREMENT.md` (AC-A1 ~ AC-A6)

**write_files**:
- `test/test_scripts_security.bats` (新)
- `test/fixtures/security/TASK_sec.md` (新, 含注入字符串的 mock TASK.md)

**action**:
1. 创建 `test/fixtures/security/TASK_sec.md`，含 T01/T02/T03 三个 task 块，T01 name 含 `$(touch /tmp/flow-kit-sec-test-2)` 注入字符串
2. 新建 `test/test_scripts_security.bats`，6 个 @test (SEC-1 ~ SEC-6)
3. setup() 段：
   - `export LC_ALL=en_US.UTF-8` (若不存在则 skip SEC-6)
   - 创建 `test/fixtures/security/repo/` 临时 git repo（`git init` + config user + 注入 commit msg）
4. teardown() 段：清理 `/tmp/flow-kit-sec-test*` + 临时 repo
5. 每个 @test 实现按 REQUIREMENT AC-A1 ~ AC-A6 的 Given/When/Then

**verify**:
```bash
npx bats test/test_scripts_security.bats
# 期望：6 passed, 0 failed
! test -e /tmp/flow-kit-sec-test && ! test -e /tmp/flow-kit-sec-test-2  # teardown 清理（POSIX 合规）
```

**done**: 6 tests pass + 无 /tmp 残留

---

### T02 · test_integration_smoke.bats
**id**: T02
**name**: 新建 INT 集成测试（5 cases）
**model-tier**: standard

**read_files**:
- `.specs/superpowers-absorb-followup-1/REQUIREMENT.md` (AC-B1 ~ AC-B5)
- `flow-kit-bundle/flow-kit/GO.md`
- `flow-kit-bundle/flow-kit/prompts/6-review.md`
- `flow-kit-bundle/flow-kit/prompts/4-dev.md`

**write_files**:
- `test/test_integration_smoke.bats` (新)

**action**:
1. 新建 `test/test_integration_smoke.bats`，5 个 @test (INT-1 ~ INT-5)
2. setup() 段：与 T01 共享 `test/fixtures/security/repo/` 或自建简单 fixture
3. INT-1: 调 `flow-kit-bundle/flow-kit/scripts/review-package HEAD~1 HEAD` → grep 三个 headers（## Commits / ## Files changed / ## Diff）
4. INT-2: 调 `awk -f flow-kit-bundle/flow-kit/scripts/task-brief fixtures/TASK_sec.md T02` → 验证输出只含 T02 块
5. INT-3: `grep -cE 'prompts/[0-9]' flow-kit-bundle/flow-kit/GO.md` → 期望 ≥10
6. INT-4: `! grep -qE 'Round [123]' flow-kit-bundle/flow-kit/prompts/6-review.md`
7. INT-5: 三个 grep `task-brief` / `model-tier` / `task_progress` 各 ≥1 匹配 in `flow-kit-bundle/flow-kit/prompts/4-dev.md`

**verify**:
```bash
npx bats test/test_integration_smoke.bats
# 期望：5 passed, 0 failed
```

**done**: 5 tests pass

---

## Wave 2（顺序 · 1 任务）

### T03 · 修 test-l2-first-correction.bats AC-I (b)(c)
**id**: T03
**name**: L-067 root cause 调查 + mock-only 修复
**model-tier**: top

**read_files**:
- `test/test-l2-first-correction.bats` (现有，重点 setup() 和 AC-I b/c 测试体)
- `flow-kit-bundle/hooks/stop/29-independent-review.sh` (只读，理解 mock 期望)
- `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh` (只读，理解 correction 路径)
- `.specs/superpowers-absorb-followup-1/DESIGN.md` § 1 D3 + § 3 状态机

**write_files**:
- `test/test-l2-first-correction.bats` (修改 setup() + AC-I b/c 相关 mock state)

**action**:
1. **Probe**: `npx bats test/test-l2-first-correction.bats` 复现 AC-I (b)(c) fail，记录 fail 原因
2. **Check 1**: 读 setup() 中 mock .flow-active 是否含 `phase_sub_goals` 字段
   - 若缺：在 setup() 中补 `--argjson phase_sub_goals '{}'` 或对应字段
3. **Rerun**: 跑测试，验证 pass? 若 pass → done
4. **Check 2** (若 step 3 fail): 比对 mock 写 correction 路径 vs `flow-kit-resume.sh` 中 `correction_file_read()` 的 read path
   - 若不一致：在 setup() 中改 mock 写入路径与 SessionStart 一致（项目根相对路径）
5. **Rerun**: 跑测试，验证 pass? 若 pass → done
6. **[ESCALATE]** (若仍 fail): 按 DESIGN § 3 状态机 [ESCALATE] 分支处理 — 不偷偷改生产代码
7. **AC-C1 验证**: `git diff --name-only` 应仅含 `test/` + `flow-kit-bundle/test/` 下文件

**verify**:
```bash
npx bats test/test-l2-first-correction.bats
# 期望：全绿（包括 AC-I a/b/c）
# AC-C1 git diff 自动断言：除 test/ 和 flow-kit-bundle/test/ 外不应有其他文件改动
git diff --name-only | grep -vE '^(test/|flow-kit-bundle/test/)' | grep -q . && {
  echo "❌ AC-C1 violated: production code touched" >&2
  exit 1
} || echo "✅ AC-C1 OK: only test files changed"
```

**done**: AC-I b/c 全绿 + git diff 仅含 test 文件

---

## Wave 3（顺序 · 1 任务 · 依赖 Wave 1+2 完成）

### T04 · 双源同步 + 全量回归 + package validate
**id**: T04
**name**: make test-sync + 全量 bats + package validate
**model-tier**: standard

**read_files**: 无（操作型任务）

**write_files**:
- `flow-kit-bundle/test/test_scripts_security.bats` (cp from test/)
- `flow-kit-bundle/test/test_integration_smoke.bats` (cp from test/)
- `flow-kit-bundle/test/test-l2-first-correction.bats` (cp from test/, T03 修改后的版本)

**action**:
1. `make test-sync` 同步 3 个 .bats 文件到 `flow-kit-bundle/test/`
2. `diff test/test_scripts_security.bats flow-kit-bundle/test/test_scripts_security.bats` 确认 0 差异（其他 2 个同）
3. `npx bats test/` 全量跑
4. `bash package-flow-kit.sh --validate` 验证打包完整性

**verify**:
```bash
make test-sync
diff test/test_scripts_security.bats flow-kit-bundle/test/test_scripts_security.bats && echo "sync OK"
diff test/test_integration_smoke.bats flow-kit-bundle/test/test_integration_smoke.bats && echo "sync OK"
diff test/test-l2-first-correction.bats flow-kit-bundle/test/test-l2-first-correction.bats && echo "sync OK"
# AC-E2: 新增测试性能 ≤5s（结构性硬门槛）
SECONDS=0
npx bats test/test_scripts_security.bats test/test_integration_smoke.bats
ELAPSED=$SECONDS
[ "$ELAPSED" -le 5 ] || { echo "❌ AC-E2 violated: ${ELAPSED}s > 5s budget" >&2; exit 1; }
echo "✅ AC-E2 OK: ${ELAPSED}s ≤ 5s"
# 全量回归
npx bats test/
# 期望：≥656 tests, 0 failed
bash package-flow-kit.sh --validate
# 期望：exit code = 0 (warnings OK)
```

**done**: AC-D1 (双源同步) + AC-E1 (package validate) + AC-E2 (新测试 ≤5s) + AC-E3 (teardown 清理) 全过

---

## Task Graph

```
Wave 1 (parallel):
  ├── T01 (SEC tests + fixture)
  └── T02 (INT tests)
Wave 2 (sequential):
  └── T03 (L-067 fix, depends on T01 fixture pattern)
Wave 3 (sequential):
  └── T04 (sync + validate, depends on T01+T02+T03 done)
```

## Phase 4 实施约束

- 每个 task 完成后立即跑 verify，verify fail 不算 done
- T03 必须按 DESIGN § 3 状态机走，遇 [ESCALATE] 立即暂停通知用户
- T04 是最后兜底，必须全量回归 0 fail 才能 phase 4 → 5 transition
