# T12b-SUMMARY — C13 check-skills-sync 覆盖门禁 + check-gate-sync PAIRS 迁移（AC-11）

> 阶段 4（DEV）· health-fix-2026-09c · 前置：T08 done（挂链范式）、T12a done 935aa3d（薄壳化本体）。
> 本任务只动 write_files 清单内文件；TASK.md 状态未碰；无 git commit。

## 0. 交付物清单（与 TASK.md write_files 一一对应）

| 文件 | 动作 | 说明 |
|---|---|---|
| flow-kit-bundle/flow-kit/reference/check-skills-sync.sh | 新建（+x，11156B） | C13/AC-11 三判据门禁 |
| flow-kit-bundle/flow-kit/reference/check-gate-sync.sh | 修改（405→242 行，+22/−185） | PAIRS/check_pair 整体迁出，T07 段 byte-identical |
| Makefile | 修改（+13/−2 行区段） | check-skills-sync target + check: 链挂接 + .PHONY |
| test/test_skills_sync.bats | 新建（10 用例） | 正向绿 + 反向篡改腿（FXC1 沙箱范式） |
| flow-kit-bundle/test/test_skills_sync.bats | 镜像 | cmp 逐字节一致 |
| test/test_check_gate_sync.bats | 修改（22→18 用例） | 删 4 条 PAIRS 腿 + 注释重锚 |
| flow-kit-bundle/test/test_check_gate_sync.bats | 镜像 | cmp 逐字节一致 |

## 1. 设计（reference/check-skills-sync.sh 判据面）

**受辖清单（封闭）**：`GOVERNED_PAIRS` 14 对（skill 目录 ↔ prompts 文件）+
`WHITELIST_PAIRS` 1 席（flow-go → flow-kit/GO.md，D5：三判据全辖，仅权威载体指向不同）+
`EXEMPT_SKILLS` 1 席（flow-kit-install：安装文档型，无权威正文配对，不辖）。
`skills/flow` 不匹配 flow-* glob（PRESET_MAP 载体，不辖）。**清单外任何 flow-* 目录 ⇒ 🔴 UNREGISTERED**
（白名单是封闭集合，新 skill 未登记即红，防裸奔）。

**① 覆盖（阈值 100%，AC-11）**：每受辖对三条件——SKILL.md 存在 + 权威载体存在 +
@see 已配对（锚行命中）。缺件 ⇒ 🔴 MISSING 具名路径；有件无锚 ⇒ 🔴 NO-SEE。
覆盖率 = 通过对 / 应辖对（14 对 + 白名单 1 = 15），不足 100% 即 rc≠0。

**② 不复制（D7 归一化行集）**：双侧 `grep -vE '^[[:space:]]*$|^---$|^```' | sort -u`
后 `comm -12 | wc -l` 必须为 0（滤平凡行防假红——空行/`---`/代码栅栏是双侧天然公共行）。
违反 ⇒ 🔴 DUP（报公共行数 + 首 3 个公共行样例，`awk 'NR<=3'` 取样防大输出 SIGPIPE）。
**flow-dev 显式豁免（偏差①）**：实测归一化公共行 63（T12a 定稿的「部分骨架」形态，
456 行保留段落骨架），登记进脚本内 `DUP_EXEMPT` 并在输出打印 ⚪ 豁免行——
①覆盖与 ③@see 仍辖该 skill。

**③ @see 锚可解析**：锚行 = 行首形如 `^>?@see`（flow-dev :6「@see 链」散言行不误报）。
token 走查：锚行内最近前置路径必须存在于 BUNDLE_ROOT；`§「标题」` 小节锚在**就近前置
路径**对应文件内必须 grep 命中标题行。违反 ⇒ 🔴 SEE 具名（skills/<name>/SKILL.md:行号 +
幽灵目标）。**括号注记关键词不入判据**（偏差②）：注记是散文非机读锚，「逐项命中」规则
在现树必假红（flow-architect [架构文档生成][模块依赖] 等），判据面收缩到路径 + § 锚。

**fail-closed 与措辞族**：错误分支全具名（MISSING/NO-SEE/DUP/SEE/UNREGISTERED），
汇总行打印三判据通过数，任一错误 ⇒ exit 1。

## 2. check-gate-sync.sh 手术（PAIRS 迁出，T07 段零触碰）

