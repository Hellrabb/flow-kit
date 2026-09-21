#!/usr/bin/env bats
# test_gate_freshness.bats — 门禁「新鲜度」（check-dist）与「真入口」判据的**行为**回归保护
#
# 起因（brooks-review 2026-09-21 · 🟡 Coverage Illusion）：
#   health-fix-2026-09 新增的 check-dist / is_real_entry / --check 分流只有**变更期夹具**
#   （`.specs/<id>/verify/ac*.sh`，随归档冻结、不进 make test），而 verify-claims §10d 里
#   有两条判据是"grep 源码文本"—— 实测"只有定义、无任何调用点"的文件同样判通过（假绿）。
#   本文件把最关键的几条**行为**固定下来：真跑命令、看输出与退出码，不 grep 源码文本。
#
# 夹具策略：把 package-dsh-plugin.sh 复制进临时目录 + 造一棵最小同构树，
#   所有破坏性用例都在临时目录里做（不碰仓库工作区；本仓 AC-8 的同类要求）。

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

make_fixture() {
  FX="$BATS_TEST_TMPDIR/pkgfx"
  rm -rf "$FX"
  mkdir -p "$FX/dsh-flow-kit/lib" "$FX/dsh-flow-kit/test"
  mkdir -p "$FX/flow-kit-bundle"/{skills,flow-kit,hooks,brooks-lint}
  cp "$REPO_ROOT/package-dsh-plugin.sh" "$FX/"
  # 最小同构：目录对 / 必需单文件 / 可选文档 / 供打包期 node 单测与语法检查通过的最小件
  echo 'console.log(1)' > "$FX/dsh-flow-kit/lib/a.js"
  cat > "$FX/dsh-flow-kit/test/dummy.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert';
test('dummy', () => { assert.ok(true); });
JS
  echo '{"version":"9.9.9"}' > "$FX/dsh-flow-kit/package.json"
  for f in cordis.patch.yml README.md DESIGN.md; do echo x > "$FX/dsh-flow-kit/$f"; done
  for d in skills flow-kit hooks brooks-lint; do echo s > "$FX/flow-kit-bundle/$d/f.txt"; done
  echo g > "$FX/flow-kit-bundle/FLOW-KIT-用户指南.md"
  echo o > "$FX/flow-kit-bundle/OPENCODE-INSTALL.md"
  run bash -c "cd '$FX' && bash package-dsh-plugin.sh"
  [ "$status" -eq 0 ]
}

@test "夹具自检：打包成功（基线 dist 与源一致）" {
  make_fixture
  run bash -c "cd '$FX' && bash package-dsh-plugin.sh --check"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dist 与源一致"* ]]
}

@test "check-dist：dist 内容陈旧 → rc=1，且**指名**具体文件" {
  make_fixture
  echo tweak >> "$FX/dist/dsh-flow-kit/skills/f.txt"
  run bash -c "cd '$FX' && bash package-dsh-plugin.sh --check"
  [ "$status" -eq 1 ]
  [[ "$output" == *"陈旧"* ]]
  [[ "$output" == *"skills/f.txt"* ]]
}

@test "check-dist：必需源目录被移走 → rc=1（原实现静默 ✅ 的回归保护）" {
  make_fixture
  mv "$FX/flow-kit-bundle/hooks" "$FX/hooks-moved-away"
  run bash -c "cd '$FX' && bash package-dsh-plugin.sh --check"
  mv "$FX/hooks-moved-away" "$FX/flow-kit-bundle/hooks"
  [ "$status" -eq 1 ]
  [[ "$output" == *"源目录缺失"* ]]
  [[ "$output" == *"flow-kit-bundle/hooks"* ]]
}

@test "check-dist：dist 不存在 + 必需源也缺失 → rc=1（L3 阶段6 major 的回归保护）" {
  # 原实现：dist 不存在 → 直接 return 0（优雅降级），**不核源侧完整性** →
  # "dist 未构建 + 打包必败"也会放行。
  make_fixture
  rm -rf "$FX/dist"
  mv "$FX/dsh-flow-kit/lib" "$FX/lib-moved-away"
  run bash -c "cd '$FX' && bash package-dsh-plugin.sh --check"
  mv "$FX/lib-moved-away" "$FX/dsh-flow-kit/lib"
  [ "$status" -eq 1 ]
  [[ "$output" == *"必需源目录缺失"* ]]
}

