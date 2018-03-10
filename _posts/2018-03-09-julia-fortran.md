---
layout: post
title:  "Julia and Fortran"
date:   2018-03-09 16:16:01 -0600
categories: julia fortran
---

[Julia](https:/julialang.org/) is an exciting new language with several interesting capabilities: high-level syntax which resembles MATLAB, high performance, multiple dispatch, etc. One of my favorite features, is its no-nonsense, native approach to calling C and Fortran code. While documentation on C is [widely available online](https://docs.julialang.org/en/stable/manual/calling-c-and-fortran-code/), getting Fortran to work is a bit tricky.

The objective of this short tutorial is to get you up to speed with calling Fortran code from Julia in the most painless way possible.
Most information here has been obtained from the Julia documentation and this [very enlightening discussion](https://groups.google.com/forum/#!topic/julia-users/Hujil3RqWQQ), both of which I highly recommend reading.

# Super basic example
Let's say you have a function or subroutine Fortran to calculate the dot product. Your file may look something like this:

{% highlight fortran %}
module basic_example
    contains

    real function dot(n, x, y)
        integer :: n
        real, dimension(n) :: x, y

        a = 0.
        do i = 1, n
           a = x(i)*y(i) 
        end do
        dot = a
    end function dot
end module basic_example
{% endhighlight %}

The process of accessing this through Julia is simple, but with a few caveats along the way. The compilation is simple:

{% highlight bash %}
gfortran basic_example.f95 -o basic_example.so -shared -fPIC
{% endhighlight %}

As the documentation states, we must ensure that a shared library with position-independent code ([PIC](https://en.wikipedia.org/wiki/Position-independent_code)) is used.  After that, we ideally would be able to call it from Julia with 

{% highlight julia %}
ccall((:dot, "./basic_example.so"), ...
{% endhighlight %}

Unfortunately that is not the case: one must use the Fortran symbol name of the function, which is unlikely to be `dot` as Fortran [generates mangled names](https://en.wikipedia.org/wiki/Name_mangling#Fortran). In order to address that we must find the symbol name. A quick way to do that in Linux is to use the [`nm`](https://en.wikipedia.org/wiki/Nm_\(Unix\)) command, which lists the names of symbols in a binary:

{% highlight bash %}
nm basic_example.so | grep dot
{% endhighlight %}

On my machine this returns `__basic_example_MOD_dot`, which is the name which should be used in the `ccall`. In the next example we will see how we can bypass name mangling.

Now we have to worry about variable types. The output is `real` and the inputs are: single `integer`, two `real` arrays. C has system independent `float`s which are nicely matched to Julia types such as `Float32` or its alias `Cfloat`. In Fortran that is not the case, our Fortran `real` most likely means `real*4`, which is equivalent to `Float32`, but we cannot be 100% sure, as it is architechture and compile dependent and could be for example `real*8`. The same goes for `integer` which most likely means `integer*4`, but can also mean `integer*2`. For now, we will just assume that `real` is a `Float32` and `integer` is an `Int32`. Our `dot` function should then read

{% highlight julia %}
ccall((:__basic_example_MOD_dot, "./basic_example.so"),
      Float32,
      (Ref{Int32}, Ref{Float32}, Ref{Float32}),
      ...
{% endhighlight %}

As per advised by the documentation, we should pass `Ref`s when the memory is allocated by Julia (our case), as opposed to `Ptr` when it is allocated by the other language. We are now nearly there and all we have to do is create some input and pass that to the `ccall`:

{% highlight julia %}
x = Float32[1,2,3,4]
y = Float32[1,1,1,1]
n = Int32[4]
{% endhighlight %}

The arrays are straightforward; this is how one usually allocate arrays. This is because the Fortran `ccall` demands passing references (or pointers) which is fine for arrays, as they are passed by reference. An integer variable, on the other hand, is not bound to the reference of the variable, but to the value itself. Therefore, to make our lives easier, we will just encase it within an `Int32` array. With all that in mind, our `ccall` will finally look like:

{% highlight julia %}
ccall((:__basic_example_MOD_dot, "./basic_example.so"),
      Float32,
      (Ref{Int32}, Ref{Float32}, Ref{Float32}),
      n, x, y)
{% endhighlight %}

This should return `10.0`.

# Slightly better example

If your Fortran code is part of a well established library, especially one which interacts with other languages, it is possible that your code uses C bindings. Alternatively, you may have some pull on how the code is written and you can add that yourself. In these cases, the following code pattern works for me:

{% highlight fortran %}
module better_example
    use, intrinsic :: iso_c_binding
    implicit none
    contains

    subroutine dot(n, x, y, a) bind(c, name="better_dot")
        integer, intent(in) :: n
        real(c_double), dimension(n), intent(in) :: x, y
        real(c_double), intent (out) :: a
        integer :: i
        a = 0.
        do i=1, n
            a  = a + x(i)*y(i)
        end do
    end subroutine dot
end module better_example
{% endhighlight %}

The first difference we notice is the use of [`iso_c_binding`](https://gcc.gnu.org/onlinedocs/gfortran/ISO_005fC_005fBINDING.html). This creates named constants which are equivalent to their C types. In  multilanguage setting, it sets a standard dialect to be spoken by all. The second difference is the use of `bind` after the `subroutine` definition. This ensures that the `subroutine` can be accessed by C functions. Conveniently, it also means that we can name the structure without the standard mangling. I chose to call it `better_dot`, but omitting `name=` in this case would just result in `dot`.

We compile the code similarly as before, but now our Julia code will look like this:

{% highlight julia %}
x = Cdouble[1,2,3,4]
y = Cdouble[1,1,1,1]
n = Cint[4]
a = Cdouble[NaN]
ccall((:better_dot, "./better_example.so"),
      Void,
      (Ref{Cint}, Ref{Cdouble}, Ref{Cdouble}, Ref{Cdouble}),
      n, x, y, a)
{% endhighlight %}

We will be using now `Cdouble`s and `Cint`s to make it clear that we are interoperable. Our `ccall` also looks a bit different: our return is now `Void`, and instead we are passing `a` as the container for our return. After running the code above, `a` will become `[10.0]`. Note the use of `NaN` in its first declaration: this helps us debug a faulty `ccall`.
