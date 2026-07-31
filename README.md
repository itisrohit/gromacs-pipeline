# GROMACS HPC Pipeline

A minimal, Bash-only molecular dynamics pipeline for HPC clusters (PBS / Slurm / LSF).
Built around standard GROMACS capabilities — no Python, no workflow engines, no Docker.

---

## Architecture: why 3 jobs?

The pipeline submits **3 PBS jobs** chained with dependencies:

```
Job 1: SETUP (CPU)          prepare → pdb2gmx → editconf → solvate → genion → index
Job 2: EQUILIBRATION (GPU)  EM → NVT → NPT
Job 3: PRODUCTION (GPU)     production MD (chunked, checkpoint-aware)
```

Each job waits for the previous via `-W depend=afterok:`. This balances:

- **Fewer queue waits** — CPU stages grouped into 1 job, GPU eq into 1 job
- **Resumability** — if production hits walltime, it restarts from checkpoint
- **Correct hardware** — setup uses CPU nodes, eq/production use GPU nodes

Production is chunked: `PRODUCTION_NS / CHUNK_NS` chunks are submitted in a chain.
Each chunk runs `mdrun -maxh -cpi -nsteps -1` so long simulations survive walltime limits.

---

## Repository layout

```
gromacs-pipeline/
├── run.sh                    # Main entry point (submit/status/report)
├── lib/
│   ├── gmx.sh                # GROMACS discovery, version check, GPU flags
│   ├── scheduler.sh          # PBS/Slurm/LSF submission abstraction
│   ├── stages.sh             # All MD stage functions
│   └── state.sh              # Locking, workflow state, fingerprint check
├── setup/
│   ├── init.sh               # Create a new project
│   ├── validate.sh           # Validate a project before running
│   ├── doctor.sh             # Check HPC environment
│   ├── fingerprint.sh        # Hash simulation inputs
│   └── templates/
│       └── config.sh         # Default project config
├── profiles/
│   ├── iitd.sh               # IIT Delhi HPC (PBS)
│   ├── generic-pbs.sh        # Generic PBS template
│   ├── generic-slurm.sh      # Generic Slurm template
│   └── generic-lsf.sh        # Generic LSF template
├── mdp/                      # Default MDP files (copied to projects)
│   ├── em.mdp
│   ├── nvt.mdp
│   ├── npt.mdp
│   └── md.mdp
├── forcefields/              # Shared force field storage (user-populated)
│   └── get-ff.sh             # Force field manager
└── README.md
```

---

## Quick start (5 steps)

```bash
# 1. Create a project
bash gromacs-pipeline/setup/init.sh projects/my_system

# 2. Place your structure and edit config
#    projects/my_system/input/system.pdb
#    projects/my_system/config.sh   (set FORCEFIELD, lengths, resources)

# 3. Install a force field (one-time)
bash gromacs-pipeline/forcefields/get-ff.sh install amber99sb-ildn

# 4. Validate
bash gromacs-pipeline/setup/validate.sh projects/my_system

# 5. Submit
bash gromacs-pipeline/run.sh submit projects/my_system
```

Monitor with `bash gromacs-pipeline/run.sh status projects/my_system`.

---

## Full workflow

### 1. Create a project

```bash
bash gromacs-pipeline/setup/init.sh projects/blm_cmyc
```

This creates:
```
projects/blm_cmyc/
├── config.sh        # edit this
├── input/           # place system.pdb here
├── mdp/             # MDP files (copied from pipeline)
├── output/          # setup/, equilibration/, production/, logs/
├── .state/          # workflow state + fingerprint
└── prep/            # (you create this) project-specific preparation
```

### 2. Prepare the structure

The pipeline reads `input/system.pdb` and expects it to be GROMACS-ready:

- Standard residue names (recognized by your force field)
- Proper chain IDs in PDB column 22
- No water (pdb2gmx handles it, but cleaner to strip)
- Structural ions/ligands preserved

Put preparation logic in `prep/prepare.sh` (project-specific, NOT part of the pipeline):

```bash
bash projects/blm_cmyc/prep/prepare.sh
# produces projects/blm_cmyc/input/system.pdb
```

The pipeline only strips water. Everything else (topology, box, solvation, ions,
hydrogens) is GROMACS.

### 3. Install a force field

