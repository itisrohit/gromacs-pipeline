# GROMACS HPC Pipeline

A minimal, Bash-only molecular dynamics pipeline for HPC clusters (PBS / Slurm / LSF).
Built around standard GROMACS capabilities — no Python, no workflow engines, no Docker.

---

## AI-Assisted Repository

This repository is designed for AI-assisted operation, inspired by Max Iskiev's approach to AI-augmented scientific computing.

- AI assists with repository operations, validation, reasoning, documentation, and scientific workflows.
- The repository is designed so AI agents can reliably understand and operate it.
- AI reuses existing repository capabilities rather than inventing new workflows.
- Operational knowledge is maintained in dedicated skills rather than duplicated throughout the repository.
- The repository remains deterministic, reproducible, and script-first.

**For AI agents:** Read `AGENTS.md` first. It contains operational knowledge, validated workflows, known pitfalls, and current project status. This README is for end users. AGENTS.md is the agent's source of truth.

---

## Architecture: Why 3 Jobs?

The pipeline submits **3 PBS jobs** chained with dependencies:

```
Job 1: SETUP (CPU)          prepare → pdb2gmx → editconf → solvate → genion → index
Job 2: EQUILIBRATION (GPU)  EM → NVT → NPT
Job 3: PRODUCTION (GPU)     production MD (checkpoint-aware, extend-from-checkpoint loop)
```

Each job waits for the previous via `-W depend=afterok:`. This balances:

- **Fewer queue waits** — CPU stages grouped into 1 job, GPU eq into 1 job
- **Resumability** — if production hits walltime, it restarts from checkpoint
- **Correct hardware** — setup uses CPU nodes, eq/production use GPU nodes

Production uses an extend-from-checkpoint loop. Each PBS job runs multiple
chunks until the walltime budget is exhausted, then exits gracefully. The next
job resumes from the last checkpoint. No need for even division of
`PRODUCTION_NS / CHUNK_NS`.

---

## Repository Layout

```
gromacs-pipeline/
├── run.sh                    # Main entry point (submit/status/report)
├── lib/
│   ├── gmx.sh                # GROMACS discovery, version check, GPU flags, checkpoint reading
│   ├── scheduler.sh          # PBS/Slurm/LSF submission abstraction
│   ├── stages.sh             # All MD stage functions (including production loop)
│   └── state.sh              # Locking, workflow state, fingerprint check
├── setup/
│   ├── init.sh               # Create a new project
│   ├── validate.sh           # Validate a project before running
│   ├── doctor.sh             # Check HPC environment
│   ├── replicate.sh          # Clone template into N replicates
│   ├── fingerprint.sh        # Hash simulation inputs
│   └── templates/
│       └── config.sh         # Default project config
├── post/
│   └── prepare.sh            # Trajectory preparation (PBC, center, fit, strip)
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
├── tests/
│   ├── unit.sh               # Unit tests for gmx.sh functions
│   ├── integration.sh        # Integration tests for production loop
│   ├── test_prepare.sh       # Tests for trajectory preparation
│   └── bin/
│       └── fake_gmx          # Mock GROMACS for testing
├── docs/
│   └── benchmark.md          # Performance benchmark report
├── .agent/                   # Agent skills for input preparation
├── AGENTS.md                 # Agent/developer operations guide
└── README.md                 # This file
```

---

## Quick Start

> **Where**: Steps 1–2 are **LOCAL** (your Mac). Steps 3–5 are **ON THE HPC**.

```bash
# ── RUN LOCALLY (on your Mac) ──────────────────────────────────────────────

# 1. Create a project
bash setup/init.sh projects/my_system

# 2. Place your structure, prepare it, and edit config
bash projects/my_system/prep/prepare.sh            # → input/system.pdb
#    edit projects/my_system/config.sh  (set FORCEFIELD, lengths, resources)

# 3. Upload the project to the HPC (see "Deploy to the HPC" below)

# ── RUN ON THE HPC ─────────────────────────────────────────────────────────

# 4. Install a force field (one-time)
bash gromacs-pipeline/forcefields/get-ff.sh install amber99sb-ildn

# 5. Validate and submit
bash gromacs-pipeline/setup/validate.sh projects/my_system
bash gromacs-pipeline/run.sh submit projects/my_system
```

