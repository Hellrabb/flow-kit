# TASK: 修掉「门禁守卫自身」的三处假绿（+ 三处可维护性）

- **Change ID**: brooks-review-fix-2026-09
- **关联**: `@.specs/brooks-review-fix-2026-09/REQUIREMENT.md`（7 条 AC）、`@.specs/brooks-review-fix-2026-09/DESIGN.md`（7 决策 / 6 风险）
- **形态**: 回溯登记 —— 下列 `write_files` 是**已发生事实的声明**，非事前约束（见 CHANGE.md「登记形态」）

---

## 波次划分

```
Wave 0 (前置):  T00                    —— 记录修复前基线（dist 整树哈希 + 三条假绿的复现），供 R2/AC-3 比对
Wave 1:         T01[P], T02[P]         —— package-dsh-plugin.sh（映射单一化） / sync-hooks.sh（判据提到作用域 + 出口）
Wave 1b:        T03                    —— verify-claims.sh（依赖 T02 的 --entry-class 出口做行为断言）
Wave 2:         T04                    —— test/test_gate_freshness.bats + make test-sync（依赖 T01/T02 的行为已定型）
Wave 3:         T05[P]                 —— 注释去重（三载体，互不重叠）
Wave 4:         T06                    —— 全量回归取证（make check + verify-claims 三态 + dist 重建）
```

> 同 wave = 可并行；跨 wave = 必须顺序。**T00 是取证步**：没有修复前基线就无法证明 AC-3 的"假绿存在"与"产物等价"。

---

## 任务清单

