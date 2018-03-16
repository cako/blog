#!/usr/bin env
export OMP_NUM_THREADS=4 
export JULIA_NUM_THREADS=4

gfortran bench_example.f90 -o bench_example.so -Ofast -fopenmp -lblas -march=native -shared -fPIC
gfortran bench_example.f90 -o bench_example -Ofast -fopenmp -lblas -march=native
./bench_example
julia -O3 -p 4 bench_example.jl
