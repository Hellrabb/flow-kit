# TEST: L3 审查链五类缺陷修复（§B1–§B5 + M32/M34/M35/M36/M37）

- **Change ID**: `l3-review-defects-2026-09`
- **关联**: `@.specs/l3-review-defects-2026-09/REQUIREMENT.md`（AC-1–AC-12）、`DESIGN.md`（D1–D14）、`DEV-SUMMARY.md`
- **测试对象**: flow-kit 的 L2/L3 独立审查链（hooks/stop + hooks/pre-tool-use + 同步工具）

---

## 0. 本次测试范围声明（5 轮金字塔）

| 轮次 | 适用性 | 说明 |
| --- | --- | --- |
| 1 功能测试 | ✅ 主要轮次 | 86 条 bats 回归（B1–B10 + AC2），逐条对应 AC |
| 2 性能测试 | ⚠️ 限量 | 无服务/无网络路径；只测 hook 的**墙钟开销**与提示词构造的线性度（见 §2） |
| 3 安全测试 | ✅ 适用 | 本 change 的主战场：**不可信载荷**伪造结构性边界（ADR-026）；另跑依赖/秘钥扫描 |
| 4 兼容性测试 | ✅ 适用 | bash/awk/sed 版本差异、`--posix` 行为、多平台安装树（7 个 DEST_ROOTS） |
| 5 可观测性验证 | ✅ 适用 | 告警面：截断告警、空值告警、结构自检告警、corpus/verify-claims 输出 |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵（AC → 用例）

| AC | 用例 | 结果 |
| --- | --- | --- |
| AC-1 L3 段不冒充 L2（含 L3 段内行首 `## `） | B1-R2[1-4]、B1-R27、B2-R9、B2-R11、B2-R13、B2-R17/R18/R19 | ✅ 27(B1)+21(B2) |
| AC-2 活语料零非枚举 + 每份空值可归因（数值预算按基线语料 ≤8） | 「AC2: 活语料零非枚举 + 每份空值可归因」+ `L2-EMPTY-ATTRIBUTION.md`（`corpus-count.sh --attribution` 机械再生） | ✅ 1（`n=227 empty=11 base_empty=8 nonenum=0`） |
| AC-3 §B1 的五行输入回归 | B1-R1 | ✅ |
| AC-4 段重写幂等（标记/围栏/空行零残留） | B2-R2、B2-R6、B2-R7、B2-R10 | ✅ |
| AC-5 无标记历史件仍可清除 | B1-R21、B2-R3、B2-R4 | ✅ |
| AC-6/AC-7 键名=字节 + 旧键 DEPRECATED | B3-R1..R5b | ✅ 8 |
| AC-8/AC-9 产物清单全量 + 必备件 MISSING 严格 | B4-R1..R4 | ✅ 4 |
| AC-10 副本零漂移（含反向残留可发现） | B5-R1..R5 | ✅ 5 |
| AC-11 双源同步 + 结构门槛 | `make check-test-sync`、`test_lib_split_metrics.bats`（l3-api.sh 250/250） | ✅ |
| AC-12 空值可观测告警 | B1-R25、B1-R26、B1-R27 | ✅ |
| （M32）非 pass 撤销陈旧锚点 | B6-R1..R6 | ✅ 6 |
| （M34）提示词补充产物全量 | B7-R1..R5 | ✅ 5 |
| （D13）读侧还原转义 | B8-R1、B8-R2 | ✅ 2 |
| （M36/M37）贴入路径可执行拦截（Write/Edit+Bash） | B9-R1..R8 | ✅ 8 |
| （M37）写入后结构自检 | B10-R1..R5 | ✅ 5 |

**实测（现算）**：`npx bats test/test_l3_review_defects_2026_09.bats --formatter tap | awk '/^ok/{o++} /^not ok/{n++} END{printf "ok=%d not_ok=%d\n", o, n+0}'`
→ **98 ok / 0 not ok**；`npx bats test/` 同法 → **924 ok / 0 not ok**（数字随用例增长漂移，只断言 `not_ok=0`；bats 版本 1.13.0 未固定 —— 见 M42）。

### 1.2 UAT 脚本

见 `@.specs/l3-review-defects-2026-09/UAT.md`（UAT-1 全流程 / UAT-2 对抗载荷 / UAT-3 漂移与门禁）。

### 1.3 覆盖率

本 change 无传统行覆盖率工具（bash 工具链）；以**AC 覆盖 + 分支自证**替代：

