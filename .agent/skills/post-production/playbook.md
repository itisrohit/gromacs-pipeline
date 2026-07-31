# Repository Interaction Principles

1. The repository is always the primary source of truth.
   Consult repository before playbook, documentation, or external sources.

2. Inspect existing repository workflows before generating new procedures.
   If the repository already implements a workflow, use it.

3. Reuse existing implementations whenever possible.
   Do not create new procedures when existing ones suffice.

4. Never duplicate repository functionality.
   The playbook explains operations; the repository implements workflows.

5. When repository behaviour changes, re-read the repository.
   Do not rely on stale knowledge from previous sessions.

6. If repository and playbook disagree, trust the repository.
   The repository is the implementation; the playbook is knowledge about it.

7. If repository and external documentation disagree, report the conflict.
   Never silently choose one source over another.

---

# Production Completion Verification

## Objective

Confirm that the production simulation completed successfully and all required outputs exist.

## When to Use

Before any post-production analysis. This is a prerequisite for all other operations.

## What to Check

- `output/production/PRODUCTION_COMPLETE` exists
- `output/production/md.xtc` exists and is non-empty
- `output/production/md.tpr` exists and is non-empty
- `output/production/md.edr` exists and is non-empty
- `output/production/md.log` exists (for performance and completion info)
- `.state/workflow.json` shows production phase as "completed"

## Repository Prerequisites

**Required:**
- Production workflow completed (run.sh submit)

**Optional:**
- Checkpoint file (md.cpt) — not required if production completed

## What to Report

- Production completion status
- Final simulation time (from md.log or checkpoint)
- Performance (ns/day from md.log)
- Any warnings or errors in md.log

## Decision Rules

- If PRODUCTION_COMPLETE marker exists → production completed
- If marker is missing but outputs exist → check md.log for completion
- If outputs are missing → production did not complete, report issue
- If outputs are corrupt → report issue, do not proceed

---

# Energy Extraction & Stability Assessment

## Objective

Determine whether the simulation maintained correct temperature, pressure, and energy stability throughout production.

## Scientific Meaning

The energy file (md.edr) contains time-series data for temperature, pressure, total energy, potential energy, kinetic energy, volume, and density. These quantities should fluctuate around their reference values without systematic drift.

Temperature should remain near the thermostat reference (300 K). Pressure should fluctuate around the barostat reference (1 bar) with amplitude scaling as 1/sqrt(N). Total energy should be conserved (small drift acceptable). Volume and density should be stable in NPT simulations.

## When to Use

After production completes. This is typically the first analysis performed because energy stability is a prerequisite for meaningful structural analysis.

## Required Inputs

- `output/production/md.edr` — energy file from production
- `output/production/md.tpr` — for reference values

## Required Trajectory State

Not applicable (energy file is independent of trajectory).

## Interactive Selections

When using gmx energy, the following selections are required:

1. "Select terms to output from" → Temperature, Pressure, Total-Energy, Potential, Kinetic-En., Volume, Density

The exact selection depends on what is available in the energy file. The skill should select all relevant thermodynamic quantities.

## Expected Outputs

- `.xvg` file with columns: time and selected energy terms
- File should be non-empty with monotonic time column

## Output Validation

- Output file exists and is non-empty
- First column is time (increasing)
- Selected columns contain numeric values (no NaN)
- Time range covers the production period

## Repository Prerequisites

**Required:**
- Production completed with energy file output

**Optional:**
- None

## Operational Pitfalls

**Selection pitfalls:**
- Selecting wrong energy term → misleading assessment
- Not selecting enough terms → incomplete picture

**Interpretation pitfalls:**
- Confusing equilibration drift with production drift → only assess production portion
- Ignoring short-term fluctuations → fluctuations are normal, look for systematic drift
- Assuming perfect conservation → some drift is acceptable in NPT

**File pitfalls:**
- Energy file from equilibration only → production energy file needed
- Corrupt energy file → check with gmx check

## Scientific Interpretation

