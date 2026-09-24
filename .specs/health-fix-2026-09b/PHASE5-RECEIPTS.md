# PHASE5 RECEIPTS — health-fix-2026-09b 阶段 5 · 原始回执存档

> **目的**：让 `TEST.md` 的每条自报数字都能被外部**重放核对**，而不是只给汇总数字（L3 第 2 轮 major 1/2 的响应工件）。
> **复算入口**：`bash .specs/health-fix-2026-09b/reproduce-5-test.sh`（判据从 `TASK.md` **权威副本** awk 原样抽取后**字面执行**，不套 `set -e`、零改写；模式 `--criteria-only` / `--gates-only` / `--only T19,T27`；任一非 0 ⇒ `exit 1`）。
> **本次运行**：2026-09-24 10:40（+08:00）· HEAD = `9cbd098bf90b3a6ad8856070734128a5688d4f90` · bash `5.2.21(1)-release` · 日志目录 `/tmp/p5/repro-final`（脚本默认 `<tmp>/fk-reproduce-5`）。
> **脱敏**：嵌入输出中的本机仓库根按 **L-129** 去形为 `<repo>`（替换 `/home/<账号>/` 形态，仅此一处改写，其余字节原样）。

---

## §0 最小复算证据（索引与结论 · 落在补充产物 3000 B 预算内）

**结论**：12 条关键判据 + 7 项门禁（含 [F] 阶段门沙箱）+ `make check` 九道门禁在本 HEAD 全绿；阶段门沙箱复现健康层 A/B/C 全绿、B2/B3 为 TD-059 缺口实证（⚠️ 不得读作通过）。
**一键复算**：`bash .specs/health-fix-2026-09b/reproduce-5-test.sh`（判据 + 门禁）· `bash .specs/health-fix-2026-09b/reproduce-phase-gate.sh`（阶段门五层状态）—— 均需 `exit 0` 才算全绿。

| 面 | 结果 | 原文 |
| --- | --- | --- |
| 判据 T05/06/11/13/17/19/20/22/24/26/27/29 | 12/12 ✅ rc=0 | §A |
| `npx bats test/` | rc=0 · ok=976 / not ok=0 / skip=0 | §B-2 |
| `make check` | rc=0 · 21 条 ✅ / 0 条 ❌ | §B-3 |
| `make check-path-privacy` | rc=0 · 清单外命中 0 | §B-4 |
| NFR：`time make check-path-privacy` ≤ 5 s | 5 次实测 2.836–2.898 s（均值 2.858 = 预算 57%） | §E |
| `package-flow-kit.sh --validate` | rc=0 · 漏配 0 / 源缺失 0 | §B-5 |
| 阶段门沙箱复现 | 健康层 ✅ A/B/C · 缺口层 ⚠️ B2/B3（TD-059） | §H |
| 端到端耗时（L3 第 4 轮 minor ①） | `npx bats test/` real **121.203 s** · `make check` real **258.890 s**（均 rc=0） | §I-1 |
| 处置后独立复算（判据活性） | 判据 12/12 + 门禁 7/7 ✅ rc=0（新代码里的 `sed -i` 曾被 T29 / NFR 判红并指名 `file:line`） | §I |

**读法**：本节是索引与结论，§A/§B 是逐条原始 stdout 存档。补充产物只按**前 3000 B** 送进外部审查信封（`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:286` 取件 · `:304` 按整行截断）⇒ 关键数字与复算入口必须留在本节内（L-151）。

---

## §A 关键判据 · 12 条（抽取行数 / rc / 原始输出）

| 判据 | rc | 抽取行数 | 原始输出 |
| --- | --- | --- | --- |
| T05 | ✅ rc=0 | 12 | §A-1 |
| T06 | ✅ rc=0 | 22 | §A-2 |
| T11 | ✅ rc=0 | 7 | §A-3 |
| T13 | ✅ rc=0 | 34 | §A-4 |
| T17 | ✅ rc=0 | 73 | §A-5 |
| T19 | ✅ rc=0 | 33 → **36**（L3 第 3 轮 major 4 回写后，见 §I） | §A-6 |
| T20 | ✅ rc=0 | 3 | §A-7 |
| T22 | ✅ rc=0 | 20 | §A-8 |
| T24 | ✅ rc=0 | 18 | §A-9 |
| T26 | ✅ rc=0 | 30 | §A-10 |
| T27 | ✅ rc=0 | 19 | §A-11 |
| T29 | ✅ rc=0 | 15 | §A-12 |

**抽取命令**（每条同形，`sed` 三段即脚本内 `extract_verify()` 的等价手写形态）：

```bash
sed -n '/<task id="T17"[^>]*>/,/<\/task>/p' .specs/health-fix-2026-09b/TASK.md \
  | sed -n '/<verify>/,/<\/verify>/p' | sed '1d;$d' > /tmp/v_T17.sh && bash /tmp/v_T17.sh; echo "rc=$?"
```

### §A-1 · T05（判据 12 行 · rc=0）

```
```

### §A-2 · T06（判据 22 行 · rc=0）

```
```

### §A-3 · T11（判据 7 行 · rc=0）

```
```

### §A-4 · T13（判据 34 行 · rc=0）

```
✅ 脱敏完成：授权面外命中 = 0（tracked + 未 tracked 两面均已扫描）
```

### §A-5 · T17（判据 73 行 · rc=0）

```
```

### §A-6 · T19（首次运行：判据 33 行 · rc=0）

> ⚠️ **本段是 10:40 那次运行的原文**。此后 T19 `<verify>` 已按 **L3 第 3 轮 major 4** 回写权威副本 `TASK.md`（4 处 `rc=$?` ⇒ 「先置零再捕获」，见 `TEST.md` §1.7）⇒ 现抽取 **36 行**，回写后的实跑回执见 **§I**（`rc=0`）与 §A 表内的「33 → 36」注记。

```
bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 1 条（含占位符排除后）
   清单外命中 1 条
   ── 清单外命中归因（file:line）──
   leak.txt:1: <repo>/leak
🔴 清单外命中 1 条（非允许清单命中 ⇒ 阻塞，ADR-027 ②③ / ADR-028 决策 2）
make: *** [Makefile:3：check-path-privacy] 错误 1
bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 8c5b94d40ab7f6452131dde9e9ab80160c9fb5b4
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
To /tmp/l3-ac3-HG4F3a/remote.git
 * [new branch]      develop -> develop
```

