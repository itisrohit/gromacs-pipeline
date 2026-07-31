---
name: post-production
description: Verifies simulation health, orchestrates analyses, interprets results, and produces quality assessments after production MD completes. Activate when production is complete, when QC is requested, or when simulation convergence is questioned.
---

# Post-Production Analysis & Verification

## Purpose

After production completes, three questions must be answered:

1. Did the simulation complete successfully?
2. Is the simulation scientifically valid?
3. What do the results show?

This skill answers all three through repository-first, evidence-first reasoning.

## Activation Conditions

- Production phase status is "completed"
- User asks whether simulation completed successfully
- User requests quality control analysis
- User asks about simulation convergence
- User asks to interpret production results
- User asks for post-production analysis

## Non-Activation Conditions

- User submits jobs (`run.sh submit`) — execution stage
- User monitors running jobs (`run.sh status`) — monitoring stage
- User resumes after walltime interruption — execution stage
- User requests code changes to the pipeline — development stage
- User asks about input preparation — input-preparation skill
- User asks about visualization only — user responsibility

## Responsibilities

1. **Verify** — Confirm production completed successfully
2. **Inspect** — Check trajectory integrity and file completeness
3. **Orchestrate** — Decide which analyses to run and execute them
4. **Interpret** — Read analysis outputs and apply scientific reasoning
5. **Correlate** — Synthesize findings across multiple analyses
6. **Assess** — Determine convergence and simulation quality
7. **Recommend** — Suggest next steps based on assessment
8. **Report** — Produce final quality assessment

## Non-Responsibilities

This skill must NEVER:

- Execute GROMACS commands directly without following the evidence hierarchy
- Present unverified commands as authoritative
- Generate plots (user responsibility)
- Perform advanced analysis (PCA, free energy, etc.) — user responsibility
- Make scientific conclusions beyond quality assessment
- Hide uncertainty or ambiguity
- Guess at command syntax or interpretation

## Behavioural Principles

1. **Verify before interpreting** — Ensure trajectory is valid before analyzing
2. **Compare to baseline** — Assess changes relative to initial or equilibrated state
3. **Look for convergence** — Focus on whether metrics have plateaued
4. **Correlate signals** — Don't assess metrics in isolation
5. **Report confidence** — State certainty level with every assessment
6. **Never fabricate** — If analysis is missing data, say so

## Verified Knowledge Principle

The skill must never execute or recommend operational procedures solely from model memory.

Operational procedures must always be verified using the defined evidence hierarchy before execution or recommendation.

If verification cannot be completed, the skill must explicitly report uncertainty rather than presenting unverified procedures as authoritative.

The skill must clearly distinguish:

- Repository facts (what the code does)
- Official documentation (what GROMACS docs state)
- Scientific evidence (published findings)
- Community conventions (widely used, not validated)
- Agent reasoning (inference from available evidence)

This principle applies to:

- Commands
- Workflows
- Procedures
- Recommendations
- Scientific interpretation

Whenever uncertainty exists it must report uncertainty instead of guessing.

## Evidence Hierarchy

Before making any recommendation, verify information in this order:

| Level | Source | When to use |
|-------|--------|-------------|
| 1 | Repository implementation | What the pipeline actually does |
| 2 | Repository documentation | What AGENTS.md, README.md document |
| 3 | Playbook operational knowledge | Verified operational procedures |
| 4 | Official GROMACS documentation | Tool syntax and behavior |
| 5 | Scientific literature | Interpretation and thresholds |
| 6 | Wider internet | Last resort only, always labeled unverified |

Every recommendation must cite its evidence source.

## Supporting Documents

| Document | Purpose |
|----------|---------|
| `workflow.md` | How the agent thinks through post-production tasks |
| `playbook.md` | Operational knowledge for each analysis type |
