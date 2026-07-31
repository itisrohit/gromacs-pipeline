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

#### PDB Structural Validation

The following checks detect problems that cause pdb2gmx failures. Read the PDB and apply each check.

**Record integrity:**
- ATOM/HETATM records present — corrupt PDB crashes pdb2gmx
- No binary garbage or truncated lines — PDB lines should be ≤ 80 characters

**Chain IDs:**
- All ATOM records have a chain ID (column 22, character 21)
- No mixed empty/filled chain IDs (e.g., some residues chain A, others blank)
- No duplicate chain IDs for different polymer chains
- DNA chains use consistent naming (A/B vs 1/2 — pick one convention)

**Residue numbering:**
- No duplicate residue numbers within the same chain (seqid in columns 23-26)
- Insertion codes (column 27, letters after residue number) detected and reported — pdb2gmx handles them but topology may be unexpected
- Residue numbers are sequential (gaps > 10 indicate missing residues or numbering errors)

**Atom naming:**
- No duplicate atom names within the same residue (e.g., two "CA" atoms in one residue)
- Atom names follow PDB convention (columns 13-16, left-justified for elements)
- No atoms with empty names

**Alternate locations:**
- Column 22 (altLoc) must be empty or contain single conformations
- A/B alternates cause chain-type errors (Bug #9 in AGENTS.md)
- If altLoc present, report which residues have alternates and advise the user to resolve them (keep highest occupancy or merge)

**Backbone integrity:**
- Consecutive Cα atoms (protein) should be 3.2-3.8 Å apart
- Gaps > 5 Å between consecutive residues indicate broken backbone or missing residues
- Report any suspicious gaps with residue numbers

**Unsupported residues:**
- HETATM residues that are not standard amino acids, nucleic acids, water, or common ions (ZN, CA, MG, NA, K, CL, FE, CU, MN, CO, etc.)
- Report unrecognized residue names — these require custom topology files

**Hydrogen completeness:**
- If PDB has no hydrogen records (HYDROGEN/DUM), pdb2gmx with `-ignh` will add them — this is fine
- If PDB has partial hydrogen records, note this (pdb2gmx will regenerate them)

#### Ligand & Custom Topology Validation

When HETATM residues are detected in the PDB, classify them and validate topology readiness.

**Residue classification:**
- Water: HOH, SOL, WAT, TIP3, SPC — ignored by run_stage_prepare (stripped)
- Structural ions: ZN, CA, MG, NA, K, CL, FE, CU, MN, CO, etc. — must be in FF residuetypes.dat
- Ligands: any other HETATM residue — requires custom topology
- Unknown: unrecognized residue names — requires investigation

**Validation steps:**
1. List all unique HETATM residue names from PDB
2. Classify each as water / ion / ligand / unknown
3. For ions: verify the ion name exists in the FF's `residuetypes.dat`
4. For ligands: check if `EXTRA_ITPS` in config.sh references the required topology files
5. For ligands: verify each referenced `.itp` file exists at the specified path
6. For unknowns: report the residue name and advise the user to investigate

**EXTRA_ITPS validation:**
- If `EXTRA_ITPS` is set, split by spaces and verify each file exists
- If HETATM residues exist but `EXTRA_ITPS` is empty, warn that custom topologies may be needed
- If `EXTRA_ITPS` references files that don't exist, report error

**What the skill cannot do:**
- Generate topologies (requires ACPype, GAFF, antechamber, or manual parameterization)
- Validate topology correctness (requires running pdb2gmx)
- Determine partial charges or force field parameters

**Manual work the user must do for ligands:**
1. Generate topology: `antechamber -i ligand.mol2 -fi mol2 -o ligand.mol2 -fo mol2 -c bcc`
2. Or use ACPype: `acpype -i ligand.mol2 -a gaff2 -c bcc`
3. Place resulting `.itp` file in project and reference in `EXTRA_ITPS`
4. Add ligand to index file if needed

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

#### Resource Estimation

Estimate resource requirements from actual project inputs. All values are approximations.

**Atom count estimation:**
- Count ATOM/HETATM records in PDB (excluding water)
- Protein: ~15 atoms per residue (average)
- DNA/RNA: ~33 atoms per nucleotide
- Water: added by solvate, estimated from box volume
- Ions: ~1 per 50-100 water molecules (depending on SALT_CONC)

**Solvent size estimation:**
- Box volume ≈ (2 × protein_radius + 2 × BOX_DISTANCE)³ for cubic
- Dodecahedron: ~0.77 × cubic volume (23% fewer water molecules)
- Water density: ~55.5 mol/L = 3.34 × 10²⁸ molecules/m³
- Approximate water count: box_volume_nm³ × 33.4 (water molecules per nm³)

**Total atom count:**
- protein_atoms + water_atoms + ions_atoms
- Rule of thumb: solvated system is typically 3-10× the solute atom count

**Memory estimation (GPU):**
- PROD_MEM ≥ 0.02 GB per 1000 solvated atoms
- Example: 500k atoms → 10 GB minimum, recommend 16 GB
- EQ_MEM similar to PROD_MEM
- SETUP_MEM: 2-4 GB typically sufficient (CPU-only)

**Trajectory size estimation:**
- nstxout-compressed = 25000 with dt = 0.002 → 1 frame per 50 ps
- Total frames = PRODUCTION_NS × 1000 / 50 = PRODUCTION_NS × 20
- Frame size: atom_count × 3 coordinates × 4 bytes × ~0.5 compression ≈ atom_count × 6 bytes
- Total trajectory: frames × frame_size
- Example: 500k atoms, 100 ns → 2000 frames × 3 MB/frame = 600 MB

**Checkpoint storage:**
- Checkpoint size ≈ atom_count × 100 bytes (coordinates + velocities + forces)
- Example: 500k atoms → ~50 MB per checkpoint
- One checkpoint per chunk, one chunk per PROD_WALLTIME

**Disk usage estimation:**
- Trajectory: calculated above
- Checkpoints: 50 MB × chunks
- Logs: ~100 KB per ns
- Total: trajectory + checkpoints + 10% margin

**Runtime estimation (production):**
- From benchmark data: ns/day for the system size
- Interpolate from AGENTS.md benchmarks (39-43 ns/day for 75k atoms on A100)
- Scale: runtime ∝ atom_count^1.5 (approximate)
- Total production time = PRODUCTION_NS / ns_per_day

**CHUNK_NS validation:**
- Estimate ns/day from benchmarks and system size
- Calculate: chunk_runtime_hours = CHUNK_NS × 24 / ns_per_day
- Verify: chunk_runtime_hours < PROD_WALLTIME (convert to hours)
- If chunk exceeds walltime, the loop will hit walltime before reaching target — reduce CHUNK_NS

#### Project State Validation

Before submission, verify the project state is internally consistent.

**State file checks:**
- `.state/workflow.json` exists and is valid JSON
- `.state/fingerprint` exists and is non-empty

**State vs output consistency:**
- If phase status is "completed" but sentinel file is missing → state is stale, needs reset
- If phase status is "running" but no job ID → state is corrupted
- If phase status is "running" but output exists → mark completed
- Sentinel files: setup → `output/setup/ions.gro`, equilibration → `output/equilibration/npt.gro`, production → `output/production/PRODUCTION_COMPLETE`

**Fingerprint consistency:**
- Compute current fingerprint via `setup/fingerprint.sh --check`
- Compare with stored fingerprint in `.state/fingerprint`
- If mismatch: config/profile/MDP/PDB changed since initialization — user must reinitialize or use `--force`

**Stale state detection:**
- If `.state/workflow.json` says "running" for any phase but no corresponding job log exists in `output/logs/` → state is stale
- Advise user to reset state before submission

**Partial completion:**
- If setup completed but equilibration not started → normal (ready for equilibration)
- If equilibration completed but production not started → normal (ready for production)
- If production partially completed (checkpoint exists but no PRODUCTION_COMPLETE) → resumable

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

## Scientific Readiness Review

Before allowing submission, perform a final scientific review. Flag anything suspicious with reasoning.

**Box assessment:**
- BOX_DISTANCE < 0.8 nm: risky — solute interacts with periodic images, causing pressure instability
- BOX_DISTANCE > 1.5 nm: wasteful — excessive water molecules slow the simulation
- BOX_DISTANCE = 1.0 nm: standard, no action needed
- Box type dodecahedron: optimal for roughly spherical solutes
- Box type cubic: simpler but uses ~23% more water — only needed for anisotropic systems or NMR restraints

**Production length assessment:**
- < 50 ns: very short — suitable only for fast local motions (side-chain rotation, loop fluctuations)
- 50-100 ns: short — may be sufficient for well-folded proteins, insufficient for DNA-protein dynamics
- 100-500 ns: standard — appropriate for most systems
- 500-1000 ns: long — needed for large conformational changes, binding/unbinding
- > 1000 ns: very long — only with strong scientific justification
- Flag if production length doesn't match typical range for the system type

**MDP consistency review:**
- dt = 0.002 with constraints = h-bonds: correct
- dt = 0.004: requires hydrogen mass repartitioning — flag if not mentioned
- nstxout-compressed = 25000 (50 ps): standard for most analyses
- nstxout-compressed < 5000: dense trajectory — check if needed for the analysis
- nstxout-compressed > 50000: sparse — may miss fast events

**Output frequency assessment:**
- nstenergy = 5000 (10 ps): standard for stability monitoring
- nstlog = 5000 (10 ps): standard for diagnostics
- If nstenergy or nstlog > 50000: may miss energy drift

**Assumption check — flag these for the user:**
- Temperature: 300 K (standard, but user may want different)
- Pressure: 1 bar (standard, but user may want different)
- Water model: spce (standard with Amber FFs, but user may need tip3p/tip4p)
- Ensemble: NPT for production (standard, but some studies need NVT or NPT with different barostat)

**Risk assessment:**
- Risk level LOW: standard settings, no unusual choices
- Risk level MEDIUM: non-standard settings that are still valid (e.g., long production, dense trajectory)
- Risk level HIGH: settings likely to cause problems (BOX_DISTANCE < 0.8, insufficient memory, incompatible FF)
- For HIGH risk: block submission until user acknowledges the risk
- For MEDIUM risk: warn but allow submission

---

## Final Preparation Report

After all validation and reasoning, produce a readiness report. This is the final output before submission.

**Report format:**

```
═══════════════════════════════════════════════════════
  INPUT PREPARATION REPORT — <project_name>
═══════════════════════════════════════════════════════

SYSTEM SUMMARY
  Type:           protein / protein-DNA / protein-ligand
  Chains:         <count> (<list>)
  Residues:       <count>
  Atoms (solute): <count>
  Atoms (total):  <count> (estimated after solvation)

CONFIGURATION
  Force field:    <name> (<status: installed / not found>)
  Water model:    <name>
  Box type:       <type>
  Box distance:   <distance> nm
  Salt:           <concentration> M (<cation>/<anion>)

SIMULATION LENGTH
  Production:     <ns> ns
  Chunk size:     <ns> ns
  Total chunks:   <count> (estimated)

RESOURCES
  Setup:          <cpus> CPUs, <mem> memory, <walltime> walltime
  Equilibration:  <cpus> CPUs, <gpus> GPUs, <mem> memory, <walltime> walltime
  Production:     <cpus> CPUs, <gpus> GPUs, <mem> memory, <walltime> walltime

ESTIMATES (approximate)
  Trajectory size:   <size> GB
  Checkpoint size:   <size> MB per chunk
  Disk usage:        <size> GB total
  Production time:   <hours> hours (<days> days)
  ns/day:            <rate> (estimated from benchmarks)

VALIDATION STATUS
  ✅ / ❌ config.sh loads
  ✅ / ❌ Required variables set
  ✅ / ❌ Force field installed
  ✅ / ❌ Cluster profile exists
  ✅ / ❌ Input files valid
  ✅ / ❌ PDB structural integrity
  ✅ / ❌ FF compatibility
  ✅ / ❌ MDP consistency
  ✅ / ❌ Resource adequacy
  ✅ / ❌ State consistency

POTENTIAL RISKS
  - <risk 1: explanation>
  - <risk 2: explanation>

RECOMMENDATIONS
  - <recommendation 1: explanation>
  - <recommendation 2: explanation>

───────────────────────────────────────────────────────
  DECISION: READY / NOT READY
───────────────────────────────────────────────────────

  If READY: run `bash gromacs-pipeline/run.sh submit <project>`
  If NOT READY: address the issues above before submission.
═══════════════════════════════════════════════════════
```

**Decision logic:**
- READY: all validation checks pass, no HIGH risk items, user has confirmed recommendations
- NOT READY: any validation check fails, or HIGH risk items not acknowledged

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
