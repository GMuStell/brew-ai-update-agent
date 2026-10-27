#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

LABEL="com.brew-ai-update-agent"
SERVICE="gui/$(id -u)/$LABEL"

EXPECTED_SCRIPT="$ROOT_DIR/bin/brew-ai-update-agent.sh"
REPORT="$ROOT_DIR/state/latest-report.md"
LOG="$ROOT_DIR/state/agent.log"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

usage() {
  cat <<'TXT'
Usage: status.sh [--raw|--help]

  no option   Show a concise health and status summary
  --raw       Show the complete launchctl service definition
  --help      Show this help
TXT
}

[[ $# -le 1 ]] || {
  print -u2 -- "ERROR: Expected at most one option."
  usage >&2
  exit 2
}

case "${1:-}" in
  "") ;;
  --raw) RAW=1 ;;
  --help|-h)
    usage
    exit 0
    ;;
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

if [[ "${RAW:-0}" -eq 1 ]]; then
  if ! launchctl print "$SERVICE"; then
    print -u2 -- "ERROR: Cannot access the LaunchAgent: $SERVICE"
    exit 1
  fi
  exit 0
fi

field() {
  print -r -- "$STATUS" |
    /usr/bin/grep -m1 "$1" |
    /usr/bin/sed 's/^[[:space:]]*//' || true
}

calendar_value() {
  print -r -- "$STATUS" |
    /usr/bin/grep -m1 "\"$1\"" |
    /usr/bin/sed -E 's/.*=>[[:space:]]*//' || true
}

print -- "=== Brew AI Update Agent ==="
print -- "Project: $ROOT_DIR"
print

if [[ -f "$PLIST" ]]; then
  print -- "LaunchAgent plist: $PLIST"
else
  print -- "LaunchAgent plist: NOT FOUND"
fi

print

if STATUS="$(launchctl print "$SERVICE" 2>/dev/null)"; then
  print -- "LaunchAgent: LOADED"

  STATE="$(field 'state =')"
  RUNS="$(field 'runs =')"
  EXIT_CODE="$(field 'last exit code =')"

  [[ -n "$STATE" ]] && print -- "  $STATE"
  [[ -n "$RUNS" ]] && print -- "  $RUNS"
  [[ -n "$EXIT_CODE" ]] && print -- "  $EXIT_CODE"

  ACTIVE_SCRIPT="$(
    print -r -- "$STATUS" |
      /usr/bin/grep -m1 'brew-ai-update-agent.sh' |
      /usr/bin/sed 's/^[[:space:]]*//' || true
  )"

  print -- "  Expected script: $EXPECTED_SCRIPT"
  [[ -n "$ACTIVE_SCRIPT" ]] && print -- "  Loaded script:   $ACTIVE_SCRIPT"

  if [[ -n "$ACTIVE_SCRIPT" && "$ACTIVE_SCRIPT" != *"$EXPECTED_SCRIPT"* ]]; then
    print -- "  WARNING: Loaded service does not appear to use the project script."
  fi

  WEEKDAY="$(calendar_value Weekday)"
  HOUR="$(calendar_value Hour)"
  MINUTE="$(calendar_value Minute)"

  print
  print -- "Schedule:"

  if [[ "$WEEKDAY" == <-> && "$HOUR" == <-> && "$MINUTE" == <-> ]]; then
    case "$WEEKDAY" in
      0|7) DAY_NAME="Sunday" ;;
      1) DAY_NAME="Monday" ;;
      2) DAY_NAME="Tuesday" ;;
      3) DAY_NAME="Wednesday" ;;
      4) DAY_NAME="Thursday" ;;
      5) DAY_NAME="Friday" ;;
      6) DAY_NAME="Saturday" ;;
      *) DAY_NAME="unknown" ;;
    esac

    printf '  %s (Weekday %s) at %02d:%02d\n' \
      "$DAY_NAME" "$WEEKDAY" "$HOUR" "$MINUTE"
  else
    print -- "  unavailable"
  fi
else
  print -- "LaunchAgent: NOT LOADED"
  print -- "  Service: $SERVICE"
  print -- "Schedule: unavailable"
fi

print

if [[ -f "$REPORT" ]]; then
  print -- "Report: $REPORT"

  if [[ -r "$REPORT" ]]; then
    MODIFIED="$(
      /usr/bin/stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$REPORT" 2>/dev/null ||
        true
    )"

    [[ -n "$MODIFIED" ]] && print -- "  Last modified: $MODIFIED"

    for prefix in 'Pending updates:' 'AI analyses refreshed:' 'Summary:'; do
      LINE="$(/usr/bin/grep -m1 "^$prefix" "$REPORT" || true)"
      [[ -n "$LINE" ]] && print -- "  $LINE"
    done
  else
    print -- "  WARNING: Report is not readable."
  fi
else
  print -- "Report: NOT CREATED"
fi

print

if [[ -f "$LOG" ]]; then
  print -- "Agent log: $LOG"

  if [[ -r "$LOG" ]]; then
    LAST_START="$(
      /usr/bin/grep -E '^\[[^]]+\] Start v' "$LOG" |
        /usr/bin/tail -n 1 || true
    )"

    LAST_RESULT="$(
      /usr/bin/grep -E 'Complete v|^\[ERROR\]' "$LOG" |
        /usr/bin/tail -n 1 || true
    )"

    [[ -n "$LAST_START" ]] && print -- "  Latest start:  $LAST_START"
    [[ -n "$LAST_RESULT" ]] && print -- "  Latest result: $LAST_RESULT"
  else
    print -- "  WARNING: Agent log is not readable."
  fi
else
  print -- "Agent log: NOT CREATED"
fi

print
print -- "Helpers:"
print -- "  Run:         \"$SCRIPT_DIR/run-now.sh\""
print -- "  Run + log:   \"$SCRIPT_DIR/run-now.sh\" --follow"
print -- "  Log:         \"$SCRIPT_DIR/show-log.sh\""
print -- "  Report:      \"$SCRIPT_DIR/open-report.sh\""
print -- "  Raw status:  \"$SCRIPT_DIR/status.sh\" --raw"
