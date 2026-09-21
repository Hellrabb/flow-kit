# CHANGE: 堵住三个门禁盲区（打包件新鲜度 / lint 文件域 / exec 判据）

- **Change ID**: health-fix-2026-09
- **创建日期**: 2026-09-20
- **路径建议**: 完整（0 → 1 → 2 → 3 → 4 → 5 → 6 → 7）
- **状态**: draft

---

## Why（为什么做）

2026-09-20 全量健康巡检（`.specs/health/2026-09-20-HEALTH.md`，97/100）过程中，三次出现**「改动已完成、CI 全绿、但门禁完全没看见」**的情况。三者都不是代码缺陷，而是**检查器自身的判据缺陷** —— 危害在于制造"假安全感"：

1. **dist 打包件无新鲜度门禁（后果最实）**：`61c4bf8`（09-18）把工件截断上限从「字符」改为「字节」，但 `dist/` 仍是 09-11 构建 —— 打包件里的 README 落后源码 7 天，**发出去的文档写的是 `max_artifact_chars` + 「缺省 20000 字符」**。用户按它配 60000 期待"6 万字符"，实得 60000 **字节** ≈ 2 万汉字，**与预期差 3 倍**。三道现有防线全部绕过：`dist/` 被 gitignore（git 看不见它陈旧）、`make check` 五门不覆盖 dist、`sync-hooks --check` 只比 hooks 不比包顶层文档。**这是唯一一个已经产生用户可见错误后果的项。**

2. **`make lint` 文件域漏 7 个生产脚本**（路径级精确枚举 · 2026-09-20 复验；**初稿误写 4，系按 basename 去重所致**——`regression-demos/*/check.sh` 是 4 个同名文件）：`Makefile:23` 用 `for f in *.sh flow-kit-bundle/{lib,hooks/*}/*.sh` 枚举，漏掉 `flow-kit-bundle/install.sh`、`hooks/pre-commit/pre-commit.sh`、`flow-kit/reference/check-gate-sync.sh`、`flow-kit/regression-demos/{hallucination-guard,scope-drift-guard,strong-model-verbosity,weak-model-interactive-ui}/check.sh`。实测这些文件里**有 5 处 warning 从未被门禁看过**（`install.sh` SC2034×2 + `check-gate-sync.sh` SC2034×2 + regression-demo SC1090×1）。**`install.sh` 恰是 2026-08-03 那次 🔴 `--user` 安装链路回归的现场文件** —— 门禁盲区正好覆盖在高风险文件上。

3. **`check-hooks-sync` exec 判据过宽**：`sync-hooks.sh:188-193` 按**目录**判定可执行位（`stop/*.sh|session-start/*.sh|pre-tool-use/*.sh` 都要求 `-x`），于是把 `pre-tool-use/` 下 4 个**只被 `source`、从不被直接执行**的库误报为"缺可执行位"。该告警长期存在且每次安装都打印，会**训练用户忽略这条 warn** —— 等真有入口丢了 exec 位时反而没人看。判据应表达真实契约：**只有真入口需要 exec 位**。

**共性根因**：三个检查器的判据都比真实契约宽或窄，且**都不在 `make check` 里**（第 1 项完全无检查）。修的是"检查器看见真相的能力"。

> 来由先例：2026-06-30 健康报告 89/100 漏检 `package-flow-kit.sh` 末尾孤儿 `fi`（Critical，打包脚本不可用）→ 根因同为"巡检流程无该维度门禁"，当时新增 bash -n 门禁堵住。本次同类。

## What（做什么）

三处**检查层**修复，不碰任何运行时逻辑：

1. **新增 `make check-dist`（打包件新鲜度门禁）** —— 比对 `dist/dsh-flow-kit/` 与源（`dsh-flow-kit/` + `flow-kit-bundle/`），有差异即 fail 并指明差异文件；纳入 `make check`。jscpd/shellcheck 未装时优雅 skip 的既有惯例照搬（缺 dist 时给出"请先跑 package-dsh-plugin.sh"的可执行提示）。
2. **`make lint` 文件域改 `find` 枚举** —— 替换 `Makefile:23` 的 glob 列表，确保**所有**生产 `.sh` 被扫（含上述 7 个漏网脚本），并保留 `-e SC1091` 与 error 级门禁语义不变。
3. **`check-hooks-sync` exec 判据收窄为「仅真入口」** —— `sync-hooks.sh` 的 exec 检查改为只对真被执行的入口（stop 主模块、session-start、pre-tool-use 的 3 个入口、pre-commit）要求 `-x`，被 `source` 的库不再要求。

## 影响面

