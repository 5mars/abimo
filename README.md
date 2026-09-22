# Abimo

> Say your business idea out loud. Abimo transcribes it, has an AI critic taste-test it
> (a harsh 0–100 viability score with reasons and live market research), and hands you
> chapter one of a small, concrete action plan. iOS, SwiftUI, Supabase, OpenAI, StoreKit 2.

![iOS](https://img.shields.io/badge/iOS-18.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-6-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-yes-green.svg)

## What's in the repo

| Path | What |
|---|---|
| `Abimo/` | The app. Models · ViewModels · Views (Auth, Recording, Notes, Analysis, ActionPlan, Paywall, Profile, Settings, Onboarding) · Services (Supabase, pipeline, entitlements, analytics, notifications) · Utilities |
| `AbimoTests/` | Unit tests (XCTest) |
| `supabase/` | Edge functions (`transcribe-audio`, `research-market`, `analyze-swot`, `generate-action-plan`, `extend-action-plan`, `verify-entitlement`, shared `gate.ts` / `scoring.ts` / `appleJWS.ts`) and SQL migrations |
| `AbimoPlus.storekit` | Local StoreKit test configuration (attached to the shared scheme; not bundled in the app) |
| `scripts/` | Scoring calibration harness + SQL |
| `tools/` | Asset tooling (mascot sheet slicer, icon renderer, screenshot composer) |
| `docs/` | Mascot art spec, App Store metadata and store assets (`docs/store/`) |
| `LAUNCH-CHECKLIST.md` | Step-by-step release runbook |

## Running it

Requirements: Xcode 26, an iOS 18+ simulator or device, and access to the Supabase project
(the anon key and URL are in `SupabaseService.swift`; the OpenAI key lives only in Supabase
Edge Function secrets — never in the app).

```bash
git clone git@github.com:5mars/abimo.git ~/Developer/abimo
open ~/Developer/abimo/Abimo.xcodeproj
```

Select the **Abimo** scheme and run. The scheme attaches `AbimoPlus.storekit`, so Plus can be
purchased locally without an App Store sandbox account. `GoogleService-Info.plist` enables
Firebase Analytics/Crashlytics; debug builds send nothing unless launched with `-FIRDebugEnabled`.

Keep the checkout under `~/Developer` — iCloud Desktop sync creates `Foo 2.swift` duplicates.

## Server

```bash
deno test supabase/functions/_shared/
deno check supabase/functions/_shared/*.ts supabase/functions/*/index.ts
supabase functions deploy analyze-swot research-market generate-action-plan transcribe-audio verify-entitlement extend-action-plan
```

All six functions verify the user's JWT and enforce per-user daily budgets by tier
(`profiles.is_premium`, written only by `verify-entitlement` after checking the StoreKit 2
transaction's certificate chain against Apple's root). See `LAUNCH-CHECKLIST.md` for the
full deploy procedure and the "Plus is the second chapter" tier model.

## Monetization

Free: 3 active ideas, one full tasting + chapter one each, 3 tastings/day.
**Abimo Plus** (`com.mars.Abimo.plus.monthly` $4.99, `.yearly` $34.99, 7-day trial): next
chapters, re-taste, full evidence, unlimited ideas, 6/6/12/12 daily caps.

## Legal

Privacy policy and terms: https://abimo.ca/privacy/ · https://abimo.ca/terms/
(source: [5mars/abimo-legal](https://github.com/5mars/abimo-legal)). Support: support@abimo.ca.
