#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib/swift-tools.sh

require_tool swiftformat
require_tool swiftlint
use_command_line_tools_sourcekit

swiftlint lint --fix --quiet
swiftformat . --quiet
