# DEV-SUMMARY · brooks-review-fix-2026-09

- **Change ID**: brooks-review-fix-2026-09
- **阶段**: 4-dev / 5-test（**回溯登记** —— 代码与测试先于本文件存在，见 `CHANGE.md`「登记形态」）
- **任务**: T00–T06（全部 done，见 `TASK.md`）

---

## 做了什么（一段话）

按 `brooks-review` 的 6 条发现逐条修复：把 `verify-claims.sh` 的工件解析从"核不到就换一个 change"改成
**三态**（解析到 / 未指定 SKIP / 指定了找不到 FAIL）并支持显式 `<change-id> <base-ref>`；把 `package-dsh-plugin.sh`
的拷贝映射从两份收敛为**一份**（打包循环与 `--check` 同读 `COPY_*` 三表）且把"源缺失"语义与打包侧对齐
（实测修掉了"移走 `dsh-flow-kit/lib` 仍报 ✅"的假绿）；把 `sync-hooks.sh` 的真入口判据从循环体提到**文件作用域**
并新增无副作用的 `--entry-class` 自检出口，使 `§10d` 的两条文本判据换成**行为断言**；新增
`test/test_gate_freshness.bats`（14 例真跑）补上 `make test` 层面的行为回归；顺带清掉三处重复注释、收敛 `_changed` 的两余条 git 命令。

## 改动文件

| 文件 | 变更 | 对应发现 |
|---|---|---|
| `package-dsh-plugin.sh` | `COPY_DIRS`/`COPY_FILES`/`COPY_OPTIONAL` 单一映射；打包与检查同读；缺失语义对齐 | 🟡3（D3/D4） |
| `sync-hooks.sh` | `PTU_ENTRIES`+`is_real_entry()` 提到文件作用域；新增 `--entry-class`；注释去重 | 🟢2（D2）+ 🟢1 |
| `verify-claims.sh` | 工件解析三态 + `spec_target()`；新增两个位置参数；`§10c` 收敛与 `⏭ SKIP`；`§10d` ②删/④行为化 | 🟡1（D1）+ 🟡2（D5）+ 🟢3（D7）+ 🟢1（D6） |
| `Makefile` | 删除 `check-dist` 段的一行同义注释 | 🟢1 |
| `test/test_gate_freshness.bats` | **新增** 14 例行为回归 | 🟡2 |
| `flow-kit-bundle/test/test_gate_freshness.bats` | 双源镜像（`make test-sync`） | 🟡2 |

> 未触碰：`hooks/**`、`prompts/**`、`dsh-flow-kit/lib/**`、`flow-kit-bundle/lib/install_hooks.sh`（零改动）。

## verify 输出（必填）

```
$ make check
║  ✅ make check: 全部通过                           ║
exit=0 · 6 门全绿 · 4m03s
  ├─ bats: 964 ok / 0 not ok（基线 950 + 本 change 11）
  ├─ lint: SCANNED_FILES: 66 · 无 error
  ├─ validate: staging coverage OK
  ├─ check-test-sync: 双源一致
  ├─ check-hooks-sync: 7 副本漂移 0
  └─ check-dist: dist 与源一致

$ bash verify-claims.sh            # 登记后（.flow-active 指向本 change）
复验结果: ✅ 14  ❌ 0  ⏭ 0          # §8/§9/§10c 全部核到本 change 的工件

$ bash verify-claims.sh            # 登记前（无活跃 change · 三态之 SKIP）
复验结果: ✅ 11  ❌ 0  ⏭ 3          # 不再核别的 change

$ npx bats test/test_gate_freshness.bats
ok 1..14（14/14）
```

## 6 维自查

| 维 | 结论 |
|---|---|
| 认知负担 | `check_dist` 从"映射硬编码 + 两个不对称循环"变为"三张表 + 三个语义化循环"，分支减少、语义外显 |
| 变更传播 | 单一映射后，"改打包映射只需改一处"成为结构性事实（原先需两处同步） |
| 知识重复 | 三处注释重复清零；工件解析逻辑集中到 `spec_target()` 一处 |
| 意外复杂度 | 未引入新文件/新依赖/新门禁；`--entry-class` 是最小可测化改造 |
| 依赖方向 | `verify-claims.sh` → `sync-hooks.sh --entry-class`（同级工具互调，单向、无环） |
| 领域模型 | "本 change"这一概念现在**只有一种解析路径**，且解析结果显式可见（不再隐式替换对象） |

## 越界检查（必填）

- **未触碰 DESIGN §0.5.1 的禁用清单**：`hooks/**`、`prompts/**`、`dsh-flow-kit/lib/*.js`、`package-flow-kit.sh`、`.gitignore` 均零改动。
- `git status` 显示的本 change 改动集 = 上表 6 个文件 + `.specs/**` 工件 + `.brooks-lint-history.json`。
- 无新增依赖、无网络调用、无权限提升。

## 完成判定

- 7 条 AC（`REQUIREMENT.md`）全部有"修复前失败 / 修复后通过"的双向实测。
- `make check` 6 门全绿；`verify-claims` 三条工件断言核到**本 change**且 ❌=0。
- 🟡 全部闭环；🟢 全部闭环；新延后项 4 条已登记 `MINOR-DEFERRED.md`（均附理由）。
