# IIT Delhi HPC Guide

This guide was written from direct experience running GROMACS molecular
dynamics on the IIT Delhi HPC cluster. It consolidates the node architecture,
scheduling queues, PBS job submission, and direct-connect workflows into a
single reference. It also records hard-won operational lessons — most
importantly which node classes are reliable and which must be avoided.

---

## 1. Access and Accounts

Using the HPC requires three credentials:

1. **User ID** — the login username.
2. **Password** — the account password.
3. **Project ID** — the billing/quota project used by the scheduler.

The project ID is passed to the scheduler with `-P`. On this cluster the
project `helicases.spons` is used for all work. The project does not carry a
dedicated allocation; all compute nodes are shared with every other user on
the cluster, so queue behaviour is competitive.

Access is via SSH:

```bash
ssh <user>@hpc.iitd.ac.in
```

The login nodes (`login07`, `login08`) are intended for file management and
job submission only. Heavy computation must never run there; actual work runs
on compute nodes, reached either through the scheduler (PBS) or by direct
SSH.

---

## 2. Node Architecture

The cluster provides many node classes, all shared. Node class is selected
through the `centos=` field in the PBS resource specification.

### 2.1 GPU Nodes

| Type | CPU cores | GPU | Memory | CentOS | Status |
|------|-----------|-----|--------|--------|--------|
| `aice*` | 64 | 2× A100 40GB | 514 GB | `icelake` | **Preferred — fastest GPUs on the cluster** |
| `vsky*` | 40 | 1–2× V100 32GB | 192 GB | `skylake` | Usable, fewer CPUs |
| `scai*` | 32–72 | 4–8 GPUs | 500 GB–1 TB | `amdepyc`/`icelake` | Special-purpose GPU nodes |
| `khas*` | 24 | 1–2 GPUs | 62 GB | `haswell` | **BROKEN — avoid entirely** |
| `chas*` | 24 | 0 | 63 GB | `haswell` | **BROKEN — avoid entirely** |

### 2.2 CPU Nodes

| Type | CPU cores | Memory | CentOS |
|------|-----------|--------|--------|
| `csky*` | 40 | 187 GB | `skylake` |
| `cice*` | 64 | 256 GB | `icelake` |
| `cgen*` | 128 | 772 GB–1.5 TB | `genoa` |

### 2.3 Which Nodes to Use

- **A100 nodes (`aice*`, `centos=icelake`) are the only GPU class intended for
  production MD.** They are the fastest GPUs available and the target for all
  production runs.
- **Haswell nodes (`khas*`, `chas*`) are broken and must never be used.**
  This was confirmed empirically: a production job that landed on a haswell
  GPU node (`khas002`) ran at 3.49 ns/day — roughly 12× slower than the
  43.7 ns/day achieved on A100. A senior user explicitly confirmed these
  nodes are unreliable. They are excluded by requesting `centos=icelake`.
- **CPU nodes have no GPUs**, so requesting `ngpus=1` automatically excludes
  them from GPU scheduling.

---

## 3. Scheduler Queues

| Queue | Priority | GPU | Limits | Notes |
|-------|----------|-----|--------|-------|
| `standard` | 0 | any | max walltime 168 h, max 50 run/user | Default queue |
| `high` | 20 | any | max walltime 168 h | Higher scheduling priority |
| `scai_q` | 0 | GPU-only (min 1, max 8) | max walltime 24 h, max 2 jobs/user, max 8 GPUs/user | GPU-dedicated queue |
| `workshop` | 0 | any | max walltime 168 h | Restricted user list |
| `serial` | 0 | any | max walltime 168 h | Restricted user list |

Key facts:

- Without `-q`, jobs go to the `standard` queue.
- `scai_q` requires `ngpus>=1` and allows up to 8 GPUs per user, but only two
  running jobs and two queued jobs per user — sequential submission is
  required, not bulk submission.
- `high` offers higher scheduling priority than `standard` while accepting the
  same node classes.
- The scheduler strongly favours GPU work: its job-sorting formula adds large
  bonuses for jobs requesting GPUs. Production jobs therefore tend to jump
  ahead of CPU work in the queue.

The default queue for the pipeline is `standard`. It is the tested path and is
sufficient when GPUs are available; GPU-heavy scheduling means even the
default queue places production jobs competitively.

---

## 4. Submitting Jobs with PBS

