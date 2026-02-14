#!/bin/bash
# Tests for webfetch-markdown-redirect.sh
set -uo pipefail

script="$(dirname "$0")/webfetch-markdown-redirect.sh"
config="$(dirname "$0")/markdown-config.json"
pass=0
fail=0

# Set up temp HOME
tmp_home=$(mktemp -d)
mkdir -p "$tmp_home/.claude/hooks"
export HOME="$tmp_home"

# Start with exclusions-only config (no method/retain_images)
reset_config() {
  # Remove method and retain_images so they don't affect redirect tests
  jq 'del(.method, .retain_images)' "$config" > "$tmp_home/.claude/hooks/markdown-config.json"
}
reset_config

assert() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $name"
    ((pass++))
  else
    echo "  FAIL: $name"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    ((fail++))
  fi
}

run() { echo "$1" | bash "$script" 2>/dev/null || true; }
url_from() { echo "$1" | jq -r '.hookSpecificOutput.updatedInput.url // empty' 2>/dev/null || true; }
ctx_from() { echo "$1" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null || true; }
decision_from() { echo "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null || true; }

# --- Redirect ---
echo "Redirect:"

out=$(run '{"tool_input":{"url":"https://example.com"}}')
assert "rewrites URL" "https://markdown.new/example.com" "$(url_from "$out")"
assert "sets additionalContext" "URL redirected through markdown.new for HTML-to-markdown conversion. Response is clean markdown — use it directly." "$(ctx_from "$out")"
assert "auto-approves" "allow" "$(decision_from "$out")"

out=$(run '{"tool_input":{"url":"https://docs.python.org/3/library/json.html"}}')
assert "preserves path" "https://markdown.new/docs.python.org/3/library/json.html" "$(url_from "$out")"

out=$(run '{"tool_input":{"url":"http://example.com"}}')
assert "strips http" "https://markdown.new/example.com" "$(url_from "$out")"

out=$(run '{"tool_input":{"url":"https://example.com/search?q=test&page=2"}}')
assert "preserves query params" "https://markdown.new/example.com/search?q=test&page=2" "$(url_from "$out")"

# --- Skip ---
echo "Skip:"

out=$(run '{"tool_input":{"url":"https://markdown.new/example.com"}}')
assert "already proxied" "" "$(url_from "$out")"

out=$(run '{"tool_input":{"url":""}}')
assert "empty URL" "" "$(url_from "$out")"

out=$(run '{"tool_input":{}}')
assert "missing URL" "" "$(url_from "$out")"

out=$(run '{"tool_input":{"url":"null"}}')
assert "null string URL" "" "$(url_from "$out")"

# --- Default exclusions ---
echo "Default exclusions:"

out=$(run '{"tool_input":{"url":"http://localhost:3000/api"}}')
assert "localhost" "" "$(url_from "$out")"

out=$(run '{"tool_input":{"url":"http://127.0.0.1:8080"}}')
assert "127.0.0.1" "" "$(url_from "$out")"

out=$(run '{"tool_input":{"url":"http://0.0.0.0:5000"}}')
assert "0.0.0.0" "" "$(url_from "$out")"

out=$(run '{"tool_input":{"url":"http://192.168.1.100/admin"}}')
assert "192.168.*" "" "$(url_from "$out")"

out=$(run '{"tool_input":{"url":"https://10.0.0.1/internal"}}')
assert "10.*" "" "$(url_from "$out")"

out=$(run '{"tool_input":{"url":"https://172.16.0.1/dashboard"}}')
assert "172.16.*" "" "$(url_from "$out")"

# --- Config: method ---
echo "Config (method):"

cat > "$tmp_home/.claude/hooks/markdown-config.json" <<'EOF'
{"method": "browser", "exclude": []}
EOF
out=$(run '{"tool_input":{"url":"https://example.com"}}')
assert "method=browser" "https://markdown.new/example.com?method=browser" "$(url_from "$out")"

cat > "$tmp_home/.claude/hooks/markdown-config.json" <<'EOF'
{"method": "ai", "exclude": []}
EOF
out=$(run '{"tool_input":{"url":"https://example.com"}}')
assert "method=ai" "https://markdown.new/example.com?method=ai" "$(url_from "$out")"

cat > "$tmp_home/.claude/hooks/markdown-config.json" <<'EOF'
{"method": "auto", "exclude": []}
EOF
out=$(run '{"tool_input":{"url":"https://example.com"}}')
assert "method=auto" "https://markdown.new/example.com?method=auto" "$(url_from "$out")"

cat > "$tmp_home/.claude/hooks/markdown-config.json" <<'EOF'
{"method": "invalid", "exclude": []}
EOF
out=$(run '{"tool_input":{"url":"https://example.com"}}')
assert "invalid method ignored" "https://markdown.new/example.com" "$(url_from "$out")"

# --- Config: retain_images ---
echo "Config (retain_images):"

cat > "$tmp_home/.claude/hooks/markdown-config.json" <<'EOF'
{"retain_images": true, "exclude": []}
EOF
out=$(run '{"tool_input":{"url":"https://example.com"}}')
assert "retain_images=true" "https://markdown.new/example.com?retain_images=true" "$(url_from "$out")"

cat > "$tmp_home/.claude/hooks/markdown-config.json" <<'EOF'
{"retain_images": false, "exclude": []}
EOF
out=$(run '{"tool_input":{"url":"https://example.com"}}')
assert "retain_images=false ignored" "https://markdown.new/example.com" "$(url_from "$out")"

# --- Config: combined ---
echo "Config (combined):"

cat > "$tmp_home/.claude/hooks/markdown-config.json" <<'EOF'
{"method": "browser", "retain_images": true, "exclude": []}
EOF
out=$(run '{"tool_input":{"url":"https://example.com"}}')
assert "method + retain_images" "https://markdown.new/example.com?method=browser&retain_images=true" "$(url_from "$out")"

cat > "$tmp_home/.claude/hooks/markdown-config.json" <<'EOF'
{"method": "browser", "exclude": []}
EOF
out=$(run '{"tool_input":{"url":"https://example.com/search?q=test"}}')
assert "config params + existing query" "https://markdown.new/example.com/search?q=test&method=browser" "$(url_from "$out")"

# --- Config: custom exclusions ---
echo "Config (exclusions):"

cat > "$tmp_home/.claude/hooks/markdown-config.json" <<'EOF'
{"exclude": ["*.internal.co"]}
EOF
out=$(run '{"tool_input":{"url":"https://docs.internal.co/api"}}')
assert "wildcard *.internal.co" "" "$(url_from "$out")"

cat > "$tmp_home/.claude/hooks/markdown-config.json" <<'EOF'
{"exclude": ["secret.example.com"]}
EOF
out=$(run '{"tool_input":{"url":"https://secret.example.com/docs"}}')
assert "exact domain" "" "$(url_from "$out")"

out=$(run '{"tool_input":{"url":"https://public.example.com"}}')
assert "non-matching domain passes" "https://markdown.new/public.example.com" "$(url_from "$out")"

# --- No config file ---
echo "No config:"

rm -f "$tmp_home/.claude/hooks/markdown-config.json"
out=$(run '{"tool_input":{"url":"https://example.com"}}')
assert "works without config" "https://markdown.new/example.com" "$(url_from "$out")"

# --- Cleanup ---
rm -rf "$tmp_home"

# --- Results ---
echo ""
echo "$((pass + fail)) tests: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
