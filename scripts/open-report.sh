#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
REPORT="$ROOT_DIR/state/latest-report.md"

usage() {
  cat <<'TXT'
Usage: open-report.sh [--path|--print|--help]

  no option   Open the latest Markdown report
              VS Code is preferred, then the macOS default application
  --path      Print the report path only
  --print     Print the report to the terminal
  --help      Show this help
TXT
}

if (( $# > 1 )); then
  print -u2 "ERROR: Too many arguments."
  print -u2
  usage >&2
  exit 2
fi

case "${1:-}" in
  "")
    ;;
  --path)
    print -r -- "$REPORT"
    exit 0
    ;;
  --print)
    if [[ ! -f "$REPORT" ]]; then
      print -u2 "ERROR: No report has been generated yet."
      print -u2 "Expected report: $REPORT"
      print -u2 "Generate it with: $SCRIPT_DIR/run-now.sh --follow"
      exit 1
    fi

    cat -- "$REPORT"
    exit 0
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    print -u2 "ERROR: Unknown option: $1"
    print -u2
    usage >&2
    exit 2
    ;;
esac

if [[ ! -f "$REPORT" ]]; then
  print -u2 "ERROR: No report has been generated yet."
  print -u2 "Expected report: $REPORT"
  print -u2 "Generate it with: $SCRIPT_DIR/run-now.sh --follow"
  exit 1
fi

print "Opening Brew AI Update Agent report:"
print "  $REPORT"

if command -v code >/dev/null 2>&1; then
  exec command code "$REPORT"
fi

if command -v open >/dev/null 2>&1; then
  exec command open "$REPORT"
fi

print -u2 "ERROR: Cannot open the report automatically."
print -u2 "Neither Visual Studio Code CLI ('code') nor macOS 'open' is available."
print -u2 "Report: $REPORT"
exit 1
