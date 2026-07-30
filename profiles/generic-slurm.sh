# Generic Slurm cluster profile
SCHEDULER="slurm"
MODULES=("gromacs/2023.2")
SUBMIT_CMD="sbatch"
SUBMIT_ACCOUNT="--account=%ACCOUNT%"
SUBMIT_QUEUE="--partition=%QUEUE%"
SUBMIT_DEPENDENCY="--dependency=afterok:%JOBID%"
SELECT_GPU="1:ncpus=%CPUS%:ngpus=%GPUS%:mem=%MEMORY%"
SELECT_CPU="1:ncpus=%CPUS%:mem=%MEMORY%"
SUBMIT_WALLTIME="--time=%WALLTIME%"
SUBMIT_OUTPUT="--output=output/logs/%NAME%.o%JOBID%"
WORKDIR_VAR="SLURM_SUBMIT_DIR"
SCRATCH_DIR=""
GMX_VERSION=""
