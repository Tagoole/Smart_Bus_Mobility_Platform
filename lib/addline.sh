#!/bin/bash

# Script to add an empty line at the bottom of every file in a specified folder
# and commit each file individually
# Usage: ./add_empty_line.sh [folder_path]

# Set the target folder (default to current directory if no argument provided)
TARGET_FOLDER="${1:-.}"

# Check if the folder exists
if [ ! -d "$TARGET_FOLDER" ]; then
    echo "Error: Folder '$TARGET_FOLDER' does not exist."
    exit 1
fi

echo "Adding empty line to all files in: $TARGET_FOLDER"

# Find all files (not directories) in the target folder and process them
find "$TARGET_FOLDER" -type f -print0 | while IFS= read -r -d '' file; do
    # Add empty line to the file
    echo "" >> "$file"
    echo "Added empty line to: $file"
    
    # Add and commit the file
    git add "$file"
    git commit -m "Add empty line to $(basename "$file")"
    echo "Committed: $file"
done

echo "Done!"



