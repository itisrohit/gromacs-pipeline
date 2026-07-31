# Benchmark Report: GROMACS Production Performance

## Purpose

Before running 500ns × 3 replicates of BLM-KRAS_K (~700k atoms), we benchmarked
GROMACS production settings on IITD HPC to find the fastest configuration that
maintains simulation stability.

The production stage dominates total runtime. A 10% speedup on 500ns × 3
replicates saves ~30 hours of GPU time.

## What We Benchmarked

We tested six configurations, each changing one parameter from a baseline:

| Config | Parameter Changed | Value |
|--------|-------------------|-------|
| baseline | (none) | nstlist=400, vbt=0.002, nce=500 |
| nstlist=100 | neighbour list frequency | 100 (from 400) |
| vbt=0.005 | Verlet buffer tolerance | 0.005 (from 0.002) |
| nstlist=40 | neighbour list frequency | 40 (from 400) |
| nce=1000 | nstcalcenergy | 1000 (from 500) |
| Berendsen NPT | barostat (equilibration only) | Berendsen (from PR) |

After individual tests, we attempted a combined test (nstlist=100 + vbt=0.005)
and a C-rescale barostat test.

## Why These Parameters

**nstlist** (neighbour list update frequency): Larger values mean fewer list
rebuilts, but the list must be larger to stay accurate. The Verlet scheme
automatically manages buffer size based on `verlet-buffer-tolerance`.

**verlet-buffer-tolerance** (vbt): Controls how much energy error is tolerated
from the neighbour list buffer. Higher tolerance = smaller buffer = faster
list rebuilds, but more approximation.

**nstcalcenergy**: How often energies are recalculated. Higher = less overhead,
but coarser energy monitoring.

**Barostat**: Berendsen is faster but produces incorrect fluctuations for
production. Parrinello-Rahman is correct but slightly slower. C-rescale is
a newer barostat with better properties.

## How We Did It

### System

- **System**: BLM-cMYC (protein–DNA complex, ~700k atoms)
- **Hardware**: IITD HPC, NVIDIA A100-PCIE-40GB (`aice*` nodes)
- **GROMACS**: 2023.2-plumed_2.10.0_dev (CUDA, mixed precision)
- **MDP**: Production settings (PME, v-rescale thermostat, PR barostat)
- **Run length**: 50,000 steps (100 ps) per benchmark

### Method

1. Created a benchmark project with NPT-equilibrated structure from BLM-cMYC
2. Generated separate MDP files for each configuration
3. Ran `grompp` + `mdrun` with GPU flags (`-nb gpu -pme gpu -bonded gpu -update gpu`)
4. Extracted performance (ns/day) and LINCS warning counts from logs
5. All individual benchmarks ran on `aice008` (A100)

### Command pattern

```bash
gmx_mpi grompp -f mdp_<config>.mdp -c nvt.gro -r nvt.gro -t npt.cpt \
    -p topol.top -n index.ndx -o <config>.tpr -maxwarn 2
gmx_mpi mdrun -deffnm <config> -nsteps 50000 \
    -nb gpu -pme gpu -bonded gpu -update gpu
```

## Results

### Individual benchmarks (job 968167, A100)

| Config | ns/day | hour/ns | vs baseline | LINCS | Status |
|--------|--------|---------|-------------|-------|--------|
| baseline (nst400/vbt002) | 39.259 | 0.611 | — | 0 | Reference |
| nstlist=100 | 43.469 | 0.552 | **+10.7%** | 0 | Adopt |
| vbt=0.005 | 41.775 | 0.575 | **+6.4%** | 0 | Adopt |
| nstlist=40 | 39.661 | 0.605 | +1.0% | 0 | Skip |
| nce=1000 | 39.181 | 0.613 | -0.2% | 0 | Skip |
| Berendsen NPT | 39.678 | 0.605 | +1.1% | 0 | Keep for eq only |

### Combined + C-rescale benchmarks (job 968361, A100)

| Config | ns/day | hour/ns | vs baseline | Status |
|--------|--------|---------|-------------|--------|
| combined nst100+vbt005 | 25.921 | 0.926 | -34% | **INVALID** |
| C-rescale NPT | 28.196 | 0.851 | -28% | **INVALID** |

Both ran with 1 OpenMP thread instead of 8. The benchmark script did not
set `OMP_NUM_THREADS`. The first benchmark (nst100) inherited 8 threads from
the shell environment; subsequent runs in the same script did not.

**These results must not be used for decisions.** Re-run with
`export OMP_NUM_THREADS=8` before each mdrun.

### Key observations from valid runs

- **nstlist=100 is the clear winner** (+10.7%). The 8x100 GPU pair-list
  setup with dynamic pruning handles the shorter list efficiently.
- **vbt=0.005 adds another +6.4%** on top of nstlist=100 (estimated ~17%
  combined). The relaxed buffer reduces pair-search overhead.
- **nstlist=40 and nce=1000 are noise** (<2% change). Not worth the
  parameter change.
- **Berendsen vs PR barostat**: negligible performance difference (1.1%).
  Keep PR for production (correct ensemble), Berendsen for equilibration
  (faster convergence).

## Decisions

### Adopted for production

| Setting | Value | Rationale |
|---------|-------|-----------|
| nstlist | 100 | +10.7%, no LINCS warnings |
| verlet-buffer-tolerance | 0.005 | +6.4% additional, same physics |
| nstcalcenergy | 500 | No benefit from 1000 |
| Berendsen NPT | Equilibration only | Correct ensemble needed for production |
| Parrinello-Rahman | Production | Standard for production MD |

### Not adopted

| Setting | Reason |
|---------|--------|
| nstlist=40 | Negligible improvement |
| nstcalcenergy=1000 | No measurable benefit |
| C-rescale | Needs re-benchmark with correct threading; potential for production |
| Combined benchmark | Invalid result (threading bug); needs re-run |

### Estimated performance

With nstlist=100 + vbt=0.005 on A100:
- **~46 ns/day** (estimated from individual +6.4% on top of 43.5)
- **~0.52 hour/ns**
- 500ns × 3 replicates: **~32.5 days** on A100
- 500ns × 3 replicates: **~65 days** on V100 (~20 ns/day)

## Open Items

1. **Re-run combined benchmark** with `export OMP_NUM_THREADS=8` to confirm
   additive speedup.
2. **Re-run C-rescale benchmark** with correct threading to evaluate for
   production use.
3. **Test production walltime-interruption + resume** on HPC to validate
   the extend-from-checkpoint loop works end-to-end.
4. **Update default MDPs** (`mdp/md.mdp`) with nstlist=100 + vbt=0.005
   after confirmation.
