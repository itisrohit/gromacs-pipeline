# Generic PBS cluster profile
SCHEDULER="pbs"
MODULES=("gromacs/2023.2")
SUBMIT_CMD="qsub"
SUBMIT_ACCOUNT="-P %ACCOUNT%"
SUBMIT_QUEUE="-q %QUEUE%"
SUBMIT_DEPENDENCY="-W depend=afterok:%JOBID%"
SELECT_GPU="-l select=1:ncpus=%CPUS%:ngpus=%GPUS%:mem=%MEMORY%"
SELECT_CPU="-l select=1:ncpus=%CPUS%:mem=%MEMORY%"
SUBMIT_WALLTIME="-l walltime=%WALLTIME%"
SUBMIT_OUTPUT="-o output/logs/%NAME%.o%j"
WORKDIR_VAR="PBS_O_WORKDIR"
SCRATCH_DIR=""
GMX_VERSION=""
