# AGENTS.md — GROMACS HPC Pipeline Work Pattern

This file tells any agent/assistant exactly how this project works, how to
operate it on the IITD HPC, and the full pattern used to develop, deploy,
debug, and validate it. Read this first if you lost context.

---

## Repository Philosophy

This repository follows a script-first, AI-assisted design inspired by Max Iskiev's approach to AI-assisted software development.

Core principles:

- The repository is the primary source of truth. Reuse existing repository capabilities before creating new ones.
- Prefer deterministic, reproducible Bash workflows over hidden automation.
- AI assists with reasoning, validation, documentation, and orchestration, but should not invent repository behaviour.
- Commands, workflows, and operational procedures must be verified before execution rather than generated from memory.
- Operational knowledge belongs in dedicated AI skills. The repository implements workflows; the skills explain how to reason about them.
- Preserve reproducibility, portability, and resumability across all changes.
- When extending the repository, prefer improving existing workflows over introducing new scripts or duplicate functionality.
- AGENTS.md captures institutional knowledge and development practices. README.md is for end users. Skills capture structured operational reasoning.

---

## Project purpose (the final aim)

Build a **generic, reusable, Bash-only GROMACS MD pipeline** that:

- Works **end-to-end** for **any biomolecular input** (protein, protein–DNA,
  protein–RNA, protein–ligand) with no project-specific code in the pipeline.
- Runs on **any HPC cluster** (PBS) via cluster profiles.
- Is portable, reproducible, and resumable (checkpoint-aware).
- User supplies only `input/system.pdb` + `config.sh`. Everything else is
  GROMACS + the pipeline.

**For users**: point them to `README.md` (usage, quick start, command reference).

**For agents**: this file documents the *development/ops* workflow, the
known pitfalls, and how to get an end-to-end run working.

---

## CURRENT STATUS — READ THIS FIRST (as of the last session)

**Phase**: PRODUCTION READY ✅. Engineering validation complete (Level 1 + Level 2). BLM-cMYC 500 ns × 3 replicates ready to submit.

### Recent fixes (committed)
1. **TPR filename mismatch** (`df3012e`): `convert-tpr -o md.tpr.tmp` created `md.tpr.tmp.tpr` (GROMACS appends `.tpr`). Fixed to use `md.tpr.tmp.tpr` consistently. Validated on HPC with real GROMACS.
2. **fake_gmx awk field index** (`1d1c37e`): `convert-tpr` writes `target = value` (3 fields), but mdrun awk read `$2` (`=`) instead of `$3` (value). Fixed. Integration tests: 17/18 pass.
3. **Trajectory preparation** (`0a89774`): Added `post/prepare.sh` for PBC correction, centering, fitting, stripping. Tested on HPC with real production trajectory. Refactored: removed dead code, extracted `get_group_number()` helper.
4. **AGENTS.md updates** (`26100f9`): Added validation hierarchy (Level 1/2/3), operational commands, post-Level-1 roadmap, verified HPC status.

### Key HPC learnings this session (IMPORTANT)
- **Target node = A100 (`aice*`, `centos=icelake`).** This is the ONLY acceptable GPU class — the user's hard requirement.
- **haswell (`khas*`, e.g. khas002) nodes are BROKEN/slow — do NOT use.** Job 968587 landed there (submitted without `centos=icelake`); it runs but on the wrong hardware. Kill + resubmit with A100 constraint.
- **A100 nodes are congested** — `centos=icelake` GPU jobs queue and wait. Accept the queue wait; do NOT fall back to haswell/skylake.
- Job 968584 failed with `Compatible GPUs must have been found` — submitted WITHOUT `-l select=...:ngpus=1` (no GPU resource request).
- Job 968585 queued long with `centos=icelake` (A100 busy), killed manually.
- **CHUNK_NS must fit walltime:** 0.1 ns (100 ps) needs ~197s at 43.7 ns/day but PROD_WALLTIME=150s → job killed mid-chunk. Reduced CHUNK_NS=0.05 (50 ps, ~115s).
- Correct A100 submission: `qsub -P helicases.spons -l select=1:ncpus=8:ngpus=1:centos=icelake -l walltime=00:02:30 ...`

### Production chunking (IMPLEMENTED, DEPLOYED, VALIDATED)
The extend-from-checkpoint loop is in `lib/stages.sh:run_stage_production()`.
Local tests: 20/20 unit, 17/18 integration (1 pre-existing test logic issue — see Test 7 below).

What changed:
- `checkpoint_time_ps()` in `lib/gmx.sh` reads time via `gmx dump -cp` (primary) or `gmx check` (fallback)
- `run_stage_production()` loops: read checkpoint → compute target → convert-tpr -until → mdrun -cpi → check progress
- Atomic TPR replacement: `convert-tpr -o md.tpr.tmp.tpr` then `mv md.tpr.tmp.tpr md.tpr` (GROMACS appends `.tpr`)
- Post-convert-tpr file existence validation (safety net beyond exit code)
- Stale lock recovery: PID-based staleness check in mkdir fallback
- `run.sh` submits ONE production job (no more N-chunk chain), marker-based completion
- `-nsteps -1` REMOVED from mdrun (was overriding convert-tpr target)
- All `$GMX` calls quoted for paths with spaces

