// hook-bridge.js — decoupled hook dispatcher for dsh.
//
// Claude Code hooks are shell scripts that read a Claude-shaped JSON event on
// stdin. dsh has no Claude hooks JSON, but it has richer Cordis events:
//
//   Claude Code                dsh event                    dispatch point
//   ────────────────────────   ──────────────────────────   ─────────────────────────
//   PreToolUse                tools/pre-execute (waterfall)  sync deny, exit 2 = block
//   Stop                      agent/status → idle            async chain 00-gate → 01..99
//   SessionStart (startup)    agent/created                  async reminder/resume
//   PostToolUse (future)      tools/post-execute             generic runner, if present
//
// This bridge synthesizes the exact JSON shape the shell hooks already parse,
// so the entire shell hook chain (all modules, L2/L3 independent review,
// auto-checkpoint, weak-model compliance, …) is reused unchanged. The only
// runtime facts injected are FLOW_KIT_RUNTIME=dsh and FLOW_KIT_PROJECT_DIR.

import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, copyFileSync } from "node:fs";
import { mkdtemp, writeFile, rm, copyFile, access, mkdir } from "node:fs/promises";
import { join, dirname } from "node:path";
import { tmpdir } from "node:os";

const TOOL_NAME_MAP = {
  bash: "Bash",
  write: "Write",
  edit: "Edit",
  read: "Read",
  read_image: "Read",
};

function claudeToolName(name) {
  return TOOL_NAME_MAP[name] ?? name;
}

function isSubagent(agent) {
  const header = agent?.session?.header;
  if (!header) return false;
  return header.origin === "subagent" || header.parentSession !== undefined;
}

function sessionCwd(agent, exec) {
  return (
    process.env.FLOW_KIT_PROJECT_DIR ??
    agent?.session?.header?.cwd ??
    exec?.agent?.session?.header?.cwd ??
    process.cwd()
  );
}

/** Extract flat text from a dsh message content block list. */
function flattenText(content) {
  if (!Array.isArray(content)) return "";
  const parts = [];
  for (const block of content) {
    if (!block || typeof block !== "object") continue;
    if (block.type === "text" && typeof block.text === "string") parts.push(block.text);
    else if (block.type === "tool-result" && Array.isArray(block.content)) parts.push(flattenText(block.content));
  }
  return parts.join("\n");
}

/**
 * Synthesize a Claude-transcript-shaped JSONL document from the durable dsh
 * session log. The stop-hook transcript parser (01-transcript-parse.sh) only
 * needs `.type`/`.tool`/`.args`/`.message` lines, which are mapped 1:1 below.
 */
export function synthesizeTranscript(agent) {
  const events = agent?.session?.events ?? [];
  const callNames = new Map();
  for (const event of events) {
    if (event.type === "tool/call") callNames.set(event.data?.callId, event.data?.name ?? "unknown");
  }
  const lines = [];
  for (const event of events) {
    const data = event.data ?? {};
    switch (event.type) {
      case "user/message":
        lines.push({ type: "user", message: flattenText(data.content) });
        break;
      case "assistant/message":
        lines.push({ type: "assistant", message: flattenText(data.message?.content) });
        break;
      case "tool/call": {
        const args = { ...(data.arguments ?? {}) };
        // dsh fs tools take `path`; Claude transcripts carry `file_path`.
        if (data.name === "write" || data.name === "edit") args.file_path = args.path ?? args.file_path;
        lines.push({ type: "tool_use", tool: claudeToolName(data.name), args });
        break;
      }
      case "tool/result": {
        const callId = data.message?.source?.callId;
        lines.push({
          type: "tool_result",
          tool: claudeToolName(callNames.get(callId) ?? "unknown"),
          message: flattenText(data.message?.content),
        });
        break;
      }
      default:
        break;
    }
  }
  return lines;
}

function buildEnv(extra = {}) {
  return {
    ...process.env,
    FLOW_KIT_RUNTIME: "dsh",
    FLOW_KIT_PROJECT_DIR: extra.FLOW_KIT_PROJECT_DIR ?? process.env.FLOW_KIT_PROJECT_DIR ?? process.cwd(),
    ...extra,
  };
}

