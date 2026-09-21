# TEST: 修掉「门禁守卫自身」的三处假绿（+ 三处可维护性）

- **Change ID**: brooks-review-fix-2026-09
- **关联**: `@.specs/brooks-review-fix-2026-09/REQUIREMENT.md`（7 AC）、`@.specs/health/2026-09-21-BROOKS-REVIEW-FIXES.md`（处置记录）
- **形态**: 回溯登记 —— 下列数据是**当日实跑**的原始结果（含"修复前"对照），不做事后修饰

---

## 0. 本次测试范围声明（5 轮金字塔）

| 轮次 | 是否适用 | 说明 |
|---|---|---|
| 1 功能测试 | ✅ 适用 | 7 条 AC 全部有可复制执行的验证命令（本文件 1.1） |
| 2 性能测试 | ✅ 适用（轻量） | 只读检查 NFR ≤2s；新增 bats 单跑时长 |
| 3 安全测试 | ⚠️ 形式化 | 无新增依赖 / 无密钥 / 无网络；SAST = shellcheck（error 级门禁） |
| 4 兼容性测试 | ✅ 适用 | Bash 版本、GNU/BSD 工具差异、bats 版本下限（`BATS_TEST_TMPDIR`）、node 前提 |
| 5 可观测性验证 | ✅ 适用 | 新增 `⏭ SKIP` 第三态与"指名"输出的可读性 |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵（AC → 用例）

| AC | 用例 / 命令 | 修复前实测 | 修复后实测 | 判定 |
|---|---|---|---|---|
| AC-1 | `resolve_spec_artifact DESIGN.md`（无活跃 change） | `.specs/archive/2026-09-18-l3-review-defects-2026-09/DESIGN.md` rc=0（**核错对象**） | `""` rc=1 → 三行 `⏭ SKIP`；`grep l3-review-defects` 命中 0 | ✅ |
| AC-1 | `bash verify-claims.sh ghost-change-2099` | —（无此路径） | rc≠0，输出 `change 'ghost-change-2099' 的 DESIGN.md 未找到` | ✅ |
| AC-1 | `bash verify-claims.sh health-fix-2026-09` | — | §8 文案指名 `.specs/archive/2026-09-21-health-fix-2026-09/DESIGN.md` | ✅ |
| AC-2 | `npx bats test/test_gate_freshness.bats` | 文件不存在；两侧 70 个 bats 中 `grep check-dist` = 0 命中 | **ok 1..14**（11/11） | ✅ |
| AC-2 | §10d ④ 判据性质（死定义文件跑同款 grep） | rc=0（**假绿**） | 判据已换为 `--entry-class` 行为断言（无 grep） | ✅ |
| AC-3 | 夹具：移走 `dsh-flow-kit/lib` → `--check` | `✅ 一致` **rc=0**（假绿，dist 陈旧树仍在） | rc=1 + `❌ 源目录缺失 … 且 dist 侧仍有旧副本` | ✅ |
| AC-3 | 夹具：陈旧内容 / 删源留副本 / 未知参数 | — | rc=1 指名 / rc=1 反向残留 / rc=2 | ✅ |
| AC-3 | 产物等价（重构不改产物） | 基线整树哈希 `9c0b7b1e…`（525 文件） | 重构后**立即**重建 → 哈希**相同** | ✅ |
| AC-4 | `grep -c 'dist/ 被 .gitignore 忽略' Makefile` | 2 | 1 | ✅ |
| AC-4 | `grep -c '10c. DESIGN §0.5.1 覆盖全部被改文件' verify-claims.sh` | 2 | 1 | ✅ |
| AC-5 | `--entry-class` 四分类 + 缺参数 | 参数不存在（未知参数 rc=2） | entry rc=0（2 个）/ library rc=1（2 个）/ 缺参数 rc=2 | ✅ |
| AC-5 | `--entry-class bogus/path.sh`（审查新增用例） | 旧实现无此前缀校验 → 会被静默判成 `library: bogus/path.sh` rc=1 | **rc=2** + `无法识别的相对路径` | ✅ |
| AC-6 | 旧 `status --short \| awk` 取法 / 未跟踪取法 | 三条命令并存，rename 取旧名 | 旧取法不存在；`git ls-files --others` 在位 | ✅ |
| AC-6 | `<base-ref>` 不可解析（审查新增用例） | 旧实现无校验 → `git diff 坏ref` 静默给空集 → §10c 退化成只核工作区并照样 ✅ | **rc=2** + `不是可解析的提交` | ✅ |
| AC-7 | `make check` | 6 门全绿 · bats 950 · 新门禁 0 覆盖 | 6 门全绿 · bats **964** · 4m03s | ✅ |
| AC-7 | `bash verify-claims.sh` | ✅ 11 ❌ 0 ⏭ 0（其中 3 条核的是**别的 change**） | ✅ 11 ❌ 0 **⏭ 3**（三条显式未核对） | ✅ |

