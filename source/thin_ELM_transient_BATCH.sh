#!/usr/bin/env bash
#SBATCH -J thin_elm_transient
#SBATCH -A cli185
#SBATCH -p batch
#SBATCH -N 1
#SBATCH -c 4
#SBATCH --mem=32G
#SBATCH -t 24:00:00
#SBATCH -o slurm-%x-%j.out
#SBATCH -e slurm-%x-%j.err

set -euo pipefail

module purge
module load nco
# module load netcdf

# # --- required args ---
# if [ $# -lt 1 ]; then
#   echo "Usage: $0 STORED_NAME RUN_NAME [POST_DIR]" >&2
#   exit 1
# fi

run_name="$1"      # short run tag used in filenames (after '2d-')
stored_name=$run_name # can modify if different

post_process_run_dir="/gpfs/wolf2/cades/cli185/proj-shared/nb8/ilamb_ready_simulation_archive"

###########
# define
####
cd "${post_process_run_dir}/${stored_name}"
pwd

# build sorted list
ls 2d-${run_name}_ICB20TRCNPRDCTCBC.elm.h0.????-??.nc | sort -V > output_file_names.txt

# vars
VARS="time,time_bounds,lat,lon,area,landfrac,lndgrid,\
TOTVEGC,TOTVEGC_ABG,\
GPP,\
NPP,NEE,ER,\
H2OSOI,SOILWATER_10CM,\
TLAI,\
EFLX_LH_TOT,FCTR,FGEV,\
QRUNOFF,QOVER,QDRAI,\
H2OSNO,\
ALTMAX,TSOI_10CM,\
ZWT,\
FSDS,FLDS,RAIN,SNOW,TBOT,QBOT,WIND,PBOT"

# concat + thin
out_raw="${run_name}.transient.elm.h0.concat.thin.raw.nc"
ncrcat -O --ovr -C -v "${VARS}" $(<output_file_names.txt) "${out_raw}"

# compress/chunk (change lndgrid->ncol if your files use ncol)
out_nc4="${run_name}.transient.elm.h0.concat.thin.nc"
# nccopy -k nc4 -d 4 -s -c time/120,lndgrid/4096 "${out_raw}" "../${out_nc4}" # chunk in space and time
nccopy -k nc4 -d 4 -s -c time/120 "${out_raw}" "../${out_nc4}" # chunk in time only


rm -f "${out_raw}"
echo "Wrote ../${out_nc4}"