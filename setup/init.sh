#!/bin/bash
set -euo pipefail

PROJECT_DIR="${1:-}"
if [ -z "$PROJECT_DIR" ]; then
    echo "Usage: setup/init.sh <project_directory>"
    echo ""
    echo "Creates a new GROMACS HPC project at the specified path."
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)/$PROJECT_DIR"

if [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/config.sh" ]; then
    echo "ERROR: Project already exists at $PROJECT_DIR"
    exit 1
fi

SETUP_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES="$SETUP_DIR/templates"

mkdir -p "$PROJECT_DIR/input"
mkdir -p "$PROJECT_DIR/output/setup"
mkdir -p "$PROJECT_DIR/output/equilibration"
mkdir -p "$PROJECT_DIR/output/production"
mkdir -p "$PROJECT_DIR/output/logs"
mkdir -p "$PROJECT_DIR/output/reports"
mkdir -p "$PROJECT_DIR/scripts"

# Copy default config if not provided
if [ ! -f "$PROJECT_DIR/config.sh" ]; then
    cp "$TEMPLATES/config.sh" "$PROJECT_DIR/config.sh"
    echo "  Created: config.sh"
fi

# Copy profiles if profiles/ is empty
if [ ! -d "$PROJECT_DIR/profiles" ] || [ -z "$(ls -A "$PROJECT_DIR/profiles" 2>/dev/null)" ]; then
    mkdir -p "$PROJECT_DIR/profiles"
    cp "$TEMPLATES/profiles/generic-pbs.sh" "$PROJECT_DIR/profiles/"
    cp "$TEMPLATES/profiles/generic-slurm.sh" "$PROJECT_DIR/profiles/"
    cp "$TEMPLATES/profiles/generic-lsf.sh" "$PROJECT_DIR/profiles/"
    echo "  Created: profiles/ (generic templates)"
fi

echo ""
echo "Project initialized at: $PROJECT_DIR"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_DIR"
echo "  2. Place your input files:"
echo "       input/system.pdb"
echo "       input/em.mdp"
echo "       input/nvt.mdp"
echo "       input/npt.mdp"
echo "       input/md.mdp"
echo "  3. Edit config.sh"
echo "  4. Run: setup/doctor.sh"
echo "  5. Run: ./run.sh submit"
echo ""
