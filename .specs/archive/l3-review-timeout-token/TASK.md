# TASK: L3 审查工具超时/token 上限可配置化

- **Change ID**: l3-review-timeout-token
- **关联**: `@.specs/l3-review-timeout-token/REQUIREMENT.md`、`@.specs/l3-review-timeout-token/DESIGN.md`、`@.specs/CONTEXT.md`

---

## 波次划分

```
Wave 1: T01（实测探针，不改代码）
  └── T01 收集 DESIGN R2/R3/R4 + AC-10 证据（代理上限 + enabled+32k 大产物 + content[0] 结构）

Wave 2: T02 (depends on T01)
  └── T02 实现 _l3_call_api 三 env var 可配 + Fail-safe + 可观测性（据 T01 证据定默认值）

Wave 3: T03 (depends on T02)
  └── T03 改写 test_l3_review.bats（删旧硬编码断言 + 新增 stub curl 双路径测试）

Wave 4: T04 (depends on T03)
  └── T04 全量回归 make test + lint + 双源同步 + AC-9 手动冒烟
```

依赖图（无环 · 串行）：
```
T01 ──> T02 ──> T03 ──> T04
```

---

## 任务清单（XML）

### Wave 1

```xml
<task id="T01" parallel="true">
  <name>实测探针：收集 DESIGN R2/R3/R4 + AC-10 证据（不改代码）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    .specs/l3-review-timeout-token/DESIGN.md
    .specs/l3-review-timeout-token/REQUIREMENT.md
  </read_files>
  <write_files>
    .specs/l3-review-timeout-token/T01-SUMMARY.md
  </write_files>
  <action>
    三次实测收集证据（DESIGN R2/R3/R4 + REQUIREMENT AC-10 落地）：
    1. **R4 探针**：用 curl 直接调阿里云 deepseek 代理（ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN），max_tokens=32000 打一个最小 prompt（如"回复 OK"），确认 HTTP 200 + text block。若 400（超代理上限），记录代理实际上限，T02 默认值下调。
    2. **R3 探针**：用 enabled（无 thinking 字段）+ max_tokens=32000 + --max-time 300 对大产物 prompt（读 gate-done-authorship 的 TASK.md 作 prompt 内容）跑一次，确认是否产出 text block（vs 思考吃满 32k）。
    3. **AC-10 探针（R1b/C3 落地）**：打印上述调用的 `.content[0]` 完整结构（jq '.content[0]'），确认 thinking block 字段名（是否 .thinking/.text）。判定 enabled+32k 大产物是否触发 fallback 静默错判（l3-review.sh:378 的 `.thinking // .text` fallback）。
    所有探针用 thinking=disabled fallback 模式（DESIGN 提议配置）作为对照——确认解套配置有效。
    约束：不改任何源码文件（只 curl 探针）。结果全记 T01-SUMMARY.md「实测证据」段。
  </action>
  <verify>test -f .specs/l3-review-timeout-token/T01-SUMMARY.md && grep -q "实测证据" .specs/l3-review-timeout-token/T01-SUMMARY.md && grep -qE "代理上限|代理.*[0-9]" .specs/l3-review-timeout-token/T01-SUMMARY.md && grep -qE "content\[0\]|thinking.*字段" .specs/l3-review-timeout-token/T01-SUMMARY.md && grep -qE "静默错判|fallback.*触发" .specs/l3-review-timeout-token/T01-SUMMARY.md</verify>
  <done>T01-SUMMARY.md 含「实测证据」段，覆盖 R4（代理上限数值）+ R3（enabled+32k 大产物 text block 产出）+ AC-10（content[0] 字段名 + 静默错判判定）；verify 断言数值/字段名非仅存在性；不改任何源码</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="false">
  <name>实现 _l3_call_api 三 env var 可配 + Fail-safe + 可观测性</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    .specs/l3-review-timeout-token/DESIGN.md
    .specs/l3-review-timeout-token/REQUIREMENT.md
    .specs/l3-review-timeout-token/T01-SUMMARY.md
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
  </write_files>
  <action>
    修改 _l3_call_api()（L340-386）：
    1. **读三个 env var**（L341 附近）：
       - max_tokens 默认 32000（T01 R4 探针若发现代理上限更低，下调至代理上限）
       - timeout 默认 300
       - thinking 默认 enabled
       用 bash ${VAR:-default} 惯法（DESIGN D6：2 级 env var，非 3 级链）
    2. **Fail-safe（AC-6）**：
       - max_tokens/timeout 非数字或空 → 回退默认 + stderr 警告（用正则 ^[0-9]+$ 校验）
       - thinking 非 {enabled,disabled} → 按 enabled 默认 + stderr 警告
    3. **可观测性（AC-7）**：stderr 输出 `[l3-review] using max_tokens=X timeout=Y thinking=Z`（X/Y/Z 为解析后的实际值）
    4. **改两路径请求体**（L349 路径1 / L365 路径2）：
       - max_tokens 用变量 $max_tokens 替换硬编码 8000
       - thinking=disabled 时请求体加 `thinking:{type:"disabled"}` 字段（jq -n 条件构造，见 DESIGN §2.3）
       - thinking=enabled 时不含 thinking 字段
       两路径同步改（AC-1~AC-5 双路径要求）
    5. **改两路径 curl --max-time**（L346 / L362）：用变量 $timeout 替换硬编码 90
    6. 约束：不改 _l3_parse_result 的 fallback 链（L378，Out of Scope，R1b 记录在案）
    据 T01 实测证据定默认值（若 R4 发现代理上限 < 32000，下调；若 R3 发现 enabled+32k 大产物仍失败，T02 后评估是否改默认 disabled——但默认 disabled 属 v2 决策，本 change 保留 enabled + 实测记录）。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -q 'FLOW_KIT_L3_MAX_TOKENS' flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -q 'FLOW_KIT_L3_TIMEOUT' flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -q 'FLOW_KIT_L3_THINKING' flow-kit-bundle/hooks/stop/lib/l3-review.sh && ! grep -q 'max_tokens:8000' flow-kit-bundle/hooks/stop/lib/l3-review.sh && ! grep -q -- '--max-time 90' flow-kit-bundle/hooks/stop/lib/l3-review.sh && grep -q 'using max_tokens' flow-kit-bundle/hooks/stop/lib/l3-review.sh</verify>
  <done>三 env var 全可配（FLOW_KIT_L3_MAX_TOKENS/TIMEOUT/THINKING）；硬编码 8000/90 全删；Fail-safe 回退 + 警告；可观测性 stderr 行；双路径同步改；bash -n 通过</done>
  <depends_on>T01</depends_on>
