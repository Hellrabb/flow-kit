# TASK: l3-prompt-loop-fix

- **Change ID**: l3-prompt-loop-fix
- **关联**: `@.specs/l3-prompt-loop-fix/REQUIREMENT.md`、`@.specs/l3-prompt-loop-fix/DESIGN.md`

---

## 波次划分

```
Wave 1: T01（UTF-8 截断 helper）
Wave 2: T02（前轮发现提取器 + fixtures）          (depends on T01)
Wave 3: T03（_l3_inject_context 重构 · 三锚 + 配额）(depends on T02)
Wave 4: T04（build_prompt 重排 + D5/D6 + 13 位点）  (depends on T01, T03)
Wave 5: T05（回归清扫 + AC-4/AC-7 端到端）          (depends on T04)
Wave 6: T06（全量同步 + md5 + 测试双源 + 漂移存档） (depends on T05)
```

> **纯串行**（无 `[P]` 标记）：T01–T04 全部写同一物理文件 `l3-prompt.sh` 与同一测试文件 `test_l3_pipeline_fix.bats`，按「文件冲突切」原则必须单写者顺序执行。
> 所有代码任务只改 **bundle 维护源**（`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`）；副本同步统一在 T06（已锁决策 [2026-06-16]）。

---

## 任务清单