**What to look for:**
- Temperature fluctuating around 300 K without systematic drift
- Pressure fluctuating around 1 bar with reasonable amplitude
- Total energy showing minimal drift (acceptable: < 1e-4 kJ/mol/ps/atom)
- Volume and density stable (water density ~997 kg/m³ at 300 K, 1 bar)

**Common misinterpretations:**
- "Pressure fluctuations are too large" → large fluctuations are normal in NPT, amplitude scales with system size
- "Energy is not conserved" → some drift is expected in NPT with Berendsen/PR barostat
- "Temperature is not exactly 300 K" → temperature fluctuates, average should be near 300 K

**When conclusions are justified:**
- Temperature average is within 5 K of reference → thermostat is working
- Pressure average is within 10 bar of reference → barostat is working
- Energy drift is small and linear → no systematic problem

**When conclusions should NOT be drawn:**
- Pressure is noisy → noise is normal, look for systematic drift only
- Energy has short-term fluctuations → fluctuations are expected in MD

**Confidence considerations:**
- Temperature assessment is high confidence (well-established physics)
- Pressure assessment is medium confidence (fluctuations are large)
- Energy drift assessment requires knowing the exact acceptable threshold

## Decision Rules

- If temperature drift > 10 K → investigate thermostat settings
- If pressure drift > 50 bar → investigate barostat settings
- If energy drift is large and non-linear → investigate integrator or constraints
- If volume is changing systematically → box may not be equilibrated

## Evidence Confidence

**Repository verified:** ✅ Energy file is standard GROMACS output
**Official documentation verified:** ✅ gmx energy documented in GROMACS manual
**Scientific literature verified:** ✅ Energy stability is well-established physics
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

## Verification Checklist

**Before execution:**
- [ ] Production completed
- [ ] md.edr exists and is non-empty
- [ ] md.tpr exists (for reference values)
- [ ] Compatible GROMACS version installed

**After execution:**
- [ ] Output file created
- [ ] Output file readable
- [ ] Expected columns present
- [ ] No parsing errors
- [ ] Time column is monotonic

**Ready for interpretation:**
YES / NO

## References

- Official: https://manual.gromacs.org/current/onlinehelp/gmx-energy.html
- Literature: Allen & Tildesley, "Computer Simulation of Liquids"

---

# RMSD Calculation

## Objective

Determine whether the production trajectory has structurally converged by measuring backbone RMSD over time.

## Scientific Meaning

Root mean square deviation (RMSD) measures the average displacement of atoms from a reference structure. For proteins, backbone RMSD is calculated after fitting the backbone atoms to the reference. Low, stable RMSD indicates the structure is maintaining its fold. Rising RMSD may indicate conformational change or instability.

Formula: RMSD(t) = sqrt(1/M * Σ mi ||ri(t) - ri(0)||²)

## When to Use

After production completes and trajectory is prepared. This is the primary indicator of structural stability.

## Required Inputs

- Trajectory file (must be PBC-corrected and centered)
- Structure file (TPR or GRO)
- Reference structure (usually the first frame or initial structure)

## Required Trajectory State

Prepared (PBC-corrected, centered on protein). Use `post/prepare.sh` if trajectory is raw.

## Interactive Selections

When using gmx rms, the following selections are required:

1. "Select group for least-squares fitting" → Backbone
2. "Select group for RMSD calculation" → Backbone

## Expected Outputs

- `.xvg` file with two columns: time (ps) and RMSD (nm)
- File should be non-empty, have monotonic time column, no NaN values

## Output Validation

- Output file exists and is non-empty
- First column is time (increasing)
- Second column is RMSD (non-negative)
- Time range covers the production period

## Repository Prerequisites

**Required:**
- Prepared trajectory (post/prepare.sh)

**Optional:**
- Existing index groups

## Operational Pitfalls

**Preparation pitfalls:**
- Trajectory not PBC-corrected → atoms appear to jump, inflated RMSD
- Wrong centering group → protein drifts from center
- Equilibration included → artifacts contaminate analysis

**Selection pitfalls:**
- Wrong fitting group → RMSD includes rotational artifacts
- Wrong calculation group → analyzing wrong atoms
- All atoms instead of backbone → noisier signal

