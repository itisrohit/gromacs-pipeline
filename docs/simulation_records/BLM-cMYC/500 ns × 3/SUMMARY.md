# Execution Summary

**BLM–c-MYC G4 Complex: 500 ns × 3 Independent Replicates**

---

## Quick Facts

| Parameter | Value |
|-----------|-------|
| System | BLM core domain (639–1290) + c-MYC G-quadruplex (17-mer) |
| Total atoms | 697,864 |
| Box type | Dodecahedron, 1.0 nm clearance |
| Force field | amber99sb-ildn + OL15 DNA + SPC/E water |
| Production duration | 500 ns × 3 replicates |
| Frame interval | 50 ps (25,000 steps × 0.002 ps) |
| Frames per replicate | 10,000 |
| Total frames | 30,000 |
| Estimated storage | ~80 GB total (3 × ~27 GB) |
| Hardware | IITD HPC A100 GPU (8 CPU cores) |
| Performance | ~20–25 ns/day per replicate |
| Total estimated time | ~20–25 days (wall clock, sequential GPU) |

## Topology Charge Accounting

| Molecule | Atoms | Charge | Notes |
|----------|-------|--------|-------|
| Protein_chain_A | 10,077 | +5.0 | Amber99sb-ildn protonation at pH 7 |
| DNA_chain_B | 620 | −18.0 | Standard B-DNA G4 parameters |
| Ion (Zn + 2K) | 3 | +4.0 | Cosmetic grouping by pdb2gmx |
| K⁺ | 650 | +650.0 | 0.15 M salt + charge neutralization |
| Cl⁻ | 641 | −641.0 | 0.15 M salt + charge neutralization |
| **Total** | **697,864** | **0.0** | **Neutral** |

## Execution Timeline

| Date | Event | Details |
|------|-------|---------|
| 2026-08-05 | Pre-production validation | 12-area audit PASSED |
| 2026-08-05 | Independent scientific verification | amber99sb-ildn, Parrinello-Rahman, SPC/E, LINCS verified |
| 2026-08-05 | Pre-production input inspection | 18 files, 72+ parameters verified |
| 2026-08-05 | Topology charge investigation | Root cause identified, neutrality confirmed |
| 2026-08-05 | Production launch | 3 replicates submitted |
| 2026-08-05 | Production confirmed | Jobs 972360–972362 on A100 GPUs |
| 2026-08-05 | Documentation started | This simulation record |

## Pipeline Workflow

```
Structure Preparation
    ├── HDOCK docking (model_2 selected)
    ├── pdb2gmx (amber99sb-ildn, SPC/E, neutral pH)
    └── Solvation + ion addition (0.15 M KCl)

Energy Minimization
    ├── Steepest descent (50,000 steps max)
    └── Convergence: Fmax < 1000 kJ/mol/nm

NVT Equilibration
    ├── v-rescale thermostat (300K)
    ├── Position restraints (1000 kJ/mol/nm²)
    └── Duration: 500 ps (250,000 steps)

NPT Equilibration
    ├── Berendsen barostat (1 bar)
    ├── Position restraints (1000 kJ/mol/nm²)
    └── Duration: 500 ps (250,000 steps)

Production
    ├── Parrinello-Rahman barostat (1 bar)
    ├── v-rescale thermostat (300K)
    ├── No restraints
    ├── Duration: 500 ns (250,000,000 steps)
    └── 50 ns chunks (extend-from-checkpoint)
```

## Key Files

```
blm_cmyc_prod_rep{1,2,3}/
├── config.sh                    # Simulation parameters
├── .state/workflow.json         # Pipeline state
├── input/
│   └── system.pdb              # Input structure
├── output/
│   ├── setup/
│   │   ├── topol.top           # System topology
│   │   ├── topol_Protein_chain_A.itp
│   │   ├── topol_DNA_chain_B.itp
│   │   └── index.ndx           # Index groups
│   ├── equilibration/
│   │   ├── nvt.gro             # NVT output
│   │   └── npt.gro             # NPT output
│   └── production/
│       ├── md.cpt              # Checkpoint (extendable)
│       ├── md.xtc              # Trajectory (~27 GB)
│       ├── md.edr              # Energy data
│       └── md.log              # Log file
├── mdp/
│   ├── em.mdp                  # Energy minimization
│   ├── nvt.mdp                 # NVT equilibration
│   ├── npt.mdp                 # NPT equilibration
│   └── md.mdp                  # Production
└── logs/
    ├── em.log                  # EM log
    ├── nvt.log                 # NVT log
    ├── npt.log                 # NPT log
    └── production_*.log        # Production logs
```

## Validation Checkpoints

- [x] Pre-production: 12-area audit PASSED
- [x] Independent scientific verification PASSED
- [x] Pre-production input inspection PASSED
- [x] Topology charge investigation PASSED
- [x] Production launch: 3/3 jobs submitted
- [x] Production confirmed on A100: 3/3 running
- [x] Production health verified: 0 LINCS warnings, all on GPU
- [ ] Post-completion: structural integrity check
- [ ] Post-completion: energy statistics analysis
- [ ] Post-completion: convergence analysis
- [ ] Post-completion: RMSD/RMSF analysis

---

*Last updated: 2026-08-05*
*Documentation status: Phase 1 (pre-completion)*
