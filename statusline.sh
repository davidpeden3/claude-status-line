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

SEVEN_D=$(python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
val = data.get('rate_limits', {}).get('seven_day', {}).get('used_percentage')
print(int(round(val)) if val is not None else '')
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
fi
if [ -n "$SEVEN_D" ]; then
  WEEK_BAR=$(make_bar "$SEVEN_D")
  if [ -n "$RATE_PARTS" ]; then
    RATE_PARTS="${RATE_PARTS}  7d: ${WEEK_BAR}"
  else
    RATE_PARTS="7d: ${WEEK_BAR}"
  fi
fi
if [ -n "$RATE_PARTS" ]; then
  OUTPUT="${OUTPUT} │ ${RATE_PARTS}"
fi

echo -e "${OUTPUT}"