```bash
# List available force fields
bash gromacs-pipeline/forcefields/get-ff.sh list

# Install from system GROMACS
bash gromacs-pipeline/forcefields/get-ff.sh install amber99sb-ildn

# Install from a local path
bash gromacs-pipeline/forcefields/get-ff.sh install amber14sb /path/to/amber14sb.ff

# Complete a partial force field (copy missing DNA/RNA/ion files from system)
bash gromacs-pipeline/forcefields/get-ff.sh complete amber14sb

# Check if a force field is usable
bash gromacs-pipeline/forcefields/get-ff.sh doctor amber14sb
```

Force fields are stored in `gromacs-pipeline/forcefields/`. The pipeline sets
`GMXLIB` to this directory (plus the system GROMACS library) so custom force
fields are found automatically.

### 4. Edit config.sh

```bash
# projects/my_system/config.sh
CLUSTER="iitd"              # must match profiles/iitd.sh
PROJECT="my_system"
PDB="input/system.pdb"
FORCEFIELD="amber99sb-ildn"  # REQUIRED
WATER_MODEL="spce"
BOX_TYPE="dodecahedron"
BOX_DISTANCE="1.0"
SALT_CONC="0.15"
CATION="K"
ANION="CL"
PRODUCTION_NS=1              # total production length in ns
CHUNK_NS=1                   # chunk length in ns (walltime-limited)
ACCOUNT="helicases.spons"    # PBS project
QUEUE="standard"
SETUP_CPUS=8
EQ_CPUS=8
EQ_GPUS=1
PROD_CPUS=8
PROD_GPUS=1
```

### 5. Validate

```bash
bash gromacs-pipeline/setup/validate.sh projects/my_system
```

Checks:
- config.sh is loadable and complete
- FORCEFIELD exists in any search path (project / pipeline / GMXLIB / system)
- Cluster profile exists
- All MDP files and PDB exist
- Numeric parameters and walltimes are valid
- Fails fast with clear errors — no GROMACS run needed

### 6. Submit

```bash
bash gromacs-pipeline/run.sh submit projects/my_system
```

This:
1. Verifies the fingerprint (config unchanged since init)
2. Generates `scripts/setup.sh`, `scripts/equilibration.sh`, `scripts/production.sh`
3. Submits all 3 PBS jobs with `afterok` dependencies

### 7. Monitor

```bash
bash gromacs-pipeline/run.sh status projects/my_system
```

### 8. Report

```bash
bash gromacs-pipeline/run.sh report projects/my_system
```

---

## Resume vs restart

The pipeline is **idempotent** — every stage skips if its output already exists.
This means you can re-run `run.sh submit` safely; it only submits what's incomplete.

| Situation | What changed | Action |
|-----------|-------------|--------|
| **Resume** | Nothing, or only a bug fix in pipeline code / MDP | Just re-`submit` — completed stages are skipped, only incomplete ones re-run |
| **Resume after walltime** | Production chunk hit walltime | Just re-`submit` — `mdrun -cpi` resumes from checkpoint automatically |
| **Restart** | Force field, `system.pdb`, or `config.sh` changed | `rm -rf output` then re-init + submit (below) |
| **Restart phase** | Only equilibration/production settings changed | Delete just that phase's dir then re-`submit` |

### Resume (recommended for MDP/code fixes)

```bash
# Just re-submit. Completed stages skip, incomplete ones run.
bash gromacs-pipeline/run.sh submit projects/my_system
```

Example: if NVT failed but setup is done, re-running `submit` skips setup
(`ions.gro` exists) and only re-submits equilibration. If production hit
walltime, `mdrun -cpi` continues from the checkpoint instead of step 0.

### Restart from scratch (only when inputs changed)

```bash
# Force field / PDB / config changed → previous outputs are invalid
rm -rf projects/my_system/output
rm -rf projects/my_system/.state
mkdir -p projects/my_system/output/setup \
         projects/my_system/output/equilibration \
         projects/my_system/output/production \
         projects/my_system/output/logs
bash gromacs-pipeline/setup/state.sh projects/my_system
bash gromacs-pipeline/setup/fingerprint.sh projects/my_system
bash gromacs-pipeline/run.sh submit projects/my_system
```

### Restart just equilibration or production

```bash
# If only equilibration needs a clean run:
rm -rf projects/my_system/output/equilibration
bash gromacs-pipeline/run.sh submit projects/my_system
```

