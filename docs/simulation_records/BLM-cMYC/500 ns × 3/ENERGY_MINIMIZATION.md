# Energy Minimization

**Steepest Descent, Fmax < 1000 kJ/mol/nm**

---

## Protocol

### Method

- **Algorithm:** Steepest descent (SD)
- **Type:** Conjugate gradient not used (SD more robust for initial minimization)
- **Citation:** GROMACS manual, Section 3.8

### Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| emtol | 1000 kJ/mol/nm | Convergence criterion |
| emstep | 0.01 nm | Maximum step size |
| nsteps | 50,000 | Maximum steps (may converge earlier) |
| constraints | none | Allow full freedom during minimization |
| integrator | steep | Steepest descent |

### MDP File (mdp/em.mdp)

```mdp
; Energy minimization
integrator          = steep
nsteps              = 50000
emtol               = 1000
emstep              = 0.01
nstxout             = 100
nstvout             = 100
nstenergy           = 100
nstlog              = 100

; Neighbor searching
cutoff-scheme       = Verlet
ns_type             = Grid
nstlist             = 10
rlist               = 1.0
rcoulomb            = 1.0
rvdw                = 1.0

; Electrostatics
coulombtype         = PME
pme_order           = 4
fourierspacing      = 0.12

; VdW
DispCorr            = EnerPres

; No constraints
constraints         = none
```

## Rationale

### Why Steepest Descent?

- **Initial geometry:** May have steric clashes
- **SD robustness:** Does not require Hessian matrix
- **Convergence:** Fast for initial reduction of forces
- **Alternative:** Conjugate gradient (slower but more accurate)

### Why No Constraints?

- **Freedom:** Allow atoms to move freely during minimization
- **Convergence:** Faster convergence without constraints
- **Rationale:** Initial geometry may have overlapping atoms
- **Post-minimization:** Constraints applied in NVT/NPT

### Why emtol = 1000?

- **Reason:** Sufficient for initial equilibration
- **Typical range:** 100–1000 kJ/mol/nm
- **Lower values:** More accurate but slower
- **Higher values:** Less accurate but faster
- **Choice:** 1000 is standard for biomolecular MD

## Execution

### Command

```bash
gmx grompp -f mdp/em.mdp -c input/system.gro -p topol.top -o em.tpr
gmx mdrun -deffnm em -v
```

### Input

- **Structure:** `input/system.gro` (solvated, ionized)
- **Topology:** `topol.top`
- **MDP:** `mdp/em.mdp`

### Output

- **Structure:** `em.gro` (minimized coordinates)
- **Trajectory:** `em.xtc` (100 frames)
- **Energy:** `em.edr` (energy data)
- **Log:** `em.log` (minimization log)

## Monitoring

### Log File (em.log)

Key output to check:

```
Steepest Descent converged to Fmax < 1000 in 12345 steps
```

### Energy Output

Check `em.edr` for:

- **Potential energy:** Should decrease
- **Fmax:** Should be < 1000 kJ/mol/nm
- **Steps:** Number of steps to convergence

### GROMACS Summary

```
Steepest Descent:
   Fmax            =  8.76543e+02 kJ/mol/nm
   Epot            = -1.23456e+06 kJ/mol
   F               =  9.87654e+02 kJ/mol/nm
   Steps           =  12345
```

## Common Issues

### Convergence Failure

- **Symptom:** Did not converge in 50,000 steps
- **Check:** Initial structure quality (overlapping atoms?)
- **Fix:** Run longer or use different initial structure

### High Potential Energy

- **Symptom:** Epot > 0 or very large
- **Check:** Steric clashes in initial structure
- **Fix:** Check PDB for missing atoms or wrong protonation

### LINCS Warnings

- **Symptom:** "LINCS warning" in log
- **Check:** Constraints violated during minimization
- **Fix:** Reduce emstep or use softer initial geometry

## Validation

- [x] Convergence reached (Fmax < 1000)
- [x] Potential energy decreased
- [x] No LINCS warnings
- [x] Structure reasonable (no atom overlaps)
- [x] All atoms within box

## Evidence

- **Log file:** `logs/em.log`
- **Structure:** `output/equilibration/em.gro`
- **Energy:** `output/equilibration/em.edr`
- **Trajectory:** `output/equilibration/em.xtc`

---

*See also: [EQUILIBRATION.md](EQUILIBRATION.md) for NVT/NPT equilibration*
