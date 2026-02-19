#!/bin/bash
#SBATCH -A cli185
#SBATCH -J concat_daily_diag
#SBATCH -p batch
#SBATCH -N 1
#SBATCH -c 4
#SBATCH --mem=16G
#SBATCH -t 02:00:00

set -euo pipefail

# submit with:
# sbatch thin_daily_diag.sh MasterE3SM_IM.3_no.topo_pan-arctic-CAVM0.5deg_crujra

if [ $# -lt 1 ]; then
  echo "Usage: $0 RUN_NAME" >&2
  exit 1
fi

run_name="$1"

out_nc4_95_24="${run_name}.DailyDiag_1995-2024.nc"

full_prefix="${run_name}_ICB20TRCNPRDCTCBC_DailyDiag"
cur_results_dir="/gpfs/wolf2/cades/cli185/scratch/nb8/${full_prefix}/run"
output_dir="/gpfs/wolf2/cades/cli185/scratch/nb8"

hist_search_prefix="${full_prefix}.elm.h0."

cd "$cur_results_dir"

ls "${hist_search_prefix}"[12][0-9][0-9][0-9]-01-02-00000.nc \
  | awk -v p="${hist_search_prefix}" '
      {
        y = substr($0, index($0,p)+length(p), 4)
        if (y >= 1995 && y <= 2024) print $0
      }' \
  | sort -V > files_1995_2024.txt

echo "Found $(wc -l < files_1995_2024.txt) yearly files."
head files_1995_2024.txt
tail files_1995_2024.txt

out_path="${output_dir}/${out_nc4_95_24}"

xargs -a files_1995_2024.txt ncrcat -O --ovr -o "$out_path"

echo "Wrote: $out_path"
