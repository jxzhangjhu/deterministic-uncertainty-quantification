#!/bin/bash

# This is a generic running script. It can run in two configurations:
# Single job mode: pass the python arguments to this script
# Batch job mode: pass a file with first the job tag and second the commands per line

#SBATCH --job-name=DUQ
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#       --gres=gpu:titanrtx:1

set -e # fail fully on first line failure

echo "Running on $(hostname)"

if [ -z "$SLURM_ARRAY_TASK_ID" ]
then
    # Not in Slurm Job Array - running in single mode

    JOB_ID=$SLURM_JOB_ID

    # Just read in what was passed over cmdline
    JOB_CMD="${@}"
else
    # In array

    JOB_ID="${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"

    # Get the line corresponding to the task id
    JOB_CMD=$(head -n ${SLURM_ARRAY_TASK_ID} "$1" | tail -1)
 fi

# Find what was passed to --output_dir
regexp="--output_dir\s+(\S+)"
if [[ $JOB_CMD =~ $regexp ]]
then
    JOB_OUTPUT=${BASH_REMATCH[1]}
else
    echo "Error: did not find a --output_dir argument"
    exit 1
fi

# Check if results exists, if so remove slurm log and skip
if [ -f  runs/"$JOB_OUTPUT"/results.json ]
then
    echo "Results already done - exiting"
    rm "slurm-${JOB_ID}.out"
    exit 0
fi

# Check if the output folder exists at all. We could remove the folder in that case.
if [ -d  "runs/$JOB_OUTPUT" ]
then
    echo "Folder exists, but was unfinished or is ongoing (no results.json)."
    echo "Starting job as usual"

    echo "Removing current output before continuing"
    rm -r "runs/$JOB_OUTPUT"
fi

# Set up the environment
if [[ $SLURM_CLUSTER_NAME == "oatcloud" ]]; then
    export CONDA_ENVS_PATH=/scratch-ssd/"$USER"/conda_envs
    export CONDA_PKGS_DIRS=/scratch-ssd/"$USER"/miniconda3/pkgs
    path_to_conda="/scratch-ssd/oatml/miniconda3"

    /scratch-ssd/oatml/scripts/run_locked.sh "${path_to_conda}/bin/conda-env" update -q -f environment.yml
elif [[ $SLURM_CLUSTER_NAME == "arcus-htc" ]]; then
    # Run this once
    # /home/wolf5359/miniconda3/bin/conda-env update -f environment.yml
    path_to_conda="/home/wolf5359/miniconda3"
fi

# Activate the environment
source "${path_to_conda}/bin/activate" gpduq

# Train the model
srun python $JOB_CMD

# Move the log file to the job folder
mv "slurm-${JOB_ID}.out" runs/"$JOB_OUTPUT"/
