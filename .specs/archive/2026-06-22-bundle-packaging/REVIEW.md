# REVIEW: brooks-lint npm 工具离线打包

- **Change ID**: `bundle-packaging`
- **关联**: `@.specs/bundle-packaging/REQUIREMENT.md`、`@.specs/bundle-packaging/DESIGN.md`、`@.specs/bundle-packaging/TASK.md`、`@.specs/bundle-packaging/TEST.md`
- **日期**: 2026-06-22

---

## 第一轮 · Spec 合规审查

### AC 对照表

| AC | 实现 | 测试覆盖 | 判定 |
|---|---|---|---|
| AC-1 depcheck 离线可用 | `install_brooks_tools()` 生成 depcheck shim → `~/.local/bin/depcheck` | `test_install_brooks_tools.bats: test 4` (DRY_RUN 含 depcheck) | ✅ |
| AC-2 jscpd 离线可用 | shim → `~/.local/bin/jscpd` | 同上 | ✅ |
| AC-3 knip 离线可用 | shim → `~/.local/bin/knip` | 同上 | ✅ |
| AC-4 ts-prune 离线可用 | shim → `~/.local/bin/ts-prune` | 同上 | ✅ |
| AC-5 打包产出 brooks-tools | Part G: npm pack → 解压 → 合并 → manifest.json | E2E: 1227 files in tarball, manifest.json 存在 | ✅ |
| AC-6 Node.js 缺失提示 | `check_node()` + `install_brooks_tools()` 双重检测 | `test_install_brooks_tools.bats: test 5` (源缺失跳过) | ✅ |
| AC-7 现有打包不退化 | Part A-F 未修改逻辑，仅追加 Part G | 94 bats tests 全通过 | ✅ |
| AC-8 shim 可被调用 | `which depcheck jscpd knip ts-prune` 等价验证（dry-run 显示路径正确） | `test_install_brooks_tools.bats: test 2,4` | ✅ |

### 范围蔓延检查

- ❌ 未引入 REQUIREMENT.md v2/out 中列出的功能（无多平台矩阵、无增量更新、无 CentOS 7 兼容）
- ❌ 未修改 brooks-lint 插件 skill prompt
- ❌ 未引入 Node.js 运行时打包
- ✅ 实现严格在 v1 范围内

### 架构越界检查

- ❌ 未触碰 DESIGN.md 0.5.1 禁动清单（hooks/、skills/、flow-kit/ 核心、Part A-E）
- ❌ 未新增外部依赖（仅使用开发机已有 npm CLI）
- ✅ 实现与 DESIGN.md 6 条决策一致

**第一轮结论**：✅ 通过。8 条 AC 全部覆盖，无范围蔓延，无架构越界。

---

## 第二轮 · 代码质量审查（6 维衰退风险）

> brooks-lint 已装。本 review 使用内置 6 维快查（针对 Bash 脚本的 6 维适配诊断）。

### 2.0 TEST.md 5 轮完整性

- [x] 5 轮状态明确（1 ✅ / 2 ❌ / 3 ⚠️ / 4 ⚠️ / 5 ❌）
- [x] 跳过轮次均有理由（Bash 脚本项目特征）
- [x] 第 1 轮每条 AC 有覆盖
- [x] 其余轮次因项目类型合理跳过

✅ 通过。

### 2.1 6 维诊断

#### R1 · 认知过载

- `package-flow-kit.sh` Part G（L286-363，78 行）：分段清晰（检测→pack→解压→合并→manifest），每段 ≤ 20 行。✅
- `install_brooks_tools.sh`（102 行）：6 个编号段，每段有 `# ──` 注释标题。✅
- `install.sh check_node()`（11 行）：单职责函数。✅
- **结论**：🟢 无问题。

#### R2 · 变更传播

