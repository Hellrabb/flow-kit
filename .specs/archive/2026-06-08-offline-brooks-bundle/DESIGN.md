# DESIGN: 打包脚本离线化 brooks-lint 分发

- **Change ID**: `offline-brooks-bundle`
- **关联**: `@.specs/offline-brooks-bundle/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> CLI Bash 项目 — 跳过选型（2-design 步骤 0 例外条款）。延续既有栈。

- **语言/运行时**: Bash 4+（`#!/bin/bash`，`set -euo pipefail`）
- **文件同步**: rsync（取代 git archive 作为 brooks-lint 打包方式）
- **版本控制**: Git（仅 fallback 路径用到 `git archive`）
- **理由**: 延续 CONTEXT.md 已锁决策。rsync 是 Linux 标配，无需安装。
- **明确排除**: npm / Node.js（brooks-lint 终端用户不需要）

---

## 0.5 既有架构对齐（brownfield · B2 护栏）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（实际 grep）：
- package-flow-kit.sh L504-530（Part F · brooks-lint 打包段）— **修改**

新增模块：
- 无新文件。仅修改既有脚本的一段。

禁动清单（与本次无关，AI 不许"顺手"碰）：
- package-flow-kit.sh L1-226（打包流程其余部分：skills/hooks/core/tar）
- package-flow-kit.sh L227-498（install 函数：install_flow_kit_core/install_skills/install_hooks/install_brooks_lint）
- package-flow-kit.sh L458-498（主流程 dispatch）
- flow-kit-bundle.tar.gz
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？ | 决定 |
|---|---|---|
| 文件复制 | `install_file()` 已有 cp + dry-run | 沿用模式（Part F 打包侧不直接调用 install_file，但风格一致） |
| CLI 参数解析 | `case "$MODE" in` + flag 变量（NO_HOOKS/NO_SKILLS/NO_BROOKS） | 沿用 flag 模式，新增 `BROOKS_SRC` 变量 |
| 路径配置 | `HOOK_SRC`、`BROOKS_PLUGIN_SRC` 等已有机变量 | 沿用大写变量命名 + 默认值模式 |
| 版本检测 | 无既有抽象 | 新建（理由：第一次需要 semver 排序） |
| 错误处理 | `set -euo pipefail` | 沿用 |

### 0.5.3 沿用模式 vs 引入新模式

```
- CLI 参数解析：**沿用** flag 变量模式（`NO_BROOKS` / `HOOKS_ONLY` 同款）
- 文件打包：**引入新模式** rsync（替代 git archive）→ 理由：git archive 依赖 .git 目录，离线环境可能不存在
- 版本选择：**引入新模式** 简单 semver 排序 → 理由：首次需要多版本管理
- 错误处理：**沿用** `set -euo pipefail` + `|| true` / `2>/dev/null` 容错
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | 默认源：rsync 本地缓存（`~/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/<latest>/`） | 保持 git archive / 要求用户必须传 --brooks-src | 本地缓存是 marketplace 自动维护的，版本号子目录化，适合直接 rsync。零依赖（不需要 git） | 缓存目录结构是 marketplace 内部实现细节，未来若变化需适配 |
| D2 | Fallback：缓存不可用时回退到 git archive（原有行为） | 报错退出 / 跳过 brooks-lint 打包 | 向后兼容——老用户换新机器后仍能打包，只是多一个 warn | git archive 路径强依赖 marketplace git repo，换机器后同样不可用 |
| D3 | 版本选择：简单 `ls -1 | sort -V | tail -1`（bash 内置） | 引入 semver 工具（jq/semver CLI） | bash `sort -V` 支持 `X.Y.Z` 格式，对 2-3 个子目录够用，零外部依赖 | `sort -V` 对预发布版（`1.3.0-beta`）的处理可能与 semver 预期不同，但当前无此类版本 |
| D4 | `--brooks-src` 参数的解析位置：在现有参数解析 case 块中新增 | 单独的函数 parse_brooks_args() | 沿用现有风格——所有参数在同一 case 块处理，保持一致性 | 若未来参数增多（>20 个），case 块会变长——但当前规模可控 |
| D5 | 不在打包阶段校验 brooks-lint 内容完整性 | 预先校验 skills/commands/hooks 目录结构 | 轻量优先——宁可打包了不完整的 brooks-lint 后期发现，也不加复杂预检逻辑。完整性校验延迟到安装后用户首次调用 `/brooks-review` | 可能打出残缺 bundle 到离线环境才发现——但因为源是本地缓存（已验证可用），概率极低 |

---

## 2. 数据流 / 架构图

### 2.1 修改后的 Part F 数据流

```
package-flow-kit.sh Part F（修改后）

  BROOKS_SRC 参数?
      │
      ├── 用户指定了 --brooks-src <path>
      │   └─> BROOKS_SRC=<path>
      │
      └── 未指定
          │
          ├── 检测本地缓存
          │   CACHE=~/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/
          │   │
          │   ├── $CACHE 存在且非空
          │   │   ├─> VERSION=$(ls -1 "$CACHE" | sort -V | tail -1)
          │   │   ├─> rsync -a "$CACHE/$VERSION/" "$STAGING/brooks-lint/plugin/"
          │   │   └─> echo "✅ brooks-lint v$VERSION (本地缓存)"
          │   │
          │   └── $CACHE 不存在或为空
          │       ├─> echo "⚠️ 本地缓存不可用，回退到 git archive 方式"
          │       └─> git archive ... (原有逻辑)
          │
          └── F1: 命令入口文件（不变）
              cp ~/.claude/commands/brooks-*.md → $STAGING/brooks-lint/commands/

  与旧版差异：
    - 旧版：BROOKS_PLUGIN_SRC → git archive → staging/plugin/
    - 新版：CACHE/<version>/ → rsync → staging/plugin/（首选）
            BROOKS_PLUGIN_SRC → git archive → staging/plugin/（fallback）
