#!/bin/bash
set -euo pipefail

STATE_FILE=".state/workflow.json"

# ── Generate completion report ──
report_generate() {
    echo "============================================"
    echo "  GROMACS HPC — Workflow Complete"
    echo "============================================"
    echo ""

    local project
    project=$(grep -o '"project": "[^"]*"' "$STATE_FILE" 2>/dev/null | head -1 | cut -d'"' -f4 || echo "unknown")

    echo "  Project: $project"
    echo ""

    for phase in setup equilibration production; do
        local status jid
        status=$(grep -o "\"$phase\": {[^}]*}" "$STATE_FILE" 2>/dev/null | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "unknown")
        jid=$(grep -o "\"$phase\": {[^}]*}" "$STATE_FILE" 2>/dev/null | grep -o '"job_id": "[^"]*"' | cut -d'"' -f4 || echo "-")

        local log_file="output/logs/${phase}.o${jid}"
        local runtime=""
        if [ -f "$log_file" ]; then
            runtime=$(grep -m1 -oP 'Walltime:\s+\K[\d:]+' "$log_file" 2>/dev/null || grep -m1 -oP 'Time:\s+\K[\d:]+' "$log_file" 2>/dev/null || echo "unknown")
        fi

        printf "  %-15s %-10s %-20s %s\n" "$phase" "${status^^}" "${jid:-}" "${runtime:-}"
    done

    echo ""
    echo "  Outputs: output/"
    echo "  Logs: output/logs/"

    # Count production chunks
    local chunk_count
    chunk_count=$(grep -o '"index": [0-9]*' "$STATE_FILE" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$chunk_count" -gt 0 ]; then
        echo "  Production chunks: $chunk_count"
    fi

    echo ""
    echo "  Report generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "============================================"
}

# ── Print one-line summary ──
report_print_summary() {
    local parts=()
    for phase in setup equilibration production; do
        local status
        status=$(grep -o "\"$phase\": {[^}]*}" "$STATE_FILE" 2>/dev/null | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "unknown")
        parts+=("$phase: ${status}")
    done

    local joined
    joined=$(IFS=", "; echo "${parts[*]}")
    echo "$joined"
}
