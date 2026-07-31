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

# Part 1: Scientific Objective & Evidence Planning

## Objective Extraction

The skill must first understand what the user is trying to determine.

Ask:
- What scientific question is being asked?
- What would constitute an answer?
- What evidence would support or refute the conclusion?

## Working Hypothesis

Before evidence collection, formulate a provisional explanation.

The purpose is NOT to prove the hypothesis. The purpose is to make explicit what the current scientific explanation is before evidence collection begins.

The hypothesis must always remain provisional. The evidence may confirm, weaken, or reject it.

## Evidence Requirements

For each scientific objective, determine:

**Required Evidence**
Evidence without which the objective cannot be answered.

**Strengthening Evidence**
Additional evidence that increases confidence.

**Evidence Already Available**
Evidence from prior analyses or existing data.

**Evidence Still Missing**
Evidence that must be obtained to answer the objective.

## Evidence Gap Analysis

The core reasoning question:

"What evidence is still missing before I can answer the scientific objective?"

The skill must continuously ask this question throughout the workflow.

## Evidence Sufficiency Rule

Before selecting additional evidence producers, ask:

"Would obtaining additional evidence materially change the scientific conclusion?"

If the answer is NO:
- Stop requesting analyses
- Do NOT maximize the number of analyses
- Maximize the quality and sufficiency of evidence
- Avoid unnecessary computational work

## Evidence Prioritisation

When multiple types of missing evidence exist:

1. Required evidence first
2. Strengthening evidence second
3. Avoid redundant evidence

## Evidence Integration

When combining evidence:

- All evidence agrees → high confidence
- Most evidence agrees → medium confidence
- Evidence disagrees → report discrepancy, low confidence
- Insufficient evidence → state limitation

## Confidence Assignment

Confidence comes from:
- Number of independent evidence sources agreeing
- Quality of each evidence source
- Appropriateness for the scientific question
- Limitations of the data

## Decision Rules

- If required evidence cannot be obtained → state limitation
- If evidence sources disagree → report discrepancy
- If confidence is low → recommend additional evidence
- If question is beyond scope → state honestly

---

# Part 2: Evidence Producers

## RMSD Calculation

### Scientific Objective
Determine whether the production trajectory has structurally converged by measuring backbone RMSD over time.

### Scientific Meaning
Root mean square deviation (RMSD) measures the average displacement of atoms from a reference structure. For proteins, backbone RMSD is calculated after fitting the backbone atoms to the reference. Low, stable RMSD indicates the structure is maintaining its fold. Rising RMSD may indicate conformational change or instability.

Formula: RMSD(t) = sqrt(1/M * Σ mi ||ri(t) - ri(0)||²)

### When to Use
When the scientific objective requires evidence of global structural stability, structural convergence, or structural drift.

### Required Inputs
- Trajectory file (must be PBC-corrected and centered)
- Structure file (TPR or GRO)
- Reference structure (usually the first frame or initial structure)

### Required Trajectory State
Prepared (PBC-corrected, centered on protein). Use `post/prepare.sh` if trajectory is raw.

### Interactive Selections
When using gmx rms, two selections are required:

1. "Select group for least-squares fitting" → Backbone
2. "Select group for RMSD calculation" → Backbone

### Expected Outputs
- `.xvg` file with two columns: time (ps) and RMSD (nm)
- File should be non-empty, have monotonic time column, no NaN values

### Output Validation
- Output file exists and is non-empty
- First column is time (increasing)
- Second column is RMSD (non-negative)
- Time range covers the production period

### Repository Prerequisites

**Required:**
- Prepared trajectory (post/prepare.sh)

**Optional:**
- Existing index groups

### Primary Evidence Produced
- Global structural stability
- Structural convergence
- Structural drift from reference

### Secondary Evidence Produced
- Large conformational transitions
- Simulation stability indicators

### Evidence Not Produced
- Local flexibility
- Binding affinity
- Interface stability

### Complementary Evidence
- RMSF: Per-residue flexibility
- Radius of Gyration: Compactness
- Hydrogen Bonds: Secondary structure stability

