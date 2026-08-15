// skill-loader.test.mjs — bundled skill discovery and frontmatter parsing.
import test from "node:test";
import assert from "node:assert/strict";
import { resolve } from "node:path";
import { loadBundledSkills, registerBundledSkills } from "../lib/skill-loader.js";

const BUNDLE_ROOT = resolve(import.meta.dirname, "../../flow-kit-bundle");

test("loads every flow-* and brooks-* skill from the bundle", async () => {
  const skills = await loadBundledSkills(BUNDLE_ROOT);
  const names = skills.map((s) => s.name);
  assert.ok(names.includes("flow"));
  assert.ok(names.includes("flow-kit-install"));
  assert.ok(names.includes("flow-architect"));
  assert.ok(names.includes("brooks-review"));
  // every discovered skill carries dsh-required fields
  for (const skill of skills) {
    assert.ok(skill.name, "name required");
    assert.ok(skill.description.length > 0, `${skill.name} description required`);
    assert.ok(skill.content.length > 0, `${skill.name} content required`);
    assert.equal(skill.resourceBase.kind, "directory");
  }
  console.log(`discovered ${skills.length} skills: ${names.length} unique`);
});

test("registerBundledSkills tolerates a missing skills service", () => {
  const registered = [];
  const ctx = { skills: { register: (skill) => registered.push(skill.name) }, logger: { warn: () => {} } };
  registerBundledSkills(ctx, [{ name: "flow", description: "x", content: "# x", resourceBase: { kind: "directory", path: "/tmp" } }]);
  assert.deepEqual(registered, ["flow"]);
});
