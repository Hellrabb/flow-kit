# DEV-SUMMARY — user-guide-sync-2026-09b

> 记录阶段 4（DEV）各任务的落地情况与机械证据。命令均在仓库根执行；`f` = `flow-kit-bundle/FLOW-KIT-用户指南.md`。

## T01 · 指南修订（上：§1–§5 + §10.7 + §11）

**改动**：§1 组件表（Stop Hook 配置载体改为用户级 + 插件模板兜底）· §2.1（`--global` 不含 hooks / `--project` 配置仍走用户级）· §2.2（选项表补 `--platform` / `--no-brooks-tools` / `--self-test` / `--brooks-src` / `--yes`，修正 `--hooks-only` 与 `--user` 口径）· §2.4（更新入口改 `make dsh-sync` + 插件 v0.2.0 + registry 备选）· §3.2（`.flow-active` 示例补 `goal` 段）· §4 子命令表（补 `/flow gate-config`、`/flow l2-review`）· §4.1.2 阶段子目标（删不存在的 `--sub-goal-N` flag，改 env `SUB_GOAL_N` + 自动提取）· §5 阶段 3（TASK XML 模板换现行字段 + 波次/`depends_on` 语义纠正）· §5 阶段 4（LESSONS 路径）· §5 阶段 6（单轮合并审查 + 严重度 Important）· §5 阶段 7（产出改 `UAT.md` + 归档目录 + CHANGELOG/STATE，34 号职责纠正）· §10.7（值域表 `both/L2/L3/off` + 方式 C 用户级三平台路径）· 版本行与分节日期 → 2026-09-21。

**证据（实跑）**：

| 断言 | 结果 |
|---|---|
| `grep -q "^> 版本: 2026-09-21" "$f"` | ✅ |
| `grep -c "\.specs/lessons/" "$f"` | 0 ✅ |
| `grep -q "\.specs/LESSONS\.md" "$f"` | ✅ |
| `grep -q "make dsh-sync" "$f"` | ✅（3 处） |
| `grep -cF -- "--sub-goal-4" "$f"` | 0 ✅（残留的 `--sub-goal-<n>` 是"该 flag 不存在"的说明句） |
| `grep -c "三轮审查" "$f"` | 0 ✅ |
| `grep -c "20260713\|2026-07-13" "$f"` | 0 ✅ |
| `grep -n "2026-09-03" "$f" \| grep -vc "起"` | 0 ✅（唯一命中为「2026-09-03 起…」历史锚点） |

## T02 · 指南修订（下：§6–§12 + 附录）

**改动**：§6 M-health 三档模式（快速体检/完整审计/单维深挖）· A-architect 产出路径（`.specs/ARCHITECTURE.md` + `.specs/adr/`）· L-restyle change-id 两格式。§7：模块表 34 号职责纠正；PreToolUse 表（matcher `Bash|Write|Edit` + path-guard；新增 `runtime-edit-guard.sh` 行）；SessionStart 补 `archive-uncommitted`；配置文件段重写（用户级单一源 + 解析链 + `max_artifact_bytes` 80000 字节 + `independent_review.model` 标废弃 + `pre_tool_use_gates` 占位未消费 + 12 键口径）；独立 Review 机制（握手文件废弃 → `.done` 6 键 KVP + path-guard + 熔断自动 bypass + ADR-025/026 口径）；新增「L3 凭证（必配）」段（三 Path + rc 语义 + l3.env 加载 + 安全红线）；新增「仓库质量门禁（`make check` 六门）」段（含 `hooks-sync` / `dsh-sync` / `verify-claims`）。§9 ppt skill（不由 bundle 分发 + skill 文件 vs 生成工程结构）。§12（`.flow-kit/` 只放状态；全局树补用户级 `stop-hook.json`/`settings.json`、`~/.local/bin` 移出、dsh/opencode 路径注记；项目级树删项目级 `stop-hook.json`、补真实产物清单、hooks 标为 user scope、`stop/lib` 19 个库、`pre-tool-use` 7 文件）。附录：预设名补到 17 项；gate_config 快照检测范围限定。

**证据（实跑，正例 ≥1 / 反例 = 0）**：

- 反例 0：`pre_tool_use_gates.auto_checkpoint` · `此字段仅作末级兜底` · `允许手动绕过` · `手动 touch done` · `随 flow-kit bundle 分发` · `"31-auto-advance": true` · `ARCHIVE.md` · `项目根 \`ARCHITECTURE.md\`` · `仅安装 hooks（需配合 --project）` · `<title>任务标题</title>` · `只在同波次内`
- 正例：`runtime-edit-guard`(2) · `path-guard`(3) · `check-hooks-sync`(1) · `verify-claims`(1) · `max_artifact_bytes`(1) · `80000`(1) · `l3.env`(2) · `check-dist`(1) · `make dsh-sync`(3) · `/flow l2-review`(1) · `快速体检`/`完整审计`/`单维深挖`(各 1) · `archive-uncommitted`(4) · `无独立开关`(3) · `requirement-review`/`spec-test`(各 1) · `l3-api.sh`…`runtime-adapter.sh`(各 1) · `gate-checks-review.sh`(1) · `~/.local/bin`(2) · `ADR-025`(1) · `ADR-026`(1)

