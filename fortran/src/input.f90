module input

    ! Physical system dimensions
    real, parameter :: lx = 1.0e6
    real, parameter :: ly = 1.0e6
    real, parameter :: lz = 1.0e6/120.

    ! Number of Gaussian quadrature points per spatial dimension
    integer, parameter :: iquad = 2

    ! Grid cell dimensions per MPI domain
    integer, parameter :: nx = 70
    integer, parameter :: ny = 1
    integer, parameter :: nz = 1

    ! Set number of MPI domains per spatial dimension
    integer :: mpi_nx = 16
    integer :: mpi_ny = 1

    ! Temporal integration order
    !   * 2 for
    !   * 3 for 3rd-order Runga-Kutta (Shu-Osher)
    integer, parameter :: iorder = 2

    ! Fluctuating hydrodynamics
    logical, parameter :: llns = .false.

    ! Initial conditions
    integer, parameter :: icid = 3

    ! Boundary conditions:
    !   * 0 for set_bc subroutine used to prescribe BCs
    !   * 1 for wall (vanishing normal velocities).
    !   * 2 for periodic (MPI does this for you).
    character(*), parameter :: xlbc = 'wall'
    character(*), parameter :: xhbc = 'wall'
    character(*), parameter :: ylbc = 'periodic'
    character(*), parameter :: yhbc = 'periodic'
    character(*), parameter :: zlbc = 'periodic'
    character(*), parameter :: zhbc = 'periodic'

    ! Simulation time
    real, parameter :: tf = 8.5e4

    ! Riemann solver
    ! If all of them = 0, then LLF is used for fluxes.
    !   LLF is very diffusive for the hydro problem. Roe and HLLC are much less
    !   diffusive than LLF and give very similar results with similar cpu overhead
    !   Only HLLC is setup to handle water EOS (ieos = 2)
    logical, parameter :: ihllc = .true.

    ! Thermodynamic and transport parameters
    real, parameter :: ieos = 1
    real, parameter :: mu = 2.0
    real, parameter :: aindex = 5./3.
    real, parameter :: aindm1 = aindex - 1.0
    real, parameter :: cp = aindex/aindm1

    ! Equation of state and constitutive parameters
    real, parameter :: vis = 0.0
    real, parameter :: epsi = 5.0
    real, parameter :: clt = 2.0

    ! Output frequency and directory
    integer, parameter :: ntout = 100
    character (*), parameter :: datadir="data"
    character (*), parameter :: outname="test_modbc_0"
    character (*), parameter :: outdir = trim(datadir//"/"//outname)

    ! Checkpointing
    !   set iread to 1 or 2 (when using the odd/even scheme)
    integer, parameter :: iread = 0
    integer, parameter :: iwrite = 0
    logical, parameter :: resuming = .false.
    character (4), parameter :: fpre = 'Qout'

end module input