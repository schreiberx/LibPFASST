!
! This file is part of LIBPFASST.
!
!>  Module to define the main parameters, data types, and interfaces in pfasst
module pf_mod_dtype
  use iso_c_binding
  implicit none

  !>  static pfasst paramters
  !  integer, parameter :: pfdp = c_long_double
  integer, parameter :: pfdp = c_double

  real(pfdp), parameter :: ZERO  = 0.0_pfdp
  real(pfdp), parameter :: ONE   = 1.0_pfdp
  real(pfdp), parameter :: TWO   = 2.0_pfdp
  real(pfdp), parameter :: THREE  = 3.0_pfdp
  real(pfdp), parameter :: HALF  = 0.5_pfdp

  integer, parameter :: PF_MAXLEVS = 4  
  integer, parameter :: PF_MAX_HOOKS = 32
  !> Quadrature node types
  integer, parameter :: SDC_GAUSS_LOBATTO   = 1
  integer, parameter :: SDC_GAUSS_RADAU     = 2
  integer, parameter :: SDC_CLENSHAW_CURTIS = 3
  integer, parameter :: SDC_UNIFORM         = 4
  integer, parameter :: SDC_GAUSS_LEGENDRE  = 5
  integer, parameter :: SDC_PROPER_NODES    = 2**8
  integer, parameter :: SDC_COMPOSITE_NODES = 2**9
  integer, parameter :: SDC_NO_LEFT         = 2**10

  !> States of operatrion
  integer, parameter :: PF_STATUS_ITERATING = 1
  integer, parameter :: PF_STATUS_CONVERGED = 2
  integer, parameter :: PF_STATUS_PREDICTOR = 3

  type, bind(c) :: pf_state_t
    real(pfdp) :: t0  !<  Time at beginning of this time step
    real(pfdp) :: dt  !<  Time step size
    integer :: nsteps   !< total number of time steps
    integer :: cycle    !< deprecated?
    integer :: iter     !< current iteration number
    integer :: step     !< current time step number assigned to processor
    integer :: level    !< which level is currently being operated on
    integer :: hook     !< which hook
    integer :: proc     !< which processor
    integer :: sweep    !< sweep number
    integer :: status   !< status (iterating, converged etc)
    integer :: pstatus  !< previous rank's status
    integer :: itcnt    !< iteration counter
    integer :: skippedy !< skipped sweeps for state (for mixed integration)
    integer :: mysteps  !< steps I did
  end type pf_state_t

  !<  Hook to call diagnostic routines from various places in code
  type :: pf_hook_t
     procedure(pf_hook_p), pointer, nopass :: proc
  end type pf_hook_t

  !<  The base SDC sweeper type
  type, abstract :: pf_sweeper_t
     integer     :: npieces
     logical     :: use_LUq
   contains
     procedure(pf_sweep_p),        deferred :: sweep
     procedure(pf_initialize_p),   deferred :: initialize
     procedure(pf_evaluate_p),     deferred :: evaluate
     procedure(pf_integrate_p),    deferred :: integrate
     procedure(pf_evaluate_all_p), deferred :: evaluate_all
     procedure(pf_residual_p),     deferred :: residual
     procedure(pf_spreadq0_p),     deferred :: spreadq0 
     procedure(pf_destroy_p),      deferred :: destroy
  end type pf_sweeper_t

  !<  The base stepper type
  type, abstract :: pf_stepper_t
     integer     :: npieces
     integer     :: order
   contains
     procedure(pf_do_n_steps_p),           deferred :: do_n_steps
     procedure(pf_initialize_stepper_p),   deferred :: initialize
     procedure(pf_destroy_stepper_p),      deferred :: destroy
  end type pf_stepper_t

  !<  The base data type for the solution
  type, abstract :: pf_encap_t
   contains
     procedure(pf_encap_setval_p),  deferred :: setval
     procedure(pf_encap_copy_p),    deferred :: copy
     procedure(pf_encap_norm_p),    deferred :: norm
     procedure(pf_encap_pack_p),    deferred :: pack
     procedure(pf_encap_unpack_p),  deferred :: unpack
     procedure(pf_encap_axpy_p),    deferred :: axpy
     procedure(pf_encap_eprint_p),  deferred :: eprint
  end type pf_encap_t

  !<  Generic type for creation and desstruction of objects
  type, abstract :: pf_factory_t
   contains
     procedure(pf_encap_create_single_p),  deferred :: create_single
     procedure(pf_encap_create_array_p),   deferred :: create_array
     procedure(pf_encap_destroy_single_p), deferred :: destroy_single
     procedure(pf_encap_destroy_array_p),  deferred :: destroy_array
  end type pf_factory_t

  !<  The user level which is inherited  to include problem dependent stuff
  type, abstract :: pf_user_level_t
     class(pf_factory_t), allocatable :: factory
     class(pf_sweeper_t), allocatable :: sweeper
     class(pf_stepper_t), allocatable :: stepper
   contains
     procedure(pf_transfer_p), deferred :: restrict
     procedure(pf_transfer_p), deferred :: interpolate
  end type pf_user_level_t

  !>  Tool for storing results for later output
  type :: pf_results_t
     real(pfdp), allocatable :: errors(:,:,:)
     real(pfdp), allocatable :: residuals(:,:,:)
     integer :: nsteps
     integer :: niters
     integer :: nprocs
     integer :: nlevels
     integer :: p_index
     integer :: nblocks
     
     character(len = 16   ) :: fname_r  !<  output file name for residuals
     character(len = 14) :: fname_e     !<  output file name errors
     
   contains
     procedure :: initialize => initialize_results
     procedure :: dump => dump_results
     procedure :: destroy => destroy_results
  end type pf_results_t

  !>  Data type of a PFASST level
  type :: pf_level_t
     integer  :: index        = -1   !< level number (1 is the coarsest)
     integer  :: mpibuflen    = -1   !< size of solution in pfdp units
     integer  :: nnodes       = -1   !< number of sdc nodes
     integer  :: nsteps_rk    = -1   !< number of rk steps to perform
     integer  :: nsweeps      =  1   !< number of sdc sweeps to perform
     integer  :: nsweeps_pred =  1      !< number of coarse sdc sweeps to perform predictor in predictor
     logical     :: Finterp = .false.   !< interpolate functions instead of solutions

     real(pfdp)  :: error            !< holds the user defined error
     real(pfdp)  :: residual         !< holds the user defined residual
     real(pfdp)  :: residual_rel     !< holds the user defined relative residual (scaled by solution magnitude)

     class(pf_user_level_t), allocatable :: ulevel  !<  user customized level info

     !>  Simple data storage at each level
     real(pfdp), allocatable :: &
          send(:),    &                 !< send buffer
          recv(:),    &                 !< recv buffer
          nodes(:),   &                 !< list of SDC nodes
          t_sdc(:),   &                 !< time at the SDC nodes
          qmat(:,:),  &                 !< spectral integration matrix (0 to node)
          qmatFE(:,:),  &               !< Forward Euler integration matrix (0 to node)
          qmatBE(:,:),  &               !< Backward Euler matrix (0 to node)
          LUmat(:,:), &                 !< LU factorization (replaces BE matrix in Q form)
          s0mat(:,:), &                 !< integration matrix (node to node)
          rmat(:,:),  &                 !< time restriction matrix
          tmat(:,:)                     !< time interpolation matrix

     integer, allocatable :: &
          nflags(:)                     !< sdc node flags

     !>  Solution variable storage
     class(pf_encap_t), allocatable :: &
          Q(:),     &           !< solution at sdc nodes
          pQ(:),    &           !< unknowns at sdc nodes, previous sweep
          R(:),     &           !< full residuals
          I(:),     &           !< 0 to node integrals
          Fflt(:),  &           !< functions values at sdc nodes (flat)
          tauQ(:),  &           !< fas correction in Q form
          pFflt(:), &           !< functions at sdc nodes, previous sweep (flat)
          q0,       &           !< initial condition 
          qend                  !< solution at end time

     !>  Function  storage
     class(pf_encap_t), pointer :: &
          F(:,:), &                     !< functions values at sdc nodes
          pF(:,:)                       !< functions at sdc nodes, previous sweep


     integer, allocatable :: shape(:)   !< user defined shape array

     logical :: allocated = .false.
  end type pf_level_t

  !>  Data type to define the communicator
  type :: pf_comm_t
     integer :: nproc = -1              ! total number of processors

     integer :: comm = -1               ! communicator
     integer, pointer :: &
          recvreq(:), &                 ! receive requests (indexed by level)
          sendreq(:)                    ! send requests (indexed by level)
     integer :: statreq                 ! status send request

     ! fakie, needs modernization
     type(c_ptr), pointer :: pfs(:)     ! pfasst objects (indexed by rank)
     type(c_ptr), pointer :: pfpth(:,:)

     !> Procedure interfaces
     procedure(pf_post_p),        pointer, nopass :: post
     procedure(pf_recv_p),        pointer, nopass :: recv
     procedure(pf_recv_status_p), pointer, nopass :: recv_status
     procedure(pf_send_p),        pointer, nopass :: send
     procedure(pf_send_status_p), pointer, nopass :: send_status
     procedure(pf_wait_p),        pointer, nopass :: wait
     procedure(pf_broadcast_p),   pointer, nopass :: broadcast
  end type pf_comm_t

  !>  The main data type which includes pretty much everything
  type :: pf_pfasst_t
     !>  Parameters
     integer :: nlevels = -1            !< number of pfasst levels
     integer :: niters  = 5             !< number of PFASST iterations to do
     integer :: qtype   = SDC_GAUSS_LOBATTO  !< type of nodes
     
     !>  Level dependend parameters
     integer :: nsweeps(PF_MAXLEVS) = 1       !<  number of sweeps at each levels
     integer :: nsweeps_pred(PF_MAXLEVS) =1   !<  number of sweeps during predictor
     integer :: nnodes(PF_MAXLEVS)=3          !< number of nodes
     integer :: nnodes_rk(PF_MAXLEVS)=3       !< number of runge-kutta nodes

     !>  Tolerances
     real(pfdp) :: abs_res_tol = 0.d0   !<  absolute convergence tolerance
     real(pfdp) :: rel_res_tol = 0.d0   !<  relative convergence tolerance

     !>  predictor options  (should be set before pfasst_run is called)
     logical :: PFASST_pred = .true.    !<  true if the PFASST type predictor is used
     logical :: RK_pred = .false.       !<  true if the coarse level is initialized with Runge-Kutta instead of PFASST
     logical :: pipeline_pred = .false. !<  true if coarse sweeps after burn in are pipelined  (if nsweeps_pred>1 on coarse level)
     integer :: nsweeps_burn =  1       !<  number of sdc sweeps to perform during coarse level burn in
