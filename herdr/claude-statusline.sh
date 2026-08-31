#!/bin/sh

# Capture Claude Code's live model and effort for Herdr, then delegate to the
# existing ccstatusline renderer unchanged.
set -u

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
payload=$(cat)

if command -v jq >/dev/null 2>&1; then
  session_id=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)

  case "$session_id" in
    '' | *[!A-Za-z0-9_-]*) ;;
    *)
      profile_file="$config_dir/.agent-elapsed-state.claude-${session_id}.json"
      temporary=$(mktemp "$config_dir/.agent-elapsed-state.claude-${session_id}.XXXXXX")

      if printf '%s' "$payload" |
        jq -c '{
          model: (.model.id // .model.display_name // null),
          effort: (.effort.level // null),
          updated_at: now
        }' > "$temporary" 2>/dev/null; then
        mv "$temporary" "$profile_file"
      else
        rm -f "$temporary"
      fi
      ;;
  esac
fi

printf '%s' "$payload" | npx -y ccstatusline@latest
