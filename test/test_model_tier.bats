#!/usr/bin/env bats
# 位置无关定位仓库根（勿写死绝对路径：包内分发不携带宿主 home 路径）

setup() {
  # 从测试文件所在目录向上找 flow-kit-bundle/（本仓 bats 统一模式）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle" ]; do
    d="$(dirname "$d")"
  done
  cd "$d" || exit 1
}

@test "4-dev.md contains task-brief script reference" {
  grep -q "task-brief" flow-kit-bundle/flow-kit/prompts/4-dev.md
}

@test "4-dev.md contains MODEL-TIER hint format" {
  grep -q "MODEL-TIER hint" flow-kit-bundle/flow-kit/prompts/4-dev.md
}

@test "4-dev.md contains task_progress jq append template" {
  grep -q "task_progress +=" flow-kit-bundle/flow-kit/prompts/4-dev.md
}

@test "4-dev.md contains fallback standard for old TASK.md" {
  grep -q -E "fallback.*standard|standard.*fallback" flow-kit-bundle/flow-kit/prompts/4-dev.md
}

@test "4-dev.md contains narration-constraint @see reference" {
  grep -q "narration-constraint" flow-kit-bundle/flow-kit/prompts/4-dev.md
}

@test "AC-F4 backward compatibility: old .flow-active without task_progress does not error" {
  # Simulate old .flow-active
  tmp=$(mktemp)
  echo '{"goal":{}}' > "$tmp"
  result=$(jq '.goal.task_progress += [{id: "T01"}]' "$tmp" 2>&1)
  echo "$result" | grep -q '"task_progress"' || {
    rm -f "$tmp"
    return 1
  }
  echo "$result" | grep -q '"id": "T01"' || {
    rm -f "$tmp"
    return 1
  }
  rm -f "$tmp"
}
