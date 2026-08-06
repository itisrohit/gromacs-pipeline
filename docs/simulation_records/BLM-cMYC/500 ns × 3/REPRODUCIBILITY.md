# Reproducibility

**Complete Parameter Record for Replication**

---

## Reproducibility Statement

This simulation record provides all information necessary to independently
replicate the BLM–c-MYC G4 500 ns × 3 production simulation. All parameters,
software versions, hardware specifications, and random seeds are recorded.

## Software Versions

| Software | Version | Citation |
|----------|---------|----------|
| GROMACS | 2023.2-plumed_2.10.0_dev | Abraham et al. 2015 |
| PLUMED | 2.10.0_dev | Tribello et al. 2014 |
| PBS Pro | Latest | OpenPBS |
| Python | 3.x | Standard |
| Bash | 4.x | Standard |

## Hardware

| Component | Specification |
|-----------|---------------|
| Cluster | IITD HPC |
| CPU | Intel Xeon (icelake) |
| Cores | 8 per job |
| GPU | NVIDIA A100 (80 GB) |
| RAM | ~128 GB per job |
| Architecture | centos=icelake |

## Force Field Parameters

### amber99sb-ildn

- **Citation:** Lindorff-Larsen et al. 2010, *Proteins* 78:1950
- **DOI:** 10.1002/prot.22711
- **Files:** `amber99sb-ildn.ff/`

### OL15 DNA

- **Citation:** Zgarbová et al. 2011, *J Chem Theory Comput* 7:2886
- **DOI:** 10.1021/ct200162x
- **Files:** Included in `amber99sb-ildn.ff/`

### SPC/E Water

- **Citation:** Berendsen et al. 1987, *J Phys Chem* 91:6269
- **DOI:** 10.1021/j100298a009
- **Files:** `amber99sb-ildn.ff/waterModels/spce.gro`

## MDP Parameters

### Energy Minimization (em.mdp)

```mdp
integrator          = steep
nsteps              = 50000
emtol               = 1000
emstep              = 0.01
constraints         = none
cutoff-scheme       = Verlet
nstlist             = 10
rlist               = 1.0
rcoulomb            = 1.0
rvdw                = 1.0
coulombtype         = PME
pme_order           = 4
fourierspacing      = 0.12
```

### NVT Equilibration (nvt.mdp)

```mdp
integrator          = md
dt                  = 0.002
nsteps              = 250000
tcoupl              = V-rescale
tc-grps             = Protein_DNA Water_Ions
tau_t               = 0.1     0.1
ref_t               = 300     300
pcoupl              = no
constraints         = h-bonds
constraint_algorithm = LINCS
lincs_iter          = 1
lincs_order         = 4
gen_vel             = yes
gen_temp            = 300
gen_seed            = 1993
define              = -DPOSRES -DPOSRES_DNA
pbc                 = xyz
cutoff-scheme       = Verlet
ns_type             = Grid
nstlist             = 400
rlist               = 1.0
rcoulomb            = 1.0
rvdw                = 1.0
coulombtype         = PME
pme_order           = 4
fourierspacing      = 0.12
DispCorr            = EnerPres
nstxout-compressed  = 25000
nstlog              = 2500
nstenergy           = 2500
nstcalcenergy       = 100
```

### NPT Equilibration (npt.mdp)

```mdp
integrator          = md
dt                  = 0.002
nsteps              = 250000
tcoupl              = V-rescale
tc-grps             = Protein_DNA Water_Ions
tau_t               = 0.1     0.1
ref_t               = 300     300
pcoupl              = Berendsen
pcoupltype          = isotropic
tau_p               = 2.0
ref_p               = 1.0
compressibility     = 4.5e-5
constraints         = h-bonds
constraint_algorithm = LINCS
lincs_iter          = 1
lincs_order         = 4
define              = -DPOSRES -DPOSRES_DNA
pbc                 = xyz
cutoff-scheme       = Verlet
ns_type             = Grid
nstlist             = 400
rlist               = 1.0
rcoulomb            = 1.0
rvdw                = 1.0
coulombtype         = PME
pme_order           = 4
fourierspacing      = 0.12
DispCorr            = EnerPres
nstxout-compressed  = 25000
nstlog              = 2500
nstenergy           = 2500
nstcalcenergy       = 100
```

