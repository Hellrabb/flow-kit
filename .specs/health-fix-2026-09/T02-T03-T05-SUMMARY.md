# T02 / T03 / T05 SUMMARY — Makefile 门禁改造 · exec 判据收窄 · F6 回归守护

- **Change ID**: health-fix-2026-09
- **完成时间**: 2026-09-20

---

## T02 · Makefile：lint 全量枚举 + SCANNED_FILES + check-dist 挂载

### 做了什么

1. **`lint` 文件域改 `find` 全量枚举**（原手写 glob 漏 7 个生产脚本）—— 选 `find` 而非补 glob，因"补 glob 是打补丁，下次加目录仍漏"（判据过窄的复发模式）
2. **排除集提为具名变量 `SCAN_EXCLUDES`**（契约，定义在 REQUIREMENT AC-4b）
3. **固定输出 `SCANNED_FILES: <n>` + 逐行 `./` 前缀路径 + 空行结束**（AC-4 输出契约）
4. **保持 error 级门禁语义**（ADR-010 / D8）：扩面只让 warning 可见，不升级 fail
5. **新增 `check-dist` target**（薄壳调 `package-dsh-plugin.sh --check`）并挂进 `check:` → 第 6 门

### verify 输出（实测）

```
$ make lint
SCANNED_FILES: 66
./Makefile …（66 行）
✅ shellcheck: no errors found        rc=0

$ make -n check | grep -c check-dist  → 1（已挂载）
$ make check-dist → ✅ check-dist: dist 与源一致
```

| 断言 | 结果 |
|---|---|
| `make lint` rc=0（扩面不弄红） | ✅ |
| 输出契约：声明 n=66 == 实际路径行数 66 | ✅ |
| 7 个此前漏扫脚本全部在清单内 | ✅ 7/7 |

### AC-4c 验证（静默扩张检测 · 本任务新增判据的证明力实测）

```
扫描集 66 ∪ 契约排除集 187 == 全仓 .sh 253  → 缺口 0  ✅
负向实测：模拟漏扫 1 个文件 → 缺口 1，检出 flow-kit-bundle/lib/paths.sh  ✅ 有证明力
```

### 6 维自查

R1 ✅（`SCAN_EXCLUDES` 具名、recipe 单职责）· R2 ✅（仅 Makefile）· R3 ✅（排除集单一来源）· R4 ✅ · R5 ✅（零新依赖）· R6 ✅

---

## T03 · sync-hooks.sh：exec 判据收窄 + 逐条指名

### 做了什么

1. **判据收窄为「仅真入口」**：新增 `is_real_entry()` + 具名白名单 `PTU_ENTRIES`（3 个 pre-tool-use 入口）；`stop/lib/**` 等库移出判据域
2. **检出时逐条指名**：原实现**只在 `MODE=list` 打印文件名**，`--check` 只给聚合计数 → 维护者拿到"有 N 个入口缺 exec 位"却无法定位。现**所有模式**都打印具体路径
3. **维持 advisory（不升级 fail）**：DESIGN D5 —— 比对根含 `~/.claude/hooks` 等用户环境目录，升级会误红本仓 CI

### 🐛 实现中踩到并修正的一处真 bug（值得记账）

首版 `is_real_entry` 写成 `case "$1" in stop/*.sh|...)` —— **bash glob 的 `*` 会跨 `/`**，于是 `stop/*.sh` 把 `stop/lib/common.sh` 也匹配成"入口"，实测告警计数从 5 暴涨到 **108**。修正为先排除三层路径（`*/*/*`）再匹配。**教训**：路径 glob 判据必须显式处理层级，不能依赖 `*` 的直觉语义。

### verify 输出（实测）

| 断言 | 结果 |
|---|---|
| AC-5：健康态 `缺可执行位` 计数 = 0，rc=0 | ✅（原 5 处假告警**全部消失**） |
| AC-6：四类真入口逐个摘 exec 位 → 均**指名** | ✅ 4/4（pre-tool-use / stop 主模块 / session-start / pre-commit） |
| 反例保护：库文件摘 exec 位 → 不报警 | ✅（收窄正确，非"把检查删掉"） |

