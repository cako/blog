module dot_prod
    use, intrinsic :: iso_c_binding
    implicit none
    contains

    real(c_double) function sdot(n, x, y) bind(c, name="sdot")
        integer(c_int), intent(in) :: n
        real(c_double), dimension(n), intent(in) :: x, y
        integer(c_int) :: i
        real(c_double) :: a
        a = 0.
        do i=1, n
            a  = a + x(i)*y(i)
        end do
        sdot = a
    end function sdot

    real(c_double) function pdot(n, x, y) bind(c, name="pdot")
        integer(c_int), intent(in) :: n
        real(c_double), dimension(n), intent(in) :: x, y
        integer(c_int) :: i
        real(c_double) :: a
        a = 0.
        !$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(i,n) REDUCTION(+:a)
        do i=1, n
            a  = a + x(i)*y(i)
        end do
        !$OMP END PARALLEL DO
        pdot = a
    end function pdot
end module dot_prod

program time_dot
    use, intrinsic :: iso_c_binding
    use omp_lib
    use dot_prod
    implicit none

    real :: start_time, stop_time
    integer(c_int), parameter :: n = 10000
    real(c_double), dimension(n) :: x, y
    real(c_double) :: p
    integer(c_int) :: i

    x = (/ (1., i=1,n) /)
    y = (/ (i, i=1,n) /)

    start_time = omp_get_wtime()
    do i=1, n
        p = sdot(n, x, y)
    enddo
    stop_time = omp_get_wtime()
    print *, "Native serial Fortran"
    print "(F14.2)", p
    write(*,fmt="(F15.10,A)") stop_time-start_time, " seconds"

    start_time = omp_get_wtime()
    do i=1, n
        p = pdot(n, x, y)
    enddo
    stop_time = omp_get_wtime()
    print *
    print *, "Native parallel Fortran"
    print "(F14.2)", p
    write(*,fmt="(F15.10,A)") stop_time-start_time, " seconds"
end program time_dot
