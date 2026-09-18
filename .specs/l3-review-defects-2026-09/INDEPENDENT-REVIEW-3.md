
---

## 主 agent 响应（阶段 3 L2 盲审 · 2026-09-18）

> 派发方式：`workflow` 的 `agent()`（**全新上下文**，不继承作者会话）；只读审查 + 自行落盘 JSON。
> 分类标记行会被 `_l3_inject_context` 注入下一轮。

- **critical①（T08 verify 实测 rc=1）** — Fixed in: AC-2 用例改为**活语料不变量 + 基线数值预算**（零非枚举 / 每份空值可归因 / `base_empty ≤ 8`），归因清单改由 `bash corpus-count.sh --attribution` **机械再生**（本次：`n=227 empty=11 base_empty=8 nonenum=0`，清单 11 行覆盖全部空值）；AC-2 文本同步分层（REQUIREMENT/TEST）。
- **critical②（verify-claims 11✅/2❌ 且被当成 R6.5 工具）** — Fixed in: §0.5.1 补 `correction-file.sh`（第 10c 项）；T09 的 done 如实写明**不解析 TASK.md 的 write_files**；门禁项随测试转绿复验。
- **critical③（T07 verify 的 `make check-structure` 不存在）** — Fixed in: 改 `npx bats test/test-l3-check-rerun-content-marker.bats test/test_lib_split_metrics.bats`；REQUIREMENT AC-11 的 `scripts/check-structure.sh` 载体一并更正为真实载体。
- **critical④（write_files 漏 12 文件 / T03 路径不存在 / M36·M37·D14 无任务承接）** — Fixed in: 新增 **T11**（M32 锚点撤销）、**T12**（M36/M37/D14 三文件 + 写后自检）、**T13**（反向残留）；补齐 write_files（pre-tool-use×3、l3-done/l3-review、correction-file、`.claude/l3.env.example`、`L2-EMPTY-ATTRIBUTION.md`）；R6.5 表按 `git diff --name-only` 重写并新增**禁动命中登记表**（3 项，含"仅追加函数、不改签名"的边界声明）。
- **major（AC-2 交付物无生产者）** — Fixed in: 写入 T02 的 write_files，并在 done 中写明"随语料自增、机械再生"。
- **major（波次表与 depends_on 矛盾）** — Fixed in: 波次重排（T06→Wave1、T11/T12→Wave2、T13→Wave3、T10 单列 Wave5）+ 新增"同波不得有依赖"的不变量表。
- **major（T01 verify 含跨任务断言）** — Fixed in: T01 的 verify 注明范围（B2-R1..R4/R6/R7/R9..R13/R17..R19），跨任务断言归 T05。
- **major（`bats -f` 命中 0 条即通过）** — Fixed in: T08 的 verify 改为 `make check`（整目录、含 900+ 例）；其余任务的 done 改为"本任务范围内的用例"表述。**Tech-debt:** verify 过滤器加命中数下限校验（解析 TAP `1..N`）列入后续（M40）。
- **major（T10 done 不可证伪）** — Fixed in: T10 的 verify 增 `jq -e '.independent_review.max_artifact_bytes == 200000'`（该文件被 `.gitignore:64` 忽略，diff 不可见）+ ADR 存在性断言。
- **minor（覆盖面缺口）** — 记录：L2 亦指出 T06/T01/T08 粒度过大（334/244/1361 行）。**Not-applicable（补档语境）**：本 change 为回溯补档，任务边界按"缺陷编号"而非"可并行切片"划分；已在 TASK.md 的模式说明中如实标注。

---

## L2 盲审（阶段 3 · 任务拆解 · 全新上下文子 agent · 2026-09-18）

> 派发：`workflow` 的 `agent()`（全新上下文）；只读审查，唯一写操作 = 自己的 JSON 落盘。
> 说明：本段的 4 critical / 7 major / 3 minor 已由**上文**「主 agent 响应（阶段 3 L2 盲审）」逐条处置。

