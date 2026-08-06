# Production MD Protocol

**500 ns × 3 Replicates, Parrinello-Rahman, A100 GPU**

---

## Protocol

### Method

- **Ensemble:** NPT (isothermal-isobaric)
- **Timestep:** 0.002 ps (2 fs)
- **Duration:** 500 ns per replicate (250,000,000 steps)
- **Total:** 1.5 µs (3 × 500 ns)

### MDP File (mdp/md.mdp)

```mdp
; Production MD
integrator          = md
dt                  = 0.002
nsteps              = -1

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
nstlist             = 100
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
pcoupl              = Parrinello-Rahman
pcoupltype          = isotropic
tau_p               = 2.0
ref_p               = 1.0
compressibility     = 4.5e-5

; Bonds
constraints         = h-bonds
constraint_algorithm = LINCS
lincs_iter          = 1
lincs_order         = 4

; Continuation
continuation        = yes
```

### Key Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| dt | 0.002 ps | Standard for biomolecular MD |
| nsteps | -1 | Indefinite (extend from checkpoint) |
| nstlist | 100 | Update neighbor list every 100 steps |
| nstxout-compressed | 25000 | Frame every 50 ps |
| nstlog | 2500 | Log every 5 ps |
| nstenergy | 2500 | Energy every 5 ps |
| nstcalcenergy | 100 | Calculate energy every 100 steps |

## Temperature Control

### V-rescale Thermostat

- **Type:** Modified Berendsen thermostat (Bussi-Donadio-Parrinello)
- **Coupling time:** τ_t = 0.1 ps
- **Reference temperature:** 300 K
- **Group coupling:** Protein_DNA and Water_Ions (separate coupling)
- **Citation:** Bussi et al. 2007, *J Chem Phys* 126:014101

### Why V-rescale?

- **Correct ensemble:** Produces canonical (NVT) or isothermal-isobaric (NPT) ensemble
- **No drift:** Unlike Berendsen (no temperature drift)
- **Stable:** Unlike Nosé-Hoover (less prone to oscillations)
- **Standard:** Widely used for biomolecular simulations

## Pressure Control

### Parrinello-Rahman Barostat

- **Type:** Extended Lagrangian barostat
- **Coupling time:** τ_p = 2.0 ps
- **Reference pressure:** 1.0 bar
- **Compressibility:** 4.5 × 10⁻⁵ bar⁻¹ (water)
- **Isotropic:** Uniform scaling in all directions
- **Citation:** Parrinello M, Rahman A. "Polymorphic transitions in
  single crystals..." *J Appl Phys* 1981; 52:7182. DOI: 10.1063/1.328693

### Why Parrinello-Rahman?

- **Correct ensemble:** Produces isothermal-isobaric (NPT) ensemble
- **No artifacts:** Unlike Berendsen (does not produce correct ensemble)
- **Stable:** With τ_p = 2.0 ps
- **Standard:** Recommended for production runs

### Why τ_p = 2.0 ps?

- **Standard value:** Recommended in GROMACS manual
- **Coupling time:** τ_p = 2.0 ps for Parrinello-Rahman
- **Too fast:** τ_p = 0.5 ps causes pressure oscillations
- **Too slow:** τ_p = 5.0 ps does not couple pressure effectively

## Electrostatics

### PME Parameters

- **Method:** Particle Mesh Ewald
- **Cutoff:** 1.0 nm (real-space)
- **Grid:** 4th order B-splines
- **Fourier spacing:** 0.12 nm
- **Tolerance:** 10⁻⁶

### Why PME?

- **Long-range:** Coulomb interaction decays as 1/r
- **Direct cutoff:** Causes artifacts at boundaries
- **PME:** Treats long-range part on mesh (O(N log N))
- **Accuracy:** 10⁻⁶ relative error

## Neighbor List

### Verlet Scheme

- **Algorithm:** Verlet (dynamic neighbor list)
- **Update frequency:** Every 100 steps (nstlist)
- **Buffer:** 0.2 nm (rlist = cutoff + buffer)
- **Cutoff:** 1.0 nm for vanderWaals and Coulomb

