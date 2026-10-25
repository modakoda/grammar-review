#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib/swift-tools.sh

require_tool gitleaks
require_tool osv-scanner
require_tool zizmor
require_tool semgrep

# The scripts parse only the appcast.xml that assemble-site.py writes itself, so defusedxml adds
# nothing there.
semgrep_excludes=(
  --exclude-rule python.lang.security.use-defused-xml.use-defused-xml
  --exclude-rule python.lang.security.use-defused-xml-parse.use-defused-xml-parse
)

zizmor_format=()
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  zizmor_format=(--format github)
fi

status=0
echo "==> Gitleaks (secrets in the commit history)"
gitleaks git . --redact --no-banner || status=1
echo "==> OSV-Scanner (known vulnerabilities in Package.resolved and site/tests/package-lock.json)"
osv-scanner scan source --recursive . || status=1
echo "==> zizmor (GitHub Actions workflows)"
zizmor ${zizmor_format[@]+"${zizmor_format[@]}"} .github/workflows || status=1
echo "==> Semgrep (Swift, Python and hard-coded secrets)"
semgrep scan --metrics=off --error --quiet \
  --config p/swift --config p/python --config p/secrets "${semgrep_excludes[@]}" || status=1

if ((status != 0)); then
  echo "Security checks failed: fix the problems above." >&2
fi
exit "$status"
