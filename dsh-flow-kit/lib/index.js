// dsh-flow-kit — flow-kit as a DeepSeek Harness plugin.
//
// Decoupling contract (see DESIGN.md):
//   * No Claude Code dependency: this module never reads ~/.claude, CLAUDE_PROJECT_DIR,
//     or Claude hooks JSON. Project state lives in `.flow-active`; hook config
//     lives in `.flow-kit/stop-hook.json` (defaulted from the package).
//   * The full shell hook suite is reused through hook-bridge.js, which
//     synthesizes the Claude-shaped event JSON the shell hooks already parse.
//   * L2/L3 independent review is untouched: PRESET_MAP, gate_config values
//     (L2|L3|both), .done author-anchors and the PreToolUse hard gate all run
//     in the shipped shell chain.
//   * Skills, prompts, templates, reference and brooks-lint ship verbatim in
//     this package (see the build script package-dsh-plugin.sh).

import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { runFlowCommand } from "./flow-state.js";
import { runL2Review } from "./l2-review.js";
import { HookBridge } from "./hook-bridge.js";
import { loadBundledSkills, registerBundledSkills } from "./skill-loader.js";

const name = "flow-kit";
const inject = ["commands", "skills", "systemPrompt"];

const packageRoot = join(dirname(fileURLToPath(import.meta.url)), "..");

async function apply(ctx, config = {}) {
  // ── flow-kit skills (flow-* + brooks-*) into dsh skill registry ──
  try {
    const skills = await loadBundledSkills(packageRoot);
    registerBundledSkills(ctx, skills);
    ctx.logger?.info?.(`[flow-kit] registered ${skills.length} bundled skills`);
  } catch (error) {
    ctx.logger?.warn?.(`[flow-kit] bundled skill loading failed: ${error.message}`);
  }

  // ── /flow command (state manager ported from skills/flow/SKILL.md) ──
  ctx.commands.register({
    name: "flow",
    description: "flow-kit 状态管理 — start/stop/phase/task/checkpoint/goal/gate-config/model/l2-review/doctor（管理 .flow-active 与 L2 盲审派发）",
    input: { hint: "[start|stop|phase <n>|task <T>|checkpoint <file> <desc>|goal [...]|gate-config <phase>=<value>|model [l2=|l3=]|l2-review <phase>|doctor]" },
    handler(invocation) {
      const raw = invocation.rawInput ?? "";
      if (raw.trim().startsWith("l2-review")) {
        return runL2Review(ctx, invocation, raw.trim().slice("l2-review".length).trim(), packageRoot);
      }
      return runFlowCommand(raw, invocation.agent);
    },
  });

  // ── Hook bridge (PreToolUse gate + Stop chain + SessionStart) ──
  const bridge = new HookBridge({ ctx, packageRoot, config });
  bridge.attach();

  ctx.logger?.info?.(`[flow-kit] dsh plugin ready (hooks=${packageRoot}/hooks, skills=${packageRoot}/skills)`);
}

export { apply, inject, name };
