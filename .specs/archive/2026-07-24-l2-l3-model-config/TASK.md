# TASK — L2/L3 模型配置解耦

- **Change ID**: l2-l3-model-config
- **关联**: REQUIREMENT.md、DESIGN.md（§7 文件清单 + §0.5 触碰模块）、CONTEXT.md
- **路径约定**：源码在 `flow-kit-bundle/`，verify 命令相对项目根
- **修订**：v2 — L2 第 1 轮 fail 后修正 R1（加 T11 更新既有测试）+ R2（/flow model 内联 flow/SKILL.md，对齐 gate-config 模式，删独立 skill T08）

---

## 波次划分

```
Wave 1 (parallel · 基础抽象):  T01[P] fk_resolve_model  |  T02[P] correction lib
Wave 2 (parallel · 调用点接入): T03[P] l3-review  |  T04[P] 29-indep  |  T05[P] l2-detect  |  T06[P] resume 收割  |  T07[P] flow /flow model 内联段
Wave 3 (parallel · 测试):       T09[P] test_fk_resolve_model  |  T10[P] test_flow_kit_resume  |  T11[P] 更新 test_independent_review_model
```

依赖：T03/T04/T05 依赖 T01+T02；T06 依赖 T02；T09 依赖 T01；T10 依赖 T06；T11 依赖 T04。T07 无依赖（内联独立段）。

---

## Wave 1 · 基础抽象

<task id="T01" parallel="true" status="done">
  <name>common.sh 新增 fk_resolve_model 三级优先级链</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
  </write_files>
  <action>
    新增 `fk_resolve_model <layer>`（layer ∈ L3/L2）。按 DESIGN §1 三级链逐级取非空值即停：L3=ANTHROPIC_DEFAULT_HAIKU_MODEL→FLOW_KIT_L3_MODEL→.flow-active.goal.l3_model；L2 同。纯查询函数（不写 correction / 不发 API / return 0）。用 `${PROJECT_ROOT:-}` 防 set -u 未设崩溃；jq 读 .flow-active 失败容错返回空。不碰既有 6 个 fk_* 函数。
  </action>
  <verify>source flow-kit-bundle/hooks/stop/lib/common.sh && type fk_resolve_model >/dev/null && echo OK</verify>
  <done>fk_resolve_model L3/L2 定义存在；source common.sh 不报错；全未配置返回空字符串</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>correction-file.sh 新增 write_model_missing_correction / clear（compliance 优先 + 原子写）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
    flow-kit-bundle/hooks/stop/lib/correction-types.sh
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
  </write_files>
  <action>
    新增 `write_model_missing_correction <layer>` + `write_model_missing_clear <layer>`（DESIGN §4.2 强制单一 lib 函数）。写入 schema `{type:"l3-model-missing"|"l2-model-missing", layer, message}`（与既有 l2-missing 精确等值区分）。**compliance 优先 + 原子写（L3 Phase 2 竞态发现）**：用 jq 单次原子操作（`jq 'if .type=="compliance" and (.violations|length>0) then . else $new end'`，一次 read-merge-write，避免 Check-Then-Act TOCTOU 竞态），或 flock 互斥；禁止 caller 层 check-then-write 两步。clear 删除 model-missing type 的 correction（保留 compliance）。参照既有 correction_file_exists 等 helper。
  </action>
  <verify>source flow-kit-bundle/hooks/stop/lib/correction-file.sh && type write_model_missing_correction >/dev/null && type write_model_missing_clear >/dev/null && { grep -qF 'flock' flow-kit-bundle/hooks/stop/lib/correction-file.sh || grep -qF 'if .type=="compliance"' flow-kit-bundle/hooks/stop/lib/correction-file.sh; } && echo OK</verify>
  <done>两函数定义存在；写入时 compliance 在场不覆盖（原子判定）；clear 仅清 model-missing</done>
  <depends_on></depends_on>
</task>

---

## Wave 2 · 调用点接入

