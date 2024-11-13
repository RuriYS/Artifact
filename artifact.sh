#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

print_info() { echo -e "${GREEN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }

# Usage
usage() {
    echo "Usage: $0 [options] [src] [config]"
    echo
    echo "Options:"
    echo "  -h, --help             Show this help message"
    echo "  -v, --verbose          Enable verbose output"
    echo "  -c, --clear            Clear existing artifacts"
    echo "  -d, --dry-run          Show what would be copied without copying"
    echo "  -f, --force            Overwrite existing artifacts directory"
    echo "  -o, --output DIR       Specify output directory (default: artifacts)"
    echo
    echo "Arguments:"
    echo "  src                    Source directory (default: current directory)"
    echo "  config                 Artifact config  (default: .artifacts)"
    echo
    echo "Config Format: (gitignore syntax)"
    echo "  - app/*.php            Match all PHP files in app directory"
    echo "  - resources/**/*.tsx   Match all TSX files recursively in resources"
    echo "  - *.json              Match all JSON files in root"
    echo "  - !vendor             Exclude vendor directory"
    echo
    echo "Commands:"
    echo "  $0 clear               Remove artifacts directory"
    exit 1
}

clear_artifacts() {
    local dir="${1:-artifacts}"

    if [ ! -d "$dir" ]; then
        print_warning "Directory '$dir' not found."
        return 0
    fi

    local file_count=$(find "$dir" -type f -not -name "metadata.json" | wc -l)

    if [ "$file_count" -eq 0 ]; then
        print_warning "No artifacts found in '$dir'."
        return 0
    fi

    find "$dir" -type f -not -name ".gitkeep" -exec rm -f {} +
    find "$dir" -mindepth 1 -type d -empty -delete

    print_info "Removed $file_count artifacts from '$dir'."
    return 0
}

# Initialize metadata JSON
init_metadata() {
    echo '{
  "created_at": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'",
  "source_directory": "'"$(realpath "$source_dir")"'",
  "artifacts": []
}' >"$output_dir/metadata.json"
}

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
    php) echo "text/x-php" ;;
    tsx | jsx) echo "text/typescript-jsx" ;;
    *) file --mime-type -b "$file" 2>/dev/null || echo "application/octet-stream" ;;
    esac
}

# Add entry to metadata JSON
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

# Convert glob pattern to find pattern
convert_pattern() {
    local pattern="$1"
    # Remove leading ./ if present
    pattern="${pattern#./}"
    # Handle ** recursive matching
    pattern="${pattern//\*\*/*}"
    # Handle remaining * matching
    pattern="${pattern//\*/[^/]*}"
    # Handle ? matching
    pattern="${pattern//\?/.}"
    echo "$pattern"
}

# Parse command line arguments using getopt
TEMP=$(getopt -o hvdcfo: --long help,verbose,dry-run,clear,force,output: -n "$0" -- "$@")
if [ $? != 0 ]; then
    echo "Failed to parse arguments. Use --help for usage information."
    exit 1
fi

eval set -- "$TEMP"

# Default values
source_dir="."
config=".artifacts"
output_dir="artifacts"
verbose=false
dry_run=false
force=true
clear=true

# Process options
while true; do
    case "$1" in
    -h | --help)
        usage
        ;;
    -v | --verbose)
        verbose=true
        shift
        ;;
    -d | --dry-run)
        dry_run=true
        shift
        ;;
    -c | --clear)
        clear=true
        shift
        ;;
    -f | --force)
        force=true
        shift
        ;;
    -o | --output)
        output_dir="$2"
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *)
        print_error "Internal error!"
        exit 1
        ;;
    esac
done

# Handle remaining arguments
case $# in
0) ;;
1) source_dir="$1" ;;
2)
    source_dir="$1"
    config="$2"
    ;;
*) usage ;;
esac

# Handle special commands
if [ "$1" = "clear" ]; then
    clear_artifacts
    exit 0
fi

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
        echo "# Syntax (.gitignore syntax):"
        echo "# - app/*.php            Match all PHP files in app directory"
        echo "# - resources/**/*.tsx   Match all TSX files recursively in resources"
        echo "# - *.json              Match all JSON files in root"
        echo "# - !vendor             Exclude vendor directory"
        echo
    } >"$config"
    usage
fi

# Check if source directory exists
if [ ! -d "$source_dir" ]; then
    print_error "Source directory '$source_dir' not found"
    exit 1
fi

# Check if output directory exists and handle force flag
if [ -d "$output_dir" ] && [ "$force" = false ]; then
    print_error "Output directory '$output_dir' already exists. Use --force to overwrite."
    exit 1
fi

# Clear artifacts
if [ "$clear" = true ]; then
    clear_artifacts "$output_dir"
fi

# Create output directory if not in dry-run mode
if [ "$dry_run" = false ]; then
    mkdir -p "$output_dir"
    init_metadata
fi

copied_count=0
declare -a exclude_patterns=()
declare -a include_patterns=()

# First pass: collect patterns
while IFS= read -r pattern || [ -n "$pattern" ]; do
    # Skip comments and empty lines
    [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
    pattern=$(echo "$pattern" | xargs)

    if [[ "$pattern" == "!"* ]]; then
        # Handle exclude pattern
        exclude_patterns+=("${pattern#!}")
    else
        # Handle include pattern
        include_patterns+=("$pattern")
    fi
done <"$config"

# Process files based on patterns
process_files() {
    local file="$1"
    local base_name=$(basename "$file")

    # Check exclude patterns first
    for exclude in "${exclude_patterns[@]}"; do
        if [[ "$file" =~ $(convert_pattern "$exclude") ]]; then
            return
        fi
    done

    # Process file if it matches any include pattern
    if [ "$dry_run" = true ]; then
        print_info "[DRY RUN] $file -> $output_dir/$base_name"
    else
        cp "$file" "$output_dir/$base_name"
        add_to_metadata "$base_name" "$file" "$(get_file_size "$file")" "$(get_file_type "$file")"
        if [[ "$verbose" = true ]]; then
            print_info "$file -> $output_dir/$base_name"
        fi
    fi
    ((copied_count++))
}

# Second pass: process files
for pattern in "${include_patterns[@]}"; do
    find_pattern=$(convert_pattern "$pattern")
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        process_files "$file"
    done < <(find "$source_dir" -type f -path "./$find_pattern" -not -path "./artifacts/*" 2>/dev/null)
done

# Summary
if [ "$dry_run" = true ]; then
    print_info "- Would create $copied_count artifacts in $output_dir/"
    print_info "- Would generate metadata in $output_dir/metadata.json"
else
    if [[ "$verbose" = true ]]; then
        echo
    fi
    print_info "- Created $copied_count artifacts in $output_dir/"
    print_info "- Generated metadata in $output_dir/metadata.json"
fi
