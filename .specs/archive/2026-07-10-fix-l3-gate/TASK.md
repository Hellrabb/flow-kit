# TASK: 修 L3 gate 机制三连异常（L-030）

- **Change ID**: fix-l3-gate
- **关联**: `@.specs/fix-l3-gate/REQUIREMENT.md`、`@.specs/fix-l3-gate/DESIGN.md`

---

## 波次划分

```
Wave 1:            T01                              (l3-review.sh 核心修改)
Wave 2 (parallel): T02[P], T03[P]                   (transition jq 同步 · depends on T01)
Wave 3:            T04                              (测试 + 回归 · depends on T02, T03)
```

> T01 必须最先执行——它是核心修改，T02/T03 验证 transition 同步时需要 T01 的 .done 写逻辑已就绪。

---

## 任务清单

```xml
<task id="T01" parallel="false" status="done">
  <name>l3-review.sh：重审检测 + 追加写入 + .done 条件写入</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    .specs/fix-l3-gate/DESIGN.md
    .specs/fix-l3-gate/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    修改 l3_review_run() 函数（L160-419），三处改动：

    1. **重审检测**（替换 L298-304 的覆写逻辑）：
       - 若 INDEPENDENT-REVIEW-N.md 已存在 → stat -c %Y 取 mtime
       - 比较阶段产物文件 mtime（按 phase 取主产物：1→REQUIREMENT.md / 2→DESIGN.md / 3→TASK.md / 5→TEST.md / 6|7→REVIEW.md）
       - artifact_mtime > review_mtime → is_review=true，log "re-review triggered"
       - artifact_mtime ≤ review_mtime → log "skipping"，return 0

    2. **追加写入**（替换 L298-323）：
       - 移除 awk 覆写旧 L3 段的逻辑（不再删除已有 L3 内容）
       - 首次审查写 `## L3 盲审` header（is_review=false）
       - 重审写 `## L3 重审` header（is_review=true）
       - 均用 `>>` 追加到 review_md 末尾
       - 追加前检查文件大小 > 50KB 时 warn log

    3. **.done 条件写入**（替换 L381-418）：
       - l3_verdict=pass → 写 .done（现有逻辑不变）
       - l3_verdict=fail|timeout|error → 不写 .done，log "verdict=X — .done NOT written"
       - `l3_write_timeout_done()`（L453-499）：移除 .done 写入段，改为 return 1（timeout 走统一 fail 路径，不写 .done）。调用方 `l3_review_with_timeout()` L445 改为 `return 1` 而非调用 `l3_write_timeout_done`

    详见 DESIGN.md §3.1 和 §3.2。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh && echo "SYNTAX OK"</verify>
  <done>AC-1 (重审触发) + AC-2 (fail 不写 .done) + AC-3 (pass 写 .done) 实现完成，bash -n 语法检查通过</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>31-auto-advance.sh：transition jq 加 .phase 同步</name>
  <read_files>
    flow-kit-bundle/hooks/stop/31-auto-advance.sh
    .specs/fix-l3-gate/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/31-auto-advance.sh
  </write_files>
  <action>
    修改 31-auto-advance.sh L92-95 的 transition jq：

    在现有 jq 表达式中加 `.phase = $next`：
    ```
    jq --arg next "$next_phase" --arg gk "$gate_key" \
      '.goal.current_phase = $next | .phase = $next | .goal.phases_done += [...] | .goal.gates[$gk] = "passed" | .updated_at = now'
    ```

    `--arg next` 天然产生 string，`.phase = $next` 统一为 string 类型（与 .goal.current_phase 一致）。
    详见 DESIGN.md §3.3。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/31-auto-advance.sh && echo "SYNTAX OK"</verify>
  <done>AC-4 (四字段同步) — 31-auto-advance.sh 路径：transition 后 .phase 与 .goal.current_phase 一致</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>GO.md + prompts：transition jq 模板同步 .phase</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/GO.md
    .specs/fix-l3-gate/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/GO.md
  </write_files>
  <action>
    在以下 6 个文件的 Toll-Gate transition jq 模板中加 `.phase` 同步（全部用字符串）：

    1. `1-requirement.md`：transition jq 加 `.phase = "2"`
    2. `2-design.md`：transition jq 加 `.phase = "3"`
    3. `3-task.md`：transition jq 加 `.phase = "4"`
    4. `5-test.md`：transition jq 加 `.phase = "6"`
    5. `6-review.md`：transition jq 加 `.phase = "7"`
    6. `GO.md` Phase 0→1 Toll-Gate 段：transition jq 加 `.phase = "1"`

    实施前先 grep 确认每个 prompt 中的 transition jq 精确位置。
    详见 DESIGN.md §3.4。
  </action>
  <verify>grep -rn '\.phase\s*=' flow-kit-bundle/flow-kit/prompts/1-requirement.md flow-kit-bundle/flow-kit/prompts/2-design.md flow-kit-bundle/flow-kit/prompts/3-task.md flow-kit-bundle/flow-kit/prompts/5-test.md flow-kit-bundle/flow-kit/prompts/6-review.md flow-kit-bundle/flow-kit/GO.md</verify>
  <done>AC-4 (四字段同步) — 所有 prompt/GO.md transition jq 模板均已加 .phase 同步</done>
  <depends_on>T01</depends_on>
</task>

<task id="T04" parallel="false" status="done">
  <name>新增 bats 测试 + 全量回归验证</name>
  <read_files>
    test/test_fix_l3_gate.bats
    test/
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/31-auto-advance.sh
    .specs/fix-l3-gate/REQUIREMENT.md
    .specs/fix-l3-gate/DESIGN.md
  </read_files>
  <write_files>
    test/test_fix_l3_gate.bats
  </write_files>
  <action>
    新建 test/test_fix_l3_gate.bats，覆盖本 change 的 6 条测试用例（见 DESIGN.md §7.2）：

    1. AC-1: mtime 检测——产物更新后触发重审（mock L3 API fixture）
    2. AC-1: 防重入——产物未变时跳过重审
    3. AC-2: L3 verdict=fail → .done 不存在 + exit code != 0
    4. AC-3: L3 verdict=pass → .done 存在 + L3_verdict=pass
    5. AC-4: transition jq 后四字段一致（jq 验证）
    6. AC-5: 回退方向 transition 不要求 .done

    Mock 策略：设置 L3_FIXTURE_RESPONSE 环境变量指向预置 JSON fixture 文件，
    在 l3_review_run() 中检测该变量后跳过 curl 直接读取 fixture。
    若 fixture 机制不可行，则至少覆盖不依赖 L3 API 的纯文件系统/逻辑测试。

    完成后跑全量回归：npx bats test/ → 0 fail。
  </action>
  <verify>npx bats test/test_fix_l3_gate.bats</verify>
  <done>所有 AC 对应测试用例通过 + npx bats test/ 全量 0 fail（基线 407 tests）</done>
  <depends_on>T02, T03</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 [P] 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在文件末尾「阻塞日志」记录）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