**规模**：`git diff --stat` = `+183 / −122`（T01+T02 合计，单文件）。

## T03 · README / dsh README 口径核对与连改

| # | 条目 | 证据行号 | 结论 | 改动 |
|---|---|---|---|---|
| 1 | 安装入口与作用域 | `README.md`（快速开始段）、`flow-kit-bundle/install.sh:145` | **改** | `bash install.sh /path/to/target-project` 会被 `install.sh` 拒绝（必须显式 `--global` / `--project`）→ 改为三条正确示例 + 明确警告；`--global` 默认不含 hooks 的口径写入 |
| 2 | 配置路径单一源 | `README.md:121-129`、`dsh-flow-kit/README.md:38-39,77-78` | 已就位，未改 | 两份 README 均已写「用户级唯一一份（2026-09-21 起）」 |
| 3 | 工件上限单位与默认值 | `README.md:121-130`、`dsh-flow-kit/README.md:77-84` | 已就位，未改 | `max_artifact_bytes` / 80000 / 字节 / ÷3 / 旧名废弃 均已在位 |
| 4 | L3 凭证与熔断 | `README.md:101-119`、`dsh-flow-kit/README.md:61-75` | 已就位，未改 | 三 Path、死锁后果、systemd drop-in 均已在位 |
| 5 | dsh 插件更新入口 `make dsh-sync` | `README.md`（新增段）、`dsh-flow-kit/README.md:96-109` | **改** | 根 README 新增「dsh 插件」段（打包/安装/`make dsh-sync`/为何不能只靠 `sync-hooks.sh`）；dsh README 的同步流程补 `make dsh-sync` 步骤并标注 pnpm 重装后需重跑 |
| 6 | dsh docs/README 与源的同步关系 | `dsh-flow-kit/README.md:101-109`、`dist/dsh-flow-kit/README.md` | **改** | 明确「dist 产物不手工编辑；改源后按 `make dsh-sync` 刷新」并补 `check-dist` 的配套关系说明 |

**附带修正**：`README.md` 目录树里写死的 `test/（72 tests）` 改为不写死计数（实测 `test/*.bats` 文件数随本轮新增变化）。

**证据（实跑）**：`grep -q "make dsh-sync" README.md` ✅；`grep -q "80000" README.md` ✅；`! grep -q "项目级.*stop-hook.json" README.md` ✅；`grep -q "2026-09-21" dsh-flow-kit/README.md` ✅；`grep -q "make dsh-sync" dsh-flow-kit/README.md` ✅ → `T03-verify-OK`

## T04 · 四副本对齐（含 dist 窄路径再生）

**覆盖前快照**（记录基线，不写死进 AC）：

| 副本 | md5(8) | mtime | 行数 |
|---|---|---|---|
| 仓库根 | `fb2ff01b` | 2026-09-21 22:11:05 | 1631 |
| `flow-kit-bundle/` | `17efc398` | 2026-09-21 22:15:22 | 1693 |
| `dist/.../docs/` | `d87c6d84` | 2026-09-21 21:33:45 | 1632 |
| `dist/.../vendor/` | `d87c6d84` | 2026-09-21 21:33:45 | 1632 |

**归类**：`diff 根 bundle` = 125 行 root-only / 187 行 bundle-only —— 全部归为「根旧 / bundle 新」（根副本停在 2026-09-03；bundle 为本轮底稿），无「bundle 独有且非本轮」的意外条目。

**动作**：`cp` bundle → 根 → `cp` 到 dist 两份（按 `package-dsh-plugin.sh:45` 映射的窄路径）；另 `cp dsh-flow-kit/README.md dist/dsh-flow-kit/README.md`（T03 改了源，dist 副本需同步）。

**证据（实跑）**：

```
17efc398…  FLOW-KIT-用户指南.md
17efc398…  flow-kit-bundle/FLOW-KIT-用户指南.md
17efc398…  dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md
17efc398…  dist/dsh-flow-kit/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md
唯一 md5 数 = 1        → T04-verify-OK
bash package-dsh-plugin.sh --check  → ✅ check-dist: dist 与源一致 (rc=0)
make dsh-sync → ✅ 已同步（web profile）；同步后 diff -rq dist ↔ 已装插件 = 0
```

## T05 · deck 扩页重建

（由 T05 执行子任务落地，产物见 `.specs/user-guide-deck-gen/` 与 `flow-kit-用户指南.pptx`；证据由 TEST.md 汇总。）

## T06 · 副本一致性守护（`test/test_guide_copy_parity.bats`）

