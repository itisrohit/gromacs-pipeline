# Generic LSF cluster profile
SCHEDULER="lsf"
MODULES=("gromacs/2023.2")
SUBMIT_CMD="bsub"
SUBMIT_ACCOUNT="-P %ACCOUNT%"
SUBMIT_QUEUE="-q %QUEUE%"
SUBMIT_DEPENDENCY="-w \"done(%JOBID%)\""
SELECT_GPU="-gpu \"num=%GPUS%\" -R \"select[mem>%MEMORY%]\" -n %CPUS%"
SELECT_CPU="-n %CPUS% -R \"select[mem>%MEMORY%]\""
SUBMIT_WALLTIME="-W %WALLTIME%"
SUBMIT_OUTPUT="-o output/logs/%NAME%.o%JOBID%"
WORKDIR_VAR="LS_SUBCWD"
SCRATCH_DIR=""
GMX_VERSION=""