### Benchmark results (COMPLETE — jobs 968167 + 968361 on HPC A100)
See `~/simulations/bench/benchmark_summary.log` on HPC.

| Config | ns/day | hour/ns | LINCS | Notes |
|--------|--------|---------|-------|-------|
| baseline (nst400/vbt002/nce500) | 39.259 | 0.611 | 0 | |
| nstlist=100 | 43.469 | 0.552 | 0 | **ADOPT** (+10.7%) |
| vbt=0.005 | 41.775 | 0.575 | 0 | **ADOPT** (+6.4%) |
| nstlist=40 | 39.661 | 0.605 | 0 | Negligible |
| nce=1000 | 39.181 | 0.613 | 0 | Negligible |
| Berendsen NPT | 39.678 | 0.605 | 0 | Keep for equilibration |
| C-rescale NPT | 28.196 | 0.851 | 0 | Ran with 1 thread (INVALID) |
| combined nst100+vbt005 | 25.921 | 0.926 | 0 | Ran with 1 thread (INVALID) |

**Combined + C-rescale results are INVALID** — both ran with 1 OpenMP thread instead of 8. Re-run needed with `export OMP_NUM_THREADS=8`.

**Recommendation**: nstlist=100 + vbt=0.005. Re-run combined benchmark with correct threading to confirm.

### HPC validation status (BLM-cMYC 1ns)
- Setup ✅, EM ✅, NVT ✅, NPT ✅ (Berendsen)
- **Production walltime-interruption validation: COMPLETE** ✅
  - Job 968472 ran on A100 (aice001), 5-min walltime
  - Completed 137.2 ps (step 68600), wrote checkpoint, exited gracefully
  - Performance: 44.2 ns/day
  - Production loop correctly detected walltime exhaustion and exited

### Validation hierarchy

Validation occurs in three levels.

```
Level 1: Single-Replicate Engineering Validation (historical — superseded by Level 2)
    ↓
Level 2: Multi-Replicate Engineering Validation (n=3) ✅ COMPLETE
    ↓
Level 3: Scientific Reproducibility Considerations
```

---

#### Level 1 — Single-Replicate Engineering Validation (historical)

**Status:** Superseded by Level 2. Historical validation run paused at 236.4 ps. Not required for production readiness.

**What it validated:**
- Checkpoint creation and reading
- Checkpoint resume after interruption
- convert-tpr extension with correct target
- Target calculation (min of chunk + current, production limit)
- Repeated production extension (multiple chunks per job)
- Production completion detection
- PRODUCTION_COMPLETE marker creation
- Idempotent re-submission after completion

**Why superseded:** Level 2 completed all Level 1 requirements for 3 independent replicates (0→500 ps via ~10 chunks each). Level 2 evidence is redundant, not missing.

---

#### Level 2 — Multi-Replicate Engineering Validation (n=3) ✅ COMPLETE

**Purpose:** Validate that the chaining logic operates correctly for multiple independent replicates.

**What it validates:**
- Chaining algorithm (checkpoint → convert-tpr → mdrun → checkpoint)
- Checkpoint resume after interruption
- convert-tpr extension with correct target
- Target calculation (min of chunk + current, production limit)
- Repeated production extension (multiple chunks per job)
- Production completion detection
- PRODUCTION_COMPLETE marker creation
- Idempotent re-submission after completion
- Replicate isolation (separate directories)
- Independent workflow state (separate .state/)
- Independent checkpoints (separate md.cpt)
- Independent trajectories (separate md.xtc)
- Independent completion markers (separate PRODUCTION_COMPLETE)
- Orchestration correctness (parallel submission)

**Current status:** COMPLETE ✅ — All 3 replicates reached 500 ps. Isolation verified. Idempotent re-runs validated.

**Level 2 replicates (BLM-KRAS val):**
| Replicate | Status | Checkpoint | xtc md5 | cpt md5 |
|-----------|--------|------------|---------|---------|
| blm_kras_val_rep1 | ✅ COMPLETE | 500 ps | f4c2383c | bb9ec167 |
| blm_kras_val_rep2 | ✅ COMPLETE | 500 ps | 2d82c445 | 54fcab5f |
| blm_kras_val_rep3 | ✅ COMPLETE | 500 ps | d225e6af | cfa99749 |

**Validation results:**
- ✅ All 3 PRODUCTION_COMPLETE markers exist
- ✅ All 3 xtc md5 hashes DIFFERENT (independent trajectories)
- ✅ All 3 cpt md5 hashes DIFFERENT (independent checkpoints)
- ✅ All 3 workflow.json show production=completed
- ✅ Idempotent re-run on all 3: detected completion, submitted nothing
- ✅ No cross-replicate contamination
- ✅ Checkpoint chaining worked for every replicate (0→500 ps via ~10 chunks each)

**This validation proves:** The repository correctly manages multiple independent simulations.

