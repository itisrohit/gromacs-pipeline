#!/bin/bash
# ==============================================================================
# post/prepare.sh — Trajectory preparation for GROMACS MD simulations
#
# Prepares raw production trajectories for visualization and analysis.
# Never modifies raw production outputs. All derived files go to prepared/.
#
# Usage:
#   bash gromacs-pipeline/post/prepare.sh <project> [options]
#
# Examples:
#   bash gromacs-pipeline/post/prepare.sh projects/blm_cmyc
#   bash gromacs-pipeline/post/prepare.sh projects/blm_cmyc --preset analysis
#   bash gromacs-pipeline/post/prepare.sh projects/blm_cmyc --fit-to Backbone
#   bash gromacs-pipeline/post/prepare.sh projects/blm_cmyc --keep Protein_DNA
#   bash gromacs-pipeline/post/prepare.sh projects/blm_cmyc --force
# ==============================================================================
set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ── Helpers ──────────────────────────────────────────────────────────────────
info()  { echo "[PREPARE]  $*"; }
warn()  { echo "[PREPARE]  WARNING: $*" >&2; }
error() { echo "[PREPARE]  ERROR: $*" >&2; exit 1; }

usage() {
    cat <<'EOF'
prepare.sh — Trajectory preparation for GROMACS MD simulations

Usage:
  bash gromacs-pipeline/post/prepare.sh <project> [options]

Options:
  --center-on <group>   Center trajectory on this group (default: Protein)
  --fit-to <group>      Rigid-body fit to this group
  --keep <group>        Keep only these atoms in output
  --preset <name>       Use a preset combination of options
  --force               Overwrite existing prepared files
  --help                Show this help

Presets:
  visualization         --center-on Protein
  analysis              --center-on Protein --fit-to Backbone --keep Protein_DNA
  dry                   --center-on Protein --keep Protein_DNA

Generated files (in output/prepared/):
  md_noPBC.xtc          PBC-corrected, centered trajectory
  md_noPBC.gro          First frame, PBC-corrected, centered
  md_fitted.xtc         Fitted trajectory (if --fit-to used)
  md_<group>.xtc        Stripped trajectory (if --keep used)
  md_<group>.gro        First frame, stripped (if --keep used)

Examples:
  bash gromacs-pipeline/post/prepare.sh projects/blm_cmyc
  bash gromacs-pipeline/post/prepare.sh projects/blm_cmyc --preset analysis
  bash gromacs-pipeline/post/prepare.sh projects/blm_cmyc --fit-to Backbone --keep Protein_DNA
EOF
    exit 0
}

# ── Parse arguments ──────────────────────────────────────────────────────────
PROJECT=""
CENTER_ON="Protein"
FIT_TO=""
KEEP=""
PRESET=""
FORCE=false
SHOW_HELP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)       SHOW_HELP=true; shift ;;
        --center-on)  CENTER_ON="$2"; shift 2 ;;
        --fit-to)     FIT_TO="$2"; shift 2 ;;
        --keep)       KEEP="$2"; shift 2 ;;
        --preset)     PRESET="$2"; shift 2 ;;
        --force)      FORCE=true; shift ;;
        -*)
            error "Unknown option: $1. Use --help for usage."
            ;;
        *)
            if [[ -z "$PROJECT" ]]; then
                PROJECT="$1"
            else
                error "Unexpected argument: $1. Use --help for usage."
            fi
            shift
            ;;
    esac
done

$SHOW_HELP && usage
[[ -z "$PROJECT" ]] && error "Missing project path. Usage: bash gromacs-pipeline/post/prepare.sh <project> [options]"

# ── Resolve project directory ────────────────────────────────────────────────
PROJECT_DIR="$(cd "$PROJECT" 2>/dev/null && pwd)" || {
    error "Project directory not found: $PROJECT"
}

cd "$PROJECT_DIR"

# ── Apply presets ────────────────────────────────────────────────────────────
if [[ -n "$PRESET" ]]; then
    case "$PRESET" in
        visualization)
            CENTER_ON="Protein"
            FIT_TO=""
            KEEP=""
            ;;
        analysis)
            CENTER_ON="Protein"
            FIT_TO="Backbone"
            KEEP="Protein_DNA"
            ;;
        dry)
            CENTER_ON="Protein"
            FIT_TO=""
            KEEP="Protein_DNA"
            ;;
        *)
            error "Unknown preset: $PRESET. Available: visualization, analysis, dry"
            ;;
    esac
    info "Preset '$PRESET' applied: --center-on $CENTER_ON${FIT_TO:+ --fit-to $FIT_TO}${KEEP:+ --keep $KEEP}"
