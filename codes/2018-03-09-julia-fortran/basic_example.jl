x = Float32[1,2,3,4]
y = Float32[1,1,1,1]
n = Int32[4]
println(ccall((:__basic_example_MOD_dot, "./basic_example.so"),
              Float32,
              (Ref{Int32}, Ref{Float32}, Ref{Float32}),
              n, x, y))
