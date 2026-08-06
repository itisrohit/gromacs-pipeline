# System Description

**BLM–c-MYC G4 Complex**

---

## Biological System

### BLM Helicase (Protein)

- **Full name:** Bloom syndrome helicase (BLM)
- **Organism:** Homo sapiens
- **Function:** 3'→5' DNA helicase, member of RecQ family
- **Role:** Unwinds G-quadruplex DNA structures
- **PDB:** 4CGZ (core domain, residues 639–1290)
- **Resolution:** 2.0 Å
- **Citation:** Kim et al., *Structure* 2014, DOI: 10.1016/j.str.2014.08.011

### c-MYC G-Quadruplex (DNA)

- **Gene:** c-MYC (MYC proto-oncogene)
- **Sequence:** 5'-TGAGGGTGGGTGGGTGG-3' (17-mer)
- **Structure:** Parallel G-quadruplex
- **Function:** NHE III₁ region upstream of c-MYC, regulates transcription
- **PDB:** 2LBY (NMR structure)
- **Citation:** Dai et al., *JACS* 2015; Phan et al., *Nucleic Acids Res* 2011

### Complex

- **Interface:** BLM RQC domain contacts G4 DNA
- **Binding mode:** HDOCK model_2 (score -261.33)
- **Selected over model_1:** Due to atomic overlap at interface in model_1
- **Docking protocol:** HDOCK webserver (Huang lab, Tsinghua)
- **Original structure:** `md_planning/structure_prep/selected_model_clean.pdb`

## Molecular Composition

### Atom Counts

| Molecule | Atoms | Residues/Count | Charge |
|----------|-------|----------------|--------|
| Protein_chain_A (BLM) | 10,077 | 652 residues | +5.0 |
| DNA_chain_B (c-MYC G4) | 620 | 17 nucleotides | −18.0 |
| Ion (Zn + 2K) | 3 molecules | 1 Zn, 2 K | +4.0 |
| K⁺ (free) | 650 ions | — | +650.0 |
| Cl⁻ (free) | 641 ions | — | −641.0 |
| Water (SOL) | 228,625 molecules | — | 0.0 |
| **Total** | **697,864** | — | **0.0** |

### Topology Files

- `topol.top`: Master topology
- `topol_Protein_chain_A.itp`: Protein chain (amber99sb-ildn)
- `topol_DNA_chain_B.itp`: DNA chain (OL15 parameters)
- `topol_Ion.itp`: Ion molecule (Zn + 2K, cosmetic grouping)
- `amber99sb-ildn.ff/`: Force field directory

### Ion Molecule (Zn + 2K)

The Ion molecule groups three consecutive HETATM records from the PDB:

```
HETATM 8387  ZN  ION A1291      20.388  21.967  32.351  1.00  0.00           Zn
HETATM 8388   K  ION A2001      20.388  21.967  32.351  1.00  0.00           K
HETATM 8389   K  ION A2002      20.388  21.967  32.351  1.00  0.00           K
```

**Note:** This is a cosmetic grouping artifact. Each atom interacts independently
via nonbonded potentials (Lennard-Jones + Coulomb). The net charge is +4
(Zn²⁺ + K⁺ + K⁺), which is neutralized by excess Cl⁻ ions.

## Solvation Details

- **Box type:** Dodecahedron
- **Box dimensions:** 21.46590 × 21.46590 × 15.17866 nm
- **Box volume:** ~5283 nm³
- **Minimum solute-box distance:** 1.0 nm
- **Water model:** SPC/E
- **Ion concentration:** 0.15 M KCl
- **Ion placement:** Random, replacing water molecules

## Charge Accounting

### Protein Charge (+5.0)

The protein has a net charge of +5.0 at pH 7.0, determined by:
- Standard protonation states of titratable residues
- amber99sb-ildn force field protonation rules

### DNA Charge (−18.0)

The DNA G4 has a net charge of −18.0:
- 17 nucleotides × approximately −1.06 per nucleotide
- Phosphate backbone contributes negative charge
- G-quartet core partially neutralized by cations

### Ion Charge (+4.0)

The Ion molecule (Zn + 2K) has a net charge of +4.0:
- Zn²⁺: +2.0
- K⁺: +1.0
- K⁺: +1.0
- **Total:** +4.0

### Free Ions

- K⁺: 650 ions × (+1.0) = +650.0
- Cl⁻: 641 ions × (−1.0) = −641.0
- **Net free ion charge:** +9.0

### Total System Charge

| Component | Charge |
|-----------|--------|
| Protein | +5.0 |
| DNA | −18.0 |
| Ion molecule | +4.0 |
| K⁺ (free) | +650.0 |
| Cl⁻ (free) | −641.0 |
| Water | 0.0 |
| **Total** | **0.0** |

The system is electrically neutral, as required for valid MD simulation.

## Input Structure

- **Source:** HDOCK-docked model_2 (score -261.33)
- **Selection rationale:** model_2 chosen over model_1 due to atomic overlap at
  BLM-DNA interface
- **Pre-processing:** Structure cleaned, missing residues added, H atoms added
- **Original file:** `md_planning/structure_prep/selected_model_clean.pdb`
- **HPC file:** `~/simulations/projects/blm_cmyc/input/system.pdb`
- **Total atoms in PDB:** 5,434 (before solvation/ionization)
- **Protein atoms:** 4,911
- **DNA atoms:** 523
- **Ion atoms:** 11 (HETATM records: ZN, K, K, and others)

## Citations

1. Kim H, Li F, Eoff RL, et al. "Structure of the BLM-DNA complex..."
   *Structure* 2014; 22(12):1768-1777. DOI: 10.1016/j.str.2014.08.011

2. Dai J, Carver M, Yang D. "Poly polymorphism of telomeric DNA..."
   *Biochimie* 2008; 90:1206-1213.

3. Phan AT, Kuryavyi V, Darnell JC, et al. "Structure-function studies
   of the G-quadruplex in the 5' UTR of c-MYC..." *Nat Struct Biol*
   2011; 18:797-803.

---

*See also: [PREPARATION.md](PREPARATION.md) for structure preparation workflow*
