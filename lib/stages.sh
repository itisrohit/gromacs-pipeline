#!/bin/bash
set -euo pipefail

# ── Prepare step: clean input PDB ──
run_stage_prepare() {
    local out="output/setup/complex_clean.pdb"
    [ -f "$out" ] && { echo "SKIP: $out exists"; return 0; }

    mkdir -p output/setup
    echo "PREPARE: Cleaning input PDB..."

    # Strip water, keep protein and DNA atoms, assign chains
    awk '
    /^ATOM|^HETATM/ {
        resname = substr($0,18,3)
        gsub(/ /,"",resname)
        # Skip water, ions
        if (resname == "HOH" || resname == "SOL" || resname == "WAT" || resname == "TIP3" || resname == "SPC") next
        if (resname == "K" || resname == "K+" || resname == "NA" || resname == "CL" || resname == "ZN") next
        print
    }
    /^TER|^END/ { print }
    ' "input/complex.pdb" > "$out"

    echo "PREPARE: $(grep -c '^ATOM\|^HETATM' "$out" 2>/dev/null || echo 0) atoms written"
}

# ── Topology generation ──
run_stage_topol() {
    local out="output/setup/processed.gro"
    [ -f "$out" ] && { echo "SKIP: $out exists"; return 0; }

    mkdir -p output/setup
    echo "TOPOL: Generating topology..."

    $GMX pdb2gmx \
        -f output/setup/complex_clean.pdb \
        -o "$out" \
        -p output/setup/topol.top \
        -i output/setup/posre.itp \
        -ff "$FORCEFIELD" \
        -water "$WATER_MODEL" \
        -ignh -missing

    if [ ! -f "$out" ]; then
        echo "ERROR: pdb2gmx failed to produce $out"
        exit 1
    fi
    echo "TOPOL: Complete"
}

# ── Box definition ──
run_stage_box() {
    local out="output/setup/box.gro"
    [ -f "$out" ] && { echo "SKIP: $out exists"; return 0; }

    echo "BOX: Creating $BOX_TYPE box..."
    $GMX editconf \
        -f output/setup/processed.gro \
        -o "$out" \
        -bt "$BOX_TYPE" \
        -d "$BOX_DISTANCE"

    [ -f "$out" ] || { echo "ERROR: editconf failed"; exit 1; }
    echo "BOX: Complete"
}

# ── Solvation ──
run_stage_solvate() {
    local out="output/setup/solv.gro"
    [ -f "$out" ] && { echo "SKIP: $out exists"; return 0; }

    echo "SOLVATE: Adding water..."
    $GMX solvate \
        -cp output/setup/box.gro \
        -cs spc216.gro \
        -o "$out" \
        -p output/setup/topol.top

    [ -f "$out" ] || { echo "ERROR: solvate failed"; exit 1; }
    echo "SOLVATE: Complete"
}

# ── Ion addition ──
run_stage_ions() {
    local out="output/setup/ions.gro"
    [ -f "$out" ] && { echo "SKIP: $out exists"; return 0; }

    echo "IONS: Adding ions..."
    mkdir -p output/setup

    $GMX grompp \
        -f mdp/em.mdp \
        -c output/setup/solv.gro \
        -r output/setup/solv.gro \
        -p output/setup/topol.top \
        -o output/setup/ions.tpr \
        -maxwarn 2

    echo "SOL" | $GMX genion \
        -s output/setup/ions.tpr \
        -o "$out" \
        -p output/setup/topol.top \
        -pname "$CATION" \
        -nname "$ANION" \
        -neutral \
        -conc "$SALT_CONC"

    [ -f "$out" ] || { echo "ERROR: genion failed"; exit 1; }
    echo "IONS: Complete"
}

# ── Index file creation ──
run_stage_index() {
    local out="output/setup/index.ndx"
    [ -f "$out" ] && { echo "SKIP: $out exists"; return 0; }

    echo "INDEX: Creating temperature coupling groups..."

    # Build groups from TC_GROUPS config (one line per group)
    local grp_num=0
    local groups=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        groups+=("$line")
        grp_num=$((grp_num + 1))
    done <<< "$TC_GROUPS"

    if [ "$grp_num" -eq 0 ]; then
        echo "WARNING: No TC_GROUPS defined in config. Using default groups."
        $GMX make_ndx -f output/setup/ions.gro -o "$out" <<- EOF
1 | 12
name 21 Protein_DNA
16 | 17
name 22 Water_Ions
q
EOF
    else
        # Use gmx select for each group
        rm -f "$out"
        for sel in "${groups[@]}"; do
            $GMX select -f output/setup/ions.gro -s output/setup/ions.gro \
                -on "$out" \
                -select "$sel"
        done
    fi

    [ -f "$out" ] || { echo "ERROR: index creation failed"; exit 1; }
    echo "INDEX: Complete"
}

