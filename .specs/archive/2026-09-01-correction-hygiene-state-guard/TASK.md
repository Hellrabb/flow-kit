# TASK — correction-hygiene-state-guard

> 依据：REQUIREMENT.md（10 AC）+ DESIGN.md（D1-D8）+ ADR-024（9 check 白名单）。
> 维护源：`flow-kit-bundle/hooks/`（唯一源，.claude/hooks 为运行时副本）。测试双源：`test/` + `flow-kit-bundle/test/`（make test-sync）。

```
Wave 1 (parallel): T01[P] (correction-file.sh), T03[P] (29号)
Wave 2:            T02 (33号, depends T01)
Wave 3:            T04 (bats 全量, depends T01+T02+T03)
```

<task id="T01" parallel="true">
  <name>correction-file.sh 新增共享去重/容量 helper</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
    flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh
    .specs/correction-hygiene-state-guard/DESIGN.md
    .specs/adr/024-correction-violations-scope.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
  </write_files>
  <action>
    新增两个导出函数（不改既有 4 函数签名 exists/read/write/clear）：
    1. `correction_file_dedupe(file)`：violations[] 中同 `check`+`field` 组合只保留最新（数组末尾）一条。作用域限制：仅过滤 check ∈ ADR-024 白名单（9 种 state-integrity check 名，白名单以 readonly 数组常量 CORRECTION_STATE_INTEGRITY_CHECKS 形式定义在本文件）；compliance 条目（无 check 字段或 check 不在白名单）原样保留（AC-10 / D1）。实现用单步 jq 表达式，保持原子写（mktemp + mv，沿用文件内既有 tmp+mv 范式）。
    2. `correction_file_trim(file, max)`：先调 dedupe，再对白名单内条目按 FIFO（保留数组末尾 max 条）淘汰超额项（AC-2 / D2，先去重后淘汰）；compliance 条目不计入配额、永不淘汰。文件无 violations 数组或非法 JSON 时静默返回非零（调用方容错）。
    3. `correction_file_strip_type(file, segment)`（盲审 R3 共享抽象，DESIGN §9.1）：从 `+` 连接的合并标签 type 中剥离指定段（如 strip_type file "l2-missing" → l2-missing+state-integrity 变 state-integrity；strip_type file "state-integrity" → l2-missing）；segment 不存在时 no-op；violations[] 原样保留；非法 JSON/无 type 时返回非零。T02（外来清空剥 state-integrity 段）与 T03（退场剥 l2-missing 段）共用，禁止双份内联。**边界契约（盲审 N3）**：纯 type（无 `+` 连接符）时 no-op 返回非零——剥离仅对合并标签有意义，纯 type 场景由调用方走各自分支（退场→rm / 外来→保留），共享函数不对纯 type 做隐式变更。
    白名单 9 值（逐字，顺序与 33 号源码一致）：corrupt_json / change_id_dangling / change_id_null_with_dirs / phase_artifact_missing / pipeline_phase_artifact_missing / pipeline_gate_not_passed / pipeline_gate_phase_mismatch / stale_updated_at / token_spent_unmaintained。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/correction-file.sh && shellcheck -e SC1091 -S error flow-kit-bundle/hooks/stop/lib/correction-file.sh && ~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats test/test_correction_file.bats test/test_common.bats</verify>
  <done>✅ done 2026-09-01T03:20:00+08:00 — 三函数+常量导出（L158/L172/L184/L220/L269）；bats 35/35（correction-file 10+common 25）；smoke: dedupe 保最新/compliance 字节保留/trim FIFO/strip 双态+纯type边界rc1/segment不在rc0/错误语义rc1 全过</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="false">
  <name>33 号改造：去重/容量接线 + 健康清零 + 外来清空</name>
  <read_files>
    flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
    .specs/correction-hygiene-state-guard/DESIGN.md
    .specs/correction-hygiene-state-guard/REQUIREMENT.md
    .specs/adr/024-correction-violations-scope.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh
  </write_files>
  <action>
    三处改造（D3/D5/D6 + AC-3/5/6/10）：
    1. `_fai_append_violation` 每次 append 后调用 T01 的 `correction_file_dedupe` + `correction_file_trim file 10`（AC-1/2）。
    2. 健康清零（AC-3/D3）：本轮全部检查通过（9 处 append 均未触发）且 `.flow-active` 为合法 JSON 时——在 33 号出口处读取 correction，violations[] 中 check ∈ 白名单的条目全部移除；l2-missing / model-missing / foreign-state / compliance 保留。若清除后白名单条目数为 0 且原本 >0，写一行 stderr 审计（"state-integrity cleared N items"）。
    3. 外来清空（AC-5/6/D5/D6）：入口 L25 `jq empty` 失败分支重写——不再 append corrupt_json；改为 33 号单一 actor 外来让位：① correction 中白名单类 violation 全部清空 ② type 为合并标签（含 state-integrity 段）时调 `correction_file_strip_type file "state-integrity"` 剥离（l2-missing+state-integrity → l2-missing）③ violations 追加 1 条 `{check:"foreign_state", message:"外来的状态文件，已让位并清除 state-integrity 状态。如果你是 flow-kit，请重新 /flow 启动。", field:"flow_active", detected_at:now}`（去重键=check，已存在则不重复）④ 写一行 stderr 提示（SessionStart 可收割）。语法错误（合法 JSON 但非 flow-kit 结构）同样走外来路径但 message 措辞区分「损坏」。compliance 条目全程保留（AC-10）。**全程只读 .flow-active 本体，绝不写/转换/删除外来文件（AC-7）**。
    注意保持既有 exit code 语义（非破坏性失败不阻塞 stop 链）。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh && shellcheck -e SC1091 -S error flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh && ~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats test/test_stop_chain.bats</verify>
  <done>✅ done 2026-09-01T03:45:00+08:00 — bash-n+shellcheck OK；bats 90/90 四文件全绿；smoke: S1 去重3→1+FIFO cap10 / S2 健康清零 7→2 保 l2-missing+compliance+审计行 "state-integrity cleared N items"+幂等 / S3 外来 no-append+type剥离+note恰1条+compliance保留+AC-7 sha256不变 全过</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="true">
  <name>29 号改造：l2-missing 退场前置 + 写入 compliance-priority 条件写</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    .specs/correction-hygiene-state-guard/DESIGN.md
    .specs/correction-hygiene-state-guard/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    三处改造（D4/D8 + AC-4 + 盲审 R2/N2）：
    1. 退场检测（M0 节点，盲审 R2）：在 Gate 3（`fk_independent_review_gate_active "$phase" "L3"` early-exit，L47-50）**之前**插入 l2-missing 退场检测块，与 L3 激活判定解耦。触发条件：correction 存在且 type 含 l2-missing（`contains("l2-missing")` 语义——jq `contains` 或 `test("l2-missing")`，禁止精确相等），且（对应 IR 文件已含 `## L2 盲审` 段 **或** gate_config 非 both）。动作双态（D4）：纯 type l2-missing → 走 `write_model_missing_clear` 同款文件级 rm（type 精确比较后 rm）；合并标签 l2-missing+state-integrity → 调 T01 的 `correction_file_strip_type file "l2-missing"` 剥离（type 改回 state-integrity），violations[] 原样保留。清除前写 stderr 审计（记录清除前 type）。gate=both 且 IR 无 L2 段时不触发退场（L2 仍缺失，既有 l2-missing 写入逻辑保持）。
    2. L38 yield 显式化（盲审 R2）：`jq empty ... || exit 0` 行为保持不变（DESIGN 2.1 O 节点：静默退出、不写 correction，AC-5 已满足），但在该分支加注释显式说明「外来/损坏 .flow-active 让位由 33 号承担（F2 单一 actor），29 号此处静默让位」——消除 DESIGN 0.5.1/CHANGE.md 例外登记与实际 diff 的对账歧义。
    3. 写入保护（D8，盲审 R1）：`_write_l2_missing_correction`（L24-30）由 `jq -n > file` 覆写改为 compliance-priority 条件写——单步 jq `if .type=="compliance" and ((.violations // []) | length > 0) then . else $new end` 对既有文件内容判断 + mktemp 原子写（逐字对齐 write_model_missing_correction correction-file.sh:116-123 范式）。correction 已有 compliance 条目时不覆盖。
    注意：29 号为 CONTEXT 禁动清单文件，本任务改动范围 = 退场检测块（新增）+ 写入函数体（改造），属 CHANGE.md 已登记例外（l2-missing 生命周期）；其余段落（gate 编排/L3 流程/l2-missing 检测触发条件）禁动。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/29-independent-review.sh && shellcheck -e SC1091 -S error flow-kit-bundle/hooks/stop/29-independent-review.sh && ~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats test/test_stop_chain.bats test/test_independent_review_model.bats</verify>
  <done>✅ done 2026-09-01T03:20:00+08:00 — bats 55/55（stop_chain 43+model 12）；smoke: R1 写入保护 compliance 保留/M0 合并标签剥离保 violations+审计行/M0 纯 type rm/不触发分支 0 审计+D4 门重写 全过</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="false">
  <name>bats 新增 test_correction_hygiene.bats（双源）+ 全量回归</name>
  <read_files>
    .specs/correction-hygiene-state-guard/REQUIREMENT.md
    .specs/correction-hygiene-state-guard/DESIGN.md
    test/test_stop_chain.bats
    test/test_correction_file.bats
  </read_files>
  <write_files>
    test/test_correction_hygiene.bats
    flow-kit-bundle/test/test_correction_hygiene.bats
    Makefile
  </write_files>
  <action>
    0. Makefile check-validate 权威直判（盲审 N1，TD-012 同款）：`check-validate` target 现仅有装饰管道 `bash package-flow-kit.sh --validate 2>&1 | tail -5`（exit code 被 tail 吞，恒 0）——补第二行权威直判（对齐 test target L10+L11 双行模式）：`@bash package-flow-kit.sh --validate > /dev/null 2>&1 && echo "✅ validate: staging coverage OK" || { echo "❌ validate: coverage check failed"; exit 1; }`。**（此 Makefile 修复已在 phase 3 fix loop 中由主 agent 直接落地，本任务执行时核验该行存在即可；若缺失则补齐。）**
    新建 test/test_correction_hygiene.bats，用例映射（setup 沿用 test/ 既有 BATS_ROOT 向上查找模式，禁 2>/dev/null || true 吞错）：
    - AC-1 去重：同一 check+field 连写 3 条 → violations 仅剩最新 1 条
    - AC-2 容量：白名单类写 12 条（不同 field）→ 剩 10 条 FIFO（最旧 2 条被淘汰）；混合 compliance 条目 → compliance 保留且不占配额
    - AC-3 健康清零：合法 .flow-active + 模拟 33 号全通过 → 白名单条目清空；correction 含 l2-missing/compliance → 保留
    - AC-4 退场双态：纯 l2-missing → 整文件 rm；l2-missing+state-integrity（含 violations）→ type 剥离为 state-integrity + violations 保留；gate_config=L2（非 both）+ IR 无 L2 段 → 退场仍触发（R2 插入点验证）
    - AC-5/6 外来：.flow-active 写 YAML → 33 号跑完 correction 白名单条目清空 + 恰 1 条 foreign_state note（再跑一次不重复）+ type 合并标签剥离为 l2-missing + compliance 保留
    - AC-9 chisel_env 场景：复刻生产 observation——YAML .flow-active + correction 50 条（43 corrupt_json + 6 phase_artifact_missing + 1 l2-missing 合并）→ 33 号单轮收敛（state-integrity 全清 + l2-missing 剥离保留 + 1 note）
    - AC-10 compliance：任意清零/外来/退场路径后 compliance 条目逐字节不变
    - AC-7 外来文件不可触碰：外来 .flow-active（YAML）跑 33 号前后 sha256 逐字节一致 + mtime 不变（只读断言）
    - R1 写入保护：correction 预置 compliance 条目 → 调 _write_l2_missing_correction → compliance 仍在且 type 未变 l2-missing
    完成后 `make test-sync` 同步 flow-kit-bundle/test/，全量回归以 `make check` 四门为验收门（test/lint/打包校验/双源 diff；timeout ≥300s，预期 752+新增全绿，0 fail 阻断）。
  </action>
  <verify>make test-sync && ~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats test/test_correction_hygiene.bats && make check</verify>
  <done>✅ done 2026-09-01T03:50:00+08:00 — 新文件双源一致（diff -q identical）；新用例 10/10 全绿；主 agent 全量回归 make check 四门绿：bats 764/764（752 基线 + 10 新增 + NFR 断言更新至 AC-5/6/7）+ shellcheck 0 error + validate 302 项 0 漏配 + test 双源一致。NFR 更新说明：test_flow_active_integrity.bats "handles corrupt JSON" 旧断言（append corrupt_json）与 F2/D5 规格化行为变更冲突，主 agent 更新为断言外来让位新行为（no corrupt_json + 恰 1 foreign_state + AC-7 sha256 不变），双源同步</done>
  <depends_on>T01, T02, T03</depends_on>
</task>
