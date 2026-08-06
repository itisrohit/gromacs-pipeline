# Pre-Production Audit: 12-Area Checklist

**Date:** 2026-08-05
**Status:** PASSED

---

## 1. Structure Preparation

- [x] BLM structure (PDB 4CGZ) downloaded
- [x] c-MYC G4 structure (PDB 2LBY) downloaded
- [x] HDOCK docking completed (model_2 selected)
- [x] Atomic overlap in model_1 identified and avoided
- [x] Structure cleaned (water, heteroatoms removed)
- [x] Hydrogen atoms added

## 2. Topology Generation (pdb2gmx)

- [x] Force field: amber99sb-ildn
- [x] Water model: SPC/E
- [x] Protonation: Neutral pH (7.0)
- [x] Protein topology: 10,077 atoms
- [x] DNA topology: 620 atoms
- [x] Ion molecule: 3 atoms (Zn + 2K)
- [x] Position restraints: Generated

## 3. Solvation

- [x] Box type: Dodecahedron
- [x] Minimum distance: 1.0 nm
- [x] Water model: SPC/E
- [x] Water molecules: 228,625
- [x] Box dimensions: 21.46590 × 21.46590 × 15.17866 nm

## 4. Ionization

- [x] Salt: 0.15 M KCl
- [x] Neutralize: Yes
- [x] Random seed: 1993
- [x] K⁺ ions: 650
- [x] Cl⁻ ions: 641
- [x] System neutral (0.0 net charge)

## 5. Energy Minimization

- [x] Algorithm: Steepest descent
- [x] Convergence: Fmax < 1000 kJ/mol/nm
- [x] Constraints: None
- [x] MDP file: mdp/em.mdp
- [x] Output: em.gro, em.edr, em.xtc

## 6. NVT Equilibration

- [x] Ensemble: NVT
- [x] Temperature: 300 K
- [x] Thermostat: V-rescale
- [x] Duration: 500 ps
- [x] Position restraints: Yes (1000 kJ/mol/nm²)
- [x] Velocity generation: Yes (gen_vel=yes, seed=1993)
- [x] MDP file: mdp/nvt.mdp
- [x] Output: nvt.gro, nvt.edr, nvt.xtc

## 7. NPT Equilibration

- [x] Ensemble: NPT
- [x] Temperature: 300 K
- [x] Pressure: 1.0 bar
- [x] Thermostat: V-rescale
- [x] Barostat: Berendsen
- [x] Duration: 500 ps
- [x] Position restraints: Yes (1000 kJ/mol/nm²)
- [x] MDP file: mdp/npt.mdp
- [x] Output: npt.gro, npt.edr, npt.xtc

## 8. Production MDP

- [x] Ensemble: NPT
- [x] Timestep: 0.002 ps
- [x] Duration: 500 ns (nsteps=-1)
- [x] Thermostat: V-rescale (300 K)
- [x] Barostat: Parrinello-Rahman (1 bar)
- [x] No position restraints
- [x] Neighbor list: Verlet, nstlist=100
- [x] Electrostatics: PME (4th order, 0.12 nm spacing)
- [x] vanderWaals: LJ 12-6, 1.0 nm cutoff
- [x] Constraints: LINCS, h-bonds, 4th order
- [x] MDP file: mdp/md.mdp

## 9. Hardware

- [x] Cluster: IITD HPC
- [x] GPU: NVIDIA A100 (80 GB)
- [x] Architecture: centos=icelake
- [x] CPUs: 8 cores per job
- [x] Walltime: 24 hours
- [x] Queue: standard
- [x] Project: helicases.spons

## 10. Pipeline

- [x] Main script: run.sh
- [x] Replicate script: setup/replicate.sh
- [x] Stages: lib/stages.sh
- [x] GROMACS utilities: lib/gmx.sh
- [x] Cluster profile: profiles/iitd.sh
- [x] Post-processing: post/prepare.sh
- [x] Config: config.sh

## 11. Documentation

- [x] README: gromacs-pipeline/README.md
- [x] HPC guide: docs/hpc_guide.md
- [x] Benchmark: docs/benchmark.md
- [x] Simulation records: docs/simulation_records/BLM-cMYC/500 ns × 3/
- [x] AGENTS.md: Updated

## 12. Reproducibility

- [x] All parameters recorded
- [x] Random seeds documented (gen_seed=1993, genion seed=1993)
- [x] Software versions specified (GROMACS 2023.2)
- [x] Hardware documented (A100, centos=icelake)
- [x] MDP files provided
- [x] Topology files available
- [x] Workflow documented

---

**Result:** 12/12 areas PASSED
**Date:** 2026-08-05