> 「修复前实测」的取证方式：AC-1 用当日实跑输出；AC-3 用 `git show HEAD:package-dsh-plugin.sh` 放回夹具重跑（同款最小树）；
> AC-2 用同款 grep 打在"有定义、无调用点"的合成文件上。三者均记录在 REQUIREMENT 各 AC 的「修复前实测行为」段。

### 1.2 UAT 脚本

本 change 无用户可见界面。维护者侧 UAT = 三个"日常动作"：

```bash
make verify-claims                 # 期望 exit 0，✅/❌/⏭ 三计数可见
make check                         # 期望 6 门全绿
bash package-dsh-plugin.sh --check # 期望 ✅ 一致（或明确指名陈旧文件）
```

### 1.3 覆盖率

- 新增代码路径的行为覆盖：`check_dist` 的 5 条分支（基线 / 陈旧 / 缺失 / 反向残留 / 只读）与
  `is_real_entry` 的 4 类输入（真入口 / 库 / 三层路径 / 白名单外）**全部**有 bats 或 §10d 断言覆盖。
- 既有路径：`make test` 964 例覆盖全仓；本 change 未降低任何既有覆盖。

### 1.4 边界 / 错误路径用例

| 场景 | 期望 | 实测 |
|---|---|---|
| `--check` 遇到未知参数 | rc=2（fail-closed），不重建 | ✅ rc=2 |
| 打包侧必需源缺失 | rc=1 + `ERROR: … missing（COPY_DIRS 必需项）` | ✅ |
| `--entry-class` 缺参数 | rc=2 + 用法 | ✅ |
| 可选项（docs）源缺失 | 合法，不报错；但"源删而 dist 留"必须报反向残留 | ✅（代码路径 + 夹具 ④） |
| `.DS_Store` 在源侧 | 不产生永久假红（打包会删它） | ✅（既有语义保留） |
| `verify-claims` 无活跃 change | 三态之 SKIP，退出码 0 | ✅ |

### 1.5 测试质量自检（6 维测试衰退风险）

| 维 | 风险 | 结论 |
|---|---|---|
| T1 Test Obscurity | 用例名是否表达场景+期望 | ✅ 14 例全部为「对象：场景 → 期望」句式（如 `check-dist：必需源目录被移走 → rc=1（原实现静默 ✅ 的回归保护）`） |
| T2 Test Brittleness | 是否断言实现细节 | ✅ 只断言**退出码 + 输出关键词**（如 `源目录缺失` / `陈旧` / `反向残留`），不断言行号、不断言内部函数名 |
| T3 Test Duplication | 夹具是否重复 | ✅ 夹具集中在 `make_fixture()`；破坏性用例各自只改一处状态 |
| T4 Mock Abuse | 是否 mock 掉真实行为 | ✅ 无 mock；真跑 `package-dsh-plugin.sh` / `sync-hooks.sh` |
| T5 Coverage Illusion | 是否"执行了但没验" | ✅ 每条用例都有可证伪断言；且**修复前版本会在用例 3 上失败**（假绿已复现） |
| T6 Architecture Mismatch | 层次是否合理 | ✅ 全部为集成级（真跑脚本），无慢 E2E；单文件 14 例 ~10s |

### 1.6 测试质量记事（backlog）

- 夹具用 `$BATS_TEST_TMPDIR`（bats ≥1.5 特性）—— 若将来降到更老 bats 需换 `mktemp -d` + trap 清理。
- `--filter` 精确匹配在部分 bats 版本行为不同，1.2 的 UAT 建议直接跑整文件。

---

## 第 2 轮 · 性能测试

### 2.1 性能预算（来自 REQUIREMENT.md 非功能性需求）

- `package-dsh-plugin.sh --check`（只读新鲜度检查）：**≤2s**
- 新增 bats 单文件运行：**≤30s**
- `make check` 全量：**不显著劣化**（基线 4m3s 量级）

### 2.2 实测结果

