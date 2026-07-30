# Existing Pipeline Inventory — BLM-cMYC (Successful 1ns Test)

## 1. Starting Structure

| Property | Value |
|----------|-------|
| **Source** | HDOCK model_2.pdb (BLM 4CGZ + c-MYC 2LBY) |
| **Input file** | `systems/blm_cmyc/input/selected_model_clean.pdb` |
| **Protein** | BLM helicase core, chain A, residues LEU639–SER1290 (627 residues) |
| **DNA** | c-MYC G-quadruplex, chain B, 19 residues (DT1–DG18) |
| **Zn²⁺** | 1 structural Zn²⁺ (chain I, residue 1291) |
| **K⁺** | 2 channel K⁺ (chain I, residues 2001–2002) |
| **Total atoms (raw PDB)** | 5,434 |
| **Total atoms (after pdb2gmx)** | 10,698 |
| **Net charge** | −9e (Protein +5, DNA −18, Ions +4) |
| **Histidine protonation** | All HISE (epsilon protonated) |

**Preprocessing performed:**
- CYS1036/1055/1063/1066 → CYM (deprotonated for Zn²⁺ coordination)
- DNA atom names: OP1 → O1P, OP2 → O2P
- DNA residues: DT5/DT3 → DT, DA5/DA3 → DA, DG5/DG3 → DG, DC5/DC3 → DC
- Zn²⁺ and K⁺ coordinates calculated from G-tetrad O6 centroids
- Water and non-standard residues stripped
- Chain IDs assigned: A = protein (resnum ≥ 600), B = DNA (DA/DC/DG/DT), I = ions

---

## 2. Force Field Configuration

| Setting | Value |
|---------|-------|
| **Force field** | amber14sb (Amber ff14SB protein + Amber bsc1 DNA) |
| **Water model** | spce (SPC/E) |
| **Cation** | K⁺ |
| **Anion** | Cl⁻ |
| **Salt concentration** | 0.15 M (150 mM KCl) |
| **Box type** | dodecahedron |
| **Box clearance** | 1.0 nm |
| **Hydrogen handling** | `-ignh` (ignore existing, regenerate) |
| **Missing atoms** | `-missing` (allow incomplete residues) |
| **Ion parameters** | Joung-Cheatham K⁺ (implicit in amber14sb.ff) |

---

## 3. MDP Files

### 3a. `em.mdp` — Energy Minimization

| Parameter | Value | Notes |
|-----------|-------|-------|
| `integrator` | `steep` | Standard steepest descent |
| `emtol` | `1000.0` | Default convergence threshold |
| `emstep` | `0.01` | Default step size |
| `nsteps` | `50000` | Max steps |
| `nstlist` | `20` | Conservative for EM |
| `constraints` | `none` | Flexible bonds during minimization |
| `define` | `-DPOSRES` | Position restraints on |
| **Pipeline default?** | ✅ Yes | Standard values, no system-specific tuning |

### 3b. `nvt.mdp` — NVT Equilibration (100 ps)

| Parameter | Value | Notes |
|-----------|-------|-------|
| `define` | `-DPOSRES` | Position restraints on |
| `integrator` | `md` | |
| `nsteps` | `50000` | 100 ps at 2 fs |
| `dt` | `0.002` | 2 fs |
| `nstxout-compressed` | `5000` | Every 10 ps |
| `nstenergy` | `5000` | Every 10 ps |
| `nstlog` | `5000` | Every 10 ps |
| `nstcalcenergy` | `500` | GPU optimization |
| `continuation` | `no` | First MD after EM |
| `constraints` | `h-bonds` | |
| `lincs_order` | `4` | |
| `cutoff-scheme` | `Verlet` | |
| `verlet-buffer-tolerance` | `0.002` | GPU optimization |
| `nstlist` | `400` | GPU optimization |
| `rcoulomb`/`rvdw`/`rlist` | `1.0` | Standard |
| `coulombtype` | `PME` | |
| `fourierspacing` | `0.12` | |
| `tcoupl` | `v-rescale` | |
| `tc-grps` | `Protein_DNA Water_Ions` | |
| `tau_t` | `0.1 0.1` | |
| `ref_t` | `300 300` | |
| `pcoupl` | `no` | NVT |
| `gen_vel` | `yes` | Maxwellian |
| `gen_temp` | `300` | |
| `gen_seed` | `-1` | Time-based seed |
| **Pipeline default?** | ✅ Yes | Standard NVT parameters |

### 3c. `npt.mdp` — NPT Equilibration (1 ns)

