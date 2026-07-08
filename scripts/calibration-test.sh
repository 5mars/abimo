#!/bin/bash
#
# Calibration test for the analyze-swot edge function.
# Runs 4 canned transcripts (terrible → strong) N times each and prints the
# viability scores. Pass criteria:
#   T1 (vague AI-everything app)      →  5-20
#   T2 (campus food truck ratings)    → 22-39
#   T3 (wedding-DJ FAQ tool)          → 42-59
#   T4 (tutor billing, real evidence) → 62-82
#   Gap between T2 and T4 means ≥ 25 points.
#   Also watch for band-edge pinning: repeated exact 39/59/79 across
#   DIFFERENT ideas means dims are overshooting the verdict band.
#
# Usage: ./scripts/calibration-test.sh [runs-per-transcript, default 3]
#
set -euo pipefail

URL="https://ymbfqlrarlnqtzatgfah.supabase.co/functions/v1/analyze-swot"
ANON_KEY="sb_publishable_HUIZRQ5EfaFU3EV-1IzqNQ_8uOBDJ39"
RUNS="${1:-3}"

T1="Okay so, hear me out — an app that's like, a social network but for everything. AI powered. People can post stuff, buy stuff, date, find jobs, everything in one app. Nobody's done all of it together."
T2="An app where college students can rate campus food trucks and see which ones have short lines. Students are always complaining about lines at lunch."
T3="I'm a wedding DJ. Couples email me the same 40 questions before every gig, and I retype answers every time. I want a little tool that builds a shareable FAQ-plus-questionnaire page for event vendors, like ten bucks a month. Every DJ I know has this problem and we all hack it with Google Docs."
T4="I run a 3,000-member Facebook group for private math tutors. Every week someone asks how to handle parent billing — the current tool everyone names costs 50 dollars a month and does 90 things tutors don't need. I polled the group: 140 tutors said they'd pay 12 dollars a month for just invoicing plus session notes, and 25 gave me their emails for early access. I could announce it in the group tomorrow."

run_one() {
  local label="$1" transcript="$2"
  for i in $(seq 1 "$RUNS"); do
    score=$(curl -s "$URL" \
      -H "Authorization: Bearer $ANON_KEY" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg t "$transcript" '{transcription: $t}')" \
      | jq -r '.viabilityScore // "ERROR: \(.error // "no score")"')
    echo "$label run $i: $score"
  done
}

echo "=== Calibration test ($RUNS runs each; expect T1 8-20, T2 22-38, T3 44-60, T4 65-82) ==="
run_one "T1 (terrible) " "$T1"
run_one "T2 (mediocre) " "$T2"
run_one "T3 (decent)   " "$T3"
run_one "T4 (strong)   " "$T4"
