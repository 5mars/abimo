#!/bin/bash
#
# Calibration test for the analyze-swot edge function.
#
# Runs every case in scripts/calibration/cases.json N times and reports the
# score distribution against each case's target range. Research comes from
# the case's canned digest by default (--research fixture) so scoring is not
# confounded by web-search variance; --research live calls research-market
# first; --research none scores from the transcript alone.
#
# Pass criteria (scoring v2):
#   - each case in its target range in >= 2 of 3 runs
#   - per-case SD <= 6
#   - <= 25% of ALL runs in 50-65
#   - no exact value holds > 10% of runs; <= 2 runs at 58 or 59
#   - mean(T4) - mean(T2) >= 30
#
# Auth: a dedicated calibration user (password grant). Put in .env (gitignored):
#   SUPABASE_URL=https://xxx.supabase.co
#   SUPABASE_ANON_KEY=sb_publishable_...
#   CALIB_EMAIL=calibration@example.com
#   CALIB_PASSWORD=...
# and list that user's id in the AI_LIMIT_EXEMPT_USER_IDS secret of the
# Supabase project so the 30-run batch clears the daily budget.
#
# Usage: ./scripts/calibration-test.sh [--runs N] [--research fixture|live|none] [--only T3,T4]
#
set -euo pipefail

cd "$(dirname "$0")/.."
[ -f .env ] && set -a && source .env && set +a

: "${SUPABASE_URL:?set SUPABASE_URL in .env}"
: "${SUPABASE_ANON_KEY:?set SUPABASE_ANON_KEY in .env}"
: "${CALIB_EMAIL:?set CALIB_EMAIL in .env}"
: "${CALIB_PASSWORD:?set CALIB_PASSWORD in .env}"

RUNS=3
RESEARCH=fixture
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --runs) RUNS="$2"; shift 2 ;;
    --research) RESEARCH="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    *) echo "unknown arg $1"; exit 2 ;;
  esac
done

CASES=scripts/calibration/cases.json
OUT=$(mktemp -t abimo-calib)
trap 'rm -f "$OUT"' EXIT

echo "→ signing in as $CALIB_EMAIL"
TOKEN=$(curl -s "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Type: application/json" \
  -d "$(jq -n --arg e "$CALIB_EMAIL" --arg p "$CALIB_PASSWORD" '{email:$e,password:$p}')" \
  | jq -r '.access_token // empty')
[ -n "$TOKEN" ] || { echo "✗ sign-in failed"; exit 1; }

AUTH=(-H "Authorization: Bearer $TOKEN" -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Type: application/json")

score_one() {
  local id="$1" transcript="$2" fixture="$3"
  local research="null"
  case "$RESEARCH" in
    fixture) research="$fixture" ;;
    live)
      research=$(curl -s "$SUPABASE_URL/functions/v1/research-market" "${AUTH[@]}" \
        -d "$(jq -n --arg t "$transcript" '{transcription:$t}')")
      ;;
    none) research="null" ;;
  esac
  curl -s "$SUPABASE_URL/functions/v1/analyze-swot" "${AUTH[@]}" \
    -d "$(jq -n --arg t "$transcript" --argjson r "$research" '{transcription:$t, research:$r, calibration:true}')" \
    | jq -c '{score: .viabilityScore, band: .verdictBand, dims: .dimensionScores, hedged: (.scoreMeta.hedged // false), caps: ((.scoreMeta.caps // []) | length), error: .error}'
}

echo "→ $RUNS runs per case, research=$RESEARCH"
jq -c '.[]' "$CASES" | while read -r c; do
  id=$(jq -r .id <<<"$c")
  if [ -n "$ONLY" ] && ! grep -q "\b$id\b" <<<"$ONLY"; then continue; fi
  label=$(jq -r .label <<<"$c")
  lo=$(jq -r '.target[0]' <<<"$c"); hi=$(jq -r '.target[1]' <<<"$c")
  transcript=$(jq -r .transcript <<<"$c")
  fixture=$(jq -c .fixture <<<"$c")
  for i in $(seq 1 "$RUNS"); do
    r=$(score_one "$id" "$transcript" "$fixture")
    s=$(jq -r '.score // "ERR"' <<<"$r")
    printf "%-4s run %d: %-4s  %s\n" "$id" "$i" "$s" "$(jq -c 'del(.score)' <<<"$r")"
    echo "$id $lo $hi $s" >> "$OUT"
  done
done

echo
echo "=== Summary ==="
awk '
  $4 ~ /^[0-9]+$/ {
    n[$1]++; sum[$1]+=$4; sq[$1]+=$4*$4; lo[$1]=$2; hi[$1]=$3
    if ($4>=$2 && $4<=$3) inrange[$1]++
    all++; if ($4>=50 && $4<=65) mid++
    exact[$4]++; if ($4==58 || $4==59) seam++
    if ($1=="T2") { t2s+=$4; t2n++ } ; if ($1=="T4") { t4s+=$4; t4n++ }
  }
  END {
    for (id in n) {
      mean=sum[id]/n[id]; sd=sqrt(sq[id]/n[id]-mean*mean)
      ok=(inrange[id]>=2||inrange[id]==n[id])?"PASS":"FAIL"
      printf "%-4s target %2d-%-2d  mean %5.1f  sd %4.1f  in-range %d/%d  %s\n", id, lo[id], hi[id], mean, sd, inrange[id], n[id], ok
    }
    printf "\nmid-cluster (50-65): %d/%d = %.0f%%  %s\n", mid, all, 100*mid/all, (mid/all<=0.25?"PASS":"FAIL")
    printf "seam values 58/59:   %d  %s\n", seam, (seam<=2?"PASS":"FAIL")
    top=0; for (v in exact) if (exact[v]>top) { top=exact[v]; tv=v }
    printf "most common exact:   %s x%d  %s\n", tv, top, (top/all<=0.10?"PASS":"FAIL")
    if (t2n>0 && t4n>0) printf "T4 - T2 mean gap:    %.1f  %s\n", t4s/t4n - t2s/t2n, ((t4s/t4n - t2s/t2n)>=30?"PASS":"FAIL")
  }' "$OUT" | sort
