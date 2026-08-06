# Force Field & Parameters

**amber99sb-ildn + OL15 DNA + SPC/E Water**

---

## Force Field Selection

### Primary Force Field: amber99sb-ildn

- **Full name:** Assisted Model Building with Energy Refinement 99sb with
  improved side-chain torsion potentials (ILDN)
- **Type:** All-atom, fixed-charge, additive force field
- **Citation:** Lindorff-Larsen K, Piana S, Palmo K, et al. "Improved
  side-chain torsion potentials for the amber ff99SB protein force field."
  *Proteins* 2010; 78:1950-1958. DOI: 10.1002/prot.22711
- **Use case:** Protein and nucleic acid simulations
- **Validation status:** Extensively validated for protein dynamics

### DNA Parameters: OL15

- **Full name:** Optimization of DNA force field (OL15)
- **Citation:** Zgarbová M, Otyepka M, Šponer J, et al. "Refinement of the
  sugar–phosphate backbone torsion beta for the AMBER force fields..."
  *J Chem Theory Comput* 2011; 7:2886-2902. DOI: 10.1021/ct200162x
- **Use case:** DNA nucleotides
- **Validation status:** Standard for DNA simulations with amber99sb-ildn

### Water Model: SPC/E

- **Full name:** Extended Simple Point Charge water model
- **Citation:** Berendsen HJC, Grigera JR, Straatsma TP. "The missing term
  in effective pair potentials." *J Phys Chem* 1987; 91(24):6269-6271.
  DOI: 10.1021/j100298a009
- **Type:** Rigid, 3-site water model
- **Parameters:** O-H = 0.1 nm, H-O-H = 109.47°, ε(O) = 0.6502 kJ/mol,
  σ(O) = 0.3166 nm, q(O) = −0.8476 e, q(H) = +0.4238 e
- **Use case:** Standard water model for biomolecular simulations

## Force Field Parameters

### Bonded Interactions

| Interaction | Functional Form | Parameters |
|-------------|-----------------|------------|
| Bonds | Harmonic | k_b, r_0 |
| Angles | Harmonic | k_θ, θ_0 |
| Dihedrals | Fourier series | V_n, γ, n |
| Impropers | Harmonic | k_ξ, ξ_0 |

### Nonbonded Interactions

| Interaction | Functional Form | Parameters |
|-------------|-----------------|------------|
| Van der Waals | Lennard-Jones 12-6 | ε, σ |
| Electrostatics | Coulomb | q_i, q_j, r_ij |

### Cutoff

- **vanderWaals:** 1.0 nm (Verlet cutoff scheme)
- **Coulomb:** 1.0 nm (PME for long-range)

## Topology Structure

### Protein Topology (topol_Protein_chain_A.itp)

- **Atoms:** 10,077
- **Residues:** 652 (residues 639–1290 of BLM)
- **Net charge:** +5.0
- **Protonation states:** Standard at pH 7.0
- **Includes:**
  - Backbone atoms (N, CA, C, O)
  - Side chain atoms
  - Hydrogen atoms
  - Terminal groups

### DNA Topology (topol_DNA_chain_B.itp)

- **Atoms:** 620
- **Nucleotides:** 17
- **Net charge:** −18.0
- **Includes:**
  - Phosphate backbone (P, O1P, O2P, O3', O5')
  - Sugar ring (C1', C2', C3', C4', O4')
  - Base atoms (A, T, G, C)
  - Hydrogen atoms
  - G-quartet hydrogen bonds

### Ion Topology (topol_Ion.itp)

- **Molecule:** Ion
- **Atoms:** 3 (Zn + 2K)
- **Net charge:** +4.0
- **Note:** Cosmetic grouping artifact from consecutive HETATM records

### Water Topology

- **Molecule:** SOL (SPC/E water)
- **Atoms:** 228,625 × 3 = 685,875
- **Net charge:** 0.0

## Force Field Directory Structure

```
amber99sb-ildn.ff/
├── aminoacids.r2b    # Residue to building block mapping
├── aminoacids.rtp    # Residue topology
├── aminoacids.ts1    # Torsion parameters (set 1)
├── aminoacids.ts2    # Torsion parameters (set 2)
├── aminoacids.ts3    # Torsion parameters (set 3)
├── atomtypes.atp     # Atom type definitions
├── dna.rtp           # DNA residue topology
├── ffbonded.itp      # Bonded parameters
├── ffnonbonded.itp   # Nonbonded parameters
├── forcefield.itp    # Main force field file
├── gbsa.itp          # Implicit solvent parameters
├── hsd.rtp           # Histidine (delta protonated)
├── hse.rtp           # Histidine (epsilon protonated)
├── rna.rtp           # RNA residue topology
└── waterModels/
    ├── spce.gro      # SPC/E water geometry
    └── tip3p.gro     # TIP3P water geometry
```

## Validation

### amber99sb-ildn Validation Status

- [x] Protein dynamics validated
- [x] Side-chain torsion potentials improved over ff99sb
- [x] DNA parameters compatible with OL15
- [x] Water model (SPC/E) well-characterized
- [x] Ion parameters validated for monovalent ions
- [x] Force field compatible with GROMACS 2023.2
- [x] Extensive literature support

### Known Limitations

- Fixed-charge force field: no polarization effects
- SPC/E water: rigid model, no intramolecular flexibility
- Ion parameters: validated for monovalent ions (K⁺, Cl⁻), divalent ions
  (Zn²⁺) less well-characterized

## Citation

If using this force field, cite:

1. Lindorff-Larsen K, Piana S, Palmo K, et al. "Improved side-chain
   torsion potentials for the amber ff99SB protein force field." *Proteins*
   2010; 78:1950-1958. DOI: 10.1002/prot.22711

2. Zgarbová M, Otyepka M, Šponer J, et al. "Refinement of the sugar–
   phosphate backbone torsion beta for the AMBER force fields..." *J Chem
   Theory Comput* 2011; 7:2886-2902. DOI: 10.1021/ct200162x

3. Berendsen HJC, Grigera JR, Straatsma TP. "The missing term in effective
   pair potentials." *J Phys Chem* 1987; 91(24):6269-6271.
   DOI: 10.1021/j100298a009

---

*See also: [SOLVATION_AND_IONS.md](SOLVATION_AND_IONS.md) for ion parameters*
