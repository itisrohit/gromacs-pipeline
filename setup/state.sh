#!/bin/bash
set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

mkdir -p ".state"

if [ -f "config.sh" ]; then
    source "config.sh"
fi

TMP=$(mktemp ".state/workflow.json.XXXXXX")

cat > "$TMP" <<- STATEOF
{
  "schema_version": 1,
  "project": "${PROJECT:-unknown}",
  "initialized": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phases": {
    "setup": { "status": "pending" },
    "equilibration": { "status": "pending" },
    "production": { "status": "pending" }
  }
}
STATEOF

mv "$TMP" ".state/workflow.json"
echo "State initialized: .state/workflow.json"
