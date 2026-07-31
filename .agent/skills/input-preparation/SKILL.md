---
name: input-preparation
description: Validates inputs, explains constraints, recommends defaults, and orchestrates project setup for GROMACS HPC simulations. Activate when preparing a new simulation, reviewing config, checking PDB readiness, selecting force fields, or diagnosing input failures.
---

# Input Preparation & Verification

## Purpose

Before any simulation runs, three things must be true:

1. Every input exists and is valid
2. Every setting is compatible with every other setting
3. The user understands what will happen and why

This skill ensures all three. It reasons about inputs, validates readiness, and orchestrates existing deterministic scripts — but never reimplements them.

## When This Skill Activates

- User creates a new simulation project
- User prepares a PDB structure for GROMACS
- User edits or reviews config.sh
- User selects or changes a force field
- User asks about MDP parameters
- User asks why a validation failed
- User asks whether settings are appropriate for their system
- User reports a pdb2gmx, grompp, or genion error
- User wants benchmark-backed parameter recommendations

## When This Skill Does NOT Activate

- User submits jobs (`run.sh submit`) — execution stage
- User monitors running jobs (`run.sh status`) — monitoring stage
- User resumes after walltime interruption — execution stage
- User requests code changes to the pipeline — development
- User asks about post-processing or analysis — analysis stage

## Responsibilities

1. **Understand** — Determine what the user wants to simulate and what inputs exist
2. **Inspect** — Read the PDB and config to understand the system
3. **Validate** — Check domain-level correctness beyond file existence
4. **Explain** — Clarify non-obvious constraints and their consequences
5. **Recommend** — Suggest improvements backed by measured evidence
6. **Clarify** — Resolve ambiguous decisions where the skill cannot determine the right answer
7. **Execute** — Run existing deterministic scripts (`init.sh`, `validate.sh`, `get-ff.sh`) only after user approval
8. **Verify** — Confirm successful completion of each preparation step
9. **Hand off** — Deliver clean, validated inputs to the execution stage

## Non-Responsibilities

This skill must NEVER:

- Submit jobs or interact with the scheduler
- Execute GROMACS commands (pdb2gmx, grompp, mdrun)
- Modify MDP physics parameters without explanation
- Override the user's scientific decisions (PRODUCTION_NS, force field choice)
- Replace `validate.sh` or `init.sh` — it complements them
- Handle resume/restart logic
- Monitor or debug running simulations
- Make assumptions about the user's scientific question

## Behavioural Principles

- **Verify before acting** — Read the PDB and config before making recommendations
- **Inspect before recommending** — Check FF compatibility before suggesting a force field
- **Explain before changing** — State why a change is needed before suggesting it
- **Ask before assuming** — When intent is ambiguous, ask the user
- **Execute only after approval** — Never run scripts without explicit user confirmation
- **Verify outputs after execution** — Check that scripts produced expected results

Never guess. Never fabricate repository behaviour. Never overwrite user choices. Never silently modify scientific decisions.

## Execution Philosophy

The repository performs deterministic work. The skill performs reasoning.

This skill orchestrates three existing deterministic scripts:

| Script | What it does | When to run |
|--------|-------------|-------------|
| `setup/init.sh <project>` | Create project directory, copy config template, copy MDPs, init state | First time setting up a project |
| `setup/validate.sh <project>` | Check config, FF, profile, MDPs, params | Before every submission |
| `forcefields/get-ff.sh install <name>` | Install force field from system GROMACS | When FF is not yet installed |

The skill presents what these scripts will do, asks for approval, then executes them. It does not contain duplicate logic from these scripts.

## Supporting Documents

| Document | Purpose |
|----------|---------|
| `workflow.md` | How the agent thinks through a preparation task |
| `playbook.md` | Operational knowledge: repository structure, validation rules, decision logic |
