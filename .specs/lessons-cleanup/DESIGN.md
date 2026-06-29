# DESIGN: 消除 LESSONS.md 三条活跃技术债

- **Change ID**: `lessons-cleanup`
- **关联**: `@.specs/lessons-cleanup/REQUIREMENT.md`、`@.specs/CONTEXT.md`、`@.specs/LESSONS.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 纯 CLI / Bash 项目，跳过技术栈卡片选择（符合 2-design 步骤 0 例外规则）。

- **语言/运行时**: Bash 4.0+（`set -euo pipefail`）
- **测试**: bats-core 1.13.0（npx）
- **关键依赖**: jq 1.6+、git、grep、find、diff
- **理由**: 与项目既有技术栈一致（CONTEXT.md 已锁决策），不引入新依赖
- **明确排除**: Python/Node.js 辅助脚本（项目是纯 Bash 分发仓库，引入新运行时破坏"零依赖安装"哲学）

---

## 0.5 既有架构对齐（brownfield · 来自 grep 实际文件）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep 出来的实际清单）：
- flow-kit-bundle/flow-kit/prompts/7-integration.md（L-013：归档流程 §5 "归档 ARCHIVE" 段）
- flow-kit-bundle/skills/flow-integration/SKILL.md（L-013：skill 入口的归档协议）
- package-flow-kit.sh（L-012：Part A~G 的 cp/rsync/mkdir staging 指令）
- flow-kit-bundle/flow-kit/prompts/4-dev.md（L-010：§1.8 破坏性变更协议，含 1.8.1~1.8.6）
- flow-kit-bundle/skills/flow-dev/SKILL.md（L-010：skill 入口的 1.8 协议段，需同步）

新增模块（本 change 产出）：
- package-flow-kit.sh 内新增 --validate 模式（函数级新增，不拆新文件）
- flow-kit-bundle/lib/archive-check.sh（L-013 归档校验函数，可选抽取）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/flow-kit/GO.md（核心路由逻辑，与本次无关）
- flow-kit-bundle/lib/install_*.sh（安装逻辑，与本次无关）
- flow-kit-bundle/hooks/stop/（stop 链，与本次无关）
- .specs/CONTEXT.md § 禁动清单 段（不在本次修改范围）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 归档后清理工作目录 | 无——当前 `mv .specs/<id>/ → archive/` 后不删源 | 新增：归档完成确认后 `rm -rf .specs/<id>/` |
| 扫描未归档已完成 change | 无——当前无扫描逻辑 | 新增：归档后 grep `.specs/` 下非 archive 目录的 REVIEW✅ + TASK done |
| 打包 staging 覆盖校验 | 无——当前无校验 | 新增：解析 Part A~G cp/rsync 指令 → diff 实际目录树 |
| 1.8 后跑 bats | 无——当前 1.8.4 是手动提示 | 增强：在 1.8.4 段加自动 bats 执行 + 失败阻断 |
| 错误处理 | `set -euo pipefail`（项目基线） | 沿用 |
| jq 操作 .flow-active | `common.sh` 的 `fk_flow_field` 等函数 | 沿用（校验脚本不依赖 flow-active，不引用） |

### 0.5.3 沿用模式 vs 引入新模式

```
- 错误处理：**沿用** set -euo pipefail + exit code（0=通过, 1=校验失败, 2=脚本错误）
- 命令行接口：**沿用** package-flow-kit.sh 的 flag 风格（--validate 新 flag）
- prompt 协议段：**沿用** 现有的编号段落结构（7-integration §5 / 4-dev §1.8），加子段不改结构
- 归档校验：**引入新函数** → 理由：既有归档流程无校验逻辑，归档完成后插入新步骤
- 打包校验：**引入新函数** → 理由：既有打包脚本无校验模式，需新增完整解析+对账逻辑
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **L-013 归档清理在 7-integration prompt 内实现**（纯 prompt 指令，不额外写 bash 脚本） | 抽取独立 `archive-check.sh` 脚本 | prompt 指令改动面小（只改一段），AI 执行时直接按指令操作；独立脚本需要维护 + 测试 + 打包同步，overhead 大 | AI 弱模型可能不严格按 prompt 执行清理——L3 证据链 + PCSC 自检兜底 |
| D2 | **L-013 扫描触发时机：归档完成时**（不额外 cron/独立命令） | 独立 `make scan-orphans` target | 归档完成是自然触发点，不增加用户操作负担；Q1 已确认 | 如果长时间不归档，孤儿 change 积累——v2 可加独立扫描 |
| D3 | **L-012 校验实现：解析 Part A~G 的 cp/rsync/mkdir 指令，构建"期望覆盖集合"，diff 实际目录树** | 维护手工清单文件 `.package-manifest.txt` | 解析方案零额外维护——改 Part A~G 后校验自动感知；手工清单容易过时（本身就是 L-012 要解决的问题） | 解析器需处理 3 级 fallback（git archive / rsync / 本地 cp）的不同语法，复杂度中等 |
| D4 | **L-012 `--validate` 作为独立 flag，不改变现有打包流程** | 把校验嵌入 `--build` 默认流程 | 独立 flag 向后兼容——现有 CI/脚本调用不受影响；用户主动跑校验时才触发 | 用户可能忘记跑校验——可在 pre-push hook（quality-baseline change）中自动调用 |
| D5 | **L-010 在 4-dev prompt §1.8.4 "回归测试覆盖" 段嵌入自动 bats 执行** | 在 1.8.3 反问之后独立加一步 | 1.8.4 是现有"回归测试"段，语义自然契合；改一处不扩结构 | prompt 指令依赖 AI 执行——弱模型可能跳过，需要 L2 自检 gate 强制填空确认 |
| D6 | **L-010 bats 失败阻断：exit code ≠ 0 → 强制暂停 + 禁止进入 toll-gate** | 警告但不阻断 | 阻断是硬防护——破坏性变更后测试不过说明有东西坏了，继续是危险的；Q3 已确认 | 如果 bats 有 flaky test 会误阻断——当前 94 tests 全 stable，风险低 |

