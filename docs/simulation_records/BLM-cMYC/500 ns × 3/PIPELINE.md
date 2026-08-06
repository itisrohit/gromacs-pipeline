# Pipeline & Workflow Details

**Automated GROMACS Pipeline with PBS Job Scheduling**

---

## Pipeline Overview

### Architecture

```
gromacs-pipeline/
├── run.sh                    # Main entry point
├── config.sh                 # Simulation parameters
├── setup/replicate.sh        # Create independent replicates
├── lib/stages.sh             # Stage execution logic
├── lib/gmx.sh                # GROMACS utilities
├── mdp/                      # MDP files (EM, NVT, NPT, MD)
├── profiles/iitd.sh          # Cluster-specific settings
├── post/prepare.sh           # Trajectory post-processing
├── docs/                     # Documentation
├── benchmark/                # Performance data
└── tests/                    # Validation scripts
```

### Workflow Stages

```
1. Structure Preparation
   └── pdb2gmx (amber99sb-ildn, SPC/E)

2. Solvation
   └── genbox (SPC/E water, dodecahedron)

3. Ionization
   └── genion (0.15 M KCl, neutralize)

4. Energy Minimization
   └── grompp + mdrun (steep, Fmax < 1000)

5. NVT Equilibration
   └── grompp + mdrun (500 ps, v-rescale 300K)

6. NPT Equilibration
   └── grompp + mdrun (500 ps, Berendsen 1 bar)

7. Production
   └── grompp + mdrun (500 ns, Parrinello-Rahman)
```

## Key Scripts

### run.sh (Main Entry Point)

```bash
# Submit all replicates
./run.sh submit --force

# Monitor running jobs
./run.sh monitor

# Check completion
./run.sh check
```

**Features:**
- Manages multiple replicates
- Handles job submission and monitoring
- Automatic checkpoint management
- Error recovery

### setup/replicate.sh (Create Replicates)

```bash
# Create a new replicate
./setup/replicate.sh blm_cmyc_prod_rep1
```

**Features:**
- Creates independent replicate directory
- Copies setup and equilibration outputs
- Generates configuration
- Initializes workflow state

### lib/stages.sh (Stage Execution)

**Stage Functions:**
- `run_stage_production()`: Production MD with extend-from-checkpoint
- `checkpoint_time_ps()`: Extract time from checkpoint
- `extend_from_checkpoint()`: Continue from checkpoint

### lib/gmx.sh (GROMACS Utilities)

**Functions:**
- `gmx_command()`: Execute GROMACS command
- `checkpoint_time_ps()`: Extract time from checkpoint
- `check_gmx_error()`: Check for GROMACS errors

### profiles/iitd.sh (Cluster Settings)

```bash
# IITD HPC specific settings
SELECT_GPU="-l select=1:ncpus=8:ngpus=1:centos=icelake"
WALLTIME="24:00:00"
```

**Features:**
- GPU selection (centos=icelake)
- Walltime limits
- Queue settings
- Project billing

### post/prepare.sh (Post-Processing)

```bash
# Post-process trajectory
./post/prepare.sh md.xtc md.tpr
```

**Features:**
- PBC correction (remove periodicity)
- Centering (protein in box)
- Fitting (RMSD to reference)
- Trajectory splitting

## Configuration

### config.sh (Simulation Parameters)

```bash
# Cluster
CLUSTER="iitd"
QUEUE="standard"
ACCOUNT="helicases.spons"

# Simulation
PRODUCTION_NS=500
CHUNK_NS=50
PROD_WALLTIME="24:00:00"

# Physics
FORCEFIELD="amber99sb-ildn"
WATER_MODEL="spce"
BOX_TYPE="dodecahedron"
BOX_DISTANCE="1.0"
SALT_CONC="0.15"
CATION="K"
ANION="CL"
```

### MDP Files

| File | Stage | Key Parameters |
|------|-------|----------------|
| mdp/em.mdp | EM | steep, emtol=1000, no constraints |
| mdp/nvt.mdp | NVT | v-rescale 300K, gen_vel=yes |
| mdp/npt.mdp | NPT | Berendsen 1 bar, τ_p=2.0 ps |
| mdp/md.mdp | Production | Parrinello-Rahman, nstlist=100 |

### PBS Scripts

**Job submission:**
```bash
#!/bin/bash
#PBS -N blm_cmyc_prod
#PBS -l select=1:ncpus=8:ngpus=1:centos=icelake
#PBS -l walltime=24:00:00
#PBS -q standard
#PBS -P helicases.spons
#PBS -j oe

cd $PBS_O_WORKDIR
module load gromacs/2023.2-plumed_2.10.0_dev
gmx mdrun -deffnm md -cpi md.cpt -append
```

## Workflow State

### .state/workflow.json

```json
{
  "replicate": "blm_cmyc_prod_rep1",
  "stages": {
    "setup": "completed",
    "equilibration": "completed",
    "production": "running"
  },
  "production": {
    "target_ns": 500,
    "current_ns": 3.3,
    "chunk": 1,
    "job_id": 972360
  }
}
```

### State Tracking

- **setup:** Structure preparation, solvation, ionization
- **equilibration:** EM, NVT, NPT
- **production:** 500 ns production MD

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| LINCS warning | Constraints violated | Check initial structure |
| PME error | Grid too small | Increase grid size |
| Segfault | Memory error | Reduce system size |
| Walltime exceeded | Job too long | Reduce chunk size |

### Recovery

```bash
# Restart from checkpoint
gmx mdrun -deffnm md -cpi md.cpt -append

# Reset workflow
./run.sh reset

# Check and fix errors
./run.sh check --fix
```

## Validation

- [x] Pipeline: `run.sh submit --force`
- [x] Replicates: 3 created via `setup/replicate.sh`
- [x] Config: Updated with correct parameters
- [x] Workflow state: Set to running
- [x] Jobs: Submitted (972360–972362)
- [x] Monitoring: qstat + log files

---

*See also: [REPRODUCIBILITY.md](REPRODUCIBILITY.md) for reproducibility details*
