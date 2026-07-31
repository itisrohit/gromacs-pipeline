# AGENTS.md — GROMACS HPC Pipeline Work Pattern

This file tells any agent/assistant exactly how this project works, how to
operate it on the IITD HPC, and the full pattern used to develop, deploy,
debug, and validate it. Read this first if you lost context.

---

## Project purpose (the final aim)

Build a **generic, reusable, Bash-only GROMACS MD pipeline** that:

- Works **end-to-end** for **any biomolecular input** (protein, protein–DNA,
  protein–RNA, protein–ligand) with no project-specific code in the pipeline.
- Runs on **any HPC cluster** (PBS / Slurm / LSF) via cluster profiles.
- Is portable, reproducible, and resumable (checkpoint-aware).
- User supplies only `input/system.pdb` + `config.sh`. Everything else is
  GROMACS + the pipeline.

**For users**: point them to `README.md` (usage, quick start, command reference).

**For agents**: this file documents the *development/ops* workflow, the
known pitfalls, and how to get an end-to-end run working.

---

## CURRENT STATUS — READ THIS FIRST (as of the last session)

**Phase**: Production submitted on BLM-cMYC with optimizations (nstlist=100, vbt=0.005). Waiting for A100 node.

### Recent fixes (committed)
1. **TPR filename mismatch** (`df3012e`): `convert-tpr -o md.tpr.tmp` created `md.tpr.tmp.tpr` (GROMACS appends `.tpr`). Fixed to use `md.tpr.tmp.tpr` consistently. Validated on HPC with real GROMACS.
2. **fake_gmx awk field index** (`1d1c37e`): `convert-tpr` writes `target = value` (3 fields), but mdrun awk read `$2` (`=`) instead of `$3` (value). Fixed. Integration tests: 17/18 pass.

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
| C-rescale NPT | 28.196 | 0.851 | 0 | Ran with 1 thread (see below) |
| combined nst100+vbt005 | 25.921 | 0.926 | 0 | Ran with 1 thread (see below) |

**Combined + C-rescale results are INVALID** — both ran on `aice005` with 1 OpenMP thread instead of 8. The benchmark script does not set `OMP_NUM_THREADS`. The first run (nst100) inherited 8 threads from the environment; subsequent runs did not. Re-run needed with `export OMP_NUM_THREADS=8`.

**Recommendation**: nstlist=100 + vbt=0.005. Re-run combined benchmark with correct threading to confirm.

### HPC validation status (BLM-cMYC 1ns)
- Setup ✅, EM ✅, NVT ✅, NPT ✅ (Berendsen)
- Production: extend-from-checkpoint loop validated on HPC (convert-tpr + mv + checkpoint cycle works)
- **Production submitted**: Job 968472.pbshpc, walltime=5min, waiting for A100 node
- **Production walltime-interruption validation: IN PROGRESS** — job submitted, waiting to run
- MDP updated: nstlist=100, vbt=0.005
- Profile restored: `centos=icelake` added back to SELECT_GPU

### Immediate next actions
1. **Check if job 968472 ran** — verify checkpoint, resume, completion.
2. **Re-run combined benchmark** with `export OMP_NUM_THREADS=8`.
3. **Apply nstlist=100 + vbt=0.005 to default MDPs** after benchmark confirmation.
4. **Apply C-rescale to production MDP** after validation (replace Berendsen for correct ensemble).
5. **Configure BLM-KRAS_K 500ns × 3 replicates** via `setup/replicate.sh`.

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
- Node types: `csky*` CPU, `vsky*` V100 GPU, `aice*` A100 GPU (`centos=icelake`)
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

| Stage | Sentinal file |
|-------|--------------|
| setup done | `output/setup/index.ndx` |
| EM done | `output/equilibration/em.gro` |
| NVT done | `output/equilibration/nvt.gro` |
| NPT done | `output/equilibration/npt.gro` |
| production | `output/production/md.xtc` |

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
| 17 | production over-runs chunk | `-maxh` stops at walltime, not CHUNK_NS | **IMPLEMENTED + convert-tpr/mv VALIDATED on HPC** (`df3012e`): extend-from-checkpoint loop in `lib/stages.sh`. Atomic TPR replacement (`md.tpr.tmp.tpr`). Post-convert-tpr existence check. Stale lock recovery. `-nsteps -1` removed. convert-tpr → mv → checkpoint cycle verified on real GROMACS. **Walltime-interruption + resume NOT YET TESTED on HPC.** |

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
bash gromacs-pipeline/setup/replicate.sh projects/blm_cmyc blm_kras 3
# → projects/blm_kras_rep1, _rep2, _rep3 (independent)

for p in projects/blm_kras_rep*; do
  bash gromacs-pipeline/run.sh submit "$p" &
done
wait
```

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

---

## When to refer to README vs AGENTS.md

- **README.md** → for USERS: how to set up a project, run the pipeline,
  command reference, troubleshooting. Point end users here.
- **AGENTS.md** → for AGENTS/DEVELOPERS: the ops workflow, deployment,
  debugging, known bugs, and how to operate the pipeline on the HPC.
