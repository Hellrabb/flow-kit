# T17-SUMMARY — C14-b gate_config 五载体集合比对（AC-12-b）

> 阶段 4（DEV）· health-fix-2026-09c · TASK.md T17。前置：T07(8f0ff2f)/T12b(eca69ff)/T12c 均满足。
> 交付：check-gate-sync.sh 追加五载体对账判据段 + test_gate_config_carriers.bats（test/ 与 flow-kit-bundle/test/ 镜像字节一致）。

## 任务概述

在 T12b 重写后的 check-gate-sync.sh（405→242 行）上**追加**独立判据块 `check_gate_config_carriers`：
以 ③`dsh-flow-kit/lib/flow-state.js` PRESET_MAP（17 键）为权威全集，对五载体做预设名集合比对 + 值域对账；
任一载体增删预设名不同步 → rc≠0（AC-12-b 反向控制，bats 注入篡改用例钉住）。
**T07 段（resolve_gate_config 提取器 + 34 对键值比对 + PARSE fail-closed + 健康行）字节不动**——仅 :222 后插入新段 + 主流程/头注释改。

## §1 五载体实测表（实测时点全部一致 ⇒ 门槛可绿且有牙）

| # | 载体 | 提取方式 | 实测集合 |
|---|------|----------|----------|
| ① | flow-kit-bundle/skills/flow/SKILL.md PRESET_MAP 段 | T07 提取器 `resolve_gate_config skill` → 首列 | 17 名（=③） |
| ② | flow-kit-bundle/test/test_gate_config_presets.bats mock case 块 | 同一提取器 `resolve_gate_config bats` → 首列 | 17 名（=③） |
| ③ | dsh-flow-kit/lib/flow-state.js :20 起 `const PRESET_MAP`（**权威真源**） | 文本解析（sed 段锚点 + awk 键行；D1 哲学读文本不 source，ADR-030 豁免） | 17 键：full all code-only review design requirement plan design-review requirement-review task test integration task-review test-review task-test task-test-review spec-test |
| ④ | flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh `fk_check_gate_config_tamper` 内联值域 | 函数体提取：jq select `.value == "X"` 枚举 + case `X|Y|Z) ;;` 行 | 双处均 = {both independent L2 L3 true}，自一致；⊇ bash 侧使用值 {both} |
| ⑤ | FLOW-KIT-用户指南.md 预设名表（:1567-1583；**只读对账无写权**） | 段锚点 `### gate_config 预设名` → `### 数字简写`，表行第一列反引号 token + 别名折算 | 16 行 17 名（`code-only`/`review` 别名行两名均真键，机械拆分各记一名）；折算后 = ③ |

结论：现树五载体本就一致——**flow-state.js 与 gate-helpers.sh 无需改动**（写权预留未用）；判据价值在反向控制（漂移转红），由 §3 反向腿钉住。

## §2 判据设计（check-gate-sync.sh 新增段）

