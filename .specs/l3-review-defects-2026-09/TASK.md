# TASK: L3 审查链五类缺陷修复（§B1–§B5）

- **Change ID**: `l3-review-defects-2026-09`
- **关联**: `@.specs/l3-review-defects-2026-09/REQUIREMENT.md`、`@.specs/l3-review-defects-2026-09/DESIGN.md`、`@.specs/CONTEXT.md`
- **模式说明**: 本 change 为**回溯补档**——代码与回归套件先随缺陷复测落地（commit `61c4bf8`），
  七件套在 pipeline 中补齐。故所有任务的 `status` 均为 `done`，但其 `verify` 命令**现在仍可复跑**
  （这是补档不等于事后编造的可核性保障）。

---

## 波次划分

```
Wave 1:            T08[P]                                     （套件骨架：分组 + 断言，TDD 先红）
Wave 2 (parallel): T01[P] T03[P] T04[P] T06[P]                （均 ←T08）
Wave 3 (parallel): T02[P] T07[P]                              （T02←T01,T08；T07←T01,T08）
Wave 4 (parallel): T05[P] T11[P] T13[P]                       （T05←T01,T02,T08；T11←T01,T02,T08；T13←T06,T08）
Wave 5:            T12                                        （←T03,T05,T11,T08）
Wave 6:            T08B                                       （←T01..T08,T11,T12；套件补齐 + 变异自证）
Wave 7:            T09                                        （←T08B）
Wave 8:            T10                                        （←T01..T09,T11,T12,T13,T08B）
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。
>
> **依赖方向（依阶段 3 的 L3 22:18 major：verify 引用 T08 产物却无 T08 依赖）**：T08 已**真的拆成两段**
> ——`T08`=骨架（Wave 1，创建套件文件与 `@test` 骨架，先红）与 `T08B`=补齐（Wave 6，补全 + 变异自证 + 全量绿）。
> 因此每个「verify 会跑到套件用例」的任务都把 `T08` 写进 `depends_on`：**文件存在性由 T08 保证**，
> **文件完整性由 `verify_phase="final"` 的复验时点保证**（复验在 Wave 6 之后一次性执行）。两者都不再靠
> 散文解释 —— `depends_on` 里能看到 T08，且 T01→T08→(无)→… 不构成环（T08B←各实现任务，故实现任务
> **不得**反向依赖 T08B，这正是拆两段的原因）。
>
> **补档语义（阶段 3 的 L3 20:46 三条 critical + 22:18 major 的处置）**：本 change 是**回溯补档** ——
> 回归套件 `test/test_l3_review_defects_2026_09.bats`（T08/T08B 的产物）与各实现任务是**同批
> co-develop** 的。22:18 的 major 指出原表只靠散文解释「verify 引用套件、`depends_on` 却没有 T08」，
> 且把复验时点塞进非标准字段 `verify_phase`。**现已按评审要求把 T08 真的拆两段**（骨架 Wave 1 /
> 补齐 Wave 6），所有跑套件用例的任务 `depends_on` 含 `T08`：verify 的**产物存在性**由依赖图表达，
> **完备性**由 `verify_phase="final"`（复验时点 = Wave 6 之后）表达，散文只做补充说明。
>
> **verify 的防空跑写法（M40 的收敛修法，2026-09-18 起全表统一）**：
> `bats -f <组>-` 在 0 匹配时输出 `1..0` 且 rc=0 —— 必须**三查**：① bats 自身退出码；
> ② TAP 计划行 `1..N` 的 N ≥ 期望下限；③ 输出不得含 `not ok`（组过滤下 rc 已能反映，但显式更稳）。
> 复现 M40：`npx bats test/test_l3_review_defects_2026_09.bats -f "ZZZ-NOPE"` → `1..0`，rc=0。
>
> **过滤器必须锚定（M1 的修法 · 阶段 3 的 L3 22:18 major）**：bats 的 `--filter` 是**正则子串**匹配，
> `-f "B2-R1"` 会连 `B2-R10..B2-R19` 一起跑（实测 `1..11`），使 T01 越界执行 T05 的写侧接线用例
> （R14/R15/R16）。故**全表统一**为锚定形式 `-f "^<用例 ID>:"`（测试名格式为 `@test "B2-R1: …"`），
> 并把计划行下限写成该过滤器**精确**期望的条数。实测：`-f "B2-R1"` → `1..11`；`-f "^B2-R1:"` → `1..1`。

> **复验模型（M45 的修法，取代早先的 `verify_depends_on`）**：本 change 的回溯复验命令都跑 T08 的套件产物，
> 但**构造依赖**与**复验依赖**是两种关系 —— 前者用 `depends_on`（波次执行用），后者用新增的
> `verify_phase="final"`（**复验时点**：全部波次完成后一次性执行）。三者分开声明后：
> ① 波次图只表达**构造依赖**（无环）；② `verify` 是**收敛后的复验命令**，不对波次执行构成门禁；
> ③ 因此「verify 引用 T08 产物」与「T08 依赖各实现任务」不再构成环。
>
> **T01 的 verify 只跑本任务可判定的用例**：B2 组含 R8/R14/R15/R16（写侧接线，属 T05），
> 故 T01 的验收范围显式限定为 `B2-R1..R4 / R6 / R7 / R9..R13 / R17..R19`（见该任务 verify 内注释）。
> **不变量（依阶段 3 的 L2 盲审 major：原表把 T09/T10 同列一个 [P] 波次，却又有 T10←T09 依赖）**：
> 同一波次内，任一任务的 `depends_on` **不得包含本波次的其它任务**（依赖只能指向**更早**波次）——
> 这才是"同波次可并行"的充分条件；早先写成"两个任务的 depends_on 不得相交"过强（同波次的 T02/T07
> 都依赖 `T01,T08` 是合法的）。复验：下表按波次顺序人工核对 + `awk` 抽取 `depends_on` 与波次号比对。

| 波次 | 任务 | depends_on | 依赖只指向更早波次？ |
| --- | --- | --- | --- |
| 1 | T08（骨架） | — | ✅ |
| 2 | T01 | T08 | ✅ |
| 2 | T03 | T08 | ✅ |
| 2 | T04 | T08 | ✅ |
| 2 | T06 | T08 | ✅ |
| 3 | T02 | T01,T08 | ✅ |
| 3 | T07 | T01,T08 | ✅ |
| 4 | T05 | T01,T02,T08 | ✅（与 T02 都写 `l2-detect.sh`，故串行于 T02 之后） |
| 4 | T11 | T01,T02,T08 | ✅ |
| 4 | T13 | T06,T08 | ✅（与 T06 都写 `sync-hooks.sh`，故串行于 T06 之后） |
| 5 | T12 | T03,T05,T11,T08 | ✅（与 T11 都写 `l3-review.sh`、与 T03 都写 `29-independent-review.sh`，故串行于两者之后） |
| 6 | T08B（补齐） | T01,T02,T03,T04,T05,T06,T07,T08,T11,T12 | ✅ |
| 7 | T09 | T08B | ✅（与 T06 都写 `Makefile`，故串行于 T06 之后） |
| 8 | T10 | T01..T09,T11,T12,T13,T08B | ✅ |

### 共享写文件 → 串行化证明（阶段 3 的 L3 22:18 major ③）

多个任务写同一文件**不是**边界错误，但必须能机械证明"两次写不在同一波次、且后写者依赖先写者"：

| 共享文件 | 写者（波次） | 串行化依据 | 行级/段落边界声明 |
| --- | --- | --- | --- |
| `hooks/stop/lib/l2-detect.sh` | T02(3) → T05(4) | T05∈depends_on T02 ✅ | T02 改 `fk_extract_l2_verdict`；T05 加写入侧 fail-closed（不同函数） |
| `hooks/stop/lib/l3-api.sh` | **仅 T05(4)** | 单一写者（评审 04:13 major① 指出的"T07 私改未登记"已收敛） | T05 加写入侧 fail-closed **并把行数压回 250/250**；T07 不写该文件（只读以保证判据同源） |
| `hooks/stop/lib/l3-section.sh` | T01(2) → T12(5) | T12←T05←T01 ✅（传递） | T01 建段边界唯一来源；T12 只加 `_l3_verify_review_structure` |
| `hooks/stop/29-independent-review.sh` | T03(2) → T12(5) | T12∈depends_on T03 ✅（评审 04:13 major② 补齐） | T03 改键名解析链 + AC-12 告警；T12 加结构自检调用（不同函数） |
| `sync-hooks.sh` | T06(2) → T13(4) | T13∈depends_on T06 ✅ | T06 建镜像与 `--check/--list`；T13 加 `--strict-orphans` 与参数解析 |
| `Makefile` | T06(2) → T09(7) | T09←T08B←T06 ✅（传递） | T06 只动 `hooks-sync`/`check-hooks-sync`；T09 只动 `verify-claims`（T06 的 action 已写死此边界） |
| `.flow-kit/stop-hook.json` | **仅 T03(2)** | 单一写者（评审 22:18 major ② 指出的 T03/T10 双重归属已收敛） | T03 改 cap=200000；T10 **只断言不写**（`jq -e` 于 verify） |
| `test/test_l3_review_defects_2026_09.bats`（+ 镜像副本） | T08(1) → T08B(6) | T08B←T08 ✅ | T08 建骨架；T08B 补齐并加变异自证 |

**自检命令**（人工比对用）：`grep -n 'write_files' -A8 TASK.md` 与本表逐条对齐。

### AC ↔ 任务覆盖矩阵（AC-1..AC-12 零空白 · 阶段 3 的 L3 22:18 critical 的处置）

评审 critical：`AC-4`/`AC-5` 没有任何任务显式对应、`done` 里也从未提及。下表把 **REQUIREMENT 的全部
12 条 AC** 逐条绑到「实现任务 → 复验命令 → 用例 ID」，并给出**可跑的空白自检**：

| AC | 实现任务（波次） | 复验命令（任务） | 用例 ID | 断言来源 |
| --- | --- | --- | --- | --- |
| AC-1 L3 段不冒充 L2 | T02(3) | T02 verify | `B1-R2`、`B1-R4`、`B2-R9`、`B2-R11` | `REQUIREMENT §AC-1` + `_fk_l2_scope` |
| AC-2 语料零非枚举 + 空值可归因 | T02(3)（提取）+ T09(7)（归因清单） | T02 verify（`^AC2:`）+ T09 verify（`corpus-count.sh`） | `AC2:`、`B1-*` | 现场复算，不抄快照 |
| AC-3 §B1 自包含复现改结论 | T02(3) | T02 verify | `B1-R1` | 修复前 PASS → 修复后 fail |
| **AC-4 重写幂等 · 任意轮次零残留** | **T01(2)（段边界/转义）+ T05(4)（两个写入方）+ T12(5)（写入后结构自检）** | **T01 verify + T05 verify + T12 verify** | **`B2-R2`、`B2-R6`、`B2-R7`、`B2-R10`** | 连跑 5 轮：字节稳定、标记恰 1、围栏恰 2 |
| **AC-5 无标记历史件仍可清除 L3 段** | **T01(2)（`_l3_spans_impl` 的 `stop==0` 分支）+ T07(3)（判据同源）** | **T01 verify + T07 verify** | **`B2-R3`、`B2-R4`、`B1-R21`** | 历史件完整清除且不误删后续段落 |
| AC-6 cap 单位=字节 | T03(2) | T03 verify | `B3-R4`、`B3-R5`、`B3-R5b` | 四级解析链 + 四处载体「CJK ÷3」 |
| AC-7 旧键可用 + DEPRECATED | T03(2) | T03 verify | `B3-R1`..`B3-R3` | 子串 `DEPRECATED` + 旧键仍生效 |
| AC-8 阶段 7 清单不截断 | T04(2) | T04 verify | `B4-R1`..`B4-R4` | 全量目录 + `_l3_extra_deliverables` |
| AC-9 必备件 MISSING 语义 | T04(2) | T04 verify | `B4-R2`、`B4-R4` | 必备 6 件缺失仍报 MISSING |
| AC-10 副本零漂移 | T06(2) + T13(4) | T06 verify + T13 verify | `B5-R1`..`B5-R4` | `--check` 漂移 0 + 自证能发现漂移 |
| AC-11 结构与既有门禁不回退 | T05(4)（`l3-api.sh` 行数 250/250）+ T08B(6)（`make check` 五门） | T05 verify + T07 verify（结构门槛复验）+ T08B verify | `test_lib_split_metrics.bats` | 行数/结构/`check-lint` 逐条 |
| AC-12 提取失败语义可见 | T03(2)（`29-independent-review.sh` 告警）+ T02(3)（用例） | T03 verify + T02 verify | `B1-R25`、`B1-R26`、`B1-R27` | 空值 → stderr 含 `L2 verdict not found`，实参仍合法 |

**空白自检（可跑）**：

```sh
# ① 12 条 AC 都必须在本文件出现（矩阵零空白）
for i in $(seq 1 12); do grep -q "AC-$i[ ·]" TASK.md || echo "MISSING AC-$i"; done   # 期望：零输出
# ② 每个 AC 行都必须指向至少一个任务 ID
awk -F'|' '/^\| (AC-[0-9]+|\*\*AC-[0-9]+)/ {n=gsub(/T[0-9]+[A-Z]?/,"&"); if(n==0) print "无任务: " $0}' TASK.md  # 期望：零输出
```

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done" model-tier="standard">
  <name>抽取 L3 段边界的单一来源（l3-section.sh）：显式结束标记 + 转义入口</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-api.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-truncate.sh
    test/test_l3_review_defects_2026_09.bats     <!-- T08 骨架：verify 要跑的用例来源 -->
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
    # 命令层过滤（M45 的 ③）：逐个跑本任务可判定的用例，不跑 T05 的写侧接线用例。
    # 过滤器**锚定** `^<ID>:`（M1 修法）：裸 `-f "B2-R1"` 会连 B2-R10..R19 一起跑（实测 1..11）。
    for c in B2-R1 B2-R2 B2-R3 B2-R4 B2-R6 B2-R7 B2-R9 B2-R10 B2-R11 B2-R12 B2-R13 B2-R17 B2-R18 B2-R19; do
      out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^$c:" --formatter tap) || exit 1   # ① bats 退出码
      printf '%s\n' "$out" | grep -q '^not ok' && exit 1                                            # ③ 无失败行
      printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=1)?0:1}' || exit 1                             # ② 锚定后精确 1 条，下限 1
    done
  </verify>
  <done>
    L3 段边界只有一个实现；本任务范围内的 B2 用例全绿（跨任务断言归 T05 验收）。
    **AC-4**（重写幂等 · 零残留）：本任务交付 `_l3_spans_impl` 的段终点判据与 `_l3_escape_payload`
    转义集，由 `B2-R2`（5 轮后标记恰 1、围栏恰 2）、`B2-R6`、`B2-R7`、`B2-R10` 断言。
    **AC-5**（无标记历史件仍可清除）：本任务交付 `stop==0` 分支，由 `B2-R3`、`B2-R4` 断言。
  </done>
  <depends_on>T08</depends_on>
  <verify_phase>final（全部波次完成后统一复验；见下「复验模型」）</verify_phase>
</task>

<task id="T02" parallel="true" status="done" model-tier="standard">
  <name>收口 L2 结论提取：行首锚定 + 限定 L2 层 + 末次命中 + 小写归一</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/lib/l3-section.sh
    test/test_l3_review_defects_2026_09.bats     <!-- T08 骨架 -->
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
    set -o pipefail
      out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^B1-" --formatter tap) || exit 1
      printf '%s\n' "$out" | grep -q '^not ok' && exit 1
      printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=27)?0:1}' || exit 1
      # M5 的修法：done 里"语料全量复算"的声明必须有对应命令 —— 本任务自己跑 AC-2 的活语料用例
      out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^AC2:" --formatter tap) || exit 1
      printf '%s\n' "$out" | grep -q '^not ok' && exit 1
      printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=1)?0:1}' || exit 1
  </verify>
  <done>
    B1 组 27/27 全绿 + `AC2:` 活语料用例绿：提取函数零非枚举；**AC-2 的另一半（空值逐份可归因的
    清单再生）归 T09**（`corpus-count.sh --attribution` 是它的产物，本任务不重复认领）。
    对应 **AC-1**（限定 L2 层：`B1-R2`/`B1-R4`）、**AC-2**（`AC2:`）、**AC-3**（`B1-R1`）、
    **AC-12 的用例侧**（`B1-R25`/`B1-R26`/`B1-R27`，实现侧告警归 T03）。
  </done>
  <depends_on>T01,T08</depends_on>
  <verify_phase>final（全部波次完成后统一复验；见下「复验模型」）</verify_phase>
</task>

<task id="T03" parallel="true" status="done" model-tier="standard">
  <name>§B3：配置键改名 max_artifact_chars → max_artifact_bytes（保留旧键 + DEPRECATED 提示）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/config/stop-hook.json
    README.md
    dsh-flow-kit/README.md
    .claude/l3.env.example
    package-flow-kit.sh                          <!-- M2 修法：write_files 里的 heredoc 载体必须可读 -->
    .flow-kit/stop-hook.json                     <!-- M2 修法：本任务改 cap，T10 只断言不写 -->
    test/test_l3_review_defects_2026_09.bats     <!-- T08 骨架 -->
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
    set -o pipefail
      out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^B3-" --formatter tap) || exit 1
      printf '%s\n' "$out" | grep -q '^not ok' && exit 1
      printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=7)?0:1}' || exit 1
      # AC-12 的实现侧（本任务写 29-independent-review.sh 的告警），逐条跑对应用例
      for c in B1-R25 B1-R26 B1-R27; do
        out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^$c:" --formatter tap) || exit 1
        printf '%s\n' "$out" | grep -q '^not ok' && exit 1
        printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=1)?0:1}' || exit 1
      done
  </verify>
  <done>
    B3 组 **7/7**（`@test` 实测 7 条：`R1 R2 R3 R4 R5 R7 R8`；"第五处载体" `dsh-flow-kit/README.md`
    已并入 `B3-R5` 的载体循环，**不存在**独立的 `B3-R5b` 用例 —— 评审 04:13 minor① 指出的计数与 ID
    枚举不一致已按实测口径修正）。对应 **AC-6**（`B3-R4/R5`）、**AC-7**（`B3-R1..R3`）、
    **AC-12 实现侧**（`B1-R25/R26/R27`）。
    项目级 `.flow-kit/stop-hook.json` 的 cap=200000 由本任务写入（单一写者；T10 只 `jq -e` 断言）。
  </done>
  <depends_on>T08</depends_on>
  <verify_phase>final（全部波次完成后统一复验；见下「复验模型」）</verify_phase>
</task>

<task id="T04" parallel="true" status="done" model-tier="standard">
  <name>§B4：阶段 7 提示词产物清单改全量，并区分必备 / 补充产物</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    test/test_l3_review_defects_2026_09.bats     <!-- T08 骨架 -->
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
    set -o pipefail
      out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^B4-" --formatter tap) || exit 1
      printf '%s\n' "$out" | grep -q '^not ok' && exit 1
      printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=4)?0:1}' || exit 1
      out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^B7-" --formatter tap) || exit 1
      printf '%s\n' "$out" | grep -q '^not ok' && exit 1
      printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=5)?0:1}' || exit 1
  </verify>
  <done>
    B4 组 4/4 与 B7 组 5/5 全绿：41 条目目录零遗漏、不再凭空产出 INTEGRATION.md === MISSING。
    对应 **AC-8**（`B4-R1..R4`）、**AC-9**（`B4-R2`/`B4-R4`：必备件缺失仍报 MISSING）。
  </done>
  <depends_on>T08</depends_on>
  <verify_phase>final（全部波次完成后统一复验；见下「复验模型」）</verify_phase>
</task>

<task id="T05" parallel="true" status="done" model-tier="standard">
  <name>§B2：写入侧转义载荷（两个自动写入方）+ 写入侧 fail-closed</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-section.sh
    flow-kit-bundle/hooks/stop/lib/l3-api.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md
    test/test_l3_review_defects_2026_09.bats     <!-- T08 骨架 -->
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
    **本任务同时负责 `l3-api.sh` 的行数收敛**（新增 fail-closed 后曾达 257 行 → 压回 **250/250**，
    `AC-B1-metric` 绿）——评审 04:13 major① 指出原表把这条写入错记在 T07 名下，现已收归本任务
    （`write_files` 是任务边界的权威声明；T07 只读该文件）。
  </action>
  <verify>
    # 锚定过滤器（M1）：每个 ID 精确 1 条。本任务负责**写侧接线**用例，T01 不再越界跑到它们。
    set -o pipefail
    for c in B2-R5 B2-R8 B2-R9 B2-R10 B2-R14 B2-R15 B2-R16 B2-R20 B2-R21; do
      out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^$c:" --formatter tap) || exit 1
      printf '%s\n' "$out" | grep -q '^not ok' && exit 1
      printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=1)?0:1}' || exit 1
    done
  </verify>
  <done>
    转义是契约（B2-R5/R8/R9/R10/R14/R15/R16 全绿）；载荷无法伪造段起点、围栏或标记。
    两个写入方（`_l3_parse_result`、`l2_dispatch_agent`）均写入侧 fail-closed（`B2-R15/R16`、`B2-R20/R21`）。
    **AC-4**（重写幂等 · 零残留）：本任务交付"两个自动写入方都经 `_l3_escape_payload`"，
    由 `B2-R6`（5 轮字节稳定）、`B2-R7`（标记恰 1）、`B2-R10`（围栏不被破坏）断言。
    **AC-11 的实现侧**（结构门槛不回退）：`l3-api.sh` 行数 **250/250**（实测 `wc -l`）。
  </done>
  <depends_on>T01,T02,T08</depends_on>
  <verify_phase>final（全部波次完成后统一复验；见下「复验模型」）</verify_phase>
</task>

<task id="T06" parallel="true" status="done" model-tier="standard">
  <name>§B5：副本一致性工具 sync-hooks.sh（唯一源 → 四类树镜像 + 漂移检测）</name>
  <read_files>
    flow-kit-bundle/hooks/**
    flow-kit-bundle/flow-kit/prompts/**
    flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md
    Makefile
    test/test_l3_review_defects_2026_09.bats     <!-- T08 骨架（B5 组用例） -->
  </read_files>
  <write_files>
    sync-hooks.sh
    Makefile
  </write_files>
  <action>
    Makefile 行级边界：**只动** `hooks-sync` / `check-hooks-sync` 两个 target（`verify-claims` 归 T09）。
    新增 sync-hooks.sh：把源镜像到 7 个 DEST_ROOTS（含此前完全未覆盖的 `~/.config/opencode/hooks`
    与 dist/dsh 运行时树），覆盖四类树（hooks / prompts / 复合 agent / 平台级 agent 落点）；
    `--check` 必须**只读**（不得在检查模式下重放 agent 拷贝段）；`--list` 供复验工具动态枚举载体。
    Makefile 接线 `hooks-sync` 与 `check-hooks-sync`（后者入 `make check`）。
  </action>
  <verify>
    set -o pipefail
      ./sync-hooks.sh --check || exit 1
      make check-hooks-sync || exit 1
      out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^B5-" --formatter tap) || exit 1
      printf '%s\n' "$out" | grep -q '^not ok' && exit 1
      printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=5)?0:1}' || exit 1
  </verify>
  <done>
    漂移 0（`B5-R2`）；`B5-R4` 自证「能真的发现漂移」；用户级副本 `~/.claude/hooks` 命中 P0-1/P0-2（`B5-R3`）。
    对应 **AC-10**（副本一致：`B5-R1..R4`，本任务自跑；T13 在加 `--strict-orphans` 后再跑一遍）。
  </done>
  <depends_on>T08</depends_on>
</task>

<task id="T07" parallel="false" status="done" model-tier="standard">
  <name>判据同源：l3-truncate.sh 的「L3 段存在」改走 _l3_has_section</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-truncate.sh
    flow-kit-bundle/hooks/stop/lib/l3-section.sh
    test/test-l3-check-rerun-content-marker.bats
    test/test_l3_review_defects_2026_09.bats     <!-- T08 骨架（B2-R3/R4、B1-R21） -->
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-truncate.sh
    test/test-l3-check-rerun-content-marker.bats
  </write_files>
  <action>
    裸正则 `^## L3 (盲审|重审)` 判据废弃，改调 `_l3_has_section`（与写侧同源），并做依赖注入兜底；
    夹具补 `---` preamble 以符合新判据。**本任务不写 `l3-api.sh`**：其行数收敛归 T05
    （评审 04:13 major①：action 里出现而 write_files 未列 = 隐藏写入，故删去该句、收归文件所有者）。
  </action>
  <verify>
    set -o pipefail
      npx bats test/test-l3-check-rerun-content-marker.bats test/test_lib_split_metrics.bats || exit 1
      for c in B2-R3 B2-R4 B1-R21; do
        out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^$c:" --formatter tap) || exit 1
        printf '%s\n' "$out" | grep -q '^not ok' && exit 1
        printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=1)?0:1}' || exit 1
      done
  </verify>
  <done>
    重审触发判据与写侧同源。结构门槛由本任务**复验**（`test_lib_split_metrics.bats` 两文件实跑），
    其**实现**（`l3-api.sh` 行数收敛到 250/250）归 T05 —— 见共享写文件表"单一写者"行。
    对应 **AC-5**（判据同源后无标记历史件仍按 `stop==0` 分支清除：`B2-R3`/`B2-R4`/`B1-R21`）、
    **AC-11 的复验侧**。
  </done>
  <depends_on>T01,T08</depends_on>
  <verify_phase>final（全部波次完成后统一复验；见下「复验模型」）</verify_phase>
