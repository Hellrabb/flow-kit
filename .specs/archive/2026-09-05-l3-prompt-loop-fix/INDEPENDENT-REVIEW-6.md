# 独立审查 · 阶段 6

## L2 盲审

> **独立性声明**：本审查输入仅为 `git diff 07eaf08..HEAD`（6 commits）与 `.specs/l3-prompt-loop-fix/{REQUIREMENT,DESIGN,REVIEW}.md` 工件本身，未接受任何主 agent 自评/辩护注入。REVIEW.md 作为待复核对象而非权威。
> **盲审锚点（独立实证）**：四副本 md5 一致（`bc1f0ad6`）；`test/fixtures` 与 `flow-kit-bundle/test/fixtures` 双源一致；`test_l3_pipeline_fix.bats` 双源 identical；`head -c` 残留 2 处均在 helper 函数体内（D7 锚点）；全量 `npx bats test/` exit=0 / 0 fail / 1 既有 skip。

### 🟡 R1 · UTF-8 边界：前轮摘要行截断可切在多字节字符中间，产出非法 UTF-8
**Severity**：🟡 Important
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:155` — `trimmed="${l:0:197}…"`。函数 `_l3_extract_prior_findings` 顶部 `local LC_ALL=C`（:91）使 `${l:0:197}` 按**字节**切片，197 字节边界落在中文/emoji 多字节序列中间时产出悬挂 lead/续字节（非法 UTF-8）。实测：`l="x"+"中"×100`（301B）→ `${l:0:197}…` 经 `iconv -f UTF-8 -t UTF-8` 校验为 **INVALID**。
**Source（源头）**：REQUIREMENT 非功能性需求「健壮性」——「反馈注入与工件截断须落在 UTF-8 字符边界…注入段整体必须为合法 UTF-8——中文摘要截断产生非法字节序列会重新引入弱模型误读风险」。本 change 已为工件截断建 `_l3_utf8_head_bytes/_l3_utf8_head_stream`（D7），但摘要行截断（:154-155）绕过了它们。T02 行长用例（test/test_l3_pipeline_fix.bats:309-326）仅断言 `len ≤201` + `tail -c 4` 含 `…`，**不校验 UTF-8 合法性**（且 fixture 前缀字节数恰好使 197 落在字符边界，未触发）。
**Consequence（后果）**：单条摘要行 >200B（verbose 中文审查常见）且 197B 落在字符中间（中文 3B/字，约 2/3 概率）时，注入的前轮发现摘要含非法字节 → 弱模型误读 → 以退化方式重演本 change 要修复的假阳性循环。NFR 明确点名此风险。
**Remedy（修补）**：复用既有 helper 做 UTF-8 安全截断（`_l3_utf8_head_stream` 已含边界回退）：
```bash
if [ "${#l}" -gt 200 ]; then
  trimmed="$(printf '%s' "$l" | _l3_utf8_head_stream 197)…"
else
  trimmed="$l"
fi
```
（`_l3_utf8_head_stream 197` 在字节 cap 内回退到上一完整字符；`…` 3B，总量 ≤200B 契约不变）

### 🟢 R2 · AC-6 字面「无 skip」与实际「1 既有 skip」未对账
**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT AC-6 THEN 要求「全量 bats 无 fail/skip」；实测 `npx bats test/` 1 skip——test 630 `AC-4: 模拟全量覆盖场景下 --validate exit = 0 # skip AC-4 需要全量覆盖环境；当前仓库已知有 gap`，属 `package-flow-kit.sh --validate` 覆盖 gap，与本 change 无关。
**Source（源头）**：AC-6 文本措辞 vs 现实环境（既有 skip 早于本 change 存在）
**Consequence（后果）**：无实质后果（REVIEW.md 已披露「1 既有 skip」；不影响本 change 正确性）
**Remedy（修补）**：7-integration 时将 AC-6 措辞从「无 skip」收窄为「无新增 skip / 无 fail」，或登记该既有 skip 为已知环境项。

