// skill-loader.js — register flow-kit's bundled skills into dsh's skill registry.
//
// dsh exposes `ctx.skills.register({ name, description, content, resourceBase })`
// for runtime (packaged) skills. We read every `SKILL.md` shipped in this
// package (flow-* and brooks-*), parse the dsh-compatible YAML frontmatter
// (`name` + `description`), and register the body. Resource references inside
// a skill resolve against its directory via `resourceBase`.
//
// This is the dsh-native replacement for install.sh copying skills into
// ~/.claude/skills or ~/.dsh/skills — the plugin is self-contained.

import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";

const FRONTMATTER = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/;

function parseFrontmatter(text) {
  const match = text.match(FRONTMATTER);
  if (!match) return null;
  const meta = {};
  const lines = match[1].split(/\r?\n/);
  let currentKey = null;
  for (const line of lines) {
    const keyMatch = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (keyMatch) {
      currentKey = keyMatch[1];
      meta[currentKey] = keyMatch[2].trim();
    } else if (currentKey && /^\s+/.test(line)) {
      // Multiline YAML description continuation (| or plain indented).
      const value = meta[currentKey];
      meta[currentKey] = value ? `${value}\n${line.trim()}` : line.trim();
    } else {
      currentKey = null;
    }
  }
  return { meta, body: match[2].trimStart() };
}

function parseDescription(description) {
  if (!description) return "";
  // YAML block scalar "|" keeps trailing newlines; fold to one clean line list.
  return description.split("\n").map((line) => line.trim()).filter(Boolean).join("\n");
}

async function skillFromDir(dir) {
  const file = join(dir, "SKILL.md");
  let text;
  try {
    text = await readFile(file, "utf8");
  } catch {
    return null;
  }
  const parsed = parseFrontmatter(text);
  if (!parsed?.meta.name) return null;
  return {
    name: parsed.meta.name,
    description: parseDescription(parsed.meta.description),
    content: parsed.body,
    source: "bundled",
    resourceBase: { kind: "directory", path: dir },
  };
}

async function skillDirs(root) {
  const out = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name.startsWith("_")) continue;
    out.push(join(root, entry.name));
  }
  return out;
}

export async function loadBundledSkills(packageRoot) {
  const roots = [
    join(packageRoot, "skills"),
    join(packageRoot, "brooks-lint", "plugin", "skills"),
  ];
  const skills = [];
  for (const root of roots) {
    let dirs = [];
    try {
      dirs = await skillDirs(root);
    } catch {
      continue;
    }
    for (const dir of dirs) {
      const skill = await skillFromDir(dir);
      if (skill) skills.push(skill);
    }
  }
  return skills;
}

export function registerBundledSkills(ctx, skills) {
  for (const skill of skills) {
    try {
      ctx.skills.register(skill);
    } catch (error) {
      ctx.logger?.warn?.(`[flow-kit] skill "${skill.name}" registration skipped: ${error.message}`);
    }
  }
}
