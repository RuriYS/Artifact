#!/bin/bash

usage() {
    echo "artifact.sh - File artifacting utility"
    echo
    echo "Description:"
    echo "  Creates a collection of files by copying them from their source"
    echo "  locations into a single flat directory structure."
    echo
    echo "Usage: $0 [src] [artifacts]"
    echo "  src:        Optional. Directory to search for files (default: current directory)"
    echo "  artifacts:  Optional. File containing list of files to copy (default: .artifacts)"
    echo
    echo "Special Commands:"
    echo "  $0 clear    Remove the artifacts directory"
    echo
    echo "Examples:"
    echo "  $0                      # Use current directory and default .artifacts file"
    echo "  $0 /path/to/project     # Search in specific directory"
    echo "  $0 . custom-artifacts   # Use custom artifacts list file"
    echo "  $0 clear                # Remove artifacts directory"
    echo
    exit 1
}

# Clear artifacts function
clear_artifacts() {
    local output_dir="artifacts"
    if [ ! -d "$output_dir" ]; then
        echo "No artifacts directory found."
        exit 0
    fi

    # Count files in artifacts directory
    local file_count=$(find "$output_dir" -type f | wc -l)

    echo "This will remove the artifacts directory containing $file_count files."
    read -p "Are you sure you want to continue? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$output_dir"
        echo "Artifacts directory removed."
    else
        echo "Operation cancelled."
    fi
    exit 0
}

# Parse arguments
source_dir="."
artifacts_file=".artifacts"

# Handle special commands first
if [ "$1" = "help" ]; then
    usage
elif [ "$1" = "clear" ]; then
    clear_artifacts
fi

case $# in
    0) ;;
    1) source_dir="$1" ;;
    2) source_dir="$1"; artifacts_file="$2" ;;
    *) usage ;;
esac

if [ ! -f "$artifacts_file" ]; then
    echo "$artifacts_file does not exist, creating it..."
    echo "Check the created $artifacts_file file for usage instructions"
    {
        echo "# Artifacts Configuration File"
        echo "# ---------------------------"
        echo "# Each line can be either:"
        echo "#   1. A specific path relative to source directory"
        echo "#   2. Just a filename to search for recursively"
        echo "#"
        echo "# Examples with specific paths (relative to source):"
        echo "# docs/README.md              # Only looks in docs directory"
        echo "# src/lib/utils.js           # Only looks in src/lib directory"
        echo "# config/settings.json       # Only looks in config directory"
        echo "#"
        echo "# Examples with filenames (searched recursively):"
        echo "# README.md                  # Finds all README.md files"
        echo "# .env                      # Finds all .env files"
        echo "# config.json              # Finds all config.json files"
        echo "#"
        echo "# Lines starting with # are ignored"
        echo
    } >> "$artifacts_file"
    echo
    usage
fi

# Check if source directory exists
if [ ! -d "$source_dir" ]; then
    echo "Error: Source directory '$source_dir' not found"
    exit 1
fi

output_dir="artifacts"
mkdir -p "$output_dir"
copied_count=0
conflict_count=0

while IFS= read -r file || [ -n "$file" ]; do
    # Skip empty lines and comments
    [[ -z "$file" || "$file" =~ ^[[:space:]]*# ]] && continue

    # Remove any leading/trailing whitespace
    file=$(echo "$file" | xargs)

    # If the file contains a path separator, treat it as a specific path
    if [[ "$file" == *"/"* ]]; then
        full_path="$source_dir/$file"
        if [ -f "$full_path" ]; then
            filename=$(basename "$full_path")
            # Handle filename conflicts
            if [ -f "$output_dir/$filename" ]; then
                new_filename="${filename%.*}_$((++conflict_count)).${filename##*.}"
                echo "Warning: File conflict, renaming to $new_filename"
                filename="$new_filename"
            fi
            cp "$full_path" "$output_dir/$filename"
            echo "$full_path -> $output_dir/$filename"
            ((copied_count++))
        else
            echo "Warning: Specific file not found: $file"
        fi
    else
        # Find the file recursively in the source directory
        while IFS= read -r found_file; do
            # Skip if find returned nothing
            [ -z "$found_file" ] && continue

            filename=$(basename "$found_file")
            # Handle filename conflicts
            if [ -f "$output_dir/$filename" ]; then
                new_filename="${filename%.*}_$((++conflict_count)).${filename##*.}"
                echo "Warning: File conflict, renaming to $new_filename"
                filename="$new_filename"
            fi
            cp "$found_file" "$output_dir/$filename"
            echo "$found_file -> $output_dir/$filename"
            ((copied_count++))
        done < <(find "$source_dir" -type f -name "$file" -not -path "./artifacts/*" 2>/dev/null)
    fi
done < "$artifacts_file"

echo
echo "Summary:"
echo "- Created $copied_count artifacts in $output_dir/"
if [ $conflict_count -gt 0 ]; then
    echo "- Renamed $conflict_count files due to naming conflicts"
fi