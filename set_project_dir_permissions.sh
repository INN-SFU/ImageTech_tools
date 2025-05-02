#!/bin/bash

###############################################################################
# Script Name: set_project_dir_permissions.sh
#
# Description:
#   This script sets up the 'sourcedata' directory with appropriate group
#   ownership, permissions, and ACLs, and creates a named subdirectory (e.g.,
#   "projects") within it. If the script is run with the 'reset' argument, it
#   resets the permissions and ACLs for all files and directories inside
#   the 'projects' directory.
#
# Usage:
#   ./set_project_dir_permissions.sh
#   (Optional: Edit the PROJECT_DIR variable to change the subdirectory name)
#   ./set_project_dir_permissions.sh reset  # to reset permissions of files inside projects
#
# Requirements:
#   - Run as a user in the group 'imgtech_server_staff'.
#
# Author: Leanne Rokos
###############################################################################

# Set project directory name
PROJECT_DIR="projects" #MODIFY
SOURCEDATA_DIR="sourcedata"
FULL_PROJECT_PATH="${SOURCEDATA_DIR}/${PROJECT_DIR}"

# Function to handle and report errors
fail() {
    echo "Error: $1" >&2
    exit 1
}

# Function to check command success
check_command() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        fail "Command failed: $*"
    fi
}

# Reset permissions function
reset_permissions() {
    echo "Resetting permissions and ACLs for everything inside '$FULL_PROJECT_PATH'..."

    # Set group ownership and ACLs for everything inside the 'projects' directory
    check_command chown -R :imgtech_server_staff "$FULL_PROJECT_PATH"
    check_command chmod -R 2770 "$FULL_PROJECT_PATH"
    check_command setfacl -R -d -m o::--- "$FULL_PROJECT_PATH"   # No access for others
    check_command setfacl -R -d -m g::rwx "$FULL_PROJECT_PATH"    # Group has rwx permission

    echo "Permissions and ACLs reset complete."
}

# Main logic
if [ "$1" == "reset" ]; then
    reset_permissions
    exit 0
fi

echo "Checking sourcedata directory..."
if [ -d "$SOURCEDATA_DIR" ]; then
    echo "Directory '$SOURCEDATA_DIR' already exists."
else
    echo "Creating '$SOURCEDATA_DIR'..."
    mkdir -p "$SOURCEDATA_DIR" || fail "Could not create $SOURCEDATA_DIR"
fi

echo "Setting group ownership and permissions for '$SOURCEDATA_DIR'..."
check_command chown :imgtech_server_staff "$SOURCEDATA_DIR"
check_command chmod 2770 "$SOURCEDATA_DIR"
check_command setfacl -d -m o::--- "$SOURCEDATA_DIR" # No access for others
check_command setfacl -d -m g::rwx "$SOURCEDATA_DIR" # Group permission rwx

echo "Checking project directory '${PROJECT_DIR}'..."
if [ -d "$FULL_PROJECT_PATH" ]; then
    echo "Directory '$FULL_PROJECT_PATH' already exists."
else
    echo "Creating '$FULL_PROJECT_PATH'..."
    mkdir -p "$FULL_PROJECT_PATH" || fail "Could not create $FULL_PROJECT_PATH"
fi

echo "Final directory listing:"
ls -ld "$SOURCEDATA_DIR"
ls -ld "$FULL_PROJECT_PATH"

echo
echo "Access control lists:"
getfacl "$SOURCEDATA_DIR"
getfacl "$FULL_PROJECT_PATH"

echo
echo "Setup complete."