**Reference pitfalls:**
- Wrong reference structure → misleading RMSD values
- Reference from different state → comparing unlike structures

**Interpretation pitfalls:**
- Confusing equilibration with production → incorrect convergence assessment
- Assuming absolute thresholds → ignoring system-specific context
- Ignoring PBC artifacts → inflated RMSD values

## Scientific Interpretation

**What to look for:**
- Rising RMSD at end of trajectory → possible incomplete convergence
- Plateau after initial rise → structure has equilibrated
- Sudden jump → conformational transition or artifact

**Common misinterpretations:**
- "RMSD < X nm means stable" → stability depends on system type and timescale
- "High RMSD means bad simulation" → high RMSD may be correct for flexible systems
- "Low RMSD means good simulation" → low RMSD may indicate insufficient sampling

**When conclusions are justified:**
- RMSD has clearly plateaued → structure has reached equilibrium
- RMSD is still rising → simulation may need extension

**When conclusions should NOT be drawn:**
- RMSD is noisy → need longer simulation or block averaging
- RMSD has multiple states → need clustering analysis
- System is membrane protein → different RMSD expectations than globular

**Confidence considerations:**
- Backbone RMSD is more reliable than all-atom RMSD
- RMSD relative to initial structure vs crystal structure may differ
- PBC artifacts can inflate RMSD if trajectory not prepared

## Decision Rules

- If RMSD is still rising at end → recommend extending simulation
- If RMSD has plateaued → structure appears equilibrated
- If RMSD has sudden jumps → investigate for artifacts or transitions
- If trajectory not prepared → stop, prepare trajectory first

## Evidence Confidence

**Repository verified:** ✅ Trajectory preparation exists (post/prepare.sh)
**Official documentation verified:** ✅ gmx rms documented in GROMACS manual
**Scientific literature verified:** ✅ RMSD is well-established structural measure
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

## Verification Checklist

**Before execution:**
- [ ] Production completed
- [ ] Trajectory prepared (PBC-corrected, centered)
- [ ] TPR file exists
- [ ] Compatible GROMACS version installed

**After execution:**
- [ ] Output file created
- [ ] Output file readable
- [ ] Two columns present (time, RMSD)
- [ ] RMSD values are non-negative
- [ ] No parsing errors

**Ready for interpretation:**
YES / NO

## References

- Official: https://manual.gromacs.org/current/onlinehelp/gmx-rms.html
- Literature: GROMACS reference manual, eq. 461

---

# RMSF Calculation

## Objective

Identify flexible and rigid regions of the structure by computing per-residue root mean square fluctuation.

## Scientific Meaning

Root mean square fluctuation (RMSF) measures the average displacement of each residue from its mean position. High RMSF indicates flexible regions (loops, termini). Low RMSF indicates rigid regions (helices, sheets, core).

Formula: RMSF(i) = sqrt(||ri - <ri>||²)

## When to Use

After production completes and trajectory is prepared. Useful for identifying flexible regions and validating secondary structure stability.

## Required Inputs

- Trajectory file (must be PBC-corrected and centered)
- Structure file (TPR or GRO)

## Required Trajectory State

Prepared (PBC-corrected, centered on protein).

## Interactive Selections

When using gmx rmsf, the following selections are required:

1. "Select group for calculation" → Backbone (or Protein)

## Expected Outputs

- `.xvg` file with two columns: residue number and RMSF (nm)
- File should be non-empty

## Output Validation

- Output file exists and is non-empty
- First column is residue number (integer)
- Second column is RMSF (non-negative)
- RMSF values are reasonable (typically 0.01-0.5 nm for proteins)

## Repository Prerequisites

**Required:**
- Prepared trajectory (post/prepare.sh)

**Optional:**
- Existing index groups

## Operational Pitfalls

**Selection pitfalls:**
- Using all atoms → noisier than backbone-only
- Including terminal residues → artificially high RMSF

**Interpretation pitfalls:**
- Confusing high RMSF with instability → loops are naturally flexible
- Ignoring crystallographic B-factors → different measurement, not directly comparable

