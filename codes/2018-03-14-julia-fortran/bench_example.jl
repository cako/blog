using BenchmarkTools

function sdot(a::AbstractVector{T}, b::AbstractVector{T}) where {T}
    v = zero(T)
    @inbounds @simd for i = 1 : length(a)
        v += a[i] * b[i]
    end

    v
end

"""
    split(N, P, i) -> from:to
    
Find the ith range when 1:N is split into P consecutive parts of roughly equal size
"""
function split(N, P, i)
    base, rem = divrem(N, P)
    from = (i - 1) * base + min(rem, i - 1) + 1
    to = from + base - 1 + (i ≤ rem ? 1 : 0)
    from : to
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

@everywhere @inbounds @fastmath function ppdot(x, y)
    @parallel (+) for i=1:length(x)
        x[i]*y[i]
    end
end

function fsdot(x::AbstractVector{Float64}, y::AbstractVector{Float64})
    const benchlib = "./bench_example.so"
   return ccall((:sdot, benchlib), Cdouble, (Ref{Cint},Ref{Cdouble},Ref{Cdouble}),
                Cint[length(x)], x, y)
end

function fpdot(x::AbstractVector{Float64}, y::AbstractVector{Float64})
    const benchlib = "./bench_example.so"
   return ccall((:pdot, benchlib), Cdouble, (Ref{Cint},Ref{Cdouble},Ref{Cdouble}),
                Cint[length(x)], x, y)
end

function bench(n = 100_000)
    a = ones(Float64, n)
    b = Float64[i for i=1:n]
    threads = parse(Int, ENV["JULIA_NUM_THREADS"])
    omp_threads = parse(Int, ENV["OMP_NUM_THREADS"])

    # Sanity check
    @assert dot(a,b) ≈ pdot(a,b) ≈ sdot(a, b) ≈ fsdot(a, b) ≈ fpdot(a, b) ≈ ppdot(a, b)

    print("Julia Fortran (no threads):\t")
    println(@benchmark fsdot($a, $b))
    print("Julia Fortran (", omp_threads, " threads):\t")
    println(@benchmark fpdot($a, $b))

    BLAS.set_num_threads(threads)
    print("Julia BLAS (", threads, " threads):\t")
    println(@benchmark dot($a, $b))
    print("Julia (no threads):\t")
    println(@benchmark sdot($a, $b))
    print("Julia (", threads, " threads):\t")
    println(@benchmark pdot($a, $b))

    a = convert(SharedArray, a)
    b = convert(SharedArray, b)
    print("Julia (", nprocs()-1, " procs):\t")
    println(@benchmark ppdot($a, $b))
end

bench()