### Production (md.mdp)

```mdp
integrator          = md
dt                  = 0.002
nsteps              = -1
tcoupl              = V-rescale
tc-grps             = Protein_DNA Water_Ions
tau_t               = 0.1     0.1
ref_t               = 300     300
pcoupl              = Parrinello-Rahman
pcoupltype          = isotropic
tau_p               = 2.0
ref_p               = 1.0
compressibility     = 4.5e-5
constraints         = h-bonds
constraint_algorithm = LINCS
lincs_iter          = 1
lincs_order         = 4
continuation        = yes
pbc                 = xyz
cutoff-scheme       = Verlet
ns_type             = Grid
nstlist             = 100
rlist               = 1.0
rcoulomb            = 1.0
rvdw                = 1.0
coulombtype         = PME
pme_order           = 4
fourierspacing      = 0.12
DispCorr            = EnerPres
nstxout-compressed  = 25000
nstlog              = 2500
nstenergy           = 2500
nstcalcenergy       = 100
```

## Random Seeds

| Parameter | Value | Purpose |
|-----------|-------|---------|
| gen_seed (NVT) | 1993 | Velocity generation |
| genion seed | 1993 | Ion placement |

## System Parameters

| Parameter | Value |
|-----------|-------|
| Protein atoms | 10,077 |
| DNA atoms | 620 |
| Ion atoms | 3 |
| Water molecules | 228,625 |
| K⁺ ions | 650 |
| Cl⁻ ions | 641 |
| Total atoms | 697,864 |
| Box type | Dodecahedron |
| Box dimensions | 21.46590 × 21.46590 × 15.17866 nm |
| Box volume | ~5283 nm³ |
| Solute-box distance | 1.0 nm |
| Salt concentration | 0.15 M |
| Net charge | 0.0 |

## Simulation Parameters

| Parameter | Value |
|-----------|-------|
| Timestep | 0.002 ps |
| Production duration | 500 ns per replicate |
| Total production | 1.5 µs |
| Frame interval | 50 ps |
| Frames per replicate | 10,000 |
| Total frames | 30,000 |
| Neighbor list | Verlet, nstlist=100 |
| Electrostatics | PME, 4th order, 0.12 nm spacing |
| vanderWaals | LJ 12-6, 1.0 nm cutoff |
| Temperature | 300 K (V-rescale) |
| Pressure | 1.0 bar (Parrinello-Rahman) |
| Constraints | LINCS, h-bonds, 4th order |

## Replication Steps

### 1. Clone Repository

```bash
git clone https://github.com/itisrohit/gromacs-pipeline.git
cd gromacs-pipeline
```

### 2. Install GROMACS

```bash
# Install GROMACS 2023.2 with PLUMED
# See GROMACS documentation for details
```

### 3. Prepare Input

```bash
# Download BLM structure (PDB: 4CGZ)
# Download c-MYC G4 structure (PDB: 2LBY)
# Dock using HDOCK
# Clean structure
```

### 4. Run Pipeline

```bash
# Create replicate
./setup/replicate.sh blm_cmyc_rep1

# Edit config.sh if needed
# Submit jobs
./run.sh submit
```

### 5. Monitor

```bash
# Check job status
qstat -u $USER

# Check logs
tail -f logs/production.log
```

## Validation

- [x] All parameters recorded
- [x] Random seeds documented
- [x] Software versions specified
- [x] Hardware documented
- [x] MDP files provided
- [x] Topology files available
- [x] Workflow documented

## Evidence

- **MDP files:** `mdp/em.mdp`, `mdp/nvt.mdp`, `mdp/npt.mdp`, `mdp/md.mdp`
- **Config:** `config.sh`
- **Pipeline:** `run.sh`, `setup/replicate.sh`
- **Documentation:** This file

---

*See also: [LIMITATIONS.md](LIMITATIONS.md) for known limitations*
