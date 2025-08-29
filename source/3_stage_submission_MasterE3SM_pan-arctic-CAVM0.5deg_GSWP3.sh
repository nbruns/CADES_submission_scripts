#!/bin/bash
## Script for submitting pan-arctic ELM runs on CADES-Baseline
## Nick Bruns, Aug 29, 2025
## brunsne@ornl.gov

############ ############ ############
## todo's to consider:
  # 1. !! add met file changes to top, so no need to change below
  # 2. !! similar, put all namelist additions I can think of down below for first pass of runs
    ## things like the radiation downscaling should go in top of ingredients

  # 3. Add better documentation of differences across the 3 stages
  # 4. make use of re-submission features
  # 5. align start date with initialization date for full-spinup
    # # After cd into FULL_SPINUP_CASE_DIR, before case.setup:
    # ./xmlchange RUN_STARTDATE=0201-01-01
    # ./xmlchange CONTINUE_RUN=FALSE
############ ############ ############

set -e
############ ############ ############
## 0. SET RUN INGREDIENTS
############ ############ ############
RUN_NAME="MasterE3SM"
EXTENT_TAG="pan-arctic-CAVM0.5deg"
MET_TAG="GSWP3"

############
# secondary things to name, likely unchanged between runs
###########
COMPLETE_RUN_NAME="${RUN_NAME}_${EXTENT_TAG}_${MET_TAG}"
# NOTE: compsets per stage are asummed to not change in study, so hardcoded into names
  # if they change, modify here to avoid confusing misnaming
AD_SPINUP_NAME="${COMPLETE_RUN_NAME}_ICB1850CNRDCTCBC_ad_spinup"
FULL_SPINUP_NAME="${COMPLETE_RUN_NAME}_ICB1850CNPRDCTCBC"
TRANSIENT_RUN_NAME="${COMPLETE_RUN_NAME}_ICB20TRCNPRDCTCBC"

MODELROOT="/gpfs/wolf2/cades/cli185/proj-shared/nb8/models"
CASEROOT="/gpfs/wolf2/cades/cli185/proj-shared/nb8/project-e3sm/cases"

AD_SPINUP_CASE_DIR="${CASEROOT}/${AD_SPINUP_NAME}"
FULL_SPINUP_CASE_DIR="${CASEROOT}/${FULL_SPINUP_NAME}"
TRANSIENT_CASE_DIR="${CASEROOT}/${TRANSIENT_RUN_NAME}"

##init files for stage 2 and 3
# NOTE: update these if STOP_N's are modified
INIT_FILE_PATH_FOR_FULL_SPINUP="/gpfs/wolf2/cades/cli185/scratch/nb8/${AD_SPINUP_NAME}/run/${AD_SPINUP_NAME}.elm.r.0201-01-01-00000.nc"
INIT_FILE_PATH_FOR_TRANSIENT_RUN="/gpfs/wolf2/cades/cli185/scratch/nb8/${FULL_SPINUP_NAME}/run/${FULL_SPINUP_NAME}.elm.r.0601-01-01-00000.nc"
############ ############ ############



############ ############ ############
## 1. Setup/Build Full Spinup
############ ############ ############

$MODELROOT/E3SM/cime/scripts/create_newcase --case "${AD_SPINUP_CASE_DIR}" \
  --mach cades-baseline \
  --compset ICB1850CNRDCTCBC \
  --res ELM_USRDAT \
  --mpilib openmpi-amanzitpls \
  --walltime 24:00:00 \
  --handle-preexisting-dirs u \
  --project e3sm \
  --compiler gnu

cd "${AD_SPINUP_CASE_DIR}"

./xmlchange MOSART_MODE=NULL
./xmlchange DIN_LOC_ROOT=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata
./xmlchange DIN_LOC_ROOT_CLMFORC=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/
./xmlchange ELM_USRDAT_NAME=pan-arctic_CAVM.0.5deg
./xmlchange --append ELM_BLDNML_OPTS="-bgc_spinup on"
./xmlchange ATM_DOMAIN_PATH=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/share/domains/domain.clm
./xmlchange LND_DOMAIN_PATH=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/share/domains/domain.clm

# ./xmlchange ATM_DOMAIN_FILE=domain.lnd.pan-arctic_CAVM.0.01deg.1D.c250623.nc
./xmlchange ATM_DOMAIN_FILE=domain.lnd.r05_RRSwISC6to18E3r5.240328_cavm1d.nc

# ./xmlchange LND_DOMAIN_FILE=domain.lnd.pan-arctic_CAVM.0.01deg.1D.c250623.nc
./xmlchange LND_DOMAIN_FILE=domain.lnd.r05_RRSwISC6to18E3r5.240328_cavm1d.nc


./xmlchange DOUT_S=FALSE
./xmlchange ATM_NCPL=24
./xmlchange NTASKS=1280
./xmlchange NTHRDS=1
./xmlchange NTHRDS_IAC=1
./xmlchange MAX_TASKS_PER_NODE=128
./xmlchange MAX_MPITASKS_PER_NODE=128
./xmlchange STOP_OPTION=nyears
./xmlchange STOP_N=200
./xmlchange REST_N=20
./xmlchange --id PIO_TYPENAME --val netcdf