</task>
```

### Wave 2

```xml
<task id="T03" parallel="false">
  <name>新增/改写 test_l3_review.bats（stub curl 双路径 + env var + Fail-safe + 可观测性 + AC-10）</name>
  <read_files>
    test/test_l3_review.bats
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    .specs/l3-review-timeout-token/REQUIREMENT.md
    .specs/l3-review-timeout-token/DESIGN.md
  </read_files>
  <write_files>
    test/test_l3_review.bats
  </write_files>
  <action>
    按 REQUIREMENT AC-1~AC-8 + AC-10 派生测试（双源同步留 T04）：
    0. **删旧硬编码断言（R3 落地）**：既有 test_l3_review.bats 的 `AC-5: max_tokens is 8000`（L24）+ `AC-5: curl timeout is 90s`（L29）在 T02 删硬编码后必破裂——删除这两个旧测试（或改写为新断言：max_tokens 不再硬编码 8000，而是验证 env var 解析后的值）。
    1. **编号碰撞处理（R3 落地）**：旧 `AC-1: git ls-files`（L131）/`AC-2: phase 7 artifact`（L148）与本 change 新 AC-1/AC-2 编号碰撞——这两个旧测试是 l3-comprehensive-fix 等历史 change 的产物（测 git ls-files/artifact listing，与 L3 参数无关），**保留但重命名编号**为不冲突的标识（如 `AC-legacy-1`/`AC-legacy-2`），或移到独立 test 函数不挂 AC 编号。
    2. **Mock 策略（AC-1~AC-7）**：bats 定义 `curl()` shell 函数覆盖真实 curl，捕获命令行参数 + 请求体 JSON，不打真实网络。**禁止 stub 整个 _l3_call_api**（保请求体构造逻辑被测）。
    3. **AC-1/AC-2**（max_tokens 默认 32000 + env var 覆盖）：双路径各断言请求体 max_tokens 值。AC-2 用 `FLOW_KIT_L3_MAX_TOKENS=16000` env var 前缀跑 bats
    4. **AC-3/AC-4**（timeout 默认 300 + env var 覆盖）：双路径各断言 curl --max-time 值。AC-4 用 `FLOW_KIT_L3_TIMEOUT=600` 前缀
    5. **AC-5a/5b/5c**（thinking 显式 enabled/disabled/未设基线）：双路径 × 三取值断言请求体含/不含 thinking 字段。AC-5a 用 `FLOW_KIT_L3_THINKING=enabled`、5b 用 `=disabled`、5c 不设，分别跑 bats
    6. **AC-6**（Fail-safe）：6 非法值（MAX_TOKENS=abc/空、TIMEOUT=xyz/空、THINKING=yes/空）双路径断言回退默认 + grep stderr 警告。每非法值用对应 env var 前缀跑 bats
    7. **AC-7**（可观测性）：双路径 grep stderr 配置记录行
    8. **AC-10/fallback 立场修正（R3 落地）**：AC-10 属 T01 手动探针（不进 bats——bats 无法打真实 API）。T03 不 blanket"保留 fallback 断言"——而是**新增一条断言**：_l3_parse_result 的 fallback 链（L378）在无 text block + 有 thinking block 时的行为（用 mock 响应喂给 _l3_parse_result，断言其提取内容，记录行为但不改 fallback 逻辑——Out of Scope）。这把"静默错判危险"从立场矛盾转为可观测测试
    **粒度（R5 落地）**：T03 估 +290~450 行超 200 guideline。拆分选项：① 按 AC 分多个 @test（已在上面）② 若单文件超 450 行，拆为 test_l3_review_params.bats（AC-1~AC-7）+ test_l3_review_fallback.bats（AC-10/fallback 行为）。T03 实施时按实际行数决定是否拆——若不超则单文件，超则拆两个。
  </action>
  <verify>npx bats test/test_l3_review.bats test/test_l3_review_params.bats</verify>
  <done>旧硬编码断言删/改写；旧 AC 编号重命名避碰撞；AC-1~AC-7 bats 测试全绿（含 env var 前缀覆盖 AC-2/4/5a/5b/6/7）；AC-10 fallback 行为可观测测试（非 blanket 保留）；若超 450 行拆两文件；exit 0</done>
  <depends_on>T01, T02</depends_on>
