# TASK: 加固 toll-gate 不可绕过性 + 扩展 L2 独立审查到 3/5/7

- **Change ID**: gate-integrity
- **关联**: `@.specs/gate-integrity/REQUIREMENT.md`（AC-1~6）、`@.specs/gate-integrity/DESIGN.md`（D1-D10 / R1-R12）、`@.specs/CONTEXT.md`
- **栈**: Bash + bats-core（DESIGN §0）

> 拆解依据：DESIGN §0.5.1 触碰/新增/禁动清单 + D1-D10 决策 + AC-1~6。
> 特点：多数改动聚类于 `independent-review-gate.sh` / `flow-kit-artifacts.sh` / `29-independent-review.sh` → Wave 2 主要串行；独立文件（SKILL.md / check-gate-sync.sh / pipeline-gates.md / demos）Wave 1 并行。
> AC-6 三处修复（CONFIG_FILE 回退 / 00-gate 调度 27-28-29 / 29号 追加+fail_count）**已在树**，本 TASK 不重复，仅补 l3_token 哈希 + 握手字段（T12）。

---

## 波次划分

```
Wave 1 (parallel · 独立文件): T01[P], T02[P], T03[P], T04[P]
Wave 2 (serial · hook 核心，文件聚类): T05 → T06 → T07 → T08 → T09 → T10 → T11
Wave 3 (parallel · 测试 + AC-6 补完): T12[P], T13[P]
Wave 4 (final · 全量回归): T14
```

---

## Wave 1 · 独立文件（并行）

<task id="T01" parallel="true">
  <name>AC-4 PRESET_MAP 扩展 + all 预设 + 数字映射 3/5/7</name>
  <read_files>
    flow-kit-bundle/skills/flow/SKILL.md
    .specs/gate-integrity/adr/G4-gate-config-357.md
    flow-kit-bundle/test/test_gate_config_presets.bats
    ~/.claude/skills/flow/SKILL.md
  </read_files>
  <write_files>
    flow-kit-bundle/skills/flow/SKILL.md
    flow-kit-bundle/test/test_gate_config_presets.bats
  </write_files>
  <action>
    SKILL.md 维护源（flow-kit-bundle/skills/flow/SKILL.md）PRESET_MAP（:132-150）：数字映射扩 3→3-task / 5→5-test / 7→7-integration；新增 `all` 预设 = {1,2,3,5,6,7}（含 7-integration，0/4 排除）；`full` 不变（仅 1/2/6）。test_gate_config_presets.bats 扩 `resolve_gate_config()` 镜像（数字 case 加 3/5/7 + 预设 case 加 `all` 分支）+ 用例（all / full vs all 区分 / 数字 3/5/7）。改完跑 `bash flow-kit-bundle/install.sh`（user-scope 部署）+ diff 验证 ~/.claude/skills/flow/SKILL.md 与维护源一致（L-015 合规：改源不改进运行时）。
  </action>
  <verify>cd flow-kit-bundle && npx bats test/test_gate_config_presets.bats</verify>
  <done>`all` 含 7-integration、`full` 不变、数字 3/5/7 映射正确；现有 20 tests 不破坏 + 新增用例通过；install.sh 部署后 ~/.claude 运行时与维护源 diff 一致（L-015） ✅ [DONE 2026-07-02 · T01-SUMMARY.md]</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>check-gate-sync.sh 重写为语义 set-diff（D3 / L2-R3 R4）</name>
  <read_files>
    flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
    .specs/gate-integrity/adr/G4-gate-config-357.md
    flow-kit-bundle/test/test_gate_config_presets.bats
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
    flow-kit-bundle/test/test_check_gate_sync.bats
  </write_files>
  <action>
    重写 check-gate-sync.sh：用 `source <(sed 提取 SKILL.md PRESET_MAP 代码块) + declare -p PRESET_MAP` 提取预设名集合 ↔ bats 镜像 resolve_gate_config() 支持集合，set-diff 不等 → exit 1（非文本段 diff）。新增 bats：故意改 SKILL.md 不改 bats → 脚本 exit 1。
  </action>
  <verify>npx bats flow-kit-bundle/test/test_check_gate_sync.bats</verify>
  <done>脚本对预设名集合漂移 exit 1；对一致 exit 0；不再依赖文本段 marker ✅ [DONE 2026-07-02 · T02-SUMMARY.md]</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true">
  <name>AC-2 pipeline-gates.md 扩全链 gate key transition 语义</name>
  <read_files>
    flow-kit-bundle/flow-kit/reference/pipeline-gates.md
    .specs/gate-integrity/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/reference/pipeline-gates.md
  </write_files>
  <action>
    现 pipeline-gates.md（53 行）自述范围仅 4-dev。扩展为覆盖全链 gate key（0→1 ... 6→7）的 transition 校验语义：transition 前置查 `goal.gates["N→N+1"]` 非 passed 则拒；保留 4-dev 作参考实例段（R6）。
  </action>
  <verify>grep -c 'gate key\|transition' flow-kit-bundle/flow-kit/reference/pipeline-gates.md | grep -qv '^1$' && echo OK</verify>
  <done>全链 7 个 gate key transition 语义齐；4-dev 段保留 ✅ [DONE 2026-07-02 · T03-SUMMARY.md]</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true">
  <name>regression-demos 创建（7 demo + check.sh）</name>
  <read_files>
    .specs/gate-integrity/REQUIREMENT.md
    .specs/gate-integrity/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/test/regression-demos/empty-done/setup.sh
    flow-kit-bundle/test/regression-demos/empty-done/check.sh
    flow-kit-bundle/test/regression-demos/forged-done/check.sh
    flow-kit-bundle/test/regression-demos/hijack-done/check.sh
    flow-kit-bundle/test/regression-demos/tampered-done/check.sh
    flow-kit-bundle/test/regression-demos/gate-config-tamper/check.sh
    flow-kit-bundle/test/regression-demos/skipped-subprocess/check.sh
    flow-kit-bundle/test/regression-demos/exotic-escape/check.sh
    flow-kit-bundle/test/regression-demos/README.md
  </write_files>
  <action>
    7 个 demo 对应 AC-1 威胁①②③④⑤⑥ + skipped-subprocess（T3/T4 时机）+ exotic-escape（文档化 v1 不挡的 Bash 逃逸向量）。每个 check.sh 断言 hook 行为（拒绝/放行）。README 列每个 demo 对应的威胁 + v1 立场。
  </action>
  <verify>cd flow-kit-bundle/test/regression-demos && for d in */; do bash "$d/check.sh" || echo "FAIL $d"; done</verify>
  <done>7 demo 目录 + check.sh 齐全；README 映射威胁表 ✅ [DONE 2026-07-02 · T04-SUMMARY.md]</done>
  <depends_on></depends_on>
