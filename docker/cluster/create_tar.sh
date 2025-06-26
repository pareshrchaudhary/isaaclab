#!/bin/bash

# Parse command line arguments
DOCKER_VOLUMES_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --docker-volumes)
            DOCKER_VOLUMES_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--docker-volumes]"
            exit 1
            ;;
    esac
done

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the target directory relative to the script location
TARGET_DIR="$SCRIPT_DIR/../../../hyak_transfer"
TAR_FILE="$TARGET_DIR/isaac-lab-base.tar"
DOCKER_VOLUMES_DIR="$SCRIPT_DIR/../../../docker_volumes"
HYAK_TRANSFER_DIR="/gscratch/socialrl/prc/adversarial_manipulation/"

# If only syncing docker volumes, skip tar creation
if [ "$DOCKER_VOLUMES_ONLY" = true ]; then
    echo "Syncing docker_volumes directory to Hyak only..."
    if [ -d "$DOCKER_VOLUMES_DIR" ]; then
        rsync -avz --progress --chmod=u=rwX,go=rX --ignore-errors "$DOCKER_VOLUMES_DIR" pareshrc@klone.hyak.uw.edu:"$HYAK_TRANSFER_DIR"
        echo "Docker volumes sync completed!"
    else
        echo "Error: docker_volumes directory not found at $DOCKER_VOLUMES_DIR"
        exit 1
    fi
    exit 0
fi

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

if [ -f "$TAR_FILE" ]; then
    echo "Removing existing tar file..."
    rm "$TAR_FILE"
fi

echo "Saving isaac-lab-base:latest to tar file..."
docker save isaac-lab-base:latest -o "$TAR_FILE"

echo "Checking size of the tar file..."
ls -lh "$TAR_FILE"

echo "Do you want to send it to Hyak? (y/n)"
read -r response
if [[ "$response" == "y" || "$response" == "Y" ]]; then
    echo "Checking if tar file exists on Hyak and removing if present..."
    ssh pareshrc@klone.hyak.uw.edu "rm -f '$HYAK_TRANSFER_DIR/hyak_transfer/isaac-lab-base.tar' && echo 'Tar file removed or not found on Hyak.'"
    
    echo "Sending Docker image tar to Hyak..."
    rsync -avz --progress "$TARGET_DIR" pareshrc@klone.hyak.uw.edu:"$HYAK_TRANSFER_DIR"
    
    if [ -d "$DOCKER_VOLUMES_DIR" ]; then
        echo "Syncing docker_volumes directory to Hyak..."
        rsync -avz --progress --chmod=u=rwX,go=rX --ignore-errors "$DOCKER_VOLUMES_DIR" pareshrc@klone.hyak.uw.edu:"$HYAK_TRANSFER_DIR"
    fi
    echo "Transfer completed!"
else
    echo "Skipping transfer to Hyak."
fi

echo "Done!"