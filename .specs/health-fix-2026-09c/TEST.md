# TEST: health-fix-2026-09c · 2026-09-29 健康报告 14 项发现全量修复

- **Change ID**: health-fix-2026-09c
- **关联**: `@.specs/health-fix-2026-09c/REQUIREMENT.md`（AC-1…AC-17）、`@flow-kit-bundle/flow-kit/reference/test-pyramid.md`
- **项目类型**: CLI（Bash 门禁 + bats 测试套件 + JS 状态机）

---

## 0. 本次测试范围声明（5 轮金字塔）

| 轮次 | 状态 | 范围 | 跳过理由 |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 17 条 AC + 连带回归 | — |
| 第 2 轮 · 性能 | ✅ | 四快门 + make check 全链计时（CLI 门禁延迟即性能预算） | — |
| 第 3 轮 · 安全 | ✅ | 真名隐私四层扫描（tracked / 可达对象 / 全对象库 / 远端 clone）+ 交付物清点 | trufflehog/npm audit 不适用（无 npm 运行时依赖、无秘钥面） |
| 第 4 轮 · 兼容 | ⚠️ | node --test 20/20 + bash/bats 套件自证 + git 历史重写回滚预案（bundle） | 浏览器/视口面 N/A（CLI）；跨版本由套件 + dist 镜像断言承载 |
| 第 5 轮 · 可观测 | ⚠️ | fail-closed 具名报文三族 + 积压告警通道（module_output warning） | metric/trace 体系 N/A（门禁脚本非长时服务，stderr 即日志面） |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵（AC → 用例）

> 证据分三类：**[suite]** = bats 用例绿；**[anchor]** = REQUIREMENT 原文机检锚实测；**[ops]** = 一次性运维操作取证（T16 重写 / 工作树收口等）。执行日 2026-10-01（阶段 5）。