| 指标 | 口径 | 实测 |
| --- | --- | --- |
| AC 覆盖 | 12 条 AC 全部有用例（§1.1） | 12/12 |
| 降级分支覆盖 | 每个 fail-closed / 降级分支都有「能失败」的断言 | 7 处：**行为变异** 2 处（B1-R27 经 stub 树真跑 29 号；B5-R4 真造漂移）；**接线非恒真** 5 处（B2-R16/R21、B6-R5、B9-R6、B10-R5，其自指局限见 M41） |
| 语料回归 | 全仓 `INDEPENDENT-REVIEW-*.md` 复算（活语料，**数量随审查轮次自增**） | `bash corpus-count.sh` → 现算 `228 102 133 133 11 0`（末位 = 非枚举，**必须为 0**；基线 `base_empty=8`） |
| 镜像一致性 | 47 个镜像文件 × 7 个落点 | 漂移 0（`./sync-hooks.sh --check`） |

### 1.4 边界 / 错误路径用例

| # | 边界 | 用例 | 断言 |
| --- | --- | --- | --- |
| 1 | 载荷含行首 `## ` / 围栏 / 标记字面量 | B2-R1/R6/R10 | 段内不残留、围栏恰 2 条、标记恰 1 个 |
| 2 | 载荷含伪 `---` + 伪 `## L3 …`（未转义） | B2-R13（已知行为）、B9-R1/R4/R7（拦截） | 拦截生效；未拦截通道的后果被如实断言 |
| 3 | 历史件无结束标记 | B2-R3/R4/R12/R17 | 完整清除且不误删后续段落；段尾收紧为已知区段 |
| 4 | L2 段存在但无 Verdict 行 | B1-R25/R26/R27 | stderr 出现 `L2 verdict not found`；实参仍为合法枚举 |
| 5 | 转义函数不可用（lib 缺失） | B2-R15/R16/R20/R21 | 两个写入方都拒写（fail-closed），不留半截段 |
| 6 | 评审文件结构损坏（段尾缺标记 / 围栏不配平） | B10-R2/R3 | Stop 侧自检告警（非阻塞） |
| 7 | 副本里残留源已删除的 hook | B5-R5 | 默认 advisory；`--strict-orphans` 计失败 |
| 8 | 顶层条目 41 的 change 目录 | B4-R1 | 清单全量、零遗漏、不误报 MISSING |

### 1.5 测试质量自检（6 维测试衰退风险）

| 维度 | 结论 | 证据 |
| --- | --- | --- |
| **脆弱性**（对无关改动过敏） | 🟡 中 | 断言锚在行为与内容契约上（无 mtime 依赖）；但**活语料类断言**（AC-2）天生对「新增审查件」敏感 —— 已改为「再生器 + 不变量」判据（不比对快照），见 §1.5 T2 |
| **慢** | 🟢 可接受 | 量级：全量 ≈ 3 分钟（924 例）；缺陷套件 ≈ 20s（98 例）。复算 `time npx bats test/` |
| **断言不足/恒真**（最危险） | 🟡 **曾发生并已修** | B7-R4 曾因 `$('\n'` 误写成命令替换而在报错文本上"假绿"；已加固（内层丢 stderr）+ B7-R5 静态钉住。`verify-claims.sh` check 5 亦曾恒真（已用真裸正则自证） |
| **重复** | 🟢 低 | 分组按缺陷编号（B1–B10），共用 setup 的 `$FK_ROOT/$L3_*` 常量 |
| **测试与实现耦合** | 🟢 可接受 | 少量"接线断言"（B6-R4/B9-R6/B10-R4）是刻意的契约断言，且每条都配变异自证 |
| **覆盖盲区** | 🟡 已知 2 处 | ① `Bash` 之外的写盘通道（外部进程直写）无法在 hook 层拦截 → 由 M37 的 Stop 侧自检兜底；② "载荷原文自带 `\## `"与"写侧转义"不可区分（M38） |

### 🔴 T2 · 活语料断言的两次假红（已修）

**结论**：AC-2 用例曾两次因语料自增而红：① 固定 `≤8` 套活语料；② 比对提交进仓库的**快照清单**
（19:55 的清单在 19:57 生成 IR-7 后即过期）。两次都不是真回归。
**处置**：判据改为「现场再生清单 → 行数 == 活语料空值数」+「零非枚举」+「基线 ≤8」；
仓库内那份清单由收尾步骤 `bash corpus-count.sh --attribution` 再生（UAT-1 第 5 条）。
**顺带修掉的真 bug**：字段提取用贪婪 `.*empty=` 会命中 `base_empty=`（曾误判 empty=8）；路径归一化
用 `${f#.specs/}` 处理不了绝对路径（曾得到 0 行）。

### 🔴 T1 · 断言可信度：假绿曾真实发生

