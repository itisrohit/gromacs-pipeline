# IIT Delhi HPC cluster profile (PBS)
SCHEDULER="pbs"
MODULES=("apps/gromacs/2023.2/gnu")
SUBMIT_CMD="qsub"
SUBMIT_ACCOUNT="-P %ACCOUNT%"
SUBMIT_QUEUE="-q %QUEUE%"
SUBMIT_DEPENDENCY="-W depend=afterok:%JOBID%"
SELECT_GPU="1:ncpus=%CPUS%:ngpus=%GPUS%:centos=skylake"
SELECT_CPU="1:ncpus=%CPUS%:centos=skylake"
SUBMIT_WALLTIME="-l walltime=%WALLTIME%"
SUBMIT_OUTPUT="-o output/logs/%NAME%.o%JOBID% -j oe"
WORKDIR_VAR="PBS_O_WORKDIR"
SCRATCH_DIR=""
GMX_VERSION=""