### §A-7 · T20（判据 3 行 · rc=0）

```
源: <repo>/unisoc/flow-kit/flow-kit-bundle/hooks
镜像文件数: 48（stop 模块与 install_hooks.sh 同源计数）

  ✅ <repo>/.claude/hooks
  ✅ <repo>/unisoc/flow-kit/dist/dsh-flow-kit/hooks
  ✅ <repo>/unisoc/flow-kit/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ <repo>/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks
  ✅ <repo>/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ <repo>/.config/opencode/hooks

✅ hooks 副本一致（漂移 0）
```

### §A-8 · T22（判据 20 行 · rc=0）

```
```

### §A-9 · T24（判据 18 行 · rc=0）

```
归档内 pre-push 成员：dsh-flow-kit/hooks/pre-push/pre-push.sh dsh-flow-kit/vendor/flow-kit-bundle/hooks/pre-push/pre-push.sh
0.2.0: eval-echo=0
0.2.0: chisel=0
```

### §A-10 · T26（判据 30 行 · rc=0）

```
🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ...
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 1 条（含占位符排除后）
   清单外命中 1 条
   ── 清单外命中归因（file:line）──
   .specs/CONTEXT.md:720: <!-- probe: <repo>/ -->
🔴 清单外命中 1 条（非允许清单命中 ⇒ 阻塞，ADR-027 ②③ / ADR-028 决策 2）
make: *** [Makefile:127: check-path-privacy] Error 1
🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ...
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
源: <repo>/unisoc/flow-kit/flow-kit-bundle/hooks
镜像文件数: 48（stop 模块与 install_hooks.sh 同源计数）

  ✅ <repo>/.claude/hooks
  ✅ <repo>/unisoc/flow-kit/dist/dsh-flow-kit/hooks
  ✅ <repo>/unisoc/flow-kit/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ <repo>/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks
  ✅ <repo>/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ <repo>/.config/opencode/hooks

✅ hooks 副本一致（漂移 0）
```

### §A-11 · T27（判据 19 行 · rc=0）

```
dist/dsh-flow-kit-0.2.0.tgz: eval-echo=0
dist/dsh-flow-kit-0.2.0.tgz: chisel=0
bats: rc=0 ok=976 not-ok=0（基线 2026-09-24 T29 收口实测 rc=0 / 976 ok / 0 not ok，skip 计入 ok 行）
```

### §A-12 · T29（判据 15 行 · rc=0）

