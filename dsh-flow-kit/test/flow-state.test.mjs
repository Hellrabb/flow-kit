// flow-state.test.mjs — dsh-flow-kit `/flow` state machine unit tests.
import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile, rm, access } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { resolveGateConfig, runFlowCommand, FlowError } from "../lib/flow-state.js";

async function tempProject() {
  const root = await mkdtemp(join(tmpdir(), "dsh-flow-kit-"));
  process.env.FLOW_KIT_PROJECT_DIR = root;
  return root;
}

test("resolveGateConfig: preset all covers the six review phases", () => {
  const { gate } = resolveGateConfig("all");
  assert.deepEqual(gate, {
    "1-requirement": "both",
    "2-design": "both",
    "3-task": "both",
    "5-test": "both",
    "6-review": "both",
    "7-integration": "both",
  });
});

test("resolveGateConfig: numeric list 1,6 maps to requirement+review", () => {
  const { gate } = resolveGateConfig("1,6");
  assert.deepEqual(gate, { "1-requirement": "both", "6-review": "both" });
});

test("resolveGateConfig: JSON object passes through", () => {
  const { gate } = resolveGateConfig('{"6-review":"L2","2-design":"L3"}');
  assert.deepEqual(gate, { "6-review": "L2", "2-design": "L3" });
});

test("resolveGateConfig: --l2-only / --l3-only granular override (last wins)", () => {
  const l2 = resolveGateConfig("review", { l2Only: true });
  assert.deepEqual(l2.gate, { "6-review": "L2" });
  const l3 = resolveGateConfig("review", { l3Only: true });
  assert.deepEqual(l3.gate, { "6-review": "L3" });
  const both = resolveGateConfig("review", { l2Only: true, l3Only: true });
  assert.deepEqual(both.gate, { "6-review": "L3" });
  assert.equal(both.warnings.length, 1);
});

test("resolveGateConfig: unknown value raises FlowError", () => {
  assert.throws(() => resolveGateConfig("nonsense"), FlowError);
});

test("/flow start → goal pipeline → phase → checkpoint → stop (full state cycle)", async () => {
  const root = await tempProject();
  try {
    let result = await runFlowCommand("start", undefined);
    assert.equal(result.kind, "success");
    result = await runFlowCommand("goal \"pnpm test passes\" --pipeline --from 4 --gate-config review --l3-only", undefined);
    assert.equal(result.kind, "success");
    assert.match(result.text, /Pipeline Goal/);

    const state = JSON.parse(await readFile(join(root, ".flow-active"), "utf8"));
    assert.equal(state.phase, "0");
    assert.equal(state.goal.scope, "pipeline");
    assert.equal(state.goal.start_phase, "4");
    assert.deepEqual(state.goal.gate_config, { "6-review": "L3" });
    assert.deepEqual(Object.keys(state.goal.gates), ["4→5", "5→6", "6→7"]);

    result = await runFlowCommand("phase 6", undefined);
    assert.equal(result.kind, "success");
    result = await runFlowCommand("checkpoint REVIEW.md \"L3 verdict pending\"", undefined);
    assert.equal(result.kind, "success");
    result = await runFlowCommand("task T2", undefined);
    assert.equal(result.kind, "success");

    const after = JSON.parse(await readFile(join(root, ".flow-active"), "utf8"));
    assert.equal(after.phase, "6");
    assert.equal(after.task_id, "T2");
    assert.equal(after.interrupt.active_file, "REVIEW.md");

    result = await runFlowCommand("stop", undefined);
    assert.equal(result.kind, "success");
    await assert.rejects(readFile(join(root, ".flow-active"), "utf8"));
  } finally {
    await rm(root, { recursive: true, force: true });
    delete process.env.FLOW_KIT_PROJECT_DIR;
  }
});

test("/flow gate-config and model persist into .goal", async () => {
  const root = await tempProject();
  try {
    await runFlowCommand("start", undefined);
    await runFlowCommand("goal \"ship it\"", undefined);
    let result = await runFlowCommand("gate-config 6-review=L2", undefined);
    assert.equal(result.kind, "success");
    result = await runFlowCommand("model l2=deepseek-v4-flash l3=deepseek-v4-pro", undefined);
    assert.equal(result.kind, "success");

    const state = JSON.parse(await readFile(join(root, ".flow-active"), "utf8"));
    assert.equal(state.goal.gate_config["6-review"], "L2");
    assert.equal(state.goal.l2_model, "deepseek-v4-flash");
    assert.equal(state.goal.l3_model, "deepseek-v4-pro");

    await runFlowCommand("gate-config 6-review=off", undefined);
    const off = JSON.parse(await readFile(join(root, ".flow-active"), "utf8"));
    assert.equal(off.goal.gate_config["6-review"], "off");
  } finally {
    await rm(root, { recursive: true, force: true });
    delete process.env.FLOW_KIT_PROJECT_DIR;
  }
});
