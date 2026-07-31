#!/bin/bash
set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Parse arguments: [command] [--force] [project_path] ──
CMD="${1:-submit}"
shift 1 2>/dev/null || true

FORCE=""
if [ "${1:-}" = "--force" ]; then
    FORCE="--force"
    shift 1
fi

PROJECT="${1:-${PWD}}"
PROJECT_DIR="$(cd "$PROJECT" 2>/dev/null && pwd)" || {
    echo "ERROR: Project directory not found: $PROJECT"
    exit 1
}

cd "$PROJECT_DIR"

# ── Source pipeline libraries ──
source "$PIPELINE_DIR/lib/state.sh"
source "$PIPELINE_DIR/lib/scheduler.sh"

# ── Common setup for submit/status/report ──
require_project() {
    state_require_initialized
    source "$PROJECT_DIR/config.sh"
    scheduler_init
}

# ── submit: submit all pipeline phases ──
cmd_submit() {
    require_project
    state_lock
    trap state_unlock EXIT

    if [ "$FORCE" != "--force" ]; then
        state_verify_fingerprint && echo "FINGERPRINT: match" || {
            echo "ERROR: Configuration has changed since initialization."
            echo "       Run with --force to submit anyway."
            state_unlock
            exit 1
        }
    fi

    local dep_setup=""
    local dep_eq=""

    phase_is_done() {
        local p="$1"
        case "$p" in
            setup)         [ -f "$PROJECT_DIR/output/setup/ions.gro" ] ;;
            equilibration)  [ -f "$PROJECT_DIR/output/equilibration/npt.gro" ] ;;
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
        mkdir -p "$PROJECT_DIR/scripts"
        cat > "$PROJECT_DIR/scripts/setup.sh" << SCRIPT
#!/bin/bash
set -euo pipefail
PROJECT_DIR="$PROJECT_DIR"
PIPELINE_DIR="$PIPELINE_DIR"
cd "\$PROJECT_DIR"
export GMXLIB="\$PIPELINE_DIR/forcefields"
_gmx_bin=\$(command -v gmx_mpi 2>/dev/null || command -v gmx 2>/dev/null || true)
if [ -n "\$_gmx_bin" ]; then
    _gmx_top="\$(dirname \"\$(dirname \"\$_gmx_bin\")\")/share/gromacs/top"
    [ -d "\$_gmx_top" ] && export GMXLIB="\$GMXLIB:\$_gmx_top"
fi
source "\$PROJECT_DIR/config.sh"
source "\$PIPELINE_DIR/profiles/\$CLUSTER.sh"
source "\$PIPELINE_DIR/lib/gmx.sh"
source "\$PIPELINE_DIR/lib/stages.sh"
. /etc/profile.d/modules.sh 2>/dev/null || true
for mod in "\${MODULES[@]}"; do
    module load "\$mod" 2>/dev/null || echo "WARN: module \$mod not found"
done
gmx_check
gmx_version_log
gmx_version_pin "\$GMX_VERSION"
run_stage_prepare
run_stage_topol
run_stage_box
run_stage_solvate
run_stage_ions
run_stage_index
echo "SETUP COMPLETE"
SCRIPT
        chmod +x "$PROJECT_DIR/scripts/setup.sh"

        dep_setup=$(scheduler_submit "$PROJECT_DIR/scripts/setup.sh" "$SETUP_CPUS" "0" "$SETUP_MEM" "$SETUP_WALLTIME")
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
        mkdir -p "$PROJECT_DIR/scripts"
        cat > "$PROJECT_DIR/scripts/equilibration.sh" << SCRIPT
#!/bin/bash
set -euo pipefail
PROJECT_DIR="$PROJECT_DIR"
PIPELINE_DIR="$PIPELINE_DIR"
cd "\$PROJECT_DIR"
export GMXLIB="\$PIPELINE_DIR/forcefields"
_gmx_bin=\$(command -v gmx_mpi 2>/dev/null || command -v gmx 2>/dev/null || true)
if [ -n "\$_gmx_bin" ]; then
    _gmx_top="\$(dirname \"\$(dirname \"\$_gmx_bin\")\")/share/gromacs/top"
    [ -d "\$_gmx_top" ] && export GMXLIB="\$GMXLIB:\$_gmx_top"
fi
source "\$PROJECT_DIR/config.sh"
source "\$PIPELINE_DIR/profiles/\$CLUSTER.sh"
source "\$PIPELINE_DIR/lib/gmx.sh"
source "\$PIPELINE_DIR/lib/stages.sh"
. /etc/profile.d/modules.sh 2>/dev/null || true
for mod in "\${MODULES[@]}"; do
    module load "\$mod" 2>/dev/null || echo "WARN: module \$mod not found"