- 删除：PAIRS 数组（原 :46-50）+ PAIRS_TOTAL（原 :53）+ check_pair 全函数（原 :62-193，
  含 SIGPIPE 地雷 :187 `printf|head -8`）+ 主流程 PAIRS 循环（原 :384-391）+ COMPARED 计数器。
- 保留 byte-identical：BASH_SOURCE 守卫（:11-17）、_rgc_expand_json、resolve_gate_config
  提取器、check_gate_config_sync 判据面（T07 D1/AC-7/ADR-030 全部语义未动；段内
  「措辞与 check_pair 的 MISSING 分支同族」历史先例注释刻意保留原样）。
- 汇总改写：覆盖度行 → 「gate-config 校验面 1/1（PCSC 3 对内容比对判据已迁移
  reference/check-skills-sync.sh · T12b）」；成功行 → 「✅ 校验对 1/1 一致（gate-config
  键值对集合比对通过；仅覆盖本校验面）」——**保留「校验对…一致」措辞锚**，test#6（原 :116）
  零编辑自愈。
- 手术法：锚定拼接脚本（每个锚点断言全局唯一命中；写入在全部断言通过之后，原子）；
  术后回验 = git diff --stat + 残留 grep（PAIRS_TOTAL/check_pair/COMPARED 仅剩历史注释 1 处）
  + bash -n + 真实树 rc=0。

## 3. PAIRS 迁移逐腿归因表（7 红任务口径 → 实测 8 红 + 2 翻红）

根因两条：**A** PAIRS 3 对薄壳化后内容必漂移（check_pair 判 both 侧不一致 → ERRORS=3 → exit 1）；
**B** check-gate-sync.sh:187 `printf '%s\n' "$diff_out" | head -8` 在 set -euo pipefail 下
SIGPIPE 竞态（bats run 捕获环境实测 rc=141 与 rc=1 摆动，5 连跑非确定）——PAIRS 腿删除后
该管道随之消失（gate-config 路径无 head 截断）。父任务口径 7 红为静态归因；实测 not ok 8 个
（#5/#13/#21 因竞态在父任务观察窗口里可能表现为绿）。

| 旧测试（号/腿） | 术前态 | 处置 | 归因 |
|---|---|---|---|
| #2 基线 rc=0 + 17 预设 | 红 | **自愈保留** | 根因 A 消失 ⇒ rc=0；17 预设断言仍有效（gate-config 段输出不变） |
| #5 注英文注释不误报 | 红（竞态） | **自愈保留** | 根因 B 管道消失；gate-config 段稳定可达，报「预设名集合一致」 |
| #6 完整夹具 rc=0 + 「校验对…一致」 | 红 | **自愈保留（零编辑）** | rc=0 恢复；新汇总行保留「校验对 1/1 一致」措辞锚 |
| #8 R3-18A skill 侧加行具名 | 红 | **删除** | 单侧具名语义随 check_pair 死亡；新判据 comm=0 无「单侧」概念，不迁 |
| #9 R3-18B prompt 侧加行具名 | 红 | **删除** | 同 #8 |
| #13 缺 bats → MISSING 具名 | 红（竞态） | **自愈保留** | 根因 B 消失后 gate-config MISSING 分支稳定打印具名路径 |
| #16 完整树 rc=0 + ✅ | 红 | **自愈保留** | 根因 A 消失 ⇒ rc=0 |
| #21 T07④ both→independent 转红 | 红（竞态） | **自愈保留（实测确认 ok）** | 基线转绿后篡改产生真红：DRIFT + independent 明细，未打印「键值对集合比对通过」 |
| #7 缺 flow-evolve/SKILL.md → MISSING（原绿） | 绿 | **删除（迁移承接）** | PAIRS 摘除后 check-gate-sync 不看 flow-evolve ⇒ 翻红；skill 缺件语义由新门禁①覆盖承接（test_skills_sync #4：删 flow-test/SKILL.md → 🔴 MISSING 具名 + 覆盖度跌破 15/15） |
| #15 R5-10③ 同行数改内容判红（原绿） | 绿 | **删除（迁移承接）** | 同上翻红；内容漂移语义由新门禁②comm=0 承接（test_skills_sync #5/#6：抄入正文行 → 🔴 DUP；含同行数替换变体） |