PBS is the primary execution path. It queues the job, selects a suitable node,
and manages resources. The job script declares its resource requirements via
`#PBS` directives.

### 4.1 CPU Jobs

CPU-only stages (setup, equilibration, analysis) request CPUs only:

```bash
#PBS -P helicases.spons
#PBS -N setup_<name>
#PBS -l select=1:ncpus=8:centos=skylake
#PBS -l walltime=02:00:00
#PBS -j oe
```

### 4.2 GPU Jobs

GPU stages (production MD) add a GPU request:

```bash
#PBS -P helicases.spons
#PBS -N md_<name>
#PBS -l select=1:ncpus=8:ngpus=1:centos=icelake
#PBS -l walltime=48:00:00
#PBS -j oe
```

The only difference from a CPU job is `:ngpus=1`. **For A100 the select line
must include `centos=icelake`.** Omitting it lets the scheduler land the job
on haswell or skylake GPU nodes, which are broken or slower.

### 4.3 Flag Reference

| Flag | Purpose | Value used |
|------|---------|------------|
| `-P` | Billing project | `helicases.spons` |
| `-N` | Job name shown in `qstat` | descriptive name |
| `-l select=1:ncpus=8` | One chunk, eight CPU cores | PBS chooses the node |
| `:ngpus=1` | Request one GPU (omitted for CPU) | production only |
| `:centos=icelake` | Node class constraint | targets A100, excludes haswell |
| `-l walltime=` | Maximum wall-clock time | short for CPU, long for GPU |
| `-q <queue>` | Queue selection | `high` / `scai_q` / default |
| `-j oe` | Merge output and error into one file | cleaner logs |

### 4.4 Selecting a Specific Node

To target a specific free GPU node (one reporting `0 GPUs used`):

```bash
pbsnodes -a | awk '/^aice/ {node=$1} /resources_assigned.ngpus/ && node ~ /^aice/ {ngpu=$3} /state = free/ && node ~ /^aice/ && ngpu == 0 {print node}'
```

Then submit with the host pinned inside the select line:

```bash
qsub -l select=1:host=aice014:ncpus=8:ngpus=1:centos=icelake ...
```

Pinning does not guarantee faster execution — the scheduler still applies
queue priority — but it can place work on a known-free A100.

### 4.5 Passing Variables

Variables are passed to the job script with `-v`:

```bash
qsub -v SYSTEM=blm_kras_k run_full_pipeline.pbs
```

### 4.6 Checking Job Status

```bash
qstat -u <user>                       # list all jobs for the user
qstat -xf <job_id> | grep exit_status # 0 = success
qstat -xf <job_id> | grep job_state   # R=running, Q=queued, F=finished
```

### 4.7 Chaining Jobs

Production replicates are chained with a completion dependency so the next
job only starts after the previous one succeeds:

```bash
qsub -W depend=afterok:<job_id> submit_hpc.pbs
```

### 4.8 Why Only These Flags

The scheduler decides the remaining details itself — which queue, which node,
how to allocate. Extra or conflicting flags can interfere with those
decisions. Only the flags listed above have been verified on this cluster and
should be used.

---

## 5. Direct SSH to Compute Nodes

Direct SSH is an alternative to PBS. It connects straight to a free compute
node and runs commands with no queue and no project code. It is the right
choice when the queue is slow or stuck, when PBS rejects the project, or when
a quick test is needed. For long production runs PBS is safer because the
node is shared — a direct connection can be displaced when the scheduler
assigns the node to another job.

### 5.1 Finding Free GPU Nodes

A node reporting `state = free` does **not** mean its GPUs are free. The GPU
allocation must be checked separately via `resources_assigned.ngpus = 0`:

```bash
pbsnodes -a | awk '/^aice/ {node=$1} /resources_assigned.ngpus/ && node ~ /^aice/ {ngpu=$3} /state = free/ && node ~ /^aice/ && ngpu == 0 {print node, "GPUs FREE"}' | sort -u
```

Replace `aice` with `vsky` to inspect other GPU classes.

### 5.2 Verifying a GPU Is Actually Free

Even after selection, confirm the GPU is idle before starting work:

```bash
ssh <node> "nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader"
```

Low utilisation (<10%) and low memory usage indicate a genuinely free GPU.

### 5.3 Finding Free CPU Nodes

```bash
pbsnodes -a | awk '/^csky/ {node=$1} /state = free/ && node ~ /^csky/ {print node}' | sort -u
```