```
🧪 make test: running bats...
ok 974 CF-01: write_compliance_correction creates valid JSON with all fields
ok 975 CF-02: write_compliance_correction merges with existing + dedup
ok 976 CF-03: clear_compliance_correction removes the file
✅ bats: all tests passed
🔍 make lint: shellcheck (error level only)...
SCANNED_FILES: 68
./corpus-count.sh
./flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
./flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
./flow-kit-bundle/flow-kit/regression-demos/hallucination-guard/check.sh
./flow-kit-bundle/flow-kit/regression-demos/scope-drift-guard/check.sh
./flow-kit-bundle/flow-kit/regression-demos/strong-model-verbosity/check.sh
./flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/check.sh
./flow-kit-bundle/hooks/pre-commit/pre-commit.sh
./flow-kit-bundle/hooks/pre-push/pre-push.sh
./flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh
./flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh
./flow-kit-bundle/hooks/pre-tool-use/gate-checks-review.sh
./flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh
./flow-kit-bundle/hooks/pre-tool-use/gate-helpers-types.sh
./flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
./flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh
./flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
./flow-kit-bundle/hooks/session-start/stop-report-reminder.sh
./flow-kit-bundle/hooks/stop/00-gate.sh
./flow-kit-bundle/hooks/stop/01-transcript-parse.sh
./flow-kit-bundle/hooks/stop/20-claude-md.sh
./flow-kit-bundle/hooks/stop/21-memory.sh
./flow-kit-bundle/hooks/stop/22-git.sh
./flow-kit-bundle/hooks/stop/23-quality.sh
./flow-kit-bundle/hooks/stop/24-session.sh
./flow-kit-bundle/hooks/stop/25-project.sh
./flow-kit-bundle/hooks/stop/26-workflow.sh
./flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh
./flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh
./flow-kit-bundle/hooks/stop/29-independent-review.sh
./flow-kit-bundle/hooks/stop/30-ai-analyze.sh
./flow-kit-bundle/hooks/stop/31-auto-advance.sh
./flow-kit-bundle/hooks/stop/32-fallback-guard.sh
./flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh
./flow-kit-bundle/hooks/stop/34-archive-commit-check.sh
./flow-kit-bundle/hooks/stop/99-report.sh
./flow-kit-bundle/hooks/stop/lib/banner.sh
./flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh
./flow-kit-bundle/hooks/stop/lib/common.sh
./flow-kit-bundle/hooks/stop/lib/correction-file.sh
./flow-kit-bundle/hooks/stop/lib/correction-types.sh
./flow-kit-bundle/hooks/stop/lib/done-validation.sh
./flow-kit-bundle/hooks/stop/lib/fix-compliance.sh
./flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
./flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh
./flow-kit-bundle/hooks/stop/lib/l2-detect.sh
./flow-kit-bundle/hooks/stop/lib/l3-api.sh
./flow-kit-bundle/hooks/stop/lib/l3-done.sh
./flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
./flow-kit-bundle/hooks/stop/lib/l3-review.sh
./flow-kit-bundle/hooks/stop/lib/l3-section.sh
./flow-kit-bundle/hooks/stop/lib/l3-truncate.sh
./flow-kit-bundle/hooks/stop/lib/runtime-adapter.sh
./flow-kit-bundle/hooks/stop/lib/transcript-parser.sh
./flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
./flow-kit-bundle/install.sh
./flow-kit-bundle/lib/install_agents_md.sh
./flow-kit-bundle/lib/install_brooks.sh
./flow-kit-bundle/lib/install_brooks_tools.sh
./flow-kit-bundle/lib/install_core.sh
./flow-kit-bundle/lib/install_hooks.sh
./flow-kit-bundle/lib/install_skills.sh
./flow-kit-bundle/lib/paths.sh
./flow-kit-bundle/lib/validate_staging.sh
./package-dsh-plugin.sh
./package-flow-kit.sh
./sync-hooks.sh
./verify-claims.sh

✅ shellcheck: no errors found
📦 make check-validate: package staging coverage...
   实际文件: 317 项
   🔴 漏配 (ERROR): 0
   ⚠️  源缺失 (WARNING): 0

   ✅ 校验通过：所有文件均被 Part A~G 覆盖。
✅ validate: staging coverage OK
🔍 make check-test-sync: test/ ↔ flow-kit-bundle/test/ ...
✅ test 双源一致
🔍 make check-hooks-sync: hooks 副本漂移检测 ...
源: <repo>/unisoc/flow-kit/flow-kit-bundle/hooks
镜像文件数: 48（stop 模块与 install_hooks.sh 同源计数）

  ✅ <repo>/.claude/hooks
  ✅ <repo>/unisoc/flow-kit/dist/dsh-flow-kit/hooks
  ✅ <repo>/unisoc/flow-kit/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ <repo>/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks
  ✅ <repo>/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ <repo>/.config/opencode/hooks

✅ hooks 副本一致（漂移 0）
📦 make check-dist: 打包件新鲜度检查 ...
✅ check-dist: dist 与源一致
🔍 make check-gate-sync: prompt↔skill 协议一致性检查 ...
🔍 check-gate-sync: 校验 prompt↔skill toll-gate 协议一致性...

   校验: A-evolve ↔ flow-evolve
     prompt: <repo>/unisoc/flow-kit/flow-kit-bundle/flow-kit/prompts/A-evolve.md
     skill:  <repo>/unisoc/flow-kit/flow-kit-bundle/skills/flow-evolve/SKILL.md
   ✅ 内容一致（已剥离 front-matter；diff 内容 = 0 行）

   校验: I-intel-scan ↔ flow-intel
     prompt: <repo>/unisoc/flow-kit/flow-kit-bundle/flow-kit/prompts/I-intel-scan.md
     skill:  <repo>/unisoc/flow-kit/flow-kit-bundle/skills/flow-intel/SKILL.md
   ✅ 内容一致（已剥离 front-matter；diff 内容 = 0 行）

   校验: L-restyle ↔ flow-restyle
     prompt: <repo>/unisoc/flow-kit/flow-kit-bundle/flow-kit/prompts/L-restyle.md
     skill:  <repo>/unisoc/flow-kit/flow-kit-bundle/skills/flow-restyle/SKILL.md
   ✅ 内容一致（已剥离 front-matter；diff 内容 = 0 行）

   校验: gate-config 预设名同步 (SKILL.md PRESET_MAP ↔ bats resolve_gate_config)
     skill:  <repo>/unisoc/flow-kit/flow-kit-bundle/skills/flow/SKILL.md
     bats:   <repo>/unisoc/flow-kit/flow-kit-bundle/test/test_gate_config_presets.bats
   ✅ 预设名集合一致 (17 个预设)

   ── 校验汇总 ──
   覆盖度: 校验对 3/14（v1 仅覆盖内容本应一致、仅差 front-matter 的对；其余 11 对已实质分叉，留 v2/TD-025）
   ✅ 校验对 3/14 一致（仅覆盖上述对，非全量 14 对全绿）。
🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ...
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
🔍 make check-nfr-portability: NFR 兼容性判据（bash 3.2/macOS 可移植 · 三态包装）...
✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造，语法检查通过

╔════════════════════════════════════════════════════╗
║  ✅ make check: 全部通过                           ║
╚════════════════════════════════════════════════════╝
bats: rc=0 ok=976 not-ok=0（基线 2026-09-24 T29 收口实测 rc=0 / 976 ok / 0 not ok；skip 计入 ok 行）
```

---

## §B 门禁权威回执（6 项 · 同一次运行）

> 第 **7** 项门禁 —— `[F]` **阶段门沙箱复现** —— 的原文见 **§H**（同一脚本 `reproduce-phase-gate.sh`）；处置后的一次全绿运行见 **§I**。§B（6 项）+ §H（第 7 项）共同构成 §0 表内所称的「七项门禁」。

| 门禁 | rc | 摘要 |
| --- | --- | --- |
| `npx bats --count test/` | ✅ rc=0 | 用例数 **976** |
| `npx bats test/`（TAP 全量直跑） | ✅ rc=0 | **ok=976 / not ok=0**（TAP 的 `ok` 行含 skip ⇒ 另按 §B-2 计数） |
| `make check` | ✅ rc=0 | **21 条 ✅ / 0 条 ❌** |
| `make check-path-privacy` | ✅ rc=0 | 清单外命中 **0** 条 |
| NFR 预算 `time make check-path-privacy` ×5 | ✅ rc=0 | 环境 `nproc=32` `loadavg=6.20 6.45 6.51` |
| `package-flow-kit.sh --validate` | ✅ rc=0 | 漏配 ERROR **0** · 源缺失 WARNING **0** |

### §B-1 · 本次运行的完整汇总回执（脚本 stdout 原文）

