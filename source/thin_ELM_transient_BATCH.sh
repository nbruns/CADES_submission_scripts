#!/usr/bin/env bash
#SBATCH -J thin_elm_transient
#SBATCH -A cli185
#SBATCH -p batch
# #SBATCH -p batch_ccsi
#SBATCH -N 1
#SBATCH -c 4
#SBATCH --mem=32G
#SBATCH -t 12:00:00
#SBATCH --export=NONE
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
SOILICE,SOILLIQ,\
FINUNDATED,FH2OSFC,\
QVEGE,QVEGT,QSOIL,\
TLAI,\
EFLX_LH_TOT,FCTR,FGEV,\
QRUNOFF,QOVER,QDRAI,\
H2OSNO,\
ALT,ALTMAX,TSOI_10CM,\
ZWT,\
FSH,FGE,FIRE,FIRA,FSA,FSR,FGR,\
FSDS,FLDS,RAIN,SNOW,TBOT,QBOT,WIND,PBOT"

# concat + thin
# out_raw="${run_name}.transient.elm.h0.concat.thin.raw.nc"
out_nc4="${run_name}.transient.elm.h0.concat.thin.nc"

out_nc4_95_24="${run_name}.transient.elm.h0.concat.thin_1995-2024.nc"

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

echo "now trying to subset"
echo "first, load python environment"

###now, subset to the 30 year's of interest
# first, load the pythong environment
# Ensure srun inherits the environment built below (from CADES docs)
unset SLURM_EXPORT_ENV
source /sw/baseline/nsp/init/profile
module purge
module load miniforge3/24.11.3-0
eval "$(conda shell.bash hook)"
# set +u # activate elm_env can set off "set u" do to an unset var # turning off!
conda activate elm_env
# set -u # turning off!


#use path reset to ensure conda version of python is used
  # this fixed issues with not using cartopy downloaded data
    # and tyrying to download maps on nodes
echo "python version, before re-setting path"
which python
export PATH="$CONDA_PREFIX/bin:$PATH"
hash -r
echo "python version, after re-setting path"
which python

cd /gpfs/wolf2/cades/cli185/proj-shared/nb8/ilamb_ready_simulation_archive

echo "now do the work"
python - <<PY
import xarray as xr
duration_laste_30_years = slice("1995","2024")
ds_full = xr.open_dataset("$out_nc4")
ds_last_30_years = ds_full.sel(time=duration_laste_30_years)
ds_last_30_years.to_netcdf("$out_nc4_95_24")
PY

cp $out_nc4_95_24 /gpfs/wolf2/cades/cli185/proj-shared/nb8/ilamb_sandbox/DATA_baseline_compare
echo "completed the work"
