// hook-bridge.test.mjs — dsh event → Claude-shaped JSON → shell hook chain.
import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, writeFile, readFile, rm, access } from "node:fs/promises";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { HookBridge, synthesizeTranscript } from "../lib/hook-bridge.js";

const BUNDLE_ROOT = resolve(import.meta.dirname, "../../flow-kit-bundle");

function stubCtx() {
  const handlers = new Map();
  const logs = [];
  return {
    handlers,
    logs,
    on(event, callback) {
      handlers.set(event, callback);
    },
    logger: { warn: (msg) => logs.push(String(msg)), info: () => {}, error: () => {} },
  };
}

async function tempProject() {
  const root = await mkdtemp(join(tmpdir(), "dsh-flow-kit-bridge-"));
  return root;
}

test("PreToolUse gate denies git commit when L3 review .done missing", async () => {
  const root = await tempProject();
  try {
    await writeFile(
      join(root, ".flow-active"),
      JSON.stringify({
        change_id: "demo-change",
        phase: "6",
        task_id: null,
        goal: { scope: "phase", gate_config: { "6-review": "L3" } },
      }),
      "utf8",
    );
    const fake = stubCtx();
    const bridge = new HookBridge({ ctx: fake, packageRoot: BUNDLE_ROOT, config: { hooks: { sessionStart: false, stop: false } } });
    bridge.attach();

    const preExec = fake.handlers.get("tools/pre-execute");
    assert.ok(preExec, "tools/pre-execute listener attached");

    const exec = {
      name: "bash",
      arguments: { command: 'git commit -m "wip"', description: "commit" },
      agent: { session: { id: "s1", header: { cwd: root } } },
    };
    const decision = await preExec(exec, async () => ({ kind: "allow" }));
    assert.equal(decision.kind, "deny");
    assert.match(decision.reason, /review|commit|deny/i);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("PreToolUse gate allows an ordinary bash command", async () => {
  const root = await tempProject();
  try {
    await writeFile(
      join(root, ".flow-active"),
      JSON.stringify({
        change_id: "demo-change",
        phase: "6",
        task_id: null,
        goal: { scope: "phase", gate_config: { "6-review": "L3" } },
      }),
      "utf8",
    );
    const fake = stubCtx();
    const bridge = new HookBridge({ ctx: fake, packageRoot: BUNDLE_ROOT, config: { hooks: { sessionStart: false, stop: false } } });
    bridge.attach();
    const preExec = fake.handlers.get("tools/pre-execute");

    const exec = {
      name: "bash",
      arguments: { command: "ls -la", description: "list files" },
      agent: { session: { id: "s2", header: { cwd: root } } },
    };
    const decision = await preExec(exec, async () => ({ kind: "allow" }));
    assert.equal(decision.kind, "allow");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("dsh runtime materializes .flow-kit/stop-hook.json (not .claude)", async () => {
  const root = await tempProject();
  try {
    const fake = stubCtx();
    const bridge = new HookBridge({ ctx: fake, packageRoot: BUNDLE_ROOT, config: {} });
    await bridge.ensureProjectConfig(root);
    await access(join(root, ".flow-kit", "stop-hook.json"));
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("synthesizeTranscript maps dsh session events to Claude transcript lines", () => {
  const agent = {
    session: {
      events: [
        { type: "user/message", data: { content: [{ type: "text", text: "hello" }] } },
        { type: "tool/call", data: { callId: "c1", name: "bash", arguments: { command: "pnpm test" } } },
        { type: "tool/result", data: { message: { source: { callId: "c1" }, content: [{ type: "tool-result", content: [{ type: "text", text: "1 passed" }] }] } } },
        { type: "tool/call", data: { callId: "c2", name: "write", arguments: { path: "src/a.ts" } } },
        { type: "assistant/message", data: { message: { content: [{ type: "text", text: "done" }] } } },
      ],
    },
  };
  const lines = synthesizeTranscript(agent);
  assert.deepEqual(lines[0], { type: "user", message: "hello" });
  assert.deepEqual(lines[1], { type: "tool_use", tool: "Bash", args: { command: "pnpm test" } });
  assert.deepEqual(lines[2], { type: "tool_result", tool: "Bash", message: "1 passed" });
  assert.deepEqual(lines[3].tool, "Write");
  assert.equal(lines[3].args.file_path, "src/a.ts");
  assert.deepEqual(lines[4], { type: "assistant", message: "done" });
});

test("Stop chain runs end-to-end on agent idle (00-gate → state file + report)", async () => {
  const root = await tempProject();
  try {
    const fake = stubCtx();
    const bridge = new HookBridge({
      ctx: fake,
      packageRoot: BUNDLE_ROOT,
      config: { timeoutMs: { stop: 60000 } },
    });
    const agent = {
      session: {
        id: "stop-e2e",
        header: { cwd: root },
        events: [
          { type: "user/message", data: { content: [{ type: "text", text: "hello" }] } },
          { type: "tool/call", data: { callId: "c1", name: "bash", arguments: { command: "ls -la" } } },
          { type: "tool/result", data: { message: { source: { callId: "c1" }, content: [{ type: "tool-result", content: [{ type: "text", text: "ok" }] }] } } },
        ],
      },
    };
    await bridge.runStopChain(agent);
    await access(join(root, ".flow-kit", "stop-hook.json"));
    await access(join(root, ".flow-kit", "stop-hook-state.json"));
    const state = JSON.parse(await readFile(join(root, ".flow-kit", "stop-hook-state.json"), "utf8"));
    assert.ok(state.stop_count >= 1, "00-gate incremented stop_count");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("SessionStart hook stdout is injected once as a dsh prompt banner", async () => {
  const root = await tempProject();
  try {
    const configDir = join(root, ".flow-kit");
    await import("node:fs/promises").then(async ({ mkdir }) => mkdir(configDir, { recursive: true }));
    await writeFile(join(configDir, "stop-hook.json"), JSON.stringify({
      session_start: { remind_unreviewed: true },
      output: { report_file: ".flow-kit/stop-hook-report.md", suggestions_file: ".flow-kit/stop-hook-suggestions.md" },
      thresholds: { report_max_age_days: 3 },
    }), "utf8");
    await writeFile(join(configDir, "stop-hook-report.md"), "# Stop Hook Report\n", "utf8");
    await writeFile(join(configDir, "stop-hook-state.json"), "{}", "utf8");

    let promptContext;
    const fake = stubCtx();
    fake.systemPrompt = { context: (def) => { promptContext = def; } };
    const bridge = new HookBridge({
      ctx: fake,
      packageRoot: BUNDLE_ROOT,
      config: { hooks: { preToolUse: false, stop: false, sessionStart: true } },
    });
    bridge.attach();
    const created = fake.handlers.get("agent/created");
    assert.ok(created, "agent/created listener attached");
    created({ agent: { session: { id: "banner-session", header: { cwd: root }, events: [] } } });

    // SessionStart hooks run async via void promise — poll for the banner.
    let banner = "";
    for (let i = 0; i < 50 && !banner; i += 1) {
      await new Promise((resolve) => setTimeout(resolve, 100));
      banner = promptContext?.text({ agent: { session: { id: "banner-session" } } }) ?? "";
    }
    assert.ok(banner.length > 0, "SessionStart banner captured from hook stdout");
    assert.match(banner, /Report|报告|待 Review|Stop Hook/i);
    // Consumed after first read — no repeated injection on every step.
    assert.equal(promptContext.text({ agent: { session: { id: "banner-session" } } }), "");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