```
== 阶段 5 一键复算 · change health-fix-2026-09b ==
   仓库根 : <repo>/unisoc/flow-kit
   HEAD   : 9cbd098bf90b3a6ad8856070734128a5688d4f90
   时间   : 2026-09-24T10:40:17+08:00
   日志   : /tmp/p5/repro-final
   bash   : 5.2.21(1)-release

== 关键判据（从 TASK.md 原样抽取后字面执行）==
  T05  ✅ rc=0（12 行判据 / 输出 /tmp/p5/repro-final/out_T05.txt）
  T06  ✅ rc=0（22 行判据 / 输出 /tmp/p5/repro-final/out_T06.txt）
  T11  ✅ rc=0（7 行判据 / 输出 /tmp/p5/repro-final/out_T11.txt）
  T13  ✅ rc=0（34 行判据 / 输出 /tmp/p5/repro-final/out_T13.txt）
  T17  ✅ rc=0（73 行判据 / 输出 /tmp/p5/repro-final/out_T17.txt）
  T19  ✅ rc=0（33 行判据 / 输出 /tmp/p5/repro-final/out_T19.txt）
  T20  ✅ rc=0（3 行判据 / 输出 /tmp/p5/repro-final/out_T20.txt）
  T22  ✅ rc=0（20 行判据 / 输出 /tmp/p5/repro-final/out_T22.txt）
  T24  ✅ rc=0（18 行判据 / 输出 /tmp/p5/repro-final/out_T24.txt）
  T26  ✅ rc=0（30 行判据 / 输出 /tmp/p5/repro-final/out_T26.txt）
  T27  ✅ rc=0（19 行判据 / 输出 /tmp/p5/repro-final/out_T27.txt）
  T29  ✅ rc=0（15 行判据 / 输出 /tmp/p5/repro-final/out_T29.txt）

== [A] bats 权威回执 ==
  bats --count           ✅ rc=0  用例数 976（源码面 test/*.bats）
  bats test/             ✅ rc=0  rc=0 ok=976 not-ok=0（基线 976 ok / 0 not ok，skip 计入 ok 行）

== [B] make check（全门禁）==
         ✅ <repo>/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks
         ✅ <repo>/.config/opencode/hooks
       ✅ hooks 副本一致（漂移 0）
       ✅ check-dist: dist 与源一致
          ✅ 内容一致（已剥离 front-matter；diff 内容 = 0 行）
          ✅ 内容一致（已剥离 front-matter；diff 内容 = 0 行）
          ✅ 内容一致（已剥离 front-matter；diff 内容 = 0 行）
          ✅ 预设名集合一致 (17 个预设)
          ✅ 校验对 3/14 一致（仅覆盖上述对，非全量 14 对全绿）。
       ✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
       ✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造，语法检查通过
       ║  ✅ make check: 全部通过                           ║
  make check             ✅ rc=0  21 条 ✅ / 0 条 ❌（原文 /tmp/p5/repro-final/make-check.txt）

== [C] check-path-privacy 自证面 ==
       🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ...
          扫描面: 工作树
          允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
          命中合计 0 条（含占位符排除后）
          清单外命中 0 条
       ✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
  check-path-privacy     ✅ rc=0  ✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）

== [D] NFR 性能预算（5 次 · 预算 ≤5s）==
       run 1: real=2.905 user=1.167 sys=1.891 
       run 2: real=2.930 user=1.192 sys=1.887 
       run 3: real=2.857 user=1.173 sys=1.840 
       run 4: real=2.874 user=1.165 sys=1.871 
       run 5: real=2.846 user=1.180 sys=1.804 
  NFR ≤5s ×5          ✅ rc=0  环境 nproc=32 loadavg=6.20 6.45 6.51

== [E] 打包覆盖 validate ==
          🔴 漏配 (ERROR): 0
          ⚠️  源缺失 (WARNING): 0
       
          ✅ 校验通过：所有文件均被 Part A~G 覆盖。
  package --validate     ✅ rc=0     🔴 漏配 (ERROR): 0    ⚠️  源缺失 (WARNING): 0 

== 汇总 ==
| 判据 | 结果 | 抽取行数 | 原始输出 |
| --- | --- | --- | --- |
| T05 | ✅ rc=0 | 12 | `out_T05.txt` |
| T06 | ✅ rc=0 | 22 | `out_T06.txt` |
| T11 | ✅ rc=0 | 7 | `out_T11.txt` |
| T13 | ✅ rc=0 | 34 | `out_T13.txt` |
| T17 | ✅ rc=0 | 73 | `out_T17.txt` |
| T19 | ✅ rc=0 | 33 | `out_T19.txt` |
| T20 | ✅ rc=0 | 3 | `out_T20.txt` |
| T22 | ✅ rc=0 | 20 | `out_T22.txt` |
| T24 | ✅ rc=0 | 18 | `out_T24.txt` |
| T26 | ✅ rc=0 | 30 | `out_T26.txt` |
| T27 | ✅ rc=0 | 19 | `out_T27.txt` |
| T29 | ✅ rc=0 | 15 | `out_T29.txt` |
| 门禁 | 结果 | 摘要 |
| --- | --- | --- |
| bats --count | ✅ rc=0 | 用例数 976（源码面 test/*.bats） |
| bats test/ | ✅ rc=0 | rc=0 ok=976 not-ok=0（基线 976 ok / 0 not ok，skip 计入 ok 行） |
| make check | ✅ rc=0 | 21 条 ✅ / 0 条 ❌（原文 /tmp/p5/repro-final/make-check.txt） |
| check-path-privacy | ✅ rc=0 | ✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞） |
| NFR ≤5s ×5 | ✅ rc=0 | 环境 nproc=32 loadavg=6.20 6.45 6.51 |
| package --validate | ✅ rc=0 |    🔴 漏配 (ERROR): 0    ⚠️  源缺失 (WARNING): 0  |

✅ 复算全绿（判据 + 权威回执）；原始输出保存在 /tmp/p5/repro-final
```

### §B-2 · TAP 计数（直跑 `npx bats test/`）

```bash
npx bats test/ > /tmp/bats-tap.txt 2>&1; echo "rc=$?"
grep -cE '^ok '     /tmp/bats-tap.txt    # ok 行（含 skip）
grep -cE '^not ok ' /tmp/bats-tap.txt    # 失败行
grep -cE '^# skip'  /tmp/bats-tap.txt    # skip 显式行
npx bats --count test/                   # 收集面
```

结果：`rc=0` · `^ok` = **976** · `^not ok` = **0** · 显式 skip 行 = **0** · `--count` = **976** ⇒ 收集面 = 执行面，零静默跳过。
（TAP 首行 `1..976`、末尾为最后一条用例行 —— bats 不打印汇总行，断言必须按行计数。）

### §B-3 · `make check` 全文（21 条 ✅ / 0 条 ❌）

