#!/usr/bin/env bash
set -euo pipefail

######define run
# run_name="MasterE3SM_pan-arctic-CAVM0.5deg_GSWP3_RERUN.longitude.fix_2D"
run_name="$1"

post_process_run_dir="/gpfs/wolf2/cades/cli185/proj-shared/nb8/ilamb_ready_simulation_archive"

cd "${post_process_run_dir}/${run_name}"

# 1) Build a sorted list of monthly h0 files
ls ${run_name}_ICB1850CNPRDCTCBC.elm.h0.????-??.nc | sort -V > output_file_names.txt

# 2) Vars to keep (24 + coords)
VARS="time,time_bounds,lat,lon,area,landfrac,\
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

# 3) Concatenate + thin to only these variables
out_raw="${run_name}.transient.elm.h0.concat.thin.raw.nc"
ncrcat -O --ovr -C -v "${VARS}" $(<output_file_names.txt) "${out_raw}"

# 4) Repack/compress with chunking (adjust lndgrid->ncol if needed)
out_nc4="${run_name}.transient.elm.h0.concat.thin.nc"
nccopy -k nc4 -d 4 -s -c time/120,lndgrid/4096 "${out_raw}" "../${out_nc4}"

# 5) (Optional) remove the intermediate
rm -f "${out_raw}"

echo "Wrote ${out_nc4}"
