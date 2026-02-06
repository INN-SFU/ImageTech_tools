#!/bin/bash

################################################################################
# Script to process subject neuroimaging data with the following steps:
# Default:
#   - Copy and sort MRI files from: /data/storage/sourcedata/<project>/mri to: /data/storage/projects/<project>/mri/raw_sorted
#   - Copy MEG files from: /data/storage/sourcedata/<project>/meg to: /data/storage/projects/<project>/meg/raw
#
# Optional:
#    -b, --bids-mri     : Reconstruct MRI data to BIDS (reconstruct_MRIs.sh)
#    -r, --reface       : Reface MRI anatomical images (T1w, FLAIR)
#    -g, --meg-copy     : Copy MEG raw data only
#    -m, --bids-meg     : Reconstruct MEG to BIDS (reconstruct_MEG.py)
#
# Usage:
#   $0 [flags] <subject_id_file.txt> <project_name>
#
# Arguments:
#   subject_id_file.txt  : Text file containing subject IDs (one per line)
#   project_name         : Name of the project folder under /data/storage/sourcedata
#
# Example:
#   $0 -b -r -g -m subjects_BrainResilience.txt BrainResilience
#
# Prerequisites for MRI sorting
#  The following needs to be run to install dicomsort:
#     pip install thedicomsort
#
# Prerequisites for BIDS reconstruction:
#   - Subject IDs in the subject_id_file.txt should start on a new line for each subject
#   - MRI zip files are expected in /data/storage/sourcedata/<project_name>/mri
#   - MEG input directories expected in /data/storage/sourcedata/<project_name>/meg/<subject_folder>/<date_folder>
#   - A unique configuration file must be created for each project in /data/storage/software/config_files/:
#       Format: <project_name>_config.json
#       An example file is located at: /data/storage/software/config_files/BrainResilience_config.json
#
# Prerequisites for Refacing:
#   Before running refacing, a unique file with the file names that you want refaced must be created in /data/storage/software/config_files/:
#       Format: <project_name>_reface.txt -- each line should include the unique naming of the files to be refaced.
#   The following will be installed/set up:
#     1) Install packages:
#          pip install docker
#          pip install matlab
#     2) Load the Docker image:
#          sudo docker load -i /data/storage/software/mri_reface_docker/mri_reface_docker_image
#
# Log files:
#   - A log file is created for each subject and stored in:
#       /data/storage/projects/<project_name>/logs/
#
# Author: Leanne Rokos
################################################################################
#set -x
#echo "$-"
usage() {
    echo "Usage: $0 [-b|bids-mri] [-r|--reface] [-m|--bids-meg] [-g| --meg-copy] <subject_id_file.txt> <project_name>"
    echo "Example: $0 -b -r -g -m subject_ids.txt BrainResilience"
    echo "Flags:"
    echo "  -b, --bids-mri  Run MRI reconstruction to BIDS"
    echo "  -r, --reface    Run refacing on MRI"
    echo "  -g, --meg-copy  Copy raw MEG data"
    echo "  -m, --bids-meg  Run MEG reconstruction to BIDS"
    exit 1
}

# -------------------
# Default settings
# -------------------
MEG_COPY=1
MRI_COPY=1
BIDS_MRI=0
BIDS_MEG=0
REFACE=0
MEG_FLAG_EXPLICIT=0

# -------------------
# Parse flags
# -------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -g|--meg-copy)
            MEG_COPY=1
            MEG_FLAG_EXPLICIT=1
            MRI_COPY=0
            ;;
        -r|--reface)
            REFACE=1
            BIDS_MRI=1
            MRI_COPY=1
            ;;
        -b|--bids-mri)
            BIDS_MRI=1
            MRI_COPY=1
            MEG_COPY=0
            ;;
        -m|--bids-meg)
            BIDS_MEG=1
            MEG_COPY=1   # Copy MEG for BIDS-MEG
            MRI_COPY=1
            ;;
        -*|--*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            break
            ;;
    esac
    shift
done

# -------------------
# Resolve flag dependencies
# -------------------

# REFACE implies BIDS_MRI
if [ "$REFACE" -eq 1 ]; then
    BIDS_MRI=1
    MRI_COPY=1
fi

# Ensure MRI_COPY is on if BIDS_MRI was requested
if [ "$BIDS_MRI" -eq 1 ]; then
    MRI_COPY=1