### Confidence Contribution
- High when combined with Rg and RMSF
- Medium alone (only shows global deviation)

### Appropriate Use
- Assessing structural stability
- Detecting conformational changes
- Evaluating simulation convergence

### Limitations
- Does not capture local dynamics
- Requires prepared trajectory
- Reference structure must be appropriate

### Operational Pitfalls

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

### Scientific Interpretation

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

### Decision Rules

- If RMSD is still rising at end → recommend extending simulation
- If RMSD has plateaued → structure appears equilibrated
- If RMSD has sudden jumps → investigate for artifacts or transitions
- If trajectory not prepared → stop, prepare trajectory first

### Evidence Confidence

**Repository verified:** ✅ Trajectory preparation exists (post/prepare.sh)
**Official documentation verified:** ✅ gmx rms documented in GROMACS manual
**Scientific literature verified:** ✅ RMSD is well-established structural measure
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

### Verification Checklist

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

### Remaining Uncertainty
- Only captures global structural deviation
- Does not distinguish between different types of structural change
- Reference structure choice affects absolute values

### References
- Official: https://manual.gromacs.org/current/onlinehelp/gmx-rms.html
- Literature: GROMACS reference manual, eq. 461

---

## RMSF Calculation

### Scientific Objective
Determine whether specific regions of the structure have changed their flexibility patterns.

### Scientific Meaning
Root mean square fluctuation (RMSF) measures the average displacement of each residue from its mean position. High RMSF indicates flexible regions (loops, termini). Low RMSF indicates rigid regions (helices, sheets, core).

Formula: RMSF(i) = sqrt(||ri - <ri>||²)

### When to Use
When the scientific objective requires evidence of per-residue flexibility, flexible regions, or dynamics comparison.

### Required Inputs
- Trajectory file (must be PBC-corrected and centered)
- Structure file (TPR or GRO)

### Required Trajectory State
Prepared (PBC-corrected, centered on protein).

### Interactive Selections
When using gmx rmsf, one selection is required:

1. "Select group for calculation" → Backbone (or Protein)

### Expected Outputs
- `.xvg` file with two columns: residue number and RMSF (nm)
- File should be non-empty

### Output Validation
- Output file exists and is non-empty
- First column is residue number (integer)
- Second column is RMSF (non-negative)

### Repository Prerequisites

**Required:**
- Prepared trajectory (post/prepare.sh)

**Optional:**
- Existing index groups

### Primary Evidence Produced
- Per-residue flexibility
- Identification of flexible regions
- Comparison of dynamics between systems

### Secondary Evidence Produced
- Secondary structure stability indicators
- Loop dynamics

### Evidence Not Produced
- Global structural stability
- Compactness
- Specific interactions

### Complementary Evidence
- RMSD: Global stability context
- DSSP: Secondary structure changes
- Hydrogen Bonds: Interaction stability

### Confidence Contribution
- High for flexibility questions
- Medium for stability assessment (local only)

### Appropriate Use
- Identifying flexible loops
- Comparing wild-type vs mutant dynamics
- Assessing secondary structure flexibility

### Limitations
- Does not capture global stability
- Terminal residues often noisy
- Requires adequate sampling

### Operational Pitfalls

**Selection pitfalls:**
- Using all atoms → noisier than backbone-only
- Including terminal residues → artificially high RMSF

**Interpretation pitfalls:**
- Confusing high RMSF with instability → loops are naturally flexible
- Ignoring crystallographic B-factors → different measurement

### Scientific Interpretation

**What to look for:**
- High RMSF in loops → normal flexibility
- High RMSF in helices → possible instability
- Low RMSF in core → expected rigidity

**Common misinterpretations:**
- "High RMSF means unfolding" → loops are naturally flexible
- "Low RMSF means stable" → low RMSF in core is expected

**When conclusions are justified:**
- RMSF profile matches expected secondary structure → simulation is reasonable
- Unexpectedly high RMSF in structured regions → investigate for instability