---

## T05 · verify-claims.sh：F6 回归守护

### 做了什么（本任务暴露并修掉了 F6 的**两层**更深缺陷）

| 层 | 缺陷 | 修法 |
|---|---|---|
| 1（阶段 1 已修） | 三处路径硬编码已归档 change | `resolve_spec_artifact()` live→archive 回退 |
| **2（本任务暴露）** | **解析到的是已归档的 `l3-review-defects-2026-09/DESIGN.md`**，却拿**任何新 change** 的被改文件去比 → §10c **结构上永远不可能通过** | 改为按 `.flow-active` 的 `change_id` 解析**当前活跃 change** 的工件 |
| **3（本任务暴露）** | §10c 的对比基线 `git diff 19b3463 HEAD` 里 **19b3463 是旧 change 的起点**，把上个 change 的全部被改文件也算了进来 | 改为「本 change 的**工作区改动**」（`git diff HEAD` + staged + untracked）—— 正是 §0.5.1 的本意 |

**共性根因**：`verify-claims.sh` 原先**不只路径写死，语义也写死**在 `l3-review-defects-2026-09` 上（"用哪个 change 的工件""对比基线从哪算"两处都固定）。只修路径不够 —— 本任务证明了这一点。

### verify 输出（实测）

```
$ bash verify-claims.sh   → rc=0
  ✅ 被改的 4 个脚本/bats 均在 §0.5.1 出现
  ✅ make check 6 门全绿          ← 门数动态跟随 T02 新增的 check-dist
  复验结果: ✅ 13  ❌ 0        ← 该时点（阶段4）真实输出；阶段6 新增 §10d 后为 14，见 TEST.md
```

---

## 越界检查（R6.5）

```
T02 write_files: Makefile                     → 实际改动 ✅
T03 write_files: sync-hooks.sh                → 实际改动 ✅
T05 write_files: verify-claims.sh             → 实际改动 ✅
（T01 write_files: package-dsh-plugin.sh      → 实际改动 ✅）

实际工作区生产文件改动：Makefile / package-dsh-plugin.sh / sync-hooks.sh / verify-claims.sh
→ 4/4 均在对应 task 的 write_files 内，**0 越界** ✅
另：.specs/CONTEXT.md、.specs/LESSONS.md 属 M-health 巡检（本 change 之前），未回滚他人改动
```

## 破坏性变更（R4.6 / 1.8）

**未命中**：
- `sync-hooks.sh`：判据收窄属**行为修正**（消除假告警），非删代码 ≥5 行、非公共接口签名变更
- `Makefile`：`lint` 文件域扩大 + 新增 target；既有 target 语义不变
- `verify-claims.sh`：`resolve_spec_artifact` 签名不变（新增 `_resolve_artifact_for` / `_active_change_id` 两个内部辅助函数）

## AC-7 全量回归（实测）

| 门 | 结果 |
|---|---|
| `make test` | **950 ok / 0 not ok / 1 skip** ✅ |
| `make lint` | error 级 0 ✅ |
| `make check-validate` | 漏配 0 / 源缺失 0 ✅ |
| `make check-test-sync` | 双源一致 ✅ |
| `make check-hooks-sync` | 漂移 0 ✅ |
| `make check-dist`（新增） | dist 与源一致 ✅ |
| `verify-claims` | 13 ✅ / 0 ❌ ✅ |

**`make check` 整体：rc=0 · 全部通过（6 门）· 4m12s**

## 是否触发新 fix-plan

**否**。但记账两条实现期发现（均已修，非遗留）：
1. `is_real_entry` 的 glob 跨 `/` 陷阱（T03 内已修）
2. `verify-claims.sh` §10c 的"对比基线写死"（T05 内已修）—— 这条揭示 F6 只修路径是不够的，已写入 LESSONS
