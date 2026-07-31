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
Inspect inputs (PDB structure, ligands, config)
    ↓
Validate project state
    ↓
Identify missing information
    ↓
Run deterministic validation
    ↓
Apply domain-level reasoning
    ↓
Estimate resources
    ↓
Recommend improvements
    ↓
Clarify ambiguous decisions
    ↓
Execute deterministic scripts after approval
    ↓
Verify outputs
    ↓
Scientific readiness review
    ↓
Produce final preparation report
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

Read the PDB and config to understand the system.

**PDB structural validation:**
- ATOM/HETATM records present (not corrupt)
- Chain IDs consistent (no mixed empty/filled, no duplicates)
- Residue numbering sequential (no duplicates, detect insertion codes)
- No duplicate atom names within residues
- AltLoc column clean (no A/B alternate conformations)
- Backbone integrity (Cα distances 3.2-3.8 Å between consecutive residues)
- Standard residue names (protein, DNA, RNA)

Reference: `playbook.md` → "PDB Structural Validation" for detailed checks.

**Ligand and HETATM classification:**
- Classify HETATM residues: water / structural ion / ligand / unknown
- For ions: verify in FF residuetypes.dat
- For ligands: check if `EXTRA_ITPS` references required topology files
- For unknowns: report residue name, advise investigation

Reference: `playbook.md` → "Ligand & Custom Topology Validation".

**Config inspection:**
- FORCEFIELD is set and appropriate for system composition
- WATER_MODEL is set
- CATION/ANION are set
- PRODUCTION_NS and CHUNK_NS are reasonable
- Resource values are adequate for system size

Reference: `playbook.md` for config relationships and decision rules.

## Step 4: Validate Project State

Check that the project state is internally consistent:

- `.state/workflow.json` exists and is valid JSON
- Phase statuses match actual output files (sentinel file existence)
- Fingerprint matches current config/profile/MDP/PDB
- No stale "running" states without corresponding job logs
- Partial completion detected (e.g., setup done but equilibration not started)

If inconsistencies exist, explain them and recommend state reset if needed.

Reference: `playbook.md` → "Project State Validation".

## Step 5: Identify Missing Information

Determine what would prevent execution:

- PDB missing → "Place your structure at input/system.pdb"
- config.sh missing → "Run `setup/init.sh <project>` to create the project"
- FORCEFIELD empty → "What force field does your system need?"
- ACCOUNT empty → "What is your PBS project account?"
- CLUSTER empty → "Which HPC cluster are you targeting?"

## Step 6: Run Deterministic Validation

Run the validation script:

```bash
bash setup/validate.sh <project>
```

This checks config, FF, profile, MDPs, numeric params, walltime format, resources.

Then apply domain-level reasoning beyond what `validate.sh` checks:
- PDB structural integrity (Step 3)
- Ligand topology readiness (Step 3)
- FF compatibility with PDB residues
- MDP physics consistency
- Resource adequacy for system size

Reference: `playbook.md` → "Validation Knowledge".

## Step 7: Estimate Resources

Using actual project inputs, estimate:

- Solute atom count (from PDB)
- Total atom count (after solvation, estimated from box volume)
- Trajectory size (from nstxout-compressed, PRODUCTION_NS, atom count)
- Disk usage (trajectory + checkpoints + logs)
- Production runtime (from benchmarks and atom count)
- CHUNK_NS fit in PROD_WALLTIME

Present estimates as approximations with clear uncertainty.

Reference: `playbook.md` → "Resource Estimation".

## Step 8: Recommend Improvements

Suggest improvements backed by evidence:

- **nstlist=100**: Measured +10.7% speedup on A100 (benchmark job 968167)
- **vbt=0.005**: Measured +6.4% speedup, same physics (benchmark job 968167)
- **Resource adequacy**: Estimate memory needs from atom count
- **CHUNK_NS vs walltime**: Verify chunk fits in walltime budget
- **Production length**: Guidance based on system type (protein-DNA: 100-500 ns)

Reference: `playbook.md` for benchmark results and decision rules.

## Step 9: Clarify Ambiguous Decisions

Resolve situations where the skill cannot determine the right answer:

- FF doesn't support PDB residues → "Your PDB has [residue]. [FF] doesn't support it. Did you mean [alternative]?"
- PRODUCTION_NS too short for system type → "For [system type], typical range is [X]-[Y] ns. You set [Z] ns."
- ACCOUNT is empty → "What is your PBS project account?"
- Ligand topology missing → "Your PDB has [residue]. You need a topology file. Here's what to do..."

Never guess. If the skill cannot determine correctness, ask the user.

## Step 10: Execute Deterministic Scripts After Approval

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

## Step 11: Verify Outputs

After script execution, confirm expected artifacts exist:

| Script | Expected outputs |
|--------|-----------------|
| `init.sh` | `config.sh`, `mdp/*.mdp`, `.state/workflow.json`, `.state/fingerprint` |
| `get-ff.sh install` | `forcefields/<name>.ff/` with `forcefield.itp` |
| `validate.sh` | Exit code 0, 0 errors |

## Step 12: Scientific Readiness Review

Perform a final scientific review before allowing submission:

- Box size assessment (too small / too large / appropriate)
- Production length assessment (matches system type?)
- MDP consistency (dt + constraints, cutoff values, output frequency)
- Risk level (LOW / MEDIUM / HIGH)
- Hidden assumptions flagged (temperature, pressure, water model, ensemble)

If HIGH risk: block submission until user acknowledges.
If MEDIUM risk: warn but allow.

Reference: `playbook.md` → "Scientific Readiness Review".

## Step 13: Produce Final Preparation Report

Generate a concise readiness report summarizing everything:

- System summary (type, chains, residues, atoms)
- Configuration (FF, water model, box, salt)
- Simulation length (production, chunks, total)
- Resources (setup, equilibration, production)
- Estimates (trajectory size, disk usage, runtime)
- Validation status (all checks pass/fail)
- Potential risks
- Recommendations
- READY / NOT READY decision

Reference: `playbook.md` → "Final Preparation Report" for template.

## Step 14: Hand Off to Execution Stage

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