```bash
# If only production needs a clean run:
rm -rf projects/my_system/output/production
bash gromacs-pipeline/run.sh submit projects/my_system
```

### Golden rule

- **Code / MDP fix** → resume (just re-`submit`)
- **Force field / structure / config change** → restart (delete `output/`)

---

## Command reference

### run.sh

| Command | Purpose |
|---------|---------|
| `run.sh submit <project>` | Submit all pipeline jobs |
| `run.sh status <project>` | Show phase + scheduler status |
| `run.sh report <project>` | Generate completion report |

### setup scripts

| Script | Purpose |
|--------|---------|
| `setup/init.sh <project>` | Create a new project |
| `setup/validate.sh <project>` | Validate config, force field, files |
| `setup/doctor.sh` | Check HPC environment (scheduler, GROMACS, disk) |
| `setup/fingerprint.sh <project>` | Hash inputs; `--check` compares |

### forcefields/get-ff.sh

| Command | Purpose |
|---------|---------|
| `get-ff.sh list` | List installed + system force fields |
| `get-ff.sh install <name> [source]` | Install a force field |
| `get-ff.sh complete <name>` | Copy missing DNA/RNA/ion files from system |
| `get-ff.sh doctor <name>` | Check force field usability |

---

## What each stage does

| Stage | GROMACS tool | Input → Output |
|-------|-------------|----------------|
| prepare | awk (pipeline) | `system.pdb` → `complex_clean.pdb` (strip water) |
| topol | `pdb2gmx -ignh -missing -noter` | → `processed.gro`, `topol.top`, `posre.itp` |
| box | `editconf -bt -d` | → `box.gro` |
| solvate | `solvate -cs spc216.gro` | → `solv.gro` |
| ions | `grompp` + `genion -neutral -conc` | → `ions.gro` |
| index | `gmx select` | → `index.ndx` (Protein_DNA, Water_Ions) |
| EM | `grompp` + `mdrun` | → `em.gro` (convergence checked) |
| NVT | `grompp` + `mdrun -cpi` (GPU) | → `nvt.gro` |
| NPT | `grompp` + `mdrun -cpi` (GPU) | → `npt.gro` |
| Production | `mdrun -maxh -cpi -nsteps -1` (GPU) | → `md.xtc` (chunked) |

---

## Force field discovery

GROMACS searches for `<forcefield>.ff` in:
1. Current directory (first)
2. `GMXLIB` environment variable
3. GROMACS install tree

The pipeline sets `GMXLIB` to `gromacs-pipeline/forcefields/` plus the system
GROMACS library. `setup/validate.sh` checks these paths in order:

1. `$PROJECT_DIR/<forcefield>.ff` (project-local override)
2. `$PIPELINE_DIR/forcefields/<forcefield>.ff` (shared)
3. `$GMXLIB/<forcefield>.ff`
4. System GROMACS install

Validation succeeds only if `forcefield.itp` exists inside the directory.

---

## Production with replicates

For multiple replicates, create separate project directories:

```bash
bash gromacs-pipeline/setup/init.sh projects/blm_kras_rep1
bash gromacs-pipeline/setup/init.sh projects/blm_kras_rep2
bash gromacs-pipeline/setup/init.sh projects/blm_kras_rep3
```

Each is independent. Set `PRODUCTION_NS=500` and `CHUNK_NS=50` in each, then
submit all three. They run in parallel; each chunks production sequentially.

---

## Troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| `FORCEFIELD not found` | Force field not installed. Run `get-ff.sh install <name>` |
| `qsub` prints usage | Profile's SELECT flag missing `-l select=` prefix |
| Job fails at genion | Partial force field missing ion definitions. Run `get-ff.sh complete <name>` |
| `-cpi: Too many values` | GROMACS version not parsed (MPI warning pollution). Use fixed `gmx.sh` |
| `Protein_DNA not found` | `Water`/`Ion` groups missing. Check `solv.gro`/`ions.gro` |
| `PROJECT_DIR: unbound variable` | Job script generated before the PROJECT_DIR hardcode fix. Re-run submit |
| EM doesn't converge | Check `em.log`; may need more steps or looser restraints |

### Where logs go

PBS output goes to `projects/<name>/*.o<jobid>` (in the project root) because
IITD's PBS doesn't support custom `-o` paths. Stage-level logs:
- `output/setup/*.log`
- `output/equilibration/*.log`
- `output/production/*.log`
