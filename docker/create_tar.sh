#!/bin/bash

# Script to save Isaac Lab Docker image to tar file and check its size

if [ -f "isaac-lab-base.tar" ]; then
    echo "Removing existing tar file..."
    rm isaac-lab-base.tar
fi

echo "Saving isaac-lab-base:latest to tar file..."
docker save isaac-lab-base:latest -o isaac-lab-base.tar

echo "Checking size of the tar file..."
ls -lh isaac-lab-base.tar

echo "Do you want to send it to Hyak? (y/n)"
read -r response
if [[ "$response" == "y" || "$response" == "Y" ]]; then
    echo "Sending tar file to Hyak..."
    rsync -avz --progress isaac-lab-base.tar pareshrc@klone.hyak.uw.edu:/gscratch/socialrl/prc/adversarial_manipulation/isaaclab/docker
    echo "Transfer completed!"
else
    echo "Skipping transfer to Hyak."
fi

echo "Done!"