```
🧪 make test: running bats...
ok 974 CF-01: write_compliance_correction creates valid JSON with all fields
ok 975 CF-02: write_compliance_correction merges with existing + dedup
ok 976 CF-03: clear_compliance_correction removes the file
✅ bats: all tests passed
🔍 make lint: shellcheck (error level only)...
SCANNED_FILES: 68
./corpus-count.sh
./flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
./flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
./flow-kit-bundle/flow-kit/regression-demos/hallucination-guard/check.sh
./flow-kit-bundle/flow-kit/regression-demos/scope-drift-guard/check.sh
./flow-kit-bundle/flow-kit/regression-demos/strong-model-verbosity/check.sh
./flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/check.sh
./flow-kit-bundle/hooks/pre-commit/pre-commit.sh
./flow-kit-bundle/hooks/pre-push/pre-push.sh
./flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh
./flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh
./flow-kit-bundle/hooks/pre-tool-use/gate-checks-review.sh
./flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh
./flow-kit-bundle/hooks/pre-tool-use/gate-helpers-types.sh
./flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
./flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh
./flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
./flow-kit-bundle/hooks/session-start/stop-report-reminder.sh
./flow-kit-bundle/hooks/stop/00-gate.sh
./flow-kit-bundle/hooks/stop/01-transcript-parse.sh
./flow-kit-bundle/hooks/stop/20-claude-md.sh
./flow-kit-bundle/hooks/stop/21-memory.sh
./flow-kit-bundle/hooks/stop/22-git.sh
./flow-kit-bundle/hooks/stop/23-quality.sh
./flow-kit-bundle/hooks/stop/24-session.sh
./flow-kit-bundle/hooks/stop/25-project.sh
./flow-kit-bundle/hooks/stop/26-workflow.sh
./flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh
./flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh
./flow-kit-bundle/hooks/stop/29-independent-review.sh
./flow-kit-bundle/hooks/stop/30-ai-analyze.sh
./flow-kit-bundle/hooks/stop/31-auto-advance.sh
./flow-kit-bundle/hooks/stop/32-fallback-guard.sh
./flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh
./flow-kit-bundle/hooks/stop/34-archive-commit-check.sh
./flow-kit-bundle/hooks/stop/99-report.sh
./flow-kit-bundle/hooks/stop/lib/banner.sh
./flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh
./flow-kit-bundle/hooks/stop/lib/common.sh
./flow-kit-bundle/hooks/stop/lib/correction-file.sh
./flow-kit-bundle/hooks/stop/lib/correction-types.sh
./flow-kit-bundle/hooks/stop/lib/done-validation.sh
./flow-kit-bundle/hooks/stop/lib/fix-compliance.sh
./flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
./flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh
./flow-kit-bundle/hooks/stop/lib/l2-detect.sh
./flow-kit-bundle/hooks/stop/lib/l3-api.sh
./flow-kit-bundle/hooks/stop/lib/l3-done.sh
./flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
./flow-kit-bundle/hooks/stop/lib/l3-review.sh
./flow-kit-bundle/hooks/stop/lib/l3-section.sh
./flow-kit-bundle/hooks/stop/lib/l3-truncate.sh
./flow-kit-bundle/hooks/stop/lib/runtime-adapter.sh
./flow-kit-bundle/hooks/stop/lib/transcript-parser.sh
./flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh
./flow-kit-bundle/install.sh
./flow-kit-bundle/lib/install_agents_md.sh
./flow-kit-bundle/lib/install_brooks.sh
./flow-kit-bundle/lib/install_brooks_tools.sh
./flow-kit-bundle/lib/install_core.sh
./flow-kit-bundle/lib/install_hooks.sh
./flow-kit-bundle/lib/install_skills.sh
./flow-kit-bundle/lib/paths.sh
./flow-kit-bundle/lib/validate_staging.sh
./package-dsh-plugin.sh
./package-flow-kit.sh
./sync-hooks.sh
./verify-claims.sh

✅ shellcheck: no errors found
📦 make check-validate: package staging coverage...
   实际文件: 317 项
   🔴 漏配 (ERROR): 0
   ⚠️  源缺失 (WARNING): 0

   ✅ 校验通过：所有文件均被 Part A~G 覆盖。
✅ validate: staging coverage OK
🔍 make check-test-sync: test/ ↔ flow-kit-bundle/test/ ...
✅ test 双源一致
🔍 make check-hooks-sync: hooks 副本漂移检测 ...
源: <repo>/unisoc/flow-kit/flow-kit-bundle/hooks
镜像文件数: 48（stop 模块与 install_hooks.sh 同源计数）

  ✅ <repo>/.claude/hooks
  ✅ <repo>/unisoc/flow-kit/dist/dsh-flow-kit/hooks
  ✅ <repo>/unisoc/flow-kit/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ <repo>/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks
  ✅ <repo>/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks
  ✅ <repo>/.config/opencode/hooks

✅ hooks 副本一致（漂移 0）
📦 make check-dist: 打包件新鲜度检查 ...
✅ check-dist: dist 与源一致
🔍 make check-gate-sync: prompt↔skill 协议一致性检查 ...
🔍 check-gate-sync: 校验 prompt↔skill toll-gate 协议一致性...

   校验: A-evolve ↔ flow-evolve
     prompt: <repo>/unisoc/flow-kit/flow-kit-bundle/flow-kit/prompts/A-evolve.md
     skill:  <repo>/unisoc/flow-kit/flow-kit-bundle/skills/flow-evolve/SKILL.md
   ✅ 内容一致（已剥离 front-matter；diff 内容 = 0 行）

   校验: I-intel-scan ↔ flow-intel
     prompt: <repo>/unisoc/flow-kit/flow-kit-bundle/flow-kit/prompts/I-intel-scan.md
     skill:  <repo>/unisoc/flow-kit/flow-kit-bundle/skills/flow-intel/SKILL.md
   ✅ 内容一致（已剥离 front-matter；diff 内容 = 0 行）

   校验: L-restyle ↔ flow-restyle
     prompt: <repo>/unisoc/flow-kit/flow-kit-bundle/flow-kit/prompts/L-restyle.md
     skill:  <repo>/unisoc/flow-kit/flow-kit-bundle/skills/flow-restyle/SKILL.md
   ✅ 内容一致（已剥离 front-matter；diff 内容 = 0 行）

   校验: gate-config 预设名同步 (SKILL.md PRESET_MAP ↔ bats resolve_gate_config)
     skill:  <repo>/unisoc/flow-kit/flow-kit-bundle/skills/flow/SKILL.md
     bats:   <repo>/unisoc/flow-kit/flow-kit-bundle/test/test_gate_config_presets.bats
   ✅ 预设名集合一致 (17 个预设)

   ── 校验汇总 ──
   覆盖度: 校验对 3/14（v1 仅覆盖内容本应一致、仅差 front-matter 的对；其余 11 对已实质分叉，留 v2/TD-025）
   ✅ 校验对 3/14 一致（仅覆盖上述对，非全量 14 对全绿）。
🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ...
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
🔍 make check-nfr-portability: NFR 兼容性判据（bash 3.2/macOS 可移植 · 三态包装）...
✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造，语法检查通过

╔════════════════════════════════════════════════════╗
║  ✅ make check: 全部通过                           ║
╚════════════════════════════════════════════════════╝
```