## Scientific Interpretation

**What to look for:**
- High RMSF in loops → normal flexibility
- High RMSF in helices → possible instability
- Low RMSF in core → expected rigidity
- Symmetric RMSF profiles → symmetric protein

**Common misinterpretations:**
- "High RMSF means unfolding" → loops are naturally flexible
- "Low RMSF means stable" → low RMSF in core is expected
- "RMSF > X means problem" → depends on residue type and location

**When conclusions are justified:**
- RMSF profile matches expected secondary structure → simulation is reasonable
- Unexpectedly high RMSF in structured regions → investigate for instability

**When conclusions should NOT be drawn:**
- Single residue has high RMSF → may be natural flexibility
- RMSF is slightly different from crystal structure → different conditions

**Confidence considerations:**
- Backbone RMSF is more reliable than side-chain RMSF
- Terminal residues often have artificially high RMSF
- Comparison to B-factors requires careful interpretation

## Decision Rules

- If RMSF is unexpectedly high in structured regions → investigate for instability
- If RMSF profile matches expected structure → simulation appears reasonable
- If trajectory not prepared → stop, prepare trajectory first

## Evidence Confidence

**Repository verified:** ✅ Trajectory preparation exists (post/prepare.sh)
**Official documentation verified:** ✅ gmx rmsf documented in GROMACS manual
**Scientific literature verified:** ✅ RMSF is well-established flexibility measure
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

## Verification Checklist

**Before execution:**
- [ ] Production completed
- [ ] Trajectory prepared
- [ ] TPR file exists
- [ ] Compatible GROMACS version installed

**After execution:**
- [ ] Output file created
- [ ] Output file readable
- [ ] Two columns present (residue, RMSF)
- [ ] RMSF values are non-negative
- [ ] No parsing errors

**Ready for interpretation:**
YES / NO

## References

- Official: https://manual.gromacs.org/current/onlinehelp/gmx-rmsf.html

---

# Radius of Gyration Calculation

## Objective

Assess whether the protein maintains its compact structure throughout the simulation.

## Scientific Meaning

Radius of gyration (Rg) measures the mass-weighted root mean square distance of atoms from the center of mass. It provides a single number characterizing the compactness of the structure. Stable Rg indicates the protein maintains its fold. Increasing Rg may indicate unfolding or expansion.

Formula: Rg = sqrt(Σ mi ||ri||² / Σ mi)

## When to Use

After production completes and trajectory is prepared. Useful for detecting unfolding or large conformational changes.

## Required Inputs

- Trajectory file (must be PBC-corrected and centered)
- Structure file (TPR or GRO)

## Required Trajectory State

Prepared (PBC-corrected, centered on protein).

## Interactive Selections

When using gmx gyrate, the following selections are required:

1. "Select group for calculation" → Protein (or Backbone)

## Expected Outputs

- `.xvg` file with columns: time (ps), Rg (nm), and optionally Rg.x, Rg.y, Rg.z
- File should be non-empty

## Output Validation

- Output file exists and is non-empty
- First column is time (increasing)
- Second column is Rg (positive values)
- Time range covers the production period

## Repository Prerequisites

**Required:**
- Prepared trajectory (post/prepare.sh)

**Optional:**
- Existing index groups

## Operational Pitfalls

**Selection pitfalls:**
- Including water → Rg dominated by solvent
- Excluding part of protein → artificially low Rg

**Interpretation pitfalls:**
- Small Rg change = no problem → depends on system size
- Rg increase = unfolding → could be conformational change, not necessarily unfolding

## Scientific Interpretation

**What to look for:**
- Stable Rg → protein maintains compact structure
- Monotonic Rg increase → possible unfolding or expansion
- Rg fluctuations → normal breathing motions

**Common misinterpretations:**
- "Rg > X means unfolding" → depends on protein size and expected Rg
- "Rg is constant means stable" → Rg can be constant while internal structure changes
- "Rg increase means bad simulation" → Rg increase may be correct for flexible systems

**When conclusions are justified:**
- Rg is stable and matches expected value → structure is compact
- Rg is increasing without plateau → possible unfolding

