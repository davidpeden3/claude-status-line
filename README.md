# Claude Code Status Line

A custom status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that displays model name, context window usage, and rate limit consumption as color-coded progress bars.

## What It Looks Like

```
Opus 4.6 │ ctx: ████░░░░░░ (40%) │ 5h: ██░░░░░░░░ (20%)  7d: █░░░░░░░░░ (10%)
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

### 1. Copy the script

Copy `statusline.sh` to your Claude config directory:

```bash
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Or clone the repo and reference it directly (see step 2).

### 2. Configure Claude Code

Add the following to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

If you cloned the repo and want to reference the script directly, use the full path instead:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /path/to/claude-status-line/statusline.sh"
  }
}
```

### 3. Restart Claude Code

The status line will appear at the bottom of your Claude Code session.

## How It Works

Claude Code pipes a JSON object to the status line command via stdin on each render. The script extracts three values:

| Field | JSON Path | Description |
|-------|-----------|-------------|
| Model | `model.display_name` | The active model name |
| Context | `context_window.used_percentage` | How much of the context window is consumed |
| 5h rate limit | `rate_limits.five_hour.used_percentage` | Rolling 5-hour rate limit usage |
| 7d rate limit | `rate_limits.seven_day.used_percentage` | Rolling 7-day rate limit usage |

Each percentage is rendered as a 10-segment bar using Unicode block characters (`█` filled, `░` empty) with ANSI color codes.

## License

[MIT](LICENSE)