fi

# Only turn off MEG_COPY if the user did NOT explicitly request it
if [ "$BIDS_MRI" -eq 1 ] && [ "$MEG_COPY" -eq 1 ] && [ "$BIDS_MEG" -ne 1 ] && [ "$MEG_FLAG_EXPLICIT" -eq 0 ]; then
    MEG_COPY=0
fi

if [ $# -ne 2 ]; then
    usage
fi

check_command() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Error executing command: $*"
        exit $status
    fi
}

SUBJECT_LIST_FILE="$1"
PROJECT_NAME="$2"

BASE_DIR="/data/storage/sourcedata"
PROJECT_DIR="${BASE_DIR}/${PROJECT_NAME}"
MRI_DIR="${PROJECT_DIR}/mri"
RECON_DIR="/data/storage/projects/${PROJECT_NAME}/mri/reconstructed"
#RECON_DIR="/data/storage/test-project/${PROJECT_NAME}/mri/reconstructed" # testing path
RECON_SCRIPT="/data/storage/software/reconstruct_MRIs.sh"
REFACE_SCRIPT="/data/storage/software/mri_reface_docker/run_mri_reface_docker.sh"
MEG_SCRIPT="/data/storage/software/reconstruct_MEG.py"
MEG_DIR="${PROJECT_DIR}/meg"

if [ ! -f "$SUBJECT_LIST_FILE" ]; then
    echo "Error: File '$SUBJECT_LIST_FILE' not found."
    exit 1
fi

if [ ! -d "$MRI_DIR" ]; then
    echo "Error: Project directory MRI folder '$MRI_DIR' not found."
    exit 1
fi

if [ $MEG_COPY -eq 1 ] || [ $BIDS_MEG -eq 1 ]; then
    if [ ! -d "$MEG_DIR" ]; then
        echo "Error: Project directory MEG folder '$MEG_DIR' not found."
        exit 1
    fi
fi

# Ensure correct packages installed for refacing
if [ $REFACE -eq 1 ]; then
    if ! python3 -c "import docker" &> /dev/null; then
        pip install --user --quiet docker
    fi

    if ! python3 -c "import matlab" &> /dev/null; then
        pip install --user --quiet matlab
    fi
# Start sudo session and keep it alive
    echo "Requesting sudo access..."
    sudo -v
    while true; do sudo -v; sleep 60; done &
    KEEP_SUDO_ALIVE_PID=$!
    # Kill the keep-alive loop on exit
    trap "kill $KEEP_SUDO_ALIVE_PID 2>/dev/null" EXIT
fi

# ==================== SET PERMISSIONS AT START ====================
PROJECT_OUTPUT_DIR="/data/storage/projects/${PROJECT_NAME}" #TO DO: CHANGE TEST-PROJECT

echo "Setting initial group ownership and default permissions for '${PROJECT_OUTPUT_DIR}'..."

# Create base directory if it doesn't exist
mkdir -p "$PROJECT_OUTPUT_DIR"

if [ "$(stat -c %G "$PROJECT_OUTPUT_DIR")" != "imgtech_server_staff" ]; then
    echo "Setting initial group ownership and default permissions for '${PROJECT_OUTPUT_DIR}'..."
    check_command chown :imgtech_server_staff "$PROJECT_OUTPUT_DIR"
    check_command chmod g+rw "$PROJECT_OUTPUT_DIR"
    check_command find "$PROJECT_OUTPUT_DIR" -type d -exec chmod 2770 {} \;

    # Set default ACLs to make new files/folders inherit permissions
    check_command setfacl -d -m g::rwx "$PROJECT_OUTPUT_DIR"
    check_command setfacl -d -m o::--- "$PROJECT_OUTPUT_DIR"
else
    echo "Permissions already set for ${PROJECT_OUTPUT_DIR}, skipping."
fi

# ==================== LOG DIRECTORY ====================
LOG_DIR="/data/storage/projects/${PROJECT_NAME}/logs"
mkdir -p "$LOG_DIR"

# ==================== PROJECT README SETUP ====================
README_SCRIPT="/data/storage/software/create_project_readmes.sh"
#bash "$README_SCRIPT" "$PROJECT_NAME"

# ==================== SUBJECT LOOP ====================
# Loop through each subject
mapfile -t subject_list_array < $SUBJECT_LIST_FILE

