#!/usr/bin/env bats

setup() {
  cd /home/hellrabbit/unisoc/flow-kit || exit 1
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
