!> Top-level wrapper for MUSICA chemistry components
module musica_ccpp
  use musica_ccpp_micm, only : micm_register, micm_init, micm_run, micm_final

  implicit none
  private

  public :: musica_ccpp_register, musica_ccpp_init, musica_ccpp_run, musica_ccpp_final

contains

  subroutine musica_ccpp_register(constituents, errmsg, errcode)
    use ccpp_constituent_prop_mod, only : ccpp_constituent_properties_t
    type(ccpp_constituent_properties_t), allocatable, intent(out) :: constituents(:)
    character(len=512), intent(out) :: errmsg
    integer, intent(out) :: errcode

    call micm_register(constituents, errmsg, errcode)
  end subroutine musica_ccpp_register

  !> \section arg_table_musica_ccpp_init Argument Table
  !! \htmlinclude musica_ccpp_init.html
  subroutine musica_ccpp_init(errmsg, errcode)
    character(len=512), intent(out) :: errmsg
    integer, intent(out) :: errcode

    call micm_init(errmsg, errcode)
  end subroutine musica_ccpp_init

  !> \section arg_table_musica_ccpp_run Argument Table
  !! \htmlinclude musica_ccpp_run.html
  subroutine musica_ccpp_run(time_step, temperature, pressure, dry_air_density, constituent_props, &
                      constituents, errmsg, errcode)
    use ccpp_kinds, only: kind_phys
    use ccpp_constituent_prop_mod, only: ccpp_constituent_prop_ptr_t

    real(kind_phys),                   intent(in)    :: time_step            ! s
    real(kind_phys),                   intent(in)    :: temperature(:,:)     ! K
    real(kind_phys),                   intent(in)    :: pressure(:,:)        ! Pa
    real(kind_phys),                   intent(in)    :: dry_air_density(:,:) ! kg m-3
    type(ccpp_constituent_prop_ptr_t), intent(in)    :: constituent_props(:)
    real(kind_phys),                   intent(inout) :: constituents(:,:,:)  ! kg kg-1
    character(len=512),                intent(out)   :: errmsg
    integer,                           intent(out)   :: errcode

    call micm_run(time_step, temperature, pressure, dry_air_density, constituent_props, &
                  constituents, errmsg, errcode)

  end subroutine musica_ccpp_run

  !> \section arg_table_musica_ccpp_final Argument Table
  !! \htmlinclude musica_ccpp_final.html
  subroutine musica_ccpp_final(errmsg, errcode)
    integer, intent(out) :: errcode
    character(len=512), intent(out) :: errmsg

    call micm_final(errmsg, errcode)
  end subroutine musica_ccpp_final

end module musica_ccpp
