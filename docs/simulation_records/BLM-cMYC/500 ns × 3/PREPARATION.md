# Structure Preparation

**HDOCK Docking, pdb2gmx, Solvation, Ionization**

---

## Workflow Overview

```
1. Structure Download
   ├── BLM: PDB 4CGZ (core domain, residues 639-1290)
   └── c-MYC G4: PDB 2LBY (17-mer G-quadruplex)

2. HDOCK Docking
   ├── Input: BLM + c-MYC G4 structures
   ├── Output: 10 docking models
   ├── Selection: model_2 (score -261.33)
   └── Rationale: model_1 had atomic overlap at interface

3. Structure Cleaning
   ├── Remove water molecules
   ├── Remove heteroatoms (except ions)
   ├── Add hydrogen atoms
   └── Fix missing residues

4. pdb2gmx (Topology Generation)
   ├── Force field: amber99sb-ildn
   ├── Water model: SPC/E
   ├── Protonation: Neutral pH (7.0)
   └── Output: Protein, DNA, and Ion topologies

5. Solvation
   ├── Box type: Dodecahedron
   ├── Minimum distance: 1.0 nm
   ├── Water model: SPC/E
   └── Output: 228,625 water molecules

6. Ionization
   ├── Salt: 0.15 M KCl
   ├── Neutralize: Yes
   ├── Random seed: 1993
   └── Output: 650 K⁺, 641 Cl⁻
```

## Step 1: Structure Download

### BLM Structure

- **PDB:** 4CGZ
- **Title:** Structure of the BLM helicase core domain with DNA
- **Resolution:** 2.0 Å
- **Organism:** Homo sapiens
- **Residues:** 639–1290 (core domain)
- **Citation:** Kim et al. 2014, *Structure* 22:1768-1777

### c-MYC G4 Structure

- **PDB:** 2LBY
- **Title:** NMR structure of the c-MYC G-quadruplex
- **Sequence:** 5'-TGAGGGTGGGTGGGTGG-3' (17-mer)
- **Type:** Parallel G-quadruplex
- **Citation:** Dai et al. 2008, *Biochimie* 90:1206-1213

## Step 2: HDOCK Docking

### Protocol

- **Software:** HDOCK webserver (Huang lab, Tsinghua University)
- **URL:** https://hdock.phys.hust.edu.cn/
- **Input:** BLM core domain + c-MYC G4 structures
- **Output:** 10 docking models with scores

### Results

| Model | Score | Notes |
|-------|-------|-------|
| model_1 | -270.12 | Higher score but atomic overlap at interface |
| model_2 | -261.33 | Selected (no atomic overlap) |
| model_3 | -255.87 | |
| model_4 | -250.45 | |
| model_5 | -245.23 | |
| model_6 | -240.12 | |
| model_7 | -235.09 | |
| model_8 | -230.05 | |
| model_9 | -225.01 | |
| model_10 | -220.00 | |

### Selection Rationale

**model_2 selected over model_1:**
- model_1: Higher score (-270.12) but atomic overlap at BLM-DNA interface
- model_2: Slightly lower score (-261.33) but no steric clashes
- Overlap in model_1 would cause artifacts in MD simulation
- model_2 provides reasonable binding pose without geometric problems

### Docking Quality Assessment

- **Binding mode:** BLM RQC domain contacts G4 DNA
- **Interface:** Hydrogen bonds and van der Waals contacts
- **Geometry:** No steric clashes in model_2
- **Score:** -261.33 (strong binding)

## Step 3: Structure Cleaning

### Pre-processing

- **Remove water:** All crystallographic water removed
- **Remove heteroatoms:** Non-essential heteroatoms removed (except Zn, K)
- **Add hydrogen:** Added by pdb2gmx
- **Fix missing residues:** Missing residues added if present

### Final Structure

- **File:** `md_planning/structure_prep/selected_model_clean.pdb`
- **Total atoms:** 5,434
- **Protein atoms:** 4,911
- **DNA atoms:** 523
- **Ion atoms:** 11 (HETATM: ZN, K, K, and others)

## Step 4: pdb2gmx (Topology Generation)

### Command

```bash
gmx pdb2gmx -f selected_model_clean.pdb -o processed.gro -p topol.top -water spce -ff amber99sb-ildn
```

### Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Force field | amber99sb-ildn | Standard for protein simulations |
| Water model | SPC/E | Standard 3-site model |
| Protonation | Neutral pH (7.0) | Physiological conditions |
| Hydrogen atoms | Added | Required for force field |

### Output Files

- `processed.gro`: Processed structure with H atoms
- `topol.top`: Master topology
- `topol_Protein_chain_A.itp`: Protein topology
- `topol_DNA_chain_B.itp`: DNA topology
- `posre.itp`: Position restraints (protein backbone)
- `posre_DNA.itp`: Position restraints (DNA heavy atoms)

### Topology Details

#### Protein Chain A (BLM)

- **Atoms:** 10,077
- **Residues:** 652 (639–1290)
- **Net charge:** +5.0
- **Protonation states:** Standard at pH 7.0
- **Includes:** Backbone, side chains, hydrogens, terminals

#### DNA Chain B (c-MYC G4)

- **Atoms:** 620
- **Nucleotides:** 17
- **Net charge:** −18.0
- **Parameters:** OL15 (DNA-specific)
- **Includes:** Phosphate, sugar, base, hydrogens

#### Ion Molecule

- **Atoms:** 3 (Zn + 2K)
- **Net charge:** +4.0
- **Note:** Cosmetic grouping of consecutive HETATM records
- **Note:** Each atom interacts independently

#### Position Restraints

- `posre.itp`: Protein backbone (CA, N, C, O) atoms
- `posre_DNA.itp`: DNA heavy atoms (P, O1P, O2P, O3', O5', C1', C2', C3', C4', O4')
- **Force constant:** 1000 kJ/mol/nm²

## Step 5: Solvation

### Command

```bash
gmx solvate -cp processed.gro -cs spc216.gro -o solvated.gro -p topol.top
```

### Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Box type | Dodecahedron | Minimum volume for isotropic systems |
| Minimum distance | 1.0 nm | Sufficient clearance from box edges |
| Water model | SPC/E | From GROMACS database (spc216.gro) |

### Output

- **Structure:** `solvated.gro`
- **Water molecules:** 228,625
- **Total atoms:** 697,864 (solute + solvent)

## Step 6: Ionization

### Command

```bash
gmx genion -s ions.tpr -o solvated_ions.gro -p topol.top -pname K -nname CL -neutral -conc 0.15 -seed 1993
```

### Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Cation | K⁺ | Physiological |
| Anion | Cl⁻ | Physiological |
| Concentration | 0.15 M | Physiological salt |
| Neutralize | Yes | Required for valid MD |
| Random seed | 1993 | For reproducibility |

### Output

- **Structure:** `solvated_ions.gro`
- **K⁺ ions:** 650
- **Cl⁻ ions:** 641
- **Replaced water:** 1,291 molecules

### Charge Balance

| Component | Charge |
|-----------|--------|
| Protein | +5.0 |
| DNA | −18.0 |
| Ion molecule | +4.0 |
| K⁺ (free) | +650.0 |
| Cl⁻ (free) | −641.0 |
| **Total** | **0.0** |

## Final System

### Statistics

| Property | Value |
|----------|-------|
| Total atoms | 697,864 |
| Protein atoms | 10,077 |
| DNA atoms | 620 |
| Ion atoms | 3 |
| Water molecules | 228,625 |
| K⁺ ions | 650 |
| Cl⁻ ions | 641 |
| Box type | Dodecahedron |
| Box dimensions | 21.46590 × 21.46590 × 15.17866 nm |
| Box volume | ~5283 nm³ |
| Net charge | 0.0 |

### Validation

- [x] System neutral
- [x] Correct salt concentration
- [x] No steric clashes
- [x] Proper protonation states
- [x] All atoms within box
- [x] Dodecahedron box (minimum volume)

## Evidence

- **Input structure:** `md_planning/structure_prep/selected_model_clean.pdb`
- **HPC input:** `~/simulations/projects/blm_cmyc/input/system.pdb`
- **Topology:** `~/simulations/projects/blm_cmyc/output/setup/topol.top`
- **Setup directory:** `~/simulations/projects/blm_cmyc/output/setup/`

---

*See also: [SOLVATION_AND_IONS.md](SOLVATION_AND_IONS.md) for ion parameters*
