#!/bin/bash
set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

if [ ! -d ".state" ]; then
    echo "ERROR: Project not initialized. Run setup/state.sh first."
    exit 1
fi

if [ ! -f "config.sh" ]; then
    echo "ERROR: config.sh not found"
    exit 1
fi

source "config.sh"

FILES_TO_HASH=("config.sh")

# Include the active cluster profile
if [ -n "${CLUSTER:-}" ] && [ -f "profiles/$CLUSTER.sh" ]; then
    FILES_TO_HASH+=("profiles/$CLUSTER.sh")
fi

# Include input files
for fvar in PDB EM_MDP NVT_MDP NPT_MDP MD_MDP; do
    fpath="${!fvar:-}"
    if [ -n "$fpath" ] && [ -f "$fpath" ]; then
        FILES_TO_HASH+=("$fpath")
    fi
done

FINGERPRINT=$(
    for f in "${FILES_TO_HASH[@]}"; do
        if [ -f "$f" ]; then
            sha256sum "$f" 2>/dev/null || shasum -a 256 "$f" 2>/dev/null
        fi
    done | sha256sum 2>/dev/null | cut -d' ' -f1
    if [ -z "$FINGERPRINT" ]; then
        for f in "${FILES_TO_HASH[@]}"; do
            [ -f "$f" ] && shasum -a 256 "$f"
        done | shasum -a 256 | cut -d' ' -f1
    fi
)

echo "$FINGERPRINT" > ".state/fingerprint"
echo "Fingerprint written: .state/fingerprint"
echo "  Files: ${FILES_TO_HASH[*]}"
