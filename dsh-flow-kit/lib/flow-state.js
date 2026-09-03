// flow-state.js — flow-kit `.flow-active` state management for the dsh plugin.
//
// This is a JavaScript port of the `/flow` state-manager skill
// (flow-kit-bundle/skills/flow/SKILL.md). It intentionally keeps the exact
// `.flow-active` JSON schema consumed by the shell hook chain, and the exact
// gate_config PRESET_MAP / numeric mapping of the L2/L3 independent-review
// design (ADR-007 / l2-l3-granular-gate). No Claude Code dependency exists
// here: the project root is resolved from FLOW_KIT_PROJECT_DIR, the calling
// agent's session cwd, or process.cwd().

import { readFile, writeFile, mkdir, rm, rename, access } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";

// ── Constants (single source, mirrors fk_phase_gate_key in hooks/stop/lib/common.sh) ──
const VALID_PHASES = ["0", "1", "2", "2a", "3", "4", "5", "6", "7"];
export const GATE_PHASES = { "1": "1-requirement", "2": "2-design", "3": "3-task", "5": "5-test", "6": "6-review", "7": "7-integration" };

// PRESET_MAP — identical to the skill/installation presets. Values are
// normalized to "both" (L2+L3 dual-layer), matching fk_normalize_gate_val().
const PRESET_MAP = {
  full: { "1-requirement": "both", "2-design": "both", "6-review": "both" },
  all: {
    "1-requirement": "both",
    "2-design": "both",
    "3-task": "both",
    "5-test": "both",
    "6-review": "both",
    "7-integration": "both",
  },
  "code-only": { "6-review": "both" },
  review: { "6-review": "both" },
  design: { "2-design": "both" },
  requirement: { "1-requirement": "both" },
  plan: { "1-requirement": "both", "2-design": "both" },
  "design-review": { "2-design": "both", "6-review": "both" },
  "requirement-review": { "1-requirement": "both", "6-review": "both" },
  task: { "3-task": "both" },
  test: { "5-test": "both" },
  integration: { "7-integration": "both" },
  "task-review": { "3-task": "both", "6-review": "both" },
  "test-review": { "5-test": "both", "6-review": "both" },
  "task-test": { "3-task": "both", "5-test": "both" },
  "task-test-review": { "3-task": "both", "5-test": "both", "6-review": "both" },
  "spec-test": { "1-requirement": "both", "2-design": "both", "5-test": "both" },
};

const nowIso = () => new Date().toISOString();

// ── Project root resolution (Claude-Code-decoupled) ──
export function resolveProjectRoot(agent) {
  const fromEnv = process.env.FLOW_KIT_PROJECT_DIR;
  if (fromEnv) return resolve(fromEnv);
  const sessionCwd = agent?.session?.header?.cwd;
  if (sessionCwd) return resolve(sessionCwd);
  return process.cwd();
}

const flowPath = (root) => join(root, ".flow-active");

async function readFlow(root) {
  const file = flowPath(root);
  try {
    const raw = await readFile(file, "utf8");
    return { file, state: JSON.parse(raw), error: null };
  } catch (error) {
    if (error.code === "ENOENT") return { file, state: null, error: null };
    return { file, state: null, error: `无法解析 ${file}: ${error.message}` };
  }
}

async function writeFlow(file, state) {
  const tmp = `${file}.tmp`;
  await mkdir(dirname(file), { recursive: true });
  await writeFile(tmp, `${JSON.stringify(state, null, 2)}\n`, "utf8");
  await rename(tmp, file); // atomic replace on POSIX
}

function updateTs(state) {
  return { ...state, updated_at: nowIso() };
}

function requireActive(result, action) {
  if (!result.state) throw new FlowError(`当前没有活跃的 flow。先 /flow start，再 /flow ${action}。`);
  return result.state;
}

function requireGoal(state) {
  if (!state.goal) throw new FlowError("当前无活跃 goal。先 /flow goal <条件> 设定（gate_config 是 goal 子字段）。");
  return state.goal;
}

export class FlowError extends Error {}

