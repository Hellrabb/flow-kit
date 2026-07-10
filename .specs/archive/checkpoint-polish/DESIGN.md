# DESIGN: auto-checkpoint 收尾——BW01/02/03 三项品质提升

- **Change ID**: `checkpoint-polish`
- **关联**: `@.specs/checkpoint-polish/REQUIREMENT.md`、`@.specs/CONTEXT.md`、`@.specs/ARCHITECTURE.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 本项目为 Bash 脚本分发包仓库，CONTEXT.md 已锁定技术栈。跳过 tech-stacks.md 卡片筛选。

- **选定**: 纯 Bash（`#!/bin/bash`，`set -euo pipefail`）
- **前端**: 无
- **后端**: 无
- **数据库**: 无
- **测试**: bats-core 1.13.0（`npx bats`）
- **静态分析**: shellcheck（error 级别，`-e SC1091`）
- **构建**: GNU Makefile
- **关键依赖**: `jq`（JSON 处理）、`bash` ≥ 4.0（关联数组）
- **理由**: 延续项目既有技术栈，本次 change 不引入新语言/框架/依赖
- **明确排除**: 无（纯 Bash 重构，无需选栈）

---

## 0.5 既有架构对齐（brownfield）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep/read 验证的实际清单）:
- flow-kit-bundle/hooks/session-start/flow-kit-resume.sh（254 行 · BW01 重构源——banner 段 L201-254）
- flow-kit-bundle/hooks/stop/lib/（既有共享 lib 目录 · BW01 新 banner lib 放入此处）
- hooks/stop/lib/checkpoint-lib.sh（既有 lib 范式参考——checkpoint_write() 封装模式可复用）
- .specs/CHANGELOG.md（664 行 · BW02 格式统一目标）
- test/（37 .bats · BW03 同步源）
- flow-kit-bundle/test/（37 .bats · BW03 同步目标）
- Makefile（73 行 · BW03 集成点——新增 test-sync target + 已有 check-test-sync）

新增文件:
- flow-kit-bundle/hooks/stop/lib/banner.sh（BW01 · 新 lib 文件 · ~70 行）
- test/test_resume_banner.bats（BW01 · 新测试文件 · ~30 行）

禁动清单（与本次无关，AI 禁止"顺手"碰）:
- flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh（既有 lib，与 BW01 同目录但无关——禁顺手重构）
- flow-kit-bundle/hooks/session-start/stop-report-reminder.sh（SessionStart 另一模块，无关）
- package-flow-kit.sh（打包脚本——BW03 新增文件需在 Part F 注册但禁改 Part A-E/G）
- hooks/stop/ 下除 lib/banner.sh 外的所有模块（禁顺手改）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| lib 函数封装模式 | `hooks/stop/lib/checkpoint-lib.sh` 的 `checkpoint_write()` | **沿用**——相同的 `source` + fail-open + 活跃 change 检测模式 |
| Shell 错误处理 | `set -euo pipefail` + `common.sh` | **沿用** |
| Makefile target 模式 | `Makefile` 已有 `check-test-sync`、`dup`、`lint` | **沿用**——新 target 遵循相同风格（recipe 内 command -v 检测 + 非阻塞 skip） |
| bats 测试结构 | `test/` 下 37 个 .bats，统一的 `setup()` / `@test` 范式 | **沿用** |
| CHANGELOG 追加格式 | `.specs/CHANGELOG.md` 顶部紧凑 pipe 格式 | **沿用**——统一为此格式而非引入新格式 |

### 0.5.3 沿用模式 vs 引入新模式

