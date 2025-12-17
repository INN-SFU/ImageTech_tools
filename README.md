# ImageTech Tools

This repository contains scripts used by **ImageTech** for managing shared imaging data, setting permissions, and reconstructing MRI and MEG datasets, including conversion to **BIDS (Brain Imaging Data Structure)** format.

These tools are intended for use on the ImageTech server and assume access to the shared data storage environment.

---

## Contents

### Permission & Access Control Scripts

* **`set_sourcedata_permissions.sh`**
  Create and manage directories in `sourcedata` with correct group ownership and permissions.

* **`set_user_acl.sh`**
  Create or update user-specific Access Control Lists (ACLs) for project directories in `projects`.

### Reconstruction Scripts

* **`run_reconstruction.sh`**
  Main script to copy raw data and perform MRI/MEG reconstruction (optional BIDS conversion and MRI refacing).

* **`reconstruct_MRIs.sh`**
  Script for MRI reconstruction workflows.

* **`reconstruct_MEG.py`**
  Script for MEG data handling and reconstruction.

---

## ImageTech Directory Structure Overview

### Main Storage Location

```
/data/storage/
```

* Primary shared location for all imaging project data and scripts.

---

### Software & Scripts Location

```
/data/storage/software/
```

* Stores scripts and supporting files used to create project directories, set permissions, and copy/reconstruct data.

---

### Raw Imaging Data Location (sourcedata)

Uploaded raw data must be placed within a sub-directory inside `sourcedata`:

```
/data/storage/sourcedata/<project_name>/
```

* `sourcedata` contains raw, unprocessed imaging data.
* `<project_name>` corresponds to the specific research project.
* This folder is intended to be accessed only by ImageTech staff for data management and reconstruction.

---

### Shared/Reconstructed Project Directory (projects)

Reconstructed and processed data is stored in:

```
/data/storage/projects/<project_name>/
```

* Contains copied, sorted and optionally BIDS-converted MRI and MEG data for the project.
* This folder is intended to be shared with project users.
* Permissions for these project directories can be managed on a per-user basis using ACLs and the `set_user_acl.sh` script.


---


## Creating a Project Directory in `sourcedata`

To create a new project directory in `sourcedata`, run:

```
./set_sourcedata_permissions.sh <project>
```

* Replace `<project>` with your project name.
* You will be prompted for your password (sudo is required).

### Optional Flags

You may also create modality-specific subdirectories:

* `--meg` → create `meg/`
* `--mri` → create `mri/`
* `--both` → create both `meg/` and `mri/`

**Example:**

```
./set_sourcedata_permissions.sh my_project --both
```
---

## Data Preparation & BIDS Conversion

These tools support preparing data for broader sharing, including conversion to **BIDS (Brain Imaging Data Structure)**.

* BIDS improves data **accessibility, interoperability, and reproducibility**
* More information: [https://bids.neuroimaging.io](https://bids.neuroimaging.io)

---

### Reconstruction Workflow

The primary reconstruction workflow is handled by:

* **`run_reconstruction.sh`**

This script copies and processes subject-level MRI and MEG data from:

```
/data/storage/sourcedata/<project>
```

to:

```
/data/storage/projects/<project>
```

with optional reconstruction to BIDS format.

---

#### Default Behavior

* Copies and sorts MRI files from:

  ```
  /data/storage/sourcedata/<project>/mri
  ```

  to:

  ```
  /data/storage/projects/<project>/mri/raw_sorted
  ```
  
---

#### Optional Processing Steps

| Flag               | Description                           |
| ------------------ | ------------------------------------- |
| `-b`, `--bids-mri` | Convert MRI data to BIDS format       |
| `-r`, `--reface`   | Run MRI refacing                      |
| `-g`, `--meg-copy` | Copy raw MEG data                     |
| `-m`, `--bids-meg` | Copy raw MEG data and convert to BIDS |

---

#### Usage

```
./run_reconstruction.sh [flags] <subject_id_file.txt> <project_name>
```

---

#### BIDS Configuration File (Required for BIDS Reconstruction)

A unique BIDS configuration file must be created for each project to correctly map DICOM files to the BIDS format, based on the specific sequences acquired and the naming conventions used in the DICOM headers.

* File name format/location:

  ```
    /data/storage/software/config_files/<project>_config.json
  ```

---

#### Reface Mapping File (Required for MRI refacing)

A unique reface file must be created for each project, based on naming conventions and refacing requirements.

* File name format/location:

  ```
  /data/storage/software/config_files/<project>_reface.txt
  ```

* Each line should contain a unique identifying substring found in the filenames to be refaced
* Note: Other anatomical images not specified in the mapping file and all other modalities (e.g., fMRI, dwi) will not be defaced, but will be copied alongside the defaced files without modification. 

---

## User Permissions (ACLs)

```
/data/storage/software/user_permissions/
```

* Stores **user-specific Access Control List (ACL) files**.
* Each user should have **one ACL file** defining their access to **project directories** under `/data/storage/projects/`.

#### ACL File Format

Each line in a user’s ACL file specifies a project folder and the permissions granted:

```
<project_name>:<permissions>
```

Permission codes:

* `r` = read
* `w` = write
* `x` = execute
* `-` = no permission

**Example:**

```
project_1:rwx
project_2:r-x
```

---

## Notes

* These scripts were designed for the ImageTech server environment and have been tested with the following naming conventions and directory structure:
  * Subject IDs: `sub-BRS####`
  * `mri/` folder containing zipped MRI files per subject:
    ```
    /data/storage/sourcedata/<project>/mri/sub-BRS####_YYYYMMDD.zip
    ```
  * `meg/` folder organized by subject and session date:

    ```
    /data/storage/sourcedata/<project>/meg/brs_####/YYYYMMDD/
    ```
* The BIDS process **automatically creates a `participants.tsv` file**, which is populated with `n/a` values by default and **should not be relied upon**.