// ── gate_config parser (three-segment auto-detect + L2/L3 override flags) ──
export function resolveGateConfig(value, opts = {}) {
  let gate = {};
  const text = (value ?? "").trim();

  if (text.startsWith("{")) {
    try {
      const parsed = JSON.parse(text);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) gate = parsed;
      else throw new Error("object required");
    } catch {
      throw new FlowError(`gate-config 不是合法 JSON 对象: ${value}`);
    }
  } else if (Object.hasOwn(PRESET_MAP, text)) {
    gate = { ...PRESET_MAP[text] };
  } else if (/^[0-9](,[0-9])*$/.test(text)) {
    for (const num of text.split(",")) {
      const key = GATE_PHASES[num];
      if (!key) throw new FlowError(`无效 gate phase 数字: ${num}。有效值: 1,2,3,5,6,7`);
      gate[key] = "both";
    }
  } else if (text !== "") {
    throw new FlowError(`无法识别的 gate_config: "${text}"。可用预设: ${Object.keys(PRESET_MAP).join(", ")}；或 JSON 对象；或逗号分隔数字 1,2,3,5,6,7`);
  }

  // L2/L3 granular override flags (l2-l3-granular-gate): both passed → last wins + warning.
  const warnings = [];
  if (opts.l2Only && opts.l3Only) warnings.push("--l2-only 与 --l3-only 同时传入，后者覆盖");
  const override = opts.l3Only ? "L3" : opts.l2Only ? "L2" : null;
  if (override) {
    for (const key of Object.keys(gate)) gate[key] = override;
  }
  return { gate, warnings };
}

function buildPipelineGates(from) {
  const start = Number(from);
  const gates = {};
  for (let n = start; n < 7; n += 1) gates[`${n}→${n + 1}`] = "pending";
  return gates;
}

function phaseGateChain(from) {
  const start = Number(from);
  const chain = [];
  for (let n = start; n <= 7; n += 1) chain.push(String(n));
  return chain;
}

function formatGoal(goal) {
  if (!goal) return "当前无活跃 goal。用 /flow goal <条件> 设定。";
  const lines = [];
  if (goal.scope === "pipeline") {
    const start = goal.start_phase ?? "4";
    const current = goal.current_phase ?? start;
    const done = new Set(goal.phases_done ?? []);
    const progress = phaseGateChain(start).map((p) => (done.has(p) ? "✅" : p === current ? "🔄" : "⏸")).join(" → ");
    lines.push(`🎯 [pipeline] Goal: ${goal.condition}`);
    lines.push(`   起始: ${start} | 进度: ${progress}`);
    const toll = Object.entries(goal.gates ?? {})
      .map(([key, value]) => `${key} ${value ?? "pending"}`)
      .join(" | ");
    if (toll) lines.push(`   toll-gates: ${toll}`);
    lines.push(`   auto_advance: ${goal.auto_advance ?? false}`);
    lines.push(`   状态: ${goal.status} | 已执行: ${goal.turns ?? 0} turns | 模式: ${goal.mode}`);
    lines.push(`   设定于: ${goal.active_since}`);
  } else {
    lines.push(`🎯 Goal: ${goal.condition}`);
    lines.push(`   状态: ${goal.status} | 已执行: ${goal.turns ?? 0} turns | 模式: ${goal.mode}`);
    lines.push(`   设定于: ${goal.active_since}`);
  }
  return lines.join("\n");
}

function formatStatus(state, root) {
  if (!state) return "当前没有活跃的 flow。用 /flow start 开始。";
  const lines = [
    `flow-kit 状态 (${root})`,
    `change_id: ${state.change_id ?? "(none)"}`,
    `phase: ${state.phase}`,
    `task_id: ${state.task_id ?? "(none)"}`,
    `token_spent: ${state.token_spent ?? 0}`,
    `updated_at: ${state.updated_at ?? "-"}`,
  ];
  if (state.interrupt?.active_file) {
    lines.push(`interrupt: ${state.interrupt.active_file} — ${state.interrupt.last_action ?? ""} @ ${state.interrupt.checkpoint_at ?? ""}`);
  }
  if (state.goal) lines.push(formatGoal(state.goal));
  return lines.join("\n");
}

function parseArgs(rawInput) {
  const tokens = (rawInput ?? "").trim().split(/\s+/).filter(Boolean);
  const flags = { pipeline: false, l2Only: false, l3Only: false, from: null, gateConfig: null };
  const positional = [];
  for (let i = 0; i < tokens.length; i += 1) {
    const token = tokens[i];
    if (token === "--pipeline") flags.pipeline = true;
    else if (token === "--l2-only") flags.l2Only = true;
    else if (token === "--l3-only") flags.l3Only = true;
    else if (token === "--from") {
      const next = tokens[++i];
      if (!next || !/^[0-7]$/.test(next)) throw new FlowError(`无效起始阶段: ${next ?? "(missing)"}。有效值: 0,1,2,3,4,5,6,7`);
      flags.from = next;
    } else if (token === "--gate-config") {
      const next = tokens[++i];
      if (next === undefined) throw new FlowError("--gate-config 需要参数");
      flags.gateConfig = next;
    } else positional.push(token);
  }
  return { flags, positional };
}

