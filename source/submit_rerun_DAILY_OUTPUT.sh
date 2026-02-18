#!/bin/bash
## Script for submitting rereunning daily outputs for ILAMB diagnostics
## February 17, 2026
set -euo pipefail 

# submit like this:
# ./make_daily_branch_case.sh \
#   --variant im3_ds1_topo \
#   --met crujra \
#   --startdate 1990-01-01 \
#   --rerun_nyears 35


############ ############ ############
## 0. declare, parse filenames
############ ####1######## ############
while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant) VARIANT="${2:?ERROR: --variant requires a value}"; shift 2;;
    --met) MET_TAG="${2:?ERROR: --met requires a value}"; shift 2;;
    --startdate) REF_DATE_ARG="${2:?ERROR: --startdate requires a value}"; shift 2;;
    --rerun_nyears) RERUN_NYEARS="${2:?ERROR: --rerun_nyears requires a value}"; shift 2;;
    *) echo "ERROR: Unknown arg: $1" >&2; exit 2;;
  esac
done



: "${VARIANT:?ERROR: --variant is required}"
: "${MET_TAG:?ERROR: --met is required (crujra|gswp3)}"
: "${REF_DATE_ARG:?ERROR: --startdate is required (YYYY-MM-DD)}"
: "${RERUN_NYEARS:?ERROR: --rerun_nyears is required}"


# todo: fil in RUN_NAME_REFs here
case "$VARIANT" in
  baseline)
    USE_IM_2_FLAG=".false."
    USE_IM_3_FLAG=".false."
    USE_TOPO_UNITS=false
    USE_TOPOBASED_MET_DOWNSCALE=false
    RUN_NAME_REF_BASE="MasterE3SM_pan-arctic-CAVM0.5deg_CRUJRA.trendy"

    ;;
  im2)
    USE_IM_2_FLAG=".true."
    USE_IM_3_FLAG=".false."
    USE_TOPO_UNITS=true
    USE_TOPOBASED_MET_DOWNSCALE=false
    RUN_NAME_REF_BASE="MasterE3SM_IM.2_no.ds_yes.topo_pan-arctic-CAVM0.5deg_crujra"
    ;;
  im3)
    USE_IM_2_FLAG=".false."
    USE_IM_3_FLAG=".true."
    USE_TOPO_UNITS=false
    USE_TOPOBASED_MET_DOWNSCALE=false
    RUN_NAME_REF_BASE="MasterE3SM_IM.3_no.topo_pan-arctic-CAVM0.5deg_crujra"
    ;;
  ds_only)
    USE_IM_2_FLAG=".false."
    USE_IM_3_FLAG=".false."
    USE_TOPO_UNITS=true
    USE_TOPOBASED_MET_DOWNSCALE=true
    RUN_NAME_REF_BASE="MasterE3SM_just.ds_yes.topo_pan-arctic-CAVM0.5deg_crujra"
    ;;
  im2_ds)
    USE_IM_2_FLAG=".true."
    USE_IM_3_FLAG=".false."
    USE_TOPO_UNITS=true
    USE_TOPOBASED_MET_DOWNSCALE=true
    RUN_NAME_REF_BASE="MasterE3SM_IM-2-no-phen_pan-arctic-CAVM0.5deg_crujra"
    ;;
  im3_ds)
    USE_IM_2_FLAG=".false."
    USE_IM_3_FLAG=".true."
    USE_TOPO_UNITS=true
    USE_TOPOBASED_MET_DOWNSCALE=true
    RUN_NAME_REF_BASE="MasterE3SM_IM.3_ds.1_yes.topo_pan-arctic-CAVM0.5deg_crujra"
    ;;
  *)
    echo "ERROR: unknown variant '$VARIANT'"; exit 2 ;;
esac




############ ############ ############
## 1. declare, parse filenames
############ ####1######## ############
RUN_NAME_REF="${RUN_NAME_REF_BASE}_ICB20TRCNPRDCTCBC"
REF_RUN_DIR="/gpfs/wolf2/cades/cli185/scratch/nb8/${RUN_NAME_REF}/run"
#test if restart file exits
restart_pattern="${REF_RUN_DIR}/${RUN_NAME_REF}.elm.r.${REF_DATE_ARG}-*.nc"
ls ${restart_pattern} >/dev/null 2>&1 || { echo "ERROR: Missing restart: ${restart_pattern}" >&2; exit 2; }



RUN_NAME_DAILY="${RUN_NAME_REF}_DailyDiag"

MODELROOT="/gpfs/wolf2/cades/cli185/proj-shared/nb8/models"
CASEROOT="/gpfs/wolf2/cades/cli185/proj-shared/nb8/project-e3sm/cases"

DAILY_OUTPUT_CASE_DIR="${CASEROOT}/${RUN_NAME_DAILY}"


## get options parses
if [[ $USE_TOPO_UNITS == true ]]; then
  # with topo units
  SURF_FILE="/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/lnd/clm2/surfdata_map/topounit_surfdata_0.5x0.5_simyr1850.c20220204_cavm1d.nc"
  DOMAIN_FILE="domain.lnd.r05_RRSwISC6to18E3r5.240328_cavm1d_toposafe.nc"
else
  # without topo units
  # DOMAIN_FILE="domain.lnd.r05_RRSwISC6to18E3r5.240328_cavm1d.nc"
  SURF_FILE="/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/lnd/clm2/surfdata_map/surfdata_0.5x0.5_simyr1850_c240308_TOP_cavm1d.nc"
  DOMAIN_FILE="domain.lnd.r05_RRSwISC6to18E3r5.240328_cavm1d_toposafe.nc" # topo safe, use for both
