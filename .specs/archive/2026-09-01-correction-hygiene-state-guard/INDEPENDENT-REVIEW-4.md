# 独立审查 · 阶段 4

## L2 盲审 · correction-hygiene-state-guard (Phase 4 DEV)

**Verdict**: pass

### 审查方法（自证，非转述）
独立执行：`diff -r test/ flow-kit-bundle/test/`（双源 0 差异）· `bash -n` ×3 · `shellcheck -e SC1091 -S error` ×3（clean）· 全量 bats **764 ok / 0 not-ok**（PIPESTATUS 0）· `make check` 四门全过（test / lint / check-validate / check-test-sync）· 手工 mktemp fixture 8 项 spot-check 全 PASS（(a) dedupe 保最新+compliance 字节保留；(b) trim 12→10 FIFO 保 compliance；(c) 外来 YAML：0 corrupt_json、恰 1 foreign_state、幂等、type→l2-missing、.flow-active sha256+mtime 不变；(d1) M0 纯 l2-missing→rm+stderr 审计；(d2) 合并标签→剥离为 state-integrity、violations 原样；(e) fk_phase_gate_key 1="1-requirement"；(f) D8 compliance 优先不覆写）。31/32/34 均不在 `git diff --name-only`（未触碰）。

### Findings

1. 🟢 Minor · R3（知识重复）· 29 M0 内联 jq 剥离而非共享抽象 `correction_file_strip_type`
   **Severity**：🟢 Minor
   **Symptom**：`flow-kit-bundle/hooks/stop/29-independent-review.sh:97-99` 内联 `.type = (.type | split("+") | map(select(. != $seg)) | join("+"))`；TASK.md T03 动作要求「调 T01 的 correction_file_strip_type」；注释 L79-81 与 T03-SUMMARY.md L24 声明「T02/T04 后续统一时再切换」，但本 change 内未切换 → 剥离逻辑存在两份（correction-file.sh:269 与 29:97）。
   **Source**：DESIGN §9.1「禁止双份内联」；TASK T03 显式指令；ADR-024 单一抽象意图。
   **Consequence**：剥离逻辑双源漂移风险（改一漏一）；实测退化标签 `l2-missing+l2-missing` 内联版产出 `type=""`（空串），而共享抽象契约是 all-stripped → rc=0 原样保留 —— 内联版存在理论上的 type 损坏路径（当前无生产者写重复段，概率≈0）。
   **Remedy**：把 29 的 `source lib/correction-file.sh`（现 L122）上移到 M0 块之前，M0 改用 `correction_file_strip_type "$f" "l2-missing"`，删除内联 jq；或在下一 change 内完成「统一切换」。

2. 🟢 Minor · 文档一致性 · T03-SUMMARY 用「按指令」措辞淡化偏差
   **Severity**：🟢 Minor
   **Symptom**：`T03-SUMMARY.md:24`「按指令只在本文件注释中引用」——实际 TASK T03 指令是调用共享函数，SUMMARY 措辞与 TASK 相反（偏差本身已记录，措辞误导）。
   **Source**：L2 独立性约束「证据优先于解释」；4-dev 决策偏离须如实记录。
   **Consequence**：归档后读者会误以为 TASK 要求内联；后续审计按 SUMMARY 追溯时产生错误因果。
   **Remedy**：将 T03-SUMMARY L24 改为「TASK 要求调用共享函数；因运行时 source 顺序（correction-file.sh 在 L122 才加载，M0 在 L71 先行）临时内联，T02/T04 应统一切换」并标记 Tech-debt。

