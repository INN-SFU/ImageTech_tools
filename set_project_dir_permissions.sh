#!/bin/bash

###############################################################################
# Script Name: set_project_dir_permissions.sh
#
# Description:
#   This script creates the 'sourcedata' directory with appropriate group
#   ownership, permissions, and ACLs, and creates a named project subdirectory 
#   within it. If the script is run with the '--reset' argument, it
#   resets the permissions and ACLs for all files and directories inside
#   the project directory (i.e., to rwxrws---).
#
# Usage:
#   ./set_project_dir_permissions.sh <project_name>
#   ./set_project_dir_permissions.sh <project_name> --reset
#
# Requirements:
#   - Must be run by a user in the group 'imgtech_server_staff'.
#
# Author: Leanne Rokos
###############################################################################

SOURCEDATA_DIR="/data/storage/sourcedata_testing"

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

# Parse arguments
PROJECT_DIR="$1"
RESET_FLAG="$2"

if [[ -z "$PROJECT_DIR" ]]; then
    fail "No project directory specified. Usage: $0 <project_name> [--reset]"
fi

if [[ "$RESET_FLAG" == "--reset" ]]; then
    RESET_MODE=true
else
    RESET_MODE=false
fi

FULL_PROJECT_PATH="${SOURCEDATA_DIR}/${PROJECT_DIR}"

# Reset permissions function
reset_permissions() {
    echo "Resetting permissions and ACLs for everything inside '$FULL_PROJECT_PATH'..."

    check_command chown -R :imgtech_server_staff "$FULL_PROJECT_PATH"
    check_command chmod -R 2770 "$FULL_PROJECT_PATH"
    check_command setfacl -R -d -m o::--- "$FULL_PROJECT_PATH" # No access for others
    check_command setfacl -R -d -m g::rwx "$FULL_PROJECT_PATH" # Group has rwx permission

    echo "Permissions and ACLs reset complete."
}

# If reset flag is set, reset and exit
if [ "$RESET_MODE" = true ]; then
    reset_permissions
    exit 0
fi

# Main setup logic
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
check_command setfacl -d -m g::rwx "$SOURCEDATA_DIR" # Group has rwx permission

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
