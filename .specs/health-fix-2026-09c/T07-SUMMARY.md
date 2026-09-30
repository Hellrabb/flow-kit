# T07-SUMMARY — C5+C11 跨层闭环：gate-config 判据面换血（AC-7）

任务：check-gate-sync.sh 判据面从「mock 自比（名集合比对 + `)` 截断丢值）」换血为
「双侧同一提取器读生产文本 + 键值对集合比对」；mock 契约值 72 处 independent→both；
反向控制（both→independent 篡改必红）落测试。上游 T03（沙箱化 17 腿，af5843b）已就位。

## 1. 提取器设计（D1/AC-7/ADR-030）

**宿主**：`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（reference/ 可执行
检查器，ADR-030 豁免：把生产 .sh/SKILL.md 当**数据文本**解析——grep/sed/awk 锚点
提取，**不 source、不 eval** 被检文件；豁免依据写入函数头注释块 :191-220）。

**签名**：`resolve_gate_config() <skill|bats> <file>`（定义于 :229，
`grep -cE 'resolve_gate_config[[:space:]]*\(\)'` = 1 ✅）

| 侧 | 段边界（sed 锚点） | 行识别（awk 状态机） |
|---|---|---|
| skill | `预设名映射表（PRESET_MAP）` → `数字映射：` | `# <name> → {...}`；取首个 `{...}`，尾注（⚠️ tokens 提示）丢弃 |
| bats | `case "$value" in` → `esac`（2 空格缩进锚定 mock 块） | 分支行 `full)` / `code-only|review)` 挂起，下一 `echo '{...}'` 配对消费；`\*)` 与 `;;` 复位；`\|` 别名拆行 |

**展开与输出**：私有辅助 `_rgc_expand_json()`（:222）把 `{"k":"v",…}` 按逗号切分
成 `k=v` 行（值域 both/L2/L3/independent 皆简单词，无嵌套，切分安全）；终态输出
每行一个键值对，规范形 **`<preset> <phase-key>=<value>`**，`sort -u` 规范化。
→ `{...}` 值形态完整进入比对，旧判据 `sed s/\).*//` 在 `)` 截断丢值（C5 病灶
:231）就此消除；比对是**键值对集合** diff，非字符串前缀比对。

**rc 契约（fail-closed）**：0=提取成功；1=用法错/文件不可读；2=格式漂移（段锚点
缺失或段内零预设行）。检查器把 rc≠0 转具名 `🔴 PARSE`（:337-342），解析失败
≠ 通过（ADR-030）。

**双侧同源（AC-7 Given 落地）**：check-gate-sync.sh 头部守卫
`if [[ "${BASH_SOURCE[0]}" == "$0" ]] …`（:11-17）——直接运行才执行主流程+exit；
被 source 时仅暴露函数定义（`FK_CGS_MAIN=0`），且**不向调用方泄漏 set -euo
pipefail**。bats 测试 T07 ①腿断言此守卫，②腿直接 `source "$SCRIPT"` 用**与检查器
同一份** resolve_gate_config 做双侧提取——「测试与 check-gate-sync.sh 双侧 source
同一实现」不再是纸面声明。

**比对流（check_gate_config_sync :309-376）**：双侧 `resolve_gate_config` 提取
（`|| rc=$?` 捕获，set -e 安全）→ 任一 rc≠0 ⇒ 🔴 PARSE；diff rc≥2 ⇒ 🔴
MECHANICAL（机械故障不折算一致）；diff 非空 ⇒ 🔴 DRIFT（沿用旧措辞锚「gate-config
预设名集合不一致」+ 值域说明，既有 3 条漂移腿零改动仍绿）；空 ⇒ 双计数（预设 17 /
键值对 34）打印 `✅ 预设名集合一致 (17 个预设) — 键值对集合比对通过 (34 对…)`
（前缀兼容 T02 健康腿断言）。缺文件双态 🔴 MISSING（F6/R5-14）原样保留。

## 2. 72 处替换计数

