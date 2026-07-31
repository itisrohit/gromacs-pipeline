# GROMACS HPC Pipeline Configuration
# Edit this file for each project.

# ⚠️ DO NOT TOUCH these unless you understand the consequence:
#   - EQ_GPUS / PROD_GPUS must be >= 1 (equilibration and production are GPU runs)
#   - BOX_DISTANCE too small → simulation blows up (unstable density)
#   - CHUNK_NS must divide PRODUCTION_NS evenly (chunking arithmetic)
#   - FORCEFIELD / WATER_MODEL / CATION / ANION must match the installed
#     force field — a mismatch causes pdb2gmx/genion failures

# ── Cluster Profile ──
CLUSTER="generic-pbs"        # must match profiles/<name>.sh on the cluster
PROJECT="my_project"         # display name for this simulation

# ── Input Files ──
PDB="input/system.pdb"       # the only required structure input
EM_MDP="mdp/em.mdp"          # leave as-is unless overriding MDPs per project
NVT_MDP="mdp/nvt.mdp"
NPT_MDP="mdp/npt.mdp"
MD_MDP="mdp/md.mdp"
EXTRA_ITPS=""                # optional: custom topology includes (space-separated)

# ── System ──
FORCEFIELD=""                # REQUIRED: e.g. amber99sb-ildn, amber14sb
                             # MUST be installed (get-ff.sh install <name>)
                             # MUST be compatible with your structure's residues
WATER_MODEL="spce"           # MUST be available in the chosen force field
BOX_TYPE="dodecahedron"      # dodecahedron is optimal for spherical solutes
BOX_DISTANCE="1.0"           # ⚠️ too small (< 0.8) → pressure instability / blowup
SALT_CONC="0.15"             # salt concentration (M); 0 = neutralization only
CATION="K"                   # MUST exist in the force field ion parameters
ANION="CL"                   # MUST exist in the force field ion parameters

# ── Simulation Length ──
PRODUCTION_NS=100            # total production time (ns)
CHUNK_NS=50                  # per-chunk (ns). ⚠️ must divide PRODUCTION_NS evenly.
                             # Smaller chunk = more resume points, more queue waits.

# ── Resources ──
SETUP_CPUS=8                 # setup is CPU-only
SETUP_MEM="8GB"
SETUP_WALLTIME="00:30:00"
EQ_CPUS=8                    # CPU threads for equilibration
EQ_GPUS=1                    # ⚠️ DO NOT set to 0 — equilibration requires a GPU
EQ_MEM="16GB"
EQ_WALLTIME="02:00:00"
PROD_CPUS=8                  # CPU threads for production
PROD_GPUS=1                  # ⚠️ DO NOT set to 0 — production requires a GPU
PROD_MEM="16GB"
PROD_WALLTIME="24:00:00"     # per chunk; must fit the cluster's max walltime.
                             # Production runs ~90% of this then checkpoints.

# ── Scheduler ──
ACCOUNT="my_account"         # PBS project for billing (e.g. helicases.spons)
QUEUE="standard"             # scheduler queue (standard / high on IITD)
