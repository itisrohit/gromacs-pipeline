#!/bin/bash
set -euo pipefail

PASS=0
FAIL=0
WARN=0

check_pass() { PASS=$((PASS + 1)); echo "  ✅ $1"; }
check_fail() { FAIL=$((FAIL + 1)); echo "  ❌ $1"; }
check_warn() { WARN=$((WARN + 1)); echo "  ⚠️  $1"; }

echo "============================================"
echo "  GROMACS HPC — Doctor"
echo "============================================"
echo ""

# ── 1. Scheduler ──
echo "── Scheduler ──"

if command -v qstat &>/dev/null; then
    check_pass "Scheduler found: PBS ($(qstat --version 2>&1 | head -1))"
elif command -v squeue &>/dev/null; then
    check_pass "Scheduler found: Slurm ($(squeue --version 2>&1 | head -1))"
elif command -v bjobs &>/dev/null; then
    check_pass "Scheduler found: LSF"
else
    check_fail "No supported scheduler found (PBS/Slurm/LSF)"
fi

echo ""
echo "── Module System ──"

if command -v module &>/dev/null; then
    check_pass "Module system available"
else
    check_warn "No module system detected"
fi

# ── 2. GROMACS ──
echo ""
echo "── GROMACS ──"

GMX_EXEC=""
for candidate in gmx_mpi gmx; do
    if command -v "$candidate" &>/dev/null; then
        GMX_EXEC="$candidate"
        break
    fi
done

if [ -n "$GMX_EXEC" ]; then
    check_pass "GROMACS found: $GMX_EXEC ($($GMX_EXEC --version 2>&1 | head -1))"
else
    check_fail "GROMACS not found. Load a GROMACS module or add it to PATH."
fi

# ── 3. Filesystem ──
echo ""
echo "── Filesystem ──"

if [ -w . ]; then
    check_pass "Project directory writable"
else
    check_fail "Project directory not writable"
fi

mkdir -p output
if [ -w output ]; then
    check_pass "Output directory writable"
    rmdir output 2>/dev/null || true
else
    check_fail "Output directory not writable"
fi

AVAIL_KB=$(df . 2>/dev/null | awk 'NR==2 {print $4}')
if [ -n "$AVAIL_KB" ] && [ "$AVAIL_KB" -gt 1048576 ]; then
    check_pass "Disk space: $((AVAIL_KB / 1048576)) GB available"
elif [ -n "$AVAIL_KB" ]; then
    check_warn "Low disk space: $((AVAIL_KB / 1048576)) GB available"
fi

# ── Summary ──
echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "============================================"

[ "$FAIL" -gt 0 ] && exit 1