| Parameter | Value | Notes |
|-----------|-------|-------|
| `define` | `-DPOSRES` | Restraints on |
| `nsteps` | `500000` | 1 ns |
| `nstxout-compressed` | `5000` | Every 10 ps |
| `continuation` | `yes` | From NVT |
| `constraints` | `h-bonds` | |
| `verlet-buffer-tolerance` | `0.002` | GPU optimization |
| `nstlist` | `400` | GPU optimization |
| `nstcalcenergy` | `500` | GPU optimization |
| `tcoupl` | `v-rescale` | |
| `tc-grps` | `Protein_DNA Water_Ions` | |
| `ref_t` | `300 300` | |
| `pcoupl` | `Parrinello-Rahman` | |
| `pcoupltype` | `isotropic` | |
| `tau_p` | `5.0` | |
| `ref_p` | `1.0` | |
| `gen_vel` | `no` | Continuation |
| **Pipeline default?** | ✅ Yes | Standard NPT parameters |

### 3d. `md.mdp` — Production MD (50 ns per chunk)

| Parameter | Value | Notes |
|-----------|-------|-------|
| `nsteps` | `25000000` | 50 ns per chunk (chain 10× for 500 ns) |
| `nstxout-compressed` | `25000` | Every 50 ps (20 frames/ns) |
| `continuation` | `yes` | From NPT |
| `nstlist` | `400` | GPU optimization |
| `nstcalcenergy` | `500` | GPU optimization |
| `verlet-buffer-tolerance` | `0.002` | |
| `mts` | `yes` | Multiple time stepping |
| `tc-grps` | `Protein_DNA Water_Ions` | |
| `pcoupl` | `Parrinello-Rahman` | |
| `tau_p` | `5.0` | |
| `gen_vel` | `no` | Continuation |
| **Pipeline default?** | ✅ Yes | Standard production parameters |

---

## 4. GROMACS Workflow (Complete Command Log)

```
Stage 2:  python3 scripts/02_prepare_structure.py blm_cmyc
Stage 3:  gmx pdb2gmx -f 02_prepared.pdb -o 03_processed.gro -p topol.top
              -i posre.itp -ff amber14sb -water spce -ignh -missing
Stage 4:  gmx editconf -f 03_processed.gro -o 04_box.gro -bt dodecahedron -d 1.0
Stage 5:  gmx solvate -cp 04_box.gro -cs spc216.gro -o 05_solv.gro -p topol.top
Stage 6:  gmx grompp -f em.mdp -c 05_solv.gro -r 05_solv.gro -p topol.top
              -o ions.tpr -maxwarn 2
          echo "SOL" | gmx genion -s ions.tpr -o 06_ions.gro -p topol.top
              -pname K -nname CL -neutral -conc 0.15
Index:    gmx make_ndx -f 06_ions.gro -o index.ndx
              (1 | 12 → name 21 Protein_DNA; 16 | 17 → name 22 Water_Ions)
Stage 7:  gmx grompp -f em.mdp -c 06_ions.gro -r 06_ions.gro -p topol.top
              -o em.tpr -maxwarn 2
          gmx mdrun -v -s em.tpr -deffnm em
Stage 8:  gmx grompp -n index.ndx -f nvt.mdp -c em.gro -r em.gro -p topol.top
              -o nvt.tpr -maxwarn 1
          gmx mdrun -v -s nvt.tpr -deffnm nvt
Stage 9:  gmx grompp -n index.ndx -f npt.mdp -c nvt.gro -r nvt.gro -p topol.top
              -o npt.tpr -maxwarn 1
          gmx mdrun -v -s npt.tpr -deffnm npt
Stage 10: gmx grompp -n index.ndx -f md.mdp -c npt.gro -p topol.top
              -o md.tpr -maxwarn 1
          gmx mdrun -v -s md.tpr -deffnm md
Stage 11: echo "1 0" | gmx trjconv -s md.tpr -f md.xtc -o md_noPBC.xtc
              -pbc mol -center
          echo "4 4" | gmx rms -s md.tpr -f md_noPBC.xtc -o rmsd.xvg -tu ns
          echo "1" | gmx rmsf -s md.tpr -f md_noPBC.xtc -o rmsf.xvg -res
```

**Wrapper behavior** (`bin/gmx`): all `gmx` commands → `mpirun -np 1 gmx_mpi ...`. Outside PBS, adds `--mca btl tcp,self --mca plm isolated --mca orte_daemonize false`. For mdrun, adds `-pin on`. Does NOT add GPU flags (they were omitted in the successful run).

---

## 5. Scheduler Configuration