```
- lib 组织: **沿用** hooks/stop/lib/ 作为共享 lib 目录（SessionStart + PreToolUse + Stop 共用）
- 函数封装: **沿用** checkpoint-lib.sh 的 sourceable shell lib 模式（纯函数定义，无 main 入口）
- Makefile target: **沿用** 既有 recipe 风格（@echo 标题 + 检测工具 + graceful skip）
- 没有引入新模式——本次三轮 BW 均为既有模式的增量应用
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| **D1** | Banner 函数放在 `hooks/stop/lib/banner.sh` | ① 新建 `hooks/session-start/lib/banner.sh` ② `flow-kit-bundle/lib/banner.sh` | `hooks/stop/lib/` 已是 SessionStart + Stop + PreToolUse 的共享 lib 目录（11 个既有 lib），ARCHITECTURE.md §2.1 明确此为三者共用层。在此新增 banner.sh 无需改 source 路径约定 | 新函数与 checkpoint-lib.sh 等 lib 混在同一目录，单看目录名 "stop" 稍显名不副实——但 ARCHITECTURE.md 已记录此为共享层，语义清晰 |
| **D2** | 函数接口: `build_resume_banner(flow_file_path: string) → stdout` | ① 多函数拆分（banner_top / banner_body / banner_bottom）② 返回字符串变量而非 stdout | 单一函数 + stdout 输出：banner 逻辑紧凑（54 行 ASCII art），拆分过细增加 source 开销；stdout 输出方便 `diff <(old) <(new)` 回归对比 + bats 测试捕获 | 若未来 banner 逻辑显著膨胀（>100 行），需重构为多函数——边界清晰，当前不触发 |
| **D3** | `flow-kit-resume.sh` 改为 `source` banner.sh + 调用函数 | ① 保留原内联代码，仅在测试中 source banner.sh ② 用 `cat` heredoc 替代 | source + 调用是 Bash 标准模块化方式，与 checkpoint-lib.sh 等 lib 使用模式一致。`flow-kit-resume.sh` 本身已 source `hooks/stop/lib/common.sh`（同一 lib 目录），无新增依赖路径 | 增加一次 `source`（< 5ms），对 SessionStart 延迟无感知影响 |
| **D4** | CHANGELOG 格式统一: 消除独立表头行，所有条目紧凑 pipe 格式 | ① 保留表头行作为分隔 ② 全删表头行，所有条目不加表头 | 消除表头行: AC-4 已固化为 `grep -c` 返回 0。顶部条目已为此格式，统一后全文一致 | 缺少表头行对新读者略增理解成本——但第一行条目本身就是格式示例，且本文件维护者均为项目内部 |
| **D5** | 双源同步方向: `test/ → flow-kit-bundle/test/`（单向） | ① 双向 rsync ② test/ ← bundle/test/（反向）| test/ 为开发源（人工编辑 + `npx bats test/` 在此运行），bundle/test/ 为打包副本（仅 package-flow-kit.sh 读取）。单向同步避免双向冲突；Makefile recipe 用 `cp -r test/*.bats flow-kit-bundle/test/` 简单可靠 | 若有人在 bundle/test/ 直接编辑（违规），会被覆盖——通过禁动清单 + CONTEXT.md 约定防止 |
| **D6** | `make test-sync` 集成到 `make check` | ① 独立 target 不进 check ② 用 inotify 自动监听 | 集成到 `make check`：AC-7 要求 `make check` 检测不同步。`check-test-sync` 已做检测（diff -rq 非零退出），`test-sync` 作为修复动作独立 target；check 调用 check-test-sync 而非 test-sync 以避免静默覆盖 | `make check` 报不同步后需手动 `make test-sync` 修复——两步骤，符合"检测 + 修复分离"原则 |

---

## 2. 数据流 / 架构图

### BW01 · Banner 函数提取

```
重构前:
  SessionStart hook 触发
    └─> flow-kit-resume.sh (monolith)
          ├─ L1-199: phase 检测 + change_id/task_id 提取
          ├─ L201-254: banner 构建（内联 ASCII art）  ← 本次抽取目标
          └─ 输出到 stdout (CC 捕获为 session banner)

重构后:
  SessionStart hook 触发
    └─> flow-kit-resume.sh
          ├─ source hooks/stop/lib/banner.sh           ← 新增
          ├─ L1-199: phase 检测 + change_id/task_id 提取（不变）
          ├─ build_resume_banner "$flow_file"           ← 替换原 L201-254
          └─ 输出到 stdout (CC 捕获为 session banner)

测试:
  test/test_resume_banner.bats
    └─> source hooks/stop/lib/banner.sh
    └─> 构造临时 .flow-active JSON
    └─> run build_resume_banner "$tmp_flow_file"
    └─> assert_output 包含 change_id / phase / goal / interrupt
```

### BW02 · CHANGELOG 格式统一

```
重构前:
  .specs/CHANGELOG.md
    ├─ | 2026-07-10 | auto-checkpoint-hook | ...    (紧凑 pipe)
    ├─ | 2026-07-10 | td-test-infra | ...           (紧凑 pipe)
    ├─ ... (8 条紧凑 pipe)
    ├─ (空行)
    ├─ | 日期 | Change ID | 摘要 | LESSONS |        ← 独立表头行(本次删除)
    ├─ | 2026-07-05 | health-fix-2026-07 | ...      (标准表头格式条目)
    └─ ... (30 条标准表头格式条目)

重构后:
  .specs/CHANGELOG.md
    ├─ | 2026-07-10 | auto-checkpoint-hook | ...    (紧凑 pipe)
    ├─ ... (全部 38 条，统一紧凑 pipe 格式)
    └─ (无独立表头行)
```

### BW03 · 双源测试同步

```
开发流程:
  test/ (37 .bats) ──编辑──> test/ (修改后)
                                  │
                    make test-sync │ cp -r test/*.bats flow-kit-bundle/test/
                                  │
                                  v
                    flow-kit-bundle/test/ (同步后 · 37 .bats)

检测流程:
  make check
    ├─ make test        (跑全量 bats)
    ├─ make lint        (shellcheck)
    ├─ make check-validate (打包校验)
    └─ make check-test-sync
          └─ diff -rq test/ flow-kit-bundle/test/
               ├─ 一致 → ✅ test 双源一致
               └─ 不一致 → ❌ 报错: "请运行 make test-sync"
```

---

## 3. 关键状态机

无。本次 change 不引入新状态机。

---

## 4. ADR 索引

本次 change 不涉及不可逆架构决策。所有决策（D1-D6）均为模块内实现选择，不上升为项目级 ADR。

---

## 5. 风险

| # | 风险 | 类型 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|---|
| **R1** | Banner 重构后 SessionStart 输出与重构前不一致（空格、换行、字段缺失等差异导致下游解析断裂） | 实现风险 | 用户看不到正确的 resume banner / CC 依赖 banner 格式的功能异常 | 中 | `diff <(old) <(new)` 逐字符对比验证（AC-1）；全量 bats 回归（AC-3）；重构前后在同一 `.flow-active` 下跑两次 SessionStart 对比输出 |
| **R2** | CHANGELOG 格式统一时不慎删除或截断条目（如 sed/grep 表达式过宽，误删条目行） | 实现风险 | 历史记录丢失，无法回溯 change 历史 | 低 | `grep -c '^| 202[0-9]'` 前后计数一致（AC-5）；git 版本控制可回滚；修改前 `cp .specs/CHANGELOG.md .specs/CHANGELOG.md.bak` |
| **R3** | `make test-sync` 覆盖方向错误——从 bundle/test/ 同步到 test/，覆盖开发者的最新修改 | 实现风险 | 开发者未保存的测试修改丢失 | 低 | Makefile recipe 明确写死方向 `test/ → bundle/test/`，添加注释 + 确认提示；不提供反向 target |
| **R4** | banner.sh lib 文件缺失时 `flow-kit-resume.sh` 因 `source` 失败而整条 hook 崩溃（bash errexit），SessionStart 无 banner 输出 | 上线风险 | SessionStart hook 静默失败或输出不友好错误 | 低 | 按健壮性 NFR：source 失败时输出可读错误信息并以非零退出。具体：`if ! source ...; then echo "❌ banner.sh 缺失" >&2; return 1; fi` |
| **R5** | 新增的 `test/test_resume_banner.bats` 和同步后的 bundle 测试文件未在 `package-flow-kit.sh` 注册，导致分发包缺失 | 长期债务 | 用户安装分发包后缺少测试文件（低影响——测试仅开发用） | 中 | BW03 `make test-sync` 运行后 bundle/test/ 自动包含新文件；package-flow-kit.sh Part F 已在 `flow-kit-bundle/test/` 通配打包范围内（验证：grep Part F 覆盖范围）。BW01 新 lib 需确认 Part D 覆盖 `hooks/stop/lib/` |
| **R6** | BW01/02/03 三者无代码依赖但共享一个 change——任一失败需整体回滚 | 实现风险 | 一条 BW 的 bug block 另两条 BW 的发布 | 低 | 三条 BW 修改不同文件（banner.sh+resume.sh / CHANGELOG.md / Makefile），无文件级冲突。如单条失败，git revert 对应 commit 即可，不影响另两条 |

---

## 6. 不在范围

- **BW04**（install_hooks.sh 去重）——等第三个 PreToolUse hook 出现时一并处理（CHANGE.md 已声明）
- **CHANGELOG 自动生成**（从 git log 提取）——v2 范围
- **bats 测试框架升级**——项目标准锁定 bats-core 1.13.0
- **banner 国际化 / 多语言**——当前仅中文用户，无需求
- **双向测试同步**——仅 test/ → bundle/test/ 单向

---

## 9. 架构沉淀建议

本次 change 无架构层面沉淀建议。

三条 BW 均为既有模式的增量应用：BW01（lib 抽取·沿用 checkpoint-lib.sh 范式）、BW02（格式统一·沿用既有紧凑 pipe 格式）、BW03（Makefile target·沿用既有 recipe 风格）。不引入新抽象、不改变项目级决策、不新增/修改跨模块契约、不新增依赖、不改动禁动清单。