</task>

---

## Wave 2 · hook 核心（串行 · 文件聚类）

<task id="T05" parallel="false">
  <name>AC-3 阶段判定 + case 映射 5 站点同步扩 3/5/7（D6）</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    .specs/gate-integrity/adr/G2-dynamic-gate-config.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
  </write_files>
  <action>
    grep 实证 5 站点：正则 `^(1|2|6)$`（gate.sh:39 / 29号:33 / artifacts.sh:109）+ case phase_name（gate.sh:58-60 / artifacts.sh:117-119）同步扩 `^(1|2|3|5|6|7)$` + case 补 3-task/5-test/7-integration。阶段判定改动态读 `.flow-active.goal.gate_config["<phase_name>"]`（G2）。
  </action>
  <verify>cd flow-kit-bundle && grep -L '3|5|7' hooks/pre-tool-use/independent-review-gate.sh hooks/stop/29-independent-review.sh hooks/stop/lib/flow-kit-artifacts.sh || echo "all 5 sites updated"</verify>
  <done>5 站点全扩 3/5/7；阶段判定动态读 gate_config；bats 断言 5 站点覆盖（T13 补）✅ [DONE 2026-07-02 · T05-SUMMARY.md]</done>
  <depends_on></depends_on>
</task>

<task id="T06" parallel="false">
  <name>fk_validate_done_marker 两层时机校验函数（D1/D5 · G1）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    .specs/gate-integrity/adr/G1-done-authenticity.md
    .specs/gate-integrity/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
  </write_files>
  <action>
    新建 `fk_validate_done_marker <path> <phase> <change_id> <tier>`（tier=write|transition）。Tier 1：phases_done 短路 + T1 非空 + T2 KVP（phase/change_id/written_by）。Tier 2：T3 握手锚点（.flow-active.independent-review written_by=stop-hook-29 + verdict 与 .done L3_verdict 一致）+ T3b session_id 跨会话 + T4 L2_verdict 与 .md 比对。artifacts 序列化 = 空格分隔。
  </action>
  <verify>cd flow-kit-bundle && bash -c 'source hooks/stop/lib/flow-kit-artifacts.sh 2>/dev/null; type fk_validate_done_marker'</verify>
  <done>函数签名 + Tier 1/2 逻辑齐；fail-close on 解析异常（D9 · T10 强化）✅ [DONE 2026-07-02 · T06-SUMMARY.md]</done>
  <depends_on>T05</depends_on>
</task>

