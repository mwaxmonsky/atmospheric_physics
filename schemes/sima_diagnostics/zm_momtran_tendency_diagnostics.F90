module zm_momtran_tendency_diagnostics
   use ccpp_kinds, only:  kind_phys

   implicit none
   private
   save

   public :: zm_momtran_tendency_diagnostics_init ! init routine
   public :: zm_momtran_tendency_diagnostics_run  ! main routine

CONTAINS

 !> \section arg_table_zm_momtran_tendency_diagnostics_init  Argument Table
 !! \htmlinclude zm_momtran_tendency_diagnostics_init.html
 subroutine zm_momtran_tendency_diagnostics_init(errmsg, errflg)
    use cam_history,         only: history_add_field
    use cam_history_support, only: horiz_only

    character(len=512), intent(out) :: errmsg
    integer,            intent(out) :: errflg

    ! Local variables:

    errmsg = ''
    errflg = 0

    call history_add_field ('ZMMTT',  'T tendency - ZM convective momentum transport', 'lev',  'avg', 'K s-1')
    call history_add_field ('ZMMTU',  'U tendency - ZM convective momentum transport', 'lev',  'avg', 'm s-2')
    call history_add_field ('ZMMTV',  'V tendency - ZM convective momentum transport', 'lev',  'avg', 'm s-2')

   end subroutine zm_momtran_tendency_diagnostics_init

   !> \section arg_table_zm_momtran_tendency_diagnostics_run  Argument Table
   !! \htmlinclude zm_momtran_tendency_diagnostics_run.html
   subroutine zm_momtran_tendency_diagnostics_run(ncol, pver, cpair, windu_tend, windv_tend, seten, errmsg, errflg)

      use cam_history,               only: history_out_field
      !------------------------------------------------
      !   Input / output parameters
      !------------------------------------------------
      integer, intent(in) :: ncol
      integer, intent(in) :: pver
      real(kind_phys), intent(in) :: cpair
      real(kind_phys), intent(in) :: windu_tend(:,:)
      real(kind_phys), intent(in) :: windv_tend(:,:)
      real(kind_phys), intent(in) :: seten(:,:)

      ! CCPP error handling variables
      character(len=512), intent(out) :: errmsg
      integer,          intent(out) :: errflg

      real(kind_phys) :: ftem(ncol,pver)

      errmsg = ''
      errflg = 0

      call history_out_field('ZMMTU', windu_tend)
      call history_out_field('ZMMTV', windv_tend)

      ftem(:ncol,:pver) = seten(:ncol,:pver)/cpair
      call history_out_field('ZMMTT', ftem)

   end subroutine zm_momtran_tendency_diagnostics_run

   !=======================================================================

end module zm_momtran_tendency_diagnostics