Monitor with `bash gromacs-pipeline/run.sh status projects/my_system` (on HPC).

---

## Deploy to the HPC

> **RUN LOCALLY** — uploads your local code/input to the HPC.

The pipeline lives in its own git repo. Upload it to the HPC with `scp`
(you'll be prompted for your HPC password each time).

### Upload the pipeline

```bash
# From the gromacs-pipeline directory:
scp -r ./* <user>@<hpc-host>:~/simulations/gromacs-pipeline/
```

### Upload a project

```bash
# From your projects directory:
scp -r projects/blm_cmyc <user>@<hpc-host>:~/simulations/projects/
```

### Upload notes

- **`scp -r` merges/overwrites** — fine for source files (config, mdp, lib),
  but it will NOT delete files on the HPC that you removed locally.
- **Never upload `output/` or `.state/`** back to the HPC — those are
  generated there. Only upload code/input changes.
- For a clean sync (removes stale files on HPC), use:
  ```bash
  rsync -av --delete ./ <user>@<hpc-host>:~/simulations/gromacs-pipeline/
  ```
- **Do NOT `git clone` on the HPC** — it hangs. Always tar+scp upload.
- macOS tar adds `._` files. Delete them from force fields:
  `find forcefields -name '._*' -delete`

---

## Full Workflow

### Step 1: Create a project

> **RUN LOCALLY** — creates the project folder structure on your Mac.

```bash
bash setup/init.sh projects/blm_cmyc
```

This creates:

```
projects/<name>/
├── config.sh        # edit this
├── input/           # place system.pdb here
├── mdp/             # MDP files (copied from pipeline)
├── output/          # setup/, equilibration/, production/, logs/
├── .state/          # workflow state + fingerprint
├── prep/            # (you create this) project-specific preparation
└── scripts/         # generated job scripts (created on submit)
```

### Step 2: Prepare the structure

> **RUN LOCALLY** — pure text processing, no GROMACS/HPC needed.

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

### Step 3: Install a force field

> **RUN ON THE HPC** — `get-ff.sh install` copies from the HPC's system GROMACS.
> (`list`/`doctor` work anywhere; `complete` needs the system install.)

```bash
# List available force fields (anywhere)
bash gromacs-pipeline/forcefields/get-ff.sh list

# Install from system GROMACS (on the HPC)
bash gromacs-pipeline/forcefields/get-ff.sh install amber99sb-ildn

# Install from a local path (anywhere)
bash gromacs-pipeline/forcefields/get-ff.sh install amber14sb /path/to/amber14sb.ff

# Complete a partial force field (copy missing DNA/RNA/ion files from system)
bash gromacs-pipeline/forcefields/get-ff.sh complete amber14sb

# Check if a force field is usable (anywhere)
bash gromacs-pipeline/forcefields/get-ff.sh doctor amber14sb
```

Force fields are stored in `gromacs-pipeline/forcefields/`. The pipeline sets
`GMXLIB` to this directory (plus the system GROMACS library) so custom force
fields are found automatically.

### Step 4: Edit config.sh

> **RUN LOCALLY** — edit the file on your Mac, then upload it with the project.

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
ACCOUNT="<your-account>"     # PBS project/account
QUEUE="standard"
SETUP_CPUS=8
EQ_CPUS=8
EQ_GPUS=1
PROD_CPUS=8
PROD_GPUS=1
```

### Step 5: Validate

> **RUN ON THE HPC** — needs the cluster profile and (ideally) GROMACS present.

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

### Step 6: Submit

> **RUN ON THE HPC** — submits PBS jobs to the cluster.

```bash
bash gromacs-pipeline/run.sh submit projects/my_system
```

This:

1. Verifies the fingerprint (config unchanged since init)
2. Generates `scripts/setup.sh`, `scripts/equilibration.sh`, `scripts/production.sh`
3. Submits all 3 PBS jobs with `afterok` dependencies

### Step 7: Monitor

> **RUN ON THE HPC** — reads job state from the cluster.

```bash
bash gromacs-pipeline/run.sh status projects/my_system
```

### Step 8: Report

> **RUN ON THE HPC** — reads simulation outputs.

```bash
bash gromacs-pipeline/run.sh report projects/my_system
```

---

## Resume vs Restart

> **RUN ON THE HPC** — re-submitting, deleting outputs, and state re-init
> all happen on the HPC.

The pipeline is **idempotent** — every stage skips if its output already exists.
This means you can re-run `run.sh submit` safely; it only submits what's incomplete.

| Situation | What changed | Action |
|-----------|-------------|--------|
| **Resume** | Nothing, or only a bug fix in pipeline code / MDP | Just re-`submit` — completed stages are skipped, only incomplete ones re-run |
| **Resume after walltime** | Production hit walltime | Just re-`submit` — `mdrun -cpi` resumes from checkpoint automatically |
| **Restart** | Force field, `system.pdb`, or `config.sh` changed | `rm -rf output` then re-init + submit (below) |
| **Restart phase** | Only equilibration/production settings changed | Delete just that phase's dir then re-`submit` |

### Resume (recommended for MDP/code fixes)

```bash
# Just re-submit. Completed stages skip, incomplete ones run.
bash gromacs-pipeline/run.sh submit projects/my_system
```

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

### Golden rule

- **Code / MDP fix** → resume (just re-`submit`)
- **Force field / structure / config change** → restart (delete `output/`)

---

## Command Reference

### Where to run what

| Command | Runs where | Purpose |
|---------|-----------|---------|
| `setup/init.sh <project>` | **Local** | Create a project folder |
| `prep/prepare.sh` | **Local** | Produce `input/system.pdb` from raw model |
| `scp` / `rsync` | **Local** | Upload code/input to HPC |
| `get-ff.sh install <name>` | **HPC** | Copy force field from system GROMACS |
| `setup/validate.sh <project>` | **HPC** | Check project is ready |
| `run.sh submit <project>` | **HPC** | Submit 3 PBS jobs |
| `run.sh status <project>` | **HPC** | Check job state |
| `run.sh report <project>` | **HPC** | Generate completion report |
| `setup/replicate.sh <template> <base> <n>` | **HPC** | Clone template into n replicates |

### run.sh

| Command | Purpose |
|---------|---------|
| `run.sh submit <project>` | Submit all pipeline jobs |
| `run.sh submit --force <project>` | Submit (skip fingerprint check) |
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

## What Each Stage Does

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
| Production | `mdrun -maxh -cpi` (GPU, chunked loop) | → `md.xtc` |

---

## Force Field Discovery

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

## Production with Replicates

> **RUN ON THE HPC** — creates independent replicate projects from a local
> template, then submits them all in parallel.

Prepare ONE template project, then clone it into independent replicates:

```bash
# Prepare a template project fully (structure, config, force field)
# then create 3 replicates:
bash gromacs-pipeline/setup/replicate.sh projects/blm_cmyc blm_kras 3
# → projects/blm_kras_rep1, _rep2, _rep3

# Submit all in parallel (they run on different GPU nodes):
for p in projects/blm_kras_rep*; do
  bash gromacs-pipeline/run.sh submit "$p" &
done
wait
```

`setup/replicate.sh` copies the template (config, input, mdp, prep), sets a
unique `PROJECT` name per replicate, and reinitializes state/fingerprint so
each is fully independent. Set `PRODUCTION_NS=500` and `CHUNK_NS=50` in the
template first — each replicate then chains production chunks sequentially
while the 3 replicates run in parallel.

---

## Testing

```bash
# Unit tests (gmx.sh helper functions)
bash tests/unit.sh

# Integration tests (production loop)
bash tests/integration.sh

# Trajectory preparation tests
bash tests/test_prepare.sh
```

Uses `tests/bin/fake_gmx` to simulate GROMACS without a GPU.

---

## Trajectory Preparation

After production completes, prepare trajectories for visualization and analysis:

```bash
# Default: PBC correction + centering on Protein
bash gromacs-pipeline/post/prepare.sh projects/my_system

# With preset
bash gromacs-pipeline/post/prepare.sh projects/my_system --preset analysis

# With explicit options
bash gromacs-pipeline/post/prepare.sh projects/my_system \
    --center-on Protein --fit-to Backbone --keep Protein_DNA

# Force regeneration
bash gromacs-pipeline/post/prepare.sh projects/my_system --preset analysis --force
```

### Presets

| Preset | Effect |
|--------|--------|
| `visualization` | Center on Protein (default) |
| `analysis` | Center + fit to Backbone + keep Protein_DNA |
| `dry` | Center + keep Protein_DNA (remove solvent) |

### Generated files

All outputs go to `output/prepared/` (raw production files are never modified):

| File | When generated |
|------|----------------|
| `md_noPBC.xtc` | Always (PBC-corrected, centered) |
| `md_noPBC.gro` | Always (first frame) |
| `md_fitted.xtc` | With `--fit-to` |
| `md_<group>.xtc` | With `--keep` |
| `md_<group>.gro` | With `--keep` |

---

## Scientific Analysis

After trajectory preparation, use GROMACS tools for quality control and analysis. The MD Scientific Reasoning skill can orchestrate these analyses, interpret results, and answer scientific questions.

### Energy stability

Extract temperature, pressure, and energy from the energy file:

```bash
echo "Temperature" | gmx_mpi energy -f output/production/md.edr -o output/analysis/temperature.xvg
echo "Pressure" | gmx_mpi energy -f output/production/md.edr -o output/analysis/pressure.xvg
echo "Total-Energy" | gmx_mpi energy -f output/production/md.edr -o output/analysis/energy.xvg
```

### Structural stability (RMSD)

Compute backbone RMSD vs reference:

```bash
echo "Backbone" | gmx_mpi rms -s output/production/md.tpr -f output/prepared/md_noPBC.xtc -o output/analysis/rmsd.xvg
```

### Per-residue flexibility (RMSF)

Compute per-residue RMSF:

```bash
echo "Backbone" | gmx_mpi rmsf -s output/production/md.tpr -f output/prepared/md_noPBC.xtc -o output/analysis/rmsf.xvg
```

### Compactness (radius of gyration)

Compute radius of gyration:

```bash
echo "Protein" | gmx_mpi gyrate -s output/production/md.tpr -f output/prepared/md_noPBC.xtc -o output/analysis/gyrate.xvg
```

### Hydrogen bonds

Compute hydrogen bond occupancy:

```bash
echo "Protein Protein" | gmx_mpi hbond -s output/production/md.tpr -f output/prepared/md_noPBC.xtc -num output/analysis/hbond.xvg
```

### Secondary structure (DSSP)

Assign secondary structure over time:

```bash
echo "Protein" | gmx_mpi dssp -s output/production/md.tpr -f output/prepared/md_noPBC.xtc -o output/analysis/dssp.xvg
```

### COM distance

Compute center-of-mass distance between groups:

```bash
echo "Protein DNA" | gmx_mpi distance -s output/production/md.tpr -f output/prepared/md_noPBC.xtc -oall output/analysis/distance.xvg
```

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
| `Invalid atomtype format` | `._` files in force field. Run `find forcefields -name '._*' -delete` |
| `Residue type DT not found` | Partial FF missing dna.rtp. Run `get-ff.sh complete <name>` |
| `nstcomm < nstcalcenergy` | MDP missing nstcomm. Add `nstcomm=500` |
| NPT blows up / segfault | Parrinello-Rahman in equilibration. Use Berendsen NPT, PR production |

### Debugging a failure

1. Find the job log: `ls -t projects/<name>/*.o* | head -1`
2. `tail` it. **MPI_ABORT hides the real error** — the actual message is
   printed BEFORE the `----` separator. Read around it.
3. `grep -B2 -A5 'Fatal|Error|NOTE|WARNING' <log>`
4. Check the actual command that ran: `grep -A2 'Command line' <log>`

### Where logs go

PBS output goes to `projects/<name>/*.o<jobid>` (in the project root). Stage-level logs:

- `output/setup/*.log`
- `output/equilibration/*.log`
- `output/production/*.log`
