# pts-fasm-bootstrap: bootstrap the fasm assembler on Linux i386

pts-fast-boostrap bootstraps the fasm assembler on Linux i386, i.e. it
reproduces the `fasm` Linux i386 executable program bit-by-bit identical to
the official distribution from its sources (and also from the sources of
earlier fasm versions), but without having access to executable programs of
earlier fasm versions.

pts-fast-bootstrap was inspired by [bootstrapping FASM by rugxulo,
2018-02-20](https://board.flatassembler.net/topic.php?t=20431).

How to run:

* On a Linux x86 system (i386 or amd64), check out the Git repository, and
  run `./bootstrap_fasm.sh`.

* The output file is `fasm-re-1.73.32`, which is identical to the file `fasm-golden-1.73.32`.

* The output file is executable on a Linux x86 system (i386 or amd64), and
  it's statically linked (i.e. independent of the Linux distribution and the
  libc).

## Bootstrap chain

Involved fasm versions:

* fasm 1.20, released on 2001-11-17
* fasm 1.73.32, released on 2023-12-04

Both of these bootstrap chains are done by `./bootstrap_fasm.sh`:

* bootstrap assembler --> patched fasm 1.73.32 --> original fasm 1.73.32

* bootstrap assembler --> patched fasm 1.20 --> patched fasm 1.73.32 --> original fasm 1.73.32

## The bootstrap assembler

The bootstrap assembler is a simple, non-optimizing assembler targeting i386
(32-bit x86 only), and supports a subset of fasm syntax, and supports only a
subset of the i386 (32-bit x86) instructions. Its only goal is to compile
any of fasm 1.20, fasm 1.30 or fasm 1.73.32. Currently it is able to compile
a lightly patched source of all of them. `bootstrap_fasm.sh` does the
necessary patching.

Initially the bootstrap assembler was able to compile fasm 1.20 and fasm
1.30, but then it was discovered that it can also compile a lightly
patched fasm 1.73.32.

The bootstrap assembler has multiple (equivalent) implementations:

* The implementation for the oldest assembler is `fbsasm.mas`, which works
  with MASM 5.00 (1987-07-31), see the details below.
* NASM: already implemented as `fbsasm.nasm`, use it with
  `./bootstrap_nasm.sh nasm`. It is a reimplementation of a subset of fasm
  1.30 (for Linux i386) in NASM 0.95 (1997-07-27) or later. It has been
  tested with 0.98.39 extensively. It was created by
  concatenating source files from fasm 1.30 and fasm 1.37 (Linux-specific
  `fasm.asm` and `system.inc`), and manually converting it to NASM syntax
  (mostly doing some manual changes and then many regexp substitutions).
* Yasm: already implemented as `fbsasm.nasm`, use it with
  `./bootstrap_nasm.sh nasm=yasm`. The NASM source works without changes.
  Versions 1.2.0 (2011-10-31) and 1.3.0 (2014-09-11) are known to work.
  Maybe older versions work as well.
* fasm: already implemented as `fbsasm.fasm`, use it with
  `./bootstrap_fasm.sh fasm`. It needs at least fasm 1.20 (2001-11-17)
  to compile.
* GNU as(1) (+ GNU ld(1)): already implemented as `fbsasm.s`, use it with
  `./bootstrap_fasm.sh as`. It is autogenerated by `fbsasm.nasm` using the
  bundled `nasm2as.pl` Perl script. It works with various versions of GNU
  Binutils, tested with 2.7 (released on 1996-07-15), 2.9.1 (released on
  1998-05-01, part of Debian 2.1 slink), 2.9.5, 2.22 and 2.30.
* TASM (Turbo Assembler) + folink2 (custom linker): already implemented as
  `fbsasm.tas` (TASM ideal mode),
  use it with `./bootstrap_fasm.sh tasm`. It works with TASM
  1.01 (1989), 2.0 (1990), 4.1 (1996, the latest Turbo Assembler which works
  on a DOS 8086 without a DOS extender) and 5.3 (2000-01-30, probably the
  last release of TASM). The custom linker folink2 is also included and is
  built from source by TASM.
* LZASM (Lazy Assembler) + folink2 (custom linker): already implemented as
  `fbsasm.tas` (TASM ideal mode),
  use it with `./bootstrap_fasm.sh lzasm`. It works with LZASM
  0.56 (2007-10-04, last release) and possibly earlier. The custom linker
  folink2 is also included and is built from source by LZASM.
* MASM (Microsoft Macro Assembler) + WLINK: already implemented as
  `fbsasm.was`, currently `bootstrap_fasm.sh` doesn't support it. It works
  with MASM 5.00 (1987-07-31) or later, TASM 3.0 (1991-11-11) or later, WASM
  10.5 (1995-07-11) or later, JWasm 2.11a (2013-10-19) and maybe earlier,
  ASMC 2.34.49 (2024-030-26) and later and maybe earlier.
* as86 (part of dev86): already implemented as
  `fbsasm.as86`, use it with `./bootstrap_fasm.sh as86`. It works with as86
  0.0.7 (1996-09-03) and possibly earlier, but not 0.0.5.
* A386 (by Eric Isaacson): already implemented
  as `fbsasm.8`, use it with `./bootstrap_fasm.sh a386`. It works with the
  A386 4.05 (2000-01-13) on a DOS 8086 (maybe needs an i386 processor).
* [vasm](http://sun.hasenbraten.de/vasm/) (by Volker Barthelmann): already
  implemented as `fbsasm.vasm`, use it with `./bootstrap_fasm.sh vasm`. It
  works with vasm 1.9a (2022-10-02) and possibly earlier.
* [mw386as](https://github.com/pts/mw386as)
  (port of the Mark Williams 80386 assembler, originally 1993-08-02, part of
  Coherent) + link3coff.pl (custom linker),
  use it with `./bootstrap_fasm.sh mw`. It works with the
  1993-08-02 version rebuilt from source, but the code generated by 1992-11-11
  version seems to be broken. The custom linker is also included, and it's a
  Perl script. A Linux i386 executable of the Perl interpreter is also
  included.

It is a future plan to have the bootstrap assembler implemented in additional
programming languages, targeting Linux i386:

* MASM (Microsoft Macro Assembler) + folink3 (custom linker)
* JWasm: with a bit of luck, the MASM port will work. JWasm can emit binary
  files with the `-bin' flag, the linker is not
* WASM (Watcom Assembler) + folink3 (custom linker): with a bit of luck, the
  MASM port will work; also maybe WLINK will work in raw binary mode
* [ASMC](https://github.com/nidud/asmc): ASMC is a fork of JWasm, so with a
  bit of luck, the MASM port will work
* C89 (ANSI C): it should work with GCC on Debian slink (released on
  1999-03-09), released before 2001-01-01, before fasm 1.20; how far can we
  go to the past? 1999? 1996?
* Perl 5.004_04 (1997-10-15). A slow but simple assembler which can compile
  fbsasm.fasm. Maybe later it will be able to compile FASM-1.73.32 and
  fbsasm.nasm.
* [Solaris x86
  Assembler](https://docs.oracle.com/cd/E19120-01/open.solaris/817-5477/eqbui/index.html),
  part of OpenSolaris.
* POASM from Pelle's C.
* [HLA](https://en.wikipedia.org/wiki/High_Level_Assembly) with its built-in
* linker.
