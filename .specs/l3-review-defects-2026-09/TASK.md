# TASK: L3 审查链五类缺陷修复（§B1–§B5）

- **Change ID**: `l3-review-defects-2026-09`
- **关联**: `@.specs/l3-review-defects-2026-09/REQUIREMENT.md`、`@.specs/l3-review-defects-2026-09/DESIGN.md`、`@.specs/CONTEXT.md`
- **模式说明**: 本 change 为**回溯补档**——代码与回归套件先随缺陷复测落地（commit `61c4bf8`），
  七件套在 pipeline 中补齐。故所有任务的 `status` 均为 `done`，但其 `verify` 命令**现在仍可复跑**
  （这是补档不等于事后编造的可核性保障）。

---

## 波次划分

```
Wave 1 (parallel): T01[P] T02[P] T03[P] T04[P] T06[P]        （互不依赖）
Wave 2 (parallel): T05[P] T07[P] T11[P] T12[P]               （T05←T01,T02；T07←T01；T11←T01,T02；T12←T05）
Wave 3:            T08  T13                                   （T08←T01..T07,T11,T12；T13←T06）
Wave 4:            T09                                        （←T08）
Wave 5:            T10                                        （←T01..T09,T11,T12,T13）
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。
>
> **补档语义（阶段 3 的 L3 20:46 三条 critical 的处置）**：本 change 是**回溯补档** —— 回归套件
> `test/test_l3_review_defects_2026_09.bats`（T08 的产物）与各实现任务是**同批co-develop**的，
> 因此 T01–T05/T07/T11/T12 的 verify 都引用该文件，却不 `depends_on` T08。这不是波次错误，而是
> **verify 的语义不同**：它们是**回溯复验命令**（执行时全部产物已存在），不是"按波次推进时的门禁"。
> 若要在新项目里按同一张表真实推进，需要把 T08 拆成「骨架（Wave 1，与 T01 同波次创建文件）+
> 补齐（Wave 3）」两步 —— 已在 T08 的 action 中注明。
>
> **T01 的 verify 只跑本任务可判定的用例**：B2 组含 R8/R14/R15/R16（写侧接线，属 T05），
> 故 T01 的验收范围显式限定为 `B2-R1..R4 / R6 / R7 / R9..R13 / R17..R19`（见该任务 verify 内注释）。
> **不变量（依阶段 3 的 L2 盲审 major：原表把 T09/T10 同列一个 [P] 波次，却又有 T10←T09 依赖）**：
> 同一波次内任意两个任务的 `depends_on` **不得**相交。复验：
> `awk '/^<task id=/{id=$2} /<depends_on>/{…}' TASK.md`（或用下表人工核对）。

| 波次 | 任务 | depends_on | 与前序波次一致？ |
| --- | --- | --- | --- |
| 1 | T01 T02 T03 T04 T06 | — | ✅ |
| 2 | T05 | T01,T02 | ✅ |
| 2 | T07 | T01 | ✅ |
| 2 | T11 | T01,T02 | ✅ |
| 2 | T12 | T05 | ✅ |
| 3 | T08 | T01..T07,T11,T12 | ✅ |
| 3 | T13 | T06 | ✅ |
| 4 | T09 | T08 | ✅ |
| 5 | T10 | T01..T09,T11,T12,T13 | ✅ |

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done" model-tier="standard">
  <name>抽取 L3 段边界的单一来源（l3-section.sh）：显式结束标记 + 转义入口</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-api.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-truncate.sh
    .specs/l3-review-defects-2026-09/DESIGN.md   <!-- D2/D3/D6/D10 -->
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-section.sh
  </write_files>
  <action>
    新建 l3-section.sh，作为段边界的**唯一**实现：L3_SECTION_END_MARKER 字面量、_l3_l3_marker、
    _l3_escape_payload（转义集 = 行首 `## ` / 结束标记字面量 / 行首围栏）、_l3_spans_impl
    （--- preamble 判据；有标记 → 终点取范围内**最后一个**标记行；无标记 → 收紧为
    「下一个 `## L2 `/`## 主 agent`/`## L3 ` 或 EOF」）、_l3_section_spans / _l3_has_section /
    _l3_strip_sections。沿用既有 local 函数风格与 `shellcheck shell=bash` 头注；不引入新依赖（见 D6/D7）。
  </action>
  <verify>
    npx bats test/test_l3_review_defects_2026_09.bats -f "B2-"
    # B2 组含跨任务用例（R8/R14/R15/R16 断言写侧接线，属 T05）；本任务验收以下列为准：
    # B2-R1..R4 / R6 / R7 / R9..R13 / R17..R19（l3-section.sh 自身可判定）
  </verify>
  <done>
    L3 段边界只有一个实现；本任务范围内的 B2 用例全绿（跨任务断言归 T05 验收）。
  </done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done" model-tier="standard">
  <name>收口 L2 结论提取：行首锚定 + 限定 L2 层 + 末次命中 + 小写归一</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/lib/l3-section.sh
    .specs/l3-review-defects-2026-09/DESIGN.md   <!-- D1/D6/D7/D8 -->
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
  </write_files>
  <!-- AC-2 的交付物 L2-EMPTY-ATTRIBUTION.md 的**生产者是 T09**（corpus-count.sh --attribution），
       本任务只消费它；阶段 3 的 L3 20:46 指出原表把它错列在本任务下 -->
  <action>
    重写 fk_extract_l2_verdict：先用 _fk_l2_scope 得「L2 层」文本（排除 L3 段区间 —— 区间来自
    _l3_section_spans，不得自行按 `^## ` 复位；排除 `^## 主 agent` 段），再做三层提取
    （行首锚定并排除 JSON 引号行 → 标题形 → 旧式兜底），取**最后**一条并小写归一；
    返回值域限定 {pass, fail, 空}。l3-section.sh 缺失时按同目录兜底 source，并保留**不 fail-open**
    的降级排除。
  </action>
  <verify>
    npx bats test/test_l3_review_defects_2026_09.bats -f "B1-"
  </verify>
  <done>
    B1 组全绿；语料全量复算零非枚举（AC-2 的用例「AC2: 语料全量复算」）。对应 AC-1/AC-2/AC-3。
  </done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done" model-tier="standard">
  <name>§B3：配置键改名 max_artifact_chars → max_artifact_bytes（保留旧键 + DEPRECATED 提示）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/config/stop-hook.json
    README.md
    dsh-flow-kit/README.md
    .claude/l3.env.example
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/config/stop-hook.json
    README.md
    dsh-flow-kit/README.md
    .claude/l3.env.example
    package-flow-kit.sh
    .flow-kit/stop-hook.json
  </write_files>
  <action>
    四级解析链 `FLOW_KIT_L3_MAX_ARTIFACT_BYTES` > 旧 `FLOW_KIT_L3_MAX_ARTIFACT_CHARS` >
    历史直调键 > 默认 20000；读到旧键时向 stderr 打含 `DEPRECATED` 的迁移提示；键名语义统一为
    **字节**并在四处载体写明「CJK ÷3」。`package-flow-kit.sh` 仅改 emitted 文档 heredoc 文本
    （禁动偏差已登记 M10）。项目级 `.flow-kit/stop-hook.json` 的 cap 提到 200000（见 T10 的说明）。
  </action>
  <verify>
    npx bats test/test_l3_review_defects_2026_09.bats -f "B3-"
  </verify>
  <done>
    B3 组全绿（含 `B3-R5` 四处载体三要素断言、`B3-R5b` 第五处载体、`B3-R7/R8` 截断告警）。对应 AC-6/AC-7。
  </done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="done" model-tier="standard">
  <name>§B4：阶段 7 提示词产物清单改全量，并区分必备 / 补充产物</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
  </write_files>
  <action>
    删除 `ls -la | head -30` 的行数截断，改「产物目录（全量）」；必备 6 件保 MISSING 严格语义
    （AC-9）；补充产物改由 `_l3_extra_deliverables` 提供（目录内全部 `*.md`，排除必备 6 件与
    `INDEPENDENT-REVIEW-*.md`，每件 ≤3000B，**按体积升序**垫尾），阶段 1/2/3/5/6/7 全部接入；
    参数名 max_chars → max_bytes，并在截断时向 stderr 告警（含丢弃比例）。
  </action>
  <verify>
    npx bats test/test_l3_review_defects_2026_09.bats -f "B4-"
  </verify>
  <done>
    B4 组与 B7 组全绿：41 条目目录零遗漏、不再凭空产出 INTEGRATION.md === MISSING。对应 AC-8/AC-9。
  </done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="done" model-tier="standard">
  <name>§B2：写入侧转义载荷（两个自动写入方）+ 写入侧 fail-closed</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-section.sh
    flow-kit-bundle/hooks/stop/lib/l3-api.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-api.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md
  </write_files>
  <action>
    `_l3_parse_result` 与 `l2_dispatch_agent` 的载荷一律经 `_l3_escape_payload`（禁止内联 sed）；
    `l2_dispatch_agent` 增加**写入侧 fail-closed**：转义函数不可用时拒绝落盘（stderr CRITICAL +
    清理临时文件 + exit 1），不留未转义的半截文件；固化指令写约束新增第 4 条（贴入路径亦须转义）。
  </action>
  <verify>
    npx bats test/test_l3_review_defects_2026_09.bats -f "B2-R8"
  </verify>
  <done>
    转义是契约（B2-R5/R8/R9/R10/R14/R15/R16 全绿）；载荷无法伪造段起点、围栏或标记。
  </done>
  <depends_on>T01,T02</depends_on>
