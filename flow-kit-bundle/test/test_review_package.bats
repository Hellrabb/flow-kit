#!/usr/bin/env bats
# test_review_package.bats — review-package 脚本测试

setup() {
  TEST_TMPDIR=$(mktemp -d)
  # 位置无关：向上查找含 flow-kit-bundle/flow-kit/scripts 的目录
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -f "$d/flow-kit-bundle/flow-kit/scripts/review-package" ]; do
    d="$(dirname "$d")"
  done
  REVIEW_PACKAGE="$d/flow-kit-bundle/flow-kit/scripts/review-package"
  chmod +x "$REVIEW_PACKAGE"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "happy path: produces all three section headers with exit 0" {
  cd "$TEST_TMPDIR"
  git init >/dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test"
  git commit --allow-empty -m "first commit" >/dev/null 2>&1
  git commit --allow-empty -m "second commit" >/dev/null 2>&1

  run "$REVIEW_PACKAGE" HEAD~1 HEAD
  [ "$status" -eq 0 ]
  [[ "$output" =~ "## Commits" ]]
  [[ "$output" =~ "## Files changed" ]]
  [[ "$output" =~ "## Diff" ]]
}

@test "non-git error: exits non-zero with 'not a git repository' on stderr" {
  cd "$TEST_TMPDIR"
  # TEST_TMPDIR is not a git repo — script must fail

  run "$REVIEW_PACKAGE" HEAD~1 HEAD
  [ "$status" -ne 0 ]
  [[ "$output" =~ "not a git repository" ]]
}

@test "empty diff: base equals head, exits 0 with all section headers present" {
  cd "$TEST_TMPDIR"
  git init >/dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test"
  git commit --allow-empty -m "only commit" >/dev/null 2>&1

  run "$REVIEW_PACKAGE" HEAD HEAD
  [ "$status" -eq 0 ]
  [[ "$output" =~ "## Commits" ]]
  [[ "$output" =~ "## Files changed" ]]
  [[ "$output" =~ "## Diff" ]]
}

@test "large diff: 100-line file change runs successfully without script truncation" {
  cd "$TEST_TMPDIR"
  git init >/dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test"
  git commit --allow-empty -m "first commit" >/dev/null 2>&1

  # Create a 100-line file and commit it
  for i in $(seq 1 100); do
    echo "line $i: some content here for testing purposes"
  done >large_file.txt
  git add large_file.txt
  git commit -m "add 100-line file" >/dev/null 2>&1

  run "$REVIEW_PACKAGE" HEAD~1 HEAD
  [ "$status" -eq 0 ]
  # Script itself must not truncate — line 100 must appear in output
  [[ "$output" =~ "line 100" ]]
}

@test "markdown structure: sections appear in correct order" {
  cd "$TEST_TMPDIR"
  git init >/dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test"
  git commit --allow-empty -m "first commit" >/dev/null 2>&1
  git commit --allow-empty -m "second commit" >/dev/null 2>&1

  run "$REVIEW_PACKAGE" HEAD~1 HEAD
  [ "$status" -eq 0 ]

  # Sections must appear in order: ## Commits → ## Files changed → ## Diff
  commits_idx=$(echo "$output" | grep -n "## Commits" | head -1 | cut -d: -f1)
  files_idx=$(echo "$output" | grep -n "## Files changed" | head -1 | cut -d: -f1)
  diff_idx=$(echo "$output" | grep -n "## Diff" | head -1 | cut -d: -f1)

  [ "$commits_idx" -lt "$files_idx" ]
  [ "$files_idx" -lt "$diff_idx" ]
}