fi


# set met specific information
case "$MET_TAG" in
  gswp3)
    METDATA_BYPASS_FILE="/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/atm_forcing.datm7.GSWP3.0.5d.v2.c180716/cpl_bypass_full"
    # STOP_N_TRANSIENT=165    
    ;;
  crujra)
    METDATA_BYPASS_FILE="/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/atm_forcing.CRUJRA_trendy_2025/cpl_bypass_full"
    # STOP_N_TRANSIENT=175
    ;;
  *)
    echo "ERROR: Unknown MET_TAG: '$MET_TAG' (expected: gswp3 or crujra)"; exit 2
    ;;
esac



############ ############ ############
## 2. create new case dir
############ ############ ############
 $MODELROOT/E3SM/cime/scripts/create_newcase \
  --case "${DAILY_OUTPUT_CASE_DIR}" \
  --mach cades-baseline \
  --compset ICB20TRCNPRDCTCBC \
  --res ELM_USRDAT \
  --mpilib openmpi-amanzitpls \
  --walltime 24:00:00 \
  --handle-preexisting-dirs u \
  --project e3sm \
  --compiler gnu

cd "${DAILY_OUTPUT_CASE_DIR}"

############ ############ ############
## 3) .xml change some stuff to get branching right
############ ############ ############

# in the NEW daily case directory
./xmlchange RUN_TYPE=branch
./xmlchange RUN_REFCASE="${RUN_NAME_REF}"
./xmlchange RUN_REFDATE="${REF_DATE_ARG}"
./xmlchange RUN_REFDIR="${REF_RUN_DIR}"

./xmlchange STOP_OPTION=nyears
./xmlchange STOP_N="${RERUN_NYEARS}"
./xmlchange REST_OPTION=nyears
./xmlchange REST_N=5   # or 5/10, but 1 is safest for long daily runs

############ ############ ############
## 4) define history tapes with daily
############ ############ ############
./xmlchange MOSART_MODE=NULL
#./xmlchange --append ELM_BLDNML_OPTS="-bgc_spinup on"

./xmlchange DIN_LOC_ROOT=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata
./xmlchange DIN_LOC_ROOT_CLMFORC=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/
./xmlchange ELM_USRDAT_NAME=pan-arctic_CAVM.0.5deg
./xmlchange ATM_DOMAIN_PATH=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/share/domains/domain.clm
./xmlchange LND_DOMAIN_PATH=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/share/domains/domain.clm
# ./xmlchange ATM_DOMAIN_FILE=domain.lnd.r05_RRSwISC6to18E3r5.240328_cavm1d.nc

./xmlchange ATM_DOMAIN_FILE="${DOMAIN_FILE}"
./xmlchange LND_DOMAIN_FILE="${DOMAIN_FILE}"



./xmlchange DOUT_S=FALSE
./xmlchange ATM_NCPL=24
./xmlchange NTASKS=1280
./xmlchange NTHRDS=1
./xmlchange MAX_TASKS_PER_NODE=128
./xmlchange MAX_MPITASKS_PER_NODE=128



./xmlchange --id PIO_TYPENAME --val netcdf
# todo, define history dirs


if [[ $USE_TOPOBASED_MET_DOWNSCALE == true ]]; then
  echo "Turning on topo-unit based downscaling: adding -topounit to build options"
  ./xmlchange --append ELM_BLDNML_OPTS="-topounit"
fi


#note-- I have turned off landuse time series

echo "
&clm_inparm
 use_IM2_hillslope_hydrology = ${USE_IM_2_FLAG}
 create_crop_landunit = .true.
 hist_empty_htapes = .true.
 hist_dov2xy = .true.
 ! Tape 1: monthly (test)
 hist_nhtfrq = 0
 hist_mfilt  = 1
 hist_fincl1 = 'SOILC'

 ! Tape 2: daily (test)
 hist_nhtfrq(2) = -24
 hist_mfilt(2)  = 365
 hist_fincl2 = 'GPP','FCH4'

 fsurdat = '${SURF_FILE}'
 flanduse_timeseries = ''
 stream_fldfilename_ndep = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/lnd/clm2/ndepdata/fndep_elm_cbgc_exp_simyr1849-2101_1.9x2.5_ssp245_c240903.nc'
 nyears_ad_carbon_only = 25
 spinup_mortality_factor = 10
 metdata_type = '${MET_TAG}'
 metdata_bypass = '${METDATA_BYPASS_FILE}'
 co2_file = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/CO2/fco2_datm_rcp4.5_1765-2500_c130312.nc'
 aero_file = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/cam/chem/trop_mozart_aero/aero/aerosoldep_rcp4.5_monthly_1849-2104_1.9x2.5_c100402.nc'
 check_dynpft_consistency = .false.
/
">>user_nl_elm

# Only add paramfile line if USE_IM_3_FLAG is true
if [ "${USE_IM_3_FLAG}" = ".true." ]; then
  echo "paramfile = '\$DIN_LOC_ROOT/lnd/clm2/paramdata/clm_params_ngeea-im3_c240822.nc'" >> user_nl_elm
fi

./case.setup

echo "
string(APPEND CPPDEFS " -DCPL_BYPASS")
">>cmake_macros/universal.cmake

./case.build

./case.submit

