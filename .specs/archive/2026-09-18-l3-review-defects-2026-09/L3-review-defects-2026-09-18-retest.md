# L3 审查链缺陷报告 · 重新实测与过滤结论（2026-09-18）

> **对象**：`L3-review-defects-2026-09-17.md`（chisel-skill 开发中在 `chisel_env` 的 change
> `verify-ac-env-fix` 踩到，报告方核对于 commit `19b3463` / `develop`）。
> **本次动作**：逐条重跑原报告的自包含复现 + 在**当前**工作区（同 commit，文件未被改动过）上
> 复算，判定每条是否仍然成立，然后修复成立项。
> **复测时间**：2026-09-18。**复测环境**：本仓库 `~/unisoc/flow-kit`，
> DSH 运行时 `~/.dsh/profiles/web/node_modules/dsh-flow-kit/`，用户级安装 `~/.claude/hooks/`。

## 0 · 复测结论一览

| ID | 原报告严重度 | 原报告验证状态 | **本次复测判定** | 复现证据 | 修复 |
|----|----|----|----|----|----|
| B1 | 🔴 高 | 已实测复现 | **✅ 成立**（且比原报告更严重） | 两个复现式全部复现；另在 222 份归档工件上量化出 18 处提取错误 | 已修 |
| B2 | 🟡 中 | 代码可推演（未触发） | **✅ 成立**（本次**实际触发**，升级为已复现） | 构造含行首 `## ` 的载荷连写 3 轮 → 旧段尾残留并累积 | 已修 |
| B3 | 🟡 中 | 已实测 | **✅ 成立** | cap=60000 → 实测 60000 **字节** = 20000 汉字；README 原文写"字符" | 已修 |
| B4-a | 🔴 高 | 已实测复现 | **✅ 成立** | 41 条目目录 → 清单只列 27 条，14 个文件名不可见 | 已修 |
| B4-b | 🔴 高 | 已实测复现 | **✅ 成立**（根因已确证） | 全 bundle grep：`INTEGRATION.md` **仅**出现在 `l3-prompt.sh:349` 一处 | 已修 |
| B5 | 🔴 高 | 已实测 | **✅ 成立** | `~/.claude/hooks` 3 个功能文件停在 2026-09-03，P0-1/P0-2 标记 grep 计数 0/0 | 已修 |
| — | — | — | **➕ 新发现（原报告未列）** | 防漂移断言只覆盖 `l3-prompt.sh` 一个文件 → 副本真漂移时测试仍为绿 | 已修 |

**过滤结果：0 条失效、0 条误报、5 条全部成立、1 条新增。** 原报告在事实层面完全准确；
本次复测主要做了三件原报告没做的事：把 B2 从"推演"变成"实测"、给 B1 补了语料级量化、
把 B5 的"建议加机器检查"落成实际断言。

## 0.1 · 改动清单

| 文件 | 改动 |
|---|---|
| `flow-kit-bundle/hooks/stop/lib/l2-detect.sh` | §B1 `fk_extract_l2_verdict` 重写 |
| `flow-kit-bundle/hooks/stop/lib/l3-section.sh` | **新增**：§B2 的 L3 段标记 + `_l3_strip_sections` |
| `flow-kit-bundle/hooks/stop/lib/l3-api.sh` | §B2 调用 `_l3_strip_sections` + 落标记（249/250 行门槛内） |
| `flow-kit-bundle/hooks/stop/lib/l3-done.sh` | §B2 timeout/bypass 两个写入方落标记 |
| `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` | §B2 围栏感知段切换 + §B4 全量清单 / 可选产物 |
| `flow-kit-bundle/hooks/stop/lib/l3-review.sh` | §B3 解析链加 `_BYTES` + source `l3-section.sh` |
| `flow-kit-bundle/hooks/stop/29-independent-review.sh` | §B3 配置改名 + 兼容旧键 + 导出 `_BYTES` |
| `flow-kit-bundle/hooks/config/stop-hook.json` | §B3 `max_artifact_bytes` + 单位说明 |
| `README.md` / `dsh-flow-kit/README.md` / `package-flow-kit.sh` / `.claude/l3.env.example` | §B3 文档：单位=字节 + CJK ÷3 |
| `.flow-kit/stop-hook.json` | §B3 本仓库项目级配置迁移到新键 |
| `sync-hooks.sh` | **新增**：§B5 唯一源 → 6 副本镜像（含 `--check`） |
| `Makefile` | §B5 `hooks-sync` / `check-hooks-sync`（后者入门禁） |
| `test/test_l3_review_defects_2026_09.bats` | **新增**：28 例回归（B1×8 / B2×6 / B3×6 / B4×4 / B5×4） |
| `test/test_l3_lifecycle_wiring.bats` | §B3 断言更名 + 强化模板单位断言 |
| `test/test_l3_review.bats` | §B2 dedup 用例改为调用生产函数（原为测试内自复制逻辑） |
| `.specs/CHANGELOG.md` | 登记本 change |

