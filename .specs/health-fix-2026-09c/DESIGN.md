# DESIGN: health-fix-2026-09c —— 巡检发现 C1–C14 v1 面修复

- **Change ID**: health-fix-2026-09c
- **关联**: `@.specs/health-fix-2026-09c/REQUIREMENT.md`、`@.specs/CONTEXT.md`、`@flow-kit/reference/tech-stacks.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 由 2-design 步骤 0 锁定。变栈视为开新 CHANGE（R7.1）。本次为既有栈内修复，无换栈。

- **选定**：Bash 脚本项目（CONTEXT.md §技术栈 已锁 · meta/distribution）
- **前端/后端/数据库**：N/A（纯 Shell 分发包仓库）
- **部署**：tar+gzip（`package-flow-kit.sh`）+ DSH 插件包（`package-dsh-plugin.sh`）
- **关键依赖**：bash 5.x / jq / git / shellcheck 0.9.0 / bats-core 1.13.0（npx）/ **git-filter-repo 2.47.0**（AC-5 历史重写，已装 `~/.local/bin`）/ node v22（仅 dsh 插件 JS 单测）
- **理由**：全部 AC 均为既有门禁/载体/测试的结构修复，无新增运行时面。
- **明确排除**：不引入 Python/Node 进生产 hook 链（`check-path-privacy.sh` 等保持纯 bash）；不引入新第三方库。

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块（grep 实证）

```
触碰模块（grep 出来的实际清单）：
生产：
- flow-kit-bundle/flow-kit/reference/check-gate-sync.sh（C5/C11：解析对象从 mock 换生产 .sh · :189-234）
- flow-kit-bundle/flow-kit/reference/check-path-privacy.sh（C2/C3：基线文件化 · C14-f：:89-95 SELF_EXCLUDE 六行含**四条** 09b 行——09b allowlist + INDEPENDENT-REVIEW-1/2/3——+ :102 ALLOWLIST_CHANGE 解除硬编码 · AC-3：:72 通用 PAT 放宽 + PLACEHOLDER_NAMES 扩全 + 头部「下游误报处置入口」锚点）
- flow-kit-bundle/hooks/stop/29-independent-review.sh（C4：:200 || true 吃掉 L3 backlog 告警 · C8-③：L2-first 报文 ×2）
- flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh（C12：:64 fail-open → fail-closed）
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（C12：**:65/:114** fail-open → fail-closed；**:64 保留放行**——`[ -f "$flow_file" ] || exit 0` 是「无状态文件 = 非 flow-kit 项目管辖」契约（:15 头注释），转 exit 2 会阻断所有非 flow-kit 项目的全部工具调用；转换点补注释固化该契约；:42-46 source 三子库后补断言）
- flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh（C12 同批：**头注释 :5/:11「fail-open·不阻断」随 D4 落地同步改写**；其 `\|\| exit 0` fail-open 点转 fail-closed；连带 CONTEXT.md 域语言表「auto-checkpoint PreToolUse 层 v1 fail-open」行同步——反哺阶段 7-integration 一并落）
- flow-kit-bundle/hooks/stop/lib/common.sh（C14-a：删死代码 jq_atomic_write(:192)；其余只读参照，见禁动）
- flow-kit-bundle/hooks/pre-tool-use/ 三子库 gate-helpers.sh / gate-checks-basic.sh / gate-checks-review.sh（C12/AC-8：被 independent-review-gate.sh:42-46 source 后无 declare -f 断言 → 对齐 :33-37 既有范式补断言 + 函数缺失 → exit 2）
- flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh:26（C14-b 第四载体：jq 过滤器内联值域 independent|true|both|L2|L3 + :29-30 case 二次内联 → 纳入预设名集合比对）
- flow-kit-bundle/hooks/stop/lib/l3-review.sh / l3-prompt.sh / l3-section.sh（ADR-032 决策 2 纵深：补 jq 存在性断言，对齐 common.sh:226 范式——AC-8 字面外，CHANGE 显式注明）
- flow-kit-bundle/hooks/stop/lib/l2-detect.sh（C8-③：`_l2_first_deny()` 报文函数抽至此，29-independent-review.sh 两处改调用，生产报文唯一化）
- flow-kit-bundle/flow-kit/prompts/*.md（14 个 · C13 权威载体 · C8-①：4-dev.md 删内联表）
- flow-kit-bundle/skills/flow-*/SKILL.md（16 目录 · C13 薄壳化 · C8-①：flow-dev 对）
- flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md（C8-②：163 行复制段引用化）
- Makefile（C1：F6 沙箱范式 · C7/C10：隔离 · C14-d：:76↔:84 口径统一 · C14-e：node --test 纳入 · 新 check-skills-sync 挂链）
- package-dsh-plugin.sh（C14-e：:233 已有 node --test，接线 make check）
- dsh-flow-kit/lib/（flow-state.js / index.js / l2-review.js · C14-b：预设名三载体对齐）
- flow-kit-bundle/lib/install_hooks.sh（AC-17：pre-push 部署链 **:95-137 已存在**——is_flowkit_symlink(:95) / deploy_pre_push(:124，行号按 L2 阶段 3 r2 R13 校正 2026-09-29) / install_file(:126) 已装 bundle 脚本 / symlink 幂等(:132-137)，**换装机制无须新建，本 change 只改 pre-push.sh 本体 + .git/hooks 实例**——原 :291-301 为 check-path-privacy 部署块误标；:189-192 安装期 fail-closed 为 C12 参照范式，只读）
- flow-kit-bundle/hooks/pre-push/pre-push.sh（AC-17：**本体改造**——实测全文无 flock（grep 计 0），须内置 flock 并发闸（与测试同款 F6 范式：锁文件 + mktemp），换装只是部署路径）
测试（含 bundle 镜像，make test-sync 双写）：
- test/test_check_gate_sync.bats（C1/C5：沙箱 + 反向控制）
- test/test_gate_config_presets.bats（C5 mock 主战场：实测 `"independent"` ×72 → 改 both，与值比较逻辑同批不可拆）
- test/test_l3_review_defects_2026_09.bats（C6：18 处 grep 探针沙箱化 · C14-h：be138c0 硬编码 SHA 处置）
- test/test_path_privacy_gate.bats（C2/C3 · C14-f：:31,:656-659,:685 的 09b 路径字面量同步收敛）
- test/test-l2-first-correction.bats（C8-③ 断言对齐）
- test/test_fix_l3_gate.bats（C6：6 处）· test/test_l2_pretooluse_dispatch.bats（C6：4 处）· test/test_dual_review_merge.bats（C6：3 处）· test/test_l3_lifecycle_wiring.bats（C6：1 处）——AC-9 的 32 处行为断言全清单
- test/test_hook_integration.bats（C14-h：grep 探针类降级 skip，实测 :17,:20-22,:31,:34-37 区间 → 改行为断言或显式 skip+原因；此前误挂 test_l3_review_defects 名下，已纠正）
- C14-c 软跳过 11 文件（CHANGE 口径）：test/test_l3_pipeline_fix.bats（:561-564 真空通过，先修）· test/test_independent_review_model.bats · test/test_l3_review_defects_2026_09.bats · test/test_runtime_edit_guard.bats · 其余以 CHANGE C14-c 清单为准（TASK 首任务 grep 重核固化全名单）

