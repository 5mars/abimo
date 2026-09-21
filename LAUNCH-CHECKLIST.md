# Abimo — TestFlight & App Store Launch Checklist

Everything code-side is done and committed. The steps below are the manual ones
only you can do (they need your Apple/Google/OpenAI accounts). Work top to bottom —
each section is ordered so nothing blocks a later step.

---

## 1. One-time account setup (~20 min)

### 1a. OpenAI spend cap — do this first
1. Go to https://platform.openai.com/settings/organization/limits
2. Set a **monthly budget (hard limit)**: suggested **$50** at launch scale.
3. Set an **email alert** at $25.

This is the final backstop behind the per-user rate limits already deployed.
Even if everything else failed, your bill can never exceed this number.

### 1b. Firebase project (~10 min)
1. Go to https://console.firebase.google.com → **Create project** → name it `Abimo`
   (Google Analytics: leave enabled, default settings).
2. In the project: **Add app → iOS**. Bundle ID: `com.mars.Abimo`. Nickname: Abimo.
3. **Download `GoogleService-Info.plist`.**
4. In Xcode, drag the file into the `Abimo/` folder (the yellow group with the
   source files). Check **"Copy items if needed"** and target **Abimo**.
5. In the Firebase console, also enable **Crashlytics** (Build → Crashlytics → Get started).

That's it — the code already calls `FirebaseApp.configure()` and skips gracefully
when the file is missing, so nothing else changes.

**Verify:** in Xcode, edit the Abimo scheme → Run → Arguments → add
`-FIRDebugEnabled`. Run the app, open Firebase console → Analytics → **DebugView**,
and click around (record an idea, open the paywall). Events should stream in live.
Remove the argument afterwards — without it, debug builds send nothing (by design).

Events you'll see: `login`, `sign_up`, `screen_view` (per tab), `idea_created`,
`pipeline_stage_completed`, `pipeline_completed`, `pipeline_failed`, `analysis_viewed`,
`gate_hit`, `paywall_shown` (with `context`), `purchase_initiated`,
`purchase_succeeded`, `purchase_failed`, `purchase_restored`, `trial_started`.

### 1c. Funnels to build later in Firebase (once real data flows)
In Analytics → **Explore → Funnel exploration**:
1. **Activation:** `login` → `idea_created` → `pipeline_completed` → `analysis_viewed`
2. **Monetization:** `gate_hit` → `paywall_shown` → `purchase_initiated` → `purchase_succeeded`
   (add breakdown by the `context` parameter to see which gate converts)
3. **Reliability:** `idea_created` → `pipeline_completed`, plus a free-form
   exploration of `pipeline_failed` broken down by `stage`

---

## 2. App Store Connect setup (~45 min)

Prereq: your Apple Developer Program membership is active (team `VMFBV25WD2`).

### 2a. Create the app record
1. https://appstoreconnect.apple.com → My Apps → **+ → New App**
2. Platform iOS · Name **Abimo** · Primary language English ·
   Bundle ID `com.mars.Abimo` · SKU e.g. `abimo-ios`.

### 2b. Create the subscriptions (must match the code exactly)
Monetization → Subscriptions → **Create subscription group** named `Abimo Plus`, then:

| Product ID | Duration | Price | Intro offer |
|---|---|---|---|
| `com.mars.Abimo.plus.monthly` | 1 month | $4.99 | — |
| `com.mars.Abimo.plus.yearly` | 1 year | $34.99 | 3-day free trial |

- Each needs a localized display name + description (e.g. "Abimo Plus Monthly" /
  "Unlimited ideas and full tasting reports").
- Each needs a **review screenshot** — a screenshot of the paywall is fine.
- Product IDs are case-sensitive and permanent. Copy-paste them.

### 2c. App Privacy section
Privacy Policy URL: `https://5mars.github.io/abimo-legal/privacy/`

Data collection questionnaire — declare, all **linked to identity**, none used for tracking:
- **Contact info → Email address** (app functionality)
- **User content → Audio data** (app functionality)
- **Identifiers → User ID** (app functionality + analytics)
- **Usage data → Product interaction** (analytics)
- **Diagnostics → Crash data + Performance data** (app functionality / analytics)

Answer **No** to "do you use data for tracking" — the app has no IDFA/ads.

### 2d. Age rating + category
- Category: **Productivity** (secondary: Business).
- Age rating questionnaire: everything "No" → 4+.

---

### 2e. App icon redraw (palette change, Sept 2026)
The app moved to a teal-on-cream palette (the horse's brown is the accent,
not the brand). The only red left anywhere is the raster app icon
(`Abimo/Assets.xcassets/AppIcon.appiconset/AppIcon-light.png`, `-dark.png`,
`-tinted.png`, 1024×1024). Redraw it on teal `#2A9D8F` / cream `#FFFBF5`
(the horse on a teal circle works) and drop the three PNGs back in with the
same filenames. Until then the launch screen (teal) and the icon (coral) disagree.

