# Project Input Format Specification

## Design Principles

1. **One project = one simulation.** A project directory contains everything needed to run exactly one GROMACS simulation. After the simulation completes, the same directory contains all outputs.

2. **Portable by default.** All paths are relative. No absolute paths, no machine-specific configuration in input files. Moving a project to another HPC cluster requires editing only `config.sh` (cluster profile name) and ensuring the new cluster has the required modules.

3. **Single-structure input.** The pipeline accepts one starting structure (`input/complex.pdb`) containing all molecules with distinct chain identifiers. Multi-file inputs (separate protein/ligand/DNA) are not required because:
   - Docking tools produce single PDB files.
   - `pdb2gmx` handles multi-chain files natively.
   - A single file is simpler to manage, copy, and archive.
   - Chain IDs in the PDB define molecule boundaries.

4. **Custom topologies supported but not required.** For standard residues (protein, DNA, RNA, standard ions), `pdb2gmx` generates everything automatically. Custom topologies (ligand.itp, extra .itp files) live in `input/` and are included via `config.sh`.

5. **MDP files are part of the project.** Simulation parameters are not hidden in the pipeline. The user owns the MDP files and can version-control them alongside the project.

---

## Required Files

```
project/
├── config.sh              USER   Simulation parameters and cluster selection
├── input/
│   └── complex.pdb        USER   Starting structure (all chains)
├── mdp/
│   ├── em.mdp             USER   Energy minimization parameters
│   ├── nvt.mdp            USER   NVT equilibration parameters
│   ├── npt.mdp            USER   NPT equilibration parameters
│   └── md.mdp             USER   Production MD parameters
└── profiles/
    └── my_cluster.sh      USER   Cluster profile (from template)
```

`config.sh` is the only file a user MUST edit. MDP files, the PDB, and the cluster profile are copied from templates or provided by the user.

---

## Optional Files and Directories

```
project/
├── input/
│   ├── ligand.itp              Custom ligand topology (see §4.2)
│   ├── ligand.gro              Ligand coordinates (if separate from complex.pdb)
│   ├── topol_extra.itp         Additional topology includes (cofactors, modified residues)
│   ├── posre_extra.itp         Additional position restraints
│   └── index_extra.ndx         Pre-generated index file (overrides pipeline-generated)
└── output/                     Created by the pipeline at runtime
    ├── setup/                  Intermediate structures (processed.gro, ionized system)
    ├── equilibration/          EM, NVT, NPT outputs
    ├── production/             Final trajectory and energies
    └── logs/                   Scheduler output files
```

---

## File Specifications

### `config.sh` — User Configuration

Single source of truth for all user-visible settings. No variables are hardcoded elsewhere.

| Variable | Required | Purpose |
|----------|----------|---------|
| `PROJECT` | yes | Used for job naming and directory labeling |
| `CLUSTER` | yes | Selects `profiles/$CLUSTER.sh` |
| `FORCEFIELD` | yes | Argument to `pdb2gmx -ff` |
| `WATER_MODEL` | yes | Argument to `pdb2gmx -water` |
| `BOX_TYPE` | yes | Argument to `editconf -bt` |
| `BOX_DISTANCE` | yes | Solute-to-box-wall clearance (nm) |
| `SALT_CONC` | yes | Salt concentration (M), set to 0 for neutralization only |
| `CATION` | yes | Cation species for genion |
| `ANION` | yes | Anion species for genion |
| `PRODUCTION_NS` | yes | Total simulation length (ns) |
| `CHUNK_NS` | yes | Walltime chunk length (ns), must be ≤ PRODUCTION_NS |
| `TC_GROUPS` | no | Removed. Groups are built by `gmx select` (`not (group Water or group Ion)` / `group Water or group Ion`) |
| `SETUP_CPUS` | no | Default: 8 |
| `SETUP_MEM` | no | Default: 8GB |
| `SETUP_WALLTIME` | no | Default: 00:30:00 |
| `EQ_CPUS` | no | Default: 8 |
| `EQ_GPUS` | no | Default: 1 |
| `EQ_MEM` | no | Default: 16GB |
| `EQ_WALLTIME` | no | Default: 02:00:00 |
| `PROD_CPUS` | no | Default: 8 |
| `PROD_GPUS` | no | Default: 1 |
| `PROD_MEM` | no | Default: 16GB |
| `PROD_WALLTIME` | no | Default: 24:00:00 |
| `ACCOUNT` | no | Scheduler account/project |
| `QUEUE` | no | Scheduler queue/partition |

