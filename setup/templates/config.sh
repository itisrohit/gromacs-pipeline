# GROMACS HPC Pipeline Configuration
# Edit this file for each project.

# ── Cluster Profile ──
CLUSTER="generic-pbs"
PROJECT="my_project"

# ── Input Files ──
PDB="input/complex.pdb"
EM_MDP="input/em.mdp"
NVT_MDP="input/nvt.mdp"
NPT_MDP="input/npt.mdp"
MD_MDP="input/md.mdp"

# ── System ──
FORCEFIELD="amber14sb"
WATER_MODEL="spce"
BOX_TYPE="dodecahedron"
BOX_DISTANCE="1.0"
SALT_CONC="0.15"
CATION="K"
ANION="CL"

# ── Temperature Coupling Groups ──
TC_GROUPS='group Protein or group DNA
group Water or group Ion'

# ── Simulation Length ──
PRODUCTION_NS=100
CHUNK_NS=50

# ── Resources ──
SETUP_CPUS=8
SETUP_MEM="8GB"
SETUP_WALLTIME="00:30:00"
EQ_CPUS=8
EQ_GPUS=1
EQ_MEM="16GB"
EQ_WALLTIME="02:00:00"
PROD_CPUS=8
PROD_GPUS=1
PROD_MEM="16GB"
PROD_WALLTIME="24:00:00"

# ── Scheduler ──
ACCOUNT="my_account"
QUEUE="standard"