```xml
<task id="T01" parallel="false" status="done">
  <name>新增 UTF-8 安全截断 helper 两变体 + 单元测试</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    test/test_l3_pipeline_fix.bats
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    test/test_l3_pipeline_fix.bats
  </write_files>
  <action>
    在 l3-prompt.sh 顶部（_l3_inject_context 之前）新增两个 helper（见 DESIGN D7）：
    1. `_l3_utf8_head_bytes(max_bytes, file)` — 文件路径形：先 head -c 取字节，若尾部落在 UTF-8 多字节序列中间则回退 ≤5 字节至上一完整字符边界（od -An -tu1 检查尾部 ≤6 字节的续字节模式 10xxxxxx = 0x80-0xBF）；
    2. `_l3_utf8_head_stream(max_bytes)` — stdin 流形：同一回退逻辑，读 stdin 输出 stdout。
    本任务只新增 helper 函数 + 单元测试，不替换任何调用位点（替换在 T04）。
    实现约定：两 helper 内部**各恰好 1 处** `head -c`（合计 2 处）——T04 verify 以 `grep -c 'head -c' -eq 2` 精确锚定全量替换。
    单元测试覆盖：纯 ASCII 不回退；中文结尾恰好完整字符不回退；截断点落在三字节汉字中间回退 2 字节；截断点落在 emoji（四字节）中间回退 3 字节；空文件/不存在文件静默（返回空，exit 0）。
  </action>
  <verify>bats test/test_l3_pipeline_fix.bats</verify>
  <done>helper 单元测试全绿；输出恒 ≤ max_bytes 字节；边界回退正确（NFR 健壮性）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="false" status="done">
  <name>新增 _l3_extract_prior_findings 提取器 + 三类 fixtures</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    test/test_l3_pipeline_fix.bats
    .specs/l3-prompt-loop-fix/DESIGN.md
    .specs/l3-prompt-loop-fix/INDEPENDENT-REVIEW-2.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    test/test_l3_pipeline_fix.bats
    test/fixtures/independent-review-l2-sample.md
    test/fixtures/independent-review-l3-sample.md
    test/fixtures/independent-review-mixed-sample.md
    test/fixtures/independent-review-no-response.md
    test/fixtures/independent-review-empty.md
    test/fixtures/independent-review-overflow.md
    test/fixtures/independent-review-verdict-only.md
  </write_files>
  <action>
    新增 `_l3_extract_prior_findings(review_md)`（见 DESIGN D2/D3 字段映射接口定义）：
    - L2 源：`## L2 盲审` 段内 `### 🔴`/`### 🟡` 行 → severity 映射 🔴→critical/🟡→major，file 取 Symptom 中 path:line，摘要取 R{x} 标题冒号后一句；
    - L3 源：`## L3`（含 重审）段 JSON 的 "critical"/"major" 数组键下条目（无 "severity" 字段——l3-prompt.sh:156 schema 实证），file 取 file 字段，摘要取 issue 字段首句；
    - 输出单行 `severity|file|摘要`（每行 ≤200 字符，超长截断加 …）；排序 severity 降序、同级 L3 先于 L2；
    - 正则约束：POSIX ERE + LC_ALL=C 字节匹配（emoji 锚点按字节字面量），禁 grep -P；
    - minor 不提取；文件不存在/两源皆空 → 空输出 exit 0。
    fixtures 按上述映射固化七类样本：纯 L2 段、纯 L3 段、L2+L3 混排、无响应段（含 findings）、空/首轮、**溢出**（≥6 条 findings 使 600B 配额必溢出，供 (+k more) 折叠断言 · phase-3 L2 R6）、**verdict-only**（仅 Verdict: fail 行，无 findings 无响应 · phase-3 L3 Major-2）。样本数据取自 INDEPENDENT-REVIEW-2.md 真实结构（脱敏改写）。
    单元测试：七类 fixtures 的提取行数、排序、severity 映射（本任务只测提取器，配额折叠在 T03 注入层测）。
  </action>
  <verify>bats test/test_l3_pipeline_fix.bats</verify>
  <done>七类 fixtures 提取断言全绿；字段映射与 DESIGN D2 接口定义一致（AC-4 前置）</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="false" status="done">
  <name>重构 _l3_inject_context：三锚响应检测 + 配额折叠 + 未响应标注</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    test/test_l3_pipeline_fix.bats
    test/fixtures/independent-review-*.md
    .specs/l3-prompt-loop-fix/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    test/test_l3_pipeline_fix.bats
  </write_files>
  <action>
    重构 _l3_inject_context（见 DESIGN D2/D4，ADR-025）：
    1. 调用 _l3_extract_prior_findings 取前轮发现；600B 配额内取前 N 行，溢出折叠为 `(+k more)` 一行（单元测试接 overflow fixture 断言折叠行 · phase-3 L2 R6）；
    2. 响应检测三锚任一命中（`## 主 agent 响应` 段头 / `主 agent 反驳：` 段 / 行内 `(Fixed in|Tech-debt|Not-applicable):` 标记——实证格式 `- **R1** — Fixed in:`，非行首锚）→ 从命中处提取分类要点 ≤200B；
    3. **保留既有注入项**（phase-3 L2 R7）：L2/L3 verdict 行（`**Verdict**: pass|fail` 前轮结论，🔴→fail 提示谨慎复核——l3-pipeline-fix-2026-07 D4 既有行为）+ 含「审查上下文」字样的 disclaimer 行（bats:106-132 AC-5 既有断言锚，向后兼容）；
    4. 边界矩阵四象限（phase-3 L2 R8 明确化「有响应无发现」）：
       - findings 有 + 响应有 → verdict + findings 摘要（600B）+ 响应要点（200B）（AC-4）
       - findings 有 + 响应无 → verdict + findings 摘要 + 「主 agent 未响应前次发现」标注（AC-5）
       - findings 无 + 响应有 → verdict + 响应要点（无标注——响应存在即信号，不误标未响应）
       - findings 无 + 响应无、文件存在且 verdict 可解析 → 仅 verdict 行（phase-3 L3 Major-2：前轮 fail 结论不静默丢弃）
       - findings 无 + 响应无（或文件缺失/空/verdict 不可解析）→ 整段静默（无 verdict 无摘要无标注，exit 0）（AC-7）
    5. 函数签名与调用方关系不变：`_l3_inject_context(phase, artifacts_dir)` 输出注入文本到 stdout——生产拼接方 = l3-review.sh:81/L103 既有 `context_preamble` 前置组装（禁动文件不改，本任务只改函数内部逻辑；反馈段物理最前由该既有组装保证）。
    假阴性语义按 D4 显式接受（宁漏报不误报），无需额外处理自由措辞。
    单元测试：no-response fixture → 含「未响应」标注行；mixed fixture（含 Fixed in: 行）→ 无标注 + 要点行；empty fixture → stdout 为空；**verdict-only fixture（仅 Verdict: fail 行，无 findings 无响应）→ 仅 verdict 行存活（phase-3 L3 Major-2 钉住）**；既有 bats:106-132 AC-5 用例（Verdict+响应、无 findings mock）保持绿——断言「审查上下文」锚与 verdict 行注入兼容。
  </action>
  <verify>bats test/test_l3_pipeline_fix.bats</verify>
  <done>三锚检测 + 600B/200B 配额 + verdict/disclaimer 保留 + 四象限边界矩阵断言全绿（AC-4/AC-5/AC-7 单元层 + 既有 AC-5 用例向后兼容）</done>
  <depends_on>T02</depends_on>
</task>