`test/` ↔ `flow-kit-bundle/test/` 双源已同步；6 个 hooks 副本已同步（漂移 0）。

---

## 1 · B1 · `fk_extract_l2_verdict` 抽错 verdict —— ✅ 成立

### 复现（原报告 §B1 的两条）

```
① 自包含复现      → 实测输出 `PASS`（期望 `fail`）        ❌ 复现
② 真实形态工件     → 实测输出 `pass`（期望 `fail`，L2 段写的是 fail）  ❌ 复现
```

代码未变：`flow-kit-bundle/hooks/stop/lib/l2-detect.sh:41` 仍是
`grep -iE 'verdict[^a-z]*[:：]' | tail -1 | grep -ioE 'pass|fail' | tail -1`。

### 本次补充：语料级量化（原报告只有 3 个样本）

在仓库自带的 **222 份** `INDEPENDENT-REVIEW-*.md` 上，把"修复前 vs 修复后"的提取结果
同 `.done` 里记录的值三方对照：

| 指标 | 数值 |
|---|---|
| 与修复前结果不一致的文件 | 57 |
| 其中 **修复后与 `.done` 一致、修复前不一致**（= 修对了） | 18 |
| 其中修复前一致、修复后不一致（= 需逐条复核） | 12 |
| 修复后提取不到的（覆盖率回归） | **0** |

逐条复核那 12 条：全部是**原报告说的同一类错误**——`.done` 记录的值本身就来自错误提取。
两类成因：
1. **取到 L3 的 JSON**：`flow-active-integrity/INDEPENDENT-REVIEW-1.md` 的 L2 段写
   `**Verdict**: fail`（:177），L3 段 JSON 写 `"verdict": "pass"`（:233）；
   修复前返回 `pass`，`.done` 也记了 `pass` —— 与事实相反。
2. **取到主 agent 的复述**：`2026-07-10-sweep-fix-2026-07-10/INDEPENDENT-REVIEW-2.md`
   的 L2 审查员结论是 `**Verdict**: fail`（:112），主 agent 在 `## 主 agent 响应` 段里
   追写"7/7 已处置…**有效 Verdict: pass**"（:130）；修复前取到后者的 `pass`。
   而 L2 契约（`flow-kit/prompts/independent/L2-blind-review.md:142`）明确
   "主 agent **无权修改你的原文判断**"——L2 结论应取审查员那一行。

### 修复设计（与原报告建议的差异，重要）

原报告建议的锚点 `^\**[[:space:]]*Verdict[[:space:]]*\**[:：]` **会漏掉真实存在的写法**。
语料实测的 verdict 行形态分布：

| 形态 | 出现次数 | 原建议锚点能否命中 |
|---|---|---|
| `**Verdict**: pass` | 170 | ✅ |
| `- **Verdict**: pass`（列表项） | 32 | ❌ |
| `**verdict**: pass` | 9 | ✅ |
| `**Verdict**: **fail**` | 13 | ✅ |
| `## Verdict: pass` / `## Verdict` + 次行 | 10 | ⚠️ 部分 |
| `  "verdict": "fail",`（L3 JSON，**必须排除**） | 69 | ✅（锚定天然排除） |

因此实际实现放宽为：
- **锚定**：允许 列表符（`- * +`）/ 标题符（`#*`）/ 粗体（`**`）任意组合前缀；
  额外排除以引号开头的行 → 与 L3 段 JSON 彻底隔离。
- **取最后一次**：一个工件可含多轮 `## L2 盲审（重审）`，最后一次 = 最新结论；
  这也保证**确定性**（同文件任意时点结果一致，`.done` 可复现）。
- **大小写归一**：`tr 'A-Z' 'a-z'`，满足调用方 `^(pass|fail|skipped)$` 值域。
- **兜底层**：标题形（`## Verdict` / `### 重审 Verdict`）→ 旧式非锚定搜索。

