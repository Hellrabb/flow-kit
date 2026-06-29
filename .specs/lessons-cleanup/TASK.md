# TASK: lessons-cleanup

- **Change ID**: `lessons-cleanup`
- **关联**: `@.specs/lessons-cleanup/REQUIREMENT.md`、`@.specs/lessons-cleanup/DESIGN.md`
- **总计**: 6 tasks / 3 waves

---

## 波次划分

```
Wave 1 (parallel): T01[P]  L-013 归档双向校验
                    T02[P]  L-012 打包完整性校验
                    T03[P]  L-010 1.8 自动 bats

Wave 2 (parallel): T04[P]  skill 同步（flow-integration + flow-dev）
                    T05[P]  bats 测试（AC-1~AC-6）

Wave 3:            T06     文档收尾（LESSONS + CONTEXT + CHANGELOG）
```

---

## Wave 1

<task id="T01" parallel="true">
  <name>L-013：7-integration prompt §5 归档段加双向校验</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/templates/TASK.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    在 7-integration prompt 的 §5 "归档（ARCHIVE）" 段末尾追加两个子步骤：
    
    ① 清理工作目录：归档（mv 完成）后，确认 PROGRESS.md 已存在于 archive 目标目录，
       然后 rm -rf .specs/<change-id>/。加 L2 自检 gate 填空项："归档后工作目录已删除：[ ] test ! -d .specs/<id>/"。
    
    ② 扫描孤儿 change：遍历 .specs/ 下非 archive 目录，对每个目录 grep REVIEW✅/PASS + TASK 全 done
       + test ! -d archive/*<dir>。命中则输出警告行："⚠️ <dir> 已完成但未归档，建议跑 /flow-go 上线"。
    
    同时更新 prompt 末尾的 PCSC 自检表加一项："归档后 .specs/<id>/ 工作目录已删除"。
    
    遵循 DESIGN D1 决策：纯 prompt 指令，不额外创建 bash 脚本。
  </action>
  <verify>grep -c "rm -rf.*specs.*change-id\|orphan\|已完成但未归档\|工作目录已删除" flow-kit-bundle/flow-kit/prompts/7-integration.md</verify>
  <done>AC-1（归档后工作目录被删除）和 AC-2（孤儿 change 被扫描并提示）的逻辑已写入 prompt</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>L-012：package-flow-kit.sh 加 --validate 完整性校验</name>
  <read_files>
    package-flow-kit.sh
    flow-kit-bundle/
  </read_files>
  <write_files>
    package-flow-kit.sh
  </write_files>
  <action>
    在 package-flow-kit.sh 中新增 --validate flag 和 validate_staging_coverage() 函数：
    
    ① 解析 Part A~G 的 cp/rsync/mkdir 指令，提取每条指令的"源→目标"映射：
       - cp src dst → 期望 dst 存在且来自 src
       - rsync -a src/ dst/ → 期望 dst 目录内容 ⊆ src 目录内容
       - mkdir -p dir → 期望 dir 存在
       - for 循环内的 cp/mkdir → 展开 glob 后同规则
    
    ② find flow-kit-bundle/ -type f | sort 获取实际文件清单
    
    ③ 对账：实际存在但期望未覆盖 → ERROR（漏配）；期望但实际不存在 → WARNING（源缺失）
    
    ④ exit code: 0=通过, 1=有漏配, 2=脚本错误
    
    入口：case "$1" in --validate) validate_staging_coverage; exit ;; esac
    不改变现有无参数默认打包行为（DESIGN D4）。
  </action>
  <verify>bash package-flow-kit.sh --validate; echo "exit=$?"</verify>
  <done>AC-3（漏配报错 exit≠0）和 AC-4（正常通过 exit=0）的校验逻辑已实现</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true">
  <name>L-010：4-dev prompt §1.8.4 加自动 bats 执行 + 失败阻断</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
  </write_files>
  <action>
    在 4-dev prompt §1.8.4 "回归测试覆盖" 段增强以下内容：
    
    ① 自动执行：在 1.8.3 反问用户确认后，自动运行 `npx bats test/`（或 `npx bats test/ --formatter tap`）。
       先检查 bats 是否可用（`npx bats --version`），不可用时降级为 WARNING 而非阻断。
    
    ② 结果判定：
       - 0 failures → ✅ 输出"bats: N tests, 0 failures"摘要，继续
       - ≥1 failure → 🔴 阻断：输出失败测试清单（grep "not ok"），暂停流程，
         禁止进入 toll-gate，提示"修复以上测试失败后重跑 `npx bats test/`"
    
    ③ 结果写入 SUMMARY：在 1.8.5 的 SUMMARY「破坏性变更」段加 bats 结果字段（N tests, M failures, N-M passed）
    
    ④ L2 自检 gate：在 4-dev PCSC 表加一项"1.8 触发时 bats 已跑且 0 fail：[ ] npx bats test/ 输出确认"
    
    不改 1.8.1~1.8.3 和 1.8.5~1.8.6 的结构（DESIGN D5）。
  </action>
  <verify>grep -c "npx bats\|bats.*test/\|0 failures\|失败阻断\|bats --version" flow-kit-bundle/flow-kit/prompts/4-dev.md</verify>
  <done>AC-5（1.8 触发后自动跑 bats）和 AC-6（bats 失败阻断）的逻辑已写入 prompt</done>
  <depends_on></depends_on>
</task>

---

## Wave 2

<task id="T04" parallel="true">
  <name>skill 同步：flow-integration + flow-dev SKILL.md 对齐 prompt 改动</name>
  <read_files>
    flow-kit-bundle/skills/flow-integration/SKILL.md
    flow-kit-bundle/skills/flow-dev/SKILL.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
  </read_files>
  <write_files>
    flow-kit-bundle/skills/flow-integration/SKILL.md
    flow-kit-bundle/skills/flow-dev/SKILL.md
  </write_files>
  <action>
    将 T01 和 T03 的 prompt 改动同步到对应 skill 文件：
    
    ① flow-integration/SKILL.md：同步 T01 的归档双向校验逻辑（清理工作目录 + 扫描孤儿 change）。
       找到 skill 中对应 prompt §5 归档段的协议描述，追加相同的两个子步骤。
    
    ② flow-dev/SKILL.md：同步 T03 的 1.8.4 自动 bats 执行 + 失败阻断逻辑。
       找到 skill 中对应 prompt §1.8.4 段的协议描述，追加 bats 自动执行指令。
    
    两处同步保持与 prompt 相同的措辞和 L2 自检 gate 填空项。
    这是 DESIGN 中识别的"prompt↔skill 协议双入口"模式——本次手动同步，quality-baseline change 会做 DRY 提取。
  </action>
  <verify>grep -c "rm -rf.*specs\|orphan\|已完成但未归档" flow-kit-bundle/skills/flow-integration/SKILL.md && grep -c "npx bats\|0 failures\|失败阻断" flow-kit-bundle/skills/flow-dev/SKILL.md</verify>
  <done>两个 skill 文件已包含与 prompt 一致的归档校验和 bats 阻断逻辑</done>
  <depends_on>T01 T03</depends_on>
</task>

<task id="T05" parallel="true">
  <name>bats 测试：覆盖 AC-1~AC-6</name>
  <read_files>
    test/
    package-flow-kit.sh
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    .specs/lessons-cleanup/REQUIREMENT.md
  </read_files>
  <write_files>
    test/test_lessons_cleanup.bats
  </write_files>
  <action>
    创建 test/test_lessons_cleanup.bats，覆盖以下场景：
    
    AC-1：模拟归档完成场景——创建临时 .specs/<id>/ 含 PROGRESS.md → 执行归档校验函数 → 确认目录被删除
    AC-2：模拟孤儿 change 场景——创建 .specs/orphan-demo/ 含 REVIEW✅ + TASK done → 运行扫描 → grep 输出含 "orphan-demo"
    AC-3：模拟漏配场景——临时在 flow-kit-bundle/ 下加目录 → 跑 --validate → exit code ≠ 0 + stderr 含目录名
    AC-4：正常场景——干净仓库跑 --validate → exit code = 0
    AC-5：模拟 1.8 触发——检查 4-dev prompt 中是否含 `npx bats test/` 指令（grep 验证）
    AC-6：模拟 bats 失败阻断——检查 prompt 中是否含失败阻断措辞（grep 验证）
    
    使用 bats setup/teardown 的 mktemp 隔离临时文件，不污染真实仓库。
    注：AC-5/AC-6 是 prompt 文本检查（验证 prompt 写了正确指令），不是运行时 bats 集成测试。
  </action>
  <verify>npx bats test/test_lessons_cleanup.bats --formatter tap</verify>
  <done>6 条 AC 全部有对应的 bats 测试且通过（0 failures）</done>
  <depends_on>T01 T02 T03</depends_on>
</task>

---

## Wave 3

<task id="T06">
  <name>文档收尾：LESSONS + CONTEXT + CHANGELOG 更新</name>
  <read_files>
    .specs/LESSONS.md
    .specs/CONTEXT.md
    .specs/CHANGELOG.md
  </read_files>
  <write_files>
    .specs/LESSONS.md
    .specs/CONTEXT.md
    .specs/CHANGELOG.md
  </write_files>
  <action>
    ① LESSONS.md：将 L-010、L-012、L-013 三条从「技术债清单」移至「已解决」段，
       标注修复提交 hash 和解决日期。每条写一行修复摘要。
    
    ② CONTEXT.md：确认术语表中已加入 T01/T02/T03 引入的新术语（在 phase 1 已加：
       归档双向校验、打包完整性校验、1.8 恢复验证、lessons-cleanup）。
       在「已锁决策」段追加本次的决策（D1/D3/D5 的关键项）。
    
    ③ CHANGELOG.md：追加 lessons-cleanup 行，含日期、change-id、一句话摘要。
  </action>
  <verify>grep -c "L-010.*resolved\|L-012.*resolved\|L-013.*resolved\|已解决" .specs/LESSONS.md && grep -c "lessons-cleanup" .specs/CHANGELOG.md</verify>
  <done>LESSONS.md 三条债标为 resolved，CHANGELOG 已追加</done>
  <depends_on>T04 T05</depends_on>
</task>

---

## 依赖图

```
Wave 1:  T01 [P]  T02 [P]  T03 [P]
            \       |       /
             \      |      /
Wave 2:     T04 [P]    T05 [P]
                \       /
                 \     /
Wave 3:           T06
```