**When conclusions should NOT be drawn:**
- Single residue has high RMSF → may be natural flexibility
- RMSF is slightly different from crystal structure → different conditions

### Decision Rules

- If RMSF is unexpectedly high in structured regions → investigate for instability
- If RMSF profile matches expected structure → simulation appears reasonable
- If trajectory not prepared → stop, prepare trajectory first

### Evidence Confidence

**Repository verified:** ✅ Trajectory preparation exists (post/prepare.sh)
**Official documentation verified:** ✅ gmx rmsf documented in GROMACS manual
**Scientific literature verified:** ✅ RMSF is well-established flexibility measure
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

### Verification Checklist

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

### Remaining Uncertainty
- Only captures local flexibility, not global stability
- Terminal residues often noisy
- Comparison to crystal structure requires careful interpretation

### References
- Official: https://manual.gromacs.org/current/onlinehelp/gmx-rmsf.html

---

## Radius of Gyration Calculation

### Scientific Objective
Determine whether the protein maintains its compact structure throughout the simulation.

### Scientific Meaning
Radius of gyration (Rg) measures the mass-weighted root mean square distance of atoms from the center of mass. It provides a single number characterizing the compactness of the structure. Stable Rg indicates the protein maintains its fold. Increasing Rg may indicate unfolding or expansion.

Formula: Rg = sqrt(Σ mi ||ri||² / Σ mi)

### When to Use
When the scientific objective requires evidence of structural compactness, unfolding, or large conformational changes.

### Required Inputs
- Trajectory file (must be PBC-corrected and centered)
- Structure file (TPR or GRO)

### Required Trajectory State
Prepared (PBC-corrected, centered on protein).

### Interactive Selections
When using gmx gyrate, one selection is required:

1. "Select group for calculation" → Protein (or Backbone)

### Expected Outputs
- `.xvg` file with columns: time (ps), Rg (nm), and optionally Rg.x, Rg.y, Rg.z
- File should be non-empty

### Output Validation
- Output file exists and is non-empty
- First column is time (increasing)
- Second column is Rg (positive values)

### Repository Prerequisites

**Required:**
- Prepared trajectory (post/prepare.sh)

**Optional:**
- Existing index groups

### Primary Evidence Produced
- Structural compactness
- Unfolding detection
- Large conformational changes

### Secondary Evidence Produced
- Simulation stability indicators
- Box size appropriateness

### Evidence Not Produced
- Local flexibility
- Specific interactions
- Atomic-level detail

### Complementary Evidence
- RMSD: Structural deviation context
- RMSF: Per-residue flexibility
- DSSP: Secondary structure changes

### Confidence Contribution
- High for compactness questions
- Medium for stability assessment (global only)

### Appropriate Use
- Assessing protein compactness
- Detecting unfolding events
- Monitoring large conformational changes

### Limitations
- Does not capture local structural changes
- Global measure, not residue-specific
- Different proteins have different expected Rg ranges

### Operational Pitfalls

**Selection pitfalls:**
- Including water → Rg dominated by solvent
- Excluding part of protein → artificially low Rg

**Interpretation pitfalls:**
- Small Rg change = no problem → depends on system size
- Rg increase = unfolding → could be conformational change

### Scientific Interpretation

**What to look for:**
- Stable Rg → protein maintains compact structure
- Monotonic Rg increase → possible unfolding or expansion
- Rg fluctuations → normal breathing motions

**Common misinterpretations:**
- "Rg > X means unfolding" → depends on protein size and expected Rg
- "Rg is constant means stable" → Rg can be constant while internal structure changes

**When conclusions are justified:**
- Rg is stable and matches expected value → structure is compact
- Rg is increasing without plateau → possible unfolding

**When conclusions should NOT be drawn:**
- Rg has small fluctuations → fluctuations are normal
- Rg is different from crystal structure → solution conditions differ

### Decision Rules

- If Rg is monotonically increasing → investigate for unfolding
- If Rg is stable → structure appears compact
- If trajectory not prepared → stop, prepare trajectory first

### Evidence Confidence