# ── Energy minimization ──
run_stage_em() {
    local out="output/equilibration/em.gro"
    [ -f "$out" ] && { echo "SKIP: $out exists"; return 0; }

    mkdir -p output/equilibration
    echo "EM: Energy minimization..."

    $GMX grompp \
        -f mdp/em.mdp \
        -c output/setup/ions.gro \
        -r output/setup/ions.gro \
        -p output/setup/topol.top \
        -n output/setup/index.ndx \
        -o output/equilibration/em.tpr \
        -maxwarn 2

    $GMX mdrun \
        -deffnm output/equilibration/em \
        -v

    if [ ! -f "$out" ]; then
        echo "ERROR: EM failed to produce $out"
        exit 1
    fi
    echo "EM: Complete"
}

# ── NVT equilibration ──
run_stage_nvt() {
    local out="output/equilibration/nvt.gro"
    [ -f "$out" ] && { echo "SKIP: $out exists"; return 0; }

    echo "NVT: Temperature equilibration..."

    $GMX grompp \
        -f mdp/nvt.mdp \
        -c output/equilibration/em.gro \
        -r output/equilibration/em.gro \
        -p output/setup/topol.top \
        -n output/setup/index.ndx \
        -o output/equilibration/nvt.tpr \
        -maxwarn 1

    local gpu_flags
    gpu_flags=$(gmx_gpu_flags)

    $GMX mdrun \
        -deffnm output/equilibration/nvt \
        -cpi output/equilibration/nvt.cpt \
        $gpu_flags \
        -v

    if [ ! -f "$out" ]; then
        echo "ERROR: NVT failed to produce $out"
        exit 1
    fi
    echo "NVT: Complete"
}

# ── NPT equilibration ──
run_stage_npt() {
    local out="output/equilibration/npt.gro"
    [ -f "$out" ] && { echo "SKIP: $out exists"; return 0; }

    echo "NPT: Pressure equilibration..."

    $GMX grompp \
        -f mdp/npt.mdp \
        -c output/equilibration/nvt.gro \
        -r output/equilibration/nvt.gro \
        -t output/equilibration/nvt.cpt \
        -p output/setup/topol.top \
        -n output/setup/index.ndx \
        -o output/equilibration/npt.tpr \
        -maxwarn 1

    local gpu_flags
    gpu_flags=$(gmx_gpu_flags)

    $GMX mdrun \
        -deffnm output/equilibration/npt \
        -cpi output/equilibration/npt.cpt \
        $gpu_flags \
        -v

    if [ ! -f "$out" ]; then
        echo "ERROR: NPT failed to produce $out"
        exit 1
    fi
    echo "NPT: Complete"
}

# ── Production MD (checkpoint-aware, used for all chunks) ──
run_stage_production() {
    echo "PRODUCTION: Running production MD..."
    mkdir -p output/production

    if [ ! -f output/production/md.tpr ]; then
        echo "PRODUCTION: Compiling TPR..."
        $GMX grompp \
            -f mdp/md.mdp \
            -c output/equilibration/npt.gro \
            -r output/equilibration/npt.gro \
            -p output/setup/topol.top \
            -n output/setup/index.ndx \
            -o output/production/md.tpr
    fi

    # Calculate maxh from walltime with 10% safety margin
    local walltime_seconds
    walltime_seconds=$(echo "$PROD_WALLTIME" | awk -F: '{print ($1*3600 + $2*60 + $3) * 0.9}')
    local maxh
    maxh=$(echo "scale=2; $walltime_seconds / 3600" | bc 2>/dev/null || echo "23.5")

    local gpu_flags
    gpu_flags=$(gmx_gpu_flags)

    echo "PRODUCTION: mdrun -maxh $maxh"
    $GMX mdrun \
        -deffnm output/production/md \
        -cpi output/production/md.cpt \
        -maxh "$maxh" \
        -nsteps -1 \
        $gpu_flags \
        -v

    echo "PRODUCTION: mdrun exited (checkpoint written if walltime exceeded)"
}
