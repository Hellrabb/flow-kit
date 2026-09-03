# 独立审查 · 阶段 1

## L2 盲审

> 审查对象：`.specs/dsh-flow-kit-sync-2026-09/REQUIREMENT.md`（参考 CHANGE.md + 仓库真实交付，git diff 2999024..HEAD = 868f362/0981bd7）。
> 独立复核：逐条核对 flow-state.js / flow-state.test.mjs / package.json / DESIGN §8 / README / VERIFY / common.sh / SKILL.md / 33-flow-active-integrity.sh / test/test_fk_resolve_model.bats，未引用主 agent 任何自评。

### 🟡 R1 · AC 未采用 Given/When/Then 三段结构：阶段 1 模板硬性要求不满足
**Severity**：🟡 Important
**Symptom（症状）**：`.specs/dsh-flow-kit-sync-2026-09/REQUIREMENT.md:37-48` 六条 AC 均为单行声明（如 AC-2「/flow model l2-default=/l3-default= 写入 …；--clear <target> 清除 …」），无 Given / When / Then 三段。
**Source（源头）**：`flow-kit/prompts/independent/L2-blind-review.md` 阶段 1 checklist「每条 AC 是否 Given/When/Then 三段齐全且可机器验证」；`flow-requirement` skill 自检「每条 AC 都有 Given/When/Then 结构」。
**Consequence（后果）**：AC 内容具体、可机器验证，但触发前提/操作/预期被压缩进一行；分支条件（AC-3 有 correction 文件 vs 无文件、AC-2 设置 vs 清除）不显式，TASK/TEST 逐条映射时需人工拆解，可追溯性下降。
**Remedy（修补）**：逐条改写为 GWT。示例：
```
AC-2 Given 一个已 /flow goal 的活跃 flow
      When 执行 /flow model l2-default=X l3-default=Y
      Then .goal.l2_default_model=X 且 .goal.l3_default_model=Y，
           且仅 l2_model/l3_model/l2_default_model/l3_default_model 四键被触碰，
           回显含新值（非「未设置」）；
      When 执行 /flow model --clear l2 l3-default
      Then .goal.l2_model=null 且 .goal.l3_default_model=null。
```

### 🟡 R2 · 范围切分缺 v2（下次再说）桶：只有 In/Out，无延期项
**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:19-33` 只有「范围（In scope）」与「范围外（Out of scope）」，无 v2 段。
**Source（源头）**：`flow-requirement` skill「范围切分 v1/v2/out」「范围排除（v2/out）至少各 1 条」；L2 checklist「v1/v2/out 范围切分是否合理」。
**Consequence（后果）**：无显式「本次不做、下次再说」的锚，读者无法区分「永不做」与「暂缓」；仓库确有可暂缓项（`dsh-flow-kit/VERIFY.md:37-41`「未完成（后续 round）」：dsh headless 全链路真机 boot、Stop 链真机触发验证、brooks-lint 的 dsh 命令化），既非 in 也非 out，当前无处归档。
**Remedy（修补）**：在 §3 之前补 v2 段，将 VERIFY.md「未完成（后续 round）」三项列为 v2；若认定本次内容同步无遗留，则显式写「v2：无」，并保留 out。

### 🟢 R3 · 无非功能性需求段：兼容/安全红线未显式入 AC
**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md` 全文无「非功能性需求」段。
**Source（源头）**：`flow-requirement` skill「非功能性：性能/安全/兼容性等显式列出，没有就写无」；L2 checklist「是否遗漏非功能性需求（性能/安全/可观测性/容量/兼容性）」。
**Consequence（后果）**：本 change 的兼容性（claude/opencode/dsh 三端 .flow-active/.flow-active.correction 契约不变）与安全红线（凭证值不落盘）依赖上游既有契约，未在本需求显式声明，阶段 5/6 验收时易漏检。
**Remedy（修补）**：补 NFR 段，至少写「兼容性：状态契约三端不变、vendor 零丢失；安全：凭证值不落盘（沿袭上游红线）；性能/容量/可观测性：无」。

