x = Cdouble[1,2,3,4]
y = Cdouble[1,1,1,1]
n = Cint[4]
a = Cdouble[NaN]
ccall((:better_dot, "./better_example.so"),
      Void,
      (Ref{Cint}, Ref{Cdouble}, Ref{Cdouble}, Ref{Cdouble}),
      n, x, y, a)
println(a)
