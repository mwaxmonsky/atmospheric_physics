module check_energy_fix
  use ccpp_kinds, only: kind_phys

  implicit none
  private

  public  :: check_energy_fix_run

contains

  ! Add heating rate required for global mean total energy conservation
!> \section arg_table_check_energy_fix_run Argument Table
!! \htmlinclude arg_table_check_energy_fix_run.html
  subroutine check_energy_fix_run(ncol, pver, pint, gravit, heat_glob, ptend_s, eshflx, scheme_name, errmsg, errflg)
    ! Input arguments
    integer,            intent(in)    :: ncol           ! number of atmospheric columns
    integer,            intent(in)    :: pver           ! number of vertical layers
    real(kind_phys),    intent(in)    :: pint(:,:)      ! interface pressure [Pa]
    real(kind_phys),    intent(in)    :: gravit         ! gravitational acceleration [m s-2]
    real(kind_phys),    intent(in)    :: heat_glob      ! global mean heating rate [J kg-1 s-1]
    real(kind_phys),    intent(out)   :: ptend_s(:,:)   ! physics tendency heating rate [J kg-1 s-1]
    real(kind_phys),    intent(out)   :: eshflx(:)      ! effective sensible heat flux [W m-2]
                                                        ! for check_energy_chng

    ! Output arguments
    character(len=64),  intent(out)   :: scheme_name    ! scheme name
    character(len=512), intent(out)   :: errmsg         ! error message
    integer,            intent(out)   :: errflg         ! error flag

    ! Local variables
    integer :: i

    errmsg = ''
    errflg = 0

    ! Set scheme name for check_energy_chng
    scheme_name = "check_energy_fix"

    ! add (-) global mean total energy difference as heating
    ptend_s(:ncol, :pver) = heat_glob

    ! compute effective sensible heat flux
    do i = 1, ncol
      eshflx(i) = heat_glob * (pint(i,pver+1) - pint(i,1)) / gravit
    end do
  end subroutine check_energy_fix_run

end module check_energy_fix
