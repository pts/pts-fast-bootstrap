# pts-fasm-bootstrap: bootstrap the fasm assembler on Linux i386

pts-fasm-bootstrap bootstraps the fasm assembler on Linux i386, i.e. it
reproduces a recent `fasm` Linux i386 executable program bit-by-bit
identical to the official distribution from its source (and also from the
sources of earlier fasm versions), using only fasm sources (both old and
recent versions), but no precompiled executable programs of earlier
fasm versions.

pts-fasm-bootstrap was inspired by the fasm forum threads [bootstrapping
FASM, by rugxulo,
2018-02-20](https://board.flatassembler.net/topic.php?t=20431) and [The real
way to bootstrap fasm with no prior binary, started by
revolution](https://board.flatassembler.net/topic.php?p=227624). The second
thread goas back as far as fasm 1.0 (released on 2000-06-19) and does the
whole bootstrapping on 32-bit DOS (i.e. with 80386 CPU or later).
pts-fasm-bootstrap does the bootstrapping on Linux x86 (i386 or amd64),
building ELF-32 executable programs for Linux i386, and it starts at version
1.20 (released on 2001-11-17). (In a future work, going back to 1.0 is
possible.)

How to run the bootstrap:

* On a Linux x86 system (i386 or amd64), check out the Git repository, and
  run `perl -x bootstrap1.pl`. The output file is *fasm1*.

* Then run `perl -x bootstrap2.pl'. The output file is `fasm-re-1.73.32`,
  which is identical to the file `fasm-golden-1.73.32`, also identical to
  the program file in the [official fasm-1.73.32
  package](https://flatassembler.net/fasm-1.73.32.tgz)
  (released on 2023-12-04).

* The output file is executable on a Linux x86 system (i386 or amd64), and
  it's statically linked (i.e. independent of the Linux distribution and the
  libc).

## The bootstrap chain

There are two steps:

1. ([bootstrap1.pl](bootstrap1.pl))
   Build an old (1.20 or 1.37) fasm executable program from its source by
   converting the old fasm source to [NASM](https://nasm.us/) syntax with a
   few dozen Perl regexp substitutions, and compiling the result with NASM.
   The output executable program file is *fasm1*, it's called the bootstrap
   assembler.

2. ([bootstrap2.pl](bootstrap2.pl) or [bootstrap2.sh](bootstrap1.sh))
   With the bootstrap assembler executable program built in step 1, compile
   a patched version of a recent fasm (1.73.32). Then with that executable
   program, recompile the recent fasm from its unpatched source.

Step 1 is possible because the source of old fasm is similar enough to NASM
syntax so that it can be converted to NASM syntax using a few dozen regexp
substitutions. NASM syntax and features have also changed over time, but
only a backward-compatible subset of it is used here, and thus anything
between NASM 0.95 (released on 1997-07-27) and 2.16.03 (released on
2024-04-17) works.

Currently the fasm sources of version 1.20 (released on 2001-11-17) and 1.37
(released on 2002-06-12) are supported in step 1. fasm 1.37 was the first
version supporting Linux i386 hosts (i.e. the `SOURCE/LINUX` directory). For
fasm 1.20, bootstrap1.pl contains about 450 lines of assembly code
containing Linux i386 host support.

Step 2 is possible becase the source of a recent fasm is still so simple
that it can be compiled with new, old and even ancient fasm versions, after
applying a few simple patches. These patches are:

* The *format elf executable 3*, *entry ...* and *segment ..* directives
  used for ELF-32 executable generation are replaced with manual building of
  the ELF-32 header files with *db*, *dw* and *dd* directives.
* The *salc* and *pushd* instructions and the *align* directive missing
  from old fasm are polyfilled using simple macros.

To make it easy to reproduce, the Perl scripts bootstrap1.pl and
bootstrap2.pl were written so that they work with old and new versions of
Perl running on Linux i386 or Linux amd64. In particular, they work with
Perl as old as 5.004_04 (released on 1997-10-15). Thus this way it is
possible to bootstrap a recent fasm using only technology available on
2001-11-17 (Linux i386, Perl >=5.004_04, *unzip*, NASM >=0.95 and fasm 1.20
sources).

Alternatively, shell script bootstrap2.sh can be used instead of
bootstrap2.pl, without depending on Perl for this step, but depending on
some Unix commands (such as *cat* and *tr*) instead. There is no alternative
shell script replacing bootstrap1.pl, beucase *grep* and AWK wouldn't be
powerful enough for the regexp substitutions applied there when converting
from fasm to NASM syntax. (Python, Ruby, Java, Go, PHP PCRE, Pike PCRE, TCL,
C PCRE and C++ RE2 would be powerful enough, but on systems where these are
easily available, Perl is also easy to install, or installed by default.)

The following source files are used:

* *fasm.fasm* is generated by bootstrap1.pl by concatenating the old fasm
  source to a single file and applying patches (using a few Perl regexp
  substitutions).
* *fasm.nasm* is generated by bootstrap1.pl by converting *fasm.fasm* to NASM
  syntax (using a few dozen Perl regexp substitutions).
* *fasm3.fasm* is generated by bootstrap2.pl or bootstrap2.sh by concatenating
  the recent fasm source to a single file and applying patches (a few simple
  substitutions affecting a few lines).
* *fasm4.fasm* is generated by bootstrap2.pl by concatenating the recent fasm
  source to a single file, without applying any patches.

The detailed bootstrap chain:

* *fasm.nasm* is compiled by NASM to Linux i386 ELF-32 executable program
  *fasm0*.
* *fasm.fasm* is compiled by *fasm0* to *fasm1*.
* *fasm0* and *fasm1* are not compared to each other, because even though
  they implement the same functionality, they are not exepected to be
  bitwise identical, because of i386 instruction encoding differences and
  optimization differenes between NASM (the generator of *fasm0*) and fasm
  (the generator of *fasm1*).
* *fasm.fasm* is compiled by *fasm1* to *fasm2*.
* *fasm1* and *fasm2* are compared to each other (they must be bitwise
  identical), *fasm1* is the output of step 1.
* *fasm3.nasm* is compiled by *fasm1* to *fasm4*.
* *fasm4.nasm* is compiled by *fasm4* to *fasm5*.
* *fasm4.nasm* is compiled by *fasm5* to *fasm6*.
* *fasm5* and *fasm6* are compared to each other (they must be bitwise
  identical), *fasm5* is the output of step 2, and also the final output.
* *fasm6* is compared to the *fasm/fasm* Linux i386 ELF-32 executable
  program in the offical fasm release (they must be bitwise identical).

Alternatively, step 1 can be replaced by obtaining a fasm-compatible
assembler (and using it in step 2). For example, *fbsasm* (see below)
works, and it can be used by running step 2 as `perl -x bootstrap2.pl
--fasm=./fbsasm`. fasm executable programs (old and new) in the official
binary release of fasm also work.

All scripts in both steps (bootstrap1.pl, bootstrap2.pl, bootstrap2.sh) work
on Debian as early as Debian 2.1 slink (released on 1999-03-09), which has
NASM 0.96, Perl 5.004_04 and *unzip* 5.32 (part of the non-free free). With
all these dependencies in place, fasm 1.20 (released on 2001-11-17) could
have been bootstrapped this way at the time it was written.

It would be a challenge to bootstrap a recent fasm using Perl >=5.004_04
only. This would require implementing *unzip* and *zcat* and writing a
specialized i386 assembler (supporting the subset of fasm syntax used in
recent fasm) in pure Perl 5.004_04. All of these are hard but doable. They
are left as an exercise to the reader.

## History of fasm

This section is partially based on the [fasm page on the Dr-DOS
Wiki](https://pmwiki.xaver.me/drdoswiki/index.php?n=Main.DevelAsm#toc12).

fasm has been written by Tomasz Grysztar, with version 1.0 as the first
public release. The first few releases are:

* 2000-06-19: public release 1.0
* 2000-07-01: public release 1.01
* 2000-07-06: public release 1.02
* 2000-07-19: public release 1.03

These first few versions above (and a few more) ran on DOS (as *fasm.com*)
only, requiring a 80386 CPU or later in an unusual 32-bit protected mode
called *unreal mode*. DOSBox doesn't support unreal mode, but FREEDOS
running in QEMU does. Win32 and Linux i386 host support was added later:

* 2000-08-10: public release 1.04 introduced *format PE console*, i.e. Win32 PE console applicaton output support
* 2002-06-12: public release 1.37 added Linux i386 host and Win32 host support, i.e. it could be compiled from source to these systems
* 2002-11-14: public release 1.41 had *fasm* (Linux i386 executable program) precompiled (maybe earlier releases also had it)
* 2003-01-08: public release 1.43 introduced *format ELF executable* and already used it in *source/Linux/fasm.asm*
* 2003-10-14: public release 1.49 had *fasm.exe* precompiled for Win32 (maybe earlier releases also had it)

Source code has always been part of fasm, with a BSD-like open source
license, and it has been easy and deterministic since version 0.90 to
recompile fasm from its source (using the executable program of the same
version), which was also written in *fasm* syntax. For example, this is how
to recompile the latest fasm on Linux x86 for DOS, Win32 and Linux i386:

```
$ rm -rf fasm
$ wget -O fasm-1.73.32.tgz https://flatassembler.net/fasm-1.73.32.tgz
$ tar xzvf fasm-1.73.32.tgz
$ cd fasm
$ cd source/Linux && ../../fasm fasm.asm ../../fasm2
flat assembler  version 1.73.32  (16384 kilobytes memory)
5 passes, 107115 bytes.
$ chmod +x fasm2 && cmp fasm fasm2 && echo OK
OK
$ (cd source/DOS && ../../fasm fasm.asm ../../fasmd2.exe)
flat assembler  version 1.73.32  (16384 kilobytes memory)
5 passes, 108118 bytes.
$ (cd source/Win32 && ../../fasm fasm.asm ../../fasm2.exe)
flat assembler  version 1.73.32  (16384 kilobytes memory)
5 passes, 117248 bytes.
```
The source of *fasmw.exe* is included in the
https://flatassembler.net/fasmw17332.zip download instead, in the directory
`SOURCE/IDE`.

Predecessors of public fasm, also by Tomasz Grysztar:

* ASM32: An assembler with 32-bit i386 instruction output and raw binary output
  format. It was unpublished, not the same as [ASM32 by Intelligent
  Firmware](https://www.intelligentfirm.com/cpl32.html)). It was written in
  assembly language, TASM syntax. Its source and executable program files
  have been lost.
* MDAT was special a variant of ASM32, with only data and binary file
  inclusion directives. Its DOS program file (*mdat.exe*, for 32-bit DOS,
  Adam file format with DOS stub looking for *dos32.exe* does extender) and
  source (assembly language, ASM32 syntax) has survived, it's part of
  [glumpy.zip](https://board.flatassembler.net/download.php?id=2142), more
  info in [this forum
  thread](https://board.flatassembler.net/topic.php?t=4919).
* Early versions of fasm were written in assembly language, ASM32 syntax.
  These sources have been lost.
* Later, but still pre-release versions of fasm have already been written in
  assembly language, fasm syntax, for 32-bit DOS i386 host, and and they
  could compile themselves. However, these programs needed the HDOS DOS
  extender (also by Tomasz Grysztar), also written in assembly language,
  fasm syntax. Two pre-release version have survived: 0.90 and 1.00.
* 1999-05-04: unreleased version 0.90 (see
  [source](https://github.com/tgrysztar/fasm/commit/61a1789231e7391a7cff2d6c368fcf251ef3c13e)
  and [precompiled program in
  hdos2.zip](https://board.flatassembler.net/download.php?id=5735), part of
  HDOS 2.03), more info in [this forum
  thread](https://board.flatassembler.net/topic.php?t=13794)
* 1999-07-01: unreleased version 1.00 (see
  [source](https://github.com/tgrysztar/fasm/commit/613ec371a5b5c5142ae4213d5209e75bb41e524c)
  and [precompiled program in
  hdos3.zip](https://board.flatassembler.net/download.php?id=5734), part of
  HDOS 3.01), more info in [this forum
  thread](https://board.flatassembler.net/topic.php?t=13794)

## Alternative bootstrap assemblers

In step 1, bootstrap1.pl builds the bootstram assembler *fasm1*, which (in
step 2) is able to compile a patched recent fasm (1.73.32). However, it's
possible to replace the specific bootstrap assembler built by bootstrap1.pl
(thus also step 1) with alternatives, which are able to do the same in step
2. This section describes the alternative bootstrap assemblers.

A motivation for alternative bootstrap assemblers is removing the hard
dependency on NASM for bootstrapping fasm, and by that providing the user
options for their convenience. Another motivation is exploring the history
of assemblers targeting the i386 (released between 1985 and 2024), studying
their features and differences, and checking which kind of bootstraps would
have worked already in 2001. (bootstrap1.pl with NASM >=0.95 would have
definitely worked, you can try it on Debian slink (released on 1999-03-03)
or later.)

More specifically, the bootstrap assembler:

* has to run on Linux i386 host systems (and possibly others as well)
* has to be able to compile a patched recent fasm (1.73.32) for Linux i386
* alternatively, has to be able to compile a patched fasm 1.20 for Linux
  i386 (in case compiling fasm 1.73.32 turns out to be too complicated),
  and then that fasm 1.20 would be used as a bootstrap assembler
* can support only a subset of the i386 instructions and fasm directives,
  i.e. those used by the patched recent fasm
* can be a non-optimizing assembler (i.e. producing longer machine code than
  necessary)
* can be slower than an assembler in everyday use

Any working version of fasm works as a bootstrap assembler, but using that
would defeat the original purpose (i.e. compiling fasm without using a fasm
executable program).

Please note, however, that the precompiled executable
programs of most old versions of fasm (i.e. <=1.56)
have a bug on modern Linux x86 systems: they detect the available
memory incorrectly, and they allocate too little. (2.5 MiB would have been
enough for compiling fasm <=1.73.32). The error message looks like:

```
$ ../../fasm fasm.asm fasm9
flat assembler  version 1.56
error: out of memory.
```

This bug has been fixed in fasm 1.58. Earlier versions need a patch (search
for `allocate_memory:)` in [bootstrap1.pl](bootstrap1.pl) for the patch).
The fasm-golden-1.56 and earlier files in the pts-fasm-bootstrap repository
are already patched. fasm-folden-1.58 and later are the original program
files in the binary release of fasm, they work without a patch.

It has been verified for the following fasm versions that the *fasm* Linux
i386 executable program in the binary release can compile itself from source
(`source/Linux/fasm.asm`), and the output is bitwise identical to the
executable program file in the binary release: 1.37, 1.43, 1.56, 1.58, 1.60,
1.62, 1.64, 1.66, 1.67.22, 1.67.27, 1.68, 1.70, 1.70.01, 1.70.02, 1.73.32.

To use fasm as the bootstrap assembler, run something like this: `perl -x
bootstrap2.pl --fasm=./fasm-golden-1.73.32` .

As part of the pts-fasm-bootstrap project, an alternative bootstrap
assembler named *fbsasm* has been developed and released as free software
including source code. It runs on Linux i386 (and amd64) host systems. It is
based on the fasm 1.30 source code (with some cosmetic changes, removal of
some CPU instructions, removal of `format MZ`, removal of `format PE`), with
the Linux-specific I/O parts copied from the fasm 1.37 source code instead
(because that's when Linux host support was added to fasm). Its source code
has been converted from fasm syntax to >15 other assembler syntaxes,
including NASM and GNU as(1).

*fbsasm* was written with the goal of compiling as many of fasm 1.20, 1.30
and 1.37 as easily possible. All of these source versions worked with a few
lines of patches applied (to all 3) and several hundred lines of Linux i386
host support code added to fasm 1.20 and 1.30 (based on
`source/Linux/fasm.asm` and ``source/Linux/system.inc` in fasm 1.37). Then
it was discovered that *fbsasm* is able to compile the latest fasm (1.73.32)
as well, with about a few lines of patches implementing ELF-32 header
generation using hardcoded *db*, *dw* and *dd* directives. By simply
applying the same techniques again, it would be possible to make *fbsasm*
compile any version of fasm between 1.20 and 1.73.32, for Linux i386 host.
With a bit more of similar effort, all versions between 1.0 (released on
2000-06-19) and 1.20 could be ported to Linux i386 host (i.e. sevaral
hundred lines of support code added) and compiled with
*fbsasm*.

