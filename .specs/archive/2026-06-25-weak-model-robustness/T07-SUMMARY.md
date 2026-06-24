# T07-SUMMARY · bats 结构测试（AC-1/AC-3/AC-5）

- **task**: T07 · no-skip-clarify + checkpoint-keynodes + goal-anchored
- **change**: weak-model-robustness

## 做了什么

新建 3 个 bats 结构测试（放 `test/weak-model-robustness/`，沿用既有 bats 风格）：
- `no-skip-clarify.bats`（3 test）：RULES R3.5 + 0-change/1-requirement 反问 gate
- `checkpoint-keynodes.bats`（3 test）：4-dev 关键节点 checkpoint + 非每操作 + 复述边界
- `goal-anchored.bats`（2 test）：GO.md goal 锚定 + 仅入场

## 改了哪些文件

- `test/weak-model-robustness/no-skip-clarify.bats`
- `test/weak-model-robustness/checkpoint-keynodes.bats`
- `test/weak-model-robustness/goal-anchored.bats`

## verify 输出

`npx bats test/weak-model-robustness/*.bats` → **1..8，全 ok** ✅

## 沿用既有抽象 grep（R6.4）

- `ls test/*.bats` → 既有 7 个 bats（扁平结构，`#!/usr/bin/env bats` + setup/run/assert 风格）→ **沿用风格**，新测试放子目录 `weak-model-robustness/`
- ROOT 定位沿用既有模式 `$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)`

## 6 维自查

测试代码本身。R3 知识重复：3 个文件共用 setup 模式（可接受，bats 惯例）✓。无 🔴/🟡。

## 越界检查（R6.5）

- TASK write_files：3 个 bats
- 实际 diff：仅这 3 个新文件
- 越界：**0** ✅

## TDD

测试本身就是产物（验 Wave 1/2 的 markdown 改动）。RED-GREEN：先写测试→跑→全绿（被测对象 Wave 1/2 已改完）。

## 是否触发新 fix-plan

否。