**Repository verified:** ✅ Trajectory preparation exists (post/prepare.sh)
**Official documentation verified:** ✅ gmx gyrate documented in GROMACS manual
**Scientific literature verified:** ✅ Rg is well-established compactness measure
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

### Verification Checklist

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

### Remaining Uncertainty
- Global measure, does not capture local structural changes
- Different proteins have different expected Rg ranges
- Does not distinguish between different types of expansion

### References
- Official: https://manual.gromacs.org/current/onlinehelp/gmx-gyrate.html
- Literature: GROMACS reference manual, eq. 459-460

---

## Energy Extraction & Stability Assessment

### Scientific Objective
Determine whether the simulation maintained correct temperature, pressure, and energy stability throughout production.

### Scientific Meaning
The energy file (md.edr) contains time-series data for temperature, pressure, total energy, potential energy, kinetic energy, volume, and density. These quantities should fluctuate around their reference values without systematic drift.

### When to Use
When the scientific objective requires evidence of simulation health, thermodynamic stability, or production quality.

### Required Inputs
- `md.edr` — energy file from production
- `md.tpr` — for reference values

### Required Trajectory State
Not applicable (energy file is independent of trajectory).

### Interactive Selections
When using gmx energy, select the relevant thermodynamic quantities.

### Expected Outputs
- `.xvg` file with columns: time and selected energy terms
- File should be non-empty with monotonic time column

### Output Validation
- Output file exists and is non-empty
- First column is time (increasing)
- Selected columns contain numeric values (no NaN)

### Repository Prerequisites

**Required:**
- Production completed with energy file output

**Optional:**
- None

### Primary Evidence Produced
- Temperature stability
- Pressure stability
- Energy conservation
- Simulation health

### Secondary Evidence Produced
- Thermostat functioning
- Barostat functioning
- Integrator stability

### Evidence Not Produced
- Structural stability
- Convergence
- Binding affinity

### Complementary Evidence
- RMSD: Structural stability
- Rg: Compactness

### Confidence Contribution
- High for simulation health assessment
- Low for structural conclusions

### Appropriate Use
- Assessing simulation quality
- Verifying thermostat/barostat function
- Detecting energy drift

### Limitations
- Does not indicate structural stability
- Pressure fluctuations are normal in NPT
- Energy drift may be acceptable depending on magnitude

### Operational Pitfalls

**Selection pitfalls:**
- Selecting wrong energy term → misleading assessment
- Not selecting enough terms → incomplete picture

**Interpretation pitfalls:**
- Confusing equilibration drift with production drift → only assess production portion
- Ignoring short-term fluctuations → fluctuations are normal

### Scientific Interpretation

**What to look for:**
- Temperature fluctuating around 300 K without systematic drift
- Pressure fluctuating around 1 bar with reasonable amplitude
- Total energy showing minimal drift

**Common misinterpretations:**
- "Pressure fluctuations are too large" → large fluctuations are normal in NPT
- "Energy is not conserved" → some drift is expected in NPT

**When conclusions are justified:**
- Temperature average is within 5 K of reference → thermostat is working
- Pressure average is within 50 bar of reference → barostat is working

**When conclusions should NOT be drawn:**
- Pressure is noisy → noise is normal, look for systematic drift only
- Energy has short-term fluctuations → fluctuations are expected

### Decision Rules

- If temperature drift > 10 K → investigate thermostat settings
- If pressure drift > 50 bar → investigate barostat settings
- If energy drift is large and non-linear → investigate integrator

### Evidence Confidence

**Repository verified:** ✅ Energy file is standard GROMACS output
**Official documentation verified:** ✅ gmx energy documented in GROMACS manual
**Scientific literature verified:** ✅ Energy stability is well-established physics
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

### Verification Checklist

**Before execution:**
- [ ] Production completed
- [ ] md.edr exists and is non-empty
- [ ] md.tpr exists
- [ ] Compatible GROMACS version installed

**After execution:**
- [ ] Output file created
- [ ] Output file readable
- [ ] Expected columns present
- [ ] No parsing errors

**Ready for interpretation:**
YES / NO

