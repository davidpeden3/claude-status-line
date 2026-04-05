# Claude Code Status Line

A custom status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that displays model name, context window usage, and rate limit consumption as color-coded progress bars with reset countdowns.

## What It Looks Like

```
Opus 4.6 │ ctx: ████░░░░░░ (40%) │ 5h: ██░░░░░░░░ (20%) ↻3h12m  7d: █░░░░░░░░░ (10%) ↻4d6h
```

Bars change color based on usage:
- **Green** — under 70%
- **Yellow** — 70–79%
- **Orange** — 80–89%
- **Red** — 90%+

## Prerequisites

- `bash`
- `python3` (used to parse the JSON input from Claude Code)

Both are available by default on macOS and most Linux distributions.

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
| Model | `model.display_name` | The active model name |
| Context | `context_window.used_percentage` | How much of the context window is consumed |
| 5h rate limit | `rate_limits.five_hour.used_percentage` | Rolling 5-hour rate limit usage |
| 5h reset | `rate_limits.five_hour.resets_at` | Unix timestamp when the 5-hour window resets |
| 7d rate limit | `rate_limits.seven_day.used_percentage` | Rolling 7-day rate limit usage |
| 7d reset | `rate_limits.seven_day.resets_at` | Unix timestamp when the 7-day window resets |

Each percentage is rendered as a 10-segment bar using Unicode block characters (`█` filled, `░` empty) with ANSI color codes. Reset times are displayed as compact countdowns (e.g., `↻3h12m`, `↻4d6h`) so you can judge whether approaching a limit is meaningful.

## License

[MIT](LICENSE)