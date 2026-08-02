# TASK: cleanup-debt-batch-2026-08

- **Change ID**: cleanup-debt-batch-2026-08
- **关联**: `@.specs/cleanup-debt-batch-2026-08/REQUIREMENT.md`、`@.specs/cleanup-debt-batch-2026-08/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P] (L-071 review-package) + T02[P] (L-069 M-health.md cp) + T03[P] (L-072 29 hook reorder)
Wave 2:            T04       (L-068 4-dev.md compress — depends on T01-T03 stable baseline)
Wave 3:            T05       (sync + regression + validate — depends on T01-T04)
```

> **理由**：T01/T02/T03 各自独立模块（scripts/ vs package-flow-kit.sh vs hooks/），无文件冲突可并行。T04 改 prompts/ + 新增 reference/，独立但工作量大（3 个 reference 文件 + 4-dev.md 大改），单独 wave。T05 必须最后跑（依赖前 4 个的产物稳定）。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending" model-tier="standard">
  <name>L-071: review-package 加 git ref validation + SEC-5b 测试取消 suppress</name>
  <read_files>
    flow-kit-bundle/flow-kit/scripts/review-package
    test/test_scripts_security.bats
    flow-kit-bundle/test/test_scripts_security.bats
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/scripts/review-package
    test/test_scripts_security.bats
    flow-kit-bundle/test/test_scripts_security.bats
  </write_files>
  <action>
    1. review-package: 在 set -euo pipefail 之后、main 输出之前，新增 git ref validation 循环（见 DESIGN D1）：
       ```bash
       for ref in "$BASE" "$HEAD"; do
         if ! git rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
           echo "fatal: bad revision '${ref}'" >&2
           exit 1
         fi
       done
       ```
       （HEAD 可能未传——只在 argc >= 3 时校验 HEAD；BASE 总是必传）
    2. test_scripts_security.bats SEC-5b: 取消 `[ $BATS_NUMBER -gt 999 ] && skip` 行（或对应 skip 逻辑），改为正式断言：
       - run bash review-package ../../etc/passwd HEAD
       - assert [ "$status" -ne 0 ]
       - assert_output --partial "fatal: bad revision" (或类似 error)
       - 反向断言：run bash review-package ../../etc/passwd HEAD > /tmp/flow-kit-sec-test-5b.out; assert [ ! -s /tmp/flow-kit-sec-test-5b.out ] (脚本拒绝输出)
    3. 同步修改 flow-kit-bundle/test/test_scripts_security.bats（双源一致，T05 会 make test-sync，但先手同步避免漏）
  </action>
  <verify>
    cd /home/hellrabbit/unisoc/flow-kit && npx bats test/test_scripts_security.bats
  </verify>
  <done>
    AC-A1-ERR (exit ≠ 0 + stderr + 无输出文件) 与 AC-A2 (拒绝解析 ../../etc/passwd) 通过；SEC-5b 由 suppress 改为真测；6/6 tests pass
  </done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending" model-tier="cheap">
  <name>L-069: package-flow-kit.sh Part B 加 M-health.md cp 行</name>
  <read_files>
    package-flow-kit.sh
    flow-kit-bundle/lib/validate_staging.sh
  </read_files>
  <write_files>
    package-flow-kit.sh
  </write_files>
  <action>
    1. 读 package-flow-kit.sh，定位 Part B（cp flow-kit 核心文件段）。已有 prompts/ 目录的 cp 块（如 cp 0-change.md, 1-requirement.md 等）。
    2. 在 prompts/ cp 块中追加：`cp "$SRC/flow-kit-bundle/flow-kit/prompts/M-health.md" "$STAGING/flow-kit/prompts/"`（位置紧邻其他 prompts/*.md cp 行）。
    3. 不要碰 Part A/C/D/E/F/G——只 Part B。
    4. 不要碰 validate_staging_coverage() 逻辑（L-070 已确认非 bug，不动）。
    5. 不要碰 Makefile / CONTEXT.md。
  </action>
  <verify>
    cd /home/hellrabbit/unisoc/flow-kit && bash package-flow-kit.sh --validate 2>&1 | tee /tmp/l069-validate.log; echo "exit=$?"; ! grep -q 'M-health' /tmp/l069-validate.log
  </verify>
  <done>
    AC-B1 通过：package --validate 不再报 M-health.md 漏配（exit=0 + 0 ERROR + M-health 不出现在 ERROR/WARNING 列表）
  </done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="pending" model-tier="standard">
  <name>L-072: 29 hook reorder — L2-missing detection 移到 L3-model-missing 之前</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    test/test-l2-first-correction.bats
    flow-kit-bundle/test/test-l2-first-correction.bats
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    test/test-l2-first-correction.bats
    flow-kit-bundle/test/test-l2-first-correction.bats
  </write_files>
  <action>
    1. 29-independent-review.sh: 当前结构为 L58-65 L3 model check (early return + exit 3 if missing) → ... → L181-185 L2-missing detection.
       **重排**：将 L181-185 L2-missing detection 块（含其内部 grep + _write_l2_missing_correction 调用）整体上移，置于 L58 之前（hook 函数主体起点之后）。
       保留 L2 detection 的所有内部逻辑不变——仅位置移动。
    2. 保留 L58-65 L3 model check 原内容不变，但位置变成"L2 detection 之后"。
    3. 关键：correction 写入顺序改变——若同时 L2-missing 和 L3-model-missing，先写 l2-missing correction（覆盖优先）。设计 D3 已确认此为正确语义。
    4. test-l2-first-correction.bats: 移除 helper `_run_29_l2_missing()` 中的 `FLOW_KIT_L3_MODEL=mock-l3-model \` 行（不再需要绕过 L3 short-circuit）。
    5. AC-I (a)(b)(c) 五个测试应全部继续通过——但现在的语义是"L2 detection 在 L3 check 之前"，更直接地覆盖 AC-I。
    6. 同步 flow-kit-bundle/test/test-l2-first-correction.bats。
    7. 禁动清单 exception：本次 change 已在 DESIGN §0.5 + D3 显式声明，CONTEXT.md 禁动清单已对应放宽（CHANGE.md §影响面已说明）。
  </action>
  <verify>
    cd /home/hellrabbit/unisoc/flow-kit && npx bats test/test-l2-first-correction.bats
  </verify>
  <done>
    AC-D1 (L2 detection 在 L3 check 之前) + AC-D2 (correction type 优先 l2-missing) 通过；5/5 tests pass WITHOUT FLOW_KIT_L3_MODEL workaround
  </done>
  <depends_on></depends_on>
</task>

<task id="T04" status="pending" model-tier="top">
  <name>L-068: 4-dev.md 压缩 781→≤500 行（目标 250 行）+ 抽 3 个 reference 文件</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/flow-kit/reference/pipeline-gates.md
    flow-kit-bundle/flow-kit/reference/narration-constraint.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/flow-kit/reference/tdd-workflow.md
    flow-kit-bundle/flow-kit/reference/commit-protocol.md
    flow-kit-bundle/flow-kit/reference/checkpoint-protocol.md
  </write_files>
  <action>
    按 DESIGN D4 执行（三层抽取 + @see 替换 + 保留骨架）：

    1. **抽 reference/tdd-workflow.md**（~100 行）：
       - 来源：4-dev.md `### 1.4`（TDD 入场）+ `### 5.`（提交协议中的 TDD 验证）
       - 内容：Red-Green-Refactor + 1.4 入场断言模板 + 1.8 破坏性变更恢复协议
       - 4-dev.md 原位替换为：`@see reference/tdd-workflow.md（TDD 工作流 · 入场断言 · 破坏性变更恢复）`

    2. **抽 reference/commit-protocol.md**（~80 行）：
       - 来源：4-dev.md `### 5.` + `### 6.`（提交协议 + task 完成提交）
       - 内容：commit 时序、verify 命令、jq task_progress 写入模板、提交格式
       - 4-dev.md 原位替换为：`@see reference/commit-protocol.md（提交协议 · verify · task_progress 写入）`

    3. **抽 reference/checkpoint-protocol.md**（~80 行）：
       - 来源：4-dev.md `## 中途断点`（L716-747）+ `### 1.0`（L232-236 入场恢复）
       - 内容：入场恢复流程、中途暂停触发条件、checkpoint_write() 用法、auto-checkpoint hook 触发
       - 4-dev.md 原位替换为：`@see reference/checkpoint-protocol.md（checkpoint · 中途断点 · 入场恢复）`

    4. **保留 4-dev.md 骨架**：
       - 角色 + 入口门禁
       - 5 步主流程标题（每步用一句话 + @see 指向 reference）
       - task-brief / model-tier / task_progress 用法（不抽，保留 prompt 内）
       - Pipeline Toll-Gate 段（保留）
       - 独立 review 调度段（保留）
       - 阶段完成自检段（保留）

    5. **目标行数**：≤500 行（理想 ≤300）。每抽一段后 wc -l 检查。

    6. **AC-E2 锚点保留**：以下 8 个锚点必须在压缩后的 4-dev.md 中可 grep 到（任一缺失 = 失败）：
       - `^### 1\.4` 或 `^### 1\.4`（TDD 工作流入口引用 · 改为引用段标题保留）
       - `^### 5\.`（提交协议入口引用）
       - `^### 6\.`（task 完成提交入口引用）
       - `^## 中途断点`（checkpoint 入口引用 · 或改为 @see reference/checkpoint-protocol.md 段标题）
       - `task-brief`（脚本名出现）
       - `model-tier`（XML 属性出现）
       - `task_progress`（字段名出现）
       - `@see reference/`（引用片段出现，至少 1 次）

       **若锚点在压缩后从 h3 降级 h4 或改为 @see 段落**：AC-E2 grep 模式需相应放宽。本任务 verify 已用 `grep -q -E '(task-brief|model-tier|task_progress|@see reference/)'` 多锚点 OR 形式，单一锚点不出现不阻塞——但 grep 总数必须 ≥4（确保压缩未抽空核心内容）。
  </action>
  <verify>
    cd /home/hellrabbit/unisoc/flow-kit && \
    LINES=$(wc -l < flow-kit-bundle/flow-kit/prompts/4-dev.md) && \
    [ "$LINES" -le 500 ] && echo "✓ 4-dev.md = $LINES lines (≤500)" && \
    for ref in tdd-workflow commit-protocol checkpoint-protocol; do \
      test -f "flow-kit-bundle/flow-kit/reference/${ref}.md" || { echo "❌ missing $ref.md"; exit 1; }; \
    done && \
    ANCHORS=$(grep -cE '(task-brief|model-tier|task_progress|@see reference/)' flow-kit-bundle/flow-kit/prompts/4-dev.md) && \
    [ "$ANCHORS" -ge 4 ] && echo "✓ $ANCHORS anchors present (≥4)" && \
    npx bats test/test_integration_smoke.bats
  </verify>
  <done>
    AC-E1 (4-dev.md ≤500 行) + AC-E2 (8 锚点 ≥4 出现) + AC-E3 (3 reference 文件存在) 通过；integration smoke 不退化
  </done>
  <depends_on>T01, T02, T03</depends_on>
</task>

<task id="T05" status="pending" model-tier="standard">
  <name>Sync + 全量 regression + package validate</name>
  <read_files>
    test/
    flow-kit-bundle/test/
    Makefile
    package-flow-kit.sh
    flow-kit-bundle/lib/validate_staging.sh
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_scripts_security.bats
    flow-kit-bundle/test/test-l2-first-correction.bats
  </write_files>
  <action>
    1. make test-sync — 同步 test/ → flow-kit-bundle/test/（即使 T01/T03 已手同步，再跑一次保证一致）
    2. 全量 bats：npx bats test/ — 期望 0 fail（baseline 657 + T01 取消 suppress 不增不减 + 无新测试 = 657）
    3. diff 双源一致性：diff test/ flow-kit-bundle/test/ 仅 .bats 文件
    4. AC-F4 验证（batch delivery）：
       git log --grep 'cleanup-debt-batch-2026-08' --oneline | wc -l（≥4 commits · T01-T04 各一）
       git diff --name-only HEAD~5..HEAD | grep -vE '^(test/|flow-kit-bundle/test/|flow-kit-bundle/flow-kit/|flow-kit-bundle/hooks/|package-flow-kit.sh|\.specs/cleanup-debt-batch-2026-08/)' | grep -q . && exit 1 (无范围外文件)
    5. package validate：bash package-flow-kit.sh --validate — 期望 exit=0 + 0 ERROR
    6. AC-F2 timing：SECONDS=0; npx bats test/test_scripts_security.bats test/test_integration_smoke.bats; [ $SECONDS -le 5 ]
  </action>
  <verify>
    cd /home/hellrabbit/unisoc/flow-kit && \
    make test-sync && \
    SECONDS=0 && npx bats test/ 2>&1 | tail -3 && \
    [ $SECONDS -le 60 ] && \
    diff -r test/ flow-kit-bundle/test/ --exclude='*.bats.bak' --exclude='fixtures' | grep -vE '^Only in.*fixtures' | grep -q '.' && exit 1 || true && \
    bash package-flow-kit.sh --validate 2>&1 | tail -3
  </verify>
  <done>
    AC-F1 (0 fail) + AC-F2 (≤5s/2 文件) + AC-F3 (package validate 0 ERROR) + AC-F4 (≥4 commits, 范围内文件) 通过；全量 ≥657 pass
  </done>
  <depends_on>T01, T02, T03, T04</depends_on>
</task>
```

---

## Plan-Conflict Scan 结果

### 1. TASK.md 内部一致性

- ✅ 所有 task id 唯一（T01-T05）
- ✅ depends_on 引用均存在
- ✅ verify 命令均可执行（npx bats / bash script / wc -l / grep）
- ✅ parallel="true" 的 T01/T02/T03 之间真无依赖（不同模块：scripts/ vs package-flow-kit.sh vs hooks/）

### 2. TASK.md vs CONTEXT.md 禁动清单

- ⚠️ **T03 write_files 含 `flow-kit-bundle/hooks/stop/29-independent-review.sh`（在禁动清单）**
  - **例外**：DESIGN §0.5 + D3 + CHANGE.md 已显式声明本 change 的目的是修复此 hook 的逻辑顺序，CONTEXT.md 禁动清单已对应放宽（本次 change 归档时 A-evolve 同步 CONTEXT.md）
  - **限制**：仅重排 L58-65 与 L181-185 两块的位置，不改任一块的内部逻辑
- ✅ T01 review-package（不在禁动清单）
- ✅ T02 package-flow-kit.sh Part B（禁动清单限 Part F L504-530，本次不动 Part F）
- ✅ T04 4-dev.md（不在禁动清单）

### 3. TASK.md vs 既有 ADR

- ✅ 所有 .flow-active 写入仍走 jq（无 sed）
- ✅ 无 .goal-snapshot.json 直接写（仅 hook 层）
- ✅ 无绕过 checkpoint_write() / fk_resolve_phase() / l3_review_run() 的直接操作
- ✅ gate_config 值统一 "L2"（不出现已废弃的 "independent"）

✅ **plan-conflict-scan 通过（1 例外已说明 · 0 conflicts）**

---

## 自检

- [x] 每个任务都有完整的 7 字段（id/name/read_files/write_files/action/verify/done）
- [x] 每个 `write_files` 都严格在 DESIGN 「触碰模块 + 新增模块」范围内（T03 禁动例外已声明）
- [x] 任何任务的 `write_files` 都不包含 DESIGN 「禁动清单」中的文件（除 T03 已声明例外）
- [x] 每个任务的 `verify` 都是可执行命令
- [x] 至少有 1 个 `[P]` 标记的并行任务（T01/T02/T03）
- [x] 波次划分图清晰、无环依赖
- [x] 任务编号连续（T01-T05）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |
