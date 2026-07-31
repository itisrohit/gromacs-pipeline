# Playbook: Input Preparation & Verification

Operational knowledge for the input preparation skill. This document contains everything the skill needs to reason about inputs, validate readiness, and recommend improvements.

The repository is the source of truth. This document references repository behaviour — it does not reimplement it.

---

## Repository Structure

```
gromacs-pipeline/
├── run.sh                     # submit, status, report (NOT this skill)
├── lib/
│   ├── gmx.sh                 # GROMACS discovery, GPU flags, checkpoint reading
│   ├── scheduler.sh           # Job submission (PBS/Slurm/LSF)
│   ├── stages.sh              # All stage functions (NOT this skill)
│   └── state.sh               # Workflow state management
├── setup/
│   ├── init.sh                # Create project structure (THIS SKILL)
│   ├── validate.sh            # Check config, FF, profile, MDPs (THIS SKILL)
│   ├── fingerprint.sh         # Compute SHA256 hash (called by init.sh)
│   ├── state.sh               # Initialize workflow.json (called by init.sh)
│   ├── replicate.sh           # Create N replicate projects (THIS SKILL)
│   ├── doctor.sh              # Check HPC environment (THIS SKILL)
│   └── templates/
│       └── config.sh          # Default configuration template
├── profiles/
│   ├── iitd.sh                # IITD HPC (PBS, A100/V100 GPUs)
│   ├── generic-pbs.sh         # Generic PBS
│   ├── generic-slurm.sh       # Generic Slurm
│   └── generic-lsf.sh         # Generic LSF
├── mdp/
│   ├── em.mdp                 # Energy minimization (maxwarn 0)
│   ├── nvt.mdp                # Temperature equilibration (100 ps)
│   ├── npt.mdp                # Pressure equilibration (1 ns, Berendsen)
│   └── md.mdp                 # Production (nsteps=-1, Parrinello-Rahman)
├── forcefields/
│   ├── get-ff.sh              # Install, complete, check force fields (THIS SKILL)
│   └── .gitkeep
└── .agent/skills/input-preparation/
    ├── SKILL.md               # Entry point
    ├── workflow.md             # How the agent thinks
    └── playbook.md            # This file
```

---

## Scripts This Skill Executes

### setup/init.sh `<project>`

Creates a new project.

**Consumes:** `setup/templates/config.sh`, `mdp/*.mdp`
**Generates:**
- `config.sh` (copy of template)
- `mdp/*.mdp` (copy of pipeline defaults)
- `.state/workflow.json` (all phases pending)
- `.state/fingerprint` (SHA256 of config + profile + MDPs + PDB)
- Directories: `input/`, `output/{setup,equilibration,production,logs,reports}/`, `scripts/`

**Idempotent:** Refuses to run if `config.sh` already exists.

### setup/validate.sh `<project>`

Validates all inputs.

**Consumes:** `config.sh` (sources it), `FORCEFIELD` directory, `profiles/$CLUSTER.sh`, PDB file, MDP files
**Generates:** stdout report with errors/warnings

**Checks performed:**
1. config.sh exists and loads
2. Required variables set: PROJECT, PDB, FORCEFIELD, WATER_MODEL, BOX_TYPE, PRODUCTION_NS, CLUSTER, EM_MDP, NVT_MDP, NPT_MDP, MD_MDP
3. Force field found (searches 4 paths: project dir, pipeline forcefields, $GMXLIB, system GROMACS top)
4. Cluster profile exists
5. Input files exist and are non-empty
6. PRODUCTION_NS >= CHUNK_NS
7. BOX_DISTANCE is numeric
8. SALT_CONC is numeric
9. Walltime format HH:MM:SS
10. Resource values > 0

**Exit code:** 0 = pass, 1 = errors found

### forcefields/get-ff.sh `install <name>`

Installs a force field from system GROMACS.

**Consumes:** System GROMACS installation (`share/gromacs/top/<name>.ff/`)
**Generates:** `forcefields/<name>.ff/` directory with `forcefield.itp`

**Also copies shared files:** dna.rtp, rna.rtp, residuetypes.dat, etc. (missing from partial installs)

### setup/replicate.sh `<template> <base> <count>`

Creates N independent replicate projects.

**Consumes:** Template project with `config.sh` and `input/system.pdb`
**Generates:** `<base>_rep1/` through `<base>_repN/` (independent copies)

### setup/doctor.sh

Checks HPC environment readiness.

**Checks:** Scheduler (PBS/Slurm/LSF), GROMACS availability, module system, filesystem writability, disk space.

---

## Scripts This Skill Must NEVER Execute

| Script | Why |
|--------|-----|
| `run.sh submit` | Execution stage — submits PBS jobs |
| `run.sh status` | Monitoring stage — checks job status |
| `lib/stages.sh` | Execution stage — runs GROMACS commands |
| `lib/gmx.sh` | Execution stage — GROMACS discovery |
| `lib/scheduler.sh` | Execution stage — job submission |
| `lib/state.sh` | Execution stage — workflow state during runs |

