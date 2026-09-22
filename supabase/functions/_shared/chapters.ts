// The chapter ladder for "Plus is the second chapter", and the pure pieces
// of extend-action-plan that decide which chapter comes next and what the
// model is told. No I/O here, so it is unit-testable with `deno test`.
//
// Chapter 1 (generate-action-plan) stays what it is: 7-9 five-to-thirty-minute
// micro-actions, no cost, no code — the free taste. Chapters 2-5 are the
// real thing: concrete build steps on a fixed ladder, sized to the founder's
// skill, time, budget and goal.

export const MAX_CHAPTER = 5;
/** Fewest steps a Plus chapter may have; the function re-asks once below this. */
export const MIN_CHAPTER_STEPS = 6;

export const TECH_SKILLS = ["none", "no_code", "can_code"] as const;
export const HOURS = ["few", "evenings", "full_time"] as const;
export const BUDGETS = ["zero", "under_500", "under_5k", "more"] as const;
export const GOALS = ["side_income", "quit_job", "sell_it", "curious"] as const;

export interface Brief {
  tech_skill: typeof TECH_SKILLS[number];
  hours_per_week: typeof HOURS[number];
  budget: typeof BUDGETS[number];
  goal: typeof GOALS[number];
  notes?: string;
}

/** Validates the request's `brief`; null when any field is missing or off-enum. */
export function parseBrief(raw: unknown): Brief | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  const pick = <T extends readonly string[]>(v: unknown, allowed: T): T[number] | null =>
    typeof v === "string" && (allowed as readonly string[]).includes(v) ? (v as T[number]) : null;
  const tech_skill = pick(r.tech_skill, TECH_SKILLS);
  const hours_per_week = pick(r.hours_per_week, HOURS);
  const budget = pick(r.budget, BUDGETS);
  const goal = pick(r.goal, GOALS);
  if (!tech_skill || !hours_per_week || !budget || !goal) return null;
  const notes = typeof r.notes === "string" ? r.notes.trim().slice(0, 300) : "";
  return { tech_skill, hours_per_week, budget, goal, ...(notes ? { notes } : {}) };
}

export interface ChapterStep { chapter?: number | null; is_completed: boolean }

export type NextChapter =
  | { ok: true; chapter: number }
  | { ok: false; code: "empty" | "chapter_open" | "final_chapter" };

/** The chapter to write next, or why not. */
export function nextChapterFor(steps: ChapterStep[]): NextChapter {
  if (steps.length === 0) return { ok: false, code: "empty" };
  if (steps.some((s) => !s.is_completed)) return { ok: false, code: "chapter_open" };
  const current = Math.max(1, ...steps.map((s) => Number(s.chapter ?? 1)));
  const next = current + 1;
  if (next > MAX_CHAPTER) return { ok: false, code: "final_chapter" };
  return { ok: true, chapter: next };
}

export interface LadderRung {
  title: string;
  summary: string;
  /** What the steps of this chapter are about — pasted into the system prompt. */
  theme: string;
}

export const LADDER: Record<2 | 3 | 4 | 5, LadderRung> = {
  2: {
    title: "Prove people care",
    summary: "Find where the buyers already gather, show up there, and get a number.",
    theme: `CHAPTER 2 — PROVE PEOPLE CARE. Chapter one talked to friends and searched the web. Now the founder goes where the actual buyers already are and collects a signal with a number on it.
Steps must include, adapted to THIS idea: pick ONE channel where the target customer already hangs out (Instagram, TikTok, LinkedIn, a subreddit, a Discord/Facebook group, a local meetup — name it); create the page or profile with a one-line promise; publish 3 posts or 3 community replies; hold 10 conversations with STRANGERS who have the problem; put up a one-page landing (Carrd, Tally, Notion, Typedream) with a waitlist and a target ("25 signups in 2 weeks"); define the go/no-go number for this chapter. Costs stay near zero.`,
  },
  3: {
    title: "Build the smallest real version",
    summary: "Make the thinnest thing a real person can use, using tools that fit the founder.",
    theme: `CHAPTER 3 — BUILD THE SMALLEST REAL VERSION. Not a prototype to admire: the thinnest thing a stranger can actually use for the core promise, this month.
Steps must include, adapted to THIS idea and THIS founder's skill: choose the build path and the exact tools (see BUILD RULES); write the one-sentence scope ("does X, only X"); set up the tool/repo; build the single core flow; a manual/concierge fallback for everything else (the founder does it by hand behind the scenes); a way to collect payment or signups inside it; put it in front of 3 people from chapter 2 and watch them use it.`,
  },
  4: {
    title: "First real users",
    summary: "Get 5-10 people using it, fix what they trip on, and measure one thing.",
    theme: `CHAPTER 4 — FIRST REAL USERS. Onboard 5-10 people by hand (from the chapter-2 waitlist and conversations), watch every one of them, and close the loop.
Steps must include, adapted to THIS idea: a personal onboarding message and a 15-minute walkthrough call; ONE usage metric that means "it works" (name it and where to read it); a weekly feedback ritual (a form, a group chat, or 3 calls); fix the top 3 things users tripped on; collect 3 testimonials or quotes; decide the retention signal to look for in 30 days.`,
  },
  5: {
    title: "Money and the call",
    summary: "Charge for it, launch it, look at the numbers, and decide: go, pivot, or stop.",
    theme: `CHAPTER 5 — MONEY AND THE CALL. The last chapter. Price it, ask real people to pay, launch to a wider audience, and make an honest decision.
Steps must include, adapted to THIS idea: pick a price and a payment method (Stripe Payment Link, Gumroad, Lemon Squeezy, App Store, invoice — name it); ask the users from chapter 4 to pay, with the exact ask; one launch post where the buyers are (Product Hunt, a subreddit, a newsletter, a LinkedIn post — name it); a one-page numbers sheet (costs vs revenue vs hours); a written go / pivot / stop decision with the criteria set in advance; the ONE next milestone if it's a go.`,
  },
};

