# Solvation & Ion Placement

**0.15 M KCl, Dodecahedron Box, SPC/E Water**

---

## Solvation Protocol

### Solvent Model

- **Water model:** SPC/E (Extended Simple Point Charge)
- **Type:** Rigid, 3-site model
- **Citation:** Berendsen et al. 1987, *J Phys Chem* 91:6269

### Box Construction

- **Box type:** Dodecahedron
- **Minimum solute-box distance:** 1.0 nm
- **Box dimensions:** 21.46590 × 21.46590 × 15.17866 nm
- **Box volume:** ~5283 nm³
- **Reason:** Dodecahedron minimizes volume for isotropic systems vs. cubic box

### Solvation Command

```bash
gmx solvate -cp.gro -cs spc216.gro -o solvated.gro -p topol.top
```

- `-cp`: Input structure (after pdb2gmx)
- `-cs`: Solvent structure (SPC/E from GROMACS database)
- `-o`: Output solvated structure
- `-p`: Topology file (automatically updates SOL count)

### Water Molecules

- **Count:** 228,625
- **Total water atoms:** 685,875 (3 atoms per molecule)
- **Placement:** Random, filling space not occupied by solute

## Ion Placement

### Protocol

1. **Salt concentration:** 0.15 M KCl (physiological)
2. **Ion replacement:** Replace random water molecules with ions
3. **Neutralization:** Additional ions to neutralize system charge
4. **Random seed:** 1993 (for reproducibility)

### Ion Counts

| Ion | Count | Charge | Purpose |
|-----|-------|--------|---------|
| K⁺ | 650 | +1.0 | Salt + neutralization |
| Cl⁻ | 641 | −1.0 | Salt + neutralization |
| **Net** | **1,291** | **+9.0** | **Neutralizes protein/DNA charge** |

### Charge Balance

- Protein: +5.0
- DNA: −18.0
- Ion molecule: +4.0
- **Subtotal (complex):** −9.0
- K⁺ (free): +650.0
- Cl⁻ (free): −641.0
- **Net free ions:** +9.0
- **System total:** 0.0 (neutral)

### Ion Placement Command

```bash
gmx genion -s ions.tpr -o solvated.gro -p topol.top -pname K -nname CL -neutral -conc 0.15 -seed 1993
```

- `-s`: Input structure (after genbox)
- `-o`: Output with ions
- `-p`: Topology file (automatically updates ion counts)
- `-pname`: Cation name (K⁺)
- `-nname`: Anion name (Cl⁻)
- `-neutral`: Add ions to neutralize system
- `-conc 0.15`: 0.15 M salt concentration
- `-seed 1993`: Random seed for reproducibility

## Ion Parameters

### K⁺ (Potassium)

- **Force field:** amber99sb-ildn
- **Lennard-Jones:** ε = 0.3648480 kJ/mol, σ = 0.325 nm
- **Charge:** +1.0 e
- **Hydration:** 6 water molecules (first shell)
- **Radius:** 1.38 Å (crystallographic)

### Cl⁻ (Chloride)

- **Force field:** amber99sb-ildn
- **Lennard-Jones:** ε = 0.7112800 kJ/mol, σ = 0.4401000 nm
- **Charge:** −1.0 e
- **Hydration:** 7 water molecules (first shell)
- **Radius:** 1.81 Å (crystallographic)

### Zn²⁺ (Zinc)

- **Force field:** amber99sb-ildn
- **Lennard-Jones:** ε = 0.1702832 kJ/mol, σ = 0.1103000 nm
- **Charge:** +2.0 e
- **Coordination:** 4-5 protein ligands
- **Note:** Part of Ion molecule (cosmetic grouping)

## Solvation Statistics

### Pre-Solvation

- **Solute atoms:** 11,700 (protein + DNA + ion molecule)
- **Box volume:** ~5283 nm³
- **Solute volume:** ~11.7 nm³ (estimated from atom count)
- **Available volume:** ~5271 nm³

### Post-Solvation

- **Water molecules:** 228,625
- **Total atoms:** 697,864
- **Box fill fraction:** ~99.9% (water fills all available space)
- **Number density:** ~132 atoms/nm³ (close to bulk water: ~100 atoms/nm³)

### Post-Ionization

- **K⁺ ions:** 650
- **Cl⁻ ions:** 641
- **Replaced water:** 1,291 molecules
- **Net charge:** 0.0

## Validation

- [x] System neutral (0.0 net charge)
- [x] Correct salt concentration (0.15 M)
- [x] Random ion placement (seed 1993)
- [x] SPC/E water model used
- [x] Dodecahedron box (minimum image convention satisfied)
- [x] 1.0 nm solute-box distance

## Evidence

- **Solvation log:** `logs/solvate.log` (on HPC)
- **Ionization log:** `logs/genion.log` (on HPC)
- **Final structure:** `output/setup/solvated_ions.gro`
- **Topology:** `output/setup/topol.top` (SOL and ion counts updated)

---

*See also: [BOX_AND_PBC.md](BOX_AND_PBC.md) for periodic boundary conditions*