---

## Configuration Relationships

### Required Variables (validate.sh checks these)

| Variable | Purpose | Constraints |
|----------|---------|-------------|
| PROJECT | Label for status/reports | Any string |
| PDB | Input structure path | Must exist, non-empty, ATOM records |
| FORCEFIELD | Physics model name | Must be installed, must support PDB residues |
| WATER_MODEL | Water model | Must exist in force field |
| BOX_TYPE | Simulation cell shape | dodecahedron (default) or cubic |
| PRODUCTION_NS | Total production length (ns) | Must be >= CHUNK_NS |
| CLUSTER | HPC cluster name | Must match a profile in profiles/ |
| EM_MDP | Energy minimization MDP | Must exist, non-empty |
| NVT_MDP | NVT equilibration MDP | Must exist, non-empty |
| NPT_MDP | NPT equilibration MDP | Must exist, non-empty |
| MD_MDP | Production MDP | Must exist, non-empty |

### Resource Variables

| Variable | Purpose | Constraints |
|----------|---------|-------------|
| SETUP_CPUS | CPU cores for setup | > 0 |
| SETUP_MEM | Memory for setup | Valid memory string |
| SETUP_WALLTIME | Walltime for setup | HH:MM:SS format |
| EQ_CPUS | CPU threads for equilibration | > 0 |
| EQ_GPUS | GPUs for equilibration | >= 1 (GPU required) |
| EQ_MEM | Memory for equilibration | Valid memory string |
| EQ_WALLTIME | Walltime for equilibration | HH:MM:SS, must fit EM+NVT+NPT |
| PROD_CPUS | CPU threads for production | > 0 |
| PROD_GPUS | GPUs for production | >= 1 (GPU required) |
| PROD_MEM | Memory for production | Valid memory string |
| PROD_WALLTIME | Walltime per production job | HH:MM:SS, cluster max applies |

### Scheduler Variables

| Variable | Purpose | Constraints |
|----------|---------|-------------|
| ACCOUNT | PBS project for billing | Non-empty for PBS clusters |
| QUEUE | Scheduler queue | standard or high (IITD) |

### Derived Values (skill reasons about these)

| Value | How derived | Why it matters |
|-------|-------------|----------------|
| CHUNK_NS | Must fit in PROD_WALLTIME at estimated ns/day | Chunk too large = never completes |
| Memory | ~0.02 GB per 1000 atoms (GPU) | OOM kills the job |
| System type | From PDB residue names | Determines FF recommendation, production length |

---

## Validation Knowledge

The deterministic checks listed in "Checks performed" under `setup/validate.sh` above are handled by the script. Do not duplicate them.

The following require domain reasoning that `validate.sh` cannot perform:

#### PDB Quality