Replace `csky` with `cice` or `cgen` for other CPU classes.

### 5.4 SSH Keys

For repeated direct access, set up a key once so later connections do not
prompt for the password:

```bash
ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ""   # if no key exists
ssh-copy-id <node>                          # prompts for the password once
```

### 5.5 Loading the GROMACS Environment

`module load apps/gromacs/2023.2/gnu` works correctly on compute nodes and
sets `PATH`, `LD_LIBRARY_PATH`, and the CUDA libraries automatically.

### 5.6 Running Interactively

```bash
ssh <node>
module load apps/gromacs/2023.2/gnu
cd ~/simulations/projects/<system_name>
gmx_mpi ...
```

### 5.7 Long-Running Work (tmux)

SSH sessions can drop during long processes. Run work inside `tmux` so it
survives a disconnect:

```bash
ssh <node>
tmux new -s md
module load apps/gromacs/2023.2/gnu
cd ~/simulations/projects/<system_name>
# run commands; detach with Ctrl+B, D; reattach with: tmux attach -t md
```

### 5.8 Manual Environment Setup (Fallback)

If `module load` is unavailable, the environment can be assembled manually:

```bash
export PATH=/home/apps/centos7/gromacs/2023.2/gcc9.1_ompi4.1.2/bin:/home/soft/centOS/compilers/gcc/openmpi/4.1.2/bin:$PATH
export LD_LIBRARY_PATH=/home/soft/cuda-11.0.2/lib64:/home/apps/centos7/gromacs/2023.2/gcc9.1_ompi4.1.2/lib64:/home/soft/centOS/compilers/gcc/openmpi/4.1.2/lib:/opt/pbs/2024.1.5/lib:$LD_LIBRARY_PATH
export OMP_NUM_THREADS=8
```

The required libraries are `libcufft.so.10` (CUDA FFT), `libgromacs_mpi.so.8`
(GROMACS), and `libmpi.so.40` (OpenMPI).

### 5.9 When Direct SSH Fails

If connections keep dropping or libraries cannot be found, return to PBS with
the `high` queue, which sets up the environment correctly and runs reliably:

```bash
qsub -P helicases.spons -q high -l select=1:ncpus=8:ngpus=1:centos=icelake -l walltime=01:00:00 -v SYSTEM=<name> -j oe ~/simulations/md_pipeline/<name>/hpc/run_full_pipeline.pbs
```

---

## 6. Environment: Module vs Direct Paths

GROMACS is available through both mechanisms:

- **In PBS scripts** — `module load apps/gromacs/2023.2/gnu` works and is the
  recommended path.
- **In direct SSH** — `module load` also works correctly on compute nodes
  (validated).
- **Direct paths** — the GROMACS binaries live at
  `/home/apps/centos7/gromacs/2023.2/gcc9.1_ompi4.1.2/bin/` and the OpenMPI
  binaries at `/home/soft/centOS/compilers/gcc/openmpi/4.1.2/bin/`. These can
  be added to `PATH` directly when modules are unavailable.

---

## 7. Troubleshooting

| Symptom | Resolution |
|---------|------------|
| Job stuck in queue (`Q`) | Try the `high` or `scai_q` queue; GPU-heavy jobs are already prioritised |
| Walltime exceeded | Increase `-l walltime` and ensure `CHUNK_NS` fits inside it |
| GPU not available | Inspect `pbsnodes -a` for nodes with free GPUs and pin the host |
| Project not found | Pass `-P helicases.spons` |
| Unexpectedly slow run | Confirm the job landed on A100 (`centos=icelake`), not haswell/skylake |

---

## 8. Operational Rules (Hard-Won Lessons)

1. **A100 only for production.** Always request `centos=icelake` for GPU work.
2. **Never use haswell nodes** (`khas*`, `chas*`). They are broken and
   measured ~12× slower than A100.
3. **Never run heavy jobs on login nodes.** They are for file management and
   submission.
4. **Respect `scai_q` limits.** Two running + two queued jobs per user — submit
   sequentially.
5. **Prefer PBS over direct SSH for long runs.** A direct session can be
   displaced by the scheduler on a shared node.
6. **Chunk sizes must fit walltime.** A chunk that cannot finish within the
   job's walltime is killed mid-run; size `CHUNK_NS` so each chunk completes
   with margin.