---

#### Level 3 — Scientific Reproducibility Considerations

**Prerequisite:** Level 2 must have passed.

**Purpose:** Document what repository validation does NOT prove scientifically.

**This is NOT repository validation.** These are scientific considerations for production runs.

**What repository validation proves:**
- Replicates are isolated
- Replicates run independently
- Replicates complete independently

**What repository validation does NOT prove:**
- Statistical independence of trajectories
- Correct ensemble sampling
- Physical accuracy of simulation

**Scientific considerations:**
- Stochastic initialization: `gen_seed = -1` in NVT MDP uses time-based automatic seed selection (official GROMACS behaviour)
- Velocity generation: Velocities generated from time-dependent seed during NVT equilibration
- Thermostat: v-rescale applies stochastic velocity rescaling (official GROMACS behaviour)
- Barostat: Parrinello-Rahman introduces stochastic fluctuations (official GROMACS behaviour)
- Controlled variables: FORCEFIELD, topology, MDP, production length, chunk size, walltime, temperature, pressure
- Variable components: Project identity, output directory, checkpoint history, stochastic initialization, resulting trajectory

**Repository validation does NOT claim to verify scientific reproducibility.**

### Current operational status

**What we are doing right now:** PRODUCTION READY ✅. Engineering validation complete. Ready to submit BLM-cMYC 500 ns × 3 replicates.

**Production configuration:**
- PRODUCTION_NS=500 (500 ns per replicate)
- CHUNK_NS=50 (50 ns per chunk)
- PROD_WALLTIME="24:00:00" (24h per PBS job)
- Expected: ~13 jobs per replicate, ~39 total
- Expected runtime: ~13 days per replicate (with A100 congestion: ~20-30 days)
- Expected storage: ~29 GB per replicate, ~87 GB total

**Production submission command:**
```bash
# Create replicates
cd ~/simulations
bash gromacs-pipeline/setup/replicate.sh projects/blm_cmyc blm_cmyc_prod 3

# Copy setup + equilibration outputs
for p in projects/blm_cmyc_prod_rep*; do
    mkdir -p $p/output/setup $p/output/equilibration
    cp -a projects/blm_cmyc/output/setup/* $p/output/setup/
    cp -a projects/blm_cmyc/output/equilibration/* $p/output/equilibration/
done

# Update config for 500 ns production
for p in projects/blm_cmyc_prod_rep*; do
    sed -i 's/^PRODUCTION_NS=.*/PRODUCTION_NS=500/' "$p/config.sh"
    sed -i 's/^CHUNK_NS=.*/CHUNK_NS=50/' "$p/config.sh"
    sed -i 's/^PROD_WALLTIME=.*/PROD_WALLTIME="24:00:00"/' "$p/config.sh"
done

# Update workflow state
for p in projects/blm_cmyc_prod_rep*; do
    cat > $p/.state/workflow.json << STATE
{
  "schema_version": 1,
  "project": "$(basename $p)",
  "initialized": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phases": {
    "setup": {"status": "completed", "job_id": ""},
    "equilibration": {"status": "completed", "job_id": ""},
    "production": {"status": "pending", "job_id": ""}
  }
}
STATE
done

# Submit all 3 in parallel
for p in projects/blm_cmyc_prod_rep*; do
    bash gromacs-pipeline/run.sh submit --force "$p" &
done
wait
```

**Resubmission command (per replicate):**
```bash
cd ~/simulations/projects/<replicate_name>
qsub -P helicases.spons -l select=1:ncpus=8:ngpus=1:centos=icelake \
     -l walltime=24:00:00 \
     -v PROJECT_DIR=$(pwd) \
     scripts/production.sh
```

**To check status:**
```bash
qstat -u <user>
ls -la ~/simulations/projects/blm_cmyc/output/production/
tail -5 ~/simulations/projects/blm_cmyc/output/production/md.log
```

**After job completes, verify:**
```bash
# Check checkpoint time increased
gmx_mpi dump -cp output/production/md.cpt 2>/dev/null | grep "^t ="

# Check if PRODUCTION_COMPLETE exists
ls output/production/PRODUCTION_COMPLETE

# If not complete, re-submit on A100 ONLY (never drop centos=icelake)
cd ~/simulations/projects/blm_cmyc
qsub -P helicases.spons -l select=1:ncpus=8:ngpus=1:centos=icelake \
     -l walltime=00:02:30 \
     -v PROJECT_DIR=/home/bioschool/phd/blz208818/simulations/projects/blm_cmyc \
     scripts/production.sh
```

### After Level 2 passes — real production

Once Level 2 validation completes (3 replicates independent):

**Step 1: Update config for 500 ns production**
```bash
for p in projects/blm_kras_val_rep*; do
    sed -i 's/^PRODUCTION_NS=.*/PRODUCTION_NS=500/' "$p/config.sh"
    sed -i 's/^CHUNK_NS=.*/CHUNK_NS=50/' "$p/config.sh"
    sed -i 's/^PROD_WALLTIME=.*/PROD_WALLTIME="24:00:00"/' "$p/config.sh"
done
```

