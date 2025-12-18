#!/bin/bash
set -euo pipefail

# === USAGE CHECK ===
if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <GCM> <YYYYMM> <input_dir> <output_dir>"
  exit 1
fi

# === INPUTS FROM WRAPPER ===
GCM=$1         # e.g. CNRMESM21 or NORESM2MM
YYYYMM=$2      # e.g., 201412
INPUT_DIR=$3   # merged monthly variable files
ARCHIVE_DIR=$4  # final IVT output

# Archive IVT files on tape

filenm="IVT_RACMO_${GCM}_${YYYYMM}.nc"
src="$INPUT_DIR/$filenm"
dst="$ARCHIVE_DIR/$filenm"

echo "Archiving $filenm to $dst …"
if [ ! -f "$src" ]; then
  echo "❌ Source file not found: $src"
  exit 2
fi

ecp "$src" "$dst"
echo "✅ Archive successful: $dst"