**When conclusions should NOT be drawn:**
- Rg has small fluctuations → fluctuations are normal
- Rg is different from crystal structure → solution conditions differ

**Confidence considerations:**
- Rg is a global measure, not residue-specific
- Rg does not distinguish between different types of structural change
- Comparison to expected Rg requires knowing the protein size

## Decision Rules

- If Rg is monotonically increasing → investigate for unfolding
- If Rg is stable → structure appears compact
- If Rg is very different from expected → check protein size and expected Rg
- If trajectory not prepared → stop, prepare trajectory first

## Evidence Confidence

**Repository verified:** ✅ Trajectory preparation exists (post/prepare.sh)
**Official documentation verified:** ✅ gmx gyrate documented in GROMACS manual
**Scientific literature verified:** ✅ Rg is well-established compactness measure
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

## Verification Checklist

**Before execution:**
- [ ] Production completed
- [ ] Trajectory prepared
- [ ] TPR file exists
- [ ] Compatible GROMACS version installed

**After execution:**
- [ ] Output file created
- [ ] Output file readable
- [ ] Time and Rg columns present
- [ ] Rg values are positive
- [ ] No parsing errors

**Ready for interpretation:**
YES / NO

## References

- Official: https://manual.gromacs.org/current/onlinehelp/gmx-gyrate.html
- Literature: GROMACS reference manual, eq. 459-460

---

# Hydrogen Bond Analysis

## Objective

Assess the stability of hydrogen bonds that maintain secondary structure or mediate protein-DNA interactions.

## Scientific Meaning

Hydrogen bonds are electrostatic interactions between a hydrogen bond donor and acceptor. In proteins, hydrogen bonds stabilize alpha-helices and beta-sheets. In protein-DNA complexes, hydrogen bonds mediate specific recognition. Occupancy measures the fraction of time a hydrogen bond exists.

## When to Use

After production completes and trajectory is prepared. Essential for protein-DNA systems. Useful for assessing secondary structure stability.

## Required Inputs

- Trajectory file (must be PBC-corrected and centered)
- Structure file (TPR or GRO)

## Required Trajectory State

Prepared (PBC-corrected, centered on protein).

## Interactive Selections

When using gmx hbond, the following selections are required:

1. "Select group for donor" → Protein (or Protein_DNA)
2. "Select group for acceptor" → DNA (or Water)

The exact selection depends on what hydrogen bonds are of interest.

## Expected Outputs

- `.xvg` file with hydrogen bond count over time
- `.dat` file with hydrogen bond occupancy
- File should be non-empty

## Output Validation

- Output files exist and are non-empty
- Occupancy values are between 0 and 1
- Time column is monotonic

## Repository Prerequisites

**Required:**
- Prepared trajectory (post/prepare.sh)

**Optional:**
- Existing index groups for protein and DNA

## Operational Pitfalls

**Selection pitfalls:**
- Wrong groups selected → analyzing wrong hydrogen bonds
- Including water → hydrogen bonds with solvent dominate

**Interpretation pitfalls:**
- High occupancy always means stable → depends on hydrogen bond type
- Low occupancy always means unstable → some hydrogen bonds are transient by design

**File pitfalls:**
- No hydrogen bonds found → check selection, may need different groups

## Scientific Interpretation

**What to look for:**
- High occupancy hydrogen bonds in secondary structure → structure is stable
- Low occupancy hydrogen bonds in protein-DNA interface → interactions may be weak
- Changing hydrogen bond patterns → conformational change

**Common misinterpretations:**
- "Occupancy > 80% means stable" → depends on the hydrogen bond type
- "No hydrogen bonds means problem" → may need different selection
- "Hydrogen bonds change means unstable" → dynamics are expected

**When conclusions are justified:**
- Secondary structure hydrogen bonds are stable → fold is maintained
- Protein-DNA hydrogen bonds are stable → complex is stable

**When conclusions should NOT be drawn:**
- Single hydrogen bond has low occupancy → may be transient by design
- Hydrogen bond pattern differs from crystal structure → solution conditions differ