`test/test_gate_config_presets.bats`：`sed -i 's/"independent"/"both"/g'` 全局替换。
**改前 `"independent"` 计数 = 72（test/ 与 flow-kit-bundle/test/ 镜像同 = 72）；
改后 = 0，且 `"both"` 计数 = 72**（一一对应，无多改无漏改）。逐处预核：72 处全部
是契约值形态（case 块 echo JSON ×17 预设、数字简写 jq '. + {...}' ×6、断言
`= "independent"` 逐键值、AC-8 passthrough 输入 JSON），无断言无关文本被误伤。
保留未动（非契约值，任务边界明令「只改 gate_config 契约值」）：
- :120 测试名 prose「3 keys all independent」、:311 段头「independent-review-gap」、
  :393 测试名「no independent review」（历史语义描述，非断言字面量）🟡 见偏差节。
文件头加 T07 迁移注释 4 行；镜像 `cp` 后 `cmp` 逐字节相同。

## 3. 反向控制证明（篡改必红 → 闭环有检测力）

三阶段实证（REQUIREMENT:191 顺序：先换比对逻辑，后迁 mock 值）：

| 阶段 | 判据面 | 结果 |
|---|---|---|
| A 改造前（基线） | 旧名集合比对 | rc=0 **假绿**：skill 侧 17 预设全 both vs mock 侧全 independent，名比对对此不可见 |
| B 换判据后、mock 迁移前 | 新键值对集合比对 | **rc=1 真红**：`1,34c1,34`，skill 34 对全 both vs bats 34 对全 independent——证明旧门禁盲、新门禁有牙 |
| C mock 迁移后（终态） | 同 B | **rc=0 真绿**：双侧 34 对全等（both=both），判据面已是真生产文本非 mock 自比 |

**篡改腿（T07 ④，FXC1 夹具内 sed both→independent，tracked 文件零接触）真实输出**：

```
   校验: gate-config 预设键值对同步 (SKILL.md PRESET_MAP ↔ bats 镜像 · 提取器 resolve_gate_config)
     skill:  /tmp/t07-proof-oDogSK/fk/flow-kit-bundle/skills/flow/SKILL.md
     bats:   /tmp/t07-proof-oDogSK/fk/flow-kit-bundle/test/test_gate_config_presets.bats
   🔴 DRIFT: gate-config 预设名集合不一致（键值对集合比对：名字或值漂移——任一侧 both↔independent/L2/L3 值变动即红，旧名比对对此不可见）
     1,34c1,34
     < all 1-requirement=independent
     < all 2-design=independent
     …（34 对全部列出，skill 侧被篡改为 independent）…
PROOF_RC=1
```

同场景下**旧判据恒绿**（阶段 A 即同款漂移）——这正是 C5「更绿不更红」失效模式的
对偶证明。另有 T07 ⑤ fail-closed 腿：删段锚点 ⇒ 🔴 PARSE + rc≠0（解析失败不折算
✅ 一致）。

## 4. verify 真实输出（本机 /home/<acct>/unisoc/flow-kit）

```
$ npx bats test/test_check_gate_sync.bats test/test_gate_config_presets.bats
1..56
ok 1-17   （T02/T03/T-FIX-04/10/18/25 既有 17 腿全绿，零改动沿用）
ok 18 T07 ①: source check-gate-sync.sh → 主流程不执行、导出 resolve_gate_config、不泄漏 set -e
ok 19 T07 ②: 双侧同一提取器读真实生产件 → 键值对集合相等（34 对 / 17 预设）
ok 20 T07 ③: 提取器保留 {...} 值形态 → 输出 <preset> <phase>=<value> 全值（无右括号截断）
ok 21 T07 ④ 反向控制: 生产侧 both→independent 篡改 → 门禁转红（闭环有检测力）
ok 22 T07 ⑤ fail-closed: 段锚点删除（格式漂移）→ 🔴 PARSE 转红（解析失败 ≠ 通过）
ok 23-56 （test_gate_config_presets.bats 34 腿全绿——both 迁移后 mock 行为不变）
BATS_RC=0

$ make check-gate-sync
   校验: gate-config 预设键值对同步 (SKILL.md PRESET_MAP ↔ bats 镜像 · 提取器 resolve_gate_config)
   ✅ 预设名集合一致 (17 个预设) — 键值对集合比对通过 (34 对，双侧同一提取器 resolve_gate_config 读生产文本)
   ✅ 校验对 3/14 一致（仅覆盖上述 3 对，非全量 14 对全绿）。
MAKE_RC=0

$ test "$(grep -c '"independent"' test/test_gate_config_presets.bats)" -eq 0   → 0 ✅
$ test "$(grep -cE 'resolve_gate_config[[:space:]]*\(\)' …/check-gate-sync.sh)" -ge 1 → 1 ✅
$ cmp test/test_gate_config_presets.bats flow-kit-bundle/test/… → 逐字节相同 ✅
$ cmp test/test_check_gate_sync.bats    flow-kit-bundle/test/… → 逐字节相同 ✅
```

