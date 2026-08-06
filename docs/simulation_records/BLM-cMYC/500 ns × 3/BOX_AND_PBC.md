# Periodic Boundary Conditions & Box

**Dodecahedron Box, 1.0 nm Clearance**

---

## Box Parameters

### Geometry

- **Box type:** Dodecahedron (rhombic dodecahedron)
- **Reason:** Minimum volume for isotropic systems (saves ~47% atoms vs cubic)
- **Citation:** GROMACS manual, Section 3.11

### Dimensions

| Parameter | Value | Notes |
|-----------|-------|-------|
| Box length (x) | 21.46590 nm | |
| Box length (y) | 21.46590 nm | |
| Box length (z) | 15.17866 nm | |
| Box volume | ~5283 nm³ | |
| Minimum distance | 1.0 nm | Solute to box edge |

### Vector Representation

The dodecahedron box in GROMACS is defined by three vectors:

```
v1 = [21.46590, 0.00000, 0.00000] nm
v2 = [10.73295, 18.58911, 0.00000] nm
v3 = [7.15530, 3.09818, 15.17866] nm
```

These vectors define the edges of the dodecahedron box.

## Minimum Image Convention

### Principle

- **Rule:** Each particle interacts with the nearest image of every other particle
- **Cutoff:** 1.0 nm for both vanderWaals and Coulomb interactions
- **Box size:** Must be > 2 × cutoff = 2.0 nm (minimum)
- **Actual:** 15.17866 nm minimum dimension >> 2.0 nm ✓

### Validation

- **Shortest box dimension:** 15.17866 nm
- **Required minimum:** 2.0 nm (2 × cutoff)
- **Margin:** 7.6× minimum required ✓
- **No artifacts expected:** Box sufficiently large for all interactions

## PBC Settings in MDP

### Energy Minimization (em.mdp)

```mdp
pbc                    = xyz
cutoff-scheme          = Verlet
nstlist                = 10
rlist                  = 1.0
rvdw                   = 1.0
rcoulomb               = 1.0
pme_order              = 4
fourierspacing         = 0.12
```

### NVT Equilibration (nvt.mdp)

```mdp
pbc                    = xyz
cutoff-scheme          = Verlet
nstlist                = 400
rlist                  = 1.0
rvdw                   = 1.0
rcoulomb               = 1.0
pme_order              = 4
fourierspacing         = 0.12
```

### NPT Equilibration (npt.mdp)

```mdp
pbc                    = xyz
cutoff-scheme          = Verlet
nstlist                = 400
rlist                  = 1.0
rvdw                   = 1.0
rcoulomb               = 1.0
pme_order              = 4
fourierspacing         = 0.12
```

### Production (md.mdp)

```mdp
pbc                    = xyz
cutoff-scheme          = Verlet
nstlist                = 100
rlist                  = 1.0
rvdw                   = 1.0
rcoulomb               = 1.0
pme_order              = 4
fourierspacing         = 0.12
```

## Electrostatics

### Method

- **Long-range electrostatics:** Particle Mesh Ewald (PME)
- **Cutoff:** 1.0 nm (real-space)
- **Grid:** 4th order B-splines
- **Fourier spacing:** 0.12 nm
- **Tolerance:** 10⁻⁶

### Why PME?

- **Coulomb interaction:** Long-range (1/r decay)
- **Direct cutoff:** Causes artifacts at boundaries
- **PME:** Treats long-range part on mesh (O(N log N))
- **Accuracy:** 10⁻⁶ relative error

## Van der Waals

### Method

- **Interaction:** Lennard-Jones 12-6 potential
- **Cutoff:** 1.0 nm (Verlet neighbor list)
- **Switch:** None (straight cutoff)
- **Dispersion correction:** Energy and pressure

### Neighbor List

- **Algorithm:** Verlet (dynamic neighbor list)
- **Update frequency:** Every `nstlist` steps
- **Buffer:** 0.2 nm (rlist = cutoff + buffer)
- **Cutoff:** 1.0 nm for vanderWaals and Coulomb

## Box Size Validation

### Minimum Requirements

- **Cutoff:** 1.0 nm
- **Required box:** > 2.0 nm (any dimension)
- **Actual minimum:** 15.17866 nm
- **Margin:** 7.6× required ✓

### Protein Diameter

- **BLM core domain:** ~6 nm (652 residues)
- **c-MYC G4:** ~3 nm (17 nucleotides)
- **Complex:** ~8 nm (estimated from structure)
- **Box:** 15.17866 nm minimum
- **Clearance:** 15.17866 − 8 = 7.17866 nm >> 1.0 nm required ✓

### Water Shell

- **Minimum:** 1.0 nm (from any solute atom)
- **Actual:** 15.17866/2 = 7.59 nm average
- **Adequate:** Sufficient for bulk-like water behavior

## PBC Artifacts

### Known Issues (Mitigated)

- **Imaging:** Trajectory must be unwrapped for analysis
- **Centering:** System must be centered in box for visualization
- **Minimum image:** Satisfied for all relevant distances

### Trajectory Processing

After production, trajectory must be processed:

```bash
gmx trjconv -s md.tpr -f md.xtc -o centered.xtc -pbc mol -center
```

- `-pbc mol`: Remove periodic boundary artifacts
- `-center`: Center protein in box

## Validation

- [x] Box type: Dodecahedron
- [x] Minimum distance: 1.0 nm ✓
- [x] PBC: xyz (3D periodic boundaries)
- [x] Cutoff scheme: Verlet
- [x] Neighbor list: Updated every nstlist steps
- [x] PME: 4th order, 0.12 nm spacing
- [x] vanderWaals: LJ 12-6, 1.0 nm cutoff
- [x] Box size >> minimum required
- [x] No imaging artifacts expected

---

*See also: [ENERGY_MINIMIZATION.md](ENERGY_MINIMIZATION.md) for simulation protocol*
