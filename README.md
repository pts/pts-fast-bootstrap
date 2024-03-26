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

It is a future plan to have the bootstrap assembler implemented in multiple
programming languages, targeting Linux i386:

* NASM: already implemented as `fbsasm.nasm`, use it with
  `./bootstrap_nasm.sh nasm`. It is a reimplementation of a subset of fasm
  1.30 (for Linux i386) in NASM 0.98.39 or later. It was created by
  concatenating source files from fasm 1.30 and fasm 1.37 (Linux-specific
  `fasm.asm` and `system.inc`), and manually converting it to NASM syntax
  (mostly doing some manual changes and then many regexp substitutions).
* fasm: already implemented as `fbsasm.fasm`, use it with
  `./bootstrap_fasm.sh fasm`.
* GNU as(1) (+ GNU ld(1)): already implemented as `fbsasm.s`, use it with
  `./bootstrap_fasm.sh as`. It is autogenerated by `fbsasm.nasm` using the
  bundled `nasm2as.pl` Perl script. It works with various versions of GNU
  Binutils, tested with 2.9.1 (released on 1998-05-01, part of Debian 2.1
  slink), 2.9.5, 2.22 and 2.30.
* TASM (Turbo Assembler) + folink1 (custom linker): already implemented as
  `fbsasm.tas`, use it with `./bootstrap_fasm.sh tasm`. It works with TASM
  2.0 (1990) and the TASM 4.1 (1996, the latest Turbo Assembler which works
  on a DOS 8086 without a DOS extender).
* A386 (by Eric Isaacson): already implemented
  as `fbsasm.8`, use it with `./bootstrap_fasm.sh a386`. It works with the
  A386 4.05 (2000-01-13) on a DOS 8086 (maybe needs an i386 processor).
* JWasm
* C89 (ANSI C): it should work with GCC on Debian slink (released on
  1999-03-09), released before 2001-01-01, before fasm 1.20; how far can we
  go to the past? 1999? 1996?
