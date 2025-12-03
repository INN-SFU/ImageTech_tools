#!/bin/bash

###############################################################################
# Script Name: set_sourcedata_permissions.sh
#
# Description:
#   This script creates the 'sourcedata' directory with appropriate group
#   ownership, permissions, and ACLs, and creates a named project subdirectory
#   within it. Optional flags allow creation of 'mri' and/or 'meg' subfolders.
#   If run with '--reset', it resets the permissions and ACLs recursively.
#
# Usage:
#   ./set_sourcedata_permissions.sh <project_name>
#   ./set_sourcedata_permissions.sh <project_name> --reset
#   ./set_sourcedata_permissions.sh <project_name> [--mri|--meg|--both]
#
# Requirements:
#   - Must be run by a user in the group 'imgtech_server_staff'.
#
# Author: Leanne Rokos
###############################################################################

SOURCEDATA_DIR="/data/storage/sourcedata"

usage() {
    echo "Usage: $0 <project_name> [--reset] [--mri] [--meg] [--both]"
    echo
    echo "Options:"
    echo "  --reset        Reset permissions and ACLs recursively inside the project directory."
    echo "  --mri          Create an 'mri' subdirectory inside the /data/storage/sourcedata/<project> directory."
    echo "  --meg          Create a 'meg' subdirectory inside the /data/storage/sourcedata/<project> directory."
    echo "  --both         Create both 'mri' and 'meg' subdirectories."
    echo
    echo "Example:"
    echo "  $0 MyProject --mri --meg"
    echo "  $0 MyProject --reset"
    exit 1
}

# Functions
fail() {
    echo "Error: $1" >&2
    exit 1
}

check_command() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        fail "Command failed: $*"
    fi
}

# Parse arguments
PROJECT_DIR="$1"
shift

# Validate project name
if [[ -z "$PROJECT_DIR" || "$PROJECT_DIR" == --* ]]; then
    echo "Error: You must specify a valid <project_name> as the first argument."
    usage
fi

# Defaults
RESET_MODE=false
CREATE_MRI=false
CREATE_MEG=false

# Parse optional flags
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --reset) RESET_MODE=true ;;
        --mri) CREATE_MRI=true ;;
        --meg) CREATE_MEG=true ;;
        --both) CREATE_MRI=true; CREATE_MEG=true ;;
        *) usage ;;
    esac
    shift
done

# Request sudo access and keep it alive
echo "Requesting sudo access..."
sudo -v || fail "Sudo access is required to run this script."
# Keep sudo session alive until the script exits
while true; do sudo -v; sleep 60; done &
KEEP_SUDO_ALIVE_PID=$!
# Kill the keep-alive loop on exit
trap "kill $KEEP_SUDO_ALIVE_PID 2>/dev/null" EXIT

FULL_PROJECT_PATH="${SOURCEDATA_DIR}/${PROJECT_DIR}"

# Resetting permissions
reset_permissions() {
    echo "Resetting permissions and ACLs for everything inside '$FULL_PROJECT_PATH'..."

    check_command sudo chown -R :imgtech_server_staff "$FULL_PROJECT_PATH"
    check_command sudo chmod -R 2770 "$FULL_PROJECT_PATH"
    check_command sudo setfacl -R -d -m o::--- "$FULL_PROJECT_PATH"
    check_command sudo setfacl -R -d -m g::rwx "$FULL_PROJECT_PATH"

    echo "Permissions and ACLs reset complete."
}

# Handle --reset:  If reset flag is set, reset and exit
if [ "$RESET_MODE" = true ]; then
    reset_permissions
    exit 0
fi

# Main setup logic
echo "Checking sourcedata directory..."
if [ ! -d "$SOURCEDATA_DIR" ]; then
    echo "Creating '$SOURCEDATA_DIR'..."
    mkdir -p "$SOURCEDATA_DIR" || fail "Could not create $SOURCEDATA_DIR"
fi

echo "Setting group ownership and permissions for '$SOURCEDATA_DIR'..."
check_command sudo chown :imgtech_server_staff "$SOURCEDATA_DIR"
check_command sudo chmod 2770 "$SOURCEDATA_DIR"
check_command sudo setfacl -d -m o::--- "$SOURCEDATA_DIR"
check_command sudo setfacl -d -m g::rwx "$SOURCEDATA_DIR"

echo "Checking project directory '${PROJECT_DIR}'..."
if [ ! -d "$FULL_PROJECT_PATH" ]; then
    echo "Creating '$FULL_PROJECT_PATH'..."
    mkdir -p "$FULL_PROJECT_PATH" || fail "Could not create $FULL_PROJECT_PATH"
fi

# Create subdirectories if requested
if [ "$CREATE_MRI" = true ]; then
    if [ -d "${FULL_PROJECT_PATH}/mri" ]; then
        echo "MRI folder already exists at '${FULL_PROJECT_PATH}/mri', skipping creation."
    else
        echo "Creating MRI folder..."
        mkdir -p "${FULL_PROJECT_PATH}/mri" || fail "Failed to create mri folder"
    fi
fi

if [ "$CREATE_MEG" = true ]; then
    if [ -d "${FULL_PROJECT_PATH}/meg" ]; then
        echo "MEG folder already exists at '${FULL_PROJECT_PATH}/meg', skipping creation."
    else
        echo "Creating MEG folder..."
        mkdir -p "${FULL_PROJECT_PATH}/meg" || fail "Failed to create meg folder"
    fi
fi

# Final status
echo "Final directory listing:"
ls -ld "$SOURCEDATA_DIR"
ls -ld "$FULL_PROJECT_PATH"
[ -d "${FULL_PROJECT_PATH}/mri" ] && ls -ld "${FULL_PROJECT_PATH}/mri"
[ -d "${FULL_PROJECT_PATH}/meg" ] && ls -ld "${FULL_PROJECT_PATH}/meg"


echo "Access control lists:"
getfacl "$SOURCEDATA_DIR"
getfacl "$FULL_PROJECT_PATH"
[ -d "${FULL_PROJECT_PATH}/mri" ] && getfacl "${FULL_PROJECT_PATH}/mri"
[ -d "${FULL_PROJECT_PATH}/meg" ] && getfacl "${FULL_PROJECT_PATH}/meg"


echo "Setup complete."
