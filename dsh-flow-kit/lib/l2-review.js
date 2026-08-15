// l2-review.js — dsh-native L2 blind-review dispatch (`/flow l2-review`).
//
// Claude Code dispatches L2 via subagent_type + prompt injection; opencode via
// category routing; dsh dispatches through the `ctx.subagents` service
// (provider "spawn" by default). This command implements the same L2-first
// contract as hooks/stop/lib/l2-detect.sh without depending on any Claude
// runtime:
//   gate_config[phase] ∈ {L2, both}  → dispatch L2 child with the verbatim
//   L2-blind-review.md prompt + review parameters → child must write
//   .specs/<id>/INDEPENDENT-REVIEW-<phase>.md containing "## L2 盲审".
//
// FLOW_KIT_L2_MOCK=1 keeps the same observable contract for tests / dry runs
// (the shell hook suite uses the identical mock convention).

import { readFile, writeFile, mkdir, rename } from "node:fs/promises";
import { dirname, join } from "node:path";
import { resolveProjectRoot, GATE_PHASES, FlowError } from "./flow-state.js";

const PHASE_ARTIFACTS = {
  1: ".specs/${id}/REQUIREMENT.md（参考 CHANGE.md）",
  2: ".specs/${id}/DESIGN.md（参考 adr/*.md、CONTEXT.md、ARCHITECTURE.md）",
  3: ".specs/${id}/TASK.md（参考 REQUIREMENT.md、DESIGN.md）",
  5: ".specs/${id}/TEST.md（参考 REQUIREMENT.md、TASK.md）",
  6: ".specs/${id}/REVIEW.md + git diff（参考 REQUIREMENT.md、TASK.md、TEST.md）",
  7: ".specs/${id}/ 下全部产物（参考 REVIEW.md、LESSONS.md、CHANGELOG.md）",
};

function reviewFile(root, changeId, phase) {
  return join(root, ".specs", changeId, `INDEPENDENT-REVIEW-${phase}.md`);
}

async function hasL2Section(file) {
  try {
    const body = await readFile(file, "utf8");
    return /^## L2 盲审/m.test(body);
  } catch {
    return false;
  }
}

async function appendL2Section(file, section) {
  const dir = dirname(file);
  await mkdir(dir, { recursive: true });
  let existing = "";
  try {
    existing = await readFile(file, "utf8");
  } catch {
    // new review file
  }
  const tmp = `${file}.tmp`;
  await writeFile(tmp, `${existing}${existing ? "\n" : ""}${section}\n`, "utf8");
  await rename(tmp, file);
}

function promptText(packageRoot, phase, changeId, root, artifactDesc) {
  const templatePath = join(packageRoot, "flow-kit", "prompts", "independent", "L2-blind-review.md");
  return [
    "以下固化指令必须原样执行，禁止增删改：",
    "",
    "<L2_BLIND_REVIEW_INSTRUCTIONS>",
    "REQUIRE: read_file " + templatePath,
    "（把该文件全文作为你的审查指令；引用资源可相对 flow-kit/prompts/independent/ 读取）",
    "</L2_BLIND_REVIEW_INSTRUCTIONS>",
    "",
    "## 本次审查参数",
    `- 阶段：${phase}`,
    `- change-id：${changeId}`,
    `- 工件：${artifactDesc.replaceAll("${id}", changeId)}`,
    `- 项目根：${root}`,
    `- 输出：写入 ${reviewFile(root, changeId, phase)}，必须含 \`## L2 盲审\` 段`,
    "  且报告末尾必须有 `**Verdict**: pass | fail`。",
  ].join("\n");
}