/**
 * Run one shell hook with a JSON event on stdin.
 * Resolves { code, stdout, stderr, timedOut } — never rejects on non-zero exit.
 */
function runHook(scriptPath, eventJson, { timeoutMs = 30000, env = {} } = {}) {
  return new Promise((resolve) => {
    const child = spawn("bash", [scriptPath], {
      env: buildEnv(env),
      stdio: ["pipe", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, timeoutMs);
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", (error) => {
      clearTimeout(timer);
      resolve({ code: -1, stdout, stderr: `${stderr}${error.message}`, timedOut });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({ code: code ?? -1, stdout, stderr, timedOut });
    });
    child.stdin.end(JSON.stringify(eventJson));
  });
}

/**
 * Synchronous variant used only by SessionStart: dsh assembles the first
 * system prompt right after `agent/created`, so the resume/reminder banner
 * must be captured before that callback returns (Claude Code SessionStart
 * hooks are synchronous for the same reason).
 */
function runHookSync(scriptPath, eventJson, { timeoutMs = 10000, env = {} } = {}) {
  try {
    const result = spawnSync("bash", [scriptPath], {
      input: JSON.stringify(eventJson),
      env: buildEnv(env),
      encoding: "utf8",
      timeout: timeoutMs,
      maxBuffer: 1024 * 1024,
    });
    return {
      code: result.status ?? (result.error ? -1 : 0),
      stdout: result.stdout ?? "",
      stderr: result.stderr ?? "",
      timedOut: result.error?.code === "ETIMEDOUT",
    };
  } catch (error) {
    return { code: -1, stdout: "", stderr: String(error), timedOut: false };
  }
}

/** Tail of stderr/stdout for a compact, human-readable deny reason. */
function denyReason(result, fallback) {
  const text = `${result.stderr || ""}\n${result.stdout || ""}`.trim();
  if (!text) return fallback;
  const lines = text.split("\n").filter((line) => line.trim()).slice(-3);
  return lines.join(" | ");
}

export class HookBridge {
  constructor({ ctx, packageRoot, config = {} }) {
    this.ctx = ctx;
    this.packageRoot = packageRoot;
    this.config = config;
    this.hooks = join(packageRoot, "hooks");
    /** session id → SessionStart hook stdout (resume banner / report reminder). */
    this.sessionBanners = new Map();
  }

  /** Install every dsh event listener. Called from apply(). */
  attach() {
    if (this.config.hooks?.preToolUse !== false) this.attachPreToolUse();
    if (this.config.hooks?.stop !== false) this.attachStop();
    if (this.config.hooks?.sessionStart !== false) this.attachSessionStart();
    this.attachPostToolUse();
    this.registerPromptContext();
  }

  /**
   * dsh 等价于 Claude Code SessionStart hook stdout 注入：SessionStart 脚本的
   * stdout（resume banner / stop-report reminder）作为动态 system-prompt
   * context 一次性注入下一次 prompt assembly，读完即清（避免每步重复）。
   */
  registerPromptContext() {
    const systemPrompt = this.ctx?.systemPrompt ?? this.ctx?.get?.("systemPrompt");
    if (!systemPrompt?.context) return;
    try {
      systemPrompt.context({
        name: "flow-kit:session-banner",
        order: 50,
        text: (assembly) => {
          const sessionId = assembly?.agent?.session?.id ?? assembly?.scope?.session?.id;
          if (!sessionId) return "";
          const banner = this.sessionBanners.get(sessionId);
          if (!banner) return "";
          this.sessionBanners.delete(sessionId);
          return banner;
        },
      });
    } catch (error) {
      this.ctx.logger?.warn?.(`[flow-kit] systemPrompt banner context registration skipped: ${error.message}`);
    }
  }

