#!/usr/bin/env bash
#SBATCH -J thin_elm_transient
#SBATCH -A cli185
#SBATCH -p batch_ccsi
#SBATCH -N 1
#SBATCH -c 4
#SBATCH --mem=32G
#SBATCH -t 24:00:00
#SBATCH -o slurm-%x-%j-%A_%a.out
#SBATCH -e slurm-%x-%j-%A_%a.err

set -euo pipefail

# module purge
# module load nco
# module load netcdf


if [ $# -lt 1 ]; then
  echo "Usage: $0 RUN_NAME" >&2
  exit 1
fi


run_name="$1"
stored_name="$run_name"
post_process_run_dir="/gpfs/wolf2/cades/cli185/proj-shared/nb8/ilamb_ready_simulation_archive"


###########
# define
####
cd "${post_process_run_dir}/${stored_name}"

# build sorted list
ls 2d-${run_name}_ICB20TRCNPRDCTCBC.elm.h0.????-??.nc | sort -V > output_file_names.txt

# vars
VARS="time,time_bounds,lat,lon,area,landfrac,\
TOTVEGC,TOTVEGC_ABG,\
TOTSOMC,TOTLITC,SOILC,\
CH4PROD,FCH4,NFIX_TO_SMINN,\
GPP,\
NPP,NEE,ER,\
H2OSOI,SOILWATER_10CM,\
TLAI,\
EFLX_LH_TOT,FCTR,FGEV,\
QRUNOFF,QOVER,QDRAI,\
H2OSNO,\
ALTMAX,TSOI_10CM,\
ZWT,\
FSH,FGE,FIRE,FIRA,FSA,FSR,\
FSDS,FLDS,RAIN,SNOW,TBOT,QBOT,WIND,PBOT"

# concat + thin
# out_raw="${run_name}.transient.elm.h0.concat.thin.raw.nc"
out_nc4="${run_name}.transient.elm.h0.concat.thin.nc"
ncrcat -O --ovr -C -v "${VARS}" $(<output_file_names.txt) "../${out_nc4}" 

rm output_file_names.txt

# originally, I experimented with a 2-stage process
	# do concat as above
	# then do some optimized chunking
	# but that part hung up, so I've dropped it. here's the call:

		# # compress/chunk (change lndgrid->ncol if your files use ncol)
		# # nccopy -k nc4 -d 4 -s -c time/120,lndgrid/4096 "${out_raw}" "../${out_nc4}" # chunk in space and time
		# nccopy -k nc4 -d 4 -s -c time/120 "${out_raw}" "../${out_nc4}" # chunk in time only
		# rm -f "${out_raw}"

echo "Wrote ../${out_nc4}"