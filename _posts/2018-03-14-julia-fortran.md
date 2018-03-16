---
layout: post
title:  "Julia and Fortran"
date:   2018-03-14
categories: julia fortran
---

[Julia](https://julialang.org/) is an exciting new language with several interesting capabilities: high-level syntax which resembles MATLAB, high performance, multiple dispatch, etc.
One of my favorite features, is its no-nonsense, no-boilerplate approach to calling C and Fortran code.
But while [examples for C abound](https://docs.julialang.org/en/stable/manual/calling-c-and-fortran-code/), Fortran information is scarcer.

The objective of this short tutorial is to get you up to speed with calling Fortran code from Julia in the most painless way possible.
Most information here has been obtained from the Julia documentation and this [very enlightening discussion](https://groups.google.com/forum/#!topic/julia-users/Hujil3RqWQQ), both of which I highly recommend reading.
If you want to skip the read and just grab the codes, head [here](https://github.com/cako/cako.github.io/tree/master/codes/2018-03-14-julia-fortran).

#### Super basic example
Let's say you have a Fortran `function` or `subroutine` to calculate the dot product.
Your file may look something like this:

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

The process of accessing this through Julia is simple, but with a few caveats along the way.
The compilation is simple:

{% highlight bash %}
gfortran basic_example.f90 -o basic_example.so -shared -fPIC
{% endhighlight %}

As the documentation states, we must ensure that a shared library with position-independent code ([PIC](https://en.wikipedia.org/wiki/Position-independent_code)) is used.
Mimicking C, we ideally would be able to call it from Julia with 

{% highlight julia %}
ccall((:dot, "./basic_example.so"), ...
{% endhighlight %}

This will not work, and we've hit our first snag.
One must use the Fortran symbol name of the function, which is unlikely to be `dot` as Fortran [generates mangled names](https://en.wikipedia.org/wiki/Name_mangling#Fortran).
In order to address that we must find the symbol name.
A quick way to do that in Linux is to use the [`nm` command](https://en.wikipedia.org/wiki/Nm_\(Unix\)), which lists the names of symbols in a binary:

{% highlight bash %}
nm basic_example.so | grep dot
{% endhighlight %}

On my machine this returns `__basic_example_MOD_dot`, which is the name which should be used in the `ccall`.
In the next example we will see how we can bypass name mangling.

Now we have to worry about variable types.
The output is `real` and the inputs are: single `integer`, two `real` arrays.
C has system independent `float`s which are nicely matched to Julia types such as `Float32` or its alias `Cfloat`.
In Fortran that is not the case, our Fortran `real` most likely means `real*4`, which is equivalent to `Float32`, but we cannot be 100% sure, as it is architecture- and compiler-dependent, and could be `real*8`, for example.
The same goes for `integer` which most likely means `integer*4`, but can also mean `integer*2`.
For now, we will just assume that `real` is a `Float32` and `integer` is an `Int32`.
Our `dot` function should then read

{% highlight julia %}
ccall((:__basic_example_MOD_dot, "./basic_example.so"),
      Float32,
      (Ref{Int32}, Ref{Float32}, Ref{Float32}),
      ...
{% endhighlight %}

As per advised by the documentation, we should pass `Ref`s when the memory is allocated by Julia (our case), as opposed to `Ptr` when it is allocated by the other language.
We are nearly there, and all we have to do is create some input and pass that to the `ccall`:

{% highlight julia %}
x = Float32[1,2,3,4]
y = Float32[1,1,1,1]
n = Int32[4]
{% endhighlight %}

The arrays are straightforward; this is how one usually allocate arrays.
**Fortran `ccall` demands passing references (or pointers)** which is fine for arrays, as they are passed by reference.
An integer variable, on the other hand, is not bound to its reference, but rather to the value itself.
Therefore, to make our lives easier, we will just encase it within an `Int32` array.
With all that in mind, our `ccall` will finally look like:

{% highlight julia %}
ccall((:__basic_example_MOD_dot, "./basic_example.so"),
      Float32,
      (Ref{Int32}, Ref{Float32}, Ref{Float32}),
      n, x, y)
{% endhighlight %}

This should return `10.0`. If, for some reason, you do not want to encase your value in an array, you can always use the `Ref` function to obtain its reference. For example, if I had an `Int32` bound to `n` (for example through `n = Int32[4][]`), I would change the last line of the previous code from
{% highlight julia %}
      ...
      n, x, y)
{% endhighlight %}
to
{% highlight julia %}
      ...
      Ref(n), x, y)
{% endhighlight %}

#### Slightly better example

If your Fortran code is part of a well established library, especially one which interacts with other languages, it is possible that your code uses C bindings.
Alternatively, you may have some pull on how the code is written and you can add that yourself.
In these cases, you might come across a similar code pattern:

{% highlight fortran %}
module better_example
    use, intrinsic :: iso_c_binding
    implicit none
    contains

    subroutine dot(n, x, y, a) bind(c, name="better_dot")
        integer(c_int), intent(in) :: n
        real(c_double), dimension(n), intent(in) :: x, y
        real(c_double), intent (out) :: a
        integer(c_int) :: i
        a = 0.
        do i=1, n
            a  = a + x(i)*y(i)
        end do
    end subroutine dot
end module better_example
{% endhighlight %}

The first difference we notice is the use of `iso_c_binding`.
This creates named constants which are equivalent to their C types (see [here](https://gcc.gnu.org/onlinedocs/gfortran/ISO_005fC_005fBINDING.html)).
In a multi-language setting, it sets a standard dialect to be spoken by all.

The second difference is the use of `bind` after the `subroutine` definition.
This ensures that the `subroutine` can be accessed by C functions.
Conveniently, it also means that we can name the structure without the standard mangling.
I chose to call it `better_dot`, but omitting `name=` in this case would just result in `dot`.

Finally, this time I chose to use a `subroutine` as opposed to a `function`.
In this case the output value has to be placed in the input variable `a`.
This will affect how we write the associated `ccall`.

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

We will be using now `Cdouble`s and `Cint`s to make it clear that we are interoperable.
Our `ccall` also looks a bit different: our return is now `Void`, and instead we are passing `a` as the container for our return.
After running the code above, `a` will become `[10.0]`.
Note the use of `NaN` in its first declaration: this helps us debug a faulty `ccall`.

#### Benchmarks

Now that we know how to call Fortran code from Julia, let's run some benchmarks.
These are meant to be merely illustrative, and they are *not* rigorous benchmarks.

The Fortran functions can be found below.

{% highlight fortran %}
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
{% endhighlight %}
                    
These functions were compiled to a standard Fortran binary (`-Ofast -fopenmp -lblas -march=native`), to be our native Fortran comparison.
The full benchmarking code can be found [here](https://github.com/cako/cako.github.io/blob/master/codes/2018-03-14-julia-fortran/bench_example.f90).
They were also compiled to a library to be called from Julia.
Finally, I also benchmarked the native dot product, as well as a serial and a multi-threaded parallel implementation ([courtesy of `@stabbles` and `@bkamins`](https://discourse.julialang.org/t/innefficient-paralellization-need-some-help-optimizing-a-simple-dot-product)) which can be respectively found below.
The full Julia benchmark code can be found [here](https://github.com/cako/cako.github.io/blob/master/codes/2018-03-14-julia-fortran/bench_example.jl).
I also provide a script to compile, run and benchmark these two codes at once.
Grab it from [here}(https://github.com/cako/cako.github.io/blob/master/codes/2018-03-14-julia-fortran/bench_example.sh).

{% highlight julia %}
function sdot(a::AbstractVector{T}, b::AbstractVector{T}) where {T}
    v = zero(T)
    @inbounds @simd for i = 1 : length(a)
        v += a[i] * b[i]
    end
    v
end

function pdot(a::AbstractVector{T}, b::AbstractVector{T}) where {T}
    N = Threads.nthreads()
    v = zeros(T, N)
    Threads.@threads for i in 1:N
        x = zero(T)
        P = Threads.threadid()
        range = split(length(a), N, P)
        @inbounds @simd for i in range
            x += a[i] * b[i]
        end
        v[P] = x
    end
    sum(v)
end
{% endhighlight %}

A table with the summary of results can be found below (run with `julia -p 2`, taking the minimum over 3 runs):


|           | Native Fortran |          | Julia Fortran |          | Native Julia |          |        |
|----------:|:--------------:|:--------:|:-------------:|:--------:|:------------:|:--------:|:------:|
|           |     Serial     | Parallel |     Serial    | Parallel |    Serial    | Parallel | Native |
|  Time (µs)|      51.1      |   30.8   |      47.1     |   22.2   |     48.7     |    34.3  |  37.3  |
| Speed  (x)|      2.3       |   1.4    |      2.1      |    1     |      2.2     |     1.5  |  1.7   |

If we compare native Fortran and Fortran through Julia, we see almost no difference in times.
Fotran called from Julia is in fact, slightly faster, for reasons I don't fully comprehend.
In any case the `ccall` overhead is negligible.
We also do very well with pure Julia.
This requires activating some [performance tips](https://docs.julialang.org/en/stable/manual/performance-tips/) like `@simd`, `@inbounds`, and type stability.
The [native Julia `dot`](https://github.com/JuliaLang/julia/blob/master/stdlib/LinearAlgebra/src/blas.jl), which relies on BLAS (which is not multi-threaded), is also very performant.
A (slightly adapted) version can be found below:

{% highlight julia %}
function dot(n::Integer, DX::Union{Ptr{Float64},AbstractArray{Float64}}, incx::Integer,
                         DY::Union{Ptr{Float64},AbstractArray{Float64}}, incy::Integer)
    ccall((:ddot, libblas), Float64,
        (Ref{BlasInt}, Ptr{Float64}, Ref{BlasInt}, Ptr{Float64}, Ref{BlasInt}),
        n, DX, incx, DY, incy)
end
{% endhighlight %}

#### Conclusions
I hope this post has been able to convince you that using Fortran from Julia is not only easy, it is fast both in terms of implementation and in terms of computation.
It is also important to notice that even though using Fortran is attractive from a performance perspective, native Julia (through standard libraries) can be just as fast.
Therefore, before you decide to start writing new Fortran code, it might be wise to investigate whether it is possible to reduce the problem to functions in the standard library.

In this post, I limited myself to a very simplistic scenario where I am passing unidimensional arrays created in Julia, along with their size to a Fortran function.
In the next post I will explore some dangers, limitations and possible mitigation strategies when dealing with more complex code patterns.
