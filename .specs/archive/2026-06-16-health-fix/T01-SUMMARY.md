# T01-SUMMARY: 安装 bats-core + 创建 test/ 目录骨架

- **Task ID**: T01
- **状态**: done
- **完成时间**: 2026-06-16

## 做了什么

1. 检测 bats 安装状态：`bats` 未安装（无 sudo 权限），但 `npx bats` 可用（v1.13.0）
2. 创建 `test/` 目录
3. 编写 `test/test_common.bats`：覆盖 `common.sh` 6 个核心函数（config_get × 3 / module_enabled × 3 / check_enabled × 3 / is_subagent × 3 / file_not_empty × 3 / line_count × 2），共 17 个测试，无 jq 时 skip
4. 编写 `test/test_install.bats`：覆盖 `install.sh` 10 个参数 + --help，共 11 个测试，全部 dry-run 模式

## 改了哪些文件

| 文件 | 操作 |
|------|------|
| `test/test_common.bats` | 创建（17 tests） |
| `test/test_install.bats` | 创建（11 tests） |

## verify 输出

```
npx bats test/
1..28
ok 1 config_get returns value for existing key
ok 2 config_get returns default for missing key
...
ok 28 --help shows usage
28 ok, 0 failed
```

## 6 维自查（内置回退）

| 维度 | 结果 |
|------|------|
| R1 认知过载 | ✅ 测试文件简洁，每函数 ≤ 20 行 |
| R2 变更传播 | ✅ 仅创建 test/ 目录，无越界 |
| R3 知识重复 | ✅ setup/teardown 复用 bats 内置机制 |
| R4 偶然复杂 | ✅ 无过度抽象 |
| R5 依赖混乱 | ✅ 无新增依赖 |
| R6 领域扭曲 | ✅ 测试命名清晰对应被测函数 |

## 越界检查（R6.5）

```
✅ TASK write_files：test/test_common.bats, test/test_install.bats
✅ 实际 diff 涉及：test/test_common.bats, test/test_install.bats
✅ 越界：0
```

## 发现

- `common.sh` 第 9 行 `CONFIG_FILE=""` 会在 source 时覆盖调用方设置的值——测试需在 source 之后设置 `CONFIG_FILE`
- `module_enabled`/`check_enabled` 内部用 `.modules.${mod}.enabled` 拼接 jq 路径——若 mod 名含连字符（如 `claude-md`），jq 解析为 `claude - md` 导致错误。这是已知 bug，应在后续修复
