# webfetch-markdown-hook

A Claude Code hook that routes `WebFetch` through [markdown.new](https://markdown.new) for clean markdown instead of raw HTML.

## Prerequisites

- Claude Code
- `jq` — pre-installed on most systems, or:
  - macOS: `brew install jq`
  - Linux: `sudo apt install jq` / `sudo yum install jq`
  - Windows: `winget install jqlang.jq` or `choco install jq`
- Windows only: [Git for Windows](https://gitforwindows.org/) (provides Git Bash and `curl`)

## Setup

**1. Copy the script and config** (macOS / Linux / Windows Git Bash):

**Global** — applies to all projects:

```bash
mkdir -p ~/.claude/hooks
curl -o ~/.claude/hooks/webfetch-markdown-redirect.sh https://raw.githubusercontent.com/jsmillerdev/webfetch-markdown-hook/main/webfetch-markdown-redirect.sh
curl -o ~/.claude/hooks/markdown-config.json https://raw.githubusercontent.com/jsmillerdev/webfetch-markdown-hook/main/markdown-config.json
chmod +x ~/.claude/hooks/webfetch-markdown-redirect.sh
```

**Project** — applies to the current project only (run from the project root):

```bash
mkdir -p .claude/hooks
curl -o .claude/hooks/webfetch-markdown-redirect.sh https://raw.githubusercontent.com/jsmillerdev/webfetch-markdown-hook/main/webfetch-markdown-redirect.sh
curl -o .claude/hooks/markdown-config.json https://raw.githubusercontent.com/jsmillerdev/webfetch-markdown-hook/main/markdown-config.json
chmod +x .claude/hooks/webfetch-markdown-redirect.sh
```

---

**2. Add the hook to your settings:**

- **Global** → `~/.claude/settings.json`
- **Project** → `.claude/settings.json` in the project root

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

For a **project install**, set `command` to `".claude/hooks/webfetch-markdown-redirect.sh"`.

**3. Restart Claude Code** or run `/hooks` to apply.

## Configuration

Edit `markdown-config.json` in whichever `hooks/` directory you used above. The `method` and `retain_images` options are passed as query parameters to [markdown.new](https://markdown.new):

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