### §B-4 · `make check-path-privacy` 自证行

```
🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ...
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
```

### §B-5 · `package-flow-kit.sh --validate` 尾部

```
🔍 package-flow-kit.sh --validate
   校验 flow-kit-bundle/ 目录结构与 Part A~G staging 指令覆盖范围...

   解析 Part A (flow-kit 核心)...
   解析 Part B (flow-* skills)...
   解析 Part C (Hook 系统)...
   解析 Part D (配置模板)...
   解析 Part E (安装脚本 + lib + specs + test)...
   解析 Part F (brooks-lint 插件)...
   解析 Part G (brooks-tools)...
   扫描 flow-kit-bundle/ 实际文件...

   ── 对账结果 ──


   ── 校验汇总 ──
   期望覆盖: 311 项
   实际文件: 317 项
   🔴 漏配 (ERROR): 0
   ⚠️  源缺失 (WARNING): 0

   ✅ 校验通过：所有文件均被 Part A~G 覆盖。
```

---

## §C 三条「`test/` 树 0 引用」生产件的判据专项（L3 第 2 轮 major 2）

这三件（`runtime-edit-guard.sh` → T05 · `check-path-privacy.sh` → T13/T17 · `check-nfr-portability.sh` → T24/T27/T28）在 `test/` 树内**零引用**，判定力只由 change 期判据承载（`Tech-debt: TD-053`）。本节给出**完整抽取命令 + 本次执行输出**，并给出**判别力实证**（判据不是恒绿）。

1. **抽取命令**：见 §A 的 `sed` 三段式（`extract_verify()` 同形）；本次实际使用的判据文件行数 = T05 12 · T13 34 · T17 73 · T24 18 · T27 19。
2. **本次执行输出**：§A-1（T05）· §A-4（T13）· §A-5（T17）· §A-9（T24）· §A-11（T27）。
3. **判别力实证（本轮实跑）**：
   - **T17 转红**：新审查档 `INDEPENDENT-REVIEW-5.md` 出现的当天，旧断言（「集合完备」）判红，报文 `🔴 排除表缺 .specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md` ⇒ 判据对仓库状态**敏感**；
   - **T17 注入判别**（临时在门禁脚本尾部追加一行含该路径的注释 ⇒ 重跑）：**rc=1**，报文
     `🔴 审查档 .specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md 被纳入门禁排除表（豁免面不得超出冻结集 1–3；放宽须 ADR 裁决 · L-149/TD-054：审查档是脱敏第一现场，豁免即盲区）`；
     `git checkout --` 还原后（`sha256` 与备份一致、`git status` 干净）重跑 ⇒ **rc=0** ⇒ 「红/绿两侧」都能被观测到；
   - **T13 双面扫描**：tracked + 未跟踪两面都扫；本轮曾对未入库的审查档判红（rc=1）并在就地 de-shape 后复绿（`TEST.md` §阶段 5 发现 #5）。
4. **不补常设 bats 的次序理由**：见 `TEST.md` §回归保护 与 §阶段 5 发现 #1（`test/**` 属源面 + 整棵入 dist；新增用例会迫使重建分发件并令 AC-8 的 976 基线口径失效）。

---

## §D 判据修正台账（摘要 · 全文见 `TEST.md` §1.7）

| task | 执行方式 | rc | 回写 `TASK.md` |
| --- | --- | --- | --- |
| 11 条（T05/T06/T11/T13/T20/T22/T24/T26/T27/T29 + T19 回写前） | 字面抽取 + 字面执行（零改写、不套 `set -e`） | 0 | 无需（本轮未修正判据） |
| T17 | 字面执行判红 ⇒ 判据策略改判为**时间切点**（修正写入权威副本 `TASK.md`） | 改判后 0 | **已回写**（T17 `<verify>` + T13 done 注记同批订正） |
| T19（strict 对照 → 已处置） | ① `bash -c 'set -euo pipefail; source …/v_T19.sh'` 于**回写前**：**1**（19 行前置输出 · 无 🔴 报文）· ② **回写后**：`bash -e -u -o pipefail …/v_T19.sh` ⇒ **0 / 37 行输出** | 见左 | **已回写**（T19 `<verify>` 4 处改为「先置零再捕获」+ 块尾约定注释，见 §I 与 `TEST.md` §1.7）；同族其余 18 处未复算判据块仍留 `Tech-debt: TD-057` |

**早退态 vs 真红态的区分**（TD-057 的实操结论）：两者 `rc` 都是 1，**只能靠报文区分** —— 真红态必有 `🔴 …` 断言行；strict 早退态没有断言行、只有前置输出。故任何「只看 rc」的自动化判定都必须同时抓断言报文。

---

## §E 性能（NFR 预算）原始回执

**预算原文**（`REQUIREMENT.md` §非功能性需求）：`make check-path-privacy` 单次 **≤ 5 秒**；`check-gate-sync` 秒级。

**测量环境**：`nproc=32` · 运行前 `loadavg` = `6.04 / 6.48 / 6.52`（§E-1 的 5 次）与 `6.20 / 6.45 / 6.51`（§E-2 的 5 次）· 无并发测试进程 · git 索引热态（前序门禁已扫过同一工作树）。

**§E-1 · 5 次实测（`TIMEFORMAT='real=%R user=%U sys=%S'`）**

```
check-path-privacy run1: real=2.842 user=1.180 sys=1.782
check-path-privacy run2: real=2.847 user=1.174 sys=1.788
check-path-privacy run3: real=2.898 user=1.196 sys=1.792
check-path-privacy run4: real=2.836 user=1.168 sys=1.782
check-path-privacy run5: real=2.867 user=1.176 sys=1.796
⇒ min 2.836 · max 2.898 · 均值 2.858 s（预算 5 s 的 57%）；极差 0.062 s
```

