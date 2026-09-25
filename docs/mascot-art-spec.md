# Mascot art — how poses get into the app

The mascot is the horse: a judgmental, nonchalant, passive-aggressive food
critic who quietly expects you to fail and is only ever impressed
grudgingly. Every pose is drawn in that register. Sources live outside the
repo (Jeremy's `~/Desktop/mascot+poses`, 1024 px renders, one pose per
image); the original sheet is `docs/mascot/horse-sheet.jpg`.

## Where each pose appears

| Pose (`MascotExpression`) | Scenario |
|---|---|
| `neutral` | launch intro, login (kept neutral so the launch cross-fade never swaps faces), `.neutral` mood |
| `listening` | Today card "record an idea", pipeline idle/saving, record-prompt moment |
| `writing` | pipeline transcribing + planning, Today card "build the plan" |
| `searching` | pipeline web-research ("scouting") stage |
| `tasting` | pipeline analyzing, Today card "taste this idea", paywall re-taste, simmering verdict |
| `cooking` | Taste Test regeneration loading |
| `shocked` | pipeline done on a Chef's Kiss score (anything less → `thumbsUp`) |
| `facepalm` | pipeline failed |
| `tapping` | default `MascotLoadingView` (plans, actions, paywall products) |
| `sleeping` | empty states (Stable + Actions), empty-kitchen moment |
| `pointing` | spotlight tour coach, journey intro sheet |
| `waving` | walk-in welcome popup, `.playful` mood |
| `welcomeBack` | returned-after-absence popup |
| `worried` | streak-at-risk popup (tea, side-eye — hoping it breaks) |
| `horseshoe` | congrats sheet, plain step (the XP) |
| `flame` / `medal` / `flex` | congrats sheet when the step extended the streak / unlocked a badge / hit the daily goal or a 3-5-7 milestone |
| `gallop` | congrats sheet when the step closed a chapter |
| `trophy` | plan completion podium |
| `dare` | Today card "what's next" (all plans done), dares-cleared moment |
| `bowtie` | sign-up header |
| `vip` / `sign` / `stopwatch` / `receipt` / `doorman` / `tasting` | paywall header per context: general / idea cap / daily cap / full analysis / next chapter / re-taste |
| `spitTake` / `thumbsDown` / `seasoning` / `tasting` / `chefKiss` | verdict faces (`MascotExpression.forVerdict`): burnt / half-baked / needs seasoning / simmering / chef's kiss — the share card |
| `crying` | `.sad` mood (fake tears — he's crying *at* your idea) |
| `grumpy`, `thumbsUp`, `sunglasses`, `sitting`, `shrug` | their moods (`.grumpy`, `.sassy`, `.cool`) / older art kept for fallbacks |

Moment poses live in `MascotVoice.pose(for:)`, so a popup or sheet built
from a `MascotMoment` picks the right pose automatically.

## Two layers (Abimo/Models/MascotMood.swift)

- **`MascotExpression`** = what the picture shows. One case per imageset;
  the imageset name is `"Mascot" + CapitalizedCaseName`. Missing art falls
  back to `MascotNeutral`, so a new case can ship before its image exists.
- **`MascotMood`** = the critic's tone of voice (drives the line pools in
  `MascotVoice`). **`MascotMood.expression` is the one table that decides
  which pose carries which tone** — to move an emotion, edit that switch.
- Screens that want a fixed pose regardless of tone pass it explicitly:
  `MascotView(mood:size:motion:expression: .sitting)` (loading + empty
  states do this today).

Xcode Previews → `MascotView.swift` → **"Expression gallery"** shows every
pose with the moods currently mapped to it.

## Adding a pose

1. Add a case to `MascotExpression` (e.g. `case shocked`).
2. Produce `MascotShocked.imageset` (below) — or don't yet; it falls back.
3. Map it: in `MascotMood.expression`, or pass `expression: .shocked` where
   you want it.

## Slicing sprites from a sheet

`tools/slice-mascot-sheet.swift` does the whole job: keys the light
background by flood-filling from the borders (eye whites survive, ground
shadows are removed), un-blends the anti-aliased outline, finds the
sprites in a horizontal band, puts them on a shared bottom-aligned square
canvas (so the character stays the same size when moods cross-fade), and
writes 1x/2x/3x PNGs at 120/240/360 px.

```bash
swift tools/slice-mascot-sheet.swift docs/mascot/horse-sheet.jpg /tmp/out <bandMinY> name1 name2 ...
```

For a render with ONE pose (the current workflow), use single-pose mode —
it keeps every piece (props, "z", motion lines), keys the darker ground
shadow, and uses a fixed canvas so the horse stays the same size across
poses. 850 suits the 1024×1024 renders; use a smaller side when the horse is
drawn smaller (720 for the 1024×850 ones):

```bash
swift tools/slice-mascot-sheet.swift ~/Desktop/mascot+poses/trophy.jpg /tmp/out single:850 trophy
```

Single-pose output is 240/480/720 px; imagesets set
`"compression-type": "lossy"` in `properties`, which keeps each pose around
70 KB compiled.

`bandMinY` is the pixel row above which sprites are ignored (560 selects
the bottom row of the current sheet); names are given left-to-right and
become the file prefixes. Then create `Mascot<Name>.imageset` with the
three PNGs and a `Contents.json` like the existing ones.

For sprites from another row of the sheet (the six face-only heads, the
three body poses in row two), run it with a different band — heads will
need their own canvas treatment since they have no feet baseline.

## Quality note

Sheet-sliced sprites (neutral, grumpy, thumbsUp, sitting, shrug, sunglasses,
thumbsDown, writing, cooking) are ~230 px natively and look soft on the
biggest surfaces. Regenerate them as single 1024 px renders and re-cut with
single-pose mode — same imageset names, nothing else changes. Exception:
`MascotNeutral`'s 1x sets the native launch screen's mascot size (120 pt),
so keep its 1x at 120 px (sheet mode).
