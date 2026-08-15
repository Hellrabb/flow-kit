// l2-review.test.mjs — dsh-native L2 dispatch contract.
import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, writeFile, readFile, rm, access } from "node:fs/promises";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { runL2Review } from "../lib/l2-review.js";

const BUNDLE_ROOT = resolve(import.meta.dirname, "../../flow-kit-bundle");

async function tempProject(changeId = "demo-change") {
  const root = await mkdtemp(join(tmpdir(), "dsh-flow-kit-l2-"));
  process.env.FLOW_KIT_PROJECT_DIR = root;
  await writeFile(
    join(root, ".flow-active"),
    JSON.stringify({
      change_id: changeId,
      phase: "6",
      goal: { scope: "phase", gate_config: { "6-review": "both" } },
    }),
    "utf8",
  );
  return root;
}

const stubCtx = (overrides = {}) => ({
  get: () => undefined,
  subagents: undefined,
  logger: { warn: () => {}, info: () => {} },
  ...overrides,
});

test("L2 mock writes the ## L2 盲审 section (L2-first contract observable)", async () => {
  const root = await tempProject();
  const oldMock = process.env.FLOW_KIT_L2_MOCK;
  process.env.FLOW_KIT_L2_MOCK = "1";
  try {
    const result = await runL2Review(stubCtx(), { agent: undefined }, "6", BUNDLE_ROOT);
    assert.equal(result.kind, "success");
    const review = join(root, ".specs", "demo-change", "INDEPENDENT-REVIEW-6.md");
    const body = await readFile(review, "utf8");
    assert.match(body, /^## L2 盲审/m);
    assert.match(body, /Verdict\*\*: pass/);
  } finally {
    if (oldMock === undefined) delete process.env.FLOW_KIT_L2_MOCK; else process.env.FLOW_KIT_L2_MOCK = oldMock;
    delete process.env.FLOW_KIT_PROJECT_DIR;
    await rm(root, { recursive: true, force: true });
  }
});

test("L2 gate off refuses dispatch", async () => {
  const root = await tempProject();
  await writeFile(join(root, ".flow-active"), JSON.stringify({ change_id: "demo-change", phase: "6", goal: { gate_config: { "6-review": "L3" } } }), "utf8");
  try {
    const result = await runL2Review(stubCtx(), { agent: undefined }, "6", BUNDLE_ROOT);
    assert.equal(result.kind, "error");
    assert.match(result.text, /未开启 L2/);
  } finally {
    delete process.env.FLOW_KIT_PROJECT_DIR;
    await rm(root, { recursive: true, force: true });
  }
});

test("existing L2 section short-circuits idempotently", async () => {
  const root = await tempProject();
  const review = join(root, ".specs", "demo-change", "INDEPENDENT-REVIEW-6.md");
  await import("node:fs/promises").then(async ({ mkdir }) => mkdir(join(root, ".specs", "demo-change"), { recursive: true }));
  await writeFile(review, "## L2 盲审\n\n**Verdict**: pass\n", "utf8");
  let started = false;
  const ctx = stubCtx({ get: () => ({ start: () => { started = true; } }) });
  try {
    const result = await runL2Review(ctx, { agent: undefined }, "6", BUNDLE_ROOT);
    assert.equal(result.kind, "success");
    assert.equal(started, false);
  } finally {
    delete process.env.FLOW_KIT_PROJECT_DIR;
    await rm(root, { recursive: true, force: true });
  }
});

test("foreground subagent run is started and its missing file fails L2-first", async () => {
  const root = await tempProject();
  const fakeRun = {
    result: Promise.resolve({ output: [{ type: "text", text: "I reviewed, nothing found" }] }),
    dispose: async () => {},
  };
  const started = [];
  const ctx = stubCtx({
    get: () => ({
      list: () => ["spawn", "fork"],
      start: async (provider, request) => {
        started.push({ provider, request });
        return fakeRun;
      },
    }),
  });
  try {
    const result = await runL2Review(ctx, { agent: { id: "parent" } }, "6", BUNDLE_ROOT);
    assert.equal(result.kind, "error");
    assert.match(result.text, /未写入/);
    assert.equal(started.length, 1);
    assert.equal(started[0].provider, "spawn");
    assert.equal(started[0].request.label, "L2 blind review phase 6");
    assert.equal(started[0].request.prompt[0].type, "text");
    assert.match(started[0].request.prompt[0].text, /L2_BLIND_REVIEW_INSTRUCTIONS/);
  } finally {
    delete process.env.FLOW_KIT_PROJECT_DIR;
    await rm(root, { recursive: true, force: true });
  }
});