specs 文档面（C3 脱敏 6 文件 · AC-4 的 30 行真名所在）：
- .specs/health/2026-09-22-FULL-SWEEP.md · .specs/archive/2026-09-28-health-fix-2026-09b/INDEPENDENT-REVIEW-1.md · 同目录 INDEPENDENT-REVIEW-2.md · .specs/STATE.md · .specs/LESSONS.md · .specs/CONTEXT.md
  （销账载体 STATE.md 指**仓库级** `.specs/STATE.md`——实测存在，107 行，阶段 1 已更新活跃段；与 change 目录内 PROGRESS.md 是两个文件，AC-14 计数锚定前者）
- .specs/ARCHITECTURE.md（§2.2 增补行——ADR-030 决策 3 的 7-integration 义务）

新增模块：
- flow-kit-bundle/lib/flow-active-query.sh（C14-g：.flow-active 统一解析入口）
- .specs/adr/030-…md / 031-…md / 032-…md（本设计 ADR）
- test/test_flow_active_query.bats / test/test_skills_sync.bats / test/test_fail_closed.bats / test/test_l3_backlog_alarm.bats（随 TASK 定名）
- .specs/health-fix-2026-09c/scrub-history.sh（**T16 执行脚本留痕**，L2 阶段 3 M13 补登 2026-09-29：AC-5 五步序列的落地载体，落 change 目录随归档存证）
- **首建说明（L2 阶段 3 R8 修订 2026-09-29）**：path-privacy-baseline 与 flow-active-inline-whitelist 两工件 **09c 目录从未创建过种子副本**（初版 DESIGN 写了「种子」但未落盘）；**v1 即直接首建常设路径** `flow-kit-bundle/flow-kit/reference/`（规范来源 = 本 DESIGN 附录 A），change 侧不放副本；读序 **常设 > change 目录 > 双缺 fail-closed**（change 目录**种子副本**取消——v1 首建常设即自足；change 来源层读序保留、兼容后续 change 副本。**L3 重审 r2 m5 修订 2026-09-29**：原「常设 > 双缺」两层表述漏 change 层，与 ADR-028:43 / ADR-031:16 / check-path-privacy.sh:97-102 既有三层读序不符）
- **常设落点（终局，随包分发不受归档影响——沿用 ADR-028 决策 1 先例；L2 重审 R1 修订 2026-09-29）**：flow-kit-bundle/flow-kit/reference/path-privacy-baseline.txt **只存通用 PAT 定义 + 占位形态 + 每字面量一行 sha256 哈希对账行（不存真名明文）**——tracked/分发面真名恒 0（AC-4/AC-5/US-3 才可满足）；真名明文集**运行时仓外组装**（AC-5 步骤 ⓪ 同款先例：执行时从 `git remote get-url origin` + `$HOME`/`pwd` 派生生成 `../scrub-literals.tmp`，filter-repo 用毕删除，不入任何 tracked 文件）。flow-kit-bundle/flow-kit/reference/flow-active-inline-whitelist.txt（ADR-031 白名单 + 计数基线，纯路径无真名，可 tracked）；读序 **常设 > change 目录 > 双缺 fail-closed**（change 种子副本取消——R8 修订；即 check-path-privacy.sh:97-102 既有读序——**L3 重审 r2 m5 修订 2026-09-29**：该代码注释本就是三层，原引作两层佐证系误读）
- flow-kit-bundle/flow-kit/reference/check-skills-sync.sh（**落点定死 = reference/**：随 ADR-030 豁免——独立可执行检查器、零 source 生产依赖、判据二值 fail-closed；与 check-gate-sync.sh / check-path-privacy.sh 同类同址）

更名触点（L2 三审 R1 补 2026-09-29 · check-gate-sync 语义拆分后 `check-skills-sync` 上线涉及的既有引用，全仓 `grep -rln 'check-gate-sync'` 实测面）：
- test/test_quality_baseline.bats:26,29-30,34-35（+ flow-kit-bundle/test/ 镜像）——`test -x …/check-gate-sync.sh` 与直接 `bash` 运行两用例，更名/拆分后必红，TASK 同批改断言目标（预设名断言归 check-skills-sync，运行断言归 check-gate-sync）
- FLOW-KIT-用户指南.md:1585（+ flow-kit-bundle/FLOW-KIT-用户指南.md 副本）——指名该脚本守护预设名，TASK 更新指名
- flow-kit-bundle/flow-kit/reference/pipeline-gates.md:4——「改完后运行 check-gate-sync.sh」提示，TASK 同批更新（该文件已是 TD-030 伪单一源，只改引用不加承诺）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/brooks-lint/**（vendor）
- dist/**（打包产物 · gitignore）
- .omo/** · .flow-kit/**（运行时状态）
- flow-kit-bundle/hooks/stop/lib/l3-prompt.sh 的 _l3_build_prompt 拆分（C9 → v2，AC-16 已登记）
- check-path-privacy.sh 的 main() 抽取与计数器收敛（C9 → v2）
- Makefile 内嵌 bash 整体外迁（C9 → v2）
- common.sh 除 :192 死代码删除外的全部函数体（TD-134：只读参照物）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 测试沙箱（并发 + 隔离） | `test/test_check_gate_sync.bats` F6 范式（flock + mktemp） | 沿用（AC-1/AC-2/AC-17 照搬） |
| jq 原子写 | `common.sh:192 jq_atomic_write` | **不沿用**（零调用者死代码，C14-a 删除；新脚本自实现 tmp+mv 简式） |
| 门禁检查器骨架 | `check-gate-sync.sh check_pair(:53)/check_gate_config_sync(:190)` | 沿用并扩展（解析对象换生产源） |
| 依赖断言范式 | `independent-review-gate.sh:33-37`（source 后 declare -f 断言）+ `common.sh:226`（fk_resolve_phase 内 `command -v jq \|\| return 1`） | 沿用（推广到 pre-tool-use 三子库 + 注入面断言；旧引 common.sh:32-37 为行号漂移，已核正） |
| 告警输出通道 | `common.sh module_output` | 沿用（C4 的 L3 backlog 告警走它） |
| `.done` 校验 | `done-validation.sh fk_validate_done_marker(:112)` | 只读依赖（不修改） |
| hook 装配 | `lib/install_hooks.sh` | 沿用（pre-push 换装走既有装配路径） |
| 预设名集合（gate_config） | `common.sh fk_normalize_gate_val(:405)` 值域 | 沿用为唯一值域来源（SKILL/bats/JS 三载体对齐锚点） |

### 0.5.3 沿用模式 vs 引入新模式

```
- 门禁实现模式：**沿用** reference/ 独立可执行 check-*.sh（ADR-030 豁免正式化）
- 测试沙箱：**沿用** F6 flock + mktemp（CONTEXT 已锁决策）
- fail-closed 语义：**引入新模式** → jq 缺失/非法 JSON 一律 rc≠0（PreToolUse=exit 2 block；检查器=exit 1），
  替换「降级继续」的 || exit 0（ADR-032）
- .flow-active 解析：**引入新模式** → 单一入口 flow-active-query.sh（ADR-031），Makefile/生产 .sh 统一调用，
  白名单文件化只减不增
- 载体关系：**引入新模式** → prompts 权威 + SKILL.md 薄壳（frontmatter + 触发描述 + @see 锚点），
  新门禁 check-skills-sync 保覆盖（CONTEXT 已锁，本设计落地为门禁）
- 基线管理：**引入新模式** → path-privacy 基线从硬编码路径改为 .specs/health-fix-2026-09c/ 下文件 + 检查器默认值
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | C5/C11：check-gate-sync 解析对象**从 mock 换成生产 .sh 当数据**（读 `common.sh`/`SKILL.md` 文本提取键值对集合比对），不 source 生产 hook 代码、不挪目录；**提取器函数名定死 = `resolve_gate_config`，定义在 check-gate-sync.sh 内**（reference/ 同层自含，不违 §2.2）；测试与检查器**双侧 source check-gate-sync.sh 获得同一提取器**（AC-7 Given 字面满足：测试 source 的是检查器自身，非生产 hook lib；`grep resolve_gate_config` 命中生产实现 = check-gate-sync.sh 内定义处） | ① 挪 check-gate-sync.sh 出 reference/；② source common.sh 复用解析 | 挪目录牵动 Makefile/install/dist/测试四面；source common.sh 违反 ARCHITECTURE §2.2（reference→code ❌）。当数据读是文本依赖，与「reference 纯文档」精神相容（ADR-030 正式豁免） | 提取器对源码格式敏感：格式漂移须转红（fail-closed）而非误绿；反向控制（both→independent 注入必须 rc≠0）入 bats |
| D2 | C13：**权威载体 = prompts**（已锁）；16 个 SKILL.md 薄壳化 = YAML frontmatter + 触发描述 + 正文替换为 `@see` 权威正文锚点；新门禁 `check-skills-sync`（14 对全覆盖 + @see 锚点存在 + 注入漂移 rc≠0） | ① skills 权威反向；② 双正文并存 + 差异阈值；③ 生成器方案 | 双正文已实证 11/14 对分叉、95 vs 52 独有小节；生成器引入构建步骤，超 v1 面 | 薄壳化是 16 文件大面积改写：触发词须逐字保留（防技能路由回归）；`4-dev`/`6-review` 等体量分化对的差异内容需逐对甄别去留（TASK 列清单） |
| D3 | C14-g：新建 `flow-kit-bundle/lib/flow-active-query.sh` 为 `.flow-active` **唯一解析入口**（jq 包装、fail-closed、只读）；**改调清单（必须项，均不进白名单）**：`Makefile:250-253` 手搓 bash 解析（while/read/case 提取 change_id）+ `independent-review-gate.sh:63-65` 变量间接读取（`flow_file="$cwd"/.flow-active` + `jq empty "$flow_file"`——旗舰 hook 不得自免检，L2 重审 R3 修订 2026-09-29）；检测谓词 = 附录 A 四分支（含 JS 域与变量间接），不只认 jq 同行字面量；**白名单在 DESIGN 定稿（AC-12g）**：严格谓词 + 条目格式见附录 A，最终文件落**常设路径** `flow-kit-bundle/flow-kit/reference/flow-active-inline-whitelist.txt`（v1 直接首建常设，种子层取消，读序**三层：常设 > change 目录 > 双缺 fail-closed**——对齐 ADR-028:43 与 ADR-031:16；**L3 阶段 3 m4 修订 2026-09-29**：原「常设 > 双缺」漏 change 目录层且「沿用 ADR-028 决策 1」系误引所引 ADR 原文，ADR-028 决策 1 本身即三层） | ① Makefile 各处继续内联/手搓；② 解析函数进 common.sh | 手搓解析与内联 jq 同属格式知识内联（schema 变更静默失败），只认 jq 的白名单会永久放走非 jq 解析器；common.sh 是 hook 链热路径，塞 CLI 入口扩大 hook 依赖面；per-change 路径会随归档失效（09b 已实证学费） | 白名单收敛是渐进面：v1 收敛「无借口」文件；JS 侧存量三文件登记白名单（替代闸 = §9.3 五载体集合比对；长期经 hook-bridge 调 bash 入口挂 TD v2）；计数门禁只减不增，余量挂 TD |
| D4 | C12：门禁依赖统一 **fail-closed**——注入面三类（① jq 缺失 ② `.flow-active` 非法 JSON ③ **source 后关键函数缺失/半安装**——declare -f 断言覆盖；**「函数遮蔽/重定义为空体」显式移出**：declare -f 只证存在不证行为，遮蔽注入按现机制不产生 rc≠0，不承诺做不到的反向控制）：PreToolUse hook → `exit 2`（block 该次工具调用并给指引）；Stop 检查器 → `exit 1`；落点 = independent-review-gate.sh / auto-checkpoint.sh 的 `\|\| exit 0` 点 + independent-review-gate.sh:42-46 三子库（gate-helpers / gate-checks-basic / gate-checks-review）source 后补 declare -f 断言（对齐 :33-37 既有范式）；stop/lib l3-* 三库的 jq 断言作为 ADR-032 纵深（超出 AC-8 字面，显式注明） | ① 维持 fail-open + 告警；② 只在安装期拦截；③ 断言后追加行为探针（被否：对每函数写探针 = 断言面翻倍且探针自身漂移，v2 再议） | fail-open 已实证可静默放行篡改（C12 对照表）；安装期拦截（install_hooks.sh:189-192）挡不住运行时环境漂移；函数缺失面 = AC-8 第三注入 | jq 缺失环境从「静默降级」变「显式 block」：用户体验变硬，靠错误信息给修复指引缓解；bats 须 mock jq PATH / 非法 JSON / 删函数·改名三注入反向控制（按 AC-8 字面，不含遮蔽） |
| D5 | AC-11（M2 承接）：覆盖阈值定 **100%**——14 对 prompts↔skills 全对齐 + 每对 @see 锚点**可解析**（锚点目标文件存在且标题/行锚命中，目标缺失 → rc≠0）；**配对豁免显式化**：flow-go → 权威正文 `flow-kit/GO.md`（D7 同构处理）、flow-kit-install → 安装文档型技能（无 prompt 对应，登记豁免+理由）；`skills/flow/`（PRESET_MAP 所在）不匹配 flow-* glob，不受此门禁管辖（门禁只辖 flow-*） | ① 阈值 90% 起步；② 内容相似度阈值 | 薄壳化后「覆盖」退化为结构判据（frontmatter/@see/触发描述存在），可精确断言，无相似度噪声；16−14=2 的未配对目录若无显式豁免，门禁上线即永久红（AC-13 不可达） | 豁免清单本身是新的维护面（新增 skill 目录须先配对或登记豁免再合入）；反向用例（删 prompt 小节必红）入 test_skills_sync.bats |
| D6 | C4：**删除 `29-independent-review.sh:200` 的 `\|\| true`，rc 前置捕获后经 `module_output "warning" "IR" "backlog L3 failed for phase …"` 打印**（对齐 AC-6 字面：Given 删 \|\| true / Then warning 实际打印）；Stop 链不中断的兜底由 `00-gate.sh:71` 既有机制承担（模块 rc 非致命，本轮 grep 复核确认） | ① 保留 \|\| true + error 告警（被否：与 AC-6 正面冲突，且 error 级违反 TD-023 级别纪律——告警 ≠ 阻断，不可用 error 通道） | AC-6 是 REQUIREMENT 锁定判据；「Stop 链中断风险」论据已被 00-gate.sh:71 证伪（本设计 grep 实证） | 删 \|\| true 后若 00-gate.sh 兜底假设被 TASK 实测推翻（模块 rc 真会炸链），回退方案 = 恢复 \|\| true + warning（须同步改 AC-6，走变更流程而非静默偏离） |
| D7 | C8-②：`L2-blind-review.md` 为**唯一权威正文**；`flow-kit-l2-reviewer.md` 的 163 行复制段替换为 @see 引用 + 差异化说明（opencode 平台装配参数保留）；**单一可机检判据（L2 重审 R4 修订 2026-09-29：两侧归一化后比较）**：各自经 `grep -vE '^[[:space:]]*$\|^---$\|^```'` 滤平凡行（空行/`---`/代码栅栏）+ `sort -u`，再 `comm -12 … \| wc -l` = 0（未滤前权威段 163 行含 37 空行 + 6「重点：」+ 3 栅栏，薄壳载体必含平凡公共行 → 0 不可达 = 假红）。**AC-15-② 机检显式变更**：原「整文件 diff grep -v '^#' 为空」判据作废（opencode 侧保留 frontmatter/装配参数，整文件 diff 恒非空，不可机检）——已同步修订 REQUIREMENT AC-15-②（对账标注 2026-09-29 L3 阶段 2 + L2 重审 R4 加归一化），与 D6 同款显式变更流程，非静默偏离 | ① 双正文 + sync 门禁；② 反向（opencode 为权威）；③ 双判据并存（被否：TEST 按两判据派生会得出相反红绿） | 与 D2 同构：单一权威 + 引用化；opencode 文件仅是平台适配壳；TASK 零裁量 | opencode 无 skill 加载机制时 @see 可能不可达——保底 = 装配参数段 + 一句「正文见 @see 目标」触发说明，正文本体零复制 |
| D8 | C14-e/f：JS 单测经 `package-dsh-plugin.sh --check`（内含 `node --test`，:233）挂进 `make check`；check-path-privacy 的 09b 硬编码（:89-95 SELF_EXCLUDE + :102 ALLOWLIST_CHANGE）改为「默认值 + 环境变量/配置文件覆盖」 | ① make check 直呼 node --test；② 硬编码改传参 | 走既有打包脚本入口免重复装配；配置化保留 09b 档案可寻址又解耦巡检后续 | check 链新增 node 依赖：CI/离线环境无 node 时须 fail-closed 提示而非静默跳过 |
| D9 | 机制补决策（R8 批次，AC 有文件名无做法的四处定死；L2 重审 R1 修订 2026-09-29）：**C2 拆两问各自定死**——(a) **门禁面**（AC-3）：`check-path-privacy.sh:72` 通用 PAT 放宽（占位符模式匹配）+ `PLACEHOLDER_NAMES` 扩全，**维持既有机制，不引入真名新正则**；(b) **脱敏面**（AC-4/AC-5）：**真名明文不落任何 tracked 文件**——常设基线 `reference/path-privacy-baseline.txt` 只存通用 PAT + 占位形态 + **sha256 哈希对账行**（防基线自身静默漂移）；filter-repo 的 replace-text 文件**运行时仓外组装**（步骤 ⓪ 捕获 `git remote get-url origin` + `$HOME`/`pwd` 派生 → `../scrub-literals.tmp` → 步骤 ⑥ 删除）；DESIGN/REQUIREMENT 散文一律占位写法（本 fix loop 已将 09c spec 内真名串占位化）。**C7** 自测代理路径隔离 = mktemp 树 + HOME 覆盖（沿用 F6 范式，不自建沙箱框架）；**C10** 卸载清理判据 = 安装清单文件化（install 记录 → uninstall 按单删，残留 diff=0）；**C14-c** 双计数与终局权威 = TASK 严格谓词重算清单（`grep -l 'HOME/.claude' test/*.bats` 文件数 + 位点数求和；**HEALTH 报告附录 C 的 11/11 为种子，重算偏差以重算为准并回写 CHANGE 登记差值**） | ① 各处沿用临时裁量（被否：AC 判据空转，TASK 仍会自由发挥）；② 真名明文入 tracked 基线（被否：L2 重审 R1——SELF_EXCLUDE 只遮自检不遮 git grep/逐 blob/分发面，AC-4/5/US-3 数学上不可满足）；③ 只计数不文件化 | 逐项定死后 TASK 只做实现不做机制决策；C2 两问分离消除「正则族 vs 精确串」语义混叠；真名零 tracked 化与 AC-5「真值不入任何 tracked 文件」卫生原则同构 | C10 安装清单是新增持久文件（uninstall 兼容旧安装须 fallback 全扫）；哈希对账行防漂移但不防「真名改写后旧哈希残留」（重写完成后基线随 AC-4 重测重建）；AC-4 账面随 09c 占位化重测（30 行 → 新基线，TASK 首任务固化） |

> D1/D3/D4 可逆性低（改架构规则/新增唯一入口/改失败语义），分别落 ADR-030/031/032（§4）。D2 已是 CONTEXT 已锁决策，不再另立 ADR。

## 2. 数据流 / 架构图

```
【C5/C11 门禁真源数据流】
  生产源（文本）                     检查器                      失败面
  ─────────────────                ──────────────────────      ──────────
  common.sh (fk_normalize_gate_val
    值域 :405-419)  ──读文本──▶  check-gate-sync.sh
  skills/flow-*/SKILL.md            ├─ 提取器: 键值对集合        ├─ 解析失败 → rc=1 (fail-closed)
  (gate_config 预设行)  ──读文本──▶  │   (读生产真源文本——非 mock、非 shell source)      ├─ 集合不匹配 → rc=1
  flow-kit/prompts/*.md             ├─ 与 mock 用例块比对        └─ (反向) 注入漂移 → 必须 rc=1
  (阶段 gate_config 行) ──读文本──▶  └─ mock 值改 both
        │
        └──▶ test_check_gate_sync.bats（F6 沙箱 + 反向控制 both→independent 注入断言 rc≠0）

【C14-g 解析入口数据流】
  .flow-active ──▶ flow-active-query.sh <field>（jq 包装 · 非法 JSON/缺 jq → rc≠0）
                     ▲                ▲
        Makefile 调用 │（:250-253 手搓 bash 解析一并改调）│ 生产 .sh 调用（白名单外内联解析收敛至此）
  白名单文件（内联解析豁免清单 · 检测谓词含 jq 内联与 bash 手搓 · 计数门禁只减不增）

【C12 fail-closed 语义流】
  PreToolUse hook: jq 缺失 / .flow-active 非法 / source 后函数缺失 → exit 2（block + 修复指引）
  Stop 检查器:     同注入 → exit 1 + module_output "error"
  安装期:          install_hooks.sh:189-192 既有断言（参照，不动）

【C13 载体数据流】
  flow-kit/prompts/*.md（权威正文 · 14）
     └─@see─▶ skills/flow-*/SKILL.md（薄壳: frontmatter + 触发描述 + 锚点 · 16 目录）
                    └─▶ check-skills-sync（全对齐 + @see 存在 + 漂移 rc≠0 → make check 挂链）