fi

# ── Source pipeline libraries ────────────────────────────────────────────────
source "$PIPELINE_DIR/lib/gmx.sh"

# ── Find GROMACS ─────────────────────────────────────────────────────────────
gmx_check
info "GROMACS: $GMX ($GMX_VERSION)"

# ── Validate inputs ─────────────────────────────────────────────────────────
PROD_DIR="output/production"
PREP_DIR="output/prepared"

MD_XTC="$PROD_DIR/md.xtc"
MD_TPR="$PROD_DIR/md.tpr"

[[ -f "$MD_XTC" ]] || error "Trajectory not found: $MD_XTC"
[[ -f "$MD_TPR" ]] || error "TPR file not found: $MD_TPR"

# Check for index.ndx (optional, for custom groups)
INDEX_NDX=""
[[ -f "output/setup/index.ndx" ]] && INDEX_NDX="output/setup/index.ndx"

mkdir -p "$PREP_DIR"

# ── Group resolution ─────────────────────────────────────────────────────────
# Get group number for trjconv (by name)
# Checks index.ndx first (if provided), then GROMACS built-in groups
get_group_number() {
    local name="$1"
    local tpr="$2"
    local ndx="${3:-}"

    # Try index.ndx first (for custom groups like Protein_DNA)
    if [[ -n "$ndx" ]] && [[ -f "$ndx" ]]; then
        local num
        num=$(echo "q" | "$GMX" make_ndx -f "$tpr" -n "$ndx" 2>/dev/null \
            | awk -v name="$name" '$0 ~ "^[[:space:]]*[0-9]+[[:space:]]+" name "[[:space:]]" {gsub(/[^0-9]/,"",$1); print $1; exit}')
        if [[ -n "$num" ]] && [[ "$num" =~ ^[0-9]+$ ]]; then
            echo "$num"
            return 0
        fi
    fi

    # Fallback to built-in groups (Protein, Backbone, System, etc.)
    local num
    num=$(echo "q" | "$GMX" make_ndx -f "$tpr" 2>/dev/null \
        | awk -v name="$name" '$0 ~ "^[[:space:]]*[0-9]+[[:space:]]+" name "[[:space:]]" {gsub(/[^0-9]/,"",$1); print $1; exit}')

    if [[ -n "$num" ]] && [[ "$num" =~ ^[0-9]+$ ]]; then
        echo "$num"
        return 0
    fi

    return 1
}

# ── Skip-if-exists helper ───────────────────────────────────────────────────
skip_if_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        if $FORCE; then
            warn "Overwriting: $file"
            rm -f "$file"
            return 1
        else
            info "Skipping (exists): $file"
            return 0
        fi
    fi
    return 1
}

# ── Stage 1: PBC correction + centering ─────────────────────────────────────
NO_PBC_XTC="$PREP_DIR/md_noPBC.xtc"
NO_PBC_GRO="$PREP_DIR/md_noPBC.gro"

info "Stage 1: PBC correction + centering on $CENTER_ON"

if ! skip_if_exists "$NO_PBC_XTC"; then
    # Get group number for centering — always use built-in groups
    local_center=$(get_group_number "$CENTER_ON" "$MD_TPR") \
        || error "Group '$CENTER_ON' not found. Available groups can be listed with: $GMX make_ndx -f $MD_TPR"

    info "  Centering on group $local_center ($CENTER_ON)"
    info "  Output group: 0 (System)"

    echo "${local_center} 0" | "$GMX" trjconv \
        -s "$MD_TPR" \
        -f "$MD_XTC" \
        -o "$NO_PBC_XTC" \
        -pbc mol \
        -center \
        -quiet 2>/dev/null

    [[ -f "$NO_PBC_XTC" ]] || error "trjconv failed to produce $NO_PBC_XTC"
    info "  Generated: $NO_PBC_XTC ($(du -h "$NO_PBC_XTC" | cut -f1))"
