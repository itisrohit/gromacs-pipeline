#!/bin/bash
# Force field manager for GROMACS HPC Pipeline
# Helps install, list, and manage force fields.
set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FF_DIR="$PIPELINE_DIR/forcefields"

cmd_help() {
    cat <<- HELP
Usage: $(basename "$0") <command> [args]

Commands:
  list                        List installed and system-available force fields
  install <name> [source]     Install a force field
  doctor <name>               Check if a force field is usable
  help                        Show this message

Examples:
  $(basename "$0") list
  $(basename "$0") install amber14sb /path/to/amber14sb.ff
  $(basename "$0") doctor amber14sb
HELP
}

cmd_list() {
    echo "=== Pipeline force fields ($FF_DIR) ==="
    if [ -z "$(ls -A "$FF_DIR" 2>/dev/null | grep -v '\.gitkeep\|get-ff.sh')" ]; then
        echo "  (none installed)"
    else
        for d in "$FF_DIR/"*.ff/; do
            [ -d "$d" ] && echo "  $(basename "$d")"
        done
    fi

    echo ""
    echo "=== System-installed force fields ==="
    local gmx_bin
    gmx_bin=$(command -v gmx_mpi 2>/dev/null || command -v gmx 2>/dev/null || true)
    if [ -n "$gmx_bin" ]; then
        local top_dir
        top_dir="$(dirname "$(dirname "$gmx_bin")")/share/gromacs/top"
        if [ -d "$top_dir" ]; then
            for d in "$top_dir/"*.ff/; do
                [ -d "$d" ] && echo "  $(basename "$d")"
            done
        fi
    else
        echo "  (GROMACS not found in PATH)"
    fi

    if [ -n "${GMXLIB:-}" ] && [ -d "$GMXLIB" ]; then
        echo ""
        echo "=== GMXLIB force fields ==="
        for d in "$GMXLIB/"*.ff/; do
            [ -d "$d" ] && echo "  $(basename "$d")"
        done
    fi
}

cmd_install() {
    local name="${1:-}"
    local source="${2:-}"
    if [ -z "$name" ]; then
        echo "ERROR: Usage: $(basename "$0") install <name> [source]"
        exit 1
    fi

    local target="$FF_DIR/${name}.ff"
    if [ -d "$target" ]; then
        echo "ERROR: Force field already installed: $target"
        exit 1
    fi

    if [ -n "$source" ]; then
        if [ -d "$source" ]; then
            cp -r "$source" "$target"
            echo "Installed: $source -> $target"
        else
            echo "ERROR: Source not found: $source"
            exit 1
        fi
    elif command -v gmx_mpi &>/dev/null || command -v gmx &>/dev/null; then
        # Try to copy from system installation
        local gmx_bin
        gmx_bin=$(command -v gmx_mpi 2>/dev/null || command -v gmx 2>/dev/null)
        local top_dir
        top_dir="$(dirname "$(dirname "$gmx_bin")")/share/gromacs/top"
        local system_ff="$top_dir/${name}.ff"
        if [ -d "$system_ff" ]; then
            cp -r "$system_ff" "$target"
            echo "Copied from system: $system_ff -> $target"
        else
            echo "ERROR: Force field '$name' not found in system installation."
            echo "       Provide a source path: $(basename "$0") install $name /path/to/${name}.ff"
            exit 1
        fi
    else
        echo "ERROR: No source provided and GROMACS not found in PATH."
        echo "       Provide a source path: $(basename "$0") install $name /path/to/${name}.ff"
        exit 1
    fi

    if [ -f "$target/forcefield.itp" ]; then
        echo "  Validated: forcefield.itp found"
    else
        echo "  WARNING: forcefield.itp not found in $target"
    fi
}

cmd_doctor() {
    local name="${1:-}"
    if [ -z "$name" ]; then
        echo "ERROR: Usage: $(basename "$0") doctor <name>"
        exit 1
    fi

    local search_paths=(
        "$FF_DIR/${name}.ff"
    )
    if [ -n "${GMXLIB:-}" ]; then
        search_paths+=("$GMXLIB/${name}.ff")
    fi
    local gmx_bin
    gmx_bin=$(command -v gmx_mpi 2>/dev/null || command -v gmx 2>/dev/null || true)
    if [ -n "$gmx_bin" ]; then
        local top_dir
        top_dir="$(dirname "$(dirname "$gmx_bin")")/share/gromacs/top"
        search_paths+=("$top_dir/${name}.ff")
    fi

    echo "Searching for force field '$name'..."
    for d in "${search_paths[@]}"; do
        if [ -d "$d" ]; then
            if [ -f "$d/forcefield.itp" ]; then
                echo "  FOUND: $d (valid)"
                return 0
            else
                echo "  FOUND: $d (missing forcefield.itp)"
            fi
        else
            echo "  NOT FOUND: $d"
        fi
    done
    return 1
}

case "${1:-help}" in
    list)    cmd_list ;;
    install) shift; cmd_install "$@" ;;
    doctor)  shift; cmd_doctor "$@" ;;
    help|--help|-h) cmd_help ;;
    *)       echo "Unknown command: $1"; cmd_help; exit 1 ;;
esac
