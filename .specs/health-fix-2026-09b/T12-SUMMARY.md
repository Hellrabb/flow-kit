# T12-SUMMARY — `sync-hooks.sh` 四处登记 `pre-push`（真实条目 + entry-class 白名单 + 收集 + orphan 反向扫描）

- **task id**: T12 · **change**: `health-fix-2026-09b` · 阶段 4（DEV）
- **产品文件**：`sync-hooks.sh`（唯一产品文件；`TASK.md` 的 `<write_files>` 仅此一个）
- **提交**：`9933c35`（sync-hooks.sh 原子提交，单独含产品文件，6+/5-，0 越界）
- **状态**：DONE（产品实现 + 门禁全绿；verify 两条 `--list` 断言为工件缺陷，上报裁决）

## 一、实现：四处登记（对 `<action>` 的逐条落实）

在 `sync-hooks.sh` 中把 `pre-push/pre-push.sh` 登记为真实条目并纳入镜像面，**四处缺一不可**：

| # | 点 | 改动 | 行为面 |
|---|----|------|--------|
| ① | `:82 is_real_entry` | `stop/*.sh\|session-start/*.sh\|pre-commit/*.sh\|pre-push/*.sh) return 0 ;;` | 判定为真实条目 |
| ② | `:95 --entry-class` 白名单 + `:97` 错误文案 | 白名单补 `pre-push/*`；报错文案尾缀补 ` · pre-push/` | 前缀不再被判「无法识别的相对路径」（rc=2 → rc=0） |
| ③ | `:137 collect_rel_paths` | `[ -f "$SRC/pre-push/pre-push.sh" ] && printf 'pre-push/pre-push.sh\n'` | 进入镜像正向收集面 |
| ④ | orphan 反向扫描：`:284` `_d` 目录表 + `:290` `$_rel` case 白名单 | `_d` 补 `pre-push`；case 补 `pre-push/*.sh` | **源已删/改名而副本仍在 ⇒ 可被检出**（漏登 = 漏检） |