> ⚠️ 复测中发现一个**原报告未提及的坑**：语料里有 **Gen-1 布局**（L3 段在前、L2 段在后，
> 早期 append 顺序所致）。任何"限定在 L3 标题之前"的写法（含按 `## L2` 段截取）都会在这批
> 文件上退化为**空值**——实测 6~21 份不等。最终实现不做段截取，改用"锚定 + 排除 JSON"，
> 对两种布局同时成立。

原报告要求保留的 `l3-review.sh:61` 值域校验**未动**（它确实是最后一道闸）。

---

## 2 · B2 · L3 段重写按标题截断、无结束标记 —— ✅ 成立（本次已实际触发）

原报告标注"代码可推演，本次未实际触发"。本次构造了触发条件并实测：

```
轮 2 载荷含一行 `## 附录：模型自由发挥的 markdown 标题`
轮 3 正常写入
→ 实测结果：L3 标题 1 个，但残留 `## 附录`、`more text`、半个 ``` 围栏、上一轮
   L3_artifact_hash、以及多出的 `---` 分隔条；围栏计数 2→3（不再配平）。
```

即：**旧段尾残留且逐轮累积**，工件被静默污染（正是原报告预言的"残留片段"，
"吞掉后续内容"未复现）。

同时发现一个**连带的同源缺陷**（原报告未单列）：`l3-prompt.sh` 的
`_l3_extract_prior_findings()` 用 `case "$line" in '## '*) section="other"` 切段，
**不感知围栏**。载荷里的行首 `## ` 会把 L3 的 JSON 缓冲腰斩 → "前轮发现摘要"丢失
（L3 每轮看到的上下文变空）。已一并按同源修复。

### 修复

- 写入侧三处（`_l3_parse_result` / `l3_write_timeout_done` / `l3_write_bypass_done`）
  统一在段尾落 `<!-- /L3-SECTION -->`。
- 删除侧新增 `_l3_strip_sections()`：**先找标记**，找到就精确切到标记；
  只有撞到"下一段 L3 / 回到 L2 段"才判定本段无标记，**回落到原标题法**（历史工件兼容）。
- 顺带回收紧邻上方的空行 + 单个 `---`，避免逐轮累积空分隔条（实测 5 轮后 `---` 仍为 1、
  空行数恒定 7、工件与单轮结果同形）。
- `_l3_extract_prior_findings()` 的段切换改为**仅在非围栏行**判定。
- 标记字面量与 `_l3_strip_sections` 独立成 `hooks/stop/lib/l3-section.sh`：
  `l3-api.sh` 有 ≤250 行的结构门槛（`test_lib_split_metrics.bats` AC-B1/B3），
  且改动前它就已是 249/250。契约集中一处 → 写入方三处引用同一变量/函数，不再各带一份字面量。

前三个写入方共用同一字面量，并有跨文件一致性断言（防"改一处漏两处"）。

---

## 3 · B3 · `max_artifact_chars`：名字是"字符"、实现是"字节" —— ✅ 成立

### 复现

```
输入：90000 字节 / 30000 汉字的 md
_l3_utf8_head_bytes 60000 →
  实测输出 60000 字节 = 20000 汉字      ❌ 与名字/文档不符
```

文档侧确证：`README.md:123` 原文"否则 L3 只看前 20000 **字符**"、
`.claude/l3.env.example` 原文"只看得到前 20000 **字符**"、
`dsh-flow-kit/README.md:79` 同。**名实不符成立**。

### 修复（取原报告 3 选项中的第 1 项：改名 + 保留旧名兼容）

| 层 | 规范名（新） | 兼容旧名 |
|---|---|---|
| 项目配置 | `independent_review.max_artifact_bytes` | `max_artifact_chars`（仍按**字节**解释，行为不变，打印 DEPRECATED 提示） |
| 环境变量 | `FLOW_KIT_L3_MAX_ARTIFACT_BYTES` | `FLOW_KIT_L3_MAX_ARTIFACT_CHARS` → `L3_MAX_ARTIFACT_CHARS` |

解析链：`_BYTES` > `_CHARS` > 历史直调 > 20000。文档（README ×2、配置模板、l3.env 模板）
统一写明**单位 = 字节**并给出 **CJK ÷3** 换算，配置模板示例值从误导性的
`max_artifact_chars: 60000` 改为 `max_artifact_bytes: 180000 ≈ 6 万汉字`。

