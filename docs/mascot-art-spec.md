# Mascot expression art — drop-in spec

The app's mood system is fully wired: `MascotMood.assetName` looks for the
image sets below and silently falls back to `MascotNeutral` for any that
don't exist yet. Moods can ship **one image at a time** — no code changes
needed, ever.

## What to generate

Three expression variants of the existing mascot (master art:
`neutral.svg` at the repo root — 1024×1024, transparent background):

| Asset catalog name | Mood | Used for | Expression direction |
|---|---|---|---|
| `MascotPlayful` | playful | good scores (simmering/chef's kiss), celebrations, milestones, sign-up | Open smile, bright wide eyes, maybe one raised brow — delighted but still the critic |
| `MascotGrumpy` | grumpy | bad scores (burnt/half-baked) | Furrowed brows, flat or downturned zigzag mouth, half-lidded eyes |
| `MascotSassy` | sassy | mid scores (needs seasoning), paywall, streak-at-risk, returned-after-absence | One brow arched high, smirk, side-eye pupils |

## Consistency rules (important for AI generation)

- **Same character, same pose, same framing** as the neutral master — only
  the face changes (eyes, brows, mouth). Body, horns, arms, feet identical.
- Same flat-cartoon style: solid coral/red fill, dark outline, same line
  weight, no gradients, no shadow.
- Transparent background, subject centered with the same margins as
  `neutral.svg` (the app renders 40–260 pt; consistent margins keep every
  size swap seamless).
- Tip: give the image model the neutral PNG
  (`Abimo/Assets.xcassets/MascotNeutral.imageset/mascot_3x.png`) as the
  reference image and ask for "same character, change only the expression".

## Export & install

For each mood, export PNG at 120 / 240 / 360 px (1x/2x/3x) and add an
image set in `Abimo/Assets.xcassets` named exactly as in the table
(match `MascotNeutral.imageset`'s structure). A single 1024 px PNG in an
image set with "Single Scale" also works.

That's it — the next build picks them up at every mascot surface,
including the pipeline's per-stage moods and the score-reveal face.

## Later (optional)

If a variant ever ships as layered vector art (separate eye/mouth layers),
`MascotView.swift` can add blinking and mood-morph animation — see the
note at the top of that file.
