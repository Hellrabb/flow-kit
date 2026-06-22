# TASK: 同步说明文档与近期修改

- **Change ID**: docs-sync
- **路径**: 中等（跳过 DESIGN，直入 TASK → DEV → TEST → REVIEW → INTEGRATION）
- **说明**: 纯文档更新，无架构变更，无需 DESIGN.md

---

## 波次划分

```
Wave 1 (parallel): T01[P] · T02[P] · T03[P] · T04[P]
Wave 2:            T05 (depends on T01, T02, T03, T04 — 需全局视图)
Wave 3:            T06 (depends on T05 — 最终一致性检查)
```

---

## 任务列表

### Wave 1（可并行）

<task id="T01" parallel="true">
  <name>FLOW-KIT-用户指南.md §8 — 新增 brooks-tools 离线打包子节</name>
  <read_files>
    FLOW-KIT-用户指南.md
    .specs/CONTEXT.md
    flow-kit-bundle/lib/install_brooks.sh
    flow-kit-bundle/install.sh
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
  </write_files>
  <action>
    在 §8 (brooks-lint 代码审查插件) 末尾新增子节 "8.1 brooks-tools 离线打包"。
    内容要点：
    - brooks-tools 是什么：depcheck/jscpd/knip/ts-prune 四个 npm 工具
    - 为什么需要离线打包：pnpm 虚拟存储依赖符号链接无法跨机迁移
    - 打包方式：npm pack 逐工具打包 .tgz，解压出扁平 node_modules
    - 安装行为：install.sh 检测到 node 可用时自动安装，可用 --no-brooks-tools 跳过
    - 目标路径：~/.claude/tools/brooks-lint/
    - shim 机制：~/.local/bin/ 下的 wrapper 映射到真实可执行文件
    参考 CONTEXT.md 术语表中 "brooks-tools"、"npm pack"、"shim"、"扁平 node_modules" 的定义。
  </action>
  <verify>grep -c "brooks-tools" FLOW-KIT-用户指南.md | xargs -I{} test {} -ge 3</verify>
  <done>用户指南 §8 含 brooks-tools 子节，grep "brooks-tools" 命中 ≥3 次（对应 AC-1）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true">
  <name>FLOW-KIT-用户指南.md §4.1.2 — 更新 Pipeline 执行链描述</name>
  <read_files>
    FLOW-KIT-用户指南.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
  </write_files>
  <action>
    检查 §4.1.2 (Pipeline Goal) 并修正：
    - 若文中仍有"仅覆盖 4→7"等过时表述，改为明确说明支持 --from 0 从任意阶段起步
    - 执行链写为 0→1→2→2a→3→4→5→6→7
    - start_phase 字段说明完整（默认 "4"，可通过 --from 0 覆盖）
    - 与 CONTEXT.md 中 pipeline goal 相关术语保持一致
    注：根据 ctx_execute_file 分析，§4.1.2-4.1.4 已有 PCSC/PG/Rollback 内容，本任务仅做小修（补全 --from 0 细节 + 修正过时描述）。
  </action>
  <verify>grep -cE "\-\-from 0|start_phase|0→1→2" FLOW-KIT-用户指南.md | xargs -I{} test {} -ge 3</verify>
  <done>Pipeline 描述明确支持 0→7 全链，无"仅 4→7"过时表述（对应 AC-2）</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true">
  <name>README.md — 更新项目结构树与快速开始</name>
  <read_files>
    README.md
    .specs/CONTEXT.md
    flow-kit-bundle/
  </read_files>
  <write_files>
    README.md
  </write_files>
  <action>
    1. 项目结构树修正：
       - 移除 ".specs/init-git-repo/ 当前活跃 change"（过时）
       - 补充 flow-kit-bundle/lib/ 目录
       - 补充 test/ 目录（bats-core 72 tests）
       - 补充 .specs/ 下完整子目录（CONTEXT.md / STATE.md / CHANGELOG.md / LESSONS.md / health/ / archive/）
    2. 快速开始命令修正：
       - "bash flow-kit-bundle.tar.gz" → 正确的安装流程（tar xzf + cd + bash install.sh）
    3. 版本号/日期标记更新（如存在）
  </action>
  <verify>bash -c 'for d in "flow-kit-bundle/lib" "test" ".specs/archive" ".specs/health"; do ls -d "$d" >/dev/null 2>&1 || { echo "MISSING: $d"; exit 1; }; done && echo "OK"'</verify>
  <done>README.md 结构树与实际目录一致，快速开始命令可执行（对应 AC-3）</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true">
  <name>flow-kit-ecosystem-guide.md — 补充近期新组件</name>
  <read_files>
    flow-kit-ecosystem-guide.md
    .specs/CONTEXT.md
    FLOW-KIT-用户指南.md
  </read_files>
  <write_files>
    flow-kit-ecosystem-guide.md
  </write_files>
  <action>
    更新生态组件清单，补充以下近期新增：
    - 层 1（核心引擎）：PCSC/PG 双层防护机制、Pipeline Rollback 智能回退
    - 层 1（核心引擎）：Pipeline Goal 系统（--from 0、toll-gate、auto_advance）
    - 层 5（brooks-lint）：brooks-tools 离线打包（npm pack + shim 机制）
    - 版本号/日期更新（如存在过时标记）
    术语需与 CONTEXT.md 术语表一致。
    注意：ecosystem-guide 是架构概览，不是用户指南——只写"有什么、在哪、干什么"，不写"怎么用"。
  </action>
  <verify>grep -cE "PCSC|PCG|rollback|brooks-tools" flow-kit-ecosystem-guide.md | xargs -I{} test {} -ge 4</verify>
  <done>ecosystem-guide 覆盖 PCSC/PG/Rollback/brooks-tools，≥4 处独立提及（对应 AC-4）</done>
  <depends_on></depends_on>