**Step 2: Reset state and submit**
```bash
for p in projects/blm_kras_val_rep*; do
    # Reset state to pending
    cat > "$p/.state/workflow.json" << STATE
{
  "schema_version": 1,
  "project": "$(basename $p)",
  "initialized": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phases": {
    "setup": {"status": "completed", "job_id": ""},
    "equilibration": {"status": "completed", "job_id": ""},
    "production": {"status": "pending", "job_id": ""}
  }
}
STATE
done

# Submit all 3 in parallel
for p in projects/blm_kras_val_rep*; do
    bash gromacs-pipeline/run.sh submit --force "$p" &
done
wait
```

**Step 3: Monitor**
```bash
# Check all replicates
for p in projects/blm_kras_val_rep*; do
    echo "$(basename $p): $(qstat -u blz208818 | grep production | wc -l) jobs running"
done
```

### Validation matrix

| Stage | BLM-cMYC (protein-DNA) | Protein-only | Protein-RNA | Protein-ligand | Membrane |
|-------|------------------------|--------------|-------------|----------------|----------|
| Setup (pdb2gmx → index) | ✅ Validated | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested |
| EM | ✅ Validated | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested |
| NVT | ✅ Validated | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested |
| NPT (Berendsen) | ✅ Validated | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested |
| Production (chunking) | ✅ Validated (500 ps) | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested |
| Walltime interruption | ✅ Validated | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested |
| Trajectory preparation | ✅ Validated | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested |
| Full pipeline (setup→eq→prod→prep) | ⚠️ Not tested end-to-end | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested |
| Replicates (setup/replicate.sh) | ✅ Validated (Level 2 complete) | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested | ⚠️ Not tested |

**Tested systems:** BLM-cMYC (697k atoms, protein-DNA, amber99sb-ildn, spce water)
**Not tested:** Protein-only, protein-RNA, protein-ligand, membrane systems, different force fields, different water models

---

## Repository layout (local)

```
gromacs-pipeline/          # the pipeline tool (reusable code only)
├── run.sh                 # submit/status/report
├── lib/                   # gmx.sh, scheduler.sh, stages.sh, state.sh
├── setup/                 # init.sh, validate.sh, replicate.sh, state.sh,
│   │                      # fingerprint.sh, templates/config.sh
├── post/                  # prepare.sh (trajectory preparation)
├── profiles/              # iitd.sh, generic-pbs.sh, generic-slurm.sh, generic-lsf.sh
├── mdp/                   # em.mdp, nvt.mdp, npt.mdp, md.mdp
├── forcefields/           # get-ff.sh + installed force fields
├── tests/                 # unit.sh, integration.sh, test_prepare.sh, fake_gmx
├── README.md              # USER documentation
└── AGENTS.md              # THIS FILE (agent operations)
```

Projects live OUTSIDE the pipeline:
```
projects/<name>/
├── config.sh              # project settings (FORCEFIELD, lengths, resources)
├── input/system.pdb       # the only structure input
├── prep/prepare.sh        # project-specific structure prep (NOT pipeline)
├── mdp/                   # copied from pipeline (editable)
├── output/{setup,equilibration,production,prepared,logs}/
├── .state/                # workflow.json, fingerprint
└── scripts/               # generated job scripts
```

---

## The HPC environment (IITD)

- Login: `ssh <user>@<hpc-host>` (password in secure storage, only in expect)
- Login nodes: login07/08 — file mgmt + job submission only
- Scheduler: **PBS** (`qsub`). Project: `helicases.spons`. Queue: `standard`/`high`
- GROMACS: `module load apps/gromacs/2023.2/gnu` → `gmx_mpi`
- Node types: `csky*` CPU, `vsky*` V100 GPU, `aice*` A100 GPU (`centos=icelake`), `khas*` haswell GPU (**broken/slow — AVOID**), `cice*` icelake CPU
- **A100 (`centos=icelake`) is the ONLY GPU class to use** — haswell/skylake GPU nodes are broken/slow
- Pipeline on HPC: `~/simulations/gromacs-pipeline/`
- Projects on HPC: `~/simulations/projects/<name>/`

---

## SSH / command pattern

```bash
expect << 'EOF'
set timeout 60
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    <user>@<hpc-host> "COMMANDS..."
expect "password:"
send "<password>\r"
expect eof
EOF
```

Gotchas:
- `expect` interprets `[0-9]`, `{`, `}`, `(`, `)` etc. in the command string.
  Use simple commands or upload a `.sh` script file to avoid escaping hell.
- The login node is often slow — use generous timeouts (30-60s), and if SSH
  times out, retry with a shorter, simpler command.

---

## Deploy code to HPC (upload pattern)

The code lives in the LOCAL git repo. Every change must be deployed to the
HPC before it takes effect:

