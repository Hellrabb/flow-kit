# TASK: auto-checkpoint 收尾——BW01/02/03 三项品质提升

- **Change ID**: `checkpoint-polish`
- **关联**: `@.specs/checkpoint-polish/REQUIREMENT.md`、`@.specs/checkpoint-polish/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T04[P], T05[P]   （BW01 新 lib / BW02 CHANGELOG / BW03 Makefile · 互不冲突）
Wave 2 (parallel): T02[P], T03[P]           （BW01 集成 + 测试 · depends on T01）
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending">
  <name>BW01 · 创建 banner.sh —— 抽取 build_resume_banner() 函数</name>
  <read_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/stop/lib/banner.sh
  </write_files>
  <action>
    从 flow-kit-resume.sh L201-254 提取 banner 构建逻辑为独立 sourceable 函数 build_resume_banner()。
    函数签名为 build_resume_banner(flow_file_path: string) → stdout。
    沿用 checkpoint-lib.sh 的 sourceable lib 模式（纯函数定义，无 main 入口，fail-open 容错）。
    函数内部：读取 flow_file JSON → 提取 change_id/phase/task_id/interrupt/goal/token_spent 字段 → 组装 ASCII art banner → echo 到 stdout。
    保留原 banner 的逐字符格式（框线字符、字段宽度、对齐方式）。
    如 flow_file 不存在或 JSON 解析失败，输出错误信息到 stderr，返回非零退出码（健壮性 NFR）。
  </action>
  <verify>bash -n flow-kit-bundle/hooks/stop/lib/banner.sh && echo "✅ syntax OK"</verify>
  <done>banner.sh 通过 bash -n 语法检查；函数签名符合 D2（单函数 + stdout 输出）；可从 shell source 且不产生副作用</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending">
  <name>BW01 · 集成 —— flow-kit-resume.sh 改为 source banner.sh + 调用函数</name>
  <read_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
    flow-kit-bundle/hooks/stop/lib/banner.sh
  </read_files>
  <write_files>
    flow-kit-bundle/hooks/session-start/flow-kit-resume.sh
  </write_files>
  <action>
    修改 flow-kit-resume.sh：
    1. 在脚本顶部（source common.sh 之后）添加 source banner.sh（含健壮性检测：source 失败则输出错误到 stderr 并 return 1）
    2. 删除 L201-254 的内联 banner 构建代码
    3. 在删除位置插入 build_resume_banner "$flow_file" 调用
    4. 保留 L1-199 的 phase 检测 + change_id/task_id 提取逻辑不变
    5. 保留 L201 的 # ── Build banner ── 注释行作为调用点标记
  </action>
  <verify>bash -n flow-kit-bundle/hooks/session-start/flow-kit-resume.sh && echo "✅ syntax OK" && echo "⚠️ AC-1 diff verify: 请运行重构前后 flow-kit-resume.sh 对比 banner 输出"</verify>
  <done>resume.sh 通过 bash -n；banner 输出与重构前逐字符一致（AC-1 diff 验证）；SessionStart hook 功能不退化</done>
  <depends_on>T01</depends_on>
</task>

<task id="T03" parallel="true" status="pending">
  <name>BW01 · 创建 test_resume_banner.bats 测试</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/banner.sh
    test/test_checkpoint_lib.bats
  </read_files>
  <write_files>
    test/test_resume_banner.bats
  </write_files>
  <action>
    创建 bats 测试文件 test/test_resume_banner.bats，覆盖 AC-2：
    1. setup(): source banner.sh，构造临时 .flow-active JSON（含 change_id/phase/goal/interrupt/token_spent 字段）
    2. @test "banner 输出含 change_id"：run build_resume_banner → assert_output 含 change_id
    3. @test "banner 输出含 phase 标签"：assert_output 含 phase 编号和中文标签
    4. @test "banner 输出含 goal 条件"：assert_output 含 goal condition 文本
    5. @test "banner 输出含 interrupt 信息"：assert_output 含中断描述 + 文件路径
    6. @test "缺失 flow_file 时输出错误"：run build_resume_banner /nonexistent → assert_failure + stderr 非空
    沿用 test/test_checkpoint_lib.bats 的 setup 范式（source lib + 临时文件构造）。
  </action>
  <verify>npx bats test/test_resume_banner.bats --formatter tap && npx bats test/ --formatter tap 2>&1 | tail -3 && echo "✅ AC-3 全量回归 0 fail"</verify>
  <done>所有 bats 测试通过（≥5 条 new + 全量回归 0 fail）；覆盖 AC-2 字段验证 + AC-3 全量不退化 + 健壮性 NFR 缺失文件场景</done>
  <depends_on>T01</depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>BW02 · 统一 CHANGELOG.md 为紧凑单行 pipe 格式</name>
  <read_files>
    .specs/CHANGELOG.md
  </read_files>
  <write_files>
    .specs/CHANGELOG.md
  </write_files>
  <action>
    修改 .specs/CHANGELOG.md：
    1. 备份：cp .specs/CHANGELOG.md .specs/CHANGELOG.md.bak
    2. 找到并删除独立表头行 `| 日期 | Change ID | 摘要 | LESSONS |`（及其上方的空行）
    3. 确认下部标准表头格式条目（30 条）已是紧凑单行 pipe 格式（与顶部 8 条一致）
    4. 如发现格式不统一的条目，改写为 `| YYYY-MM-DD | change-id | 摘要 | LESSONS |` 格式
    5. 验证 grep -c '^| 202[0-9]' 前后条目数一致（AC-5）
    6. 验证 grep -c '^| 日期 | Change ID' 返回 0（AC-4）
  </action>
  <verify>BEFORE=$(grep -c '^| 202[0-9]' .specs/CHANGELOG.md.bak) && AFTER=$(grep -c '^| 202[0-9]' .specs/CHANGELOG.md) && test "$BEFORE" -eq "$AFTER" && grep -c '^| 日期 | Change ID | 摘要 | LESSONS |$' .specs/CHANGELOG.md | xargs test 0 -eq && echo "✅ CHANGELOG format unified ($AFTER entries, 0 header lines)"
  <done>独立表头行已删除；所有 38 条目统一为紧凑 pipe 格式；条目数不变（AC-4 + AC-5）</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="pending">
  <name>BW03 · 新增 make test-sync target + 集成到 make check</name>
  <read_files>
    Makefile
    test/
    flow-kit-bundle/test/
  </read_files>
  <write_files>
    Makefile
  </write_files>
  <action>
    修改 Makefile：
    1. 在 .PHONY 行追加 test-sync
    2. 在 check-test-sync target 之前新增 test-sync target：
       ```
       # ── test-sync: 同步 test/ → flow-kit-bundle/test/ ──
       test-sync:
           @echo "🔄 make test-sync: test/ → flow-kit-bundle/test/ ..."
           @if [ ! -d flow-kit-bundle/test ]; then \
               echo "❌ flow-kit-bundle/test/ 不存在"; exit 1; \
           fi
           @cp test/*.bats flow-kit-bundle/test/ && echo "✅ test 双源已同步" || { echo "❌ 同步失败"; exit 1; }
       ```
    3. check-test-sync 的报错信息追加提示 `请运行 make test-sync`
    4. 沿用既有 Makefile recipe 风格（@echo 标题 + 检测 + 非零退出）
  </action>
  <verify>make test-sync && make check-test-sync && echo "✅ test-sync OK"</verify>
  <done>make test-sync 成功同步 test/ → bundle/test/；make check 调用 check-test-sync 检测不同步（AC-6 + AC-7）</done>
  <depends_on></depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 [P] 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在文件末尾「阻塞日志」记录）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