> 选择"改名"而不是"改成真按字符截断"的理由：截断的真实目的是**控制发给模型的字节/Token 量**；
> 改成按字符裁会让中文工件的实际请求体膨胀最多 3 倍，重新引入超限风险。改名让名字服从实现，
> 并用提示 + 文档消除"按字符估算"的误读。

---

## 4 · B4 · 阶段 7 产物清单截断 + 硬编码 `INTEGRATION.md` —— ✅ 成立

### B4-a 清单截断（复现）

41 个顶层条目的 change 目录，`ls -la | head -30` 只产出 27 个文件名，**14 个不可见**，
其中包含 `TASK.md` / `TEST.md` / `REQUIREMENT.md` / `REVIEW.md` / `T07-SUMMARY.md` / `UAT.md`
—— 与原报告"33 条目时漏 T07-SUMMARY.md / TASK.md / TEST.md / UAT.md"一致（条目更多时漏更多）。
L3 据此报"产物缺失"并 verdict=fail：**对提示词为真、对仓库为假**。

### B4-b `INTEGRATION.md` 硬编码（根因确证）

全 bundle 检索：`INTEGRATION.md` **只在** `l3-prompt.sh:349` 出现一次。
`skills/flow-integration/SKILL.md` 的产物契约是 `UAT.md` + `CHANGELOG.md` 更新，
**不产 `INTEGRATION.md`**。因此提示词里必然出现 `=== INTEGRATION.md === MISSING`
—— 这是提示词自己制造的假 major。原报告的判断准确。

### 修复

- 清单改为**全量**（去掉 `head -30`）。整体仍受 `max_artifact_bytes` 约束，溢出只切正文尾部。
- 必备清单缩回真实契约产物：`CHANGE/REQUIREMENT/DESIGN/TASK/TEST/REVIEW`。
- `INTEGRATION.md` / `UAT.md` / `MINOR-DEFERRED.md` 改为**存在才列**（不再输出 MISSING）。
- `checklist` 补一句"非必备产物未出现不构成缺陷"，避免模型改判到另一头。
- 原报告建议的"其它阶段分支是否有等价固定截断"已核查：**没有**。
  `l3-prompt.sh:225` 的 `head -8`（前轮发现配额）与 `:273` 的 `head -3`（ADR 取样）
  是**刻意配额**且已有专门的配额断言测试，不是漏检，故不动。

修复后实测：41 条目 → 41 个名字全部出现、`INTEGRATION.md === MISSING` 计数 0、
存在的 `UAT.md` 正常列出、缺失的 `MINOR-DEFERRED.md` 不列、删掉 `TASK.md` 后仍严格报 MISSING。

---

## 5 · B5 · 安装树不同步 —— ✅ 成立

### 复现

| 检查点 | `flow-kit-bundle/hooks` | `~/.claude/hooks` |
|---|---|---|
| `FLOW_KIT_L3_MAX_ARTIFACT_CHARS`（P0-2） | 有 | **0** |
| `l3_write_bypass_done`（P0-1） | 有 | **0** |
| 3 个功能文件 mtime | 2026-09-11 | **2026-09-03** |

差异文件与报告完全一致：`stop/29-independent-review.sh`、`stop/lib/l3-review.sh`、
`stop/lib/l3-done.sh`。diff 逐行核对：**差异内容 100% 就是 P0-1/P0-2 那两处修复**，
没有任何"本地有意改动"（即可以直接覆盖）。报告提到的 `l3-prompt.sh.bak-20260824`
已 diff：是 8/24 的重构前快照，无独有内容，保留不动。

### 新增发现：防漂移断言本身失效（原报告 §7 的"建议机器检查"为何没挡住）

原报告建议"加一条机器检查：比对三处副本的 hooks 树哈希"。**其实已经有一条**：

```
test/test_l3_pipeline_fix.bats
  T06: AC-6 l3-prompt.sh four in-repo copies share one md5
  T06: AC-6 global ~/.claude copy cmp-identical when present
```

问题：它只比对 `l3-prompt.sh` **一个文件**。而 `l3-prompt.sh` 恰恰是唯一同步到位的文件
（mtime 2026-09-06，与其他副本一致），真正漂移的 3 个文件不在断言范围内
→ **测试全绿，漂移照旧**。这就是"同一 change 换条路径结论不同"能长期潜伏的原因。

### 修复

