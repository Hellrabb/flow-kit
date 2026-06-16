# REVIEW: 健康巡检修复 — 消除技术债 + 引入测试

- **Change ID**: `health-fix`
- **关联**: `@.specs/health-fix/REQUIREMENT.md`、`@.specs/health-fix/DESIGN.md`、`@.specs/health-fix/TEST.md`
- **变更规模**: 14 files, +103/-396 lines

---

## 第一轮 · Spec 合规审查

| AC | 描述 | 实现状态 | 测试覆盖 |
|---|---|---|---|
| AC-1 | bats 框架就绪 | ✅ `test/` 目录，`npx bats` 可运行 | ✅ 28/28 pass |
| AC-2 | common.sh 6 函数覆盖 | ✅ test_common.bats 17 tests | ✅ |
| AC-3 | install.sh 10 参数覆盖 | ✅ test_install.bats 11 tests | ✅ |
| AC-4 | hooks 唯一源 | ✅ `.claude/hooks/` 删除，install.sh 重装恢复 | ✅ manual verify |
| AC-5 | install.sh 拆分 ≤5 文件 | ⚠️ install.sh 202 行（目标 150）+ 4 lib ≤ 156 行 | ✅ 11/11 tests pass |
| AC-6 | 魔法数字 → readonly | ✅ 4 文件 8 个 readonly 常量 | ✅ grep verify |
| AC-7 | 外部路径 fallback | ✅ Part A/B/F 三级 fallback | ✅ 本地副本存在 |
| AC-8 | settings.json 去重 | ✅ heredoc 替换为 cp | ✅ grep verify |
| AC-9 | 版本号动态读取 | ✅ jq → grep/sed → unknown fallback | ✅ 0 hardcoded |

**范围蔓延检查**：
- ✅ 未引入 out of scope 的内容
- ✅ 未新增 REQUIREMENT.md 之外的功能
- ✅ 未触动 DESIGN.md 禁动清单的文件

**AC-5 偏差说明**：install.sh 主脚本 202 行 vs 目标 150 行。差异来自 usage 帮助文本（~26 行）和 --reinstall 清理逻辑（~20 行），均为必要的用户文档和安全清理。实测功能等价（11/11 tests pass），建议接受此偏差。

---

## 第二轮 · 代码质量审查（6 维衰退风险）

### 2.0 TEST.md 5 轮完整性

| 轮次 | 状态 | 理由 | 判定 |
|---|---|---|---|
| 第 1 轮 | ✅ | 28 bats tests, 9/9 ACs | ✅ |
| 第 2 轮 | ❌ | Bash 项目无性能预算 | ✅ 理由充分 |
| 第 3 轮 | ⚠️ | 秘钥扫描 0 命中 | ✅ 范围合理 |
| 第 4 轮 | ❌ | 无浏览器/DB/API | ✅ 理由充分 |
| 第 5 轮 | ❌ | 无运行时服务 | ✅ 理由充分 |

✅ 5 轮状态明确，跳过轮次有具体理由。

### 2.1 代码质量诊断（brooks-lint 已装 · 内置 6 维 + diff 审查）

#### 🔴 R2 (Change Propagation) — install.sh lib source 路径依赖

**Symptom**: `flow-kit-bundle/install.sh:23-26` — 4 个 lib 文件使用 `source "$SCRIPT_DIR/lib/xxx.sh"` 绝对路径硬编码 source 顺序。若后续有人在 lib/ 中新增文件但忘记在主脚本中 source，函数未定义但不会在脚本启动时报错（只在调用时才报错）。

**Source**: Hunt & Thomas — The Pragmatic Programmer — Orthogonality（模块间应松耦合，但 source 链形成隐式依赖）

**Consequence**: 新增安装函数（如 `install_docs()`）时，容易遗漏 source 声明，导致运行时 "command not found" 错误。

**Remedy**: 在 install.sh 顶部添加 glob-based auto-source：
```bash
for lib in "$SCRIPT_DIR/lib/"*.sh; do source "$lib"; done
```
或保留显式 source 但加上注释 `# NOTE: 新增 lib 文件时必须在此添加 source`

**严重度**: 🟡 Major

#### 🟡 R3 (Knowledge Duplication) — install.sh 与 lib/install_hooks.sh 中 `install_file` 重复定义风险

**Symptom**: `install_file()` 函数定义在 `lib/install_hooks.sh:5-14`，仅在 `install_hooks()` 和 `install_skills()` 中使用。但因 install.sh source 了所有 lib 文件，函数全局可见，可能在未来被其他 lib 文件隐式依赖。

**Source**: Ousterhout — A Philosophy of Software Design — Information Leakage（不应暴露超出必要范围的接口）

