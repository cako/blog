---
layout: post
title:  "Julia and Fortran"
date:   2018-03-09
categories: julia fortran
---

[Julia](https:/julialang.org/) is an exciting new language with several interesting capabilities: high-level syntax which resembles MATLAB, high performance, multiple dispatch, etc. One of my favorite features, is its no-nonsense, native approach to calling C and Fortran code. While documentation on C is [widely available online](https://docs.julialang.org/en/stable/manual/calling-c-and-fortran-code/), getting Fortran to work is a bit tricky.

The objective of this short tutorial is to get you up to speed with calling Fortran code from Julia in the most painless way possible.
Most information here has been obtained from the Julia documentation and this [very enlightening discussion](https://groups.google.com/forum/#!topic/julia-users/Hujil3RqWQQ), both of which I highly recommend reading.

Super basic example
===================
Let's say you have a function/subroutine Fortran to calculate the dot product. Your file may look something like this:

{{ "{% highlight javascript " }}%}  
/* Some pointless Javascript */
var rawr = ["r", "a", "w", "r"];
{{ "{% endhighlight " }}%}  



