#!/bin/bash
#SBATCH --account=def-rmcintos
#SBATCH --mail-user=sunsar@sfu.ca
#SBATCH --mail-type=FAIL
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=6
#SBATCH --mem=32000MB
#SBATCH --time=0-3:30
#SBATCH --output=log/log_%x_%j.o

# sbatch script for MRI image reconstruction from raw DICOMS
# MRI raw data are in:
cd ~/projects/def-rmcintos/BCGP/raw/mri

# Load dcm2niix software:
module load dcm2niix

# For each subject:
#if else statement to check for zip vs unzip

# Unzip MRI .zip from /projects into your /scratch/BCGP directory with correct naming system:
unzip -o ~/projects/def-rmcintos/BCGP/raw/mri/<ImageTech-id>.zip -d ~/scratch/BCGP

#if sorted(?) dicomsort
# comment if sorted - user dependant

# make target directory:
mkdir ~/projects/def-rmcintos/BCGP/reconstructed/mri/BRS000<subj-number>

# Reconstruct MRI images with dcm2niix software:
dcm2niix -o ~/projects/def-rmcintos/BCGP/reconstructed/mri/BRS2023000<subj-number>/ -z y -v y ~/scrat>

# Download the following .nii.gz images to your local machine and inspect with FSLeyes or equivalent:
# *3D_FLAIR*
# *B0map*
# *DTI_60*
# *DTI_b0_rev*
# *fMRI*_e1*
# *fMRI*_e2*
# *fMRI*_e3*
# *T1W*
