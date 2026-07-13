# SFU's Centre for Advanced Imaging (SCAI) Tools

This repository contains scripts used by **SCAI** for managing shared imaging data, setting permissions, and reconstructing MRI and MEG datasets, including conversion to **BIDS (Brain Imaging Data Structure)** format.

These tools are intended for use on the SCAI server and assume access to the shared data storage environment.

---
## Contents

| Script | Description |
|---|---|
| `set_sourcedata_permissions.sh` | Create and manage directories in `sourcedata` with correct group ownership and permissions. |
| `set_user_acl.sh` | Create or update user-specific Access Control Lists (ACLs) for project directories in `projects`. |
| `run_reconstruction.sh` | Main script to copy raw data and perform MRI/MEG reconstruction (optional BIDS conversion and MRI refacing). |
| `reconstruct_MRIs.sh` | Script for MRI reconstruction workflows. |
| `reconstruct_MEG.py` | Script for MEG data handling and reconstruction. |
| `create_project_readmes.sh` | Generates standardized README files within project directories. |


## SCAI Directory Structure Overview

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

Raw imaging data are organized within project-specific modality directories:

```
/data/storage/sourcedata/<project_name>/mri/
/data/storage/sourcedata/<project_name>/meg/
```

* `sourcedata` contains raw, unprocessed imaging data.
* `<project_name>` corresponds to the specific research project.
* This folder is intended to be accessed only by SCAI staff for data management and reconstruction.

---

### Shared/Reconstructed Project Directory (projects)

Reconstructed data is stored in:

```
/data/storage/projects/<project_name>/
```

* Contains copied, sorted and optionally BIDS-converted MRI and MEG data for the project.
* This folder is intended to be shared with project users.
* Permissions for these project directories can be managed on a per-user basis using ACLs and the `set_user_acl.sh` script.


---

# Getting Started

## 1. Dependencies

The SCAI workflow uses the following external software and packages. These scripts were developed for the SCAI server environment, where some dependencies may already be installed.

### Docker

 Docker is required for MRI refacing using `mri_reface`.

  - Download and unzip `mri_reface_0.3.5_docker.zip` from:
        https://www.nitrc.org/projects/mri_reface/

  - The script assumes the Docker image is located at:
  `/data/storage/software/mri_reface_docker/mri_reface_docker_image`

### DICOM/BIDS conversion tools

 The following tools must be installed and available in your environment:

  - `dicomsort` (install using: `pip install thedicomsort`)
  - `dcm2niix`
  - `dcm2bids`
  - `mne-bids` (installed automatically)

---

## 2. Creating a Project Directory in `sourcedata`

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

## 3. Uploading Raw Imaging Data

Uploaded raw data should be placed in the appropriate modality-specific directories within the project `sourcedata` folder:

```
/data/storage/sourcedata/<project_name>/mri/
/data/storage/sourcedata/<project_name>/meg/
```



**Note**: *These scripts were designed for the SCAI server environment and have been tested with the following naming conventions and directory structure:*
  * Subject IDs: `sub-BRS####`
  * `mri/` folder containing zipped MRI files per subject:
    `/data/storage/sourcedata/<project>/mri/sub-BRS####_YYYYMMDD.zip`

  * `meg/` folder organized by subject and session date:
    `/data/storage/sourcedata/<project>/meg/brs_####/YYYYMMDD/`

---

## 4. Data Preparation & BIDS Conversion

These tools support preparing data for broader sharing, including conversion to **BIDS (Brain Imaging Data Structure)**.

* BIDS improves data **accessibility, interoperability, and reproducibility**
* More information: [https://bids.neuroimaging.io](https://bids.neuroimaging.io)

**Note:** BIDS conversion and MRI refacing are optional. If either step is enabled, a corresponding project-specific configuration file must be created before running the workflow.

---
### 4.1. BIDS Configuration (optional)

A unique BIDS configuration file **must** be created for each project to correctly map DICOM files to the BIDS format, based on the specific sequences acquired and the naming conventions used in the DICOM headers.

* File name/location:

  ```
    /data/storage/software/config_files/<project>_config.json
  ```

---
### 4.2. MRI Refacing Configuration (optional)

A unique refacing mapping file **must** be created for each project, based on naming conventions and refacing requirements.

* File name/location:

  ```
  /data/storage/software/config_files/<project>_reface.txt
  ```

* Each line should contain a unique identifying substring found in the filenames to be refaced.
* Note: Other anatomical images not specified in the mapping file and all other modalities (e.g., fMRI, dwi) will not be refaced, but will be copied alongside the refaced files without modification. 

---
### 4.3. Run reconstruction

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

with optional BIDS conversion and MRI refacing.

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

* Copies MEG files from: 
  ```
  /data/storage/sourcedata/<project>/meg
  ```

  to:

  ```
  /data/storage/projects/<project>/meg/raw
  ```

---

#### Optional Processing Steps

| Flag               | Description                           |
| ------------------ | ------------------------------------- |
| `-b`, `--bids-mri` | Convert MRI data to BIDS format       |
| `-r`, `--reface`   | Run MRI refacing                      |
| `-g`, `--meg-copy` | Copy raw MEG data only                |
| `-m`, `--bids-meg` | Copy raw MEG data and convert to BIDS |

---

# User Permissions (ACLs)

ACL files are stored in:

```
/data/storage/software/user_permissions/
```

Each user has an ACL file defining access to project directories.

Format:

```
<project_name>:<permissions>
```

Permissions:

- `r` = read
- `w` = write
- `x` = execute
- `-` = no permission

Example:

```
project_1:rwx
project_2:r-x
```

---

## Notes
* The BIDS process **automatically creates a `participants.tsv` file**, which is populated with `n/a` values by default and **should not be relied upon**.