| AC | 类型 | 证据 | 状态 |
|---|---|---|---|
| AC-1 沙箱化+并发 | suite | `test/test_check_gate_sync.bats` 18/18（T03 交付 17 腿，后续波次连带 +1；FXC1 mktemp 沙箱、SKILL→SKILL_REL）；并发双跑逐 pid rc=0 | ✅ |
| AC-2 中断回归网 | suite | kill 注入腿（TERM/KILL → rc≠0 + `skills/` 域零改动），17 腿内 | ✅ |
| AC-3 正则收紧 | suite | `test/test_path_privacy_gate.bats` 39/39（T04：PAT 边界化 + PLACEHOLDER_NAMES 7→17 + 4 个 `T04:` 前缀用例） | ✅ |
| AC-4 tracked 脱敏 | anchor | tracked PAT 域命中 = 0 | ✅ |
| AC-5 历史重写 | ops+anchor | 远端 develop=6c25724 / main=4c81c66；可达面 `git grep -F "$HOME" $(git rev-list --all)` = 0；**全对象面 batch-all-objects = 0**（本轮收口残留工作树后）；bundle verify rc=0；T16 全新 clone 逐 blob = 0 | ✅ |
| AC-6 积压告警 | suite | `test/test_l3_backlog_alarm.bats` 4/4 绿侧用例（RED 证明为 T02 执行日操作：对前置提交 57060f8^ 旧脚本恰红——`:200 || true` 使 bl_rc 恒 0、:203 warning 恒死码；套件内不含 RED 腿） | ✅ |
| AC-7 契约闭环 | anchor | `independent_in_bats` 引用 = 0 + `resolve_gate_config()` 生产定义 = 1 | ✅ |
| AC-8 fail-closed | suite | `test/test_fail_closed.bats` 8/8（T01）；连带 `test_auto_checkpoint.bats` 13/13（用例 8/9 改断言 exit 2） | ✅ |
| AC-9 行为断言 | anchor | 机检锚（缺 `# 行为断言` 标记的 grep 命中）= 0 —— **本轮实战发现 2 处缺失并修复**（见 1.6 记事 F-1） | ✅（修后） |
| AC-10 单跑+lint | suite+anchor | ① `test_makefile_gates.bats` 用例 1：npx/bats 双假 shim 计数恰 1 行 + `^npx bats` 形态钉住；② 最小 PATH 遮蔽（无 shellcheck）→ `make lint` rc=2 + 具名 fail-closed 报文（实测）；2/2 绿 | ✅ |
| AC-11 权威载体 | anchor | `make check-skills-sync` rc=0（15/15 · 14/14 · 19/19）；薄壳 @see 15 文件；行数口径：14 薄壳文件 3275→112 行（T12a df98ddb，git 可复现），另 flow-dev 456 / flow-kit-install 111 非薄壳保持全文，skills/ 16 文件合计 3842→679 | ✅ |
| AC-12-a 死代码 | anchor | `grep -rn 'jq_atomic_write' flow-kit-bundle/hooks/` = 0 | ✅ |
| AC-12-b 五载体一致 | suite+anchor | check-gate-sync 双健康行（①skill 17 ②bats 17 ③js 17=权威 ⑤指南折算 17 ④值域 ⊇）；`test_gate_config_carriers.bats` 15 用例全绿（正向五载体一致 + 逐载体反向篡改转红） | ✅ |
| AC-12-c 读机器态 | ops | T05 严格谓词重算权威名单 5 文件（种子 11→5：误报 6 出局、漏报 0），逐位点显式处置；`skip "` 带原因计数 = 76 | ✅ |
| AC-12-d 递归同步 | anchor | `make check-test-sync` rc=0（含子目录） | ✅ |
| AC-12-e JS 单测 | anchor | `package-dsh-plugin.sh --check` rc=0，`node --test` 20/20 先行后退出（位置序 nt=233 < ck=183 不成立 → 重排后 nt<ck 判据绿） | ✅ |
| AC-12-f 战役解耦 | anchor | check-path-privacy 内 `health-fix-2026-09b` 硬编码 = 0（SELF_EXCLUDE 6→2） | ✅ |
| AC-12-g 解析收敛 | anchor | Makefile 手搓形态锚 = 0 + `flow-active-query` 引用 ≥1（实测 6）；白名单 427/427 | ✅ |
| AC-12-h/i skip+SHA | anchor | 显式 skip 带原因 = 76；`be138c0` 非注释命中 = 0；仓根 tarball = 0 | ✅ |
| AC-13 总门禁 | anchor | `make check` rc=0 全横幅（「✅ make check: 全部通过」，dist 重建后净跑）；@test = 1179 ≥ 1116（test/ 与 bundle/ 双侧一致） | ✅ |
| AC-14 反哺销账 | scheduled | 载体 = `.specs/STATE.md` 活跃段（报告不作销账载体）；按 DESIGN/TASK 归 **7-integration 反哺批**，本阶段不终判 | 🟡 排程内 |
| AC-15 结构层三件 | anchor | ① commit-protocol 双计数 comm=0 + 删表锚（正确路径 `flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md`）② 163 行复制段 comm=0 ③ `L2-first 契约未满足` 全仓 = 1 | ✅ |
| AC-16 C9 降级登记 | anchor | `.specs/STATE.md:73` C9 四项 + v2 承接 + 理由（grep 'C9' 命中含「降级」「v2」） | ✅ |
| AC-17 pre-push 换装 | suite | `test/test_pre_push_gate.bats`（裸仓并发双 dry-run 串行化，双 rc=0；A6 污染通路关闭） | ✅ |

### 1.2 UAT 脚本

无人工 UAT——全部 AC 均可机检（本 change 即门禁/测试基建自举），UAT 面由下列一次性运维操作替代并留痕于各 T-SUMMARY：

- **UAT-1 · 历史重写全链（AC-5）**：前置 = 净树 + bundle 备份 → 步骤 = filter-repo 替换 600 字面量 → reflog/gc → force push → 全新 clone 逐 blob 扫描 → 期望 = 0 命中 + 备份 verify rc=0 → 实际 = 通过（T16-SUMMARY，重写前 develop=534e3e8/main=9b5dda7 → 后 d6ca423/4c81c66）
- **UAT-2 · 本地对象库残留收口（AC-5 补充）**：前置 = T16 后全对象面扫出 46 行真名（10 对象）→ 步骤 = 取证定位（`--indexed-objects` 判别 → 链接工作树 `/tmp/p6d/v23base` 锚定）→ `git worktree remove --force` + reflog expire + gc → 期望 = 全对象面 0 → 实际 = 通过（对象数 6876→6866）
- **UAT-3 · 最小 PATH 遮蔽 fail-closed（AC-10②）**：前置 = 临时 bin 目录仅含 make/bash/find 等必需工具的符号链接、**不含 shellcheck**，PATH 只指该目录 → 步骤 = `make lint` → 期望 = rc≠0 且具名报文（非静默跳过） → 实际 = 通过（rc=2 + 「❌ shellcheck 不在场：lint fail-closed 转红（C10）」）。**方法学教训：PATH 前置空目录不构成遮蔽（原 PATH 仍可见 shellcheck）；单跑计数的 shim 必须拦截 `npx` 而非 `bats`（recipe 形态是 `npx bats`，npx 自行解析包不经 PATH 上的 bats）——两项均已按正确口径复测。**

