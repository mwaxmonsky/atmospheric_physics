! Copyright (C) 2024-2025 University Corporation for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
module musica_ccpp_tuvx_wavelength_grid

  implicit none

  private
  public :: create_wavelength_grid

  ! TUV-x Wavelegnth grid notes
  !
  !-----------------------------------------------------------------------
  ! The wavelength grid used with TUV-x is based on the grid used in the
  ! CAM-Chem photolysis rate constant lookup tables. Slight modifications
  ! were made to the grid in the Shumann-Runge and Lyman-alpha regions to
  ! work with the expectations of the TUV-x code.
  !
  ! The wavelength grid is defined by the host model. Any wavelength-
  ! resolved quantities passed to TUV-x must be on this grid.

  !> Label for wavelength grid in TUV-x
  character(len=*), parameter, public :: wavelength_grid_label = "wavelength"
  !> Unit for wavelength grid in TUV-x
  character(len=*), parameter, public :: wavelength_grid_unit = "nm"

contains

  !> Creates a TUV-x wavelength grid
  function create_wavelength_grid( wavelength_grid_interfaces, &
      errmsg, errcode ) result( wavelength_grid )

    use ccpp_kinds,       only: kind_phys
    use musica_ccpp_util, only: has_error_occurred
    use musica_tuvx_grid, only: grid_t
    use musica_util,      only: error_t

    real(kind_phys),  intent(in)  :: wavelength_grid_interfaces(:) ! nm
    character(len=*), intent(out) :: errmsg
    integer,          intent(out) :: errcode
    type(grid_t),     pointer     :: wavelength_grid

    ! local variables
    reaL(kind_phys) :: midpoints( size( wavelength_grid_interfaces ) - 1 ) ! nm
    type(error_t)   :: error

    midpoints(:) = &
        0.5 * ( wavelength_grid_interfaces( 1: size( wavelength_grid_interfaces ) - 1 ) &
              + wavelength_grid_interfaces( 2: size( wavelength_grid_interfaces ) ) )
    wavelength_grid => grid_t( wavelength_grid_label, wavelength_grid_unit, &
                               size( midpoints ), error )
    if ( has_error_occurred( error, errmsg, errcode ) ) return
    call wavelength_grid%set_edges( wavelength_grid_interfaces, error )
    if ( has_error_occurred( error, errmsg, errcode ) ) return
    call wavelength_grid%set_midpoints( midpoints, error )
    if ( has_error_occurred( error, errmsg, errcode ) ) return

  end function create_wavelength_grid

end module musica_ccpp_tuvx_wavelength_grid