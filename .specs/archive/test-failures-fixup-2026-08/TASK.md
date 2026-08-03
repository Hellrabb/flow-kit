# TASK · test-failures-fixup-2026-08

> Phase 3 任务清单 · 2026-08-03

---

## Wave 1（并行 2 task）

### T01 · AC-A1 + AC-B1/B2/B3 测试 assertion 重写
- **action**:
  1. 修改 `test/test_gate_integrity.bats` AC-3 5站点 test (line 148-156)：grep 4 文件循环 + total_matches 检查
  2. 修改 `test/test_lessons_cleanup.bats` 3 tests：
     - AC-5 (line 144-158)：3 子断言 per-sub-assertion OR 双文件
     - AC-6 失败阻断 (line 174-184)：第一子断言 OR；第二子断言 pattern 改 `禁止进入.*toll-gate`
     - 边界 子段编号 (line 230-236)：grep tdd-workflow.md 的 4 个 #### 标题
  3. cp 修改后的 2 个 bats 文件到 flow-kit-bundle/test/
- **verify**: `npx bats test/test_gate_integrity.bats test/test_lessons_cleanup.bats` exit 0
- **done**: 2 bats 文件修改 + 同步到 bundle/test/，6 个原 fail 测试全 pass

### T02 · AC-C1 shellcheck 指令添加
- **action**:
  1. 在以下 7 个文件首行（在任何注释之前）添加 `# shellcheck shell=bash`：
     - flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
     - flow-kit-bundle/hooks/stop/lib/l3-api.sh
     - flow-kit-bundle/hooks/stop/lib/l3-truncate.sh
     - flow-kit-bundle/hooks/stop/lib/l3-done.sh
     - flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh
     - flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh
     - flow-kit-bundle/hooks/pre-tool-use/gate-checks-review.sh
- **verify**: `for f in <7 files>; do shellcheck -e SC1091 "$f" || exit 1; done` + `make lint` exit 0
- **done**: 7 文件首行含 `# shellcheck shell=bash`，shellcheck SC2148 不再触发

## Wave 2（serial · 依赖 W1）

### T03 · Sync verify + commit + bookkeeping
- **action**:
  1. `diff -r test flow-kit-bundle/test` 应输出空（双源一致）
  2. `npx bats test/` 全量跑 → 应 0 fail（原 657 ok → 现在 662 ok / 0 fail）
  3. 更新 `.specs/CONTEXT.md`：添加 change-id 引用
  4. 更新 `.specs/CHANGELOG.md`：追加 row entry
  5. 更新 `.specs/LESSONS.md`：5 个 pre-existing fail 标注 ✅ Resolved
  6. git commit
- **verify**: `git log --oneline --grep="test-failures-fixup-2026-08" | wc -l` ≥1
- **done**: commit 完成，所有 .specs 同步

---

## AC 映射

- AC-A1 → T01 (gate regex test)
- AC-B1/B2/B3 → T01 (lessons cleanup tests)
- AC-C1 → T02 (shellcheck)
- AC-D1/D2 → T03 (sync + regression)
- AC-E1/E2 → T03 (commit + .specs sync)