<task id="T07" parallel="false">
  <name>D7 PreToolUse matcher 扩面 + is_handshake_write path-guard（D7/D9）</name>
  <read_files>
    flow-kit-bundle/hooks/lib/install_hooks.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    .specs/gate-integrity/adr/G1-done-authenticity.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/lib/install_hooks.sh
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    install_hooks.sh:136/153 matcher 从 "Bash" 扩 `["Bash","Write","Edit"]`。gate.sh 增 `is_handshake_write`：Write/Edit tool 目标 file_path 含 `.flow-active.independent-review` → deny；Bash 命令匹配写该路径正则（`>`/`>>`/`tee`/`cp`/`mv`/`sed -i`/`dd of=`/`printf`/`awk..>`/`install`/heredoc）→ deny。path-guard 段 **fail-open**（lib 失败 exit 0，D9）。29号 hook 子进程直写放行（不经 agent tool）。
  </action>
  <verify>cd flow-kit-bundle && test/regression-demos/forged-done/check.sh && test/regression-demos/exotic-escape/check.sh</verify>
  <done>Write/Edit/Bash 三类写向量拦常见路径；29号写放行；path-guard fail-open✅ [DONE 2026-07-02 · T07-SUMMARY.md]</done>
  <depends_on>T06</depends_on>
</task>

<task id="T08" parallel="false">
  <name>D7 29号握手写入 l3_token + written_by（补 AC-6）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    .specs/gate-integrity/adr/G1-done-authenticity.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    29号 state_file（.flow-active.independent-review）写握手完整字段：`{phase, status:"done", verdict, l3_token:<hash(L3响应原文)>, written_by:"stop-hook-29", written_at}`。l3_token 用 sha256（可用 `sha256sum`/`openssl`）。AC-6 已修的追加（>>）+ fail_count 保留。
  </action>
  <verify>cd flow-kit-bundle && bash -c 'grep -q "written_by=stop-hook-29\|l3_token" hooks/stop/29-independent-review.sh'</verify>
  <done>握手含 written_by + l3_token；追加 + fail_count 不破坏 ✅ [DONE 2026-07-02 · T08-SUMMARY.md]</done>
  <depends_on>T07</depends_on>
</task>

<task id="T09" parallel="false">
  <name>D8 ⑥ gate_config 篡改检测 + .goal-snapshot.json（G3）</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    ~/.claude/skills/flow/SKILL.md
    .specs/gate-integrity/adr/G3-gate-config-tamper-detection.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    ~/.claude/skills/flow/SKILL.md
  </write_files>
  <action>
    gate.sh 增 `fk_check_gate_config_tamper`：transition 时 diff `.flow-active.goal.gate_config` 与 `.specs/<id>/.goal-snapshot.json`，phase key 由 independent→false/缺失 → deny exit 2。/flow goal skill 创建 goal 时写 `.specs/<id>/.goal-snapshot.json`（gate_config 副本 + created_at，入库）。fail-close（D9）。
  </action>
  <verify>cd flow-kit-bundle && test/regression-demos/gate-config-tamper/check.sh</verify>
  <done>篡改 gate_config 关 gate → transition deny；快照写 .specs（入库）✅ [DONE 2026-07-02 · T09-SUMMARY.md]</done>
  <depends_on>T08</depends_on>
</task>

<task id="T10" parallel="false">
  <name>D9 fail 策略区分（校验 fail-close / path-guard fail-open）</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    .specs/gate-integrity/adr/G1-done-authenticity.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
  </write_files>
  <action>
    明确分段：path-guard（is_handshake_write）= fail-open（T07 已）；Tier 1/2 校验（fk_validate_done_marker）+ ⑥检测 = fail-close（jq 不可用/source 失败/解析异常 → exit 2 deny + 可读错误）。bats 覆盖畸形 .flow-active 输入（agent 不能靠制造 hook 内部错误放行）。
  </action>
  <verify>cd flow-kit-bundle && echo '{broken' > /tmp/.flow-active.malformed && bash -c 'source hooks/stop/lib/flow-kit-artifacts.sh; fk_validate_done_marker /tmp/.flow-active.malformed 2 test transition; echo "exit=$?"' | grep -q 'exit=2' && echo OK</verify>
  <done>校验段畸形输入 deny exit 2；path-guard 段失败 exit 0 ✅ [DONE 2026-07-02 · T10-SUMMARY.md]</done>
  <depends_on>T09</depends_on>
</task>

