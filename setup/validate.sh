#!/bin/bash
set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="${1:-${PWD}}"
cd "$PROJECT_DIR"

echo "============================================"
echo "  GROMACS HPC — Validate Project"
echo "============================================"
echo ""

ERRORS=0
WARNINGS=0

check_err() { ERRORS=$((ERRORS + 1)); echo "  ❌ $1"; }
check_warn() { WARNINGS=$((WARNINGS + 1)); echo "  ⚠️  $1"; }
check_ok() { echo "  ✅ $1"; }

# ── 1. Config file ──
echo "── Configuration ──"

if [ ! -f config.sh ]; then
    check_err "config.sh not found"
    echo ""; echo "FAILED: $ERRORS errors"; exit 1
fi

source config.sh
check_ok "config.sh loaded"

# ── 2. Required variables ──
echo ""
echo "── Required Variables ──"

REQUIRED_VARS=(
    "PROJECT" "PDB" "FORCEFIELD" "WATER_MODEL"
    "BOX_TYPE" "PRODUCTION_NS" "CLUSTER"
    "EM_MDP" "NVT_MDP" "NPT_MDP" "MD_MDP"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        check_err "$var is not set"
    else
        check_ok "$var = ${!var}"
    fi
done

# ── 3. Cluster profile ──
echo ""
echo "── Cluster Profile ──"

if [ -n "${CLUSTER:-}" ]; then
    PROFILE_PATH="$PIPELINE_DIR/profiles/$CLUSTER.sh"
    if [ -f "$PROFILE_PATH" ]; then
        check_ok "Profile found: $PROFILE_PATH"
    else
        check_err "Profile not found: $PROFILE_PATH"
    fi
fi

# ── 4. Input files ──
echo ""
echo "── Input Files ──"

for fvar in PDB EM_MDP NVT_MDP NPT_MDP MD_MDP; do
    fpath="${!fvar:-}"
    if [ -z "$fpath" ]; then
        check_err "$fvar not set"
        continue
    fi
    if [ -f "$fpath" ]; then
        FSIZE=$(stat -c%s "$fpath" 2>/dev/null || stat -f%z "$fpath" 2>/dev/null)
        if [ "$FSIZE" -gt 0 ]; then
            check_ok "$fvar ($fpath, ${FSIZE} bytes)"
        else
            check_err "$fvar ($fpath) is empty"
        fi
    else
        check_err "$fvar ($fpath) not found"
    fi
done

# ── 5. Numeric parameters ──
echo ""
echo "── Simulation Parameters ──"

if [ -n "${PRODUCTION_NS:-}" ] && [ -n "${CHUNK_NS:-}" ]; then
    if [ "$PRODUCTION_NS" -ge "${CHUNK_NS:-0}" ] 2>/dev/null; then
        check_ok "PRODUCTION_NS ($PRODUCTION_NS) >= CHUNK_NS ($CHUNK_NS)"
    else
        check_err "PRODUCTION_NS ($PRODUCTION_NS) < CHUNK_NS ($CHUNK_NS)"
    fi
fi

for valname in BOX_DISTANCE SALT_CONC; do
    val="${!valname:-}"
    if [ -n "$val" ]; then
        [[ "$val" =~ ^[0-9]+\.?[0-9]*$ ]] && check_ok "$valname = $val" || check_err "$valname not a number: $val"
    fi
done

# ── 6. Walltime format ──
echo ""
echo "── Walltime Formats ──"

for wtvar in SETUP_WALLTIME EQ_WALLTIME PROD_WALLTIME; do
    wt="${!wtvar:-}"
    if [ -z "$wt" ]; then
        check_err "$wtvar not set"
    elif [[ "$wt" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        check_ok "$wtvar = $wt"
    else
        check_err "$wtvar invalid format: $wt (expected HH:MM:SS)"
    fi
done

# ── 7. Resource values ──
echo ""
echo "── Resource Settings ──"

for rvar in SETUP_CPUS EQ_CPUS EQ_GPUS PROD_CPUS PROD_GPUS; do
    val="${!rvar:-}"
    if [ -z "$val" ]; then
        check_warn "$rvar not set"
    elif [ "$val" -gt 0 ] 2>/dev/null; then
        check_ok "$rvar = $val"
    else
        check_err "$rvar invalid: $val"
    fi
done

# ── Summary ──
echo ""
echo "============================================"
echo "  Results: $ERRORS errors, $WARNINGS warnings"
echo "============================================"

[ "$ERRORS" -gt 0 ] && exit 1
