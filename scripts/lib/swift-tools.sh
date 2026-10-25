require_tool() {
  if ! command -v "$1" >/dev/null; then
    echo "$1 is not installed. Install the developer tools with: brew bundle" >&2
    exit 69
  fi
}

use_command_line_tools_sourcekit() {
  local clt=/Library/Developer/CommandLineTools
  if [[ -z "${TOOLCHAIN_DIR:-}" && "$(xcode-select -p)" == "$clt"* && -d "$clt/usr/lib/sourcekitdInProc.framework" ]]; then
    export TOOLCHAIN_DIR="$clt"
  fi
}
