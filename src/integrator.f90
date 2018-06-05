!***** INTEGRATOR.F90 ********************************************************************
module integrator

use input!, only : nx,ny,nz
use params!, only : nQ,nbasis,Q_r0,Q_r1,Q_r2,Q_r3
use helpers
use spatial
! use timestep

use prep_step
use sources
use flux

    !===========================================================================
    ! ABSTRACT INTERFACE to subroutine for temporal integration
    !-----------------------------------------------------------------
    abstract interface
        subroutine update_ptr(Q_io, Q_1, Q_2, dt)
            use input, only : nx,ny,nz
            use params, only : nQ,nbasis

            real, dimension(nx,ny,nz,nQ,nbasis), intent(inout) :: Q_io
            real, dimension(nx,ny,nz,nQ,nbasis), intent(inout) :: Q_1, Q_2
            real, intent(inout) :: dt
        end subroutine update_ptr
    end interface
    !---------------------------------------------------------------------------


    !===========================================================================
    ! Initialize pointer to temporal integration subroutine
    !-----------------------------------------------------------------
    procedure (update_ptr), pointer :: update => null ()
    !---------------------------------------------------------------------------

contains

    !===========================================================================
    ! Select user-specified integration method at runtime
    !-----------------------------------------------------------------
    subroutine select_integrator(name, integrator)
        implicit none
        character(*), intent(in) :: name
        procedure(update_ptr), pointer :: integrator

        select case (name)
            case ('heun')
                call mpi_print(iam, 'Selected 2nd-order Runga-Kutta (Heun) integration')
                integrator => RK2
            case ('shu-osher')
                call mpi_print(iam, 'Selected 3rd-order Runga-Kutta (Shu-Osher) integration')
                integrator => RK3
            case default
                call mpi_print(iam, 'Defaulting to 2nd-order Runga-Kutta (Heun) integration')
                integrator => RK2
        end select
    end subroutine select_integrator
    !---------------------------------------------------------------------------


    !===========================================================================
    ! Temporal integration subroutines (subject to change!)
    !-----------------------------------------------------------------
    subroutine RK2(Q_io, Q_1, Q_2, dt)
        implicit none
        real, dimension(nx,ny,nz,nQ,nbasis), intent(inout) :: Q_io
        real, dimension(nx,ny,nz,nQ,nbasis), intent(inout) :: Q_1, Q_2
        real, intent(inout) :: dt

        call euler_step(Q_io, Q_1, dt)
        call euler_step(Q_1, Q_2, dt)
        Q_io = 0.5 * ( Q_io + Q_2 )
    end subroutine RK2

    !----------------------------------------------------
    subroutine RK3(Q_io, Q_1, Q_2, dt)
        implicit none
        real, dimension(nx,ny,nz,nQ,nbasis), intent(inout) :: Q_io
        real, dimension(nx,ny,nz,nQ,nbasis), intent(inout) :: Q_1, Q_2
        real, intent(inout) :: dt

        call euler_step(Q_io, Q_1, dt)
        call euler_step(Q_1, Q_2, dt)
        Q_1 = 0.75*Q_io + 0.25*Q_2

        call euler_step(Q_1, Q_2, dt)  ! re-use the second array
        Q_io = c1d3*Q_io + c2d3*Q_2
    end subroutine RK3
    !---------------------------------------------------------------------------


    !===========================================================================
    ! Explicit Euler integration step
    !-----------------------------------------------------------------
    subroutine euler_step(Q_in, Q_out, dt)
        implicit none
        real, dimension(nx,ny,nz,nQ,nbasis), intent(inout) :: Q_in
        real, dimension(nx,ny,nz,nQ,nbasis), intent(out) :: Q_out
        real, intent(inout) :: dt

        call prep_advance(Q_in, dt)
        call glflux(Q_in, dt)
        ! call source_calc(Q_in, dt)
        call advance_time(Q_in, Q_out, dt)
        if (ivis == 'full') then
           call source_calc(Q_out, t)
           call advance_time_source(Q_out, Q_out, dt)
        end if
        call check_for_NaNs(Q_out)
    end subroutine euler_step


    !----------------------------------------------------
    subroutine prep_advance(Q_io, dt)
        implicit none
        real, dimension(nx,ny,nz,nQ,nbasis), intent(inout) :: Q_io
        real, intent(inout) :: dt

        if (ieos == 1 .or. ieos == 2) call limiter(Q_io)
        if (llns) call get_region_Sflux(Sflux, dt)
        call exchange_flux(Q_io)
        call apply_boundaries
    end subroutine prep_advance

    !----------------------------------------------------
    ! subroutine calc_rhs(Q_io, dt)
    !     implicit none
    !     real, dimension(nx,ny,nz,nQ,nbasis), intent(inout) :: Q_io
    !     real, intent(inout) :: dt
    !
    !     call glflux(Q_io, dt)
    !     call source_calc(Q_io, dt)
    ! end subroutine calc_rhs

    !---------------------------------------------------------------------------
    subroutine advance_time(Q_in, Q_out, dt)
        implicit none
        real, dimension(nx,ny,nz,nQ,nbasis), intent(in)  :: Q_in
        real, dimension(nx,ny,nz,nQ,nbasis), intent(out) :: Q_out
        real, intent(inout) :: dt
        real, dimension(nx,ny,nz,nQ,nbasis) :: Q_r
        integer :: i,j,k,ieq,ir
        real :: fac

        select case(ivis)
        case('linear_ex')  ! LINEARNIZED (explicit)
            fac = 1.
        case('linear')     ! LINEARNIZED (IMEX)
            fac = 1./(1. + nu*dt)
        case('linear_src')     ! LINEARNIZED (IMEX)
            fac = 1./(1. + nu*dt)
        case('full')       ! New NONLINEAR (IMEX)??? WARNING: not sure...
            fac = 1.
        end select

        if (ivis .ne. 'linear_src') then
        do ir=1,nbasis
        do k = 1,nz
        do j = 1,ny
        do i = 1,nx
          !--------------------------------
          Q_out(i,j,k,rh,ir) = Q_in(i,j,k,rh,ir) - dt*(glflux_r(i,j,k,rh,ir)-source_r(i,j,k,rh,ir))
          Q_out(i,j,k,mx,ir) = Q_in(i,j,k,mx,ir) - dt*(glflux_r(i,j,k,mx,ir)-source_r(i,j,k,mx,ir))
          Q_out(i,j,k,my,ir) = Q_in(i,j,k,my,ir) - dt*(glflux_r(i,j,k,my,ir)-source_r(i,j,k,my,ir))
          Q_out(i,j,k,mz,ir) = Q_in(i,j,k,mz,ir) - dt*(glflux_r(i,j,k,mz,ir)-source_r(i,j,k,mz,ir))
          Q_out(i,j,k,en,ir) = Q_in(i,j,k,en,ir) - dt*(glflux_r(i,j,k,en,ir)-source_r(i,j,k,en,ir))
          !--------------------------------
          Q_out(i,j,k,exx,ir) = fac * ( Q_in(i,j,k,exx,ir) - dt*glflux_r(i,j,k,exx,ir) )
          Q_out(i,j,k,eyy,ir) = fac * ( Q_in(i,j,k,eyy,ir) - dt*glflux_r(i,j,k,eyy,ir) )
          Q_out(i,j,k,ezz,ir) = fac * ( Q_in(i,j,k,ezz,ir) - dt*glflux_r(i,j,k,ezz,ir) )
          Q_out(i,j,k,exy,ir) = fac * ( Q_in(i,j,k,exy,ir) - dt*glflux_r(i,j,k,exy,ir) )
          Q_out(i,j,k,exz,ir) = fac * ( Q_in(i,j,k,exz,ir) - dt*glflux_r(i,j,k,exz,ir) )
          Q_out(i,j,k,eyz,ir) = fac * ( Q_in(i,j,k,eyz,ir) - dt*glflux_r(i,j,k,eyz,ir) )
          !--------------------------------
        end do
        end do
        end do
        end do

        else

        do ir=1,nbasis
        do k = 1,nz
        do j = 1,ny
        do i = 1,nx
          !--------------------------------
          Q_out(i,j,k,rh,ir) = Q_in(i,j,k,rh,ir) - dt*(glflux_r(i,j,k,rh,ir)-source_r(i,j,k,rh,ir))
          Q_out(i,j,k,mx,ir) = Q_in(i,j,k,mx,ir) - dt*(glflux_r(i,j,k,mx,ir)-source_r(i,j,k,mx,ir))
          Q_out(i,j,k,my,ir) = Q_in(i,j,k,my,ir) - dt*(glflux_r(i,j,k,my,ir)-source_r(i,j,k,my,ir))
          Q_out(i,j,k,mz,ir) = Q_in(i,j,k,mz,ir) - dt*(glflux_r(i,j,k,mz,ir)-source_r(i,j,k,mz,ir))
          Q_out(i,j,k,en,ir) = Q_in(i,j,k,en,ir) - dt*(glflux_r(i,j,k,en,ir)-source_r(i,j,k,en,ir))
          !--------------------------------
          Q_out(i,j,k,exx,ir) = fac*( Q_in(i,j,k,exx,ir) -                                      &
                                      dt*(glflux_r(i,j,k,exx,ir) - source_r(i,j,k,exx,ir)) )
          Q_out(i,j,k,eyy,ir) = fac*( Q_in(i,j,k,eyy,ir) -                                      &
                                      dt*(glflux_r(i,j,k,eyy,ir) - source_r(i,j,k,eyy,ir)) )
          Q_out(i,j,k,ezz,ir) = fac*( Q_in(i,j,k,ezz,ir) -                                      &
                                      dt*(glflux_r(i,j,k,ezz,ir) - source_r(i,j,k,ezz,ir)) )
          Q_out(i,j,k,exy,ir) = fac*( Q_in(i,j,k,exy,ir) -                                      &
                                      dt*(glflux_r(i,j,k,exy,ir) - source_r(i,j,k,exy,ir)) )
          Q_out(i,j,k,exz,ir) = fac*( Q_in(i,j,k,exz,ir) -                                      &
                                      dt*(glflux_r(i,j,k,exz,ir) - source_r(i,j,k,exz,ir)) )
          Q_out(i,j,k,eyz,ir) = fac*( Q_in(i,j,k,eyz,ir) -                                      &
                                      dt*(glflux_r(i,j,k,eyz,ir) - source_r(i,j,k,eyz,ir)) )
          !--------------------------------
        end do
        end do
        end do
        end do
        end if
    end subroutine advance_time
    !---------------------------------------------------------------------------


    !---------------------------------------------------------------------------
    subroutine advance_time_source(Q_in, Q_out, dt)
        implicit none
        real, dimension(nx,ny,nz,nQ,nbasis), intent(in)  :: Q_in
        real, dimension(nx,ny,nz,nQ,nbasis), intent(out) :: Q_out
        real, intent(inout) :: dt
        integer :: i,j,k,ir
        real :: dn,dni,vx,vy,vz,P, vx2,vy2,vz2,vsq,nu_dt,fac

        nu_dt = nu*dt
        fac = 1./(1. + nu_dt)

        do k = 1,nz
        do j = 1,ny
        do i = 1,nx
          do ir=1,nbasis
            Q_out(i,j,k,exx,ir) = ( Q_in(i,j,k,exx,ir) + nu_dt*source_r(i,j,k,exx,ir) ) * fac
            Q_out(i,j,k,eyy,ir) = ( Q_in(i,j,k,eyy,ir) + nu_dt*source_r(i,j,k,eyy,ir) ) * fac
            Q_out(i,j,k,ezz,ir) = ( Q_in(i,j,k,ezz,ir) + nu_dt*source_r(i,j,k,ezz,ir) ) * fac
            Q_out(i,j,k,exy,ir) = ( Q_in(i,j,k,exy,ir) + nu_dt*source_r(i,j,k,exy,ir) ) * fac
            Q_out(i,j,k,exz,ir) = ( Q_in(i,j,k,exz,ir) + nu_dt*source_r(i,j,k,exz,ir) ) * fac
            Q_out(i,j,k,eyz,ir) = ( Q_in(i,j,k,eyz,ir) + nu_dt*source_r(i,j,k,eyz,ir) ) * fac
          end do
        end do
        end do
        end do
    end subroutine advance_time_source
    !---------------------------------------------------------------------------

    !---------------------------------------------------------------------------
    ! NOTE: may be able to make functions from Qin loop and final loop w/
    !       0.125*cbasis(...) for re-use by advance_time_src & source_calc
    subroutine advance_time_src_v0(Q_in, Q_out, dt)
        implicit none
        real, dimension(nx,ny,nz,nQ,nbasis), intent(in)  :: Q_in
        real, dimension(nx,ny,nz,nQ,nbasis), intent(out) :: Q_out
        real, intent(inout) :: dt

        real, dimension(npg,nQ) :: source, Qout
        real, dimension(nQ) :: Qin
        integer i,j,k,ieq,ipg,ir
        real dn,dni,vx,vy,vz,P, vx2,vy2,vz2,vsq,nudt,fac

        nudt = nu*dt
        fac = 1./(1. + nudt)

        do k = 1,nz
        do j = 1,ny
        do i = 1,nx
            do ipg = 1,npg
                do ieq = 1,nQ
                    Qin(ieq) = sum(bfvals_int(ipg,1:nbasis)*Q_in(i,j,k,ieq,1:nbasis))
                end do
                !--------------------------------
                dn  = Qin(rh)
                dni = 1./Qin(rh)
                vx  = Qin(mx)*dni
                vy  = Qin(my)*dni
                vz  = Qin(mz)*dni
                vx2 = vx*vx
                vy2 = vy*vy
                vz2 = vz*vz
                vsq = vx2 + vy2 + vz2
                P   = aindm1*(Qin(en) - 0.5*dn*vsq)
                if (P < P_floor) P = P_floor  ! NOTE: is this necessary?
                !--------------------------------
                Qout(ipg,exx) = ( Qin(exx) + nudt*(P + dn*vx2  ) ) * fac
                Qout(ipg,eyy) = ( Qin(eyy) + nudt*(P + dn*vy2  ) ) * fac
                Qout(ipg,ezz) = ( Qin(ezz) + nudt*(P + dn*vz2  ) ) * fac
                Qout(ipg,exy) = ( Qin(exy) + nudt*(    dn*vx*vy) ) * fac
                Qout(ipg,exz) = ( Qin(exz) + nudt*(    dn*vx*vz) ) * fac
                Qout(ipg,eyz) = ( Qin(eyz) + nudt*(    dn*vy*vz) ) * fac
            end do

            do ieq=exx,nQ
                do ir=1,nbasis
                    Q_out(i,j,k,ieq,ir) = 0.125*cbasis(ir)*sum(wgt3d(1:npg)*bfvals_int(1:npg,ir)*Qout(1:npg,ieq))
                    ! This is probably faster
                    ! Q_out(i,j,k,ieq,ir) = 0.125*cbasis(ir)*sum(bval_int_wgt(1:npg,ir)*Qout(1:npg,ieq))
                end do
            end do
        end do
        end do
        end do
    end subroutine advance_time_src_v0
    !---------------------------------------------------------------------------


    !---------------------------------------------------------------------------
    ! Check for NaNs; bail out with info.
    !---------------------------------------------------------------------------
    subroutine check_for_NaNs(Q_io)
        implicit none
        real, dimension(nx,ny,nz,nQ,nbasis), intent(inout) :: Q_io
        integer i,j,k,ieq

        do ieq = 1,nQ
        do k = 1,nz
        do j = 1,ny
        do i = 1,nx
            if ( Q_io(i,j,k,ieq,1) /= Q_io(i,j,k,ieq,1) ) then
              print *,'------------------------------------------------'
              print *,'NaN. Bailing out...'
              write(*,'(A7,I9,A7,I9,A7,I9)')          '   i = ',   i, '   j = ',    j, '   k = ',k
              write(*,'(A7,ES9.2,A7,ES9.2,A7,ES9.2)') '  xc = ',xc(i),'  yc = ',yc(j), '  zc = ', zc(k)
              write(*,'(A14,I2,A7,I2)') '    >>> iam = ', iam, ' ieq = ', ieq
              print *,''
              call exit(-1)
            endif
        end do
        end do
        end do
        end do
    end subroutine check_for_NaNs
    !---------------------------------------------------------------------------

end module integrator