【C4 告警流】
  l3_review_run … （:200 || true 已删）→ rc=$? 前置捕获 → rc≠0 时 module_output "warning" "IR" "backlog L3 failed for phase …"（不再静默；Stop 链兜底 = 00-gate.sh:71）
```

## 3. 关键状态机（如有）

无新增状态机。pipeline 门禁状态沿用 `.flow-active` 的 `pending → passed` 两态（gates 表），本 change 不改转移语义。

## 4. ADR 索引

- `@.specs/adr/030-reference-executable-checkers.md` —— reference/ 可执行检查器豁免与「数据化解析」边界（D1）
- `@.specs/adr/031-flow-active-single-parser.md` —— `.flow-active` 单一解析入口（D3）
- `@.specs/adr/032-gate-fail-closed.md` —— 门禁依赖统一 fail-closed 语义（D4）

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1（实现） | C13 薄壳化重写 16 个 SKILL.md，触发词/描述被无意改动 → 技能路由回归 | 高（skills 是用户入口） | 中 | frontmatter 与触发描述**逐字保留**（bats 断言 frontmatter diff=空）；正文段替换为 @see；每对改完跑 skill 加载冒烟 |
| R2（实现） | C5 提取器对生产 .sh 文本格式敏感：函数重构/注释变化导致解析失配 | 门禁误红（噪音）或漏判 | 中 | 解析失败显式 rc=1 + 指明行号（fail-closed 不误绿）；提取器带版本注释锚点；反向控制测试保「必红」能力 |
| R3（上线） | C12 fail-closed 使无 jq 环境的 hook 全面 block | 用户工具链被拦 | 低 | 错误信息带修复指引（装 jq / 修 .flow-active）；安装期既有断言前置暴露；bats 用 PATH shim mock jq 缺失反向验证 |
| R4（长期债务） | 28 文件内联解析白名单收敛不彻底，残余漂移 | 解析入口仍多源 | 中 | 白名单文件化 + 计数门禁「只减不增」；余量登记 TD 跟踪（v2 收口） |
| R5（数据） | AC-5 历史重写不可逆操作失手 | 仓库历史损坏 | 低 | `git bundle --all` 仓外备份 + verify 判据（REQUIREMENT Given）；重写前 `git status` 必须净 |
| R6（执行顺序） | 波次内隐式依赖被并行放大：① C2→C3（先脱敏 tracked 文件再扩正则基线，反序会把 30 行真名固化进新基线=合法红窗口失效）；② C5 值比较逻辑先于 mock 改 both（先改 mock 后改提取器 = 门禁长期红、被迫抢跑合入）；③ C13 薄壳化先于 check-skills-sync 上线（窗口内漂移无人拦）；④ AC-17 pre-push 换装先于 C12 fail-closed（新 hook 用旧语义） | 判据互相污染、门禁红窗口被「合了再说」消音 | 中 | TASK 波次显式编码此偏序（C3 依赖 C2、值比较 wave 先于 mock wave、**门禁文件紧随薄壳化（T12a W4 → T12b W5 紧邻跨 wave，偏序有界——L3 阶段 3 m8 修订 2026-09-29：原「同 wave」与波次图不符，窗口被依赖边钉死为一波）**、C12 先于 AC-17）；每 wave 收尾跑 `make check` 全绿才进下一 wave |
| R7（上线） | `.flow-active` 写方原子性与 D4 硬阻断的交互：写方若非 tmp+mv（jq_atomic_write 本就零调用者且本次删除，无保障），半写窗口的非法 JSON 会按 fail-closed **block 用户全部工具调用**直至手修 | 用户工具链在写入窗口被误伤 | 中 | 4-dev 落地时核查全部 `.flow-active` 写点统一 tmp+mv（transition/33-flow-active-integrity 等）；hook 的 exit 2 信息附「状态文件可能正在写入，重试一次」指引 + 报告写点半写残留 |
| R8（上线） | D8 给 make check 引入 node 依赖：无 node 环境跑 `make check` 时 JS 单测环节的失败语义未定（静默跳过 = fail-open 复辟） | 门禁链在离线/精简环境退化为部分绿 | 低 | 落点 = `package-dsh-plugin.sh --check` 入口自检 `command -v node`，缺失 → rc≠0 + 显式「缺 node，JS 单测未跑」（fail-closed 提示，不静默） |

> 含实现（R1/R2）/ 上线（R3/R7/R8）/ 长期债务（R4）各一，另附数据安全（R5）与执行顺序（R6）。

## 6. 不在范围

- C9 四项（main() 抽取 / `_l3_build_prompt` 拆分 / Makefile 内嵌 bash 外迁 / check-path-privacy 计数器收敛）—— AC-16 已显式降级 v2 并登记 STATE.md
- brooks-lint vendor 内部问题（含其 skills/evals 的重复）—— vendor 不动
- dist/ 生成机制与镜像策略 —— 打包产物，gitignore
- 2 份陈旧 tarball（flow-kit-bundle.tar.gz 27M · flow-kit-full-20260803-232437.tar.gz 25M）—— C14-i 仅「移出仓库根/删除」操作项，不设计打包替代方案
- dsh-flow-kit JS 内部重构 —— 仅对齐预设名集合（C14-b），不改其状态机

---

## 9. 架构沉淀建议（本 change 完成后供 `A-evolve` 同步用 · 软约束）

### 9.1 新增的可复用抽象（建议 append 到 CONTEXT 「既有抽象索引」段）

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `flow-kit-bundle/lib/flow-active-query.sh` | `.flow-active` 只读字段查询（jq 包装 · fail-closed） | 任何需要读 pipeline 状态的脚本/Makefile | 禁止再内联 `jq … .flow-active`（白名单外） |

### 9.2 新增 / 改变的项目级技术决策（建议 append 到 CONTEXT「已锁技术决策」段）

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 门禁失败语义 | 统一 fail-closed（ADR-032） | 全部 PreToolUse/Stop 检查器 | 需逐门禁回退语义 + bats 反向控制同步改，约一周 |
| reference/ 定位 | 可执行检查器豁免 + 数据化解析边界（ADR-030） | ARCHITECTURE §2.2 + 两个既有检查器 + check-skills-sync | 回退需挪目录或删豁免，牵动 Makefile/install/dist |
| 权威载体 | prompts 权威 + SKILL 薄壳（已锁决策的门禁落地） | 14 对载体 + 新门禁 | 回退 = 恢复双正文 + 撤门禁，TD-136 重开 |
| skill→prompt 直引（绕过 GO.md 路由） | 薄壳 SKILL.md 的 @see 直指 `flow-kit/prompts/*.md` 正文，偏离既有「Skills → GO.md → prompts」路由链（ARCHITECTURE §2.2 允许方向 + §5 扩展点「委托到 GO.md」——非禁止方向，属有意识模式变更） | 16 个薄壳 + check-skills-sync 判据 | 回退 = 改回经 GO.md 中转（薄壳 @see 改两跳）；7-integration 落 ARCHITECTURE §5 扩展点说明 |
| **main 历史清理提前到 v1**（L2 三审 R4 补 2026-09-29） | AC-5 ②孤儿 main 单独重写 + ⑤强推两分支——**显式推翻** CONTEXT 已锁决策 [2026-09-22]「本地 main 暂不清理只加 push 拦截（权威验证 8→0 归 v2，禁止当 bug 重报）」；依据 = 阶段 1 REQUIREMENT 定稿（用户确认范围） | REQUIREMENT AC-5 + 本行 | 7-integration 同步 CONTEXT 已锁段追加推翻记录（旧锁不删、加注「09c v1 推翻，见 AC-5」） |

### 9.3 新增 / 修改的跨模块契约（API / Schema / 事件总线）

```
- flow-active-query.sh CLI：`flow-active-query.sh <jq-path>`，stdout=值，rc：0=正常 / 1=字段缺失或检查失败 / 2=依赖缺失(jq)或 .flow-active 非法
- check-skills-sync 门禁：14 对全对齐 + @see 锚点**可解析**（目标文件存在且标题/行锚命中）；未配对 flow-* 目录无显式豁免登记 → rc≠0；豁免清单 = flow-go（→GO.md，D7 同构）+ flow-kit-install（安装文档型）；skills/flow/ 不匹配 flow-* glob 不受辖
- gate_config 预设名集合唯一来源 = common.sh fk_normalize_gate_val 值域；**五载体**以集合比对断言（L2 重审 R6 修订 2026-09-29）：SKILL.md / bats / dsh JS / gate-helpers.sh:26 内联值域（含 :29-30 case）/ FLOW-KIT-用户指南.md（分发面枚举预设名）
- C4 告警契约：L3 backlog 失败必发 module_output "warning" "IR"（对齐 AC-6；级别纪律 = TD-023，告警通道不用 error）（静默=缺陷）
```

### 9.4 新增 / 升级的依赖（建议 append 到 CONTEXT「技术栈」段）

| 包 | 版本 | 用途 | 是否替换既有 |
|---|---|---|---|
| git-filter-repo | 2.47.0（~/.local/bin） | AC-5 历史重写（一次性运维工具，非运行时依赖） | 否 |

### 9.5 禁动清单变化（建议 patch CONTEXT「禁动清单」段）

```
- 新增禁动：.flow-active 的读取必须经 flow-active-query.sh（白名单文件除外）
- 新增禁动：skills/flow-*/SKILL.md 正文不得脱离 prompts 权威正文独立演化（走 prompts 改 + 门禁过）
- 解禁：common.sh jq_atomic_write(:192) 死代码移除后，该行位不再是抽象索引项
```

---

## 附录 A · flow-active 内联解析白名单（AC-12g · DESIGN 定稿）

**严格谓词**（基线可复现命令，check 落地时由 `make check-flow-active-inline` 执行同款；L2 重审 R3 修订 2026-09-29——入域 dsh JS + 根 .sh + 变量间接分支）：

```bash
# 分支 ①②③：同行字面量（shell 域 + 根 .sh + JS 等价）
grep -rnE '(jq[[:space:]]+[^|]*\.flow-active|while .*read.*\.flow-active|<[^>]*\.flow-active|\.flow-active[\"'\''])' \
  --include='*.sh' --include='Makefile' --include='*.bats' \
  flow-kit-bundle/ Makefile test/ .claude/ *.sh 2>/dev/null
