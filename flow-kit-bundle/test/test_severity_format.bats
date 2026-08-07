#!/usr/bin/env bats
# T06: Severity format enforcement tests for L2-blind-review.md

setup() {
  # 向上查找 flow-kit-bundle/（对齐 test_fk_resolve_model.bats 模式 · TD-012）
  BATS_ROOT="${BATS_TEST_DIRNAME:-.}"
  while [ ! -d "$BATS_ROOT/flow-kit-bundle/flow-kit/prompts" ] && [ "$BATS_ROOT" != "/" ]; do
    BATS_ROOT="$(dirname "$BATS_ROOT")"
  done
  PROJECT_ROOT="$BATS_ROOT"
  PROMPT_FILE="$BATS_ROOT/flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md"
}

@test "severity marking rule is present (Critical, Important, Minor)" {
  run grep -qE "Severity.*Critical.*Important.*Minor" "$PROMPT_FILE"
  [ "$status" -eq 0 ]
}

@test "MINOR-DEFERRED.md path is declared" {
  run grep -q "MINOR-DEFERRED.md" "$PROMPT_FILE"
  [ "$status" -eq 0 ]
}

@test "@see terse-contract.md reference is present" {
  run grep -q "terse-contract.md" "$PROMPT_FILE"
  [ "$status" -eq 0 ]
}

@test "Minor gating rule (不入 fix loop) is present" {
  run grep -qE "不入 fix loop|do not enter fix loop" "$PROMPT_FILE"
  [ "$status" -eq 0 ]
}