!     logical :: pipeline_burn = .false. !<  true if coarse level sweeps are pipelined in predictor (meaningless if nsweeps_burn>1 )

     
     !  q0 can take 3 values
     !  0:  Only the q0 at t=0 is valid  (default)
     !  1:  The q0 at each processor is valid
     !  2:  q0 and all nodes at each processor is valid
     integer :: q0_style =  0                                                   

     !>  run options  (should be set before pfasst_run is called)
     logical :: Vcycle = .true.         !<  decides if Vcycles are done
     logical :: Finterp = .false.    !<  True if transfer functions operate on rhs
     logical :: use_LUq = .true.     !<  True if LU type implicit matrix is used 
     integer :: taui0 = -999999     !< iteration cutoff for tau inclusion

     !> RK and Parareal options
     logical :: use_rk_stepper = .false. !< decides if RK steps are used instead of the sweeps

     !> misc
     logical :: debug = .false.
     logical :: save_results = .false.
     logical    :: echo_timings  = .false.

     integer :: rank    = -1            !< rank of current processor

     !> pf objects
     type(pf_state_t), allocatable :: state   !<  Describes where in the algorithm proc is
     type(pf_level_t), allocatable :: levels(:) !< Holds the levels
     type(pf_comm_t),  pointer :: comm    !< Points to communicator
     type(pf_results_t) :: results

     !> hooks variables
     type(pf_hook_t), allocatable :: hooks(:,:,:)  !<  Holds the hooks
     integer,  allocatable :: nhooks(:,:)   !<  Holds the number hooks

     !> timing variables
     integer :: timers(100)   = 0
     integer :: runtimes(100) = 0

     !> output directory
     character(512) :: outdir

  end type pf_pfasst_t

  !> Interfaces for subroutines
  interface
    !> hooks subroutines
    subroutine pf_hook_p(pf, level, state)
       use iso_c_binding
       import pf_pfasst_t, pf_level_t, pf_state_t
       type(pf_pfasst_t), intent(inout) :: pf
       class(pf_level_t), intent(inout) :: level
       type(pf_state_t),  intent(in)    :: state
     end subroutine pf_hook_p
     
     !> SDC sweeper subroutines
     subroutine pf_sweep_p(this, pf, level_index, t0, dt, nsweeps, flags)
       import pf_pfasst_t, pf_sweeper_t, pf_level_t, pfdp
       class(pf_sweeper_t), intent(inout) :: this
       type(pf_pfasst_t),   intent(inout),target :: pf
       real(pfdp),          intent(in)    :: dt
       real(pfdp),          intent(in)    :: t0
       integer,             intent(in)    :: level_index
       integer,             intent(in)    :: nsweeps
       integer, optional,   intent(in)    :: flags
     end subroutine pf_sweep_p

     subroutine pf_evaluate_p(this, lev, t, m, flags, step)
       import pf_sweeper_t, pf_level_t, pfdp
       class(pf_sweeper_t), intent(inout) :: this
       class(pf_level_t),   intent(inout) :: lev
       real(pfdp),          intent(in)    :: t
       integer,             intent(in)    :: m
       integer, optional,   intent(in)    :: flags, step
     end subroutine pf_evaluate_p

     subroutine pf_evaluate_all_p(this, lev, t, flags, step)
       import pf_sweeper_t, pf_level_t, pfdp
       class(pf_sweeper_t), intent(inout) :: this
       class(pf_level_t),   intent(inout) :: lev
       real(pfdp),          intent(in)    :: t(:)
       integer, optional,   intent(in)    :: flags, step
     end subroutine pf_evaluate_all_p

     subroutine pf_initialize_p(this, lev)
       import pf_sweeper_t, pf_level_t
       class(pf_sweeper_t), intent(inout) :: this
       class(pf_level_t),   intent(inout) :: lev
     end subroutine pf_initialize_p

     subroutine pf_destroy_sweeper_p(this)
       import pf_sweeper_t
       class(pf_sweeper_t), intent(inout) :: this
     end subroutine pf_destroy_sweeper_p

     subroutine pf_integrate_p(this, lev, qSDC, fSDC, dt, fintSDC, flags)
       import pf_sweeper_t, pf_level_t, pf_encap_t, pfdp
       class(pf_sweeper_t), intent(inout) :: this
       class(pf_level_t),   intent(in)    :: lev
       class(pf_encap_t),   intent(in)    :: qSDC(:), fSDC(:, :)
       real(pfdp),          intent(in)    :: dt !<  Time step size
       class(pf_encap_t),   intent(inout) :: fintSDC(:)
       integer, optional,   intent(in)    :: flags
     end subroutine pf_integrate_p

     subroutine pf_residual_p(this, lev, dt, flags)
       import pf_sweeper_t, pf_level_t, pfdp
       class(pf_sweeper_t), intent(inout) :: this
       class(pf_level_t),   intent(inout) :: Lev
       real(pfdp),          intent(in)    :: dt !<  Time step size
       integer, optional,   intent(in)    :: flags
     end subroutine pf_residual_p

     subroutine pf_spreadq0_p(this, lev, t0, flags, step)
       import pf_sweeper_t, pf_level_t, pfdp
       class(pf_sweeper_t), intent(inout) :: this
       class(pf_level_t),   intent(inout) :: Lev
       real(pfdp),          intent(in)    :: t0 !<  Time at beginning of step; if flags == 2, time at end of step
       integer, optional,   intent(in)    :: flags, step
     end subroutine pf_spreadq0_p

     subroutine pf_destroy_p(this, lev)
       import pf_sweeper_t, pf_level_t, pfdp
       class(pf_sweeper_t), intent(inout) :: this
       class(pf_level_t),   intent(inout) :: Lev
     end subroutine pf_destroy_p

     !>  time stepper interfaces
     subroutine pf_do_n_steps_p(this, pf, level_index, t0, big_dt,nsteps_rk)
       import pf_pfasst_t, pf_stepper_t, pf_level_t, pfdp
       class(pf_stepper_t), intent(inout) :: this
       type(pf_pfasst_t),   intent(inout),target :: pf
       real(pfdp),          intent(in)    :: big_dt !<  Time step size
       real(pfdp),          intent(in)    :: t0
       integer,             intent(in)    :: level_index
       integer,             intent(in)    :: nsteps_rk
     end subroutine pf_do_n_steps_p

     subroutine pf_initialize_stepper_p(this, lev)
       import pf_stepper_t, pf_level_t
       class(pf_stepper_t), intent(inout) :: this
       class(pf_level_t),   intent(inout) :: lev
     end subroutine pf_initialize_stepper_p

     subroutine pf_destroy_stepper_p(this, lev)
       import pf_stepper_t, pf_level_t, pfdp
       class(pf_stepper_t), intent(inout) :: this
       class(pf_level_t),   intent(inout) :: Lev
     end subroutine pf_destroy_stepper_p

     !> transfer interfaces used for restriction and interpolation
     subroutine pf_transfer_p(this, levelF, levelG, qF, qG, t, flags)
       import pf_user_level_t, pf_level_t, pf_encap_t, pfdp
       class(pf_user_level_t), intent(inout) :: this
       class(pf_level_t), intent(inout)      :: levelF, levelG
       class(pf_encap_t),   intent(inout)    :: qF, qG
       real(pfdp),          intent(in)       :: t
       integer, optional,   intent(in)       :: flags
     end subroutine pf_transfer_p

     !> encapsulation interfaces
     subroutine pf_encap_create_single_p(this, x, level, shape)
       import pf_factory_t, pf_encap_t
       class(pf_factory_t), intent(inout)              :: this
       class(pf_encap_t),   intent(inout), allocatable :: x
       integer,      intent(in   )              :: level,  shape(:)
     end subroutine pf_encap_create_single_p

     subroutine pf_encap_create_array_p(this, x, n, level, shape)
       import pf_factory_t, pf_encap_t
       class(pf_factory_t), intent(inout)              :: this
       class(pf_encap_t),   intent(inout), allocatable :: x(:)
       integer,      intent(in   )              :: n, level, shape(:)
     end subroutine pf_encap_create_array_p

     subroutine pf_encap_destroy_single_p(this, x, level,  shape)
       import pf_factory_t, pf_encap_t
       class(pf_factory_t), intent(inout)              :: this
       class(pf_encap_t),   intent(inout), allocatable :: x
       integer,      intent(in   )              :: level,  shape(:)
     end subroutine pf_encap_destroy_single_p

     subroutine pf_encap_destroy_array_p(this, x, n, level,   shape)
       import pf_factory_t, pf_encap_t
       class(pf_factory_t), intent(inout)              :: this
       class(pf_encap_t),   intent(inout), allocatable :: x(:)
       integer,      intent(in   )              :: n, level,  shape(:)
     end subroutine pf_encap_destroy_array_p

     subroutine pf_encap_setval_p(this, val, flags)
       import pf_encap_t, pfdp
       class(pf_encap_t), intent(inout)        :: this
       real(pfdp),        intent(in)           :: val
       integer,    intent(in), optional :: flags
     end subroutine pf_encap_setval_p

     subroutine pf_encap_copy_p(this, src, flags)
       import pf_encap_t, pfdp
       class(pf_encap_t), intent(inout)           :: this
       class(pf_encap_t), intent(in   )           :: src
       integer,    intent(in   ), optional :: flags
     end subroutine pf_encap_copy_p

     function pf_encap_norm_p(this, flags) result (norm)
       import pf_encap_t, pfdp
       class(pf_encap_t), intent(in   ) :: this
       integer,    intent(in   ), optional :: flags
       real(pfdp) :: norm
     end function pf_encap_norm_p

     subroutine pf_encap_pack_p(this, z, flags)
       import pf_encap_t, pfdp
       class(pf_encap_t), intent(in   ) :: this
       real(pfdp),        intent(  out) :: z(:)
       integer, optional,   intent(in)  :: flags
     end subroutine pf_encap_pack_p

     subroutine pf_encap_unpack_p(this, z, flags)
       import pf_encap_t, pfdp
       class(pf_encap_t), intent(inout) :: this
       real(pfdp),        intent(in   ) :: z(:)
       integer, optional,   intent(in)  :: flags
     end subroutine pf_encap_unpack_p

     subroutine pf_encap_axpy_p(this, a, x, flags)
       import pf_encap_t, pfdp
       class(pf_encap_t), intent(inout)  :: this
       class(pf_encap_t), intent(in   )  :: x
       real(pfdp),  intent(in)           :: a
       integer, intent(in), optional :: flags
     end subroutine pf_encap_axpy_p

     subroutine pf_encap_eprint_p(this,flags)
       import pf_encap_t
       class(pf_encap_t), intent(inout) :: this
       integer, intent(in), optional :: flags
     end subroutine pf_encap_eprint_p

     !> communicator interfaces
     subroutine pf_post_p(pf, level, tag, ierror, direction)
       import pf_pfasst_t, pf_level_t
       type(pf_pfasst_t), intent(in)    :: pf
       class(pf_level_t), intent(inout) :: level
       integer,    intent(in)           :: tag
       integer,    intent(inout)        :: ierror
       integer, optional, intent(in)    :: direction
     end subroutine pf_post_p

     subroutine pf_recv_p(pf, level, tag, blocking, ierror, direction)
       import pf_pfasst_t, pf_level_t
       type(pf_pfasst_t), intent(inout) :: pf
       class(pf_level_t), intent(inout) :: level
       integer,    intent(in)    :: tag
       logical,           intent(in)    :: blocking
       integer,    intent(inout)       :: ierror
       integer, optional, intent(in)    :: direction
     end subroutine pf_recv_p

     subroutine pf_recv_status_p(pf, tag,istatus,ierror, direction)
       import pf_pfasst_t, pf_level_t
       type(pf_pfasst_t), intent(inout) :: pf
       integer,    intent(in)    :: tag
       integer,    intent(inout)       :: istatus
       integer,    intent(inout)       :: ierror
       integer, optional, intent(in)    :: direction
     end subroutine pf_recv_status_p

     subroutine pf_send_p(pf, level, tag, blocking,ierror, direction)
       import pf_pfasst_t, pf_level_t
       type(pf_pfasst_t), intent(inout) :: pf
       class(pf_level_t), intent(inout) :: level
       integer,    intent(in)    :: tag
       logical,           intent(in)    :: blocking
       integer,    intent(inout)       :: ierror
       integer, optional, intent(in)    :: direction
     end subroutine pf_send_p

     subroutine pf_send_status_p(pf, tag,istatus,ierror, direction)
       import pf_pfasst_t, pf_level_t
       type(pf_pfasst_t), intent(inout) :: pf
       integer,    intent(in)    :: tag
       integer,    intent(in)       :: istatus
       integer,    intent(inout)       :: ierror
       integer, optional, intent(in)    :: direction
     end subroutine pf_send_status_p

     subroutine pf_wait_p(pf, level,ierror)
       import pf_pfasst_t
       type(pf_pfasst_t), intent(in) :: pf
       integer,    intent(in) :: level
       integer,    intent(inout)       :: ierror
     end subroutine pf_wait_p

     subroutine pf_broadcast_p(pf, y, nvar, root,ierror)
       import pf_pfasst_t, pfdp
       type(pf_pfasst_t), intent(inout) :: pf
       integer,    intent(in)    :: nvar, root
       real(pfdp)  ,      intent(in)    :: y(nvar)
       integer,    intent(inout)       :: ierror
     end subroutine pf_broadcast_p

  end interface

