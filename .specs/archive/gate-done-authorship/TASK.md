# TASK: 独立 review gate `.done` 作者性校验缺口修复

- **Change ID**: gate-done-authorship
- **关联**: `@.specs/gate-done-authorship/REQUIREMENT.md`、`@.specs/gate-done-authorship/DESIGN.md`、`@.specs/CONTEXT.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P]
  ├── T01 重写 path-guard D7 + 删 is_handshake_write + 新增 _is_dotdone_write + L2-only 例外
  ├── T02 删 done-validation.sh T3/T3b 握手段
  └── T03 删 29-independent-review.sh state_file 读/删 + 幂等改用 .done 存在性
  （三任务改不同文件，无文件冲突 → 并行）

Wave 2 (parallel): T04[P] (deps T01,T02,T03) ‖ T05[P] (deps T01)
  ├── T04 重写 test_gate_integrity.bats（4 done-validation + 6 D7 单元 + 3 新增集成）+ 双源同步
  └── T05 清理 test/regression-demos/tampered-done + exotic-escape 握手 demo（双源）
  （改 test_gate_integrity.bats vs regression-demos/，无文件冲突 → 并行）

Wave 3: T06 (depends on T04, T05)
  └── T06 全量回归 make test + 死代码 grep 验证 + 0 fail 确认
```

依赖图（无环）：
```
T01 ──┬──> T04 ──┐
T02 ──┤          ├──> T06
T03 ──┤     │
       └──> T05 ──┘
```

---

## 任务清单（XML）

### Wave 1

