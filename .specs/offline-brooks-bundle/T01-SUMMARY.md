# T01-SUMMARY: 重构 Part F brooks-lint 打包逻辑

- **Change ID**: `offline-brooks-bundle`
- **Task ID**: `T01`
- **状态**: ✅ done

---

## 做了什么

1. 变量声明新增 `BROOKS_SRC=""`（L223）
2. 参数解析新增 `--brooks-src) BROOKS_SRC="$2"; shift ;;`（L261）
3. Part F 重写为三级优先级：
   - ① `--brooks-src` 指定路径 → rsync
   - ② 本地缓存 `~/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/<latest>/` → rsync + 自动选最新版
   - ③ Fallback：原有 git archive 逻辑（不变）
4. F1（commands）保持不变
5. 日志输出标注来源：`--brooks-src <path>` / `本地缓存 vX.Y.Z` / `git archive（fallback）`

## 改动文件

- `package-flow-kit.sh`（+30 −5 行，仅 Part F + 参数解析段）

## verify 输出

```
bash -n package-flow-kit.sh → syntax OK
BROOKS_CACHE: 5 references
BROOKS_SRC: 5 references
rsync brooks-lint: 1
sort -V: 1
git archive (fallback): 7
--brooks-src param: present
```

## 6 维自查（R6.4）

Shell 脚本修改 ≤ 30 行，沿用既有模式（flag 变量 + case/if 结构）。跳过 brooks-review。

## 越界检查（R6.5）

- TASK write_files：`package-flow-kit.sh`
- 实际 diff：`package-flow-kit.sh` 1 个文件
- 越界：0 ✅
- install_brooks_lint() 未修改 ✅
