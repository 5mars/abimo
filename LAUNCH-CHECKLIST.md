# Abimo — TestFlight & App Store Launch Checklist

Updated 2026-09-21. Code-side work for 1.0 is committed on `gsd-testing`
(iOS 18 floor, teal icon, privacy manifest, deletion fix, store tooling and
metadata under `docs/store/`). Everything below is the manual path, in the
order that avoids blocking a later step. ☐ = still to do · ☑ = done.

Decisions locked for 1.0: Individual Apple account (legal name shows as
Seller — accepted), based in Quebec; **no EU distribution** (keeps your
address/phone off the store page); domain **abimo.ca** with role e-mails;
GitHub repo private; English only.

---

## 0. Day one — accounts and money (~1 h, approvals take days, so first)

### 0a. Apple: Agreements, Tax, and Banking
App Store Connect → Business (or Agreements, Tax, and Banking).
- ☐ **Paid Apps Agreement** — accept as Account Holder. Subscriptions stay
  "Missing Metadata / not submittable" until this is *Active*.
- ☐ **Tax** — the prompt is country-specific. For Canada it asks GST/HST
  (and **QST** for Quebec) registration. If you're not registered (small
  supplier, < $30k over four quarters) choose that option. Apple is merchant
  of record for sales taxes and remits them; your Canadian remittances are
  reduced by GST/QST *on Apple's commission* only. Ask an accountant once;
  the income is self-employment income on your T1 unless you incorporate.
- ☐ **Banking** — a Canadian account in your name (institution, transit,
  account). Payouts arrive ~33 days after the end of Apple's fiscal month
  once the small minimum is met; balances roll over. Track under Payments
  and Financial Reports.
- ☐ **Small Business Program** — enroll right after the agreement is active
  (15 % commission instead of 30 %; new developers qualify automatically).

### 0b. Identity exposure (what will and won't be public)
- Your **legal name** as *Seller* — unavoidable on an Individual account.
  To change later: incorporate → D-U-N-S → convert to Organization.
- ☐ **Trader status** (Business → Compliance): declare. With no EU
  distribution Apple's help says you are *not* acting as a trader on the App
  Store, so no address/phone is published. Then in *Pricing and
  Availability* **deselect the 27 EU countries** (§2e).
- ☐ **GitHub** `5mars/abimo` → Settings → Danger Zone → make **private**.
  `5mars/abimo-legal` stays public (it is the website).
- ☐ **Firebase API key** — Google Cloud Console → APIs & Services →
  Credentials → the iOS key → Application restrictions → iOS apps →
  `com.mars.Abimo`.
- Heads-up (not blocking): Quebec's language law expects software sold in
  Quebec to be available in French unless no French version exists.
  English-only 1.0 is common; put French on the 1.x list.

### 0c. Domain, e-mail, website
- ☑ Registered **abimo.ca** on GoDaddy 2026-09-22; nameservers moved to Cloudflare (brett/zita) the same day.
- ~~☐ Register **abimo.ca** (Cloudflare Registrar, ~US$15/yr, WHOIS privacy on).~~
- ☑ **Apple mail** records live 2026-09-22 (iCloud MX ×2, apple-domain TXT, SPF, DKIM CNAME). ☐ Still to confirm: `support@` / `info@` show *verified* in iCloud settings and a test mail lands; add `review@` before App Review (steps in `docs/ops/DOMAIN-EMAIL-HOSTING.md` §3). Do NOT enable Cloudflare Email Routing.
- ☑ Cloudflare DNS done 2026-09-22 (DNS-only / grey cloud): `A` 185.199.108.153 ·
  185.199.109.153 · 185.199.110.153 · 185.199.111.153, `AAAA`
  2606:50c0:8000::153 · 8001::153 · 8002::153 · 8003::153,
  `CNAME www → 5mars.github.io`.
- ☑ **https://abimo.ca is live** (2026-09-22): site PR #1 merged, certificate issued for abimo.ca + www, Enforce HTTPS on, http→https and www→apex redirect, old `5mars.github.io/abimo-legal/…` links redirect.
- ☑ In-app feedback e-mail → `support@abimo.ca`, privacy links → `https://abimo.ca/privacy/` (2026-09-22). Terms link stays Apple's standard EULA.