### Why nstlist = 100?

- **Optimal:** Balances accuracy and performance
- **Too frequent:** nstlist = 10 (slow, unnecessary updates)
- **Too infrequent:** nstlist = 200 (may miss interactions)
- **Standard:** nstlist = 100 for 1.0 nm cutoff

## Output Control

### Trajectory

- **Format:** Compressed (XTC)
- **Precision:** 0.001 nm
- **Frame interval:** 50 ps (25,000 steps × 0.002 ps)
- **Frames per replicate:** 10,000
- **Total frames:** 30,000

### Energy

- **Format:** EDR (GROMACS energy file)
- **Interval:** 5 ps (2500 steps)
- **Contents:** Temperature, pressure, density, energies

### Log

- **Format:** LOG (text)
- **Interval:** 5 ps (2500 steps)
- **Contents:** Performance, energies, constraints

## Execution

### Commands

```bash
# Production (indefinite, extend from checkpoint)
gmx grompp -f mdp/md.mdp -c npt.gro -p topol.top -o md.tpr
gmx mdrun -deffnm md

# Extension (after 50 ns chunk)
gmx mdrun -deffnm md -cpi md.cpt -append
```

### Indefinite Mode

- **nsteps = -1:** Run until manually stopped or walltime reached
- **Extend from checkpoint:** Use `-cpi md.cpt` to continue
- **Append:** Use `-append` to add to existing trajectory

### Walltime Management

- **Job walltime:** 24 hours (HPC limit)
- **Chunks:** ~50 ns per 24-hour job
- **Total chunks:** ~10 chunks (500 ns / 50 ns)
- **Automatic:** `setup/replicate.sh` handles chunking

### Chunk Structure

```
chunk_01/
├── md_01.tpr
├── md_01.cpt
├── md_01.xtc
└── md_01.edr

chunk_02/
├── md_02.tpr
├── md_02.cpt
├── md_02.xtc
└── md_02.edr

...

chunk_10/
├── md_10.tpr
├── md_10.cpt
├── md_10.xtc
└── md_10.edr
```

## Monitoring

### Performance

Check `md.log` for performance:

```
Performance:
  ns/day:  22.65
  hours/ns: 1.06
```

### LINCS Warnings

Check `md.log` for:

```
LINCS warning: particles with highest constraint violation
```

**Expected:** 0 warnings (validated during pre-production)

### Trajectory Growth

Check `md.xtc` file size:

- **50 ns:** ~2.7 GB
- **100 ns:** ~5.4 GB
- **500 ns:** ~27 GB

### Checkpoint

Check `md.cpt` for:

- **Step:** Current step number
- **Time:** Current time (ps)
- **State:** Checkpoint state (should be "OK")

## Common Issues

### LINCS Warnings

- **Symptom:** "LINCS warning" in log
- **Check:** Constraints violated during dynamics
- **Fix:** Check initial structure, reduce timestep, or use softer constraints

### Performance Drop

- **Symptom:** ns/day drops significantly
- **Check:** System size, GPU usage, temperature
- **Fix:** Restart from checkpoint, check GPU utilization

### Trajectory Corruption

- **Symptom:** Cannot read trajectory
- **Check:** Checkpoint file integrity
- **Fix:** Restart from last valid checkpoint

### Walltime Exceeded

- **Symptom:** Job killed by PBS
- **Check:** Chunk too long for walltime
- **Fix:** Reduce chunk size (e.g., 40 ns instead of 50 ns)

## Validation

- [x] Temperature stable at 300 K (±5 K)
- [x] Pressure stable at 1.0 bar (±10 bar)
- [x] Density stable at ~1000 kg/m³
- [x] No LINCS warnings
- [x] Performance ~20-25 ns/day
- [x] Trajectory growing
- [x] Checkpoint valid
- [x] All on GPU

## Evidence

- **Production log:** `logs/production.log`
- **Production energy:** `output/production/md.edr`
- **Production trajectory:** `output/production/md.xtc`
- **Production checkpoint:** `output/production/md.cpt`

---

*See also: [VALIDATION.md](VALIDATION.md) for validation checkpoints*
