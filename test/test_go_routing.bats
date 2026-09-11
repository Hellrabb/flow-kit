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
  GO_MD=flow-kit-bundle/flow-kit/GO.md
}

@test "GO.md line count ≤ 350 (AC-H1)" {
  lines=$(wc -l < "$GO_MD")
  [ "$lines" -le 350 ]
}

@test "GO.md retains Artifact Preflight Gate" {
  grep -q "Artifact Preflight Gate" "$GO_MD"
}

@test "GO.md retains Phase Completion Gate" {
  grep -q "Phase Completion Gate" "$GO_MD"
}

@test "GO.md retains routing intent keywords: 加新功能 / 新事物描述 → 0-change" {
  grep -qE "新事物描述|做.*想.*加.*实现.*设计" "$GO_MD"
}

@test "GO.md retains routing intent keywords: 修 bug / fix" {
  grep -qE "修.*bug|bug|fix" "$GO_MD"
}

@test "GO.md retains routing intent keywords: 重构 / refactor" {
  grep -qE "重构|refactor" "$GO_MD"
}

@test "GO.md retains routing intent keywords: review / 审查" {
  grep -qE "审查|review" "$GO_MD"
}

@test "GO.md retains routing intent keywords: 测试 / test" {
  grep -qE "测试|test" "$GO_MD"
}

@test "GO.md retains routing intent keywords: 上线 / 集成 / 归档" {
  grep -qE "上线|集成|归档|archive|integration" "$GO_MD"
}

@test "GO.md has @see reference to loading-artifacts.md" {
  grep -q "loading-artifacts.md" "$GO_MD"
}

@test "GO.md deleted sections are gone: 真实成本影响因子" {
  ! grep -q "真实成本影响因子" "$GO_MD"
}

@test "GO.md deleted sections are gone: 用户视角的取舍" {
  ! grep -q "用户视角的取舍" "$GO_MD"
}

@test "GO.md deleted sections are gone: 可选 runtime adapter 检测" {
  ! grep -q "可选 runtime adapter" "$GO_MD"
}