echo "
&clm_inparm
 hist_mfilt = 1
 hist_nhtfrq = 0
 hist_empty_htapes = .true.
 hist_fincl1 = 'TLAI','TOTSOMC','TSOI_10CM','SOILWATER_10CM'
 hist_dov2xy = .true.
 fsurdat = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/lnd/clm2/surfdata_map/surfdata_0.5x0.5_simyr1850_c240308_TOP_cavm1d.nc'
 stream_fldfilename_ndep = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/lnd/clm2/ndepdata/fndep_elm_cbgc_exp_simyr1849-2101_1.9x2.5_ssp245_c240903.nc'
 nyears_ad_carbon_only = 25
 spinup_mortality_factor = 10
 metdata_type = 'gswp3'
 metdata_bypass = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/atm_forcing.datm7.GSWP3.0.5d.v2.c180716/cpl_bypass_full'
 co2_file = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/CO2/fco2_datm_rcp4.5_1765-2500_c130312.nc'
 aero_file = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/cam/chem/trop_mozart_aero/aero/aerosoldep_rcp4.5_monthly_1849-2104_1.9x2.5_c100402.nc'
">>user_nl_elm

./case.setup

echo "
string(APPEND CPPDEFS " -DCPL_BYPASS")
">>cmake_macros/universal.cmake

./case.build

############ ############ ############
## 2. Setup/Build Full Spinup
############ ############ ############

$MODELROOT/E3SM/cime/scripts/create_newcase --case "${FULL_SPINUP_CASE_DIR}" \
  --mach cades-baseline \
  --compset ICB1850CNPRDCTCBC \
  --res ELM_USRDAT \
  --mpilib openmpi-amanzitpls \
  --walltime 24:00:00 \
  --handle-preexisting-dirs u \
  --project e3sm \
  --compiler gnu

cd "${FULL_SPINUP_CASE_DIR}"

./xmlchange MOSART_MODE=NULL
#./xmlchange --append ELM_BLDNML_OPTS="-bgc_spinup on"

./xmlchange DIN_LOC_ROOT=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata
./xmlchange DIN_LOC_ROOT_CLMFORC=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/
./xmlchange ELM_USRDAT_NAME=pan-arctic_CAVM.0.5deg

./xmlchange ATM_DOMAIN_PATH=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/share/domains/domain.clm
./xmlchange LND_DOMAIN_PATH=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/share/domains/domain.clm
./xmlchange ATM_DOMAIN_FILE=domain.lnd.r05_RRSwISC6to18E3r5.240328_cavm1d.nc
./xmlchange LND_DOMAIN_FILE=domain.lnd.r05_RRSwISC6to18E3r5.240328_cavm1d.nc

./xmlchange DOUT_S=FALSE
./xmlchange ATM_NCPL=24
./xmlchange NTASKS=1280
./xmlchange NTHRDS=1
./xmlchange MAX_TASKS_PER_NODE=128
./xmlchange MAX_MPITASKS_PER_NODE=128

./xmlchange STOP_OPTION=nyears
./xmlchange STOP_N=600
./xmlchange REST_N=20

./xmlchange --id PIO_TYPENAME --val netcdf

echo "
&clm_inparm
 hist_mfilt = 1
 hist_nhtfrq = 0
 hist_empty_htapes = .true.
 hist_fincl1 = 'TLAI','TOTSOMC','TSOI_10CM','SOILWATER_10CM'
 hist_dov2xy = .true.
 fsurdat = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/lnd/clm2/surfdata_map/surfdata_0.5x0.5_simyr1850_c240308_TOP_cavm1d.nc'
 stream_fldfilename_ndep = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/lnd/clm2/ndepdata/fndep_elm_cbgc_exp_simyr1849-2101_1.9x2.5_ssp245_c240903.nc'
 nyears_ad_carbon_only = 25
 spinup_mortality_factor = 10
 metdata_type = 'gswp3'
 metdata_bypass = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/atm_forcing.datm7.GSWP3.0.5d.v2.c180716/cpl_bypass_full'
 co2_file = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/CO2/fco2_datm_rcp4.5_1765-2500_c130312.nc'
 aero_file = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/cam/chem/trop_mozart_aero/aero/aerosoldep_rcp4.5_monthly_1849-2104_1.9x2.5_c100402.nc'
 finidat = '${INIT_FILE_PATH_FOR_FULL_SPINUP}'
">>user_nl_elm

./case.setup

echo "
string(APPEND CPPDEFS " -DCPL_BYPASS")
">>cmake_macros/universal.cmake

./case.build


############ ############ ############
## 3. Setup/Build Transient Run
############ ############ ############
$MODELROOT/E3SM/cime/scripts/create_newcase \
  --case "${TRANSIENT_CASE_DIR}" \
  --mach cades-baseline \
  --compset ICB20TRCNPRDCTCBC \
  --res ELM_USRDAT \
  --mpilib openmpi-amanzitpls \
  --walltime 24:00:00 \
  --handle-preexisting-dirs u \
  --project e3sm \
  --compiler gnu

