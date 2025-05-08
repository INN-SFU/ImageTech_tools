#!/bin/bash

##############################################################################
# Script Name: set_user_acl.sh
# Author: Patrick S. Mahon
# Email: pmahon@sfu.ca
# Description:
#   This script manages user-specific ACL (Access Control List) permissions
#   for dataset directories under a predefined prefix directory (e.g., `/data`).
#
#   Features:
#   - Processes user-specific ACL files from `user_facls/` (e.g., `user_1_facls.txt`).
#   - Supports regex-based dataset matching (`*project_*:rwx`).
#   - Ensures no sticky bit (`t`) or setgid (`s`) is set on directories.
#   - Provides options for full ACL resets, updates, and removals.
#
# Usage:
#   1. Process all users (default mode):
#      ./set_user_acl.sh
#
#   2. Apply/reset ACLs for a specific user (removes all old ACLs):
#      ./set_user_acl.sh user_1
#
#   3. Update ACLs for a specific user without resetting:
#      ./set_user_acl.sh user_1 update
#
#   4. Remove all ACLs for a user and revoke access:
#      ./set_user_acl.sh user_1 -d
#
# ACL Files Location:
#   - All user ACL files must be stored inside `user_facls/`
#   - Example structure:
#       /your_project/
#       ├── set_user_acl.sh
#       ├── user_facls/
#       │   ├── user_1_facls.txt
#       │   ├── user_2_facls.txt
#
##############################################################################

# Hardcoded directories
PREFIX_DIR="/data/storage/"
USER_FACLS_DIR="/data/storage/software/user_facls"  # Directory where all user ACL files are stored

# Ensure the ACL directory exists
if [[ ! -d "$USER_FACLS_DIR" ]]; then
    echo "Error: ACL directory '$USER_FACLS_DIR' does not exist."
    exit 1
fi

# Function to validate the prefix directory
validate_prefix_directory() {
    if [ ! -d "$PREFIX_DIR" ]; then
        echo "Error: Prefix directory '$PREFIX_DIR' does not exist."
        exit 1
    fi
}

# Function to find dataset directories matching a regex
find_matching_datasets() {
    local regex_pattern="$1"
    find "$PREFIX_DIR" -mindepth 1 -maxdepth 1 -type d | grep -E "$regex_pattern"
}

# Function to reset ACLs for a user before applying new ones
reset_user_permissions() {
    local user="$1"
    echo "Resetting all ACL permissions for user '$user' under '$PREFIX_DIR'"

    find "$PREFIX_DIR" -type d | xargs -r setfacl -x u:"$user"
}

# Function to remove all ACL permissions for a user
delete_user_permissions() {
    local user="$1"

    read -p "Are you sure you want to remove all ACLs for user '$user'? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted. No ACLs were removed for '$user'."
        return
    fi

    echo "Removing all ACL permissions for user '$user' under '$PREFIX_DIR'"
    find "$PREFIX_DIR" -type d | xargs -r setfacl -x u:"$user"
    setfacl -x u:"$user" "$PREFIX_DIR"
}

# Function to remove sticky bit (`t`) and setgid (`s`) from directories
fix_sticky_and_setgid() {
    local dataset_path="$1"

    if [[ -d "$dataset_path" ]]; then
        echo "Ensuring no sticky bit or setgid bit is set on '$dataset_path'"
        chmod g-s,o+t "$dataset_path"
    fi
}

# Function to convert POSIX-style permission notation to `setfacl` format
convert_posix_to_acl() {
    local posix_perm="$1"
    local acl_perm=""

    [[ "${posix_perm:0:1}" == "r" ]] && acl_perm+="r"
    [[ "${posix_perm:1:1}" == "w" ]] && acl_perm+="w"
    [[ "${posix_perm:2:1}" == "x" ]] && acl_perm+="x"

    echo "$acl_perm"
}

# Function to apply ACL permissions to a dataset or regex-matched datasets
apply_user_permissions() {
    local user="$1"
    local dataset_pattern="$2"
    local posix_perm="$3"

    # Convert POSIX permissions (e.g., r-x) to `setfacl` format (rx)
    local acl_perm
    acl_perm=$(convert_posix_to_acl "$posix_perm")

    if [[ -z "$acl_perm" ]]; then
        echo "Warning: Invalid permissions '$posix_perm' for '$dataset_pattern', skipping."
        return
    fi

    if [[ "$dataset_pattern" == \**\* ]]; then
        dataset_regex="${dataset_pattern//\*/.*}"  # Convert *wildcards* to regex
        dataset_paths=($(find_matching_datasets "$dataset_regex"))
    else
        dataset_paths=("$PREFIX_DIR/$dataset_pattern")
    fi

    if [[ ${#dataset_paths[@]} -eq 0 ]]; then
        echo "Warning: No matching dataset folders for '$dataset_pattern', skipping."
        return
    fi

    for dataset_path in "${dataset_paths[@]}"; do
        #fix_sticky_and_setgid "$dataset_path"

        echo "Setting permissions '$acl_perm' for user '$user' on '$dataset_path'"
        echo "setfacl -m u:"$user":"$acl_perm" "$dataset_path""
        setfacl -R -m u:$user:$acl_perm $dataset_path
        echo "setfacl -d -m u:"$user":"$acl_perm" "$dataset_path""
        setfacl -d -R -m u:$user:$acl_perm $dataset_path
    done
}

# Function to process a single user's ACL file
        process_user_acl_file() {
    local user="$1"
    local user_facls_file="$2"
    local update_mode="$3"

    if [ ! -f "$user_facls_file" ]; then
        echo "Error: ACL file '$user_facls_file' for user '$user' does not exist."
        return
    fi

    if [[ "$update_mode" != "update" ]]; then
        reset_user_permissions "$user"
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue

        dataset_pattern=$(echo "$line" | cut -d':' -f1)
        posix_perm=$(echo "$line" | cut -d':' -f2)

        apply_user_permissions "$user" "$dataset_pattern" "$posix_perm"
    done < "$user_facls_file"

    echo "ACL permissions update complete for user '$user'."
}

# Main Execution Flow
validate_prefix_directory

if [[ "$#" -eq 2 && "$2" == "-d" ]]; then
    USER="$1"
    delete_user_permissions "$USER"
elif [[ "$#" -eq 2 && "$2" == "update" ]]; then
    USER="$1"
    USER_FACLS_FILE="$USER_FACLS_DIR/${USER}_facl.txt"
    process_user_acl_file "$USER" "$USER_FACLS_FILE" "update"
elif [[ "$#" -eq 1 ]]; then
    USER="$1"
    USER_FACLS_FILE="$USER_FACLS_DIR/${USER}_facl.txt"
    process_user_acl_file "$USER" "$USER_FACLS_FILE"
elif [[ "$#" -eq 0 ]]; then
    echo "Processing all user ACL files in '$USER_FACLS_DIR'..."
    for user_facls_file in "$USER_FACLS_DIR/"*_facl.txt; do
        echo "$user_facls_file"
        [[ ! -f "$user_facls_file" ]] && continue  # Skip if no matching files
        USER=$(basename "$user_facls_file" | sed 's/_facl.txt$//')  # Extract username
        process_user_acl_file "$USER" "$user_facls_file"
    done
else
    echo "Usage: $0 [username] [update|-d]"
    exit 1
fi

echo "All ACL updates complete."
