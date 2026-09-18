
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

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-19 06:41）

> 自动生成于 2026-09-19 06:41。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "TEST.md §1.3/§1.5",
      "issue": "5 处关键降级/守卫分支（B2-R16/R21、B6-R5、B9-R6、B10-R5）仅有“接线存在性”断言，且其变异自证被明确承认为自指恒真，无法证明这些分支在真实失败场景下能正确 fail-closed。",
      "why": "这些分支覆盖写入侧 fail-closed 与 PreToolUse 守卫等安全主战场；若仅证明接线存在，则分支一旦静默失效，测试仍会通过，安全防线可能被破坏而不被发现。",
      "fix": "为这 5 处分支构造可触发真实失败的 stub/夹具（如移除转义函数、模拟解码器不可用、制造库缺失），使断言能实际验证失败路径，并纳入自动回归。"
    },
    {
      "file": "TEST.md §1.1 (AC-2)",
      "issue": "AC-2 的覆盖证据是 corpus-count.sh 的一次运行输出（n=234 empty=8 base_empty=8 nonenum=0）及 L2-EMPTY-ATTRIBUTION.md 清单，未明确该断言是否已固化为 bats 用例或 CI 门禁。",
      "why": "若该检查仅靠手工运行或文档记录，则 AC-2 的“覆盖”不可自动重复，后续语料变化时可能漏跑，覆盖声明的可复现性不足。",
      "fix": "将 corpus-count.sh 的零非枚举、空值可归因、基线 ≤8 等不变量封装为 bats 测试或用例，并纳入 make check 门禁。"
    },
    {
      "file": "TEST.md §2.2",
      "issue": "PreToolUse 守卫性能测试通过 `for i in $(seq 1 200); do bash -c '...'` 启动 200 个子 shell 测量，与真实 hook 在已有 shell 中 source 后调用的方式不同，测量值包含 bash 进程启动开销。",
      "why": "子 shell 启动开销可能显著高于实际 hook 调用，导致 7.0 ms/call 结果不能准确代表真实 PreToolUse 守卫墙钟开销，<50ms 预算验证失真。",
      "fix": "改为在同一 shell 中 source 后循环调用 _gate_path_guard 200 次取平均，或使用 bats 的 run 多次计时，以接近真实调用路径。"
    }
  ],
  "minor": [
    {
      "file": "TEST.md §1.1",
      "issue": "AC-1 行结果列写“✅ 27(B1)+21(B2)”，与“覆盖用例”列的少量编号混用，易误读为 AC-1 拥有 48 个覆盖用例。",
      "why": "实际是 B1/B2 两组通过总数，不是 AC-1 行为断言数，影响矩阵可读性和覆盖口径。",
      "fix": "将结果列改为仅标注覆盖该 AC 的行为用例编号，或明确“该行对应缺陷组的通过总数”，避免误导。"
    },
    {
      "file": "TEST.md §1.1",
      "issue": "去重校验命令 `grep -oE '^@test \"[A-Za-z0-9]+-[A-Za-z0-9]+'` 只匹配 B#-R# 形式的测试名，无法覆盖含空格/冒号的测试名（如“AC2: 活语料零非枚举…”）。",
      "why": "去重校验不完整，无法保证所有测试名唯一，可能遗漏重名冲突。",
      "fix": "改为更通用的正则（如 `grep -oE '^@test .*'`）或直接提取完整测试名后 uniq -d。"
    },
    {
      "file": "TEST.md §3.4",
      "issue": "对抗用例命令未导出 UAT.md 中设置的 HOOK_BASE_DIR 环境变量。",
      "why": "若 gate-helpers.sh 内部依赖该变量，命令可能失败或行为不一致，降低可复现性。",
      "fix": "在 §3.4 命令前补充 `export HOOK_BASE_DIR=\"$PWD/flow-kit-bundle/hooks/stop\"`。"
    },
    {
      "file": "TEST.md §1.1 (AC-6/7)",
      "issue": "矩阵将 B3-R7/R8 计入 AC-6/7 的“✅ 7”，但同一节注释称它们不重复计入 AC 覆盖，口径不一致。",
      "why": "文档算术不严谨，易让读者误以为 AC-6/7 有 7 个行为断言，实际覆盖证据为 B3-R1..R5。",
      "fix": "将 AC-6/7 行结果改为“✅ 5（B3-R1..R5），另 B3-R7/R8 为截断告警断言”。"
    }
  ],
  "verdict": "pass",
  "summary": "测试矩阵已明确区分行为断言与接线断言，12 条 AC 均有行为覆盖，UAT 关键守卫命令已在工件内补全且可复现，未发现 mock 屏蔽真实失败；主要不足是 5 处安全分支仍缺真实失败触发测试及 AC-2 断言未完全自动化。"
}
```

L3_artifact_hash: 362b8f647e6effed3ff897a17d966b572c32ba52622efca49ec59b7c38118dd4

<!-- /L3-SECTION -->