<task id="T03" parallel="true" status="done">
  <name>l3-review.sh:623 替换 :? → fk_resolve_model + 降级</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    替换 :623 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:?...}` → `model=$(fk_resolve_model "L3")`。空时调 `write_model_missing_correction "L3"` + stderr 提示 + API 调用前 return（不发 _l3_call_api，DESIGN §3 降级 vs 错误区分）。正常路径调 `write_model_missing_clear "L3"`（DESIGN §4.4 退场）。
  </action>
  <verify>grep -q 'fk_resolve_model "L3"' flow-kit-bundle/hooks/stop/lib/l3-review.sh && ! grep -q 'ANTHROPIC_DEFAULT_HAIKU_MODEL:?' flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -q 'write_model_missing_correction "L3"' flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -q 'write_model_missing_clear "L3"' flow-kit-bundle/hooks/stop/lib/l3-review.sh && echo OK</verify>
  <done>:623 用 fk_resolve_model；无 :? 硬依赖；降级在 API 前 return</done>
  <depends_on>T01, T02</depends_on>
</task>

<task id="T04" parallel="true" status="done">
  <name>29-independent-review.sh:59 替换 :? → fk_resolve_model + 降级</name>
  <read_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/29-independent-review.sh
  </write_files>
  <action>
    替换 :59 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:?...}` → `model=$(fk_resolve_model "L3")`。空时 write_model_missing_correction "L3" + stderr + API 前 return。正常路径 write_model_missing_clear "L3"。保留既有 _write_l2_missing_correction（本 change 顺带让其持久化见 T06）。**注意**：此 task 移除 :? 会使既有 test_independent_review_model.bats AC-3 断言（:? 计数>=1）失效 → 由 T11 同步更新。
  </action>
  <verify>grep -q 'fk_resolve_model "L3"' flow-kit-bundle/hooks/stop/29-independent-review.sh && ! grep -q 'ANTHROPIC_DEFAULT_HAIKU_MODEL:?' flow-kit-bundle/hooks/stop/29-independent-review.sh && grep -q 'write_model_missing_correction "L3"' flow-kit-bundle/hooks/stop/29-independent-review.sh && grep -q 'write_model_missing_clear "L3"' flow-kit-bundle/hooks/stop/29-independent-review.sh && echo OK</verify>
  <done>:59 用 fk_resolve_model；无 :?；降级 API 前 return；既有测试由 T11 更新</done>
  <depends_on>T01, T02</depends_on>
</task>

<task id="T05" parallel="true" status="done">
  <name>l2-detect.sh:215 替换 fallback → fk_resolve_model + 降级（移除 claude-sonnet-5）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/correction-file.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
  </write_files>
  <action>
    替换 :215 `${ANTHROPIC_L2_MODEL:-claude-sonnet-5}` → `model=$(fk_resolve_model "L2")`（**移除 claude-sonnet-5 fallback**，DESIGN §1 产品决策）。空时 write_model_missing_correction "L2" + stderr + API 前 return。正常路径 write_model_missing_clear "L2"。
  </action>
  <verify>grep -q 'fk_resolve_model "L2"' flow-kit-bundle/hooks/stop/lib/l2-detect.sh && ! grep -q 'claude-sonnet-5' flow-kit-bundle/hooks/stop/lib/l2-detect.sh && grep -q 'write_model_missing_correction "L2"' flow-kit-bundle/hooks/stop/lib/l2-detect.sh && grep -q 'write_model_missing_clear "L2"' flow-kit-bundle/hooks/stop/lib/l2-detect.sh && echo OK</verify>
  <done>:215 用 fk_resolve_model；无 claude-sonnet-5 fallback；降级 API 前 return</done>
  <depends_on>T01, T02</depends_on>
</task>

