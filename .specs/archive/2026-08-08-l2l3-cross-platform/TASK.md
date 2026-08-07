# TASK · l2l3-cross-platform（修订版 · Phase 3 第二轮）

> **回退背景**：Phase 6 盲审发现 F-B（平台感知优先级）/ R2（工具名兼容）/ F-A（AC-6 bats 断言）三项 spec 层缺陷 → rollback 到 Phase 1 修订 REQUIREMENT/DESIGN/ADR → 现重拆 TASK.md。
>
> **已落地代码**（第一轮 Wave 1-4 产出，在磁盘上）：common.sh `fk_resolve_api_credentials`（固定 Path1>P3>P2）/ l3-api.sh 共享化 / l2-detect.sh 双模式+共享化 / l3-review.sh box 双模式 / transcript-parser.sh jq（仅 `.tool=="Agent"`）/ 6 prompt 注释行 / .opencode/agent/ 定义 / install_hooks.sh agent 段 / flow-kit-resume.sh 平台感知 banner / 4 个新 bats / 2 个测试路径 bug 修复（T-FIX-01）。
>
> **本次 delta**：3 处代码改 + 1 处 bats 扩展 + 全量回归。

---

## Wave 1（并行）

<task id="T01-rev" parallel="true">
  <name>common.sh fk_resolve_api_credentials 平台翻转优先级</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    .specs/l2l3-cross-platform/DESIGN.md
    .specs/l2l3-cross-platform/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
  </write_files>
  <action>
    在 fk_resolve_api_credentials() 顶部加平台感知分支：
    - `fk_platform_is_opencode` 为真时优先级 = Path3 > Path1 > Path2（opencode 下 FLOW_KIT_L3_* 压制残留 ANTHROPIC_AUTH_TOKEN）
    - 否则保持现有 Path1 > Path3 > Path2（CC 零回归）
    - 公共规则不变：任一 Path1/3 命中即短路 Path2；Path3 token 有 base_url 空→rc=2 stderr 报错；Path2 仅当 Path1/3 全空
    - 三全局清空逻辑（FK_API_AUTH_TOKEN/BASE_URL/AUTH_SCHEME）每分支复用
    - **不改函数签名、不改 rc 语义（0/1/2）、不改 fk_platform_is_opencode 本身**
  </action>
  <verify>cd flow-kit-bundle && bash -c 'source hooks/stop/lib/common.sh; (unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY FLOW_KIT_L3_AUTH_TOKEN FLOW_KIT_L3_BASE_URL OPENCODE OPENCODE_BIN; set +e; fk_resolve_api_credentials; echo "rc=$?"); (unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY OPENCODE OPENCODE_BIN; set +e; FLOW_KIT_L3_AUTH_TOKEN=t FLOW_KIT_L3_BASE_URL=u OPENCODE=1 fk_resolve_api_credentials; test "$?" -eq 0 -a "$FK_API_BASE_URL" = "u" && echo "opencode-path3 OK" || { echo "opencode-path3 FAIL"; exit 1; }); (unset FLOW_KIT_L3_AUTH_TOKEN OPENCODE OPENCODE_BIN; set +e; ANTHROPIC_AUTH_TOKEN=t OPENCODE=1 fk_resolve_api_credentials; test "$?" -eq 0 -a "$FK_API_AUTH_SCHEME" = "bearer" && echo "opencode-path1-fallback OK" || { echo "FAIL"; exit 1; })'</verify>
  <done>fk_resolve_api_credentials 在 OPENCODE=1 时 Path3 命中优先于 Path1（FK_API_BASE_URL=FLOW_KIT_L3_BASE_URL）；OPENCODE 未设时 Path1 优先（CC 零回归）；Path2 短路 + rc=2 语义不变</done>
  <depends_on></depends_on>
</task>