```xml
<task id="T01" parallel="true">
  <name>重写 path-guard D7 保护 .done + 删 is_handshake_write + 新增 _is_dotdone_write + L2-only 例外</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    .specs/gate-done-authorship/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  </write_files>
  <action>
    1. 删除 is_handshake_write() 函数定义（L41-55）+ 其调用点（L190 块）。
    2. 新增 _is_dotdone_write() <cmd> 函数：检测 Bash 命令是否写 .independent-review-*.done。
       - 文件名匹配用 glob *.independent-review-*.done*（双通配，L2 R5 已记录误报面 → v2 细化）
       - 写路径匹配继承 is_handshake_write 的 11 种模式（> / >> / tee / cp / mv / sed -i / printf / dd of= / install / awk / heredoc，见 is_handshake_write L43-54 + DESIGN §2.2）
       - regex-in-variable 风格（local re='...'; [[ "$c" =~ $re ]]），遵循 TD-011/015 约定
    3. 新增 _gate_is_l2_only(phase, cwd) 函数：查 gate_config 对应 phase_name，值为 L2 则放行。
       - 阶段号来源（L2 R2 落地）：从 Write/Edit 的 $file_path 或 Bash 的 $cmd 通过 glob 提取 <N>，
         file_path match *.independent-review-<N>.done → phase=N
       - gate_config key 组装：用 fk_phase_gate_key "$N"（common.sh:284 单一源，gate.sh 已 source common.sh · ADR-007/D1），不新增任何 phase→key 映射表
       - gate_config 值读取：local phase_name; phase_name="$(fk_phase_gate_key "$N")"; jq -r --arg pn "$phase_name" '.goal.gate_config[$pn] // "off"' "$flow_file"
       - 读取失败（jq error / flow_file 不存在 / key 缺失）→ fail-open 放行（D3 决策，DESIGN D3 已论证 both/L3 误放端到端不可利用）
    4. 重写 _gate_path_guard()（L180-199）：
       - Write/Edit 工具 → file_path match *.independent-review-*.done → 查 _gate_is_l2_only → L2 则放行，否则 exit 2
       - Bash 工具 → _is_dotdone_write(cmd) 命中 → 同 L2-only 例外逻辑 → 否则 exit 2
       - 拒绝消息更新：原"禁止直接写 .flow-active.independent-review"改为"禁止直接写 .independent-review-*.done（作者性锚点）"
       - 保留 fail-open（D7 path-guard 拦不住不卡 agent 工具流）
    5. 更新文件头注释（L1-15）：path-guard 描述从"写 .flow-active.independent-review 握手文件"改为"写 .independent-review-*.done（作者性锚点）"。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && grep -c "is_handshake_write" flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh | grep -qx 0 && grep -q '_is_dotdone_write()' flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh && grep -q '_gate_is_l2_only()' flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh</verify>
  <done>is_handshake_write 全删；_is_dotdone_write + _gate_is_l2_only 新增（verify 验函数定义存在）；bash -n 语法通过；0 处 is_handshake_write 残留</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>删 done-validation.sh Tier 2 T3/T3b 握手校验段</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    .specs/gate-done-authorship/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </write_files>
  <action>
    1. 删除 T3 D7 握手锚点段（L140-149）：读 ${flow_file}.independent-review 握手文件 + 验 written_by=stop-hook-29 + 验 hs_verdict==l3v。
    2. 删除 T3b SESSION_ID 跨会话锚点段（L151-157）：cur_sid/done_sid 比对。
    3. 保留 Tier 2 的 T4 L2_verdict vs INDEPENDENT-REVIEW-N.md 比对段（L160+，L2-first gating 调度契约依赖）。
    4. 保留 Tier 1 元数据快校验（L111-135，非空 + KVP + 值域）不变。
    5. 保留 phases_done 短路（L102-109）不变。
    6. 更新 fk_validate_done_marker 注释（L91-95）：Tier 2 描述移除"T3 握手校验"，改为"作者性由 path-guard D7 前置保证，Tier 2 仅保留 T4 L2 比对"。
    注意：T3 删除后 tier="transition" 路径仅余 T4（若 tier=write 则 L137 return 0 不进 Tier 2）。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/done-validation.sh && ! grep -q "written_by=stop-hook-29\|hs_path\|hs_wby\|hs_verdict\|T3 D7 握手\|T3b SESSION_ID" flow-kit-bundle/hooks/stop/lib/done-validation.sh && grep -q 'T4 L2_verdict\|fk_extract_l2_verdict\|INDEPENDENT-REVIEW' flow-kit-bundle/hooks/stop/lib/done-validation.sh</verify>
  <done>T3/T3b 握手段全删；T4 L2 比对段保留（verify 验 T4 token 在位）；bash -n 通过；0 处握手引用残留</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true">
  <name>删 29-independent-review.sh state_file 读/删 + 幂等改用 .done 存在性</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    .specs/gate-done-authorship/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    1. 删除 Gate 4 幂等读 state_file 段（L68-74）：state_file 变量定义 + 读 .flow-active.independent-review + prev_status==done 判断。
    2. 替换为 .done 文件存在性幂等：done_marker="${PROJECT_ROOT}/.specs/${change_id}/.independent-review-${phase}.done"；[[ -f "$done_marker" ]] && exit 0。
       （D4 决策：.done 是唯一 anchor，存在即表示 L3 已完成）
    3. 删除 L203-204 的 state_file 重新赋值 + rm -f "$state_file"（注释 L202"清理旧握手文件"一并删）。
    4. **Gate 5（L121-128）显式处理**：原 Gate 5 含 L125 `rm -f "$state_file"`（清理握手文件）+ module_output 日志。.done 短路语义已被 T03 新增的 Gate 4 覆盖，Gate 5 中的 `rm -f "$state_file"` 引用已删的 state_file 变量 → `set -euo pipefail`（L13）下若该死分支被触及抛 unbound variable 错。
       处理：删 L125 `rm -f "$state_file"`；若 Gate 5 的 module_output 日志语义与 Gate 4 重复则并入 Gate 4，否则保留日志行但移除 state_file 引用。
    5. 保留其余 L3 审查触发逻辑（l3_review_run 调用、_l3_scan_backlog、其余 module_output 报告）不变。
    6. 确认 change_id / phase 变量在幂等检查点已定义（M3 落地）：先 grep 确认 change_id 在 Gate 4 幂等检查点之前已赋值；若原有代码 change_id 在幂等检查后才解析，将幂等检查移至 change_id 赋值之后。done_marker 定义必须在 change_id 赋值之后，避免空变量致路径错误。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/29-independent-review.sh && ! grep -q 'state_file="\|\.flow-active\.independent-review"\|rm -f "\$state_file"' flow-kit-bundle/hooks/stop/29-independent-review.sh && grep -q "independent-review-\${phase}.done" flow-kit-bundle/hooks/stop/29-independent-review.sh && awk '/change_id=/{found=1} /independent-review-\${phase}.done/{ if(found){print "ok"; exit} else {print "ORDER_ERR"; exit 1} }' flow-kit-bundle/hooks/stop/29-independent-review.sh</verify>
  <done>state_file 读/删全删；幂等改用 .done 存在性；bash -n 通过；0 处 state_file/.flow-active.independent-review 残留</done>
  <depends_on></depends_on>
</task>
```