### 0d. Other consoles
- ☐ **OpenAI** → Settings → Limits: hard monthly budget **$50**, alert **$25**.
- ☐ **Firebase** (project `abimo-5bfbd` exists, plist is in the app):
  confirm *Google Analytics is enabled* for the project (Project settings →
  Integrations — the plist says `IS_ANALYTICS_ENABLED = false`); enable
  **Crashlytics**; verify events in Analytics → DebugView by running the app
  once with the `-FIRDebugEnabled` argument (already in the scheme, disabled).

---

## 1. Server — deploy before TestFlight (~10 min)
☑ **2026-09-22 chapters 2-5 ladder** — migration pushed + extend-action-plan deployed (Jeremy, same day). For any later change:
```bash
deno test supabase/functions/_shared/
supabase db push                              # chapter_briefs + micro_actions.chapter 1..5
supabase functions deploy extend-action-plan
```
☑ **All six functions deployed 2026-09-22** (tier caps, gpt-4o-mini plan/next
chapter, gpt-4o-mini-transcribe, Plus 6/6/12/12, `extend-action-plan` live).
Re-run the block below after any further change under `supabase/functions/`.

```bash
deno test supabase/functions/_shared/
deno check supabase/functions/_shared/*.ts supabase/functions/*/index.ts
supabase functions deploy analyze-swot research-market generate-action-plan transcribe-audio verify-entitlement extend-action-plan
```
- ☐ Dashboard → Database → Extensions → enable **pg_cron**, then run the
  `cron.schedule('expire-lapsed-plus', …)` block from
  `supabase/migrations/20260916130000_profiles_plus.sql` in the SQL editor.
- ☐ Edge Functions → Secrets: `OPENAI_API_KEY`, `AI_LIMIT_EXEMPT_USER_IDS`
  present; **`ALLOW_STOREKIT_TEST_ENV` absent**.

---

## 2. App Store Connect (~45 min) — `docs/store/metadata.md` has every string

- ☐ **2a. New App**: iOS · *Abimo* · English (U.S.) · `com.mars.Abimo` · SKU `abimo-ios`.
- ☐ **2b. Subscriptions** → group **Abimo Plus**:

  | Product ID | Duration | Price | Intro offer |
  |---|---|---|---|
  | `com.mars.Abimo.plus.monthly` | 1 month | $4.99 | **Free, 1 week** |
  | `com.mars.Abimo.plus.yearly` | 1 year | $34.99 | **Free, 1 week** |

  Display names/descriptions from the metadata file; review screenshot =
  the paywall PNG in `docs/store/screenshots/`. IDs are case-sensitive and
  permanent — copy-paste.
- ☐ **2c. App Privacy**: policy URL `https://abimo.ca/privacy/`; declare
  Email · Audio · Other User Content · User ID · **Device ID** · Product
  Interaction · Crash · Performance, exactly as the table in the metadata
  file; tracking = **No**.
- ☐ **2d. Age rating**: complete Apple's questionnaire honestly (expect 4+).
  Category Productivity / Business.
- ☐ **2e. Pricing & Availability**: Free. Availability → deselect Austria,
  Belgium, Bulgaria, Croatia, Cyprus, Czechia, Denmark, Estonia, Finland,
  France, Germany, Greece, Hungary, Ireland, Italy, Latvia, Lithuania,
  Luxembourg, Malta, Netherlands, Poland, Portugal, Romania, Slovakia,
  Slovenia, Spain, Sweden.
- ☐ **2f. Sandbox tester**: Users and Access → Sandbox → add a test Apple ID
  (any e-mail you control; it never needs to be a real Apple account).
- ☐ **2g. Demo account** for App Review: sign up `review@abimo.ca` in the
  app, confirm the e-mail, record **two** ideas and let them finish (one
  free stall stays open for the reviewer). Put the password in the review
  notes only — never in git.

