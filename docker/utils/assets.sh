#!/bin/bash

# Isaac Sim Asset Setup Script
# This script extracts Isaac Sim assets to the correct location for Docker usage
set -e  # Exit on any error

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
ASSETS_DIR="$PROJECT_ROOT/docker_volumes/assets"
DOWNLOADS_DIR="$HOME/downloads"

echo "Project root: $PROJECT_ROOT"
echo "Assets target directory: $ASSETS_DIR"
echo "Downloads directory: $DOWNLOADS_DIR"
echo

# Check if assets already exist in the correct nested structure
ISAAC_ASSETS_PATH="$ASSETS_DIR/Assets/Isaac/4.5"
if [ -d "$ISAAC_ASSETS_PATH/NVIDIA" ] && [ -d "$ISAAC_ASSETS_PATH/Isaac" ]; then
    echo "Isaac Sim assets already exist at: $ISAAC_ASSETS_PATH"
    echo "   You can proceed with running Isaac Sim."
    exit 0
fi

echo "Isaac Sim assets not found at: $ISAAC_ASSETS_PATH"
echo

# Find asset files in Downloads directory (more flexible version detection)
echo "Searching for Isaac Sim asset files..."
ASSET_FILES=()
for file in "$DOWNLOADS_DIR"/isaac-sim-assets-*.zip; do
    if [ -f "$file" ]; then
        ASSET_FILES+=("$(basename "$file")")
    fi
done

if [ ${#ASSET_FILES[@]} -eq 0 ]; then
    echo "No Isaac Sim asset files found in Downloads directory: $DOWNLOADS_DIR"
    echo
    echo "Please download the Isaac Sim asset files from:"
    echo "   https://docs.isaacsim.omniverse.nvidia.com/4.5.0/installation/install_faq.html#isaac-sim-setup-assets-content-pack"
    echo
    echo "   Place them in: $DOWNLOADS_DIR"
    echo "   Expected files: isaac-sim-assets-1@*.zip, isaac-sim-assets-2@*.zip, isaac-sim-assets-3@*.zip"
    echo
    exit 1
fi

echo "Found ${#ASSET_FILES[@]} asset files:"
for file in "${ASSET_FILES[@]}"; do
    echo "   - $file"
done
echo

# Create the target directory structure
echo "Creating target directory structure..."
mkdir -p "$ASSETS_DIR"
echo "   Created: $ASSETS_DIR"
echo

# Extract assets
echo "Extracting Isaac Sim asset packs..."
cd "$DOWNLOADS_DIR"

for i in "${!ASSET_FILES[@]}"; do
    file="${ASSET_FILES[$i]}"
    current=$((i + 1))
    total=${#ASSET_FILES[@]}
    echo "   [$current/$total] Extracting: $file"
    
    # Get file size for progress indication
    file_size=$(du -h "$file" | cut -f1)
    echo "   File size: $file_size"
    
    # Get total number of files in archive for percentage calculation
    total_files=$(unzip -l "$file" 2>/dev/null | tail -n1 | awk '{print $2}' | tr -d ' ')
    echo "   Total files: $total_files"
    
    # Extract with percentage progress
    echo -n "   Progress: 0%"
    unzip -o "$file" -d "$ASSETS_DIR" >/dev/null 2>&1 &
    unzip_pid=$!
    
    # Monitor extraction progress
    start_time=$(date +%s)
    while kill -0 $unzip_pid 2>/dev/null; do
        sleep 1
        
        # Count extracted files (approximate progress)
        if [ -d "$ASSETS_DIR" ]; then
            extracted_files=$(find "$ASSETS_DIR" -type f 2>/dev/null | wc -l)
            if [ "$total_files" -gt 0 ]; then
                percentage=$((extracted_files * 100 / total_files))
                if [ $percentage -gt 100 ]; then percentage=100; fi
                printf "\r   Progress: %d%%" $percentage
            else
                # Fallback to time-based estimation if file count fails
                elapsed=$(($(date +%s) - start_time))
                printf "\r   Progress: %ds elapsed" $elapsed
            fi
        fi
    done
    
    wait $unzip_pid
    printf "\r   Progress: 100%% ✓ Completed\n"
done

echo "Asset extraction complete"
echo

# Ensure proper nested structure exists
echo "Ensuring proper asset directory structure..."
mkdir -p "$ISAAC_ASSETS_PATH"

# Check if assets were extracted to the root level and need to be moved
if [ -d "$ASSETS_DIR/NVIDIA" ] && [ -d "$ASSETS_DIR/Isaac" ] && [ ! -d "$ISAAC_ASSETS_PATH/NVIDIA" ]; then
    echo "   Moving assets to proper nested structure..."
    mv "$ASSETS_DIR/NVIDIA" "$ISAAC_ASSETS_PATH/" 2>/dev/null || true
    mv "$ASSETS_DIR/Isaac" "$ISAAC_ASSETS_PATH/" 2>/dev/null || true
    # Move any other files that might be at root level
    find "$ASSETS_DIR" -maxdepth 1 -type f -exec mv {} "$ISAAC_ASSETS_PATH/" \; 2>/dev/null || true
    echo "   Assets moved to: $ISAAC_ASSETS_PATH"
fi
echo

# Verify the extraction
echo "Verifying asset structure..."
if [ -d "$ISAAC_ASSETS_PATH/NVIDIA" ] && [ -d "$ISAAC_ASSETS_PATH/Isaac" ]; then
    echo "Assets extracted successfully!"
    echo "   - NVIDIA folder: $(ls -1 "$ISAAC_ASSETS_PATH/NVIDIA" | wc -l) items"
    echo "   - Isaac folder: $(ls -1 "$ISAAC_ASSETS_PATH/Isaac" | wc -l) items"
    echo
    echo "Isaac Sim assets are ready for use!"
    echo "   Location: $ISAAC_ASSETS_PATH"
else
    echo "Asset extraction failed - missing required folders"
    echo "   Expected: $ISAAC_ASSETS_PATH/NVIDIA and $ISAAC_ASSETS_PATH/Isaac"
    echo "   Found: $(ls -la "$ASSETS_DIR" 2>/dev/null || echo "Directory not found")"
    echo
    echo "Trying to debug the structure..."
    find "$ASSETS_DIR" -maxdepth 4 -type d | head -20
    exit 1
fi