#!/bin/sh

# Display-only elapsed-time reporter for Herdr agent rows. Herdr exposes the
# current semantic state but no state-transition timestamp, so a run begins
# when this tracker first observes the pane as working.
set -eu

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state_file="$config_dir/agent-elapsed-state.json"
herdr_bin=${HERDR_BIN_PATH:-herdr}

if [ ! -f "$state_file" ]; then
  printf '%s\n' '{"starts":{},"labels":{},"profiles":{},"sessions":{}}' > "$state_file"
fi

update_state() {
  expression=$1
  shift
  temporary=$(mktemp "$config_dir/.agent-elapsed-state.XXXXXX")
  jq "$expression" "$@" "$state_file" > "$temporary"
  mv "$temporary" "$state_file"
}

codex_session_from_process() {
  pane_id=$1
  process_info=$($herdr_bin pane process-info --pane "$pane_id" 2>/dev/null || true)

  printf '%s' "$process_info" |
    jq -r '
      .result.process_info.foreground_processes[]?.argv
      | select(((.[0]? // "") | endswith("codex")))
      | (index("resume")) as $resume_index
      | select($resume_index != null and .[$resume_index + 1] != null)
      | .[$resume_index + 1]
    ' 2>/dev/null |
    head -n 1
}

claude_session_from_process() {
  pane_id=$1
  process_info=$($herdr_bin pane process-info --pane "$pane_id" 2>/dev/null || true)

  printf '%s' "$process_info" |
    jq -r '
      .result.process_info.foreground_processes[]?.argv
      | select(((.[0]? // "") | endswith("claude")))
      | ((index("--resume")) // (index("-r"))) as $resume_index
      | select($resume_index != null and .[$resume_index + 1] != null)
      | .[$resume_index + 1]
    ' 2>/dev/null |
    head -n 1
}

find_codex_session_file() {
  session_id=$1
  codex_dir=${CODEX_HOME:-"$HOME/.codex"}
  cached_path=$(jq -r --arg session_id "$session_id" \
    '.sessions[$session_id].path // empty' "$state_file")

  if [ -n "$cached_path" ] && [ -f "$cached_path" ]; then
    printf '%s\n' "$cached_path"
    return
  fi

  find "$codex_dir/sessions" "$codex_dir/archived_sessions" \
    -type f -name "*-${session_id}.jsonl" -print 2>/dev/null |
    head -n 1
}

find_claude_session_file() {
  session_id=$1
  claude_dir=${CLAUDE_CONFIG_DIR:-"$HOME/.claude"}
  cached_path=$(jq -r --arg session_id "$session_id" \
    '.sessions[$session_id].path // empty' "$state_file")

  if [ -n "$cached_path" ] && [ -f "$cached_path" ]; then
    printf '%s\n' "$cached_path"
    return
  fi

  find "$claude_dir/projects" -type f -name "${session_id}.jsonl" \
    -print 2>/dev/null |
    head -n 1
}

abbreviate_effort() {
  case "$1" in
    none) printf 'n\n' ;;
    low) printf 'l\n' ;;
    medium) printf 'm\n' ;;
    high) printf 'h\n' ;;
    xhigh) printf 'xh\n' ;;
    max) printf 'max\n' ;;
    ultracode) printf 'uc\n' ;;
    unknown) printf '?\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

codex_profile() {
  session_id=$1
  if [ -z "$session_id" ]; then
    printf '?/?\n'
    return
  fi

  session_file=$(find_codex_session_file "$session_id")
  if [ -z "$session_file" ] || [ ! -f "$session_file" ]; then
    printf '?/?\n'
    return
  fi

  cached_profile=$(jq -r --arg session_id "$session_id" \
    '.sessions[$session_id].profile // empty' "$state_file")
  settings=$(
    tail -n 400 "$session_file" |
      jq -c '
        if .type == "turn_context" then
          {model: .payload.model, effort: .payload.effort}
        elif .type == "event_msg" and .payload.type == "thread_settings_applied" then
          {
            model: .payload.thread_settings.model,
            effort: .payload.thread_settings.reasoning_effort
          }
        else
          empty
        end
        | select(.model != null and .effort != null)
      ' 2>/dev/null |
      tail -n 1
  )

  # A long-running turn can push its settings event outside the recent window.
  # Reuse the cached value in that case; scan the full file only on first sight.
  if [ -z "$settings" ] && [ -z "$cached_profile" ]; then
    settings=$(
      jq -c '
        if .type == "turn_context" then
          {model: .payload.model, effort: .payload.effort}
        elif .type == "event_msg" and .payload.type == "thread_settings_applied" then
          {
            model: .payload.thread_settings.model,
            effort: .payload.thread_settings.reasoning_effort
          }
        else
          empty
        end
        | select(.model != null and .effort != null)
      ' "$session_file" 2>/dev/null |
      tail -n 1
    )
  fi

  if [ -z "$settings" ]; then
    printf '%s\n' "${cached_profile:-?/?}"
    return
  fi

  model=$(printf '%s' "$settings" | jq -r '.model')
  effort=$(printf '%s' "$settings" | jq -r '.effort')

  case "$model" in
    gpt-6-astra) model_label='A' ;;
    gpt-5.6 | gpt-5.6-sol) model_label='S' ;;
    gpt-5.6-terra) model_label='T' ;;
    gpt-5.6-luna) model_label='L' ;;
    gpt-*) model_label=$(printf '%s' "$model" | sed -e 's/^gpt-//' -e 's/-codex$//') ;;
    *) model_label=$model ;;
  esac

  effort_label=$(abbreviate_effort "$effort")

  profile="$model_label/$effort_label"
  if [ "$profile" != "$cached_profile" ]; then
    update_state '
      .sessions = (.sessions // {})
      | .sessions[$session_id] = {path: $path, profile: $profile}
    ' \
      --arg session_id "$session_id" \
      --arg path "$session_file" \
      --arg profile "$profile"
  fi

  printf '%s\n' "$profile"
}