const SKILL_RULES: Record<Brief["tech_skill"], string> = {
  none: `The founder does NOT code and doesn't want to. Never assign coding. Build steps use no-code or AI builders — name the tool: Glide, Softr, Bubble, Lovable, Replit Agent, Framer, Shopify, Notion + Tally + Zapier/Make, Google Sheets. Prefer a manual/concierge version whenever a tool would take more than a weekend. Templates for build steps are the exact prompt to paste into the AI builder, or the exact checklist to click through.`,
  no_code: `The founder is comfortable with no-code tools but does not write code. Build with no-code/AI builders (Bubble, Softr, Glide, Lovable, Webflow, Zapier/Make, Airtable, Stripe Payment Links) and go deeper than a landing page: real data, logins, payments. Templates for build steps are the exact prompt to paste into the builder or the exact configuration checklist.`,
  can_code: `The founder can code. Build steps may be real engineering: pick a stack and say why (one line), create the repo, auth, ONE core feature, deploy (Vercel/Fly/Supabase/TestFlight), analytics. Still ruthless about scope — the smallest deployable thing. Templates for build steps are the concrete task list or the prompt for a coding assistant.`,
};

const HOURS_RULES: Record<Brief["hours_per_week"], string> = {
  few: "They have 2-4 hours a week. Steps are 15-90 minutes each and the whole chapter fits in about a month; suggest the order that fits weeknights.",
  evenings: "They have evenings and weekends (5-12 hours a week). Steps are 30 minutes to 3 hours; the chapter fits in 2-3 weeks.",
  full_time: "They work on this full time. Steps can be half-days (up to 4 hours) and the chapter should be done in one week.",
};

const BUDGET_RULES: Record<Brief["budget"], string> = {
  zero: "Budget is $0. Only free tiers, free trials, and sweat. Say so when a tool's free tier is enough.",
  under_500: "Budget is under $500 total. Paid tool plans, a domain, small ad tests ($50-100) and a cheap freelancer task (Fiverr/Upwork) are fine — name the amount.",
  under_5k: "Budget is up to $5,000. A freelancer or agency for one well-scoped piece, a designer, paid ads tests and paid tools are fine — name the amount and what it buys.",
  more: "Budget is above $5,000. Hiring help, paid acquisition and paid tools are all on the table; still spend on learning first, building second.",
};

const GOAL_RULES: Record<Brief["goal"], string> = {
  side_income: "Their goal is side income: optimise for the fastest path to the first paying customers with the least ongoing effort.",
  quit_job: "Their goal is to quit their job: optimise for evidence of a real, repeatable business — retention and revenue, not vanity metrics.",
  sell_it: "Their goal is to build something sellable: keep everything documented and measurable, favour assets (audience, list, product) over one-off services.",
  curious: "They're mainly curious: keep every step cheap to reverse, make the learning explicit, and never push a commitment they haven't earned.",
};

export function describeBrief(b: Brief): string {
  return [
    `THE FOUNDER (write for exactly this person):`,
    `- Tech skill: ${b.tech_skill}. ${SKILL_RULES[b.tech_skill]}`,
    `- Time: ${b.hours_per_week}. ${HOURS_RULES[b.hours_per_week]}`,
    `- Budget: ${b.budget}. ${BUDGET_RULES[b.budget]}`,
    `- Goal: ${b.goal}. ${GOAL_RULES[b.goal]}`,
    b.notes ? `- In their own words before this chapter: "${b.notes}"` : "",
  ].filter(Boolean).join("\n");
}