<task id="T06" parallel="true" status="done">
  <name>flow-kit-resume.sh 扩展收割（rm -f 条件化 + model-missing 分支 + l2-missing 持久化）</name>
  <read_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </write_files>
  <action>
    扩展 :89-128 收割（DESIGN §4.3）：新增 l3-model-missing / l2-model-missing 分支（banner 显示配置提示，含 FLOW_KIT_*_MODEL）。**rm -f 条件化**：原 :127 无条件 rm 移入各分支——compliance 读后清 / unknown 异常清 / model-missing 与 l2-missing **不删**（持续提示）。附带修复既有 l2-missing 持久化 bug（此前被 :127 无条件删）。
  </action>
  <verify>grep -q 'l3-model-missing' flow-kit-bundle/hooks/session-start/flow-kit-resume.sh && grep -q 'l2-model-missing' flow-kit-bundle/hooks/session-start/flow-kit-resume.sh && echo OK</verify>
  <done>收割识别 4 种 type；rm -f 条件化；model-missing 不删持续提示</done>
  <depends_on>T02</depends_on>
</task>

<task id="T07" parallel="true" status="done">
  <name>flow/SKILL.md 加 /flow model 内联段（对齐 gate-config 模式，非独立子 skill）</name>
  <read_files>
    flow-kit-bundle/skills/flow/SKILL.md
  </read_files>
  <write_files>
    flow-kit-bundle/skills/flow/SKILL.md
  </write_files>
  <action>
    在 flow/SKILL.md「## 子命令」段加 `### /flow model` 内联段（**对齐既有 gate-config / goal / checkpoint 等内联模式**——既有 /flow 子命令全部内联在此文件，无独立子 skill 路由，L2 R2 查证）。覆盖 DESIGN §5 全语法：`/flow model`（显示）/ `l2=<m>` / `l3=<m>` / `l2=<m> l3=<m>`（合并）/ `--clear l2|l3`。读写 `.flow-active.goal.l2_model`/`l3_model`（jq --arg + jq_atomic_write 原子写，防注入）；仅写 l2_model/l3_model 不碰其他 goal 字段（DESIGN §5 边界）。
  </action>
  <verify>grep -q '/flow model' flow-kit-bundle/skills/flow/SKILL.md && grep -q '\-\-clear' flow-kit-bundle/skills/flow/SKILL.md && echo OK</verify>
  <done>flow/SKILL.md 含 /flow model 内联段（显示/设置/合并/--clear 全语法）</done>
  <depends_on></depends_on>
</task>

---

## Wave 3 · 测试

<task id="T09" parallel="true" status="done">
  <name>新建 test_fk_resolve_model.bats（AC-1/AC-3 全链 5 场景 × L2/L3）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/test/test_flow_active_integrity.bats
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_fk_resolve_model.bats
  </write_files>
  <action>
    覆盖 AC-1/AC-2/AC-3 五场景 × L2/L3：A（**P1 命中·AC-2 专项**：L3 用真实 `ANTHROPIC_DEFAULT_HAIKU_MODEL`、L2 用真实 `ANTHROPIC_L2_MODEL`，断言返回该值且不查 P2/P3——验证 CC 用户优先级 1 不变）/ B（P2 命中压 P3）/ C（P3 命中）/ D（全空降级）/ E（三级同设返回 P1）。每场景独立 setup（mktemp -d 临时 .flow-active + unset 对应 env var），互不污染。**场景 A 必须用真实 P1 env var 隔离测试并断言 P2/P3 未被查询**（AC-2 证伪）。参照既有 bats 风格。
  </action>
  <verify>npx bats flow-kit-bundle/test/test_fk_resolve_model.bats && echo PASS</verify>
  <done>10 用例（5 场景 × L2/L3）全 pass；场景 A 用真实 P1 env var 隔离且断言截断（AC-2 证伪）；场景隔离无污染</done>
  <depends_on>T01</depends_on>
</task>

<task id="T10" parallel="true" status="done">
  <name>扩展 test_flow_kit_resume.bats（AC-6 model-missing 收割 + 不删）</name>
  <read_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/test/test_flow_kit_resume.bats
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_flow_kit_resume.bats
  </write_files>
  <action>
    扩展 AC-6 对称两分支：写入 l3-model-missing correction → source resume → grep banner 含 FLOW_KIT_L3_MODEL + 断言文件未被删；l2-model-missing 同。验证 rm -f 条件化（model-missing 持续）。同步检查既有 :99 行断言（l2-missing 持久化）与新 T06 行为一致。
  </action>
  <verify>npx bats flow-kit-bundle/test/test_flow_kit_resume.bats && echo PASS</verify>
  <done>model-missing 收割两分支 pass；文件不被异常删除；l2-missing 持久化断言一致</done>
  <depends_on>T06</depends_on>
