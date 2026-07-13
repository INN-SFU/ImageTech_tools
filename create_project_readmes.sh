#!/bin/bash
###############################################################################
# create_project_readmes.sh
#
# Create standardized README files for a project directory.
# This script will not overwrite existing READMEs.
#
# Usage:
#   ./create_project_readmes.sh <project_name>
#
# Example:
#   ./create_project_readmes.sh BrainResilience
###############################################################################

set -e

PROJECT_NAME="$1"

if [[ -z "$PROJECT_NAME" ]]; then
    echo "ERROR: Project name not provided."
    echo "Usage: ./create_project_readmes.sh <project_name>"
    exit 1
fi

PROJECT_DIR="/data/storage/projects/${PROJECT_NAME}"

# -------------------------
# Helper function
# -------------------------
create_readme() {
    local path="$1"
    local content="$2"

    mkdir -p "$path"

    local readme="${path}/README.md"
    if [[ -f "$readme" ]]; then
        echo "README already exists, skipping: $readme"
    else
        echo "Creating README: $readme"
        cat <<EOF > "$readme"
$content

---
*This README was automatically generated on $(date '+%Y-%m-%d').*
EOF
        chmod 664 "$readme"
    fi
}

# -------------------------
# Top-level README
# -------------------------
create_readme "$PROJECT_DIR" "# ${PROJECT_NAME}

This directory contains all processed neuroimaging data for the **${PROJECT_NAME}** project.

## Directory overview
- \`mri/raw_sorted/\`    – Sorted MRI DICOM data
- \`mri/reconstructed/\` – Reconstructed MRI data (BIDS-like format)
- \`mri/refaced/\`       – MRI data with facial features replaced
- \`meg/raw/\`           – Raw MEG data as acquired
- \`meg/reconstructed/\` – Reconstructed MEG data (BIDS-like format)
- \`logs/\`              – Processing logs generated during pipeline execution
"
# -------------------------
# MRI READMEs
# -------------------------
create_readme "$PROJECT_DIR/mri/raw_sorted" "# MRI – Raw Sorted Data

This directory contains **sorted original MRI DICOM files** for each subject and session.

- Data are organized by subject and session."

create_readme "$PROJECT_DIR/mri/reconstructed" "# MRI – Reconstructed Data

This directory contains **reconstructed MRI data** derived from the raw DICOMs.

- Data are organized in a BIDS-like structure by subject and session.
- Includes modality-specific subdirectories (e.g., anat, dwi, fmap).
- Session naming is date-based and not fully BIDS-compliant.
"

create_readme "$PROJECT_DIR/mri/refaced" "# MRI – Refaced Data

This directory contains **MRI data** suitable for sharing.

- Anatomical scans with facial features are processed using **mri_reface**.
- Scans without facial features are copied without modification.
- Data are organized in a BIDS-like format.

The following files should NOT be uploaded to Compute Canada:
- FaceTemplate files
- PNG images containing original facial features"

# -------------------------
# MEG READMEs
# -------------------------
create_readme "$PROJECT_DIR/meg/raw" "# MEG – Raw Data

This directory contains **raw, unprocessed MEG data** as acquired from the scanner.

- No preprocessing or BIDS conversion has been applied.
"

create_readme "$PROJECT_DIR/meg/reconstructed" "# MEG – Reconstructed Data

This directory contains **reconstructed MEG data** organized in a BIDS-like format.

- Data are organized in a BIDS-like structure by subject and session using mne-bids.
- Session naming is date-based and not fully BIDS-compliant.
- Any events.tsv files are automatically generated for BIDS compliance; 
  however, event extraction from the raw .fif files is recommended.
"

echo "---------------------------------------------"
echo "README creation complete for project: ${PROJECT_NAME}"