```

### 2.2 改动范围（diff 边界）

```
package-flow-kit.sh
  L504-530: Part F brooks-lint 打包段 — 修改
    ~504: 注释更新（Part F 描述）
    ~507-510: 新增 BROOKS_CACHE 变量声明
    ~510-520: 新增缓存检测 + 版本选择逻辑
    ~520-530: rsync / git archive 分支
    ~256: 参数解析 case 新增 --brooks-src)
  
  其余全部行：不变（0 diff）
```

---

## 3. 关键状态机

无。本次 change 仅改打包脚本的一个子段，不引入状态机。

---

## 4. ADR 索引

无需独立 ADR。所有决策均可逆：
- D1（rsync 优先）→ 可改回 git archive
- D2（fallback）→ 可改为报错退出
- D3（sort -V）→ 可替换为 semver 工具

---

## 5. 风险

| # | 风险 | 类型 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|---|
| R1 | 本地缓存路径 `~/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/` 未来被 marketplace 改结构 | 实现风险 | 打包找不到源 → fallback git archive 或报错 | 低 | --brooks-src 参数可手动指定路径绕过；cache 路径在 CONTEXT.md 记录 |
| R2 | `sort -V` 对非标准版本号（如 `1.3.0-beta-1`）排序不正确 | 实现风险 | 选错版本 | 低 | 当前 brooks-lint 仅发布正式版（x.y.z），无预发布标签 |
| R3 | rsync 在极简容器（如 alpine）中可能不存在 | 上线风险 | 打包失败 → fallback git archive | 低 | fallback 机制已覆盖；且打包机通常是完整 Linux 发行版 |
| R4 | 修改 package-flow-kit.sh 时意外改动其他 Part（skills/hooks/core）的逻辑 | 实现风险 | 破坏其他组件的打包 | 中 | 4-dev 步骤 5 diff 边界 verify（R6.5）严格检查；仅 Part F 段可改 |
| R5 | `.specs/LESSONS.md` L-002 指出的硬编码路径问题未根本解决（仅加 --brooks-src 缓解） | 长期债务 | 换机后默认缓存路径不可用 | 低 | --brooks-src 参数是当前最务实的缓解；长期方案需 marketplace 标准化导出路径 |

---

## 6. 不在范围

- 不修改 install_brooks_lint() 安装侧逻辑（已是纯文件复制）
- 不引入 Node.js / npm（已验证不需要）
- 不增加 `--brooks-version` 参数（v2）
- 不校验 brooks-lint 缓存内容完整性（v2）
- 不改变 bundle 结构（brooks-lint/commands/ + brooks-lint/plugin/ 子目录不变）
- 不修改 package-flow-kit.sh 其他 Part（A-E, G-tar）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

`N/A` — 本 change 不引入新的可复用函数或工具库。版本检测逻辑（`ls -1 | sort -V | tail -1`）是 inline 实现，暂不抽取。

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| brooks-lint 打包源优先级 | 本地缓存 > git archive fallback | package-flow-kit.sh Part F | 低 — 改回 git archive 只需删除缓存检测段 |
| 版本自动选择策略 | `sort -V \| tail -1`（bash 内置） | 打包时版本探测 | 低 — 替换为 semver 工具即可 |

### 9.3 新增 / 修改的跨模块契约

`N/A` — brooks-lint/commands/ + brooks-lint/plugin/ 目录结构不变，安装侧无感知。

### 9.4 新增 / 升级的依赖

`N/A` — rsync 是 Linux 标配，不视为新增依赖。

### 9.5 禁动清单变化

```
新增禁动（建议 append 到 CONTEXT.md「禁动清单」段）：
- package-flow-kit.sh L504-530（Part F brooks-lint 打包段）— 仅 Part F 可改；Part A-E, G 禁顺手改
```

---

> 本文件不包含完整代码实现。关键逻辑已用 ASCII 数据流图描述，具体修改留给 4-dev 阶段。