术后 bats 实测（编辑前跑旧文件）：8 现红中 6 自愈 ok，#8/#9 仍红，#7/#15 翻红——与上表逐腿
预测完全一致；删除 4 腿 + 注释重锚后 18/18 ok。

## 4. verify 真实输出（任务块原文 + 补充）

```
$ make check-skills-sync
   覆盖度: 15/15（阈值 100%；白名单映射 1 · 清单外豁免 1 · 未登记 0）
   不复制: 14/14 对 comm=0（豁免 1 对: flow-dev）
   @see 锚: 19/19 锚行可解析
   ✅ skill 薄壳 ↔ prompt 权威载体同步校验通过（覆盖 15/15 · 不复制 14/14 · @see 全可解析）
EXIT=0

$ make check-gate-sync
   ✅ 预设名集合一致 (17 个预设) — 键值对集合比对通过 (34 对，双侧同一提取器 resolve_gate_config 读生产文本)
   覆盖度: gate-config 校验面 1/1（PCSC 3 对内容比对判据已迁移 reference/check-skills-sync.sh · T12b）
   ✅ 校验对 1/1 一致（gate-config 键值对集合比对通过；仅覆盖本校验面）
EXIT=0

$ npx bats test/test_skills_sync.bats test/test_check_gate_sync.bats
1..28  → 28 ok / 0 not ok（BATS_EXIT=0）

$ make check-test-sync
✅ test 双源一致   EXIT=0

$ make lint（补充，新脚本在 reference/ 扫描面内）
✅ shellcheck: no errors found   EXIT=0

$ make test（全量）
✅ bats: all tests passed   MAKE_TEST_EXIT=0
（make recipe 为 tee 日志 + tail -3，成功即删日志；为留 0-fail 证据补跑
 npx bats test/ --formatter tap 全量捕获：plan 行 1..1149，grep 实测
 ok 1149 / not ok 0，退出码 0。基数账：1143 − 4 删腿 + 10 新腿 = 1149 ✓；
 10 条 T12b 腿在全量套件内逐条 ok（ok 1073–1082），gate-sync 18 腿全 ok。）
```

## 5. 六维自查

1. **write_files 边界**：git status --porcelain 改动 = write_files 7 文件 + 本 SUMMARY，
   无清单外触碰（.specs/ 下其余未跟踪文件为父波次遗留，非本任务产生）。
2. **TASK.md 状态**：未读改任务状态区（只读 :367-402 任务块）。
3. **禁碰面**：无 git commit；.flow-active 未动；T07 提取器/gate-config 判据面语义
   byte-identical（diff 仅落在标题/边界声明注释/PAIRS/check_pair/主流程/汇总）；
   skills/ 与 prompts/ 内容零改动（全部篡改只落 mktemp 沙箱副本）。
4. **镜像双写**：两个 bats 镜像均 cmp 逐字节验证（MIRROR OK）。
5. **SUMMARY 无真名路径**：全文无家目录/用户名字面。
6. **bats set -e 纪律**：期望非零处全部 `run` + `[ "$status" -ne 0 ]` 断言；前置自检
   （行数不变、文件已删、抄入行非空）用命令成功路径，无 `!` 前缀反直觉写法。

## 6. 偏差登记

1. **flow-dev ②comm 豁免**（DUP_EXEMPT）：实测归一化公共行 63，T12a「部分骨架」定稿使
   纯 comm=0 判据对它必假红。豁免显式登记在脚本内 + 输出 ⚪ 行 + 本表留档；①覆盖/③@see
   仍辖。任务块未预列此豁免（其范式假定为纯薄壳 13 对 + flow-dev 未单独点名）。
2. **@see 括号注记关键词不入判据**：注记（如「（五轮测试金字塔 / 测试矩阵 / UAT 脚本 /
   覆盖率回顾）」）为散文，非机读锚；「逐项命中」规则对现树必假红。判据面 = 路径存在 +
   § 小节标题命中（任务块原文口径）。
3. **check-gate-sync 汇总措辞改写**：成功/覆盖度行随 PAIRS 摘除必然改写（保留
   「校验对…一致」措辞锚使 #6 零编辑自愈）；错误行提示改为指向 PRESET_MAP↔bats 同步。
4. **红数口径**：任务块「7 红」为静态口径；实测 8 红（SIGPIPE 竞态使 #5/#13/#21 摆动）
   + 2 翻红（#7/#15）。全部消除，处置见 §3 表。