Historically, *fbsasm* can be compiled not only with recent and up-to-date
assemblers, but also with the oldest i386 assembers ever: MASM 5.00
(released on 1987-07-31) and the SVR3 assembler (released on 1987-10-28).
However, Linux i386 wasn't available as a host operating system at that time
to run *fbsasm*. Linux 1.0 was released in 1994, and *fbsasm* runs on it, it
can be tried using the [MCC
1.0](https://www.ibiblio.org/pub/historic-linux/distributions/MCC-1.0/1.0/)
Linux distribution (released on 1994-05-11, running Linux kernel 1.0.4).

## Existing fbsasm implementations in various assembly languages

* The implementation for the oldest assembler is [fbsasm.mas](fbsasm.mas),
  which works with MASM 5.00 (1987-07-31). The second oldest one is the SVR3
  assembler (1987-10-28), the fbsasm implementation is in
  [fbsasms.s](fbsasm.s). The oldest assembler which is also free software is
  as86 0.0.0 (1991-11-29), the fbsasm implmenetation is in
  [fbsasm0.as86](fbsasm0.as86). See all details below.
* NASM: already implemented as `fbsasm.nasm`, use it with
  `./compile_fbsasm.sh nasm`. It is a reimplementation of a subset of fasm
  1.30 (for Linux i386) in NASM 0.95 (1997-07-27) or later. It has been
  tested with 0.98.39 extensively. It was created by
  concatenating source files from fasm 1.30 and fasm 1.37 (Linux-specific
  `fasm.asm` and `system.inc`), and manually converting it to NASM syntax
  (mostly doing some manual changes and then many regexp substitutions).
* Yasm: already implemented as `fbsasm.nasm`, use it with
  `./compile_fbsasm.sh nasm=yasm`. The NASM source works without changes.
  Versions 1.2.0 (2011-10-31) and 1.3.0 (2014-09-11) are known to work.
  Maybe older versions work as well.
* fasm: already implemented as `fbsasm.fasm`, use it with
  `./compile_fbsasm.sh fasm`. It needs at least fasm 1.20 (2001-11-17)
  to compile.
* GNU as(1) (+ GNU ld(1)): already implemented as `fbsasm.s`, use it with
  `./compile_fbsasm.sh as`. It is autogenerated by `fbsasm.nasm` using the
  bundled `nasm2as.pl` Perl script. It works with various versions of GNU
  Binutils, tested with 2.7 (released on 1996-07-15), 2.9.1 (released on
  1998-05-01, part of Debian 2.1 slink), 2.9.5, 2.22 and 2.30.
* TASM (Turbo Assembler) + folink2 (custom linker): already implemented as
  `fbsasm.tas` (TASM ideal mode),
  use it with `./compile_fbsasm.sh tasm`. It works with TASM
  1.01 (1989), 2.0 (1990), 4.1 (1996, the latest Turbo Assembler which works
  on a DOS 8086 without a DOS extender) and 5.3 (2000-01-30, probably the
  last release of TASM). The custom linker folink2 is also included and is
  built from source by TASM.
* LZASM (Lazy Assembler) + folink2 (custom linker): already implemented as
  `fbsasm.tas` (TASM ideal mode),
  use it with `./compile_fbsasm.sh lzasm`. It works with LZASM
  0.56 (2007-10-04, last release) and possibly earlier. The custom linker
  folink2 is also included and is built from source by LZASM.
* MASM (Microsoft Macro Assembler) + WLINK: already implemented as
  `fbsasm.was`, currently `compile_fbsasm.sh` doesn't support it. It works
  with MASM 5.00 (1987-07-31) or later, TASM 3.0 (1991-11-11) or later, WASM
  10.5 (1995-07-11) or later, JWasm 2.11a (2013-10-19) and maybe earlier,
  ASMC 2.34.49 (2024-030-26) and later and maybe earlier.
* as86 (part of dev86): already implemented as `fbsasm.as86` (for as86
  >=0.0.7, 1996-09-03) and as `fbsasm0.as86` (for as86 0.0.0 .. 0.0.8), use
  it with `./compile_fbsasm.sh as86`. It works with with the earliest as86
  found in archives: as86
  [0.0.0](https://mirror.math.princeton.edu/pub/oldlinux/Linux.old/bin/as86.src.tar.Z)
  (1991-11-29). This is the first free software assembler targeting the
  i386.
* A386 (by Eric Isaacson): already implemented
  as `fbsasm.8`, use it with `./compile_fbsasm.sh a386`. It works with the
  A386 4.05 (2000-01-13) on a DOS 8086 (maybe needs an i386 processor).
* [vasm](http://sun.hasenbraten.de/vasm/) (by Volker Barthelmann): already
  implemented as `fbsasm.vasm`, use it with `./compile_fbsasm.sh vasm`. It
  works with vasm 1.9a (2022-10-02) and possibly earlier.
* [mw386as](https://github.com/pts/mw386as)
  (port of the Mark Williams 80386 assembler, originally 1993-08-02, part of
  Coherent) + link3coff.pl (custom linker),
  use it with `./compile_fbsasm.sh mw`. It works with the
  1993-08-02 version rebuilt from source, but the code generated by 1992-11-11
  version seems to be broken. The custom linker is also included, and it's a
  Perl script. A Linux i386 executable of the Perl interpreter is also
  included.
* The AT&T Unix System V Release 3 (SVR3) assembler (see [Linux i386
  port](https://github.com/pts/pts-svr3as-linux)) + link3coff.pl (custom
  linker), use it with `./compile_fbsasm.sh --svr3=...`. All 3 versions
  (1987-10-28, 1988-05-27, 1989-10-03) work. The custom linker is also
  included, and it's a Perl script. A Linux i386 executable of the Perl
  interpreter is also included.
* The SunOS 4.0.1 assembler (see [Linux i386
  port](https://github.com/pts/pts-svr3as-linux)) + link3coff.pl (custom
  linker), use it with `./compile_fbsasm.sh --svr3=...`. The version
  released on 1988-11-16 works. The custom linker is also
  included, and it's a Perl script. A Linux i386 executable of the Perl
  interpreter is also included.
* The AT&T Unix System V Release 4 (SVR4) assembler, built from source
  (released on 1993-01-16)
  port](https://github.com/pts/pts-svr3as-linux)) + GNU ld(1), use it with
  `./compile_fbsasm.sh --svr4=...`. This assembler has more code generation
  bugs than its predecessor, the SVR3 assembler. These bugs have been worked
  around for the purposes of pts-fasm-bootstrap.

# Future plans for fbsasm implementations

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
  fbsasm.fasm. Maybe later it will be able to compile fasm 1.73.32 and
  fbsasm.nasm.
* [Solaris x86
  Assembler](https://docs.oracle.com/cd/E19120-01/open.solaris/817-5477/eqbui/index.html),
  part of OpenSolaris.
* POASM from Pelle's C.
* [HLA](https://en.wikipedia.org/wiki/High_Level_Assembly) with its built-in
  linker.
* [GoAsm.exe](http://www.godevtool.com/) + GoLink.exe.
* [ASM32](https://www.intelligentfirm.com/cpl32.html):
  it supports flat .bin output in use32 mode.
* [XAssembler](https://web.archive.org/web/20070823101949/http://xasm.webpark.pl:80/xasm/en_download.htm).