| Setting | Value (Successful Run) | Alternate (Available) |
|---------|------------------------|----------------------|
| **Scheduler** | PBS | PBS |
| **Queue** | standard | high, gpu |
| **Account** | helicases.spons | — |
| **CPUs** | 8 | 8 |
| **GPUs** | 1 (no explicit GPU flags in successful run) | 1 (with `-nb gpu -pme gpu -bonded gpu -update gpu`) |
| **Memory** | (not specified — used PBS default) | — |
| **Walltime (setup)** | 02:00:00 | — |
| **Walltime (EM)** | 01:00:00 | — |
| **Walltime (MD)** | 24:00:00 | 48:00:00 |
| **Node type** | `centos=icelake` | — |
| **Modules** | `apps/gromacs/2023.2/gnu` | `apps/gromacs/2023.2/gpu`, `apps/gromacs/2021.4/gpu` |
| **Anaconda** | `apps/anaconda/3` (strip lib from LD_LIBRARY_PATH) | — |
| **GROMACS version** | 2023.2-plumed_2.10.0_dev | — |
| **OMP_NUM_THREADS** | 8 | — |
| **MPI** | OpenMPI (via wrapper: `mpirun -np 1 gmx_mpi`) | — |

---

## 6. Runtime Outputs

| Stage | Output Files |
|-------|-------------|
| Stage 2 | `02_prepared.pdb` |
| Stage 3 | `03_processed.gro`, `topol.top`, `posre.itp`, `topol_*.itp` |
| Stage 4 | `04_box.gro` |
| Stage 5 | `05_solv.gro` (33 MB) |
| Stage 6 | `06_ions.gro` (33 MB), `ions.tpr` |
| Stage 7 | `em.gro`, `em.tpr`, `em.log`, `em.edr`, `em.trr` |
| Stage 8 | `nvt.gro`, `nvt.tpr`, `nvt.log`, `nvt.edr`, `nvt.cpt` |
| Stage 9 | `npt.gro`, `npt.tpr`, `npt.log`, `npt.edr`, `npt.cpt` |
| Stage 10 | `md.gro` (48 MB), `md.xtc` (56 MB), `md.tpr`, `md.log`, `md.edr`, `md.cpt` |
| Stage 11 | `md_noPBC.xtc`, `rmsd.xvg`, `rmsf.xvg` |

---

## 7. Custom/Additional Files

| File | Type | Used? |
|------|------|-------|
| `amber14sb.ff/` | Local force field copy | ✅ (bundled with pipeline) |
| `bin/gmx` | MPI wrapper | ✅ (all commands) |
| `posre_*.itp` | Position restraints | ✅ (generated by pdb2gmx) |
| `index.ndx` | Index file | ✅ (created by make_ndx) |
| Custom .itp files | — | ❌ Not used (standard residues only) |

---

## 8. Assumptions the Old Pipeline Makes

1. **System is protein–DNA.** The `02_prepare_structure.py` hardcodes chain assignment: resnum ≥ 600 = protein (chain A), DNA residues = chain B, ions = chain I.
2. **Zn²⁺ and 2 K⁺ channel ions are present.** The prepare script calculates positions from specific G-tetrad O6 atoms and inserts a Zn²⁺ and 2 K⁺.
3. **GROMACS is available via `module load`.** No fallback if modules are not available.
4. **`python3` is on PATH.** All validation and preparation use Python.
5. **Shared filesystem between login and compute nodes.** The pipeline assumes `$PBS_O_WORKDIR` is accessible on compute nodes.
6. **Scheduler is PBS.** Job headers use `#PBS` syntax. No Slurm or LSF support.
7. **Output directory is `systems/<SYSTEM>/outputs/`.** Paths are hardcoded in every stage script.
8. **The `bin/gmx` wrapper handles MPI.** All `gmx` commands go through the wrapper.
9. **`npt.gro` is the final equilibration output.** Production reads `npt.gro` directly (no `-r` flag in production grompp).

---

## 9. Migration Mapping

