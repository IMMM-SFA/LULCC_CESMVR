#!/bin/bash

#-------- Anjana, July 2019 --------------------------
# driving bash script to set up case for LULCC CESMVR simulations on NERSC CORI

#-------- create new case ----------------------------

CASENAME=TEST_ne30_ne240

cd $BASE_DIR/cesm/cime/scripts

./create_newcase --case ~/$CASENAME --res ne30_ne0CONUSne30x8 --compset FHIST --mach cori-haswell --run-unsupported

#------- in case directory ---------------------------

cd ~/$CASENAME

./xmlchange NTASKS=-64
./xmlchange SSTICE_DATA_FILENAME=/project/projectdirs/ccsm1/inputdata/atm/cam/sst/sst_HadOIBl_bc_1x1_1850_2016_c170525.nc

    #--------------------- NOTE -------------------------
    #------ may need to set DIN_LOC_ROOT
    #------ in case input files are missing in /project/projectdirs/ccsm1/inputdata
    #------ set DIN_LOC_ROOT to temporary scratch directory & download input data there
    #./xmlchange DIN_LOC_ROOT=$some_scratch_dir
    #------------------- END NOTE -----------------------

cp $BASE_DIR/LULCC_CESMVR/user_mods/env_mach_specific.xml .

cp $BASE_DIR/LULCC_CESMVR/user_mods/dyn_comp.F90 SourceMods/src.cam
cp $BASE_DIR/LULCC_CESMVR/namelists/ne30_cam/user_nl_cam .
cp $BASE_DIR/LULCC_CESMVR/namelists/ne240_clm/user_nl_clm_${year} .
mv user_nl_clm_${year} user_nl_clm      
cp $BASE_DIR/LULCC_CESMVR/namelists/mosart/user_nl_mosart .

    #-------------------- NOTE -------------------------
    #----- if iterim restarts need to be saved
    #./xmlchange DOUT_S_SAVE_INTERIM_RESTART_FILES=TRUE
    #---------------- END NOTE -------------------------

./xmlchange ATM_NCPL=48 
./xmlchange STOP_N=5
./xmlchange STOP_OPTION=ndays
./xmlchange REST_N=5
./xmlchange REST_OPTION=ndays
./xmlchange JOB_WALLCLOCK_TIME=00:30:00 --subgroup case.run
./xmlchange JOB_QUEUE=debug --force

./case.setup
#./case.build
#./case.submit



