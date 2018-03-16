module basic_example
    contains

    real function dot(n, x, y)
        integer :: n
        real, dimension(n) :: x, y

        a = 0.
        do i = 1, n
           a = a + x(i)*y(i) 
        end do
        dot = a
    end function dot
end module basic_example
