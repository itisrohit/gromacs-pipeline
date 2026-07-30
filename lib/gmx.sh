#!/bin/bash
set -euo pipefail

GMX=""
GMX_VERSION=""

# ── Find GROMACS executable ──
gmx_check() {
    for candidate in gmx_mpi gmx; do
        if command -v "$candidate" &>/dev/null; then
            GMX="$candidate"
            GMX_VERSION=$("$GMX" --version 2>&1 | head -1)
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
        echo "WARNING: Could not parse GROMACS version from: $GMX_VERSION"
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
