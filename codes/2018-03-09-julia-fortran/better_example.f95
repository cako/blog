module better_example
    use, intrinsic :: iso_c_binding
    implicit none
    contains

    subroutine dot(n, x, y, a) bind(c, name="better_dot")
        integer(c_int), intent(in) :: n
        real(c_double), dimension(n), intent(in) :: x, y
        real(c_double), intent (out) :: a
        integer :: i
        a = 0.
        do i=1, n
            a  = a + x(i)*y(i)
        end do
    end subroutine dot
end module better_example