grep -rnE '\.flow-active' --include='*.js' dsh-flow-kit/ 2>/dev/null
# 分支 ④：变量间接（赋值行命中 → 该变量全部下游读取同受辖）
grep -rnE '^\s*[A-Za-z_][A-Za-z0-9_]*="[^"]*\.flow-active' \
  --include='*.sh' --include='*.bats' --include='*.js' \
  flow-kit-bundle/ test/ .claude/ dsh-flow-kit/ *.sh 2>/dev/null
# 三股合并后：排除入口自身与白名单
… | grep -v 'flow-active-query' \
  | grep -vF -f flow-kit-bundle/flow-kit/reference/flow-active-inline-whitelist.txt
```

- 分支④语义：命中赋值 `X="….flow-active"` 即视 $X 后续所有 jq/读取调用为内联解析（登记须覆盖赋值行与下游使用行各一条）。
- **JS 立场（ADR-031 补决策）**：dsh-flow-kit JS 解析器**入域不豁免**——存量三文件（index.js / flow-state.js / l2-review.js）登记白名单（理由行注明「JS 侧无法直调 bash 入口；替代闸 = §9.3 gate_config 预设名五载体集合比对 + 本谓词 JS 分支」）；新增 JS 内联解析同样须登记；长期整改 = 经 hook-bridge 子进程调 flow-active-query.sh（挂 TD，v2）。
- 命中即 rc≠0（fail-closed：白名单文件缺失/空同样转红，读序 **常设 > change 目录 > 双缺**——change 种子副本层取消、change 来源层保留，R8 修订；**L3 重审 r2 m5 修订 2026-09-29** 与 ADR-028:43 / ADR-031:16 对齐）。
- **条目格式**（白名单每行一条，grep -vF 字面匹配）：

```
<路径>:<行号>:<该行完整内容原文>
# <理由一行>（紧随其后，# 开头；无理由的条目 = 门禁红的合法理由失效）
```

- **v1 收敛范围**（D3）：白名单只收「无借口」文件以外的存量豁免；`Makefile:250-253` 手搓解析与 `independent-review-gate.sh:63-65` 变量间接读取（`flow_file="$cwd"/.flow-active` + `jq empty "$flow_file"`）**必须**改调 flow-active-query.sh（不进白名单——旗舰 hook 不得自免检）。
- **只减不增**：新增条目须走变更流程并在理由行注明 CHANGE 引用；计数基线 TASK 以严格谓词重建（宽松 grep=43 含镜像/注释误配，不采）。

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