**结论**：`B7-R4` 在修复前是**恒真**的（bash 报错文本携带载荷 → 断言在 stderr 上命中）。
**处置**：内层 `2>/dev/null` + 新增静态断言 `B7-R5`（`! grep -q "$('\n'"`）。
**遗留风险**：其它用例若用 `run`（默认合并 stderr），同样可能被"报错文本"喂绿 —— 已在本表登记，
后续新增断言凡涉及"输出中出现某串"的，应在内层显式丢弃 stderr。

### 1.6 测试质量记事（backlog）

- 引入 `run --separate-stderr`（若 bats 版本支持）作为默认，替代手工 `2>/dev/null`。
- 为 `_l3_verify_review_structure` 增加"真实损坏工件"的回归（当前用合成夹具）。

---

## 第 2 轮 · 性能测试

### 2.1 性能预算（来自 REQUIREMENT.md 非功能性需求）

| 项 | 预算 | 来源 |
| --- | --- | --- |
| L3 提示词构造 | 线性于工件字节，单次 < 1s | NFR-1（hook 不得成为交互瓶颈） |
| Stop hook 增量开销 | < 200ms（不含外部 API） | NFR-1 |
| PreToolUse 守卫 | < 50ms | 新引入的能力，需可忽略 |

### 2.2 实测结果

```
$ /usr/bin/time -f "real=%es" bash -c 'source lib/l3-prompt.sh; _l3_build_prompt 2 <change 目录> 200000 >/dev/null'
real=0.13s      # 工件 DESIGN.md 40KB 级（含补充产物与 ADR 摘录）

$ /usr/bin/time -f "real=%es" bash -c 'source lib/l3-section.sh; _l3_verify_review_structure <224KB 评审文件>'
real=0.01s（现最大件 INDEPENDENT-REVIEW-2.md = 231522B）

$ /usr/bin/time -f "real=%es" ./sync-hooks.sh --check      # 47 文件 × 7 落点
real=0.85s
```

### 2.3 工具输出

以上为 `time` 内建输出（无外部依赖；未引入 benchmark 框架 —— 本 change 不新增工具链，见 DESIGN §9.4）。

### 2.4 退步项处理

无退步。**已知非线性点**：`_l3_extra_deliverables` 的"体积升序"排序为 O(n log n)（n = 目录内
`*.md` 数，实测 ≤ 12），可忽略；`_fk_l2_scope` 为 O(文件行数) 两次扫描（spans + 过滤），
224KB 文件实测 0.02s。

---

## 第 3 轮 · 安全测试

### 3.1 依赖漏洞

**N/A** —— 无包管理器依赖（bash + coreutils + awk/sed/grep/jq/sha256sum，均为系统既有）。

### 3.2 秘钥扫描

```
$ git diff 61c4bf8..HEAD | grep -inE '(api[_-]?key|token|secret|password)[[:space:]]*[:=][[:space:]]*.{8,}' | grep -v 'auth_token\|_token\b'
（无输出）
```
L3 凭证只从 `~/.config/flow-kit/l3.env` 读取（`set -a; . file`），不入库；`l3.env.example` 仅占位符。

### 3.3 SAST

`make lint`（shellcheck error 级）：**0 error**（逐文件实测：`l3-section.sh` / `l2-detect.sh` / `l3-prompt.sh` / `sync-hooks.sh` / `gate-helpers.sh` 均 0 error）。新增代码通过 `bash -n` 语法检查。
`check-validate`（打包覆盖校验）：0 漏配 / 0 源缺失。

### 3.4 OWASP Top 10（按适用性裁剪）

| 项 | 适用性 | 处置 |
| --- | --- | --- |
| A03 注入（命令/参数注入） | ✅ **本轮核心** | 载荷一律经 `_l3_escape_payload`；`awk`/`sed` 以变量传参不经 `eval`；`grep` 模式均为字面量 |
| A08 数据/完整性失败 | ✅ | `<!-- /L3-SECTION -->` + `---` preamble 判据 + PreToolUse 拦截 + 写入后结构自检（三层） |
| A09 日志与监控失败 | ✅ | 截断告警（含丢弃比例）、空值告警、结构自检告警、熔断计数（`.l3-attempts-*`） |
| A01/A02/A04–A07/A10 | N/A | 无网络服务、无会话、无前端、无反序列化（JSON 解析只走 `jq`） |

**对抗用例实测**（可粘贴复跑）：

```
$ bash -c 'source lib/l2-detect.sh; fk_extract_l2_verdict /tmp/c1-adv.md'      # L3 段内 '## ' + 伪 Verdict
fail
$ bash -c 'source lib/l2-detect.sh; fk_extract_l2_verdict /tmp/c2-only-l3.md'  # 仅含 L3 段
（空）
$ source pre-tool-use/gate-helpers.sh; _gate_is_unescaped_l3_paste "$fake"; echo $?
0        # 命中 → 调用方 exit 2
```

