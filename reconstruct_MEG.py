#   Filename: reconstruct_MEG_testing.py
#   Language: Python >= 3.7
#   Author: Sunayani Sarkar
#   Modified by: Leanne Rokos
#   Purpose: Copy raw MEG data to /data/storage/projects/<project>/meg/raw & optionally convert to BIDS format
#   Requirements: pip install mne-bids --> automatically installed if missing
#
#   Usage:
#       python reconstruct_MEG.py /path/to/subject_directory <project_name> [--bids]
#
#   Description:
#       This script copies the raw MEG data to /data/storage/projects/<project>/meg/raw
#       It also optionally converts raw MEG data stored in a given subject directory
#       into the BIDS format using the mne-bids package.
#       The subject directory should contain session folders, each with MEG files
#       in .fif format.
#       The script automatically detects sessions and runs, extracts the task
#       name from the filename, and writes BIDS-formatted data to a specified
#       output directory.
#
#   Example:
#       python reconstruct_MEG.py /data/storage/sourcedata/BrainResilience/meg/sub-001 BrainResilience
#


import sys
import subprocess
import importlib.util
import re
import traceback
from pathlib import Path
import shutil

# Function to check if a package is installed
def install_if_missing(package_name):
    spec = importlib.util.find_spec(package_name)
    if spec is None:
        print(f"Package '{package_name}' not found. Installing it now...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", package_name])

# Defaults
do_copy = True
do_bids = False

if len(sys.argv) < 3:
    print("Usage: python reconstruct_MEG_testing.py /path/to/subject_directory <project_name> [--bids]")
    sys.exit(1)

subject_dir = Path(sys.argv[1])
project_name = sys.argv[2]

def log_error(msg):
    print(f"ERROR: {msg}")

# Check optional flag (only --bids supported)
if len(sys.argv) > 3 and sys.argv[3].lower() == "--bids":
    do_bids = True

if not subject_dir.is_dir():
    log_error(f"Error: Provided path is not a directory: {subject_dir}")
    sys.exit(0)

def normalize_subject_id(subj_id):
    """
    Normalize a subject ID from the directory name to match filenames.
    Examples:
        'sub-BRS0170' -> 'BRS0170'
    """
    # remove any 'sub-' or 'sub_' prefix
    subj = re.sub(r'^sub[-_]', '', subj_id, flags=re.I)
    # remove any other dashes/underscores and uppercase letters
    subj = re.sub(r'[-_]', '', subj).upper()
    return subj

def subject_has_invalid_files(session_folder, subject_dir):
    """
    Return True if any file in session_folder does NOT match the expected subject ID.
    """
    expected_sub_id = normalize_subject_id(subject_dir)
    print(f"Checking session folder: {session_folder}")
    print(f"Expected subject ID: {expected_sub_id}")

    for f in session_folder.iterdir():
        if f.is_file() and f.suffix.lower() in [".fif", ".fif.gz"]:
            # Check if expected_sub_id is in filename, ignoring case
            if expected_sub_id.upper() not in f.stem.upper():
                log_error(f"{f.name} contains unexpected subject ID (expected {expected_sub_id})")
                return True
            else:
                print(f"File OK: {f.name} contains expected subject ID")

    return False

# --- Pre-check all sessions first ---
invalid_subject = False
print(f"\nChecking subject {subject_dir.name} for invalid files...")
for session_folder in subject_dir.iterdir():
    if session_folder.is_dir():
        if subject_has_invalid_files(session_folder, subject_dir.name):
            log_error(f"Skipping subject {subject_dir.name} because session '{session_folder.name}' contains invalid files")
            invalid_subject = True
            break  # skip entire subject if any session has invalid files

if invalid_subject:
    print(f"ERROR: Subject {subject_dir.name} MEG processing skipped due to invalid files.\n")
    sys.exit(0)

if do_bids:
    install_if_missing('mne_bids')

import mne
from mne_bids import BIDSPath, write_raw_bids

# Define and create output paths
reconstructed_base = Path(f"/data/storage/projects/{project_name}/meg")  # TO DO: CHANGE TEST-PROJECT
reconstructed_path = reconstructed_base / "reconstructed"
raw_path = reconstructed_base / "raw"

