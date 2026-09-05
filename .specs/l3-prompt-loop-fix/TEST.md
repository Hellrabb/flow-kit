# TEST: L3 前轮反馈注入 + 反馈优先截断 + 归档布局解析修复

- **Change ID**: l3-prompt-loop-fix
- **关联**: `@.specs/l3-prompt-loop-fix/REQUIREMENT.md`、`@flow-kit/reference/test-pyramid.md`
- **项目类型**: CLI / Shell hooks 库（Bash + bats）

---

## 0. 本次测试范围声明（5 轮金字塔）

| 轮次 | 状态 | 范围 | 跳过理由 |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 AC-1~AC-7（bats 行为级） | — |
| 第 2 轮 · 性能 | ⚠️ 部分 | 字节预算类量化断言（配额 600/200/800B、截断 20000B、JSON 契约完整） | Shell hook 无 load/bundle 概念；性能面 = prompt 字节预算，已用量化断言覆盖 |
| 第 3 轮 · 安全 | ⚠️ 部分 | shellcheck（make check 内置）+ 改动面秘钥扫描 | 内部 CI hook，无网络面新增；本次改动不触凭证链（fk_resolve_api_credentials 禁动清单） |
| 第 4 轮 · 兼容 | ⚠️ 部分 | UTF-8 多字节边界（2/3/4 字节）+ LC_ALL=C 字节语义 + 跨副本部署一致性（md5/cmp） | 无浏览器/schema/迁移面 |
| 第 5 轮 · 可观测 | ❌ 跳过 | — | Stop hook 子进程无运行时指标面；hook 自身日志走 HOOK_TMP_DIR 既有机制，本次未改动 |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵（AC → 用例）

| AC | 类型 | 用例文件 / UAT | 状态 |
|---|---|---|---|
| AC-1 反馈段先于工件 + 满载存活 + 总输出≤cap | unit+integration | `test/test_l3_pipeline_fix.bats` T05「AC-1 assembly ordering」（字节位比较 + disclaimer 存活）+ T04「AC-1 ①总输出≤20000 字节 + JSON 契约永不被切」+ 既有 AC-1 段序锚 | ✅ |
| AC-2 checklist 对齐归档约定 | unit | T04「D6 checklist 措辞」固定完整行文案锚定（T0x-SUMMARY + CHANGELOG 标项目级） | ✅ |
| AC-3 archive 布局注入成功 | unit | T04「D5 双位点」（CHANGELOG + `=== LESSONS.md ===` 双断言） | ✅ |
| AC-4 单行摘要 + 配额 (+k more) | unit+integration | T02 提取器 7 用例 + T03 配额折叠 + T05「AC-4 e2e mixed/overflow」（组装层排序 + 折叠 + 字节位） | ✅ |
| AC-5 无响应段→标注未响应 + 摘要仍注入 | unit | T03「AC-5 no-response 标注注入」+ T05 溢出 e2e（未响应标注在场） | ✅ |
| AC-6 四副本 md5 一致 + 全局 cmp | integration | T06「AC-6 four copies share one md5」+「global ~/.claude cmp-identical when present」 | ✅ |
| AC-7 缺失/源空→静默 | unit+integration | T02「empty/verdict-only/missing yield nothing」+ T03 AC-7 象限 + T05「AC-7 e2e assembly」 | ✅ |

### 1.2 UAT 脚本

无需 manual UAT——全部 AC 可在 bats 内自动化（fixture 驱动）。全局部署 `~/.claude` 的 cmp gate 为存在性门控断言（缺失环境平凡通过，本环境实测在场且同值）。

### 1.3 覆盖率

```text
$ npx bats test/ --formatter tap | grep -cE '^ok'          # 含行尾 # skip 的 ok 行
801
$ npx bats test/ --formatter tap | grep -cE '^not ok'      # fail
0
$ npx bats test/ --formatter tap | grep -cE '# skip '      # skip（bats TAP：ok N ... # skip，行尾非行首）
1
```

- bats 无行覆盖工具；按 R5.5「AC 覆盖优先于行覆盖」：AC-1~AC-7 全覆盖（矩阵见 1.1）
- 本 change 新增/改写用例：test_l3_pipeline_fix.bats 8→39（+31）
- 全量基线：801 total = 800 pass + 1 skip / 0 fail
- **既有 skip 披露**：`test/test_lessons_cleanup.bats:137`（`skip "AC-4 需要全量覆盖环境…"`），属 `ce482c4 test-failures-fixup-2026-08` 引入的既有 skip，与本 change 无关（本 change 未触碰该文件）。AC-6「无 fail/skip」按「0 fail + 0 新增 skip」口径达成——本 change 新增的 39 个用例 0 fail / 0 skip。

