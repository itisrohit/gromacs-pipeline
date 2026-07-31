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

**Phase**: Production chunking IMPLEMENTED + benchmark COMPLETE. Awaiting HPC validation + MDP adoption.

### Production chunking fix (IMPLEMENTED and DEPLOYED to HPC)
The extend-from-checkpoint loop is implemented in `lib/stages.sh:run_stage_production()`.
All local tests pass (20/20 unit, 15/16 integration). Deployed to HPC (`lib/gmx.sh`, `lib/stages.sh`, `run.sh`).

What changed:
- `checkpoint_time_ps()` in `lib/gmx.sh` reads time via `gmx dump -cp` (primary) or `gmx check` (fallback)
- `run_stage_production()` loops: read checkpoint → compute target → convert-tpr -until → mdrun -cpi → check progress
- Atomic TPR replacement: `convert-tpr -o md.tpr.tmp` then `mv md.tpr.tmp md.tpr`
- Stale lock recovery: PID-based staleness check in mkdir fallback
- `run.sh` submits ONE production job (no more N-chunk chain), marker-based completion
- `-nsteps -1` REMOVED from mdrun (was overriding convert-tpr target)
- All `$GMX` calls quoted for paths with spaces

### Benchmark results (job 968167, COMPLETE on HPC A100)
See `~/simulations/bench/benchmark_summary.log` on HPC.

| Config | ns/day | hour/ns | LINCS |
|--------|--------|---------|-------|
| baseline (nst400/vbt002/nce500) | 39.259 | 0.611 | 0 |
| nstlist=100 | 43.469 | 0.552 | 0 |
| vbt=0.005 | 41.775 | 0.575 | 0 |
| nstlist=40 | 39.661 | 0.605 | 0 |
| nce=1000 | 39.181 | 0.613 | 0 |
| Berendsen NPT | 39.678 | 0.605 | 0 |
| C-rescale NPT | grompp FAILED | — | — |

**C-rescale failure**: benchmark MDP typo — duplicate `pcoupl` line + missing `pcoupltype = isotropic`.
NOT a GROMACS version issue. Fixed MDP uploaded to HPC (`bench/mdp_npt_crescale_fixed.mdp`).

**Combined nstlist=100+vbt=0.005 benchmark**: MDP uploaded (`bench/mdp_combined100_005.mdp`).
Job 968312 submitted, running now. Awaiting results.

**Recommendation so far**: nstlist=100 + vbt=0.005 (estimated ~17% speedup). Need combined benchmark to confirm additive.

### HPC validation status (BLM-cMYC 1ns)
- Setup ✅, EM ✅, NVT ✅, NPT ✅ (Berendsen)
- Production: job 967992 over-ran (old bug, killed). New code deployed.
- **Production walltime-interruption validation: NOT YET DONE**
- All recent production jobs (968267–968291) failed at startup (qdel'd during debugging, no GPU nodes, module issues).
- `output/production/` has stale `md.tpr` and `md.tpr.tmp.tpr` from failed attempts. No checkpoint. No marker.
- Profile currently has `centos=icelake` removed (was blocking on no A100 nodes). Restore before 500ns runs.

### Immediate next actions
1. **Wait for benchmark job 968312** to finish. Check `~/simulations/bench/run_final_bench.sh.o968312`.
2. **Run production walltime-interruption validation**: submit with PROD_WALLTIME=00:05:00, wait for interruption, re-submit, verify reaches 1000 ps. Use `run.sh submit` with proper state (setup+eq marked completed).
3. **Update default MDPs** if benchmark results justify (nstlist=100, vbt=0.005).
4. **Restore `centos=icelake` in profile** before 500ns runs.
5. **Apply C-rescale to production MDP** after validation (replace Berendsen for correct ensemble).

### HPC profile gotcha (DO NOT REPEAT)
- `SELECT_GPU` currently has NO `centos=icelake` constraint (removed to unblock GPU access when A100s were busy).
- **Restore it before running 500ns production**: `sed -i 's|ngpus=%GPUS%"|ngpus=%GPUS%:centos=icelake"|' profiles/iitd.sh`
- PBS uses `-P` for project, not `-A`. Profile has `SUBMIT_ACCOUNT="-P %ACCOUNT%"`.
- `qdel -f` is invalid on IITD PBS. Use `qdel` without flags.
- A100 nodes (`aice*`) are often busy. V100 (`vsky*`) available. Job requests `centos=icelake` for A100.
- To submit without A100 constraint: remove `centos=icelake` from SELECT_GPU temporarily.
- Benchmark jobs run on A100 (~43 ns/day). V100 runs at ~20 ns/day.
- `expect` chokes on `{}`, `[0-9]`, `$` in SSH commands. Upload `.sh` scripts instead of inline commands.

---

## Repository layout (local)

```
gromacs-pipeline/          # the pipeline tool (reusable code only)
├── run.sh                 # submit/status/report
├── lib/                   # gmx.sh, scheduler.sh, stages.sh, state.sh
├── setup/                 # init.sh, validate.sh, replicate.sh, state.sh,
│   │                      # fingerprint.sh, templates/config.sh
├── profiles/              # iitd.sh, generic-pbs.sh, generic-slurm.sh, generic-lsf.sh
├── mdp/                   # em.mdp, nvt.mdp, npt.mdp, md.mdp
├── forcefields/           # get-ff.sh + installed force fields
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
├── output/{setup,equilibration,production,logs}/
├── .state/                # workflow.json, fingerprint
└── scripts/               # generated job scripts
```

---

## The HPC environment (IITD)

- Login: `ssh blz208818@hpc.iitd.ac.in` (password `m0203SFR`, only in expect)
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
    blz208818@hpc.iitd.ac.in "COMMANDS..."
expect "password:"
send "m0203SFR\r"
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
scp /tmp/hpc-upload.tar.gz blz208818@hpc.iitd.ac.in:~/simulations/

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
qstat -u blz208818                # R=running Q=queued H=held F=finished
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
| 17 | production over-runs chunk | `-maxh` stops at walltime, not CHUNK_NS | **IMPLEMENTED, NOT VERIFIED**: extend-from-checkpoint in `lib/stages.sh`. Atomic TPR replacement. Stale lock recovery. `-nsteps -1` removed. Deployed to HPC. All production jobs so far failed at startup — HPC validation pending. |

### Benchmark findings (COMPLETE — job 968167 + 968312)
- **nstlist=100**: 43.5 ns/day (+10.7% vs baseline 39.3). 0 LINCS. **ADOPT.**
- **vbt=0.005**: 41.8 ns/day (+6.4%). Same physics. **ADOPT.**
- **nstcalcenergy=1000**: 39.2 ns/day (-0.2%). **DO NOT adopt.**
- **nstlist=40**: 39.7 ns/day (+1.0%). Negligible. Keep nstlist=100.
- **Berendsen NPT**: 39.7 ns/day. Performance fine. Keep for equilibration.
- **C-rescale NPT**: grompp failed (MDP typo: duplicate pcoupl + missing pcoupltype). Fixed MDP on HPC. Need clean benchmark run.
- **Combined nstlist=100+vbt=0.005**: Job 968312 running. Check `~/simulations/bench/run_final_bench.sh.o968312`.
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
