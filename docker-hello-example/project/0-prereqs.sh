#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Check for Docker

set -euo pipefail

success_count=0

if "${SCRIPT_DIR}/../../bin/check-docker"; then
  success_count=$((success_count + 1))
fi

echo ""
if [ "$success_count" = 1 ]; then
    echo "✅ Success; all checks complete"
else
    echo "⚠️  Please resolve issues above"
    exit 1
fi