@test "check-dist：dist 不存在 + 源完整 → rc=0（优雅降级仍保留）" {
  make_fixture
  rm -rf "$FX/dist"
  run bash -c "cd '$FX' && bash package-dsh-plugin.sh --check"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dist 不存在"* ]]
}

@test "check-dist：删源文件、dist 留旧副本 → rc=1（报必需源缺失 + 提示旧副本）" {
  make_fixture
  rm "$FX/dsh-flow-kit/DESIGN.md"
  run bash -c "cd '$FX' && bash package-dsh-plugin.sh --check"
  [ "$status" -eq 1 ]
  [[ "$output" == *"必需源文件缺失"* ]]
  [[ "$output" == *"旧副本"* ]]
}

@test "check-dist：必需源文件与 dist 副本**都不在** → rc=1（L3 阶段6 critical 的回归保护）" {
  # 原实现只查"反向残留"，源与 dist 都没有该文件时 fail 不置位 → 打包必败却报 ✅（假绿）
  make_fixture
  rm "$FX/dsh-flow-kit/cordis.patch.yml" "$FX/dist/dsh-flow-kit/cordis.patch.yml"
  run bash -c "cd '$FX' && bash package-dsh-plugin.sh --check"
  [ "$status" -eq 1 ]
  [[ "$output" == *"必需源文件缺失"* ]]
}

@test "check-dist：只读契约 —— 跑完不改动 dist 树" {
  make_fixture
  before="$(cd "$FX" && find dist -type f | sort | xargs sha256sum | sha256sum)"
  run bash -c "cd '$FX' && bash package-dsh-plugin.sh --check"
  after="$(cd "$FX" && find dist -type f | sort | xargs sha256sum | sha256sum)"
  [ "$before" = "$after" ]
}

@test "check-dist：未知参数 fail-closed → rc=2" {
  make_fixture
  run bash -c "cd '$FX' && bash package-dsh-plugin.sh --bogus"
  [ "$status" -eq 2 ]
  [[ "$output" == *"未知参数"* ]]
}

@test "打包侧：必需源目录缺失 → rc=1（与 check 侧同语义）" {
  make_fixture
  mv "$FX/flow-kit-bundle/skills" "$FX/skills-moved-away"
  run bash -c "cd '$FX' && bash package-dsh-plugin.sh"
  mv "$FX/skills-moved-away" "$FX/flow-kit-bundle/skills"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing"* ]]
}

@test "is_real_entry 行为：库 rc=1 / 真入口 rc=0（不 grep 源码文本）" {
  # 该判据此前只在 sync-hooks.sh 的循环体里被间接使用，测试只能 grep 源码文本 ——
  # 于是"定义了但没人调用"也判通过（brooks-review 2026-09-21 · 🟡2）。
  # 现走判据自检出口（无副作用）直调本体，分类错即红。
  run bash "$REPO_ROOT/sync-hooks.sh" --entry-class pre-tool-use/gate-helpers.sh
  [ "$status" -eq 1 ]
  run bash "$REPO_ROOT/sync-hooks.sh" --entry-class stop/lib/common.sh
  [ "$status" -eq 1 ]
  run bash "$REPO_ROOT/sync-hooks.sh" --entry-class pre-tool-use/independent-review-gate.sh
  [ "$status" -eq 0 ]
  run bash "$REPO_ROOT/sync-hooks.sh" --entry-class stop/00-gate.sh
  [ "$status" -eq 0 ]
}

@test "is_real_entry：--entry-class 缺参数 → rc=2（用法错误 fail-closed）" {
  run bash "$REPO_ROOT/sync-hooks.sh" --entry-class
  [ "$status" -eq 2 ]
}

@test "is_real_entry：--entry-class 未知前缀 → rc=2（拼错路径不得被静默判成库）" {
  run bash "$REPO_ROOT/sync-hooks.sh" --entry-class bogus/path.sh
  [ "$status" -eq 2 ]
  [[ "$output" == *"无法识别的相对路径"* ]]
}

@test "verify-claims：<base-ref> 不可解析 → rc=2（禁止静默退化为只核工作区）" {
  run bash "$REPO_ROOT/verify-claims.sh" brooks-review-fix-2026-09 no-such-ref-2099
  [ "$status" -eq 2 ]
  [[ "$output" == *"不是可解析的提交"* ]]
}
