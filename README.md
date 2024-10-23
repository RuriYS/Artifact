# Artifact

A utility script for creating and artifacts

This script helps maintain a curated set of files (artifacts) by copying them
from their original locations while preserving their names. It's useful for:

- Creating backups of specific files
- Preparing files for distribution
- Maintaining a collection of important documents
- Collecting files scattered across different directories

## Usage

```sh
   artifact.sh [src] [artifacts]

   artifact.sh help               Shows help obviously
   artifact.sh clear              Remove artifacts directory
```

## Parameters

   `src`       - Optional. Root directory to search for files
                 Default: Current directory (.)

   `artifacts` - Optional. Path to the artifacts configuration file
                Default: .artifacts

   `clear`     - Special command to remove the artifacts directory

Configuration File (`.artifacts`):
The script uses a text file to specify which files to collect.
Each line can be either:

1. Just a filename to search for recursively: `README.md`
2. A specific path relative to source directory: `docs/README.md`

```sh
 script.js                         Will only look for script.js
 docs/README.md                    Will only look in docs directory
 src/lib/utils.js                  Will only look in src/lib directory
```

## Examples

Filenames (searched recursively)

```sh
 README.md                         Will find all README.md files
 .env                              Will find all .env files
 config.json                       Will find all config.json files
```

Specific paths (relative to source directory)

```sh
./artifact.sh                      Use current dir and default config
./artifact.sh /path/to/project     Specify source directory
./artifact.sh . .artifacts         Use custom config file
./artifact.sh clear                Remove artifacts directory
```