// ── Command executor. Returns { kind: "success" | "error", text }. ──
export async function runFlowCommand(rawInput, agent) {
  const root = resolveProjectRoot(agent);
  const { file, state, error } = await readFlow(root);
  if (error) return { kind: "error", text: `❌ ${error}` };

  const sub = rawInput?.trim().split(/\s+/, 1)[0] ?? "";
  const rest = rawInput?.trim().slice(sub.length).trim() ?? "";

  try {
    switch (sub) {
      case "":
        return { kind: "success", text: formatStatus(state, root) };

      case "start": {
        if (state) return { kind: "success", text: `已有活跃 flow（change=${state.change_id ?? "none"}, phase=${state.phase}）。如需新建请先 /flow stop。` };
        const fresh = { change_id: null, goal: null, phase: "0", task_id: null, interrupt: null, token_spent: 0, updated_at: nowIso() };
        await writeFlow(file, fresh);
        return { kind: "success", text: "flow-kit 已激活 (phase 0)。现在告诉我你想做什么，我来自动路由。" };
      }

      case "stop": {
        if (!state) return { kind: "success", text: "当前没有活跃的 flow。" };
        await rm(file, { force: true });
        return { kind: "success", text: `flow-kit 已停止 (change=${state.change_id ?? "none"})。` };
      }

      case "phase": {
        requireActive({ state }, "phase");
        if (!rest || !VALID_PHASES.includes(rest)) return { kind: "error", text: `❌ 无效阶段 "${rest}"。有效值: ${VALID_PHASES.join(", ")}` };
        const next = { ...state, phase: rest, updated_at: nowIso() };
        await writeFlow(file, next);
        return { kind: "success", text: `阶段切换: ${state.phase} → ${rest}` };
      }

      case "task": {
        requireActive({ state }, "task");
        if (!/^T\d+$/.test(rest)) return { kind: "error", text: `❌ 无效 task id "${rest}"。格式: T<N>，如 T1。` };
        const next = { ...state, task_id: rest, updated_at: nowIso() };
        await writeFlow(file, next);
        return { kind: "success", text: `task → ${rest}` };
      }

      case "checkpoint": {
        requireActive({ state }, "checkpoint");
        const [fileArg, ...descParts] = rest.split(/\s+/);
        if (!fileArg || descParts.length === 0) return { kind: "error", text: "用法: /flow checkpoint <file> <description>" };
        const ts = nowIso();
        const next = {
          ...state,
          interrupt: { active_file: fileArg, last_action: descParts.join(" "), checkpoint_at: ts },
          updated_at: ts,
        };
        await writeFlow(file, next);
        return { kind: "success", text: `📍 checkpoint: ${fileArg} — ${descParts.join(" ")}` };
      }

      case "goal": {
        requireActive({ state }, "goal");
        if (rest === "") return { kind: "success", text: formatGoal(state.goal) };
        if (["clear", "stop", "off", "reset", "none", "cancel"].includes(rest)) {
          const next = { ...state, goal: null, updated_at: nowIso() };
          await writeFlow(file, next);
          return { kind: "success", text: "✅ Goal 已清除" };
        }
        const { flags, positional } = parseArgs(rest);
        const condition = positional.join(" ");
        if (!condition) return { kind: "error", text: "用法: /flow goal <条件文本> [--pipeline] [--from <n>] [--gate-config <JSON|preset>]" };
        const ts = nowIso();
        if (flags.pipeline) {
          const from = flags.from ?? "4";
          const gates = buildPipelineGates(from);
          let gateConfig = {};
          const warnings = [];
          if (flags.gateConfig) {
            const resolved = resolveGateConfig(flags.gateConfig, { l2Only: flags.l2Only, l3Only: flags.l3Only });
            gateConfig = resolved.gate;
            warnings.push(...resolved.warnings);
          }
          const goal = {
            condition,
            status: "active",
            active_since: ts,
            turns: 0,
            mode: "pending",
            scope: "pipeline",
            start_phase: from,
            current_phase: from,
            phases_done: [],
            gates,
            gate_config: gateConfig,
            auto_advance: false,
            phase_sub_goals: { "4": "", "5": "", "6": "", "7": "" },
          };
          const next = { ...state, goal, updated_at: ts };
          await writeFlow(file, next);
          // D8 ⑥ gate_config snapshot (git-tracked tamper detection anchor)
          if (state.change_id) {
            const snapDir = join(root, ".specs", state.change_id);
            await mkdir(snapDir, { recursive: true });
            const snapTmp = join(snapDir, ".goal-snapshot.json.tmp");
            await writeFile(snapTmp, `${JSON.stringify({ gate_config: gateConfig, created_at: Date.now() / 1000 }, null, 2)}\n`, "utf8");
            await rename(snapTmp, join(snapDir, ".goal-snapshot.json"));
          }
          const chain = phaseGateChain(from).join("→");
          const extra = warnings.length ? `\n⚠️ ${warnings.join("; ")}` : "";
          return { kind: "success", text: `✅ Pipeline Goal 已设定。执行链：${chain}\n${formatGoal(goal)}${extra}` };
        }
        const goal = { condition, status: "active", active_since: ts, turns: 0, mode: "pending" };
        const next = { ...state, goal, updated_at: ts };
        await writeFlow(file, next);
        return { kind: "success", text: `✅ Goal 已设定\n${formatGoal(goal)}` };
      }

      case "gate-config": {
        requireActive({ state }, "gate-config");
        const goal = requireGoal(state);
        if (rest === "") return { kind: "success", text: `当前 gate_config:\n${JSON.stringify(goal.gate_config ?? {}, null, 2)}` };
        const match = rest.match(/^([0-9a-z-]+)=(.+)$/i);
        if (!match) return { kind: "error", text: "用法: /flow gate-config <phase>=<value>。phase ∈ 1-requirement|2-design|3-task|5-test|6-review|7-integration" };
        const [, phaseKey, rawValue] = match;
        if (!Object.values(GATE_PHASES).includes(phaseKey)) {
          return { kind: "error", text: `❌ 无效 phase key "${phaseKey}"。合法值: ${Object.values(GATE_PHASES).join(" / ")}` };
        }
        let value = rawValue;
        if (value === "independent" || value === "true") value = "both";
        else if (value === "off" || value === "false") value = "off";
        else if (!["L2", "L3", "both", "off"].includes(value)) {
          return { kind: "error", text: `❌ 无效 gate value "${rawValue}"。合法值: both|L2|L3|independent|true|off|false` };
        }
        const gateConfig = { ...(goal.gate_config ?? {}), [phaseKey]: value };
        const next = { ...state, goal: { ...goal, gate_config: gateConfig }, updated_at: nowIso() };
        await writeFlow(file, next);
        return { kind: "success", text: `✅ gate_config[${phaseKey}] = ${value}。\n当前: ${JSON.stringify(gateConfig, null, 2)}` };
      }

      case "model": {
        requireActive({ state }, "model");
        const goal = requireGoal(state);
        // L2 盲审 R1（dsh-flow-kit-sync-2026-09）：渲染必须读「当前值」而非写前闭包。
        // render(g) 纯函数化——参数化要显示的 goal，写入后传 nextGoal 回显新值；
        // 「✅ 已更新。」只作单行 header，不再逐行加前缀。
        const render = (g) => [
          `L2 显式: ${g.l2_model ?? "(未设置 → ANTHROPIC_L2_MODEL / FLOW_KIT_L2_MODEL env)"}`,
          `L3 显式: ${g.l3_model ?? "(未设置 → ANTHROPIC_DEFAULT_HAIKU_MODEL / FLOW_KIT_L3_MODEL env)"}`,
          `L2 默认: ${g.l2_default_model ?? "(未设置 → FLOW_KIT_L2_DEFAULT_MODEL env → 降级)"}`,
          `L3 默认: ${g.l3_default_model ?? "(未设置 → FLOW_KIT_L3_DEFAULT_MODEL env → 降级)"}`,
          "优先级链: ANTHROPIC_* env > FLOW_KIT_*_MODEL env > .goal.l*_model（显式） > FLOW_KIT_*_DEFAULT_MODEL env > .goal.l*_default_model（站点默认） > 降级",
        ].join("\n");
        if (rest === "") return { kind: "success", text: render(goal) };
        // 五级解析链 tier-4/5（model tier, 2026-09 同步）：
        // l2=|l3= 写显式字段；l2-default=|l3-default= 写站点默认字段；
        // --clear <l2|l3|l2-default|l3-default> 清对应字段。
        // 仅触碰 4 个模型字段，不碰 condition/gates/gate_config（平行配置维度）。
        const tokens = rest.split(/\s+/);
        let nextGoal = { ...goal };
        const fieldOf = { l2: "l2_model", l3: "l3_model", "l2-default": "l2_default_model", "l3-default": "l3_default_model" };
        for (const token of tokens) {
          const m = token.match(/^(l2|l3|l2-default|l3-default)=(.+)$/);
          if (m) nextGoal[fieldOf[m[1]]] = m[2];
        }
        const clearIdx = tokens.indexOf("--clear");
        if (clearIdx >= 0) {
          for (const target of tokens.slice(clearIdx + 1)) {
            if (Object.hasOwn(fieldOf, target)) nextGoal[fieldOf[target]] = null;
          }
        }
        const next = { ...state, goal: nextGoal, updated_at: nowIso() };
        await writeFlow(file, next);
        return { kind: "success", text: `✅ 已更新。\n${render(nextGoal)}` };
      }

      case "doctor": {
        if (!state) return { kind: "error", text: "🩺 没有 .flow-active。先 /flow start。" };
        const lines = ["🩺 flow-kit 诊断报告"];
        lines.push(`✅ .flow-active: 有效 (phase ${state.phase}, change=${state.change_id ?? "none"})`);
        const hookConfig = join(root, ".flow-kit", "stop-hook.json");
        try {
          await access(hookConfig);
          const cfg = JSON.parse(await readFile(hookConfig, "utf8"));
          lines.push(cfg.modules?.workflow?.enabled === true ? "✅ Stop Hook workflow: 已启用" : "⚠️ Stop Hook workflow: 未启用 (.flow-kit/stop-hook.json)");
        } catch {
          lines.push("⚠️ Stop Hook 配置: .flow-kit/stop-hook.json 缺失（dsh 插件内置 hook bridge 仍可运行）");
        }
        // correction 卫生（correction-hygiene-state-guard · ADR-024）：报告
        // .flow-active.correction 类型与待办规模；去重/FIFO 治理由 33 号 hook 负责。
        const correctionPath = join(root, ".flow-active.correction");
        try {
          const correction = JSON.parse(await readFile(correctionPath, "utf8"));
          const tag = correction.type ?? "(unknown)";
          const violations = Array.isArray(correction.violations) ? correction.violations : [];
          if (violations.length > 0) {
            // violations 是异质 schema：state-integrity 类（33 号）写 check；
            // compliance 类（28 号 weak-model-compliance）写 rule——取摘要时做
            // check → rule 回退（phase 2 L2 盲审 R1）。用 || 而非 ??：空字符串
            // check 也必须回退到 rule（phase 6 L3 重审 Major 1 边界）。
            const checks = [...new Set(violations.map((v) => (v?.check || v?.rule || "?")).filter(Boolean))].join(", ");
            lines.push(`⚠️ .flow-active.correction: type=${tag}, violations=${violations.length} (${checks})`);
          } else if (correction.message) {
            lines.push(`⚠️ .flow-active.correction: type=${tag} — ${correction.message}`);
          } else {
            lines.push(`⚠️ .flow-active.correction: type=${tag}`);
          }
        } catch (error) {
          if (error.code === "ENOENT") lines.push("✅ .flow-active.correction: 无待办纠正（卫生良好）");
          else lines.push(`⚠️ .flow-active.correction: 读取失败 — ${error.message}`);
        }
        if (state.change_id) {
          const specDir = join(root, ".specs", state.change_id);
          for (const artifact of ["CHANGE.md", "REQUIREMENT.md", "DESIGN.md", "TASK.md", "TEST.md", "REVIEW.md"]) {
            try {
              await access(join(specDir, artifact));
            } catch {
              lines.push(`⚠️ Phase 产物: ${artifact} 缺失`);
            }
          }
        }
        return { kind: "success", text: lines.join("\n") };
      }

      default:
        return { kind: "error", text: `未知 /flow 子命令: ${sub}。可用: start|stop|phase|task|checkpoint|goal|gate-config|model|l2-review|doctor` };
    }
  } catch (err) {
    if (err instanceof FlowError) return { kind: "error", text: `❌ ${err.message}` };
    return { kind: "error", text: `❌ /flow 执行失败: ${err.message}` };
  }
}
