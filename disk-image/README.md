# BCPL, revisited

BCPL can be considered the "classic" programming language from the 1960's which
later inspired C.  See the BCPL [home
page](http://www.cl.cam.ac.uk/~mr10/BCPL.html) and [reference
manual](http://www.cl.cam.ac.uk/users/mr/bcplman.pdf) (PDF) by Martin Richards
and the [Wikipedia](https://en.wikipedia.org/wiki/BCPL) page.

This is an extract of one of the earlier versions of BCPL, when it was still
16-bit only and interpreted. All the fancier stuff to compile straight to
machine code has been left out, to illustrate _how little is needed_ for a
full-blown 2-pass compiler, assembler-linker, and interpreter.

The assembler-linker and the interpreter are modeled after the original `icint`
code in C, but have been completely re-written from scratch in Python.

The files in this area are sufficient to compile and run arbitrary source code
programs written in traditional BCPL (using `$(` + `$)` instead of `{` + `}`,
for example).  In addition, all the original sources are included to re-build
both the BCPL compiler and the runtime library from scratch, as long as you are
careful not to break the core set of properly-working files, i.e.  `pass1`,
`pass2`, and `run-time.i`.

Two shell scripts simplify day-to-day use of this system:

1. To compile: `./b [-c] [-o outfile] file.b ...`
2. To run: `./r [outfile]`

The `b` and `r` script will automatically switch to [PyPy](http://pypy.org) if
it is available, which should boost the interpreter's speed about 15-fold.

The default outfile is `EXCODE`, which allows shortening the above commands to:

    ./b hello.b && ./r

To rebuild the two compiler passes, do:

    ./b -o pass1 syn.b trn.b
    ./b -o pass2 cg.b

To rebuild the run-time library (note: `iclib.i` contains a few lines of
hand-written glue code):

    ./b -c blib.b && cat blib.i iclib.i >run-time.i

You can read the [TFoC - A compiler in 256
LoC](https://jeelabs.org/2017/11/tfoc---a-compiler-in-256-loc/) post on the
JeeLabs weblog for further details.

-jcw, 2017-10-21
