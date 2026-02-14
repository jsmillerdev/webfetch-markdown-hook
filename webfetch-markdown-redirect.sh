#!/bin/bash
set -euo pipefail

if ! command -v jq &>/dev/null; then
  echo "jq is required: brew install jq" >&2
  exit 2
fi

original_url=$(jq -r '.tool_input.url')

[[ -z "$original_url" || "$original_url" == "null" ]] && exit 0
[[ "$original_url" == *"markdown.new"* ]] && exit 0

# Load config
config="$HOME/.claude/hooks/markdown-config.json"
params=()
if [[ -f "$config" ]]; then
  # Check excluded domains (supports wildcards: *.example.com)
  while IFS= read -r pattern; do
    # shellcheck disable=SC2254
    [[ "$original_url" == *$pattern* ]] && exit 0
  done < <(jq -r '.exclude[]? // empty' "$config")

  # Build query string from config
  method=$(jq -r '.method // empty' "$config")
  retain=$(jq -r '.retain_images // empty' "$config")
  [[ "$method" =~ ^(auto|ai|browser)$ ]] && params+=("method=$method")
  [[ "$retain" == "true" ]] && params+=("retain_images=true")
fi

new_url="https://markdown.new/${original_url#*://}"
if [[ ${#params[@]} -gt 0 ]]; then
  sep="?"; [[ "$new_url" == *"?"* ]] && sep="&"
  new_url+="${sep}$(IFS='&'; echo "${params[*]}")"
fi

jq -n --arg url "$new_url" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: "Redirecting through markdown.new",
    updatedInput: { url: $url },
    additionalContext: "URL redirected through markdown.new for HTML-to-markdown conversion. Response is clean markdown — use it directly."
  }
}'