  attachPreToolUse() {
    const gateScript = join(this.hooks, "pre-tool-use", "independent-review-gate.sh");
    const checkpointScript = join(this.hooks, "pre-tool-use", "auto-checkpoint.sh");
    const runtimeGuardScript = join(this.hooks, "pre-tool-use", "runtime-edit-guard.sh");
    const preToolTimeout = Number(this.config.timeoutMs?.preToolUse ?? 20000);

    this.ctx.on("tools/pre-execute", async (exec, next) => {
      const toolName = claudeToolName(exec.name);
      if (!["Bash", "Write", "Edit"].includes(toolName)) return next();

      const cwd = sessionCwd(undefined, exec);
      const eventJson = {
        hook_event_name: "PreToolUse",
        session_id: exec.agent?.session?.id ?? "unknown",
        transcript_path: "",
        cwd,
        tool_name: toolName,
        tool_input: {
          command: exec.arguments?.command ?? "",
          file_path: exec.arguments?.file_path ?? exec.arguments?.path ?? "",
        },
      };

      // 1) Independent-review gate — hard deny on exit 2 (commit / PR / phase
      //    transition / .done forgery). L2/L3 state machine lives in the shell.
      const gate = await runHook(gateScript, eventJson, { timeoutMs: preToolTimeout, env: { FLOW_KIT_PROJECT_DIR: cwd } });
      if (gate.code === 2) {
        return { kind: "deny", reason: denyReason(gate, "flow-kit independent-review gate denied this tool call") };
      }
      if (gate.code !== 0) {
        this.ctx.logger?.warn?.(`flow-kit PreToolUse gate exited ${gate.code}: ${denyReason(gate, "")}`);
      }

      // 2) Write/Edit side hooks: auto-checkpoint + runtime-edit-guard.
      if (toolName !== "Bash") {
        for (const script of [checkpointScript, runtimeGuardScript]) {
          const result = await runHook(script, eventJson, { timeoutMs: preToolTimeout, env: { FLOW_KIT_PROJECT_DIR: cwd } });
          if (result.code === 2) {
            return { kind: "deny", reason: denyReason(result, "flow-kit guard denied this edit") };
          }
          if (result.code !== 0) {
            this.ctx.logger?.warn?.(`flow-kit ${script} exited ${result.code}: ${denyReason(result, "")}`);
          }
        }
      }
      return next();
    });
  }

  attachPostToolUse() {
    const dir = join(this.hooks, "post-tool-use");
    this.ctx.on("tools/post-execute", async (exec, _result, next) => {
      const downstream = await next();
      // Round-1 compatibility seam: flow-kit has no post-tool-use hooks yet,
      // but if a future bundle drops a post-tool-use/*.sh directory, every
      // script in it runs here with a synthesized PostToolUse event.
      let scripts = [];
      try {
        const { readdir } = await import("node:fs/promises");
        const entries = await readdir(dir);
        scripts = entries.filter((entry) => entry.endsWith(".sh")).sort();
      } catch {
        return downstream;
      }
      const eventJson = {
        hook_event_name: "PostToolUse",
        session_id: exec.agent?.session?.id ?? "unknown",
        transcript_path: "",
        cwd: sessionCwd(undefined, exec),
        tool_name: claudeToolName(exec.name),
        tool_input: { command: exec.arguments?.command ?? "", file_path: exec.arguments?.file_path ?? exec.arguments?.path ?? "" },
      };
      for (const script of scripts) {
        await runHook(join(dir, script), eventJson, { timeoutMs: Number(this.config.timeoutMs?.postToolUse ?? 20000), env: { FLOW_KIT_PROJECT_DIR: sessionCwd(undefined, exec) } });
      }
      return downstream;
    });
  }

