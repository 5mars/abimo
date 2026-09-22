# AI cost controls — what's in place, what it costs, what to change

Audited 2026-09-21 against `supabase/functions/*` and the migrations.
Prices: OpenAI list prices on the same date (gpt-4o $2.50 in / $10 out per
1M tokens; whisper-1 $0.006 per minute; web-search tool $10 per 1,000 calls
plus search content billed as input tokens).

## The architecture is already the right one

This is the setup that production AI apps use, and Abimo has it:

| Layer | Abimo | Why it matters |
|---|---|---|
| The OpenAI key never ships in the app | ✅ only in Supabase Edge Function secrets | A key in the binary is extracted within hours of launch |
| Every AI call goes through your server | ✅ six edge functions | You decide who may call and how often |
| Caller must be a signed-in user | ✅ JWT verified at the gateway and in `_shared/gate.ts` | Anonymous traffic is refused for free |
| Sign-up needs a confirmed e-mail | ✅ Supabase setting | Makes mass account creation cost the attacker something |
| Per-user, per-day budgets, atomically counted | ✅ `consume_ai_credit` RPC, `ai_usage` table | The one control that actually bounds spend per account |
| Budgets by tier, from the server's own record | ✅ `profiles.is_premium`, written only after verifying Apple's signed receipt | A hacked client can't claim Plus |
| Output size caps | ✅ `max_tokens` 4096 / 2500 / 2500, research 4000 | Bounds the expensive side (output tokens) |
| Input size caps | ✅ transcript ≤ 8k chars, audio ≤ 20 MB from your own bucket only | Stops the "send a 3-hour file" trick and the SSRF hole |
| Research cached by transcript hash | ✅ `research_digests` | Re-tastes don't pay for search twice |
| Hard spend cap at the provider | ⚠️ you: prepaid $20, no auto-refill, personal account | The backstop behind everything above |

Nobody can run up your bill without first creating a confirmed account, and
each account is capped per day. The remaining questions are *how much* a
capped account can cost and *what happens when the prepaid balance runs out*.

## What a single account can cost per day (worst case, after the tier deploy)

| Call | Free/day | Plus/day | Cost per call, worst case | Notes |
|---|---|---|---|---|
| transcribe (gpt-4o-mini-transcribe) | 3 | 6 | **≈ $0.15** (20 MB ≈ 25 min at $0.006/min) | dominated by *length*; typical 2-min idea = $0.012 |
| research (gpt-4o + web search) | 3 | 6 | ≈ $0.10–0.20 | $0.01 per search call (model may search several times) + ~20k content tokens + 4k output |
| analyze-swot (gpt-4o) | 6 | 12 | ≈ $0.07–0.10 | ~12k input (prompt + transcript + digest), up to 4k output, sometimes a second remix call |
| plan / next chapter (gpt-4o-mini) | 6 / 0 | 12 / 12 | ≈ $0.05 | 2.5k output cap |

- **Hostile free account, maxing everything with 25-minute recordings: ≈ $1.6/day.**
  With normal 2-minute recordings: ≈ $1.0/day.
- **Plus account maxing everything: ≈ $6–7/day**, against $4.24/month net
  revenue. Nobody does this by accident, but the caps allow it.
- **A normal user:** one idea = transcribe + research + SWOT + plan
  ≈ **$0.25–0.35**. A free user's three ideas cost you about $1 in total;
  a typical Plus user (a few ideas a month, some re-tastes) costs $1–3/month.

Unit economics are fine. The exposure is the tail: someone scripting
sign-ups. Each account costs them a working e-mail address and gets them at
most ~$1.6 of your money per day, and your provider cap ends the game.

## What to change (ordered by value)

1. **Move OpenAI off the personal account.** OpenAI dashboard → create an
   *Organization* if you don't have one, then **Projects → New project
   "Abimo production"**. Create a **project API key** there, paste it into
   Supabase → Edge Functions → Secrets as `OPENAI_API_KEY` (takes effect on
   the next invocation, no redeploy), then revoke the old personal key.
   Set the project's **budget limit** (e.g. $100/month) and an alert at 50 %.
2. **Prepaid balance: keep it, but turn auto-recharge ON with a ceiling.**
   "$20, no refill" protects your wallet but kills the app the moment the
   balance hits zero — including during App Review, which is a rejection.
   Settings → Billing: recharge $25 when below $10, monthly cap $100. Your
   worst month is then $100, and the app never goes dark for a paying user.
   Raise the cap as revenue comes in; it's a five-second change.
