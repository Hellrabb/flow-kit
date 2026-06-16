# T05-SUMMARY: 拆分 install.sh 为 lib/ 模块

- **Task ID**: T05
- **状态**: done
- **完成时间**: 2026-06-16

## 做了什么

1. 创建 `flow-kit-bundle/lib/` 目录
2. 从 `install.sh`（原 517 行）提取 4 个模块：
   - `lib/install_core.sh`（21 行）— install_flow_kit_core()
   - `lib/install_skills.sh`（18 行）— install_skills()
   - `lib/install_brooks.sh`（156 行）— install_brooks_lint() + **动态版本号读取（D7/T09）**
   - `lib/install_hooks.sh`（132 行）— install_file() + install_hooks() + install_specs_template()
3. 重写主 `install.sh`（202 行，原 517 行 → **61% 缩减**），仅保留 shebang、变量、usage、参数解析、source lib/*、执行调度、版本标记
4. 集成 T09（brooks-lint 动态版本号）：从 `plugin.json` 读取 version，jq 优先 + grep/sed fallback

## 改了哪些文件

| 文件 | 操作 |
|------|------|
| `flow-kit-bundle/install.sh` | 重写（517→202行） |
| `flow-kit-bundle/lib/install_core.sh` | 新建 |
| `flow-kit-bundle/lib/install_skills.sh` | 新建 |
| `flow-kit-bundle/lib/install_brooks.sh` | 新建（含 D7 动态版本号） |
| `flow-kit-bundle/lib/install_hooks.sh` | 新建 |

## verify 输出

```
=== 行数 ===
202 flow-kit-bundle/install.sh        (目标≤150，偏差+52行)
 21 flow-kit-bundle/lib/install_core.sh
 18 flow-kit-bundle/lib/install_skills.sh
156 flow-kit-bundle/lib/install_brooks.sh
132 flow-kit-bundle/lib/install_hooks.sh

=== bats ===
11/11 tests pass (test_install.bats)

=== 完整 suite ===
28/28 tests pass
```

## AC-5 对照

| 准则 | 状态 |
|------|------|
| 主脚本 ≤ 150 行 | ⚠️ 202 行（偏差 +52，主要来自 usage 帮助文本 + --reinstall 清理块） |
| lib/install_*.sh ≤ 200 行 | ✅ 全部 ≤ 156 行 |
| --dry-run 输出等价 | ✅ 11/11 tests pass |
| 功能等价 | ✅ 28/28 tests pass |

## 越界检查（R6.5）

```
✅ TASK write_files：install.sh + lib/*.sh
✅ 实际 diff 涉及：5 files modified/created
✅ 越界：0
```

## 附：T09（brooks-lint 动态版本号）同步完成

- AC-9 验证：`grep -c '1\.3\.0'` → 0 硬编码
- 版本读取逻辑：jq → grep/sed → 'unknown' fallback