<task id="T04" parallel="false" status="done">
  <name>_l3_build_prompt 重排反馈优先 + D5 双位点 project_root + D6 checklist + 13 处位点替换</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    test/test_l3_pipeline_fix.bats
    test/fixtures/independent-review-*.md
    .specs/l3-prompt-loop-fix/DESIGN.md
    .specs/l3-prompt-loop-fix/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    test/test_l3_pipeline_fix.bats
  </write_files>
  <action>
    按 DESIGN §2 数据流图重排 _l3_build_prompt 自身段序（**不动 _l3_inject_context 调用关系**——组装层 l3-review.sh:81/L103 既有 preamble 前置，禁动不改；build_prompt 输出内不含反馈段）：
    ① phase 7 CHANGELOG/LESSONS 注入段置 build_prompt 输出最前；② 既有 7 文件工件循环；③ checklist 收尾。
    D5：project_root 解析改为——artifacts_dir 匹配 `*/.specs/archive/*` 时 dirname×3，否则 dirname×2；**两处同构位点统一套用**（phase 6 L91-92 与 phase 7 L127-128）。
    D6：checklist 措辞改固定文案——「SUMMARY」改「T0x-SUMMARY（如已生成）」；CHANGELOG 句改「项目级 .specs/CHANGELOG.md 是否更新（CHANGELOG 不入归档目录，勿因归档目录缺失报错）」。
    D7：全部 13 处裸 head -c 替换——10 处文件路径形（L60/66/73/80/86/106/122/132/139/143）→ _l3_utf8_head_bytes；3 处流形（L115/118/145）→ _l3_utf8_head_stream；max_chars 字节预算语义不变。
    端到端测试（沿用 test_l3_pipeline_fix.bats，fixtures 同 T02）：
    - AC-1：CHANGELOG/LESSONS fixtures 各 ≥1500B + 工件满载 → `_l3_build_prompt` 单调用输出 ≤20000 字节 且 `=== CHANGELOG.md ===`/`=== LESSONS.md ===` 段标记仍在输出前部（反馈段不在 build_prompt 输出内——组装层前置，AC-4/5 验证组合调用）；
    - AC-2：checklist 断言固定完整行文案存在、旧「SUMMARY）」文案不存在；
    - AC-3：artifacts_dir=.specs/archive/{id}/ 布局 → CHANGELOG/LESSONS 注入成功（两段标记在）；
    - AC-5：组合调用复刻 l3-review.sh:81-104 组装（`out="$(_l3_inject_context 7 {dir})$(_l3_build_prompt 7 {dir} 20000)"`）+ no-response fixture → 「未响应」标注在组合输出最前部。
    - AC-1 组合层顺序断言（phase-3 L3 Major-1）：mixed 与 no-response 两 fixture 的组合输出中，反馈段标记字节位置 < `=== CHANGELOG.md ===` 字节位置；且 ≥1500B fixtures + 工件满载场景下组合输出内反馈段完整存活（800B 注入 + 20000B 预算交互被测试钉住）。此断言在 T05 全量回归中固化为独立 @test 用例。
  </action>
  <verify>bats test/test_l3_pipeline_fix.bats && [ "$(grep -o 'head -c' flow-kit-bundle/hooks/stop/lib/l3-prompt.sh | wc -l)" -eq 2 ]</verify>
  <done>AC-1/2/3/5 端到端全绿；grep -o 'head -c' 计数恰好 2 次且均在 helper 函数体内（两 helper 各 1 次，见 T01 action 约定——-o 逐次计数防行计数假阳/假阴 · phase-3 L3 minor）（D7 验证锚点）</done>
  <depends_on>T01, T03</depends_on>
</task>