### Remaining Uncertainty
- Energy stability does not indicate structural stability
- Normal NPT fluctuations may look alarming to inexperienced users
- Acceptable drift thresholds are system-dependent

### References
- Official: https://manual.gromacs.org/current/onlinehelp/gmx-energy.html
- Literature: Allen & Tildesley, "Computer Simulation of Liquids"

---

## Hydrogen Bond Analysis

### Scientific Objective
Determine whether hydrogen bonds that maintain secondary structure or mediate protein-DNA interactions are stable.

### Scientific Meaning
Hydrogen bonds are electrostatic interactions between a hydrogen bond donor and acceptor. In proteins, hydrogen bonds stabilize alpha-helices and beta-sheets. In protein-DNA complexes, hydrogen bonds mediate specific recognition. Occupancy measures the fraction of time a hydrogen bond exists.

### When to Use
When the scientific objective requires evidence of secondary structure stability, protein-DNA interactions, or binding interface integrity.

### Required Inputs
- Trajectory file (must be PBC-corrected and centered)
- Structure file (TPR or GRO)

### Required Trajectory State
Prepared (PBC-corrected, centered on protein).

### Interactive Selections
When using gmx hbond, two selections are required:

1. "Select group for donor" → Protein (or Protein_DNA)
2. "Select group for acceptor" → DNA (or Water)

### Expected Outputs
- `.xvg` file with hydrogen bond count over time
- `.dat` file with hydrogen bond occupancy

### Output Validation
- Output files exist and are non-empty
- Occupancy values are between 0 and 1

### Repository Prerequisites

**Required:**
- Prepared trajectory (post/prepare.sh)

**Optional:**
- Existing index groups for protein and DNA

### Primary Evidence Produced
- Secondary structure stability
- Protein-DNA interaction stability
- Binding interface integrity

### Secondary Evidence Produced
- Conformational changes at interface
- Solvent accessibility changes

### Evidence Not Produced
- Global structural stability
- Local flexibility
- Binding affinity

### Complementary Evidence
- RMSD: Global structural context
- RMSF: Per-residue flexibility
- DSSP: Secondary structure assignment

### Confidence Contribution
- High for interaction stability questions
- Medium for structural stability (local evidence only)

### Appropriate Use
- Assessing secondary structure stability
- Evaluating protein-DNA interactions
- Monitoring binding interface integrity

### Limitations
- Hydrogen bond detection depends on geometry criteria
- Different GROMACS versions may use slightly different criteria
- Occupancy is averaged over trajectory, not instantaneous

### Operational Pitfalls

**Selection pitfalls:**
- Wrong groups selected → analyzing wrong hydrogen bonds
- Including water → hydrogen bonds with solvent dominate

**Interpretation pitfalls:**
- High occupancy always means stable → depends on hydrogen bond type
- Low occupancy always means unstable → some hydrogen bonds are transient

### Scientific Interpretation

**What to look for:**
- High occupancy hydrogen bonds in secondary structure → structure is stable
- Low occupancy hydrogen bonds in protein-DNA interface → interactions may be weak
- Changing hydrogen bond patterns → conformational change

**When conclusions are justified:**
- Secondary structure hydrogen bonds are stable → fold is maintained
- Protein-DNA hydrogen bonds are stable → complex is stable

**When conclusions should NOT be drawn:**
- Single hydrogen bond has low occupancy → may be transient by design
- Hydrogen bond pattern differs from crystal structure → solution conditions differ

### Decision Rules

- If secondary structure hydrogen bonds are stable → fold appears maintained
- If protein-DNA hydrogen bonds are stable → complex appears stable
- If no hydrogen bonds found → check selection groups

### Evidence Confidence

**Repository verified:** ✅ Trajectory preparation exists (post/prepare.sh)
**Official documentation verified:** ✅ gmx hbond documented in GROMACS manual
**Scientific literature verified:** ✅ Hydrogen bonds are well-established interaction measure
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

### Verification Checklist

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