# Create base directories if they don't exist
reconstructed_path.mkdir(parents=True, exist_ok=True)
raw_path.mkdir(parents=True, exist_ok=True)
failed_bids_files = []
for session_folder in subject_dir.iterdir():
    if session_folder.is_dir():
        session_id_short = session_folder.name
        session_id = f"20{session_id_short}"
        print(f"\nFound session: {session_id}")

        meg_files = list(session_folder.glob("*.fif"))
        if not meg_files:
            log_error(f"  No .fif files found in session '{session_folder}' (session ID: {session_id})")
            continue

        # Create subject/session folders in raw
        subject_id = subject_dir.name.replace('_', '').replace('sub-', '').replace('sub_', '').upper()
        raw_subj_ses_dir = raw_path / f"sub-{subject_id}" / f"ses-{session_id}"
        raw_subj_ses_dir.mkdir(parents=True, exist_ok=True)

        # Copy all files from session_folder to raw_subj_ses_dir
        for item in session_folder.iterdir():
            if item.is_file():
                dest = raw_subj_ses_dir / item.name
                if not dest.exists():
                    shutil.copy2(item, dest)
        print(f"    Copied raw MEG files to: {raw_subj_ses_dir}")

        # If --bids flag set, also convert to BIDS
        if do_bids:
            for raw_meg in meg_files:
                print(f"  Processing MEG file: {raw_meg.name}")
                try:
                    raw = mne.io.read_raw_fif(raw_meg, verbose=False)
                    print(f"    Loaded file successfully.")
                except Exception as e:
                    log_error(f"    Failed to load {raw_meg.name}: {e}")
                    continue

                # Clear birthday to avoid mne_bids errors
                if raw.info.get("subject_info") and "birthday" in raw.info["subject_info"]:
                    raw.info["subject_info"]["birthday"] = None

                if raw.info.get("subject_info"):
                    raw.info["subject_info"]["sex"] = 0 # SET TO N/A FOR NOW
                    raw.info["subject_info"]["hand"] = 0 # SET TO N/A FOR NOW

                # Parse filename to extract subject_id, task, run robustly
                fname = raw_meg.name.lower().replace('.fif', '').replace('.fif.gz', '')

                # Regex pattern to capture:
                #  sub[-_]subjectid[_-]task+run[_-]raw...
                pattern = r'^(?:sub[-_]?)?([a-z0-9]+)[-_]([a-z]+[0-9]*)[_-]raw'
                m = re.match(pattern, fname)
                if m:
                    subject_id = m.group(1).upper()
                    task_run_str = m.group(2)
                else:
                    log_error(f"    WARNING: Could not parse subject/task from filename '{raw_meg.name}'. Skipping this file.")
                    continue

                # Extract task and optional run number from task_run_str
                m_task = re.match(r'([a-z]+)(\d*)', task_run_str)
                if m_task:
                    task = m_task.group(1)
                    run = int(m_task.group(2)) if m_task.group(2) else None
                else:
                    log_error(f"    WARNING: Could not parse task/run from '{task_run_str}'. Skipping this file.")
                    continue

                bids_path = BIDSPath(
                    subject=subject_id,
                    session=session_id,
                    task=task,
                    run=run,
                    root=reconstructed_path,
                    datatype='meg',
                    extension=".fif"
                )

                print(f"    Using BIDS path: {bids_path.fpath}")

                try:
                    write_raw_bids(
                        raw,
                        bids_path,
                        overwrite=True,
                        verbose=True
                    )
                    print("    BIDS conversion complete")

                except Exception as e:
                    log_error(f"    Failed to write BIDS: {e}")
                    traceback.print_exc()
                    failed_bids_files.append(raw_meg.name)

            # --- Print summary of any files that were not converted ---
            if failed_bids_files:
                print("\n WARNING: The following MEG files were NOT converted to BIDS:")
                for f in failed_bids_files:
                    print(f"  {f}")

        # Move BIDS output files up one level and remove 'meg' folder
        subject_bids_dir = reconstructed_path / f"sub-{subject_id}" / f"ses-{session_id}"
        meg_folder = subject_bids_dir / "meg"

        if meg_folder.exists():
            for f in meg_folder.iterdir():
                dest = subject_bids_dir / f.name

                # Remove existing file or directory at destination
                if dest.exists():
                    if dest.is_dir():
                        shutil.rmtree(dest)
                    else:
                        dest.unlink()

                shutil.move(str(f), str(dest))

            shutil.rmtree(meg_folder)
            print(f"    Moved contents and removed: {meg_folder}")

        # --- Call demographics extraction script ---
        participants_tsv = reconstructed_path / "participants.tsv"

        # Create participants.tsv with header if it doesn't exist
        if not participants_tsv.exists():
            with participants_tsv.open('w') as f:
                f.write("participant_id\tsession_id\tsex\tweight\tage\n")

        # Build DICOM path (raw_sorted_dir) and call script
        raw_sorted_dir = f"/data/storage/projects/{project_name}/mri/raw_sorted/sub-{subject_id}/ses-{session_id}"

        extract_script = Path("/data/storage/software/extract_subject_info.py")
        cmd = [
            "python3", str(extract_script),
            "--dicom_path", str(raw_sorted_dir),
            "--subject_id", f"sub-{subject_id}",
            "--session_id", f"ses-{session_id}",
            "--participants_tsv", str(participants_tsv)
        ]
        try:
            print(f"    Running extract_subject_info.py for {subject_id} / {session_id}")
            subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as e:
            log_error(f"    ERROR running extract_subject_info.py: {e}")


print("\nAll MEG files have been processed.")
