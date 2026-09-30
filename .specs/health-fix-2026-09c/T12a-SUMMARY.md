# T12a-SUMMARY — C13 SKILL 薄壳化 16 载体 + skill 独有条款并入（AC-11）

- **Change ID**: health-fix-2026-09c
- **Task ID**: T12a
- **完成时间**: 2026-09-30（CST）
- **AI 角色**: Dev（阶段 4 · fresh context 单任务）
- **上游**: T11 已提交 d8a5673（flow-dev 薄壳范式样板）

---

## 做了什么（一段话）

按 D2/D5 完成 C13 薄壳化两步：**步骤①侦查处置**——对 16 载体做 D7 归一化段集 diff（`grep -vE '^[[:space:]]*$|^---$|^```'` + sort -u + comm），实测 8 个净对（skill 侧 unique 仅 frontmatter name/description 两行，无独有条款）、6 个分叉载体共 25 条 skill-独有条款（并入 14 / 弃用 11，逐条对账见 TASK.md「C13 skill-独有条款处置清单」，弃用理由同步登记 CHANGE.md C13 段）；**步骤②薄壳化**——14 个 SKILL.md 压为「frontmatter（逐字保留）+ 薄壳声明 blockquote + 单条 `@see` 权威 prompt」8 行薄壳（flow-go 特例指 GO.md）。全仓 skill 载体 2770 行 → 679 行（-2415），权威 prompt 侧 +175 行承接并入条款。verify 四腿全绿（@see 计数 15≥13 / make lint 0 error / 处置清单 25 行逐条 grep 对账 / frontmatter 16/16 逐字节保留）。

## 16 载体处置矩阵

| 载体 | 处置 | 权威源 | 行数 前→后 | 独有条款 |
|---|---|---|---|---|
| flow-architect | 薄壳化（本任务） | prompts/A-architect.md | 264→8 | 0（净对） |
| flow-change | 薄壳化（本任务） | prompts/0-change.md | 163→8 | 1（弃用：旧弱版反问） |
| flow-design | 薄壳化（本任务） | prompts/2-design.md | 217→8 | 0（净对） |
| flow-dev | **T11 已完成（范式样板）** | prompts/4-dev.md | 456（不动） | T11 已处置 |
| flow-evolve | 薄壳化（本任务） | prompts/A-evolve.md | 347→8 | 0（净对） |
| flow-go | 薄壳化（本任务 · D5 豁免映射特例） | **GO.md** | 393→8 | 10（并入 5 / 弃用 5） |
| flow-health | 薄壳化（本任务） | prompts/M-health.md | 259→8 | 2（并入 2，含 bash -n 语法门禁整节） |
| flow-integration | 薄壳化（本任务） | prompts/7-integration.md | 187→8 | 7（并入 5 / 弃用 2） |
| flow-intel | 薄壳化（本任务） | prompts/I-intel-scan.md | 255→8 | 0（净对） |
| flow-kit-install | **豁免（D5 登记）**：安装器自包含，无对应 prompt 载体 | —（自身即权威） | 111（不动） | — |
| flow-requirement | 薄壳化（本任务） | prompts/1-requirement.md | 67→8 | 1（弃用：旧版反问节） |
| flow-restyle | 薄壳化（本任务） | prompts/L-restyle.md | 197→8 | 0（净对） |
| flow-review | 薄壳化（本任务） | prompts/6-review.md | 233→8 | 8（并入 2 / 弃用 2 + 轮次架构差异） |
| flow-task | 薄壳化（本任务） | prompts/3-task.md | 140→8 | 0（净对） |
| flow-test | 薄壳化（本任务） | prompts/5-test.md | 273→8 | 0（净对） |
| flow-ui-design | 薄壳化（本任务） | prompts/2a-ui-design.md | 280→8 | 0（净对） |

skills/flow 不辖（D5 glob 豁免，未触碰）。

## 条款处置（25 条 = 并入 14 + 弃用 11；逐条对账表在 TASK.md）

**并入 14 条**（锚串已在权威载体 grep -qF 逐字命中，verify 对账全绿）：

| 目标载体 | 并入锚串（grep -qF 特征串） | 来源 |
|---|---|---|
| prompts/M-health.md | `步骤 2.6 · 全量 bash -n 语法门禁`（:233 整节）/ `步骤 2.6 bash -n 语法门禁已跑`（:245 自检行） | flow-health |
| prompts/7-integration.md | `归档完成。是否将当前分支合并到 main`（:391）/ `git checkout main && git pull && git merge`（:397）/ `合并到 main 和创建 PR 均需用户明示确认，禁止自动执行`（:438）/ `合并到 main 已询问用户`（:449）/ `创建 PR 已询问用户`（:450） | flow-integration §6.1/§6.2 |
| prompts/6-review.md | `2.0 TEST.md 5 轮金字塔完整性`（:218，补悬空引用）/ `4.1 技术债评估`（:301，补悬空引用） | flow-review |
| GO.md | `FLOW_KIT_ROOT`（第〇步整节 :73-93）/ `真实成本影响因子`（:58 六因子表）/ `Forge adapter: detected / not detected`（:124 adapter 检测节）/ `interrupt.active_file`（:109 第一步升级）/ `⚡︎ 全读`（:335 加载工件语义约定+per-phase 表 11 行） | flow-go |