---

## 2. 数据流 / 架构图

### L-013 归档双向校验流程

```
  7-integration §5 归档完成
        │
        ├── ① PROGRESS.md 已确认入 archive/（既有机检）
        │
        ├── ② [NEW] rm -rf .specs/<change-id>/
        │         └── 前提: test -d .specs/archive/<date>-<id>/PROGRESS.md
        │
        └── ③ [NEW] 扫描 .specs/ 下非 archive 目录
                  │
                  ├── for each .specs/<dir>/:
                  │     grep "REVIEW.*✅\|REVIEW.*PASS" → 已完成
                  │     grep "status.*done" TASK.md → 全 done
                  │     test ! -d .specs/archive/*<dir> → 未归档
                  │
                  └── 命中 → 输出警告: "<dir> 已完成但未归档，建议跑 7-integration"
```

### L-012 打包完整性校验流程

```
  bash package-flow-kit.sh --validate
        │
        ├── ① 解析 Part A~G，构建期望覆盖集合
        │     ├── Part A: rsync flow-kit/ → STAGING/flow-kit/
        │     ├── Part B: cp SKILL.md → STAGING/skills/<name>/
        │     ├── Part C: cp stop/*.sh → STAGING/hooks/stop/
        │     ├── Part D: cp config → STAGING/hooks/config/
        │     ├── Part E: cp install.sh + lib/* → STAGING/
        │     ├── Part F: rsync brooks-lint/ → STAGING/brooks-lint/
        │     └── Part G: cp brooks-tools → STAGING/brooks-lint/tools/
        │
        ├── ② 扫描 flow-kit-bundle/ 实际目录树
        │     find flow-kit-bundle/ -type f | sort
        │
        ├── ③ diff ① vs ②
        │     ├── 期望但实际不存在 → WARNING（源文件缺失）
        │     ├── 实际但期望未覆盖 → ERROR（漏配！这正是 L-012 要抓的）
        │     └── 完全一致 → OK
        │
        └── ④ 输出结果 + exit code
              ├── 0: 校验通过
              ├── 1: 有漏配项
              └── 2: 脚本自身错误
```

### L-010 1.8 自动 bats 流程