3. ✅ *Done 2026-09-22.* **Cap recording length in the app (5 minutes).** Transcription is the
   only call whose cost scales with what the user sends, and there is no
   limit today (`AudioRecordingService.swift` records until stopped; 20 MB
   is the only ceiling). A 5-minute cap makes the worst free account
   ≈ $0.9/day and matches the product ("one idea, said out loud").
4. ✅ *Done 2026-09-22 (needs the function redeploy).* **Cheaper models where calibration doesn't matter.** Keep gpt-4o for
   `analyze-swot` — the score is calibrated to it. Switch
   `generate-action-plan` and `extend-action-plan` to **gpt-4o-mini**
   (16× cheaper, plenty for step lists) and `transcribe-audio` to
   **gpt-4o-mini-transcribe** ($0.003/min, half of whisper-1). Saves ~30 %
   of a typical idea's cost with no visible change.
5. ✅ *Done 2026-09-22 — Plus is now 6/6/12/12 (needs the function redeploy).* **Tighten Plus daily caps or add a monthly one.** 10/10/20/20 per *day*
   lets one subscriber cost 50× their fee. Either 5/5/10/10 per day, or keep
   the daily caps and add a monthly cap (e.g. 60 tastings) in
   `consume_ai_credit` — "burners back next month" copy already fits.
6. **Supabase Pro ($25/month) before launch.** The free plan pauses a project
   after a week of inactivity (a paused backend during review = rejection),
   has 500 MB database / 1 GB file storage (your voice recordings live there)
   and no backups. Pro removes pausing, gives daily backups, 8 GB DB,
   100 GB storage, 2M function invocations. This is the single most common
   "what do people normally do" answer for a Supabase-backed app.
7. **Alerting.** OpenAI budget alert (above), Supabase → Settings → Usage
   alerts, and a weekly look at `scripts/sql/score_histogram.sql` plus a new
   query on `ai_usage` for accounts hitting their cap every day (that's your
   abuser signal — delete the account).
8. **Optional, if abuse shows up:** Supabase Auth → Attack Protection →
   enable Cloudflare Turnstile on sign-up (supabase-swift supports the
   captcha token; needs a small web view in `SignUpView`), and lower the
   Auth rate limit for sign-ups per IP.

## Scalability — will it fall over?

- **Edge functions** scale horizontally; each AI call is one invocation
  (~4 per idea). 10,000 ideas/month = 40k invocations, far under the free
  plan's 500k and Pro's 2M.
- **Database** load is trivial (a few rows per idea, RLS on every table).
  Storage is the thing that grows: a 2-minute recording is ~2 MB; 10,000
  ideas ≈ 20 GB. Pro's 100 GB lasts a long time; consider deleting the audio
  after transcription (keep the transcript) as a later optimisation.
- **OpenAI rate limits** for a new project (Tier 1: 500 requests/min on
  gpt-4o) exceed anything a launch produces. If you ever see 429s from
  OpenAI rather than from your own gate, prepay more — tiers rise with spend.
- **Firebase Analytics / Crashlytics** are free at any volume you'll see.
- **StoreKit / entitlement verification** is per-launch and cached daily.

## Monthly bill at three sizes (rounded)

| | 100 users, 5 paying | 1,000 users, 50 paying | 10,000 users, 500 paying |
|---|---|---|---|
| OpenAI (≈$0.30/idea, ~2 ideas/free user, ~8/Plus user) | ≈ $70 | ≈ $700 | ≈ $7,000 |
| Supabase Pro | $25 | $25 | $25 + egress |
| Apple net revenue ($4.24/mo, blended with yearly) | ≈ $20 | ≈ $200 | ≈ $2,000 |

Read that honestly: at the free tier's generosity (three full tastings with
web research for $0), **free users cost more than Plus users pay** until
conversion is well above 5 %. That's normal for a freemium AI app and it's
why the caps, the cheaper models for non-scored calls, and the recording cap
matter more than any other engineering work before launch. Watch
`paywall_shown → purchase_succeeded` in Firebase for the first month and
tighten the free tier (e.g. research only on the first idea) if conversion
is low.