### 🟢 R3 · phase 7 `echo -e` 对字面转义序列的失真边界（独立确认，与主 agent F3 一致）
**Severity**：🟢 Minor
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:354` — `artifact=$(echo -e "$artifact" | _l3_utf8_head_stream "$max_chars")`。`echo -e` 会把工件内容中字面 `\n`/`\t`/`\xHH` 序列解释展开。
**Source（源头）**：Hunt《The Pragmatic Programmer》「巧合编程」边界；POSIX `echo -e` 非可移植且语义重载。独立结论（非抄主 agent——我从 NFR 健壮性 + `_l3_utf8_*` helper 的边界职责切入，主 agent 从「巧合编程」切入）。
**Consequence（后果）**：工件内容（CHANGELOG/REVIEW 等）含字面反斜杠序列时被改写；当前 41KB CHANGELOG 无命中，低概率。
**Remedy（修补）**：构造分隔符改用 `$'\n'` 拼接、工件内容经 `printf '%s'` 直通，去掉 `echo -e`（或 `printf '%b'` 仅展开分隔符）。与主 agent M12 登记一致，不重复登记。

---

## 与主 agent REVIEW.md 的对照

- **主 agent 漏判**：R1（UTF-8 摘要行截断）——主 agent 的 4 条 Minor（F1-F4）无一覆盖 `_l3_extract_prior_findings` 行截断的 UTF-8 边界缺陷；F1 仅把提取器归为「双文法单函数」认知过载（l3-prompt.sh:89-166），未识别出**字节切片产出非法 UTF-8** 的正确性缺陷（NFR 健壮性直接违反）。
- **独立一致**：R3 与主 agent F3（echo -e）结论一致，属独立得出。
- **主 agent 未提**：R2（AC-6 措辞 vs 既有 skip）。

**Verdict**: pass

---

## 主 agent 响应

- **R1**（`${l:0:197}` 字节切片产非法 UTF-8，主 agent 漏判确认）— Fixed in: `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:152-157`（超长行截断改 `printf '%s' "$l" | _l3_utf8_head_stream 197` 复用 D7 边界回退 helper）+ `test/test_l3_pipeline_fix.bats` 新增用例「T06fix: L2 R1 - line cap truncation respects UTF-8 boundary」（RED→GREEN：iconv 合法性断言 + ≤201 字节 + 省略号在场）+ 四副本 + ~/.claude 全局已同步（md5 复核见下）。
- **R2**（AC-6 措辞 vs 既有 skip）— Not-applicable（🟢 不入 fix loop）→ MINOR-DEFERRED.md M14。
- **R3**（echo -e 失真边界）— Not-applicable（🟢 不入 fix loop，与主 agent F3 独立一致）→ 已登记 M12。
- 漏判致谢：F1 仅识别认知过载维度，未识别字节切片正确性缺陷；L2 R1 实证（iconv 复现）成立，已按修代码优先协议修复并回归。

---

## L3 重审（glm-5.3-flash 外部模型 · 2026-09-05 04:07）

> 自动生成于 2026-09-05 04:07。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[],"minor":[{"file":"flow-kit-bundle/hooks/stop/lib/l3-prompt.sh","issue":"截断门控与截断实现单位不一致：门控仍用 `${#l}`（UTF-8 locale 下按字符计数），而 `_l3_utf8_head_stream 197` 按字节截断","why":"修复前两侧同为字符语义（UTF-8 locale 下一致），修复后引入错位：CJK 行 ≤200 字符（可达约 600 字节）不会被门控拦截、整行原样进入摘要（单行可吃掉 600B 配额大头）；而 >200 字符的 CJK 行反被压到 197 字节（约 65 个汉字），信息保留率骤降。与 CONTEXT.md 新增「前轮发现单行摘要 ≤800 字节」的立场及测试注释声称的 200B 行帽不吻合（总量 800B 由下游折叠兜底，故不升级为 major）","fix":"门控改为字节长度判断，如 `[ \"$(printf '%s' \"$l\" | LC_ALL=C wc -c)\" -gt 200 ]`，使门控与截断同为字节语义；或对两侧统一声明并文档化字符/字节口径"},{"file":"flow-kit-bundle/test/test_l3_pipeline_fix.bats","issue":"T06fix 断言 `[ \"${#capped}\" -le 201 ]` 在 UTF-8 locale 下按字符计数，与注释「200B cap」不符","why":"UTF-8 locale 下该断言实际测得约 66 个字符，恒成立、近乎空断言，字节帽属性未被有效验证（仅 C locale 下才真正生效），削弱了对修复行为的回归锚定力","fix":"改用字节口径断言：`[ \"$(printf '%s' \"$capped\" | LC_ALL=C wc -c)\" -le 200 ]`，并在断言旁注明 locale 无关"},{"file":"test/test_l3_pipeline_fix.bats","issue":"T06fix 使用 `iconv -f utf-8 -o /dev/null`，`-o` 选项为 GNU iconv 扩展，非所有平台 iconv（部分 BSD/macOS 构建）支持","why":"在不支持 `-o` 的平台上 iconv 因未知选项报错退出，导致该回归测试在这些环境出现与被测行为无关的假失败；这是可移植性问题而非假通过","fix":"改为 `iconv -f utf-8 >/dev/null`（利用 stdout 重定向 + 退出码判断），语义等价且跨平台"}],"verdict":"pass","summary":"前轮 major（摘要行截断切断多字节字符）已在 bundle 与 .claude 双副本以 `_l3_utf8_head_stream` 边界回退正确修复、双源测试同步并以 T06fix 精确锚定（197/198 字节边界确落在 CJK 字符内部），T05fix 补齐 AC-4 ②③ 配额断言，CONTEXT.md 文档追加与已锁决策一致；无 critical，余下为门控/断言的字符-字节单位不一致及 iconv -o 可移植性等 minor。"}
```

L3_artifact_hash: e764a552c4375b0ae091e805ec89490fe700da7fd62c41bef9ad0691f3729b11

---

## 主 agent 响应（L3）

- **L3 Minor-1**（门控 `${#l}` 字符计数 vs 字节截断单位不一致）— Not-applicable（误读）：`_l3_extract_prior_findings` 函数顶部已声明 `local LC_ALL=C`（l3-prompt.sh:92），C locale 下 `${#l}` 即字节数——实证 150 个 CJK 字符 `${#l}`=450。门控与截断单位一致（均为字节）。
- **L3 Minor-2**（T06fix 断言 `${#capped}` 字符计数）— Fixed in: test/test_l3_pipeline_fix.bats T06fix（断言改 `printf '%s' "$capped" | LC_ALL=C wc -c` 显式字节语义；属 L2 R1 修复的断言精度收尾，41/41 复绿）+ 双源镜像同步。
- **L3 Minor-3**（iconv -o GNU 扩展可移植性）— Not-applicable（🟢 不入 fix loop）→ MINOR-DEFERRED.md M15。
