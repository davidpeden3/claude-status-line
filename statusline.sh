#!/bin/bash
JSON=$(cat)

CWD=$(python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
print(data.get('cwd', ''))
" <<< "$JSON")

GIT_BRANCH=""
if [ -n "$CWD" ]; then
  GIT_BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
fi

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

# Fable weekly usage is not piped into the statusline JSON, so fetch it out of
# band from the same endpoint /usage uses, caching to a file with a TTL. The
# render never blocks on the network: it draws from cache and refreshes in the
# background when the cache goes stale.
FABLE_CACHE="$HOME/.claude/.fable-usage-cache.json"
FABLE_LOCK="${FABLE_CACHE}.lock"
FABLE_TTL=120

fetch_fable_usage() {
  python3 - "$FABLE_CACHE" <<'PYEOF'
import subprocess, json, sys, urllib.request, datetime, os, tempfile
cache = sys.argv[1]
try:
    raw = subprocess.check_output(
        ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
        text=True, stderr=subprocess.DEVNULL)
    token = json.loads(raw)["claudeAiOauth"]["accessToken"]
    request = urllib.request.Request(
        "https://api.anthropic.com/api/oauth/usage",
        headers={
            "Authorization": f"Bearer {token}",
            "anthropic-beta": "oauth-2025-04-20",
            "Content-Type": "application/json",
        })
    with urllib.request.urlopen(request, timeout=10) as response:
        body = json.loads(response.read())
    fable = next(
        (limit for limit in (body.get("limits") or [])
         if limit.get("kind") == "weekly_scoped"
         and ((limit.get("scope") or {}).get("model") or {}).get("display_name") == "Fable"),
        None)
    if fable is None:
        sys.exit(0)
    resets_at = fable.get("resets_at")
    epoch = datetime.datetime.fromisoformat(resets_at).timestamp() if resets_at else None
    payload = {
        "percent": fable.get("percent"),
        "resets_at": epoch,
        "fetched_at": datetime.datetime.now(datetime.timezone.utc).timestamp(),
    }
    handle, temp = tempfile.mkstemp(dir=os.path.dirname(cache))
    with os.fdopen(handle, "w") as out:
        json.dump(payload, out)
    os.replace(temp, cache)
except Exception:
    sys.exit(0)
PYEOF
}

FABLE=""
FABLE_RESET=""
FABLE_AGE=999999
if [ -f "$FABLE_CACHE" ]; then
  FABLE_DATA=$(python3 -c "
import json, time, sys
try:
    d = json.load(open('$FABLE_CACHE'))
except Exception:
    print('||999999'); sys.exit()
pct = d.get('percent')
ra = d.get('resets_at')
fa = d.get('fetched_at', 0)
pct_s = str(int(round(pct))) if pct is not None else ''
if ra is not None:
    diff = max(0, int(ra - time.time()))
    days, rem = diff // 86400, diff % 86400
    h = rem // 3600
    if days > 0:
        reset_s = f'{days}d{h}h'
    else:
        m = (rem % 3600) // 60
        reset_s = f'{h}h{m:02d}m' if h > 0 else f'{m}m'
else:
    reset_s = ''
age = int(time.time() - fa) if fa else 999999
print(f'{pct_s}|{reset_s}|{age}')
" 2>/dev/null)
  FABLE="${FABLE_DATA%%|*}"
  FABLE_REST="${FABLE_DATA#*|}"
  FABLE_RESET="${FABLE_REST%%|*}"
  FABLE_AGE="${FABLE_REST##*|}"
fi

if [ -z "$FABLE_AGE" ]; then
  FABLE_AGE=999999
fi
if [ "$FABLE_AGE" -ge "$FABLE_TTL" ]; then
  REFRESH=1
  if [ -f "$FABLE_LOCK" ]; then
    LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$FABLE_LOCK" 2>/dev/null || echo 0) ))
    if [ "$LOCK_AGE" -lt 30 ]; then
      REFRESH=0
    fi
  fi
  if [ "$REFRESH" -eq 1 ]; then
    touch "$FABLE_LOCK"
    ( fetch_fable_usage; rm -f "$FABLE_LOCK" ) >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi
fi

make_bar() {
  local PCT=$1
  local YELLOW=${2:-70}
  local ORANGE=${3:-80}
  local RED=${4:-90}
  local FILLED=$(( PCT / 10 ))
  local EMPTY=$(( 10 - FILLED ))
  local COLOR
  if [ "$PCT" -ge "$RED" ]; then
    COLOR="\033[31m"
  elif [ "$PCT" -ge "$ORANGE" ]; then
    COLOR="\033[38;5;208m"
  elif [ "$PCT" -ge "$YELLOW" ]; then
    COLOR="\033[33m"
  else
    COLOR="\033[32m"
  fi
  local BAR=""
  for ((i=0; i<FILLED; i++)); do BAR="${BAR}█"; done
  for ((i=0; i<EMPTY; i++)); do BAR="${BAR}░"; done
  echo -ne "${COLOR}${BAR}\033[0m (${PCT}%)"
}

OUTPUT=""
if [ -n "$GIT_BRANCH" ]; then
  OUTPUT="\033[36m ${GIT_BRANCH}\033[0m │ "
fi
OUTPUT="${OUTPUT}${MODEL}"

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
if [ -n "$FABLE" ]; then
  FABLE_BAR=$(make_bar "$FABLE")
  FABLE_PART="Fable: ${FABLE_BAR}"
  if [ -n "$FABLE_RESET" ]; then
    FABLE_PART="${FABLE_PART} ↻${FABLE_RESET}"
  fi
  if [ -n "$RATE_PARTS" ]; then
    RATE_PARTS="${RATE_PARTS}  ${FABLE_PART}"
  else
    RATE_PARTS="${FABLE_PART}"
  fi
fi
if [ -n "$RATE_PARTS" ]; then
  OUTPUT="${OUTPUT} │ ${RATE_PARTS}"
fi

echo -e "${OUTPUT}"