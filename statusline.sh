#!/bin/bash
JSON=$(cat)

MODEL=$(python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
m = data.get('model', {})
print(m.get('display_name', '') if isinstance(m, dict) else m)
" <<< "$JSON")

CTX_PCT=$(python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
val = data.get('context_window', {}).get('used_percentage')
print(int(round(val)) if val is not None else '')
" <<< "$JSON")

FIVE_H=$(python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
val = data.get('rate_limits', {}).get('five_hour', {}).get('used_percentage')
print(int(round(val)) if val is not None else '')
" <<< "$JSON")

FIVE_H_RESET=$(python3 -c "
import sys, json, time
data = json.loads(sys.stdin.read())
val = data.get('rate_limits', {}).get('five_hour', {}).get('resets_at')
if val is not None:
    diff = max(0, int(val - time.time()))
    h, m = diff // 3600, (diff % 3600) // 60
    if h > 0:
        print(f'{h}h{m:02d}m')
    else:
        print(f'{m}m')
" <<< "$JSON")

SEVEN_D=$(python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
val = data.get('rate_limits', {}).get('seven_day', {}).get('used_percentage')
print(int(round(val)) if val is not None else '')
" <<< "$JSON")

SEVEN_D_RESET=$(python3 -c "
import sys, json, time
data = json.loads(sys.stdin.read())
val = data.get('rate_limits', {}).get('seven_day', {}).get('resets_at')
if val is not None:
    diff = max(0, int(val - time.time()))
    d, rem = diff // 86400, diff % 86400
    h = rem // 3600
    if d > 0:
        print(f'{d}d{h}h')
    else:
        m = (rem % 3600) // 60
        if h > 0:
            print(f'{h}h{m:02d}m')
        else:
            print(f'{m}m')
" <<< "$JSON")

make_bar() {
  local PCT=$1
  local FILLED=$(( PCT / 10 ))
  local EMPTY=$(( 10 - FILLED ))
  local COLOR
  if [ "$PCT" -ge 90 ]; then
    COLOR="\033[31m"
  elif [ "$PCT" -ge 80 ]; then
    COLOR="\033[38;5;208m"
  elif [ "$PCT" -ge 70 ]; then
    COLOR="\033[33m"
  else
    COLOR="\033[32m"
  fi
  local BAR=""
  for ((i=0; i<FILLED; i++)); do BAR="${BAR}█"; done
  for ((i=0; i<EMPTY; i++)); do BAR="${BAR}░"; done
  echo -ne "${COLOR}${BAR}\033[0m (${PCT}%)"
}

OUTPUT="${MODEL}"

if [ -n "$CTX_PCT" ]; then
  CTX_BAR=$(make_bar "$CTX_PCT")
  OUTPUT="${OUTPUT} │ ctx: ${CTX_BAR}"
fi

RATE_PARTS=""
if [ -n "$FIVE_H" ]; then
  FIVE_BAR=$(make_bar "$FIVE_H")
  RATE_PARTS="5h: ${FIVE_BAR}"
  if [ -n "$FIVE_H_RESET" ]; then
    RATE_PARTS="${RATE_PARTS} ↻${FIVE_H_RESET}"
  fi
fi
if [ -n "$SEVEN_D" ]; then
  WEEK_BAR=$(make_bar "$SEVEN_D")
  WEEK_PART="7d: ${WEEK_BAR}"
  if [ -n "$SEVEN_D_RESET" ]; then
    WEEK_PART="${WEEK_PART} ↻${SEVEN_D_RESET}"
  fi
  if [ -n "$RATE_PARTS" ]; then
    RATE_PARTS="${RATE_PARTS}  ${WEEK_PART}"
  else
    RATE_PARTS="${WEEK_PART}"
  fi
fi
if [ -n "$RATE_PARTS" ]; then
  OUTPUT="${OUTPUT} │ ${RATE_PARTS}"
fi

echo -e "${OUTPUT}"