# Mascot art — how poses get into the app

The mascot is the horse from `docs/mascot/horse-sheet.jpg`. Five poses from
the sheet's bottom row are live (see `docs/mascot/current-poses.png`):

| Asset catalog imageset | `MascotExpression` | What it shows | Carries mood(s) / used for |
|---|---|---|---|
| `MascotNeutral` | `.neutral` | standing, half-lidded, flat mouth | `.neutral` — launch screen, login, record prompt |
| `MascotGrumpy` | `.grumpy` | arms crossed, scowl | `.grumpy` — burnt / half-baked scores |
| `MascotThumbsUp` | `.thumbsUp` | smug thumbs-up | `.sassy` — needs-seasoning, paywall, streak-at-risk |
| `MascotWaving` | `.waving` | eyes-closed grin, waving | `.playful` — good scores, every celebration |
| `MascotSitting` | `.sitting` | slumped on the floor, bored | loading screens, empty states (not a mood) |

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

`bandMinY` is the pixel row above which sprites are ignored (560 selects
the bottom row of the current sheet); names are given left-to-right and
become the file prefixes. Then create `Mascot<Name>.imageset` with the
three PNGs and a `Contents.json` like the existing ones.

For sprites from another row of the sheet (the six face-only heads, the
three body poses in row two), run it with a different band — heads will
need their own canvas treatment since they have no feet baseline.

## Quality note

The sheet is 1024 px wide, so each sprite is ~230 px tall natively; the 3x
export is an upscale and will look soft on the biggest surfaces (260 pt
loading mascot, 220 pt plan-completion podium). When you regenerate art,
ask for each pose at ≥ 800 px on a transparent background and drop it in
with the same imageset names — nothing else changes. The 1x image also sets
the native launch screen's mascot size (120 pt); keep 1x at 120 px.