  attachSessionStart() {
    const scripts = [
      join(this.hooks, "session-start", "stop-report-reminder.sh"),
      join(this.hooks, "session-start", "flow-kit-resume.sh"),
    ];
    this.ctx.on("agent/created", (payload) => {
      const agent = payload?.agent;
      if (!agent || isSubagent(agent)) return;
      const cwd = sessionCwd(agent);
      const eventJson = {
        hook_event_name: "SessionStart",
        source: "startup",
        session_id: agent.session?.id ?? "unknown",
        transcript_path: "",
        cwd,
        parent_session_id: "",
      };
      // Synchronous: the banner must be visible to the first system-prompt
      // assembly, which happens immediately after agent/created.
      this.ensureProjectConfigSync(cwd);
      const banners = [];
      for (const script of scripts) {
        const result = runHookSync(script, eventJson, {
          timeoutMs: Number(this.config.timeoutMs?.sessionStart ?? 10000),
          env: { FLOW_KIT_PROJECT_DIR: cwd },
        });
        if (result.code !== 0) {
          this.ctx.logger?.warn?.(`flow-kit SessionStart ${script} exited ${result.code}: ${denyReason(result, "")}`);
        }
        const stdout = result.stdout?.trim();
        if (stdout) banners.push(stdout);
      }
      if (banners.length > 0) this.sessionBanners.set(agent.session?.id, banners.join("\n"));
    });
  }

  attachStop() {
    const stopGate = join(this.hooks, "stop", "00-gate.sh");
    this.ctx.on("agent/status", (payload) => {
      const agent = payload?.agent;
      if (payload?.status !== "idle" || !agent || isSubagent(agent)) return;
      void this.runStopChain(agent).catch((error) => {
        this.ctx.logger?.warn?.(`flow-kit stop chain failed: ${error.message}`);
      });
    });
  }

  async runStopChain(agent) {
    const stopGate = join(this.hooks, "stop", "00-gate.sh");
    const cwd = sessionCwd(agent);
    await this.ensureProjectConfig(cwd);

    // dsh has no Claude transcript file — synthesize a compatible JSONL so the
    // full transcript-parsing stop chain (01..99, L2/L3 included) runs.
    const tmp = await mkdtemp(join(tmpdir(), "flow-kit-dsh-"));
    const transcriptPath = join(tmp, "transcript.jsonl");
    const lines = synthesizeTranscript(agent);
    await writeFile(transcriptPath, lines.map((line) => JSON.stringify(line)).join("\n"), "utf8");

    const eventJson = {
      hook_event_name: "Stop",
      session_id: agent.session?.id ?? "unknown",
      transcript_path: transcriptPath,
      cwd,
      parent_session_id: "",
      stop_hook_active: true,
    };
    try {
      const result = await runHook(stopGate, eventJson, {
        timeoutMs: Number(this.config.timeoutMs?.stop ?? 600000),
        env: { FLOW_KIT_PROJECT_DIR: cwd },
      });
      if (result.code !== 0) {
        this.ctx.logger?.warn?.(`flow-kit stop chain exited ${result.code}: ${denyReason(result, "")}`);
      }
    } finally {
      await rm(tmp, { recursive: true, force: true }).catch(() => {});
    }
  }

  /** Synchronous config materialization for SessionStart (see runHookSync). */
  ensureProjectConfigSync(cwd) {
    const targetDir = join(cwd, ".flow-kit");
    const targetFile = join(targetDir, "stop-hook.json");
    const source = join(this.hooks, "config", "stop-hook.json");
    if (existsSync(targetFile)) return targetFile;
    try {
      mkdirSync(targetDir, { recursive: true });
      copyFileSync(source, targetFile);
    } catch (error) {
      this.ctx.logger?.warn?.(`flow-kit could not materialize .flow-kit/stop-hook.json: ${error.message}`);
    }
    return null;
  }

  /** Materialize the dsh-runtime config dir (.flow-kit/) from package defaults. */
  async ensureProjectConfig(cwd) {
    const targetDir = join(cwd, ".flow-kit");
    const targetFile = join(targetDir, "stop-hook.json");
    const source = join(this.hooks, "config", "stop-hook.json");
    try {
      await access(targetFile);
      return targetFile;
    } catch {
      // fall through — copy the packaged default
    }
    try {
      await mkdir(targetDir, { recursive: true });
      await copyFile(source, targetFile);
      return targetFile;
    } catch (error) {
      this.ctx.logger?.warn?.(`flow-kit could not materialize .flow-kit/stop-hook.json: ${error.message}`);
      return null;
    }
  }
}