contains
  subroutine initialize_results(this, nsteps_in, niters_in, nprocs_in, nlevels_in,rank_in)
    class(pf_results_t), intent(inout) :: this
    integer, intent(in) :: nsteps_in, niters_in, nprocs_in, nlevels_in,rank_in

    if (rank_in == 0) then
       open(unit=123, file='result-size.dat', form='formatted')
       write(123,'(I5, I5, I5, I5)') nsteps_in, niters_in, nprocs_in, nlevels_in
       close(unit=123)
    end if

    this%nsteps=nsteps_in
    this%nblocks=nsteps_in/nprocs_in
    this%niters=niters_in
    this%nprocs=nprocs_in
    this%nlevels=nlevels_in
    this%p_index=rank_in+100

    write (this%fname_r, "(A9,I0.3,A4)") 'dat/residual_',rank_in,'.dat'
    write (this%fname_e, "(A7,I0.3,A4)") 'dat/errors_',rank_in,'.dat'

    if(allocated(this%errors)) &
            deallocate(this%errors, this%residuals)

    allocate(this%errors(niters_in, this%nblocks, nlevels_in), &
         this%residuals(niters_in, this%nblocks, nlevels_in))

    this%errors = 0.0_pfdp
    this%residuals = 0.0_pfdp
  end subroutine initialize_results

  subroutine dump_results(this)
    class(pf_results_t), intent(inout) :: this
    integer :: i, j, k
    
    open(unit=this%p_index, file=this%fname_r, form='formatted')
    do k = 1, this%nlevels
       do j = 1, this%nblocks
          do i = 1 , this%niters
             write(this%p_index, '(I4, I4, I4, e21.14)') i,j,k,this%residuals(i, j, k)
          end do
       end do
    enddo
    close(20)
    close(this%p_index)

  end subroutine dump_results

  subroutine destroy_results(this)
    class(pf_results_t), intent(inout) :: this

    if(allocated(this%errors)) &
        deallocate(this%errors, this%residuals)
  end subroutine destroy_results
  
end module pf_mod_dtype