- 新函数群：`_gc5_js_preset_keys`（③键集，rc=2 fail-closed：段锚点缺失/零键）、`_gc5_gate_helpers_domains`（④双处值域，输出两行；rc=2）、`_gc5_guide_fold_name` + `GC5_GUIDE_ALIAS_FOLD` 折算表（内置于此；**当前登记 0 条改写级别名**——指南唯一复合形两名均真键，机械拆分即折算；新呈现名若出现且未登记 ⇒ 未知预设名 ⇒ 红）、`_gc5_guide_names`（⑤折算后名集，rc=2）、主函数 `check_gate_config_carriers`。
- ①② 名集**复用 T07 提取器**（双侧同源；提取失败时与键值对面同源复报，双计错可接受且报文注明）。
- 错误类别（均具名 + ERRORS++）：🔴 CARRIER-MISSING（仓内但④/⑤缺件）、🔴 CARRIER-PARSE（任一提取 rc≠0，列五侧 rc；未验证 ≠ 通过）、🔴 CARRIER-DRIFT（①②−③双向/③−①②、⑤未知（⑤−③）/⑤未覆盖（③−⑤）、④双处内联不一致、④值域未覆盖使用值）。
- **仓内上下文门**：③不存在（安装态副本/最小夹具）⇒ 整段显式跳过不计错（⏭️ 行 + 覆盖度 1/1）。理由：既有 FXC1/FXB10/FXB18/FXB25 沙箱腿只造 bundle 子树，严格 fail-closed 会弄红不在 T17 写权内的 test_check_gate_sync.bats；仓内检测面由 bats 真实树腿钉住（真实树必须打印五载体健康行），跳过不得静默退化为仓内逃逸口。
- 健康行（计数动态算）：`✅ 五载体预设名集合一致 (①skill 17 ②bats 17 ③js 17=权威 ⑤指南折算 17；④值域 … ⊇ 使用值 … 且 jq/case 双处内联一致) — C14-b/AC-12-b`。与 T07 健康行并存不互扰（「✅ 五载体」开头不撞 R3-19 的「✅ 预设名集合一致」否定断言）。
- 汇总：跳过态「校验面 1/1（…五载体对账未运行=非仓内上下文 · T17）」/ 运行态「校验面 2/2」；成功分支相应 1/1、2/2 两形；错误分支文案补五载体文件提示。

### 新测试 test/test_gate_config_carriers.bats（×2 树镜像，cmp 字节一致）

15 腿：前置存在可执行；真实树基线（rc=0 + 五载体健康行 + `③js 17=权威` + T07 健康行 + 校验面 2/2 + 无🔴）；沙箱基线（FXC5 mktemp 沙箱，rc=0）；非仓内跳过边界（显式⏭️ + 1/1 + 无健康行）；④缺失 CARRIER-MISSING；③锚点漂移 CARRIER-PARSE（③js rc=2）；反向 8 腿（①增/②增/③增/③删——后两者断言 **T07 面仍绿、仅新面红**，即新判据面独立性；④a 值域内部不一致/④b 使用值未覆盖；⑤删行未覆盖/⑤增行未知预设名）；折算机制钉住（source 模式：GC5_GUIDE_ALIAS_FOLD 在位 + identity 兜底）。
纪律：期望非零一律 `run` + `$status`；setup/teardown 备份还原四 tracked 载体（回归安全网，篡改只落沙箱副本）。

## §3 verify 真实输出（命令原样，禁全量 make test 已遵守）

```
$ npx bats test/test_gate_config_carriers.bats
1..15
ok 1  T17 前置: check-gate-sync.sh 存在且可执行
ok 2  T17 基线: 真实树（仓内上下文）→ rc=0 + 五载体健康行 + T07 健康行语义保留
ok 3  T17 沙箱基线: 五载体齐备夹具 → rc=0 + 健康行（判据有牙，非恒红）
ok 4  T17 边界: 非仓内上下文（无 ③flow-state.js）→ 五载体段跳过 + rc=0
ok 5  T17 缺件: 仓内上下文但 ④gate-helpers.sh 缺失 → 🔴 CARRIER-MISSING 具名转红
ok 6  T17 解析: 载体③段锚点漂移 → 🔴 CARRIER-PARSE fail-closed（未验证 ≠ 通过）
ok 7  T17 ①反向: SKILL.md 增预设名 → rc≠0 + 双面具名转红（含 fake 名）
ok 8  T17 ②反向: bats mock 增预设分支 → rc≠0 + 双面具名转红（含 fake 名）
ok 9  T17 ③反向增: flow-state.js PRESET_MAP 增键 → 仅五载体面红（T07 面仍绿）
ok 10 T17 ③反向删: flow-state.js PRESET_MAP 删键 → 仅五载体面红
ok 11 T17 ④反向a: gate-helpers 值域内部不一致（jq/case 双处）→ rc≠0 具名
ok 12 T17 ④反向b: 值域未覆盖 bash 侧使用值 → rc≠0 具名
ok 13 T17 ⑤反向删: 用户指南删预设行 → 折算后未覆盖 → rc≠0（指南无写权，只报不代修）
ok 14 T17 ⑤反向增: 用户指南增未知预设行 → 折算后含未知预设名 → rc≠0
ok 15 T17 折算机制: GC5_GUIDE_ALIAS_FOLD 内置 + _gc5_guide_fold_name identity 兜底（source 模式）
（bats rc=0）

$ make check-gate-sync        → rc=0
   ✅ 预设名集合一致 (17 个预设) — 键值对集合比对通过 (34 对，双侧同一提取器 resolve_gate_config 读生产文本)
   ✅ 五载体预设名集合一致 (①skill 17 ②bats 17 ③js 17=权威 ⑤指南折算 17；④值域 both independent L2 L3 true ⊇ 使用值 both 且 jq/case 双处内联一致) — C14-b/AC-12-b
   覆盖度: gate-config 校验面 2/2（①②键值对集合 + 五载体预设名/值域对账 · T17/C14-b/AC-12-b）
   ✅ 校验对 2/2 一致（键值对集合 + 五载体名集/值域对账；仅覆盖本校验面）

$ make check-test-sync        → rc=0   ✅ test 双源一致（镜像 cmp 亦 MIRROR-IDENTICAL）
$ make lint                   → rc=0   ✅ shellcheck: no errors found
```

