#!/bin/bash
set -euo pipefail
shopt -s nullglob
# ==================================================================
# Get RACMO data needed for IVT calculations Arctic, from tape archive.
# data is available in nc files, per vertical layer
# Move all data from ARCHIVE to RACMO_input
# From the wrapper the ARCHIVE path is given untill variable name:
# ARCHIVE="ec:/rug/CORDEX/CMIP6/DD/ARC-12/UU-IMAU/${NAME}/${EXP}/${MEMBER}/RACMO24P-NN/v1-r1/6hr"

# Usage check
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <GCM> <EXP> <MEMBER> <YYYYMM> <input_dir> <output_dir>"
    exit 1
fi

GCM=$1          # e.g. CNRMESM21 or NORESM2MM
EXP=$2          # e.g. historical or ssp370
MEMBER=$3       # e.g. r1i1p1f2 or r1i1p1f1
YYYYMM=$4       # e.g. 201412
input_dir=$5    # path to archive
output_dir=$6   # path to store nc files

variables=("hus" "ua" "va")
levels=(300 400 500 600 700 850 925 1000)  # in hPa
YEAR=${YYYYMM:0:4}
all_present=true

case "${GCM}_${EXP}" in
    CNRM-ESM2-1_historical) vdate="v20250320" ;;
    CNRM-ESM2-1_ssp370)     vdate="v20250327" ;;
    NorESM2-MM_historical)  vdate="v20250307" ;;
    NorESM2-MM_ssp370)      vdate="v20250314" ;;
esac

for var in "${variables[@]}"; do
    echo "🔄 Processing variable: $var"
    for lev in "${levels[@]}"; do
        infile="${var}${lev}_ARC-12_${GCM}_${EXP}_${MEMBER}_UU-IMAU_RACMO24P-NN_v1-r1_6hr_${YEAR}01010000-${YEAR}12311800.nc"
        path="${input_dir}/${var}${lev}/${vdate}/${infile}"

        # check if monthly split files already exist
        matches=(${output_dir}/${var}${lev}_ARC-12_${GCM}_${EXP}_${MEMBER}_UU-IMAU_RACMO24P-NN_v1-r1_6hr_${YEAR}??.nc)
        if [ ${#matches[@]} -eq 0 ]; then
            all_present=false
            break 2  # Exit both loops early if any file is missing
        fi
    done
done

if [ "${all_present}" = true ]; then
    echo "✅ All RACMO files already present for ${YEAR}, skipping download."
    exit 0
fi

# If not all_present, proceed with download and split
for var in "${variables[@]}"; do
    echo "⬇️ Downloading and splitting: $var"
    for lev in "${levels[@]}"; do
        infile="${var}${lev}_ARC-12_${GCM}_${EXP}_${MEMBER}_UU-IMAU_RACMO24P-NN_v1-r1_6hr_${YEAR}01010000-${YEAR}12311800.nc"
        path="${input_dir}/${var}${lev}/${vdate}/${infile}"

        if ! ecp "${path}" "${output_dir}"; then
            echo "❌ Failed to copy: ${path}"
            exit 2
        fi

        cdo splitmon "${output_dir}/${infile}" "${output_dir}/${var}${lev}_ARC-12_${GCM}_${EXP}_${MEMBER}_UU-IMAU_RACMO24P-NN_v1-r1_6hr_${YEAR}"
    done
done
