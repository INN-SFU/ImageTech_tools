#!/bin/bash
###############################################################################
# rename_data.sh
#
# Script to rename reconstructed MRI/MEG data from the ImageTech servers to be BIDS-compliant.
# The script renames BOTH:
#   1) session folders (e.g., ses-20230101 →ses-<label>)
#   2) all files within those folders that contain a ses-* entity
#      - Note: any '_deFaced' suffix in filenames is removed
#
# -------------------------
# Mapping file (TSV) format
# -------------------------
# - Column 1 must be named 'subject' and contain subject IDs (e.g., sub-BRS001)
# - All remaining column names must be the desired BIDS session labels (e.g., ses-1, ses-2)
# - Each cell under a session label contains the existing session folder name (e.g., ses-YYYYMMDD)
#
# Example:
# subject	ses-1	ses-2	ses-3
# sub-BRS001	ses-20230101	ses-20230301	ses-20230501
# sub-BRS002	ses-20230201	ses-20230401	ses-20230601
#
# -------------------------
# Usage
# -------------------------
# - The script should be run from the directory containing the sub-* folders,
#   or the BASE variable in the script should be updated accordingly.
#
# Dry run (default; no files are changed):
#   ./rename_data.sh mapping_file.tsv
#
# Apply changes:
#   ./rename_data.sh --run mapping_file.tsv
#
###############################################################################

BASE="." # MODIFY
RUN_MODE=0
MAP_FILE=""

# --- Parse arguments ---
for arg in "$@"; do
    if [[ "$arg" == "--run" ]]; then
        RUN_MODE=1
    else
        MAP_FILE="$arg"
    fi
done

# --- Check mapping file ---
if [[ -z "$MAP_FILE" ]] || [[ ! -f "$MAP_FILE" ]]; then
    echo "ERROR: You must specify a valid mapping TSV file."
    echo "Usage: ./rename_data.sh [--run] <mapping_file.tsv>"
    exit 1
fi

echo "---------------------------------------------"
echo "RUN_MODE: $RUN_MODE"
echo "Mapping file: $MAP_FILE"
echo "Base directory: $BASE"
echo "---------------------------------------------"

# --- Read header to get BIDS session labels ---
read -r HEADER < "$MAP_FILE"
SESSION_LABELS=($(echo "$HEADER" | tr '\t' '\n' | tail -n +2))  # skip 'subject' column

# --- Process each subject ---
tail -n +2 "$MAP_FILE" | while IFS=$'\t' read -r -a FIELDS; do
    SUBJECT="${FIELDS[0]}"
    echo "Processing subject: $SUBJECT"

    SUBJECT_PATH="$BASE/$SUBJECT"
    if [[ ! -d "$SUBJECT_PATH" ]]; then
        echo "WARNING: Subject folder not found: $SUBJECT_PATH"
        continue
    fi

    for i in "${!SESSION_LABELS[@]}"; do
        NEW_SESSION="${SESSION_LABELS[i]}"
        OLD_SESSION="${FIELDS[i+1]}"

        [[ -z "$OLD_SESSION" ]] && continue

        SESSION_PATH="$SUBJECT_PATH/$OLD_SESSION"
        if [[ ! -d "$SESSION_PATH" ]]; then
            echo "WARNING: Session folder not found: $SESSION_PATH"
            continue
        fi

        echo "Renaming files in $SESSION_PATH → $NEW_SESSION"

        # Rename files in this session folder
        find "$SESSION_PATH" -type f -print0 | while IFS= read -r -d '' FILE; do
            BASENAME=$(basename "$FILE")
            DIRNAME=$(dirname "$FILE")

            # Rename session in filename and remove _deFaced
            NEWNAME=$(echo "$BASENAME" | sed -E "s/ses-[0-9]+/$NEW_SESSION/" | sed -E 's/_deFaced//g')

            if [[ "$NEWNAME" != "$BASENAME" ]]; then
                if [[ $RUN_MODE -eq 1 ]]; then
                    if [[ -e "$DIRNAME/$NEWNAME" ]]; then
                        echo "WARNING: $DIRNAME/$NEWNAME exists, skipping"
                    else
                        mv "$FILE" "$DIRNAME/$NEWNAME"
                        echo "Renamed: $FILE → $DIRNAME/$NEWNAME"
                    fi
                else
                    echo "[DRY RUN] Would rename: $FILE → $DIRNAME/$NEWNAME"
                fi
            fi
        done

        # --- Rename the session folder itself ---
        NEW_SESSION_PATH="$SUBJECT_PATH/$NEW_SESSION"
        if [[ "$SESSION_PATH" != "$NEW_SESSION_PATH" ]]; then
            if [[ $RUN_MODE -eq 1 ]]; then
                if [[ -e "$NEW_SESSION_PATH" ]]; then
                    echo "WARNING: Target folder $NEW_SESSION_PATH already exists, skipping folder rename"
                else
                    mv "$SESSION_PATH" "$NEW_SESSION_PATH"
                    echo "Renamed folder: $SESSION_PATH → $NEW_SESSION_PATH"
                fi
            else
                echo "[DRY RUN] Would rename folder: $SESSION_PATH → $NEW_SESSION_PATH"
            fi
        fi

    done
done

echo "---------------------------------------------"
echo "Processing complete."