### Remaining Uncertainty
- Detection depends on geometric criteria
- Does not capture all types of interactions
- Occupancy is time-averaged, not instantaneous

### References
- Official: https://manual.gromacs.org/current/onlinehelp/gmx-hbond.html

---

## Secondary Structure Analysis (DSSP)

### Scientific Objective
Determine whether secondary structure elements (helices, sheets) are maintained throughout the simulation.

### Scientific Meaning
DSSP (Dictionary of Secondary Structure of Proteins) assigns secondary structure based on hydrogen bonding patterns. Alpha-helices, beta-sheets, turns, and coils are identified for each residue at each frame. Changes in secondary structure content indicate structural rearrangement.

### When to Use
When the scientific objective requires evidence of secondary structure stability, unfolding, or structural rearrangement.

### Required Inputs
- Trajectory file (must be PBC-corrected and centered)
- Structure file (TPR or GRO)

### Required Trajectory State
Prepared (PBC-corrected, centered on protein).

### Interactive Selections
When using gmx dssp, one selection is required:

1. "Select group for calculation" → Protein

### Expected Outputs
- `.xvg` file with secondary structure assignments over time

### Output Validation
- Output file exists and is non-empty
- Contains valid secondary structure assignments (H, B, E, G, T, S, C)

### Repository Prerequisites

**Required:**
- Prepared trajectory (post/prepare.sh)

**Optional:**
- DSSP binary available

### Primary Evidence Produced
- Secondary structure stability
- Helix/sheet content changes
- Structural rearrangement detection

### Secondary Evidence Produced
- Folding/unfolding events
- Secondary structure transitions

### Evidence Not Produced
- Global structural stability
- Local flexibility
- Specific interactions

### Complementary Evidence
- RMSD: Global structural context
- RMSF: Per-residue flexibility
- Hydrogen Bonds: Interaction stability

### Confidence Contribution
- High for secondary structure questions
- Medium for structural stability (specific to secondary structure)

### Appropriate Use
- Assessing secondary structure maintenance
- Detecting helix/sheet unfolding
- Monitoring structural rearrangements

### Limitations
- DSSP assignment depends on hydrogen bonding criteria
- Different DSSP implementations may differ slightly
- Terminal residues often have irregular assignments

### Operational Pitfalls

**Selection pitfalls:**
- Including non-protein atoms → DSSP only works for proteins
- Wrong group selected → analyzing wrong residues

**Interpretation pitfalls:**
- Small changes in helix count → normal breathing motions
- Complete loss of secondary structure → possible unfolding

### Scientific Interpretation

**What to look for:**
- Stable helix and sheet counts → secondary structure is maintained
- Decreasing helix content → possible unfolding
- Increasing sheet content → possible aggregation

**When conclusions are justified:**
- Secondary structure content is stable → fold is maintained
- Significant loss of secondary structure → possible unfolding

**When conclusions should NOT be drawn:**
- Single frame shows different assignment → transient fluctuation
- DSSP differs slightly from PDB assignment → different hydrogen bond criteria

### Decision Rules

- If secondary structure is stable → fold appears maintained
- If significant loss of helices → investigate for unfolding
- If DSSP fails → check DSSP installation and version

### Evidence Confidence

**Repository verified:** ✅ Trajectory preparation exists (post/prepare.sh)
**Official documentation verified:** ✅ gmx dssp documented in GROMACS manual
**Scientific literature verified:** ✅ DSSP is standard secondary structure assignment
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

### Verification Checklist

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

### Remaining Uncertainty
- Assignment depends on hydrogen bonding criteria
- Different DSSP implementations may differ
- Terminal residues often irregular

### References
- Official: https://manual.gromacs.org/current/onlinehelp/gmx-dssp.html
- Literature: Kabsch & Sander, "Dictionary of Protein Secondary Structure"

---

## COM Distance Calculation

### Scientific Objective
Determine whether the distance between two groups (e.g., protein and DNA) remains stable, indicating complex integrity.

### Scientific Meaning
Center of mass (COM) distance measures the separation between two groups of atoms. For protein-DNA complexes, this indicates whether the protein remains bound to DNA. Stable distance suggests a stable complex. Increasing distance may indicate dissociation.