**Consequence**: install_file 被多处隐式调用时，修改其行为（如加 chmod）可能意外影响其他调用方。

**Remedy**: 保持现状（install_file 语义单一、行为稳定）。若后续新增 > 3 个调用方，考虑抽到独立的 `lib/utils.sh`。

**严重度**: 🟢 Minor

#### 🟡 R1 (Cognitive Overload) — 24-session.sh readonly 常量与原有逻辑混排

**Symptom**: `flow-kit-bundle/hooks/stop/24-session.sh:11-16` — 新增 5 个 readonly 常量在 `set -euo pipefail` 之后、业务逻辑之前，但部分原比较（`-gt 0`/`-lt 60`/`-lt 3600`）仍使用裸数字。新增常量和遗留数字混合，增加理解成本。

**Source**: McConnell — Code Complete — Ch. 12: Fundamental Data Types（一致性：同一文件内常量与裸数字不应混用）

**Consequence**: 新开发者可能误以为"0/60/3600 也是阈值需要抽常量"，但其实它们是通用的时间/零值比较——造成困惑而非帮助。

**Remedy**: 在常量定义区加注释标明 `# 以下为业务阈值常量，通用比较（-gt 0/-lt 60/-lt 3600）保留裸数字`

**严重度**: 🟢 Minor

#### 🟢 R4 (Accidental Complexity) — package-flow-kit.sh Part B 重复的 fallback 循环体

**Symptom**: `package-flow-kit.sh:52-67` — 本地副本路径和外部路径的 for 循环体完全相同（12 行），仅 `skill_dir` 变量来源不同。

**Source**: Fowler — Refactoring — Duplicate Code

**Consequence**: 修改 skills 打包逻辑时需同步修改两处，容易遗漏。

**Remedy**: 提取公共循环为函数 `pack_skills_from_dir(base_dir)`：
```bash
pack_skills_from_dir() {
  local base="$1"
  for skill_dir in "$base/flow-"*/ "$base/flow/"; do
    [ -d "$skill_dir" ] || continue
    ...
  done
}
```

**严重度**: 🟢 Minor

### 2.2 架构依赖检查

不触发（本次 change 无新增顶级模块/package/目录，无 import 变更，非大型重构）。

---

## 第三轮 · UI 视觉审查

跳过 — Bash CLI 项目，无 UI 文件。

---

## 第四轮 · 补充审查

### 4.1 技术债评估

跳过 — 本次 change 本身就是健康巡检修复，刚刚跑过 M-health（62→预计 85+）。不重复评估。

### 4.2 跨模型 spot-check

跳过 — 不命中触发条件：无安全/认证变更，无并发/分布式，无单一函数 > 80 行，测试覆盖率上升（0→28 tests）。

---

## 修复任务

```xml
<task id="T-FIX-01" status="pending">
  <name>添加 install.sh lib source 注释提醒</name>
  <read_files>flow-kit-bundle/install.sh</read_files>
  <write_files>flow-kit-bundle/install.sh</write_files>
  <action>
    在 4 个 source 声明之后添加注释：
    "# NOTE: 新增 lib/ 文件时必须在此添加 source 声明"
  </action>
  <verify>grep -c '新增 lib.*source' flow-kit-bundle/install.sh</verify>
  <done>注释存在，提醒后续维护者</done>
  <depends_on></depends_on>
</task>

<task id="T-FIX-02" status="pending">
  <name>在 24-session.sh 常量区添加分类注释</name>
  <read_files>flow-kit-bundle/hooks/stop/24-session.sh</read_files>
  <write_files>flow-kit-bundle/hooks/stop/24-session.sh</write_files>
  <action>
    在 readonly 常量块之后添加注释：
    "# 以下比较使用通用值（-gt 0/ -lt 60/ -lt 3600），非业务阈值，保留裸数字"
  </action>
  <verify>grep -c '通用值\|非业务阈值' flow-kit-bundle/hooks/stop/24-session.sh</verify>
  <done>注释存在，消歧常量与通用比较</done>
  <depends_on></depends_on>
</task>
```

---

## 审查结论

**通过** ✅ — 允许进入 7-integration。

### 严重度汇总

| 严重度 | 数量 | 内容 |
|------|------|------|
| 🔴 Critical | 0 | — |
| 🟡 Major | 1 | R2: lib source 路径依赖 |
| 🟢 Minor | 3 | R1 常量混排、R3 install_file 暴露、R4 重复循环体 |

### 处理策略

- 🟡 T-FIX-01: 添加注释（1 行改动，建议立即修）
- 🟢 T-FIX-02 + R3/R4: 记入 backlog，非阻塞
