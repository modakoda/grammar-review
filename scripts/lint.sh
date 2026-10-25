#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib/swift-tools.sh

require_tool swiftformat
require_tool swiftlint
use_command_line_tools_sourcekit

format_reporter=()
lint_reporter=()
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  format_reporter=(--reporter github-actions-log)
  lint_reporter=(--reporter github-actions-logging)
fi

status=0
echo "==> SwiftFormat"
swiftformat . --lint --quiet ${format_reporter[@]+"${format_reporter[@]}"} || status=1
echo "==> SwiftLint"
swiftlint lint --strict --quiet ${lint_reporter[@]+"${lint_reporter[@]}"} || status=1

if ((status != 0)); then
  echo "Lint failed. scripts/format.sh fixes formatting; the rest needs a manual fix." >&2
fi
exit "$status"
