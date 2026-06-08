# TEST: 打包脚本离线化 brooks-lint 分发

- **Change ID**: `offline-brooks-bundle`

---

## 本次测试范围声明

| 轮次 | 状态 | 范围 | 跳过理由 |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 5 条 AC | — |
| 第 2 轮 · 性能 | ❌ 跳过 | — | Bash 脚本修改 ≤ 30 行，无运行时性能影响 |
| 第 3 轮 · 安全 | ❌ 跳过 | — | 无新增依赖/API/凭据；rsync 源路径已校验非空 |
| 第 4 轮 · 兼容 | ⚠️ 部分 | bash -n 语法检查 | rsync 是 Linux 标配；sort -V GNU 扩展 |
| 第 5 轮 · 可观测 | ❌ 跳过 | — | 无运行时服务 |

---

## 第 1 轮 · 功能测试

| AC | 验证 | 结果 |
|---|---|---|
| AC-1 | 本地缓存 `1.3.0/` 存在，rsync 语法正确 | ✅ |
| AC-2 | `--brooks-src` 参数解析 + 变量使用 | ✅ |
| AC-3 | `git archive` fallback 保留 | ✅ |
| AC-4 | `sort -V` 版本选择 | ✅ |
| AC-5 | `install_brooks_lint()` 未修改 | ✅ |

## 第 4 轮 · 兼容（部分）

- `bash -n package-flow-kit.sh` → syntax OK ✅
- `sort -V` 是 GNU coreutils 扩展（Linux 标配），macOS 需 `brew install coreutils` → 仅在打包机上运行，打包机是 Linux ✅