### 1.4 边界 / 错误路径用例

- 空 / null：空 fixture、空文件 `[ -s ]` 守卫、空 stdin stream（T01/T02/T03/T05 各有）
- 极大 / 极小：30 条发现溢出折叠、197B+… 截断、20000B 总预算满载（T03/T04/T05）
- Unicode / 特殊字符：UTF-8 2/3/4 字节边界截断（T01×7）、`|` 字段净化、CJK 混排字节计数（T02）
- 错误路径：审查文件缺失、JSON 围栏畸形（jq 容错降级）、 verdict-only 文件、目录缺失（T02/T03/T05）

### 1.5 测试质量自检（6 维测试衰退风险）

- [x] **T1 测试晦涩**：用例名含场景（"AC-4 e2e overflow - (+k more) fold at assembly level"）；grep -bo 字节位比较附注释意图
- [x] **T2 测试脆弱**：断言外部行为（输出内容/字节位/退出码），未锚定内部函数调用序；D5 用 if/else 而非嵌套 case 正是保 sed 提取契约（受 T4 教训）
- [x] **T3 测试重复**：unit（T02/T03）与 e2e（T05）分层不重复——e2e 验组装层顺序/存活，unit 验提取/象限
- [x] **T4 Mock 滥用**：零 mock——全部真实 fixture 文件 + 真实函数调用；唯一"组装复刻"（复刻 l3-review.sh:81-104 拼接）在 TASK.md R1 方案 A 显式裁决
- [x] **T5 覆盖率幻觉**：无空断言；每用例 ≥1 实质断言（内容/计数/字节位/cmp）
- [x] **T6 架构错配**：提取器/注入器用 unit；build_prompt 组装层用 integration；跨副本一致性用部署级断言——层级匹配

命中 0 项 → 无测试质量技术债。

---

## 第 2 轮 · 性能（部分：字节预算量化）

| 预算项（REQUIREMENT 非功能） | 断言 | 结果 |
|---|---|---|
| 反馈段 ≤800B（摘要 600 + 响应 200） | T03 配额用例（发现行+折叠行 ≤640B）+ T05fix 补充断言（响应要点内容 ≤200B；发现行内容+响应内容合计 ≤800B） | ✅ |
| 单行摘要 ≤200B（197+…） | T02「line length cap」 | ✅ |
| 总输出 ≤ max_chars 且 JSON 契约完整 | T04「AC-1 ①」双断言 | ✅ |
| jq 模板指令前置（截断不切契约） | T04 段序断言 | ✅ |
| 无 shell 循环内子进程热路径退化 | 沿用既有 od 逐字节实现（T01 已锚定），本次无新增热路径 | ✅ |

与上版基线对比：新增功能无既有预算退步面（旧实现无任何截断安全/反馈注入——本 change 即修复该缺失）。

## 第 3 轮 · 安全（部分）

- shellcheck：make check 内置，0 error（commit 5a2e542 实测）
- 秘密扫描：本次 5 个 commit 改动面 grep 无 token/secret 字面量（jq --arg 转义路径，REQUIREMENT 非功能项）✅
- 凭证链禁动：fk_resolve_api_credentials / l3-review.sh 未触碰（diff 边界验证于各任务 SUMMARY）✅

## 第 4 轮 · 兼容（部分）

- UTF-8 边界：2 字节（194-223）/3 字节（224-239）/4 字节（240-244）截断回退 7 用例 ✅
- LC_ALL=C 字节语义：提取器/截断器全路径显式设置 ✅
- 部署一致性：仓库内四副本 md5 唯一 + ~/.claude cmp gate ✅
- 无 schema/迁移/API 版本面 → 其余项不适用

## 第 5 轮 · 可观测：❌ 跳过（理由见范围声明）

---

## 步骤 N · 回归测试登记

| 用例组 | 文件 | 数量 | 登记 |
|---|---|---|---|
| T01 UTF-8 helper | test/test_l3_pipeline_fix.bats | 7 | 本 change 新增 |
| T02 提取器 | 同上 | 7 | 本 change 新增 |
| T03 注入矩阵 | 同上 | 11 | 新增 6 + 改写既有 5（假声明修复） |
| T04 build_prompt 重排 | 同上 | 5 | 新增（含改写既有段序锚） |
| T05 端到端固化 | 同上 | 4 | 本 change 新增 |
| T06 副本一致性 | 同上 | 2 | 本 change 新增 |

双源镜像：test/ ↔ flow-kit-bundle/test/（bats + 7 fixtures），`make check-test-sync` 收口绿。
