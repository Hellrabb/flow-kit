# T11-SUMMARY — C8 载体收敛三件（AC-15 ①②③）

- **Change ID**: health-fix-2026-09c
- **Task ID**: T11
- **完成时间**: 2026-09-30 11:00 (CST)
- **AI 角色**: Dev（阶段 4 · fresh context 单任务）

---

## 做了什么（一段话）

按 AC-15 完成载体收敛三件：① 4-dev.md 的 PCSC 内联表删改纯 `@see`；flow-dev SKILL.md 头部加薄壳声明 + §4/§5/§5.5/§6 四个语义段改 `@see` 引用（frontmatter/触发描述逐字未动，R1 ✓）。② l2-reviewer.md 删 :36-198 的 163 行全文拷贝段，改「来源声明 + 装配说明 + @see」，comm 归一化交集 117→0。③ deny 报文抽单点 `_l2_first_deny()` 入 lib（注意：l2-detect.sh **已存在**，本次是向既有 lib 新增函数，非新建文件——见偏差①），29 号 :139/:249 两处内联改调用，全 bundle 域报文字面量 4→1（仅 lib 内）；测试字面量拼接构造化并重锚定。**发现一处跨文件契约冲突（见「阻塞与移交」）**：sync-hooks.sh 的 L-031 复合载体再生逻辑会对抗 ② 的零拷贝——已在 SUMMARY 与上报中如实记录，修复需扩 write_files，未越权代改。

## 改动文件（write_files 7 + SUMMARY）

| 文件 | 性质 | 前后 |
|---|---|---|
| flow-kit-bundle/flow-kit/prompts/4-dev.md | 修改 | 352→338 行；§6.0 删 ⚠️框 + 8 行内联表 → 1 行纯 @see（含一句 gating 语义指针） |
| flow-kit-bundle/skills/flow-dev/SKILL.md | 修改 | 549→456 行；头部 +薄壳声明 2 行；§4/§5/§5.5/§6 正文（~105 行）→ 4 条 @see；标题逐字保留；frontmatter 与 HEAD 逐字节一致（diff 验证） |
| flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md | 修改 | 198→36 行；:36-198 拷贝段删除；:33-34 来源 blockquote 改写为引用化声明 + @see；:1-32（frontmatter/锚点声明/派发名映射说明表）原样保留 |
| flow-kit-bundle/hooks/stop/lib/l2-detect.sh | 修改 | 519→531 行；`_l2_first_deny()` 插入在 `l2_detect_missing()` 之前（:212 前新增 12 行块，函数体 5 行）；报文与原 29:139 逐字节相同 |
| flow-kit-bundle/hooks/stop/29-independent-review.sh | 修改 | 346→350 行；主门（原 :139）改「懒 source + type 守卫调用」；D4 fallback（原 :249）改「type 守卫调用」（该处上文已 source lib） |
| test/test-l2-first-correction.bats | 修改 | 73→77 行；(a)-2 重锚定（2 调用点 + lib 正文断言）；(a)-3 标题与 grep 拼接构造化、目标改 lib；头部注释 +1 行 T11 说明 |
| flow-kit-bundle/test/test-l2-first-correction.bats | 修改 | 手动双写，与 test/ 副本 `cmp` 逐字节相同 |
| .specs/health-fix-2026-09c/T11-SUMMARY.md | 新增 | 本文件 |

## 三件前后对照（要点）

**① PCSC 表（4-dev.md §6.0）**：原 :92 @see + :94-95 ⚠️强制框 + :97-106 八行表（行 1-7 与 pipeline-gates.md:13-21 逐字重复；行 8 .flow-active 字段自检在 pipeline-gates.md **无对应项**，且该文件不在本任务 write_files——行 8 删除记为偏差②，33-flow-active-integrity hook 已覆盖该检查面）。终态 = 标题 + 单行 @see（补 PCSC/auto_advance/Toll-Gate 语义指针 + 一句「任一 ❌ 禁止进入 toll-gate」gating 语义）。:108-111 auto_advance 分支按任务范围（:99-106）未动。