export async function runL2Review(ctx, invocation, rest, packageRoot) {
  const root = resolveProjectRoot(invocation.agent);
  const phase = rest.trim().split(/\s+/, 1)[0] || null;
  if (!phase || !GATE_PHASES[phase]) {
    return { kind: "error", text: "用法: /flow l2-review <phase>。phase ∈ 1,2,3,5,6,7" };
  }

  let state;
  try {
    state = JSON.parse(await readFile(join(root, ".flow-active"), "utf8"));
  } catch {
    return { kind: "error", text: "当前没有活跃的 flow。先 /flow start 并 /flow goal 开启 gate_config。" };
  }

  const changeId = state.change_id;
  if (!changeId || changeId === "null") {
    return { kind: "error", text: ".flow-active.change_id 为空，无法定位审查工件。" };
  }
  const gateConfig = state.goal?.gate_config ?? {};
  const gateKey = GATE_PHASES[phase];
  let gateVal = gateConfig[gateKey] ?? "";
  if (gateVal === "independent" || gateVal === "true") gateVal = "both";
  if (!["L2", "both"].includes(gateVal)) {
    return { kind: "error", text: `阶段 ${phase} (${gateKey}) 未开启 L2 审查（gate_config=${gateVal || "(off)"}）。` };
  }

  const file = reviewFile(root, changeId, phase);
  if (await hasL2Section(file)) {
    return { kind: "success", text: `L2 盲审已完成：${file}` };
  }

  const artifactDesc = PHASE_ARTIFACTS[phase];
  const prompt = promptText(packageRoot, phase, changeId, root, artifactDesc);

  // Test / dry-run contract shared with the shell suite.
  if (process.env.FLOW_KIT_L2_MOCK === "1") {
    const ts = new Date().toISOString().replaceAll(":", "-");
    await appendL2Section(file, [
      "",
      "---",
      "## L2 盲审（mock · dsh-flow-kit）",
      "",
      "> Mock L2 review — FLOW_KIT_L2_MOCK=1",
      "",
      "### 🟢 Mock Finding · Mock review for testing",
      "**Severity**：🟢 Minor",
      "**Symptom**: Mock dispatch succeeded",
      "**Source**: FLOW_KIT_L2_MOCK=1",
      "**Consequence**: None (mock)",
      "**Remedy**: None (mock)",
      "",
      "**Verdict**: pass",
    ].join("\n"));
    return { kind: "success", text: `L2 盲审完成（mock）：${file}` };
  }

  const subagents = ctx?.get?.("subagents") ?? ctx?.subagents;
  if (!subagents?.start) {
    return {
      kind: "error",
      text: [
        "dsh 当前 profile 未挂载 subagents 服务，无法自动派发 L2。",
        "请用 subagent tool 手动派发，description=\"L2 blind review phase " + phase + "\"，",
        "prompt 原样注入 flow-kit/prompts/independent/L2-blind-review.md 全文，并附：",
        prompt,
      ].join("\n"),
    };
  }

  const providers = subagents.list();
  const provider = providers.includes("spawn") ? "spawn" : providers[0];
  if (!provider) return { kind: "error", text: "dsh 没有可用的 subagent provider，无法派发 L2。" };

  let run;
  try {
    run = await subagents.start(provider, {
      label: `L2 blind review phase ${phase}`,
      prompt: [{ type: "text", text: prompt }],
      parent: invocation.agent,
    });
    const result = await run.result;
    const output = (result?.output ?? [])
      .map((block) => (typeof block === "string" ? block : block?.type === "text" ? block.text : JSON.stringify(block)))
      .join("\n")
      .trim();
    if (await hasL2Section(file)) {
      return { kind: "success", text: `L2 盲审完成：${file}${output ? `\n\n子代理输出摘要：\n${output.slice(0, 2000)}` : ""}` };
    }
    return {
      kind: "error",
      text: `L2 子代理已结束，但未写入 ${file} 的 ## L2 盲审 段。L2-first 契约不满足。子代理输出：\n${output.slice(0, 4000) || "(empty)"}`,
    };
  } catch (error) {
    return { kind: "error", text: `L2 派发失败：${error.message}` };
  } finally {
    if (run?.dispose) await Promise.resolve().then(() => run.dispose()).catch(() => {});
  }
}