<task id="T11" parallel="false">
  <name>D10 phases_done 合法写入通路（is_phase_write 扩拦）</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    .specs/gate-integrity/adr/G1-done-authenticity.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    is_phase_write 扩拦 `.goal.phases_done` 写信号（agent 经 Bash/Write/Edit 写该字段 → deny）。transition hook 子进程独占写 phases_done（与 29号独占写握手同模式）。合法 phase 推进走 hook 子进程（dogfood 本 change transition 也走此通路，不自卡）。
  </action>
  <verify>cd flow-kit-bundle && bash -c 'cmd="jq \".goal.phases_done += [\\\"3\\\"]\" .flow-active"; source hooks/pre-tool-use/independent-review-gate.sh >/dev/null 2>&1; is_phase_write "$cmd" && echo BLOCKED || echo LEAK'</verify>
  <done>agent jq phases_done 被拦；transition hook 子进程能写 ✅ [DONE 2026-07-02 · T11-SUMMARY.md]</done>
  <depends_on>T10</depends_on>
</task>

---

## Wave 3 · 测试 + AC-6 补完（并行）

<task id="T12" parallel="true">
  <name>AC-6 补完：29号删残留 dump + l3_token 哈希落地</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    .specs/gate-integrity/INDEPENDENT-REVIEW-2.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    AC-6 已修追加/fail_count/CONFIG_FILE/调度。本任务补：29号 L3 段不写原始 API JSON（仅解析后报告）；l3_token 用 sha256 落地（T08 写入字段，本任务确保算法实现 + 不 dump）。核对 INDEPENDENT-REVIEW-2.md L3 段无 `<details>` 原始 JSON 残留。
  </action>
  <verify>cd flow-kit-bundle && grep -c 'id.*msg_\|"stop_reason"' hooks/stop/29-independent-review.sh | grep -q '^0$' && echo "no dump OK"</verify>
  <done>29号不 dump 原始 API JSON；l3_token=sha256 实现 ✅ [DONE 2026-07-02 · T12-SUMMARY.md]</done>
  <depends_on>T08</depends_on>
</task>

<task id="T13" parallel="true">
  <name>test_gate_integrity.bats 主测试套（6 类威胁 + 5 站点 + D7-D10）</name>
  <read_files>
    flow-kit-bundle/test/test_gate_integrity.bats
    flow-kit-bundle/test/test_stop_chain.bats
    flow-kit-bundle/test/test_common.bats
    .specs/gate-integrity/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_gate_integrity.bats
  </write_files>
  <action>
    整合 T05-T11 的 bats：6 类威胁用例（empty/forged/hijack/tampered/gate-config-tamper + skipped-subprocess 时机 + exotic-escape 文档化）+ 5 站点 case 覆盖 + D7 path-guard（Write/Edit/Bash 三向量）+ D8 ⑥检测 + D9 fail-close/fail-open + D10 phases_done 拦截。每个 AC（1~6）至少 1 用例。
  </action>
  <verify>cd flow-kit-bundle && npx bats test/test_gate_integrity.bats</verify>
  <done>AC-1~6 全覆盖；D7-D10 行为断言；exotic-escape 标 skip 或文档化 ✅ [DONE 2026-07-02 · T13-SUMMARY.md]</done>
  <depends_on>T11</depends_on>
</task>

---

## Wave 4 · 全量回归

<task id="T14" parallel="false">
  <name>AC-5 全量 bats 不回归 + check-gate-sync 通过</name>
  <read_files>
    flow-kit-bundle/test/
    .specs/gate-integrity/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_gate_integrity.bats
  </write_files>
  <action>
    跑全量 `npx bats test/`：基线 213 + 本 change 新增全过；12 个预先存在失败（correction-file / AC-7）不新增。check-gate-sync.sh 通过（SKILL.md ↔ bats 镜像一致）。统计总数 = 213 + 新增。
  </action>
  <verify>cd flow-kit-bundle && npx bats test/ 2>&1 | tail -3 && bash scripts/check-gate-sync.sh && echo "GATE-SYNC OK"</verify>
  <done>全量 bats exit 0（12 预存失败不计）；check-gate-sync 通过；总数 = 基线 + 新增 ✅ [DONE 2026-07-02 · T14-SUMMARY.md · bats 216total/12预存/0新增 ✅；check-gate-sync 预设名✅ PCSC预存漂移非本change]</done>
  <depends_on>T12,T13</depends_on>
</task>

---

## 自检

- [x] 每任务 7 字段齐全（id/name/read_files/write_files/action/verify/done）
- [x] write_files 全在 DESIGN §0.5.1 触碰/新增范围
- [x] 无 write_files 含禁动清单（package-flow-kit.sh / flow-kit-bundle.tar.gz / .gitignore）
- [x] 每任务 verify 可执行
- [x] Wave 1 有 4 个 [P] 并行任务
- [x] 波次图无环依赖（Wave 2 线性 T05→T11；Wave 3 依赖 T11/T08；Wave 4 依赖 T12/T13）
- [x] 任务编号连续 T01-T14