### Wave 2

```xml
<task id="T04" parallel="true">
  <name>重写 test_gate_integrity.bats 4 握手测试 + 新增 payload 注入集成测试</name>
  <read_files>
    test/test_gate_integrity.bats
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
    .specs/gate-done-authorship/REQUIREMENT.md
    .specs/gate-done-authorship/DESIGN.md
  </read_files>
  <write_files>
    test/test_gate_integrity.bats
  </write_files>
  <action>
    改写 4 个握手测试为新语义（.done 作者性，对应 REQUIREMENT AC-1/AC-2/AC-5）：
    1. AC-1 ②③ forged-done：改写为"agent 通过 Bash/Write 写 .independent-review-<N>.done → path-guard 拦截 exit 2"。覆盖 Write/Edit + Bash（cat heredoc / > redirect / tee）三通道。
    2. AC-1 ④ hijack：改写为"agent 在子目录写后 mv 到 .done → path-guard 拦截 mv"。
    3. AC-1 ⑤ tampered：改写为"agent 用 sed -i 改 .done → path-guard 拦截 sed -i"。
    4. D9 正向：验证 l3_review_run 写 .done 不被 path-guard 拦截——**此放行是架构天然隔离**（l3_review_run 在 Stop hook 进程运行，不经过 PreToolUse hook，path-guard 根本不执行），非代码级分支。T04 不直接调 _gate_path_guard 验证此路径（那会误导需要代码级放行逻辑），而是通过 AC-6 payload 注入测试间接验证（PreToolUse 拦截 agent 写 .done 但 Stop hook 写 .done 不受影响——两路径的互补正确性）。若需单元级验证，通过 source gate.sh + 确认 _gate_path_guard 无 l3_review_run 特殊分支（正确行为：path-guard 对所有写入 .done 的 Bash/Write/Edit 统一拦截，l3_review_run 因不经过 PreToolUse 天然绕过）。
    D7 path-guard 单元测试改写（6 个，L173-201，原 run is_handshake_write）：
    5. 6 个 D7 单元测试全部改写为 run _is_dotdone_write——目标文件从 .flow-active.independent-review 改为 .independent-review-<N>.done，保留 9 种写向量（> / >> / tee / cp / mv / sed -i / printf / dd of= / heredoc）命中断言 + exotic（perl -i / python -c）不挡的 v1 边界断言。**改写不删除**——D7 写向量覆盖是 v1 安全基座，删则退化为只靠集成测试。
    T4 done-validation 单元测试保留与新增（L2-first gating 契约保护 · RR1 落地）：
    5b. 保留 4 个 done-validation 测试中调用 fk_validate_done_marker 的部分（empty-done 拒绝 + KVP 伪造拒绝 + 值域校验），**不改写为 path-guard 语义**——T4（L2_verdict vs INDEPENDENT-REVIEW-N.md 交叉校验）是 DESIGN §2.2 明确保留的 L2-first gating 契约，必须有独立单元覆盖。
    5c. 新增 T4 裁决不匹配测试：构造 .done 的 L2_verdict 与 INDEPENDENT-REVIEW-N.md 的 L2 段 verdict 不一致 → fk_validate_done_marker tier=transition return 2（拒绝）。覆盖 T4 拒绝路径。
        .done 最小格式（8 键 KVP，见 DESIGN §2.3）：phase=N / change_id=<id> / written_by=l3-review-run / written_at=<ISO> / L2_verdict=pass / L3_verdict=pass / session_id=<uuid> / artifacts=a,b
        INDEPENDENT-REVIEW-N.md L2 段提取：grep "^## L2" 后取 Verdict 行（done-validation.sh 的 _fk_done_kvp + fk_extract_l2_verdict 既有逻辑）
    5d. 新增 T4 正向测试：.done 的 L2_verdict 与 INDEPENDENT-REVIEW-N.md L2 段一致 → return 0（放行）。覆盖 T4 通过路径。同 5c 格式，verdict 一致版本。
    新增集成测试（对应 AC-6，记忆 [[gate-orchestration-integration-test]]）：
    6. AC-6 payload 注入：gate_config=both 下，模拟 agent 通过 Bash cat > .done → path-guard exit 2；模拟绕过写入直接 jq transition → done-validation Gate 4 拦截。明确 step 6 覆盖 T4 裁决不匹配路径（.done L2_verdict 与 INDEPENDENT-REVIEW-N.md 不一致 → transition 拒绝）。
    7. AC-4 L2-only 例外：gate_config=L2 下 agent 写 .done → path-guard 放行（验证 _gate_is_l2_only）。
    8. R6 验证用例：模拟 l3_review_run 写 .done 场景，验证 path-guard 不拦截（R3 风险的测试兜底）。
    9. L2-only fail-open 测试（m2 落地）：模拟 .flow-active 缺失 gate_config key / jq 错误 → _gate_is_l2_only 返回 0（放行，D3 fail-open）。
    测试总数计算依据（M1 澄清）：原有 11 项（4 done-validation + 6 D7 + 1 helper）→ 4 done-validation 保留（5b）+ 2 新增 T4（5c/5d）+ 6 D7 改写（第 5 条）+ 3 新增集成（6/7/8）+ 1 fail-open（9）= 16 项。被移除的握手构造（write_valid_handshake helper）不计入新测试数。
    双源同步（R4 落地）：改完 test/test_gate_integrity.bats 后执行 make test-sync 同步到 flow-kit-bundle/test/test_gate_integrity.bats，diff -q 验证一致。
    所有测试用 payload 注入式（bash gate.sh + exit code 断言），覆盖编排层（非纯单元）。
    移除所有 written_by=stop-hook-29 / is_handshake_write / state_file 引用（含 write_valid_handshake helper）。
  </action>
  <verify>npx bats test/test_gate_integrity.bats && make test-sync && diff -q test/test_gate_integrity.bats flow-kit-bundle/test/test_gate_integrity.bats</verify>
  <done>4 done-validation 保留（含 T4 契约）+ 2 新增 T4 单元（不匹配拒绝/正向通过）+ 6 D7 单元改写 + 3 新增集成（AC-6/AC-4/R6）+ 1 fail-open = 16 测试全绿；T4 L2-first gating 契约有独立单元覆盖；双源同步 diff 一致；0 处握手引用残留；exit 0</done>
  <depends_on>T01, T02, T03</depends_on>
</task>

<task id="T05" parallel="true">
  <name>清理 test/regression-demos/tampered-done + exotic-escape 握手 demo</name>
  <read_files>
    test/regression-demos/tampered-done/
    test/regression-demos/exotic-escape/
    flow-kit-bundle/test/regression-demos/tampered-done/
    flow-kit-bundle/test/regression-demos/exotic-escape/
    .specs/gate-done-authorship/DESIGN.md
  </read_files>
  <write_files>
    test/regression-demos/tampered-done/
    test/regression-demos/exotic-escape/
    flow-kit-bundle/test/regression-demos/tampered-done/
    flow-kit-bundle/test/regression-demos/exotic-escape/
  </write_files>
  <action>
    双源测试同步（test/ + flow-kit-bundle/test/ 两处保持一致）：
    1. tampered-done/：改写为 .done 作者性语义——check.sh 验证 agent 用 sed -i 改 .done 被 path-guard 拦截（移除握手引用 written_by=stop-hook-29）。
    2. exotic-escape/：**确定性指令（M4 落地）**——保留目录但更新注释标注 v2 加密签名（exotic perl -i / python -c 路径仍超出 v1 path-guard 覆盖范围，留 v2 处理，demo 保留以记录该已知缺口）。更新 check.sh 使其反映 v1 边界（exotic 不挡是预期行为，非缺陷）。
    3. 同步两处源（test/ 开发源 + flow-kit-bundle/ 打包源），确保 check.sh 内容一致。
  </action>
  <verify>bash test/regression-demos/tampered-done/check.sh && ! grep -rl "written_by=stop-hook-29\|is_handshake_write\|state_file" test/regression-demos/ flow-kit-bundle/test/regression-demos/ 2>/dev/null</verify>
  <done>tampered-done demo 改写为 .done 作者性（check.sh rc=0 硬断言）；exotic-escape 评估处理；双源同步；0 处握手引用残留（无 || echo 兜底）</done>
  <depends_on>T01</depends_on>
</task>
```