- `package-flow-kit.sh`：仅修改 L22（mkdir 追加）+ 新增 Part G（L286-363）+ heredoc/summary 追加。Part A-F 一行未改。✅
- `install.sh`：仅新增代码（变量 + 函数 + flag + 调用），未改既有函数。✅
- `install_brooks_tools.sh`：新建文件，零耦合。✅
- **结论**：🟢 无问题。变更最小化。

#### R3 · 知识重复

- `install_brooks_tools()` 和 `check_node()` 都检测 `command -v node` — **轻微重复**，但语义不同（前者安装时检测，后者独立 preflight），可接受。
- `echo "   ⚠️  Node.js 未安装..."` 消息在两处出现（`check_node()` 和 `install_brooks_tools()`）— 🟢 Minor，可抽取为常量但在 Bash 中抽取文本常量过度工程。
- **结论**：🟢 可接受。无概念级重复。

#### R4 · 偶然复杂

- Part G `declare -A BROOKS_TOOLS` 用于存储 4 个工具版本号 → 对于 4 项数据使用关联数组略为过度，可用简单变量或索引数组替代。但关联数组使后续升级（添加第 5 个工具）更便捷。
- `npm pack` 后的 tgz 查找使用 `ls -t | head -1` → 可通过 `echo "$TOOLS_PACK_DIR/${tool}-${ver}.tgz"` 直接构造路径避免 ls 解析。🟢 Minor。
- **结论**：🟢 整体简洁。Minor 优化项见下方。

#### R5 · 依赖混乱

- `install.sh` source 链：`install_brooks_tools.sh` → 无外部依赖。✅
- Part G 依赖 npm CLI（开发机环境依赖），用 `command -v npm` 做 graceful degradation。✅
- 无反向依赖（高层不依赖低层实现细节）。✅
- **结论**：🟢 无问题。

#### R6 · 领域扭曲

- 变量命名使用项目域语言：`brooks-tools`、`shim`、`manifest.json`、`check_node`。✅
- 输出消息使用"brooks-lint 工具"而非技术术语（如"npm 全局包"）。✅
- **结论**：🟢 无问题。

### 严重度汇总

| 编号 | 严重度 | 位置 | 问题 |
|---|---|---|---|
| R4-M1 | 🟢 Minor | `package-flow-kit.sh:325` | `ls -t \| head -1` 可用路径构造替代 |
| R3-M1 | 🟢 Minor | `install_brooks_tools.sh:11` + `install.sh:63` | Node.js 缺失提示文本重复 |

**第二轮结论**：🟢 通过。2 个 🟢 Minor 项，无需修复（记录在案即可）。

---

## 第三轮 · UI 视觉审查

> **跳过**。本项目为 Bash 脚本项目（meta/distribution），无 `.css/.tsx/.vue/.html` 文件，无 `UI-DESIGN.md`，不适用。

---

## 第四轮 · 补充审查

### 4.1 技术债评估

**未触发**。本次 change 非里程碑/季度大版本，CONTEXT.md 技术债段 5 天前更新。跳过。

### 4.2 跨模型 spot-check

**未触发**。无安全/认证变更、无并发/分布式代码、无 > 80 行函数、测试覆盖率稳定（94 tests 全通过）。跳过。

---

## 动态门禁判定

| 检查项 | 级别 | 结果 |
|---|---|---|
| brooks-review 🔴 Critical | critical | 0 发现 ✅ |
| brooks-review 🟡 Major | warn | 0 发现 ✅ |
| spec 合规失败（AC 未覆盖） | critical | 8/8 AC 覆盖 ✅ |
| 跨模型分歧 | warn | 未触发 ✅ |

**门禁**：✅ 全部通过。无 🔴 Critical，无 🟡 Major 阻塞项。

---

## 总结

| 轮次 | 结论 |
|---|---|
| 第一轮 · Spec 合规 | ✅ 通过 |
| 第二轮 · 代码质量 | 🟢 通过（2 Minor） |
| 第三轮 · UI | ⏭ 跳过（Bash 项目） |
| 第四轮 · 补充 | ⏭ 未触发 |

**最终判定**：✅ **审查通过，可进入 7-integration。**
