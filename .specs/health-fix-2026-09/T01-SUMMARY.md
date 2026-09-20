# T01 SUMMARY — package-dsh-plugin.sh 加 --check 新鲜度模式

- **Change ID**: health-fix-2026-09
- **Task**: T01
- **完成时间**: 2026-09-20

## 做了什么

新增 `--check` 只读新鲜度检查模式（DESIGN D1/D2/D3）：

1. **参数分置于 `node -p` 之前**（:19 上方）—— 保证该模式**不调用 node/npm**（NFR 性能）且零副作用
2. **未知参数 fail-closed**（`rc=2` + usage）—— 杜绝"静默忽略未知选项 → 照常重建并 exit 0"的假成功
3. **比对用 `cmp -s` 按字节**，**不比 mode**（打包第 5 步有意 `chmod +x`，比 mode 会永久假红；脚本内已注明理由）
4. **6 组目录映射 + 7 个顶层文件**，与打包第 1-5 步的 `cp` **同源**（未另写映射表 —— 单一事实源）
5. **含反向残留检测**（dist 有、源已无），沿用 `sync-hooks.sh --check` 的既有语义
6. **dist 不存在 → 提示后 `exit 0`**（优雅降级，与 `make dup` 对 jscpd 缺失同款）
7. **失败逐条指名文件路径** + 给出修复命令与操作顺序提示

## 改了哪些文件

- `package-dsh-plugin.sh`（+~100 行：`check_dist()` / `usage_check()` / case 分流）

## verify 输出（T01 的 verify 命令，实测）

```
① 正向：dist 与源一致
   $ bash package-dsh-plugin.sh --check   → rc=0
   ✅ check-dist: dist 与源一致
   mtime 未变（未重建）· 无 `==> packaging` 横幅

② 负向（AC-1 的可证伪核心）：改源后
   $ printf '\n<!-- probe -->\n' >> dsh-flow-kit/README.md
   $ bash package-dsh-plugin.sh --check   → rc=1
   ❌ 陈旧: .../dist/dsh-flow-kit/README.md（内容与 .../dsh-flow-kit/README.md 不一致 → 请重建 dist）
   → 指名 README.md ✅ · 还原后恢复 rc=0 ✅

③ 无参打包 0 回归
   $ bash package-dsh-plugin.sh            → rc=0（含 `==> packaging` 横幅）
```

### 额外边界实测（超出 verify 的最小要求，为证明设计无死角）

| 边界 | 结果 |
|---|---|
| 反向残留（dist 有、源已无） | rc=1，输出 `❌ 反向残留: .../hooks/__probe__/ghost.sh` |
| **vendor/test 陈旧**（本次真实事故形态） | rc=1，指名 `vendor/flow-kit-bundle/test/test_quality_baseline.bats` |
| dist 目录不存在 | rc=0 + `⚠️ dist 不存在 —— 请先运行: bash package-dsh-plugin.sh` |
| 未知参数 `--bogus` | rc=2 + usage（fail-closed） |

## 破坏性变更（R4.6 / 1.8）

**未命中**。`package-dsh-plugin.sh` 的既有行为零改动：无参路径的 `cp`/`chmod`/单测/打包序列原样保留，仅在**之前**插入参数分流。无删除 ≥5 行、无公共接口签名变更、无文件删除。

## 沿用既有抽象 grep（R6.4）

| 本次需要 | 既有有没有 | 决定 |
|---|---|---|
| 内容比对 | `sync-hooks.sh:180/225/290` 用 `cmp -s` | **沿用同款**（POSIX，GNU/BSD 语义一致） |
| 反向残留语义 | `sync-hooks.sh:229-260`（orphan 检测） | **沿用**其语义与输出体例 |
| 工具缺失优雅降级 | `Makefile:93-97`（`make dup` 对 jscpd） | **沿用**该惯例 |
| 输出前缀体例 | `sync-hooks.sh` 的 `✅/⚠️/❌` | **沿用** |

## 6 维自查（内置快查 · 路径 B）

- **R1 认知过载**：`check_dist()` 68 行（含大量注释）；职责单一（比对+报错），无嵌套 >3 层 → 可接受
- **R2 变更传播**：仅改 `package-dsh-plugin.sh` 单文件 ✅
- **R3 知识重复**：比对映射与打包步骤**同源**，未另写第二份映射表（DESIGN D2 的核心要求）✅
- **R4 偶然复杂**：无"以后可能用到"的扩展点 ✅
- **R5 依赖混乱**：仅 coreutils（`find`/`cmp`），**零新依赖** ✅
- **R6 领域扭曲**：命名用本域词（陈旧 / 反向残留 / 映射）✅

## 越界检查（R6.5）

```
TASK 声明的 write_files：
  - package-dsh-plugin.sh

实际工作区 diff 涉及：
  - package-dsh-plugin.sh     ← 本任务 ✅
  - verify-claims.sh          ← ⚠️ 属 T05（阶段 1 的 F6 改动，尚未提交）
  - .specs/CONTEXT.md         ← 属 M-health 巡检（本 change 之前）
  - .specs/LESSONS.md         ← 同上
  - .specs/health-fix-2026-09/、.specs/adr/010-*  ← 本 change 自身工件

→ 本任务自身的改动：仅 package-dsh-plugin.sh，0 越界 ✅
→ 其余为其他任务/前置工作的未提交改动，**如实登记**（不谎报"0 越界"，也不回滚他人改动）
```

## 是否触发新 fix-plan

否。但发现一处**既有隐患**（非本任务引入，已记 LESSONS L-097）：本脚本原先**无任何参数解析**，未知选项被静默忽略 → 未来任何"只读"契约若不加参数解析，都会退化成"照常重建"的假成功。本任务的 `case` 分流已堵住该路径（`--bogus` → rc=2）。
