#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
LOG="$ROOT_DIR/state/agent.log"

LINES=40
FOLLOW=1

usage() {
  cat <<'TXT'
Usage: show-log.sh [--no-follow] [--lines N] [--help]

  no option     Show the last 40 lines and follow new output
  --no-follow   Show recent lines and exit
  --lines N     Number of recent lines to show (default: 40)
  --help        Show this help

Ctrl+C stops viewing the log; it does not stop the agent.
TXT
}

while (( $# > 0 )); do
  case "$1" in
    --no-follow)
      FOLLOW=0
      shift
      ;;
    --lines)
      if (( $# < 2 )); then
        print -u2 -- "ERROR: --lines requires a positive integer."
        usage >&2
        exit 2
      fi

      if [[ "$2" != <-> || "$2" -le 0 ]]; then
        print -u2 -- "ERROR: Invalid value for --lines: $2"
        print -u2 -- "Expected a positive integer."
        exit 2
      fi

      LINES="$2"
      shift 2
      ;;
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
done

if [[ ! -f "$LOG" ]]; then
  print -u2 -- "ERROR: Agent log has not been created yet."
  print -u2 -- "Expected: $LOG"
  print -u2 -- "Start the agent with: \"$SCRIPT_DIR/run-now.sh\""
  exit 1
fi

if [[ ! -r "$LOG" ]]; then
  print -u2 -- "ERROR: Agent log is not readable: $LOG"
  exit 1
fi

if (( FOLLOW )); then
  print -- "Following Brew AI Update Agent log (last $LINES lines)."
  print -- "Press Ctrl+C to stop viewing. This does not stop the agent."
  print
  exec /usr/bin/tail -n "$LINES" -f "$LOG"
fi

exec /usr/bin/tail -n "$LINES" "$LOG"
