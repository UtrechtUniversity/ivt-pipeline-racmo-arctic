#!/bin/bash
set -euo pipefail

export HDF5_USE_FILE_LOCKING=FALSE

# Usage check
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <GCM> <EXP> <MEMBER> <YYYYMM> <input_dir> <output_dir>"
    exit 1
fi

GCM=$1          # e.g. CNRM-ESM2-1 or NorESM2-MM
EXP=$2          # e.g. historical or ssp370
MEMBER=$3       # e.g. r1i1p1f2 or r1i1p1f1
YYYYMM=$4       # e.g. 201412
input_dir=$5    # path to raw input files
output_dir=$6   # path to save merged files


# Variables to merge
variables=("hus" "ua" "va")
levels=(300 400 500 600 700 850 925 1000)  # in hPa

# Make sure output directory exists
mkdir -p "$output_dir"

# Create a temporary working directory
tmp_dir=$(mktemp -d)
echo "🛠 Working in temp dir: $tmp_dir"

for var in "${variables[@]}"; do
    echo "🔄 Processing variable: $var"
    level_files=()

    for lev in "${levels[@]}"; do
        infile="${input_dir}/${var}${lev}_ARC-12_${GCM}_${EXP}_${MEMBER}_UU-IMAU_RACMO24P-NN_v1-r1_6hr_${YYYYMM}.nc"
        tmpfile="${tmp_dir}/${var}_${lev}.nc"

        if [[ ! -f "$infile" ]]; then
            echo "⚠️  Missing file: $infile"
            continue
        fi

        echo "🔧 Renaming variable ${var}${lev} → ${var} in $infile"
        cdo chname,${var}${lev},${var} "$infile" "$tmpfile"
        level_files+=("$tmpfile")
    done

    if [ ${#level_files[@]} -eq 0 ]; then
        echo "⛔ No files found for $var, skipping..."
        continue
    fi

    merged_file="${output_dir}/${var}_${YYYYMM}_stacked.nc"
    final_file="${output_dir}/${var}_${YYYYMM}_stacked_with_level.nc"

    if [[ -f "$merged_file" ]]; then
        echo "⚠️  File $merged_file exists — overwriting."
        rm -f "$merged_file"
    fi

    echo "📦 Merging all levels into: $merged_file"
    cdo -O -w merge "${level_files[@]}" "$merged_file"

    echo "➕ Adding level coordinate to merged file"
    ncap2 -O -s 'defdim("level",8); level[level]={30000,40000,50000,60000,70000,85000,92500,100000}' "$merged_file" "$final_file"

    # Rename vertical dimension and variable from level → plev
    ncrename -d level,plev -v level,plev "$final_file"
    # Remap hus to use plev as vertical dimension
    #ncpdq -a time,plev,rlat,rlon "$final_file" tmp.nc && mv tmp.nc "$final_file"

    echo "✅ Finished: $final_file"
done
# Cleanup
rm -rf "$tmp_dir"