for subject_id_in_subject_file in "${subject_list_array[@]}"; do
    # Skip empty or comment lines
    [[ -z "$subject_id_in_subject_file" || "$subject_id_in_subject_file" =~ ^# ]] && continue
    start_time=$(date +%s)
    # Log file path
    subj_base=$(echo "$subject_id_in_subject_file" | sed -E 's/^sub[_-]//' | sed -E 's/_[0-9]{8}//')
    log_file="${LOG_DIR}/${subj_base}.log"
    echo -e "\n\n\n\n[$(date '+%Y-%m-%d %H:%M:%S')] ==== Starting processing for $subject_id_in_subject_file ====" | tee -a "$log_file"
    RAW_SORTED_CREATED_TEMP=0
    # ==================== MRI PROCESSING ====================
    if [ "$MRI_COPY" -eq 1 ]; then
        # Determine zip file pattern to match for the subject line
        if [[ "$subject_id_in_subject_file" =~ ^sub[-_].* ]]; then
            # If starts with 'sub-' or 'sub_'
            # Match exact if contains '_', otherwise allow _* after
            if [[ "$subject_id_in_subject_file" == *_* ]]; then
                pattern="${subject_id_in_subject_file}.zip"
            else
                pattern="${subject_id_in_subject_file}_*.zip"
            fi
        else
            # Any other subject ID
            pattern="*${subject_id_in_subject_file}*.zip"
        fi

        matches=("$MRI_DIR"/$pattern)
        if [ -e "${matches[0]}" ]; then
            for zipfile in "${matches[@]}"; do
                if [ -f "$zipfile" ]; then
                    echo "Processing MRI $zipfile" | tee -a "$log_file"

                    # Run MRI reconstruction script first
                    filename=$(basename "$zipfile" .zip)
                    subj_id=$(echo "$filename" | sed -E 's/^sub[_-]//' | sed -E 's/_[0-9]{8}//')
                    date_yyyymmdd=$(echo "$filename" | grep -oP '[0-9]{8}')
                    recon_subject_dir="${RECON_DIR}/${subj_id}/ses-${date_yyyymmdd}"

                    # Check existence of raw_sorted for later MEG-BIDS step
                    RAW_SORTED_DIR="/data/storage/projects/${PROJECT_NAME}/mri/raw_sorted/sub-${subj_id}/ses-${date_yyyymmdd}"
                    if [ ! -d "$RAW_SORTED_DIR" ]; then
                        if [ "$BIDS_MEG" -eq 1 ] && [ "$BIDS_MRI" -eq 0 ]; then
                            echo "${RAW_SORTED_DIR} directory does not exist. Will create temporary raw_sorted for MEG BIDS."| tee -a "$log_file"
                            RAW_SORTED_CREATED_TEMP=1
                        fi
                    fi

                    echo "Running MRI script for $zipfile" | tee -a "$log_file"
                    cmd="bash $RECON_SCRIPT \"$zipfile\" ${PROJECT_NAME}"

                    # Append 'bids' argument if BIDS_MRI is set
                    if [ "$BIDS_MRI" -eq 1 ]; then
                        cmd+=" bids"
                    fi
                    eval $cmd >> "$log_file" 2>&1
                    if [ $? -ne 0 ]; then
                        echo "ERROR: MRI reconstruction failed for ${subj_id}" | tee -a "$log_file"
                        continue
                    fi

                    # ==================== REFACE ====================
                    if [ $REFACE -eq 1 ]; then
                        echo "--- MRI refacing ---" | tee -a "$log_file"
                        recon_anat_dir="${RECON_DIR}/sub-${subj_id}/ses-${date_yyyymmdd}/anat"

                        subject_session_dir="/data/storage/projects/${PROJECT_NAME}/mri/refaced/sub-${subj_id}/ses-${date_yyyymmdd}"
                        subject_reface_anat_dir="${subject_session_dir}/anat"

                    # Load reface patterns from file
                        reface_pattern_file="/data/storage/software/config_files/${PROJECT_NAME}_reface.txt"
                        if [ ! -f "$reface_pattern_file" ]; then
                            echo "Error: Reface pattern file not found: $reface_pattern_file" | tee -a "$log_file"
                            echo "Skipping" | tee -a "$log_file"
                            continue
                        fi

                        # Read lines and wrap with '*'
                        reface_patterns=()
                        while IFS= read -r pattern_line || [ -n "$pattern_line" ]; do
                            pattern=$(echo "$pattern_line" | xargs)  # trim whitespace
                            if [ -n "$pattern" ]; then
                                reface_patterns+=("*${pattern}*")
                            fi
                        done < "$reface_pattern_file"

                    # Check if any refaced files matching the patterns already exist
                        already_refaced=0
                        for pattern in "${reface_patterns[@]}"; do
                            matches=$(find "$subject_reface_anat_dir" -type f -name "$pattern" | wc -l)
                            already_refaced=$((already_refaced + matches))
                        done

                        if [ "$already_refaced" -gt 0 ]; then
                            echo "Refaced files matching patterns already exist for $subj_id ses-${date_yyyymmdd}, skipping..." | tee -a "$log_file"

                        else
                            # Find all .nii.gz files in anat/
                            mapfile -t nii_gz_files < <(find "$recon_anat_dir" -type f -name '*.nii.gz')

                            if [ "${#nii_gz_files[@]}" -eq 0 ]; then
                                echo "Warning: No .nii.gz files found for $subj_id on $date_yyyymmdd" | tee -a "$log_file"
                            else
                                # Create a temporary refacing directory
                                tmp_reface_dir="/tmp/reface_sub-${subj_id}_ses-${date_yyyymmdd}_$$"
                                tmp_reface_output_dir="${tmp_reface_dir}/refaced"

                                mkdir -p "$tmp_reface_dir" "$tmp_reface_output_dir" "$subject_reface_anat_dir"

                                for nii_gz_file in "${nii_gz_files[@]}"; do
                                    nii_file="${nii_gz_file%.gz}"
                                    base_name=$(basename "$nii_file")

                                    should_reface=0
                                    for pattern in "${reface_patterns[@]}"; do
                                        if [[ "$base_name" == $pattern ]]; then
                                            should_reface=1
                                            break
                                        fi
                                    done

                                    if [ $should_reface -eq 1 ]; then
                                        echo "Unzipping for refacing: $base_name"
                                        gunzip -c "$nii_gz_file" > "$tmp_reface_dir/$base_name"
                                    else
                                        echo "Copying non-refaced anat file: $base_name"
                                        cp "$nii_gz_file" "$subject_reface_anat_dir/"
                                    fi
                                done

                                chmod -R 777 "$tmp_reface_dir"

                                # Load Docker image (if not already loaded)
                                sudo docker load -i /data/storage/software/mri_reface_docker/mri_reface_docker_image

                                # Run the refacing script on each copied NIfTI file
                                for nii_file in "$tmp_reface_dir"/*.nii; do
                                    echo "Running refacing on $(basename "$nii_file")" | tee -a "$log_file"
                                    sudo bash "$REFACE_SCRIPT" "$nii_file" "$tmp_reface_output_dir"
                                done

                                # Move refaced output to anat/ subdirectory in refaced storage
                                cp -r "$tmp_reface_output_dir/"* "$subject_reface_anat_dir/"

                                # Gzip any remaining .nii files in the subject_reface_anat_dir
                                echo "Compressing .nii files in $subject_reface_anat_dir"
                                find "$subject_reface_anat_dir" -type f -name '*.nii' ! -name '*.nii.gz' -exec gzip {} \;

                                # Rename any files with _defaced to _refaced in anat/
                                echo "Renaming _deFaced files to _refaced in $subject_reface_anat_dir"
                                find "$subject_reface_anat_dir" -type f -name '*_deFaced*' | while read -r f; do
                                    mv "$f" "${f/_deFaced/_refaced}"
                                done

                                # Copy other original files (e.g., dwi/, fmap/, etc.) into the refaced session directory
                                original_session_dir="${RECON_DIR}/sub-${subj_id}/ses-${date_yyyymmdd}"
                                echo "Copying additional original files from $original_session_dir to $subject_session_dir"
                                rsync -av --ignore-existing --exclude='anat/' "$original_session_dir/" "$subject_session_dir/"

                                # Copy any JSON files from anat/ into refaced anat/
                                if [[ -d "$original_session_dir/anat" ]]; then
                                    echo "Copying JSONs from $original_session_dir/anat to $subject_reface_anat_dir"
                                    find "$original_session_dir/anat" -maxdepth 1 -type f -name '*.json' -exec cp {} "$subject_reface_anat_dir/" \;
                                fi

                                # Clean up temporary directory
                                echo "Deleting temporary refacing directory $tmp_reface_dir"
                                rm -rf "$tmp_reface_dir"
                            fi
                        fi
                    fi
                fi
            done
        else
            echo "WARNING: No MRI zip files found for pattern '$pattern' in $MRI_DIR" | tee -a "$log_file"
        fi
    fi
    # ==================== MEG ====================
    if [ $MEG_COPY -eq 1 ] || [ $BIDS_MEG -eq 1 ]; then
        subj_id="$subject_id_in_subject_file"
        echo "--- MEG reconstruction ---" | tee -a "$log_file"
        subj_no_sub=$(echo "$subj_id" | sed 's/^sub-//I' | tr '[:upper:]' '[:lower:]')
        prefix=$(echo "$subj_no_sub" | sed -E 's/^([a-z]+).*/\1/')
        suffix=$(echo "$subj_no_sub" | sed -E "s/^$prefix//")  # everything after the prefix

        # List of possible MEG folder names
        possible_folders=(
            "${prefix}${suffix}"        # e.g., brs0170
            "${prefix}_${suffix#_}"     # e.g., brs_0170
			"${subj_id}"                # e.g., BRS0170 
        )

        subj_meg_path=""
        for folder in "${possible_folders[@]}"; do
            if [ -d "${MEG_DIR}/${folder}" ]; then
                subj_meg_path="${MEG_DIR}/${folder}"
                break
            fi
        done

        echo "Using MEG folder path: $subj_meg_path"

        if [ -z "$subj_meg_path" ]; then
            echo "Warning: MEG subject directory '$subj_meg_path' not found for subject '$subj_id'. Skipping MEG." | tee -a "$log_file"
            continue
        fi

        echo "Running MEG reconstruction script for subject '$subj_id'" | tee -a "$log_file"
        cmd="python3 $MEG_SCRIPT \"$subj_meg_path\" ${PROJECT_NAME}"

        if [ "$BIDS_MEG" -eq 1 ]; then
            cmd+=" --bids"
        fi

        # Delete temporary raw_sorted if it was created only for MEG-BIDS
        if [ "$RAW_SORTED_CREATED_TEMP" -eq 1 ]; then
            echo "Deleting temporary ${RAW_SORTED_DIR} directory for $subj_id" | tee -a "$log_file"
            rm -rf "$RAW_SORTED_DIR"
        fi

        eval $cmd >> "$log_file" 2>&1
        if [ $? -ne 0 ]; then
            echo "ERROR: MEG reconstruction failed for ${subj_id}" | tee -a "$log_file"
            continue
        fi
    fi
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ==== Finished processing for ${subj_id} (took ${elapsed}s) ====" | tee -a "$log_file"

done

# Stop the sudo refresher if it was started
if [ $REFACE -eq 1 ]; then
    echo "Stopping sudo keep-alive process"
    kill "$KEEP_SUDO_ALIVE_PID"
fi

# Clean up intermediate folders
echo "Cleaning up any intermediate MRI folders..."
MRI_INTERMEDIATE_PATH="/data/storage/projects/${PROJECT_NAME}/mri"

for dir in unzipped zipped; do
    fullpath="${MRI_INTERMEDIATE_PATH}/${dir}"
    if [ -d "$fullpath" ]; then
        echo "Removing $fullpath"
        rm -rf "$fullpath"
    fi
done
# Clean up tmp BIDS folder
TMP_PATH="${RECON_DIR}/tmp_dcm2bids"
if [ -d "$TMP_PATH" ]; then
    echo "Removing $TMP_PATH"
    rm -rf "$TMP_PATH"
fi
echo "Processing complete."

echo -e "\n============ DISPLAYING ALL SUBJECT LOGS FROM THIS RUN ============\n"
for subject_id_in_subject_file in "${subject_list_array[@]}"; do
    subj_base=$(echo "$subject_id_in_subject_file" | sed -E 's/^sub[_-]//' | sed -E 's/_[0-9]{8}//')
    log_file="${LOG_DIR}/${subj_base}.log"

    if [ -f "$log_file" ]; then
        echo -e "=== Log from $subj_base ===\n"
        cat "$log_file"
        echo -e "\n"
    fi
done
