#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

print_info() { echo -e "${GREEN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }

# Usage message - replace the current usage() function
usage() {
    echo -e "${YELLOW}"
    echo "Usage: $0 [src] [config]"
    echo "  src               Source directory (default: current directory)"
    echo "  config            Artifact config  (default: .artifacts)"
    echo
    echo "Commands:"
    echo "  $0 clear      Remove artifacts directory"
    echo -e "${NC}"
    exit 1
}

# Replace clear_artifacts() with simpler version
clear_artifacts() {
    if [ ! -d "artifacts" ]; then
        print_error "No artifacts directory found."
        exit 0
    fi
    rm -rf "artifacts"
    print_info "Artifacts directory removed."
    exit 0
}

# Initialize metadata JSON
init_metadata() {
    echo '{
  "created_at": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'",
  "source_directory": "'"$(realpath "$source_dir")"'",
  "artifacts": []
}' >"$output_dir/metadata.json"
}

# Get file size in bytes
get_file_size() {
    local file="$1"
    if [ -f "$file" ]; then
        du -b "$file" | cut -f1
    else
        echo "0"
    fi
}

get_file_type() {
    local file="$1"
    local ext="${file##*.}"
    case "$ext" in
    js) echo "text/javascript" ;;
    css) echo "text/css" ;;
    html) echo "text/html" ;;
    json) echo "application/json" ;;
    md) echo "text/markdown" ;;
    txt) echo "text/plain" ;;
    *) file --mime-type -b "$file" 2>/dev/null || echo "application/octet-stream" ;;
    esac
}

# Add entry to metadata JSON
# Parameters: configname original_path file_size file_type
add_to_metadata() {
    local filename="$1"
    local path="$2"
    local size="$3"
    local type="$4"

    jq --arg f "$filename" \
        --arg p "$(realpath "$path")" \
        --arg s "$size" \
        --arg t "$type" \
        '.artifacts += [{
           "filename": $f,
           "original_path": $p,
           "size_bytes": $s | tonumber,
           "type": $t
       }]' "$output_dir/metadata.json" >"$output_dir/metadata_temp.json"

    mv "$output_dir/metadata_temp.json" "$output_dir/metadata.json"
}

# Parse arguments
source_dir="."
config=".artifacts"

# Handle special commands first
if [ "$1" = "help" ]; then
    usage
elif [ "$1" = "clear" ]; then
    clear_artifacts
fi

case $# in
0) ;;
1) source_dir="$1" ;;
2)
    source_dir="$1"
    config="$2"
    ;;
*) usage ;;
esac

# Check if jq is installed
if ! command -v jq &>/dev/null; then
    print_error "This script requires 'jq' for JSON processing."
    print_info "Please install jq using your package manager."
    print_info "For example: 'sudo apt install jq' or 'brew install jq'"
    exit 1
fi

# Check if config exists
if [ ! -f "$config" ]; then
    print_info "$config does not exist, creating it..."
    {
        echo "# List files to copy, one per line:"
        echo "# - Specific path: src/file.js"
        echo "# - Any file: filename.txt"
        echo
    } >"$config"
    usage
fi

# Check if source directory exists
if [ ! -d "$source_dir" ]; then
    print_error "Source directory '$source_dir' not found"
    exit 1
fi

output_dir="artifacts"
mkdir -p "$output_dir"
copied_count=0

# Initialize metadata file
init_metadata

while IFS= read -r file || [ -n "$file" ]; do
    # Skip comments and empty lines
    [[ -z "$file" || "$file" =~ ^[[:space:]]*# ]] && continue
    file=$(echo "$file" | xargs)

    if [[ "$file" == *"/"* ]]; then
        # Copy specific file
        full_path="$source_dir/$file"
        [ ! -f "$full_path" ] && print_warning "Not found: $file" && continue

        filename=$(basename "$full_path")
        cp "$full_path" "$output_dir/$filename"
        add_to_metadata "$filename" "$full_path" "$(get_file_size "$full_path")" "$(get_file_type "$full_path")"
        print_info "Copied: $full_path"
        ((copied_count++))
    else
        # Copy found files
        while IFS= read -r found_file; do
            [ -z "$found_file" ] && continue
            filename=$(basename "$found_file")
            cp "$found_file" "$output_dir/$filename"
            add_to_metadata "$filename" "$found_file" "$(get_file_size "$found_file")" "$(get_file_type "$found_file")"
            print_info "Copied: $found_file"
            ((copied_count++))
        done < <(find "$source_dir" -type f -name "$file" -not -path "./artifacts/*" 2>/dev/null)
    fi
done <"$config"

# Summary
echo
print_info "- Created $copied_count artifacts in $output_dir/"
print_info "- Generated metadata in $output_dir/metadata.json"
