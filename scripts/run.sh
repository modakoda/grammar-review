#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Builds the app bundle, quits a running copy, and opens the new build.

  scripts/run.sh          build and launch
  scripts/run.sh --logs   ... then stream the app's log messages (Ctrl-C to stop)
EOF
}

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="$root/build/Grammar Review.app"
process=GrammarReview

logs=false
for arg in "$@"; do
  case "$arg" in
    --logs) logs=true ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (try --help)" >&2
      exit 64
      ;;
  esac
done

"$root/scripts/build-app.sh"

if pgrep -x "$process" >/dev/null; then
  echo "==> Quitting the running Grammar Review"
  osascript -e 'quit app "Grammar Review"' >/dev/null 2>&1 || true
  for _ in {1..50}; do
    pgrep -x "$process" >/dev/null || break
    sleep 0.1
  done
  if pgrep -x "$process" >/dev/null; then
    echo "    still running; sending SIGTERM"
    pkill -x "$process" || true
    sleep 0.5
  fi
fi

echo "==> Opening $app"
open "$app"

if $logs; then
  echo "==> Streaming logs (Ctrl-C to stop)"
  exec log stream --predicate 'subsystem == "com.grammarreview.app"' --level debug
fi
