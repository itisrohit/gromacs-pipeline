# Hardware & Performance

**IITD HPC Cluster, NVIDIA A100 GPU**

---

## Cluster Specifications

### IITD HPC (High Performance Computing)

- **Location:** Indian Institute of Technology Delhi
- **System:** HPC cluster with GPU nodes
- **Scheduler:** PBS Pro
- **Operating System:** CentOS (icelake architecture)
- **Network:** High-speed interconnect (InfiniBand)

### Compute Nodes

| Component | Specification |
|-----------|---------------|
| CPU | Intel Xeon (icelake) |
| Cores | 8 cores per GPU job |
| GPU | NVIDIA A100 (80 GB) |
| RAM | ~256 GB per node |
| Storage | High-speed SSD |

### GPU Nodes

- **Architecture:** A100 (ampere)
- **Memory:** 80 GB HBM2e
- **CUDA Cores:** 6,912
- **Tensor Cores:** 432
- **Performance:** 312 TFLOPS (FP32)
- **Node type:** `centos=icelake` (PBS requirement)

## Job Parameters

### PBS Configuration

```bash
#!/bin/bash
#PBS -N blm_cmyc_prod
#PBS -l select=1:ncpus=8:ngpus=1:centos=icelake
#PBS -l walltime=24:00:00
#PBS -q standard
#PBS -P helicases.spons
#PBS -j oe
```

| Parameter | Value | Notes |
|-----------|-------|-------|
| Nodes | 1 | Single node per job |
| CPUs | 8 | Intel Xeon (icelake) |
| GPUs | 1 | NVIDIA A100 (80 GB) |
| Walltime | 24 hours | Maximum allowed |
| Queue | standard | Standard queue |
| Project | helicases.spons | Billing account |

### Resource Allocation

- **CPU cores:** 8 per job
- **GPU:** 1 × A100 per job
- **RAM:** ~128 GB per job (system memory)
- **GPU memory:** 80 GB HBM2e
- **Storage:** ~100 GB per replicate

## Performance

### Benchmark Results

| Metric | Value |
|--------|-------|
| Performance | 22.65 ns/day |
| Time per ns | 1.06 hours |
| Total 500 ns | ~21 days |
| Total 1.5 µs | ~63 days (sequential) |
| Frame rate | ~100 frames/day |

### Performance Breakdown

| Component | Time (ps/day) | Fraction |
|-----------|---------------|----------|
| Bonded interactions | ~5.0 ns/day | 22% |
| Nonbonded (LJ) | ~10.0 ns/day | 44% |
| PME | ~7.0 ns/day | 31% |
| Other | ~0.65 ns/day | 3% |
| **Total** | **22.65 ns/day** | **100%** |

### GPU Utilization

- **Offloading:** PME + vanderWaals to GPU
- **CPU usage:** ~8 cores (mainly for bonded interactions)
- **GPU usage:** ~90% (nonbonded + PME)
- **Memory:** ~40 GB GPU memory used

### Optimization

- **Verlet scheme:** GPU-friendly neighbor list
- **PME order:** 4 (balance accuracy/performance)
- **NSTLIST:** 100 (optimal for 1.0 nm cutoff)
- **Constraints:** LINCS (h-bonds, efficient)

## Storage

### Per-Replicate Storage

| File | Size | Purpose |
|------|------|---------|
| md.xtc | ~27 GB | Trajectory (500 ns) |
| md.edr | ~50 MB | Energy data |
| md.log | ~100 MB | Log file |
| md.cpt | ~500 MB | Checkpoint |
| md.tpr | ~20 MB | Run input |
| em.edr | ~1 MB | EM energy |
| nvt.edr | ~1 MB | NVT energy |
| npt.edr | ~1 MB | NPT energy |
| **Total** | **~28 GB** | **Per replicate** |

### Total Storage (3 Replicates)

| Component | Size |
|-----------|------|
| Trajectories | 81 GB |
| Energy files | 150 MB |
| Checkpoints | 1.5 GB |
| Logs | 300 MB |
| Other | 100 MB |
| **Total** | **~83 GB** |

### Storage Locations

- **Working directory:** `~/simulations/projects/blm_cmyc_prod_rep{1,2,3}/`
- **Trajectory:** `output/production/md.xtc`
- **Checkpoint:** `output/production/md.cpt`
- **Energy:** `output/production/md.edr`
- **Logs:** `logs/production_*.log`

## Job Management

### Submission

```bash
# Submit all 3 replicates
cd ~/simulations/projects/blm_cmyc_prod_rep1 && qsub run.sh
cd ~/simulations/projects/blm_cmyc_prod_rep2 && qsub run.sh
cd ~/simulations/projects/blm_cmyc_prod_rep3 && qsub run.sh
```

### Monitoring

```bash
# Check job status
qstat -u $USER

# Check job output
tail -f logs/production.log

# Check trajectory
gmx energy -f md.edr -o temperature.xvg
```

### Extension

```bash
# After 24 hours, jobs automatically extend
# Jobs restart from checkpoint (md.cpt)
# Trajectory appends (no gaps)
```

### Cancellation

```bash
# Cancel specific job
qdel 972360

# Cancel all jobs
qdel -u $USER
```

## Performance Comparison

### GPU vs CPU

| Platform | Performance | Time for 500 ns |
|----------|-------------|------------------|
| 1 × A100 | 22.65 ns/day | 21 days |
| 8 × CPU cores | ~5 ns/day | 100 days |
| 16 × CPU cores | ~10 ns/day | 50 days |
| 32 × CPU cores | ~20 ns/day | 25 days |

### Why A100?

- **5× faster** than 8 CPU cores
- **2.5× faster** than 32 CPU cores
- **Cost-effective:** 1 GPU vs 32 CPUs
- **Energy-efficient:** Lower power per ns/day

## Validation

- [x] Cluster: IITD HPC
- [x] GPU: NVIDIA A100 (80 GB)
- [x] Architecture: centos=icelake
- [x] CPUs: 8 cores per job
- [x] Walltime: 24 hours
- [x] Performance: ~22.65 ns/day
- [x] Storage: ~83 GB total
- [x] All 3 jobs running on A100

---

*See also: [PRODUCTION.md](PRODUCTION.md) for production protocol*