**① SKILL 薄壳化**：头部薄壳声明定义「本 skill = 触发入口薄壳，语义正文以 prompt 为权威源」；§4 → prompt §「4.」（6 维自查正文仍在 prompt 内联，故指 prompt）；§5/§5.5/§6 → reference/commit-protocol.md（与 prompt §「5./6.」同源）。四个段标题逐字保留（测试/grep 锚稳定），正文各压为 1 条 @see。

**② 复制段归一（l2-reviewer.md）**：163 行拷贝全删；新来源声明固化「装配时由调用方把源文件全文原样注入 task prompt 字段」的装配契约 + opencode 平台差异仅保留派发名映射段。comm 归一化（过滤空行/`---`/代码围栏 + sort -u）：**117 → 0**。

**③ 报文单点**：`_l2_first_deny()`（phase/change_id 参数与 l2_detect_missing 签名对称、当前未插值留扩展）内 1 处报文字面量；29 号两调用点均用 `type _l2_first_deny >/dev/null 2>&1 && _l2_first_deny "$phase" "$change_id" || true` 守卫（set -euo pipefail 下与文件既有惯例一致，cf. 原 :160）。主门在调用前懒 source lib（D4 fallback 处上文已 source）。测试 (a)-2 原断言「29 内报文 ≥2」必然失绿，重锚定为「`grep -Fc '_l2_first_deny "$phase" "$change_id"'` = 2（调用点）+ lib 含派发指引」；(a)-3 标题与 grep 均拼接形态（`'L2-first ''契约未满足'`），grep -rn 域扫不命中测试副本。

## 薄壳范式样例（供 T12a 批量推广）

1. **头部声明**（frontmatter 结束 `---` 后、首个 @see 前，独立 blockquote）：

   > **薄壳声明（thin shell · C8-① 引用化范式）**：本 skill 是 `<权威 prompt 路径>` 的**触发入口薄壳**——仅保留 frontmatter / 触发描述与段落骨架，阶段语义正文以 prompt 为权威源（`@<权威 prompt 路径>`），不在本文件复制；凡与 prompt 冲突，以 prompt 为准。协议细节沿 prompt 的 @see 链引用 reference 文件（…枚举…）。

2. **语义段替换**：标题**逐字保留**（锚稳定），正文压为单条 `> @see`，括注该段的**检索特征**（如「触发条件 · 路径 A/B · Minor 入 MINOR-DEFERRED.md」），让读者不跳转也能定位语义。
3. **frontmatter / 触发描述零改动**（R1 技能路由回归防护，用 `git show HEAD:<file> | diff -` 逐字节验证）。
4. 引用目标二选一：正文仍在 prompt 内联 → 指 prompt §；正文已抽 reference → 指 reference 文件并括注「与 prompt §X 同源」。

## verify 真实输出（终态重跑；check-test-sync 按指示跳过留编排者）

```text
$ npx bats test/test-l2-first-correction.bats
1..5
ok 1 AC-I (a): 29 含 _write_l2_missing_correction helper（D3 双管 a 载体）
ok 2 AC-I (a): 29 两处 D4 门调用 _l2_first_deny（主门 + fallback）——lib 报文含派发指引（写入 ## L2 盲审 段）
ok 3 AC-I (a): 29 D4 提示含 deny reason（L2-first 契约未满足）
ok 4 AC-I (b): gate_config=both 无 L2 段跑 29 → 写 .flow-active.correction(type=l2-missing)
ok 5 AC-I (c): 跑 29 写 module_output 日志（independent-review.txt 含派发指引）
（改前基线同为 5/5 ok——改造未破坏行为，实跑 (b)(c) 证明迁移后报文仍真实发出）

$ make lint
./verify-claims.sh
✅ shellcheck: no errors found

$ grep -c '1\.8 触发时 bats' flow-kit-bundle/flow-kit/prompts/4-dev.md   → 0 （改前 1）
$ comm -12 <(…L2-blind-review.md 归一化) <(…l2-reviewer.md 归一化) | wc -l → 0 （改前 117）
$ grep -rn 'L2-first 契约未满足' flow-kit-bundle/ | wc -l                → 1 （改前 4；唯一处 lib/l2-detect.sh:222）
$ cmp test/test-l2-first-correction.bats flow-kit-bundle/test/…          → 逐字节相同

$ make hooks-sync        （改后首跑，真实输出）
  ✅ …/vendor/flow-kit-bundle/hooks（已一致）
  🔄 …/.config/opencode/hooks — 同步 4 个文件（其中 0 个副本缺失）
  🔄 同步平台级 agent: …/.config/opencode/agent/flow-kit-l2-reviewer.md
  ✅ 已同步 16 个文件
$ make check-hooks-sync  （紧随其后）→ ✅ hooks 副本一致（漂移 0）
```