### 🟢 R4 · AC-1/AC-6 验证目标不在仓库 diff 内：追溯性依赖运行时外部状态
**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:37`（AC-1 dist 重打包/vendor 逐字节）与 `:48`（AC-6 两 profile node_modules 刷新 0.2.0/dump-config）对应的产物（`dist/dsh-flow-kit`、`~/.dsh/profiles/*/node_modules`）不在 git diff 2999024..HEAD 内（dist 为构建产物、profile 为机器本地状态）。
**Source（源头）**：本 change 审查目标「补档文档与真实交付是否一致、可追溯」；L2 通用 L-031「对比 git diff 实际改的文件」。
**Consequence（后果）**：独立审查无法仅凭仓库内容复核「vendor 逐字节一致」「profile 已刷新 0.2.0」在合入时刻为真，只能信任命令可重跑。
**Remedy（修补）**：在 TEST.md/INTEGRATION.md 固化命令输出摘要（INTEGRATION.md:21-28 已有部分，补 `diff -rq` 空输出与 `--dump-config` 的 `id: flow-kit` 原文作为证据），并在 AC-1/AC-6 标注「验证命令 + 证据落点」。

### 交叉一致性核对（L-031）

- `l2_default_model` / `l3_default_model` 字段名：shell `fk_resolve_model`（`flow-kit-bundle/hooks/stop/lib/common.sh:261,267`）读 `.goal.l2_default_model/.goal.l3_default_model`；插件 JS（`dsh-flow-kit/lib/flow-state.js:352-353,363-366`）写同名键；`SKILL.md:237-246,258-259` 与测试断言（`flow-state.test.mjs:156-172`）一致 —— 无漏改。✅
- `--clear <l2|l3|l2-default|l3-default>` 语义：JS `fieldOf` 仅映射 4 个模型键、`nextGoal = {...goal}` 不碰 condition/gates/gate_config；SKILL.md L245-246/259 字段边界一致；测试断言 gate_config 不变。✅
- correction 结构：33 号 hook（`33-flow-active-integrity.sh:368-423`）写 `type` + `violations[]`（含 `.check`）；doctor（`flow-state.js:394-408`）读 `type` 与 `v?.check` 去重摘要；测试断言 `type=…/violations=3/stale_updated_at, corrupt_json`。✅
- 版本与 files：`package.json` 0.1.0→0.2.0（diff 证实），files 含 vendor/skills/flow-kit/hooks/brooks-lint/docs。✅
- 测试计数：插件单测 4 文件 19→20 个 `test()`（`flow-state` 7→8，新增 doctor 用例；model 五级链断言扩入既有用例）；`make test` 实跑 770 例全过（`test/` 顶层 68 个 .bats，`test/weak-model-robustness/` 8 例不在 `make test` 收口内，属既有结构，非本 change 引入）。✅
- 范围无夸大：In scope 7 项逐条在 diff 或运行时证据中有对应（版本/doctor/model/单测/文档/重打包+重装/补审），无未实现项混入 v1。✅

**Verdict**: pass

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-03 16:13）

> 自动生成于 2026-09-03 16:13。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"REQUIREMENT — dsh-flow-kit-sync-2026-09（AC-2）","issue":"AC-2 未列出“仅 4 个模型键”的具体键名，且设置路径使用 .goal.l2_default_model，--clear l2 后断言 .goal.l2_model，键名与命令参数对应关系不明确。","why":"验收者无法判定“触碰”的含义与正确键集合，--clear 场景可能因键名笔误或未解释的语义产生假通过/假失败。","fix":"显式列出 4 个模型键及命令参数映射，统一 l2_default_model/l2_model 命名，或直接以 test/flow-state.test.mjs 中的逐键断言为准并标注完整清单。"},{"file":"REQUIREMENT — dsh-flow-kit-sync-2026-09（AC-3 / v1 范围）","issue":"v1 单测三形状为 state-integrity + compliance + model-missing，AC-3 却写为 state-integrity / compliance / 无 violations 有 message；且“check 或 rule 去重摘要或 message”未按形状明确必须输出项。","why":"范围与 AC 对同一功能给出不同形状定义，or 表述使输出断言不唯一，验收结论不可复现。","fix":"统一形状命名，分别为三种形状写独立 Given/When/Then：state-integrity 输出 check 去重摘要，compliance 输出 rule 去重摘要，无 violations 有 message（含 model-missing）输出 message，并要求 type 原样。"},{"file":"REQUIREMENT — dsh-flow-kit-sync-2026-09（NFR 安全）","issue":"安全 NFR 声明 FLOW_KIT_L3_* 不落盘、凭证经 env 注入，但没有任何 AC 或验证步骤覆盖。","why":"安全红线若无验收手段，回归时无法防止凭证落盘，NFR 形同虚设。","fix":"增加一条 AC：在安装/触发 hook 后检查 .flow-active/.specs 及运行时文件不含 FLOW_KIT_L3_* 值，并纳入 AC-5 回归门禁。"}],"minor":[{"file":"REQUIREMENT — dsh-flow-kit-sync-2026-09（AC-5）","issue":"“20/20、770 ok / 0 fail”写在 When 括号中，与 Then 的“全部 exit 0”分离。","why":"括号内容易被误读为命令参数，而不是输出断言。","fix":"将这些计数移入 Then 作为输出断言。"},{"file":"REQUIREMENT — dsh-flow-kit-sync-2026-09（AC-3）","issue":"“无文件时提示卫生良好”未写成独立 Given/When/Then 分支。","why":"该场景缺少前置条件和输入，验收者无法准确触发。","fix":"补充 Given .flow-active.correction 不存在；When /flow doctor；Then 输出卫生良好提示。"},{"file":"REQUIREMENT — dsh-flow-kit-sync-2026-09（AC-1 / AC-6）","issue":"AC-1 的 Given “flow-kit-bundle 为当前 HEAD”未指明 HEAD 来源/确认方式；AC-6 未明确 pnpm install 的 cwd 与 node_modules/dsh-flow-kit 的检查路径。","why":"前置条件和执行环境不完整，跨机器复现时可能无法满足。","fix":"注明 flow-kit-bundle 对应的 commit/标签及核对命令；明确 AC-6 的安装目录和 node_modules 解析路径。"},{"file":"REQUIREMENT — dsh-flow-kit-sync-2026-09（NFR 兼容性）","issue":"“三端状态契约不变”只声明为 NFR，没有映射到具体 AC 或测试断言。","why":"AC-1/AC-5 只能证明打包一致与回归通过，不能显式防止 claude/opencode/dsh 某端状态契约回归。","fix":"补充三端 .flow-active/.done 契约样例测试，或将契约断言显式纳入 node --test 测试集。"},{"file":"REQUIREMENT — dsh-flow-kit-sync-2026-09（v1 范围）","issue":"v1 范围混入了“独立审查补审”“VERIFY round 5”等流程活动。","why":"范围切分应是交付物边界，流程记录混入会让读者误判交付内容。","fix":"将流程/证据活动移入独立“验证记录”小节，v1 只保留产品/测试/文档交付物。"}],"verdict":"pass","summary":"范围切分总体合理、AC 基本可执行，但 AC-2/AC-3 存在可验证性歧义且安全 NFR 缺少验收映射，需在后续修订中澄清。"}
```

L3_artifact_hash: f9233007d29ededeb34aaa10d9594381760f7ee51c864c4d757d484e2bdf5f79