### When to Use
When the scientific objective requires evidence of complex stability, binding integrity, or molecular separation.

### Required Inputs
- Trajectory file (must be PBC-corrected and centered)
- Structure file (TPR or GRO)
- Index file with groups for the two molecules

### Required Trajectory State
Prepared (PBC-corrected, centered on complex).

### Interactive Selections
When using gmx distance, two selections are required:

1. "Select two groups" → Protein, DNA (or Protein, Ligand)

### Expected Outputs
- `.xvg` file with distance (nm) over time

### Output Validation
- Output file exists and is non-empty
- Distance values are non-negative

### Repository Prerequisites

**Required:**
- Prepared trajectory (post/prepare.sh)
- Index file with appropriate groups

**Optional:**
- None

### Primary Evidence Produced
- Complex stability
- Binding integrity
- Molecular separation

### Secondary Evidence Produced
- Dissociation detection
- Conformational changes affecting distance

### Evidence Not Produced
- Specific interactions
- Local flexibility
- Energetics of binding

### Complementary Evidence
- Hydrogen Bonds: Specific interactions at interface
- RMSD: Structural context
- Contacts: Interface-specific interactions

### Confidence Contribution
- High for complex stability questions
- Medium for binding assessment (distance alone)

### Appropriate Use
- Assessing protein-DNA complex stability
- Monitoring protein-ligand distance
- Detecting dissociation events

### Limitations
- COM distance is a global measure
- Does not capture specific interactions
- PBC corrections are essential

### Operational Pitfalls

**Selection pitfalls:**
- Wrong groups selected → measuring wrong distance
- PBC artifacts → distance jumps between periodic images

**Interpretation pitfalls:**
- Distance increase always means dissociation → could be conformational change
- Distance fluctuation is problem → fluctuations are normal

### Scientific Interpretation

**What to look for:**
- Stable distance → complex appears stable
- Increasing distance → possible dissociation
- Distance jumps → PBC artifact or conformational change

**When conclusions are justified:**
- Distance is stable and matches expected binding → complex appears stable
- Distance is increasing without plateau → possible dissociation

**When conclusions should NOT be drawn:**
- Distance has small fluctuations → fluctuations are normal
- Distance differs from crystal structure → solution conditions differ

### Decision Rules

- If distance is stable → complex appears stable
- If distance is increasing → investigate for dissociation
- If trajectory not prepared → stop, prepare trajectory first

### Evidence Confidence

**Repository verified:** ✅ Trajectory preparation exists (post/prepare.sh)
**Official documentation verified:** ✅ gmx distance documented in GROMACS manual
**Scientific literature verified:** ✅ COM distance is standard interaction measure
**HPC verified:** ✅ Successfully ran on IITD HPC
**Production verified:** ✅ Ran on BLM-cMYC 1ns production data
**Overall confidence:** High

### Verification Checklist

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

### Remaining Uncertainty
- Does not capture specific interactions
- Global measure, not residue-specific
- PBC corrections essential for accuracy

### References
- Official: https://manual.gromacs.org/current/onlinehelp/gmx-distance.html

---

# Part 3: Evidence Synthesis

## Structural Stability

### Scientific Objective
Determine whether the protein maintains its structural fold.

### Working Hypothesis
The protein maintains its structural fold.

### Required Evidence
- RMSD plateau
- Stable Radius of Gyration

### Supporting Evidence
- Stable Hydrogen Bonds
- Stable DSSP assignments
- Normal RMSF patterns

### Conflicting Evidence
- Increasing RMSF
- Loss of secondary structure
- Increasing Rg

### Evidence Quality Checks
- Is the trajectory long enough for stability assessment?
- Has the simulation converged?
- Is the reference structure appropriate?

### Confidence Rules
- High: Required + supporting evidence all agree
- Medium: Required evidence agrees, some supporting missing
- Low: Required evidence disagrees or insufficient