**关键过程发现**（对应 DESIGN D3 item 7 的「漏检」提示）：第一次编辑只把 `pre-push` 加进 orphan 的 `_d` 目录表（:284），**未同步** case `$_rel` 白名单（:290）⇒ orphan 探针落在 `pre-push/z12-probe.sh` 时命中 `*) continue` 被**静默跳过**，`--check --strict-orphans` 仍 rc=0。这正是 D3 所述「漏检」现场。补上 `:290` 的 `pre-push/*.sh` 后，反向检出恢复正常（见「双态对照」）。—— **orphan 反向扫描是 :283**/**:289 整体，两处必须同改**，为本 task 的核心教训。

**未改动** `--check`/`--list` 只读语义（:164 前）；`mapfile`×3 维持 TD-035 known-acceptable，**未新增**任何 bash4/GNU-only 构造（bash 3.2 / macOS 兼容保持）。

## 二、verify 逐条真实输出

**（判据修正后的工件 verify —— 见「判据修正（L-128）」段）** 从 `TASK.md` 工件重新抽取 verify 并原样执行：

```bash
flow-kit-bundle/flow-kit/scripts/task-brief .specs/health-fix-2026-09b/TASK.md T12 | \
  awk '/^  <verify>$/{f=1;next} /^  <\/verify>$/{f=0} f' > /tmp/t12v-artifact.sh &&
  bash -n /tmp/t12v-artifact.sh && bash /tmp/t12v-artifact.sh; echo "rc=$?"
```

真实输出（stdout，全部断言通过即 rc=0）：

```
entry: pre-push/pre-push.sh
rc=0
```

verify 内部对各关键环节做 `>/dev/null` 静默 + 失败分支 `exit 1`，故可见输出仅 `entry:`（`--entry-class` 的 stdout）与 `rc=0`。各子断言实况：`--entry-class pre-push/pre-push.sh` rc=0；`--check` rc=0（漂移 0）；`--list` 抽 6 个镜像根逐一 `pre-push/pre-push.sh` 在位；`镜像文件数 = 48`（评≥48）；orphan 双态 —— 探针 `$HOME/.claude/hooks/pre-push/zz-verify-orphan-probe.sh` 在位 ⇒ `--check --strict-orphans` rc=1 且报文指名该路径，移除 ⇒ `--check` rc=0；`trap` EXIT 保证清理。跑完 `ls ~/.claude/hooks/pre-push/` 仅剩 `pre-push.sh`，探针无残留。

**修正前的原判据（工件缺陷）真实输出**：测试脚本 `/tmp/t12v.sh` 实跑得 ——
- `bash sync-hooks.sh --entry-class pre-push/pre-push.sh` → rc=0（✅）
- `bash sync-hooks.sh --check` → rc=0（✅）
- `bash sync-hooks.sh --list \| grep -q 'pre-push'` → **❌ 不满足**（`--list` 输出无 `pre-push` 字符串）
- `[ "$(bash sync-hooks.sh --list \| grep -cE '✅')" -ge 7 ]` → **❌ 结构性不满足**（`--list` 只有 6 条 ✅，= 6 个 DEST_ROOT）

原后两条（`--list`）为**工件缺陷，非实现失败**：`--list` 语义是**逐 DEST_ROOT 枚举状态**（`✅`/`⚠️` per-root，共 6 个 DEST_ROOTS），`grep -cE '✅'` 恒为 **6** 与前置/后置一致 ⇒ `>=7` 结构上不可达；`--list` **不枚举镜像文件名**（只在 root 行下打印 prompts-tree `↳` 与 orphan `↳`），故 `grep -q 'pre-push'` 永假。真实清单文件枚举由 `collect_rel_paths`（:137 已含 pre-push）驱动，非 `--list` 职责。判据已由主 agent 依 L-128 改写并回写工件（见「判据修正（L-128）」段）。

## 三、双态对照（L-120）

夹具：镜像根 `~/.claude/hooks/pre-push/` 下放源树不存在的假文件 `z12-orphan-probe.sh`（用完即删）。

| 态 | 操作 | `bash sync-hooks.sh --check` | `--check --strict-orphans` |
|----|------|------------------------------|-----------------------------|
| (a) orphan 存在 | 写入探针 | rc=0（advisory ⚠️）+ 报文指名 `pre-push/z12-orphan-probe.sh` | **rc=1**（❌）+ 报文指名同一文件 |
| (b) orphan 清除 | 删除探针 | **rc=0**，`✅ hooks 副本一致（漂移 0）` | rc=0 |

两态结果**不同**（同一夹具正反两态），证明 orphan 反向扫描对 pre-push 真实有效，非恒真断言。（Builder 注意：B5-R5 期望**默认 advisory rc=0** —— 态 (a) 的 plain `--check` rc=0 正是该契约；`--strict-orphans` 才升级为失败，与测试一致。）

## 四、反向对照（L-123）：`--entry-class pre-push/pre-push.sh` rc=0 非恒真

`is_real_entry` 是**路径模式匹配**（非文件存在性校验），故同前缀下「不存在的文件路径」仍按模式判 entry（rc=0）—— 这是抽象语义（stub/shadow/verify 用 `--entry-class` 对**推断路径**分类），不是恒真缺陷。**真正证明非恒真**的是「未登记路径 / 库路径」：

```
entry: pre-push/pre-push.sh        rc=0   ← 登记后
❌ --entry-class: 无法识别的相对路径 foo/bar.sh（期望 stop/ · session-start/ · pre-commit/ · pre-tool-use/ · pre-push/ 前缀）   rc=2   ← 未知前缀（修复前 pre-push 同此态）
library: stop/lib/common.sh        rc=1   ← 三层以上 = 库
```

修前 post-push 基线：`pre-push/pre-push.sh` 正是 rc=2「无法识别的相对路径」。今 rc=0 对应登记生效；未知前缀 rc=2、库路径 rc=1 说明 rc=0 **非恒真**（若恒真则 `foo/bar.sh`、`stop/lib/common.sh` 也会得 rc=0）。

## 五、修复前 / 修复后（L-120 双态，三组数值）

| 判据 | 修复前 | 修复后 |
|------|--------|--------|
| `--entry-class pre-push/pre-push.sh` | **rc=2**（无法识别的相对路径） | **rc=0** |
| `--list \| grep -cE '✅'` | **6** | **6**（结构性恒定 = DEST_ROOT 数） |
| `bash sync-hooks.sh --check` | rc=0 | rc=0 |

## 六、门禁与套件

- `bash sync-hooks.sh`（同步）：`✅ 已同步 6 个文件`，pre-push 进入全部 6 个 DEST_ROOT。
- `make check-hooks-sync`：rc=0（`✅ hooks 副本一致（漂移 0）`）。
- `npx bats test/test_l3_review_defects_2026_09.bats`：B5-R1…B5-R5 全 `ok`（54-57、91），0 not-ok。
- `make test`：**973 ok / 0 not ok**（plan `1..973`）/ rc=0。973 与基线一致（本 task 未新增测试；行为面由 B5 组 + T16/T19 覆盖，见 §七）。
- `make lint`：rc=0（`✅ shellcheck: no errors found`）。
- `make check-test-sync`：rc=0（`✅ test 双源一致`）。
- **`make check-dist`：预期红**（遗留 8 条陈旧，全是 dist 重建缺口：`check-gate-sync.sh` ×2 + 6 个 test 文件，无一涉 `sync-hooks.sh`；本 task 未新增其失败项）。留给 T24 用 `bash package-dsh-plugin.sh` 收口，**不修**。

## 七、TDD 说明（如实声明）

本 task 的行为面**不是由 T12 自写的新测试**覆盖，而是由既有回归面覆盖：
- **B5 组**（`test_l3_review_defects_2026_09.bats` B5-R1…R5）：安装树同步契约 —— 尤其 B5-R2（`--check` rc=0 + `漂移 0`）与 **B5-R5**（反向残留检出：默认 advisory、`--strict-orphans` 升级失败）正是对 `:283/:289` orphan 扫描语义的回归断言；T12 使 pre-push 纳入该扫描面，B5-R5 对 pre-push 目录同样生效。
- **T16/T19**：pre-push 拦截器的部署（install_hooks.sh 部署面）与动态断言（被拒 ref 指名）。
- 门禁面：`make test` 973 全绿即覆盖本 task 改动不引入漂移/漏检（B5 组显式断言）。**未新增** task 本地单测是因为本 task 是「登记/接线」改动，行为由既有同步回归面承载（符合 flow-kit 不重复建测试的约定）。

## 八、越界检查（L-121 / DESIGN D10′ 边界）

`git show --numstat <commit>` 对本次产品提交统计：**0 越界** —— 提交仅含 `sync-hooks.sh`（产品文件），`<write_files>` 之外零改动（`test/**`、`flow-kit-bundle/**`、`Makefile`、`.git/hooks/**` 均未入库）。协议产物（T12-SUMMARY / MINOR-DEFERRED / TASK.md / `.flow-active`）按流程留在工作树由主 agent 统一核算提交，不混入本产品提交。

## 九、6 维自查结论

1. **判据触达（L-122）**：双态 orphan 探针真实落到 `:283/:289` 现场并正反两态区分 ✅
2. **命令 ≠ 断言（L-121）**：每条 verify 均带失败分支，空集/枚举条数显式断言 ✅（唯 `--list` 两条为工件缺陷，见 §二）
3. **双态对照（L-120）**：orphan 存在/清除两态 rc 不同、entry-class 修前/修后 rc 不同 ✅
4. **反向对照（L-123）**：`--entry-class` rc=0 非恒真（foo/bar rc=2、lib rc=1）✅
5. **判据锚定行级标签（L-125）**：四处登记锚定 :82/:95/:97/:137/:284/:290 行级标签，基于实现现实结论，非同形字面/脚手架假象 ✅
6. **禁止 `--no-verify`（L-126）**：未使用；pre-commit 门禁自然跑绿（make test/lint/check-test-sync/check-hooks-sync 全绿）✅

## 十、遗留项

- ~~`--list` 两条 verify 断言为工件缺陷~~ **已由主 agent 依 L-128 裁定并回写工件**：改判为「逐根 `pre-push/pre-push.sh` 在位 + `镜像文件数 ≥ 48` + orphan 双态」，评判记录见 `MINOR-DEFERRED.md`，本 task 已按新判据重新抽取实跑（§二）rc=0。
- `dist` 陈旧待到 T24 统一 `package-dsh-plugin.sh` 重建刷新。
- `MINOR-DEFERRED.md` 追加 T12 已知接受项（已追加：`--list` 判据陷阱 + orphan 反向扫描 :284/:290 成对改）。

## 十一、抽象 grep 结果（沿用）

`is_real_entry`/`collect_rel_paths`/orphan 反向扫描均为 `sync-hooks.sh` 内既有抽象，本次仅在其白名单/目录表中追加 `pre-push` 分支，**未新建抽象**、未触碰 `lib/l2-*.sh`、`l3-*.sh` 等分析链。

## 十二、判据修正（L-128）

**原判据为何不可满足（含实测数据）**：修正前 `TASK.md` T12 `<verify>` 末两条断言为 ——
`bash sync-hooks.sh --list | grep -q 'pre-push'` 与 `[ "$(bash sync-hooks.sh --list | grep -cE '✅')" -ge 7 ]`。
实测 `sync-hooks.sh --list` 输出：`镜像文件数: 48` + 6 条 `✅ <DEST_ROOT>` 状态行（每条下接 prompts-tree `↳` 行），
**从不打印镜像文件名**。故 `✅` 计数恒为 **6**（= DEST_ROOTS 数，与登记面无关）、`pre-push` 字面命中 **0** ⇒
第一条 `grep -q 'pre-push'` 永假、第二条 `>=7` 结构上恒不可达。这两条并非实现漏了一步 entry，而是判据把
`--list`（逐根状态面）误当作「镜像文件清单枚举面」—— 真实清单文件枚举由 `collect_rel_paths`（:137 已含 pre-push）承担，
`镜像文件数` 从 T05 基线的 **47** 增至 **48**（+pre-push/pre-push.sh）。

**本轮工艺失误（L-128 现场）**：我（执行者）在初次交付时**只在沙箱临时副本**（`/tmp/t12v.sh`）里观察到
`--list` 两条不满足，并据此得出「工件缺陷」结论，但**并未把改写后的判据回写工件本体 `TASK.md`**——这使工件的判据与
实跑的判据分叉。主 agent 独立复核确认两条断言确为工件缺陷后，**依 L-128 授权把 `TASK.md` 及其 `<done>` 一并改写回写**：
新判据改为 `--entry-class` rc=0 → `--check` rc=0 → 从 `--list` 抽 6 个 `✅` 根并**逐一断言 `$root/pre-push/pre-push.sh` 在位** →
`镜像文件数 ≥ 48`（T05 基线 47）→ **orphan 反向扫描双态**（探针在位 ⇒ `--strict-orphans` 必非 0 且报文指名；移除 ⇒ `--check` 必 0；`trap` 保证清理）。
本小结 §二 已贴**从工件重新抽取并原样执行**后的真实输出。

**整改（L-128 教训）**：判据改写必须落工件本体、同一提交内与实现一起回写，禁止只改运行副本——否则仓内判据与实跑判据分叉，事后无法从仓内复现。本条已同步到 `MINOR-DEFERRED.md` 的 T12 记录中。