### 1.3 覆盖率

无 `--coverage` 工具（Bash 项目）。替代口径：

- AC 覆盖：17/17 全部落证据（16 ✅ + AC-14 排程至 7-integration）
- 用例规模：@test 1116（基线）→ **1179**（+63，净增不减）
- 反向控制覆盖（「测试的测试」）：五载体逐载体篡改、prompt 小节删除转红、kill 注入、jq 遮蔽、shellcheck 遮蔽、RED 证明（git show 旧脚本恰红）

### 1.4 边界 / 错误路径用例

- **空 / 缺失**：jq 缺失（AC-8：三库顶层断言 exit 1/2 具名报文）；`.flow-active` 缺字段（flow-active-query rc=1 静默 / rc=2 fail-closed）；双候选库均缺（旧式安装单行警告 + exit 0 等价放行）
- **非法输入**：非法 JSON（AC-8：independent-review-gate :65 拆分两行 exit 2 具名报文）
- **中断 / 信号**：TERM/KILL 注入腿（AC-2：rc≠0 + 沙箱域零改动）
- **并发**：check-gate-sync 并发双跑逐 pid rc=0（AC-1）；裸仓并发双 dry-run 串行化（AC-17）；**本轮实战：make check 与 make test shim 并跑（bash-1606/1609）即并发回归的自发验证**
- **极端值**：251KB-294KB 大 IR 文件转义载荷（B2-R8 契约钉）；600 替换字面量全历史重写；554 commits 重写后 0 漂移

### 1.5 测试质量自检（6 维测试衰退风险）

> 未装 brooks-lint → AI 内置 T1~T6 快查。

**严重度统计**：

| 编号 | 测试衰退风险 | 命中文件数 | 严重度分布 |
|---|---|---|---|
| T1 | Test Obscurity 测试晦涩 | 0 | 🔴 0 / 🟡 0 / 🟢 0 |
| T2 | Test Brittleness 测试脆弱 | 0 | 🔴 0 / 🟡 0 / 🟢 0 |
| T3 | Test Duplication 测试重复 | 1 | 🔴 0 / 🟡 1 / 🟢 0 |
| T4 | Mock Abuse Mock 滥用 | 0 | 🔴 0 / 🟡 0 / 🟢 0 |
| T5 | Coverage Illusion 覆盖率幻觉 | 0（已修 1） | 🔴 0 / 🟡 0 / 🟢 0 |
| T6 | Architecture Mismatch 架构错配 | 0 | 🔴 0 / 🟡 0 / 🟢 0 |

**详细发现**：

```markdown
### 🟡 T3 · Test Duplication：第 4 个同构夹具生成器
**Symptom**：test/test_check_gate_sync.bats（FXC1，T03 新增）
**Source**：《Effective Software Testing》· 测试重复
**Consequence**：夹具演化时四处不同步（T03 执行时已自报）
**Remedy**：收敛为共享 helper——已登记 MINOR-DEFERRED 延后（非本 change 验收面）

### 🟢（已闭环）T5 · Coverage Illusion：行为断言标记虚挂
**Symptom**：test/test_l3_review_defects_2026_09.bats:756/:758（本轮 AC-9 机检锚抓出）
**Source**：《xUnit Test Patterns》· 覆盖率幻觉
**Consequence**：T10 提交信息自述「30 行为化 + 2 白名单」但标记从未落行——若机检锚不严，AC-9 将空转通过
**Remedy**：两行补 `# 行为断言（契约钉…）` 行内标记（双份镜像同步），锚复跑 = 0
```

**处理**：命中 1 项（T3 🟡）→ 已记 1.6 记事；未达 ≥3 门槛。

### 1.6 测试质量记事（backlog）

| 文件 | 维度 | 严重度 | 计划修复时间 |
|---|---|---|---|
| `test/test_check_gate_sync.bats`（FXC1 第 4 同构夹具） | T3 | 🟡 | MINOR-DEFERRED（下轮 change） |

**本轮实战发现（非 6 维框架内，TEST 第 1 轮红→绿）**：

- **F-1（AC-9）**：机检锚首跑 = 2 ≠ 0——`test/test_l3_review_defects_2026_09.bats:756/:758`（B2-R8 契约钉）缺 `# 行为断言` 行内标记。根因：T10 提交 b5d7587 自述落标但从未写入；TASK 版锚（过滤 hooks/lib/.sh）与 REQUIREMENT 版锚（全 test/*.bats）锚面不同未捕。修复：双份补标 + cmp 一致 + 锚复跑 0 + B2-R8 1/1 ok。**教训：跨载体锚面差异要在 TEST 阶段以最宽锚复跑全量。**
- **F-2（AC-5 补充）**：T16 重写后本地对象库存留 46 行真名（10 个预脱敏对象）——`git grep $(git rev-list --all)` 与远端全净但 `cat-file --batch-all-objects` 命中。根因：09b 时代调试链接工作树 `/tmp/p6d/v23base`（detached 2c0412a）锚定——`rev-list --indexed-objects` 遍历所有工作树索引、fsck/gc 视工作树 HEAD 为根，故 gc 不回收。修复：worktree remove --force + reflog expire + gc --prune=now → 全对象面 0。**教训：历史重写后必查 `git worktree list`（filter-repo 只重写 refs，不动工作树）。**

