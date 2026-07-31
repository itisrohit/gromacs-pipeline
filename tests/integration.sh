#!/bin/bash
# tests/integration.sh — integration tests for production loop
# Run from repo root: bash gromacs-pipeline/tests/integration.sh
set +euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PIPELINE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the library
. "$PIPELINE_DIR/lib/gmx.sh"
. "$PIPELINE_DIR/lib/stages.sh"
set +euo pipefail  # re-source re-enables; disable for tests

PASS=0 FAIL=0
ok()   { PASS=$((PASS+1)); echo "  OK: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

echo "=== Integration tests: production loop ==="

# ── Helper: set up a fake project directory ──
setup_project() {
    local proj="$1" prod_ns="$2" chunk_ns="$3" walltime="${4:-24:00:00}"
    rm -rf "$proj"
    mkdir -p "$proj"/{output/{production,equilibration},mdp,.state}
    cat > "$proj/config.sh" << EOF
PRODUCTION_NS=$prod_ns
CHUNK_NS=$chunk_ns
PROD_WALLTIME="$walltime"
EOF
    # Fake mdp with dt
    echo "dt = 0.002" > "$proj/mdp/md.mdp"
    # Fake npt.gro (grompp target)
    touch "$proj/output/equilibration/npt.gro"
    # Create initial md.tpr (infinite / nsteps=-1)
    echo "target = -1" > "$proj/output/production/md.tpr"
    # Source config
    PRODUCTION_NS="$prod_ns"
    CHUNK_NS="$chunk_ns"
    PROD_WALLTIME="$walltime"
    MD_MDP="$proj/mdp/md.mdp"
    GMX="$SCRIPT_DIR/bin/fake_gmx"
    GMX_VERSION=2023.2
}

teardown_project() { rm -rf "$1"; }

# ══════════════════════════════════════════════════════════════
# TEST 1: Fresh production completes in one job
# ══════════════════════════════════════════════════════════════
echo ""
echo "TEST 1: fresh production completes in one job"
setup_project /tmp/prod_test1 0.5 0.1
cd /tmp/prod_test1
unset FAKE_WALL_CAP_PS FAKE_ZERO FAKE_FAIL
FAKE_PROGRESS_PS=20000 run_stage_production
t=$(checkpoint_time_ps output/production/md.cpt)
[ -f output/production/PRODUCTION_COMPLETE ] && ok "marker exists" || fail "marker missing"
time_gte "$t" "500.0" && ok "t=$t >= 500 ps" || fail "t=$t < 500"
cd /tmp
teardown_project /tmp/prod_test1

# ══════════════════════════════════════════════════════════════
# TEST 2: Walltime interruption + resume
# ══════════════════════════════════════════════════════════════
echo ""
echo "TEST 2: walltime interruption + resume"
setup_project /tmp/prod_test2 0.5 0.1
cd /tmp/prod_test2
FAKE_WALL_CAP_PS=60 FAKE_PROGRESS_PS=20000 run_stage_production
t1=$(checkpoint_time_ps output/production/md.cpt)
[ -f output/production/PRODUCTION_COMPLETE ] && { fail "should not be complete"; } || ok "not complete yet"
FAKE_WALL_CAP_PS=60 FAKE_PROGRESS_PS=20000 run_stage_production
t2=$(checkpoint_time_ps output/production/md.cpt)
awk -v a="$t2" -v b="$t1" 'BEGIN{exit !(a>b)}' && ok "time advanced: $t1 -> $t2" || fail "no advance: $t1 -> $t2"
FAKE_WALL_CAP_PS=60 FAKE_PROGRESS_PS=20000 run_stage_production
FAKE_WALL_CAP_PS=60 FAKE_PROGRESS_PS=20000 run_stage_production
FAKE_WALL_CAP_PS=60 FAKE_PROGRESS_PS=20000 run_stage_production
FAKE_WALL_CAP_PS=60 FAKE_PROGRESS_PS=20000 run_stage_production
FAKE_WALL_CAP_PS=60 FAKE_PROGRESS_PS=20000 run_stage_production
FAKE_WALL_CAP_PS=60 FAKE_PROGRESS_PS=20000 run_stage_production
FAKE_WALL_CAP_PS=60 FAKE_PROGRESS_PS=20000 run_stage_production
tfinal=$(checkpoint_time_ps output/production/md.cpt)
[ -f output/production/PRODUCTION_COMPLETE ] && ok "eventually completed" || fail "did not complete (t=$tfinal)"
time_gte "$tfinal" "500.0" && ok "final t=$tfinal >= 500" || fail "final t=$tfinal"
cd /tmp
teardown_project /tmp/prod_test2

# ══════════════════════════════════════════════════════════════
# TEST 3: Completion at exactly PRODUCTION_NS
# ══════════════════════════════════════════════════════════════
echo ""
echo "TEST 3: exact completion at PRODUCTION_NS"
setup_project /tmp/prod_test3 0.5 0.5
cd /tmp/prod_test3
# progress = 500 ps = exactly PRODUCTION_NS
FAKE_PROGRESS_PS=500 FAKE_WALL_CAP_PS=500 run_stage_production
t=$(checkpoint_time_ps output/production/md.cpt)
[ -f output/production/PRODUCTION_COMPLETE ] && ok "marker exists" || fail "marker missing"
time_gte "$t" "500.0" && ok "t=$t >= 500" || fail "t=$t"
cd /tmp
teardown_project /tmp/prod_test3

# ══════════════════════════════════════════════════════════════
# TEST 4: Missing checkpoint (fresh start from t=0)
# ══════════════════════════════════════════════════════════════
echo ""
echo "TEST 4: fresh start with no checkpoint"
setup_project /tmp/prod_test4 0.5 0.1
cd /tmp/prod_test4
rm -f output/production/md.cpt
FAKE_PROGRESS_PS=20000 run_stage_production
t=$(checkpoint_time_ps output/production/md.cpt)
awk -v a="$t" -v b="0" 'BEGIN{exit !(a>b)}' && ok "started from t=0, now $t" || fail "t=$t"
cd /tmp
teardown_project /tmp/prod_test4

# ══════════════════════════════════════════════════════════════
# TEST 5: Missing checkpoint mid-run (data loss guard)
# ══════════════════════════════════════════════════════════════
echo ""
echo "TEST 5: missing checkpoint mid-run (fatal)"
setup_project /tmp/prod_test5 0.5 0.1
cd /tmp/prod_test5
# Create fake xtc (mid-run trajectory exists)
touch output/production/md.xtc
# Delete checkpoint
rm -f output/production/md.cpt
if run_stage_production 2>/dev/null; then
    fail "should fail when checkpoint missing but xtc exists"
else
    ok "fatally exits when checkpoint lost mid-run"
fi
cd /tmp
teardown_project /tmp/prod_test5

# ══════════════════════════════════════════════════════════════
# TEST 6: Corrupt checkpoint (fatal)
# ══════════════════════════════════════════════════════════════
echo ""
echo "TEST 6: corrupt checkpoint (fatal)"
setup_project /tmp/prod_test6 0.5 0.1
cd /tmp/prod_test6
echo "CORRUPT" > output/production/md.cpt
if run_stage_production 2>/dev/null; then
    fail "should fail with corrupt checkpoint"
else
    ok "fatally exits with corrupt checkpoint"
fi
cd /tmp
teardown_project /tmp/prod_test6

# ══════════════════════════════════════════════════════════════
# TEST 7: Zero-progress detection (fatal)
# ══════════════════════════════════════════════════════════════
echo ""
echo "TEST 7: zero-progress detection (fatal)"
setup_project /tmp/prod_test7 0.5 0.1
cd /tmp/prod_test7
FAKE_ZERO=1 FAKE_PROGRESS_PS=20000 run_stage_production
if run_stage_production 2>/dev/null; then
    fail "should fail on zero progress"
else
    ok "fatally exits on zero progress"
fi
cd /tmp
teardown_project /tmp/prod_test7

# ══════════════════════════════════════════════════════════════
# TEST 8: Idempotency — re-run after completion
# ══════════════════════════════════════════════════════════════
echo ""
echo "TEST 8: re-run after completion is idempotent"
setup_project /tmp/prod_test8 0.5 0.1
cd /tmp/prod_test8
FAKE_PROGRESS_PS=20000 run_stage_production
t1=$(checkpoint_time_ps output/production/md.cpt)
FAKE_PROGRESS_PS=20000 run_stage_production
t2=$(checkpoint_time_ps output/production/md.cpt)
[ "$t1" = "$t2" ] && ok "time unchanged: $t1" || fail "time changed: $t1 -> $t2"
[ -f output/production/PRODUCTION_COMPLETE ] && ok "marker still present" || fail "marker gone"
cd /tmp
teardown_project /tmp/prod_test8

# ══════════════════════════════════════════════════════════════
# TEST 9: Chunk smaller than PRODUCTION_NS (multiple chunks)
# ══════════════════════════════════════════════════════════════
echo ""
echo "TEST 9: multiple chunks complete correctly"
setup_project /tmp/prod_test9 0.5 0.1
cd /tmp/prod_test9
# progress=100 ps = exactly 1 chunk; no wall cap
FAKE_PROGRESS_PS=100 FAKE_WALL_CAP_PS=100 run_stage_production
t=$(checkpoint_time_ps output/production/md.cpt)
[ -f output/production/PRODUCTION_COMPLETE ] && ok "completed after 5 chunks" || fail "not complete"
time_gte "$t" "500.0" && ok "t=$t >= 500" || fail "t=$t"
cd /tmp
teardown_project /tmp/prod_test9

# ══════════════════════════════════════════════════════════════
# TEST 9: Non-divisible production length (5 ns / 2 ns chunks)
# Expected targets: 2 → 4 → 5 (NOT 2 → 4 → 6)
# ══════════════════════════════════════════════════════════════
echo ""
echo "TEST 9: non-divisible production length (5 ns / 2 ns chunks)"
setup_project /tmp/prod_test9b 5 2
cd /tmp/prod_test9b
# Each chunk: progress = 2000 ps = exactly CHUNK_NS, no wall cap
FAKE_PROGRESS_PS=2000 run_stage_production
# Should have 3 chunks: 0→2000, 2000→4000, 4000→5000
# Final time must be exactly 5000 ps (not 6000)
t=$(checkpoint_time_ps output/production/md.cpt)
[ -f output/production/PRODUCTION_COMPLETE ] && ok "completed" || fail "not complete"
# t should be 5000.0 (capped by min(t+chunk, PRODUCTION_NS))
awk -v t="$t" 'BEGIN{exit !(t==5000.0)}' && ok "final t=$t == 5000 (capped at PRODUCTION_NS)" || fail "final t=$t (expected 5000)"
cd /tmp
teardown_project /tmp/prod_test9b

# ══════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