附加回归（不在任务块 verify 清单、为证「不弄红既有面」而跑的邻居套件，均 rc=0）：
test/test_check_gate_sync.bats 18/18 ok、test/test_quality_baseline.bats 15/15 ok、test/test_skills_sync.bats 12/12 ok。

## §4 偏差与决策记录

1. **flow-state.js / gate-helpers.sh 未改动**：任务块预留写权「仅当需对齐」，实测五载体本就一致，无需对齐（见 §1）。
2. **verify 清单外补跑三个邻居套件**：任务块要求 bats 新测试 + 两个 make target（+镜像 cmp + lint）；因新段插入既有脚本，补跑 check-gate-sync 相关既有套件以证 T07 面/沙箱腿/quality 基线未被弄红——属验证性只读操作，非全量 make test。
3. **③增删反向腿同时把⑤拖红**（js 键集漂移 ⇒ 指南名集相对③出现未知/未覆盖方向）：语义正确（③是权威，两侧对比都以它为基准），断言聚焦③具名行与 T07 面仍绿，不视为偏差。
4. **CARRIER-PARSE 报文允许「同源复报」**：①②复用 T07 提取器，若 skill/bats 解析失败则键值对面与五载体面各计 1 错（ERRORS=2）——报文已注明同源复报，计数语义为「处」非「根因」。

## §5 遗留偏差（非 T17 辖，如实记录）

1. dist/dsh-flow-kit/{docs,vendor} 指南副本 md5 与 root/bundle 指南漂移（T15-SUMMARY §5① 已记录：有人改指南未跑 make dsh-sync）——T17 未动指南，不辖此偏差，交编排者知悉。
2. 工作树中 T12c/T15 等兄弟波改动（M/?? 若干）非 T17 所写，未触碰。

## §6 六维内置快查表

| 维 | 自查 |
|---|---|
| ① 任务边界 | 仅 T17；T07 段字节不动（:223 健康行原文 grep 验证在位）；未动 TASK.md/.flow-active/skills/prompts/指南 |
| ② 写权限 | 实写：check-gate-sync.sh、test/test_gate_config_carriers.bats、flow-kit-bundle/test/ 镜像、本 SUMMARY；flow-state.js/gate-helpers.sh 预留未用（实测无需对齐）；未 commit |
| ③ 防虚构 | 每文件写后立即 grep/运行回验（新函数群 grep 命中、15 腿实跑、make 三 target 真跑）；增量落盘（脚本→测试→镜像→SUMMARY 逐个落） |
| ④ 镜像一致 | `cmp test/test_gate_config_carriers.bats flow-kit-bundle/test/test_gate_config_carriers.bats` → MIRROR-IDENTICAL；make check-test-sync rc=0 |
| ⑤ verify 真跑 | §3 全部真实输出；**未跑全量 make test**（归编排者波末） |
| ⑥ 偏差如实 | §4 四条 + §5 两条，无隐瞒 |
