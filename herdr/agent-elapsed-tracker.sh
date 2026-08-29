#!/bin/sh

# Display-only elapsed-time reporter for Herdr agent rows. Herdr exposes the
# current semantic state but no state-transition timestamp, so a run begins
# when this tracker first observes the pane as working.
set -eu

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state_file="$config_dir/agent-elapsed-state.json"
herdr_bin=${HERDR_BIN_PATH:-herdr}

if [ ! -f "$state_file" ]; then
  printf '%s\n' '{"starts":{},"labels":{},"profiles":{}}' > "$state_file"
fi

update_state() {
  expression=$1
  shift
  temporary=$(mktemp "$config_dir/.agent-elapsed-state.XXXXXX")
  jq "$expression" "$@" "$state_file" > "$temporary"
  mv "$temporary" "$state_file"
}

agents=$($herdr_bin agent list 2>/dev/null || true)
if ! printf '%s' "$agents" | jq -e '.result.agents | type == "array"' >/dev/null 2>&1; then
  exit 0
fi

# These labels are a local display convention, not model telemetry. Keep the
# mapping in one place so it can be adjusted without touching sidebar layout.
printf '%s' "$agents" |
  jq -r '.result.agents[] | [.pane_id, .agent] | @tsv' |
  while IFS="$(printf '\t')" read -r pane_id agent_name; do
    case "$agent_name" in
      codex) profile='S/xh' ;;
      claude) profile='Op/h' ;;
      *) continue ;;
    esac

    previous_profile=$(jq -r --arg pane_id "$pane_id" '.profiles[$pane_id] // empty' "$state_file")
    if [ "$profile" != "$previous_profile" ] &&
      "$herdr_bin" pane report-metadata "$pane_id" \
        --source user:elapsed-tracker \
        --token "profile=$profile" >/dev/null 2>&1; then
      update_state '.profiles = (.profiles // {}) | .profiles[$pane_id] = $profile' \
        --arg pane_id "$pane_id" \
        --arg profile "$profile"
    fi
  done

seen=$(mktemp "${TMPDIR:-/tmp}/herdr-elapsed-seen.XXXXXX")
trap 'rm -f "$seen"' EXIT HUP INT TERM

printf '%s' "$agents" |
  jq -r '.result.agents[] | select(.agent_status == "working") | .pane_id' |
  while IFS= read -r pane_id; do
    [ -n "$pane_id" ] || continue
    printf '%s\n' "$pane_id" >> "$seen"

    started_at=$(jq -r --arg pane_id "$pane_id" '.starts[$pane_id] // empty' "$state_file")
    if [ -z "$started_at" ]; then
      started_at=$(date +%s)
      update_state '.starts[$pane_id] = $started_at' \
        --arg pane_id "$pane_id" \
        --argjson started_at "$started_at"
    fi

    now=$(date +%s)
    elapsed_seconds=$((now - started_at))
    if [ "$elapsed_seconds" -lt 60 ]; then
      elapsed_label='<1m'
    else
      elapsed_label="$((elapsed_seconds / 60))m"
    fi

    previous_label=$(jq -r --arg pane_id "$pane_id" '.labels[$pane_id] // empty' "$state_file")
    if [ "$elapsed_label" != "$previous_label" ] &&
      "$herdr_bin" pane report-metadata "$pane_id" \
        --source user:elapsed-tracker \
        --token "elapsed=$elapsed_label" \
        --ttl-ms 90000 >/dev/null 2>&1; then
      update_state '.labels[$pane_id] = $elapsed_label' \
        --arg pane_id "$pane_id" \
        --arg elapsed_label "$elapsed_label"
    fi
  done

jq -r '.starts | keys[]?' "$state_file" |
  while IFS= read -r pane_id; do
    [ -n "$pane_id" ] || continue
    if ! grep -Fqx "$pane_id" "$seen"; then
      "$herdr_bin" pane report-metadata "$pane_id" \
        --source user:elapsed-tracker \
        --clear-token elapsed >/dev/null 2>&1 || true
      update_state 'del(.starts[$pane_id]) | del(.labels[$pane_id])' --arg pane_id "$pane_id"
    fi
  done
