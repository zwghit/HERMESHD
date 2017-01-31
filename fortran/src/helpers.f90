! Any functions in this module should NOT have any dependence on global
! variables specific to a hydro problem. This prevents the helpers module from
! depending on other modules.
module helpers


contains

    !---------------------------------------------------------------------------
    ! Get current time from system_clock
    !-----------------------------------------------------------------
    real function get_clock_time()
        integer :: ticks, count_rate, count_max
        call system_clock( ticks, count_rate, count_max )
        get_clock_time = 1.0 * ticks / count_rate
    end function get_clock_time
    !---------------------------------------------------------------------------


    !---------------------------------------------------------------------------
    ! Print a message from the MPI rank with ID mpi_id
    !-----------------------------------------------------------------
    subroutine mpi_print(mpi_id, message)
        integer, intent(in) :: mpi_id
        character(*) :: message
        if (mpi_id .eq. print_mpi) then
            print *,message
            print *,''       ! print a new line after message by default
        endif
    end subroutine mpi_print
    !---------------------------------------------------------------------------


    !---------------------------------------------------------------------------
    ! Print a message from the MPI rank with ID mpi_id
    !-----------------------------------------------------------------
    subroutine whoami_print(mpi_id, message)
        integer, intent(in) :: mpi_id
        character(*) :: message
        print *,'Rank',mpi_id, ':', message
        print *,''       ! print a new line after message by default
    end subroutine whoami_print
    !---------------------------------------------------------------------------


    !---------------------------------------------------------------------------
    ! Initialize the RNG with a random seed
    !-----------------------------------------------------------------
    subroutine init_random_seed(mpi_id, iseed)
        implicit none
        integer, intent(in) :: mpi_id
        integer :: i, n, clock, iseed
        integer, dimension(:), allocatable :: seed

        call random_seed(size = n)
        allocate(seed(n))

        call system_clock(count=clock)

        if (iseed .eq. 0) then
            seed =  clock*(mpi_id+1) + 37 * (/ (i - 1, i = 1, n) /)
        else
            seed =  iseed*(mpi_id+1)
        endif
        call random_seed(put = seed)

        ! print *,seed(1)
        deallocate(seed)
    end subroutine
    !---------------------------------------------------------------------------

end module helpers