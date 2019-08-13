;------------------------------------------------------------------------------------------
; script to load data, calculate mean across years, regrid & write mon climatology data to nc file
;----- Anjana Devanand, 8 Apr 2019--------------------------------------------------------

  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
  load "/global/homes/d/devanand/ncl_codes/temp_extremes/model_evaluation/read_variable_from_files.ncl"

begin

;----------------------------------------------------- arrange data files -------------------------------------------------------
  years = ispan(1984,2005,1)
  variable_name = getenv("variable_name")
  string_files_2000 = new(264,string)
  string_files_1850 = new(264,string)

;----- 15 years = 15*12=180 months --------------
  string_files_2000(0:179) = systemfunc("ls /global/cscratch1/sd/devanand/archive/LU2000.FHIST.ne240conus/lnd/hist/LU2000.FHIST.ne240conus.clm2.h0.*.nc")
;----- 3 years = 3*12=36 months -----------------
  string_files_2000(180:215) = systemfunc("ls /global/cscratch1/sd/devanand/archive/LU2000.FHIST.ne240conus_subdaily/lnd/hist/LU2000.FHIST.ne240conus_subdaily.clm2.h0.*.nc")
;----- 4 years =  4*12=48 months 
  string_files_2000(216:263) = systemfunc("ls /global/cscratch1/sd/devanand/archive/LU2000.FHIST.ne240conus_subdaily_conus/lnd/hist/LU2000.FHIST.ne240conus_subdaily_conus.clm2.h0.200[2-5]*.nc")

  string_files_1850(0:179) = systemfunc("ls /global/cscratch1/sd/devanand/archive/LU1850.FHIST.ne240conus/lnd/hist/LU1850.FHIST.ne240conus.clm2.h0.*.nc")
  string_files_1850(180:215) = systemfunc("ls /global/cscratch1/sd/devanand/archive/LU1850.FHIST.ne240conus_subdaily/lnd/hist/LU1850.FHIST.ne240conus_subdaily.clm2.h0.*.nc")
  string_files_1850(216:263) = systemfunc("ls /global/cscratch1/sd/devanand/archive/LU1850.FHIST.ne240conus_subdaily_conus/lnd/hist/LU1850.FHIST.ne240conus_subdaily_conus.clm2.h0.200[2-5]*.nc")

;--------------------------------------------------------------------------------------------------------------------------------
  file1 = addfile(string_files_2000(0),"r")
  dims = filevardimsizes(file1,"FSH")
  no_of_years = dimsizes(string_files_2000)/12

  var_LU2000_SE = new((/no_of_years,12,dims(1)/),float)
  var_LU2000_SE!0 = "time_yr"
  var_LU2000_SE&time_yr = years

  var_LU1850_SE = new((/no_of_years,12,dims(1)/),float)
  var_LU1850_SE!0 = "time_yr"
  var_LU1850_SE&time_yr = years

  end_file = (no_of_years-1)*12
  year_count = 0
  do i_file = 0,end_file,12

        files_2000_yr = addfiles(string_files_2000(i_file:i_file+11),"r")
        files_1850_yr = addfiles(string_files_1850(i_file:i_file+11),"r")
        ;print(i_file)
        print(string_files_2000(i_file))
        print(string_files_1850(i_file))

        var_data = read_variable_from_files(files_1850_yr,files_2000_yr,variable_name) 
        var_LU1850_SE(year_count,:,:) = var_data[0]
        var_LU2000_SE(year_count,:,:) = var_data[1]

        year_count = year_count+1
        delete([/files_2000_yr,files_1850_yr,var_data/])
  end do

  var_LU2000_SE!1 = "time_mon"
  var_LU2000_SE&time_mon = ispan(1,12,1)
  var_LU1850_SE!1 = "time_mon"
  var_LU1850_SE&time_mon = ispan(1,12,1)

  printVarSummary(var_LU2000_SE)
  printVarSummary(var_LU1850_SE)

  var_LU2000_SE_clim = dim_avg_n_Wrap(var_LU2000_SE,0)
  var_LU1850_SE_clim = dim_avg_n_Wrap(var_LU1850_SE,0)

;--------------------------------------------------------------------------------------------------------------------------------
  weights_file = "/global/cscratch1/sd/devanand/T_extremes_CESM2_output_working/lndvar_regrid_weights/ne240conus_to_nldasgrid_weights_clm"+variable_name+".nc"
  var_LU2000 = ESMF_regrid_with_weights(var_LU2000_SE_clim,weights_file,False)
  var_LU1850 = ESMF_regrid_with_weights(var_LU1850_SE_clim,weights_file,False)
  var_LU2000_minus_1850 = var_LU2000-var_LU1850
  copy_VarMeta(var_LU2000,var_LU2000_minus_1850)

;  setfileoption("nc","Format","NetCDF4")
  data_filename = "/global/cscratch1/sd/devanand/T_extremes_CESM2_output_working/Model_evaluation/ne240_ne240_ncfiles/"+variable_name+"_mon_nldasgrid.nc"
  system("rm -f " + data_filename)
  data_nc = addfile(data_filename,"c")
  var_name = variable_name+"_LU2000"
  data_nc->$var_name$    = var_LU2000
  var_name = variable_name+"_LU1850"
  data_nc->$var_name$    = var_LU1850
  var_name = variable_name+"_LU2000_minus_1850"
  data_nc->$var_name$    = var_LU2000_minus_1850

end
