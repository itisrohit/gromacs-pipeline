#!/bin/bash
set -euo pipefail

GMX=""
GMX_VERSION=""

# ── Find GROMACS executable ──
gmx_check() {
    for candidate in gmx_mpi gmx; do
        if command -v "$candidate" &>/dev/null; then
            GMX="$candidate"
            # Extract only the version number. Some clusters emit MPI
            # warnings on stderr before the version banner, so filter
            # for the actual version pattern instead of taking head -1.
            GMX_VERSION=$("$GMX" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
            return 0
        fi
    done
    echo "ERROR: GROMACS not found. Load a GROMACS module or add it to PATH."
    echo "       Tried: gmx_mpi gmx"
    exit 1
}

# ── Log GROMACS version ──
gmx_version_log() {
    echo "GROMACS: $GMX ($GMX_VERSION)"
}

# ── Compare installed version against minimum ──
# Usage: gmx_version_gte MAJOR MINOR
# Example: gmx_version_gte 2021 0  → true for 2023.2
gmx_version_gte() {
    local req_major="$1"
    local req_minor="${2:-0}"

    local version_str
    version_str=$(echo "$GMX_VERSION" | grep -oE '^[0-9]+\.[0-9]+' | head -1)

    if [ -z "$version_str" ]; then
        echo "WARNING: Could not parse GROMACS version from: $GMX_VERSION" >&2
        return 1
    fi

    local maj="${version_str%%.*}"
    local min="${version_str#*.}"

    if [ "$maj" -gt "$req_major" ] 2>/dev/null; then
        return 0
    fi
    if [ "$maj" -eq "$req_major" ] 2>/dev/null && [ "$min" -ge "$req_minor" ] 2>/dev/null; then
        return 0
    fi
    return 1
}

# ── Echo GPU flags for mdrun ──
# Includes -update gpu only for GROMACS >= 2021
gmx_gpu_flags() {
    local flags="-nb gpu -pme gpu -bonded gpu"
    if gmx_version_gte 2021 0; then
        flags="$flags -update gpu"
    fi
    echo "$flags"
}

# ── Read simulation time (ps) from a GROMACS checkpoint ──
# Uses gmx dump -cp (stable key=value stdout) as primary method;
# falls back to gmx check (stderr, human-readable) if dump fails.
# Cross-validates t ≈ step × dt to detect corrupt/partial checkpoints.
# Returns 0 if checkpoint doesn't exist (outputs "0" for convenience).
# Usage: t=$(checkpoint_time_ps md.cpt 0.002)
checkpoint_time_ps() {
    local cpt="$1" dt="${2:-0.002}"
    [ -f "$cpt" ] || { echo "0"; return 0; }

    local t step
    t=$("$GMX" dump -cp "$cpt" 2>/dev/null | awk '/^t = /{print $3; exit}')
    step=$("$GMX" dump -cp "$cpt" 2>/dev/null | awk '/^step = /{print $3; exit}')

    # Fallback: gmx check prints "Last frame ... time X" to stderr
    if [ -z "$t" ]; then
        t=$("$GMX" check -f "$cpt" 2>&1 | awk '/Last frame/{print $NF; exit}')
    fi

    if [ -z "$t" ] || ! printf '%s' "$t" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
        echo "ERROR: cannot parse time from checkpoint $cpt" >&2
        return 1
    fi

    # Cross-check: t ≈ step × dt (within 0.5 ps)
    if [ -n "$step" ] && printf '%s' "$step" | grep -qE '^[0-9]+$'; then
        if ! awk -v t="$t" -v s="$step" -v d="$dt" \
            'BEGIN{d=s*d; exit !(d>=t-0.5 && d<=t+0.5)}'; then
            echo "ERROR: checkpoint $cpt inconsistent (t=$t ps, step=$step, dt=$dt)" >&2
            return 1
        fi
    fi

    echo "$t"
}

# ── Parse dt from an MDP file ──
production_dt() {
    local mdp="${MD_MDP:-mdp/md.mdp}"
    local dt
    dt=$(awk '/^dt[[:space:]]*=/{print $3; exit}' "$mdp" 2>/dev/null)
    [ -n "$dt" ] && echo "$dt" || echo "0.002"
}

# ── Float comparisons for simulation times ──
time_gte() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>=b)}'; }
time_gt()  { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>b)}'; }
time_lt()  { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a<b)}'; }
time_lte() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a<=b)}'; }

# ── Print the minimum of two floats ──
time_min() { awk -v a="$1" -v b="$2" 'BEGIN{if(a<b) print a; else print b}'; }

# ── Convert HH:MM:SS walltime to seconds ──
walltime_to_seconds() { echo "$1" | awk -F: '{print ($1*3600)+($2*60)+$3}'; }

# ── Verify GROMACS version matches profile pin ──
gmx_version_pin() {
    local expected="$1"
    if [ -z "$expected" ]; then
        return 0
    fi
    if echo "$GMX_VERSION" | grep -q "$expected"; then
        return 0
    fi
    echo "ERROR: Expected GROMACS $expected but found: $GMX_VERSION"
    echo "       Update the GMX_VERSION in your cluster profile,"
    echo "       or load a different GROMACS module."
    exit 1
}
