# TASK: L3 审查链五类缺陷修复（§B1–§B5）

- **Change ID**: `l3-review-defects-2026-09`
- **关联**: `@.specs/l3-review-defects-2026-09/REQUIREMENT.md`、`@.specs/l3-review-defects-2026-09/DESIGN.md`、`@.specs/CONTEXT.md`
- **模式说明**: 本 change 为**回溯补档**——代码与回归套件先随缺陷复测落地（commit `61c4bf8`），
  七件套在 pipeline 中补齐。故所有任务的 `status` 均为 `done`，但其 `verify` 命令**现在仍可复跑**
  （这是补档不等于事后编造的可核性保障）。

---

## 波次划分

```
Wave 1 (parallel): T01[P] T02[P] T03[P] T04[P]
Wave 2 (parallel): T05[P] T06[P] T07     (T05 ← T01,T02；T06 独立；T07 ← T01)
Wave 3:            T08                    (← T01..T07)
Wave 4 (parallel): T09[P] T10            (T09 ← T08；T10 ← T01..T09)
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

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
  </verify>
  <done>
    L3 段边界只有一个实现，且 B2 组（含 AC-4 围栏/幂等、AC-5 历史件、转义契约）全绿。
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
    flow-kit-bundle/flow-kit/l3.env.example
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/config/stop-hook.json
    README.md
    dsh-flow-kit/README.md
    flow-kit-bundle/flow-kit/l3.env.example
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
    npx bats test/test-l3-check-rerun-content-marker.bats && make check-structure
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
    按缺陷编号分组（B1/B2/B3/B4/B5 + B6/M32 + B7/M34），每条断言可独立运行；关键断言配**变异自证**
    （`B2-R16` / `B5-R4` / `B6-R5` / `B1-R27`：把实现改坏，断言必须失败），避免恒真断言。
  </action>
  <verify>
    npx bats test/test_l3_review_defects_2026_09.bats
  </verify>
  <done>
    套件全绿且含 ≥4 处自证用例；`make check-test-sync` 双源一致。对应 AC-11/AC-12。
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
  </write_files>
  <action>
    把响应段里的可验证声明做成机械复验：载体**动态枚举**（读 `sync-hooks.sh --list`，不写死路径/数量）、
    计数**现场复算**（不抄快照）、DESIGN/MINOR 结构自洽。每条检查必须**能失败**（注入反例验证过）。
  </action>
  <verify>
    bash verify-claims.sh
  </verify>
  <done>
    13 项检查全 ✅、rc=0，且第 5 项（裸正则残留）已用真实裸正则证明其可失败。
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
    make check-validate && bash verify-claims.sh
  </verify>
  <done>
    项目级沉淀齐全且可复验（ADR 索引、CONTEXT 术语表、CHANGELOG 条目、cap 生效）。
  </done>
  <depends_on>T01,T02,T03,T04,T05,T06,T07,T08,T09</depends_on>
</task>
```

---

## R6.5 提交前 diff 边界校验

| 任务 | write_files 与实际 diff |
| --- | --- |
| T01–T05 | 全部落在 `flow-kit-bundle/hooks/stop/**` 与 `flow-kit-bundle/flow-kit/prompts/**` 内（受 `sync-hooks.sh` 镜像） |
| T03 | 额外命中 `package-flow-kit.sh` 的 heredoc 文本 = **禁动偏差**（已声明 + M10 + 回滚方案） |
| T06 | `sync-hooks.sh` / `Makefile` 为新增/接线，未改 `install_hooks.sh`（只读引用） |
| T10 | `.specs/**` 与 `.flow-kit/stop-hook.json`，无源码改动 |

复验命令：`bash verify-claims.sh`（含「响应段声明 ↔ 现场事实」逐条核对）。