---

## 3. Store assets (Claude drives, you approve) — `scripts/store-assets.sh`
- ☑ 2026-09-22: five framed screenshots in `docs/store/screenshots/`
  (record · taste · evidence · chapter 1 journey · chapter 2) and a 24.5 s
  preview `docs/store/previews/abimo-preview-6.9.mp4` (886×1920, H.264 High
  L4.0, silent AAC — passes ffprobe). Captured on Jeremy's account.
- ☑ Shot 6 (paywall with live prices) captured 2026-09-22. Prices only render
  when the app is launched by Xcode's Run action (the scheme attaches
  `AbimoPlus.storekit`; `simctl launch` and hosted-test `SKTestSession` do
  not). Scriptable via AppleScript: `tell application "Xcode" to run
  workspace document` after opening the project.
- ☐ Apple wants a **poster frame** for the preview: pick one in App Store
  Connect after upload (the gauge at ~7 s reads best).
- ☐ App icon: approve the teal horse on the simulator home screen
  (alternative head-shot crop in `docs/store/icon-alt/`). Regenerate with
  `swift tools/render-app-icon.swift Abimo/Assets.xcassets/MascotNeutral.imageset/neutral_3x.png <out>`.

---

## 4. Merge, archive, upload (~20 min)
- ☐ Open/merge PR `gsd-testing → main`. **Archive from `main`.**
- ☐ Xcode → scheme *Abimo* → destination *Any iOS Device (arm64)* →
  Product → **Archive** → Organizer → *Distribute App* → *App Store Connect*
  → Upload. No export-compliance prompt (declared in the build); Crashlytics
  dSYMs upload from the run-script. Version 1.0, build 2.
- ☐ Wait for the "build processed" e-mail (15–30 min).

## 5. TestFlight device pass (~1 h)
- ☐ TestFlight tab → Internal Testing → group with your Apple ID → install
  from the TestFlight app on your iPhone.
- ☐ Sign up fresh → walk-in tour → record → transcribe → taste → chapter 1
  → complete steps → wrap-up.
- ☐ 4th idea → Stable's full → paywall. 4th tasting of the day → daily cap.
- ☐ Settings → App Store → Sandbox Account = your tester. Buy monthly, then
  yearly (7-day trial shown). Within a minute `profiles.is_premium = true`
  in the dashboard. Next chapter appends chapter 2. Re-taste keeps the row
  id and shows the delta. Restore Purchases. Manage Subscription opens
  Apple's sheet.
- ☐ Background the app mid-pipeline → notification arrives → tap deep-links.
- ☐ Delete Account → gone from `auth.users` and the `voice-recordings` bucket.
- ☐ Firebase DebugView shows events; Crashlytics shows the build's dSYM.
- ☐ Optional: External Testing group for friends (first build needs a ~1 day
  Beta App Review).

## 6. Submit
- ☐ App Store tab → 1.0 → attach the build, add screenshots + previews,
  paste metadata, **select both subscriptions** for this version, App Review
  Information (demo login + notes from `docs/store/metadata.md`), release
  = **Manually**.
- ☐ Submit for Review. First reviews take 1–3 days. If rejected, paste the
  note to Claude — every common first-app cause (privacy URL, restore,
  account deletion, demo login, subscription disclosure, export compliance)
  is already covered.
- ☐ Approved → Release this version. Watch `score_audits`, Crashlytics and
  the OpenAI spend the first week.

---
## Deployed server-side protection (reference)

Already live on Supabase project `ymbfqlrarlnqtzatgfah` (verified with curl):

| Protection | Value |
|---|---|
| JWT verification | all 6 edge functions, gateway + in-function |
| Daily per-user budgets | free 3 · 3 · 6 · 6 — Plus 6 · 6 · 12 · 12 (transcribe · research · SWOT · plan/next chapter) |
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
re-taste, full evidence, unlimited ideas, caps 6/6/12/12.

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
2. ⏳ ☑ DONE 2026-09-22 — deployed the other five functions (with the cost-control changes)
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
