#!/usr/bin/env bats
# ============================================================================
# quality-baseline — AC-1 ~ AC-7 验收测试
# ============================================================================

# ═══════════════════════════════════════════════════════════════════════════
# AC-1: pipeline-gates.md 存在且被引用
# ═══════════════════════════════════════════════════════════════════════════

@test "AC-1: pipeline-gates.md 存在" {
  run test -f flow-kit-bundle/flow-kit/reference/pipeline-gates.md
  [ "$status" -eq 0 ]
}

@test "AC-1: 4-dev prompt 引用 pipeline-gates" {
  run grep -q "pipeline-gates" flow-kit-bundle/flow-kit/prompts/4-dev.md
  [ "$status" -eq 0 ]
}

@test "AC-1: flow-dev skill 引用 pipeline-gates" {
  run grep -q "pipeline-gates" flow-kit-bundle/skills/flow-dev/SKILL.md
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════════
# AC-2: check-gate-sync.sh（gate-config 预设键值对同步门禁）运行断言
# T12c（health-fix-2026-09c · C13/AC-11 更名触点收敛 · L2 r3 R4 修订 2026-09-29）：
# 旧 AC-2 以 check-gate-sync.sh 为唯一同步门禁（PCSC prompt↔skill 内容比对 +
# gate-config 预设键值对）。T12b 语义拆分后 PCSC prompt↔skill 同步判据迁至
# reference/check-skills-sync.sh——同步门禁的存在性/同步判据断言载体收敛为
# test_skills_sync.bats（skills 侧）/ test_check_gate_sync.bats（预设键值对侧），
# 本文件仅保留 check-gate-sync 运行断言（存留语义 = gate-config 预设键值对同步）。
# ═══════════════════════════════════════════════════════════════════════════

@test "AC-2: check-gate-sync.sh 运行无脚本错误" {
  run bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh
  # exit 0=预设键值对一致, 1=发现预设键值漂移——两者都是正常执行（非脚本错误 exit 2）
  [ "$status" -ne 2 ]
}

# ═══════════════════════════════════════════════════════════════════════════
# AC-3: Makefile targets 可用
# ═══════════════════════════════════════════════════════════════════════════

@test "AC-3: Makefile 存在" {
  run test -f Makefile
  [ "$status" -eq 0 ]
}

@test "AC-3: make test target 定义存在" {
  run grep -q "^test:" Makefile
  [ "$status" -eq 0 ]
}

@test "AC-3: make lint target 定义存在" {
  run grep -q "^lint:" Makefile
  [ "$status" -eq 0 ]
}

@test "AC-3: make check target 定义存在" {
  run grep -q "^check:" Makefile
  [ "$status" -eq 0 ]
}

@test "AC-3: make lint (或 shellcheck 未装时 skip)" {
  if which shellcheck > /dev/null 2>&1; then
    run make lint
    [ "$status" -eq 0 ]
  else
    skip "shellcheck 未安装"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# AC-4: pre-push hook 生效
# ═══════════════════════════════════════════════════════════════════════════

@test "AC-4: pre-push hook 存在且可执行" {
  run test -x .git/hooks/pre-push
  [ "$status" -eq 0 ]
}

@test "AC-4: pre-push hook 调用 make check" {
  run grep -q "make check" .git/hooks/pre-push
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════════
# AC-5: stop 链 smoke test 覆盖
# ═══════════════════════════════════════════════════════════════════════════

@test "AC-5: test_stop_chain.bats 存在" {
  run test -f test/test_stop_chain.bats
  [ "$status" -eq 0 ]
}

@test "AC-5: stop 链 smoke tests 全绿" {
  run npx bats test/test_stop_chain.bats
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════════
# AC-6: shellcheck 无 error（或 skip）
# ═══════════════════════════════════════════════════════════════════════════

@test "AC-6: shellcheck 无 error 级别问题" {
  if which shellcheck > /dev/null 2>&1; then
    run bash -c 'shellcheck -e SC1091 *.sh flow-kit-bundle/lib/*.sh 2>&1 | grep -ci "error" || true'
    [ "$output" = "0" ]
  else
    skip "shellcheck 未安装"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# AC-7: test 双源校验
# ═══════════════════════════════════════════════════════════════════════════

@test "AC-7: test/ 与 flow-kit-bundle/test/ 一致" {
  if [ -d flow-kit-bundle/test ]; then
    run diff -rq test/ flow-kit-bundle/test/
    [ "$status" -eq 0 ]
  else
    skip "flow-kit-bundle/test/ 不存在"
  fi
}
