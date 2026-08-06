# BLM–c-MYC G4 Complex: 500 ns × 3 Production Simulation Record

**Status:** Production running on IITD HPC A100 GPUs (jobs 972360–972362)
**Target:** 500 ns × 3 independent replicates = 1.5 µs total
**Started:** 2026-08-05 (all 3 jobs submitted and confirmed on A100 nodes)

---

## Overview

This directory contains the complete scientific simulation record for the
Bloom syndrome helicase (BLM) bound to the c-MYC promoter G-quadruplex DNA
complex, simulated using GROMACS 2023.2 on the IITD HPC cluster.

## System

- **Protein:** BLM core domain (residues 639–1290, PDB: 4CGZ)
- **DNA:** c-MYC promoter G-quadruplex (17-mer, PDB: 2LBY)
- **Total atoms:** 697,864
- **Box:** Dodecahedron, 1.0 nm clearance, ~5283 nm³
- **Charge:** Neutral (+5 protein, −18 DNA, +4 ion, +650 K, −641 CL)
- **Ions:** 0.15 M KCl

## Force Field & Water Model

- **Force field:** amber99sb-ildn (Lindorff-Larsen et al. 2010)
- **DNA parameters:** OL15 (Zgarbová et al. 2011)
- **Water model:** SPC/E (Berendsen et al. 1987)
- **Ion parameters:** Parameters from amber99sb-ildn (OW, HW, K⁺, Cl⁻)

## Simulation Protocol

| Stage | Software | Duration | Key Settings |
|-------|----------|----------|--------------|
| Energy minimization | GROMACS 2023.2 | Until Fmax < 1000 kJ/mol/nm | Steepest descent, no constraints |
| NVT equilibration | GROMACS 2023.2 | 500 ps | v-rescale 300K, position restraints (1000 kJ/mol/nm²) |
| NPT equilibration | GROMACS 2023.2 | 500 ps | Berendsen barostat 1 bar, position restraints (1000 kJ/mol/nm²) |
| Production | GROMACS 2023.2 | 500 ns | Parrinello-Rahman 1 bar, v-rescale 300K, no restraints |
| **Production × 3** | **GROMACS 2023.2** | **500 ns each** | **Same as above, independent runs** |

## Hardware

- **Cluster:** IITD HPC (centos/icelake nodes)
- **CPU:** 8 cores per job (Intel Xeon, icelake architecture)
- **GPU:** 1 × NVIDIA A100 per job
- **Job scheduler:** PBS Pro
- **Performance:** ~20–25 ns/day on A100

## Replicates

| Replicate | Job ID | Status | Checkpoint |
|-----------|--------|--------|------------|
| Replicate 1 | 972360 | Running | md.cpt |
| Replicate 2 | 972361 | Running | md.cpt |
| Replicate 3 | 972362 | Running | md.cpt |

## Document Index

| Document | Description |
|----------|-------------|
| [SUMMARY.md](SUMMARY.md) | Execution summary and key results |
| [SYSTEM.md](SYSTEM.md) | Complete system description |
| [PREPARATION.md](PREPARATION.md) | Structure preparation workflow |
| [FORCEFIELD.md](FORCEFIELD.md) | Force field and parameter validation |
| [SOLVATION_AND_IONS.md](SOLVATION_AND_IONS.md) | Solvation and ion placement |
| [BOX_AND_PBC.md](BOX_AND_PBC.md) | Periodic boundary conditions |
| [ENERGY_MINIMIZATION.md](ENERGY_MINIMIZATION.md) | Energy minimization protocol |
| [EQUILIBRATION.md](EQUILIBRATION.md) | NVT and NPT equilibration |
| [PRODUCTION.md](PRODUCTION.md) | Production MD protocol |
| [HARDWARE.md](HARDWARE.md) | Hardware and performance details |
| [PIPELINE.md](PIPELINE.md) | Pipeline and workflow details |
| [VALIDATION.md](VALIDATION.md) | Validation checkpoints |
| [REPRODUCIBILITY.md](REPRODUCIBILITY.md) | Reproducibility information |
| [LIMITATIONS.md](LIMITATIONS.md) | Known limitations |
| [REFERENCES.md](REFERENCES.md) | Complete reference list |

## Quick Links

- **Pipeline code:** `gromacs-pipeline/` (itisrohit/gromacs-pipeline)
- **HPC project:** `~/simulations/projects/blm_cmyc_prod_rep{1,2,3}/`
- **HPC guide:** `docs/hpc_guide.md`
- **Benchmark:** `docs/benchmark.md`