export function buildSystemPrompt(chapter: number, brief: Brief): string {
  const rung = LADDER[chapter as 2 | 3 | 4 | 5];
  if (!rung) throw new Error(`no ladder rung for chapter ${chapter}`);
  return `You are a startup action coach writing chapter ${chapter} of 5 for a founder who finished the previous chapters. Chapter one was a taste — tiny, free, no-code micro-actions to see if the idea holds up. From chapter two on, the steps are REAL: concrete, specific, and sized to this founder.

${rung.theme}

${describeBrief(brief)}

BUILD RULES:
- Every step names the exact tool, platform, place or number. "Post on social media" is banned; "Post 3 before/after reels on the @[handle] TikTok, one per day" is right.
- 6-10 steps — never fewer than 6 — ordered so they can be done top to bottom. Each takes 15 to 240 minutes (use 15, 30, 45, 60, 90, 120, 180 or 240).
- Never repeat a step from earlier chapters, even reworded. A "DIDN'T WORK" outcome means change the approach, not retry it. Quote the founder's own notes back where it makes a step more credible.
- Spending is allowed only within the stated budget, and only when a free path would be clearly slower.
- Coding only if the founder can code; otherwise AI/no-code builders or a manual version.

FIELD RULES:
"text" — ONE sentence, max 10 words, starts with a verb. It's a label beside a node on a path.
"done_criteria" — ONE short binary check with a number where possible ("25 waitlist signups", "3 users completed onboarding").
"template" — the COPY-PASTE READY material for the step: the message/post/email to send, the prompt to paste into an AI or no-code builder, the exact checklist to click through, or the questions to ask. Reference the founder's specific idea, market and channel. Only [brackets] for what you truly can't know.
"action_type" — message | search | email | post | link | generic. Use "link" when the step is done inside a website or tool: deep_link_data.url_scheme is the URL to open, template is what to do there.
"deep_link_data" — all four fields present; "" when not applicable (message → body; search → query; email → body+subject; post → body+url_scheme; link → url_scheme; generic → all "").
"time_estimate_minutes" — 15, 30, 45, 60, 90, 120, 180 or 240. "priority" — 1 = do first. "quadrant" — the SWOT area the step most serves (strength|weakness|opportunity|threat).
"title" — 2-4 word chapter name. "summary" — one sentence: what THIS chapter will prove or produce for THIS idea.`;
}

export interface UserMessageInput {
  chapter: number;
  transcript: string;
  planTitle: string;
  planSummary: string;
  analysisSummary: string;
  strengths: string;
  weaknesses: string;
  opportunities: string;
  threats: string;
  viability: number;
  dims: string;
  weakestLink: string;
  comparables: string;
  history: string;
}

export function buildUserMessage(i: UserMessageInput): string {
  const rung = LADDER[i.chapter as 2 | 3 | 4 | 5];
  return `WRITE CHAPTER ${i.chapter}: ${rung?.title ?? ""}.

VOICE NOTE:
${i.transcript.slice(0, 8000)}

PLAN SO FAR: "${i.planTitle}" — ${i.planSummary}
SUMMARY: ${i.analysisSummary.slice(0, 2000)}
STRENGTHS: ${i.strengths}
WEAKNESSES: ${i.weaknesses}
OPPORTUNITIES: ${i.opportunities}
THREATS: ${i.threats}
VIABILITY: ${i.viability}/100
DIMENSION SCORES (0-10): ${i.dims}
WEAKEST LINK: ${i.weakestLink}
REAL SMALL COMPARABLES: ${i.comparables}

EVERYTHING DONE IN EARLIER CHAPTERS (do not repeat any of these):
${i.history}

Generate chapter ${i.chapter} — "${rung?.title ?? ""}": 6-10 concrete steps with copy-paste templates, sized to this founder.`;
}

/** Same outer shape as chapter one so the app reuses ActionPlanResponse. */
export const CHAPTER_SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string" },
    summary: { type: "string" },
    actions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          text: { type: "string" },
          done_criteria: { type: "string" },
          time_estimate_minutes: { type: "integer", enum: [15, 30, 45, 60, 90, 120, 180, 240] },
          priority: { type: "integer", minimum: 1, maximum: 10 },
          quadrant: { type: "string", enum: ["strength", "weakness", "opportunity", "threat"] },
          template: { type: "string" },
          action_type: { type: "string", enum: ["message", "search", "email", "post", "link", "generic"] },
          deep_link_data: {
            type: "object",
            properties: {
              url_scheme: { type: "string" },
              body: { type: "string" },
              subject: { type: "string" },
              query: { type: "string" },
            },
            required: ["url_scheme", "body", "subject", "query"],
            additionalProperties: false,
          },
        },
        required: ["text", "done_criteria", "time_estimate_minutes", "priority", "quadrant", "template", "action_type", "deep_link_data"],
        additionalProperties: false,
      },
    },
  },
  required: ["title", "summary", "actions"],
  additionalProperties: false,
};