- [ ] 影响 `REQUIREMENT.md`
- [ ] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC（写出哪些）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [x] 仅修复 bug，无范围变化 —— 修的是检查器判据，被测对象的运行时行为不变
- [x] **影响 `make check` 的组成**（新增 check-dist 门禁）→ 需 DESIGN 说明门槛与失败语义
- [x] **影响 `make lint` 的实际扫描面** → 可能**新暴露**既有 warning（预期：7 个被漏脚本里的 5 处）；须确认这些是 known-acceptable 还是需顺带修

> ⚠️ 影响面第 2 条是本次真正的风险点：**门禁一旦变严，可能立刻变红**。DESIGN 必须给出"新暴露的 5 处 warning 如何处置"的决策（修 / 登记豁免 / 降级为 note），否则 change 会在 5-test 阶段被自己的新门禁挡住。

## 范围排除（这次不做）

- ❌ **不做** `prompts ↔ skills` 双载体同步门禁（TD-025 🟡）—— 需要先回答"skills/ 是 prompts 的镜像还是允许差异的独立精简版"这个**产品判断**，属独立决策，塞进 health-fix 会让本 change 范围失控
- ❌ **不做** `sync-hooks.sh:243` SC2221/SC2222 的 `disable` 注释 —— 已复核为**假阳性**（外层 `_d` 循环已限定取值域），单独登记，不并入本 change
- ❌ **不做** 打包产物清理类装饰项：清 `dist/dsh-flow-kit-0.1.0.tgz` 历史 tarball、`vendor/` 权限逐位对齐源 bundle —— 无功能收益
- ❌ **不改** 任何 hook 运行时逻辑（`hooks/**` 的内容语义）、不改 `package-dsh-plugin.sh` 的产物内容 —— 本 change 只碰 Makefile / sync-hooks.sh 的**检查层**
- ❌ **不新增** 对 `brooks-lint` / `brooks-tools` 第三方目录的任何检查

## 验收线（粗粒度，不是 AC）

1. **改任一「进入 dist 的源文件」（以 `package-dsh-plugin.sh` 的实际打包域为准，至少含 `dsh-flow-kit/README.md`）、不重建 dist → `make check` 必须变红并指出是哪个文件陈旧**；重建后恢复绿。（直接复现本次 README 事故的形态；判据细节见 REQUIREMENT.md AC-1）
2. **人为在 7 个漏网脚本之一里引入 syntax error → `make lint` 必须抓到并 fail**。（当前行为：完全静默通过）
3. **`check-hooks-sync` 在健康的仓库上不再输出 exec-bit 告警**；且**人为摘掉一个真入口的 exec 位时仍能报警**。（证明是收窄判据而非关闭检查）
4. `make check` 全绿（含新增的 check-dist），全量 bats 不退化（基线 950 ok / 0 not ok / 1 skip）。

## 风险与未知

- **R1（高）门禁变严可能立刻变红**：`make lint` 扩面后预计新暴露 5 处 warning。若把 warning 也设为 fail，会当场红；若只保留 error 级门禁（现状），则扩面**不改变**红绿结果，只让 warning 可见。**倾向：保持 error 级门禁语义不变**，把 5 处 warning 作为"可见性收益"记录，不升级为 fail。DESIGN 定案。
- **R2（中）`check-dist` 的比对基准与噪声**：dist 含生成/拷贝产物（vendor 全量副本、tarball），全量比对可能引入虚假差异（如 tarball 二进制、mtime 相关）。需明确**比什么、不比什么**（倾向：只比文本内容 + 明确排除 tarball）。另外 `package-dsh-plugin.sh` 会 `rm -rf` 并重建 dist，**如何在重建后判断"是否与源一致"而不依赖 mtime** 是核心设计点。
- **R3（中）check-dist 纳入 `make check` 的副作用**：`make check` 被 pre-commit hook 调用（实测超 60s）。新增门禁若慢会拖长每次提交。须实测耗时（倾向：纯 diff，应 < 1s）。
- **R4（低）「真入口」清单的维护性**：exec 判据收窄后，"哪些是真入口"需要一个单一事实源（避免下次拆分 hook 时又漏）。倾向复用现有 `HOOK_MODULE_NAMES` + pre-tool-use 入口白名单，并在 DESIGN 里说明该清单从哪来。
- **未知**：`check-dist` 是否需要覆盖 `dist/dsh-flow-kit/vendor/`（全量 bundle 副本）。覆盖更严但可能因 test 双源同步时机产生偶发差异；不覆盖则 vendor 陈旧（本次即发生）不可见。DESIGN 决策。

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