1. 新增 `sync-hooks.sh`：以 `flow-kit-bundle/hooks/` 为唯一源，把 `install_hooks.sh`
   的**安装文件集**（47 个文件）镜像到全部 6 个已存在的副本。
   契约：**只增改、不删除**（副本里别的工具的文件一律不动）、副本不存在则跳过、幂等、
   **只管内容不改权限**（可执行位归 `install_hooks.sh`；本工具只读提示缺失的 +x）。
   `--check` 为只读漂移检测（CI 用），`--list` 为状态查看。
2. Makefile 接线：`make hooks-sync` / `make check-hooks-sync`，并把
   `check-hooks-sync` 纳入 `make check` 门禁。
3. 副本清单从 3 处扩到 6 处——原报告只比了 3 处，实际运行时副本还有
   `dist/dsh-flow-kit/hooks`、`dist/dsh-flow-kit/vendor/…/hooks`、
   以及**本次 DSH 会话真正在执行**的
   `~/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks`（已核对 `hook-bridge.js`
   `this.hooks = join(packageRoot, "hooks")`，即插件跑的是包内 hooks，不是 vendor）。
4. 实测结果：首次 `--check` 报 6 个副本全部漂移 → 同步 40 个文件 → 复检
   **6/6 副本漂移 0**。

---

## 6 · 修复后的验证

| 缺陷 | 验证方式 | 结果 |
|---|---|---|
| B1 | 原报告 §B1 自包含复现 → 期望 `fail` | ✅ `fail` |
| B1 | 222 份归档工件提取覆盖率 | ✅ 空值 0、非枚举 0 |
| B1 | `PASS` / `- **Verdict**: Pass` / `### Verdict: FAIL` / `## Verdict`+次行 | ✅ 全部归一为小写枚举 |
| B2 | 4 轮连写（载荷含行首 `## `）| ✅ L3 段 1 个、标记 1 个、`---` 1 条、残留 0、围栏配平 |
| B2 | **生产链路** `_l3_parse_result` 连跑 5 轮（2 轮载荷带行首 `## `）| ✅ 与单轮结果同形：段 1 / 标记 1 / 分隔 1 / 围栏 2 / 空行 7（不增长）/ 残留 0 |
| B2 | 历史无标记工件 | ✅ 仍按标题法清除，标记后内容不误删 |
| B3 | cap=60000 对 CJK 文件 | ✅ 60000 字节 = 20000 汉字（已断言） |
| B3 | 新键/旧键/历史 env/缺省 四级解析 | ✅ 60000/60000(带提示)/333/20000 |
| B4 | 41 条目目录 → `_l3_build_prompt 7` | ✅ 41/41 名字在清单内，`INTEGRATION.md === MISSING` 计数 0 |
| B4 | 删掉必备 `TASK.md` | ✅ 仍严格输出 `=== TASK.md === MISSING`（门禁未削弱） |
| B5 | `./sync-hooks.sh --check` | ✅ 6/6 副本漂移 0 |
| B5 | 漂移检测自证（伪造缺失副本） | ✅ 能报出漂移并非零退出（非恒真断言） |
| B5 | 同步不产生无关权限变更 | ✅ `git diff --summary` 零 mode change（工具只读提示缺失的 +x） |
| 全部 | `test/test_l3_review_defects_2026_09.bats`（28 例） | ✅ 28/28 |
| 全部 | 全量 `npx bats test/` | ✅ **854 / 854，0 fail**（基线 826） |
| 全部 | `make check`（test + lint + check-validate + check-test-sync + check-hooks-sync） | ✅ 五门全绿 |
| 全部 | shellcheck（8 个改动/新增脚本，error 级） | ✅ 0 error |
| 全部 | 打包完整性 `--validate`（含新增 `l3-section.sh`） | ✅ 312 文件全覆盖，漏配 0 / 源缺失 0 |

## 7 · 未覆盖声明

- 本次**没有**重新审查原报告 §8 已声明不覆盖的范围（L2 派发/子 agent 生命周期、gate 与
  transition 逻辑、`31-auto-advance.sh`、看板、安装器与打包脚本）。
- B1 的语义判定（"L2 verdict = 审查员原文结论，而非主 agent 修复后的复述"）依据
  `L2-blind-review.md:142` 的独立性条款；若有异议，只需调整锚点/取值顺序，不影响本次的结构性修复。
- 归档工件的 `.done` 历史值与新提取结果存在 12 处不一致——这是**历史记录**，未回溯修改
  `.done`（PreToolUse 守卫本就禁止主 agent 改 `.done`，且新 change 起自洽）。
