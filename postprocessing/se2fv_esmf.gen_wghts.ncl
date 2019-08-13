;----------------------------------------------------------------------
; Original code written by Dennis Shea and modified by Sheri Mickelson
; March 2013 and then by Keith Oleson October 2013
; ----------------- Anjana -------------- 26 Feb 2019
; used to generate wghts and save them
; removed the code lines to write out the regridded variable 
;----------------------------------------------------------------------
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
; Only works for ncl V6.2.0
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

begin

;---Data file containing source grid and variables
    procDir = "/global/cscratch1/sd/devanand/T_extremes_CESM2_output_working/lndvar_regrid_weights/"
    SE_dir   = procDir                                                                                                                  ;getenv("procDir")
    SE_file  = "/global/cscratch1/sd/devanand/archive/LU2000.FHIST.ne240conus/lnd/hist/LU2000.FHIST.ne240conus.clm2.h0.1984-01.nc"      ;getenv("InFile") 

    print("DEBUG NCL se2fv_esmf.regrid2file.ncl SE_dir (procDir) = " + SE_dir)
    print("DEBUG NCL se2fv_esmf.regrid2file.ncl SE_file (InFile) = " + SE_file)

    sfile    = addfile(SE_file,"r")
    SE_nfile = dimsizes(sfile)

    method    = "bilinear"       ;getenv("method")
    oldres    = "ne240conus"     ;getenv("oldres")
    newres    = "nldasgrid"      ;getenv("newres")

;---Get 1d destination lat/lons

    fLL = addfile("/global/cscratch1/sd/devanand/MCS_CESM2_output_working/MCS_Regional_rainfall_analysis/Analyze_tracking_output/NLDAS_FORA0125_H.A20111231.2300.002.nc","r")
    dst_lat = fLL->lat_110
    dst_lon = fLL->lon_110

;---Get all variables on the SE file
    var_in   = getenv("variable_name")   ;"TSA"   ;getfilevarnames( sfile )
    nvar_in  = dimsizes(var_in)

;---Specify a list of variables on the source SE file that should NOT be copied or interpolated
;   var_in_exclude = (/"lat", "lon", "date_written", "time_written", "time_bounds", "ZSOI", "DZSOI", "WATSAT", "SUCSAT", "BSW", "HKSAT", "ZLAKE", "DZLAKE", "area"/)  
    var_in_exclude = (/"lat", "lon", "date_written", "time_written", "time_bounds", "area"/)  

;---Specify a list of variables on the source SE file that should be directly copied 
    var_in_copy = (/"time", "levgrnd", "levlak", "levdcmp", "hist_interval","mscur"/)

;---Specify a list of variables to be regridded
    var_out        = "All_Variables"     ; to be regridded

   WgtFileName = "/global/cscratch1/sd/devanand/T_extremes_CESM2_output_working/lndvar_regrid_weights/ne240conus_to_nldasgrid_weights_clm"+var_in+".nc"

    ;---Convert destination grid to SCRIP file ------ already created SCRIP file, so using that
   SrcSCRIP = "/global/cscratch1/sd/devanand/MCS_CESM2_output_working/MCS_Regional_rainfall_analysis/Analyze_tracking_output/ne240conus_SCRIP_file/SCRIPgrid_conus_30_x8_nomask_c170111.nc"
   SrcSCRIPFileName = "/global/cscratch1/sd/devanand/T_extremes_CESM2_output_working/lndvar_regrid_weights/SCRIPgrid_conus_30_x8_nomask_c170111_"+var_in+".nc"
   system("/bin/cp -f "+SrcSCRIP+" "+SrcSCRIPFileName)

   ; Opt = False
   DstFileName  = "/global/cscratch1/sd/devanand/T_extremes_CESM2_output_working/lndvar_regrid_weights/SCRIPfile_nldasgrid.nc"
   ; rectilinear_to_SCRIP(DstFileName,dst_lat,dst_lon,Opt)   ----  already used this function to generate the SCRIP file for the NLDAS grid

;---Set options for GW (ESMF_regrid_gen_weights)
    Opt_GW = True
    Opt_GW@PrintTimings = False
    Opt_GW@Debug = False
    Opt_GW@InterpMethod = method
;-----added -- Anjana
    Opt_GW@SrcRegional = False
    Opt_GW@DstRegional = True

;---Generate the latitudinal weights
    gw  = latRegWgt(dst_lat, "double", 0)
    gw!0= "lat"

;---Use the destination (FV) grid info on the weight file to create lat/lon
    lat       = dst_lat                  ; get from weight file
    lat@long_name = "latitude"
    lat!0     = "lat"
    lat@units = "degrees_north"
    lat&lat   =  lat
    nlat      = dimsizes(lat)            ; same as dst_nlat

    lon       = dst_lon                  ; get from weight file
    lon@long_name = "longitude"
    lon!0     = "lon"
    lon@units = "degrees_east"
    lon&lon   =  lon
    mlon      = dimsizes(lon)            ; same as dst_mlon

    do nv=0,nvar_in-1
       print(var_in(nv))
       if (.not.any(var_in(nv).eq.var_in_exclude)) then

                 if (var_in(nv) .eq. "landmask" .or. var_in(nv) .eq. "pftmask" .or. var_in(nv) .eq. "nbedrock") then
                   maskmiss = int2flt(sfile->$var_in(nv)$)
                   maskmiss@_FillValue = 0.
                   maskmiss = where(ismissing(maskmiss),0.,1.)
                 else
                   maskmiss = where(ismissing(sfile->$var_in(nv)$),0.,1.)
                 end if
                 cdf_file = addfile(SrcSCRIPFileName,"w")
                 rank_in = dimsizes(getfilevardimsizes(sfile, var_in(nv)))
                 if (rank_in .eq. 1) then
                   cdf_file->grid_imask = (/maskmiss/)
                 else
                   if (rank_in .eq. 2) then
                     cdf_file->grid_imask = (/maskmiss(0,:)/)
                   else
                     if (rank_in .eq. 3) then
                       cdf_file->grid_imask = (/maskmiss(0,0,:)/)
                     end if
                   end if
                 end if

                 ;---Generation of weights
                 ESMF_regrid_gen_weights(SrcSCRIPFileName,DstFileName,WgtFileName,Opt_GW)
                 delete(maskmiss)
       end if
    end do
;    system("/bin/rm -f " + RGRD_dir+"/"+DstFileName)
    system("/bin/rm -f " + SrcSCRIPFileName)

end
