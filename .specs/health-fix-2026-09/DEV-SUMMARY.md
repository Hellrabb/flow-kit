# DEV-SUMMARY — health-fix-2026-09（阶段 4 汇总）

- **Change ID**: health-fix-2026-09
- **阶段**: 4-dev（T00 → T07）
- **完成时间**: 2026-09-20

---

## 交付物总览

| Task | 交付 | verify | 状态 |
|---|---|---|---|
| T00 | dist 重建（AC-2 的 Given） | 6 组映射 diff 全 0 | ✅ |
| T01 | `package-dsh-plugin.sh --check`（只读新鲜度） | 正向/负向/未知参数/无参回归 全过 | ✅ |
| T02 | `Makefile`：lint find 全量枚举 + `SCANNED_FILES` + `check-dist` 挂载 | 66 文件覆盖 7 个漏扫 · 契约 66=66 · 6 门 | ✅ |
| T03 | `sync-hooks.sh`：exec 判据收窄为真入口 + 逐条指名 | AC-5 计数 0 · AC-6 四类真入口均指名 | ✅ |
| T04 | 9 个验证夹具落盘（原样提取自 REQUIREMENT） | 9/9 语法 + **9/9 实跑 PASS** | ✅ |
| T05 | `verify-claims.sh` F6 深层修复（活跃 change 解析 + 工作区基线） | rc=0 · 13✅/0❌ · 门数动态跟随 | ✅ |
| T06 | 三载体理由注释（`health-fix-2026-09` 锚点 + 理由关键词） | 3/3 锚点 + 3/3 语义 | ✅ |
| T07 | 全量回归取证（本文件） | 见下 | ✅ |

**改动文件（4 个生产文件，0 越界）**：`package-dsh-plugin.sh` · `Makefile` · `sync-hooks.sh` · `verify-claims.sh`

---

## AC-7 六项回归（实测原始结果）

| # | 断言 | 实测 |
|---|---|---|
| ① | `make test`：950 ok / 0 not ok / 1 skip | **ok=950 not_ok=0 skip=1** ✅ |
| ② | `make lint`：error 级 0 | rc=0 ✅ |
| ③ | `make check-validate`：漏配 0 / 源缺失 0 | ✅ |
| ④ | `make check-test-sync`：双源一致 | ✅ |
| ⑤ | `make check-hooks-sync`：漂移 0 | ✅ |
| ⑥ | `make verify-claims`：13 ✅ / 0 ❌ | rc=0 · 13/0 ✅ |
| 附 | `make check-dist`（本 change 新增第 6 门） | dist 与源一致 ✅ |

**`make check` 整体**：`rc=0` · **全部通过（6 门）** · 实测耗时 **4m12s**
（新增 check-dist 未造成可感知负担 —— NFR「≤2s」**实测 0.61s**；设计期曾估 13ms，**为低估**，见 TEST.md §2）

---

## 验证夹具实跑结果（T04 / AC-8）

| 夹具 | 结果 |
|---|---|
| `ac1.sh` | ✅ AC-1 PASS（改源不重建 → `make check` 变红并指名） |
| `ac2.sh` | ✅ AC-2 PASS（dist 一致时放行，反例保护） |
| `ac3.sh` | ✅ AC-3 PASS（`install.sh` 注入语法错误 → `make lint` 抓到） |
| `ac4.sh` | ✅ AC-4 PASS（`make lint` 自报清单覆盖率 100%） |
| `ac4c.sh` | ✅ AC-4c PASS（扫描集 ∪ 契约排除集 == 全仓集） |
| `ac5.sh` | ✅ AC-5 PASS（exit 0 且 0 处告警） |
| `ac6.sh` | ✅ AC-6 PASS（真入口检出并指名） |
| `ac7.sh` | ✅（六项回归，见上表） |
| `ac9.sh` | ✅ AC-9 PASS（三载体可追溯理由注释） |

**AC-8 卫生**：全部夹具实跑后 `git status --porcelain` **无新增残留** ✅（还原均用 `git checkout` / `chmod`，未污染工作区）

---

## 实现期发现并修掉的两个真 bug（如实登记）

### 1. `is_real_entry` 的 bash glob 跨 `/` 陷阱（T03 内修）

首版判据写 `case "$1" in stop/*.sh|…)` —— **bash glob 的 `*` 会跨 `/`**，于是 `stop/*.sh` 把 `stop/lib/common.sh` 也匹配成"入口"。
**实测症状**：告警计数从 5 暴涨到 **108**。
**修法**：先排除三层路径（`*/*/*`）再匹配。
**教训**：路径 glob 判据必须显式处理层级，不能依赖 `*` 的直觉语义。

### 2. `verify-claims.sh` §10c 的"对比基线写死"（T05 内修 —— F6 的更深两层）

| 层 | 缺陷 | 后果 |
|---|---|---|
| 1 | 三处路径硬编码已归档 change（阶段 1 已修） | 归档后引用落空 |
| **2** | 解析到**已归档**的 `l3-review-defects-2026-09/DESIGN.md`，却比**任何新 change** 的被改文件 | §10c **结构上永不可能通过** |
| **3** | 对比基线 `git diff 19b3463 HEAD` 中 **19b3463 是旧 change 起点** | 把上个 change 的全部被改文件也算进来 |

**修法**：① 按 `.flow-active` 的 `change_id` 解析**活跃 change** 的工件；② 基线改为**本 change 的工作区改动**（`git diff HEAD` + staged + untracked）。
**结论**：`verify-claims.sh` 原先不只**路径**写死，**语义**（"用哪个 change 的工件""基线从哪算"）也写死 —— 只修路径不够。已写入 LESSONS。

---

## 破坏性变更（R4.6 / 1.8）

**未命中**（三条判据逐项核对）：
- 无删除既有代码 ≥5 行（`sync-hooks.sh` 判据收窄属行为修正；`verify-claims.sh` 为新增辅助函数 + 改基线来源）
- 无公共导出签名变更（`resolve_spec_artifact` 签名不变；`check_dist` / `is_real_entry` 为脚本内新增）
- 无文件删除、无重命名导出

## 沿用既有抽象（R6.4）

`cmp -s` 沿用 `sync-hooks.sh:180/225/290` · 反向残留语义沿用 `sync-hooks.sh` orphan 检测 · 工具缺失优雅降级沿用 `Makefile` 的 jscpd 处理 · 输出前缀沿用 `✅/⚠️/❌` 体例 · **零新依赖**

## 越界检查（R6.5）

```
各 task write_files：
  T00 dist/**            → dist 重建（.gitignore 覆盖，无 git 可见改动）✅
  T01 package-dsh-plugin.sh → ✅
  T02 Makefile              → ✅
  T03 sync-hooks.sh         → ✅
  T04 .specs/…/verify/      → ✅
  T05 verify-claims.sh      → ✅
  T06 三载体（Makefile/sync-hooks.sh/package-dsh-plugin.sh）→ ✅（同 T01/T02/T03 文件，属预期）
  T07 .specs/…/DEV-SUMMARY.md → ✅
→ 生产文件改动 4/4 均在 write_files 内，**0 越界**
→ .specs/CONTEXT.md、.specs/LESSONS.md 属 M-health 巡检（本 change 之前），未回滚
```

## 是否触发新 fix-plan

**否**。两条实现期发现均在本 change 内闭环。