**弃用 11 条**（理由一句/条，全文登记 CHANGE.md C13 段 :351-367）：flow-change 旧弱版反问（0-change.md R3.5 强化版已覆盖）· flow-requirement 旧版反问节（1-requirement.md 强化版已覆盖）· flow-integration 5.0.x 清理旧措辞 + 孤儿扫描/L2 变体（prompt 5.0.1-5.0.3 强化版已覆盖）· flow-review §4.2 跨模型 spot-check 旧版（ADR-014 Critical-Triggered 版 + INDEPENDENT-REVIEW-6.md 承载）· flow-review 三轮+第四轮轮次架构正文（prompt 单轮 A/B/C/D 合并版语义全覆盖）· flow-go 查 reference 示例（loading-artifacts.md §3 同款）· flow-go 用户视角取舍表（GO.md 挡位菜单同款映射）· flow-go 3.3 说明段（非条款）· flow-go 典型成本表明细（README「Token 成本表」承载）· flow-go 路由表/极少数情况/自检变体（GO.md 已有对应节且含新增演进）。

## frontmatter 保留自检（R1 硬约束）

- 侦查阶段先固化 16 载体 frontmatter 快照（head -4，/tmp），薄壳化后同法重建逐字节 diff：**`diff` 输出为空 → FRONTMATTER-PRESERVED-ALL-16**。
- 14 个薄壳 SKILL.md = frontmatter 4 行 + 空行 + 薄壳声明 1 行 + 空行 + @see 1 行（name/description 逐字节来自原文件，触发词零改动）。
- flow-dev（456 行）与 flow-kit-install（111 行）未触碰。

## verify 真实输出（TASK.md:361 原文照跑）

```text
$ test "$(grep -l '@see' flow-kit-bundle/skills/flow-*/SKILL.md | wc -l)" -ge 13 && make lint && <处置清单 awk 对账>
see-count: 15 (>=13 OK)          ← 14 本任务 + flow-dev(T11)
🔍 make lint: shellcheck (error level only, rc-based)...
SCANNED_FILES: 68
✅ shellcheck: no errors found
VERIFY-ALL-PASS (rc=0)           ← 处置清单 25 行：14 并入全部 grep -qF 命中，11 弃用格式合法
```

## 6 维自查（内置快查）

1. **越界（write_files 面）**：改动 = 14×SKILL.md + 4 权威载体（GO.md/prompts×3，均在授权面）+ TASK.md 处置清单节 + CHANGE.md C13 段内追加 + 本 SUMMARY。无越界文件。✔
2. **R1 frontmatter/触发词**：16/16 逐字节保留（见上节）。✔
3. **TASK.md 纪律**：只动「C13 skill-独有条款处置清单」节（占位 blockquote → 实表），任务状态/其他任务块零改动。✔
4. **禁改面**：未 git commit；未动 .flow-active；CHANGE.md 只在 C13 段内追加（C13 段 :333-367，C14 起始位移 :351→:369 为段内追加所致）；未跑 make test-sync/check-test-sync。✔
5. **镜像纪律**：本任务未触碰 test/，无双写需求；未动 dist/ 构建产物副本（见偏差②）。✔
6. **防虚构**：每次写文件后立即 grep 回验锚串；verify 原文实跑贴真实输出；最终消息附 git status --porcelain 原始输出。步骤①曾发生一次擅自增行（6-review 4.1 节加了原文没有的「未装 brooks-lint → 跳过」行），核对 skill 原文后已当场删除并补齐真正的第三条处置（🟢 Monitored）——如实记录，最终并入文本与 skill 原文逐字一致。✔

## 偏差记录

1. **条款实测 25 条 vs 预估 52**：52 为 DESIGN 时点旧计数（当时 11 对已分叉）；其后 T11 及此前波次已把 10/14 prompt 对的 unique 归零（本次实测 8 净对 + flow-dev 已处置 + flow-kit-install 豁免），分叉仅剩 6 载体；且条款粒度按强制小节合并计（如 flow-go 第〇步 4 级查找 = 1 条）。处置完整覆盖全部实测独有条款，零蒸发。
2. **dist/ 构建副本未同步**：dist/dsh-flow-kit/skills/ 与 dist/dsh-flow-kit/vendor/flow-kit-bundle/skills/ 下存在 16 SKILL.md 与 GO.md 的构建产物副本，不在本任务 write_files，未触碰——重建打包时自 dist 源（flow-kit-bundle/）刷新；如需门禁覆盖属 T12b/编排者范围。
3. **flow-go 权威源为 GO.md 而非 prompts/**：D5 豁免映射特例，@see 指 `flow-kit/GO.md`；GO.md 写权由 TASK.xml L2 r5 R3 修订条件性补权，已满足（5 条并入全部落在 GO.md）。
4. **净对 8 载体无处置行**：norm diff 无独有条款，故处置清单无对应行（非遗漏）；矩阵已逐一登记「0（净对）」。