| Old Setting | New Location | Notes |
|-------------|-------------|-------|
| `input/selected_model_clean.pdb` | `input/system.pdb` | Rename, no content change |
| `-ff amber14sb` | `config.sh`: `FORCEFIELD="amber14sb"` | |
| `-water spce` | `config.sh`: `WATER_MODEL="spce"` | |
| `-pname K -nname CL -conc 0.15` | `config.sh`: `CATION="K"`, `ANION="CL"`, `SALT_CONC="0.15"` | |
| `-bt dodecahedron -d 1.0` | `config.sh`: `BOX_TYPE="dodecahedron"`, `BOX_DISTANCE="1.0"` | |
| `-ignh -missing` | Generated (`lib/stages.sh`) | Hardcoded in stage function |
| `nstlist=400` | `mdp/md.mdp` | Part of production MDP |
| `nstlist=20` | `mdp/em.mdp` | Part of EM MDP |
| `mts=yes` | `mdp/md.mdp` | Production only |
| `verlet-buffer-tolerance=0.002` | `mdp/nvt.mdp`, `mdp/npt.mdp`, `mdp/md.mdp` | All GPU phases |
| `nstcalcenergy=500` | `mdp/nvt.mdp`, `mdp/npt.mdp`, `mdp/md.mdp` | All GPU phases |
| `tc-grps=Protein_DNA Water_Ions` | `mdp/nvt.mdp`, `mdp/npt.mdp`, `mdp/md.mdp` | |
| `-P helicases.spons` | `profiles/iitd.sh`: `ACCOUNT_FLAG="-P %ACCOUNT%"` | Token-based |
| `-l select=1:ncpus=8:ngpus=1:centos=icelake` | `profiles/iitd.sh`: `SELECT_GPU=...` | Token-based |
| `-l walltime=24:00:00` | `config.sh`: `PROD_WALLTIME="24:00:00"` | |
| `module load apps/gromacs/2023.2/gnu` | `profiles/iitd.sh`: `MODULES=("apps/gromacs/2023.2/gnu")` | |
| `module load apps/anaconda/3` | `profiles/iitd.sh`: `MODULES+=("apps/anaconda/3")` | Combined with GROMACS |
| `export OMP_NUM_THREADS=8` | `config.sh`: implicit via `SETUP_CPUS`/`EQ_CPUS`/`PROD_CPUS` | Set in job scripts |
| `gmx make_ndx` with groups 1,12,16,17 | `lib/stages.sh` `run_stage_index()` | Automatically creates groups |
| `gmx trjconv -pbc mol -center` | Not in new pipeline (post-processing) | No longer required |
| `gmx rms` / `gmx rmsf` | Not in new pipeline (post-processing) | Removed from core |



## 10. Migration Checklist

To create the first project (`blm_cmyc`) in the new pipeline:

- [ ] Copy `input/selected_model_clean.pdb` → `input/system.pdb`
- [ ] Set `config.sh`:
  - `PROJECT="blm_cmyc"` (or rely on directory name default)
  - `CLUSTER="iitd"`
  - `FORCEFIELD="amber14sb"`
  - `WATER_MODEL="spce"`
  - `BOX_TYPE="dodecahedron"`
  - `BOX_DISTANCE="1.0"`
  - `SALT_CONC="0.15"`
  - `CATION="K"`
  - `ANION="CL"`
  - `PRODUCTION_NS=500`
  - `CHUNK_NS=50`
  - `ACCOUNT="helicases.spons"`
  - `QUEUE="high"`
  - `TC_GROUPS="group Protein or group DNA\ngroup Water or group Ion"`
  - `SETUP_CPUS=8`, `SETUP_MEM="8GB"`, `SETUP_WALLTIME="00:30:00"`
  - `EQ_CPUS=8`, `EQ_GPUS=1`, `EQ_MEM="16GB"`, `EQ_WALLTIME="02:00:00"`
  - `PROD_CPUS=8`, `PROD_GPUS=1`, `PROD_MEM="16GB"`, `PROD_WALLTIME="24:00:00"`
- [ ] Create `profiles/iitd.sh`:
  - `SCHEDULER="pbs"`
  - `MODULES=("apps/gromacs/2023.2/gnu")`
  - `SUBMIT_CMD="qsub"`
  - `SUBMIT_ACCOUNT="-P %ACCOUNT%"`
  - `SUBMIT_QUEUE="-q %QUEUE%"`
  - `SUBMIT_DEPENDENCY="-W depend=afterok:%JOBID%"`
  - `SELECT_GPU="1:ncpus=%CPUS%:ngpus=%GPUS%:mem=%MEMORY%:centos=icelake"`
  - `SELECT_CPU="1:ncpus=%CPUS%:mem=%MEMORY%:centos=icelake"`
  - `SUBMIT_WALLTIME="-l walltime=%WALLTIME%"`
  - `SUBMIT_OUTPUT="-o output/logs/%NAME%.o%JOBID%"`
  - `WORKDIR_VAR="PBS_O_WORKDIR"`
- [ ] Copy MDP files from `configs/` → `mdp/`:
  - `em.mdp` (as-is)
  - `nvt.mdp` (as-is)
  - `npt.mdp` (as-is)
  - `md.mdp` (nsteps=25000000, GPU-optimized)
- [ ] Run `setup/init.sh .` to create `.state/` and fingerprint
- [ ] Run `setup/doctor.sh` to verify cluster readiness
- [ ] Run `setup/validate.sh` to verify config and inputs
- [ ] Run `./run.sh submit` to submit all pipeline phases
