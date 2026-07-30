#!/bin/bash
set -euo pipefail

STATE_FILE=".state/workflow.json"
LOCK_FILE=".state/lock"

# ── Acquire exclusive lock ──
state_lock() {
    mkdir -p .state
    # Use mkdir as a portable POSIX lock (atomic directory creation)
    if ! mkdir "$LOCK_FILE.lock" 2>/dev/null; then
        echo "ERROR: Project is locked by another run.sh process."
        echo "       If this is incorrect, remove: .state/lock.lock"
        exit 1
    fi
    # Store PID for cleanup
    echo "$$" > "$LOCK_FILE.lock/pid"
}

# ── Release lock ──
state_unlock() {
    rm -rf "$LOCK_FILE.lock" 2>/dev/null || true
}

# ── Verify project is initialized ──
state_require_initialized() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "ERROR: Project not initialized."
        echo "       Run: setup/init.sh <project_name>"
        exit 1
    fi
}

# ── Update a phase in workflow.json ──
state_update_phase() {
    local phase="$1"
    local status="$2"
    local job_id="$3"

    local tmp
    tmp=$(mktemp "$STATE_FILE.XXXXXX")

    # Replace the phase object: known JSON structure, targeted sed
    sed "s/\"$phase\": {[^}]*}/\"$phase\": {\"status\": \"$status\", \"job_id\": \"$job_id\"}/" \
        "$STATE_FILE" > "$tmp"

    mv "$tmp" "$STATE_FILE"
}

# ── Record a production chunk ──
state_update_production_chunk() {
    local index="$1"
    local job_id="$2"
    local status="$3"

    local tmp
    tmp=$(mktemp "$STATE_FILE.XXXXXX")

    # Append chunk before the closing ] of the runs array, or create runs array
    if grep -q '"runs"' "$STATE_FILE" 2>/dev/null; then
        # Insert before closing bracket of production phase
        sed "/\"production\"/,/production/ s/\"runs\": \[/\"runs\": [{\"index\": $index, \"job_id\": \"$job_id\", \"status\": \"$status\"},/" \
            "$STATE_FILE" > "$tmp"
    else
        # No runs array yet: add one
        sed "s/\"production\": {[^}]*}/\"production\": {\"status\": \"running\", \"runs\": [{\"index\": $index, \"job_id\": \"$job_id\", \"status\": \"$status\"}]}/" \
            "$STATE_FILE" > "$tmp"
    fi

    mv "$tmp" "$STATE_FILE"
}

# ── Compare fingerprint ──
# Calls setup/fingerprint.sh --check which computes and prints
# the current fingerprint WITHOUT modifying .state/fingerprint.
# The stored fingerprint is only written during initialization
# (setup/fingerprint.sh) or explicit reinitialization.
state_verify_fingerprint() {
    if [ ! -f ".state/fingerprint" ]; then
        return 2
    fi
    local previous
    previous=$(cat ".state/fingerprint")

    local current
    current=$(bash setup/fingerprint.sh --check 2>/dev/null || echo "")

    if [ -z "$current" ]; then
        return 2
    fi
    if [ "$previous" = "$current" ]; then
        return 0
    fi
    return 1
}

# ── Mark a phase completed based on output file evidence ──
# Called by cmd_submit when state says "running" but output files
# indicate the phase is actually done. This prevents unnecessary
# resubmission of completed work.
state_mark_completed() {
    local phase="$1"
    local tmp
    tmp=$(mktemp "$STATE_FILE.XXXXXX")
    local jid
    jid=$(grep -o "\"$phase\": {[^}]*}" "$STATE_FILE" 2>/dev/null | grep -o '"job_id": "[^"]*"' | cut -d'"' -f4)
    sed "s/\"$phase\": {[^}]*}/\"$phase\": {\"status\": \"completed\", \"job_id\": \"$jid\"}/" \
        "$STATE_FILE" > "$tmp"
    mv "$tmp" "$STATE_FILE"
}

# ── List active job IDs ──
state_active_jobs() {
    if [ ! -f "$STATE_FILE" ]; then
        return
    fi

    # Extract job_id values where status is not "completed" and not null
    grep -o '"job_id": "[^"]*"' "$STATE_FILE" | \
        grep -v 'null' | \
        while IFS= read -r line; do
            local jid
            jid=$(echo "$line" | sed 's/.*: "\(.*\)"/\1/')
            [ -n "$jid" ] && echo "$jid"
        done
}
