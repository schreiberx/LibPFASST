!
! This file is part of LIBPFASST.
!
!>  Module for reading parameters for the problem
module probin
  use pf_mod_dtype


  character(len=64), save :: problem_type

  double precision, save :: a,b    ! advection velocity
  double precision, save :: nu     ! viscosity
  double precision, save :: t00     ! initial time for exact solution
  double precision, save :: sigma  ! initial condition parameter
  integer,          save :: kfreq  ! initial condition parameter
  double precision, save :: dt     ! time step
  double precision, save :: Tfin   ! Final time

  integer, save :: nx(PF_MAXLEVS)     ! number of grid points
  integer, save :: ny(PF_MAXLEVS)     ! number of grid points  
  integer, save :: nsteps          ! number of time steps
  integer, save :: nsteps_rk       ! number of time steps for rk
  integer, save :: imex_stat       ! type of imex splitting

  character(len=32), save :: pfasst_nml

  character(len=64), save :: output ! directory name for output
  CHARACTER(LEN=255) :: istring  ! stores command line argument
  CHARACTER(LEN=255) :: message           ! use for I/O error messages

  integer :: ios,iostat
  namelist /params/  a,b,nx,ny, nsteps,nsteps_rk, dt, Tfin
  namelist /params/  pfasst_nml, nu, t00, sigma, kfreq,imex_stat

contains

  subroutine probin_init(filename)
    character(len=*), intent(in) :: filename
    integer :: i
    character(len=32) :: arg
    integer :: un

    !> set defaults
    nsteps  = -1
    nsteps_rk  = -1

    a       = 0.8_pfdp
    b       = 0.6_pfdp    
    nu      = 0.01_pfdp
    kfreq   = 1.0_pfdp
    t00      = 0.08_pfdp
    dt      = 0.01_pfdp
    Tfin    = 0.0_pfdp
    imex_stat=2    !  Default is full IMEX
    nx=4
    ny=4

    !>  Read in stuff from input file
    un = 9
    write(*,*) 'opening file ',TRIM(filename), '  for input'
    open(unit=un, file = filename, status = 'old', action = 'read')
    read(unit=un, nml = params)
    close(unit=un)
          
    !>  Read the command line
    i = 0
    do
       call get_command_argument(i, arg)
       if (LEN_TRIM(arg) == 0) EXIT
       if (i > 0) then
          istring="&PARAMS "//TRIM(arg)//" /"    
          READ(istring,nml=params,iostat=ios,iomsg=message) ! internal read of NAMELIST
       end if
       i = i+1
    end do

    !  Reset dt if Tfin is set
    if (Tfin .gt. 0.0) dt = Tfin/dble(nsteps)

  end subroutine probin_init

  subroutine ad_print_options(pf, un_opt)
    type(pf_pfasst_t), intent(inout)           :: pf   
    integer,           intent(in   ), optional :: un_opt
    integer :: un = 6

    if (pf%rank /= 0) return
    if (present(un_opt)) un = un_opt

    !  Print out the local parameters
    write(un,*) '=================================================='
    write(un,*) ' '
    write(un,*) 'Local Variables'
    write(un,*) '----------------'
    write(un,*) 'nsteps: ', nsteps, '! Number of steps'
    write(un,*) 'Dt:     ', Dt, '! Time step size'
    write(un,*) 'Tfin:   ', Tfin,   '! Final time of run'
    write(un,*) 'nx:     ',  nx(1:pf%nlevels), '! grid size per level'
    write(un,*) 'ny:     ',  ny(1:pf%nlevels), '! grid size per level'    
    write(un,*) 'a:      ',  a, '! advection constant'
    write(un,*) 'b:      ',  b, '! advection constant'    
    write(un,*) 'nu:     ', nu, '! diffusion constant'
    select case (imex_stat)
    case (0)  
       write(un,*) 'imex_stat:', imex_stat, '! Fully explicit'
    case (1)  
       write(un,*) 'imex_stat:', imex_stat, '! Fully implicit'
    case (2)  
       write(un,*) 'imex_stat:', imex_stat, '! Implicit/Explicit'
    case DEFAULT
       print *,'Bad case for imex_stat in probin ', imex_stat
       call exit(0)
    end select

    write(un,*) 'Sine initial conditions with kfreq=',kfreq

    write(un,*) 'PFASST parameters read from input file ', pfasst_nml
    write(un,*) '=================================================='
  end subroutine ad_print_options
  


end module probin
