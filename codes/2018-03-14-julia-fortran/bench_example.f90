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

    real(c_double), external :: ddot
    real(c_double) :: start_time, stop_time
    integer(c_int), parameter :: n = 100000
    real(c_double), dimension(n) :: x, y
    real(c_double) :: p1, p2, p3
    integer(c_int) :: i, threads
    !$OMP PARALLEL
    threads = omp_get_num_threads()
    !$OMP END PARALLEL

    x = 1.
    y = (/ (i, i=1,n) /)

    p1 = sdot(n, x, y)
    p2 = ddot(n, x, 1, y, 1)
    p3 = pdot(n, x, y)
    if ((p1 /= p2 .OR. p2 /= p3) .OR. p1 /= p3) then 
        print *, "Values do not match"
        call exit(1)
    endif

    start_time = omp_get_wtime()
    do i=1, n
        p1 = sdot(n, x, y)
    enddo
    stop_time = omp_get_wtime()
    write(*,*) p1
    write(*,fmt="(A,F8.3,A)") "Native Fortran (no threads): ", 1e6*(stop_time-start_time)/n, " μs"

    start_time = omp_get_wtime()
    do i=1, n
        p2 = ddot(n, x, 1, y, 1)
    enddo
    stop_time = omp_get_wtime()
    write(*,fmt="(A,F10.3,A)") "Fortran BLAS (no threads): ", 1e6*(stop_time-start_time)/n, " μs"

    start_time = omp_get_wtime()
    do i=1, n
        p3 = pdot(n, x, y)
    enddo
    stop_time = omp_get_wtime()
    write(*,fmt="(A,I1,A,F9.3,A)") "Native Fortran (", threads," threads): ", 1e6*(stop_time-start_time)/n, " μs"
end program time_dot
