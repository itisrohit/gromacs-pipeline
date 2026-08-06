# Validation Checkpoints

**Pre-Production and Production Validation**

---

## Pre-Production Validation

### 1. Pre-Production Audit (12 Areas)

| Area | Status | Notes |
|------|--------|-------|
| 1. Structure preparation | ✓ PASSED | HDOCK model_2 selected |
| 2. pdb2gmx | ✓ PASSED | amber99sb-ildn, SPC/E |
| 3. Solvation | ✓ PASSED | 228,625 water molecules |
| 4. Ionization | ✓ PASSED | 0.15 M KCl, neutral |
| 5. Energy minimization | ✓ PASSED | Fmax < 1000 |
| 6. NVT equilibration | ✓ PASSED | 300 K, 500 ps |
| 7. NPT equilibration | ✓ PASSED | 1 bar, 500 ps |
| 8. Production MDP | ✓ PASSED | Parrinello-Rahman |
| 9. Hardware | ✓ PASSED | A100 GPU |
| 10. Pipeline | ✓ PASSED | All scripts working |
| 11. Documentation | ✓ PASSED | README complete |
| 12. Reproducibility | ✓ PASSED | All parameters recorded |

### 2. Independent Scientific Verification

| Parameter | Status | Reference |
|-----------|--------|-----------|
| amber99sb-ildn | ✓ VERIFIED | Lindorff-Larsen et al. 2010 |
| OL15 DNA | ✓ VERIFIED | Zgarbová et al. 2011 |
| SPC/E water | ✓ VERIFIED | Berendsen et al. 1987 |
| Parrinello-Rahman | ✓ VERIFIED | Parrinello & Rahman 1981 |
| LINCS constraints | ✓ VERIFIED | Hess et al. 1997 |
| PME electrostatics | ✓ VERIFIED | Darden et al. 1993 |

### 3. Pre-Production Input Inspection

| File | Status | Notes |
|------|--------|-------|
| system.pdb | ✓ INSPECTED | 5,434 atoms |
| topol.top | ✓ INSPECTED | All molecules defined |
| Protein_chain_A.itp | ✓ INSPECTED | 10,077 atoms |
| DNA_chain_B.itp | ✓ INSPECTED | 620 atoms |
| Ion.itp | ✓ INSPECTED | Zn + 2K, charge +4 |
| index.ndx | ✓ INSPECTED | Protein_DNA, Water_Ions |
| em.mdp | ✓ INSPECTED | Steepest descent |
| nvt.mdp | ✓ INSPECTED | V-rescale 300K |
| npt.mdp | ✓ INSPECTED | Berendsen 1 bar |
| md.mdp | ✓ INSPECTED | Parrinello-Rahman |
| config.sh | ✓ INSPECTED | All parameters correct |
| replicate.sh | ✓ INSPECTED | Works correctly |

### 4. Topology Charge Investigation

| Check | Status | Notes |
|-------|--------|-------|
| Ion molecule | ✓ IDENTIFIED | Zn + 2K, cosmetic grouping |
| Charge balance | ✓ VERIFIED | +5 -18 +4 +650 -641 = 0 |
| grompp check | ✓ PASSED | 0 fatal, 1 NOTE (expected) |
| Physical correctness | ✓ CONFIRMED | System is neutral |

## Production Validation

### 5. Production Launch

| Replicate | Status | Job ID |
|-----------|--------|--------|
| Replicate 1 | ✓ SUBMITTED | 972360 |
| Replicate 2 | ✓ SUBMITTED | 972361 |
| Replicate 3 | ✓ SUBMITTED | 972362 |

### 6. Production Health (A100)

| Check | Rep 1 | Rep 2 | Rep 3 |
|-------|-------|-------|-------|
| Job ID | 972360 | 972361 | 972362 |
| Node | aice* | aice* | aice* |
| GPU | A100 | A100 | A100 |
| Architecture | centos=icelake | centos=icelake | centos=icelake |
| Current time | ~3.3 ns | ~1.7 ns | ~2.0 ns |
| LINCS warnings | 0 | 0 | 0 |
| Fatal errors | 0 | 0 | 0 |
| Trajectory | Growing | Growing | Growing |
| Checkpoint | Valid | Valid | Valid |

### 7. Performance Check

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| ns/day | ~20-25 | 22.65 | ✓ PASS |
| Hours/ns | ~1.0-1.2 | 1.06 | ✓ PASS |
| GPU usage | ~90% | ~90% | ✓ PASS |
| Memory | < 80 GB | ~40 GB | ✓ PASS |

## Post-Completion Validation (Pending)

### 8. Structural Integrity

- [ ] Check trajectory for artifacts
- [ ] Verify box dimensions
- [ ] Check for atom overlaps
- [ ] Verify protein folding

### 9. Energy Statistics

- [ ] Check temperature stability
- [ ] Check pressure stability
- [ ] Check density stability
- [ ] Check total energy drift

### 10. Convergence Analysis

- [ ] RMSD convergence
- [ ] RMSF convergence
- [ ] Radius of gyration
- [ ] Secondary structure

### 11. Reproducibility

- [ ] Compare 3 replicates
- [ ] Check for drift
- [ ] Verify statistics

### 12. Documentation

- [ ] Update simulation records
- [ ] Add post-completion data
- [ ] Archive results

## Validation Timeline

| Date | Validation | Status |
|------|------------|--------|
| 2026-08-05 | Pre-production audit | ✓ PASSED |
| 2026-08-05 | Independent scientific verification | ✓ PASSED |
| 2026-08-05 | Pre-production input inspection | ✓ PASSED |
| 2026-08-05 | Topology charge investigation | ✓ PASSED |
| 2026-08-05 | Production launch | ✓ COMPLETED |
| 2026-08-05 | Production health check | ✓ VERIFIED |
| TBD | Post-completion | PENDING |

## Evidence

- **Audit log:** `docs/benchmark.md`
- **Verification log:** `docs/hpc_guide.md`
- **Inspection log:** `docs/simulation_records/`
- **Charge investigation:** `docs/simulation_records/BLM-cMYC/500 ns × 3/`
- **Production logs:** `logs/production_*.log`

---

*See also: [REPRODUCIBILITY.md](REPRODUCIBILITY.md) for reproducibility details*