### Scientific Conclusion
When all required evidence indicates stability, the structure has maintained its fold. Supporting evidence increases confidence. Conflicting evidence requires investigation.

### Remaining Uncertainty
- Stability assessment depends on trajectory length
- Different proteins have different stability expectations
- Local instability may not affect global metrics

---

## Convergence

### Scientific Objective
Determine whether the simulation has reached equilibrium.

### Working Hypothesis
The system has reached equilibrium.

### Required Evidence
- RMSD plateau
- Stable Radius of Gyration
- Stable energy

### Supporting Evidence
- Stable temperature and pressure
- No systematic drift

### Conflicting Evidence
- RMSD still rising
- Rg still changing
- Energy drift

### Evidence Quality Checks
- Is the trajectory long enough?
- Are the production parameters appropriate?
- Is the system size adequate?

### Confidence Rules
- High: All required evidence converged
- Medium: Most evidence converged
- Low: Evidence still changing

### Scientific Conclusion
When all metrics have plateaued, the simulation has reached equilibrium. Partial convergence suggests more sampling needed.

### Remaining Uncertainty
- Convergence depends on the timescale of interest
- Some properties converge faster than others
- Local convergence may differ from global convergence

---

## Binding Stability

### Scientific Objective
Determine whether a molecular complex remains intact.

### Working Hypothesis
The complex remains intact.

### Required Evidence
- Stable COM distance
- Stable interface hydrogen bonds

### Supporting Evidence
- Stable contact map
- No significant RMSD change at interface

### Conflicting Evidence
- Increasing COM distance
- Loss of hydrogen bonds
- Changing contacts

### Evidence Quality Checks
- Is the trajectory long enough for binding assessment?
- Are the interface interactions adequately sampled?
- Is the reference structure appropriate?

### Confidence Rules
- High: All interface evidence stable
- Medium: Some interface evidence stable
- Low: Interface evidence changing

### Scientific Conclusion
When distance and interactions remain stable, the complex is maintained. Changes in interface evidence suggest weakened binding.

### Remaining Uncertainty
- Binding stability depends on timescale
- Some transient changes are normal
- Does not quantify binding affinity

---

## Flexibility Assessment

### Scientific Objective
Determine which regions of the structure are flexible or rigid.

### Working Hypothesis
The structure has expected flexibility patterns.

### Required Evidence
- RMSF profile

### Supporting Evidence
- DSSP changes
- Hydrogen bond fluctuations

### Conflicting Evidence
- Unexpectedly high RMSF in structured regions
- Loss of secondary structure in flexible regions

### Evidence Quality Checks
- Is the trajectory long enough for flexibility assessment?
- Has the simulation converged?
- Is the RMSF calculated over adequate frames?

### Confidence Rules
- High: RMSF matches expected patterns
- Medium: RMSF mostly matches with minor deviations
- Low: RMSF shows unexpected patterns

### Scientific Conclusion
When RMSF matches expected flexibility patterns, the dynamics are reasonable. Unexpected patterns require investigation.

### Remaining Uncertainty
- Flexibility depends on the timescale of observation
- Crystal structure comparisons may differ
- Terminal residues often noisy

---

## Simulation Quality

### Scientific Objective
Determine whether the simulation is scientifically valid.

### Working Hypothesis
The simulation is scientifically valid.

### Required Evidence
- Temperature stability
- Pressure stability
- Energy stability

### Supporting Evidence
- Structural stability
- No artifacts

### Conflicting Evidence
- Temperature drift
- Pressure drift
- Energy drift
- Structural instability

### Evidence Quality Checks
- Are the MDP parameters appropriate?
- Is the force field suitable?
- Are the resource settings adequate?

### Confidence Rules
- High: All stability metrics normal
- Medium: Minor deviations but acceptable
- Low: Significant deviations from expected values

### Scientific Conclusion
When all stability metrics are within acceptable ranges, the simulation is scientifically valid. Deviations require investigation.

### Remaining Uncertainty
- "Acceptable" ranges depend on system and force field
- Some drift may be acceptable depending on magnitude
- Quality does not guarantee scientific relevance