cd "${TRANSIENT_CASE_DIR}"

./xmlchange MOSART_MODE=NULL
#./xmlchange --append ELM_BLDNML_OPTS="-bgc_spinup on"

./xmlchange DIN_LOC_ROOT=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata
./xmlchange DIN_LOC_ROOT_CLMFORC=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/
./xmlchange ELM_USRDAT_NAME=pan-arctic_CAVM.0.5deg
./xmlchange ATM_DOMAIN_PATH=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/share/domains/domain.clm
./xmlchange LND_DOMAIN_PATH=/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/share/domains/domain.clm
./xmlchange ATM_DOMAIN_FILE=domain.lnd.r05_RRSwISC6to18E3r5.240328_cavm1d.nc
./xmlchange LND_DOMAIN_FILE=domain.lnd.r05_RRSwISC6to18E3r5.240328_cavm1d.nc

./xmlchange DOUT_S=FALSE
./xmlchange ATM_NCPL=24
./xmlchange NTASKS=1280
./xmlchange NTHRDS=1
./xmlchange MAX_TASKS_PER_NODE=128
./xmlchange MAX_MPITASKS_PER_NODE=128

./xmlchange STOP_OPTION=nyears
./xmlchange STOP_N=165
./xmlchange REST_N=10

./xmlchange --id PIO_TYPENAME --val netcdf


echo "
&clm_inparm
 hist_mfilt = 1
 hist_nhtfrq = 0
 hist_dov2xy = .true.
 fsurdat = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/lnd/clm2/surfdata_map/surfdata_0.5x0.5_simyr1850_c240308_TOP_cavm1d.nc'
 flanduse_timeseries = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/lnd/clm2/surfdata_map/landuse.timeseries_0.5x0.5_hist_simyr1850-2015_c240308_cavm1d.nc'
 stream_fldfilename_ndep = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/lnd/clm2/ndepdata/fndep_elm_cbgc_exp_simyr1849-2101_1.9x2.5_ssp245_c240903.nc'
 nyears_ad_carbon_only = 25
 spinup_mortality_factor = 10
 metdata_type = 'gswp3'
 metdata_bypass = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/atm_forcing.datm7.GSWP3.0.5d.v2.c180716/cpl_bypass_full'
 co2_file = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/datm7/CO2/fco2_datm_rcp4.5_1765-2500_c130312.nc'
 aero_file = '/gpfs/wolf2/cades/cli185/world-shared/e3sm/inputdata/atm/cam/chem/trop_mozart_aero/aero/aerosoldep_rcp4.5_monthly_1849-2104_1.9x2.5_c100402.nc'
 finidat = '${INIT_FILE_PATH_FOR_TRANSIENT_RUN}'
 check_dynpft_consistency = .false.
">>user_nl_elm

./case.setup

echo "
string(APPEND CPPDEFS " -DCPL_BYPASS")
">>cmake_macros/universal.cmake

./case.build


############ ############ ############
## 4. Now submit jobs, dependencies
############ ############ ############
#chained submissions capture job id, here's how it works
  #1.  2>&1: 
    # redirects stderr (2) to same place as stdout (1).

  #2. tee:
    # splits text stream
      # leaves other in terminal as before (thus continues in pipe)
      # logs one, for safe keeping

  # 3. awk line
    # awk goes line by line, then pull out the line matching "submitted job id"
    # print $NF means give last field, in this case the job id

  # 4. tail -1
    # just in case multiple job id's from re-submissions,
    # just take the last

# NOTE:
  # the output that happens when you hit submit is now saved in these files:
    #  submit_ad_spinup.log
    #  submit_full_spinup.log
    #  submit_transient.log

# 1) Submit accelerated decomposition spinup
cd "${AD_SPINUP_CASE_DIR}"
JOB_ID_ad_spinup=$(
  ./case.submit 2>&1 | tee submit_ad_spinup.log \
  | awk '/Submitted job id/ {print $NF}' | tail -n1
)
echo "parsed AD_spinup JobID: ${JOB_ID_ad_spinup}"

# 2) Submit full spinup (after AD finishes OK)
cd "${FULL_SPINUP_CASE_DIR}"
JOB_ID_full_spinup=$(
  ./case.submit --batch-args="--dependency=afterok:${JOB_ID_ad_spinup}" 2>&1 \
  | tee submit_full_spinup.log \
  | awk '/Submitted job id/ {print $NF}' | tail -n1
)
echo "Full spinup JobID: ${JOB_ID_full_spinup}"

# 3) Submit transient run
cd "${TRANSIENT_CASE_DIR}"
JOB_ID_transient=$(
  ./case.submit --batch-args="--dependency=afterok:${JOB_ID_full_spinup}" 2>&1 \
  | tee submit_transient.log \
  | awk '/Submitted job id/ {print $NF}' | tail -n1
)
echo "Transient JobID: ${JOB_ID_transient}"