| 项 | 预算 | 实测 | 判定 |
|---|---|---|---|
| `--check`（全包 525 文件逐字节 `cmp`） | ≤2s | **0.600s**（`time` 三次中位数量级一致） | ✅ |
| `npx bats test/test_gate_freshness.bats` | ≤30s | ~10s（14 例，含 10 次最小树打包/检查） | ✅ |
| `make check`（6 门 + 964 bats） | 不劣化 | **4m03s**（含新增 14 例与 8 次最小树打包） | ✅ |

### 2.3 工具输出

```
$ time bash package-dsh-plugin.sh --check
✅ check-dist: dist 与源一致
real    0m0.600s
```

### 2.4 退步项处理

无退步项。新增 14 例带来的增量约为全量耗时的 +4s（<2%）。

---

## 第 3 轮 · 安全测试

| 项 | 结论 |
|---|---|
| 3.1 依赖漏洞 | 无新增依赖（仅 bash/git/coreutils，均为既有前提） |
| 3.2 秘钥扫描 | 无凭证、无网络调用（`--check` / `--entry-class` 均为本地只读） |
| 3.3 SAST | `shellcheck -e SC1091` 对 4 个改动脚本：无 error 级问题（info/style 级为既有风格项，`make lint` 只卡 error） |
| 3.4 OWASP Top 10 | N/A（无 Web/服务端面）。相关面：命令注入 —— 新增代码全部使用引号包裹的变量展开，无 `eval` |

---

## 第 4 轮 · 兼容性测试

### 4.1 跨浏览器（Web）

N/A（CLI 工具项目）

### 4.2 视口

N/A

### 4.3 数据迁移（涉及 schema 变更必填）

N/A（无 schema）

### 4.4 跨版本

| 面 | 结论 |
|---|---|
| Bash 版本 | 新增构造：`local -a arr=(…)`、`"${arr[@]}"`、`case` 模式匹配、`printf`、`IFS= read -r -d ''` —— 均为 bash 3.2+ 可用（本仓既有代码已在用同族构造） |
| GNU/BSD 差异 | 新代码未新增 GNU 专属选项；`find -not -name` 为既有用法，保持原样 |
| bats 版本 | 夹具使用 `$BATS_TEST_TMPDIR`（bats ≥1.5）；本仓 `npx bats` 为 1.13.0 → 满足 |
| node | 夹具跑真实打包脚本 → 要求 node（打包脚本本就要求，非新增前提） |
| macOS | 未在 macOS 实测；新增代码无平台分支（既有跨平台约定不变） |

---

## 第 5 轮 · 可观测性验证

### 5.1 日志

- `check-dist` 失败时**逐条指名**文件与原因（`陈旧` / `缺失` / `源目录缺失` / `反向残留`），并在末尾给修复命令与顺序提示。
- `verify-claims` 新增 `⏭` 行写明**为什么未核对**（无 `<change-id>` 且 `.flow-active` 不可用）。

### 5.2 指标

`make lint` 的 `SCANNED_FILES: 66` 与 `verify-claims` 的 `✅/❌/⏭` 三计数即本 change 的可观测面（沿用既有出口，未新增指标）。

### 5.3 链路追踪

N/A

### 5.4 告警 + 健康检查

`check-hooks-sync` 的"不可执行"告警在本 change 后仍只对**真入口**触发（`--entry-class` 出口使该契约可测）；
`make check` 即健康检查入口。

---

## 新增测试登记

| 文件 | 用例数 | 覆盖 | 双源 |
|---|---|---|---|
| `test/test_gate_freshness.bats` | 11 | `check-dist` 5 例 · 打包与参数 fail-closed 2 例 · 真入口判据 3 例 · `<base-ref>` fail-closed 1 例 · 必需源文件缺失 1 例 · 夹具自检 1 例 | ✅ 已 `make test-sync` 同步到 `flow-kit-bundle/test/` |

全量基线变化：**950 → 964 ok / 0 not ok**。

## 回归保护

| 被保护的行为 | 守护者 |
|---|---|
| 陈旧 dist 必须红且指名 | `test_gate_freshness.bats` 用例 2 + `make check` 的 check-dist 门 |
| 必需源目录缺失不得静默通过 | `test_gate_freshness.bats` 用例 3、7 |
| `--check` 只读 | 用例 5 |
| 真入口判据分类正确 | 用例 8、9 + `verify-claims.sh §10d ③`（行为断言） |
| 工件解析不换对象 | `verify-claims.sh` 三态 + AC-1 验证命令 |
| 打包产物不变 | 产物等价基线哈希（`9c0b7b1e…`，记录于 DESIGN R2） |