### Wave 3

```xml
<task id="T06" parallel="false">
  <name>全量回归 make test + 死代码 grep 验证 + 0 fail 确认</name>
  <read_files>
    .specs/gate-done-authorship/REQUIREMENT.md
  </read_files>
  <write_files>
    <!-- 无文件修改，纯验证任务 -->
  </write_files>
  <action>
    1. make test（或 npx bats test/）全量回归，确认 0 fail exit 0（对应 AC-7）。
    2. 死代码验证（对应 AC-3）：grep -r "is_handshake_write\|state_file\|written_by=stop-hook-29\|T3.*handshake" flow-kit-bundle/hooks/ 在生产代码中 0 匹配（测试文件除外）。
    3. 若有 fail：回退到对应 Wave 1/2 任务修复，不新开任务。
    4. 确认 shellcheck（make lint）通过。
  </action>
  <verify>make test && make lint && ! grep -rnE "is_handshake_write|state_file|written_by=stop-hook-29|T3.*handshake|T3b.*SESSION|握手" flow-kit-bundle/hooks/ 2>/dev/null | grep -v "/test/\|/regression-demos/" && diff -q test/test_gate_integrity.bats flow-kit-bundle/test/test_gate_integrity.bats && echo "ALL GREEN"</verify>
  <done>make test 全量 0 fail exit 0；死代码 grep 5 token + 中文"握手"全覆盖 0 匹配（与 AC-3 逐字对齐）；双源 diff 一致；shellcheck 通过；输出 ALL GREEN</done>
  <depends_on>T04, T05</depends_on>
</task>
```