---

## 第 2 轮 · 性能测试

### 2.1 性能预算（CLI 门禁延迟，无 Web 预算）

```yaml
gates:
  check-gate-sync: < 2s        # 快门（开发循环内高频）
  check-skills-sync: < 2s
  check-flow-active-inline: < 2s
  check-path-privacy: < 10s    # 全仓扫描重门
  make_check_total: < 10min    # 全链（1179 用例 + 快门 + 镜像断言）
```

### 2.2 实测结果

| 指标 | 预算 | 实测 | 上版基线 | 判定 |
|---|---|---|---|---|
| check-gate-sync | < 2s | 0.30s | — | ✅ |
| check-skills-sync | < 2s | 0.16s | — | ✅ |
| check-flow-active-inline | < 2s | 0.52s | — | ✅ |
| check-path-privacy | < 10s | 4.30s | — | ✅ |
| make check 全链 | < 10min | 4m55s | 3m07s（首轮，含镜像红） | ✅ |

### 2.3 工具输出

```text
check-gate-sync: 0.30s / check-skills-sync: 0.16s / check-flow-active-inline: 0.52s / check-path-privacy: 4.30s
make check 全链: real 4m55.427s（user 1m59.754s / sys 1m28.745s，dist 重建后净跑 rc=0；首轮 3m07s 含一处镜像红）
（/usr/bin/time -f "%es" 快门单跑 + bash time 全链，2026-10-01）
```

### 2.4 退步项处理

无退步项。

---

## 第 3 轮 · 安全测试

### 3.1 依赖漏洞

无 npm 运行时依赖（devDependency 仅 bats-core 经 npx）；`npm audit` 不适用。Bash 侧无依赖清单。

### 3.2 秘钥扫描

trufflehog 未安装；以本 change 特设的**真名隐私四层扫描**替代（强度高于通用秘钥扫描——目标字面量已知）：

| 层 | 命令口径 | 结果 |
|---|---|---|
| tracked 工作树 | check-path-privacy 门禁（PAT 域） | 0 ✅ |
| 可达历史 | `git grep -F "$HOME" $(git rev-list --all)` | 0 ✅ |
| 全对象库 | `git cat-file --batch-all-objects`（blob 面） | 0 ✅（本轮收口后，原 46） |
| 远端 | T16 全新 clone 双分支逐 blob | 0 ✅ |

- 已 rotate：N/A（泄漏面为路径真名而非凭据；历史重写即处置）
- 备份：`../backup-pre-scrub-20260929.bundle`（16.3MB，verify rc=0，含重写前全历史）

### 3.3 SAST

shellcheck 0.9.0 经 `make lint`（-S error，rc 判红，缺工具 fail-closed——AC-10② 已验证）全绿。

### 3.4 OWASP Top 10

| 项 | 状态 | 备注 |
|---|---|---|
| A01 越权 | N/A | 本地门禁无鉴权面 |
| A02 加密失败 | N/A | 无加密面 |
| A03 注入 | ✅ | jq 断言 fail-closed（非法 JSON/缺 jq exit 2） |
| A04 不安全设计 | ✅ | fail-closed 哲学贯通（C12） |
| A05 配置错误 | ✅ | 五载体预设一致性门禁（AC-12-b） |
| A06 漏洞组件 | ✅ | 见 3.1（无运行时依赖） |
| A07 鉴权 | N/A | |
| A08 数据完整性 | ✅ | 镜像三重断言（test/hooks/dist 零漂移）+ 并发闸 |
| A09 日志监控 | ✅ | fail-closed 具名报文三族 + 积压告警通道（AC-6） |
| A10 SSRF | N/A | 无网络面 |