</task>

<task id="T08" parallel="true" status="done" model-tier="standard">
  <name>回归套件**骨架**：建 test_l3_review_defects_2026_09.bats 与 11 个分组（TDD 先红）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/**
    test/*.bats
  </read_files>
  <write_files>
    test/test_l3_review_defects_2026_09.bats
    flow-kit-bundle/test/test_l3_review_defects_2026_09.bats
  </write_files>
  <action>
    先落**文件与骨架**：分组（B1/B2/B3/B4/B5 + B6=M32 + B7=M34 + B8=D13 + B9=M36/M37 拦截 +
    B10=M37 写入后自检 + AC2）、每条 `@test "<ID>: <描述>"` 的**命名契约**（全表 verify 的锚定过滤器
    `-f "^<ID>:"` 依赖它）、各组公共夹具。此刻断言对未实现的代码应为**红**（TDD 的 Red）。
    **拆分依据**：阶段 3 的 L3 22:18 major —— 原表让实现任务的 verify 引用 Wave 5 才存在的产物，
    只用散文解释；拆成「骨架 Wave 1 / 补齐 Wave 6」后依赖可由 `depends_on` 表达。
  </action>
  <verify>
    # 骨架验收 = 文件存在 + 双源一致 + 分组与命名契约齐备（**不**要求断言通过：那是 T08B 的验收）
    set -o pipefail
      test -s test/test_l3_review_defects_2026_09.bats || exit 1
      cmp -s test/test_l3_review_defects_2026_09.bats flow-kit-bundle/test/test_l3_review_defects_2026_09.bats || exit 1
      for g in B1 B2 B3 B4 B5 B6 B7 B8 B9 B10 AC2; do
        # 锚定到组名后的分隔符（`-` 或 `:`）：否则 g=B1 会被 `@test "B10-…"` 命中 → 假绿（评审 04:13 major③）
        grep -qE "@test \"$g[-:]" test/test_l3_review_defects_2026_09.bats || { echo "缺分组: $g"; exit 1; }
      done
  </verify>
  <done>
    套件文件与 11 个分组骨架在库、双源一致、命名契约可被 `-f "^<ID>:"` 锚定。
  </done>
  <depends_on></depends_on>
</task>

<task id="T08B" parallel="false" status="done" model-tier="standard">
  <name>回归套件**补齐**：全量断言 + 变异自证 + 五门全绿</name>
  <read_files>
    test/test_l3_review_defects_2026_09.bats
    flow-kit-bundle/hooks/stop/**
    flow-kit-bundle/hooks/pre-tool-use/**
    Makefile
  </read_files>
  <write_files>
    test/test_l3_review_defects_2026_09.bats
    flow-kit-bundle/test/test_l3_review_defects_2026_09.bats
  </write_files>
  <action>
    把骨架补成全量断言；每条可独立运行；关键断言配**变异自证**
    （`B2-R16` / `B2-R21` / `B5-R4` / `B6-R5` / `B1-R27`：把实现改坏，断言必须失败），避免恒真断言。
    补齐后 `make test-sync` 同步镜像副本。阶段 3 的 L3 22:18 minor：verify 除 `make check` 外，
    必须**单独**统计缺陷套件，否则无法从合并输出确认套件自身通过。
  </action>
  <verify>
    set -o pipefail
      npx bats test/test_l3_review_defects_2026_09.bats --formatter tap > /tmp/t08b.tap || exit 1
      printf '缺陷套件: ok=%s not_ok=%s\n' \
        "$(grep -c '^ok' /tmp/t08b.tap)" "$(grep -c '^not ok' /tmp/t08b.tap)"
      grep -q '^not ok' /tmp/t08b.tap && exit 1
      head -1 /tmp/t08b.tap | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=119)?0:1}' || exit 1
      make check || exit 1
  </verify>
  <done>
    五门全绿（含全量 bats、双源一致、hooks 漂移 0）；缺陷套件**单独统计 ≥119 例 0 失败**（实测 119/0）。
    AC-2 的活语料不变量 = 零非枚举 + 每份空值可归因（清单由 `bash corpus-count.sh --attribution` 再生，
    数值预算 ≤8 只对**基线语料**成立）。对应 **AC-2 的用例侧**、**AC-11**、**AC-12 的用例侧**。
  </done>
  <depends_on>T01,T02,T03,T04,T05,T06,T07,T08,T11,T12</depends_on>
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
    set -o pipefail
      bash verify-claims.sh || exit 1
      # AC-2 的活语料不变量（现场复算，不抄快照）：零非枚举 + 每份空值都在归因清单里
      bash corpus-count.sh > /tmp/cc.out || exit 1
      cat /tmp/cc.out
      awk '{exit ($6+0==0)?0:1}' /tmp/cc.out || exit 1                      # 第 6 字段=非枚举数 → 必须 0
      bash corpus-count.sh --attribution /tmp/attrib.1 >/dev/null || exit 1  # 机械再生（临时路径，不改工作区）
      bash corpus-count.sh --attribution /tmp/attrib.2 >/dev/null || exit 1  # 再生幂等
      # 幂等比对必须排除唯一易变行「生成时间」（首版漏了这点 → 断言恒失败，2026-09-19 04:2x 修）
      diff <(grep -v '生成时间' /tmp/attrib.1) <(grep -v '生成时间' /tmp/attrib.2) >/dev/null || exit 1
      rows=$(grep -cE '^\| [0-9]+ \|' /tmp/attrib.1)
      empty=$(awk '{print $5}' /tmp/cc.out)
      printf '空值=%s 归因行=%s\n' "$empty" "$rows"
      [ "$rows" -eq "$empty" ] || exit 1
  </verify>
  <done>
    13 项检查全 ✅、rc=0（含 §0.5.1 载体覆盖、hooks 漂移、门禁）；第 5 项（裸正则残留）已用真实裸正则
    证明其可失败。**AC-2 的另一半由本任务交付**：`L2-EMPTY-ATTRIBUTION.md`（`corpus-count.sh --attribution`
    机械再生，再生幂等且归因行数 == 活语料空值数 —— 实测 8=8）。**覆盖边界（如实）**：本脚本核对
    「响应段声明 ↔ 现场事实」，**不**解析 TASK.md 的 write_files（R6.5 的 diff 边界由
    `git diff --name-only` 在评审中核对）。
  </done>
  <depends_on>T08B</depends_on>
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
  </write_files>
  <action>
    新增 ADR-026（不可信载荷不得伪造结构性边界；含三代穿透与「接受残余 + v2 PreToolUse 强制转义」）；
    登记 CONTEXT 域语言与禁动建议（§9.5）；CHANGELOG/STATE 更新。
    **边界收敛（阶段 3 的 L3 22:18 major ②）**：项目级 `.flow-kit/stop-hook.json` 的 cap 20000 → 200000
    **由 T03 写**（cap 属于 §B3 的键语义，且 T03 已在 Wave 2 完成）；本任务**只读 + 断言**，不再列入 write_files，
    消除同一文件的重复归属。
  </action>
  <verify>
    set -o pipefail
      make check-validate || exit 1
      jq -e '.independent_review.max_artifact_bytes == 200000' .flow-kit/stop-hook.json >/dev/null || exit 1
      # minor 修法：原断言 grep 文件名（自指、几乎恒真）→ 改断言 ADR 的**结论标题**与章节结构
      # （首版写成"不得伪造结构性边界"，与 ADR 实际标题"工件结构边界"不符 → 恒失败，04:2x 修）
      grep -q '^# ADR-026: .*不可信载荷不得伪造工件结构边界' .specs/adr/026-untrusted-payload-cannot-forge-boundaries.md || exit 1
      grep -q '^## Decision' .specs/adr/026-untrusted-payload-cannot-forge-boundaries.md || exit 1
      grep -q '^## Consequences' .specs/adr/026-untrusted-payload-cannot-forge-boundaries.md || exit 1
      grep -q 'l3-review-defects-2026-09' .specs/CHANGELOG.md || exit 1
  </verify>
  <done>
    项目级沉淀齐全且**可证伪**：cap=200000（`.flow-kit/stop-hook.json` 被 `.gitignore:64` 忽略，
    故 diff 不可见 → 用 `jq -e` 断言替代）、ADR-026 在库（断言其**结论标题**而非自指文件名）、
    CONTEXT 术语与 CHANGELOG 条目更新。
  </done>
  <depends_on>T01,T02,T03,T04,T05,T06,T07,T08,T08B,T09,T11,T12,T13</depends_on>
</task>

<task id="T11" parallel="true" status="done" model-tier="standard">
  <name>M32：非 pass 时撤销陈旧 .done 锚点</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-done.sh
    test/test_l3_review_defects_2026_09.bats     <!-- T08 骨架（B6 组用例） -->
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
    set -o pipefail
      out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^B6-" --formatter tap) || exit 1
      printf '%s\n' "$out" | grep -q '^not ok' && exit 1
      printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=6)?0:1}' || exit 1
  </verify>
  <done>
    B6 组 6/6；实测已阻止"截断版 pass 的锚点"在新一轮 fail 后继续放行。对应 M32。
  </done>
  <depends_on>T01,T02,T08</depends_on>
  <verify_phase>final（全部波次完成后统一复验；见下「复验模型」）</verify_phase>
</task>

<task id="T12" parallel="true" status="done" model-tier="standard">
  <name>M36/M37 + D14：贴入路径的可执行拦截与写入后结构自检</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/**
    flow-kit-bundle/hooks/stop/lib/l3-section.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh   <!-- minor 修法：路径与 write_files 统一为完整相对路径 -->
    test/test_l3_review_defects_2026_09.bats              <!-- T08 骨架（B9/B10 组用例） -->
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
    set -o pipefail
      out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^B9-" --formatter tap) || exit 1
      printf '%s\n' "$out" | grep -q '^not ok' && exit 1
      printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=16)?0:1}' || exit 1
      out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^B10-" --formatter tap) || exit 1
      printf '%s\n' "$out" | grep -q '^not ok' && exit 1
      printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=9)?0:1}' || exit 1
  </verify>
  <done>
    B9 组（16 例）与 B10 组（9 例）全绿；裸标题=放行且**证明无害**、`---`+标题+无标记=拒绝。对应 M36/M37/D14。
    **AC-4**（重写幂等 · 零残留）：本任务交付「写入后结构自检」（段数 ≤1 / 段尾=结束标记 / 段内围栏配平），
    由 `B10-*` 断言 —— 写入侧转义与段判据分别归 T05/T01，三者共同构成 AC-4 的完整证据链。
  </done>
  <depends_on>T03,T05,T11,T08</depends_on>
  <verify_phase>final（全部波次完成后统一复验；见下「复验模型」）</verify_phase>
</task>

<task id="T13" parallel="false" status="done" model-tier="standard">
  <name>sync-hooks 反向残留发现能力（源已删、副本仍在）</name>
  <read_files>
    sync-hooks.sh
    test/test_l3_review_defects_2026_09.bats     <!-- T08 骨架（B5 组用例） -->
  </read_files>
  <write_files>
    sync-hooks.sh
  </write_files>
  <action>
    `--check` 增反向残留扫描（副本有、源无的 hook 文件）默认 advisory；`--strict-orphans` 计入失败；
    顺带修参数解析只看 `$1` 的 bug（`--check --strict-orphans` 的第二个参数曾被静默忽略）。
  </action>
  <verify>
    set -o pipefail
      out=$(npx bats test/test_l3_review_defects_2026_09.bats -f "^B5-" --formatter tap) || exit 1
      printf '%s\n' "$out" | grep -q '^not ok' && exit 1
      printf '%s\n' "$out" | awk -F'[.][.]' '/^1\.\./{exit ($2+0>=5)?0:1}' || exit 1
      ./sync-hooks.sh --check --strict-orphans || exit 1
  </verify>
  <done>
    B5 组 5/5；`--check` 在真实树仍为漂移 0（含 `--strict-orphans` 也不因反向残留而失败）。
    对应阶段 2 的 L3 19:15 major② 与 **AC-10**。
  </done>
  <depends_on>T06,T08</depends_on>
  <verify_phase>final（全部波次完成后统一复验；见下「复验模型」）</verify_phase>
</task>
```

---

## R6.5 提交前 diff 边界校验

| 任务 | write_files 与实际 diff |
| --- | --- |
| T01–T05, T07, T11 | `flow-kit-bundle/hooks/stop/**`、`flow-kit-bundle/flow-kit/prompts/**`（受 `sync-hooks.sh` 镜像） |
| T12 | `flow-kit-bundle/hooks/pre-tool-use/**` 三文件（**事后扩界**：M36/M37/D14 修复期新增）+ `hooks/stop/lib/{l3-section,correction-file,l3-review}.sh` + `29-independent-review.sh` |
| T03 | 额外命中 `package-flow-kit.sh` 的 heredoc 文本 = **禁动偏差**（已声明 + M10 + 回滚方案）；并**唯一**负责 `.flow-kit/stop-hook.json` 的 cap=200000 |
| T06, T13 | `sync-hooks.sh` / `Makefile` 新增与接线，未改 `install_hooks.sh`（只读引用） |
| T08, T08B | `test/test_l3_review_defects_2026_09.bats` + 镜像 `flow-kit-bundle/test/test_l3_review_defects_2026_09.bats`（`make check-test-sync` 保证双源一致） |
| T10 | `.specs/**`（ADR-026 / CONTEXT / CHANGELOG / STATE / PROGRESS）；**不写** `.flow-kit/stop-hook.json`（写者=T03，该文件被 `.gitignore` 忽略 → 由 `jq -e` 断言替代） |

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

## 补档追加说明（2026-09-18 21:3x 起，2026-09-19 04:0x 依阶段 3 的 L3 22:18 结论更新）

- **M40 已闭合**（`bats -f <组>-` 命中 0 条即算通过）：全表 verify 统一为**三查**
  （① bats 退出码 ② TAP 计划行下限 ③ 无 `not ok`），且过滤器一律**锚定** `-f "^<ID>:"`。
  复现（旧写法确实会空跑通过）：`npx bats test/test_l3_review_defects_2026_09.bats -f "ZZZ-NOPE"` → `1..0`，rc=0。
- **本轮新发现并修掉的第二个「恒失败」缺陷（此前未被任何评审发现）**：原表计划行下限写成
  `awk '/^1\.\./{exit ($2>=N)?0:1}'` —— TAP 计划行是**单 token**（`1..27`），`$2` 为空串，
  比较恒为假 → **该 verify 永远 exit 1**（实测 `printf '1..11\n' | awk '/^1\.\./{exit ($2>=1)?0:1}'` → rc=1）。
  即：这些 verify 从未真正跑通过，也就无从发现 M40。已全表改为
  `awk -F'[.][.]' '/^1\.\./{exit ($2+0>=N)?0:1}'`（实测 `1..11` → rc=0；`1..0` → rc=1，空跑必被抓）。
- **T08 已按评审意见真的拆两段**：`T08`=骨架（Wave 1，先红）/ `T08B`=补齐（Wave 6）。
  实现任务的 `depends_on` 里能看到 `T08`（产物存在性），`verify_phase="final"` 只表达**复验时点**
  （完备性）；`T08B` 依赖各实现任务，故实现任务**不得**反向依赖 `T08B`（这正是必须拆两段的原因）。