---

## AC 覆盖矩阵

| AC | 覆盖任务 | 验证 |
|----|---------|------|
| AC-1 agent 伪造 .done 被拦截 | T01（path-guard）+ T04（测试） | T04 exit 2 断言 |
| AC-2 合法 .done 放行 | T01（l3_review_run 不经 PreToolUse）+ T04（D9 正向） | T04 exit 0 断言 |
| AC-3 握手死代码清理 | T01（删 is_handshake_write）+ T02（删 T3）+ T03（删 state_file）+ T06（grep 验证） | T06 grep 0 匹配 |
| AC-4 L2-only 例外 | T01（_gate_is_l2_only）+ T04（L2-only 测试） | T04 exit 0 断言 |
| AC-5 既有测试改写 | T04（4 done-validation + 6 D7 改写）+ T05（regression-demos） | T04 0 握手引用 + T05 check.sh rc=0 + grep clean |
| AC-6 payload 注入集成测试 | T04（新增集成测试） | T04 exit 2/4 断言 |
| AC-7 全量 bats 0 fail | T06（make test） | T06 exit 0 |

---

## 禁动清单遵守声明

所有任务的 `write_files` 均在 DESIGN § 0.5.1 触碰/新增模块范围内：
- ✅ T01: independent-review-gate.sh（触碰模块）
- ✅ T02: done-validation.sh（触碰模块）
- ✅ T03: 29-independent-review.sh（触碰模块）
- ✅ T04: test_gate_integrity.bats（测试文件）
- ✅ T05: regression-demos/（测试 demo）
- ✅ T06: 无 write_files（纯验证）

未触碰禁动清单：l2-detect.sh / common.sh / correction-file.sh / fix-compliance.sh / session-start/ / lib/ / package-flow-kit.sh。
