# Equilibration

**NVT (500 ps) → NPT (500 ps), Position Restraints**

---

## NVT Equilibration

### Protocol

- **Ensemble:** NVT (canonical)
- **Temperature:** 300 K
- **Thermostat:** V-rescale (Bussi-Donadio-Parrinello)
- **Duration:** 500 ps (250,000 steps)
- **Timestep:** 0.002 ps
- **Position restraints:** Yes (1000 kJ/mol/nm²)

### MDP File (mdp/nvt.mdp)

```mdp
; NVT equilibration
integrator          = md
dt                  = 0.002
nsteps              = 250000

; Output
nstxout             = 0
nstvout             = 0
nstfout             = 0
nstxout-compressed  = 25000
nstlog              = 2500
nstenergy           = 2500
nstcalcenergy       = 100

; Neighbor searching
cutoff-scheme       = Verlet
ns_type             = Grid
nstlist             = 400
rlist               = 1.0
rcoulomb            = 1.0
rvdw                = 1.0

; Electrostatics
coulombtype         = PME
pme_order           = 4
fourierspacing      = 0.12

; VdW
DispCorr            = EnerPres

; Temperature
tcoupl              = V-rescale
tc-grps             = Protein_DNA Water_Ions
tau_t               = 0.1     0.1
ref_t               = 300     300

; Pressure
pcoupl              = no

; Bonds
constraints         = h-bonds
constraint_algorithm = LINCS
lincs_iter          = 1
lincs_order         = 4

; Velocity generation
gen_vel             = yes
gen_temp            = 300
gen_seed            = 1993

; Position restraints
define              = -DPOSRES -DPOSRES_DNA
```

### Temperature Coupling

| Group | Thermostat | tau_t (ps) | ref_t (K) |
|-------|------------|------------|------------|
| Protein_DNA | V-rescale | 0.1 | 300 |
| Water_Ions | V-rescale | 0.1 | 300 |

### V-rescale Thermostat

- **Type:** Modified Berendsen thermostat (Bussi et al. 2007)
- **Citation:** Bussi G, Donadio D, Parrinello M. "Canonical sampling through
  velocity rescaling." *J Chem Phys* 2007; 126:014101. DOI: 10.1063/1.2408400
- **Coupling time:** 0.1 ps
- **Random seed:** 1993 (reproducibility)
- **Why:** Produces correct canonical (NVT) ensemble

### Velocity Generation

- **gen_vel:** yes (generate initial velocities)
- **gen_temp:** 300 K
- **gen_seed:** 1993 (random seed)
- **Reason:** Initial velocities from Maxwell-Boltzmann distribution

### Position Restraints

- **define:** `-DPOSRES -DPOSRES_DNA`
- **Force constant:** 1000 kJ/mol/nm²
- **Restrained atoms:** Protein backbone + DNA heavy atoms
- **Purpose:** Prevent large-scale unfolding during equilibration
- **Files:** `posre.itp` (protein), `posre_DNA.itp` (DNA)

## NPT Equilibration

### Protocol

- **Ensemble:** NPT (isothermal-isobaric)
- **Temperature:** 300 K
- **Pressure:** 1.0 bar
- **Thermostat:** V-rescale
- **Barostat:** Berendsen
- **Duration:** 500 ps (250,000 steps)
- **Timestep:** 0.002 ps
- **Position restraints:** Yes (1000 kJ/mol/nm²)

### MDP File (mdp/npt.mdp)

```mdp
; NPT equilibration
integrator          = md
dt                  = 0.002
nsteps              = 250000

; Output
nstxout             = 0
nstvout             = 0
nstfout             = 0
nstxout-compressed  = 25000
nstlog              = 2500
nstenergy           = 2500
nstcalcenergy       = 100

; Neighbor searching
cutoff-scheme       = Verlet
ns_type             = Grid
nstlist             = 400
rlist               = 1.0
rcoulomb            = 1.0
rvdw                = 1.0

; Electrostatics
coulombtype         = PME
pme_order           = 4
fourierspacing      = 0.12

; VdW
DispCorr            = EnerPres

; Temperature
tcoupl              = V-rescale
tc-grps             = Protein_DNA Water_Ions
tau_t               = 0.1     0.1
ref_t               = 300     300

; Pressure
pcoupl              = Berendsen
pcoupltype          = isotropic
tau_p               = 2.0
ref_p               = 1.0
compressibility     = 4.5e-5

; Bonds
constraints         = h-bonds
constraint_algorithm = LINCS
lincs_iter          = 1
lincs_order         = 4

; Position restraints
define              = -DPOSRES -DPOSRES_DNA
```

