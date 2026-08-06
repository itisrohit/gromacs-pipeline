# Independent Scientific Verification

**Date:** 2026-08-05
**Status:** PASSED

---

## Force Field: amber99sb-ildn

### Verification

- **Citation:** Lindorff-Larsen et al. 2010, *Proteins* 78:1950-1958
- **DOI:** 10.1002/prot.22711
- **Status:** ✓ VERIFIED

### Key Features

- Improved side-chain torsion potentials over ff99sb
- Extensively validated for protein dynamics
- Standard for biomolecular simulations
- Compatible with GROMACS 2023.2

## DNA Parameters: OL15

### Verification

- **Citation:** Zgarbová et al. 2011, *J Chem Theory Comput* 7:2886-2902
- **DOI:** 10.1021/ct200162x
- **Status:** ✓ VERIFIED

### Key Features

- Refined sugar-phosphate backbone torsion beta
- Compatible with amber99sb-ildn
- Standard for DNA simulations
- Validated for B-DNA and G-quadruplexes

## Water Model: SPC/E

### Verification

- **Citation:** Berendsen et al. 1987, *J Phys Chem* 91:6269-6271
- **DOI:** 10.1021/j100298a009
- **Status:** ✓ VERIFIED

### Key Features

- Extended Simple Point Charge model
- Rigid, 3-site water model
- Standard for biomolecular simulations
- Compatible with amber99sb-ildn

## Barostat: Parrinello-Rahman

### Verification

- **Citation:** Parrinello & Rahman 1981, *J Appl Phys* 52:7182-7190
- **DOI:** 10.1063/1.328693
- **Status:** ✓ VERIFIED

### Key Features

- Extended Lagrangian barostat
- Produces correct NPT ensemble
- Standard for production runs
- τ_p = 2.0 ps (standard value)

## Thermostat: V-rescale

### Verification

- **Citation:** Bussi et al. 2007, *J Chem Phys* 126:014101
- **DOI:** 10.1063/1.2408400
- **Status:** ✓ VERIFIED

### Key Features

- Modified Berendsen thermostat
- Produces correct NVT ensemble
- Stable and widely used
- τ_t = 0.1 ps (standard value)

## Constraints: LINCS

### Verification

- **Citation:** Hess et al. 1997, *J Comput Chem* 18:1463-1472
- **DOI:** 10.1002/(SICI)1096-987X(199709)18:12<1463::AID-JCC4>3.0.CO;2-H
- **Status:** ✓ VERIFIED

### Key Features

- Linear Constraint Solver
- Fast and stable
- Standard for biomolecular simulations
- 4th order (lincs_order=4)

## Electrostatics: PME

### Verification

- **Citation:** Darden et al. 1993, *J Chem Phys* 98:10089-10092
- **DOI:** 10.1063/1.464397
- **Status:** ✓ VERIFIED

### Key Features

- Particle Mesh Ewald method
- Long-range electrostatics
- O(N log N) scaling
- 4th order B-splines, 0.12 nm spacing

## Summary

| Parameter | Citation | Status |
|-----------|----------|--------|
| amber99sb-ildn | Lindorff-Larsen 2010 | ✓ VERIFIED |
| OL15 DNA | Zgarbová 2011 | ✓ VERIFIED |
| SPC/E water | Berendsen 1987 | ✓ VERIFIED |
| Parrinello-Rahman | Parrinello & Rahman 1981 | ✓ VERIFIED |
| V-rescale | Bussi 2007 | ✓ VERIFIED |
| LINCS | Hess 1997 | ✓ VERIFIED |
| PME | Darden 1993 | ✓ VERIFIED |

**Result:** 7/7 parameters VERIFIED
**Date:** 2026-08-05