### 2f. Project location
The repo now lives at `~/Developer/abimo` — NOT under `~/Desktop`. iCloud's
Desktop sync was creating `Foo 2.swift` duplicates that Xcode compiled as
redeclarations. Open `~/Developer/abimo/Abimo.xcodeproj` from now on.

---

## 3. Archive & upload (~15 min)

1. In Xcode select the **Abimo** scheme, destination **Any iOS Device (arm64)**.
2. **Product → Archive** (uses Release config — the debug premium override is
   compiled out automatically).
3. Organizer window → **Distribute App → App Store Connect → Upload** (defaults fine).
4. Wait ~15–30 min for processing; you'll get an email when the build is ready.
   The privacy manifest and dSYM upload are already wired in.

If the upload complains about the app icon: the dark/tinted variants are currently
copies of the light icon — acceptable, but real variants look better on iOS 18+
themed home screens (asset catalog: `AppIcon.appiconset`).

---

## 4. TestFlight (~10 min + review wait)

1. App Store Connect → your app → **TestFlight** tab.
2. The uploaded build appears; answer the export-compliance question
   (uses standard encryption only → **Yes, exempt** — HTTPS only).
3. **Internal testing:** create a group, add your own Apple ID → instant install
   via the TestFlight app. Test on your real phone:
   - record → transcribe → analysis → action plan end-to-end
   - hit the 3-idea cap → paywall from each gate
   - **sandbox purchase**: Settings → App Store → Sandbox Account (create a
     sandbox tester in App Store Connect → Users and Access → Sandbox), buy
     monthly and yearly, test Restore Purchases, test account deletion
   - background the app mid-pipeline → notification arrives
4. **External testing** (optional, for friends/strangers): create an external
   group, add emails or enable a public link. First external build requires a
   lightweight **Beta App Review** (~1 day).

---

## 5. App Store submission

1. **Screenshots**: required for 6.9" (iPhone 17 Pro Max) and 6.5" displays.
   Take them in the simulator (Cmd+S). 4–6 screens: kitchen with ideas, recording,
   the tasting report/score, action plan, paywall.
2. **Metadata**: description, keywords (e.g. startup ideas, voice notes, idea
   validation, side project, business coach), support URL
   (`https://5mars.github.io/abimo-legal/`), marketing URL optional.
3. **App Review Information — critical because the app is login-gated:**
   - Create a demo account in the app (e.g. `review@cinqmars.ca` + password),
     confirm its email, and put the credentials in the review notes.
   - Note for the reviewer: "AI analysis takes ~60–90 s per idea. Free tier
     allows 3 ideas; the Abimo Plus subscription unlocks unlimited ideas and
     full analysis detail."
4. Attach the build, select the subscriptions for this version, **Submit for Review**.
   First review typically takes 1–3 days. Common first-app rejections are already
   handled: working privacy URL ✓, restore purchases ✓, account deletion ✓,
   demo account ✓, subscription disclosure text ✓.

---

## Deployed server-side protection (reference)

Already live on Supabase project `ymbfqlrarlnqtzatgfah` (verified with curl):

| Protection | Value |
|---|---|
| JWT verification | all 4 edge functions, gateway + in-function |
| Daily per-user budgets | transcribe 10 · research 10 · SWOT 20 · plan 20 |
| voice_notes insert backstop | 10/user/day (DB trigger) |
| transcribe-audio URL lock | only this project's voice-recordings bucket, ≤20 MB |
| max_tokens caps | SWOT 4096 · plan 2500 · research 3000 |
| Input caps | transcription ≤8k chars, pivot ≤500/field |

Worst case per hostile account ≈ $2–4/day; your OpenAI hard cap (step 1a) bounds
the total. When a user hits a limit the app shows "The kitchen's done for today…".

## Known issue (pre-existing, not launch-blocking)
The unit-test host app intermittently crashes on the simulator
(`malloc: pointer being freed was not allocated`) which aborts some test runs.
Verified to exist before the Firebase/security changes. The app itself runs
normally. Worth a debugging session before building more test coverage.

## Scoring v2 (deployed 2026-09-16) — reference

The viability score is computed in `supabase/functions/_shared/scoring.ts`
(`computeScoreV2`): no verdict-band clamp, deterministic evidence caps from
the research digest's numbers, weakest-link gate, calibrated piecewise map,
hedge penalty. Every scoring call writes a `score_audits` row; research
digests are cached in `research_digests` by transcript hash.

**Redeploy procedure (any change under `supabase/functions/`):**

