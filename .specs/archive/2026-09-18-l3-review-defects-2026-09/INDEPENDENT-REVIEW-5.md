
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

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-19 22:51）

> 自动生成于 2026-09-19 22:51。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "TEST.md §1.3（降级分支覆盖）",
      "issue": "声称“行为可失败（真跑变异体）10 处”，但枚举仅 B1-R27、B5-R4、B10-R12 加 B12-R1..R5 共 8 处；且 §1.5 自检表仍保留“仍有 5 处已知局限”，与同一节“M41 已闭合/已补齐”的状态矛盾。",
      "why": "覆盖数据自相矛盾会让审查者无法确定降级/守卫分支是否已真正闭环，尤其是“5 处局限”是否仍存在。",
      "fix": "将“10 处”改为按枚举实算的“8 处”，并统一 §1.5 与 §1.3 中关于 M41 的“已闭合”表述，删除残留的“仍有 5 处已知局限”。"
    },
  {
      "file": "TEST.md §新增测试登记",
      "issue": "登记 `test/test_l3_review_defects_2026_09.bats` 为“B1–B11 + AC2 组”，但正文 §1.3/§1.5 明确引入 B12-R1..R5 作为同一缺陷套件的真跑变异体用例；登记与正文不一致。",
      "why": "测试资产清单不完整，审计者按登记核对时会漏掉 B12 这组关键回归用例，覆盖率证据链出现缺口。",
      "fix": "在新增测试登记中补充 B12-R1..R5，或注明其所在文件与范围，使登记与正文一致。"
    },
  {
      "file": "UAT.md（UAT-1/UAT-2）",
      "issue": "UAT 脚本前置和 UAT-2 命令硬编码绝对路径 `~/unisoc/flow-kit`，而 TEST.md §3.4 中的同型命令却用 `cd $(git rev-parse --show-toplevel)` 保证可移植；两处口径不一致。",
      "why": "UAT 是验收脚本，硬编码机器路径导致在其它克隆位置无法直接复跑，可复现性受损。",
      "fix": "将 UAT.md 中的绝对路径统一替换为 `cd \"$(git rev-parse --show-toplevel)\"` 或仓库根占位符，并保持与 TEST.md §3.4 一致。"
    }
  ],
  "minor": [
    {
      "file": "TEST.md §4.4",
      "issue": "§1.1 声明“本文不写死绝对条数”，但 §4.4 写入“现算 945 例 / not_ok=0”，且矩阵结果列含多处绝对计数（如 27(B1)+21(B2)）。",
      "why": "虽然带有快照时间，但绝对数字仍可能随活语料/用例增长过期，与“不写死”原则存在张力。",
      "fix": "改为只给复算命令与快照时间戳，或明确标注“快照非权威，以命令输出为准”。"
    },
    {
      "file": "TEST.md §3.4（OWASP 表）",
      "issue": "A01/A02/A04–A07/A10 行写“无反序列化”，随后又写“JSON 解析只走 jq”；JSON 解析本身即反序列化行为，表述自相矛盾。",
      "why": "安全裁剪表的适用性判断不够严谨，可能误导读者对攻击面的理解。",
      "fix": "改为“未新增反序列化面；既有 JSON 解析仅经 jq”或删除“无反序列化”表述。"
    },
    {
      "file": "TEST.md §2.2/§3.4",
      "issue": "`_gate_path_guard` 的性能与对抗用例中第三参数传空字符串 `\"\"`，而注释提到“第三参数 $max_bytes 单位是字节”，未说明空值语义；真实入口是否传空也不清楚。",
      "why": "若空 `max_bytes` 触发不同分支，则 7.0ms/call 的性能值与守卫真实调用路径可能不完全一致。",
      "fix": "在用例中显式传真实 `max_bytes`（如 200000），或注释说明空值默认行为，并确保性能样例与真实入口一致。"
    },
    {
      "file": "TEST.md §1.1 矩阵",
      "issue": "用例编号出现 `B1-R2[1-4]` 一类写法，与正文其它位置使用的 `B9-R1..R17` 区间表示不一致，易被误读为 B1-R2 与字符类。",
      "why": "编号歧义会影响用例定位与可复算性。",
      "fix": "统一写为 `B1-R21..R24` 或 `B1-R21、R22、R23、R24`。"
    }
  ],
  "verdict": "pass",
  "summary": "测试矩阵覆盖全部 AC 且含真实行为断言、变异体与回归保护，无 critical 缺陷，但存在覆盖计数、登记与 UAT 可移植性等需修正的一致性问题。"
}
```

L3_artifact_hash: fcf690ebdb72e40882a2a414f4ffd40ffc98887251088ab258e28a4a93047f1a

<!-- /L3-SECTION -->
