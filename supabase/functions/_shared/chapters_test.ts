import { assert, assertEquals, assertStringIncludes } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  buildSystemPrompt, buildUserMessage, CHAPTER_SCHEMA, LADDER, MAX_CHAPTER, nextChapterFor, parseBrief,
} from "./chapters.ts";

const brief = parseBrief({ tech_skill: "none", hours_per_week: "few", budget: "zero", goal: "side_income" })!;

Deno.test("five chapters, full stop", () => {
  assertEquals(MAX_CHAPTER, 5);
  assertEquals(Object.keys(LADDER).map(Number).sort(), [2, 3, 4, 5]);
});

Deno.test("nextChapterFor: empty, open, next, final", () => {
  assertEquals(nextChapterFor([]), { ok: false, code: "empty" });
  assertEquals(nextChapterFor([{ chapter: 1, is_completed: true }, { chapter: 1, is_completed: false }]), { ok: false, code: "chapter_open" });
  assertEquals(nextChapterFor([{ chapter: null, is_completed: true }]), { ok: true, chapter: 2 });
  assertEquals(nextChapterFor([{ chapter: 1, is_completed: true }, { chapter: 4, is_completed: true }]), { ok: true, chapter: 5 });
  assertEquals(nextChapterFor([{ chapter: 5, is_completed: true }]), { ok: false, code: "final_chapter" });
});

Deno.test("parseBrief rejects off-enum values and clips notes", () => {
  assertEquals(parseBrief(null), null);
  assertEquals(parseBrief({ tech_skill: "wizard", hours_per_week: "few", budget: "zero", goal: "curious" }), null);
  const b = parseBrief({ tech_skill: "can_code", hours_per_week: "full_time", budget: "more", goal: "sell_it", notes: "x".repeat(400) })!;
  assertEquals(b.notes?.length, 300);
  const noNotes = parseBrief({ tech_skill: "no_code", hours_per_week: "evenings", budget: "under_500", goal: "quit_job", notes: "   " })!;
  assertEquals("notes" in noNotes, false);
});

Deno.test("the ladder theme lands in the system prompt for each chapter", () => {
  for (const chapter of [2, 3, 4, 5] as const) {
    const prompt = buildSystemPrompt(chapter, brief);
    assertStringIncludes(prompt, `chapter ${chapter} of 5`);
    assertStringIncludes(prompt, LADDER[chapter].title.toUpperCase());
  }
});

Deno.test("skill changes the build rules: no code for none, engineering for can_code", () => {
  const none = buildSystemPrompt(3, brief);
  assertStringIncludes(none, "Never assign coding");
  assert(!none.includes("create the repo"));
  const coder = buildSystemPrompt(3, parseBrief({ tech_skill: "can_code", hours_per_week: "few", budget: "zero", goal: "side_income" })!);
  assertStringIncludes(coder, "create the repo");
  assert(!coder.includes("Never assign coding"));
});

Deno.test("chapters 2-5 are not chapter-one micro-actions", () => {
  const prompt = buildSystemPrompt(2, brief);
  assert(!prompt.includes("identical to chapter one"));
  assert(!prompt.includes("zero cost, no coding"));
  assertStringIncludes(prompt, "15 to 240 minutes");
  assertStringIncludes(prompt, "6-10 steps");
  const times = (CHAPTER_SCHEMA.properties.actions.items.properties.time_estimate_minutes as { enum: number[] }).enum;
  assertEquals(Math.max(...times), 240);
  assert((CHAPTER_SCHEMA.properties.actions.items.properties.action_type as { enum: string[] }).enum.includes("link"));
});

Deno.test("the founder's note is quoted back", () => {
  const b = parseBrief({ tech_skill: "none", hours_per_week: "few", budget: "zero", goal: "curious", notes: "I already have 40 Instagram followers" })!;
  assertStringIncludes(buildSystemPrompt(2, b), "40 Instagram followers");
});

Deno.test("user message names the chapter and carries the history", () => {
  const msg = buildUserMessage({
    chapter: 4, transcript: "t", planTitle: "P", planSummary: "S", analysisSummary: "A",
    strengths: "s", weaknesses: "w", opportunities: "o", threats: "th", viability: 61, dims: "d",
    weakestLink: "wl", comparables: "c", history: "- [ch3] Built the Glide app [DID IT]",
  });
  assertStringIncludes(msg, "WRITE CHAPTER 4: First real users.");
  assertStringIncludes(msg, "[ch3] Built the Glide app");
});
