
---

## L3 盲审（deepseek-v4-flash-0731 外部模型 · 2026-09-18 19:49）

> 自动生成于 2026-09-18 19:49。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[{"file":"UAT.md","issue":"UAT-2 第⑤步被截断，缺少转义后放行的预期输出与判定，验收脚本不完整。","why":"UAT 是阶段7验收脚本，必须可复现；该步骤缺失导致无法验证「同一载荷经转义后应放行」的关键行为，验收不可执行。","fix":"补全第⑤步，提供完整命令、预期输出和判定条件。"},{"file":"TEST.md / §3.4 安全测试","issue":"对抗用例中 `_gate_is_unescaped_l3_paste \"$fake\"` 的 `$fake` 变量未定义，命令无法执行。","why":"该节声称「可粘贴复跑」，但实际运行会因变量未定义而失败，安全验证不可复现。","fix":"将 `$fake` 替换为实际构造的对抗载荷内容，或显式定义该变量。"}],"major":[{"file":"TEST.md / UAT-1","issue":"UAT-1 第5条将 `corpus-count.sh` 输出写死为 `224 98 129 129 8 0`，与自身「语料类断言一律现算，不写死快照」原则冲突。","why":"语料数量变化时 UAT 会失败，即使真正关心的非枚举字段仍为0；增加维护成本且削弱 UAT 可复现性。","fix":"只断言末位非枚举为0，或使用动态比较替代硬编码数字。"},{"file":"TEST.md / §1.5","issue":"测试断言可信度存在系统性风险：仅修复 B7-R4 的假绿，但未全面审计其他 `run` 调用，合并 stderr 仍可能造成假绿。","why":"文中已承认「其它用例若用 run，同样可能被报错文本喂绿」，但没有给出全面整改方案，覆盖率声明可能被虚高。","fix":"全面改用 `run --separate-stderr` 或在内层显式丢弃 stderr，并逐一审计所有断言。"},{"file":"TEST.md / §1.3","issue":"降级分支覆盖列了 7 项（B1-R27 / B2-R16 / B2-R21 / B5-R4+R5 / B6-R5 / B9-R6 / B10-R5）却写「6 处」。","why":"计数与列表不一致，影响覆盖率报告的可信度。","fix":"修正为 7 处，或调整列表使数量一致。"},{"file":"TEST.md / §5.1","issue":"日志断言引用了未在测试矩阵中出现的用例编号，如 B3-R7/R8、B2-R15/R20、B10-R2/R3、B5-R2/R4/R5、B6-R1 等。","why":"测试矩阵只列出 B1-R1…B10-R5 的部分编号，导致这些日志断言无法对应到具体测试用例，可观测性验证悬空。","fix":"在测试矩阵中补充这些用例，或统一用例编号体系。"},{"file":"TEST.md / §2.2","issue":"性能测试命令使用 `<change 目录>`、`<224KB 评审文件>` 等占位符，非实际路径。","why":"性能测试结果无法精确复现，削弱了性能预算验证的可信度。","fix":"提供可复现的实际路径或生成脚本，并附明版本上下文。"}],"minor":[{"file":"TEST.md / §1.1","issue":"AC-2 仅对应 1 个用例，未拆分为独立的子断言（如零非枚举、空值≤8、可归因）。","why":"若该用例的某个断言失败，定位问题不够精确。","fix":"拆分为多个小用例，或至少注明该用例包含哪些断言。"},{"file":"TEST.md / §1.6","issue":"backlog 提到 `_l3_verify_review_structure` 当前用合成夹具，缺少真实损坏工件回归。","why":"合成夹具可能无法覆盖真实损坏形态，存在覆盖盲区。","fix":"增加真实损坏工件的回归测试。"},{"file":"TEST.md / §4.4","issue":"配置键迁移只验证旧键可读 + DEPRECATED 提示，未验证新旧键同时存在时的优先级或写入后同步行为。","why":"可能遗留旧键与新键不一致的状态，影响向后兼容。","fix":"增加新旧键并存时的行为测试，明确优先级。"}],"verdict":"fail","summary":"测试矩阵大体覆盖 AC，但 UAT 不完整且安全对抗用例不可复现等关键问题导致验收无法通过。"}
```

L3_artifact_hash: 83873e334a9f4925ebc053736b4e84e80458d7841125aa942bb9dc22cb9cce2a

<!-- /L3-SECTION -->

---

## L2 盲审（阶段 5 · 测试 · 全新上下文子 agent · 2026-09-18）

```json
{
 "critical": [
  {
   "file": ".specs/l3-review-defects-2026-09/TEST.md:28,36,58,227",
   "issue": "AC-2 标 ✅ 实为红。实测 `npx bats test/test_l3_review_defects_2026_09.bats --filter AC2` → `not ok`（用例 line 85 `unattributed=[]`），现场 `n=228 empty=11 base_empty=8 nonenum=0 unattributed=[l3-review-defects-2026-09/INDEPENDENT-REVIEW-7.md]`；连带全量 `ok=923 not_ok=1`、`bash verify-claims.sh` → `12 ✅ / 1 ❌（make check 未通过）`，而 §5.4 写「make check 五门实测全绿」，UAT.md:18,26 期望 not_ok=0 与 13✅/0❌。",
   "why": "AC-2（REQUIREMENT.md:82）把「每份空值都在归因清单里」定为活语料不变量，但 L2-EMPTY-ATTRIBUTION.md 是 19:55:51 的静态快照：19:57 由 L3 写侧新建的 IR-7 未入列，且清单仍列已不再为空的 IR-3。写侧每新增一份审查件门禁就自红 → AC-2 未满足，回归与门禁均非全绿。",
   "fix": "把清单再生接进写侧或用例内（AC2 用例先跑 `bash corpus-count.sh --attribution` 再断言；或 _l3_parse_result 落盘后触发），重跑后回填 TEST.md 的 ✅ 与现算数字，并同步 UAT.md 记录表。"
  }
 ],
 "major": [
  {
   "file": ".specs/l3-review-defects-2026-09/TEST.md:43-44,79,193,236",
   "issue": "用例计数不符：缺陷套件写 86，实测 98（`grep -c '^@test'` = 98，bats 编号至 98）；全量写「912 ok / 0 not ok」，实测 924（923 ok / 1 not ok）。差值同为 12，且被 REVIEW.md:125、UAT.md:16,120、IR-7 逐级引用为「最终实测值」。",
   "why": "阶段 5 工件的核心证据就是计数；§回归保护(l.246) 自称「一律现算、不写死快照」，事实相反。",
   "fix": "改为现算命令+实测值（`npx bats test/ --formatter tap | awk` 计数），或只断言 not_ok=0 不写例数。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TEST.md:28,58,196",
   "issue": "语料数字互斥：TEST.md `227 101 132 132 11 0`、UAT.md:30 `224 98 129 129 8 0`、ADR/DESIGN `223`；实测 `bash corpus-count.sh` → `228 102 133 133 11 0`（verify-claims 步骤 7 独立复算同值）。",
   "why": "同一活语料在三个工件给出三个「事实」，AC-2 的数值口径无法判定。",
   "fix": "只保留「非枚举必须为 0」的口径，数量一律引用现算命令输出。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TEST.md:194",
   "issue": "「231 处 awk 全部通过 mawk/gawk 实测路径」不可复算：实测 hooks 源 20 处、flow-kit-bundle 59 行、全仓（除 .git）386 行，无口径得 231；亦未给 mawk/gawk 双跑的可粘贴命令。",
   "why": "兼容性轮的关键证据不可验证，等于无证据。",
   "fix": "给出复算命令与真实计数，或删数字只留「仅用 POSIX 子集」的静态判据。"
  },
  {
   "file": "test/test_l3_review_defects_2026_09.bats:1009,1113,1210,1229,1282",
   "issue": "5 条「变异自证」是自指恒真：B2-R16/B2-R21/B6-R5/B9-R6/B10-R5 用 `grep -v` 删掉 X 后，再断言副本里不含 X；变异体从不跑过被测 harness，断言与 harness 行为无关。",
   "why": "§1.5 据此宣称「恒真断言」维度已修；真正做行为变异的只有 B1-R27 与 B5-R4，接线断言的检测力仍未证明。",
   "fix": "让变异体真正执行（仿 B1-R27 的 stub 树：注入变异源→跑 29 号模块→断言应红），或删去「自证有效/必须能抓到」表述。"
  }
 ],
 "minor": [
  {
   "file": ".specs/l3-review-defects-2026-09/TEST.md:57",
   "issue": "「降级分支覆盖 6 处」实际列 7 项（B5-R4+R5 记为一项）。",
   "why": "计数与列举不符，属同类「数字不可复算」残留。",
   "fix": "改为 7 处，或按 R4/R5 拆分写 8。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TEST.md:79,113-116,130",
   "issue": "耗时/体积快照失真：缺陷套件记「≈40 秒」实测 20.3s；「224KB 评审文件」现最大件 INDEPENDENT-REVIEW-2.md=231522B(226KiB)，_fk_l2_scope 实测 0.01s（记 0.02s）。",
   "why": "证据数字随时间漂移，削弱可复算性。",
   "fix": "改为量级表述（<1s / 0.0x s）并附复算命令。"
  },
  {
   "file": ".specs/l3-review-defects-2026-09/TEST.md:138,227",
   "issue": "§3.1 依赖漏洞标 N/A（「无包管理器依赖」），但回归门禁由 `npx bats`（联网获取、未固定版本）承担，全部计数都依赖该版本。",
   "why": "N/A 掩盖了唯一外部工具链的版本风险。",
   "fix": "记录 bats 版本（本机 1.13.0）或在 CI/devDependencies 固定。"
  }
 ],
 "verdict": "fail",
 "summary": "AC-2 的活语料不变量用例现场为红（归因清单缺 IR-7）并连带全量与 verify-claims 门禁非全绿，且 TEST.md 的 86/912/227/231 等数字与实测 98/924/228/20 处均不符。"
}
```

**Verdict**: fail

（依据：AC-2 的活语料不变量用例现场为红（归因清单缺 IR-7）并连带全量与 verify-claims 门禁非全绿，且 TEST.md 的 86/912/227/231 等数字与实测 98/924/228/20 处均不符。）

---

## 主 agent 响应（阶段 5 L2 盲审）

- **critical①（AC-2 现场为红：归因清单缺 IR-7；全量与 verify-claims 连带非全绿）** — Fixed in: AC-2 判据改为「**现场再生**清单 → 行数 == 活语料空值数」+「零非枚举」+「基线 ≤8」，不再比对提交进仓库的快照（`corpus-count.sh --attribution [out]` 支持再生到临时文件，测试不改工作区）；顺带修两个真 bug：字段提取贪婪匹配命中 `base_empty=`、rel 路径归一化处理不了绝对路径。实测：`AC2` ok、`DEFECTS 98 ok / 0 not ok`。
- **major①（用例计数不符 86/912 → 实测 98/924）** — Fixed in: TEST.md 全量改为**现算命令 + 实测值**，并注明"只断言 not_ok=0"。
- **major②（语料数字三处互斥 227/224/223）** — Fixed in: TEST.md 只保留现算输出 `228 102 133 133 11 0` 与「末位必须为 0」的口径；UAT.md 同类数字同步。
- **major③（「231 处 awk」不可复算）** — Fixed in: 改为可复算的静态判据（`grep -c awk …` → 13）并标注原文不可复算。
- **major④（5 条「变异自证」是自指恒真）** — Tech-debt: 属实 —— 它们只证明**静态接线断言非恒真**，未让变异体跑过 harness；已把 TEST.md §1.3 的措辞改为区分「行为变异 2 处（B1-R27/B5-R4）」与「接线非恒真 5 处」，并登记 **M41**（真行为变异需 B1-R27 式 stub 树）。
- **minor①（6 处 vs 实列 7 项）** — Fixed in: 改为 7 处并按性质分类。
- **minor②（耗时/体积快照失真）** — Fixed in: 改为量级表述 + 现算件大小（231522B）。
- **minor③（bats 未固定版本）** — Tech-debt: 登记 **M42**（记录 1.13.0 / 建议 CI 固定）。
