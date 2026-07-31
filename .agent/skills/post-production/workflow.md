# Workflow: Post-Production Analysis & Verification

This document describes how the agent thinks through post-production tasks. It is not a rigid sequence of steps — it is the reasoning pattern the agent follows.

## Overview

```
User request
    ↓
Verify production completed
    ↓
Inspect repository
    ↓
Inspect trajectory and outputs
    ↓
Determine required analyses
    ↓
Apply evidence hierarchy
    ↓
Execute analyses
    ↓
Validate outputs
    ↓
Interpret results
    ↓
Correlate findings
    ↓
Assess convergence
    ↓
Report findings
```

## Step 1: Verify Production Completed

Before any analysis, confirm the simulation actually finished.

**Check:**
- `output/production/PRODUCTION_COMPLETE` exists
- `output/production/md.xtc` exists and is non-empty
- `output/production/md.tpr` exists and is non-empty
- `output/production/md.edr` exists and is non-empty
- `.state/workflow.json` shows production as completed

**If not completed:**
- Report that production has not finished
- Explain what is missing
- Do not proceed with analysis

**Reference:** `playbook.md` → "Production Completion Verification"

## Step 2: Inspect Repository

Before generating procedures, check what the repository already provides.

**Check:**
- Repository Interaction Principles in playbook.md
- Existing repository workflows (post/prepare.sh)
- Existing repository helpers (setup/validate.sh, etc.)
- What the repository already documents

**Apply principle:** The repository is always the primary source of truth. If the repository already implements a workflow, use it.

**Reference:** `playbook.md` → "Repository Interaction Principles"

## Step 3: Inspect Trajectory and Outputs

Check that all required files exist and are in the correct state.

**Verify:**
- Trajectory file is readable (not corrupt)
- Topology file matches trajectory
- Energy file contains expected components
- Log file shows clean completion

**If files are missing or corrupt:**
- Report the issue
- Explain what is needed
- Do not proceed with affected analyses

**Reference:** `playbook.md` → "Production Completion Verification"

## Step 4: Determine Required Analyses

Based on the user's request and system type, determine which analyses are needed.

**Standard analyses for any system:**
- Energy stability (temperature, pressure, energy drift)
- RMSD (structural stability)
- RMSF (per-residue flexibility)
- Radius of gyration (compactness)

**Additional analyses for protein-DNA systems:**
- Hydrogen bonds (protein-DNA interactions)
- COM distance (protein-DNA separation)
- Secondary structure (DSSP)

**Additional analyses for protein-ligand systems:**
- Ligand RMSD
- Ligand-protein distance
- Contact frequencies

**Reference:** `playbook.md` → Individual operation sections

## Step 5: Apply Evidence Hierarchy

For every analysis, verify the operational procedure before executing.

**Check in order:**
1. Repository implementation — does the repository already do this?
2. Repository documentation — is this documented in AGENTS.md or README.md?
3. Playbook operational knowledge — is there a verified procedure?
4. Official GROMACS documentation — consult for command syntax
5. Scientific literature — consult for interpretation
6. Wider internet — last resort only, always labeled unverified

**Never skip levels.** Every transition must be justified.

**Reference:** SKILL.md → "Evidence Hierarchy"

## Step 6: Execute Analyses

Run the verified procedures.

**For each analysis:**
1. Check Verification Checklist (before execution)
2. Execute the operation
3. Check Verification Checklist (after execution)
4. Validate outputs

**If execution fails:**
- Report the failure
- Check Operational Pitfalls section
- Do not interpret invalid outputs

**Reference:** `playbook.md` → Individual operation sections

## Step 7: Validate Outputs

After execution, confirm outputs are valid.

**Check:**
- Output files exist and are non-empty
- Expected format (correct columns, no parsing errors)
- Expected frame count
- No GROMACS warnings

**If validation fails:**
- Report the issue
- Do not proceed with interpretation of invalid data

**Reference:** `playbook.md` → Individual operation sections → "Output Validation"

## Step 8: Interpret Results

Read the analysis outputs and apply scientific reasoning.

**For each analysis:**
1. Read the output data
2. Apply interpretation principles from playbook.md
3. Distinguish observation from interpretation
4. State confidence level

**Never present inference as fact.** Always label:
- What the data shows (observation)
- What this might mean (interpretation)
- How confident you are (confidence)

**Reference:** `playbook.md` → Individual operation sections → "Scientific Interpretation"

## Step 9: Correlate Findings

Synthesize findings across multiple analyses.

**Look for:**
- Consistency — do multiple metrics agree?
- Anomalies — does one metric show unexpected behavior?
- Convergence — have metrics plateaued?
- Relationships — does one metric explain another?

**If analyses disagree:**
- Report the discrepancy
- Do not force a single conclusion
- Explain what each analysis shows

**Reference:** `playbook.md` → Individual operation sections → "Decision Rules"

## Step 10: Assess Convergence

Determine whether the simulation has converged.

**Consider:**
- Has RMSD plateaued?
- Has Rg stabilized?
- Is temperature fluctuating around reference?
- Is energy drift acceptable?
- Are secondary structure elements maintained?

**If convergence is unclear:**
- State the uncertainty
- Recommend extending the simulation
- Do not claim convergence without evidence

**Reference:** `playbook.md` → Individual operation sections → "Scientific Interpretation"

## Step 11: Report Findings

Produce a final quality assessment.

**Include:**
- Production completion status
- Trajectory integrity status
- Summary of each analysis
- Convergence assessment
- Recommendations
- Confidence levels
- Any uncertainties or caveats

**Format:**
- Use the Verification Checklist to confirm readiness
- Present findings clearly
- Cite evidence sources

**Reference:** `playbook.md` → Individual operation sections → "Verification Checklist"

## Uncertainty Handling

At every step, if uncertainty exists:

1. **Report it explicitly** — never hide uncertainty
2. **State the confidence level** — high, medium, or low
3. **Explain what would increase confidence**
4. **Recommend verification steps if possible**

The skill must never present unverified procedures as authoritative.

## Decision Rules

These rules apply throughout the workflow:

- If repository implementation exists → use it
- If repository implementation is missing → consult GROMACS documentation
- If trajectory is not prepared → stop, prepare first
- If output validation fails → stop, investigate
- If GROMACS version differs → verify command syntax
- If scientific interpretation is ambiguous → report ambiguity
- If multiple analyses disagree → report discrepancy
- If repository and documentation disagree → report conflict, never choose silently
- If confidence is less than high → state limitation explicitly