</task>

<task id="T11" parallel="true" status="done">
  <name>更新 test_independent_review_model.bats（AC-3 :? 断言 → fk_resolve_model 契约 · L2 R1）</name>
  <read_files>
    flow-kit-bundle/test/test_independent_review_model.bats
    flow-kit-bundle/hooks/stop/29-independent-review.sh
    flow-kit-bundle/test/test_common.bats
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_independent_review_model.bats
  </write_files>
  <action>
    修复既有测试断言（L2 第1轮 🔴 R1 + 第2轮 🟡 R1'/R2'/R3'）：
    (1) **AC-3（:45-56）@test 块完整覆盖两断言对**：(a) 29-indep:59 从 `:?` → `fk_resolve_model "L3"` 契约（grep fk_resolve_model + 降级 correction）；(b) 30-ai-analyze.sh:92 的 `:-` 模式——本 change **不改** 30-ai-analyze.sh（不在 read/write_files，路径约定 flow-kit-bundle/），其 :- 断言**保持原样**（实现者重写 @test 块时勿丢此分支覆盖，理解断言语义即可，不需 read 该无关文件）。
    (2) **AC-1 断言**（R1'）：29-indep:57 有过期注释「完全由 ANTHROPIC_DEFAULT_HAIKU_MODEL 定义」——T04 应清理此注释（好做法），T11 同步把 AC-1 断言从「ANTHROPIC_DEFAULT_HAIKU_MODEL 字面量计数 ≥1」改为 fk_resolve_model 契约（不依赖注释存在）。
    (3) **测试读路径**（R3'）：setup 当前读 `$HOME/.claude/hooks/`（安装副本）。改为读源码树——对齐 test_common.bats 向上查找 `flow-kit-bundle/hooks/` 模式；或在 verify 前刷新安装副本（运行 install.sh 同步，不改 install.sh）。
  </action>
  <verify>npx bats flow-kit-bundle/test/test_independent_review_model.bats && grep -q 'fk_resolve_model' flow-kit-bundle/test/test_independent_review_model.bats && grep -q '30-ai-analyze' flow-kit-bundle/test/test_independent_review_model.bats && echo PASS</verify>
  <done>AC-3 两断言对（29-indep fk_resolve_model + 30-ai-analyze 保持）覆盖；AC-1 断言不依赖 :57 注释；setup 读源码树或验证前刷新安装；两处副本同步；T04 后全绿</done>
  <depends_on>T04</depends_on>
</task>

---

## 禁动清单（任何 task 的 write_files 不得触碰）

- `package-flow-kit.sh`（打包流程不变）
- `install.sh`（安装流程不变）
- `flow-kit-bundle/hooks/stop/00-gate.sh`（gate 入口不变）
- 其它与本 change 无关的 hook / skill / 模块
- ⚠️ 不新建 `flow-model/SKILL.md` 独立子 skill（既有 /flow 子命令全内联 flow/SKILL.md，L2 R2；/flow model 内联到 T07）

## 全局回归（AC-7，Wave 3 后跑一次）

- `npx bats flow-kit-bundle/test/ && echo PASS`（全量 bats 0 fail；路径约定 flow-kit-bundle/，根目录 `test/` 副本由 package-flow-kit.sh 打包时同步，不在本 change write 范围）

## AC 覆盖矩阵

| AC | 覆盖 task |
|----|----------|
| AC-1（L3 全链）| T01 实现 + T09 测试 |
| AC-2（L3 P1 命中）| T01 + T09 |
| AC-3（L2 全链）| T01 + T05 + T09 |
| AC-4a/4b（降级）| T02 + T03/T04/T05（集成层）|
| AC-5/5b/5c/5d（/flow model）| T07（人工验收显示）|
| AC-6（SessionStart 收割）| T06 + T10 |
| AC-7（全量回归）| T09 + T10 + T11 + 全局回归 |