**§E-2 · 本次复算运行的 [D] 段（同口径，第二轮独立 5 次）**

见 §B-1 中 `== [D] NFR 预算（time ×5）==` 段落（脚本自动打印 `nproc`/`loadavg` 与每次 real/user/sys）。

**判定**：✅ **达标**（最差单次仍留 ≥42% 余量）；`check-gate-sync` 0.053/0.047 s、`check-nfr-portability` 0.172 s 均秒级内（`TEST.md` §2.2）。

---

## §F 973 → 976 归因（L3 第 2 轮 minor ④）

```bash
git diff --stat 534e3e8..HEAD -- test/
for f in $(git diff --name-only 534e3e8..HEAD -- test/); do
  printf '%s  base=%s  head=%s\n' "$f" "$(git show 534e3e8:"$f" | grep -c '@test')" "$(grep -c '@test' "$f")"
done
```

```
 test/test_archive_commit_gate.bats       | 16 ++++++++++++++++
 test/test_auto_checkpoint.bats           | 31 ++++++++++++++++++++++---------
 test/test_check_gate_sync.bats           | 13 +++++++------
 test/test_combined_metric.bats           | 18 ++++++++++++++----
 test/test_correction_hygiene.bats        | 10 +++++-----
 test/test_independent_review_model.bats  |  6 ++++++
 test/test_l3_review_defects_2026_09.bats |  2 +-
 test/test_lessons_cleanup.bats           | 16 +++++++++++++---
 8 files changed, 84 insertions(+), 28 deletions(-)
--- 逐文件 @test 计数 ---
test/test_archive_commit_gate.bats  base=24  head=27
test/test_auto_checkpoint.bats  base=13  head=13
test/test_check_gate_sync.bats  base=5  head=5
test/test_combined_metric.bats  base=2  head=2
test/test_correction_hygiene.bats  base=10  head=10
test/test_independent_review_model.bats  base=12  head=12
test/test_l3_review_defects_2026_09.bats  base=124  head=124
test/test_lessons_cleanup.bats  base=16  head=16
```

⇒ `@test` 计数**唯一变化** = `test/test_archive_commit_gate.bats` 24 → 27（+3）⇒ **973 + 3 = 976**；历史「1 skip」= 变更前基线中 `test_lessons_cleanup.bats` 的过期 skip，已由 AC-7 移除 ⇒ 现基线 976 ok / 0 not ok / **0 skip**。

---

## §G 复算入口与失败语义

```bash
bash .specs/health-fix-2026-09b/reproduce-5-test.sh                  # 全量：12 条判据 + 6 项门禁
bash .specs/health-fix-2026-09b/reproduce-5-test.sh --criteria-only  # 只跑判据
bash .specs/health-fix-2026-09b/reproduce-5-test.sh --gates-only     # 只跑门禁
bash .specs/health-fix-2026-09b/reproduce-5-test.sh --only T19,T27   # 指定判据
```

- 判据输出逐条落盘：`<日志目录>/out_<Tnn>.txt`，判据源码：`<日志目录>/v_<Tnn>.sh`（**与 `TASK.md` 逐字节同源**，可直接 `diff` 复核）。
- 退出码：全绿 `0`；任一判据/门禁非 0 ⇒ `1`（并在 stdout 打印失败清单 `判据失败[ … ] 门禁失败=…`）。
- 判据用的隔离夹具（bare remote 等）建在 `${TMPDIR:-/tmp}` 下，**不触碰仓库工作树**（唯一例外：`make check-path-privacy` / `validate` 等门禁在工作树内只读执行）。

## §H 阶段门沙箱复现（.specs/health-fix-2026-09b/reproduce-phase-gate.sh 原始输出）

> 工件：`.specs/health-fix-2026-09b/reproduce-phase-gate.sh`（L3 第 3 轮 major 3 的响应：UAT ③ 的可运行复现）
> 本次运行：2026-09-24T11:06:36+08:00 · **rc=0**
> 机制：沙箱内 `git init` + 夹具 `.flow-active` / `.specs/<id>/TEST.md` / `INDEPENDENT-REVIEW-5.md`，用 stdin JSON（`hook_event_name`/`session_id`/`cwd`/`tool_name`/`tool_input.command`）真实调用
> `.specs/health-fix-2026-09b/../../flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`；被测命令 = `git commit -m probe -- .specs/<id>/TEST.md`。夹具与见证均在临时目录，不触碰工作树。

```text
== 沙箱 = /tmp/fk-phasegate-Rd3SXq
== 门禁 = <repo>/unisoc/flow-kit/flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh

── 对照 0：门禁外直连 git …（证明仓库本身可提交，拦截不是命令形态问题）
  ✅ 门禁外直连 commit 成功（HEAD 前进）（yes）

── 状态 A：gate_config["5-test"]=both 且无 .done（历史事件 ③ 的等价形态）
  ✅ 门禁 rc（拒绝）（2）
  ✅ 报文含「⛔ 独立 review gate：阶段 5 (5-test) 独立 review 未完成，禁止 git commit。」
  ✅ HEAD 未变（a44e9bed6d8c127b8d4da3b8ddd7e5bf08bb2a94）

── 状态 B：gate_config["5-test"]=L2 + 合格 .done（6 键 KVP · 阶段 5 健康态）── 同一命令应放行
  ✅ 门禁 rc（放行）（0）
  ✅ 放行后真 commit 生效（HEAD 前进）（yes）

── 状态 B2：缺口实证 —— .done 记 pass 而审查档记 fail（口径不一致 · Tier-2 T4 校验）⇒ 按当前实现应被放行（TD-059）
  ⚠️ 缺口实证（TD-059）：口径不一致（标记记 pass / 审查档记 fail）仍被放行（按当前实现 = 0）

── 状态 B3：缺口实证 —— .done 缺 L3_verdict 键（残缺 / 伪造 · Tier-1 值域校验）⇒ 按当前实现应被放行（TD-059）
  ⚠️ 缺口实证（TD-059）：残缺标记（删 L3_verdict 键 · 5 行 < 6 行下限）仍被放行（按当前实现 = 0）

── 状态 C：沙箱无 .flow-active（门不适用 ⇒ fail-open 对照）
  ✅ 门禁 rc（不适用）（0）

✅ 阶段门复现：健康层全部符合（A 拒绝且 HEAD 不变 · B 放行且 commit 真的生效 · C 门不适用放行）；判别子：门禁外直连 commit 可用 ⇒ 拦截确由门禁判定产生。
⚠️ 缺口层（B2/B3）按当前实现被放行 —— **TD-059**：阶段门在 commit 路径上是「完成标记是否存在」的判定 ⇒ 6 键 / Tier-2 一致性校验不可达。非健康行为，不得读作通过。
```

