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

**Phase**: Production chunking design fix (in progress) + performance benchmarking.

### Known design bug (being fixed)
The production chunking does NOT enforce `CHUNK_NS`. Current `run_stage_production`
uses `mdrun -maxh <walltime> -nsteps -1`, so chunks stop at **walltime**, not at
`CHUNK_NS` of simulation time. Consequences:
- `PRODUCTION_NS=1, CHUNK_NS=1` runs ~3 ns (until walltime), not 1 ns.
- `PRODUCTION_NS=500, CHUNK_NS=50` would stop short (walltime-limited chunks
  cover less than 50 ns each) — total length wrong.

### Decided fix (approved, NOT yet implemented)
Use **extend-from-checkpoint** with one `md.tpr`:
```
loop until current_time >= PRODUCTION_NS:
    gmx convert-tpr -s md.tpr -until (current_time + CHUNK_NS) -o md.tpr
    gmx mdrun -s md.tpr -cpi md.cpt -maxh $maxh
    current_time = read from md.cpt
```
- The checkpoint is the single source of truth; the TPR end is derived from it.
- Walltime (`-maxh`) is pure safety; interruptions never skip or duplicate time.
- The **per-chunk `-until` tpr idea was REJECTED** — it silently skips time when
  a walltime-interrupted chunk exits 0 and `afterok` advances the chain.
- **Never use PBS job arrays for the chunk chain** (concurrent writes corrupt
  md.cpt/md.xtc). Parallelism = separate replicate projects.

### Pending benchmark (job 968167 on HPC, queued for A100)
Validates MDP tuning before adopting:
- nstlist 40 / 100 / 400
- verlet-buffer-tolerance 0.002 / 0.005
- nstcalcenergy 500 / 1000
- NPT barostat Berendsen vs C-rescale (docs recommend c-rescale)
Results land in `~/simulations/bench/benchmark_summary.log` on the HPC.

### Other validated recommendations (waiting on benchmark + approval)
- `verlet-buffer-tolerance=0.005` (safe, GROMACS default)
- `nstcalcenergy=1000` (docs recommend for GPU-resident)
- `-pin on` + drop forced `OMP_NUM_THREADS` (thread pinning)
- **A100 already staged** (profile requests `centos=icelake`)
- bsc1/amber14sb DNA correction: **NOT available on this HPC** — external
  acquisition required, high effort. Not a default.

### Validation run status (BLM-cMYC 1ns)
- Setup ✅, EM ✅, NVT ✅, NPT ✅ (Berendsen — see barostat benchmark)
- Production: ran on V100 at ~20 ns/day, **over-ran 1ns to ~3ns** because of the
  chunking bug above (job 967992, likely done/failed by now)
- The pipeline is PROVEN end-to-end (setup through production).

### Immediate next actions
1. Stop/clean the over-running validation production if still alive.
2. Implement the extend-from-checkpoint chunking fix in `run_stage_production`
   + `run.sh` (per-chunk submit / resubmit until PRODUCTION_NS).
3. Read benchmark results, adopt validated MDP/barostat changes.
4. Re-run the 1ns validation to confirm it stops at exactly 1 ns.

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
| 17 | production over-runs chunk | `-maxh` stops at walltime, not CHUNK_NS | extend-from-checkpoint (`convert-tpr -until` from md.cpt) — NOT per-chunk tpr (skips time) |

### Known benchmark findings (pending final adoption)
- npt barostat: docs recommend **C-rescale** over Berendsen (correct ensemble, as stable). Benchmark in progress.
- `verlet-buffer-tolerance=0.005` = GROMACS default, forces identical, safe.
- `nstcalcenergy=1000` recommended for GPU-resident.
- `nstlist`: GROMACS docs say 20-40 often best on GPU; our 400 may be high (benchmark pending).
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

## When to refer to README vs AGENTS.md

- **README.md** → for USERS: how to set up a project, run the pipeline,
  command reference, troubleshooting. Point end users here.
- **AGENTS.md** → for AGENTS/DEVELOPERS: the ops workflow, deployment,
  debugging, known bugs, and how to operate the pipeline on the HPC.