claude_profile() {
  session_id=$1
  if [ -z "$session_id" ]; then
    printf '?/?\n'
    return
  fi

  cached_profile=$(jq -r --arg session_id "$session_id" \
    '.sessions[$session_id].profile // empty' "$state_file")
  live_profile_file="$config_dir/.agent-elapsed-state.claude-${session_id}.json"
  session_file=$(find_claude_session_file "$session_id")

  if [ -f "$live_profile_file" ]; then
    settings=$(jq -c '
      select(.model != null)
      | {model, effort: (.effort // "unknown")}
    ' "$live_profile_file" 2>/dev/null || true)
  else
    if [ -z "$session_file" ] || [ ! -f "$session_file" ]; then
      printf '%s\n' "${cached_profile:-?/?}"
      return
    fi

    settings=$(
      tail -n 400 "$session_file" |
        jq -c '
          select(
            .type == "assistant"
            and (.isSidechain // false) == false
            and .message.model != null
            and .effort != null
          )
          | {model: .message.model, effort: .effort}
        ' 2>/dev/null |
        tail -n 1
    )
  fi

  if [ -z "$settings" ] && [ ! -f "$live_profile_file" ] && [ -z "$cached_profile" ]; then
    settings=$(
      jq -c '
        select(
          .type == "assistant"
          and (.isSidechain // false) == false
          and .message.model != null
          and .effort != null
        )
        | {model: .message.model, effort: .effort}
      ' "$session_file" 2>/dev/null |
      tail -n 1
    )
  fi

  if [ -z "$settings" ]; then
    printf '%s\n' "${cached_profile:-?/?}"
    return
  fi

  model=$(printf '%s' "$settings" | jq -r '.model')
  effort=$(printf '%s' "$settings" | jq -r '.effort')

  case "$model" in
    *claude-opus*) model_label='Op' ;;
    *claude-sonnet*) model_label='So' ;;
    *claude-haiku*) model_label='Ha' ;;
    *claude-fable*) model_label='Fa' ;;
    *) model_label=$(printf '%s' "$model" | sed 's|.*/||') ;;
  esac

  effort_label=$(abbreviate_effort "$effort")
  profile="$model_label/$effort_label"
  if [ "$profile" != "$cached_profile" ]; then
    update_state '
      .sessions = (.sessions // {})
      | .sessions[$session_id] = {path: $path, profile: $profile}
    ' \
      --arg session_id "$session_id" \
      --arg path "$session_file" \
      --arg profile "$profile"
  fi

  printf '%s\n' "$profile"
}

agents=$($herdr_bin agent list 2>/dev/null || true)
if ! printf '%s' "$agents" | jq -e '.result.agents | type == "array"' >/dev/null 2>&1; then
  exit 0
fi

printf '%s' "$agents" |
  jq -r '.result.agents[] | [.pane_id, .agent, (.agent_session.value // "")] | @tsv' |
  while IFS="$(printf '\t')" read -r pane_id agent_name session_id; do
    case "$agent_name" in
      codex)
        if [ -z "$session_id" ]; then
          session_id=$(codex_session_from_process "$pane_id")
        fi
        profile=$(codex_profile "$session_id")
        ;;
      claude)
        if [ -z "$session_id" ]; then
          session_id=$(claude_session_from_process "$pane_id")
        fi
        profile=$(claude_profile "$session_id")
        ;;
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