⚠️ **hooks-sync 与 ② 冲突（重要，见下节）**：`make hooks-sync` 会经 sync-hooks.sh `regen_l2_agent()`（:148-174，L-031 复合载体契约）把 agent 文件重放为「头部 + L2-blind-review.md 全文」——首跑时把薄壳 36 行文件再生成回 199 行（36+163，已实测）。编排者 verify 链能按序通过仅因 comm 项在 hooks-sync 之前；hooks-sync 之后磁盘终态不再满足 comm=0。已把 agent 文件再次恢复为薄壳 36 行（当前终态），恢复后 `make check-hooks-sync` 如实转红（rc=2：6 个安装根各 1 文件不一致 + 平台级 agent 不一致——安装副本仍是再生成版）。**hooks-sync 在 sync-hooks.sh 修复前不应再跑**（会再次撤销 ②）。

## 阻塞与移交（需编排者决策）

`sync-hooks.sh` **不在 T11 write_files**，未代改。修复方向（建议新任务或扩权）：`regen_l2_agent()` 按 D7 改为**逐字节镜像**（删「保留头部 + 重放拷贝段」逻辑，agent 文件视同 prompts 树普通文件镜像），同步更新 :148-151 L-031 注释与 AGENT_MARK 常量去留；修好后跑 `make hooks-sync` 把薄壳版传播到安装副本，check-hooks-sync 即回绿。

## 6 维自查（内置快查路径 B）

- **R1 认知过载**：新增函数 5 行、无深嵌套；SKILL 段落反而变薄（549→456）。
- **R2 变更传播**：仅动 write_files 7 文件 + 本 SUMMARY（git status 佐证；工作区另有 test/test_l3_review_defects_2026_09.bats 改动为**兄弟任务**所写，本任务未触碰）。
- **R3 知识重复**：本任务主题即去重——报文 4→1、拷贝段 163→0、SKILL 重复段 ~105 行→引用。
- **R4 偶然复杂**：无新抽象；参数签名对称沿用既有惯例；守卫模式复用文件内既有 `type X && X || true` 形态。
- **R5 依赖混乱**：lib 由 hook source，方向不变；未引入新依赖层。
- **R6 领域扭曲**：`_l2_first_deny` / `l2-detect` / `薄壳声明` 命名贴合领域语义。

## 偏差清单

1. l2-detect.sh 实况与任务描述不符：文件**已存在**（519 行，含 l2_detect_missing/l2_dispatch_prompt），实际动作 = 向既有 lib 新增 `_l2_first_deny()`（任务原文「新建」）。
2. PCSC 行 8（.flow-active 字段自检）无 pipeline-gates.md 对应项且该文件不可写 → 删除而非迁移（33-flow-active-integrity hook 覆盖该检查面）。
3. 测试 (a)-2 断言必然失绿（29 内报文 2→0），重锚定为「2 调用点 + lib 正文」——语义等价、保持 5/5 绿。
4. check-test-sync 按任务指示跳过（镜像已手动 cp+cmp 双写验证），留编排者波末统一。
5. **hooks-sync/L-031 冲突**（见「阻塞与移交」）：hooks-sync 与 check-hooks-sync 首跑通过（上述真实输出），但其再生逻辑撤销 ②；已恢复薄壳终态并如实留 check 红。安装副本（仓外）现持再生成版，待 sync-hooks.sh 修复后由 hooks-sync 收敛。