fi

if ! skip_if_exists "$NO_PBC_GRO"; then
    local_center=$(get_group_number "$CENTER_ON" "$MD_TPR") \
        || error "Group '$CENTER_ON' not found"

    echo "${local_center} 0" | "$GMX" trjconv \
        -s "$MD_TPR" \
        -f "$NO_PBC_XTC" \
        -o "$NO_PBC_GRO" \
        -pbc mol \
        -center \
        -dump 0 \
        -quiet 2>/dev/null

    [[ -f "$NO_PBC_GRO" ]] || error "trjconv failed to produce $NO_PBC_GRO"
    info "  Generated: $NO_PBC_GRO"
fi

# ── Stage 2: Fitting (optional) ─────────────────────────────────────────────
FIT_XTC="$PREP_DIR/md_fitted.xtc"

if [[ -n "$FIT_TO" ]]; then
    info "Stage 2: Rigid-body fit to $FIT_TO"

    if ! skip_if_exists "$FIT_XTC"; then
        local_fit=$(get_group_number "$FIT_TO" "$MD_TPR") \
            || error "Group '$FIT_TO' not found"

        info "  Fitting to group $local_fit ($FIT_TO)"
        info "  Output group: 0 (System)"

        echo "${local_fit} 0" | "$GMX" trjconv \
            -s "$MD_TPR" \
            -f "$NO_PBC_XTC" \
            -o "$FIT_XTC" \
            -fit rot+trans \
            -quiet 2>/dev/null

        [[ -f "$FIT_XTC" ]] || error "trjconv failed to produce $FIT_XTC"
        info "  Generated: $FIT_XTC ($(du -h "$FIT_XTC" | cut -f1))"
    fi
else
    info "Stage 2: Skipping fit (not requested)"
fi

# ── Stage 3: Atom stripping (optional) ──────────────────────────────────────
if [[ -n "$KEEP" ]]; then
    # Determine input: use fitted if available, otherwise centered
    input_xtc="$NO_PBC_XTC"
    [[ -f "$FIT_XTC" ]] && input_xtc="$FIT_XTC"

    # Generate output filename from group name
    keep_lower=$(echo "$KEEP" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    STRIP_XTC="$PREP_DIR/md_${keep_lower}.xtc"
    STRIP_GRO="$PREP_DIR/md_${keep_lower}.gro"

    info "Stage 3: Keep $KEEP (strip everything else)"

    if ! skip_if_exists "$STRIP_XTC"; then
        local_keep=$(get_group_number "$KEEP" "$MD_TPR" "$INDEX_NDX") \
            || error "Group '$KEEP' not found"

        info "  Keeping group $local_keep ($KEEP)"

        echo "$local_keep" | "$GMX" trjconv \
            -s "$MD_TPR" \
            -f "$input_xtc" \
            -o "$STRIP_XTC" \
            -quiet 2>/dev/null

        [[ -f "$STRIP_XTC" ]] || error "trjconv failed to produce $STRIP_XTC"
        info "  Generated: $STRIP_XTC ($(du -h "$STRIP_XTC" | cut -f1))"
    fi

    if ! skip_if_exists "$STRIP_GRO"; then
        local_keep=$(get_group_number "$KEEP" "$MD_TPR" "$INDEX_NDX") \
            || error "Group '$KEEP' not found"

        echo "$local_keep" | "$GMX" trjconv \
            -s "$MD_TPR" \
            -f "$input_xtc" \
            -o "$STRIP_GRO" \
            -dump 0 \
            -quiet 2>/dev/null

        [[ -f "$STRIP_GRO" ]] || error "trjconv failed to produce $STRIP_GRO"
        info "  Generated: $STRIP_GRO"
    fi
else
    info "Stage 3: Skipping strip (not requested)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "=============================================="
info "Summary"
echo "=============================================="

for f in "$NO_PBC_XTC" "$NO_PBC_GRO" "$FIT_XTC" "${STRIP_XTC:-}" "${STRIP_GRO:-}"; do
    [[ -z "$f" ]] && continue
    if [[ -f "$f" ]]; then
        echo "  $(basename "$f")  ($(du -h "$f" | cut -f1))"
    fi
done

echo ""
info "Done. Output in: $PREP_DIR/"
