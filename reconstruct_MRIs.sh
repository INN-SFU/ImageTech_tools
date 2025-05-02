#!/bin/bash

# script for MRI image reconstruction from raw DICOMS

# Load dcm2niix software:
# module load dcm2niix

# get file path from user:

if [ $# -lt 1 ]; then
    echo "Usage: $0 <filepath>"
    exit 1
fi

filepath="$1"
echo "File path provided: $filepath"

# Get directory portion of path
dirpath=$(dirname "$filepath")
filename=$(basename "$filepath")

# Check if directory exists
if [ ! -d "$dirpath" ]; then
    echo "Error: Directory does not exist: $dirpath"
    exit 1
fi

# Now you can use the filepath by changing directory
# MRI raw data are in:
cd "$dirpath" || {
    echo "Error: Failed to cd to $dirpath"
    exit 1
}

echo "Now in directory: $(pwd)"

destpath="/data/storage/test-project/mri/raw" # CHANGE IF NEEDED

# Check if directory exists. If not, make new directory
# First ensure base destination path exists
[ -d "$destpath" ] || mkdir -p "$destpath" || {
    echo "Error: Could not create destination path $destpath" >&2
    exit 1
}

# Then create subdirectories
for dir in zipped unzipped sorted; do
    if [ -d "$destpath/$dir" ]; then
        echo "Directory already exists: $destpath/$dir" >&2
    else
        mkdir -p "$destpath/$dir" || {
            echo "Error: Failed to create $destpath/$dir" >&2
            exit 1
        }
    fi
done

# Copying zipped files from /sourcedata to /raw/mri/zipped
if cp "$filename" "$destpath/zipped/"; then
    echo "Copied $filename to $destpath/zipped/"
else
    echo "Error: Copy failed!" >&2
    exit 1
fi

declare -a dicomsort_raw_dirname=()

# For each subject:
# Unzip MRI .zip from /zipped into /unzipped directory with correct naming system:
for zipfile in "$destpath"/zipped/*.zip; do
    output_dir="$destpath/unzipped/$(basename "$zipfile" .zip)"
    dicomsort_raw_dirname+=("$(basename "$zipfile" .zip)")
    if [ -d "$output_dir" ] && [ "$zipfile" -ot "$output_dir" ]; then
        echo "Skipping $zipfile: Contents already up-to-date"
    else
        unzip -o "$zipfile" -d "$destpath/unzipped/" || {
            echo "Error: Failed to unzip $zipfile" >&2
            continue
        }
    fi
done

cd "$destpath/unzipped" || {
        echo "Error: Could not cd to $destpat/unzipped" >&2
        exit 1
    }

# Run dicomsort and then place the data in /raw/sorted
for subject in "${dicomsort_raw_dirname[@]}"; do
    echo "Running dicomsort on: $subject"
    dicomsort "$destpath/unzipped/$subject/DICOM" "$destpath/sorted/%PatientName/%StudyDate/%SeriesDescription/%InstanceNumber.dcm"
done

reconstruction_path="/data/storage/test-project/mri/reconstructed" # CHANGE IF NEEDED

# Check if directory exists. If not, make new directory
# First ensure base destination path exists
[ -d "$reconstruction_path" ] || mkdir -p "$reconstruction_path" || {
    echo "Error: Could not create reconstruction path $reconstruction_path" >&2
    exit 1
}

# Change to reconstruction path
cd "$reconstruction_path" || {
    echo "Error: Could not cd to $reconstruction_path" >&2
    exit 1
}

for subject in "${dicomsort_raw_dirname[@]}"; do
    mkdir -p "$subject"|| {
        echo "Error: Could not create subject directory for $subject" >&2
        continue
    }

    if [ ! -d "$subject" ]; then
        echo "Warning: $subject does not exist - skipping"
        continue
    fi
    # Reconstruct MRI images with dcm2niix software:
    # dcm2niix -o "$subject" -z y -v y "$destpath"/sorted/*/*/{T1*,
    # Find all scan-type directories under each subject/date
    find "$destpath"/sorted/*/ -type d -mindepth 2 -maxdepth 2 | while read -r scan_dir; do
        echo "Converting DICOMs in: $scan_dir"
        dcm2niix -o "$subject" -z y -v y "$scan_dir" || { #needs to be a directory name not .dcm file name
            echo "Error: dcm2niix failed for $subject" >&2
            continue
        }
    done
done


# # Process each subject directory
# for subject_dir in "$destpath"/sorted/*/; do
#     subject_name=$(basename "$subject_dir")
#     echo "Processing subject: $subject_name"

#     # Find the single date directory (alphanumeric, not 'nifti')
#     date_dir=$(find "$subject_dir" -maxdepth 1 -type d ! -name ".*" ! -name "nifti" -print -quit)
    
#     if [ ! -d "$date_dir" ]; then
#         echo "Warning: No date directory found for $subject_name" >&2
#         continue
#     fi

#     # Find and process T1 directory (case insensitive)
#     find "$date_dir" -maxdepth 1 -type d -iname "T1*" | while read -r t1_dir; do
#         echo "Found T1 directory: $(basename "$t1_dir")"
        
#         # Run dcm2niix with clean output naming
#         dcm2niix -o "$subject/$date_dir" -z y -v y "$t1_dir" || {
#             echo "Error: Failed to convert $t1_dir" >&2
#         }
#     done
# done

# echo "Processing complete"

# Download the following .nii.gz images to your local machine and inspect with FSLeyes or equivalent:
# *3D_FLAIR*
# *B0map*
# *DTI_60*
# *DTI_b0_rev*
# *fMRI*_e1*
# *fMRI*_e2*
# *fMRI*_e3*
# *T1W*
