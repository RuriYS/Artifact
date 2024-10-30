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

artifact.sh help               Shows help
artifact.sh clear              Remove artifacts directory. Unlike --clear, it only clear artifacts.
```

## Parameters

   `src`          - Optional. Root directory to search for files. (Default: `.`)

   `config`     - Optional. Path to the artifacts configuration file (Default: `.artifacts`)

## Commands

- `clear`     - Special command to remove the artifacts

## Configuration

Default config file: `.artifacts`
The script uses a text file to specify which files to collect.

Each line can be either:

- Just a filename to search for: `README.md`
- A specific path relative to source directory: `docs/README.md`
- Wildcards: `*.js`, `*.ts`, etc...

```sh
*.js                              Will only look for files that ends with .js
script.js                         Will only look for script.js
docs/README.md                    Will only look in docs directory
src/lib/utils.js                  Will only look in src/lib directory
```
