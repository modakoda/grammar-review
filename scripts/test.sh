#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

args=()
plugins=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
if [[ "$(xcode-select -p)" == /Library/Developer/CommandLineTools* && -d "$plugins" ]]; then
  args+=(-Xswiftc -plugin-path -Xswiftc "$plugins")
fi

swift test ${args[@]+"${args[@]}"} "$@"
