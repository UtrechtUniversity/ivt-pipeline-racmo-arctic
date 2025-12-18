#!/bin/bash
set -euo pipefail
#SBATCH --job-name=ivt_RACMO_CORDEX
#SBATCH --output=/ec/res4/scratch/nld1254/racmo/ivt-pipeline/ivt_racmo_CORDEX_%j.log
#SBATCH --error=/ec/res4/scratch/nld1254/racmo/ivt-pipeline/ivt_racmo_CORDEX_%j.log
#SBATCH --time=08:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=l.gavras-vangarderen@uu.nl
# --------------------------------------------------------
# IVT Processing Pipeline Wrapper Script
# --------------------------------------------------------
# This script automates the workflow for calculating
# Integrated Vapor Transport (IVT) from HCLIM climate model data.
# Model layers 300-1000hPa are used (9 layers: (300 400 500 600 700 750 850 925 1000))
#
# This script uses a specific Python version for creating level bounds:
# Default path: /usr/local/apps/python3/3.12.9-01/bin/python3
# If this path does not exist on your system, modify the PYTHON variable below to match your environment
#    e.g., PYTHON=/usr/bin/python3
#
# It sequentially runs:
#   1) Vertical layer merging of selected variables (hus, ua, va)
#   2) Creation of pressure level bounds (once per run)
#   3) IVT calculation for specified months and years
#
# Users specify the climate model (GCM), start/end years,
# and optionally start/end months for partial year processing.
#
# The script handles experiment selection (hist/ssp370) based
# on the year and sets model-specific member IDs automatically.
#
# Paths to model input files, intermediate merged files, and
# final IVT output are hardcoded but can be adjusted below.
#
# Usage:
#   ./run_ivt_pipeline.sh <GCM> <START_YEAR> <END_YEAR> [START_MONTH] [END_MONTH]
#
# Example:
#   ./run_ivt_pipeline.sh           		       # default is CNRMESM21 Dec 2014
#   ./run_ivt_pipeline.sh NORESM2MM 2015 2015 03 06    # runs Mar-Jun 2015 for NorESM2-MM
#   ./run_ivt_pipeline.sh CNRMESM21 2014 2014 12 12    # run Jan 2014 only for CNRM-ESM2.1
# --------------------------------------------------------

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [GCM] [START_YEAR] [END_YEAR] [START_MONTH] [END_MONTH]"
  exit 0
fi

GCM=${1:-"CNRMESM21"} # default CNRMESM21 201412 if not passed
START_YEAR=${2:-2014}
END_YEAR=${3:-2014}
START_MONTH=${4:-12}
END_MONTH=${5:-12}

# === Paths ===
MODEL_INPUT="/ec/res4/scratch/nld1254/racmo"
WORK_DIR="${MODEL_INPUT}/work/${GCM}"
MERGED_FILES="${MODEL_INPUT}/merged_monthly_variables/${GCM}"
IVT_OUTPUT="${MODEL_INPUT}/ivt/${GCM}"
RACMO_INPUT="${MODEL_INPUT}/RACMO_input/${GCM}"
ARCHIVE_OUT="ec:/nld1254/IVT/RACMO/${GCM}"

mkdir -p "$WORK_DIR" "$MERGED_FILES" "$IVT_OUTPUT" "$RACMO_INPUT" "$ARCHIVE_OUT"

# Set python alias to full path of python3 - comment this line if your environment already has python3 or python properly set
PYTHON='/usr/local/apps/python3/3.12.9-01/bin/python3'

# Validate months are 01-12
if ! [[ "$START_MONTH" =~ ^(0[1-9]|1[0-2])$ ]] || ! [[ "$END_MONTH" =~ ^(0[1-9]|1[0-2])$ ]]; then
  echo "Error: START_MONTH and END_MONTH must be two-digit months between 01 and 12"
  exit 1
fi

# === GCM-specific settings ===
if [[ $GCM == "CNRMESM21" ]]; then
  MEMBER="r1i1p1f2"
  NAME="CNRM-ESM2-1"
elif [[ $GCM == "NORESM2MM" ]]; then
  MEMBER="r1i1p1f1"
  NAME="NorESM2-MM"
else
  echo "Unsupported GCM: $GCM"
  exit 1
fi

# === level_bounds ===
# The create_level_bounds.py needs to be run only one time, the output file (level_bounds.nc)  will be used by the IVT calculation code.       
if [ ! -f "${WORK_DIR}/level_bounds.nc" ]; then
  echo "📘 Creating level_bounds.nc in $WORK_DIR..."
  $PYTHON create_level_bounds.py
  mv level_bounds.nc "${WORK_DIR}/level_bounds.nc"
else
  echo "✅ level_bounds.nc already exists in $WORK_DIR, skipping creation."
fi


# === Build list of months to process ===
MONTH_LIST=()
for YEAR in $(seq $START_YEAR $END_YEAR); do
  if [[ "$YEAR" -eq "$START_YEAR" && "$YEAR" -eq "$END_YEAR" ]]; then
    MONTH_START=$START_MONTH
    MONTH_END=$END_MONTH
  elif [[ "$YEAR" -eq "$START_YEAR" ]]; then
    MONTH_START=$START_MONTH
    MONTH_END=12
  elif [[ "$YEAR" -eq "$END_YEAR" ]]; then
    MONTH_START=01
    MONTH_END=$END_MONTH
  else
    MONTH_START=01
    MONTH_END=12
  fi

  for MONTH in $(seq -w $MONTH_START $MONTH_END); do
    MONTH_LIST+=("${YEAR}${MONTH}")
  done
done

# === Print model and member info ===
echo "Running IVT calculations for model: $GCM, member: $MEMBER"
echo "Processing time range (months):"

# === Print summary and confirm ===
for m in "${MONTH_LIST[@]}"; do
  echo "  - $m"
done

# === Main processing loop ===
for YYYYMM in "${MONTH_LIST[@]}"; do
  YEAR=${YYYYMM:0:4}

  if (( YEAR < 2015 )); then
    EXP="historical"
  else
    EXP="ssp370"
  fi
  
ARCHIVE_IN="ec:/rug/CORDEX/CMIP6/DD/ARC-12/UU-IMAU/${NAME}/${EXP}/${MEMBER}/RACMO24P-NN/v1-r1/6hr"

  echo ">>> Processing $YYYYMM for $GCM ($EXP)..."
  ./RACMO_fromArchive.sh "$NAME" "$EXP" "$MEMBER" "$YYYYMM" "$ARCHIVE_IN" "$RACMO_INPUT"
  ./merge_verticallayers_allvar_cdo.sh "$NAME" "$EXP" "$MEMBER" "$YYYYMM" "$RACMO_INPUT" "$MERGED_FILES"
  ./IVT_RACMO_Arctic_cdo.sh "$NAME" "$EXP" "$MEMBER" "$YYYYMM" "$MERGED_FILES" "$IVT_OUTPUT"
  ./Archive_IVT_RACMO.sh "$NAME" "$YYYYMM" "$IVT_OUTPUT" "$ARCHIVE_OUT"

  echo ">>> Finished $YYYYMM"
  echo "----------------------"
done

echo "✅ All processing complete."