<task id="T05" parallel="false" status="done">
  <name>全量回归清扫：修复重排导致的既有断言 + AC-4/AC-7 端到端补全</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    test/*.bats
  </read_files>
  <write_files>
    test/*.bats
  </write_files>
  <action>
    跑全量 bats（make check 或逐文件），识别因 prompt 段序变化而失败的既有断言（R1 风险：test_l3_review / test_hook_integration / l3-truncation 等可能锚定旧结构）——只修断言锚点与测试意图对齐，不改产品代码。
    补 AC-4 端到端（组合调用复刻 l3-review.sh:81-104 组装；mixed fixture：注入行含 severity|file|摘要 单行、排序正确、(+k more) 折叠在超配额 fixture 上）与 AC-7 端到端（empty fixture → 组合输出无反馈段标记、无未响应标注）与 **AC-1 组合层顺序用例**（phase-3 L3 Major-1：T04 定义的顺序/存活断言固化为独立 @test——mixed 与 no-response 反馈段位置 < CHANGELOG 段位置 + 满载下反馈段完整存活）。
    记录最终通过数（AC-6 的「无 fail/skip」基线在此确立）。
  </action>
  <verify>bats test/</verify>
  <done>全量 bats 0 fail 0 skip（770±N 基线，N=新增用例数）；AC-4/AC-7 端到端断言在列</done>
  <depends_on>T04</depends_on>
</task>

<task id="T06" parallel="false" status="done">
  <name>全量同步：l3-prompt.sh 四副本 + 测试双源（bats+fixtures）+ md5 一致性 + 漂移存档 + 全局部署</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    .claude/hooks/stop/lib/l3-prompt.sh
    Makefile
    test/test_l3_pipeline_fix.bats
  </read_files>
  <write_files>
    .claude/hooks/stop/lib/l3-prompt.sh
    dist/dsh-flow-kit/hooks/stop/lib/l3-prompt.sh
    dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    .specs/l3-prompt-loop-fix/sync-drift-20260904.patch
    test/test_l3_pipeline_fix.bats
    flow-kit-bundle/test/*
  </write_files>
  <action>
    同步前先存档漂移：diff bundle vs .claude/hooks 的 l3-prompt.sh 输出写入 sync-drift-20260904.patch（R3 缓解；已知漂移=旧版死代码 agent_response 残留）。
    cp bundle 源 → .claude/hooks/stop/lib/ + dist/dsh-flow-kit/hooks/stop/lib/ + dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks/stop/lib/ 三份副本。
    **测试双源同步（phase-3 L2 R5）**：`make test-sync`（cp test/*.bats → flow-kit-bundle/test/，**不含 fixtures 子目录**）+ 显式 `cp -r test/fixtures/. flow-kit-bundle/test/fixtures/`；收口跑 `make check-test-sync`（diff -rq 递归双向，防 pre-push 阻断）。
    **AC-6 bats 硬断言（phase-3 L2 R9）**：在 test/test_l3_pipeline_fix.bats 新增用例——仓库内四处 l3-prompt.sh（bundle + .claude/hooks + dist 两份）`md5sum | sort -u` 唯一值 =1，不满足即 fail（REQUIREMENT AC-6「计入 bats 用例」）；本用例在本任务同步完成后编写并同步进 flow-kit-bundle/test/（同 task 完成双源，避免 T05 全量跑时先红）。
    全局部署（AC-6 发布清单项，D8）：cp bundle → ~/.claude/hooks/stop/lib/l3-prompt.sh（仓库外路径，同步动作在本任务 action 内执行，verify 命令覆盖仓库内四处）。
  </action>
  <verify>[ "$(md5sum flow-kit-bundle/hooks/stop/lib/l3-prompt.sh .claude/hooks/stop/lib/l3-prompt.sh dist/dsh-flow-kit/hooks/stop/lib/l3-prompt.sh dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks/stop/lib/l3-prompt.sh | awk '{print $1}' | sort -u | wc -l)" -eq 1 ] && make check && { [ ! -f "$HOME/.claude/hooks/stop/lib/l3-prompt.sh" ] || cmp -s flow-kit-bundle/hooks/stop/lib/l3-prompt.sh "$HOME/.claude/hooks/stop/lib/l3-prompt.sh"; }</verify>
  <done>md5 唯一值 = 1（四处一致，verify 硬 gate）；AC-6 md5 bats 用例绿；make check 全绿（全量 bats + lint + validate + check-test-sync 收口 · 测试双源含 7 fixtures · phase-3 L3 minor）；~/.claude 全局副本存在则 cmp 同值（存在性门控断言，可证伪 · phase-3 L3 minor）；漂移 patch 已存档（AC-6）</done>
  <depends_on>T05</depends_on>
</task>
```

---

## AC → 任务映射

| AC | 覆盖任务 | 验证层 |
|---|---|---|
| AC-1 反馈段先于工件正文（截断前提下存活） | T04 + T05（组合层顺序用例） | 端到端 |
| AC-2 checklist 对齐归档约定 | T04 | 端到端 |
| AC-3 归档布局注入成功 | T04 | 端到端 |
| AC-4 前轮发现单行摘要 + 配额 | T02（提取）+ T03（配额）+ T05（端到端） | 单元 + 端到端 |
| AC-5 未响应标注 | T03（单元）+ T04（端到端） | 单元 + 端到端 |
| AC-6 四副本 md5 + 全量 bats | T05（bats）+ T06（md5） | 命令 |
| AC-7 空静默 | T03（单元）+ T05（端到端） | 单元 + 端到端 |
