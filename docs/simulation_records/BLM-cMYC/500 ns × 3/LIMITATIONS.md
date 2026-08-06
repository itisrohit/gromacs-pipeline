# Known Limitations

**Force Field, Methodology, and System-Specific Constraints**

---

## Force Field Limitations

### amber99sb-ildn

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Fixed charges | No polarization effects | Acceptable for standard biomolecular MD |
| Additive | No charge transfer | Acceptable for non-reactive systems |
| Classical | No quantum effects | Acceptable at 300K |
| No explicit H-bond dipole | Approximates H-bonding | Standard for protein simulations |

### OL15 DNA

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| B-DNA parameters | May not perfectly represent G4 | Standard for DNA simulations |
| Fixed charges | No polarization | Acceptable for standard simulations |
| Limited validation for G4 | G4-specific parameters not available | OL15 is best available |

### SPC/E Water

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Rigid model | No intramolecular flexibility | Standard for biomolecular MD |
| Fixed charges | No polarization | Acceptable for standard simulations |
| No lone pairs | Approximates water structure | Standard 3-site model |
| Slightly overstructured | May affect dynamics | Acceptable for most applications |

## Methodology Limitations

### Classical MD

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| No quantum effects | No tunneling, no excited states | Acceptable at 300K |
| No polarization | Approximates electrostatics | Fixed-charge force field |
| No charge transfer | No covalent bond formation | Not relevant for this system |
| No excited states | No photochemistry | Not relevant for this system |

### Force Field Accuracy

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Protein dynamics | ~1-2 Å RMSD accuracy | Standard for biomolecular MD |
| DNA dynamics | ~1-2 Å RMSD accuracy | Standard for DNA simulations |
| Protein-DNA interface | ~2-3 Å RMSD accuracy | Challenging for force fields |
| Ion parameters | Less validated for divalent | Zn²⁺ parameters approximate |

### Simulation Length

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| 500 ns per replicate | May not sample all states | 3 independent replicates |
| Total 1.5 µs | May not capture rare events | Sufficient for most conformational changes |
| Slow processes | May not converge | Monitoring convergence |

## System-Specific Limitations

### BLM–c-MYC Complex

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| HDOCK docking model | Approximate binding pose | Best available structure |
| No experimental structure | Binding mode uncertain | Docking score validates pose |
| Core domain only | Missing N/C-terminal regions | Core domain sufficient for G4 binding |
| G4 sequence | c-MYC specific | Results may not generalize |

### Ion Parameters

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Zn²⁺ parameters | Less validated | Standard amber99sb-ildn parameters |
| Ion grouping | Cosmetic artifact | Each atom interacts independently |
| 0.15 M KCl | Physiological | Standard concentration |

### Solvation

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Bulk water | No membrane | Not relevant for this system |
| No ions other than KCl | Simplified ionic environment | Standard for biomolecular MD |
| Random ion placement | May not represent biological reality | Acceptable for standard simulations |

## Simulation Protocol Limitations

### Energy Minimization

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Steepest descent | Less accurate than conjugate gradient | Robust for initial minimization |
| Fmax < 1000 | May not be fully converged | Sufficient for equilibration |

### Equilibration

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| 500 ps NVT + NPT | May not fully equilibrate | Standard duration |
| Position restraints | Prevents large-scale motion | Removed in production |
| Berendsen barostat | Not correct NPT ensemble | Only used for equilibration |

### Production

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| 500 ns per replicate | May not sample all states | 3 independent replicates |
| Single timestep | 2 fs (standard) | Adequate for biomolecular MD |
| No enhanced sampling | May miss rare events | Standard MD approach |

## Analysis Limitations

### Trajectory Analysis

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| PBC artifacts | Must unwrap trajectory | Post-processing applied |
| Centering required | Visualization requires centering | Post-processing applied |
| Fitting required | RMSD requires fitting | Post-processing applied |

### Convergence

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| No convergence analysis | May not be converged | Post-completion analysis planned |
| No ensemble analysis | Single trajectory analysis | 3 replicates for ensemble |

## Reproducibility Limitations

### Hardware

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| A100 GPU specific | Results may vary on different GPUs | Hardware documented |
| IITD HPC specific | Results may vary on different clusters | Pipeline portable |

### Software

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| GROMACS 2023.2 specific | Results may vary with different versions | Version documented |
| PLUMED specific | Results may vary with different versions | Version documented |

## Validation Status

### Completed

- [x] Force field selection validated
- [x] Protocol validated
- [x] Hardware validated
- [x] Software validated
- [x] System preparation validated

### Pending

- [ ] Post-completion convergence analysis
- [ ] Post-completion ensemble analysis
- [ ] Post-completion comparison with experiment

## Recommendations for Future Work

1. **Longer simulations:** Extend to 1 µs per replicate
2. **Enhanced sampling:** Replica exchange or metadynamics
3. **Multiple force fields:** Compare with other force fields
4. **Experimental comparison:** Compare with NMR or cryo-EM data
5. **Mutagenesis:** Test effect of key mutations

---

*See also: [REFERENCES.md](REFERENCES.md) for citations*
