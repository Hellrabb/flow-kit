# T-FIX-01 SUMMARY — TD-053 常设回归网（三件生产件双态 bats）

- change: `health-fix-2026-09b` · task: `T-FIX-01`（fix 波次 · 阶段 4 DEV · 只加常驻判据，**不改任何生产件**）
- commit: `5ee4ebc` — `test(health-fix-2026-09b): T-FIX-01 TD-053 常设回归网（三件生产件双态 bats）`
- 新基线: `npx bats test/` = **1001 ok / 0 not ok / 0 skip**（TAP plan `1..1001`）；`npx bats --count test/` = **1001**（原 976 + 本 task 25）
- 文内所有本机账号路径按 L-129 记为 `<repo>`，其余逐字。

## ① 交付物清单（含行数）

| 文件 | 行数 | 说明 |
| --- | --- | --- |
| `test/test_path_privacy_gate.bats` | 163 | F1 · 驱动真实 `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（9 用例） |
| `test/test_runtime_edit_guard.bats` | 113 | F2 · 驱动真实 `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`（9 用例） |
| `test/test_nfr_portability_gate.bats` | 127 | F3 · 驱动真实 `make check-nfr-portability[-internals]` 三态 + 包装层映射（7 用例） |
| `flow-kit-bundle/test/` 同名三件 | 163 / 113 / 127 | `make test-sync` 单向产物（非手改），`make check-test-sync` rc=0 |
| `.specs/STATE.md` | +3 / −2 | 计数基线 976 → 1001（就地更新既有计数行，并补一条「基线演进」引用行） |
| `dist/`（gitignored，不入库） | — | `bash package-dsh-plugin.sh` 重建（rc=0），`make check-dist` rc=0 |

合计 **25 个新用例**（F1 9 + F2 9 + F3 7）；`<verify>` 的 ok 下限是 18。三文件均为 `-rw-r--r--`（与既有 `test/*.bats` 一致）。

## ② `<verify>` 原始输出全文

### 抽取方式（逐字取自 TASK.md，32 行，未改一字）

```
awk '/<task id="T-FIX-01"/,/<\/task>/' .specs/health-fix-2026-09b/TASK.md \
  | awk '/^  <verify>$/,/^  <\/verify>$/' | sed '1d;$d;s/^    //' > /tmp/tfix1-verify.sh
bash /tmp/tfix1-verify.sh
```

### 2.1 原样跑（`bash /tmp/tfix1-verify.sh`）— 独立跑两次，输出**逐字一致**

```
TAP: ok=25 not-ok=0 rc=0
🧪 make test: running bats...
ok 999 CF-01: write_compliance_correction creates valid JSON with all fields
ok 1000 CF-02: write_compliance_correction merges with existing + dedup
ok 1001 CF-03: clear_compliance_correction removes the file
❌ bats: some tests failed
make: *** [Makefile:11: test] Error 1
🔴 make check 不绿
===VERIFY_RC=1===
```

（原始文件：`/tmp/tfix1-verify-run1.out`、`/tmp/tfix1-verify-run2.out`；`diff` 结果为空。第 31 行 `make check` 的完整输出 `/tmp/tfix1-check-run1.out` 见 2.2。）

### 2.2 原样跑里 `make check` 的原始输出（6 行，全文）

```
🧪 make test: running bats...
ok 999 CF-01: write_compliance_correction creates valid JSON with all fields
ok 1000 CF-02: write_compliance_correction merges with existing + dedup
ok 1001 CF-03: clear_compliance_correction removes the file
❌ bats: some tests failed
make: *** [Makefile:11: test] Error 1
```

**归因（已坐实）**：`make check` 的第一个前置 `test` 的第二轮 `npx bats test/ > /dev/null 2>&1` 红。全量套件在 `LC_ALL=C` 下 = **1000 ok / 1 not ok**，唯一红点：

```
not ok 646 T06fix: L2 R1 - line cap truncation respects UTF-8 boundary
# (in test file test/test_l3_pipeline_fix.bats, line 609)
#   `printf '%s' "$capped" | iconv -f utf-8 -o /dev/null   # 非法 UTF-8 → iconv 非零' failed
# iconv: illegal input sequence at position 136
```

该用例属**既有**文件（`test/test_l3_pipeline_fix.bats:592`，工作树未改），与本 task 写面无关 ⇒ 见 ④ 偏离 ①。

### 2.3 `<verify>` 其余各步的原始证据（原样跑中对全部 31 步逐条命中）

- 第 15 行：`TAP: ok=25 not-ok=0 rc=0`（`ok ≥ 18` 满足；`brc=0`；`NOTOK=0`）
- 第 21–22 行 · **活性探针**（把两件生产件打成 `#!/bin/bash\nexit 0` 恒绿桩后跑 F1+F2）：

```
$ grep -c '^not ok' /tmp/tfix1-stub.out
14
$ grep '^not ok' /tmp/tfix1-stub.out
not ok 1 干净态：常设清单在位 + 无探针 ⇒ rc=0 且自报「清单外命中 0 条」
not ok 2 真名探针（拼接构造）⇒ rc=1 且归因到 file:line
not ok 3 常设与 change 副本皆缺 ⇒ rc=1 且指名两个缺失路径（不得当空清单放行）
not ok 4 空清单（0 条有效条目）⇒ rc=0 且自报「允许清单 0 条」（空清单不是错误）
not ok 5 空清单 + 真名探针 ⇒ rc=1（空清单不得静默跳过扫描 · 反假绿）
not ok 6 命中落在允许清单内 ⇒ rc=0（只暴露不阻塞）
not ok 7 占位形态（<user> 与 user）⇒ 不命中 ⇒ rc=0
not ok 8 常设缺、change 副本在 ⇒ 读 change 副本（读序回退）
not ok 9 常设与 change 副本皆在 ⇒ 常设优先（读序不回退）
not ok 10 Write + 相对路径 ⇒ exit 2 且报文含「无法解析为绝对路径」
not ok 11 Write + ~user 形态 ⇒ exit 2（fail-closed，不做 passwd 查询）
not ok 12 Write + 空 file_path ⇒ exit 2
not ok 15 绝对路径命中 ~/.claude/hooks + 维护源在位 ⇒ exit 2 且报文含维护源路径
not ok 16 ~/ 展开分支命中 ~/.claude/skills + 维护源在位 ⇒ exit 2
```

  ⇒ 恒绿桩下 F1 九例全红、F2 拒绝组（10/11/12/15/16）全红，**活性已证**；F2 的放行组（拒绝报文不得出现）在桩下自然仍绿，符合设计。
- 第 25–26 行：两件生产件的 `cmp -s` 还原校验均通过（独立复核 md5：`06e7a97382ed666b99e5b3edaf32f1fb` / `3af4d757a8b1502adb5b6bbc1d3d1ecf`，与手工备份 `/tmp/tfix1-pp.manual.bak` / `/tmp/tfix1-reg.manual.bak` 一致）。
- 第 27 行：还原后 F1+F2 回绿（`npx bats $F1 $F2` rc=0，`>/dev/null`）。
- 第 28–30 行：`make check-test-sync` / `make check-dist` / `make check-path-privacy` 各自 rc=0。

### 2.4 最小偏离复跑（唯一差异：第 1 行 `export LC_ALL=C;` → `export LC_ALL=C.utf8;`）— **rc=0**

```
$ sed 's/^export LC_ALL=C;/export LC_ALL=C.utf8;/' /tmp/tfix1-verify.sh > /tmp/tfix1-verify-cutf8.sh
$ bash /tmp/tfix1-verify-cutf8.sh; echo "VERIFY_CUTF8_RC=$?"
TAP: ok=25 not-ok=0 rc=0
VERIFY_CUTF8_RC=0
```

该次运行第 31 行 `make check` 的结尾（原始输出 `/tmp/tfix1-check-cutf8.out`，路径已脱敏为 `<repo>`）：

```
   校验: gate-config 预设名同步 (SKILL.md PRESET_MAP ↔ bats resolve_gate_config)
     skill:  <repo>/flow-kit-bundle/skills/flow/SKILL.md
     bats:   <repo>/flow-kit-bundle/test/test_gate_config_presets.bats
   ✅ 预设名集合一致 (17 个预设)
🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ...
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
🔍 make check-nfr-portability: NFR 兼容性判据（bash 3.2/macOS 可移植 · 三态包装）...
✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造，语法检查通过
╔════════════════════════════════════════════════╗
║  ✅ make check: 全部通过                           ║
╚════════════════════════════════════════════════╝
```

### 2.5 语言环境三态隔离探针（单文件跑，含/不含本 task 文件均同结论）

```
$ LC_ALL=C     npx bats test/test_l3_pipeline_fix.bats --filter 'line cap truncation respects UTF-8 boundary'
1..1
not ok 1 T06fix: L2 R1 - line cap truncation respects UTF-8 boundary
# iconv: illegal input sequence at position 136
rc=1
$ LC_ALL=C.utf8 npx bats test/test_l3_pipeline_fix.bats --filter 'line cap truncation respects UTF-8 boundary'
1..1
ok 1 T06fix: L2 R1 - line cap truncation respects UTF-8 boundary
rc=0
$ env -u LC_ALL npx bats test/test_l3_pipeline_fix.bats --filter 'line cap truncation respects UTF-8 boundary'   # 宿主 LANG=zh_CN.UTF-8
1..1
ok 1 T06fix: L2 R1 - line cap truncation respects UTF-8 boundary
rc=0
```

### 2.6 全量套件与其他基线证据

```
$ npx bats test/ > /tmp/tfix1-full-suite.tap 2>/tmp/tfix1-full-suite.err; echo rc=$?
rc=0        # TAP: 1..1001 · ok=1001 · not ok=0 · skip=0
$ npx bats --count test/
1001
$ LC_ALL=C npx bats test/ > /tmp/lc-c-suite.tap; echo rc=$?
rc=1        # ok=1000 / not ok=1（唯一 = 646，见 2.2）
$ make test    # 原样，无任何 locale 覆盖
START 15:34:28 … ✅ bats: all tests passed … make test rc=0 END 15:38:45
```

## ③ 6 维自检

1. **测试是否有效（是否真的驱动生产件）**：三个夹具都在 `setup()` 里**运行时复制当前源**（`cp -- "$SUT_SRC" "$FIXTURE/…"`）后再调用，因此桩注入必被吃到——证据即 2.3 的 14 行 `not ok`。F3 复制真实 `Makefile` 到夹具仓，用 `FLOW_KIT_CHANGE_BASE=<sha>` 锚定真实变更集，经 `make -C "$FIXTURE" check-nfr-portability[-internals]` 驱动真实 target（不是重写判据）。
2. **是否可能假绿**：(a) 拒绝态一律**双断言**（`$status` 精确值 + `$stderr`/`$output` 关键词）；(b) F3 断言的是**三态数字**（`$NFR_RC_FILE` 里的 3/1/0）而不是 make 退出码——因为该 target 所有分支都 `exit 0`，只看退出码必然假绿；包装层另断言 `status -eq 2` 且 stderr 含 `Error 1`/`错误 1`（明确拒绝 0）；(c) 反假绿用例：空清单 + 探针必须 rc=1（若实现把空清单当错误跳过、或静默跳过扫描即红）；(d) 全部 `run --separate-stderr`（并声明 `bats_require_minimum_version 1.5.0`），内容断言区分 stdout/stderr——避免 stderr 混入造成假绿或假红。
3. **边界**：空清单（0 条有效条目，注释计数为 0 合法）；两份清单皆缺 ⇒ fail-closed rc=1 并指名两个缺失路径；清单内命中 ⇒ 只暴露不阻塞（命中合计 1 / 清单外 0，rc=0）；读序回退（常设缺 ⇒ 用 change 副本）与不回退（两者皆在 ⇒ 常设优先）；占位形态 `/home/<user>/…` 与 `/home/user/…` 均不命中（同时锁字符类边界与占位符表）；F2 的 `~user`（fail-closed，不做 passwd 查询）、空 `file_path`、相对路径三个拒绝态与 Bash/Read 两个放行态；维护源缺失 ⇒ rc=0（fail-open 边界）；F3 的整行注释 `# sed -i` 与合规惯用法 `stat -c … || stat -f …` 不误报、未跟踪 `extra/new.sh` 也纳入扫描面。
4. **负面用例**：每个 fail-closed 点都配了「缺失/缺源」用例；每条「拒绝」都配了对应「放行」用例（防判据恒红而无人察觉）；桩活性探针把「全绿」与「空转」区分开。
5. **夹具隔离**：全部 `mktemp -d "${TMPDIR:-/tmp}/fk-…XXXXXX"`；F2 夹具自带 `HOME=$TEST_TMPDIR/home`（绝不触碰真实家目录）；`teardown(){ rm -rf "$TEST_TMPDIR"; }`；用例内不在工作树写任何文件。verify 全部跑完后 `git status --short` 只剩有意文件（3 个新 bats + 3 个 test-sync 产物 + `.specs` 既有改动），无探针残留。
6. **可复算性**：`export LC_ALL=C.utf8; npx bats test/test_path_privacy_gate.bats test/test_runtime_edit_guard.bats test/test_nfr_portability_gate.bats` ⇒ `1..25 / 0 not ok`；`npx bats test/` ⇒ 1001 ok；`npx bats --count test/` ⇒ 1001；`make test-sync && make check-test-sync` ⇒ rc=0；`bash package-dsh-plugin.sh && make check-dist` ⇒ rc=0；`make check` ⇒ `✅ make check: 全部通过`。步级 rc 与期望值一一对应（见 ② 与 ④）。

## ④ 遗留与偏离

### 偏离 ①（关键 · 环境冲突，非本 task 引入）：`<verify>` 首行 `export LC_ALL=C` 与既有用例冲突

- **现象**：`LC_ALL=C` 下既有用例 `test/test_l3_pipeline_fix.bats:592`（`T06fix: L2 R1 - line cap truncation respects UTF-8 boundary`）必红——断言 `:609` 的 `iconv -f utf-8` 报 `illegal input sequence at position 136`；`LC_ALL=C.utf8` 与宿主 `zh_CN.UTF-8` 下该用例绿（2.5 三态证据）。因此 `<verify>` 原样跑时 `make check` **不可能全绿**：两次独立跑均 rc=1，且唯一红点固定在第 31 行。
- **与本 task 无关的证据**：(a) 工作树内**没有任何生产 `.sh` 改动**（`git status --short` 仅 `.specs/*` + 本 task 新增 bats）；(b) 单文件隔离跑（`--filter` 只跑该用例）仍复现，未加载本 task 文件；(c) 已排除其它猜测：原样 `make test` rc=0（所以不是第二轮 `>/dev/null`、不是并发/负载）、无 `NFR_RC_FILE`/`MAKEFLAGS` 等环境泄漏、两件被桩过的生产件已 `cmp` 还原一致。
- **采取的最小偏离**：把 `<verify>` 第 1 行的 `export LC_ALL=C;` 换成 `export LC_ALL=C.utf8;`，其余 31 行逐字不动 ⇒ **`VERIFY_CUTF8_RC=0`**（2.4）。`C.utf8` 仍给出确定的字节序（TAP/`sort` 解析的确定性诉求不变），同时保留 UTF-8 字符语义，故不破坏既有用例。
- **上游定位（未坐实，供后续 TD/责任方复核；本 task 未改任何生产件）**：200B 行 cap 的 helper 已排除——`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:36` 的 `_l3_utf8_head_stream` 在 `C` 与 `C.utf8` 下对同一输入都输出 196 B **合法** UTF-8；且 `local LC_ALL=C`（`:38`）经探针确认**生效**（`${#d}`=9 字节、首「字符」=228，两 locale 一致）。非法序列起点 136 落在 ASCII 前缀（117 B）之后的多字节区中段 ⇒ 区域敏感点在其**上游的提取/装配链路**；候选：GNU Awk 5.2.1 的字符/字节语义（`flow-kit-bundle/hooks/stop/lib/l3-section.sh:113`、`:231`、`:266` 的 `awk`）与 `grep -oP`（`l3-api.sh:218`、`:231`，`l3-prompt.sh:194`、`:354`）。建议主 agent 开 TD 交 L2 R1 责任方。

### 遗留 ①（生产件行为，本 task 不改）：非 git 仓库下 `check-path-privacy.sh` 静默 rc=0

`git ls-files` 在非 git 仓库下失败但被 `|| true` 吞掉 ⇒ 候选面为空 ⇒ 自报「清单外命中 0 条」并 rc=0。属生产件行为（本 task 只加判据、不改生产件），建议登记 TD 或在后续 fix 波次收口；常设网已用「空清单 + 真名探针 ⇒ 必须 rc=1」锁住最容易假绿的那条分支。

### 遗留 ②（文档口径过时，本 task 写面外）

`.specs/health-fix-2026-09b/TEST.md` 现有一段「本 change **未新增** bats 文件」的表述，在本 task 落地后已过时（新增 3 个 bats / 25 例、基线 976 → 1001）。该文件不在本 task 的 `write_files`，未修改，请主 agent 在 housekeeping 时一并订正。

### 遗留 ③（口径提示 · 已就地订正 STATE.md）

`make test` 的 stdout 是装饰性 `tail -3`（本轮为 3 条 `CF-0x` 用例行），**不能**作为计数依据；权威口径是 `npx bats test/`（1..1001 / 1001 ok）与 `npx bats --count test/`（1001）。`.specs/STATE.md` 的计数行已就地更新并补了一条「基线演进」引用行（976 = T29 基线；+25 = F1 9 + F2 9 + F3 7）。

### 环境备注

- 宿主 `LANG=zh_CN.UTF-8`（无 `LC_ALL`）；`locale -a` 提供 `C.utf8`。本仓 `core.hooksPath` 为空（提交不触发 hooks），质量由手动 `make check` 保证。
- 全量套件在 stderr 上会打印 46 条 bash「unterminated here-document」告警，来自**其它既有** bats 文件（本 task 三个文件单独跑均为 0 条，已逐文件核对），属既有噪声、不影响 TAP 计数。
