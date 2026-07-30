#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# ── Commands ──
CMD="${1:-submit}"

# ── Source runtime libraries ──
source lib/state.sh
source lib/scheduler.sh

# ── Common setup for submit/status/report ──
require_project() {
    state_require_initialized
    source config.sh
    scheduler_init
}

# ── submit: submit all pipeline phases ──
cmd_submit() {
    local force="${1:-}"
    require_project
    state_lock
    trap state_unlock EXIT

    if [ "$force" != "--force" ]; then
        state_verify_fingerprint && echo "FINGERPRINT: match" || {
            echo "ERROR: Configuration has changed since initialization."
            echo "       Run with --force to submit anyway."
            state_unlock
            exit 1
        }
    fi

    local dep_setup=""
    local dep_eq=""

    # ── Helper: check if a phase is complete by output files ──
    # Used when state says "running" but outputs exist (previous run
    # completed without updating state). This avoids no-op resubmissions.
    phase_is_done() {
        local p="$1"
        case "$p" in
            # Setup completes when the last stage (index) produces its output.
            # All prior stages must succeed first, so ions.gro is a reliable
            # sentinel — it is only written after prepare → topol → box →
            # solvate → ions all complete successfully.
            setup)         [ -f "output/setup/ions.gro" ] ;;
            # Equilibration completes when the last stage (NPT) produces its
            # output. The EM stage separately verifies log-based convergence
            # before allowing NVT to proceed. NPT.gro is only written after
            # EM → NVT → NPT all succeed.
            equilibration)  [ -f "output/equilibration/npt.gro" ] ;;
            # Production is excluded from file-based detection because md.xtc
            # exists after the first frame — its mere presence does not
            # indicate completion of the full trajectory. Production state
            # is tracked by the workflow.json runs array and scheduler
            # job status. The user runs `run.sh status` to sync state.
            production)     return 1 ;;
            *)             return 1 ;;
        esac
    }

    # ── Submit setup ──
    local setup_status
    setup_status=$(grep -o '"setup": {[^}]*}' .state/workflow.json 2>/dev/null | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "pending")

    if [ "$setup_status" = "completed" ]; then
        echo "SETUP: already completed"
        dep_setup=$(grep -o '"setup": {[^}]*}' .state/workflow.json | grep -o '"job_id": "[^"]*"' | cut -d'"' -f4)
    elif [ "$setup_status" = "running" ] && phase_is_done "setup"; then
        echo "SETUP: outputs found, marking completed"
        state_mark_completed "setup"
        dep_setup=$(grep -o '"setup": {[^}]*}' .state/workflow.json | grep -o '"job_id": "[^"]*"' | cut -d'"' -f4)
    else
        echo "SETUP: submitting..."
        # Generate job script
        mkdir -p scripts
        cat > scripts/setup.sh << 'SCRIPT'
#!/bin/bash
set -euo pipefail
source config.sh
source profiles/$CLUSTER.sh
source lib/gmx.sh
source lib/stages.sh
. /etc/profile.d/modules.sh 2>/dev/null || true
for mod in "${MODULES[@]}"; do
    module load "$mod" 2>/dev/null || echo "WARN: module $mod not found"
done
gmx_check
gmx_version_log
gmx_version_pin "$GMX_VERSION"
run_stage_prepare
run_stage_topol
run_stage_box
run_stage_solvate
run_stage_ions
run_stage_index
echo "SETUP COMPLETE"
SCRIPT
        chmod +x scripts/setup.sh

        dep_setup=$(scheduler_submit "scripts/setup.sh" "$SETUP_CPUS" "0" "$SETUP_MEM" "$SETUP_WALLTIME")
        state_update_phase "setup" "running" "$dep_setup"
    fi

    # ── Submit equilibration ──
    local eq_status
    eq_status=$(grep -o '"equilibration": {[^}]*}' .state/workflow.json 2>/dev/null | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "pending")

    if [ "$eq_status" = "completed" ]; then
        echo "EQUILIBRATION: already completed"
        dep_eq=$(grep -o '"equilibration": {[^}]*}' .state/workflow.json | grep -o '"job_id": "[^"]*"' | cut -d'"' -f4)
    elif [ "$eq_status" = "running" ] && phase_is_done "equilibration"; then
        echo "EQUILIBRATION: outputs found, marking completed"
        state_mark_completed "equilibration"
        dep_eq=$(grep -o '"equilibration": {[^}]*}' .state/workflow.json | grep -o '"job_id": "[^"]*"' | cut -d'"' -f4)
    else
        echo "EQUILIBRATION: submitting..."
        mkdir -p scripts
        cat > scripts/equilibration.sh << 'SCRIPT'