---

## 第 4 轮 · 兼容性测试

### 4.1 跨浏览器（Web）

**N/A** —— 无 Web 产物。

### 4.2 视口

**N/A**。

### 4.3 数据迁移（涉及 schema 变更必填）

**N/A** —— 无 schema。配置键更名按 §4.4 处理。

### 4.4 跨版本

| 维度 | 处置 | 证据 |
| --- | --- | --- |
| bash 版本 | 不使用 bash 4+ 专有语法（关联数组/`mapfile` 未用）；`BASH_SOURCE`、`$'\n'`、进程替换为 3.2+ 特性 | `bash -n` 全绿；`npx bats test/` 全绿（现算 924 例 / not_ok=0） |
| awk 方言 | 只用 POSIX 子集（`split/substr/match`），未用 `gensub`/`asort` | 静态判据可复算：`grep -c awk flow-kit-bundle/hooks/stop/lib/*.sh` → 13（源）。**更正**：原文「231 处」无口径、不可复算（阶段 5 的 L2 实测） |
| sed 方言 | 只用 BRE + `-E` 扩展（`-E` 在 GNU/BSD 均可用） | 转义/还原函数实测 |
| 正则多字节 | `## L3 (盲审|重审)` 依赖 UTF-8 locale；已在 `LC_ALL=C` 与 UTF-8 两种下实测一致（`_fk_l2_scope` 内显式 `LC_ALL=C` 的调用点除外） | B2-R12 语料 129/129 |
| 平台安装树 | 7 个 DEST_ROOTS 全部纳入漂移门禁（此前仅 2 处被手工同步） | B5-R1..R5 |
| **配置键迁移** | 旧键 `max_artifact_chars` 仍可读 + `DEPRECATED` 提示（向后兼容） | B3-R1..R3 |
| **行为兼容** | 提取语义收紧使 8 份历史工件由"错误值"变"空值" → 下游回落 `fail`（不阻塞）；逐份归因见 `L2-EMPTY-ATTRIBUTION.md` | AC-2 用例 |

---

## 第 5 轮 · 可观测性验证

### 5.1 日志

| 事件 | 输出（stderr） | 断言 |
| --- | --- | --- |
| 提示词被截断 | `WARNING: 提示词被截断 — 完整 NB，本次仅发送 MB（丢弃 X%）` | B3-R7/R8 |
| L2 提空 | `L2 verdict not found in <file> … 保守降级为 L2_verdict=fail` | B1-R25/R26/R27 |
| 转义入口缺失 | `CRITICAL: _l3_escape_payload 不可用 … 拒绝写入未转义载荷（fail-closed）` | B2-R15/R20 |
| 结构自检失败 | `WARNING: 评审文件结构自检未通过 — <file>: <诊断>` | B10-R2/R3 |
| 副本漂移 / 反向残留 | `❌ 漂移 N 个文件` / `⚠️ 反向残留 N 个（advisory）` | B5-R2/R4/R5 |
| 锚点撤销 | `stale .done removed (phase N)` | B6-R1 |

### 5.2 指标

无 metrics 后端；以 **可复算计数器** 替代：`bash corpus-count.sh`（工件/标题/前导/空值/非枚举）、
`bash verify-claims.sh`（13 项声明核对）、`.l3-attempts-<phase>`（熔断计数）。

### 5.3 链路追踪

**N/A** —— 无分布式链路。

### 5.4 告警 + 健康检查

`make check` 五门（test / lint / validate / test-sync / hooks-sync）即健康检查；**实测全绿**。
任一门失败即 exit 非 0，可被 CI 直接消费。

---

## 新增测试登记

| 文件 | 用例数 | 说明 |
| --- | --- | --- |
| `test/test_l3_review_defects_2026_09.bats`（双源） | 86 | 新增（B1–B10 + AC2） |
| `test/test_l3_lifecycle_wiring.bats`（双源） | +2 改动 | 断言随键名更名 |
| `test/test_l3_review.bats`（双源） | +3 改动 | 同上 |
| `test/test-l3-check-rerun-content-marker.bats`（双源） | +2 改动 | 夹具补 `---` preamble |

## 回归保护

- 每次改 hook 源 → `./sync-hooks.sh && make test-sync`（**本 change 自己踩过这个坑**：漏跑 hooks
  同步导致 6 棵副本跑旧代码，被 L2 八审 critical 抓到）；
- `make check` 五门为提交前必跑；`bash verify-claims.sh` 用于核对"响应段里的可验证声明"；
- 语料类断言一律**现算**（`corpus-count.sh`），不写死快照（M35 的教训）。
