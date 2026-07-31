# =============================================================================
# GROMACS HPC Pipeline — Project Configuration
# =============================================================================
# This file defines everything about ONE simulation. Edit it for each project.
# Every line below explains WHAT the setting does, so you can change it safely.

# ⚠️ DO NOT TOUCH these unless you understand the consequence:
#   - EQ_GPUS / PROD_GPUS must be >= 1 (equilibration and production are GPU runs)
#   - BOX_DISTANCE too small → simulation blows up (unstable density)
#   - CHUNK_NS must divide PRODUCTION_NS evenly (chunking arithmetic)
#   - FORCEFIELD / WATER_MODEL / CATION / ANION must match the installed
#     force field — a mismatch causes pdb2gmx/genion failures

# ── Cluster Profile ─────────────────────────────────────────────────────────
# CLUSTER selects which scheduler profile to use (profiles/<name>.sh).
# This determines the queue commands (PBS/Slurm/LSF) for your cluster.
CLUSTER="generic-pbs"
# PROJECT is just a label shown in status/reports. It does NOT need to match
# the folder name. Use something descriptive like "blm_kras_rep1".
PROJECT="my_project"

# ── Input Files ─────────────────────────────────────────────────────────────
# PDB is the ONLY required structure input. The pipeline expects this file to
# already be prepared (correct chains, no water, GROMACS-compatible residues).
PDB="input/system.pdb"
# The four MDP files define HOW each stage runs (physics parameters).
# The pipeline ships validated defaults in mdp/; leave these as-is unless you
# need to override them for a specific project.
EM_MDP="mdp/em.mdp"        # energy minimization
NVT_MDP="mdp/nvt.mdp"      # temperature equilibration
NPT_MDP="mdp/npt.mdp"      # pressure equilibration
MD_MDP="mdp/md.mdp"        # production run
# EXTRA_ITPS: additional .itp topology files to include, space-separated.
# Used only if you add custom molecules/ligands not handled by pdb2gmx.
EXTRA_ITPS=""

# ── System (chemistry) ──────────────────────────────────────────────────────
# FORCEFIELD is the physics model (e.g. amber99sb-ildn, amber14sb).
#   - MUST be installed first: bash forcefields/get-ff.sh install <name>
#   - MUST support the residues in your structure (protein + DNA/RNA + ions)
# Changing this changes the physics — pick once, keep for all replicates.
FORCEFIELD=""
# WATER_MODEL is the explicit water model. Must be available in the force field.
# spce is standard and pairs with the Amber force fields.
WATER_MODEL="spce"
# BOX_TYPE is the simulation cell shape. dodecahedron is optimal for roughly
# spherical solutes (fewest water molecules). cubic is simpler but uses more water.
BOX_TYPE="dodecahedron"
# BOX_DISTANCE (nm) = minimum clearance between the solute and the box edge.
#   1.0 is standard. ⚠️ Below ~0.8 the solute interacts with its periodic
#   images → pressure instability / blowup. Larger = more water = slower.
BOX_DISTANCE="1.0"
# SALT_CONC (M) = concentration of free salt (K+/Cl-) added to match
# physiological ionic strength. 0 = add only enough ions to neutralize charge.
SALT_CONC="0.15"
# CATION / ANION = the ion species added by genion. MUST exist in the force
# field (amber99sb-ildn includes K+, Cl-, Na+, etc.).
CATION="K"
ANION="CL"

# ── Simulation Length ───────────────────────────────────────────────────────
# PRODUCTION_NS = total production time (ns). This is the "science" length.
PRODUCTION_NS=100
# CHUNK_NS = length of ONE submitted production job (ns). The run is split
# into PRODUCTION_NS / CHUNK_NS sequential jobs, each resuming from checkpoint.
#   ⚠️ CHUNK_NS MUST divide PRODUCTION_NS evenly.
#   Smaller chunk = more resume points (safer) but more queue waits (slower).
#   Rule of thumb: chunk = how much production fits in PROD_WALLTIME.
CHUNK_NS=50

# ── Resources (hardware request per job) ────────────────────────────────────
# These control how much CPU/GPU/memory/walltime each PBS job asks for.
# SETUP is CPU-only (structure prep + solvation + ions + index).
SETUP_CPUS=8             # CPU cores for setup
SETUP_MEM="8GB"          # memory for setup
SETUP_WALLTIME="00:30:00"  # max walltime for setup (HH:MM:SS)

# EQUILIBRATION runs EM + NVT + NPT on a GPU.
EQ_CPUS=8                # CPU threads for equilibration
EQ_GPUS=1                # ⚠️ MUST be >= 1 — equilibration requires a GPU
EQ_MEM="16GB"
EQ_WALLTIME="02:00:00"   # must fit EM+NVT+NPT (usually 1-2 h)

# PRODUCTION runs the long MD on a GPU.
PROD_CPUS=8              # CPU threads for production
PROD_GPUS=1              # ⚠️ MUST be >= 1 — production requires a GPU
PROD_MEM="16GB"
# PROD_WALLTIME = walltime per chunk. Each chunk runs ~90% of this, writes a
# checkpoint, and stops. Must fit the cluster's max job walltime.
PROD_WALLTIME="24:00:00"

# ── Scheduler ───────────────────────────────────────────────────────────────
# ACCOUNT = the PBS project used for billing/quotas (e.g. helicases.spons).
ACCOUNT="my_account"
# QUEUE = scheduler queue. On IITD: standard (default) or high (faster scheduling).
QUEUE="standard"
