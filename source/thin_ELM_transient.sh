#!/usr/bin/env bash
set -euo pipefail

######define run
# stored_name="MasterE3SM_pan-arctic-CAVM0.5deg_GSWP3_RERUN.longitude.fix_2D"
#these are often the same, sometimes different
dir_name="MasterE3SM_IM-2-no-phen_pan-arctic-CAVM0.5deg_gswp3"
file_name="MasterE3SM_IM-2-no-phen_pan-arctic-CAVM0.5deg_gswp3"

#normal execution
# run_name="$1"
# stored_name=run_name

post_process_run_dir="/gpfs/wolf2/cades/cli185/proj-shared/nb8/ilamb_ready_simulation_archive"

cd "${post_process_run_dir}/${dir_name}"
pwd
ls
# 1) Build a sorted list of monthly h0 files
ls 2d-${file_name}_ICB20TRCNPRDCTCBC.elm.h0.????-??.nc | sort -V > output_file_names.txt

# 2) Vars to keep (24 + coords)
# VARS="time,time_bounds,lat,lon,area,landfrac,\
# TOTVEGC,TOTVEGC_ABG,\
# GPP,\
# NPP,NEE,ER,\
# H2OSOI,SOILWATER_10CM,\
# TLAI,\
# EFLX_LH_TOT,FCTR,FGEV,\
# QRUNOFF,QOVER,QDRAI,\
# H2OSNO,\
# ALTMAX,TSOI_10CM,\
# ZWT,\
# FSDS,FLDS,RAIN,SNOW,TBOT,QBOT,WIND,PBOT"

# updated list, December 2:
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
ALT,ALTMAX,TSOI_10CM,\
ZWT,\
FSH,FGE,FIRE,FIRA,FSA,FSR,\
FSDS,FLDS,RAIN,SNOW,TBOT,QBOT,WIND,PBOT,\
topoPerGrid,topo"



# 3) Concatenate + thin to only these variables
# out_raw="${run_name}.transient.elm.h0.concat.thin.raw.nc"
out_nc4="${file_name}.transient.elm.h0.concat.thin.nc"


ncrcat -O --ovr -C -v "${VARS}" $(<output_file_names.txt) "../thinned_nc_files/${out_nc4}" 

# # 4) Repack/compress with chunking (adjust lndgrid->ncol if needed)
# out_nc4="${run_name}.transient.elm.h0.concat.thin.nc"
# # nccopy -k nc4 -d 4 -s -c time/120,lndgrid/4096 "${out_raw}" "../${out_nc4}" #
# nccopy -k nc4 -d 4 -s -c time/120 "${out_raw}" "../${out_nc4}" #needed because no lndgrd

# # 5) (Optional) remove the intermediate
# rm -f "${out_raw}"

echo "Wrote ${out_nc4}, find it in ../thinned_nc_files"
