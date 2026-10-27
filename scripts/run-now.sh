#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
LABEL="com.brew-ai-update-agent"
SERVICE="gui/$(id -u)/$LABEL"
LOG="$ROOT_DIR/state/agent.log"
LOG_HELPER="$SCRIPT_DIR/show-log.sh"
FOLLOW=0

usage() {
  cat <<'TXT'
Usage: run-now.sh [--follow|--help]

  no option   Request one agent run via launchd and return
  --follow    Request a run, then follow the application log
  --help      Show this help

The agent may refresh Homebrew metadata and use GitHub Copilot credits.
This helper does not execute brew upgrade.
Following the log does not confirm that the run completed successfully.
Ctrl+C stops viewing the log; it does not stop the agent.
TXT
}

[[ $# -le 1 ]] || {
  print -u2 -- "ERROR: Expected at most one option."
  usage >&2
  exit 2
}

case "${1:-}" in
  "") ;;
  --follow) FOLLOW=1 ;;
  --help|-h) usage; exit 0 ;;
  *)
    print -u2 -- "ERROR: Unknown option: $1"
    usage >&2
    exit 2
    ;;
esac

command -v launchctl >/dev/null 2>&1 || {
  print -u2 -- "ERROR: launchctl is unavailable. This helper requires macOS."
  exit 1
}

if (( FOLLOW )) && [[ ! -r "$LOG_HELPER" ]]; then
  print -u2 -- "ERROR: Log helper is missing or unreadable: $LOG_HELPER"
  exit 1
fi

if ! SERVICE_STATUS="$(launchctl print "$SERVICE" 2>&1)"; then
  print -u2 -- "ERROR: Cannot access the LaunchAgent: $SERVICE"
  print -u2 -r -- "$SERVICE_STATUS"
  print -u2 -- "Check with: \"$SCRIPT_DIR/status.sh\""
  exit 1
fi

if print -r -- "$SERVICE_STATUS" |
    grep -E '^[[:space:]]*state = running[[:space:]]*$' >/dev/null; then
  print -- "Brew AI Update Agent is already running."
  if (( FOLLOW )); then
    exec /bin/zsh "$LOG_HELPER"
  fi
  print -- "Follow progress: \"$LOG_HELPER\""
  exit 0
fi

print -- "Requesting a Brew AI Update Agent run..."
print -- "The agent may refresh Homebrew metadata and use Copilot credits."

if ! launchctl kickstart "$SERVICE"; then
  print -u2 -- "ERROR: launchd could not start the agent."
  print -u2 -- "Check with: \"$SCRIPT_DIR/status.sh\""
  exit 1
fi

print -- "Start request accepted by launchd. Completion is not yet confirmed."

if (( FOLLOW )); then
  for _ in {1..50}; do
    [[ -f "$LOG" ]] && break
    sleep 0.1
  done

  if [[ -f "$LOG" ]]; then
    exec /bin/zsh "$LOG_HELPER"
  fi

  print -u2 -- "WARNING: The application log has not appeared yet."
  print -u2 -- "Check with: \"$SCRIPT_DIR/status.sh\""
  exit 0
fi

print -- "Follow progress: \"$LOG_HELPER\""
print -- "Check status: \"$SCRIPT_DIR/status.sh\""