```bash
# 1. Local: syntax check
bash -n gromacs-pipeline/lib/stages.sh

# 2. Local: copy changed files into the upload package
cp <file> /tmp/hpc-upload/gromacs-pipeline/<path>/
cd /tmp && tar czf hpc-upload.tar.gz hpc-upload/

# 3. Upload
scp /tmp/hpc-upload.tar.gz <user>@<hpc-host>:~/simulations/

# 4. On HPC:
tar xzf hpc-upload.tar.gz
cp hpc-upload/gromacs-pipeline/<file> gromacs-pipeline/<path>/
rm -rf hpc-upload hpc-upload.tar.gz
```

Gotchas:
- **Do NOT `git clone` on the HPC** — it hangs. Always tar+scp upload.
- The `tar: Ignoring unknown extended header keyword 'LIBARCHIVE.xattr...'`
  warnings are harmless (macOS metadata). Ignore them.
- macOS tar adds `._` files. **Delete them from force fields**:
  `find forcefields -name '._*' -delete` (they break GROMACS).
- **Deploy ALL changed files** — especially `profiles/*.sh`. Missing a
  profile upload means jobs use stale node selection (e.g. V100 instead of
  the intended A100). After deploying, verify: `grep SELECT_GPU profiles/iitd.sh`.

---

## Operational commands (tested patterns)

All commands below have been tested on IITD HPC. Use them as-is.

### SSH pattern (from local machine)

```bash
expect << 'EOF'
set timeout 60
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    <user>@<hpc-host> "COMMANDS..."
expect "password:"
send "<password>\r"
expect eof
EOF
```

### Upload script to HPC

```bash
expect << 'EOF'
set timeout 60
spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    /local/path/script.sh <user>@<hpc-host>:~/simulations/
expect "password:"
send "<password>\r"
expect eof
EOF
```

### Run script on HPC

```bash
expect << 'EOF'
set timeout 120
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    <user>@<hpc-host> "bash ~/simulations/script.sh 2>&1; echo EXIT=\$?"
expect "password:"
send "<password>\r"
expect "EXIT="
expect eof
EOF
```

### Check job status

```bash
expect << 'EOF'
set timeout 60
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    <user>@<hpc-host> "qstat -u <user>; echo '---'; cat ~/simulations/projects/<name>/.state/workflow.json"
expect "password:"
send "<password>\r"
expect eof
EOF
```

### Check production output

```bash
expect << 'EOF'
set timeout 60
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    <user>@<hpc-host> "ls -la ~/simulations/projects/<name>/output/production/; echo '---'; cat ~/simulations/projects/<name>/output/production/md.cpt 2>/dev/null | head -3 || echo 'no checkpoint'"
expect "password:"
send "<password>\r"
expect eof
EOF
```

### Submit production on A100 (manual qsub — verified pattern)

`run.sh submit --force` does NOT let you select the node class for a single
stage, so use manual qsub for production. **A100 only (`centos=icelake`).**

```bash
expect << 'EOF'
set timeout 120
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    <user>@<hpc-host> "cd ~/simulations/projects/<name> && qsub -P helicases.spons -l select=1:ncpus=8:ngpus=1:centos=icelake -l walltime=\$PROD_WALLTIME -v PROJECT_DIR=\$(pwd) scripts/production.sh"
expect "password:"
send "<password>\r"
expect eof
EOF
```

**NEVER drop `centos=icelake`** — without it the job lands on haswell/skylake
(broken/slow). A100 jobs queue when congested; wait.

### Update config on HPC

```bash
expect << 'EOF'
set timeout 60
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    <user>@<hpc-host> "cd ~/simulations/projects/<name> && sed -i 's/^PRODUCTION_NS=.*/PRODUCTION_NS=0.5/' config.sh && grep PRODUCTION_NS config.sh"
expect "password:"
send "<password>\r"
expect eof
EOF
```

### Reset workflow state