</task>

### Wave 2

<task id="T05">
  <name>全局清理 — 过时版本号、路径、命令示例</name>
  <read_files>
    FLOW-KIT-用户指南.md
    README.md
    flow-kit-ecosystem-guide.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    FLOW-KIT-用户指南.md
    README.md
    flow-kit-ecosystem-guide.md
  </write_files>
  <action>
    三份文档全局扫描并修正：
    1. 版本号：20260615 → 20260622（或更新）
    2. 过时路径：移除 "init-git-repo 当前活跃" 等已归档 change 的引用
    3. 命令示例：逐条审核，确保可直接执行（无 `bash flow-kit-bundle.tar.gz` 这类错误）
    4. 测试数量：确认 "72 tests" 与当前 test/ 目录一致
    5. 打包脚本引用：补充 Part G（brooks-tools 打包）
    6. 文件结构索引（§11）与实际目录对齐
  </action>
  <verify>bash -c '\
grep -rE "2026061[0-5]" FLOW-KIT-用户指南.md README.md flow-kit-ecosystem-guide.md && echo "FOUND_OLD_VERSION" && exit 1 || echo "VERSION_OK"; \
grep -rE "仅.*覆盖.*4.*7" FLOW-KIT-用户指南.md README.md flow-kit-ecosystem-guide.md && echo "FOUND_OUTDATED_PIPELINE" && exit 1 || echo "PIPELINE_OK"'</verify>
  <done>无过时版本号、无"仅 4→7"过时描述、命令示例可执行（对应 AC-5、AC-6）</done>
  <depends_on>T01, T02, T03, T04</depends_on>
</task>

### Wave 3

<task id="T06">
  <name>三文档一致性终检</name>
  <read_files>
    FLOW-KIT-用户指南.md
    README.md
    flow-kit-ecosystem-guide.md
    .specs/CONTEXT.md
    .specs/docs-sync/REQUIREMENT.md
  </read_files>
  <write_files>
    (无 — 仅读取检查)
  </write_files>
  <action>
    逐条对照 AC-1 ~ AC-6 进行终检：
    1. AC-1: grep -c "brooks-tools" FLOW-KIT-用户指南.md ≥ 3
    2. AC-2: grep -cE "--from 0|start_phase|0→1→2" FLOW-KIT-用户指南.md ≥ 3
    3. AC-3: 逐项验证 README 结构树中目录存在
    4. AC-4: grep -cE "PCSC|PCG|rollback|brooks-tools" flow-kit-ecosystem-guide.md ≥ 4
    5. AC-5: 人工审核所有命令示例
    6. AC-6: grep 确认无过时版本号/路径
    输出 PASS/FAIL 报告。任一 FAIL → 回到对应 task 修复。
  </action>
  <verify>bash .specs/docs-sync/verify-all-ac.sh 2>/dev/null || echo "MANUAL_CHECK_NEEDED"</verify>
  <done>全部 6 条 AC 验证通过</done>
  <depends_on>T05</depends_on>
</task>

---

> 任务粒度：每个任务 2~5 分钟可完成（纯文档编辑）。T01-T04 完全并行（不同文件或不同节，无冲突）。T05 需等 T01-T04 完成后做全局扫描。T06 是终检。