**新增 8 个用例**：① 四份 md5 唯一（dist 缺席时显式 NOTE；`resolve_repo_root` 兼容 bundle 落点，解析失败**显式失败**）② 版本日期口径（版本行 == 分节日期 + 旧版本号清零 + 09-03 仅历史句）③ guard 非恒绿（夹具注入 1 字节 → 判定不一致并**指名**；修复指引以 **bundle 底稿**为基准，方向正确）④ deck 新鲜度（页数 + 封面日期 == 指南版本行日期；pptx/python-pptx 缺失则 skip）⑤ deck guard 非恒绿（夹具 2 页 vs 1 页）⑥ 已安装 dsh 插件副本 when-present 一致 ⑦ **dist 缺席路径**（只造 root+bundle 两份 + 注入漂移 → 必须检出）⑧ **deck content parity**（调用 `deck_checks.py` 全断言 + `slides.json` 每页标题必须出现在 pptx 文本中）。

**实测（终态）**（`npx bats test/test_guide_copy_parity.bats`）：**8/8 ok**。过程中该守护曾在真实缺口上变红一次（T05 尚未重建 pptx 时用例 4 报 `pptx 页数(20) != slides.json 页数(24)`）——证明它不是装饰；此后按 L2 回审追加用例 7（`dist` 缺席路径）与用例 8（`deck_checks` 全断言接线 + title 级内容一致性）。

**镜像**：`make test-sync` 已把该文件同步到 `flow-kit-bundle/test/`（`check-test-sync` 要求两目录逐文件一致）。

**修复记录**：首版 `guide_parity_report` 把 `$root` 拼了两次（`cmp` 恒失败 → 假红），已修为直接比较绝对路径；夹具用例（③）证明了比较逻辑本身有效。

## 越界检查

**AC-9 边界判据实跑**（`bash .specs/user-guide-sync-2026-09b/verify-boundary.sh`，rc=0 · 实时输出）：

```
## AC-9 边界核对（git status --porcelain + 未跟踪）
  ✅ .specs/CHANGELOG.md
  ✅ .specs/CONTEXT.md
  ✅ .specs/LESSONS.md
  ✅ .specs/user-guide-deck-gen/README.md
  ✅ .specs/user-guide-deck-gen/build.py
  ✅ .specs/user-guide-deck-gen/deck_checks.py
  ✅ .specs/user-guide-deck-gen/slides.json
  ✅ FLOW-KIT-用户指南.md
  ✅ README.md
  ✅ dsh-flow-kit/README.md
  ✅ flow-kit-bundle/FLOW-KIT-用户指南.md
  ✅ flow-kit-用户指南.pptx
  ✅ .specs/user-guide-sync-2026-09b/
  ✅ flow-kit-bundle/test/test_guide_copy_parity.bats
  ✅ test/test_guide_copy_parity.bats
  （已核对 15 条 · 忽略瞬态 0 条）

## 未跟踪新增（git ls-files -o --exclude-standard）
  ✅ .specs/user-guide-sync-2026-09b/CHANGE.md
  ✅ .specs/user-guide-sync-2026-09b/DESIGN.md
  ✅ .specs/user-guide-sync-2026-09b/DEV-SUMMARY.md
  ✅ .specs/user-guide-sync-2026-09b/INDEPENDENT-REVIEW-1.md
  ✅ .specs/user-guide-sync-2026-09b/INDEPENDENT-REVIEW-2.md
  ✅ .specs/user-guide-sync-2026-09b/INDEPENDENT-REVIEW-3.md
  ✅ .specs/user-guide-sync-2026-09b/INDEPENDENT-REVIEW-5.md
  ✅ .specs/user-guide-sync-2026-09b/INDEPENDENT-REVIEW-6.md
  ✅ .specs/user-guide-sync-2026-09b/MINOR-DEFERRED.md
  ✅ .specs/user-guide-sync-2026-09b/REQUIREMENT.md
  ✅ .specs/user-guide-sync-2026-09b/REVIEW.md
  ✅ .specs/user-guide-sync-2026-09b/TASK.md
  ✅ .specs/user-guide-sync-2026-09b/TEST.md
  ✅ .specs/user-guide-sync-2026-09b/UAT.md
  ✅ .specs/user-guide-sync-2026-09b/check-appendix-superset.py
  ✅ .specs/user-guide-sync-2026-09b/make-manifest.sh
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-01.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-02.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-03.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-04.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-05.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-06.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-07.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-08.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-09.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-10.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-11.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-12.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-13.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-14.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-15.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-16.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-17.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-18.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-19.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-20.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-21.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-22.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-23.png
  ✅ .specs/user-guide-sync-2026-09b/render-preview/slide-24.png
  ✅ .specs/user-guide-sync-2026-09b/run-l3.sh
  ✅ .specs/user-guide-sync-2026-09b/verify-ac.sh
  ✅ .specs/user-guide-sync-2026-09b/verify-boundary.sh
  ✅ flow-kit-bundle/test/test_guide_copy_parity.bats
  ✅ test/test_guide_copy_parity.bats

## 禁动域 diff（必须为 0）
  禁动域改动文件数: 0

## dist 再生件（由 make check-dist 守护，git 结构性看不见）
  ✅ check-dist rc=0

✅ 边界核对通过
```

无运行时实现文件（`flow-kit-bundle/hooks/**`、`dsh-flow-kit/lib/**`、`flow-kit-bundle/skills/**`、`flow-kit-bundle/flow-kit/prompts/**`）被改动。