```xml
<task id="T00" parallel="false" status="done" model-tier="cheap">
  <name>前置取证：修复前基线（dist 整树哈希 + 三处假绿复现）</name>
  <read_files>
    package-dsh-plugin.sh
    verify-claims.sh
  </read_files>
  <write_files>
    （无 · 只取证不写码）
  </write_files>
  <action>
    ① `find dist/dsh-flow-kit -type f | sort | xargs sha256sum | sha256sum` → 记录为**产物等价基线**（525 文件 · 9c0b7b1e…）；
    ② `resolve_spec_artifact DESIGN.md`（无活跃 change）→ 记录其返回**别的 change** 的路径（AC-1 的"修复前实测行为"）；
    ③ HEAD 版 `package-dsh-plugin.sh` 放夹具里，移走 `dsh-flow-kit/lib` → 记录 `✅ 一致 rc=0`（AC-3 的"修复前实测行为"）。
  </action>
  <verify>
    H=$(find dist/dsh-flow-kit -type f | sort | xargs sha256sum | sha256sum | cut -d' ' -f1)
    [ "$H" = "9c0b7b1e7487929c7d8954aab2fdcfa65498f5b37c9b4579604dec4794e55f09" ] || echo "WARN: 基线与登记时不同（$H）"
  </verify>
  <done>三条基线数据已记入 REQUIREMENT 的「修复前实测行为」与 DESIGN R2</done>
</task>

<task id="T01" parallel="true" status="done" model-tier="standard">
  <name>package-dsh-plugin.sh：拷贝映射单一化 + 缺失语义与打包侧对齐</name>
  <read_files>
    package-dsh-plugin.sh
  </read_files>
  <write_files>
    package-dsh-plugin.sh
  </write_files>
  <action>
    实现 DESIGN D3 + D4：
    ① 新增 `COPY_DIRS` / `COPY_FILES` / `COPY_OPTIONAL` 三张表（元素 `<源>:<目标>`），**成为唯一映射**；
    ② 打包路径（无参数）改为遍历三张表（原第 1–4 步的逐条 `cp` 收敛为循环），必需项源缺失 → `exit 1`（与原先语义等价）；
    ③ `check_dist()` 同样遍历三张表：目录对正向逐文件 `cmp` + 反向残留；**删除 `[ -d "$src" ] || continue`**
       （改为报"源目录缺失（打包会失败）"并提示 dist 侧旧副本）；单文件与可选项按 D4 语义处置；
    ④ 保持 `--check` 的**只读契约**与未知参数 fail-closed（rc=2）不变。
  </action>
  <verify>
    bash -n package-dsh-plugin.sh && shellcheck -e SC1091 package-dsh-plugin.sh
    # 产物等价（R2 的缓解）：重建 dist 后整树哈希必须与 T00 基线一致
    bash package-dsh-plugin.sh >/dev/null && bash package-dsh-plugin.sh --check
    H=$(find dist/dsh-flow-kit -type f | sort | xargs sha256sum | sha256sum | cut -d' ' -f1)
    echo "重建后哈希: $H（应与 T00 基线一致 · 尚未新增 bats 时）"
  </verify>
  <done>check_dist 与打包步骤同读一份映射；源目录缺失不再静默通过；重建产物与基线逐字节一致</done>
</task>

<task id="T02" parallel="true" status="done" model-tier="standard">
  <name>sync-hooks.sh：真入口判据提到文件作用域 + 新增 --entry-class 自检出口</name>
  <read_files>
    sync-hooks.sh
  </read_files>
  <write_files>
    sync-hooks.sh
  </write_files>
  <action>
    实现 DESIGN D2：
    ① `PTU_ENTRIES` 与 `is_real_entry()` 从 `for root in "${DEST_ROOTS[@]}"` 循环体内**移到文件作用域**
       （与 `DEST_ROOTS` 同层；循环体内只留一行调用 + 简短交叉引用注释）；
    ② 新增参数 `--entry-class <rel>`：**无副作用**地打印 `entry:` / `library:` 并以 0/1 退出；缺参数 rc=2；
    ③ 用法提示同步更新；
    ④ 合并原重复的判据理由注释（🟢1 的其中一处）。
  </action>
  <verify>
    bash -n sync-hooks.sh && shellcheck -e SC1091 sync-hooks.sh
    bash sync-hooks.sh --check >/dev/null    # 既有行为不退化（漂移检查仍绿）
    bash sync-hooks.sh --entry-class pre-tool-use/gate-helpers.sh; [ $? -eq 1 ]
    bash sync-hooks.sh --entry-class pre-tool-use/independent-review-gate.sh; [ $? -eq 0 ]
    bash sync-hooks.sh --entry-class; [ $? -eq 2 ]
  </verify>
  <done>判据可被外部直调且分类正确；--check 模式行为不变</done>
</task>

<task id="T03" parallel="false" status="done" model-tier="standard">
  <name>verify-claims.sh：工件解析三态化 + §10c/§10d 判据改造 + _changed 收敛</name>
  <read_files>
    verify-claims.sh
    sync-hooks.sh                    <!-- 依赖 T02 的 --entry-class 出口 -->
    Makefile
  </read_files>
  <write_files>
    verify-claims.sh
  </write_files>
  <action>
    实现 DESIGN D1 + D5 + D6 + D7：
    ① 删 `resolve_spec_artifact()` 的**隐式历史回退**（原写死 `l3-review-defects-2026-09`）；
       改为三态（0 解析到 / 1 未指定 / 2 指定了找不到）+ `spec_target()` 统一处置；
    ② 新增位置参数 `<change-id>` `<base-ref>`；TARGET_ID 解析改为显式参数 > `.flow-active`；
    ③ §8/§9/§10c 的 ✅/❌ 文案**指名**解析到的路径；
    ④ §10d：删 ②（与 ① 同义）、④ 改**行为断言**（调 `sync-hooks.sh --entry-class` 两次，验库/真入口分类）；
    ⑤ §10c：`_changed` 收敛为 `git diff --name-only HEAD` + `git ls-files --others --exclude-standard`
       （+ `<base-ref>` 区间）；空集由 `✅` 改 `⏭ SKIP` 并写明核对范围；
    ⑥ 新增 `SKIP` 计数器与 `⏭` 输出；汇总行追加 `⏭ N`（保持既有正则 `复验结果: ✅ N  ❌ M` 可匹配）；
    ⑦ §10c 的重复标题行去重（🟢1 的另一处）。
  </action>
  <verify>
    bash -n verify-claims.sh && shellcheck -e SC1091 verify-claims.sh
    bash verify-claims.sh ghost-change-2099 >/dev/null 2>&1; [ $? -ne 0 ]   # 三态之 2 → FAIL
    bash verify-claims.sh 2>&1 | grep -c '⏭'                                 # 三态之 1 → ≥3（需无活跃 change）
    bash verify-claims.sh brooks-review-fix-2026-09 2>&1 | tail -3            # 三态之 0 → 核本 change
  </verify>
  <done>核不到对象时报 SKIP/FAIL 且绝不换对象；§10d 两条文本判据消失、行为判据在位；_changed 只剩两条 git 命令</done>
</task>

<task id="T04" parallel="false" status="done" model-tier="standard">
  <name>新增行为回归测试 test/test_gate_freshness.bats（14 例）并同步双源</name>
  <read_files>
    package-dsh-plugin.sh
    sync-hooks.sh
    test/test_check_gate_sync.bats   <!-- 既有 bats 风格参考 -->
  </read_files>
  <write_files>
    test/test_gate_freshness.bats
    flow-kit-bundle/test/test_gate_freshness.bats   <!-- 由 make test-sync 生成 -->
  </write_files>
  <action>
    实现 AC-2：把两道新门禁的**最关键行为**固定成可复算用例（真跑命令看退出码/输出，不 grep 源码文本）：
    ① 夹具自检：最小树打包成功 + 基线 `--check` rc=0；
    ② 陈旧内容 → rc=1 且**指名**文件；
    ③ 必需源目录被移走 → rc=1（T01 修掉的假绿）；
    ④ 删源文件、dist 留副本 → rc=1 反向残留；
    ⑤ 只读契约：`--check` 前后 dist 树哈希不变；
    ⑥ 未知参数 → rc=2；
    ⑦ 打包侧必需源缺失 → rc=1（与检查侧同语义）；
    ⑧ `--entry-class` 分类：库 rc=1 / 真入口 rc=0（T02 的判据本体行为）；
    ⑨ `--entry-class` 缺参数 → rc=2。
    **夹具策略**：破坏性用例全部打在 `$BATS_TEST_TMPDIR` 的最小同构树上（复制 `package-dsh-plugin.sh` + 造目录/文件 + 一个 dummy node 测试），**不碰仓库工作区**。
  </action>
  <verify>
    npx bats test/test_gate_freshness.bats        # 期望 ok 1..14
    make test-sync && diff -rq test/ flow-kit-bundle/test/
  </verify>
  <done>14/14 通过；双源一致；全量 bats 由 950 → 964 且 0 fail</done>
</task>

<task id="T05" parallel="true" status="done" model-tier="cheap">
  <name>注释去重（Makefile / verify-claims.sh / sync-hooks.sh 三载体）</name>
  <read_files>
    Makefile
    verify-claims.sh
    sync-hooks.sh
  </read_files>
  <write_files>
    Makefile
    verify-claims.sh
    sync-hooks.sh
  </write_files>
  <action>
    实现 AC-4：`Makefile:113-114` 两行同义注释合并为一条；`verify-claims.sh` §10c 的逐字重复标题行删除；
    `sync-hooks.sh` 判据理由的两段重复叙述合并（随 T02 的位置迁移一并完成）。
  </action>
  <verify>
    [ "$(grep -c 'dist/ 被 .gitignore 忽略' Makefile)" -eq 1 ]
    [ "$(grep -c '10c. DESIGN §0.5.1 覆盖全部被改文件' verify-claims.sh)" -eq 1 ]
  </verify>
  <done>三处重复各归一；无信息丢失（被删行的独有信息已并入保留行）</done>
</task>

<task id="T06" parallel="false" status="done" model-tier="standard">
  <name>全量回归取证：make check 6 门 + verify-claims 三态 + dist 重建</name>
  <read_files>
    Makefile
  </read_files>
  <write_files>
    .specs/brooks-review-fix-2026-09/TEST.md
  </write_files>
  <action>
    按 AC-7 取全量证据：`make check`（含 test/lint/check-validate/check-test-sync/check-hooks-sync/check-dist）、
    `bash verify-claims.sh`（默认三态）、`bash verify-claims.sh brooks-review-fix-2026-09`（本 change 全覆盖），
    并把实测数据写入 TEST.md（不抄快照，现场复算）。
  </action>
  <verify>
    make check
    bash verify-claims.sh > /tmp/t06_vc.log 2>&1; echo "rc=$?"; grep '复验结果' /tmp/t06_vc.log
  </verify>
  <done>6 门全绿 + verify-claims exit 0 且 ❌=0；数据写入 TEST.md</done>
</task>
```

## AC ↔ Task 覆盖矩阵

| AC | 覆盖任务 | 备注 |
|---|---|---|
| AC-1 工件三态 | T03 | 三态分别以 ghost id / 无参 / 本 change 三个调用验证 |
| AC-2 行为回归保护 | T04（+ T03 的 §10d 行为断言） | bats 14 例 + §10d 直调探针 |
| AC-3 映射单一 + 缺失语义 | T01（+ T00 基线） | 夹具 ③④⑦ 三例 + 产物等价哈希 |
| AC-4 注释去重 | T05（+ T02） | 两处 grep 计数 |
| AC-5 判据可直调 | T02（+ T04 ⑧⑨） | 四种分类 + 缺参数 |
| AC-6 `_changed` 收敛 | T03 | 负向断言（旧取法不存在）+ 正向取集 |
| AC-7 门禁不退化 | T06 | make check + verify-claims |

## 状态字段说明

`status` ∈ `pending` / `in_progress` / `done` / `blocked`。本 change 全部任务在登记时已为 `done`（回溯登记形态）。

## 阻塞日志

（无）

## Fix 任务（来自 REVIEW / INTEGRATION）

（待 6-review 填写）