---

## 第 4 轮 · 兼容性测试

### 4.1 跨浏览器（Web）

N/A（CLI）。

### 4.2 视口

N/A。

### 4.3 数据迁移（涉及 schema 变更必填）

git 历史重写（不可逆操作带备份判据）：

- [x] 生产数据快照预演通过 → bundle create --all 16,323,982 bytes + verify rc=0
- [x] 实测耗时：重写 554 commits（单次全 refs，秒级）+ clone 逐 blob 扫描
- [x] 回滚脚本就位且测过 → 备份 bundle 保留 + verify 复跑 rc=0（本轮）
- [x] 灰度 / 双写方案验证通过 → N/A（一次性重写，远端 force push 后全新 clone 验证）

### 4.4 跨版本

- [x] node --test 20/20（JS 状态机四件 *.test.mjs 经 `--check` 入链，AC-12-e）
- [x] bash/bats 套件自证（1179 用例跨 `test/` 与 `flow-kit-bundle/test/` 双侧一致）
- [x] dist 镜像零漂移（check-dist；package-dsh-plugin.sh --check rc=0）

---

## 第 5 轮 · 可观测性验证

### 5.1 日志

- [x] 关键路径有 log → fail-closed 具名报文三族：jq 缺失 / 非法 JSON / `.flow-active` 状态不可判（`[auto-checkpoint]` 前缀）
- [x] grep 验证不含 PII → 报文均占位符形态（`/home/<acct>`、`<redacted>`），第 3 轮四层扫描覆盖
- [x] 错误日志上下文充分 → 具名报文含脚本名 + 阶段 + 处置指引（如「旧式安装单行警告」）
- trace-id / 结构化 JSON：N/A（stderr 即 CLI 日志面）

### 5.2 指标

- [x] 门禁健康行：check-gate-sync 双行（34 对载体 + 五载体逐项计数 17）可 grep
- RED/USE：N/A（非服务）

### 5.3 链路追踪

N/A（单机门禁链，Makefile 目标名即「trace」）。

### 5.4 告警 + 健康检查

- [x] 关键失败有告警 → L3 积压告警（AC-6：module_output "warning" 通道 + 首败记录 + return 透传，4/4 用例含 RED 证明）
- [x] 无噪音告警 → 告警仅挂首败（bl_fail_rc 首败记录），不重复刷屏
- runbook / health 端点：N/A

---

## 新增测试登记

| 用例文件 | 类型 | 覆盖 AC | 所属轮次 |
|---|---|---|---|
| `test/test_fail_closed.bats`（8 用例） | unit | AC-8 | 1 |
| `test/test_l3_backlog_alarm.bats`（4 用例） | integration | AC-6 | 1 |
| `test/test_makefile_gates.bats`（2 用例） | unit | AC-10 | 1 |
| `test/test_gate_config_carriers.bats`（15 用例） | unit+反向 | AC-12-b | 1 |
| `test/test_skills_sync.bats` | unit+反向 | AC-11 | 1 |
| `test/test_check_gate_sync.bats` +2 腿（16→18：T03 +1 / 后续波次连带 +1） | unit+并发 | AC-1/2 | 1 |
| `test/test_path_privacy_gate.bats` 35→39（+4 `T04:` 前缀） | unit | AC-3/4 | 1 |
| `test/test_pre_push_gate.bats`（并发双 dry-run） | integration | AC-17 | 1 |
| `test/test_flow_active_query.bats`（14 用例） | unit | AC-12-g | 1 |
| 存量文件增腿（auto_checkpoint 13 / l3_review_defects 行为断言化 +63 净增） | 回归 | AC-9 等 | 1 |

## 回归保护

本次变更可能影响的旧功能：

- 全量 bats 套件（基线 1116）→ **1179/1179 全绿**（W1 波间曾出现 5 例镜像族失败 → 重建 dist + hooks-sync 后闭环，教训已入 LESSONS 候选）
- 镜像三重一致性（test/ ↔ bundle/test/ ↔ dist/）→ check-test-sync / check-hooks-sync / check-dist 全 rc=0
- 用户级安装面（`~/.claude/hooks`）→ T13 移交项：无 lib/ 兄弟目录时走旧式安装等价放行腿（= 原非管辖语义，登记 7-integration 复核）
- git 历史/远端 → 重写后 SHA 对照表 + 备份 bundle verify（见 4.3）

对应已有测试是否仍通过：✅（1179/1179 + `make check` 全链 rc=0 全横幅）