```bash
expect << 'EOF'
set timeout 60
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    <user>@<hpc-host> "cd ~/simulations/projects/<name> && cat > .state/workflow.json << 'STATE'
{
  \"schema_version\": 1,
  \"project\": \"<project_name>\",
  \"initialized\": \"<timestamp>\",
  \"phases\": {
    \"setup\": {\"status\": \"completed\", \"job_id\": \"\"},
    \"equilibration\": {\"status\": \"completed\", \"job_id\": \"\"},
    \"production\": {\"status\": \"pending\", \"job_id\": \"\"}
  }
}
STATE
cat .state/workflow.json"
expect "password:"
send "<password>\r"
expect eof
EOF

---

## The 3-job pipeline (why)

```
Job 1: SETUP (CPU)         prepare → pdb2gmx → editconf → solvate → genion → index
Job 2: EQUILIBRATION (GPU) EM → NVT → NPT
Job 3: PRODUCTION (GPU)    production MD (chunked, checkpoint-aware)
```

Chained with PBS `-W depend=afterok:`. This balances queue waits vs resumability.

---

## Submit

```bash
bash gromacs-pipeline/run.sh submit projects/blm_cmyc
```

Steps: fingerprint check → generate job scripts → submit 3 PBS jobs.

---

## Initialize / reset state (only when needed)

```bash
rm -f projects/blm_cmyc/.state/workflow.json
bash gromacs-pipeline/setup/state.sh projects/blm_cmyc
bash gromacs-pipeline/setup/fingerprint.sh projects/blm_cmyc
```

Do this after any state corruption. Then re-`submit`.

---

## Monitor

```bash
qstat -u <user>                # R=running Q=queued H=held F=finished
```

Stage completion is determined by OUTPUT FILE presence:

| Stage | Sentinel file |
|-------|--------------|
| setup done | `output/setup/index.ndx` |
| EM done | `output/equilibration/em.gro` |
| NVT done | `output/equilibration/nvt.gro` |
| NPT done | `output/equilibration/npt.gro` |
| production | `output/production/PRODUCTION_COMPLETE` (marker) or `output/production/md.xtc` (trajectory) |

PBS job logs live in the project root: `projects/blm_cmyc/<script>.o<jobid>`.

---

## Timing expectations (BLM ~75k atoms, V100)

```
setup        ~2-3 min
EM           ~5-10 min (converges ~3000 steps)
NVT 100 ps   ~8 min
NPT 1 ns     ~70 min
production   ~70 min per ns chunk
```

If a stage finishes suspiciously fast, it likely FAILED (crash), not completed.

---

## Debug a failure (the critical skill)

1. Find the job log: `ls -t projects/blm_cmyc/*.o* | head -1`
2. `tail` it. **MPI_ABORT hides the real error** — the actual message is
   printed BEFORE the `----` separator. Read around it.
3. If stdout is truncated, capture stderr separately:
   `gmx_mpi pdb2gmx ... 2>/tmp/err.log; cat /tmp/err.log`
4. `grep -B2 -A5 'Fatal|Error|NOTE|WARNING' <log>`
5. Check the actual command that ran (not what you intended):
   `grep -A2 'Command line' <log>` — this catches flag-pollution bugs.

---

## Resume vs restart (the golden rule)

**The pipeline is idempotent** — stages skip if their output exists.

| Situation | Action |
|-----------|--------|
| Code/MDP fix | **Resume**: just re-`submit`. Completed stages skip. |
| NPT fix only | `rm -f output/equilibration/npt.*` then re-`submit` |
| Walltime hit | Just re-`submit` — `-cpi` resumes from checkpoint |
| Force field / PDB / config change | **Restart**: `rm -rf output`, re-init, submit |

---

## Force field management

- Installed in `gromacs-pipeline/forcefields/`
- Use `amber99sb-ildn` (complete system FF) — avoids partial-FF DNA/ion bugs
- `get-ff.sh install|complete|doctor <name>`
- Job scripts auto-set `GMXLIB` = forcefields + system GROMACS lib
- `setup/validate.sh` checks the FF exists in 4 search paths

---

## Known bugs & fixes (institutional knowledge — MUST know)

| # | Symptom | Root cause | Fix |
|---|---------|-----------|-----|
| 1 | pdb2gmx hangs | interactive terminal selection | `-noter` |
| 2 | `$CLUSTER` empty in job | profile sourced before config | source config first |
| 3 | `PROJECT_DIR: unbound variable` | not hardcoded in job script | hardcode it |
| 4 | qsub prints usage | SELECT flag missing `-l select=` | add prefix in profile |
| 5 | job ID polluted | echo to stdout in scheduler | echo to stderr |
| 6 | log named `%JOBID%` | not a valid PBS var | use `-j oe` only |
| 7 | `Invalid atomtype format` | `._` files in force field | delete them |
| 8 | `Residue type DT not found` | partial FF missing dna.rtp | `get-ff.sh complete` |
| 9 | DNA chain type error | PDB altLoc column (21) has `A` | fix prepare.sh columns |
| 10 | posre include not found | double-path `output/setup/` | sed fix topologies |
| 11 | `nstcomm < nstcalcenergy` | MDP missing nstcomm | add `nstcomm=500` |
| 12 | wrong index groups | hardcoded group numbers | use `gmx select` (no numbers) |
| 13 | `-cpi: Too many values` | version warning polluted gpu_flags | robust version parse in gmx.sh |
| 14 | trajectory overwritten | missing `-append` | add `-append` to production |
| 15 | NPT blows up / segfault | Parrinello-Rahman in equilibration | Berendsen NPT, PR production |
| 16 | grompp aborts on 2 warnings | `-maxwarn 1` too strict | stage-specific + warning check |
| 17 | production over-runs chunk | `-maxh` stops at walltime, not CHUNK_NS | **FIXED and VALIDATED** (`df3012e`): extend-from-checkpoint loop in `lib/stages.sh`. Atomic TPR replacement (`md.tpr.tmp.tpr`). Post-convert-tpr existence check. Stale lock recovery. `-nsteps -1` removed. convert-tpr → mv → checkpoint cycle verified on real GROMACS. **Walltime-interruption + resume VALIDATED on HPC** (job 968472: 137.2 ps completed, checkpoint written, exited gracefully). |

### Benchmark findings (COMPLETE — job 968167 + 968361)
- **nstlist=100**: 43.5 ns/day (+10.7% vs baseline 39.3). 0 LINCS. **ADOPT.**
- **vbt=0.005**: 41.8 ns/day (+6.4%). Same physics. **ADOPT.**
- **nstcalcenergy=1000**: 39.2 ns/day (-0.2%). **DO NOT adopt.**
- **nstlist=40**: 39.7 ns/day (+1.0%). Negligible. Keep nstlist=100.
- **Berendsen NPT**: 39.7 ns/day. Performance fine. Keep for equilibration.
- **C-rescale NPT**: 28.2 ns/day — **INVALID** (ran with 1 OpenMP thread). Fixed MDP on HPC (`bench/mdp_npt_crescale_fixed.mdp`). Re-run needed.
- **Combined nstlist=100+vbt=0.005**: 25.9 ns/day — **INVALID** (ran with 1 OpenMP thread). Re-run needed with `export OMP_NUM_THREADS=8`.
- amber14sb + **bsc1** DNA correction: NOT on this HPC; external source needed.

---

## Index generation (gmx select — no group numbers)

```bash
gmx select -s output/setup/ions.gro -on output/setup/index.ndx \
    -select 'not (group Water or group Ion); group Water or group Ion'
# then rename auto-names:
#   [ not_(group_Water_or_group_Ion) ] → [ Protein_DNA ]
#   [ group_Water_or_group_Ion ]       → [ Water_Ions ]
```

- Verifies `Water` and `Ion` groups exist first (fail with clear error if not)
- Renames deterministically (no group numbering assumptions)
- Works for any system (protein, +DNA, +RNA, +ligand, any FF/water/ion)

---

## Grompp warning policy (strict)

`run_grompp_checked <maxwarn> <grompp args>`:
- Captures grompp output and inspects EVERY warning
- Only two warnings are tolerated:
  1. free ions not bound by a potential/constraint
  2. COM removal with position restraints
- Any other warning → fail with clear error
- Stage maxwarn: EM=0, NVT=2, NPT=2, Production=2

---

## Performance verification

```bash
grep -E 'Running on|GPU info|ns/day' output/equilibration/nvt.log
# Expect: "1 node ... 1 compatible GPU", CUDA, PME grid
# mdrun command line must be clean (no stray warnings in it)
qstat -xf <jobid> | grep exec_host   # verify node type (csky/vsky/aice)
```

---

## Multi-replicate production (parallel)

```bash
# Level 2 validation: create 3 replicates from template
bash gromacs-pipeline/setup/replicate.sh projects/blm_cmyc blm_kras_val 3
# → projects/blm_kras_val_rep1, _rep2, _rep3 (independent)

# Copy setup + equilibration outputs from template
for p in projects/blm_kras_val_rep*; do
    mkdir -p $p/output/setup $p/output/equilibration
    cp -a projects/blm_cmyc/output/setup/* $p/output/setup/
    cp -a projects/blm_cmyc/output/equilibration/* $p/output/equilibration/
done

# Update workflow state
for p in projects/blm_kras_val_rep*; do
    cat > $p/.state/workflow.json << STATE
{
  "schema_version": 1,
  "project": "$(basename $p)",
  "initialized": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phases": {
    "setup": {"status": "completed", "job_id": ""},
    "equilibration": {"status": "completed", "job_id": ""},
    "production": {"status": "pending", "job_id": ""}
  }
}
STATE
done

# Submit all 3 in parallel
for p in projects/blm_kras_val_rep*; do
  bash gromacs-pipeline/run.sh submit --force "$p" &
done
wait

# Resubmit on A100 when jobs finish
for p in projects/blm_kras_val_rep*; do
    cd "$p"
    qsub -P helicases.spons -l select=1:ncpus=8:ngpus=1:centos=icelake \
         -l walltime=00:02:30 \
         -v PROJECT_DIR=$(pwd) \
         scripts/production.sh
    cd ..
done
```

---

## Production estimates (BLM-cMYC 500 ns × 3)

### Runtime

| Metric | Value |
|--------|-------|
| Performance (baseline) | 39.3 ns/day |
| Time per chunk (50 ns) | ~30.5 hours |
| Jobs per replicate | ~13 (500 ns / 39 ns per 24h job) |
| Runtime per replicate | ~13 days (312 hours) |
| Total jobs | 39 (13 × 3 replicates) |
| Total runtime | ~13 days (24h A100) |
| With A100 congestion | ~20-30 days |

### Storage

| Metric | Value |
|--------|-------|
| Trajectory per replicate | ~29 GB (10,000 frames × 2.6 MB) |
| Checkpoint per replicate | ~16 MB |
| Energy per replicate | ~50 MB |
| Log per replicate | ~10 MB |
| Total per replicate | ~29 GB |
| Total for 3 replicates | ~87 GB |

### Job pattern

```
Job 1:  0 → 39 ns (24h walltime)
Job 2:  39 → 78 ns
Job 3:  78 → 117 ns
...
Job 13: 468 → 500 ns (PRODUCTION_COMPLETE)
```

### MDP settings (current — baseline)

| Setting | Value | Notes |
|---------|-------|-------|
| dt | 0.002 ps | 2 fs timestep |
| nstlist | 400 | Neighbor list rebuild every 0.8 ps |
| verlet-buffer-tolerance | 0.002 | Energy drift tolerance |
| nstxout-compressed | 25000 | Trajectory every 50 ps |
| nstenergy | 5000 | Energy every 10 ps |
| nstlog | 5000 | Log every 10 ps |
| nstcalcenergy | 500 | Energy computation every 1 ps |
| nsteps | -1 | Run until -maxh stops it |
| pcoupl | Parrinello-Rahman | Correct for production |
| tcoupl | v-rescale | Velocity rescaling thermostat |

### Benchmark-adopted settings (NOT YET APPLIED)

| Setting | Value | Improvement |
|---------|-------|-------------|
| nstlist | 100 | +10.7% (43.5 ns/day) |
| verlet-buffer-tolerance | 0.005 | +6.4% (41.8 ns/day) |
| Combined | nstlist=100 + vbt=0.005 | Needs re-run to confirm |

---

## Test suite

Tests live in `tests/` and use `tests/bin/fake_gmx` to simulate GROMACS without a GPU.

```bash
bash gromacs-pipeline/tests/unit.sh        # 20/20 — gmx.sh functions
bash gromacs-pipeline/tests/integration.sh  # 17/18 — production loop
bash gromacs-pipeline/tests/test_prepare.sh # 10/10 — trajectory preparation
```

### Known test issues

**Test 7 ("zero-progress detection (fatal)")** fails. The test runs `run_stage_production` twice:
1. First with `FAKE_ZERO=1` — correctly returns non-zero (zero-progress detected).
2. Second without `FAKE_ZERO` — succeeds, but the test expects failure.

The production code does not persist failure state after zero-progress detection, allowing a clean retry. The repository contains no documentation, comments, or git history explaining whether this test expectation is intentional. **Requires maintainer clarification before modification.** See maintainer report for details.

---

## Trajectory preparation

After production completes, prepare trajectories for visualization and analysis:

```bash
bash gromacs-pipeline/post/prepare.sh projects/my_system
bash gromacs-pipeline/post/prepare.sh projects/my_system --preset analysis
bash gromacs-pipeline/post/prepare.sh projects/my_system --fit-to Backbone --keep Protein_DNA
```

### What it does

- PBC correction + centering (default)
- Rigid-body fitting (optional: `--fit-to`)
- Solvent stripping (optional: `--keep`)
- Presets: `visualization`, `analysis`, `dry`

### What it does NOT do

- Analysis (RMSD, RMSF, PCA)
- Visualization (use VMD/PyMOL)
- Automatic execution (user runs manually)

### Key rules

- Never modifies raw production outputs (`output/production/`)
- All derived files go to `output/prepared/`
- Skip-if-exists (idempotent), use `--force` to regenerate
- Groups resolved from GROMACS built-in (Protein, Backbone) or index.ndx (Protein_DNA)

---

## Agent Skills

Skills live in `.agent/skills/` and provide structured guidance for specific tasks.

### input-preparation

**Purpose:** Validates inputs, explains constraints, recommends defaults, and orchestrates project setup.

**Activates when:** User creates a project, reviews config, checks PDB readiness, selects force fields, or diagnoses input failures.

**Files:**

| File | Responsibility |
|------|---------------|
| `SKILL.md` | Entry point: purpose, activation, responsibilities, principles |
| `workflow.md` | How the agent thinks through a preparation task |
| `playbook.md` | Operational knowledge: repository structure, validation rules, decision logic |

**Scripts this skill executes:** `setup/init.sh`, `setup/validate.sh`, `forcefields/get-ff.sh`

**Scripts this skill never executes:** `run.sh submit`, `lib/stages.sh`, `lib/gmx.sh`, `lib/scheduler.sh`

### md-scientific-reasoning

**Purpose:** Scientific reasoning system for molecular dynamics. Answers scientific questions by reasoning about evidence, not by executing analyses. Analyses are evidence producers.

**Activates when:** User asks scientific questions about MD results, simulation outputs, convergence, stability, flexibility, binding, mutation effects, or structural interpretation.

**Files:**

| File | Responsibility |
|------|---------------|
| `SKILL.md` | Entry point: purpose, activation, responsibilities, principles, evidence hierarchy |
| `workflow.md` | How the agent reasons about scientific questions (12-step reasoning) |
| `playbook.md` | Evidence producers and evidence synthesis patterns |

**Key principles:** Evidence-first, hypothesis-driven, minimum sufficient evidence, verified knowledge, no guessing

**Scripts this skill never executes:** `run.sh submit`, `lib/stages.sh`, `lib/gmx.sh`, `lib/scheduler.sh`

---

## When to refer to README vs AGENTS.md

- **README.md** → for USERS: how to set up a project, run the pipeline,
  command reference, troubleshooting. Point end users here.
- **AGENTS.md** → for AGENTS/DEVELOPERS: the ops workflow, deployment,
  debugging, known bugs, and how to operate the pipeline on the HPC.