done
gmx_check
gmx_version_log
gmx_version_pin "\$GMX_VERSION"
export OMP_NUM_THREADS="\${EQ_CPUS:-8}"
run_stage_em
run_stage_nvt
run_stage_npt
echo "EQUILIBRATION COMPLETE"
SCRIPT
        chmod +x "$PROJECT_DIR/scripts/equilibration.sh"

        dep_eq=$(scheduler_submit "$PROJECT_DIR/scripts/equilibration.sh" "$EQ_CPUS" "$EQ_GPUS" "$EQ_MEM" "$EQ_WALLTIME" "$dep_setup")
        state_update_phase "equilibration" "running" "$dep_eq"
    fi

    # ── Submit production chunks ──
    local prod_status
    prod_status=$(grep -o '"production": {[^}]*}' .state/workflow.json 2>/dev/null | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "pending")

    if [ "$prod_status" = "completed" ]; then
        echo "PRODUCTION: already completed"
    else
        echo "PRODUCTION: submitting chunks..."
        mkdir -p "$PROJECT_DIR/scripts"
        cat > "$PROJECT_DIR/scripts/production.sh" << SCRIPT
#!/bin/bash
set -euo pipefail
PROJECT_DIR="$PROJECT_DIR"
PIPELINE_DIR="$PIPELINE_DIR"
cd "\$PROJECT_DIR"
export GMXLIB="\$PIPELINE_DIR/forcefields"
_gmx_bin=\$(command -v gmx_mpi 2>/dev/null || command -v gmx 2>/dev/null || true)
if [ -n "\$_gmx_bin" ]; then
    _gmx_top="\$(dirname \"\$(dirname \"\$_gmx_bin\")\")/share/gromacs/top"
    [ -d "\$_gmx_top" ] && export GMXLIB="\$GMXLIB:\$_gmx_top"
fi
source "\$PROJECT_DIR/config.sh"
source "\$PIPELINE_DIR/profiles/\$CLUSTER.sh"
source "\$PIPELINE_DIR/lib/gmx.sh"
source "\$PIPELINE_DIR/lib/stages.sh"
. /etc/profile.d/modules.sh 2>/dev/null || true
for mod in "\${MODULES[@]}"; do
    module load "\$mod" 2>/dev/null || echo "WARN: module \$mod not found"
done
gmx_check
gmx_version_log
gmx_version_pin "\$GMX_VERSION"
export OMP_NUM_THREADS="\${PROD_CPUS:-8}"
run_stage_production
echo "PRODUCTION CHUNK COMPLETE"
SCRIPT
        chmod +x "$PROJECT_DIR/scripts/production.sh"

        local chunks=$((PRODUCTION_NS / CHUNK_NS))
        local prev_job="$dep_eq"

        for i in $(seq 1 "$chunks"); do
            local job_id
            job_id=$(scheduler_submit "$PROJECT_DIR/scripts/production.sh" "$PROD_CPUS" "$PROD_GPUS" "$PROD_MEM" "$PROD_WALLTIME" "$prev_job")
            state_update_production_chunk "$i" "$job_id" "running"
            prev_job="$job_id"
        done

        state_update_phase "production" "running" "$prev_job"
    fi

    echo ""
    echo "All jobs submitted."
    echo "Check status: $0 status $PROJECT_DIR"
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
        local log_file="$PROJECT_DIR/output/logs/${phase}.o${jid}"

        local walltime=""
        if [ -f "$log_file" ]; then
            walltime=$(grep -oP 'Walltime: \K[\d:]+' "$log_file" 2>/dev/null || grep -oP 'Time: \K[\d:]+' "$log_file" 2>/dev/null || echo "unknown")
        fi

        printf "  %-15s %-10s %-20s %s\n" "$phase" "$status" "$jid" "${walltime:-}"
    done

    echo ""
    echo "  Logs: $PROJECT_DIR/output/logs/"
    echo "  Report generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

# ── Main dispatch ──
case "$CMD" in
    submit)
        cmd_submit
        ;;
    status)
        cmd_status
        ;;
    report)
        cmd_report
        ;;
    *)
        echo "Usage: $0 {submit|status|report} [--force] [project_path]"
        echo ""
        echo "  submit [--force] [path]   Submit all pipeline jobs"
        echo "  status [path]            Check job status"
        echo "  report [path]            Generate completion report"
        echo ""
        echo "  project_path defaults to current directory"
        exit 1
        ;;
esac
