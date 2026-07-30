# GROMACS HPC Pipeline Configuration
# BLM-cMYC 1ns test run

CLUSTER="iitd"
PROJECT="BLM-cMYC"

# ── Input Files ──
PDB="input/system.pdb"
EM_MDP="mdp/em.mdp"
NVT_MDP="mdp/nvt.mdp"
NPT_MDP="mdp/npt.mdp"
MD_MDP="mdp/md.mdp"
EXTRA_ITPS=""

# ── System ──
FORCEFIELD="amber14sb"
WATER_MODEL="spce"
BOX_TYPE="dodecahedron"
BOX_DISTANCE="1.0"
SALT_CONC="0.15"
CATION="K"
ANION="CL"

# ── Simulation Length ──
PRODUCTION_NS=1
CHUNK_NS=1

# ── Resources ──
SETUP_CPUS=8
SETUP_MEM="4GB"
SETUP_WALLTIME="00:30:00"
EQ_CPUS=8
EQ_GPUS=1
EQ_MEM="8GB"
EQ_WALLTIME="02:00:00"
PROD_CPUS=8
PROD_GPUS=1
PROD_MEM="8GB"
PROD_WALLTIME="04:00:00"

# ── Scheduler ──
ACCOUNT="helicases.spons"
QUEUE="standard"