```
  4-dev 阶段触发 1.8 协议
        │
        ├── 1.8.1 grep 引用图（既有，不变）
        ├── 1.8.2 列出影响清单（既有，不变）
        ├── 1.8.3 反问用户（既有，不变）
        │
        ├── 1.8.4 [ENHANCED] 回归测试覆盖
        │     ├── [NEW] 自动执行: npx bats test/
        │     ├── [NEW] 检查结果:
        │     │     ├── 0 failures → ✅ 输出摘要 + 继续
        │     │     └── ≥1 failure → 🔴 阻断:
        │     │           ├── 输出失败测试清单
        │     │           ├── 暂停流程（禁止进入 toll-gate）
        │     │           └── 提示: "修复以上测试失败后重跑 npx bats test/"
        │     └── [NEW] 将 bats 结果写入 SUMMARY「破坏性变更」段
        │
        └── 1.8.5 写入 SUMMARY（既有，加 bats 结果字段）
```

---

## 3. 关键状态机

无复杂状态机。三个改动都是线性流程（触发 → 校验 → 通过/阻断）。

---

## 4. ADR 索引

本 change 无可逆性低的决策。所有决策（D1~D6）都是可逆的流程增强——如果校验逻辑有问题，回滚只是删一段 prompt 指令或函数。不写独立 ADR。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **D1 纯 prompt 指令依赖 AI 执行**：弱模型可能跳过归档清理或扫描步骤 | 归档后空壳残留，L-013 未真正修复 | 中 | L2 自检 gate：7-integration PCSC 加"归档后 .specs/<id>/ 已删除"检查项；PCG 独立验证 |
| R2 | **D3 解析器覆盖不全**：Part A~G 的 cp/rsync 语法多样（含 for 循环、变量拼接），解析器漏掉边缘 case 导致误报/漏报 | 校验假阴性（漏配报不出来）或假阳性（正常配置误报错） | 中 | AC-3/AC-4 的 bats 测试覆盖典型漏配和正常场景；解析器只处理确定模式，不确定的行标 WARNING 而非 ERROR |
| R3 | **D5 bats 阻断误伤**：如果 bats 有 environmental 原因导致的失败（如 npx 不可用），误阻断正常开发 | 开发者被卡住，浪费时间 | 低 | 阻断前检查 bats 是否可执行（`npx bats --version`），不可用时降级为 WARNING 而非阻断；当前 94 tests 全 stable |
| R4 | **L-013 自动 rm -rf 误删**：PROGRESS.md 确认逻辑有 bug，删了未真正归档的目录 | 丢失 change 全部工件 | 低 | 双重确认：① PROGRESS.md 存在于 archive 目标目录；② archive 目录名匹配 change-id；③ 先 `ls` 列出待删内容等用户确认（7-integration 既有"归档操作必须用户确认"约束） |
| R5 | **长期债：校验逻辑与打包脚本耦合**：未来 Part A~G 结构大改时，L-012 解析器需同步更新 | 校验失效或误报 | 低 | 解析器报错时输出"无法解析的行号 + 内容"，人工可快速定位；AC-4（正常场景通过）作为回归护栏 |

---

## 6. 不在范围

- 不引入独立的 `archive-check.sh` 脚本（D1 决策走 prompt 路线）
- 不做 cron / 定时扫描（v2）
- 不自动修复 L-012 校验失败（out）
- 不改变 4-dev 1.8 协议的整体结构（仅在 1.8.4 子段增强）
- 不修改 `flow-kit-bundle/lib/` 下的安装逻辑
- 不引入新的 npm/apt 依赖

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `package-flow-kit.sh` 内的 `validate_staging_coverage()` 函数 | 解析 cp/rsync/mkdir 指令 → diff 目录树 → 报告漏配 | 任何改动了 `flow-kit-bundle/` 目录结构的 change | 每次改完 bundle 结构后跑 `--validate` 确认 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 归档完成自动清理工作目录 | L-013：7-integration 归档后 rm -rf .specs/<id>/ | 所有 change 的归档流程 | 低——删一段 prompt 指令即可回滚 |
| 1.8 协议自动跑 bats | L-010：4-dev 1.8.4 段嵌入 npx bats test/ | 所有触发 1.8 协议的 change | 低——删 bats 执行指令即可回滚 |

### 9.3 新增 / 修改的跨模块契约

```
- 7-integration prompt §5 归档段新增子步骤：清理工作目录 + 扫描孤儿 change
- 4-dev prompt §1.8.4 段增强：自动 bats + 失败阻断
- package-flow-kit.sh 新增 --validate flag（不改变现有 CLI 契约）
```

### 9.4 新增 / 升级的依赖

无。不引入任何新依赖。

### 9.5 禁动清单变化

```
- 新增禁动：无（本 change 不创建需要后续保护的新模块）
- 解禁：无
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
