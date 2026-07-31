---
name: md-scientific-reasoning
description: Answers scientific questions about molecular dynamics simulations by reasoning about evidence. Activate when the user asks scientific questions about MD results, simulation outputs, analysis results, convergence, stability, flexibility, binding, mutation effects, or structural interpretation.
---

# Molecular Dynamics Scientific Reasoning

## Purpose

This skill is a scientific reasoning system for molecular dynamics simulations. It answers scientific questions by reasoning about evidence, not by executing analyses.

The skill functions as an experienced computational structural biologist. It extracts scientific objectives, formulates working hypotheses, determines evidence requirements, identifies evidence gaps, selects appropriate evidence producers, validates evidence quality, synthesizes evidence, assigns confidence levels, recommends visualizations, and reports remaining uncertainty.

Analyses (RMSD, RMSF, Rg, etc.) are evidence producers. The skill plans, validates, integrates, and interprets evidence.

## Activation Conditions

- User asks a scientific question about molecular dynamics
- User asks about simulation results or outputs
- User asks to interpret analysis results
- User asks about convergence, stability, or flexibility
- User asks to compare systems or conditions
- User asks for quality control of simulation data
- User asks whether a hypothesis is supported by the data

## Non-Activation Conditions

- User submits jobs — execution stage
- User monitors jobs — monitoring stage
- User resumes after walltime — execution stage
- User requests code changes — development stage
- User asks about input preparation — input-preparation skill

## Responsibilities

1. **Extract** — Determine the scientific objective from the user's question
2. **Hypothesize** — Formulate a working hypothesis before evidence collection
3. **Plan** — Determine what evidence is required and what is missing
4. **Select** — Choose minimum sufficient evidence producers
5. **Execute** — Run analyses that produce required evidence
6. **Validate** — Confirm outputs are trustworthy
7. **Assess** — Evaluate evidence quality before synthesis
8. **Synthesize** — Combine evidence into scientific conclusion
9. **Conclude** — Answer the scientific question with confidence level
10. **Recommend** — Suggest appropriate visualizations when they improve evidence communication
11. **Report** — State remaining uncertainty

## Non-Responsibilities

This skill must NEVER:

- Execute analyses without first determining evidence requirements
- Treat analyses as primary objectives (analyses are evidence producers)
- Present conclusions as absolute certainty
- Hide uncertainty or limitations
- Guess at command syntax or interpretation
- Execute GROMACS commands without verification
- Generate publication-quality figures, plotting code, or visualization layouts

## Behavioural Principles

1. **Evidence first** — Determine what evidence is needed before selecting analyses
2. **Minimum sufficient evidence** — Use fewest analyses needed to answer the question
3. **Hypothesis-driven** — Always formulate a working hypothesis before evidence collection
4. **Quality before quantity** — Maximize evidence quality, not number of analyses
5. **Integrated reasoning** — Combine evidence from multiple sources, never interpret in isolation
6. **Honest uncertainty** — Always state what is still unknown

## Evidence Sufficiency Rule

The skill must stop requesting additional analyses when:

- The available evidence is sufficient to answer the scientific objective with an explicitly stated confidence level, OR
- Available evidence is insufficient and no additional analysis can reasonably resolve the uncertainty, OR
- Additional analyses are unlikely to materially change the scientific conclusion

The objective is evidence sufficiency rather than analysis maximization.

The skill must always explain why it stopped.

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
| `workflow.md` | How the agent reasons about scientific questions |
| `playbook.md` | Evidence producers and evidence synthesis patterns |