```json
{
 "critical": [
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T08 verify+done)",
   "issue": "T08 的 verify 在 HEAD=49be722 实测 rc=1：`npx bats test/test_l3_review_defects_2026_09.bats` → 97 ok / 1 not ok，失败用例 `AC2: 语料全量复算`（n=226 empty=10 nonenum=0 unattributed=[INDEPENDENT-REVIEW-3.md INDEPENDENT-REVIEW-5.md]）；同一原因使 `npx bats test/` = 923 ok/1 not ok（make test → make check 失败）。",
   "why": "该用例现场扫描活的 `.specs/**`，本 change 自己的审查文件（19:47 INDEPENDENT-REVIEW-3.md、19:49 INDEPENDENT-REVIEW-5.md）就把 AC-2 的空值预算从 8 顶到 10 并产生未归因项 → 只要本 change 还在被审查，T08 verify 必红，done『套件全绿…对应 AC-11/AC-12』与 AC-2/AC-11（全量 bats 0 fail）均不成立，按 TASK.md 执行得不到 done。",
   "fix": "把 AC2 用例 hermetic 化：改成对固定快照（如 .specs/archive/** 或测试内合成语料）复算，或对 `.specs/<本 change>/**` 动态归因（新空值自动入清单）；T08 verify 改为 `make check` 并把语料口径写进 TASK.md；若口径必须覆盖全仓，则 AC-2 的『≤8』预算与用例都要改成随轮次自增的公式。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T09/T10 verify；第 306 行 R6.5 复验命令)",
   "issue": "T09 verify `bash verify-claims.sh` 与 T10 verify（`make check-validate && bash verify-claims.sh`）在 HEAD=49be722 实测 rc=1，输出 11 ✅ / 2 ❌：`10c §0.5.1 未列: correction-file.sh`、`10 门禁: make check 未通过`；与 T09 done『13 项检查全 ✅、rc=0』直接矛盾。",
   "why": "verify-claims.sh 对 TASK.md/write_files 零覆盖（`grep -c TASK.md verify-claims.sh`=0、`grep -c write_files`=0），故 TASK.md 第 306 行把它当作『R6.5 diff 边界校验』的复验工具是错误声明——被改的 correction-file.sh 只能靠 DESIGN.md 的字符串出现与否兜到，而 TASK.md 的 12 处漏列完全不可见。",
   "fix": "新增 check：解析 TASK.md 的 write_files 并对 `git diff --name-only <基线>..HEAD` 双向比对（漏列/越界即 fail）；修掉 correction-file.sh 的 §0.5.1 登记并让脚本回到 rc=0 后才可声明 done；TASK.md 第 306 行改为如实描述该脚本的覆盖范围。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T07 verify；第 6-7 行『模式说明』)",
   "issue": "T07 verify 第二段 `make check-structure` 不可执行：Makefile 无该 target、仓库无 `scripts/` 目录、`git log --all -S check-structure` 证明它从未存在；实测 `make: *** 没有规则可制作目标“check-structure”。停止。`，rc=2。",
   "why": "TASK.md 第 6-7 行自述『所有任务的 verify 命令现在仍可复跑（补档不等于事后编造的可核性保障）』被这条命令证伪；T07 done 声明的结构门槛真实载体是 `test/test_lib_split_metrics.bats`（AC-B1/B2/B3 metric，实测 4 ok），而它不在任何任务的 verify 中。",
   "fix": "T07 verify 改为 `npx bats test/test-l3-check-rerun-content-marker.bats test/test_lib_split_metrics.bats`（或 `make test`）；并同步修正 AC-11 ② 对 `scripts/check-structure.sh` 的引用（该脚本不存在）。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (write_files 全集；第 299-302 行 R6.5 表)",
   "issue": "write_files 与实际 diff 不符（base 61c4bf8 与变更基线 19b3463 结果相同：26/30 个源码-测试文件中 12 个未被任何 write_files 覆盖）：`hooks/pre-tool-use/{gate-helpers.sh,gate-helpers-types.sh,independent-review-gate.sh}`、`hooks/stop/lib/{correction-file.sh,l3-done.sh,l3-review.sh}`、`flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md`、`flow-kit-bundle/test/{test-l3-check-rerun-content-marker,test_l3_lifecycle_wiring,test_l3_review}.bats`、`test/{test_l3_lifecycle_wiring,test_l3_review}.bats`（另 11 个 .claude/hooks/** 镜像）；T03 还列了不存在的路径 `flow-kit-bundle/flow-kit/l3.env.example`（ls: No such file），而实际被改且被 B3-R5 断言的 `.claude/l3.env.example` 未列。",
   "why": "R6.5 表第 301 行『T01–T05 全部落在 hooks/stop/** 与 prompts/** 内』被 diff 直接证伪（pre-tool-use/** 不在该前缀）；write_files 是阶段 4/7 的边界执法依据，漏 12 个文件后越界不可能被拦（DEV-SUMMARY 自述的 M36/M37『事后扩界』即其后果）；D14 写后自检（B10 组 7 条）、M37 Bash 通道（B9-R7/R8）、sync-hooks 反向残留/--strict-orphans（B11/B12）整块交付面在 TASK.md 中无任何任务承接（TASK.md mtime 18:58 vs 代码/测试改到 19:49）。",
   "fix": "补 T11（M32：l3-done.sh/l3-review.sh 撤销锚点 + B6）、T12（D14/M36/M37：pre-tool-use 三文件 + 写后自检 + Bash 通道 + B9/B10）、T13（反向残留 + B11/B12）；把上述 12 个文件与 `.claude/l3.env.example` 补进对应 write_files，从 T03 删除不存在的路径；R6.5 表按 `git diff --name-only` 实测重写。"
  }
 ],
 "major": [
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T02/T08 write_files)",
   "issue": "REQUIREMENT AC-2 规定 `.specs/l3-review-defects-2026-09/L2-EMPTY-ATTRIBUTION.md` 是『本 change 的具体交付物（固定路径）』，但 TASK.md 全文无 'ATTRIBUTION'（grep rc=1），没有任何任务把它写进 write_files；T08 自己的 AC2 用例以 `[ -f \"$attr\" ]` 强依赖它。",
   "why": "AC-2 的交付物无生产者，阶段 3 的读/写约束不完整；该清单现已过期（8 条 vs 实测空值 10 条）且无人负责同步，正是 T08 verify 变红的直接输入。",
   "fix": "把该文件加入 T02 的 write_files，并把『空值 ≤8 且逐行归因、随语料自增』写进 T02 done；或在 TASK.md 新增独立任务负责该交付物。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md 第 17 行 vs 第 291 行",
   "issue": "波次表把 T09 标 `[P]` 并与 T10 同列 Wave 4（parallel），但 T10 的 depends_on 含 T09；同一页又定义『同 wave = 可并行；跨 wave = 必须顺序执行』。另 T06 depends_on 为空却被排进 Wave 2（Wave 1 尚有空位）。",
   "why": "同波任务之间存在依赖 → 波次划分与依赖图不一致，按波次并行派发会用到未完成的上游产物；T06 的错位让无依赖工作被动串行。",
   "fix": "T10 单列 Wave 5（或合并 T09+T10）；把 T06 提到 Wave 1；波次表补 depends_on 列以便机器校验『同波无依赖』不变量。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T01 verify/done)",
   "issue": "T01 在 Wave 1，其 verify `-f \"B2-\"`（21 条）包含 B2-R8/R14/R15/R16 等断言 l3-api.sh 调用点与 l2-detect.sh 写入侧接线的用例，而这些文件属 T02/T05（Wave 2）的 write_files。",
   "why": "按波次单独执行 T01 时该 verify 不可能通过（写侧接线尚未存在），T01 done 声称的『转义契约全绿』是 T05 的产物，任务边界与验收边界错位（补档环境掩盖了这一点）。",
   "fix": "把写侧接线用例划归 T05 的 verify；T01 verify 只保留 l3-section.sh 自身可判定的用例（B2-R1..R4/R6/R7/R9..R13/R17..R19），并在 done 中不引用跨任务断言。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T01–T05 verify)",
   "issue": "T01–T05 五条 verify 全为 `npx bats <file> -f \"<组>-\"` 形态；实测 `npx bats test/test_l3_review_defects_2026_09.bats -f \"ZZZ-NOPE\"` → 输出 `1..0`，rc=0。",
   "why": "过滤器命中 0 条即算通过：组名重命名、用例被删、文件被替换都仍绿；T05 的 verify 实际只跑 1 条（B2-R8），其 done 却列举 R5/R8/R9/R10/R14/R15/R16 七条 → 至少 6 条验收声明无常驻证据。",
   "fix": "verify 改为整文件/整目录（`npx bats test/`）或在过滤后加命中数下限校验（解析 TAP `1..N` 并断言 N≥预期值）。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T10 verify/done)",
   "issue": "T10 done 要求『ADR 索引、CONTEXT 术语表、CHANGELOG 条目、cap 生效』可复验，但 verify 仅 `make check-validate`（打包覆盖率，实测 rc=0）与 `bash verify-claims.sh`（12 组检查，无一读 ADR 索引/CONTEXT/CHANGELOG/200000；`grep -rn 200000 verify-claims.sh corpus-count.sh` 无命中）。",
   "why": "验收声明无对应可执行证据；`.flow-kit/stop-hook.json` 被 `.gitignore:64` 忽略（`git check-ignore -v` 命中），cap 20000→200000 的改动在 diff 中不可见、也不在任何检查内 → 该 done 完全不可证伪。",
   "fix": "给 T10 增加可执行断言并纳入 verify：`jq -e '.independent_review.max_artifact_bytes==200000' .flow-kit/stop-hook.json`、ADR 索引含 026、CHANGELOG 含本 change 行、CONTEXT 含新术语与禁动建议；或把这些写成 verify-claims.sh 的新 check。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T03 write_files) vs .specs/CONTEXT.md:469,475,480",
   "issue": "T03 write_files 含 `flow-kit-bundle/hooks/stop/29-independent-review.sh`（CONTEXT 禁动清单『independent-review-gate.sh + 29-independent-review.sh + fk_validate_done_marker — gate 校验核心链』，且该条唯一例外被限定在 cleanup-debt-batch-2026-08 一个 change 内），TASK.md 未做任何禁动命中登记；`independent-review-gate.sh`（禁动『校验顺序：真实性→实效性→放行』）与 `correction-file.sh`（禁动 4 函数签名所在文件）实际被改，既不在任何 write_files，也不在 DESIGN §0.5.1 偏差声明（该节自称命中 1 项）。",
   "why": "阶段 3 checklist 的『write_files 是否触碰禁动清单』不通过；偏差声明计数（1）与事实（≥3 个禁动文件）不符，例外未经申请即实施，与 package-flow-kit.sh 的 M10 同类但未登记。",
   "fix": "在 TASK.md/DESIGN §0.5.1 逐条登记禁动命中与理由（29-independent-review.sh、independent-review-gate.sh、correction-file.sh 追加函数、package-flow-kit.sh），补例外申请记录并给出回滚方案；把 independent-review-gate.sh/correction-file.sh 写入相应任务的 write_files。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T08；T01/T06/T09)",
   "issue": "T08 单任务 = 新增 1361 行 / 98 条用例 / 11 组（B1–B10 + AC2），且 action 只写『按缺陷编号分组（B1/B2/B3/B4/B5 + B6/M32 + B7/M34）』，与实际含 B8/B9/B10/AC2 不符；T06=334 行、T01=244 行、T09=208 行（numstat 19b3463..HEAD）。",
   "why": "超出阶段 3 checklist『单 task ≤200 行变更』与 fresh context 2~10 分钟粒度；T08 还是全 change 唯一回归套件，任一组红都要整套重跑，且按 action 无法复核实际范围。",
   "fix": "按缺陷族拆 T08（B1/B2｜B3/B4｜B5｜B6/B7｜B8/B9/B10+AC2），每组独立 verify；action 中列全组名；T01/T06/T09 若无法拆分，至少在 TASK.md 标注超线理由与拆分母任务。"
  }
 ],
 "minor": [
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T06 verify/done)",
   "issue": "verify 是同一命令跑两遍：`./sync-hooks.sh --check` 与 `make check-hooks-sync` 等价（Makefile:73-75 即 `bash sync-hooks.sh --check`）；done 点名的 B5-R2/B5-R3/B5-R4 一个都不在 verify 中。",
   "why": "重复不增加证据；『漂移可被门禁拦下』的证伪证据是 B5-R4（自证可失败），却未被执行，verify 只证明当前无漂移。",
   "fix": "verify 改为 `./sync-hooks.sh --check && npx bats test/test_l3_review_defects_2026_09.bats -f \"B5-\"`。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T09 action) / verify-claims.sh:33-42",
   "issue": "action 称载体『动态枚举（读 sync-hooks.sh --list，不写死路径/数量）』，但 verify-claims.sh 从不调用 --list（grep 计数 0），改用硬编码 CARRIER_ROOTS 四处根。",
   "why": "与 sync-hooks.sh 的 DEST_ROOTS 构成第二份副本枚举（R3 知识重复）：sync-hooks 新增落点时 verify-claims 会漏检，『不写死路径』的声明与实现相反。",
   "fix": "改为 `bash sync-hooks.sh --list`（或导出 DEST_ROOTS）驱动枚举，消除硬编码根。"
  },
  {
   "file": "verify-claims.sh:115-155",
   "issue": "check 8（DESIGN 结构）/9（MINOR 编号）/10c（§0.5.1 覆盖）没有文件存在或最小条目数前置：把目标指向空文件、或 git 输出为空时三处仍打印 ✅（本轮用空文件与空变量实测复现）。",
   "why": "属恒真断言族——与套件里 B1-R27/B2-R16/B5-R4 的自证标准不一致；文件被改坏/清空时门禁反而全绿。",
   "fix": "每个 check 前加 `[ -f \"$f\" ]` 与非空条目下限（如 `_risk` 至少 1 项、`_changed` 至少 1 个文件），否则 fail。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T07 action 第 204 行、done 第 210 行)",
   "issue": "done 声称『l3-api.sh 压回 ≤250 行结构门槛（冻结在 249 行）』『249/250』，实测 `wc -l flow-kit-bundle/hooks/stop/lib/l3-api.sh` = 250。",
   "why": "数字与现场不符（门槛断言为 `-le 250`，余量 0），本 change 期间已两次逼近上限（M37/D14 各加行），下一步一行即破门。",
   "fix": "改为如实的 250/250 并把『冻结值』写入 TASK.md 的验收口径，同时给出余量告警或拆分计划。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T08/T09 read_files)",
   "issue": "T08 read_files 仅 `flow-kit-bundle/hooks/stop/**`、`test/*.bats`，但其套件实际读取 `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh`（B9 组靠 $GATE_HELPERS）、`sync-hooks.sh`+`Makefile`（B5）、`.specs/.../L2-EMPTY-ATTRIBUTION.md`（AC2）；T09 read_files 未含它实际读取的 DESIGN.md、MINOR-DEFERRED.md 与 `.specs/**` 语料。",
   "why": "read_files 是 fresh-context 执行的输入白名单，漏列会让执行者要么读不到关键契约、要么越界读取而不自知。",
   "fix": "按实际依赖补全 read_files（T08 加 pre-tool-use/**、sync-hooks.sh、Makefile、.specs/<id>/L2-EMPTY-ATTRIBUTION.md；T09 加 DESIGN.md、MINOR-DEFERRED.md、.specs/**）。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TASK.md (T09/T10)",
   "issue": "反向覆盖不通过：T09 的 verify-claims.sh/corpus-count.sh 在 DESIGN §0.5.1 被自述为『流程治理（非 §Bx）』，T10 的 ADR/CONTEXT/CHANGELOG/STATE/PROGRESS/项目级 cap 也无 AC 承接（AC-6 的 Given 用 60000 合成配置，cap 200000 属 DESIGN 附的截断问题）。",
   "why": "阶段 3 要求每个任务服务至少一条 AC 或显式登记为非 AC 治理项；现状下这两个任务的存在理由只在 DESIGN 正文里，TASK.md 无锚点，审查/验收时无法判定其完成标准。",
   "fix": "在 TASK.md 任务头为 T09/T10 增加 `<serves>` 字段（填『治理项，非 AC』或对应 AC 编号），或把它们并入承接 AC-11/AC-2 的任务。"
  }
 ],
 "verdict": "fail",
 "summary": "TASK.md 的 verify 契约整体不成立（T07 的 make check-structure 目标不存在 rc=2；T08 的套件与 T09/T10 的 verify-claims 在 HEAD=49be722 实测 rc=1，AC2 用例现场扫描活的 .specs/ 被本 change 自己的审查件打红），write_files 漏列 12 个实际被改文件（pre-tool-use/**、l3-done.sh、l3-review.sh、correction-file.sh、agent 与既有 bats）且 R6.5 第 301 行的边界自述被 diff 证伪，另有波次与依赖互相矛盾、过滤式 verify 恒真（1..0 rc=0）、禁动清单未申报、T08 粒度 1361 行/98 用例等；作者声明（DEV-SUMMARY：86 条用例、48 files/8067 insertions、13✅rc=0）与我的实测（98 条、54 files/9318 insertions、11✅2❌）均不符——以上均为我独立跑出的结果，DEV-SUMMARY/DESIGN 只作为待复核声明使用。"
}
```

**Verdict**: fail

（依据：TASK.md 的 verify 契约整体不成立（T07 的 make check-structure 目标不存在 rc=2；T08 的套件与 T09/T10 的 verify-claims 在 HEAD=49be722 实测 rc=1，AC2 用例现场扫描活的 .specs/ 被本 change 自己的审查件打红），write_files 漏列 12 个实际被改文件（pre-tool-use/**、l3-done.sh、l3-review.sh、correction-file.sh、agent 与既有 bats）且 R6.5 第 301 行的边界自述被 diff 证伪，另有波次与依赖互相矛盾、过滤式 verify 恒真（1..0 rc=0）、禁动清单未申报、T08 粒度 1361 行/98 用例等；作者声明（DEV-SUMMARY：86 条用例、48 files/8067 insertions、13✅rc=0）与我的实测（98 条、54 files/9318 insertions、11✅2❌）均不符——以上均为我独立跑出的结果，DEV-SUMMARY/DESIGN 只作为待复核声明使用。）

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-18 22:18）

> 自动生成于 2026-09-18 22:18。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "TASK.md（任务清单/AC 映射）",
      "issue": "AC-4 与 AC-5 没有任何任务显式对应，done 中列出的 AC 映射也完全未提及这两项，无法证明任务拆解覆盖 REQUIREMENT 全部验收条件。",
      "why": "任务拆解要求覆盖 REQUIREMENT 全 AC，AC-4/AC-5 缺失会导致对应需求无实现、无验证，形成不可追溯的空白。",
      "fix": "补充 AC-4/AC-5 到具体任务的 done/action 中，或增设专门任务，并在 verify 中提供对应可执行断言。"
    }
  ],
  "major": [
    {
      "file": "TASK.md（T01 verify）",
      "issue": "T01 使用 `-f \"B2-R1\"` 循环过滤，但 bats 的 -f 为子串匹配，`B2-R1` 会同时匹配 B2-R10~R19，其中包含 T05 写侧接线用例 R14/R15/R16，与 T01 自述“不跑写侧接线用例”矛盾。",
      "why": "T01 的 verify 会被无关任务的用例影响，造成验证边界不清晰，可能出现 T01 自身正确但因 T05 未完成而失败的情况。",
      "fix": "改用精确匹配（如 `--filter '^B2-R1$'`）或按用例完整名称逐一指定，确保 T01 只验证本任务范围。"
    },
    {
      "file": "TASK.md（T03 write_files/read_files）",
      "issue": "T03 的 write_files 包含 package-flow-kit.sh 和 .flow-kit/stop-hook.json，但 read_files 中未包含这两个文件；且 .flow-kit/stop-hook.json 同时由 T10 写入，职责重叠。",
      "why": "未读先写会导致 agent 缺乏修改上下文，容易破坏文件；同一文件由两个任务写入会造成最终职责不清和潜在冲突。",
      "fix": "将这两个文件加入 T03 read_files；将 .flow-kit/stop-hook.json 的改动合并到 T10 或从 T03 write_files 移除，避免交叉写入。"
    },
    {
      "file": "TASK.md（write_files 边界整体）",
      "issue": "多个任务重叠写入同一文件：T02/T05 都写 l2-detect.sh，T01/T12 都写 l3-section.sh，T06/T13 都写 sync-hooks.sh，T06/T09 都写 Makefile，T03/T10 都写 .flow-kit/stop-hook.json。",
      "why": "任务边界不清晰，无法判断每个文件的最终内容由哪个任务负责，后续维护和复验时难以定位变更来源，也容易产生增量冲突。",
      "fix": "合并对同一文件的修改到单一任务，或通过显式 patch/增量描述拆分范围，并在 write_files 中注明“创建/追加/修改的具体函数或区域”。"
    },
    {
      "file": "TASK.md（T01–T05/T07/T11/T12/T13 verify 依赖）",
      "issue": "这些任务的 verify 均引用 T08 产出的 test_l3_review_defects_2026_09.bats，但 depends_on 均不包含 T08；仅以非标准字段 verify_phase=final 说明复验时点。",
      "why": "正式依赖图不完整：若执行引擎按 depends_on 顺序运行 verify，T08 之前执行这些 verify 必然因文件缺失而失败；verify_phase 不是机器可识别的依赖机制，补档语义虽解释但无法自动化保证。",
      "fix": "为这些任务补充 `verify_depends_on=T08`（或在 depends_on 中增加 T08 并同步调整波次），或将 verify 命令改为在 T08 产物存在的前提下运行的独立复验脚本并显式声明前置条件。"
    },
    {
      "file": "TASK.md（T02 done/verify 与 AC-2）",
      "issue": "T02 done 声称“语料全量复算零非枚举（AC-2 的用例）”，但其 verify 仅运行 `-f \"B1-\"` 的 bats 用例，未包含 corpus-count.sh 或 L2-EMPTY-ATTRIBUTION.md 的再生检查。",
      "why": "done 中的 AC-2 声明无法由 verify 证伪，验收条件与验证命令不一致，导致 AC-2 的实际验证被悬空。",
      "fix": "在 T02 verify 中加入 `bash corpus-count.sh --attribution` 并对输出做非空/零非枚举断言，或将该 AC-2 验收转移到 T09 并修正 T02 的 done 描述。"
    }
  ],
  "minor": [
    {
      "file": "TASK.md（T10 verify）",
      "issue": "T10 的 verify 用 grep 检查 ADR 文件中包含自身文件名 `026-untrusted-payload`，存在自指，但文件内容通常必然包含该字符串，可证伪性较弱。",
      "why": "该断言更多是确认文件存在且被关联，不足以验证 ADR 内容质量。",
      "fix": "改为检查 ADR 中关键结构标题或关键结论（如“不可信载荷不得伪造结构性边界”）而非文件名。"
    },
    {
      "file": "TASK.md（T08 verify）",
      "issue": "T08 verify 使用 `make check` 作为整体门禁，范围过宽，无法单独确认缺陷套件自身的通过情况。",
      "why": "若 make check 中其他检查失败，无法区分是缺陷套件问题还是其他任务回归，定位不精确。",
      "fix": "在 make check 之外增加单独运行 `npx bats test/test_l3_review_defects_2026_09.bats` 的统计输出。"
    },
    {
      "file": "TASK.md（波次表）",
      "issue": "波次表行序混乱，Wave 2 的 T07 出现在 Wave 3 的 T05 之后，虽不影响依赖，但可读性差。",
      "why": "波次表应与波次划分块顺序一致，便于人工核对。",
      "fix": "按 Wave 1→7 顺序重排表格行。"
    },
    {
      "file": "TASK.md（T12 read_files/write_files 路径）",
      "issue": "T12 read_files 写 `29-independent-review.sh`，而 write_files 写 `flow-kit-bundle/hooks/stop/29-independent-review.sh`，路径表达不一致，可能造成边界歧义。",
      "why": "同样的文件使用不同路径写法，执行时可能误读根目录版本或 bundle 版本。",
      "fix": "统一为完整相对路径 `flow-kit-bundle/hooks/stop/29-independent-review.sh`。"
    }
  ],
  "verdict": "fail",
  "summary": "任务图本身无环且大部分 verify 可复跑，但 AC-4/AC-5 完全缺失追溯，同时多处 write_files 重叠、verify 依赖未入 depends_on 且 T01 过滤不精确，故不通过。"
}
```

L3_artifact_hash: 426365ffe39a170c1946d8fef9ce9c49423ff218061bca2cb092a8ca58ea0c94

<!-- /L3-SECTION -->