<task id="T02-rev" parallel="true">
  <name>transcript-parser.sh 工具名双平台兼容（AC-4b · R2 修复）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/transcript-parser.sh
    .specs/l2l3-cross-platform/REQUIREMENT.md
    .specs/l2l3-cross-platform/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/transcript-parser.sh
  </write_files>
  <action>
    jq 过滤器双形状兼容：
    - CC 形状：`select(.type == "tool_use" and .tool == "Agent")` + `.args.subagent_type`
    - opencode 形状：`select(.type == "tool" and .tool == "task")` + 归类字段 `state.input.category`（AC-4/AC-4b 实测形状——opencode part 记录 `{"type":"tool","tool":"task","state":{"input":{"category":...}}}`）
    - 合并为单条 jq 表达式：`(.type == "tool_use" and .tool == "Agent") or (.type == "tool" and .tool == "task")` + `(if .tool == "task" then (.state.input.category // .args.category // "general-purpose") else (.args.category // .args.subagent_type // "general-purpose") end)`
    - 注释更新说明双形状语义
    - **不改函数签名、不改输出文件路径（subagent-usage.txt）、不破坏既有 CC 回归**
  </action>
  <verify>cd flow-kit-bundle && bash -c 'echo "{\"type\":\"tool_use\",\"tool\":\"Agent\",\"args\":{\"subagent_type\":\"qa-expert\"}}" | jq "(.type == \"tool_use\" and .tool == \"Agent\") or (.type == \"tool\" and .tool == \"task\")" && echo "{\"type\":\"tool\",\"tool\":\"task\",\"state\":{\"input\":{\"category\":\"unspecified-high\"}}}" | jq "(.type == \"tool_use\" and .tool == \"Agent\") or (.type == \"tool\" and .tool == \"task\")"' && bash -n hooks/stop/lib/transcript-parser.sh</verify>
  <done>✅ 已完成（2026-08-08 · 证据见 T02-rev-SUMMARY.md）：jq 过滤器匹配 CC `.tool=="Agent"` 和 opencode `.tool=="task"` 两种形状（verify 双 true + bash -n 通过）；归类字段按工具类型分流（task → state.input.category，CC → args.subagent_type，兜底 general-purpose，7 输入 mock 全分支验证）；CC 回归不破坏（test_l2_dispatch_mode.bats 12/12 全绿）</done>
  <depends_on></depends_on>
</task>

## Wave 2（dep Wave 1）

<task id="T03-rev" parallel="false">
  <name>bats 测试扩展：平台翻转矩阵 + AC-4b 工具名形状 + AC-6 断言</name>
  <read_files>
    flow-kit-bundle/test/test_l3_credential_resolution.bats
    flow-kit-bundle/test/test_l2_dispatch_mode.bats
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/transcript-parser.sh
    .specs/l2l3-cross-platform/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_l3_credential_resolution.bats
    flow-kit-bundle/test/test_l2_dispatch_mode.bats
  </write_files>
  <action>
    三项扩展：
    1. **AC-2 平台翻转矩阵**（test_l3_credential_resolution.bats 新增 ≥3 用例）：
       - opencode + Path3 + Path1 同时设置 → Path3 命中（FK_API_BASE_URL=FLOW_KIT_L3_BASE_URL）
       - opencode + Path1 + Path3 缺失 → Path1 兜底（CC 回归路径在 opencode 下也能走）
       - CC + Path1 + Path3 同时设置 → Path1 命中（零回归）
       - setup 用 `OPENCODE=1` / `env -u OPENCODE -u OPENCODE_BIN` 切换平台
    2. **AC-4b 工具名双形状**（test_l2_dispatch_mode.bats 新增 ≥2 用例）：
       - mock CC jsonl `{"type":"tool_use","tool":"Agent","args":{"subagent_type":"code-reviewer"}}` → subagent-usage.txt 含 `code-reviewer`
       - mock opencode jsonl `{"type":"tool","tool":"task","state":{"input":{"category":"unspecified-high"}}}` → subagent-usage.txt 含 `unspecified-high`（jq 路径定稿 `state.input.category`——与 AC-4 mock + AC-4b + D4 + §9.3 一致，IR-3 R-1 修复）
    3. **AC-6 bats 断言**（test_l3_credential_resolution.bats 新增 2 用例 · R-F-A1 修复格式）：
       - `@test "AC-6 redline: no token values in runtime files"`：`run grep -rsE "=sk-[A-Za-z0-9]{8,}|=[A-Za-z0-9+/]{32,}={0,2}" .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null; [ -z "$output" ]`（无输出=零命中=通过）
       - `@test "AC-6 redline: no env names in runtime files"`：`run grep -rsE "FLOW_KIT_L3_AUTH_TOKEN|FLOW_KIT_L3_BASE_URL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY" .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null; [ -z "$output" ]`
       - **扫描范围不含 INDEPENDENT-REVIEW-*.md（R-F-A2 修复）**
    4. 既有 17+7 用例保留不删（R5.3 禁删弱化）
  </action>
  <verify>~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats flow-kit-bundle/test/test_l3_credential_resolution.bats flow-kit-bundle/test/test_l2_dispatch_mode.bats</verify>
  <done>✅ 已完成（2026-08-08 · 证据见 T03-rev-SUMMARY.md）：平台翻转矩阵 3 用例（opencode P3>P1 并存取 P3 / opencode P3 缺失 P1 兜底 / CC P1>P3 零回归）+ AC-4b 工具名双形状 2 用例（CC subagent_type + opencode state.input.category）+ AC-6 红线 2 用例（R-F-A1 格式 · 范围不含 INDEPENDENT-REVIEW-*.md）全绿；bats 36/36 exit 0，既有 17+12 用例零回归；只改 2 个 write_files，未 commit</done>
  <depends_on>T01-rev, T02-rev</depends_on>