**Confidence considerations:**
- Hydrogen bond detection depends on geometry criteria
- Different GROMACS versions may use slightly different criteria
- Occupancy is averaged over the trajectory, not instantaneous

## Decision Rules

- If secondary structure hydrogen bonds are stable → fold appears maintained
- If protein-DNA hydrogen bonds are stable → complex appears stable
- If hydrogen bonds are changing → investigate for conformational change
- If no hydrogen bonds found → check selection groups

## Evidence Confidence

**Repository verified:** ✅ Trajectory preparation exists (post/prepare.sh)
**Official documentation verified:** ✅ gmx hbond documented in GROMACS manual
**Scientific literature verified:** ✅ Hydrogen bonds are well-established interaction measure
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

## Verification Checklist

**Before execution:**
- [ ] Production completed
- [ ] Trajectory prepared
- [ ] TPR file exists
- [ ] Compatible GROMACS version installed
- [ ] Appropriate groups available

**After execution:**
- [ ] Output files created
- [ ] Output files readable
- [ ] Occupancy values between 0 and 1
- [ ] No parsing errors

**Ready for interpretation:**
YES / NO

## References

- Official: https://manual.gromacs.org/current/onlinehelp/gmx-hbond.html

---

# Secondary Structure Analysis (DSSP)

## Objective

Track changes in secondary structure (alpha-helices, beta-sheets) throughout the simulation to detect unfolding or structural rearrangement.

## Scientific Meaning

DSSP (Dictionary of Secondary Structure of Proteins) assigns secondary structure based on hydrogen bonding patterns. Alpha-helices, beta-sheets, turns, and coils are identified for each residue at each frame. Changes in secondary structure content indicate structural rearrangement.

## When to Use

After production completes and trajectory is prepared. Essential for assessing whether secondary structure is maintained.

## Required Inputs

- Trajectory file (must be PBC-corrected and centered)
- Structure file (TPR or GRO)

## Required Trajectory State

Prepared (PBC-corrected, centered on protein).

## Interactive Selections

When using gmx dssp, the following selections are required:

1. "Select group for calculation" → Protein

## Expected Outputs

- `.xvg` file with secondary structure assignments over time
- File should be non-empty

## Output Validation

- Output file exists and is non-empty
- Contains secondary structure assignments (H, B, E, G, T, S, C)
- Time column is monotonic

## Repository Prerequisites

**Required:**
- Prepared trajectory (post/prepare.sh)

**Optional:**
- Existing index groups

## Operational Pitfalls

**Selection pitfalls:**
- Including non-protein atoms → DSSP only works for proteins
- Wrong group selected → analyzing wrong residues

**Interpretation pitfalls:**
- Small changes in helix count → normal breathing motions
- Complete loss of secondary structure → possible unfolding

**File pitfalls:**
- DSSP not installed → gmx dssp requires DSSP binary
- Wrong DSSP version → may produce different assignments

## Scientific Interpretation

**What to look for:**
- Stable helix and sheet counts → secondary structure is maintained
- Decreasing helix content → possible unfolding
- Increasing sheet content → possible aggregation

**Common misinterpretations:**
- "Helix count changes slightly" → small fluctuations are normal
- "DSSP differs from crystal structure" → solution conditions differ
- "Some helices unfold" → may be correct for flexible regions

**When conclusions are justified:**
- Secondary structure content is stable → fold is maintained
- Significant loss of secondary structure → possible unfolding

**When conclusions should NOT be drawn:**
- Single frame shows different assignment → transient fluctuation
- DSSP differs slightly from PDB assignment → different hydrogen bond criteria

**Confidence considerations:**
- DSSP assignment depends on hydrogen bonding criteria
- Different DSSP implementations may differ slightly
- Terminal residues often have irregular assignments

## Decision Rules

- If secondary structure is stable → fold appears maintained
- If significant loss of helices → investigate for unfolding
- If DSSP fails → check DSSP installation and version
- If trajectory not prepared → stop, prepare trajectory first

## Evidence Confidence

