#!/bin/bash
set -euo pipefail

CALLER_PWD="$PWD"
PIPELINE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PROJECT_DIR="${1:-}"
if [ -z "$PROJECT_DIR" ]; then
    echo "Usage: setup/init.sh <project_directory>"
    echo ""
    echo "Creates a new GROMACS HPC project at the specified path."
    exit 1
fi

# Resolve to absolute path (relative to caller's CWD)
case "$PROJECT_DIR" in
    /*) ;;
    *)  PROJECT_DIR="$CALLER_PWD/$PROJECT_DIR" ;;
esac

if [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/config.sh" ]; then
    echo "ERROR: Project already exists at $PROJECT_DIR"
    exit 1
fi

TEMPLATES="$PIPELINE_DIR/setup/templates"

mkdir -p "$PROJECT_DIR/input"
mkdir -p "$PROJECT_DIR/output/setup"
mkdir -p "$PROJECT_DIR/output/equilibration"
mkdir -p "$PROJECT_DIR/output/production"
mkdir -p "$PROJECT_DIR/output/logs"
mkdir -p "$PROJECT_DIR/output/reports"
mkdir -p "$PROJECT_DIR/scripts"

# Copy default config
if [ ! -f "$PROJECT_DIR/config.sh" ]; then
    cp "$TEMPLATES/config.sh" "$PROJECT_DIR/config.sh"
    echo "  Created: config.sh"
fi

# Copy default MDPs into project for reproducibility
if [ ! -d "$PROJECT_DIR/mdp" ]; then
    mkdir -p "$PROJECT_DIR/mdp"
    cp "$PIPELINE_DIR/mdp/"*.mdp "$PROJECT_DIR/mdp/"
    echo "  Created: mdp/ (copied from pipeline defaults)"
fi

# Initialize project state
bash "$PIPELINE_DIR/setup/state.sh" "$PROJECT_DIR"

# Write fingerprint
bash "$PIPELINE_DIR/setup/fingerprint.sh" "$PROJECT_DIR"

echo ""
echo "Project initialized at: $PROJECT_DIR"
echo ""
echo "Next steps:"
echo "  1. Place your input structure:"
echo "       $PROJECT_DIR/input/system.pdb"
echo "  2. Edit config.sh:"
echo "       $PROJECT_DIR/config.sh"
echo "  3. Validate:"
echo "       $PIPELINE_DIR/setup/validate.sh $PROJECT_DIR"
echo "  4. Submit:"
echo "       $PIPELINE_DIR/run.sh submit $PROJECT_DIR"
echo ""
