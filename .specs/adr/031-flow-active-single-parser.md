# ADR-031: .flow-active 单一解析入口

- **状态**: Proposed（随 health-fix-2026-09c 落地后 Accepted）
- **日期**: 2026-09-29
- **关联**: health-fix-2026-09c DESIGN D3（C14-g）· ARCHITECTURE.md §4.1

## 背景

`.flow-active` 是 pipeline 状态的唯一真源（goal/phase/gates），但全仓 28 个文件各自内联 `jq … .flow-active` 解析（2026-09-29 巡检 C14-g 实测）。另有 **`Makefile:250-253` 手搓 bash 解析**（while/read/case 提取 change_id，无 jq）——与内联 jq 同属「schema 知识内联」，且不走 jq 的检测 grep 永远看不见它。多源解析的代价：schema 变更（如新增字段/改键名）须同步全部位点，漏改即静默漂移；且各处错误处理不一（多数 fail-open）。

> 检测谓词因此定为「**任何读取 .flow-active 的解析代码**」（jq 内联 ∨ bash 手搓），不认实现语言。

## 决策

1. 新建 `flow-kit-bundle/lib/flow-active-query.sh` 作为**唯一**只读解析入口：`flow-active-query.sh <jq-path>`，jq 包装，fail-closed（rc：0=正常 / 1=字段缺失或检查失败 / 2=依赖缺失或 .flow-active 非法）。
2. 白名单文件化：既有内联解析以白名单文件登记，**常设路径 `flow-kit-bundle/flow-kit/reference/flow-active-inline-whitelist.txt`**（读序沿用 ADR-028：常设 > per-change 种子 > 双缺 fail-closed；per-change 目录随归档失效，09b 已实证学费）。严格谓词与条目格式见 DESIGN 附录 A（AC-12g 定稿义务：每条附理由行）。v1 收敛「无借口」文件（新代码、非 vendor、非镜像，**含 `Makefile:250-253` 手搓解析改调入口**），计数门禁**只减不增**。计数基线在 TASK 以 DESIGN 附录 A 严格谓词重建（巡检的宽松 grep=43 含镜像/注释误配，28 为巡检人工判读数，均不可直接作机器基线）。
3. 新增代码一律经该入口；白名单外新内联解析 → make check 转红。
4. **JS 域立场（L2 重审 R3 · 2026-09-29）**：`dsh-flow-kit/` JS 解析器**入域不豁免**——检测谓词含 JS 等价分支（DESIGN 附录 A 分支 ④ 与 `.flow-active` JS 命中）；存量三文件（index.js / flow-state.js / l2-review.js）登记白名单，理由行注明替代闸（gate_config 预设名五载体集合比对，DESIGN §9.3）；新增 JS 内联解析同样须登记。长期整改 = hook-bridge 子进程调 flow-active-query.sh（TD 跟踪，v2）。

## 备选与理由

- **解析函数进 common.sh**：common.sh 是 Stop hook 链热路径，塞 CLI 入口扩大 hook 依赖面（hook 链 NFR <5s）。
- **维持现状 + 文档约定**：无门禁的约定已实证会漂移（28 处即证据）。

## 后果

- 正面：schema 变更单点收敛；fail-closed 语义统一（与 ADR-032 对齐）。
- 负面：多一层脚本间接（调用开销可忽略）；白名单残余是显式债务（TD 跟踪至 v2 收口）。
- 推翻代价：低-中（入口保留但降级为可选；白名单门禁删除）。