**读法**：健康层 A（无完成标记 ⇒ rc=2 + 拒绝报文 + HEAD 不变）· B（合格 6 键标记且 `gate=L2` ⇒ rc=0 且放行后 commit **真的生效**）· C（无 `.flow-active` ⇒ 门不适用 ⇒ rc=0 fail-open）全部符合；
判别子「门禁外直连 commit 可用」证明拦截确由门禁判定产生（而非命令形态/环境问题）。
**缺口层 B2/B3 按当前实现被放行** —— 这是 **TD-059** 的显式缺口实证，**不是通过项**：阶段门在 commit 路径上只判定「完成标记是否存在」，
标记一旦存在，6 键值域校验与 Tier-2（标记口径 vs 审查档口径）校验即不可达；脚本用 `check_gap()` 记录该形态，行为若变化只提示 ℹ️ 而不判失败。
详见 `.specs/CONTEXT.md` TD-059·TD-058 与 `.specs/LESSONS.md` L-152。

---

## §I 处置后复算回执（L3 第 3 轮 4 major / 4 minor 落工件之后）

> 运行：2026-09-24（+08:00）· `bash .specs/health-fix-2026-09b/reproduce-5-test.sh` ⇒ **rc=0（复算全绿）**；本轮新增 **[F] 阶段门沙箱复现** 步（§H 即该步的原文）。
> 原始日志：`/tmp/p5/reproduce-final3.txt` · 逐条落盘 `/tmp/fk-reproduce-5/`（`out_<Tnn>.txt` / `v_<Tnn>.sh`）。

| 面 | 结果 |
| --- | --- |
| 关键判据 12/12 | ✅ rc=0（抽取行数：T05 12 · T06 22 · T11 7 · T13 34 · T17 73 · **T19 36（回写后）** · T20 3 · T22 20 · T24 18 · T26 30 · T27 19 · T29 15） |
| `npx bats --count test/` | ✅ 976 |
| `npx bats test/` | ✅ rc=0 · ok=976 / not ok=0 |
| `make check` | ✅ rc=0 · 21 条 ✅ / 0 条 ❌ |
| `make check-path-privacy` | ✅ rc=0 · 清单外命中 0 条 |
| NFR `time make check-path-privacy` ×5 | ✅ real 2.876 / 2.822 / 2.850 / 2.834 / 2.871 s（min 2.822 · max 2.876 · 均值 **2.851** = 预算 5 s 的 **57%**）· nproc=32 · loadavg 5.95 6.13 6.25 |
| `package-flow-kit.sh --validate` | ✅ rc=0 · 漏配 0 / 源缺失 0 |
| **[F] 阶段门沙箱复现** | ✅ rc=0 · 健康层 A/B/C ✅ · 缺口层 B2/B3 ⚠️（TD-059，非通过项） |

**本轮处置的实证亮点（判据活性 · 非恒绿）**：新增工件 `reproduce-phase-gate.sh` 里用了 `sed -i`（GNU-only）⇒ **两条判据在数分钟内转红并指名 `file:line`**：T29（rc=1，报文「🔴 新增行含 bash4-only / GNU-only 构造，命中位置」）与 `make check-nfr-portability`（`make check` rc=2）；改为「`sed … > tmp && mv`」后双双回绿。这正是 AC-8 兼容性判据「对新代码有效」的现场证据 —— 也说明 §0 的「全绿」是被判据逼出来的，不是恒绿。

**与 §E 的口径关系**：§E 记录首次运行（10:40）的 5 次实测（2.836–2.898 s，均值 2.858）；本轮为**处置后**独立复测（2.822–2.876 s，均值 2.851），两次结论一致（≈57% 预算）。`TEST.md` §2.2 已同时列出两组。

**失败语义复查**：`reproduce-5-test.sh` 在任一判据/门禁非 0 时打印「🔴 复算未全绿：判据失败[ … ] 门禁失败=N」并 `exit 1`（本轮修复 GNU-only 之前的那次运行即为该形态：`判据失败[ T29 ] 门禁失败=1`、`REPRO2 rc=1`）⇒ 判据真的会红，且能指名到 task 与 `file:line`。

---

## §I-1 端到端耗时与抽取对照（L3 第 4 轮 minor ①/⑤ 的原始回执）

> 运行：2026-09-24（+08:00）· 同一台机器 `nproc=32` · 命令字面 = `TIMEFORMAT='real=%R user=%U sys=%S'; time npx bats test/; time make check`。

```
== time npx bats test/ ==
real=121.203 user=81.050 sys=44.707
bats rc=0
== time make check ==
real=258.890 user=170.315 sys=93.520
check rc=0
T17 verify 行数: 75
T19 verify 行数: 38
```

- `npx bats test/` rc=0（原始输出 `/tmp/p5/bats-e2e.out`）· `make check` rc=0（原始输出 `/tmp/p5/check-e2e.out`）。
- **增量口径**：本次新增的三道门禁合计 ≈ **3.0 s**（`check-path-privacy` 2.8 + `check-gate-sync` 0.05 + `check-nfr-portability` 0.17）⇒ 占 `make check` 端到端的 **1.2%**，判定不变（§E / §I 的 ≤5 s 与「秒级」预算均达标）；bats 主体 121.2 s 不受新门禁影响。
- **抽取对照（minor ⑤）**：`T17` / `T19` 的 `<verify>` 抽取结果与复算脚本落盘副本 `cmp` **rc=0**（**73 / 36 行**；上面打印的 75 / 38 = 含 `<verify>` 与 `</verify>` 两行标签本身）。复算命令与回执另见 `TEST.md` 附录 B。
