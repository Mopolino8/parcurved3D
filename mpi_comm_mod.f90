module mpi_comm_mod
  ! an encapsulated module for OOP approach
  ! to use and implement MPI library.
  ! Based on the book "Modern Fortran"
  ! by Clerman and Spector
  ! 
  ! Programmed and extended by:
  ! A. Ghasemi
  ! ghasemi.arash@gmail.com
  !
  ! Ver : 1.0
  !
  use mpi
  implicit none
  private

  type, public :: mpi_comm_t

     integer :: root_rank = 0
     integer :: comm_w = MPI_COMM_WORLD
     integer :: mpi_error = MPI_SUCCESS, mpi_stat(MPI_STATUS_SIZE)
     integer :: rank, np
     logical :: mpi_comm_initialized = .false.

   contains

     procedure :: error_check
     procedure :: barrier => mpi_comm_barrier
     procedure :: init => mpi_comm_init
     procedure :: finish => mpi_comm_final
     procedure :: send_double => mpi_comm_send_double
     procedure :: recv_double => mpi_comm_recv_double
     procedure :: bcast_int => mpi_comm_bcast_integer
     procedure :: bcast_double => mpi_comm_bcast_double
     procedure :: reduce_max_double => mpi_comm_reduce_max_double

  end type mpi_comm_t


contains

  ! general error checker and stopper
  ! subroutine for MPI type
  !
  subroutine error_check(this, stage)
    implicit none
    class(mpi_comm_t), intent(inout) :: this
    character(len = *), intent(in) :: stage

    if ( this%mpi_error .ne. MPI_SUCCESS ) then
       print *, 'MPI fatal error happend in <', stage, '> stage' &
            , ' of the MPI opts! stop'
       call this%finish()
       stop
    end if

    ! done here
  end subroutine error_check

  !
  subroutine mpi_comm_barrier(this)
    implicit none
    class(mpi_comm_t), intent(inout) :: this

    call MPI_Barrier (this%comm_w, this%mpi_error)

    call this%error_check('barrier')

    ! done here
  end subroutine mpi_comm_barrier

  !
  subroutine mpi_comm_init(this)
    implicit none
    class(mpi_comm_t) :: this

    if ( .not. this%mpi_comm_initialized ) then

       ! init MPI env
       call MPI_Init( this%mpi_error)
       call this%error_check('mpi_init')

       ! get my rank
       call MPI_Comm_rank(this%comm_w, this%rank, this%mpi_error)
       call this%error_check('comm_rank')

       ! get number of processes
       call MPI_Comm_size(this%comm_w, this%np, this%mpi_error)
       call this%error_check('comm_size')

       ! set the flag
       this%mpi_comm_initialized = .true.

    else

       print *, ' warning : process # ' , this%rank , ' is already initialized!'

    end if

    ! done here
  end subroutine mpi_comm_init

  !
  subroutine mpi_comm_final(this)
    implicit none
    class(mpi_comm_t), intent(inout) :: this

    !
    call MPI_Finalize( this%mpi_error)


    ! done here
  end subroutine mpi_comm_final

  !
  subroutine mpi_comm_send_double(this, buff, idest, itag)
    implicit none
    class(mpi_comm_t), intent(inout) :: this
    real*8, dimension(:), intent(in) :: buff
    integer, intent(in) :: idest, itag

    call MPI_Send(buff, size(buff), MPI_DOUBLE &
         , idest, itag, this%comm_w, this%mpi_error)

    call this%error_check('send_double')

    ! done here
  end subroutine mpi_comm_send_double

  ! 
  subroutine mpi_comm_recv_double(this, buff, isource, itag)
    implicit none
    class(mpi_comm_t), intent(inout) :: this
    real*8, dimension(:), intent(out) :: buff
    integer, intent(in) :: isource, itag

    call MPI_recv(buff, size(buff), MPI_DOUBLE &
         , isource, itag, this%comm_w &
         , this%mpi_stat, this%mpi_error)

    call this%error_check('recv_double')

    ! done here
  end subroutine mpi_comm_recv_double

  !
  subroutine mpi_comm_bcast_integer(this, buff)
    implicit none
    class(mpi_comm_t), intent(inout) :: this
    integer, dimension(:) :: buff

    call MPI_BCAST(buff, size(buff), MPI_INT, this%root_rank &
         , this%comm_w, this%mpi_error)

    call this%error_check('bcast_integer')

    ! done here
  end subroutine mpi_comm_bcast_integer

  !
  subroutine mpi_comm_bcast_double(this, buff)
    implicit none
    class(mpi_comm_t), intent(inout) :: this
    real*8, dimension(:) :: buff

    call MPI_BCAST(buff, size(buff), MPI_DOUBLE, this%root_rank &
         , this%comm_w, this%mpi_error)

    call this%error_check('bcast_double')

    ! done here
  end subroutine mpi_comm_bcast_double

  !
  subroutine mpi_comm_reduce_max_double(this, buff_send, buff_recv)
    implicit none
    class(mpi_comm_t), intent(inout) :: this
    real*8, dimension(:), intent(in) :: buff_send
    real*8, dimension(:), intent(out) :: buff_recv

    call MPI_REDUCE(buff_send, buff_recv, size(buff_send), MPI_DOUBLE, MPI_MAX &
         , this%root_rank, this%comm_w, this%mpi_error)

    call this%error_check('reduce_max_double')

    ! done here
  end subroutine mpi_comm_reduce_max_double

end module mpi_comm_mod

! ! compile and run strings:
! ! $> mpifort -Wall mpi_comm_mod.f90 ( To Compile )
! ! $> mpirun -np 40 ./a.out ( To Run)
! !
! program tester
!   use mpi_comm_mod

!   type(mpi_comm_t) :: tmpi
!   real*8, dimension(4) :: a
!   integer :: ii, root = 0

!   a = 0.0d0

!   call tmpi%init()

!   if ( tmpi%rank .eq. root ) then ! root sends
!      a = (/ 1.0d0, 2.0d0, 3.0d0, 4.0d0 /)
!      do ii = 1, (tmpi%np-1)
!         call tmpi%send_double(buff = a, idest = ii, itag = 0)
!      end do
!   else
!      call tmpi%recv_double(buff = a, isource = root, itag = 0)
!   end if

!   print *, 'process # ', tmpi%rank , ' a = ', a

!   call tmpi%finish()

!   ! done here
! end program tester