- **ATOM/HETATM records present**: Corrupt PDB crashes pdb2gmx
- **AltLoc column clean**: Column 22 with A/B causes chain-type errors (Bug #9 in AGENTS.md)
- **Residue names standard**: Unknown residues crash pdb2gmx

#### Force Field Compatibility

- **FF supports PDB residues**: Cross-reference PDB residue names against FF residue types. DNA in amber14sb = fail.
- **FF has dna.rtp**: If PDB contains DNA (DA, DC, DG, DT residues), FF must have dna.rtp. amber14sb often missing it. Fix: `get-ff.sh complete <name>`
- **FF has rna.rtp**: Same for RNA residues.
- **WATER_MODEL in FF**: spce is standard with Amber FFs. Verify it exists in the FF directory.
- **CATION/ANION in FF**: K+, Cl-, Na+ must be in residuetypes.dat. Check FF directory.

#### MDP Physics Consistency

- **npt.mdp: pcoupl = Berendsen**: Parrinello-Rahman during equilibration causes pressure instability and box collapse (Bug #15). The MDP comments explain this.
- **md.mdp: pcoupl = Parrinello-Rahman**: Berendsen does not produce correct NPT ensemble for production.
- **md.mdp: nsteps = -1**: Required for checkpoint-based chunking. Finite nsteps breaks the extend-from-checkpoint loop.
- **nstcomm matches nstcalcenergy**: Mismatch causes extra GPU-CPU synchronization (Bug #11).

#### Resource Adequacy

- **PROD_MEM for system size**: ~0.02 GB per 1000 atoms on GPU. 700k atoms needs ~14GB.
- **CHUNK_NS fits in PROD_WALLTIME**: Estimate ns/day from benchmarks, verify chunk completes within walltime.
- **EQ_WALLTIME fits EM+NVT+NPT**: EM ~5-10 min, NVT 100 ps ~8 min, NPT 1 ns ~70 min (V100). Total ~90 min.
- **SETUP_WALLTIME adequate**: Setup ~2-3 min for typical systems. Large systems may need more.

---

## Decision Rules

### Force Field Selection

| System type | Recommended FF | Why |
|-------------|---------------|-----|
| Protein only | amber14sb or amber99sb-ildn | Standard for protein MD |
| Protein + DNA | amber99sb-ildn | Complete DNA support, validated for protein-DNA |
| Protein + RNA | amber99sb-ildn | RNA support |
| Protein + ligand | Depends on ligand | May need custom topology |

Always verify the FF has dna.rtp/rna.rtp if the PDB contains nucleic acids.

### Production Length Guidance

| System type | Typical range | Why |
|-------------|--------------|-----|
| Protein only | 100-500 ns | Convergence depends on flexibility |
| Protein + DNA | 100-500 ns | DNA-protein interfaces need long sampling |
| Protein + ligand | 100-1000 ns | Binding/unbinding kinetics |

### Resource Estimation

| System size | CPUs | GPUs | Memory | EQ walltime | Prod walltime |
|-------------|------|------|--------|-------------|---------------|
| < 50k atoms | 8 | 1 | 8GB | 1h | 24h |
| 50-200k atoms | 8 | 1 | 16GB | 2h | 24h |
| 200-500k atoms | 8 | 1 | 16GB | 2h | 24h |
| 500k-1M atoms | 8 | 1 | 32GB | 3h | 24h |
| > 1M atoms | 16 | 1-2 | 64GB | 4h | 24h |

---

## Common Failure Modes

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| pdb2gmx hangs | Interactive terminal selection | Use `-noter` flag |
| `Residue type DT not found` | FF missing dna.rtp | `get-ff.sh complete <name>` |
| `Invalid atomtype format` | `._` files in force field directory | Delete them: `find forcefields -name '._*' -delete` |
| grompp aborts on warning | MDP physics mismatch | Check pcoupl, nsteps, nstcomm |
| NPT blows up / segfault | Parrinello-Rahman in equilibration | Use Berendsen for NPT equilibration |
| genion fails | CATION/ANION not in FF | Check FF residuetypes.dat |
| solvate fails | WATER_MODEL not in FF | Check FF directory for water model |
| Job OOM killed | Memory too low for system size | Increase PROD_MEM |
| Production over-runs chunk | Old bug (fixed in current code) | Deploy current lib/stages.sh |

---

## Known Gotchas

1. **`._` files break GROMACS**: macOS tar creates `._` files in force field directories. Delete them before deploying to HPC.

2. **PDB altLoc column**: Column 22 must be empty or contain single conformations. A/B alternates cause pdb2gmx chain-type errors.

3. **amber14sb is protein-only**: Does not include DNA/RNA parameters. For protein-DNA systems, use amber99sb-ildn.

4. **Berendsen vs Parrinello-Rahman**: Berendsen for equilibration (stable), PR for production (correct ensemble). Never swap.

5. **nsteps=-1 is mandatory**: Production uses `-maxh` for chunking. Finite nsteps breaks the extend-from-checkpoint loop.

6. **nstcomm must match nstcalcenergy**: Mismatch causes extra GPU-CPU synchronization overhead.

7. **CHUNK_NS must fit in PROD_WALLTIME**: If chunk is too large, the target is never reached within a single job.

8. **EQ_GPUS and PROD_GPUS must be >= 1**: Equilibration and production require GPU. CPU-only would be orders of magnitude slower.

---

## Readiness Criteria

The execution stage (`run.sh submit`) requires all of the following:

| Criterion | Verification |
|-----------|-------------|
| `config.sh` exists and loads | `source config.sh` succeeds |
| All required variables set | `validate.sh` reports 0 errors |
| `input/system.pdb` exists, non-empty, GROMACS-ready | File check + PDB inspection |
| `mdp/*.mdp` exist and non-empty | File check |
| Force field installed with `forcefield.itp` | `find_forcefield` succeeds |
| Cluster profile exists | File check |
| `.state/workflow.json` exists | File check |
| `.state/fingerprint` exists and matches | `state_verify_fingerprint` succeeds |
| User confirmed all recommendations | Explicit approval |

---

## Benchmark Evidence

Results from job 968167 (A100, BLM-cMYC 75k atoms):

| Config | ns/day | hour/ns | LINCS | Recommendation |
|--------|--------|---------|-------|----------------|
| baseline (nst400/vbt002/nce500) | 39.259 | 0.611 | 0 | Reference |
| nstlist=100 | 43.469 | 0.552 | 0 | **ADOPT** (+10.7%) |
| vbt=0.005 | 41.775 | 0.575 | 0 | **ADOPT** (+6.4%) |
| nstlist=40 | 39.661 | 0.605 | 0 | Negligible (+1.0%) |
| nce=1000 | 39.181 | 0.613 | 0 | DO NOT adopt (-0.2%) |
| Berendsen NPT | 39.678 | 0.605 | 0 | Keep for equilibration |
| C-rescale NPT | grompp FAILED | — | — | Fixed MDP, needs clean run |

Combined nstlist=100 + vbt=0.005: Job 968312 running. Estimated ~17% speedup.