</task>

<task id="T06" parallel="true" status="done" model-tier="standard">
  <name>§B5：副本一致性工具 sync-hooks.sh（唯一源 → 四类树镜像 + 漂移检测）</name>
  <read_files>
    flow-kit-bundle/hooks/**
    flow-kit-bundle/flow-kit/prompts/**
    flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md
    Makefile
  </read_files>
  <write_files>
    sync-hooks.sh
    Makefile
  </write_files>
  <action>
    新增 sync-hooks.sh：把源镜像到 7 个 DEST_ROOTS（含此前完全未覆盖的 `~/.config/opencode/hooks`
    与 dist/dsh 运行时树），覆盖四类树（hooks / prompts / 复合 agent / 平台级 agent 落点）；
    `--check` 必须**只读**（不得在检查模式下重放 agent 拷贝段）；`--list` 供复验工具动态枚举载体。
    Makefile 接线 `hooks-sync` 与 `check-hooks-sync`（后者入 `make check`）。
  </action>
  <verify>
    ./sync-hooks.sh --check && make check-hooks-sync
  </verify>
  <done>
    漂移 0（`B5-R2`）；`B5-R4` 自证「能真的发现漂移」；用户级副本 `~/.claude/hooks` 命中 P0-1/P0-2（`B5-R3`）。对应 AC-10。
  </done>
  <depends_on></depends_on>
</task>

<task id="T07" parallel="false" status="done" model-tier="standard">
  <name>判据同源：l3-truncate.sh 的「L3 段存在」改走 _l3_has_section</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-truncate.sh
    flow-kit-bundle/hooks/stop/lib/l3-section.sh
    test/test-l3-check-rerun-content-marker.bats
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-truncate.sh
    test/test-l3-check-rerun-content-marker.bats
  </write_files>
  <action>
    裸正则 `^## L3 (盲审|重审)` 判据废弃，改调 `_l3_has_section`（与写侧同源），并做依赖注入兜底；
    夹具补 `---` preamble 以符合新判据。顺带把 l3-api.sh 压回 ≤250 行结构门槛（冻结在 249 行）。
  </action>
  <verify>
    npx bats test/test-l3-check-rerun-content-marker.bats test/test_lib_split_metrics.bats
  </verify>
  <done>
    重审触发判据与写侧同源；结构门槛不回退（`l3-api.sh` 249/250）。
  </done>
  <depends_on>T01</depends_on>
</task>

<task id="T08" parallel="false" status="done" model-tier="standard">
  <name>回归套件：test_l3_review_defects_2026_09.bats（§B1–§B5 + M32/M34 全量）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/**
    test/*.bats
  </read_files>
  <write_files>
    test/test_l3_review_defects_2026_09.bats
    flow-kit-bundle/test/test_l3_review_defects_2026_09.bats
  </write_files>
  <action>
    按缺陷编号分组（B1/B2/B3/B4/B5 + B6=M32 + B7=M34 + B8=D13 + B9=M36/M37 拦截 + B10=M37 写入后自检 + AC2），
    补档说明：本套件与实现同批 co-develop，若按波次真实推进应先落**骨架**（Wave 1）再补齐（Wave 3）。
    每条断言可独立运行；关键断言配**变异自证**
    （`B2-R16` / `B5-R4` / `B6-R5` / `B1-R27`：把实现改坏，断言必须失败），避免恒真断言。
  </action>
  <verify>
    make check
  </verify>
  <done>
    五门全绿（含全量 bats、双源一致、hooks 漂移 0）；缺陷套件含 ≥8 处自证用例。
    AC-2 的活语料不变量 = 零非枚举 + 每份空值可归因（清单由 `bash corpus-count.sh --attribution` 再生，
    数值预算 ≤8 只对**基线语料**成立）。对应 AC-2/AC-11/AC-12。
  </done>
  <depends_on>T01,T02,T03,T04,T05,T06,T07</depends_on>
</task>

<task id="T09" parallel="true" status="done" model-tier="standard">
  <name>复验工具化：verify-claims.sh + corpus-count.sh</name>
  <read_files>
    sync-hooks.sh
    test/test_l3_review_defects_2026_09.bats
    Makefile
  </read_files>
  <write_files>
    verify-claims.sh
    corpus-count.sh
    Makefile
    .specs/l3-review-defects-2026-09/L2-EMPTY-ATTRIBUTION.md
  </write_files>
  <action>
    把响应段里的可验证声明做成机械复验：载体**动态枚举**（读 `sync-hooks.sh --list`，不写死路径/数量）、
    计数**现场复算**（不抄快照）、DESIGN/MINOR 结构自洽。每条检查必须**能失败**（注入反例验证过）。
  </action>
  <verify>
    bash verify-claims.sh
  </verify>
  <done>
    13 项检查全 ✅、rc=0（含 §0.5.1 载体覆盖、hooks 漂移、门禁）；第 5 项（裸正则残留）已用真实裸正则
    证明其可失败。**覆盖边界（如实）**：本脚本核对「响应段声明 ↔ 现场事实」，**不**解析 TASK.md 的
    write_files（R6.5 的 diff 边界由 `git diff --name-only` 在评审中核对）。
  </done>
  <depends_on>T08</depends_on>
</task>

<task id="T10" parallel="false" status="done" model-tier="standard">
  <name>工件与项目级沉淀收尾：ADR-026 / CONTEXT / CHANGELOG / STATE / PROGRESS / 项目级 cap</name>
  <read_files>
    .specs/CONTEXT.md
    .specs/CHANGELOG.md
    .specs/STATE.md
    .specs/adr/**
    .flow-kit/stop-hook.json
  </read_files>
  <write_files>
    .specs/adr/026-untrusted-payload-cannot-forge-boundaries.md
    .specs/CONTEXT.md
    .specs/CHANGELOG.md
    .specs/STATE.md
    .specs/l3-review-defects-2026-09/PROGRESS.md
    .flow-kit/stop-hook.json
  </write_files>
  <action>
    新增 ADR-026（不可信载荷不得伪造结构性边界；含三代穿透与「接受残余 + v2 PreToolUse 强制转义」）；
    登记 CONTEXT 域语言与禁动建议（§9.5）；CHANGELOG/STATE 更新；项目级 cap 20000 → 200000
    （依据：截断输入使 L3 结论失真，实测 `DESIGN.md` 30535B > 20000B）。
  </action>
  <verify>
    make check-validate && jq -e '.independent_review.max_artifact_bytes == 200000' .flow-kit/stop-hook.json \
      && grep -q '026-untrusted-payload' .specs/adr/026-untrusted-payload-cannot-forge-boundaries.md
  </verify>
  <done>
    项目级沉淀齐全且**可证伪**：cap=200000（`.flow-kit/stop-hook.json` 被 `.gitignore:64` 忽略，
    故 diff 不可见 → 用 `jq -e` 断言替代）、ADR-026 在库、CONTEXT 术语与 CHANGELOG 条目更新。
  </done>
  <depends_on>T01,T02,T03,T04,T05,T06,T07,T08,T09</depends_on>
</task>

<task id="T11" parallel="true" status="done" model-tier="standard">
  <name>M32：非 pass 时撤销陈旧 .done 锚点</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-done.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-done.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    新增 `l3_invalidate_done`（幂等、失败仅 WARN），由 `l3-review.sh` 的 non-pass 分支调用；
    timeout 分支**刻意不撤销**（超时不携带"当前状态不通过"的信息）。
  </action>
  <verify>
    npx bats test/test_l3_review_defects_2026_09.bats -f "B6-"
  </verify>
  <done>
    B6 组 6/6；实测已阻止"截断版 pass 的锚点"在新一轮 fail 后继续放行。对应 M32。
  </done>
  <depends_on>T01,T02</depends_on>
</task>

<task id="T12" parallel="true" status="done" model-tier="standard">
  <name>M36/M37 + D14：贴入路径的可执行拦截与写入后结构自检</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/**
    flow-kit-bundle/hooks/stop/lib/l3-section.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    29-independent-review.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/gate-helpers-types.sh
    flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/l3-section.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    ① `_gate_is_unescaped_l3_paste`（Write/Edit + Bash 两通道，判据与读侧段起点同源）；
    ② `_l3_verify_review_structure`（段数 ≤1 / 段尾=结束标记 / 段内围栏配平）；
    ③ 确定损坏 → `write_review_structure_correction`（compliance 优先）+ `module_output error`（非阻塞）。
  </action>
  <verify>
    npx bats test/test_l3_review_defects_2026_09.bats -f "B9-"
  </verify>
  <done>
    B9 组（12 例）与 B10 组（7 例）全绿；裸标题=放行且**证明无害**、`---`+标题+无标记=拒绝。对应 M36/M37/D14。
  </done>
  <depends_on>T05</depends_on>
</task>

<task id="T13" parallel="false" status="done" model-tier="standard">
  <name>sync-hooks 反向残留发现能力（源已删、副本仍在）</name>
  <read_files>
    sync-hooks.sh
  </read_files>
  <write_files>
    sync-hooks.sh
  </write_files>
  <action>
    `--check` 增反向残留扫描（副本有、源无的 hook 文件）默认 advisory；`--strict-orphans` 计入失败；
    顺带修参数解析只看 `$1` 的 bug（`--check --strict-orphans` 的第二个参数曾被静默忽略）。
  </action>
  <verify>
    npx bats test/test_l3_review_defects_2026_09.bats -f "B5-"
  </verify>
  <done>
    B5 组 5/5；`--check` 在真实树仍为漂移 0。对应阶段 2 的 L3 19:15 major②。
  </done>
  <depends_on>T06</depends_on>
</task>
```

---

## R6.5 提交前 diff 边界校验

| 任务 | write_files 与实际 diff |
| --- | --- |
| T01–T05, T07, T11 | `flow-kit-bundle/hooks/stop/**`、`flow-kit-bundle/flow-kit/prompts/**`（受 `sync-hooks.sh` 镜像） |
| T12 | `flow-kit-bundle/hooks/pre-tool-use/**` 三文件（**事后扩界**：M36/M37/D14 修复期新增）+ `hooks/stop/lib/{l3-section,correction-file,l3-review}.sh` + `29-independent-review.sh` |
| T03 | 额外命中 `package-flow-kit.sh` 的 heredoc 文本 = **禁动偏差**（已声明 + M10 + 回滚方案） |
| T06, T13 | `sync-hooks.sh` / `Makefile` 新增与接线，未改 `install_hooks.sh`（只读引用） |
| T10 | `.specs/**`、`.flow-kit/stop-hook.json`（后者被 `.gitignore` 忽略，故 diff 不可见 → 由 `jq -e` 断言替代） |

**禁动清单命中登记（依阶段 3 的 L2 盲审 major：原 §0.5.1 只声明 1 项，实际 ≥4）**：

| 文件 | 禁动条目 | 本次改动 | 登记 |
| --- | --- | --- | --- |
| `package-flow-kit.sh` | Part A~G 逻辑禁改 | 仅 emitted 文档 heredoc 文本 | M10 + §0.5.1 偏差声明 |
| `hooks/stop/29-independent-review.sh` | gate 校验核心链 | 键名解析链 + AC-12 告警 + 结构自检调用 | §0.5.1 + T12 |
| `hooks/pre-tool-use/independent-review-gate.sh` | 校验顺序（真实性→实效性→放行） | 仅新增 content 透传（不改顺序） | §0.5.1 + T12 |
| `hooks/stop/lib/correction-file.sh` | 既有 4 函数签名 | **仅追加** `write_review_structure_correction`（不改既有函数） | §0.5.1 + T12 |

复验命令：`git diff --name-only 61c4bf8..HEAD`（人工比对上表）+
`bash verify-claims.sh`（覆盖"响应段声明 ↔ 现场事实"；**不**解析本表，边界如实标注）。

---

## 补档追加说明（2026-09-18 21:3x）

- **M40 仍未闭合**（`bats -f <组>-` 命中 0 条即算通过）：本轮只把 **T08 的 verify 改为 `make check`**
  （整目录），其余任务的 verify 仍是组过滤式。复现：
  `npx bats test/test_l3_review_defects_2026_09.bats -f "ZZZ-NOPE"` → 输出 `1..0`，rc=0。
  建议修法（下一轮）：verify 后加命中数下限校验，例如
  `npx bats -f "B2-" … --formatter tap | awk '/^1\\.\\./{exit ($2>=15)?0:1}'`。
- **T08 的产物与实现的依赖方向**：本 change 为回溯补档，套件与实现同批 co-develop，故
  `verify` 是**回溯复验命令**而非波次门禁（见上方「补档语义」段）；若按波次真实推进，需把 T08
  拆成「骨架（Wave 1）+ 补齐（Wave 3）」。
