#!/bin/bash
# Create N replicate projects from a prepared template project.
# Each replicate is fully independent (own config, state, output).
set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

TEMPLATE="${1:-}"
BASE="${2:-}"
COUNT="${3:-}"

if [ -z "$TEMPLATE" ] || [ -z "$BASE" ] || [ -z "$COUNT" ]; then
    echo "Usage: setup/replicate.sh <template_project> <base_name> <count>"
    echo ""
    echo "Clones a prepared template project into <count> independent"
    echo "replicates named <base_name>_rep1 ... <base_name>_rep<count>."
    echo ""
    echo "Example:"
    echo "  setup/replicate.sh projects/blm_kras_template blm_kras 3"
    echo "  # creates projects/blm_kras_rep1, _rep2, _rep3"
    echo ""
    echo "Each replicate starts fresh (no shared output/state), so they"
    echo "run in parallel on the cluster."
    exit 1
fi

# Resolve paths relative to the caller's working directory
CALLER_PWD="$PWD"
case "$TEMPLATE" in
    /*) TEMPLATE_DIR="$TEMPLATE" ;;
    *)  TEMPLATE_DIR="$CALLER_PWD/$TEMPLATE" ;;
esac

if [ ! -f "$TEMPLATE_DIR/config.sh" ] || [ ! -f "$TEMPLATE_DIR/input/system.pdb" ]; then
    echo "ERROR: Template project is not ready. It must contain:"
    echo "       config.sh"
    echo "       input/system.pdb"
    echo "       mdp/ (from setup/init.sh)"
    exit 1
fi

echo "Creating $COUNT replicates from: $TEMPLATE_DIR"
echo ""

for i in $(seq 1 "$COUNT"); do
    REP_NAME="${BASE}_rep${i}"
    REP_DIR="$(dirname "$TEMPLATE_DIR")/${BASE}_rep${i}"

    if [ -d "$REP_DIR" ]; then
        echo "  SKIP: $REP_DIR already exists"
        continue
    fi

    # Copy template (exclude runtime artifacts)
    mkdir -p "$REP_DIR"
    cp -r "$TEMPLATE_DIR"/. "$REP_DIR"/
    rm -rf "$REP_DIR/output" "$REP_DIR/scripts" "$REP_DIR/.state"

    # Set a unique PROJECT name in config.sh
    if grep -q '^PROJECT=' "$REP_DIR/config.sh"; then
        sed "s|^PROJECT=.*|PROJECT=\"$REP_NAME\"|" "$REP_DIR/config.sh" > "$REP_DIR/config.sh.tmp"
        mv "$REP_DIR/config.sh.tmp" "$REP_DIR/config.sh"
    else
        echo "PROJECT=\"$REP_NAME\"" >> "$REP_DIR/config.sh"
    fi

    # Reinitialize state and fingerprint
    bash "$PIPELINE_DIR/setup/state.sh" "$REP_DIR"
    bash "$PIPELINE_DIR/setup/fingerprint.sh" "$REP_DIR"

    echo "  Created: $REP_DIR"
done

echo ""
echo "Done. Submit all replicates with:"
for i in $(seq 1 "$COUNT"); do
    REP_NAME="${BASE}_rep${i}"
    echo "  bash $PIPELINE_DIR/run.sh submit ${BASE%/}_rep${i}  (from the parent of projects/)"
done
echo ""
echo "Or run them in parallel:"
echo "  for p in ${BASE}_rep*; do bash $PIPELINE_DIR/run.sh submit \$p & done; wait"
