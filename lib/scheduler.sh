#!/bin/bash
set -euo pipefail

# ── Source and validate the active cluster profile ──
scheduler_init() {
    local profile="$PIPELINE_DIR/profiles/$CLUSTER.sh"
    if [ ! -f "$profile" ]; then
        echo "ERROR: Cluster profile not found: $profile"
        echo "       Set CLUSTER in config.sh to one of:"
        ls "$PIPELINE_DIR/profiles/"*.sh 2>/dev/null | sed 's/.*\///; s/\.sh$//' | sed 's/^/       - /'
        exit 1
    fi

    source "$profile"

    local required_vars=("SUBMIT_CMD" "SELECT_CPU" "SELECT_GPU" "WORKDIR_VAR")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            echo "ERROR: Cluster profile $profile is missing required variable: $var"
            exit 1
        fi
    done
}

# ── Replace %TOKEN% placeholders with actual values ──
scheduler_replace_tokens() {
    local input="$1"
    local cpus="$2"
    local gpus="$3"
    local mem="$4"
    local walltime="$5"
    local name="$6"
    local dependency="${7:-}"

    local result="$input"
    result="${result//%CPUS%/$cpus}"
    result="${result//%GPUS%/$gpus}"
    result="${result//%MEMORY%/$mem}"
    result="${result//%WALLTIME%/$walltime}"
    result="${result//%NAME%/$name}"
    result="${result//%ACCOUNT%/$ACCOUNT}"
    result="${result//%QUEUE%/$QUEUE}"

    echo "$result"
}

# ── Submit a job and return job ID ──
scheduler_submit() {
    local script="$1"
    local cpus="$2"
    local gpus="$3"
    local mem="$4"
    local walltime="$5"
    local dependency="${6:-}"
    local name
    name=$(basename "$script" .sh)

    local select_flag
    if [ "${gpus:-0}" -gt 0 ]; then
        select_flag=$(scheduler_replace_tokens "$SELECT_GPU" "$cpus" "$gpus" "$mem" "$walltime" "$name")
    else
        select_flag=$(scheduler_replace_tokens "$SELECT_CPU" "$cpus" "$gpus" "$mem" "$walltime" "$name")
    fi

    local walltime_flag
    walltime_flag=$(scheduler_replace_tokens "$SUBMIT_WALLTIME" "$cpus" "$gpus" "$mem" "$walltime" "$name")

    local output_flag
    output_flag=$(scheduler_replace_tokens "$SUBMIT_OUTPUT" "$cpus" "$gpus" "$mem" "$walltime" "$name")
    local output_val="${output_flag##* }"

    local account_flag
    account_flag=$(scheduler_replace_tokens "$SUBMIT_ACCOUNT" "$cpus" "$gpus" "$mem" "$walltime" "$name")

    local queue_flag
    queue_flag=$(scheduler_replace_tokens "$SUBMIT_QUEUE" "$cpus" "$gpus" "$mem" "$walltime" "$name")

    local cmd="$SUBMIT_CMD $account_flag $queue_flag $select_flag $walltime_flag $output_flag"

    if [ -n "$dependency" ]; then
        local dep_flag
        dep_flag=$(scheduler_replace_tokens "$SUBMIT_DEPENDENCY" "$cpus" "$gpus" "$mem" "$walltime" "$name" "$dependency")
        dep_flag="${dep_flag//%JOBID%/$dependency}"
        cmd="$cmd $dep_flag"
    fi

    cmd="$cmd $script"

    echo "  Submitting: $SUBMIT_CMD $name" >&2
    $cmd
}

# ── Check job status ──
scheduler_status() {
    local job_id="$1"
    if [ -z "$job_id" ] || [ "$job_id" = "null" ]; then
        echo "unknown"
        return
    fi

    case "$SCHEDULER" in
        pbs)
            local state
            state=$(qstat -xf "$job_id" 2>/dev/null | grep job_state | awk '{print $3}' | tr -d ' ')
            case "$state" in
                Q|H|W) echo "queued" ;;
                R)     echo "running" ;;
                F)     echo "done" ;;
                "")    echo "unknown" ;;
                *)     echo "failed" ;;
            esac
            ;;
        slurm)
            local state
            state=$(sacct -j "$job_id" --format=State --noheader 2>/dev/null | head -1 | tr -d ' ')
            case "$state" in
                PENDING|CONFIGURING) echo "queued" ;;
                RUNNING)             echo "running" ;;
                COMPLETED)           echo "done" ;;
                "")                  echo "unknown" ;;
                *)                   echo "failed" ;;
            esac
            ;;
        lsf)
            local state
            state=$(bjobs -noheader -o stat "$job_id" 2>/dev/null | tr -d ' ')
            case "$state" in
                PEND|PSUSP|WAIT) echo "queued" ;;
                RUN|USUSP|SSUSP) echo "running" ;;
                DONE)            echo "done" ;;
                "")              echo "unknown" ;;
                *)               echo "failed" ;;
            esac
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ── Cancel a job ──
scheduler_cancel() {
    local job_id="$1"
    case "$SCHEDULER" in
        pbs)   qdel "$job_id" 2>/dev/null || true ;;
        slurm) scancel "$job_id" 2>/dev/null || true ;;
        lsf)   bkill "$job_id" 2>/dev/null || true ;;
    esac
}