</task>

## Wave 3（dep Wave 2）

<task id="T04-rev" parallel="false">
  <name>双源同步 + 全量回归 + AC-6 红线 + make check + 打包源实跑</name>
  <read_files>
    flow-kit-bundle/test/*
    test/*
    .specs/l2l3-cross-platform/REQUIREMENT.md
    .specs/l2l3-cross-platform/TASK.md
  </read_files>
  <write_files>
    test/test_l3_credential_resolution.bats
    test/test_l2_dispatch_mode.bats
  </write_files>
  <action>
    1. 双源同步：`cp` T03-rev 产出的更新版 bats 到 test/（或 make test-sync）
    2. 全量 dev 源回归：`~/.npm/_npx/.../bats test/`（二进制路径避开 npx 卡网络）→ 全绿
    3. AC-6 红线双断言（REQUIREMENT AC-6 验证方式原文 · R-F-A1 修订）：
       - ① token 值模式 `[ -z "$(grep -rsE '=sk-[A-Za-z0-9]{8,}|=[A-Za-z0-9+/]{32,}={0,2}' .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null)" ]`
       - ② env 名模式 `[ -z "$(grep -rsE 'FLOW_KIT_L3_AUTH_TOKEN|FLOW_KIT_L3_BASE_URL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY' .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null)" ]`
       - **不含 INDEPENDENT-REVIEW-*.md（R-F-A2 修复：第三方写入不可控）**
    4. make check 四门全绿（lint / check-validate / check-test-sync / test）
    5. **打包源逐文件实跑**（AC-8 修订 · R1 教训）：`~/.npm/_npx/.../bats flow-kit-bundle/test/`（排除 quality_baseline.bats 单独 ≥120s timeout 跑）→ 全绿
    6. 刷新 T12 done 标记为本次实跑证据
  </action>
  <verify>~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats test/ && make check && [ -z "$(grep -rsE '=sk-[A-Za-z0-9]{8,}|=[A-Za-z0-9+/]{32,}={0,2}' .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null)" ] && [ -z "$(grep -rsE 'FLOW_KIT_L3_AUTH_TOKEN|FLOW_KIT_L3_BASE_URL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY' .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null)" ]  <!-- R-F-A1/R-F-A2 修订：-z "$output" 判空 + 不含审查报告 --></verify>
  <done>✅ 已完成（2026-08-08 · 证据见 T04-rev-SUMMARY.md）：双源同步（cp 两文件 diff 零差异）+ dev 源全量回归 752/752 全绿 + 打包源 66 文件逐文件实跑全绿 + AC-6 双红线 PASS（token 值 + env 名零命中，含 INDEPENDENT-REVIEW token 值一次性验证）+ make check 四门全绿（lint / check-validate / check-test-sync / test）+ done 标记已刷新；quality_baseline.bats 当前双源不存在（66 文件双源一致）故无 ≥120s 特殊分支</done>
  <depends_on>T03-rev</depends_on>
</task>

---

## 波次划分

```
Wave 1 (parallel): T01-rev[P], T02-rev[P]
Wave 2:            T03-rev (depends on T01-rev, T02-rev)
Wave 3:            T04-rev (depends on T03-rev)
```

## 执行说明

- **二进制 bats 路径**：`~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats`（npx 包装卡网络，全量测试用此）
- **quality_baseline.bats**：单独跑需 ≥120s timeout（内嵌 `run npx bats test/test_stop_chain.bats` 卡网络）
- **禁动例外**：package-flow-kit.sh 已在第一轮验证零改动（rsync -a 自动覆盖 .opencode/），本轮无需触碰
- **已有 done 标记**：第一轮 T01-T12 + T-FIX-01 的 done 标记已归档（本轮不复制旧 done）
- **R-4 归类路径**：已定稿 `state.input.category`（与 AC-4/AC-4b + DESIGN D4/§9.3 一致 · IR-3 R-1 修复）
- **AC-6 base64 锚定**（IR-3 R-3 修复）：base64 分支加 `=` 前缀（`=[A-Za-z0-9+/]{32,}={0,2}`），防 commit_sha 40-hex 等裸十六进制串假阳性；JSON 式泄漏由 env 名红线（②）兜底
