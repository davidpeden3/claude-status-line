# Claude Code Status Line

A custom status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that displays the current git branch, model name, context window usage, and rate limit consumption as color-coded progress bars with reset countdowns.

## What It Looks Like

```
 develop │ Opus 4.6 │ ctx: ████░░░░░░ (40%) │ 5h: ██░░░░░░░░ (20%) ↻3h12m  7d: █░░░░░░░░░ (10%) ↻4d6h  Fable: ███░░░░░░░ (32%) ↻4d6h
```

The git branch segment is omitted when not inside a git repository. The `Fable:` segment is omitted unless a Fable weekly usage figure is available (see [Fable weekly usage](#fable-weekly-usage)).

Bars change color based on usage:
- **Green** — under 70%
- **Yellow** — 70–79%
- **Orange** — 80–89%
- **Red** — 90%+

The `Fable:` bar uses tighter thresholds — **yellow at 30%, orange at 40%, red at 45%** — because a Fable weekly allotment caps at 50% before spilling over to metered API/usage-credit consumption, so the bar should read as "hot" much earlier.

## Prerequisites

- `bash`
- `python3` (used to parse the JSON input from Claude Code)
- `git` (used to detect the current branch)

All three are available by default on macOS and most Linux distributions.

The optional `Fable:` bar additionally relies on the macOS keychain (`security`) and network access to read your Fable weekly usage (see [Fable weekly usage](#fable-weekly-usage)). It degrades gracefully: on Linux, without network, or if anything fails, the bar is simply omitted and the rest of the status line is unaffected.

## Setup

### 1. Clone the repo

```bash
git clone git@github.com:davidpeden3/claude-status-line.git ~/src/claude-status-line
```

### 2. Symlink the script

Create a symlink from your Claude config directory to the repo. This way, pulling the latest changes automatically updates your status line — no manual copying required.

```bash
ln -s ~/src/claude-status-line/statusline.sh ~/.claude/statusline.sh
```

### 3. Configure Claude Code

Add the following to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

### 4. Restart Claude Code

The status line will appear at the bottom of your Claude Code session.

## How It Works

Claude Code pipes a JSON object to the status line command via stdin on each render. The script extracts the following values:

| Field | JSON Path | Description |
|-------|-----------|-------------|
| Git branch | `cwd` → `git branch --show-current` | Current branch (omitted outside a git repo) |
| Model | `model.display_name` | The active model name |
| Context | `context_window.used_percentage` | How much of the context window is consumed |
| 5h rate limit | `rate_limits.five_hour.used_percentage` | Rolling 5-hour rate limit usage |
| 5h reset | `rate_limits.five_hour.resets_at` | Unix timestamp when the 5-hour window resets |
| 7d rate limit | `rate_limits.seven_day.used_percentage` | Rolling 7-day rate limit usage |
| 7d reset | `rate_limits.seven_day.resets_at` | Unix timestamp when the 7-day window resets |

Each percentage is rendered as a 10-segment bar using Unicode block characters (`█` filled, `░` empty) with ANSI color codes. Reset times are displayed as compact countdowns (e.g., `↻3h12m`, `↻4d6h`) so you can judge whether approaching a limit is meaningful.

## Fable weekly usage

Claude Code does **not** pipe the Fable-specific weekly limit into the status line JSON — the piped `rate_limits` object only carries `five_hour` and `seven_day`. To show a `Fable:` bar, the script fetches that figure out of band from the same endpoint the `/usage` panel uses:

- It reads your OAuth token from the macOS keychain (`Claude Code-credentials` → `claudeAiOauth.accessToken`) and calls `GET https://api.anthropic.com/api/oauth/usage`. This is an account-metadata read — it consumes no tokens and counts against no limit.
- The Fable figure is the `limits[]` entry with `kind: "weekly_scoped"` and `scope.model.display_name == "Fable"`, using its `percent` and `resets_at`.

**The render never blocks on the network.** The fetched value is cached to `~/.claude/.fable-usage-cache.json` and drawn from there on every render. When the cache is older than the TTL (120s), a detached background process refreshes it — the current render draws from whatever is already cached (nothing on the very first run, until the first fetch lands). The cache is written atomically (temp file + rename), and a short-lived lock prevents overlapping refreshes.

The token is read fresh from the keychain on each fetch and never cached. If a fetch fails — expired token, offline, non-macOS, endpoint change — the last-known value is kept and the bar simply disappears once there is no data, without affecting the rest of the status line.

## License

[MIT](LICENSE)