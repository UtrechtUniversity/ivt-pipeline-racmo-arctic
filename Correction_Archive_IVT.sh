#!/usr/bin/env bash
set -euo pipefail
#SBATCH --job-name=Correction_Archive
#SBATCH --output=/ec/res4/scratch/nld1254/racmo/ivt-pipeline/Correction_Archive_%j.log
#SBATCH --error=/ec/res4/scratch/nld1254/racmo/ivt-pipeline/Correction_Archive_%j.log
#SBATCH --time=16:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=l.gavras-vangarderen@uu.nl

# Copy RACMO IVT files from colleague's archive → your archive (copy-only).
# Matches: IVT_RACMO_<GCM>_YYYYMM.nc
# GCMs: CNRM-ESM2-1, NorESM2-MM
#
# Dry-run (list only): DRYRUN=1 ./copy_racmo_ivt.sh

DRYRUN="${DRYRUN:-0}"

SOURCES=(
  "ec:/rug/CORDEX/CMIP6/DD/ARC-12/UU-IMAU/CNRM-ESM2-1/historical/r1i1p1f2/RACMO24P-NN/v1-r1/6hr"
  "ec:/rug/CORDEX/CMIP6/DD/ARC-12/UU-IMAU/CNRM-ESM2-1/ssp370/r1i1p1f2/RACMO24P-NN/v1-r1/6hr"
  "ec:/rug/CORDEX/CMIP6/DD/ARC-12/UU-IMAU/NorESM2-MM/historical/r1i1p1f1/RACMO24P-NN/v1-r1/6hr"
  "ec:/rug/CORDEX/CMIP6/DD/ARC-12/UU-IMAU/NorESM2-MM/ssp370/r1i1p1f1/RACMO24P-NN/v1-r1/6hr"
)

DST_CNRM="ec:/nld1254/IVT/RACMO/CNRMESM21"
DST_NORESM="ec:/nld1254/IVT/RACMO/NORESM2MM"

map_dst() {
  local src="$1"
  if [[ "$src" == *"/CNRM-ESM2-1/"* ]]; then
    printf "%s|%s\n" "CNRM-ESM2-1" "$DST_CNRM"
  elif [[ "$src" == *"/NorESM2-MM/"* ]]; then
    printf "%s|%s\n" "NorESM2-MM" "$DST_NORESM"
  else
    printf "%s|\n" "UNKNOWN"
  fi
}

list_cmd() { els -1 2>/dev/null || els; }

for SRC in "${SOURCES[@]}"; do
  IFS='|' read -r GCM DST <<<"$(map_dst "$SRC")"
  [[ "$GCM" == "UNKNOWN" || -z "$DST" ]] && { echo "WARN: unknown GCM for $SRC" >&2; continue; }

  echo "SRC: $SRC"
  echo "DST: $DST"

  # List remotely, filter exact pattern IVT_RACMO_<GCM>_YYYYMM.nc
  FILES=()
  if ecd "$SRC"; then
    while IFS= read -r line; do
      name="$(awk '{print $NF}' <<<"$line")"
      [[ "$name" =~ ^IVT_RACMO_${GCM}_[0-9]{6}\.nc$ ]] && FILES+=("$name")
    done < <(list_cmd 2>/dev/null || true)
  fi

  if ((${#FILES[@]}==0)); then
    echo "INFO: no IVT_RACMO_${GCM}_YYYYMM.nc in $SRC"
    echo
    continue
  fi

  if [[ "$DRYRUN" == "1" ]]; then
    echo "-- DRYRUN: would copy ${#FILES[@]} file(s):"
    printf '  %s\n' "${FILES[@]}"
    echo
    continue
  fi

  # Ensure destination exists (best-effort)
  ecp -p /dev/null "$DST/" >/dev/null 2>&1 || true

  copied=0
  for f in "${FILES[@]}"; do
    echo "Copy: $f → $DST/"
    # IMPORTANT: use fully-qualified remote source path
    if ecp -p "$SRC/$f" "$DST/"; then
      ((copied++))
    else
      echo "WARN: copy failed for $f" >&2
    fi
  done
  echo "OK: copied $copied / ${#FILES[@]} to $DST"
  echo
done

echo "✅ Copy attempts completed."