### Red lines 核查
- **corrupt_json 不再作为新 violation 写入**：grep 全 hooks，corrupt_json 仅出现在 33:27 注释与 correction-file.sh 白名单常量；33 无任何 append corrupt_json 路径 ✅
- **外来分支不触碰 $CORRECTION_FILE 以外文件**：33 外来分支仅 `_fai_clear_whitelist`/`strip_type`/`_fai_append_foreign_note` 写 correction；.flow-active sha256+mtime 逐字节不变（AC-7 实测）✅
- **ADR-024 白名单契约**：correction-file.sh:158-168 恰 9 值，与 33 `_fai_clear_whitelist` 引用集合一致；dedupe/trim/clear 全部经白名单作用域，无数组级改写 compliance 的裸 jq ✅
- **AC-10 红线**：测试文件 grep `sk-|ANTHROPIC_API_KEY=|AKIA` 0 命中；compliance 条目在清零/外来/退场三路径 jq -c 逐字节不变 ✅

### Per-AC test mapping

| AC | 测试用例 | 命令/断言 | 状态 |
|----|----------|-----------|------|
| AC-1 | test_correction_hygiene.bats:62 | 同 check+field 连写 3 → COUNT=1 MSG=third | ✅ 764/764 |
| AC-2 | :81 | 12 白名单 → 10 FIFO（field_01/02 淘汰），COMP=2 TOTAL=12 | ✅ |
| AC-3 | :106 | 健康清零 → 3 项清空 + type/compliance 保留 + `state-integrity cleared 3 items` | ✅ |
| AC-4 | :136 (4a) + :150 (4b) | 纯→rm+`[29-l2-retire]`审计（R2 插入点证明）；合并→state-integrity+violations 原样 | ✅ |
| AC-5 | :171 + test_flow_active_integrity.bats:237 | 外来 YAML：0 corrupt_json、1 note、幂等 | ✅ |
| AC-6 | :171 | 陈旧白名单清空、type 剥为 l2-missing、恰 1 foreign_state | ✅ |
| AC-7 | :240 | sha256+mtime 前后一致 | ✅ |
| AC-8 | make check 四门 + diff -r | 764/764；lint clean；validate OK；双源一致 | ✅ |
| AC-9 | :207 | 50 条（43+6）→ 2 条单轮收敛，再跑零新增 | ✅ |
| AC-10 | :261 + :302(R1) | 三路径 compliance 字节不变；D8 不覆写 compliance correction | ✅ |

### 六维衰退（R1-R6）
R1/R2：M0 前置 + 外来让位单 actor 设计清晰，无认知过载；R3：finding #1（strip 双份）；R4/R5：无新增依赖、无偶然复杂；R6：与既有 correction 范式（write_model_missing_*）对齐。

### L-031 跨文件锚点
锚点=9 值白名单：correction-file.sh const ↔ 33 clear fn 引用集合一致；31/32/34 零引用（无漂移）；`test("l2-missing")` 正则仅 29 一处使用。DESIGN 触碰清单覆盖完整，无漏改类 🔴。

---
**Verdict**: pass — 0 Critical / 0 Important / 2 Minor。全部 10 条 AC 有真实测试覆盖且实测通过（764/764），red lines 干净，31/32/34 未触碰；唯一偏差（29 内联剥离）已在代码注释与 SUMMARY 记录，属 Minor 级知识重复，建议 phase 7 triage 后统一切换共享抽象。

---

## 主 agent 响应（2026-09-01 04:10）

| 发现 | 严重度 | 处置 |
|---|---|---|
| R1: 29 M0 内联 jq strip（29:97-99）未用共享 correction_file_strip_type；退化标签 "l2-missing+l2-missing" 场景内联产生空 type，共享函数为 no-op | 🟢 | **已知接受 + 登记 M10**。理由：29 号 source correction-file.sh 在 L122（M0 块 L71-107 之后），运行时序决定了 M0 处共享函数未定义；切换需把 source 提前到 M0 之前，属行为面变更，收益（退化标签防御，无生产者会生成重复段）不抵回归风险。归档后下一 change 统一切换 |
| R2: T03-SUMMARY:24 措辞"按指令"失实（实为时序约束下的偏离） | 🟢 | 登记 M11，在 MINOR-DEFERRED.md 更正表述 |

复核结论：无 🔴/🟡 遗留，Verdict pass 维持。