### `input/complex.pdb` — Starting Structure

A single PDB file containing all molecules. Chain identifiers define molecule boundaries.

- Protein residues: standard 20 amino acids (any chain ID)
- DNA residues: DA, DC, DG, DT (any chain ID)
- RNA residues: RA, RC, RG, RU (any chain ID)
- Ligands/cofactors: any residue name not in the lists above (custom topology required)
- Ions: HETATM records with residue names K, K+, NA, CL, ZN, etc.
- Water: stripped automatically by the prepare stage

The pipeline does not require specific chain IDs. `pdb2gmx` with `-ignh -missing` handles most formatting issues automatically.

### `mdp/*.mdp` — MDP Parameter Files

Each file corresponds to one GROMACS simulation phase. The pipeline passes them directly to `grompp` without modification.

- `em.mdp`: steepest descent minimization, position restraints enabled via `-DPOSRES`
- `nvt.mdp`: v-rescale thermostat, position restraints enabled
- `npt.mdp`: v-rescale thermostat + Parrinello-Rahman barostat, position restraints enabled
- `md.mdp`: production run, unrestrained

The pipeline does not validate MDP parameter values. Invalid parameters will be caught by `grompp` when the job runs on the compute node.

### `profiles/$CLUSTER.sh` — Cluster Profile

Defines scheduler commands, module names, and resource syntax. See `PROJECT_FORMAT.md` for the full profile specification.

---

## Custom Topologies

When the system contains residues not recognized by `pdb2gmx` (small-molecule ligands, modified residues, non-standard cofactors), the user must provide:

1. **`input/ligand.itp`** — Topology file for the custom residue(s), generated by tools such as `acpype`, `CGenFF`, `GAFF`, or `PRODRG`.

2. **`input/ligand.gro`** — Coordinate file for the ligand (if it is not included in `complex.pdb`). If the ligand IS in `complex.pdb`, this file is not needed.

3. **`config.sh` additions:**

```bash
# Custom topology files to include in topol.top (space-separated)
EXTRA_ITPS="input/ligand.itp"

# Residue name mapping for custom residues in the PDB
# Format: "PDB_RESNAME=FORCEFIELD_RESNAME"
# Example: LIG=ligand → PDB residue LIG maps to FF residue "ligand"
EXTRA_RESIDUES="LIG=ligand"
```

The pipeline appends `#include "input/ligand.itp"` to the generated `topol.top` before the `[ system ]` directive. The residue mapping tells `pdb2gmx` what to do with unrecognized PDB residue names.

---

## Examples

### Example 1: Protein Only (Minimal)

```
simulations/abl_kinase/
├── config.sh
├── input/
│   └── complex.pdb            # Single chain: ABL kinase domain
├── mdp/
│   ├── em.mdp                 # Default templates
│   ├── nvt.mdp
│   ├── npt.mdp
│   └── md.mdp
└── profiles/
    └── my_cluster.sh          # Copied from templates
```

`config.sh`:
```bash
PROJECT="abl_kinase"
CLUSTER="my_cluster"
FORCEFIELD="amber14sb"
WATER_MODEL="spce"
BOX_TYPE="dodecahedron"
BOX_DISTANCE="1.0"
SALT_CONC="0.15"
CATION="K"
ANION="CL"
PRODUCTION_NS=500
CHUNK_NS=50
ACCOUNT="my_account"
QUEUE="gpu"
TC_GROUPS="group Protein\ngroup Water or group Ion"
```

### Example 2: Protein–Ligand

```
simulations/bcl2_inhibitor/
├── config.sh
├── input/
│   ├── complex.pdb            # BCL-2 protein with inhibitor
│   ├── ligand.itp              # Inhibitor topology (generated by acpype)
│   └── ligand.gro             # Inhibitor coordinates (if separate)
├── mdp/                       # Default MDP templates
├── profiles/
│   └── my_cluster.sh
```

`config.sh` additions:
```bash
EXTRA_ITPS="input/ligand.itp"
EXTRA_RESIDUES="INH=inhibitor"
```

### Example 3: Protein–DNA (Helicase + G4)