rc=0 的判据面区分（任务块注明项）：终态 rc=0 与改造前 rc=0 **同码不同质**——改造前
是名集合比对对 17 预设名重合的假绿（值域漂移不可见，阶段 B 实证即转红）；终态
rc=0 是提取器读双侧生产文本后 34 键值对全等的真绿，任何单值篡改（阶段 C→④腿）
即 rc≠0。今日两红锚（"independent"=0、提取器定义 grep≥1）均转绿。
任务块 verify 中的 `make check-test-sync` 按派发指令跳过（编排者波末统一跑）。

## 5. 6 维自查（R1-R6 内置快查）

- **R1 认知过载** ✅：`resolve_gate_config` 三段式（段提取/行识别/展开）每段单一
  职责，含注释 ~72 行；awk 状态机仅 skill/bats 两分支；无三层以上嵌套。
- **R2 变更传播** ✅：checker 改动集中在提取器块+比对流+头尾守卫（:11-17/:186-376/
  :379-405）；既有 17 腿零改动全绿（消息串前向兼容设计），预设 mock 仅值字面量+
  头注释。与同波次并行任务（Makefile/pre-push/package-dsh-plugin 等非本任务文件）
  零行重叠。
- **R3 知识重复** ✅：双侧**同一**提取器（测试 source 生产 .sh），预设解析知识单点
  落地——正是本任务要消灭的重复（旧：checker 与 mock 各写一套解析，漂移不可见）。
- **R4 偶然复杂** ✅：无新抽象层；`_rgc_expand_json` 是唯一新增辅助且被双侧共用；
  沿用既有 MISSING/MECHANICAL/DRIFT 分支骨架，只换判据面。
- **R5 依赖混乱** ✅：reference→生产仅文本依赖（ADR-030 豁免边界）；tests→reference
  为 source 依赖且头守卫保证 source 无副作用（不执行主流程、不泄漏 set -e，①腿
  钉死）；无新包依赖。
- **R6 领域扭曲** ✅：命名沿用领域词（preset/phase/键值对集合）；输出形
  `<preset> <phase-key>=<value>` 与 SKILL.md PRESET_MAP 语义同构；错误具名
  PARSE/DRIFT/MISSING/MECHANICAL 与文件内既有四态语汇一致。

无 🔴 必修项。

## 6. 越界检查

- TASK write_files：check-gate-sync.sh、test/test_gate_config_presets.bats、
  test/test_check_gate_sync.bats、flow-kit-bundle/test/ 两镜像 —— **5 文件全为
  授权面内**；实际写入 = 上述 5 + 本 SUMMARY = 6 文件。
- 工作树中其他已修改文件（Makefile、pre-push.sh、package-dsh-plugin.sh、.specs/
  多份）属同波次并行任务，非本会话所写。
- **未** git commit；**未** 动 .flow-active；**未** 动 TASK.md；**未** 跑
  make test-sync / check-test-sync（编排者波末统一）；**未** 动其他任务文件。

## 7. 偏差 / 记录（🟡）

1. 🟡 首跑测试名含 `` `)` `` 字面量触发 bats 结果打印器的命令替换解析噪声
   （用例本身 ok）——改名「无右括号截断」后噪声消失。教训：bats 测试名勿带反引号。
2. 🟡 自写头注释中的引号字面量被本任务自己的全局 sed 误改（"independent"→"both"
   连注释一起替换成 "both" 迁移为 "both"）——当即改写为无引号措辞。教训：先注释
   后 sed 的顺序应倒置，或注释避免引号字面量。
3. 🟡 预留 3 处**非断言** prose "independent"（:120/:311/:393 测试名与段头，历史
   语义描述）按任务边界「只改契约值」有意未动；红锚口径（带引号计数=0）不受影响。
4. 🟡 dist/ 构建产物内仍有旧「预设名集合一致」文案快照——非本任务 write_files，
   留编排者波末/发布任务处理。
5. ADR-030/031 为未跟踪新文件（本 change 前序任务产物，非 T07 所建），仅引用。
