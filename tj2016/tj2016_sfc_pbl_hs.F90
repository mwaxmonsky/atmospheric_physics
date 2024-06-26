module TJ2016_sfc_pbl_hs
    use ccpp_kinds, only: kind_phys
  
    implicit none
    private
    save

    public :: tj2016_sfc_pbl_hs_run

contains

    !=======================================================================
    ! Surface fluxes and planetary boundary layer parameterization  
    !=======================================================================

    !> \section arg_table_tj2016_sfc_pbl_hs_run  Argument Table
    !! \htmlinclude tj2016_sfc_pbl_hs_run.html
    subroutine tj2016_sfc_pbl_hs_run(ncol, pver, pverp, index_top_interface, index_surface,    &
        index_surface_interface, gravit, pi, cappav, rairv,                                    &
        cpairv, latvap, rh2o, epsilo, rhoh2o, zvirv, ps0, etamid, dtime, clat,                 &
        PS, pmid, pint, lnpint, rpdel, stateT, U, dudt, V, dvdt, qv, shflx, lhflx, taux, tauy, &
        evap, dqdt_vdiff, dtdt_vdiff, dtdt_heating, Km, Ke, Tsurf, tendency_of_air_enthalpy,   &
        scheme_name, errmsg, errflg)
    !------------------------------------------------
    !   Input / output parameters
    !------------------------------------------------

    integer,  intent(in)           :: ncol                    ! number of columns
    integer,  intent(in)           :: pver                    ! number of vertical levels
    integer,  intent(in)           :: pverp                   ! number of vertical levels + 1
    integer,  intent(in)           :: index_top_interface     ! index of top interface
    integer,  intent(in)           :: index_surface           ! index of surface (layer)
    integer,  intent(in)           :: index_surface_interface ! index of surface (interface)

    real(kind_phys), intent(in)    :: gravit              ! g: gravitational acceleration (m/s2)
    real(kind_phys), intent(in)    :: pi                  ! pi constant
    real(kind_phys), intent(in)    :: cappav(:,:)         ! Rd/cp
    real(kind_phys), intent(in)    :: rairv(:,:)          ! Rd: dry air gas constant (J/K/kg)
    real(kind_phys), intent(in)    :: cpairv(:,:)         ! cp: specific heat of dry air (J/K/kg)
    real(kind_phys), intent(in)    :: latvap              ! L: latent heat of vaporization (J/kg)
    real(kind_phys), intent(in)    :: rh2o                ! Rv: water vapor gas constant (J/K/kg)
    real(kind_phys), intent(in)    :: epsilo              ! ratio of h2o to dry air molecular weights
    real(kind_phys), intent(in)    :: rhoh2o              ! density of liquid water (kg/m3)
    real(kind_phys), intent(in)    :: zvirv(:,:)          ! (rh2o/rair) - 1, needed for virtual temperature
    real(kind_phys), intent(in)    :: ps0                 ! Base state surface pressure (Pa)
    real(kind_phys), intent(in)    :: etamid(:)           ! hybrid coordinate - midpoints

    real(kind_phys), intent(in)    :: dtime               ! time step (s)
    real(kind_phys), intent(in)    :: clat(:)             ! latitude
    real(kind_phys), intent(in)    :: PS(:)               ! surface pressure (Pa)
    real(kind_phys), intent(in)    :: pmid(:,:)           ! mid-point pressure (Pa)
    real(kind_phys), intent(in)    :: pint(:,:)           ! interface pressure (Pa)
    real(kind_phys), intent(in)    :: lnpint(:,:)         ! ln(interface pressure (Pa)) at and above the surface
    real(kind_phys), intent(in)    :: rpdel(:,:)          ! reciprocal of layer thickness (Pa)

    real(kind_phys), intent(in)    :: stateT(:,:)         ! temperature (K)
    real(kind_phys), intent(in)    :: U(:,:)              ! zonal wind (m/s)
    real(kind_phys), intent(out)   :: dudt(:,:)           ! zonal wind tendency (m/s)
    real(kind_phys), intent(in)    :: V(:,:)              ! meridional wind (m/s)
    real(kind_phys), intent(out)   :: dvdt(:,:)           ! meridional wind tendency (m/s)
    real(kind_phys), intent(inout) :: qv(:,:)             ! moisture variable (vapor form) Q (kg/kg)

    real(kind_phys), intent(out)   :: shflx(:)            ! surface sensible heat flux (W/m2)
    real(kind_phys), intent(out)   :: lhflx(:)            ! surface latent heat flux   (W/m2)
    real(kind_phys), intent(out)   :: taux(:)             ! surface momentum flux in the zonal direction (N/m2)
    real(kind_phys), intent(out)   :: tauy(:)             ! surface momentum flux in the meridional direction (N/m2)
    real(kind_phys), intent(out)   :: evap(:)             ! surface water flux (kg/m2/s)
    real(kind_phys), intent(out)   :: dqdt_vdiff(:,:)     ! Q tendency due to vertical diffusion (PBL) (kg/kg/s)
    real(kind_phys), intent(out)   :: dtdt_vdiff(:,:)     ! T tendency due to vertical diffusion (PBL) in K/s
    real(kind_phys), intent(out)   :: dtdt_heating(:,:)   ! temperature tendency in K/s from relaxation
    real(kind_phys), intent(out)   :: Km(:,:)             ! Eddy diffusivity for boundary layer calculations
    real(kind_phys), intent(out)   :: Ke(:,:)             ! Eddy diffusivity for boundary layer calculations
    real(kind_phys), intent(out)   :: Tsurf(:)            ! sea surface temperature K (varied by latitude)
    real(kind_phys), intent(out)   :: tendency_of_air_enthalpy(:,:)

    character(len=512), intent(out):: scheme_name
    character(len=512), intent(out):: errmsg
    integer,            intent(out):: errflg

    !------------------------------------------------
    !   Local variables
    !------------------------------------------------
    

    ! Constants and variables for the modified Held-Suarez forcing
    real(kind_phys), parameter :: sec_per_day = 86400._kind_phys              ! number of seconds per day
    real(kind_phys), parameter :: kf=1._kind_phys/( 1._kind_phys*sec_per_day) ! 1./efolding_time for wind dissipation  (1/s)
    real(kind_phys), parameter :: ka=1._kind_phys/(40._kind_phys*sec_per_day) ! 1./efolding_time for temperature diss. (1/s)
    real(kind_phys), parameter :: ks=1._kind_phys/( 4._kind_phys*sec_per_day) ! 1./efolding_time for temperature diss. (1/s)
    real(kind_phys), parameter :: sigmab=0.7_kind_phys                        ! threshold sigma level (PBL level)
    real(kind_phys), parameter :: onemsig=1._kind_phys-sigmab                 ! 1. - sigma_reference
    real(kind_phys), parameter :: t00 = 200._kind_phys                        ! minimum reference temperature (K)
    real(kind_phys), parameter :: t_max=294._kind_phys                        ! modified maximum HS equilibrium temperature (HS original is 315 K)
    real(kind_phys), parameter :: delta_T=65._kind_phys                       ! difference in eq-polar HS equilibrium temperature (HS original is 60 K)
    real(kind_phys), parameter :: delta_theta=10._kind_phys                   ! parameter for vertical temperature gradient (K)
    real(kind_phys)            :: kv                                          ! 1./efolding_time (normalized) for wind (1/s)
    real(kind_phys)            :: kt                                          ! 1./efolding_time for temperature diss. (1/s)
    real(kind_phys)            :: trefa                                       ! "radiative equilibrium" T (K)
    real(kind_phys)            :: trefc                                       ! used in calc of "radiative equilibrium" T

    ! Trig functions
    real(kind_phys) :: cossq(ncol)                              ! coslat**2
    real(kind_phys) :: cossqsq(ncol)                            ! coslat**4
    real(kind_phys) :: sinsq(ncol)                              ! sinlat**2
    real(kind_phys) :: coslat(ncol)                             ! cosine(latitude)

    ! Simplified physics: constants
    real(kind_phys), parameter :: T_min      = 271._kind_phys                    ! Minimum sea surface temperature (K)
    real(kind_phys), parameter :: del_T      = 29._kind_phys                     ! difference in eq-polar sea surface temperature (K)
    real(kind_phys)            :: T_width                                        ! width parameter for sea surface temperature (C)
    real(kind_phys), parameter :: Tsurf_RJ12 = 302.15_kind_phys                  ! constant sea surface temperature (K) for RJ12

    real(kind_phys), parameter :: T0=273.16_kind_phys       ! Control temperature (K) for calculation of qsat
    real(kind_phys), parameter :: e0=610.78_kind_phys       ! Saturation vapor pressure (Pa) at T0 for calculation of qsat
    real(kind_phys), parameter :: Cd0=0.0007_kind_phys      ! Constant for calculating Cd from Smith and Vogl (2008)
    real(kind_phys), parameter :: Cd1=0.000065_kind_phys    ! Constant for calculating Cd from Smith and Vogl (2008)
    real(kind_phys), parameter :: Cm=0.002_kind_phys        ! Constant for calculating Cd from Smith and Vogl (2008)
    real(kind_phys), parameter :: v20=20.0_kind_phys        ! Threshold wind speed (m/s) for calculating Cd from Smith and Vogl (2008)
    real(kind_phys)            :: C                         ! Surface exchange coefficient for sensible and latent heat, depends on simple_physics_option
    real(kind_phys), parameter :: pbltop=85000._kind_phys   ! Pressure (Pa) at the top of boundary layer
    real(kind_phys), parameter :: pblconst=10000._kind_phys ! Constant (Pa) for the calculation of the decay of diffusivity

    ! Variables for the simple-physics and moist HS boundary layer turbulence calculation
    real(kind_phys)            :: wind(ncol)         ! wind speed at the lowest model level (m/s)
    real(kind_phys)            :: rho(ncol)          ! Air density near the ground (kg/m3)
    real(kind_phys)            :: Cd(ncol)           ! Drag coefficient for momentum
    real(kind_phys)            :: za(ncol)           ! Height at midpoint of the lowest model level (m)
    real(kind_phys)            :: dlnpint            ! Used for calculation of heights

    ! Variables for the simple-physics and moist HS boundary layer turbulence calculation (for T and qv)
    real(kind_phys)            :: CA(ncol,pver)      ! Matrix Coefficents for PBL Scheme
    real(kind_phys)            :: CC(ncol,pver)      ! Matrix Coefficents for PBL Scheme
    real(kind_phys)            :: CE(ncol,pverp)    ! Matrix Coefficents for PBL Scheme
    real(kind_phys)            :: CFt(ncol,pverp)   ! Matrix Coefficents for PBL Scheme
    real(kind_phys)            :: CFq(ncol,pverp)   ! Matrix Coefficents for PBL Scheme

    ! Variables for the simple-physics boundary layer turbulence calculation for u and v, not used by JT16, only by RJ12 
    real(kind_phys)            :: CAm(ncol,pver)     ! Matrix Coefficents for PBL Scheme
    real(kind_phys)            :: CCm(ncol,pver)     ! Matrix Coefficents for PBL Scheme
    real(kind_phys)            :: CEm(ncol,pverp)   ! Matrix Coefficents for PBL Scheme
    real(kind_phys)            :: CFu(ncol,pverp)   ! Matrix Coefficents for PBL Scheme
    real(kind_phys)            :: CFv(ncol,pverp)   ! Matrix Coefficents for PBL Scheme

    ! Variable for surface flux calculation
    real(kind_phys)            :: qsat               ! saturation value for Q (kg/kg)

    ! Temporary storage variable
    real(kind_phys)            :: tmp
    real(kind_phys)            :: UCopy(ncol, pver)  ! Local copy of modifiable U
    real(kind_phys)            :: VCopy(ncol, pver)  ! Local copy of modifiable V
    real(kind_phys)            :: TCopy(ncol, pver)  ! air temperature (K) _before_ run

    ! Loop variables
    integer             :: i, k

    ! Vertical index loop control variable:
    integer             :: vdir

    ! Define simple_physics_option to either "TJ16" (moist HS) or "RJ12" (simple-physics)
    character(LEN=4)    :: simple_physics_option

    ! Initialize certain constants
    T_width    = 26.0_kind_phys*pi/180.0_kind_phys

    ! Initialize certain outfields
    tendency_of_air_enthalpy = 0.0_kind_phys
    scheme_name              = "TJ2016_sfc_pbl_hs"
    errmsg                   = ' '
    errflg                   = 0

    ! Set local copies to not modify model state directly
    UCopy = U
    VCopy = V
    TCopy = stateT

    simple_physics_option = "TJ16"   ! Set the simple_physics_option "TJ16" (default, moist HS)
    ! simple_physics_option = "RJ12"   ! alternative simple-physics forcing, Reed and Jablonowski (2012)

    ! Determine what direction vertical integration/looping should occur:
    if (index_top_interface < index_surface) then
       vdir = 1
    else
       vdir = -1
    end if

    !==========================================================================
    ! Calculate Sea Surface Temperature and set exchange coefficient
    !==========================================================================
    if (simple_physics_option == "TJ16") then
        C=0.0044_kind_phys  ! Surface exchange coefficient for sensible and latent heat for moist HS
        do i = 1, ncol      ! set SST profile
            Tsurf(i) = del_T*exp(-(((clat(i))**2.0_kind_phys)/(2.0_kind_phys*(T_width**2.0_kind_phys)))) + T_min
        end do
    else                          ! settings for RJ12
        C     = 0.0011_kind_phys  ! Surface exchange coefficient for sensible and latent heat for simple-physics
        Tsurf = Tsurf_RJ12        ! constant SST
    endif

    !==========================================================================
    ! Pre-calculate trig functions
    !==========================================================================
    do i = 1, ncol
        coslat (i) = cos(clat(i))
        sinsq  (i) = sin(clat(i))*sin(clat(i))
        cossq  (i) = coslat(i)*coslat(i)
        cossqsq(i) = cossq (i)*cossq (i)
    end do

    !==========================================================================
    ! Initialize accumulated tendencies due to Eddy diffusion
    !==========================================================================
    dqdt_vdiff = 0.0_kind_phys
    dtdt_vdiff = 0.0_kind_phys

    !==========================================================================
    ! Calculate hydrostatic height za of the lowermost model level
    !==========================================================================
    do i = 1, ncol
        dlnpint = (lnpint(i,index_surface_interface) - lnpint(i,index_surface))
        za(i)   = rairv(i,index_surface)/gravit*stateT(i,index_surface)*(1._kind_phys+zvirv(i,index_surface)*qv(i,index_surface))*0.5_kind_phys*dlnpint
    end do

    !==========================================================================
    ! Simple-physics surface fluxes and turbulence scheme for heat and moisture
    !
    ! The PBL parameterization is based on a simplified Ekman
    ! theory (constant Ke below 850 hPa). Ke is updated at each time step
    ! and is linked to surface conditions. First, T and Q are updated with the
    ! surface flux at the lowermost model level and then the semi-implicit
    ! PBL scheme is applied.
    !
    ! Details of the surface flux and PBL implementation can be found in:
    ! Thatcher and Jablonowski (GMD, 2016) and Reed and Jablonowski (JAMES, 2012).
    !
    ! Note that the exchange coefficient C is set to a different constant 
    ! in TJ16 and RJ12.
    !==========================================================================

    !--------------------------------------------------------------------------
    ! Compute magnitude of the low-level wind, and diffusion coeffients (Ke and Km)
    ! for PBL turbulence scheme (Eddy diffusivity), 
    ! Ke is used for heat and moisture (used by TJ16 and RJ12)
    ! Km is used for momentum (not used by TJ16, only RJ12)
    !--------------------------------------------------------------------------
    do i = 1, ncol
        wind(i) = sqrt(UCopy(i,index_surface)**2 + VCopy(i,index_surface)**2)   ! wind speed closest to the surface
    end do
    do i = 1, ncol
        Ke(i,index_surface_interface) = C*wind(i)*za(i)
        if (wind(i) < v20) then                 ! if wind speed is less than 20 m/s
            Cd(i)        = Cd0+Cd1*wind(i)
            Km(i,index_surface_interface) = Cd(i)*wind(i)*za(i)
        else
            Cd(i)        = Cm
            Km(i,index_surface_interface) = Cm*wind(i)*za(i)
        end if
    end do

    do k = 1, pver
        do i = 1, ncol
            if( pint(i,k) >= pbltop) then
                ! keep diffusion coefficients constant below pbltop 
                Km(i,k) = Km(i,index_surface_interface)
                Ke(i,k) = Ke(i,index_surface_interface)
            else
                ! PBL diffusion coefficients are dragged to zero above pbltop
                Km(i,k) = Km(i,index_surface_interface)*exp(-(pbltop-pint(i,k))**2/(pblconst)**2)
                Ke(i,k) = Ke(i,index_surface_interface)*exp(-(pbltop-pint(i,k))**2/(pblconst)**2)
            end if
        end do
    end do

    !--------------------------------------------------------------------------
    ! Compute sensible and latent heat surface fluxes using an implicit approach
    ! and update the variables T and qv
    ! note: this only occurs in the lowermost model level
    !--------------------------------------------------------------------------
    do i = 1, ncol
        qsat   = epsilo*e0/PS(i)*exp(-latvap/rh2o*((1._kind_phys/Tsurf(i))-1._kind_phys/T0))        ! saturation value for Q at the surface
        rho(i) = pmid(i,index_surface)/(rairv(i,index_surface) * stateT(i,index_surface) *(1._kind_phys+zvirv(i,index_surface)*qv(i,index_surface)))  ! air density at the lowest level rho = p/(Rd Tv)

        tmp                = (stateT(i,index_surface)+C*wind(i)*Tsurf(i)*dtime/za(i))/(1._kind_phys+C*wind(i)*dtime/za(i)) ! new T
        dtdt_vdiff(i,index_surface) = (tmp-stateT(i,index_surface))/dtime                                    ! T tendency due to surface flux 
        shflx(i)           = rho(i) * cpairv(i,index_surface) * C*wind(i)*(Tsurf(i)-stateT(i,index_surface)) ! sensible heat flux (W/m2)
        TCopy(i,index_surface)          = tmp                                                      ! update T

        tmp                = (qv(i,index_surface)+C*wind(i)*qsat*dtime/za(i))/(1._kind_phys+C*wind(i)*dtime/za(i)) ! new Q 
        dqdt_vdiff(i,index_surface) = (tmp-qv(i,index_surface))/dtime                                   ! Q tendency due to surface flux
        lhflx(i)           = rho(i) * latvap * C*wind(i)*(qsat-qv(i,index_surface))            ! latent heat flux (W/m2)
        evap(i)            = rho(i) * C*wind(i)*(qsat-qv(i,index_surface))                     ! surface water flux (kg/m2/s)
        qv(i,index_surface)         = tmp                                                      ! update Q
    end do

    if (simple_physics_option == "RJ12") then
        !--------------------------------------------------------------------------
        ! If the configuration is set to the simple-physics package by RJ12 compute
        ! surface momentum fluxes using an implicit approach and update the variables u and v 
        ! note: this only occurs in the lowermost model level and the density field rho from
        ! above is used 
        !--------------------------------------------------------------------------
        do i = 1, ncol
            tmp           = Cd(i) * wind(i)
            taux(i)       = -rho(i) * tmp * UCopy(i,index_surface)                 ! zonal surface momentum flux (N/m2)
            UCopy(i,index_surface) = UCopy(i,index_surface)/(1._kind_phys+tmp*dtime/za(i))  ! new U
            tauy(i)       = -rho(i) * tmp * VCopy(i,index_surface)                 ! meridional surface momentum flux (N/m2)
            VCopy(i,index_surface) = VCopy(i,index_surface)/(1._kind_phys+tmp*dtime/za(i))  ! new V
        enddo
    endif

    !--------------------------------------------------------------------------
    ! Calculate Diagonal Variables for PBL Scheme (semi-implicit technique follows the CESM PBL implementation)
    !--------------------------------------------------------------------------
    do k = index_top_interface, index_surface-vdir, vdir
        do i = 1, ncol
            rho(i)     = (pint(i,k+vdir)/(rairv(i,k)*(TCopy(i,k+vdir)*(1._kind_phys+zvirv(i,index_surface)*qv(i,k+vdir))+TCopy(i,k)*(1._kind_phys+zvirv(i,index_surface)*qv(i,k)))/2.0_kind_phys))
            CA(i,k)    = rpdel(i,k)*dtime*gravit*gravit*Ke(i,k+vdir)*rho(i)*rho(i)/(pmid(i,k+vdir)-pmid(i,k))
            CC(i,k+vdir)  = rpdel(i,k+vdir)*dtime*gravit*gravit*Ke(i,k+vdir)*rho(i)*rho(i)/(pmid(i,k+vdir)-pmid(i,k))
            ! the next two PBL variables are initialized here for the potential use of RJ12 instead of TJ16
            ! since they need to use the same density field rho
            CAm(i,k)   = rpdel(i,k)*dtime*gravit*gravit*Km(i,k+vdir)*rho(i)*rho(i)/(pmid(i,k+vdir)-pmid(i,k))
            CCm(i,k+vdir) = rpdel(i,k+vdir)*dtime*gravit*gravit*Km(i,k+vdir)*rho(i)*rho(i)/(pmid(i,k+vdir)-pmid(i,k))
        end do
    end do
    do i = 1, ncol
        CA(i,index_surface)            = 0._kind_phys
        CC(i,index_top_interface)      = 0._kind_phys
        CE(i,index_surface_interface)  = 0._kind_phys
        CFt(i,index_surface_interface) = 0._kind_phys
        CFq(i,index_surface_interface) = 0._kind_phys
    end do
    do i = 1, ncol
        do k = index_surface, index_top_interface, -1*vdir
            CE(i,k)  = CC(i,k)/(1._kind_phys+CA(i,k)+CC(i,k)-CA(i,k)*CE(i,k+vdir))
            CFt(i,k) = ((ps0/pmid(i,k))**cappav(i,k)*TCopy(i,k)+CA(i,k)*CFt(i,k+vdir))/(1._kind_phys+CA(i,k)+CC(i,k)-CA(i,k)*CE(i,k+vdir))
            CFq(i,k) = (qv(i,k)+CA(i,k)*CFq(i,k+vdir))/(1._kind_phys+CA(i,k)+CC(i,k)-CA(i,k)*CE(i,k+vdir))
        end do
    end do

    !--------------------------------------------------------------------------
    ! Calculate the updated temperature T and moisture Q fields
    !--------------------------------------------------------------------------

    !---------------------------------------------------------------------
    ! First: calculate the PBL mixing tendencies at the top model level
    !---------------------------------------------------------------------
    do i = 1, ncol
        tmp             = CFt(i,index_top_interface)*(pmid(i,index_top_interface)/ps0)**cappav(i,index_top_interface)  ! new T at the model top
        dtdt_vdiff(i,index_top_interface) = (tmp-TCopy(i,index_top_interface))/dtime                                   ! T tendency due to PBL diffusion (model top)
        TCopy(i,index_top_interface)      = tmp                                                                        ! update T at the model top

        dqdt_vdiff(i,index_top_interface) = (CFq(i,index_top_interface)-qv(i,index_top_interface))/dtime               ! Q tendency due to PBL diffusion (model top)
        qv(i,index_top_interface)         = CFq(i,index_top_interface)                                                 ! update Q at the model top
    end do

    !-----------------------------------------
    ! PBL mixing at all other model levels
    !-----------------------------------------
    do i = 1, ncol
        do k = index_top_interface+vdir, index_surface
            tmp             = (CE(i,k)*TCopy(i,k-vdir)*(ps0/pmid(i,k-vdir))**cappav(i,k)+CFt(i,k))*(pmid(i,k)/ps0)**cappav(i,k)  ! new T
            dtdt_vdiff(i,k) = dtdt_vdiff(i,k) + (tmp-TCopy(i,k))/dtime  ! update the T tendency due to surface fluxes and the PBL diffusion
            TCopy(i,k)          = tmp                                   ! update T

            tmp             = CE(i,k)*qv(i,k-vdir)+CFq(i,k)         ! new Q
            dqdt_vdiff(i,k) = dqdt_vdiff(i,k) + (tmp-qv(i,k))/dtime ! update the Q tendency due to surface fluxes and the PBL diffusion
            qv(i,k)         = tmp                                   ! update Q
        end do
    end do

    if (simple_physics_option == "TJ16") then
        !==========================================================================
        ! modified HS forcing (see Thatcher and Jablonowski (GMD, 2016))
        !--------------------------------------------------------------------------
        ! The original Held-Suarez (HS) physics algorithm is described in
        !
        !   Held, I. M., and M. J. Suarez, 1994: A proposal for the
        !   intercomparison of the dynamical cores of atmospheric general
        !   circulation models.
        !   Bulletin of the Amer. Meteor. Soc., vol. 75, pp. 1825-1830
        !
        ! The modified version uses the redefined parameters: trefc, delta_T  
        !==========================================================================

        !--------------------------------------------------------------------------
        !  Compute frictional tendency from HS Rayleigh Friction (RF) at the lowest
        !  level as a diagnostic (surface momentum fluxes)
        !--------------------------------------------------------------------------
        kv  = kf*(etamid(index_surface) - sigmab)/onemsig                                 ! RF coefficient at the lowest level
        do i = 1, ncol
            dlnpint = (lnpint(i,index_surface_interface) - lnpint(i,index_surface))
            za(i)   = rairv(i,index_surface)/gravit*TCopy(i,index_surface)*(1._kind_phys+zvirv(i,index_surface)*qv(i,index_surface))*0.5_kind_phys*dlnpint ! height of lowest full model level
            rho(i)  = pmid(i,index_surface)/(rairv(i,index_surface) * TCopy(i,index_surface) *(1._kind_phys+zvirv(i,index_surface)*qv(i,index_surface)))            ! air density at the lowest level rho = p/(Rd Tv)
            taux(i) = -kv * rho(i) * UCopy(i,index_surface) * za(i)                                                         ! U surface momentum flux in N/m2
            tauy(i) = -kv * rho(i) * VCopy(i,index_surface) * za(i)                                                         ! V surface momentum flux in N/m2
        end do

        !--------------------------------------------------------------------------
        ! Apply HS Rayleigh Friction (RF) near the surface (below eta=0.7):
        ! represents surface stresses and PBL diffusion for U and V
        !--------------------------------------------------------------------------
        do k = index_top_interface, index_surface
            if (etamid(k) > sigmab) then
                kv  = kf*(etamid(k) - sigmab)/onemsig             ! RF coefficient
                do i=1,ncol
                    UCopy(i,k) = UCopy(i,k) -kv*UCopy(i,k)*dtime  ! apply RF to U
                    VCopy(i,k) = VCopy(i,k) -kv*VCopy(i,k)*dtime  ! apply RF to V
                end do
            end if
        end do

        !-----------------------------------------------------------------------
        ! Compute idealized radiative heating rates (with modified HS equilibrium temperature)
        ! mimics radiation
        !-----------------------------------------------------------------------
        do k = index_top_interface, index_surface
            if (etamid(k) > sigmab) then                                        ! lower atmosphere
                do i = 1, ncol
                    kt = ka + (ks - ka)*cossqsq(i)*(etamid(k) - sigmab)/onemsig ! relaxation coefficent varies in the vertical
                    trefc             = T_max - delta_T*sinsq(i)
                    trefa             = (trefc - delta_theta*cossq(i)*log((pmid(i,k)/ps0)))*(pmid(i,k)/ps0)**cappav(i,k)
                    trefa             = max(t00,trefa)                          ! relaxation temperature
                    dtdt_heating(i,k) = (trefa - TCopy(i,k))*kt                     ! temperature forcing due to relaxation
                    TCopy(i,k)            = TCopy(i,k) + dtdt_heating(i,k)*dtime        ! update T
                end do
            else
                do i=1,ncol
                    trefc             = T_max - delta_T*sinsq(i)
                    trefa             = (trefc - delta_theta*cossq(i)*log((pmid(i,k)/ps0)))*(pmid(i,k)/ps0)**cappav(i,k)
                    trefa             = max(t00,trefa)                          ! relaxation temperature
                    dtdt_heating(i,k) = (trefa - TCopy(i,k))*ka                     ! temperature forcing due to relaxation
                    TCopy(i,k)            = TCopy(i,k) + dtdt_heating(i,k)*dtime        ! update T
                end do
            end if
        end do

    else 
        !==========================================================================
        ! RJ12: Surface flux and PBL forcing of u and v follows the Reed-Jablonowski simple-physics configuration
        !       no HS temperature relaxation is used which limits this configuration to
        !       short simulation periods (under 30 days)
        !--------------------------------------------------------------------------

        !--------------------------------------------------------------------------
        ! Calculate Diagonal Variables for PBL Scheme (semi-implicit technique follows the CESM PBL implementation)
        ! The fields CAm and CCm are also initialized above to guarantee the use of the same density.
        !--------------------------------------------------------------------------
        do i = 1, ncol
            CAm(i,index_surface)           = 0._kind_phys
            CCm(i,index_top_interface)         = 0._kind_phys
            CEm(i,index_surface_interface) = 0._kind_phys
            CFu(i,index_surface_interface) = 0._kind_phys
            CFv(i,index_surface_interface) = 0._kind_phys
        end do
        do i = 1, ncol
            do k = index_surface, index_top_interface, -1*vdir
                CEm(i,k) = CCm(i,k)/(1._kind_phys+CAm(i,k)+CCm(i,k)-CAm(i,k)*CEm(i,k+vdir))
                CFu(i,k) = (UCopy(i,k)+CAm(i,k)*CFu(i,k+vdir))/(1._kind_phys+CAm(i,k)+CCm(i,k)-CAm(i,k)*CEm(i,k+vdir))
                CFv(i,k) = (VCopy(i,k)+CAm(i,k)*CFv(i,k+vdir))/(1._kind_phys+CAm(i,k)+CCm(i,k)-CAm(i,k)*CEm(i,k+vdir))
            end do
        end do

        !--------------------------------------------------------------------------
        ! Calculate the updated velocity fields U and V
        !--------------------------------------------------------------------------

        !---------------------------------------------------------------------
        ! First: calculate the PBL diffusive tendencies at the top model level
        !---------------------------------------------------------------------
        do i = 1, ncol
            UCopy(i,index_top_interface) = CFu(i,index_top_interface)  ! new U at the model top
            VCopy(i,index_top_interface) = CFv(i,index_top_interface)  ! new V at the model top
        end do

        !-----------------------------------------
        ! PBL diffusion of U and V at all other model levels
        !-----------------------------------------
        do i = 1, ncol
            do k = index_top_interface+vdir, index_surface
                UCopy(i,k) = CEm(i,k)*UCopy(i,k-vdir) + CFu(i,k)  ! new U
                VCopy(i,k) = CEm(i,k)*VCopy(i,k-vdir) + CFv(i,k)  ! new V
            end do
        end do
    endif

    do i = 1, ncol
        do k = index_top_interface, index_surface
            dudt(i, k)                    = (UCopy(i, k) - U(i, k)) / dtime
            dvdt(i, k)                    = (VCopy(i, k) - V(i, k)) / dtime
            tendency_of_air_enthalpy(i,k) = (TCopy(i,k) - stateT(i,k)) / dtime * cpairv(i,k)
        end do
    end do

    end subroutine tj2016_sfc_pbl_hs_run

end module TJ2016_sfc_pbl_hs
