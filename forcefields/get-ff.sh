#!/bin/bash
# Force field manager for GROMACS HPC Pipeline
# Helps install, list, complete, and manage force fields.
set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FF_DIR="$PIPELINE_DIR/forcefields"

# Files commonly shared between force fields (DNA/RNA/ions/solvent)
# These may be missing from a partial force field directory (e.g. a
# protein-only amber14sb.ff). When missing, they are copied from a
# complete system-installed force field.
SHARED_FILES=(
    "dna.rtp" "dna.r2b" "dna.hdb" "dna.arn"
    "rna.rtp" "rna.r2b" "rna.hdb" "rna.arn"
    "residuetypes.dat" "specbond.dat"
)

cmd_help() {
    cat <<- HELP
Usage: $(basename "$0") <command> [args]

Commands:
  list                        List installed and system-available force fields
  install <name> [source]     Install a force field (copies shared files if needed)
  complete <name>             Copy missing shared DNA/RNA files from system install
  doctor <name>               Check if a force field is usable (and fix if possible)
  help                        Show this message

Examples:
  $(basename "$0") list
  $(basename "$0") install amber14sb /path/to/amber14sb.ff
  $(basename "$0") complete amber14sb
  $(basename "$0") doctor amber14sb
HELP
}

# Find the system GROMACS top directory
system_top_dir() {
    local gmx_bin
    gmx_bin=$(command -v gmx_mpi 2>/dev/null || command -v gmx 2>/dev/null || true)
    if [ -n "$gmx_bin" ]; then
        local top
        top="$(dirname "$(dirname "$(readlink -f "$gmx_bin" 2>/dev/null || echo "$gmx_bin")")")/share/gromacs/top"
        [ -d "$top" ] && echo "$top"
    fi
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

    local top_dir
    top_dir=$(system_top_dir)
    if [ -n "$top_dir" ]; then
        echo ""
        echo "=== System-installed force fields ==="
        for d in "$top_dir/"*.ff/; do
            [ -d "$d" ] && echo "  $(basename "$d")"
        done
    else
        echo ""
        echo "  (GROMACS not found in PATH)"
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

    local top_dir
    top_dir=$(system_top_dir)

    if [ -n "$source" ]; then
        if [ -d "$source" ]; then
            cp -r "$source" "$target"
            echo "Installed: $source -> $target"
        else
            echo "ERROR: Source not found: $source"
            exit 1
        fi
    elif [ -n "$top_dir" ] && [ -d "$top_dir/${name}.ff" ]; then
        cp -r "$top_dir/${name}.ff" "$target"
        echo "Copied from system: $top_dir/${name}.ff -> $target"
    else
        echo "ERROR: No source provided and force field not found in system."
        echo "       Provide a source path: $(basename "$0") install $name /path/to/${name}.ff"
        exit 1
    fi

    if [ -f "$target/forcefield.itp" ]; then
        echo "  Validated: forcefield.itp found"
    else
        echo "  WARNING: forcefield.itp not found in $target"
    fi

    # Copy missing shared files (DNA/RNA etc.) from a complete system force field
    cmd_complete "$name" || true
}

cmd_complete() {
    local name="${1:-}"
    if [ -z "$name" ]; then
        echo "ERROR: Usage: $(basename "$0") complete <name>"
        exit 1
    fi

    local target="$FF_DIR/${name}.ff"
    if [ ! -d "$target" ]; then
        echo "ERROR: Force field not installed: $target"
        echo "       Run: $(basename "$0") install $name"
        exit 1
    fi

    local top_dir
    top_dir=$(system_top_dir)
    if [ -z "$top_dir" ]; then
        echo "WARNING: GROMACS not found in PATH; cannot source shared files"
        return 1
    fi

    local copied=0
    for f in "${SHARED_FILES[@]}"; do
        if [ ! -f "$target/$f" ]; then
            # Look for the file in any system-installed force field
            local found=""
            for sys in "$top_dir/"*.ff/; do
                if [ -f "$sys/$f" ]; then
                    found="$sys/$f"
                    break
                fi
            done
            if [ -n "$found" ]; then
                cp "$found" "$target/"
                echo "  Copied $f from $(dirname "$found")"
                copied=$((copied + 1))
            fi
        fi
    done

    if [ "$copied" -eq 0 ]; then
        echo "  Force field '$name' is complete (no missing shared files)"
    fi
}

cmd_doctor() {
    local name="${1:-}"
    if [ -z "$name" ]; then
        echo "ERROR: Usage: $(basename "$0") doctor <name>"
        exit 1
    fi

    local top_dir
    top_dir=$(system_top_dir)

    local search_paths=("$FF_DIR/${name}.ff")
    if [ -n "${GMXLIB:-}" ]; then
        search_paths+=("$GMXLIB/${name}.ff")
    fi
    if [ -n "$top_dir" ]; then
        search_paths+=("$top_dir/${name}.ff")
    fi

    echo "Checking force field '$name'..."
    for d in "${search_paths[@]}"; do
        if [ -d "$d" ] && [ -f "$d/forcefield.itp" ]; then
            echo "  FOUND: $d"
            # Check for missing shared files
            local missing=0
            for f in "${SHARED_FILES[@]}"; do
                if [ ! -f "$d/$f" ]; then
                    echo "  MISSING: $f"
                    missing=$((missing + 1))
                fi
            done
            if [ "$missing" -gt 0 ]; then
                echo "  Run '$0 complete $name' to copy missing files from system install"
            else
                echo "  Force field is complete"
            fi
            return 0
        fi
    done
    echo "  NOT FOUND: $name (searched: ${search_paths[*]})"
    return 1
}

case "${1:-help}" in
    list)     cmd_list ;;
    install)  shift; cmd_install "$@" ;;
    complete) shift; cmd_complete "$@" ;;
    doctor)   shift; cmd_doctor "$@" ;;
    help|--help|-h) cmd_help ;;
    *)        echo "Unknown command: $1"; cmd_help; exit 1 ;;
esac