</task>
```

### Wave 3

```xml
<task id="T04" parallel="false">
  <name>全量回归 make test + lint + 双源同步 + AC-9 手动冒烟</name>
  <read_files>
    .specs/l3-review-timeout-token/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/test/test_l3_review.bats
  </write_files>
  <action>
    1. make test（全量 bats 0 fail · AC-8）+ make lint（shellcheck 通过）
    2. 双源同步（AC-1~AC-7 的 bats）：make test-sync 同步 test/test_l3_review.bats → flow-kit-bundle/test/test_l3_review.bats，diff -q 验证一致（R4 L2 落地）
    3. AC-9 手动冒烟（非回归线）：source l3-review.sh && l3_review_run 3 gate-done-authorship .specs/gate-done-authorship pass both（用 gate-done-authorship phase 3 解套验证），确认 rc∈{0,1} 非 rc=3
    4. 若 make test 有 fail：回退对应 Wave 1/2 task 修复
  </action>
  <verify>make test && make lint && make test-sync && diff -q test/test_l3_review.bats flow-kit-bundle/test/test_l3_review.bats && echo "ALL GREEN"</verify>
  <done>make test 全量 0 fail；make lint shellcheck 通过；双源 diff 一致；AC-9 手动冒烟 rc∈{0,1} 非 rc=3（解套 gate-done-authorship）；输出 ALL GREEN</done>
  <depends_on>T03</depends_on>
</task>
```

---

## AC 覆盖矩阵

| AC | 覆盖任务 | 验证 |
|----|---------|------|
| AC-1 max_tokens 默认+双路径 | T02（实现）+ T03（测试） | T03 bats 请求体 max_tokens:32000 双路径 |
| AC-2 MAX_TOKENS env var 覆盖 | T02 + T03 | T03 bats env var 覆盖双路径 |
| AC-3 timeout 默认+双路径 | T02 + T03 | T03 bats curl --max-time 300 双路径 |
| AC-4 TIMEOUT env var 覆盖 | T02 + T03 | T03 bats env var 覆盖双路径 |
| AC-5a/5b/5c thinking 显式/未设 | T02 + T03 | T03 bats 三取值 × 双路径 |
| AC-6 Fail-safe 非法值 | T02 + T03 | T03 bats 6 非法值双路径 + grep 警告 |
| AC-7 可观测性 | T02 + T03 | T03 bats grep stderr 配置行双路径 |
| AC-8 全量 bats 0 fail | T04 | T04 make test exit 0 |
| AC-9 端到端冒烟（手动） | T04 | T04 手动 rc∈{0,1} 非 rc=3 |
| AC-10 静默错判验证 | T01（探针） | T01-SUMMARY 实测证据（content[0] 结构 + 判定） |

---

## 禁动清单遵守声明

所有任务的 `write_files` 均在 DESIGN § 0.5.1 触碰模块范围内：
- ✅ T01: .specs/l3-review-timeout-token/T01-SUMMARY.md（探针证据）
- ✅ T02: l3-review.sh（触碰模块）
- ✅ T03: test_l3_review.bats（测试文件）
- ✅ T04: flow-kit-bundle/test/test_l3_review.bats（make test-sync 双源输出）

未触碰禁动清单：common.sh / l2-detect.sh / done-validation.sh / independent-review-gate.sh / 29-independent-review.sh / 其余 hook/lib。
