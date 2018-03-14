n = Cint[10000]
x = [ 1. for i=1:n[]]
y = [ i for i=1.:n[]]


function sdot(n, x, y)
    a = 0
    for i=1:n[]
        a += x[i]*y[i]
    end
    a
end

function pdot(n, x, y)
    @parallel (+) for i=1:n[]
        x[i]*y[i]
    end
end

const benchlib = "./bench_example.so"
println("Serial Fortran")
p = ccall((:sdot, benchlib), Cdouble, (Ref{Cint}, Ref{Cdouble}, Ref{Cdouble}), n, x, y)
println(@sprintf(" %.2f", p))
@time for i=1:n[]
    ccall((:sdot, "./bench_example.so"), Cdouble, (Ref{Cint}, Ref{Cdouble}, Ref{Cdouble}), n, x, y)
end

println("\nParallel Fortran")
p = ccall((:pdot, benchlib), Cdouble, (Ref{Cint}, Ref{Cdouble}, Ref{Cdouble}), n, x, y)
println(@sprintf("  %.2f", p))
@time for i=1:n[]
    ccall((:pdot, benchlib), Cdouble, (Ref{Cint}, Ref{Cdouble}, Ref{Cdouble}), n, x, y)
end

println("\nNaive Julia")
println(@sprintf("  %.2f", sdot(n, x, y)))
@time for i=1:n[]
    sdot(n, x, y)
end

println("\nNative Julia")
println(@sprintf("  %.2f", dot(x, y)))
@time for i=1:n[]
    dot(x, y)
end

println("\nIdiomatic parallel Julia")
println(@sprintf("  %.2f", pdot(n, x, y)))
@time for i=1:n[]
    pdot(n, x, y)
end
