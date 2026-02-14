# webfetch-markdown-hook

A Claude Code hook that routes `WebFetch` through [markdown.new](https://markdown.new) for clean markdown instead of raw HTML.

## Prerequisites

- Claude Code
- `jq` (pre-installed on most systems, or `brew install jq`)

## Setup

**1. Copy the script and config:**

```bash
mkdir -p ~/.claude/hooks
curl -o ~/.claude/hooks/webfetch-markdown-redirect.sh https://raw.githubusercontent.com/jsmillerdev/webfetch-markdown-hook/main/webfetch-markdown-redirect.sh
curl -o ~/.claude/hooks/markdown-config.json https://raw.githubusercontent.com/jsmillerdev/webfetch-markdown-hook/main/markdown-config.json
chmod +x ~/.claude/hooks/webfetch-markdown-redirect.sh
```

**2. Add to `~/.claude/settings.json`:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "WebFetch",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/webfetch-markdown-redirect.sh",
            "timeout": 10,
            "statusMessage": "Redirecting through markdown.new..."
          }
        ]
      }
    ]
  }
}
```

**3. Restart Claude Code** or run `/hooks` to apply.

## Configuration

Edit `~/.claude/hooks/markdown-config.json`. The `method` and `retain_images` options are passed through as query parameters to [markdown.new](https://markdown.new):

```json
{
  "method": "auto",
  "retain_images": false,
  "exclude": [
    "localhost",
    "127.0.0.1",
    "0.0.0.0",
    "10.*",
    "172.16.*",
    "192.168.*"
  ]
}
```

| Field | Values | Default | Description |
|---|---|---|---|
| `method` | `auto`, `ai`, `browser` | `auto` | `auto` tries native markdown first, `ai` uses AI extraction, `browser` renders JS-heavy pages |
| `retain_images` | `true`, `false` | `false` | Include images in the markdown output |
| `exclude` | array of patterns | local/private IPs | URLs matching any entry are fetched directly, skipping markdown.new. Supports wildcards (`*.example.com`) |

## Privacy

All fetched URLs are routed through markdown.new, a third-party service. Local and private network URLs are excluded by default. Add sensitive domains to the `exclude` array.

## Credits

[markdown.new](https://markdown.new) by [Emre Elbeyoglu](https://x.com/elbeyoglu)