**Repository verified:** ✅ Trajectory preparation exists (post/prepare.sh)
**Official documentation verified:** ✅ gmx dssp documented in GROMACS manual
**Scientific literature verified:** ✅ DSSP is standard secondary structure assignment
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

## Verification Checklist

**Before execution:**
- [ ] Production completed
- [ ] Trajectory prepared
- [ ] TPR file exists
- [ ] Compatible GROMACS version installed
- [ ] DSSP binary available

**After execution:**
- [ ] Output file created
- [ ] Output file readable
- [ ] Contains valid secondary structure assignments
- [ ] No parsing errors

**Ready for interpretation:**
YES / NO

## References

- Official: https://manual.gromacs.org/current/onlinehelp/gmx-dssp.html
- Literature: Kabsch & Sander, "Dictionary of Protein Secondary Structure"

---

# COM Distance Calculation

## Objective

Measure the distance between centers of mass of two groups (e.g., protein and DNA) to assess complex stability.

## Scientific Meaning

Center of mass (COM) distance measures the separation between two groups of atoms. For protein-DNA complexes, this indicates whether the protein remains bound to DNA. Stable distance suggests a stable complex. Increasing distance may indicate dissociation.

## When to Use

After production completes and trajectory is prepared. Essential for protein-DNA or protein-ligand systems.

## Required Inputs

- Trajectory file (must be PBC-corrected and centered)
- Structure file (TPR or GRO)
- Index file with groups for the two molecules

## Required Trajectory State

Prepared (PBC-corrected, centered on complex).

## Interactive Selections

When using gmx distance, the following selections are required:

1. "Select two groups" → Protein, DNA (or Protein, Ligand)

## Expected Outputs

- `.xvg` file with distance (nm) over time
- File should be non-empty

## Output Validation

- Output file exists and is non-empty
- Distance values are non-negative
- Time column is monotonic

## Repository Prerequisites

**Required:**
- Prepared trajectory (post/prepare.sh)
- Index file with appropriate groups

**Optional:**
- None

## Operational Pitfalls

**Selection pitfalls:**
- Wrong groups selected → measuring wrong distance
- PBC artifacts → distance jumps between periodic images

**Interpretation pitfalls:**
- Distance increase always means dissociation → could be conformational change
- Distance fluctuation is problem → fluctuations are normal

**File pitfalls:**
- No index file → need to create index groups first

## Scientific Interpretation

**What to look for:**
- Stable distance → complex appears stable
- Increasing distance → possible dissociation
- Distance jumps → PBC artifact or conformational change

**Common misinterpretations:**
- "Distance > X means dissociated" → depends on system size
- "Distance fluctuates means unstable" → fluctuations are normal
- "Distance is constant means stable" → may not capture internal dynamics

**When conclusions are justified:**
- Distance is stable and matches expected binding → complex appears stable
- Distance is increasing without plateau → possible dissociation

**When conclusions should NOT be drawn:**
- Distance has small fluctuations → fluctuations are normal
- Distance differs from crystal structure → solution conditions differ

**Confidence considerations:**
- COM distance is a global measure
- Does not capture specific interactions
- PBC corrections are essential for accurate distances

## Decision Rules

- If distance is stable → complex appears stable
- If distance is increasing → investigate for dissociation
- If distance has jumps → check PBC correction
- If trajectory not prepared → stop, prepare trajectory first

## Evidence Confidence

**Repository verified:** ✅ Trajectory preparation exists (post/prepare.sh)
**Official documentation verified:** ✅ gmx distance documented in GROMACS manual
**Scientific literature verified:** ✅ COM distance is standard interaction measure
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

## Verification Checklist

**Before execution:**
- [ ] Production completed
- [ ] Trajectory prepared
- [ ] TPR file exists
- [ ] Index file with appropriate groups exists
- [ ] Compatible GROMACS version installed

**After execution:**
- [ ] Output file created
- [ ] Output file readable
- [ ] Distance values are non-negative
- [ ] No parsing errors

**Ready for interpretation:**
YES / NO

## References

- Official: https://manual.gromacs.org/current/onlinehelp/gmx-distance.html