#!/bin/bash
set -euo pipefail
source config.sh
source profiles/$CLUSTER.sh
source lib/gmx.sh
source lib/stages.sh
. /etc/profile.d/modules.sh 2>/dev/null || true
for mod in "${MODULES[@]}"; do
    module load "$mod" 2>/dev/null || echo "WARN: module $mod not found"
done
gmx_check
gmx_version_log
gmx_version_pin "$GMX_VERSION"
export OMP_NUM_THREADS="${EQ_CPUS:-8}"
run_stage_em
run_stage_nvt
run_stage_npt
echo "EQUILIBRATION COMPLETE"
SCRIPT
        chmod +x scripts/equilibration.sh

        dep_eq=$(scheduler_submit "scripts/equilibration.sh" "$EQ_CPUS" "$EQ_GPUS" "$EQ_MEM" "$EQ_WALLTIME" "$dep_setup")
        state_update_phase "equilibration" "running" "$dep_eq"
    fi

    # ── Submit production chunks ──
    local prod_status
    prod_status=$(grep -o '"production": {[^}]*}' .state/workflow.json 2>/dev/null | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "pending")

    if [ "$prod_status" = "completed" ]; then
        echo "PRODUCTION: already completed"
    else
        echo "PRODUCTION: submitting chunks..."
        mkdir -p scripts
        cat > scripts/production.sh << 'SCRIPT'
#!/bin/bash
set -euo pipefail
source config.sh
source profiles/$CLUSTER.sh
source lib/gmx.sh
source lib/stages.sh
. /etc/profile.d/modules.sh 2>/dev/null || true
for mod in "${MODULES[@]}"; do
    module load "$mod" 2>/dev/null || echo "WARN: module $mod not found"
done
gmx_check
gmx_version_log
gmx_version_pin "$GMX_VERSION"
export OMP_NUM_THREADS="${PROD_CPUS:-8}"
run_stage_production
echo "PRODUCTION CHUNK COMPLETE"
SCRIPT
        chmod +x scripts/production.sh

        local chunks=$((PRODUCTION_NS / CHUNK_NS))
        local prev_job="$dep_eq"

        for i in $(seq 1 "$chunks"); do
            local job_id
            job_id=$(scheduler_submit "scripts/production.sh" "$PROD_CPUS" "$PROD_GPUS" "$PROD_MEM" "$PROD_WALLTIME" "$prev_job")
            state_update_production_chunk "$i" "$job_id" "running"
            prev_job="$job_id"
        done

        state_update_phase "production" "running" "$prev_job"
    fi

    echo ""
    echo "All jobs submitted."
    echo "Check status: ./run.sh status"
}

# ── status: check job status ──
cmd_status() {
    require_project

    echo "============================================"
    echo "  Project: $PROJECT"
    echo "============================================"

    for phase in setup equilibration production; do
        local status
        status=$(grep -o "\"$phase\": {[^}]*}" .state/workflow.json 2>/dev/null | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "unknown")
        local jid
        jid=$(grep -o "\"$phase\": {[^}]*}" .state/workflow.json 2>/dev/null | grep -o '"job_id": "[^"]*"' | cut -d'"' -f4 || echo "-")

        local sched_status=""
        if [ -n "$jid" ] && [ "$jid" != "-" ] && [ "$jid" != "null" ]; then
            sched_status=$(scheduler_status "$jid" 2>/dev/null || echo "unknown")
        fi

        echo "  $phase: $status (job: $jid, scheduler: $sched_status)"
    done
}

# ── report: generate completion report ──
cmd_report() {
    require_project

    echo "============================================"
    echo "  GROMACS HPC — Report"
    echo "  Project: $PROJECT"
    echo "============================================"
    echo ""

    for phase in setup equilibration production; do
        local status
        status=$(grep -o "\"$phase\": {[^}]*}" .state/workflow.json 2>/dev/null | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "unknown")
        local jid
        jid=$(grep -o "\"$phase\": {[^}]*}" .state/workflow.json 2>/dev/null | grep -o '"job_id": "[^"]*"' | cut -d'"' -f4 || echo "-")
        local log_file="output/logs/${phase}.o${jid}"

        local walltime=""
        if [ -f "$log_file" ]; then
            walltime=$(grep -oP 'Walltime: \K[\d:]+' "$log_file" 2>/dev/null || grep -oP 'Time: \K[\d:]+' "$log_file" 2>/dev/null || echo "unknown")
        fi

        printf "  %-15s %-10s %-20s %s\n" "$phase" "$status" "$jid" "${walltime:-}"
    done

    echo ""
    echo "  Logs: output/logs/"
    echo "  Report generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

# ── Main dispatch ──
case "$CMD" in
    submit)
        cmd_submit "${2:-}"
        ;;
    status)
        cmd_status
        ;;
    report)
        cmd_report
        ;;
    --force)
        cmd_submit "--force"
        ;;
    *)
        echo "Usage: $0 {submit|status|report|--force}"
        exit 1
        ;;
esac