```
simulations/blm_kras_k/
├── config.sh
├── input/
│   └── complex.pdb            # BLM helicase (chain A) + KRAS G4 (chain B) + K+ (chain I)
├── mdp/                       # Default MDP templates
├── profiles/
│   └── iitd.sh
```

`config.sh`:
```bash
PROJECT="blm_kras_k"
CLUSTER="iitd"
FORCEFIELD="amber14sb"
WATER_MODEL="spce"
BOX_TYPE="dodecahedron"
BOX_DISTANCE="1.0"
SALT_CONC="0.15"
CATION="K"
ANION="CL"
PRODUCTION_NS=500
CHUNK_NS=50
ACCOUNT="helicases.spons"
QUEUE="high"
TC_GROUPS="group Protein or group DNA\ngroup Water or group Ion"
```

---

## Files by Category

| Category | Files | User edits? | Pipeline generates? | Never modify after init? |
|----------|-------|-------------|-------------------|--------------------------|
| Configuration | `config.sh` | ✅ | ❌ | — |
| Starting structure | `input/complex.pdb` | ✅ | ❌ | — |
| Custom topologies | `input/*.itp`, `input/*.gro` | ✅ | ❌ | — |
| MDP parameters | `mdp/*.mdp` | ✅ | ❌ | — |
| Cluster profile | `profiles/$CLUSTER.sh` | ✅ (once) | ❌ | ✅ (after first submission) |
| Pipeline code | `lib/*`, `setup/*`, `run.sh` | ❌ | ✅ | ✅ (shipped with pipeline) |
| Job scripts | `scripts/*.sh` | ❌ | ✅ (at submit time) | — |
| State | `.state/*` | ❌ | ✅ (at runtime) | — |
| Outputs | `output/*` | ❌ | ✅ (at runtime) | — |

Profiles should not be modified after the first submission because the fingerprint captures their content. Changing a profile mid-project invalidates the fingerprint.

---

## Edge Cases

### 1. Protein with multiple chains (antibody, multimer)

`complex.pdb` contains all chains. `pdb2gmx` processes them independently. The `TC_GROUPS` should be configured to treat all protein chains as a single temperature coupling group:

```bash
TC_GROUPS="group Protein\ngroup Water or group Ion"
```

The default `gmx select` syntax `group Protein` matches all atoms classified as protein by GROMACS, regardless of chain.

### 2. Protein–DNA–ligand (ternary complex)

All molecules in `complex.pdb`. The ligand requires a custom ITP:

```bash
EXTRA_ITPS="input/ligand.itp"
EXTRA_RESIDUES="LIG=ligand"
```

### 3. System with pre-equilibrated solvent

Not supported by this pipeline. The pipeline always solvates and ionizes from scratch. Users who require custom solvation should generate a solvated GRO and topology externally, then use the pipeline only for equilibration and production.

### 4. Membrane proteins

MDP files must be adjusted by the user for membrane simulations (semi-isotropic pressure coupling, specific NPT setup). The pipeline does not provide membrane-specific MDP templates. The user provides custom `mdp/npt.mdp` and `mdp/md.mdp` files.

### 5. Non-standard force fields (CHARMM36, OPLS, GROMOS)

The `FORCEFIELD` variable in `config.sh` is passed directly to `pdb2gmx`. Any force field installed with the GROMACS distribution is supported. Custom force fields must be placed in the working directory or in a path accessible to GROMACS.

### 6. Very large systems (millions of atoms)

Large systems require more memory and walltime. The user adjusts `SETUP_MEM`, `SETUP_CPUS`, etc. in `config.sh`. No structural changes to the input format are needed.

### 7. No DNA in the system

The pipeline does not require DNA. The `TC_GROUPS` configuration specifies which groups to create. For protein-only:

```bash
TC_GROUPS="group Protein\ngroup Water or group Ion"
```

No DNA-specific configuration is needed.

### 8. Reproducible archiving

To archive a complete simulation for reproducibility, the user saves:

```
project/
├── config.sh
├── input/             # All input structures and custom topologies
├── mdp/               # MDP parameter files
├── profiles/          # Cluster profile
└── .state/
    └── fingerprint    # Captures hashes of all inputs
```

This directory contains everything needed to reproduce the simulation, independent of the pipeline version (the pipeline is a separate dependency).
