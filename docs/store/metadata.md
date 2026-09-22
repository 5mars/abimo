# Abimo — App Store metadata (v1.0)

Paste-ready copy for App Store Connect. Character limits are Apple's.
Voice: the kitchen / Stable metaphor the app already speaks — a critic who
tastes your idea, a stable that holds three of them for free.

## App Information

| Field | Value |
|---|---|
| Name (30) | `Abimo` |
| Subtitle (30) | `Taste-test your business idea` |
| Primary category | Productivity |
| Secondary category | Business |
| Content rights | Does not contain, show, or access third-party content |
| Age rating | Complete Apple's questionnaire honestly; expected **4+** |
| Bundle ID | `com.mars.Abimo` |
| SKU | `abimo-ios` |
| Primary language | English (U.S.) |

## URLs

| Field | Value |
|---|---|
| Privacy Policy URL | `https://abimo.ca/privacy/` (fallback `https://5mars.github.io/abimo-legal/privacy/`) |
| Support URL | `https://abimo.ca/` |
| Marketing URL | `https://abimo.ca/` |
| License Agreement | Apple standard EULA (leave the custom field empty) |

## Promotional text (170)

```
Say your idea out loud. Abimo's critic tastes it, scores it, and hands you chapter one of a plan. Your first three ideas are on the house.
```

## Description (4000)

```
You have an idea. It's been rattling around for weeks. Abimo is where you finally say it out loud — and find out if it holds up.

RECORD IT
Tap the mic and talk. No forms, no templates. Abimo transcribes your ramble and files it in your Stable.

GET IT TASTED
Within about a minute the critic comes back with a viability score out of 100, a verdict, and the reasons behind it — strengths, weaknesses, opportunities, threats — backed by live market research, not vibes. The score is deliberately harsh. A 60 means something.

COOK CHAPTER ONE
Every tasting ends with a plan: a short chapter of small, concrete steps sized for a real week. Check them off, log what you learned, keep the streak alive. Daily dares keep the burners on when motivation cools.

THE FREE STABLE
Three ideas, each with a full tasting, the score breakdown, and chapter one of its plan. Retire an idea and the stall frees up. No card required.

ABIMO PLUS — THE SECOND CHAPTER
Plus is what happens after you do the work:
• Next chapters — four more, on a ladder: prove people care, build the smallest real version, first real users, money and the call. Concrete steps sized to your skills, time and budget
• Re-taste — the critic re-scores with your results as evidence; watch the number move
• Full evidence — every tasting note, market stat, and the receipt behind the score
• Unlimited stalls and double the daily tastings

Plus is $4.99/month or $34.99/year, each with a 7-day free trial. Cancel anytime in Settings.

WHAT ABIMO IS NOT
It's not a chatbot and it's not a business plan generator. It's one honest critic, one score, and one next step — so the idea stops rattling and starts moving.

Abimo needs an account (email) so your ideas follow you between devices. Recordings are transcribed and analysed by AI on our servers; we never sell your data and there are no ads. Full policy at abimo.ca/privacy.

Payment is charged to your Apple ID account at confirmation of purchase. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple ID › Subscriptions. Terms: apple.com/legal/internet-services/itunes/dev/stdeula. Privacy: abimo.ca/privacy.
```

## Keywords (100, comma-separated, no spaces after commas)

```
startup,idea,validation,business,voice,notes,side hustle,swot,pitch,plan,coach,founder,entrepreneur
```

(Don't repeat words already in the name or subtitle — Apple indexes those for free.)

## What's New (1.0)

```
First tasting. Record an idea, get it scored, cook chapter one.
```

## Subscriptions (group "Abimo Plus")

| Product ID | Reference name | Display name (30) | Description (45) | Price | Intro offer |
|---|---|---|---|---|---|
| `com.mars.Abimo.plus.monthly` | Abimo Plus Monthly | `Abimo Plus Monthly` | `Next chapters, re-tastes, unlimited ideas` | $4.99 / 1 month | Free, 1 week |
| `com.mars.Abimo.plus.yearly` | Abimo Plus Yearly | `Abimo Plus Yearly` | `Next chapters, re-tastes, unlimited ideas` | $34.99 / 1 year | Free, 1 week |

Both need a **review screenshot** (the paywall capture in `screenshots/`) and
must be attached to version 1.0 before the first submission.

Subscription group display name (shown in the Manage Subscriptions sheet): `Abimo Plus`.
App name shown there: `Abimo`.

## App Privacy (questionnaire)

All **collected**, all **not used for tracking**. "Linked to the user's identity" as marked.

| Data type | Linked | Purposes |
|---|---|---|
| Contact Info → Email Address | yes | App Functionality |
| User Content → Audio Data | yes | App Functionality |
| User Content → Other User Content (transcripts, notes) | yes | App Functionality |
| Identifiers → User ID | yes | App Functionality, Analytics |
| Identifiers → Device ID (Firebase app instance) | no | Analytics |
| Usage Data → Product Interaction | no | Analytics |
| Diagnostics → Crash Data | no | App Functionality |
| Diagnostics → Performance Data | no | App Functionality |

"Do you or your third-party partners use data for tracking?" → **No**.

## App Review Information

| Field | Value |
|---|---|
| Sign-in required | Yes |
| Demo username | `review@abimo.ca` |
| Demo password | *(set when the account is created — keep it out of git)* |
| Contact first/last name | *(your legal name — Apple only, not public)* |
| Contact phone / email | your phone · `support@abimo.ca` |

Notes to the reviewer:

```
Thanks for reviewing Abimo.

• The app requires an account. Please use the demo credentials above (already email-confirmed). The demo Stable holds two finished ideas so you can see a tasting (score + reasons) and an action plan without waiting; one free stall is open if you'd like to record your own.

• Recording → transcription → AI tasting → chapter one takes roughly 60–90 seconds. A progress screen shows each stage.

• Free tier: 3 active ideas, one full tasting + chapter one per idea, 3 tastings per day. Abimo Plus (auto-renewing, 7-day free trial on both plans) unlocks next chapters, re-tasting, the full evidence view and unlimited ideas. Plus can be exercised with a Sandbox Apple ID from the paywall (Profile › Go Plus, or any locked item). Restore Purchases and Manage Subscription are under Settings.

• Settings › Delete Account permanently removes the account, recordings, transcripts and analyses.

• No third-party login, no ads, no tracking. Notifications are local only (optional reminders).
```

## Version release

Manually release this version (so the server-side tier caps can be switched on
the same hour the build goes live).
