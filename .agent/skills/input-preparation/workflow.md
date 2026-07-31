# Workflow: Input Preparation & Verification

This document describes how the agent thinks through a preparation task. It is not a rigid sequence of phases — it is the reasoning pattern the agent follows.

## Overview

```
User request
    ↓
Understand request
    ↓
Inspect repository/project
    ↓
Inspect inputs
    ↓
Identify missing information
    ↓
Validate readiness
    ↓
Recommend improvements
    ↓
Clarify ambiguous decisions
    ↓
Execute deterministic scripts after approval
    ↓
Verify outputs
    ↓
Hand off to execution stage
```

## Step 1: Understand Request

Determine what the user wants:

- **New project**: User has a PDB and wants to run MD. Goal: create project, validate inputs, prepare for submission.
- **Review existing**: User has a project and wants to check or change something. Goal: inspect current state, identify issues.
- **Diagnose failure**: User reports an error from pdb2gmx, grompp, or genion. Goal: find root cause, recommend fix.

Ask for clarification when intent is ambiguous.

## Step 2: Inspect Repository and Project

Read the actual state of the project:

- Does `config.sh` exist? What values are set?
- Does `input/system.pdb` exist? Is it non-empty?
- Do `mdp/*.mdp` files exist?
- Does `.state/workflow.json` exist? What are the phase statuses?
- Does `forcefields/<name>.ff/` exist?
- Does `profiles/<cluster>.sh` exist?

Reference: `playbook.md` for repository structure and file locations.

## Step 3: Inspect Inputs

Read the PDB and config to understand the system:

**PDB inspection:**
- Has ATOM/HETATM records (not corrupt)
- Residue names are standard (protein, DNA, RNA, ligand)
- AltLoc column (column 22) is clean (no A/B alternate conformations)
- System composition: protein-only, protein-DNA, protein-RNA, protein-ligand

**Config inspection:**
- FORCEFIELD is set and appropriate for system composition
- WATER_MODEL is set
- CATION/ANION are set
- PRODUCTION_NS and CHUNK_NS are reasonable
- Resource values are adequate for system size

Reference: `playbook.md` for PDB inspection rules and config relationships.

## Step 4: Identify Missing Information

Determine what would prevent execution:

- PDB missing → "Place your structure at input/system.pdb"
- config.sh missing → "Run `setup/init.sh <project>` to create the project"
- FORCEFIELD empty → "What force field does your system need?"
- ACCOUNT empty → "What is your PBS project account?"
- CLUSTER empty → "Which HPC cluster are you targeting?"

## Step 5: Validate Readiness

Run the deterministic validation script:

```bash
bash setup/validate.sh <project>
```

This checks:
- config.sh loads
- Required variables are set (PROJECT, PDB, FORCEFIELD, WATER_MODEL, BOX_TYPE, PRODUCTION_NS, CLUSTER, EM_MDP, NVT_MDP, NPT_MDP, MD_MDP)
- Force field is installed and found
- Cluster profile exists
- Input files exist and are non-empty
- Numeric parameters are valid (PRODUCTION_NS >= CHUNK_NS, BOX_DISTANCE numeric, SALT_CONC numeric)
- Walltime format is HH:MM:SS
- Resource values are > 0

Then apply domain-level reasoning beyond what `validate.sh` checks (see `playbook.md`).

## Step 6: Recommend Improvements

Suggest improvements backed by evidence:

- **nstlist=100**: Measured +10.7% speedup on A100 (benchmark job 968167)
- **vbt=0.005**: Measured +6.4% speedup, same physics (benchmark job 968167)
- **Resource adequacy**: Estimate memory needs from atom count
- **CHUNK_NS vs walltime**: Verify chunk fits in walltime budget
- **Production length**: Guidance based on system type (protein-DNA: 100-500 ns)

Reference: `playbook.md` for benchmark results and decision rules.

## Step 7: Clarify Ambiguous Decisions

Resolve situations where the skill cannot determine the right answer:

- FF doesn't support PDB residues → "Your PDB has [residue]. [FF] doesn't support it. Did you mean [alternative]?"
- PRODUCTION_NS too short for system type → "For [system type], typical range is [X]-[Y] ns. You set [Z] ns."
- ACCOUNT is empty → "What is your PBS project account?"

Never guess. If the skill cannot determine correctness, ask the user.

## Step 8: Execute Deterministic Scripts After Approval

Present what the scripts will do, ask for approval, then execute:

**For a new project:**
```bash
bash setup/init.sh <project>     # creates project structure
bash forcefields/get-ff.sh install <name>  # if FF not installed
bash setup/validate.sh <project>  # verify readiness
```

**For an existing project:**
```bash
bash setup/validate.sh <project>  # verify after changes
```

Verify exit code and expected outputs after each execution.

## Step 9: Verify Outputs

After script execution, confirm expected artifacts exist:

| Script | Expected outputs |
|--------|-----------------|
| `init.sh` | `config.sh`, `mdp/*.mdp`, `.state/workflow.json`, `.state/fingerprint` |
| `get-ff.sh install` | `forcefields/<name>.ff/` with `forcefield.itp` |
| `validate.sh` | Exit code 0, 0 errors |

## Step 10: Hand Off to Execution Stage

The execution stage (`run.sh submit`) expects:

| Artifact | Location | Verification |
|----------|----------|-------------|
| PDB file | `input/system.pdb` | Exists, non-empty, GROMACS-ready |
| Configuration | `config.sh` | All required variables set |
| MDP files | `mdp/*.mdp` | All four exist, non-empty |
| Force field | `forcefields/<name>.ff/` | Directory exists, `forcefield.itp` present |
| Cluster profile | `profiles/<name>.sh` | File exists |
| State | `.state/workflow.json` | Initialized, all phases pending |
| Fingerprint | `.state/fingerprint` | Computed, matches current inputs |
| Validation | `validate.sh` | Exit code 0, 0 errors |

When all artifacts are present and validated, inform the user they can submit:

```bash
bash gromacs-pipeline/run.sh submit <project>
```
