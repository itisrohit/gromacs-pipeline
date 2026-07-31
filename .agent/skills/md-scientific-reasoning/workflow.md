# Workflow: Molecular Dynamics Scientific Reasoning

This document describes how the agent reasons about scientific questions. It is the canonical reasoning workflow.

## Overview

```
Scientific Objective
    ↓
Working Hypothesis
    ↓
Evidence Required
    ↓
Evidence Already Available
    ↓
Evidence Still Missing
    ↓
Select Evidence Producers
    ↓
Execute
    ↓
Validate Outputs
    ↓
Evidence Quality Assessment
    ↓
Evidence Synthesis
    ↓
Scientific Conclusion
    ↓
Remaining Uncertainty
```

## Step 1: Scientific Objective

Extract what the user is trying to determine.

**Ask:**
- What scientific question is being asked?
- What would constitute an answer?
- What is the scientific context?

**Example:**
- User: "Is the protein stable?"
- Objective: Determine whether the protein maintains its structural fold throughout the simulation.

## Step 2: Working Hypothesis

Formulate a provisional explanation before evidence collection.

**Purpose:** Make explicit what the current scientific explanation is. The hypothesis is not proved — it is tested against evidence.

**Rules:**
- Always state the hypothesis explicitly
- Keep it provisional — evidence may confirm, weaken, or reject it
- Base it on the scientific objective and any prior knowledge

**Example:**
- Objective: Determine whether the protein is stable.
- Hypothesis: The protein maintains its structural fold.

## Step 3: Evidence Required

Determine what evidence would answer the scientific objective.

**Ask:**
- What evidence would confirm the hypothesis?
- What evidence would weaken the hypothesis?
- What evidence would reject the hypothesis?

**Example:**
- Hypothesis: The protein maintains its structural fold.
- Required evidence: Structural stability metrics that show the fold is maintained.

## Step 4: Evidence Already Available

Check what evidence is already available from prior analyses or existing data.

**Check:**
- Are there existing analysis outputs?
- Has trajectory preparation been done?
- Are there energy files from production?

## Step 5: Evidence Still Missing

Determine what evidence must be obtained.

**Ask:**
- What evidence is still missing before I can answer the scientific objective?
- Would obtaining additional evidence materially change the conclusion?

**Evidence Sufficiency Rule:**

The skill must stop requesting additional analyses when:

- The available evidence is sufficient to answer the scientific objective with an explicitly stated confidence level, OR
- Available evidence is insufficient and no additional analysis can reasonably resolve the uncertainty, OR
- Additional analyses are unlikely to materially change the scientific conclusion

The objective is evidence sufficiency rather than analysis maximization.

The skill must always explain why it stopped.

## Step 6: Select Evidence Producers

Choose analyses that produce the missing evidence.

**Ask:**
- Which analyses produce the required evidence?
- Which provide complementary evidence?
- What is the minimum sufficient set?

**Reference:** `playbook.md` → Part 2: Evidence Producers

**Selection principles:**
1. Minimum sufficient evidence
2. Complementary evidence preferred
3. Each analysis should increase confidence
4. Avoid redundant evidence

## Step 7: Execute

Run the selected evidence producers.

**For each analysis:**
1. Check Verification Checklist (before execution)
2. Execute the operation
3. Check Verification Checklist (after execution)

**Reference:** `playbook.md` → Part 2: Evidence Producers

## Step 8: Validate Outputs

Confirm that evidence was actually produced and is trustworthy.

**Check:**
- Output files exist and are non-empty
- Expected format (correct columns, no parsing errors)
- No GROMACS warnings
- Data covers the production period

**If validation fails:**
- Report the issue
- Do not interpret invalid evidence

## Step 9: Evidence Quality Assessment

Before combining evidence, evaluate whether the evidence itself is trustworthy.

**Assess:**
- Trajectory length — is it sufficient for the scientific question?
- Sampling adequacy — has the relevant conformational space been explored?
- Simulation convergence — has the system reached equilibrium?
- Appropriate analysis — does this analysis actually address the objective?
- Reference structure — is the reference appropriate?
- Known limitations — are there methodological caveats?

**If evidence quality is low:**
- State the limitation explicitly
- Reduce confidence accordingly
- Do not over-interpret

## Step 10: Evidence Synthesis

Combine evidence from multiple analyses into a scientific conclusion.

**Ask:**
- Do all evidence sources agree?
- Are there discrepancies?
- What confidence level is warranted?

**Synthesis rules:**
- All evidence agrees → high confidence
- Most evidence agrees → medium confidence
- Evidence disagrees → report discrepancy, low confidence
- Insufficient evidence → state limitation

**Reference:** `playbook.md` → Part 3: Evidence Synthesis

## Step 11: Scientific Conclusion

Answer the scientific question.

**Include:**
- Direct answer to the question
- Evidence that supports the conclusion
- Confidence level
- Any caveats or limitations

**Format:**
- State the conclusion clearly
- Cite the evidence
- Assign confidence
- Note any assumptions

## Step 12: Remaining Uncertainty

Every conclusion must end with remaining uncertainty.

**Answer:**
- What is still unknown?
- What assumptions remain?
- What additional evidence would increase confidence?

**Examples:**
- Longer trajectory would increase confidence
- Replica simulations would confirm reproducibility
- Additional analyses (e.g., PCA) could reveal conformational dynamics
- Experimental validation would confirm computational findings

**Never present conclusions as absolute certainty.**

## Uncertainty Handling

At every step, if uncertainty exists:

1. **Report it explicitly** — never hide uncertainty
2. **State the confidence level** — high, medium, or low
3. **Explain what would increase confidence**
4. **Recommend verification steps if possible**

## Decision Rules

These rules apply throughout the workflow:

- If required evidence cannot be obtained → state limitation
- If evidence sources disagree → report discrepancy
- If confidence is low → recommend additional evidence
- If question is beyond scope → state honestly
- If repository and documentation disagree → report conflict, never choose silently
- If evidence quality is low → reduce confidence accordingly