```bash
deno test supabase/functions/_shared/                      # scoring anchors + JWS entitlement tests
deno check supabase/functions/_shared/*.ts supabase/functions/*/index.ts
supabase db push                                          # only if a new migration was added
supabase functions deploy analyze-swot research-market generate-action-plan transcribe-audio verify-entitlement extend-action-plan
```

All six functions import `_shared/gate.ts`, so redeploy all six together.

**Secrets (Supabase → Edge Functions → Secrets):** `OPENAI_API_KEY` (existing);
`AI_LIMIT_EXEMPT_USER_IDS` — comma-separated user ids of calibration accounts
(no daily AI budget; their audits are flagged `is_calibration`). Never list a
real user here.

**Calibration:** `scripts/calibration-test.sh` (needs `.env`, see
`.env.example`). Acceptance criteria are in the script header. Live
distribution: `scripts/sql/score_histogram.sql` in the dashboard SQL editor —
watch `pct_mid` for `scoring_version = 2` vs the v1 rows.

**Prompt anchors** ("Final ~N" in `analyze-swot/index.ts`) must be regenerated
from `scoring_test.ts` whenever the math changes — the model fights stale
anchors by inflating dimensions.

## Plus is the second chapter (built 2026-09-16; migration + verify-entitlement LIVE 2026-09-17, tier caps HELD) — reference

Server-side tiers. Free = one full taste + chapter 1 per idea, 3 active ideas,
daily AI caps 3 (research/transcribe) / 6 (analyze/plan). Plus = next chapters,
re-taste, full evidence, unlimited ideas, caps 10/10/20/20.

**Order of operations (the client ships last):**
1. ✅ DONE 2026-09-17 — `supabase db push` applied `20260916130000_profiles_plus.sql`
   (profiles + `is_plus()` + tier-aware voice_notes trigger + `micro_actions.chapter`
   + `swot_analyses.score_history/retaste_count`) and `verify-entitlement` is
   deployed (smoke-tested: null JWS → 200 + row stamped; garbage JWS → 400;
   no auth → 401). Backfill verified for the calibration user.
   ⚠️ pg_cron is NOT installed on the project: Database → Extensions → enable
   `pg_cron`, then run the `cron.schedule('expire-lapsed-plus', …)` block from
   the migration by hand in the SQL editor. Until then a lapsed subscriber
   keeps Plus server-side until their app next syncs (the client downgrades
   them regardless — StoreKit is the UI's source of truth).
2. ⏳ HELD — deploy the other five functions
   (`analyze-swot research-market generate-action-plan transcribe-audio
   extend-action-plan`). This also carries the calibration round-1 scoring fix.
   From this point free users are capped at 3/3/6/6 and Plus users are capped
   at 3/3/6/6 TOO until their app syncs an entitlement — so ship the iOS build
   promptly, and warn in release notes that Plus users should open the app once.
3. Ship the iOS build. On launch `EntitlementService.syncServer()` posts the
   StoreKit 2 `jwsRepresentation` to `verify-entitlement`, which verifies the
   x5c chain to Apple Root CA G3 locally and upserts `profiles`.

**Secrets:** `SUPABASE_SERVICE_ROLE_KEY` (injected automatically; used only
by verify-entitlement to write profiles). `ALLOW_STOREKIT_TEST_ENV=true` ONLY
on a dev project — accepts Xcode StoreKit-Testing transactions, which do not
chain to Apple. Never set it in production. Optional
`APPLE_ROOT_CA_G3_SHA256` overrides the pinned root fingerprint if Apple
rotates it (verify at apple.com/certificateauthority first).

**App Store Connect (manual):**
- [ ] Monthly `com.mars.Abimo.plus.monthly`: add introductory offer, free, 1 week.
- [ ] Yearly `com.mars.Abimo.plus.yearly`: change introductory offer 3 days → 1 week.
- [ ] Update subscription descriptions to match `AbimoPlus.storekit`
      ("Next chapters, re-tastes, full evidence, unlimited ideas").
- [ ] Re-shoot paywall review screenshots (benefits copy changed).
- [ ] Existing subscribers keep unlimited slots — the promise holds; nothing to migrate.

**Verify after deploy (Jeremy, signed in):**
- [ ] Free account: 4th transcription of the day → progress screen shows
      "Keep the burners on — go Plus" and the `.dailyCap` paywall.
- [ ] StoreKit Testing purchase → within a minute `profiles.is_premium = true`
      for that user (dashboard). Requires `ALLOW_STOREKIT_TEST_ENV=true` on a dev project.
- [ ] Finish a plan → wrap-up → Next chapter → 5-7 steps appended with
      `chapter = 2`, journey shows them after chapter 1, first one marked NEXT.
- [ ] Wrap-up → Re-taste → row keeps its id (`select id, retaste_count,
      jsonb_array_length(score_history) from swot_analyses`), gauge shows the delta.
- [ ] Free account tapping Next chapter / Re-taste → paywall, `gate_hit` logged.