### Pressure Coupling

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| pcoupl | Berendsen | Semi-isotropic barostat |
| pcoupltype | isotropic | Uniform scaling in all directions |
| tau_p | 2.0 ps | Coupling time |
| ref_p | 1.0 bar | Reference pressure |
| compressibility | 4.5e-5 bar⁻¹ | Water compressibility |

### Berendsen Barostat

- **Type:** Weak coupling barostat
- **Citation:** Berendsen HJC, et al. "Molecular dynamics with coupling
  to an external bath." *J Chem Phys* 1984; 81:3684. DOI: 10.1063/1.448118
- **Pressure:** 1.0 bar (isotropic)
- **Coupling time:** 2.0 ps
- **Compressibility:** 4.5 × 10⁻⁵ bar⁻¹ (water)
- **Why:** Allows pressure to equilibrate without oscillations

### Why Berendsen for NPT?

- **Production:** Parrinello-Rahman (correct ensemble)
- **NPT equilibration:** Berendsen (faster pressure equilibration)
- **Reason:** Berendsen equilibrates pressure faster than Parrinello-Rahman
- **Trade-off:** Berendsen does not produce correct NPT ensemble (acceptable for equilibration)

## Execution

### Commands

```bash
# NVT equilibration
gmx grompp -f mdp/nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr
gmx mdrun -deffnm nvt

# NPT equilibration
gmx grompp -f mdp/npt.mdp -c nvt.gro -r nvt.gro -p topol.top -o npt.tpr
gmx mdrun -deffnm npt
```

### Input

- **NVT:** `em.gro` (from energy minimization)
- **NPT:** `nvt.gro` (from NVT equilibration)
- **Position restraints:** `em.gro` or `nvt.gro` (with `-r` flag)

### Output

- **NVT:** `nvt.gro`, `nvt.edr`, `nvt.xtc`
- **NPT:** `npt.gro`, `npt.edr`, `npt.xtc`

## Monitoring

### Temperature (NVT)

Check `nvt.edr` for temperature:

- **Target:** 300 K
- **Tolerance:** ±5 K
- **Convergence:** Should reach 300 K within ~100 ps

### Pressure (NPT)

Check `npt.edr` for pressure:

- **Target:** 1.0 bar
- **Tolerance:** ±10 bar
- **Convergence:** Should reach 1.0 bar within ~200 ps

### Density (NPT)

Check `npt.edr` for density:

- **Target:** ~1000 kg/m³ (water density)
- **Convergence:** Should reach ~1000 kg/m³ within ~200 ps

### Energy

Check `em.edr`, `nvt.edr`, `npt.edr` for:

- **Potential energy:** Should decrease during minimization
- **Kinetic energy:** Should increase during NVT
- **Total energy:** Should stabilize during NPT

## Common Issues

### Temperature Overshoot

- **Symptom:** Temperature oscillates wildly
- **Check:** tau_t too small or too large
- **Fix:** Adjust tau_t (0.1 ps is standard)

### Pressure Instability

- **Symptom:** Pressure oscillates wildly
- **Check:** tau_p too small or too large
- **Fix:** Adjust tau_p (2.0 ps is standard)

### Density Too High/Low

- **Symptom:** Density far from 1000 kg/m³
- **Check:** Box size or water model
- **Fix:** Ensure SPC/E water and correct box dimensions

### LINCS Warnings

- **Symptom:** "LINCS warning" in log
- **Check:** Constraints violated during dynamics
- **Fix:** Reduce timestep or check initial structure

## Validation

### NVT

- [x] Temperature reached 300 K
- [x] Temperature stable (±5 K)
- [x] No LINCS warnings
- [x] Kinetic energy reasonable

### NPT

- [x] Pressure reached 1.0 bar
- [x] Pressure stable (±10 bar)
- [x] Density ~1000 kg/m³
- [x] No volume changes
- [x] No LINCS warnings

## Evidence

- **NVT log:** `logs/nvt.log`
- **NVT energy:** `output/equilibration/nvt.edr`
- **NVT trajectory:** `output/equilibration/nvt.xtc`
- **NPT log:** `logs/npt.log`
- **NPT energy:** `output/equilibration/npt.edr`
- **NPT trajectory:** `output/equilibration/npt.xtc`

---

*See also: [PRODUCTION.md](PRODUCTION.md) for production MD protocol*
