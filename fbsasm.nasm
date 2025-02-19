; by pts@fazekas.hu at Thu Mar 21 07:44:40 CET 2024
;
; Minimum NASM version required to compile: NASM 0.95 (1997-07-27). The
; nasm.exe bundled with NASM 0.95 (nasm095s.zip) precompiled for DOS 8086
; also works.
;
; This is a subset of the source code of fasm 1.30 (with some CPU instructions,
; `format MZ' and `format PE' removed), ported to NASM syntax, for Linux i386
; only. It's useful for bootstrapping fasm.
;
; Compile with: nasm-0.98.39 -O0 -w+orphan-labels -f bin -o fbsasm fbsasm.asm && chmod +x fbsasm  # Fast.
; Compile with: nasm-0.98.39 -O1 -Dnear_o0= -w+orphan-labels -f bin -o fbsasm fbsasm.asm && chmod +x fbsasm
; Compile with: nasm-0.98.39 -O999999999 -Dnear_o0= -w+orphan-labels -f bin -o fbsasm fbsasm.asm && chmod +x fbsasm
;
; Compile the GNU as(1) version (fbsasm.s) with: as --32 -march=i386 -o fbsasm.o fbsasm && ld -m elf_i386 -N -s -o fbsasm fbsasm.o
; Compile the GNU as(1) version (fbsasm.s) with earlier versions of GNU as(1) with: as -o fbsasm.o fbsasm && ld -m elf_i386 -N -s -o fbsasm fbsasm.o
;
; Lines in fbsasm.nasm and fbsasm.fasm correspond to each other.
;







; flat assembler 0.37 source, fasm.asm
; Copyright (c) 1999-2002, Tomasz Grysztar
; All rights reserved.

%define program_base 0x700000  ; NASM 0.95 doesn't support `program_base equ 0x700000' with `org program_base'.

%ifndef near_o0
%define near_o0 near  ; For `nasm -O0'.
%endif

	org	program_base
	bits 32  ; NASM 0.97 supports this but ignores `use32'.
	;cpu 386  ; True but NASM 0.97 doesn't support it.

;	macro	align value { rb (value-1) - ($ + value-1) mod value }

file_header:
	db	0x7F,'ELF',1,1,1
	times	file_header+0x10-$ db 0
	dw	2,3
	dd	1,start
	dd	program_header-file_header,0,0
	dw	program_header-file_header,0x20,1,0x28,0,0

program_header:
	dd	1,0,program_base,0
	dd	prebss-file_header,program_end-bss+prebss-file_header,7,0x1000

start:

	mov	esi,_logo
	call	display_string

	pop	eax
	cmp	eax,3
	jne near_o0 information
	pop	eax
	pop	dword [input_file]
	pop	dword [output_file]

	call	init_memory

	mov	edi,characters
	mov	ecx,100h
	xor	al,al
      make_characters_table:
	stosb
	inc	al
	loop	make_characters_table
	mov	esi,characters+'a'
	mov	edi,characters+'A'
	mov	ecx,26
	rep	movsb
	mov	edi,characters
	mov	esi,symbol_characters+1
	movzx	ecx,byte [esi-1]
	xor	ebx,ebx
      convert_table:
	lodsb
	mov	bl,al
	mov	byte [edi+ebx],0
	loop	convert_table

	push	eax
	push	eax  ; alloca(8) for the gettimeofday buffer.
	mov	eax,78  ; SYS_gettimeofday.
	mov	ebx,esp
	xor	ecx,ecx
	int	0x80
	mov	eax,dword [esp]
	mov	ecx,1000
	mul	ecx
	mov	ebx,eax
	mov	eax,dword [esp+4]
	div	ecx
	pop	ecx
	pop	ecx  ; Free the gettimeofday buffer.
	add	eax,ebx
	mov	dword [start_time],eax

	call	preprocessor
	call	parser
	call	assembler

	movzx	eax,byte [current_pass]
	inc	al
	call	display_number
	mov	esi,_passes_suffix
	call	display_string
	push	eax
	push	eax  ; alloca(8) for the gettimeofday buffer.
	mov	eax,78  ; SYS_gettimeofday.
	mov	ebx,esp
	xor	ecx,ecx
	int	0x80
	mov	eax,dword [esp]
	mov	ecx,1000
	mul	ecx
	mov	ebx,eax
	mov	eax,dword [esp+4]
	div	ecx
	pop	ecx
	pop	ecx  ; Free the gettimeofday buffer.
	add	eax,ebx
	sub	eax,dword [start_time]
	jnc	time_ok
	add	eax,3600000
      time_ok:
	xor	edx,edx
	mov	ebx,100
	div	ebx
	or	eax,eax
	jz	display_bytes_count
	xor	edx,edx
	mov	ebx,10
	div	ebx
	push	edx
	call	display_number
	mov	dl,'.'
	call	display_character
	pop	eax
	call	display_number
	mov	esi,_seconds_suffix
	call	display_string
      display_bytes_count:
	mov	eax,dword [written_size]
	call	display_number
	mov	esi,_bytes_suffix
	call	display_string
	xor	al,al
	jmp	exit_program

information:
	mov	esi,_usage
	call	display_string
	mov	al,1
	jmp	exit_program

;%include 'system.inc'

; flat assembler 0.37 source, system.inc
; Copyright (c) 1999-2002, Tomasz Grysztar
; All rights reserved.

O_ACCMODE  equ 00003q
O_RDONLY   equ 00000q
O_WRONLY   equ 00001q
O_RDWR	   equ 00002q
O_CREAT    equ 00100q
O_EXCL	   equ 00200q
O_NOCTTY   equ 00400q
O_TRUNC    equ 01000q
O_APPEND   equ 02000q
O_NONBLOCK equ 04000q

S_ISUID    equ 04000q
S_ISGID    equ 02000q
S_ISVTX    equ 01000q
S_IRUSR    equ 00400q
S_IWUSR    equ 00200q
S_IXUSR    equ 00100q
S_IRGRP    equ 00040q
S_IWGRP    equ 00020q
S_IXGRP    equ 00010q
S_IROTH    equ 00004q
S_IWOTH    equ 00002q
S_IXOTH    equ 00001q

init_memory:
	xor	ebx,ebx
	mov	eax,45  ; SYS_brk.
	int	0x80
	mov	dword [additional_memory],eax
	;mov	ebx,syscall_buffer
	;mov	eax,116  ; SYS_sysinfo. We are interested only the sysinfo.freeram field ([syscall_buffer+14h]), but on modern Linux it's not bytes anymore (see mem_unit in sysinfo(2)), so it's meaningless below.
	;int	0x80
	;mov dword [available_memory],0x100000  ; Hardcode allocating maximum 1 MiB. 1 MiB enough, but 0.75 MiB is not enough to compile fasm 1.30.
	mov dword [available_memory],0x280000  ; Hardcode allocating maximum 2.5 MiB. 1 MiB enough, but 0.75 MiB is not enough to compile fasm 1.30. 2.5 MiB is enough to compile fasm 1.73.32.
    allocate_memory:
	mov	ebx,dword [additional_memory]
	add	ebx,dword [available_memory]
	mov	eax,45  ; SYS_brk.
	int	0x80
	mov	dword [memory_end],eax
	sub	eax,dword [additional_memory]
	jz	not_enough_memory
	shr	eax,3
	add	eax,dword [additional_memory]
	mov	dword [additional_memory_end],eax
	mov	dword [memory_start],eax
	ret
    not_enough_memory:
	shr	dword [available_memory],1
	cmp	dword [available_memory],4000h
	jb near_o0 out_of_memory
	jmp	allocate_memory

exit_program:
	movzx	ebx,al
	mov	eax,1  ; SYS_exit.
	int	0x80

open:
	push	edx
	push	esi
	push	edi
	push	ebp
	mov	ebx,edx
	mov	eax,5  ; SYS_open.
	mov	ecx,O_RDONLY
	xor	edx,edx
	int	0x80
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	test	eax,eax
	js	file_error
	mov	ebx,eax
	clc
	ret
    file_error:
	stc
	ret
create:
	push	edx
	push	esi
	push	edi
	push	ebp
	mov	ebx,edx
	mov	eax,5  ; SYS_open.
	mov	ecx,O_CREAT+O_TRUNC+O_WRONLY
	mov	edx,S_IRUSR+S_IWUSR+S_IRGRP
	int	0x80
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	test	eax,eax
	js	file_error
	mov	ebx,eax
	clc
	ret
close:
	mov	eax,6  ; SYS_close.
	int	0x80
	ret
read:
	push	ecx
	push	edx
	push	esi
	push	edi
	push	ebp
	mov	eax,3  ; SYS_read.
	xchg	ecx,edx
	int	0x80
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	test	eax,eax
	js	file_error
	cmp	eax,ecx
	jne	file_error
	clc
	ret
write:
	push	edx
	push	esi
	push	edi
	push	ebp
	mov	eax,4  ; SYS_write.
	xchg	ecx,edx
	int	0x80
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	test	eax,eax
	js	file_error
	clc
	ret
lseek:
	mov	ecx,edx
	xor	edx,edx
	mov	dl,al
	mov	eax,19  ; SYS_lseek.
	int	0x80
	clc
	ret

display_string:
	push	ebx
	mov	edi,esi
	mov	edx,esi
	or	ecx,-1
	xor	al,al
	repne	scasb
	neg	ecx
	sub	ecx,2
	mov	eax,4  ; SYS_write.
	mov	ebx,1
	xchg	ecx,edx
	int	0x80
	pop	ebx
	ret
display_block:
	push	ebx
	mov	eax,4  ; SYS_write.
	mov	ebx,1
	mov	edx,ecx
	mov	ecx,esi
	int	0x80
	pop	ebx
	ret
display_character:
	push	ebx
	mov	[character],dl
	mov	eax,4  ; SYS_write.
	mov	ebx,1
	mov	ecx,character
	mov	edx,ebx
	int	0x80
	pop	ebx
	ret
display_number:
	push	ebx
	mov	ecx,1000000000
	xor	edx,edx
	xor	bl,bl
      display_loop:
	div	ecx
	push	edx
	cmp	ecx,1
	je	display_digit
	or	bl,bl
	jnz	display_digit
	or	al,al
	jz	digit_ok
	not	bl
      display_digit:
	mov	dl,al
	add	dl,30h
	push	ebx
	push	ecx
	call	display_character
	pop	ecx
	pop	ebx
      digit_ok:
	mov	eax,ecx
	xor	edx,edx
	mov	ecx,10
	div	ecx
	mov	ecx,eax
	pop	eax
	or	ecx,ecx
	jnz	display_loop
	pop	ebx
	ret

fatal_error:
	mov	esi,error_prefix
	call	display_string
	pop	esi
	call	display_string
	mov	esi,error_suffix
	call	display_string
	mov	al,0FFh
	jmp	exit_program
assembler_error:
	call	flush_display_buffer
	mov	ebx,dword [current_line]
      find_error_home:
	test	byte [ebx+7],80h
	jz	error_home_ok
	mov	ebx,[ebx+8]
	jmp	find_error_home
      error_home_ok:
	mov	esi,[ebx]
	call	display_string
	mov	esi,line_number_start
	call	display_string
	mov	eax,[ebx+4]
	call	display_number
	mov	dl,']'
	call	display_character
	cmp	ebx,dword [current_line]
	je	line_number_ok
	mov	dl,20h
	call	display_character
	mov	esi,dword [current_line]
	mov	esi,[esi]
	movzx	ecx,byte [esi]
	inc	esi
	call	display_block
	mov	esi,line_number_start
	call	display_string
	mov	esi,dword [current_line]
	mov	eax,[esi+4]
	and	eax,7FFFFFFFh
	call	display_number
	mov	dl,']'
	call	display_character
      line_number_ok:
	mov	esi,line_data_start
	call	display_string
	mov	esi,ebx
	mov	edx,[esi]
	call	open
	mov	al,2
	xor	edx,edx
	call	lseek
	mov	edx,[esi+8]
	sub	eax,edx
	push	eax
	xor	al,al
	call	lseek
	mov	ecx,[esp]
	mov	edx,dword [memory_start]
	call	read
	call	close
	pop	ecx
	mov	esi,dword [memory_start]
      get_line_data:
	mov	al,[esi]
	cmp	al,0Ah
	je	display_line_data
	cmp	al,0Dh
	je	display_line_data
	cmp	al,1Ah
	je	display_line_data
	or	al,al
	jz	display_line_data
	inc	esi
	loop	get_line_data
      display_line_data:
	mov	ecx,esi
	mov	esi,dword [memory_start]
	sub	ecx,esi
	call	display_block
	mov	esi,lf
	call	display_string
	mov	esi,error_prefix
	call	display_string
	pop	esi
	call	display_string
	mov	esi,error_suffix
	call	display_string
	jmp	exit_program

character db 0,0

error_prefix db 'error: ',0
error_suffix db '.'
lf db 0xA,0
line_number_start db ' [',0
line_data_start db ':',0xA,0

%macro dm 1
  db %1, 0
%endm

;%include '../version.inc'

; flat assembler  version 1.30
; Copyright (c) 1999-2002, Tomasz Grysztar
; All rights reserved.
;
; This programs is free for commercial and non-commercial use as long as
; the following conditions are aheared to.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are
; met:
;
; 1. Redistributions of source code must retain the above copyright notice,
;    this list of conditions and the following disclaimer.
; 2. Redistributions in binary form must reproduce the above copyright
;    notice, this list of conditions and the following disclaimer in the
;    documentation and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
; TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
; PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
; PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
; PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
; LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
; The licence and distribution terms for any publically available
; version or derivative of this code cannot be changed. i.e. this code
; cannot simply be copied and put under another distribution licence
; (including the GNU Public Licence).

%define VERSION_STRING '1.30-bootstrap'



VERSION_MAJOR equ 1
VERSION_MINOR equ 30

;%include '../errors.inc'

; flat assembler source
; Copyright (c) 1999-2001, Tomasz Grysztar
; All rights reserved.

out_of_memory:
	call	fatal_error
	dm	"out of memory"
main_file_not_found:
	call	fatal_error
	dm	"source file not found"
write_failed:
	call	fatal_error
	dm	"write failed"
code_cannot_be_generated:
	call	fatal_error
	dm	"code cannot be generated"
unexpected_end_of_file:
	call	fatal_error
	dm	"unexpected end of file"
file_not_found:
	call	assembler_error
	dm	"file not found"
error_reading_file:
	call	assembler_error
	dm	"error reading file"
invalid_macro_arguments:
	call	assembler_error
	dm	"invalid macro arguments"
unexpected_characters:
	call	assembler_error
	dm	"unexpected characters"
invalid_argument:
	call	assembler_error
	dm	"invalid argument"
illegal_instruction:
	call	assembler_error
	dm	"illegal instruction"
unexpected_instruction:
	call	assembler_error
	dm	"unexpected instruction"
invalid_operand:
	call	assembler_error
	dm	"invalid operand"
invalid_operand_size:
	call	assembler_error
	dm	"invalid size of operand"
operand_size_not_specified:
	call	assembler_error
	dm	"operand size not specified"
operand_sizes_do_not_match:
	call	assembler_error
	dm	"operand sizes do not match"
invalid_address_size:
	call	assembler_error
	dm	"invalid size of address value"
address_sizes_do_not_agree:
	call	assembler_error
	dm	"address sizes do not agree"
invalid_expression:
	call	assembler_error
	dm	"invalid expression"
invalid_address:
	call	assembler_error
	dm	"invalid address"
invalid_value:
	call	assembler_error
	dm	"invalid value"
value_out_of_range:
	call	assembler_error
	dm	"value out of range"
invalid_use_of_symbol:
	call	assembler_error
	dm	"invalid use of symbol"
relative_jump_out_of_range:
	call	assembler_error
	dm	"relative jump out of range"
extra_characters_on_line:
	call	assembler_error
	dm	"extra characters on line"
name_too_long:
	call	assembler_error
	dm	"name too long"
invalid_name:
	call	assembler_error
	dm	"invalid name"
reserved_word_used_as_symbol:
	call	assembler_error
	dm	"reserved word used as symbol"
symbol_already_defined:
	call	assembler_error
	dm	"symbol already defined"
missing_end_quote:
	call	assembler_error
	dm	"missing end quote"

;%include '../expressi.inc'

; flat assembler source
; Copyright (c) 1999-2001, Tomasz Grysztar
; All rights reserved.

convert_expression:
	push	ebp
	mov	ebp,esp
	push	edi
	mov	edi,operators
	call	get_operator
	pop	edi
	or	al,al
	jz	expression_loop
	push	ebp
	cmp	al,80h
	je	init_positive
	cmp	al,81h
	je	init_negative
	jmp	invalid_expression
      init_positive:
	xor	al,al
	jmp	expression_number
      init_negative:
	mov	al,0D1h
	jmp	expression_number
      expression_loop:
	push	ebp
	push	edi
	mov	edi,single_operand_operators
	call	get_operator
	pop	edi
      expression_number:
	push	eax
	cmp	byte [esi],0
	je near_o0 invalid_expression
	call	convert_number
	pop	eax
	or	al,al
	jz	expression_operator
	stosb
      expression_operator:
	push	edi
	mov	edi,operators
	call	get_operator
	pop	edi
	pop	ebp
	or	al,al
	jz	expression_end
      operators_loop:
	cmp	esp,ebp
	je	push_operator
	mov	bl,al
	and	bl,0F0h
	mov	bh,byte [esp]
	and	bh,0F0h
	cmp	bl,bh
	ja	push_operator
	pop	bx
	mov	byte [edi],bl
	inc	edi
	jmp	operators_loop
      push_operator:
	push	ax
	jmp	expression_loop
      expression_end:
	cmp	esp,ebp
	je	expression_converted
	pop	ax
	stosb
	jmp	expression_end
      expression_converted:
	pop	ebp
	ret

convert_number:
	cmp	byte [esi],'('
	je	expression_value
	inc	edi
	call	get_number
	jc	symbol_value
	or	ebp,ebp
	jz	valid_number
	mov	byte [edi-1],0Fh
	ret
      valid_number:
	cmp	dword [edi+4],0
	jne	qword_number
	cmp	word [edi+2],0
	jne	dword_number
	cmp	byte [edi+1],0
	jne	word_number
      byte_number:
	mov	byte [edi-1],1
	inc	edi
	ret
      qword_number:
	mov	byte [edi-1],8
	scasd
	scasd
	ret
      dword_number:
	mov	byte [edi-1],4
	scasd
	ret
      word_number:
	mov	byte [edi-1],2
	scasw
	ret
      expression_value:
	inc	esi
	call	convert_expression
	lodsb
	cmp	al,')'
	jne near_o0 invalid_expression
	ret
      symbol_value:
	lodsb
	cmp	al,1Ah
	jne near_o0 invalid_value
	lodsb
	movzx	ecx,al
	push	ecx
	push	esi
	push	edi
	mov	edi,address_registers
	call	get_symbol
	jnc	register_value
	mov	edi,symbols
	call	get_symbol
	jnc near_o0 invalid_value
	pop	edi
	pop	esi
	pop	ecx
	call	get_label_id
	mov	byte [edi-1],11h
	stosd
	ret
      register_value:
	pop	edi
	add	esp,8
	mov	byte [edi-1],10h
	mov	al,ah
	stosb
	ret

get_number:
	xor	ebp,ebp
	lodsb
	cmp	al,22h
	je near_o0 get_text_number
	cmp	al,1Ah
	jne near_o0 not_number
	lodsb
	movzx	ecx,al
	mov	dword [number_start],esi
	mov	al,[esi]
	sub	al,30h
	jb near_o0 invalid_number
	cmp	al,9
	ja near_o0 invalid_number
	mov	eax,esi
	add	esi,ecx
	push	esi
	sub	esi,2
	mov	dword [edi],0
	mov	dword [edi+4],0
	inc	esi
	cmp	word [eax],'0x'  ; Same multibyte character constant order in fasm and NASM.
	je near_o0 get_hex_number
	dec	esi
	cmp	byte [esi+1],'h'
	je near_o0 get_hex_number
	cmp	byte [esi+1],'o'
	je near_o0 get_oct_number
	cmp	byte [esi+1],'b'
	je	get_bin_number
	cmp	byte [esi+1],'d'
	je	get_dec_number
	inc	esi
	cmp	byte [eax],'0'
	je near_o0 get_oct_number
      get_dec_number:
	xor	edx,edx
	mov	ebx,1
      get_dec_digit:
	cmp	esi,dword [number_start]
	jb near_o0 number_ok
	movzx	eax,byte [esi]
	sub	al,30h
	jc	bad_number
	cmp	al,9
	ja	bad_number
	mov	ecx,eax
	jecxz	next_dec_digit
      convert_dec_digit:
	add	dword [edi],ebx
	adc	dword [edi+4],edx
	loop	convert_dec_digit
      next_dec_digit:
	dec	esi
	mov	ecx,edx
	mov	eax,10
	mul	ebx
	mov	ebx,eax
	imul	ecx,10
	jo	dec_out_of_range
	add	edx,ecx
	jnc	get_dec_digit
      dec_out_of_range:
	or	ebp,1
	jmp	get_dec_digit
      bad_number:
	pop	eax
      invalid_number:
	mov	esi,dword [number_start]
	dec	esi
      not_number:
	dec	esi
	stc
	ret
      get_bin_number:
	xor	bl,bl
      get_bin_digit:
	cmp	esi,dword [number_start]
	jb near_o0 number_ok
	movzx	eax,byte [esi]
	sub	al,30h
	jc	bad_number
	cmp	al,1
	ja	bad_number
	xor	edx,edx
	mov	cl,bl
	dec	esi
	cmp	bl,64
	je	bin_out_of_range
	inc	bl
	cmp	cl,32
	jae	bin_digit_high
	shl	eax,cl
	or	dword [edi],eax
	jmp	get_bin_digit
      bin_digit_high:
	sub	cl,32
	shl	eax,cl
	or	dword [edi+4],eax
	jmp	get_bin_digit
      bin_out_of_range:
	or	ebp,1
	jmp	get_bin_digit
      get_hex_number:
	xor	bl,bl
      get_hex_digit:
	cmp	esi,dword [number_start]
	jb near_o0 number_ok
	movzx	eax,byte [esi]
	cmp	al,'x'
	je near_o0 hex_number_ok
	sub	al,30h
	jc	bad_number
	cmp	al,9
	jbe	hex_digit_ok
	sub	al,7
	cmp	al,15
	jbe	hex_digit_ok
	sub	al,20h
	jc near_o0 bad_number
	cmp	al,15
	ja near_o0 bad_number
      hex_digit_ok:
	xor	edx,edx
	mov	cl,bl
	dec	esi
	cmp	bl,64
	je	hex_out_of_range
	add	bl,4
	cmp	cl,32
	jae	hex_digit_high
	shl	eax,cl
	or	dword [edi],eax
	jmp	get_hex_digit
      hex_digit_high:
	sub	cl,32
	shl	eax,cl
	or	dword [edi+4],eax
	jmp	get_hex_digit
      hex_out_of_range:
	or	ebp,1
	jmp	get_hex_digit
      get_oct_number:
	xor	bl,bl
      get_oct_digit:
	cmp	esi,dword [number_start]
	jb	number_ok
	movzx	eax,byte [esi]
	sub	al,30h
	jc near_o0 bad_number
	cmp	al,7
	ja near_o0 bad_number
      oct_digit_ok:
	xor	edx,edx
	mov	cl,bl
	dec	esi
	cmp	bl,64
	jae	oct_out_of_range
	add	bl,3
	cmp	cl,32
	jae	oct_digit_high
	shl	eax,cl
	or	dword [edi],eax
	jmp	get_oct_digit
      oct_digit_high:
	sub	cl,32
	shl	eax,cl
	or	dword [edi+4],eax
	jmp	get_oct_digit
      oct_out_of_range:
	or	ebp,1
	jmp	get_oct_digit
      hex_number_ok:
	dec	esi
	cmp	esi,dword [number_start]
	jne near_o0 bad_number
      number_ok:
	pop	esi
      number_done:
	clc
	ret
      get_text_number:
	lodsd
	mov	edx,eax
	xor	bl,bl
	mov	dword [edi],0
	mov	dword [edi+4],0
      get_text_character:
	sub	edx,1
	jc	number_done
	movzx	eax,byte [esi]
	inc	esi
	mov	cl,bl
	cmp	bl,64
	je	text_out_of_range
	add	bl,8
	cmp	cl,32
	jae	text_character_high
	shl	eax,cl
	or	dword [edi],eax
	jmp	get_text_character
      text_character_high:
	sub	cl,32
	shl	eax,cl
	or	dword [edi+4],eax
	jmp	get_text_character
      text_out_of_range:
	or	ebp,1
	jmp	get_text_character

calculate_expression:
	lodsb
	or	al,al
	jz near_o0 get_string_value
	cmp	al,'.'
	je near_o0 convert_fp
	cmp	al,1
	je near_o0 get_byte_number
	cmp	al,2
	je near_o0 get_word_number
	cmp	al,4
	je near_o0 get_dword_number
	cmp	al,8
	je near_o0 get_qword_number
	cmp	al,0Fh
	je near_o0 value_out_of_range
	cmp	al,10h
	je near_o0 get_register
	cmp	al,11h
	je near_o0 get_label
	cmp	al,')'
	je near_o0 expression_calculated
	cmp	al,']'
	je near_o0 expression_calculated
	sub	edi,10h
	mov	ebx,edi
	sub	ebx,10h
	mov	dx,[ebx+8]
	or	dx,[edi+8]
	cmp	al,0E0h
	je near_o0 calculate_rva
	cmp	al,0D0h
	je near_o0 calculate_not
	cmp	al,0D1h
	je near_o0 calculate_neg
	cmp	al,80h
	je near_o0 calculate_add
	cmp	al,81h
	je near_o0 calculate_sub
	mov	ah,[ebx+12]
	or	ah,[edi+12]
	jnz near_o0 invalid_use_of_symbol
	cmp	al,90h
	je near_o0 calculate_mul
	cmp	al,91h
	je near_o0 calculate_div
	or	dx,dx
	jnz near_o0 invalid_expression
	cmp	al,0A0h
	je near_o0 calculate_mod
	cmp	al,0B0h
	je near_o0 calculate_and
	cmp	al,0B1h
	je near_o0 calculate_or
	cmp	al,0B2h
	je near_o0 calculate_xor
	cmp	al,0C0h
	je near_o0 calculate_shl
	cmp	al,0C1h
	je near_o0 calculate_shr
	jmp	invalid_expression
      expression_calculated:
	sub	edi,10h
	ret
      get_byte_number:
	mov	word [edi+8],0
	mov	byte [edi+12],0
	xor	eax,eax
	lodsb
	stosd
	xor	al,al
	stosd
	scasd
	scasd
	jmp	calculate_expression
      get_word_number:
	mov	word [edi+8],0
	mov	byte [edi+12],0
	xor	eax,eax
	lodsw
	stosd
	xor	ax,ax
	stosd
	scasd
	scasd
	jmp	calculate_expression
      get_dword_number:
	mov	word [edi+8],0
	mov	byte [edi+12],0
	movsd
	xor	eax,eax
	stosd
	scasd
	scasd
	jmp	calculate_expression
      get_qword_number:
	mov	word [edi+8],0
	mov	byte [edi+12],0
	movsd
	movsd
	scasd
	scasd
	jmp	calculate_expression
      get_register:
	mov	byte [edi+9],0
	mov	byte [edi+12],0
	lodsb
	mov	[edi+8],al
	mov	byte [edi+10],1
	xor	eax,eax
	stosd
	stosd
	scasd
	scasd
	jmp	calculate_expression
      get_label:
	mov	word [edi+8],0
	mov	byte [edi+12],0
	lodsd
	or	eax,eax
	jz near_o0 current_offset_label
	cmp	eax,1
	je near_o0 counter_label
	mov	ebx,eax
	test	byte [ebx+8],1
	jz near_o0 label_undefined
	test	byte [ebx+8],4
	jz	label_defined
	mov	al,byte [current_pass]
	cmp	al,[ebx+9]
	jne near_o0 label_undefined
      label_defined:
	mov	al,[ebx+11]
	cmp	byte [next_pass_needed],0
	je	label_type_ok
	cmp	byte [current_pass],0
	jne	label_type_ok
	xor	al,al
      label_type_ok:
	mov	[edi+12],al
	mov	eax,[ebx+12]
	mov	[edi+8],eax
	mov	eax,[ebx]
	stosd
	mov	eax,[ebx+4]
	stosd
	scasd
	scasd
	mov	al,[ebx+10]
	or	al,al
	jz near_o0 calculate_expression
	cmp	byte [forced_size],2
	je near_o0 calculate_expression
	cmp	byte [forced_size],1
	jne	check_size
	cmp	byte [operand_size],0
	jne near_o0 calculate_expression
	mov	byte [operand_size],al
	jmp	calculate_expression
      check_size:
	xchg	byte [operand_size],al
	or	al,al
	jz near_o0 calculate_expression
	cmp	al,byte [operand_size]
	jne near_o0 operand_sizes_do_not_match
	jmp	calculate_expression
      current_offset_label:
	cmp	byte [reloc_labels],0
	je	get_current_offset
	mov	byte [edi+12],2
      get_current_offset:
	mov	eax,dword [current_offset]
	sub	eax,dword [org_start]
	cdq
	stosd
	mov	eax,edx
	stosd
	mov	eax,dword [org_sib]
	stosd
	scasd
	jmp	calculate_expression
      counter_label:
	mov	eax,dword [counter]
	stosd
	xor	eax,eax
	stosd
	scasd
	scasd
	jmp	calculate_expression
      label_undefined:
	cmp	byte [current_pass],0
	jne near_o0 invalid_value
	or	byte [next_pass_needed],-1
	mov	byte [edi+12],0
	xor	eax,eax
	stosd
	stosd
	scasd
	scasd
	jmp	calculate_expression
      calculate_add:
	cmp	byte [next_pass_needed],0
	jne	add_values
	cmp	byte [edi+12],0
	je	add_values
	cmp	byte [ebx+12],0
	jne near_o0 invalid_use_of_symbol
      add_values:
	mov	al,[edi+12]
	or	[ebx+12],al
	mov	eax,[edi]
	add	[ebx],eax
	mov	eax,[edi+4]
	adc	[ebx+4],eax
	or	dx,dx
	jz near_o0 calculate_expression
	push	esi
	mov	esi,ebx
	lea	ebx,[edi+10]
	mov	cl,[edi+8]
	call	add_register
	lea	ebx,[edi+11]
	mov	cl,[edi+9]
	call	add_register
	pop	esi
	jmp	calculate_expression
      add_register:
	or	cl,cl
	jz	add_register_done
      add_register_start:
	cmp	[esi+8],cl
	jne	add_in_second_slot
	mov	al,[ebx]
	add	[esi+10],al
	jnz	add_register_done
	mov	byte [esi+8],0
	ret
      add_in_second_slot:
	cmp	[esi+9],cl
	jne	create_in_first_slot
	mov	al,[ebx]
	add	[esi+11],al
	jnz	add_register_done
	mov	byte [esi+9],0
	ret
      create_in_first_slot:
	cmp	byte [esi+8],0
	jne	create_in_second_slot
	mov	[esi+8],cl
	mov	al,[ebx]
	mov	[esi+10],al
	ret
      create_in_second_slot:
	cmp	byte [esi+9],0
	jne near_o0 invalid_expression
	mov	[esi+9],cl
	mov	al,[ebx]
	mov	[esi+11],al
      add_register_done:
	ret
      calculate_sub:
	xor	ah,ah
	cmp	byte [next_pass_needed],0
	jne	sub_values
	mov	ah,[ebx+12]
	mov	al,[edi+12]
	or	al,al
	jz	sub_values
	cmp	al,ah
	jne near_o0 invalid_use_of_symbol
	xor	ah,ah
      sub_values:
	mov	byte [ebx+12],ah
	mov	eax,[edi]
	sub	[ebx],eax
	mov	eax,[edi+4]
	sbb	[ebx+4],eax
	or	dx,dx
	jz near_o0 calculate_expression
	push	esi
	mov	esi,ebx
	lea	ebx,[edi+10]
	mov	cl,[edi+8]
	call	sub_register
	lea	ebx,[edi+11]
	mov	cl,[edi+9]
	call	sub_register
	pop	esi
	jmp	calculate_expression
      sub_register:
	or	cl,cl
	jz	add_register_done
	neg	byte [ebx]
	jmp	add_register_start
      calculate_mul:
	or	dx,dx
	jz	mul_start
	cmp	word [ebx+8],0
	jne	mul_start
	mov	eax,[ebx]
	xchg	eax,[edi]
	mov	[ebx],eax
	mov	eax,[ebx+4]
	xchg	eax,[edi+4]
	mov	[ebx+4],eax
	mov	eax,[ebx+8]
	xchg	eax,[edi+8]
	mov	[ebx+8],eax
	mov	eax,[ebx+12]
	xchg	eax,[edi+12]
	mov	[ebx+12],eax
      mul_start:
	push	esi
	push	dx
	mov	esi,ebx
	xor	bl,bl
	test	dword [esi+4],1 << 31
	jz	mul_first_sign_ok
	not	dword [esi]
	not	dword [esi+4]
	add	dword [esi],1
	adc	dword [esi+4],0
	not	bl
      mul_first_sign_ok:
	test	dword [edi+4],1 << 31
	jz	mul_second_sign_ok
	not	dword [edi]
	not	dword [edi+4]
	add	dword [edi],1
	adc	dword [edi+4],0
	not	bl
      mul_second_sign_ok:
	cmp	dword [esi+4],0
	jz	mul_numbers
	cmp	dword [edi+4],0
	jnz near_o0 value_out_of_range
      mul_numbers:
	mov	eax,[esi+4]
	mul	dword [edi]
	or	edx,edx
	jnz near_o0 value_out_of_range
	mov	ecx,eax
	mov	eax,[esi]
	mul	dword [edi+4]
	or	edx,edx
	jnz near_o0 value_out_of_range
	add	ecx,eax
	jc near_o0 value_out_of_range
	mov	eax,[esi]
	mul	dword [edi]
	add	edx,ecx
	jc near_o0 value_out_of_range
	mov	[esi],eax
	mov	[esi+4],edx
	or	bl,bl
	jz	mul_ok
	not	dword [esi]
	not	dword [esi+4]
	add	dword [esi],1
	adc	dword [esi+4],0
      mul_ok:
	pop	dx
	or	dx,dx
	jz	mul_calculated
	cmp	word [edi+8],0
	jne near_o0 invalid_value
	cmp	byte [esi+8],0
	je	mul_first_register_ok
	mov	al,[edi]
	cbw
	cwde
	cdq
	cmp	edx,[edi+4]
	jne near_o0 value_out_of_range
	cmp	eax,[edi]
	jne near_o0 value_out_of_range
	imul	byte [esi+10]
	mov	dl,ah
	cbw
	cmp	ah,dl
	jne near_o0 value_out_of_range
	mov	[esi+10],al
      mul_first_register_ok:
	cmp	byte [esi+9],0
	je	mul_calculated
	mov	al,[edi]
	cbw
	cwde
	cdq
	cmp	edx,[edi+4]
	jne near_o0 value_out_of_range
	cmp	eax,[edi]
	jne near_o0 value_out_of_range
	imul	byte [esi+11]
	mov	dl,ah
	cbw
	cmp	ah,dl
	jne near_o0 value_out_of_range
	mov	[esi+11],al
      mul_calculated:
	pop	esi
	jmp	calculate_expression
      calculate_div:
	push	esi
	push	dx
	mov	esi,ebx
	call	div_64
	pop	dx
	or	dx,dx
	jz	div_calculated
	cmp	byte [esi+8],0
	je	div_first_register_ok
	mov	al,[edi]
	cbw
	cwde
	cdq
	cmp	edx,[edi+4]
	jne near_o0 value_out_of_range
	cmp	eax,[edi]
	jne near_o0 value_out_of_range
	or	al,al
	jz near_o0 value_out_of_range
	mov	al,[esi+10]
	cbw
	idiv	byte [edi]
	mov	[esi+10],al
      div_first_register_ok:
	cmp	byte [esi+9],0
	je	div_calculated
	mov	al,[edi]
	cbw
	cwde
	cdq
	cmp	edx,[edi+4]
	jne near_o0 value_out_of_range
	cmp	eax,[edi]
	jne near_o0 value_out_of_range
	or	al,al
	jz near_o0 value_out_of_range
	mov	al,[esi+11]
	cbw
	idiv	byte [edi]
	mov	[esi+11],al
      div_calculated:
	pop	esi
	jmp	calculate_expression
      calculate_mod:
	push	esi
	mov	esi,ebx
	call	div_64
	mov	[esi],eax
	mov	[esi+4],edx
	pop	esi
	jmp	calculate_expression
      calculate_and:
	mov	eax,[edi]
	and	[ebx],eax
	mov	eax,[edi+4]
	and	[ebx+4],eax
	jmp	calculate_expression
      calculate_or:
	mov	eax,[edi]
	or	[ebx],eax
	mov	eax,[edi+4]
	or	[ebx+4],eax
	jmp	calculate_expression
      calculate_xor:
	cmp	byte [value_size],1
	je	xor_byte
	cmp	byte [value_size],2
	je	xor_word
	cmp	byte [value_size],4
	je	xor_dword
	cmp	byte [value_size],6
	je	xor_pword
      xor_qword:
	mov	eax,[edi]
	xor	[ebx],eax
	mov	eax,[edi+4]
	xor	[ebx+4],eax
	jmp	calculate_expression
      xor_byte:
	cmp	dword [edi+4],0
	jne	xor_qword
	cmp	word [edi+2],0
	jne	xor_qword
	cmp	byte [edi+1],0
	jne	xor_qword
	mov	al,[edi]
	xor	[ebx],al
	jmp	calculate_expression
      xor_word:
	cmp	dword [edi+4],0
	jne	xor_qword
	cmp	word [edi+2],0
	jne	xor_qword
	mov	ax,[edi]
	xor	[ebx],ax
	jmp	calculate_expression
      xor_dword:
	cmp	dword [edi+4],0
	jne	xor_qword
	mov	eax,[edi]
	xor	[ebx],eax
	jmp	calculate_expression
      xor_pword:
	cmp	word [edi+6],0
	jne	xor_qword
	mov	eax,[edi]
	xor	[ebx],eax
	mov	ax,[edi+4]
	xor	[ebx+4],ax
	jmp	calculate_expression
      calculate_shl:
	mov	eax,dword [edi+4]
	test	eax,1 << 31
	jnz	shl_negative
	or	eax,eax
	jnz near_o0 zero_value
	mov	ecx,[edi]
	cmp	ecx,64
	jae near_o0 zero_value
	cmp	ecx,32
	jae	shl_high
	mov	edx,[ebx+4]
	mov	eax,[ebx]
	shld	edx,eax,cl
	shl	eax,cl
	mov	[ebx],eax
	mov	[ebx+4],edx
	jmp	calculate_expression
      shl_high:
	sub	cl,32
	mov	eax,[ebx]
	shl	eax,cl
	mov	[ebx+4],eax
	mov	dword [ebx],0
	jmp	calculate_expression
      shl_negative:
	not	dword [edi]
	not	dword [edi+4]
	add	dword [edi],1
	adc	dword [edi+4],0
      calculate_shr:
	mov	eax,dword [edi+4]
	test	eax,1 << 31
	jnz	shr_negative
	or	eax,eax
	jnz	zero_value
	mov	ecx,[edi]
	cmp	ecx,64
	jae	zero_value
	cmp	ecx,32
	jae	shr_high
	mov	edx,[ebx+4]
	mov	eax,[ebx]
	shrd	eax,edx,cl
	shr	edx,cl
	mov	[ebx],eax
	mov	[ebx+4],edx
	jmp	calculate_expression
      shr_high:
	sub	cl,32
	mov	eax,[ebx+4]
	shr	eax,cl
	mov	[ebx],eax
	mov	dword [ebx+4],0
	jmp	calculate_expression
      shr_negative:
	not	dword [edi]
	not	dword [edi+4]
	add	dword [edi],1
	adc	dword [edi+4],0
	jmp	calculate_shl
      zero_value:
	mov	dword [ebx],0
	mov	dword [ebx+4],0
	jmp	calculate_expression
      calculate_not:
	cmp	word [edi+8],0
	jne near_o0 invalid_expression
	cmp	byte [edi+12],0
	jne near_o0 invalid_use_of_symbol
	cmp	byte [value_size],1
	je	not_byte
	cmp	byte [value_size],2
	je	not_word
	cmp	byte [value_size],4
	je	not_dword
	cmp	byte [value_size],6
	je	not_pword
      not_qword:
	not	dword [edi]
	not	dword [edi+4]
	add	edi,10h
	jmp	calculate_expression
      not_byte:
	cmp	dword [edi+4],0
	jne	not_qword
	cmp	word [edi+2],0
	jne	not_qword
	cmp	byte [edi+1],0
	jne	not_qword
	not	byte [edi]
	add	edi,10h
	jmp	calculate_expression
      not_word:
	cmp	dword [edi+4],0
	jne	not_qword
	cmp	word [edi+2],0
	jne	not_qword
	not	word [edi]
	add	edi,10h
	jmp	calculate_expression
      not_dword:
	cmp	dword [edi+4],0
	jne	not_qword
	not	dword [edi]
	add	edi,10h
	jmp	calculate_expression
      not_pword:
	cmp	word [edi+6],0
	jne	not_qword
	not	dword [edi]
	not	word [edi+4]
	add	edi,10h
	jmp	calculate_expression
      calculate_neg:
	cmp	word [edi+8],0
	jne near_o0 invalid_expression
	cmp	byte [edi+12],0
	jne near_o0 invalid_use_of_symbol
	mov	eax,[edi]
	mov	edx,[edi+4]
	mov	dword [edi],0
	mov	dword [edi+4],0
	sub	[edi],eax
	sbb	[edi+4],edx
	add	edi,10h
	jmp	calculate_expression
      calculate_rva:
	cmp	word [edi+8],0
	jne near_o0 invalid_expression
	mov	al,[edi+12]
	cmp	al,2
	je	rva_ok
	or	al,al
	jnz near_o0 invalid_use_of_symbol
	cmp	byte [next_pass_needed],0
	je near_o0 invalid_use_of_symbol
      rva_ok:
	mov	byte [edi+12],0
	mov	eax,dword [header_data]
	mov	eax,[eax+34h]
	sub	[edi],eax
	sbb	dword [edi+4],0
	add	edi,10h
	jmp	calculate_expression
      div_64:
	xor	bl,bl
	cmp	dword [edi],0
	jne	divider_ok
	cmp	dword [edi+4],0
	jne	divider_ok
	cmp	byte [next_pass_needed],0
	je near_o0 value_out_of_range
	jmp	div_done
      divider_ok:
	test	dword [esi+4],1 << 31
	jz	div_first_sign_ok
	not	dword [esi]
	not	dword [esi+4]
	add	dword [esi],1
	adc	dword [esi+4],0
	not	bl
      div_first_sign_ok:
	test	dword [edi+4],1 << 31
	jz	div_second_sign_ok
	not	dword [edi]
	not	dword [edi+4]
	add	dword [edi],1
	adc	dword [edi+4],0
	not	bl
      div_second_sign_ok:
	cmp	dword [edi+4],0
	jne	div_high
	mov	ecx,[edi]
	mov	eax,[esi+4]
	xor	edx,edx
	div	ecx
	mov	[esi+4],eax
	mov	eax,[esi]
	div	ecx
	mov	[esi],eax
	mov	eax,edx
	xor	edx,edx
	jmp	div_done
      div_high:
	mov	eax,[esi+4]
	xor	edx,edx
	div	dword [edi+4]
	mov	ebx,[esi]
	mov	[esi],eax
	mov	dword [esi+4],0
	mov	ecx,edx
	mul	dword [edi]
      div_high_loop:
	cmp	ecx,edx
	ja	div_high_done
	jb	div_high_change
	cmp	ebx,eax
	jae	div_high_done
      div_high_change:
	dec	dword [esi]
	sub	eax,[edi]
	sbb	edx,[edi+4]
	jnc	div_high_loop
      div_high_done:
	sub	ebx,eax
	sbb	ecx,edx
	mov	edx,ecx
	mov	eax,ebx
	ret
      div_done:
	or	bl,bl
	jz	div_ok
	not	dword [esi]
	not	dword [esi+4]
	add	dword [esi],1
	adc	dword [esi+4],0
      div_ok:
	ret
      convert_fp:
	mov	word [edi+8],0
	mov	byte [edi+12],0
	mov	al,byte [value_size]
	cmp	al,4
	je	convert_fp_dword
	cmp	al,8
	je	convert_fp_qword
	jmp	invalid_value
      convert_fp_dword:
	xor	eax,eax
	cmp	word [esi+8],8000h
	je	fp_dword_store
	mov	bx,[esi+8]
	mov	eax,[esi+4]
	shl	eax,1
	shr	eax,9
	jnc	fp_dword_ok
	inc	eax
	test	eax,1 << 23
	jz	fp_dword_ok
	and	eax,(1 << 23) - 1
	inc	bx
	shr	eax,1
      fp_dword_ok:
	add	bx,7Fh
	cmp	bx,100h
	jae near_o0 value_out_of_range
	shl	ebx,23
	or	eax,ebx
	mov	bl,[esi+11]
	shl	ebx,31
	or	eax,ebx
      fp_dword_store:
	mov	[edi],eax
	xor	eax,eax
	mov	[edi+4],eax
	add	esi,12
	ret
      convert_fp_qword:
	xor	eax,eax
	xor	edx,edx
	cmp	word [esi+8],8000h
	je	fp_qword_store
	mov	bx,[esi+8]
	mov	eax,[esi]
	mov	edx,[esi+4]
	shl	eax,1
	rcl	edx,1
	mov	ecx,edx
	shr	edx,12
	shrd	eax,ecx,12
	jnc	fp_qword_ok
	add	eax,1
	adc	edx,0
	test	edx,1 << 20
	jz	fp_qword_ok
	and	edx,(1 << 20) - 1
	inc	bx
	shr	edx,1
	rcr	eax,1
      fp_qword_ok:
	add	bx,3FFh
	cmp	bx,800h
	jae near_o0 value_out_of_range
	shl	ebx,20
	or	edx,ebx
	mov	bl,[esi+11]
	shl	ebx,31
	or	edx,ebx
      fp_qword_store:
	mov	[edi],eax
	mov	[edi+4],edx
	add	esi,12
	ret
      get_string_value:
	lodsd
	mov	ecx,eax
	cmp	ecx,8
	ja near_o0 value_out_of_range
	mov	edx,edi
	xor	eax,eax
	stosd
	stosd
	mov	edi,edx
	rep	movsb
	mov	edi,edx
	inc	esi
	mov	word [edi+8],0
	mov	byte [edi+12],0
	ret

get_byte_value:
	mov	byte [value_size],1
	mov	byte [forced_size],2
	mov	dword [current_offset],edi
	call	calculate_expression
	cmp	word [edi+8],0
	jne near_o0 invalid_value
	cmp	byte [edi+12],0
	jne near_o0 invalid_use_of_symbol
	mov	eax,[edi]
	cmp	dword [edi+4],0
	je	byte_positive
	cmp	dword [edi+4],-1
	jne	range_exceeded
	cmp	eax,-80h
	jb	range_exceeded
	ret
      byte_positive:
	cmp	eax,100h
	jae	range_exceeded
      return_value:
	ret
      range_exceeded:
	cmp	dword [error_line],0
	jne	return_value
	mov	eax,dword [current_line]
	mov	dword [error_line],eax
	mov	dword [error],value_out_of_range
	ret
get_word_value:
	mov	byte [value_size],2
	mov	byte [forced_size],2
	mov	dword [current_offset],edi
	call	calculate_expression
	cmp	word [edi+8],0
	jne near_o0 invalid_value
	mov	al,[edi+12]
	cmp	al,2
	je near_o0 invalid_use_of_symbol
	mov	byte [value_type],al
      check_word_value:
	mov	eax,[edi]
	cmp	dword [edi+4],0
	je	word_positive
	cmp	dword [edi+4],-1
	jne	range_exceeded
	cmp	eax,-8000h
	jb	range_exceeded
	ret
      word_positive:
	cmp	eax,10000h
	jae	range_exceeded
	ret
get_dword_value:
	mov	byte [value_size],4
	mov	byte [forced_size],2
	mov	dword [current_offset],edi
	call	calculate_expression
	cmp	word [edi+8],0
	jne near_o0 invalid_value
	mov	al,[edi+12]
	mov	byte [value_type],al
      check_dword_value:
	mov	eax,[edi]
	cmp	dword [edi+4],0
	je	dword_positive
	cmp	dword [edi+4],-1
	jne near_o0 range_exceeded
	test	eax,1 << 31
	jz near_o0 range_exceeded
      dword_positive:
	ret
get_pword_value:
	mov	byte [value_size],6
	mov	byte [forced_size],2
	mov	dword [current_offset],edi
	call	calculate_expression
	cmp	word [edi+8],0
	jne near_o0 invalid_value
	mov	al,[edi+12]
	mov	byte [value_type],al
	mov	eax,[edi]
	mov	edx,[edi+4]
	cmp	edx,10000h
	jge near_o0 range_exceeded
	cmp	edx,-8000h
	jl near_o0 range_exceeded
	ret
get_qword_value:
	mov	byte [value_size],8
	mov	byte [forced_size],2
	mov	dword [current_offset],edi
	call	calculate_expression
	cmp	word [edi+8],0
	jne near_o0 invalid_value
	mov	al,[edi+12]
	mov	byte [value_type],al
	mov	eax,[edi]
	mov	edx,[edi+4]
	ret
get_value:
	mov	byte [operand_size],0
	mov	byte [forced_size],0
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne near_o0 invalid_value
	mov	al,byte [operand_size]
	cmp	al,1
	je	value_byte
	cmp	al,2
	je	value_word
	cmp	al,4
	je	value_dword
	cmp	al,6
	je	value_pword
	cmp	al,8
	je	value_qword
	or	al,al
	jnz near_o0 invalid_value
      value_qword:
	call	get_qword_value
	ret
      value_pword:
	call	get_pword_value
	movzx	edx,dx
	ret
      value_dword:
	call	get_dword_value
	xor	edx,edx
	ret
      value_word:
	call	get_word_value
	xor	edx,edx
	movzx	eax,ax
	ret
      value_byte:
	call	get_byte_value
	xor	edx,edx
	movzx	eax,al
	ret

get_address:
	mov	byte [segment_register],0
	mov	byte [address_size],0
	mov	byte [value_size],4
	push	dword address_ok
	mov	al,[esi]
	and	al,11110000b
	cmp	al,60h
	jne	get_size_prefix
	lodsb
	sub	al,60h
	mov	byte [segment_register],al
	mov	al,[esi]
	and	al,11110000b
      get_size_prefix:
	cmp	al,70h
	jne	calculate_address
	lodsb
	sub	al,70h
	cmp	al,4
	ja near_o0 invalid_address_size
	mov	byte [address_size],al
	mov	byte [value_size],al
	jmp	calculate_address
get_address_value:
	mov	byte [address_size],0
	mov	byte [value_size],4
	push	dword address_ok
      calculate_address:
	mov	dword [current_offset],edi
	call	calculate_expression
	mov	al,[edi+12]
	mov	byte [value_type],al
	cmp	al,1
	je near_o0 invalid_use_of_symbol
	or	al,al
	jz	address_symbol_ok
	mov	al,84h
	xchg	byte [address_size],al
	or	al,al
	jz	address_symbol_ok
	cmp	al,4
	jne near_o0 address_sizes_do_not_agree
      address_symbol_ok:
	xor	bx,bx
	xor	cl,cl
	mov	ch,byte [address_size]
	cmp	word [edi+8],0
	je near_o0 check_dword_value
	mov	al,[edi+8]
	mov	dl,[edi+10]
	call	get_address_register
	mov	al,[edi+9]
	mov	dl,[edi+11]
	call	get_address_register
	mov	ax,bx
	shr	ah,4
	shr	al,4
	or	bh,bh
	jz	check_address_registers
	or	bl,bl
	jz	check_address_registers
	cmp	al,ah
	jne near_o0 invalid_address
      check_address_registers:
	or	al,ah
	cmp	al,2
	je	address_16bit
	cmp	al,4
	jne near_o0 invalid_address
	or	bh,bh
	jnz	check_index_scale
	cmp	cl,2
	je	special_index_scale
	cmp	cl,3
	je	special_index_scale
	cmp	cl,5
	je	special_index_scale
	cmp	cl,9
	je	special_index_scale
      check_index_scale:
	or	cl,cl
	jz	address_registers_ok
	cmp	cl,1
	je	address_registers_ok
	cmp	cl,2
	je	address_registers_ok
	cmp	cl,4
	je	address_registers_ok
	cmp	cl,8
	je	address_registers_ok
	jmp	invalid_address
      special_index_scale:
	mov	bh,bl
	dec	cl
      address_registers_ok:
	jmp	check_dword_value
      address_16bit:
	or	cl,cl
	jz near_o0 check_word_value
	cmp	cl,1
	je near_o0 check_word_value
	jmp	invalid_address
      get_address_register:
	or	al,al
	jz	address_register_ok
	cmp	dl,1
	jne	scaled_register
	or	bh,bh
	jnz	scaled_register
	mov	bh,al
      address_register_ok:
	ret
      scaled_register:
	or	bl,bl
	jnz near_o0 invalid_address
	mov	bl,al
	mov	cl,dl
	jmp	address_register_ok
      address_ok:
	mov	edx,eax
	ret

calculate_logical_expression:
	call	get_logical_value
      logical_loop:
	push	ax
	lodsb
	cmp	al,'|'
	je	logical_or
	cmp	al,'&'
	je	logical_and
	dec	esi
	pop	ax
	ret
      logical_or:
	call	get_logical_value
	pop	bx
	or	al,bl
	jmp	logical_loop
      logical_and:
	call	get_logical_value
	pop	bx
	and	al,bl
	jmp	logical_loop

get_logical_value:
	xor	al,al
	cmp	byte [esi],'~'
	jne	negation_ok
	inc	esi
	or	al,-1
      negation_ok:
	push	ax
	cmp	byte [esi],'{'
	je near_o0 logical_expression
	push	esi
	cmp	byte [esi],11h
	jne	check_for_values
	add	esi,2
      check_for_values:
	xor	bl,bl
	cmp	byte [esi],'('
	jne	find_eq_symbol
	call	skip_symbol
	lodsb
	cmp	al,'='
	je near_o0 compare_values
	cmp	al,'>'
	je near_o0 compare_values
	cmp	al,'<'
	je near_o0 compare_values
	cmp	al,0xf2
	je near_o0 compare_values
	cmp	al,0xf3
	je near_o0 compare_values
	cmp	al,0xf6
	je near_o0 compare_values
	dec	esi
      find_eq_symbol:
	cmp	byte [esi],81h
	je	compare_symbols
	cmp	byte [esi],83h
	je	scan_symbols_list
	call	check_character
	jc near_o0 logical_number
	cmp	al,','
	jne	next_eq_symbol
	mov	bl,1
      next_eq_symbol:
	call	skip_symbol
	jmp	find_eq_symbol
      compare_symbols:
	inc	esi
	pop	ebx
	mov	edx,esi
	push	edi
	mov	edi,ebx
	mov	ecx,esi
	dec	ecx
	sub	ecx,edi
	repe	cmpsb
	pop	edi
	je	symbols_equal
	mov	esi,edx
      symbols_different:
	call	check_character
	jc near_o0 return_false
	call	skip_symbol
	jmp	symbols_different
      symbols_equal:
	call	check_character
	jc near_o0 return_true
	jmp	symbols_different
      scan_symbols_list:
	or	bl,bl
	jnz near_o0 invalid_expression
	xor	bp,bp
	inc	esi
	lodsb
	cmp	al,'<'
	jne near_o0 invalid_expression
	pop	ebx
	mov	ecx,esi
	sub	ecx,2
	sub	ecx,ebx
      compare_in_list:
	mov	edx,esi
	push	ecx
	push	edi
	mov	edi,ebx
	repe	cmpsb
	pop	edi
	pop	ecx
	jne	not_equal_in_list
	cmp	byte [esi],','
	je	skip_rest_of_list
	cmp	byte [esi],'>'
	jne	not_equal_in_list
      skip_rest_of_list:
	call	check_character
	jc near_o0 invalid_expression
	cmp	al,'>'
	je	list_return_true
	call	skip_symbol
	jmp	skip_rest_of_list
      list_return_true:
	inc	esi
	jmp	return_true
      not_equal_in_list:
	mov	esi,edx
      skip_list_item:
	call	check_character
	jc near_o0 invalid_expression
	cmp	al,'>'
	je	list_return_false
	cmp	al,','
	je	next_in_list
	call	skip_symbol
	jmp	skip_list_item
      next_in_list:
	inc	esi
	jmp	compare_in_list
      list_return_false:
	inc	esi
	jmp	return_false
      check_character:
	mov	al,[esi]
	or	al,al
	jz	stop
	cmp	al,0Fh
	je	stop
	cmp	al,'}'
	je	stop
	cmp	al,'|'
	je	stop
	cmp	al,'&'
	je	stop
	clc
	ret
      stop:
	stc
	ret
      compare_values:
	pop	esi
	call	get_value
	mov	bl,byte [value_type]
	push	eax
	push	edx
	push	bx
	lodsb
	mov	byte [compare_type],al
	call	get_value
	pop	bx
	cmp	byte [next_pass_needed],0
	jne	values_ok
	cmp	bl,byte [value_type]
	jne near_o0 invalid_use_of_symbol
      values_ok:
	pop	ecx
	pop	ebx
	cmp	byte [compare_type],'='
	je	check_equal
	cmp	byte [compare_type],'>'
	je	check_greater
	cmp	byte [compare_type],'<'
	je	check_less
	cmp	byte [compare_type],0xf2
	je	check_not_less
	cmp	byte [compare_type],0xf3
	je	check_not_greater
	cmp	byte [compare_type],0xf6
	je	check_not_equal
	jmp	invalid_expression
      check_equal:
	cmp	eax,ebx
	jne	return_false
	cmp	edx,ecx
	jne	return_false
	jmp	return_true
      check_greater:
	cmp	edx,ecx
	jl	return_true
	jg	return_false
	cmp	eax,ebx
	jb	return_true
	jae	return_false
      check_less:
	cmp	edx,ecx
	jl	return_false
	jg	return_true
	cmp	eax,ebx
	jbe	return_false
	ja	return_true
      check_not_less:
	cmp	edx,ecx
	jl	return_true
	jg	return_false
	cmp	eax,ebx
	jbe	return_true
	ja	return_false
      check_not_greater:
	cmp	edx,ecx
	jl	return_false
	jg	return_true
	cmp	eax,ebx
	jb	return_false
	jae	return_true
      check_not_equal:
	cmp	eax,ebx
	jne	return_true
	cmp	edx,ecx
	jne	return_true
	jmp	return_false
      logical_number:
	pop	esi
	call	get_value
	cmp	byte [value_type],0
	jne near_o0 invalid_expression
	or	eax,edx
	jnz	return_true
      return_false:
	xor	al,al
	jmp	logical_value_ok
      return_true:
	or	al,-1
	jmp	logical_value_ok
      logical_expression:
	inc	esi
	call	calculate_logical_expression
	push	ax
	lodsb
	cmp	al,'}'
	jne near_o0 invalid_expression
	pop	ax
      logical_value_ok:
	pop	bx
	xor	al,bl
	ret

;%include '../preproce.inc'

; flat assembler source
; Copyright (c) 1999-2001, Tomasz Grysztar
; All rights reserved.

preprocessor:
	mov	eax,dword [memory_start]
	mov	dword [source_start],eax
	push	dword [additional_memory]
	mov	eax,dword [additional_memory]
	mov	dword [macros_list],eax
	mov	eax,dword [additional_memory_end]
	mov	dword [labels_list],eax
	mov	dword [display_buffer],0
	mov	byte [macro_status],0
	mov	edx,dword [input_file]
	mov	edi,dword [memory_start]
	call	preprocess_file
	jc near_o0 main_file_not_found
	cmp	byte [macro_status],0
	jne near_o0 unexpected_end_of_file
	pop	dword [additional_memory]
	mov	dword [code_start],edi
	ret

preprocess_file:
	push	dword [memory_end]
	push	edx
	call	open
	jc	no_source_file
	mov	al,2
	xor	edx,edx
	call	lseek
	push	eax
	xor	al,al
	xor	edx,edx
	call	lseek
	pop	ecx
	mov	edx,dword [memory_end]
	dec	edx
	mov	byte [edx],1Ah
	sub	edx,ecx
	jc near_o0 out_of_memory
	mov	esi,edx
	cmp	edx,edi
	jbe near_o0 out_of_memory
	mov	dword [memory_end],edx
	call	read
	call	close
	pop	edx
	xor	ecx,ecx
	mov	ebx,esi
      preprocess_source:
	inc	ecx
	mov	dword [current_line],edi
	mov	eax,edx
	stosd
	mov	eax,ecx
	stosd
	mov	eax,esi
	sub	eax,ebx
	stosd
	push	ebx
	push	edx
	call	convert_line
	call	preprocess_line
	pop	edx
	pop	ebx
      next_line:
	cmp	byte [esi-1],1Ah
	jne	preprocess_source
      file_end:
	pop	dword [memory_end]
	clc
	ret
      no_source_file:
	pop	eax
	pop	eax
	stc
	ret

convert_line:
	push	ecx
	cmp	byte [macro_status],0
	jle	convert_line_data
	mov	ax,3Bh
	stosw
      convert_line_data:
	cmp	edi,dword [memory_end]
	jae near_o0 out_of_memory
	lodsb
	cmp	al,20h
	je	convert_line_data
	cmp	al,9
	je	convert_line_data
	dec	esi
	lodsb
	mov	ah,al
	mov	ebx,characters
	xlatb
	or	al,al
	jz	convert_separator
	cmp	ah,27h
	je near_o0 convert_string
	cmp	ah,22h
	je near_o0 convert_string
	mov	byte [edi],1Ah
	scasw
	stosb
	mov	ebx,characters
	xor	ecx,ecx
      convert_symbol:
	lodsb
	xlatb
	stosb
	or	al,al
	loopnz convert_symbol
	neg	ecx
	cmp	ecx,255
	ja near_o0 name_too_long
	dec	edi
	mov	ebx,edi
	sub	ebx,ecx
	mov	byte [ebx-1],cl
	mov	ah,[esi-1]
      convert_separator:
	xchg	al,ah
	cmp	al,20h
	jb	control_character
	je	convert_line_data
      symbol_character:
	cmp	al,3Bh
	je near_o0 ignore_comment
	cmp	al,5Ch
	je near_o0 concate_lines
	stosb
	jmp	convert_line_data
      control_character:
	cmp	al,1Ah
	je near_o0 line_end
	cmp	al,0Dh
	je	cr_character
	cmp	al,0Ah
	je	lf_character
	cmp	al,9
	je near_o0 convert_line_data
	or	al,al
	jnz	symbol_character
	jmp	line_end
      lf_character:
	lodsb
	cmp	al,0Dh
	je near_o0 line_end
	dec	esi
	jmp	line_end
      cr_character:
	lodsb
	cmp	al,0Ah
	je near_o0 line_end
	dec	esi
	jmp	line_end
      convert_string:
	mov	al,22h
	stosb
	scasd
	mov	ebx,edi
      copy_string:
	lodsb
	stosb
	cmp	al,0Ah
	je near_o0 missing_end_quote
	cmp	al,0Dh
	je near_o0 missing_end_quote
	or	al,al
	jz near_o0 missing_end_quote
	cmp	al,1Ah
	je near_o0 missing_end_quote
	cmp	al,ah
	jne	copy_string
	lodsb
	cmp	al,ah
	je	copy_string
	dec	esi
	dec	edi
	mov	eax,edi
	sub	eax,ebx
	mov	[ebx-4],eax
	jmp	convert_line_data
      concate_lines:
	lodsb
	cmp	al,20h
	je	concate_lines
	cmp	al,9
	je	concate_lines
	cmp	al,1Ah
	je near_o0 unexpected_end_of_file
	cmp	al,0Ah
	je	concate_lf
	cmp	al,0Dh
	je	concate_cr
	cmp	al,3Bh
	jne near_o0 extra_characters_on_line
      find_concated_line:
	lodsb
	cmp	al,0Ah
	je	concate_lf
	cmp	al,0Dh
	je	concate_cr
	or	al,al
	jz	concate_ok
	cmp	al,1Ah
	jne	find_concated_line
	jmp	unexpected_end_of_file
      concate_lf:
	lodsb
	cmp	al,0Dh
	je	concate_ok
	dec	esi
	jmp	concate_ok
      concate_cr:
	lodsb
	cmp	al,0Ah
	je	concate_ok
	dec	esi
      concate_ok:
	inc	dword [esp]
	jmp	convert_line_data
      ignore_comment:
	lodsb
	cmp	al,0Ah
	je near_o0 lf_character
	cmp	al,0Dh
	je near_o0 cr_character
	or	al,al
	jz	line_end
	cmp	al,1Ah
	jne	ignore_comment
      line_end:
	xor	al,al
	stosb
	pop	ecx
	ret

preprocess_line:
	push	dword [struc_name]
	push	ecx
	push	esi
	mov	esi,dword [current_line]
	add	esi,12
	mov	al,byte [macro_status]
	dec	al
	jz near_o0 find_macro_block
	dec	al
	jz near_o0 skip_macro_block
      preprocess_instruction:
	lodsb
	cmp	al,':'
	je	preprocess_instruction
	movzx	ecx,byte [esi]
	inc	esi
	cmp	al,1Ah
	jne	not_preprocessor_symbol
	push	edi
	mov	edi,preprocessor_directives
	call	get_symbol
	pop	edi
	jc	not_preprocessor_directive
	mov	byte [edx-2],3Bh
	movzx	ebx,ax
	add	ebx,preprocessor
	xor	eax,eax
	jmp	ebx
      not_preprocessor_directive:
	mov	al,cl
	xor	ah,ah
	call	get_macro
	jc	not_macro
	mov	byte [edx-2],3Bh
	mov	dword [struc_name],0
	jmp	use_macro
      not_macro:
	mov	dword [struc_name],esi
	add	esi,ecx
	lodsb
	cmp	al,':'
	je	preprocess_instruction
	cmp	al,1Ah
	jne	not_preprocessor_symbol
	cmp	dword [esi],3+('equ' << 8)  ; Same multibyte character constant order in fasm and NASM.
	je near_o0 define_symbolic_constant
	lodsb
	mov	ah,1
	call	get_macro
	jc	not_preprocessor_symbol
	mov	byte [edx-2],':'
	mov	al,3Bh
	xchg	al,[edx-1]
	dec	al
	mov	[edx],al
	jmp	use_macro
      not_preprocessor_symbol:
	mov	esi,dword [current_line]
	add	esi,12
	call	process_symbolic_constants
      line_preprocessed:
	pop	esi
	pop	ecx
	pop	dword [struc_name]
	ret
get_macro:
	mov	edx,esi
	mov	ebp,edi
	mov	ebx,dword [additional_memory]
      check_macro:
	mov	cl,al
	cmp	ebx,dword [macros_list]
	je	no_macro_found
	sub	ebx,8
	cmp	ax,[ebx]
	jne	check_macro
	mov	edi,[ebx+4]
	repe	cmpsb
	je	macro_ok
	mov	esi,edx
	jmp	check_macro
      no_macro_found:
	mov	edi,ebp
	stc
	ret
      macro_ok:
	mov	edi,ebp
	clc
	ret
process_symbolic_constants:
	mov	ebp,esi
	lodsb
	cmp	al,1Ah
	je	check_symbol
	cmp	al,22h
	je	ignore_string
	or	al,al
	jnz	process_symbolic_constants
	dec	esi
	ret
      ignore_string:
	lodsd
	add	esi,eax
	jmp	process_symbolic_constants
      check_symbol:
	movzx	ecx,byte [esi]
	inc	esi
	call	replace_symbolic_constant
	jnc	process_after_replaced
	add	esi,ecx
	jmp	process_symbolic_constants
      replace_symbolic_constant:
	push	edi
	mov	ebx,esi
	mov	eax,ecx
	mov	edx,dword [labels_list]
      scan_symbolic_constants:
	mov	ecx,eax
	mov	esi,ebx
	cmp	edx,dword [additional_memory_end]
	je	not_symbolic_constant
	cmp	al,[edx]
	jne	next_symbolic_constant
	mov	edi,[edx+4]
	repe	cmpsb
	je	symbolic_constant_found
      next_symbolic_constant:
	add	edx,16
	jmp	scan_symbolic_constants
      not_symbolic_constant:
	pop	edi
	stc
	ret
      symbolic_constant_found:
	pop	edi
	mov	ecx,[edx+8]
	mov	edx,[edx+12]
	xchg	esi,edx
	xor	eax,eax
	shr	ecx,1
	rcl	al,1
	shr	ecx,1
	rcl	ah,1
	rep	movsd
	mov	cl,ah
	rep	movsw
	mov	cl,al
	rep	movsb
	mov	esi,edx
	clc
	ret
      process_after_replaced:
	lodsb
	cmp	al,1Ah
	je	symbol_after_replaced
	stosb
	cmp	al,22h
	je	string_after_replaced
	or	al,al
	jnz	process_after_replaced
	mov	ecx,edi
	sub	ecx,esi
	mov	edi,ebp
	xor	eax,eax
	shr	ecx,1
	rcl	al,1
	shr	ecx,1
	rcl	ah,1
	rep	movsd
	mov	cl,ah
	rep	movsw
	mov	cl,al
	rep	movsb
	ret
      string_after_replaced:
	lodsd
	stosd
	mov	ecx,eax
	rep	movsb
	jmp	process_after_replaced
      symbol_after_replaced:
	movzx	ecx,byte [esi]
	inc	esi
	call	replace_symbolic_constant
	jnc	process_after_replaced
	mov	al,1Ah
	mov	ah,cl
	stosw
	rep	movsb
	jmp	process_after_replaced
include_file:
	lodsb
	cmp	al,22h
	jne near_o0 invalid_argument
	lodsd
	mov	edx,esi
	add	esi,eax
	cmp	byte [esi],0
	jne near_o0 extra_characters_on_line
	call	preprocess_file
	jc near_o0 file_not_found
	jmp	line_preprocessed
define_symbolic_constant:
	add	esi,4
	push	esi
	call	process_symbolic_constants
	pop	ebx
	mov	edx,dword [labels_list]
	sub	edx,16
	cmp	edx,dword [additional_memory]
	jb near_o0 out_of_memory
	mov	dword [labels_list],edx
	mov	ecx,edi
	dec	ecx
	sub	ecx,ebx
	mov	[edx+8],ecx
	mov	[edx+12],ebx
	mov	ebx,dword [struc_name]
	mov	byte [ebx-2],3Bh
	mov	al,[ebx-1]
	mov	[edx],al
	mov	[edx+4],ebx
	jmp	line_preprocessed
define_struc:
	or	ah,1
define_macro:
	cmp	byte [macro_status],0
	jne near_o0 unexpected_instruction
	lodsb
	cmp	al,1Ah
	jne near_o0 invalid_name
	lodsb
	mov	ebx,dword [additional_memory]
	mov	[ebx],ax
	mov	[ebx+4],esi
	add	ebx,8
	cmp	ebx,dword [labels_list]
	jae near_o0 out_of_memory
	mov	dword [additional_memory],ebx
	movzx	eax,al
	add	esi,eax
	mov	byte [macro_status],1
	xor	bl,bl
	lodsb
	or	al,al
	jz near_o0 line_preprocessed
	cmp	al,'{'
	je	found_macro_block
	dec	esi
      skip_macro_arguments:
	lodsb
	cmp	al,1Ah
	je	skip_macro_argument
	cmp	al,'['
	jne near_o0 invalid_macro_arguments
	xor	bl,-1
	jz near_o0 invalid_macro_arguments
	lodsb
	cmp	al,1Ah
	jne near_o0 invalid_macro_arguments
      skip_macro_argument:
	movzx	eax,byte [esi]
	inc	esi
	add	esi,eax
	lodsb
	cmp	al,','
	je	skip_macro_arguments
	cmp	al,']'
	jne	end_macro_arguments
	lodsb
	not	bl
      end_macro_arguments:
	or	bl,bl
	jnz near_o0 invalid_macro_arguments
	or	al,al
	jz near_o0 line_preprocessed
	cmp	al,'{'
	je	found_macro_block
	jmp	invalid_macro_arguments
      find_macro_block:
	add	esi,2
	lodsb
	or	al,al
	jz near_o0 line_preprocessed
	cmp	al,'{'
	jne near_o0 unexpected_characters
      found_macro_block:
	mov	byte [macro_status],2
      skip_macro_block:
	lodsb
	cmp	al,1Ah
	je	skip_macro_symbol
	cmp	al,3Bh
	je	skip_macro_symbol
	cmp	al,22h
	je	skip_macro_string
	or	al,al
	jz near_o0 line_preprocessed
	cmp	al,'}'
	jne	skip_macro_block
	lodsb
	or	al,al
	jnz near_o0 extra_characters_on_line
	mov	byte [macro_status],0
	jmp	line_preprocessed
      skip_macro_symbol:
	movzx	eax,byte [esi]
	inc	esi
	add	esi,eax
	jmp	skip_macro_block
      skip_macro_string:
	lodsd
	add	esi,eax
	jmp	skip_macro_block
purge_macro:
	lodsb
	cmp	al,1Ah
	jne near_o0 invalid_name
	lodsb
	xor	ah,ah
	call	get_macro
	jc	macro_purged
	or	byte [ebx+1],80h
      macro_purged:
	lodsb
	cmp	al,','
	je	purge_macro
	or	al,al
	jnz near_o0 extra_characters_on_line
	jmp	line_preprocessed
use_macro:
	push	dword [macro_constants]
	push	dword [macro_block]
	push	dword [macro_block_line_number]
	push	dword [counter]
	push	dword [counter_limit]
	or	byte [macro_status],80h
	or	byte [ebx+1],80h
	mov	edx,esi
	movzx	esi,byte [ebx]
	add	esi,[ebx+4]
	push	edi
	mov	edi,dword [additional_memory]
	mov	dword [macro_constants],edi
	mov	dword [counter],0
      process_macro_arguments:
	lodsb
	or	al,al
	jz near_o0 find_macro_instructions
	cmp	al,'{'
	je near_o0 macro_instructions_start
	cmp	al,'['
	jne	get_macro_argument
	mov	ebp,esi
	inc	esi
	inc	dword [counter]
      get_macro_argument:
	movzx	eax,byte [esi]
	inc	esi
	mov	[edi+4],esi
	add	esi,eax
	ror	eax,8
	or	eax,dword [counter]
	rol	eax,8
	mov	[edi],eax
	xchg	esi,edx
	mov	[edi+12],esi
      get_argument_value:
	lodsb
	or	al,al
	jz	argument_value_end
	cmp	al,','
	je	argument_value_end
	cmp	al,22h
	je	argument_string
	cmp	al,1Ah
	jne	get_argument_value
	movzx	eax,byte [esi]
	inc	esi
	add	esi,eax
	jmp	get_argument_value
      argument_string:
	lodsd
	add	esi,eax
	jmp	get_argument_value
      argument_value_end:
	dec	esi
	mov	eax,esi
	sub	eax,[edi+12]
	mov	[edi+8],eax
	xchg	esi,edx
	add	edi,16
	cmp	edi,dword [labels_list]
	jae near_o0 out_of_memory
	lodsb
	cmp	al,','
	je	next_argument
	cmp	al,']'
	je	next_arguments_group
	dec	esi
	jmp	arguments_end
      next_argument:
	cmp	byte [edx],','
	jne near_o0 process_macro_arguments
	inc	edx
	jmp	process_macro_arguments
      next_arguments_group:
	cmp	byte [edx],','
	jne	arguments_end
	inc	edx
	inc	dword [counter]
	mov	esi,ebp
	jmp	process_macro_arguments
      arguments_end:
	lodsb
	cmp	al,'{'
	je	macro_instructions_start
      find_macro_instructions:
	add	esi,14
	lodsb
	or	al,al
	jz	find_macro_instructions
	cmp	al,'{'
	jne near_o0 unexpected_characters
      macro_instructions_start:
	cmp	byte [edx],0
	jne near_o0 invalid_macro_arguments
	mov	dword [additional_memory],edi
	pop	edi
	mov	ecx,80000000h
	push	dword [current_line]
	mov	dword [macro_block],esi
	mov	dword [macro_block_line_number],ecx
	mov	eax,1
	xchg	eax,dword [counter]
	mov	dword [counter_limit],eax
	or	eax,eax
	jnz	process_macro_line
	mov	dword [counter_limit],1
      process_macro_line:
	mov	dword [current_line],edi
	mov	eax,[ebx+4]
	dec	eax
	stosd
	mov	eax,ecx
	stosd
	mov	eax,[esp]
	stosd
	or	byte [macro_status],40h
	push	ebx
	push	ecx
      process_macro:
	lodsb
	cmp	al,'}'
	je near_o0 macro_line_processed
	or	al,al
	jz near_o0 macro_line_processed
	cmp	al,1Ah
	je	process_macro_symbol
	and	byte [macro_status],~40h
	stosb
	cmp	al,22h
	jne	process_macro
      copy_macro_string:
	mov	ecx,[esi]
	add	ecx,4
	rep	movsb
	jmp	process_macro
      process_macro_symbol:
	push	esi
	push	edi
	test	byte [macro_status],40h
	jz	not_macro_directive
	movzx	ecx,byte [esi]
	inc	esi
	mov	edi,macro_directives
	call	get_symbol
	jnc	process_macro_directive
	dec	esi
	jmp	not_macro_directive
      process_macro_directive:
	movzx	edx,ax
	add	edx,preprocessor
	pop	edi
	pop	eax
	mov	byte [edi],0
	inc	edi
	pop	ecx
	pop	ebx
	jmp	edx
      not_macro_directive:
	and	byte [macro_status],~40h
	mov	eax,dword [counter]
	or	eax,eax
	jnz	check_for_macro_constant
	inc	eax
      check_for_macro_constant:
	shl	eax,8
	mov	al,[esi]
	inc	esi
	movzx	ebp,al
	mov	edx,dword [macro_constants]
	mov	ebx,esi
      scan_macro_constants:
	cmp	edx,dword [additional_memory]
	je	not_macro_constant
	cmp	eax,[edx]
	je	try_macro_constant
	cmp	ebp,[edx]
	jne	next_macro_constant
      try_macro_constant:
	mov	ecx,ebp
	mov	edi,[edx+4]
	repe	cmpsb
	je	macro_constant_found
	mov	esi,ebx
      next_macro_constant:
	add	edx,16
	jmp	scan_macro_constants
      macro_constant_found:
	cmp	dword [counter],0
	jne	replace_macro_constant
	mov	eax,[edx]
	shr	eax,8
	or	eax,eax
	jz	replace_macro_constant
	cmp	eax,dword [counter_limit]
	je	replace_macro_constant
	pop	edi
	mov	ecx,[edx+8]
	mov	esi,[edx+12]
	rep	movsb
	mov	byte [edi],','
	inc	edi
	mov	esi,ebx
	inc	eax
	shl	eax,8
	mov	al,[esi-1]
	push	edi
	jmp	scan_macro_constants
      replace_macro_constant:
	pop	edi
	pop	eax
	mov	ecx,[edx+8]
	mov	edx,[edx+12]
	xchg	esi,edx
	rep	movsb
	mov	esi,edx
	jmp	process_macro
      not_macro_constant:
	pop	edi
	pop	esi
	mov	al,1Ah
	stosb
	mov	al,[esi]
	inc	esi
	stosb
	cmp	byte [esi],'.'
	jne	copy_macro_symbol
	mov	ebx,dword [struc_name]
	or	ebx,ebx
	jz	copy_macro_symbol
	xchg	esi,ebx
	movzx	ecx,byte [esi-1]
	add	[edi-1],cl
	jc near_o0 name_too_long
	rep	movsb
	xchg	esi,ebx
      copy_macro_symbol:
	movzx	ecx,al
	rep	movsb
	jmp	process_macro
      macro_line_processed:
	mov	byte [edi],0
	inc	edi
	push	eax
	call	preprocess_line
	pop	eax
	pop	ecx
	pop	ebx
	cmp	al,'}'
	je near_o0 macro_block_processed
      process_next_line:
	inc	ecx
	add	esi,14
	jmp	process_macro_line
      local_symbols:
	lodsb
	cmp	al,1Ah
	jne near_o0 invalid_argument
	push	edi
	push	ecx
	movzx	ecx,byte [esi]
	inc	esi
	mov	edx,dword [additional_memory]
	mov	eax,dword [counter]
	shl	eax,8
	mov	al,cl
	mov	[edx],eax
	mov	[edx+4],esi
	movzx	eax,byte [_counter]
	mov	edi,dword [memory_end]
	sub	edi,eax
	sub	edi,ecx
	sub	edi,3
	mov	dword [memory_end],edi
	mov	[edx+12],edi
	add	al,cl
	jc near_o0 name_too_long
	inc	al
	jz near_o0 name_too_long
	mov	byte [edi],1Ah
	inc	edi
	mov	[edi],al
	inc	edi
	add	eax,2
	mov	[edx+8],eax
	add	edx,16
	cmp	edx,dword [labels_list]
	jae near_o0 out_of_memory
	mov	dword [additional_memory],edx
	rep	movsb
	mov	al,'?'
	stosb
	movzx	ecx,byte [_counter]
	push	esi
	mov	esi,_counter+1
	rep	movsb
	pop	esi
	pop	ecx
	pop	edi
	cmp	edi,dword [memory_end]
	jae near_o0 out_of_memory
	lodsb
	cmp	al,','
	je near_o0 local_symbols
	cmp	al,'}'
	je near_o0 macro_block_processed
	or	al,al
	jnz near_o0 extra_characters_on_line
	jmp	process_next_line
      common_block:
	call	close_macro_block
	jc near_o0 process_macro_line
	mov	dword [counter],0
	jmp	new_macro_block
      forward_block:
	call	close_macro_block
	jc near_o0 process_macro_line
	mov	dword [counter],1
	jmp	new_macro_block
      reverse_block:
	call	close_macro_block
	jc near_o0 process_macro_line
	mov	eax,dword [counter_limit]
	or	eax,80000000h
	mov	dword [counter],eax
      new_macro_block:
	mov	dword [macro_block],esi
	mov	dword [macro_block_line_number],ecx
	jmp	process_macro_line
      close_macro_block:
	push	ecx
	mov	eax,_counter
	call	increase_counter
	pop	ecx
	cmp	dword [counter],0
	je	block_closed
	jl	reverse_counter
	mov	eax,dword [counter]
	cmp	eax,dword [counter_limit]
	je	block_closed
	inc	dword [counter]
	jmp	continue_block
      reverse_counter:
	mov	eax,dword [counter]
	dec	eax
	cmp	eax,80000000h
	je	block_closed
	mov	dword [counter],eax
      continue_block:
	mov	esi,dword [macro_block]
	mov	ecx,dword [macro_block_line_number]
	stc
	ret
      block_closed:
	clc
	ret
      macro_block_processed:
	call	close_macro_block
	jc near_o0 process_macro_line
	and	byte [ebx+1],~80h
	pop	dword [current_line]
	mov	eax,dword [macro_constants]
	mov	dword [additional_memory],eax
	mov	byte [macro_status],0
	pop	dword [counter_limit]
	pop	dword [counter]
	pop	dword [macro_block_line_number]
	pop	dword [macro_block]
	pop	dword [macro_constants]
	jmp	line_preprocessed

increase_counter:
	movzx	ecx,byte [eax]
      counter_loop:
	call	increase_digit
	jnc	counter_ok
	mov	byte [eax+ecx],'0'
	loop	counter_loop
      counter_ok:
	ret
      increase_digit:
	inc	byte [eax+ecx]
	cmp	byte [eax+ecx],':'
	jb	digit_increased
	je	letter_digit
	cmp	byte [eax+ecx],'f'
	jbe	digit_increased
	stc
	ret
      letter_digit:
	mov	byte [eax+ecx],'a'
      digit_increased:
	clc
	ret

;%include '../parser.inc'

; flat assembler source
; Copyright (c) 1999-2001, Tomasz Grysztar
; All rights reserved.

parser:
	mov	eax,dword [memory_end]
	mov	dword [labels_list],eax
	mov	dword [current_locals_prefix],0
	mov	esi,dword [source_start]
	mov	edi,dword [code_start]
	push	dword [additional_memory]
     parser_loop:
	mov	dword [current_line],esi
	cmp	edi,dword [labels_list]
	jae near_o0 out_of_memory
	mov	al,0Fh
	stosb
	mov	eax,esi
	stosd
	add	esi,12
	call	parse_line
	cmp	esi,dword [code_start]
	jb	parser_loop
	xor	al,al
	stosb
	pop	dword [additional_memory]
	mov	eax,dword [code_start]
	mov	dword [source_start],eax
	mov	dword [code_start],edi
	ret

parse_line:
	mov	byte [parenthesis_stack],0
      instruction_start:
	cmp	byte [esi],1Ah
	jne near_o0 empty_instruction
	push	edi
	inc	esi
	movzx	ecx,byte [esi]
	inc	esi
	cmp	byte [esi+ecx],':'
	je near_o0 simple_label
	push	esi
	push	ecx
	add	esi,ecx
	cmp	byte [esi],1Ah
	je	check_for_data_label
	cmp	byte [esi],'='
	je	constant_label
	pop	ecx
	pop	esi
	jmp	get_main_instruction
      check_for_data_label:
	inc	esi
	movzx	ecx,byte [esi]
	inc	esi
	push	edi
	mov	edi,data_directives
	call	get_symbol
	pop	edi
	jnc	data_label
	pop	ecx
	pop	esi
      get_main_instruction:
	call	get_instruction
	jnc near_o0 parse_instruction
	mov	edi,data_directives
	call	get_symbol
	jnc	data_instruction
	mov	edi,symbols
	call	get_symbol
	pop	edi
	jc	unknown_instruction
	stosw
	jmp	parse_arguments
      data_instruction:
	movzx	ebx,ah
	mov	bx,[data_handlers+ebx*2]
	jmp	parse_instruction
      unknown_instruction:
	sub	esi,2
	jmp	parse_arguments
      constant_label:
	pop	ecx
	pop	esi
	pop	edi
	call	identify_label
	mov	byte [edi],3
	inc	edi
	stosd
	xor	al,al
	stosb
	inc	esi
	jmp	parse_arguments
      data_label:
	pop	ecx
	pop	ebx
	pop	edi
	push	ax
	push	esi
	mov	esi,ebx
	call	identify_label
	mov	byte [edi],2
	inc	edi
	stosd
	pop	esi
	pop	ax
	stosb
	push	edi
	jmp	data_instruction
      simple_label:
	pop	edi
	call	identify_label
	mov	byte [edi],2
	inc	edi
	stosd
	inc	esi
	xor	al,al
	stosb
	jmp	instruction_start
      identify_label:
	cmp	byte [esi],'.'
	je	local_label_name
	call	get_label_id
	mov	ebx,[eax+4]
	dec	ebx
	mov	dword [current_locals_prefix],ebx
	ret
      local_label_name:
	call	get_label_id
	ret
      parse_prefix_instruction:
	cmp	byte [esi],1Ah
	jne	parse_arguments
	push	edi
	inc	esi
	movzx	ecx,byte [esi]
	inc	esi
	jmp	get_main_instruction
      parse_label_directive:
	push	edi
	lodsb
	cmp	al,1Ah
	jne near_o0 invalid_argument
	movzx	ecx,byte [esi]
	lodsb
	pop	edi
	mov	al,2
	stosb
	call	identify_label
	stosd
	xor	al,al
	stosb
	jmp	parse_arguments
      parse_instruction:
	pop	edi
	mov	dl,al
	mov	al,1
	stosb
	mov	ax,bx
	stosw
	mov	al,dl
	stosb
	cmp	bx,prefix_instruction-assembler
	je	parse_prefix_instruction
	cmp	bx,end_directive-assembler
	je	parse_prefix_instruction
	cmp	bx,label_directive-assembler
	je	parse_label_directive
	cmp	bx,load_directive-assembler
	je	parse_label_directive
      parse_arguments:
	lodsb
	cmp	al,':'
	je near_o0 instruction_separator
	cmp	al,','
	je near_o0 separator
	cmp	al,'='
	je near_o0 separator
	cmp	al,'|'
	je near_o0 separator
	cmp	al,'&'
	je near_o0 separator
	cmp	al,'~'
	je near_o0 separator
	cmp	al,'>'
	je near_o0 greater
	cmp	al,'<'
	je near_o0 less
	cmp	al,')'
	je near_o0 close_expression
	or	al,al
	jz near_o0 line_parsed
	cmp	al,'['
	je near_o0 address_argument
	cmp	al,']'
	je near_o0 separator
	dec	esi
	cmp	al,1Ah
	jne near_o0 expression_argument
	push	edi
	mov	edi,directive_operators
	call	get_operator
	or	al,al
	jnz	operator_argument
	inc	esi
	movzx	ecx,byte [esi]
	inc	esi
	mov	edi,symbols
	call	get_symbol
	jnc	symbol_argument
	mov	edi,formatter_symbols
	call	get_symbol
	jnc	symbol_argument
	cmp	ecx,1
	jne	check_argument
	cmp	byte [esi],'?'
	jne	check_argument
	pop	edi
	movsb
	jmp	argument_parsed
      symbol_argument:
	pop	edi
	stosw
	jmp	argument_parsed
      operator_argument:
	pop	edi
	stosb
	cmp	al,80h
	je near_o0 forced_expression
	jmp	argument_parsed
      check_argument:
	push	esi
	push	ecx
	sub	esi,2
	mov	edi,single_operand_operators
	call	get_operator
	pop	ecx
	pop	esi
	or	al,al
	jnz	not_instruction
	call	get_instruction
	jnc near_o0 parse_instruction
	mov	edi,data_directives
	call	get_symbol
	jnc near_o0 data_instruction
      not_instruction:
	pop	edi
	sub	esi,2
      expression_argument:
	cmp	byte [esi],22h
	jne	not_string
	mov	eax,[esi+1]
	cmp	eax,8
	ja	string_argument
	lea	ebx,[esi+5+eax]
	push	ebx
	push	ecx
	push	esi
	push	edi
	mov	al,'('
	stosb
	call	convert_expression
	mov	al,')'
	stosb
	pop	eax
	pop	edx
	pop	ecx
	pop	ebx
	cmp	esi,ebx
	jne near_o0 expression_parsed
	mov	edi,eax
	mov	esi,edx
      string_argument:
	inc	esi
	mov	ax,'('
	stosw
	lodsd
	mov	ecx,eax
	stosd
	shr	ecx,1
	jnc	string_movsb_ok
	movsb
      string_movsb_ok:
	shr	ecx,1
	jnc	string_movsw_ok
	movsw
      string_movsw_ok:
	rep	movsd
	xor	al,al
	stosb
	jmp	argument_parsed
      not_string:
	cmp	byte [esi],'('
	jne	parse_expression
	push	esi
	push	edi
	inc	esi
	mov	al,'{'
	stosb
	inc	byte [parenthesis_stack]
	jmp	parse_arguments
      parse_expression:
      forced_expression:
	mov	al,'('
	stosb
      expression:
	call	convert_expression
	mov	al,')'
	stosb
	jmp	expression_parsed
      address_argument:
	mov	al,'['
	stosb
	cmp	word [esi],021Ah
	jne	convert_address
	push	esi
	add	esi,4
	lea	ebx,[esi+1]
	cmp	byte [esi],':'
	pop	esi
	jne	convert_address
	add	esi,2
	mov	ecx,2
	push	ebx
	push	edi
	mov	edi,symbols
	call	get_symbol
	pop	edi
	pop	esi
	jc near_o0 invalid_address
	cmp	al,10h
	jne near_o0 invalid_address
	mov	al,ah
	and	ah,11110000b
	cmp	ah,60h
	jne near_o0 invalid_address
	stosb
      convert_address:
	cmp	byte [esi],1Ah
	jne	convert_address_value
	push	esi
	lodsw
	movzx	ecx,ah
	push	edi
	mov	edi,address_sizes
	call	get_symbol
	pop	edi
	jc	no_size_prefix
	mov	al,ah
	add	al,70h
	stosb
	add	esp,4
	jmp	convert_address_value
      no_size_prefix:
	pop	esi
      convert_address_value:
	call	convert_expression
	lodsb
	cmp	al,']'
	jne near_o0 invalid_address
	stosb
	jmp	argument_parsed
      close_expression:
	mov	al,'}'
      separator:
	stosb
	jmp	argument_parsed
      instruction_separator:
	stosb
	jmp	instruction_start
      greater:
	cmp	byte [esi],'='
	jne	separator
	inc	esi
	mov	al,0xf2
	jmp	separator
      less:
	cmp	byte [edi-1],83h
	je	separator
	cmp	byte [esi],'>'
	je	not_equal
	cmp	byte [esi],'='
	jne	separator
	inc	esi
	mov	al,0xf3
	jmp	separator
      not_equal:
	inc	esi
	mov	al,0xf6
	jmp	separator
      argument_parsed:
	cmp	byte [parenthesis_stack],0
	je near_o0 parse_arguments
	dec	byte [parenthesis_stack]
	add	esp,8
	jmp	argument_parsed
      expression_parsed:
	cmp	byte [parenthesis_stack],0
	je near_o0 parse_arguments
	cmp	byte [esi],')'
	jne	argument_parsed
	dec	byte [parenthesis_stack]
	pop	edi
	pop	esi
	jmp	parse_expression
      empty_instruction:
	lodsb
	or	al,al
	jz	line_parsed
	cmp	al,':'
	je	empty_label
	cmp	al,3Bh
	je	skip_preprocessed_symbol
	dec	esi
	jmp	parse_arguments
      empty_label:
	mov	eax,_counter
	call	increase_counter
	mov	dword [current_locals_prefix],eax
	jmp	instruction_start
      skip_preprocessed_symbol:
	lodsb
	movzx	eax,al
	add	esi,eax
      skip_next:
	lodsb
	or	al,al
	jz	line_parsed
	cmp	al,1Ah
	je	skip_preprocessed_symbol
	cmp	al,22h
	je	skip_preprocessed_string
	jmp	skip_next
      skip_preprocessed_string:
	lodsd
	add	esi,eax
	jmp	skip_next
      line_parsed:
	cmp	byte [parenthesis_stack],0
	jne near_o0 invalid_expression
	ret

;%include '../assemble.inc'

; flat assembler source
; Copyright (c) 1999-2001, Tomasz Grysztar
; All rights reserved.

assembler:
	mov	edi,dword [labels_list]
	mov	ecx,dword [memory_end]
	sub	ecx,edi
	shr	ecx,2
	xor	eax,eax
	rep	stosd
	mov	byte [current_pass],0
	mov	dword [number_of_sections],0
	mov	byte [times_working],0
      assembler_loop:
	mov	eax,dword [labels_list]
	mov	dword [display_buffer],eax
	mov	eax,dword [additional_memory_end]
	mov	dword [structures_buffer],eax
	mov	byte [next_pass_needed],0
	mov	byte [output_format],0
	mov	dword [format_flags],0
	mov	byte [code_type],16
	mov	byte [reloc_labels],0
	mov	byte [virtual_data],0
	mov	esi,dword [source_start]
	mov	edi,dword [code_start]
	mov	dword [org_start],edi
	mov	dword [org_sib],0
	mov	dword [error_line],0
	mov	dword [counter],0
	mov	dword [number_of_relocations],0
      pass_loop:
	call	assemble_line
	jnc	pass_loop
	mov	eax,dword [structures_buffer]
	cmp	eax,dword [additional_memory_end]
	jne near_o0 unexpected_end_of_file
	jmp	pass_done
      pass_done:
	cmp	byte [next_pass_needed],0
	je	assemble_done
      next_pass:
	inc	byte [current_pass]
	cmp	byte [current_pass],100
	jae near_o0 code_cannot_be_generated
	jmp	assembler_loop
      pass_error:
	mov	dword [current_line],eax
	jmp	dword [error]
      assemble_done:
	mov	eax,dword [error_line]
	or	eax,eax
	jnz	pass_error
	call	flush_display_buffer
      assemble_ok:
	mov	eax,edi
	sub	eax,dword [code_start]
	mov	dword [real_code_size],eax
	cmp	edi,dword [undefined_data_end]
	jne	calculate_code_size
	mov	edi,dword [undefined_data_start]
      calculate_code_size:
	sub	edi,dword [code_start]
	mov	dword [code_size],edi
	mov	dword [written_size],0
	mov	edx,dword [output_file]
	call	create
	jc near_o0 write_failed
      write_code:
	mov	edx,dword [code_start]
	mov	ecx,dword [code_size]
	add	dword [written_size],ecx
	call	write
	jc near_o0 write_failed
	call	close
	ret

assemble_line:
	mov	eax,dword [display_buffer]
	sub	eax,100h
	cmp	edi,eax
	jae near_o0 out_of_memory
	lodsb
	or	al,al
	jz near_o0 source_end
	cmp	al,1
	je near_o0 assemble_instruction
	cmp	al,2
	je	define_label
	cmp	al,3
	je near_o0 define_constant
	cmp	al,0Fh
	je	new_line
	cmp	al,13h
	je	code_type_setting
	cmp	al,10h
	jne near_o0 illegal_instruction
	lodsb
	mov	ah,al
	shr	ah,4
	cmp	ah,6
	jne near_o0 illegal_instruction
	and	al,1111b
	mov	byte [segment_register],al
	call	store_segment_prefix
	jmp	assemble_line
      code_type_setting:
	lodsb
	mov	byte [code_type],al
	jmp	line_assembled
      new_line:
	lodsd
	mov	dword [current_line],eax
	jmp	assemble_line
      define_label:
	lodsd
	mov	ebx,eax
	lodsb
	mov	dl,al
	xor	ch,ch
	cmp	byte [reloc_labels],0
	je	label_reloc_ok
	mov	ch,2
      label_reloc_ok:
	xchg	ch,[ebx+11]
	mov	al,byte [current_pass]
	test	byte [ebx+8],1
	jz	new_label
	cmp	al,[ebx+9]
	je near_o0 symbol_already_defined
	mov	[ebx+9],al
	mov	eax,edi
	sub	eax,dword [org_start]
	xchg	[ebx],eax
	cdq
	xchg	[ebx+4],edx
	mov	ebp,dword [org_sib]
	xchg	[ebx+12],ebp
	cmp	byte [current_pass],0
	je near_o0 assemble_line
	cmp	eax,[ebx]
	jne	changed_label
	cmp	edx,[ebx+4]
	jne	changed_label
	cmp	ebp,[ebx+12]
	jne	changed_label
	cmp	ch,[ebx+11]
	jne	changed_label
	jmp	assemble_line
      changed_label:
	or	byte [next_pass_needed],-1
	jmp	assemble_line
      new_label:
	or	byte [ebx+8],1
	mov	[ebx+9],al
	mov	byte [ebx+10],dl
	mov	eax,edi
	sub	eax,dword [org_start]
	mov	[ebx],eax
	cdq
	mov	dword [ebx+4],edx
	mov	eax,dword [org_sib]
	mov	[ebx+12],eax
	jmp	assemble_line
      define_constant:
	lodsd
	push	eax
	lodsb
	push	ax
	call	get_value
	pop	bx
	mov	ch,bl
	pop	ebx
      make_constant:
	mov	cl,byte [current_pass]
	test	byte [ebx+8],1
	jz	new_constant
	cmp	cl,[ebx+9]
	jne	redefine_constant
	test	byte [ebx+8],2
	jz near_o0 symbol_already_defined
	or	byte [ebx+8],4
      redefine_constant:
	mov	[ebx+9],cl
	xchg	[ebx],eax
	xchg	[ebx+4],edx
	mov	cl,byte [value_type]
	xchg	[ebx+11],cl
	cmp	byte [current_pass],0
	je near_o0 assemble_line
	cmp	eax,[ebx]
	jne	changed_constant
	cmp	edx,[ebx+4]
	jne	changed_constant
	cmp	cl,[ebx+11]
	jne	changed_constant
	jmp	assemble_line
      changed_constant:
	test	byte [ebx+8],4
	jnz near_o0 assemble_line
	or	byte [next_pass_needed],-1
	jmp	assemble_line
      new_constant:
	or	byte [ebx+8],1+2
	mov	word [ebx+9],cx
	mov	[ebx],eax
	mov	[ebx+4],edx
	mov	cl,byte [value_type]
	mov	[ebx+11],cl
	jmp	assemble_line
      assemble_instruction:
	mov	byte [operand_size],0
	mov	byte [forced_size],0
	lodsw
	movzx	ebx,ax
	add	ebx,assembler
	lodsb
	jmp	ebx
      instruction_assembled:
	mov	al,[esi]
	cmp	al,0Fh
	je	line_assembled
	or	al,al
	jnz near_o0 extra_characters_on_line
      line_assembled:
	clc
	ret
      source_end:
	stc
	ret
skip_line:
	call	skip_symbol
	jnc	skip_line
	ret
skip_symbol:
	lodsb
	or	al,al
	jz near_o0 nothing_to_skip
	cmp	al,0Fh
	je near_o0 nothing_to_skip
	cmp	al,1
	je	skip_instruction
	cmp	al,2
	je	skip_label
	cmp	al,3
	je	skip_label
	cmp	al,20h
	jb	skip_assembler_symbol
	cmp	al,'('
	je	skip_expression
	cmp	al,'['
	je	skip_address
      skip_done:
	clc
	ret
      skip_label:
	add	esi,2
      skip_instruction:
	add	esi,2
      skip_assembler_symbol:
	inc	esi
	jmp	skip_done
      skip_address:
	mov	al,[esi]
	and	al,11110000b
	cmp	al,60h
	jb	skip_expression
	cmp	al,70h
	ja	skip_expression
	inc	esi
	jmp	skip_address
      skip_expression:
	lodsb
	or	al,al
	jz	skip_string
	cmp	al,'.'
	je	skip_fp_value
	cmp	al,')'
	je	skip_done
	cmp	al,']'
	je	skip_done
	cmp	al,0Fh
	je	skip_expression
	cmp	al,10h
	je	skip_register
	cmp	al,11h
	je	skip_label_value
	cmp	al,80h
	jae	skip_expression
	movzx	eax,al
	add	esi,eax
	jmp	skip_expression
      skip_label_value:
	add	esi,3
      skip_register:
	inc	esi
	jmp	skip_expression
      skip_fp_value:
	add	esi,12
	jmp	skip_done
      skip_string:
	lodsd
	add	esi,eax
	inc	esi
	jmp	skip_done
      nothing_to_skip:
	dec	esi
	stc
	ret

org_directive:
	lodsb
	cmp	al,'('
	jne near_o0 invalid_argument
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	mov	byte [reloc_labels],0
	mov	dl,byte [value_type]
	or	dl,dl
	jz	org_ok
	cmp	dl,2
	jne near_o0 invalid_use_of_symbol
	or	byte [reloc_labels],-1
      org_ok:
	mov	ecx,edi
	sub	ecx,eax
	mov	dword [org_start],ecx
	mov	dword [org_sib],0
	jmp	instruction_assembled
label_directive:
	lodsb
	cmp	al,2
	jne near_o0 invalid_argument
	lodsd
	inc	esi
	mov	ebx,eax
	xor	ch,ch
	cmp	byte [esi],11h
	jne	label_size_ok
	lodsw
	mov	ch,ah
      label_size_ok:
	mov	eax,edi
	sub	eax,dword [org_start]
	mov	ebp,dword [org_sib]
	cmp	byte [esi],80h
	jne	define_free_label
	inc	esi
	lodsb
	cmp	al,'('
	jne near_o0 invalid_argument
	mov	byte [ebx+11],0
	push	ebx
	push	cx
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_address_value
	or	bh,bh
	setnz	ch
	xchg	ch,cl
	mov	bp,cx
	shl	ebp,16
	mov	bl,bh
	mov	bp,bx
	pop	cx
	pop	ebx
	mov	dl,al
	mov	dh,byte [value_type]
	cmp	dh,1
	je near_o0 invalid_use_of_symbol
	jb	free_label_reloc_ok
      define_free_label:
	xor	dh,dh
	cmp	byte [reloc_labels],0
	je	free_label_reloc_ok
	mov	dh,2
      free_label_reloc_ok:
	xchg	dh,[ebx+11]
	mov	cl,byte [current_pass]
	test	byte [ebx+8],1
	jz	new_free_label
	cmp	cl,[ebx+9]
	je near_o0 symbol_already_defined
	mov	ch,dh
	mov	[ebx+9],cl
	xchg	[ebx],eax
	cdq
	xchg	[ebx+4],edx
	xchg	[ebx+12],ebp
	cmp	byte [current_pass],0
	je near_o0 instruction_assembled
	cmp	eax,[ebx]
	jne	changed_free_label
	cmp	edx,[ebx+4]
	jne	changed_free_label
	cmp	ebp,[ebx+12]
	jne	changed_free_label
	cmp	ch,[ebx+11]
	jne	changed_free_label
	jmp	instruction_assembled
      changed_free_label:
	or	byte [next_pass_needed],-1
	jmp	instruction_assembled
      new_free_label:
	or	byte [ebx+8],1
	mov	[ebx+9],cl
	mov	byte [ebx+10],ch
	mov	[ebx],eax
	cdq
	mov	dword [ebx+4],edx
	mov	[ebx+12],ebp
	jmp	instruction_assembled
load_directive:
	lodsb
	cmp	al,2
	jne near_o0 invalid_argument
	lodsd
	inc	esi
	push	eax
	mov	al,1
	cmp	byte [esi],11h
	jne	load_size_ok
	lodsb
	lodsb
      load_size_ok:
	cmp	al,8
	ja near_o0 invalid_value
	mov	byte [operand_size],al
	lodsb
	cmp	al,82h
	jne near_o0 invalid_argument
	lodsw
	cmp	ax,'('
	jne near_o0 invalid_argument
	lea	edx,[esi+4]
	mov	eax,[esi]
	lea	esi,[esi+4+eax+1]
	call	open
	jc near_o0 file_not_found
	mov	al,2
	xor	edx,edx
	call	lseek
	xor	edx,edx
	cmp	byte [esi],':'
	jne	load_position_ok
	inc	esi
	cmp	byte [esi],'('
	jne near_o0 invalid_argument
	inc	esi
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	push	ebx
	call	get_dword_value
	pop	ebx
	mov	edx,eax
      load_position_ok:
	xor	al,al
	call	lseek
	mov	dword [value],0
	mov	dword [value+4],0
	movzx	ecx,byte [operand_size]
	mov	edx,value
	call	read
	jc near_o0 error_reading_file
	call	close
	mov	eax,dword [value]
	mov	edx,dword [value+4]
	pop	ebx
	xor	ch,ch
	mov	byte [value_type],0
	jmp	make_constant
display_directive:
	push	esi
	push	edi
      prepare_display:
	lodsb
	cmp	al,'('
	jne near_o0 invalid_argument
	cmp	byte [esi],0
	jne	display_byte
	inc	esi
	lodsd
	mov	ecx,eax
	rep	movsb
	inc	esi
	jmp	display_next
      display_byte:
	call	get_byte_value
	stosb
      display_next:
	cmp	edi,dword [display_buffer]
	jae near_o0 out_of_memory
	lodsb
	or	al,al
	jz	do_display
	cmp	al,0Fh
	je	do_display
	cmp	al,','
	jne near_o0 extra_characters_on_line
	jmp	prepare_display
      do_display:
	dec	esi
	mov	ebp,edi
	pop	edi
	pop	ebx
	push	esi
	push	edi
	mov	esi,edi
	mov	ecx,ebp
	sub	ecx,esi
	mov	edi,dword [display_buffer]
	sub	edi,ecx
	sub	edi,4
	cmp	edi,esi
	jbe near_o0 out_of_memory
	mov	dword [display_buffer],edi
	mov	eax,ecx
	rep	movsb
	stosd
	pop	edi
	pop	esi
	jmp	instruction_assembled
flush_display_buffer:
	mov	eax,dword [display_buffer]
	or	eax,eax
	jz	display_done
	mov	esi,dword [labels_list]
	cmp	esi,eax
	je	display_done
	mov	word [value],0
      display_messages:
	sub	esi,4
	mov	ecx,[esi]
	mov	ax,word [value]
	jecxz	last_bytes_ok
	mov	al,ah
	mov	ah,[esi-1]
	cmp	ecx,1
	je	last_bytes_ok
	mov	al,[esi-2]
      last_bytes_ok:
	mov	word [value],ax
	sub	esi,ecx
	push	esi
	call	display_block
	pop	esi
	cmp	esi,dword [display_buffer]
	jne	display_messages
	mov	ax,0A0Dh
	cmp	word [value],ax
	je	display_ok
	mov	esi,value
	mov	[esi],ax
	mov	ecx,2
	call	display_block
      display_ok:
	mov	eax,dword [labels_list]
	mov	dword [display_buffer],eax
      display_done:
	ret
times_directive:
	lodsb
	cmp	al,'('
	jne near_o0 invalid_argument
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	cmp	byte [value_type],0
	jne near_o0 invalid_use_of_symbol
	or	eax,eax
	jz	zero_times
	cmp	byte [esi],':'
	jne	times_argument_ok
	inc	esi
      times_argument_ok:
	push	dword [counter]
	push	dword [counter_limit]
	mov	dword [counter_limit],eax
	mov	dword [counter],1
      times_loop:
	push	esi
	or	byte [times_working],-1
	call	assemble_line
	mov	eax,dword [counter_limit]
	cmp	dword [counter],eax
	je	times_done
	inc	dword [counter]
	pop	esi
	jmp	times_loop
      times_done:
	mov	byte [times_working],0
	pop	eax
	pop	dword [counter_limit]
	pop	dword [counter]
	jmp	instruction_assembled
      zero_times:
	call	skip_line
	jmp	instruction_assembled

virtual_directive:
	lodsb
	cmp	al,80h
	jne	virtual_at_current
	lodsb
	cmp	al,'('
	jne near_o0 invalid_argument
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_address_value
	xor	ch,ch
	or	bh,bh
	jz	set_virtual
	mov	ch,1
	jmp	set_virtual
      virtual_at_current:
	dec	esi
	mov	eax,edi
	sub	eax,dword [org_start]
	xor	bx,bx
	xor	cx,cx
	mov	byte [value_type],0
	cmp	byte [reloc_labels],0
	je	set_virtual
	mov	byte [value_type],2
      set_virtual:
	mov	edx,dword [org_sib]
	mov	byte [org_sib],bh
	mov	byte [org_sib+1],bl
	mov	byte [org_sib+2],ch
	mov	byte [org_sib+3],cl
	call	allocate_structure_data
	mov	word [ebx],virtual_directive-assembler
	neg	eax
	add	eax,edi
	xchg	dword [org_start],eax
	mov	[ebx+4],eax
	mov	[ebx+8],edx
	mov	al,byte [virtual_data]
	mov	[ebx+2],al
	mov	al,byte [reloc_labels]
	mov	[ebx+3],al
	mov	[ebx+0Ch],edi
	or	byte [virtual_data],-1
	mov	byte [reloc_labels],0
	cmp	byte [value_type],1
	je near_o0 invalid_use_of_symbol
	cmp	byte [value_type],2
	jne near_o0 instruction_assembled
	or	byte [reloc_labels],-1
	jmp	instruction_assembled
      allocate_structure_data:
	mov	ebx,dword [structures_buffer]
	sub	ebx,10h
	cmp	ebx,dword [additional_memory]
	jb near_o0 out_of_memory
	mov	dword [structures_buffer],ebx
	ret
      find_structure_data:
	mov	ebx,dword [structures_buffer]
      scan_structures:
	cmp	ebx,dword [additional_memory_end]
	je	no_such_structure
	cmp	ax,[ebx]
	jne	next_structure
	clc
	ret
      next_structure:
	cmp	ax,repeat_directive-assembler
	jne	if_structure_ok
	cmp	word [ebx],if_directive-assembler
	je	no_such_structure
      if_structure_ok:
	cmp	ax,if_directive-assembler
	jne	repeat_structure_ok
	cmp	word [ebx],repeat_directive-assembler
	je	no_such_structure
      repeat_structure_ok:
	add	ebx,10h
	jmp	scan_structures
      no_such_structure:
	stc
	ret
      end_virtual:
	call	find_structure_data
	jc near_o0 unexpected_instruction
	mov	al,[ebx+2]
	mov	byte [virtual_data],al
	mov	al,[ebx+3]
	mov	byte [reloc_labels],al
	mov	eax,[ebx+4]
	mov	dword [org_start],eax
	mov	eax,[ebx+8]
	mov	dword [org_sib],eax
	mov	edi,[ebx+0Ch]
      remove_structure_data:
	push	esi
	push	edi
	mov	esi,dword [structures_buffer]
	mov	ecx,ebx
	sub	ecx,esi
	lea	edi,[esi+10h]
	mov	dword [structures_buffer],edi
	shr	ecx,2
	rep	movsd
	pop	edi
	pop	esi
	jmp	instruction_assembled
repeat_directive:
	cmp	byte [times_working],0
	jne near_o0 unexpected_instruction
	lodsb
	cmp	al,'('
	jne near_o0 invalid_argument
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	cmp	byte [value_type],0
	jne near_o0 invalid_use_of_symbol
	or	eax,eax
	jz	zero_repeat
	call	allocate_structure_data
	mov	word [ebx],repeat_directive-assembler
	xchg	eax,dword [counter_limit]
	mov	[ebx+4],eax
	mov	eax,1
	xchg	eax,dword [counter]
	mov	[ebx+8],eax
	mov	[ebx+0Ch],esi
	jmp	instruction_assembled
      end_repeat:
	cmp	byte [times_working],0
	jne near_o0 unexpected_instruction
	call	find_structure_data
	jc near_o0 unexpected_instruction
	mov	eax,dword [counter_limit]
	inc	dword [counter]
	cmp	dword [counter],eax
	jbe	continue_repeating
	mov	eax,[ebx+4]
	mov	dword [counter_limit],eax
	mov	eax,[ebx+8]
	mov	dword [counter],eax
	jmp	remove_structure_data
      continue_repeating:
	mov	esi,[ebx+0Ch]
	jmp	instruction_assembled
      zero_repeat:
	mov	al,[esi]
	or	al,al
	jz near_o0 unexpected_end_of_file
	cmp	al,0Fh
	jne near_o0 extra_characters_on_line
	call	find_end_repeat
	jmp	instruction_assembled
      find_end_repeat:
	call	find_structure_end
	cmp	ax,repeat_directive-assembler
	jne near_o0 unexpected_instruction
	ret
      find_structure_end:
	call	skip_line
	lodsb
	cmp	al,0Fh
	jne near_o0 unexpected_end_of_file
	lodsd
	mov	dword [current_line],eax
      skip_labels:
	cmp	byte [esi],2
	jne	labels_ok
	add	esi,6
	jmp	skip_labels
      labels_ok:
	cmp	byte [esi],1
	jne	find_structure_end
	mov	ax,[esi+1]
	cmp	ax,prefix_instruction-assembler
	je	find_structure_end
	add	esi,4
	cmp	ax,repeat_directive-assembler
	je	skip_repeat
	cmp	ax,if_directive-assembler
	je near_o0 skip_if
	cmp	ax,else_directive-assembler
	je	structure_end
	cmp	ax,end_directive-assembler
	jne	find_structure_end
	cmp	byte [esi],1
	jne	find_structure_end
	mov	ax,[esi+1]
	add	esi,4
	cmp	ax,repeat_directive-assembler
	je	structure_end
	cmp	ax,if_directive-assembler
	jne	find_structure_end
      structure_end:
	ret
      skip_repeat:
	call	find_end_repeat
	jmp	find_structure_end
if_directive:
	cmp	byte [times_working],0
	jne near_o0 unexpected_instruction
	call	calculate_logical_expression
	mov	dl,al
	mov	al,[esi]
	or	al,al
	jz near_o0 unexpected_end_of_file
	cmp	al,0Fh
	jne near_o0 extra_characters_on_line
	or	dl,dl
	jnz	if_true
	call	find_else
	jc near_o0 instruction_assembled
	mov	al,[esi]
	cmp	al,1
	jne	else_true
	cmp	word [esi+1],if_directive-assembler
	jne	else_true
	add	esi,4
	jmp	if_directive
      if_true:
	call	allocate_structure_data
	mov	word [ebx],if_directive-assembler
	mov	byte [ebx+2],0
	jmp	instruction_assembled
      else_true:
	or	al,al
	jz near_o0 unexpected_end_of_file
	cmp	al,0Fh
	jne near_o0 extra_characters_on_line
	call	allocate_structure_data
	mov	word [ebx],if_directive-assembler
	or	byte [ebx+2],-1
	jmp	instruction_assembled
      else_directive:
	cmp	byte [times_working],0
	jne near_o0 unexpected_instruction
	mov	ax,if_directive-assembler
	call	find_structure_data
	jc near_o0 unexpected_instruction
	cmp	byte [ebx+2],0
	jne near_o0 unexpected_instruction
      found_else:
	mov	al,[esi]
	cmp	al,1
	jne	skip_else
	cmp	word [esi+1],if_directive-assembler
	jne	skip_else
	add	esi,4
	call	find_else
	jnc	found_else
	jmp	remove_structure_data
      skip_else:
	or	al,al
	jz near_o0 unexpected_end_of_file
	cmp	al,0Fh
	jne near_o0 extra_characters_on_line
	call	find_end_if
	jmp	remove_structure_data
      end_if:
	cmp	byte [times_working],0
	jne near_o0 unexpected_instruction
	call	find_structure_data
	jc near_o0 unexpected_instruction
	jmp	remove_structure_data
      skip_if:
	call	find_else
	jc near_o0 find_structure_end
	cmp	byte [esi],1
	jne	skip_after_else
	cmp	word [esi+1],if_directive-assembler
	jne	skip_after_else
	add	esi,4
	jmp	skip_if
      skip_after_else:
	call	find_end_if
	jmp	find_structure_end
      find_else:
	call	find_structure_end
	cmp	ax,else_directive-assembler
	je	else_found
	cmp	ax,if_directive-assembler
	jne near_o0 unexpected_instruction
	stc
	ret
      else_found:
	clc
	ret
      find_end_if:
	call	find_structure_end
	cmp	ax,if_directive-assembler
	jne near_o0 unexpected_instruction
	ret
end_directive:
	lodsb
	cmp	al,1
	jne near_o0 invalid_argument
	lodsw
	inc	esi
	cmp	ax,virtual_directive-assembler
	je near_o0 end_virtual
	cmp	ax,repeat_directive-assembler
	je near_o0 end_repeat
	cmp	ax,if_directive-assembler
	je near_o0 end_if
	jmp	invalid_argument

data_bytes:
	lodsb
	cmp	al,'('
	je	get_byte
	cmp	al,'?'
	jne near_o0 invalid_argument
	mov	eax,edi
	mov	byte [edi],0
	inc	edi
	call	undefined_data
	jmp	byte_ok
      get_byte:
	cmp	byte [esi],0
	je	get_string
	call	get_byte_value
	stosb
      byte_ok:
	cmp	edi,dword [display_buffer]
	jae near_o0 out_of_memory
	lodsb
	or	al,al
	jz	data_end
	cmp	al,0Fh
	je	data_end
	cmp	al,','
	jne near_o0 extra_characters_on_line
	jmp	data_bytes
      data_end:
	dec	esi
	jmp	instruction_assembled
      get_string:
	inc	esi
	lodsd
	mov	ecx,eax
	rep	movsb
	inc	esi
	jmp	byte_ok
      undefined_data:
	cmp	byte [virtual_data],0
	je	mark_undefined_data
	ret
      mark_undefined_data:
	cmp	eax,dword [undefined_data_end]
	je	undefined_data_ok
	mov	dword [undefined_data_start],eax
      undefined_data_ok:
	mov	dword [undefined_data_end],edi
	ret
data_unicode:
	or	byte [base_code],-1
	jmp	get_words_data
data_words:
	mov	byte [base_code],0
      get_words_data:
	lodsb
	cmp	al,'('
	je	get_word
	cmp	al,'?'
	jne near_o0 invalid_argument
	mov	eax,edi
	mov	word [edi],0
	scasw
	call	undefined_data
	jmp	word_ok
      get_word:
	cmp	byte [base_code],0
	je	word_data_value
	cmp	byte [esi],0
	je	word_string
      word_data_value:
	call	get_word_value
	call	mark_relocation
	stosw
      word_ok:
	cmp	edi,dword [display_buffer]
	jae near_o0 out_of_memory
	lodsb
	or	al,al
	jz near_o0 data_end
	cmp	al,0Fh
	je near_o0 data_end
	cmp	al,','
	jne near_o0 extra_characters_on_line
	jmp	get_words_data
      word_string:
	inc	esi
	lodsd
	mov	ecx,eax
	jecxz	word_string_ok
	xor	ah,ah
      copy_word_string:
	lodsb
	stosw
	loop	copy_word_string
      word_string_ok:
	inc	esi
	jmp	word_ok
data_dwords:
	lodsb
	cmp	al,'('
	je	get_dword
	cmp	al,'?'
	jne near_o0 invalid_argument
	mov	eax,edi
	mov	dword [edi],0
	scasd
	call	undefined_data
	jmp	dword_ok
      get_dword:
	push	esi
	call	get_dword_value
	pop	ebx
	cmp	byte [esi],':'
	je	complex_dword
	call	mark_relocation
	stosd
	jmp	dword_ok
      complex_dword:
	mov	esi,ebx
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_word_value
	mov	dx,ax
	inc	esi
	lodsb
	cmp	al,'('
	jne near_o0 invalid_operand
	mov	al,byte [value_type]
	push	ax
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_word_value
	call	mark_relocation
	stosw
	pop	ax
	mov	byte [value_type],al
	mov	ax,dx
	call	mark_relocation
	stosw
      dword_ok:
	cmp	edi,dword [display_buffer]
	jae near_o0 out_of_memory
	lodsb
	or	al,al
	jz near_o0 data_end
	cmp	al,0Fh
	je near_o0 data_end
	cmp	al,','
	jne near_o0 extra_characters_on_line
	jmp	data_dwords
data_pwords:
	lodsb
	cmp	al,'('
	je	get_pword
	cmp	al,'?'
	jne near_o0 invalid_argument
	mov	eax,edi
	mov	dword [edi],0
	scasd
	mov	word [edi],0
	scasw
	call	undefined_data
	jmp	pword_ok
      get_pword:
	push	esi
	call	get_pword_value
	pop	ebx
	cmp	byte [esi],':'
	je	complex_pword
	call	mark_relocation
	stosd
	mov	ax,dx
	stosw
	jmp	pword_ok
      complex_pword:
	mov	esi,ebx
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_word_value
	mov	dx,ax
	inc	esi
	lodsb
	cmp	al,'('
	jne near_o0 invalid_operand
	mov	al,byte [value_type]
	push	ax
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	call	mark_relocation
	stosd
	pop	ax
	mov	byte [value_type],al
	mov	ax,dx
	call	mark_relocation
	stosw
      pword_ok:
	cmp	edi,dword [display_buffer]
	jae near_o0 out_of_memory
	lodsb
	or	al,al
	jz near_o0 data_end
	cmp	al,0Fh
	je near_o0 data_end
	cmp	al,','
	jne near_o0 extra_characters_on_line
	jmp	data_pwords
data_qwords:
	lodsb
	cmp	al,'('
	je	get_qword
	cmp	al,'?'
	jne near_o0 invalid_argument
	mov	eax,edi
	mov	dword [edi],0
	scasd
	mov	dword [edi],0
	scasd
	call	undefined_data
	jmp	qword_ok
      get_qword:
	call	get_qword_value
	call	mark_relocation
	stosd
	mov	eax,edx
	stosd
      qword_ok:
	cmp	edi,dword [display_buffer]
	jae near_o0 out_of_memory
	lodsb
	or	al,al
	jz near_o0 data_end
	cmp	al,0Fh
	je near_o0 data_end
	cmp	al,','
	jne near_o0 extra_characters_on_line
	jmp	data_qwords
data_twords:
	lodsb
	cmp	al,'('
	je	get_tbyte
	cmp	al,'?'
	jne near_o0 invalid_argument
	mov	eax,edi
	mov	dword [edi],0
	scasd
	mov	dword [edi],0
	scasd
	mov	word [edi],0
	scasw
	call	undefined_data
	jmp	tbyte_ok
      get_tbyte:
	lodsb
	cmp	al,'.'
	jne near_o0 invalid_value
	cmp	word [esi+8],8000h
	je	fp_zero_tbyte
	mov	eax,[esi]
	stosd
	mov	eax,[esi+4]
	stosd
	mov	ax,[esi+8]
	add	ax,3FFFh
	cmp	ax,8000h
	jae near_o0 value_out_of_range
	mov	bl,[esi+11]
	shl	bx,15
	or	ax,bx
	stosw
	add	esi,12
	jmp	tbyte_ok
      fp_zero_tbyte:
	xor	eax,eax
	stosd
	stosd
	stosw
	add	esi,12
      tbyte_ok:
	cmp	edi,dword [display_buffer]
	jae near_o0 out_of_memory
	lodsb
	or	al,al
	jz near_o0 data_end
	cmp	al,0Fh
	je near_o0 data_end
	cmp	al,','
	jne near_o0 extra_characters_on_line
	jmp	data_twords
data_file:
	lodsw
	cmp	ax,'('
	jne near_o0 invalid_argument
	lea	edx,[esi+4]
	mov	eax,[esi]
	lea	esi,[esi+4+eax+1]
	call	open
	jc near_o0 file_not_found
	mov	al,2
	xor	edx,edx
	call	lseek
	push	eax
	xor	edx,edx
	cmp	byte [esi],':'
	jne	position_ok
	inc	esi
	cmp	byte [esi],'('
	jne near_o0 invalid_argument
	inc	esi
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	push	ebx
	call	get_dword_value
	pop	ebx
	mov	edx,eax
	sub	[esp],edx
      position_ok:
	cmp	byte [esi],','
	jne	size_ok
	inc	esi
	cmp	byte [esi],'('
	jne near_o0 invalid_argument
	inc	esi
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	push	ebx
	push	edx
	call	get_dword_value
	pop	edx
	pop	ebx
	mov	[esp],eax
      size_ok:
	cmp	byte [next_pass_needed],0
	jne	file_reserve
	xor	al,al
	call	lseek
	pop	ecx
	mov	edx,edi
	add	edi,ecx
	jc near_o0 out_of_memory
	cmp	edi,dword [display_buffer]
	jae near_o0 out_of_memory
	call	read
	jc near_o0 error_reading_file
	call	close
      check_for_next_name:
	lodsb
	cmp	al,','
	je near_o0 data_file
	dec	esi
	jmp	instruction_assembled
      file_reserve:
	call	close
	pop	ecx
	add	edi,ecx
	jc near_o0 out_of_memory
	cmp	edi,dword [display_buffer]
	jae near_o0 out_of_memory
	jmp	check_for_next_name
reserve_bytes:
	lodsb
	cmp	al,'('
	jne near_o0 invalid_argument
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	cmp	byte [value_type],0
	jne near_o0 invalid_use_of_symbol
	cmp	eax,0
	jl	reserve_negative
	mov	ecx,eax
	mov	edx,ecx
	add	edx,edi
	jc near_o0 out_of_memory
	cmp	edx,dword [display_buffer]
	jae near_o0 out_of_memory
	push	edi
	cmp	byte [next_pass_needed],0
	je	zero_bytes
	add	edi,ecx
	jmp	reserved_data
      zero_bytes:
	xor	eax,eax
	shr	ecx,1
	jnc	bytes_stosb_ok
	stosb
      bytes_stosb_ok:
	shr	ecx,1
	jnc	bytes_stosw_ok
	stosw
      bytes_stosw_ok:
	rep	stosd
      reserved_data:
	pop	eax
	call	undefined_data
	jmp	instruction_assembled
      reserve_negative:
	cmp	dword [error_line],0
	jne near_o0 instruction_assembled
	mov	eax,dword [current_line]
	mov	dword [error_line],eax
	mov	dword [error],invalid_value
	jmp	instruction_assembled
reserve_words:
	lodsb
	cmp	al,'('
	jne near_o0 invalid_argument
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	cmp	byte [value_type],0
	jne near_o0 invalid_use_of_symbol
	cmp	eax,0
	jl	reserve_negative
	mov	ecx,eax
	mov	edx,ecx
	shl	edx,1
	jc near_o0 out_of_memory
	add	edx,edi
	jc near_o0 out_of_memory
	cmp	edx,dword [display_buffer]
	jae near_o0 out_of_memory
	push	edi
	cmp	byte [next_pass_needed],0
	je	zero_words
	lea	edi,[edi+ecx*2]
	jmp	reserved_data
      zero_words:
	xor	eax,eax
	shr	ecx,1
	jnc	words_stosw_ok
	stosw
      words_stosw_ok:
	rep	stosd
	jmp	reserved_data
reserve_dwords:
	lodsb
	cmp	al,'('
	jne near_o0 invalid_argument
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	cmp	byte [value_type],0
	jne near_o0 invalid_use_of_symbol
	cmp	eax,0
	jl near_o0 reserve_negative
	mov	ecx,eax
	mov	edx,ecx
	shl	edx,1
	jc near_o0 out_of_memory
	shl	edx,1
	jc near_o0 out_of_memory
	add	edx,edi
	jc near_o0 out_of_memory
	cmp	edx,dword [display_buffer]
	jae near_o0 out_of_memory
	push	edi
	cmp	byte [next_pass_needed],0
	je	zero_dwords
	lea	edi,[edi+ecx*4]
	jmp	reserved_data
      zero_dwords:
	xor	eax,eax
	rep	stosd
	jmp	reserved_data
reserve_pwords:
	lodsb
	cmp	al,'('
	jne near_o0 invalid_argument
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	cmp	byte [value_type],0
	jne near_o0 invalid_use_of_symbol
	cmp	eax,0
	jl near_o0 reserve_negative
	mov	ecx,eax
	shl	ecx,1
	jc near_o0 out_of_memory
	add	ecx,eax
	mov	edx,ecx
	shl	edx,1
	jc near_o0 out_of_memory
	add	edx,edi
	jc near_o0 out_of_memory
	cmp	edx,dword [display_buffer]
	jae near_o0 out_of_memory
	push	edi
	cmp	byte [next_pass_needed],0
	je near_o0 zero_words
	lea	edi,[edi+ecx*2]
	jmp	reserved_data
reserve_qwords:
	lodsb
	cmp	al,'('
	jne near_o0 invalid_argument
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	cmp	byte [value_type],0
	jne near_o0 invalid_use_of_symbol
	cmp	eax,0
	jl near_o0 reserve_negative
	mov	ecx,eax
	shl	ecx,1
	jc near_o0 out_of_memory
	mov	edx,ecx
	shl	edx,1
	jc near_o0 out_of_memory
	shl	edx,1
	jc near_o0 out_of_memory
	add	edx,edi
	jc near_o0 out_of_memory
	cmp	edx,dword [display_buffer]
	jae near_o0 out_of_memory
	push	edi
	cmp	byte [next_pass_needed],0
	je near_o0 zero_dwords
	lea	edi,[edi+ecx*4]
	jmp	reserved_data
reserve_twords:
	lodsb
	cmp	al,'('
	jne near_o0 invalid_argument
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	cmp	byte [value_type],0
	jne near_o0 invalid_use_of_symbol
	cmp	eax,0
	jl near_o0 reserve_negative
	mov	ecx,eax
	shl	ecx,2
	jc near_o0 out_of_memory
	add	ecx,eax
	mov	edx,ecx
	shl	edx,1
	jc near_o0 out_of_memory
	add	edx,edi
	jc near_o0 out_of_memory
	cmp	edx,dword [display_buffer]
	jae near_o0 out_of_memory
	push	edi
	cmp	byte [next_pass_needed],0
	je near_o0 zero_words
	lea	edi,[edi+ecx*2]
	jmp	reserved_data

simple_instruction:
	stosb
	jmp	instruction_assembled
simple_instruction_16bit:
	cmp	byte [code_type],32
	je	size_prefix
	stosb
	jmp	instruction_assembled
      size_prefix:
	mov	ah,al
	mov	al,66h
	stosw
	jmp	instruction_assembled
simple_instruction_32bit:
	cmp	byte [code_type],16
	je	size_prefix
	stosb
	jmp	instruction_assembled
simple_extended_instruction:
	mov	ah,al
	mov	al,0Fh
	stosw
	jmp	instruction_assembled
prefix_instruction:
	stosb
	jmp	assemble_line
int_instruction:
	lodsb
	call	get_size_operator
	cmp	ah,1
	ja near_o0 invalid_operand_size
	cmp	al,'('
	jne near_o0 invalid_operand
	call	get_byte_value
	mov	ah,al
	mov	al,0CDh
	stosw
	jmp	instruction_assembled
aa_instruction:
	push	ax
	mov	bl,10
	cmp	byte [esi],'('
	jne	.store
	inc	esi
	xor	al,al
	xchg	al,byte [operand_size]
	cmp	al,1
	ja near_o0 invalid_operand_size
	call	get_byte_value
	mov	bl,al
      .store:
	cmp	byte [operand_size],0
	jne near_o0 invalid_operand
	pop	ax
	mov	ah,bl
	stosw
	jmp	instruction_assembled

basic_instruction:
	mov	byte [base_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je near_o0 basic_reg
	cmp	al,'['
	jne near_o0 invalid_operand
      basic_mem:
	call	get_address
	push	edx
	push	bx
	push	cx
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	cmp	byte [esi],11h
	sete	al
	mov	byte [imm_sized],al
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	basic_mem_imm
	cmp	al,10h
	jne near_o0 invalid_operand
      basic_mem_reg:
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	pop	cx
	pop	bx
	pop	edx
	mov	al,ah
	cmp	al,1
	je	basic_mem_reg_8bit
	cmp	al,2
	je	basic_mem_reg_16bit
	cmp	al,4
	je	basic_mem_reg_32bit
	jmp	invalid_operand_size
      basic_mem_reg_8bit:
	call	store_instruction
	jmp	instruction_assembled
      basic_mem_reg_16bit:
	call	operand_16bit_prefix
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      basic_mem_reg_32bit:
	call	operand_32bit_prefix
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      basic_mem_imm:
	mov	al,byte [operand_size]
	cmp	al,1
	je	basic_mem_imm_8bit
	cmp	al,2
	je	basic_mem_imm_16bit
	cmp	al,4
	je near_o0 basic_mem_imm_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
	jmp	basic_mem_imm_32bit
      basic_mem_imm_8bit:
	call	get_byte_value
	mov	byte [value],al
	mov	al,byte [base_code]
	shr	al,3
	mov	byte [postbyte_register],al
	pop	cx
	pop	bx
	pop	edx
	mov	byte [base_code],80h
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      basic_mem_imm_16bit:
	call	get_word_value
	mov	word [value],ax
	mov	al,byte [base_code]
	shr	al,3
	mov	byte [postbyte_register],al
	call	operand_16bit_prefix
	pop	cx
	pop	bx
	pop	edx
	cmp	byte [value_type],0
	jne	.store
	cmp	byte [imm_sized],0
	jne	.store
	cmp	word [value],80h
	jb	basic_mem_simm_8bit
	cmp	word [value],-80h
	jae	basic_mem_simm_8bit
      .store:
	mov	byte [base_code],81h
	call	store_instruction
	mov	ax,word [value]
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      basic_mem_simm_8bit:
	mov	byte [base_code],83h
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      basic_mem_imm_32bit:
	call	get_dword_value
	mov	dword [value],eax
	mov	al,byte [base_code]
	shr	al,3
	mov	byte [postbyte_register],al
	call	operand_32bit_prefix
	pop	cx
	pop	bx
	pop	edx
	cmp	byte [value_type],0
	jne	.store
	cmp	byte [imm_sized],0
	jne	.store
	cmp	dword [value],80h
	jb	basic_mem_simm_8bit
	cmp	dword [value],-80h
	jae	basic_mem_simm_8bit
      .store:
	mov	byte [base_code],81h
	call	store_instruction
	mov	eax,dword [value]
	call	mark_relocation
	stosd
	jmp	instruction_assembled
      basic_reg:
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	cmp	byte [esi],11h
	sete	al
	mov	byte [imm_sized],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	basic_reg_reg
	cmp	al,'('
	je near_o0 basic_reg_imm
	cmp	al,'['
	jne near_o0 invalid_operand
      basic_reg_mem:
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,1
	je	basic_reg_mem_8bit
	cmp	al,2
	je	basic_reg_mem_16bit
	cmp	al,4
	je	basic_reg_mem_32bit
	jmp	invalid_operand_size
      basic_reg_mem_8bit:
	add	byte [base_code],2
	call	store_instruction
	jmp	instruction_assembled
      basic_reg_mem_16bit:
	call	operand_16bit_prefix
	add	byte [base_code],3
	call	store_instruction
	jmp	instruction_assembled
      basic_reg_mem_32bit:
	call	operand_32bit_prefix
	add	byte [base_code],3
	call	store_instruction
	jmp	instruction_assembled
      basic_reg_reg:
	lodsb
	call	convert_register
	shl	al,3
	mov	bl,byte [postbyte_register]
	or	bl,al
	or	bl,11000000b
	mov	al,ah
	cmp	al,1
	je	basic_reg_reg_8bit
	cmp	al,2
	je	basic_reg_reg_16bit
	cmp	al,4
	je	basic_reg_reg_32bit
	jmp	invalid_operand_size
      basic_reg_reg_32bit:
	call	operand_32bit_prefix
	inc	byte [base_code]
	jmp	basic_reg_reg_8bit
      basic_reg_reg_16bit:
	call	operand_16bit_prefix
	inc	byte [base_code]
      basic_reg_reg_8bit:
	mov	al,byte [base_code]
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      basic_reg_imm:
	mov	al,byte [operand_size]
	cmp	al,1
	je	basic_reg_imm_8bit
	cmp	al,2
	je	basic_reg_imm_16bit
	cmp	al,4
	je near_o0 basic_reg_imm_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
	jmp	basic_reg_imm_32bit
      basic_reg_imm_8bit:
	call	get_byte_value
	mov	dl,al
	mov	ah,byte [base_code]
	or	ah,11000000b
	mov	bl,byte [postbyte_register]
	and	bl,111b
	or	bl,bl
	jz	basic_al_imm
	or	ah,bl
	mov	al,80h
	stosw
	mov	al,dl
	stosb
	jmp	instruction_assembled
      basic_al_imm:
	mov	al,byte [base_code]
	add	al,4
	stosb
	mov	al,dl
	stosb
	jmp	instruction_assembled
      basic_reg_imm_16bit:
	call	get_word_value
	mov	dx,ax
	call	operand_16bit_prefix
	mov	ah,byte [base_code]
	or	ah,11000000b
	mov	bl,byte [postbyte_register]
	and	bl,111b
	or	ah,bl
	cmp	byte [value_type],0
	jne	.store
	cmp	byte [imm_sized],0
	jne	.store
	cmp	dx,80h
	jb	basic_reg_simm_8bit
	cmp	dx,-80h
	jae	basic_reg_simm_8bit
      .store:
	or	bl,bl
	jz	basic_ax_imm
	mov	al,81h
	stosw
	mov	ax,dx
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      basic_reg_simm_8bit:
	mov	al,83h
	stosw
	mov	ax,dx
	stosb
	jmp	instruction_assembled
      basic_ax_imm:
	mov	al,byte [base_code]
	add	al,5
	stosb
	mov	ax,dx
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      basic_reg_imm_32bit:
	call	get_dword_value
	mov	edx,eax
	call	operand_32bit_prefix
	mov	ah,byte [base_code]
	or	ah,11000000b
	mov	bl,byte [postbyte_register]
	and	bl,111b
	or	ah,bl
	cmp	byte [value_type],0
	jne	.store
	cmp	byte [imm_sized],0
	jne	.store
	cmp	edx,80h
	jb	basic_reg_simm_8bit
	cmp	edx,-80h
	jae	basic_reg_simm_8bit
      .store:
	or	bl,bl
	jz	basic_eax_imm
	mov	al,81h
	stosw
	mov	eax,edx
	call	mark_relocation
	stosd
	jmp	instruction_assembled
      basic_eax_imm:
	mov	al,byte [base_code]
	add	al,5
	stosb
	mov	eax,edx
	call	mark_relocation
	stosd
	jmp	instruction_assembled
single_operand_instruction:
	mov	byte [base_code],0F6h
	mov	byte [postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	single_reg
	cmp	al,'['
	jne near_o0 invalid_operand
      single_mem:
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,1
	je	single_mem_8bit
	cmp	al,2
	je	single_mem_16bit
	cmp	al,4
	je	single_mem_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
      single_mem_8bit:
	call	store_instruction
	jmp	instruction_assembled
      single_mem_16bit:
	call	operand_16bit_prefix
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      single_mem_32bit:
	call	operand_32bit_prefix
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      single_reg:
	lodsb
	call	convert_register
	mov	bl,byte [postbyte_register]
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	mov	al,ah
	cmp	al,1
	je	single_reg_8bit
	cmp	al,2
	je	single_reg_16bit
	cmp	al,4
	je	single_reg_32bit
	jmp	invalid_operand_size
      single_reg_8bit:
	mov	ah,bl
	mov	al,0F6h
	stosw
	jmp	instruction_assembled
      single_reg_16bit:
	call	operand_16bit_prefix
	mov	ah,bl
	mov	al,0F7h
	stosw
	jmp	instruction_assembled
      single_reg_32bit:
	call	operand_32bit_prefix
	mov	ah,bl
	mov	al,0F7h
	stosw
	jmp	instruction_assembled
mov_instruction:
	mov	byte [base_code],88h
	lodsb
	call	get_size_operator
	cmp	al,10h
	je near_o0 mov_reg
	cmp	al,'['
	jne near_o0 invalid_operand
      mov_mem:
	call	get_address
	push	edx
	push	bx
	push	cx
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'('
	je near_o0 mov_mem_imm
	cmp	al,10h
	jne near_o0 invalid_operand
      mov_mem_reg:
	lodsb
	cmp	al,60h
	jae near_o0 mov_mem_sreg
	call	convert_register
	mov	byte [postbyte_register],al
	pop	cx
	pop	bx
	pop	edx
	cmp	ah,1
	je	mov_mem_reg_8bit
	cmp	ah,2
	je	mov_mem_reg_16bit
	cmp	ah,4
	je near_o0 mov_mem_reg_32bit
	jmp	invalid_operand_size
      mov_mem_reg_8bit:
	or	al,bl
	or	al,bh
	jz	mov_mem_al
	call	store_instruction
	jmp	instruction_assembled
      mov_mem_al:
	cmp	ch,2
	je	mov_mem_address16_al
	test	ch,4
	jnz	mov_mem_address32_al
	or	ch,ch
	jnz near_o0 invalid_address_size
	cmp	byte [code_type],32
	je	mov_mem_address32_al
	cmp	edx,10000h
	jb	mov_mem_address16_al
      mov_mem_address32_al:
	call	address_32bit_prefix
	call	store_segment_prefix_if_necessary
	mov	al,0A2h
      store_mov_address32:
	stosb
	push	dword instruction_assembled
	jmp	store_address_32bit_value
      mov_mem_address16_al:
	call	address_16bit_prefix
	call	store_segment_prefix_if_necessary
	mov	al,0A2h
      store_mov_address16:
	stosb
	mov	eax,edx
	stosw
	cmp	edx,10000h
	jge near_o0 value_out_of_range
	jmp	instruction_assembled
      mov_mem_reg_16bit:
	call	operand_16bit_prefix
	mov	al,byte [postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_mem_ax
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      mov_mem_ax:
	cmp	ch,2
	je	mov_mem_address16_ax
	test	ch,4
	jnz	mov_mem_address32_ax
	or	ch,ch
	jnz near_o0 invalid_address_size
	cmp	byte [code_type],32
	je	mov_mem_address32_ax
	cmp	edx,10000h
	jb	mov_mem_address16_ax
      mov_mem_address32_ax:
	call	address_32bit_prefix
	call	store_segment_prefix_if_necessary
	mov	al,0A3h
	jmp	store_mov_address32
      mov_mem_address16_ax:
	call	address_16bit_prefix
	call	store_segment_prefix_if_necessary
	mov	al,0A3h
	jmp	store_mov_address16
      mov_mem_reg_32bit:
	call	operand_32bit_prefix
	mov	al,byte [postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_mem_ax
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      mov_mem_sreg:
	cmp	al,70h
	jae near_o0 invalid_operand
	sub	al,61h
	mov	byte [postbyte_register],al
	pop	cx
	pop	bx
	pop	edx
	mov	ah,byte [operand_size]
	or	ah,ah
	jz	mov_mem_sreg_size_ok
	cmp	ah,2
	je	mov_mem16_sreg
	cmp	ah,4
	je	mov_mem32_sreg
	jmp	invalid_operand_size
      mov_mem32_sreg:
	call	operand_32bit_prefix
	jmp	mov_mem_sreg_size_ok
      mov_mem16_sreg:
	call	operand_16bit_prefix
      mov_mem_sreg_size_ok:
	mov	byte [base_code],8Ch
	call	store_instruction
	jmp	instruction_assembled
      mov_mem_imm:
	mov	al,byte [operand_size]
	cmp	al,1
	je	mov_mem_imm_8bit
	cmp	al,2
	je	mov_mem_imm_16bit
	cmp	al,4
	je near_o0 mov_mem_imm_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
	jmp	mov_mem_imm_32bit
      mov_mem_imm_8bit:
	call	get_byte_value
	mov	byte [value],al
	mov	byte [postbyte_register],0
	mov	byte [base_code],0C6h
	pop	cx
	pop	bx
	pop	edx
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      mov_mem_imm_16bit:
	call	get_word_value
	mov	word [value],ax
	mov	byte [postbyte_register],0
	mov	byte [base_code],0C7h
	call	operand_16bit_prefix
	pop	cx
	pop	bx
	pop	edx
	call	store_instruction
	mov	ax,word [value]
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      mov_mem_imm_32bit:
	call	get_dword_value
	mov	dword [value],eax
	mov	byte [postbyte_register],0
	mov	byte [base_code],0C7h
	call	operand_32bit_prefix
	pop	cx
	pop	bx
	pop	edx
	call	store_instruction
	mov	eax,dword [value]
	call	mark_relocation
	stosd
	jmp	instruction_assembled
      mov_reg:
	lodsb
	cmp	al,50h
	jae near_o0 mov_sreg
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	je near_o0 mov_reg_mem
	cmp	al,'('
	je near_o0 mov_reg_imm
	cmp	al,10h
	jne near_o0 invalid_operand
      mov_reg_reg:
	lodsb
	cmp	al,50h
	jae	mov_reg_sreg
	call	convert_register
	shl	al,3
	mov	bl,byte [postbyte_register]
	or	bl,al
	or	bl,11000000b
	mov	al,ah
	cmp	al,1
	je	mov_reg_reg_8bit
	cmp	al,2
	je	mov_reg_reg_16bit
	cmp	al,4
	je	mov_reg_reg_32bit
	jmp	invalid_operand_size
      mov_reg_reg_32bit:
	call	operand_32bit_prefix
	inc	byte [base_code]
	jmp	mov_reg_reg_8bit
      mov_reg_reg_16bit:
	call	operand_16bit_prefix
	inc	byte [base_code]
      mov_reg_reg_8bit:
	mov	al,byte [base_code]
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      mov_reg_sreg:
	mov	ah,al
	shr	ah,4
	cmp	ah,5
	je	mov_reg_creg
	cmp	ah,7
	je	mov_reg_dreg
	ja near_o0 invalid_operand
	sub	al,61h
	mov	bl,byte [postbyte_register]
	shl	al,3
	or	bl,al
	or	bl,11000000b
	cmp	byte [operand_size],4
	je	mov_reg_sreg32
	cmp	byte [operand_size],2
	jne near_o0 invalid_operand_size
	call	operand_16bit_prefix
	jmp	mov_reg_sreg_store
     mov_reg_sreg32:
	call	operand_32bit_prefix
     mov_reg_sreg_store:
	mov	al,8Ch
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      mov_reg_creg:
	mov	bh,20h
	jmp	mov_reg_xrx
      mov_reg_dreg:
	mov	bh,21h
      mov_reg_xrx:
	and	al,111b
	mov	bl,byte [postbyte_register]
	shl	al,3
	or	bl,al
	or	bl,11000000b
	cmp	byte [operand_size],4
	jne near_o0 invalid_operand_size
	mov	ah,bh
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
      mov_reg_mem:
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,1
	je	mov_reg_mem_8bit
	cmp	al,2
	je	mov_reg_mem_16bit
	cmp	al,4
	je near_o0 mov_reg_mem_32bit
	jmp	invalid_operand_size
      mov_reg_mem_8bit:
	mov	al,byte [postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_al_mem
	add	byte [base_code],2
	call	store_instruction
	jmp	instruction_assembled
      mov_al_mem:
	cmp	ch,2
	je	mov_al_mem_address16
	test	ch,4
	jnz	mov_al_mem_address32
	or	ch,ch
	jnz near_o0 invalid_address_size
	cmp	byte [code_type],32
	je	mov_al_mem_address32
	cmp	edx,10000h
	jb	mov_al_mem_address16
      mov_al_mem_address32:
	call	address_32bit_prefix
	call	store_segment_prefix_if_necessary
	mov	al,0A0h
	jmp	store_mov_address32
      mov_al_mem_address16:
	call	address_16bit_prefix
	call	store_segment_prefix_if_necessary
	mov	al,0A0h
	jmp	store_mov_address16
      mov_reg_mem_16bit:
	call	operand_16bit_prefix
	mov	al,byte [postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_ax_mem
	add	byte [base_code],3
	call	store_instruction
	jmp	instruction_assembled
      mov_ax_mem:
	cmp	ch,2
	je	mov_ax_mem_address16
	test	ch,4
	jnz	mov_ax_mem_address32
	or	ch,ch
	jnz near_o0 invalid_address_size
	cmp	byte [code_type],32
	je	mov_ax_mem_address32
	cmp	edx,10000h
	jb	mov_ax_mem_address16
      mov_ax_mem_address32:
	call	address_32bit_prefix
	call	store_segment_prefix_if_necessary
	mov	al,0A1h
	jmp	store_mov_address32
      mov_ax_mem_address16:
	call	address_16bit_prefix
	call	store_segment_prefix_if_necessary
	mov	al,0A1h
	jmp	store_mov_address16
      mov_reg_mem_32bit:
	call	operand_32bit_prefix
	mov	al,byte [postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_ax_mem
	add	byte [base_code],3
	call	store_instruction
	jmp	instruction_assembled
      mov_reg_imm:
	mov	al,byte [operand_size]
	cmp	al,1
	je	mov_reg_imm_8bit
	cmp	al,2
	je	mov_reg_imm_16bit
	cmp	al,4
	je	mov_reg_imm_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
	jmp	mov_reg_imm_32bit
      mov_reg_imm_8bit:
	call	get_byte_value
	mov	ah,al
	mov	al,byte [postbyte_register]
	and	al,111b
	add	al,0B0h
	stosw
	jmp	instruction_assembled
      mov_reg_imm_16bit:
	call	get_word_value
	mov	dx,ax
	call	operand_16bit_prefix
	mov	al,byte [postbyte_register]
	and	al,111b
	add	al,0B8h
	stosb
	mov	ax,dx
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      mov_reg_imm_32bit:
	call	get_dword_value
	mov	edx,eax
	call	operand_32bit_prefix
	mov	al,byte [postbyte_register]
	and	al,111b
	add	al,0B8h
	stosb
	mov	eax,edx
	call	mark_relocation
	stosd
	jmp	instruction_assembled
      mov_sreg:
	mov	ah,al
	shr	ah,4
	cmp	ah,5
	je near_o0 mov_creg
	cmp	ah,7
	je near_o0 mov_dreg
	ja near_o0 invalid_operand
	sub	al,61h
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	je	mov_sreg_mem
	cmp	al,10h
	jne near_o0 invalid_operand
      mov_sreg_reg:
	lodsb
	call	convert_register
	or	ah,ah
	jz	mov_sreg_reg_size_ok
	cmp	ah,4
	je	mov_sreg_reg32
	cmp	ah,2
	je	mov_sreg_reg16
	jmp	invalid_operand_size
      mov_sreg_reg32:
	mov	ah,al
	call	operand_32bit_prefix
	mov	al,ah
	jmp	mov_sreg_reg_size_ok
      mov_sreg_reg16:
	mov	ah,al
	call	operand_16bit_prefix
	mov	al,ah
      mov_sreg_reg_size_ok:
	mov	bl,11000000b
	or	bl,al
	mov	al,byte [postbyte_register]
	shl	al,3
	or	bl,al
	mov	al,8Eh
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      mov_sreg_mem:
	call	get_address
	mov	al,byte [operand_size]
	or	al,al
	jz	mov_sreg_mem_size_ok
	cmp	al,2
	je	mov_sreg_mem16
	cmp	al,4
	je	mov_sreg_mem32
	jmp	invalid_operand_size
      mov_sreg_mem32:
	call	operand_32bit_prefix
	jmp	mov_sreg_mem_size_ok
      mov_sreg_mem16:
	call	operand_16bit_prefix
      mov_sreg_mem_size_ok:
	mov	byte [base_code],8Eh
	call	store_instruction
	jmp	instruction_assembled
      mov_creg:
	mov	dl,22h
	jmp	mov_xrx
      mov_dreg:
	mov	dl,23h
      mov_xrx:
	and	al,111b
	mov	bh,al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	cmp	ah,4
	jne near_o0 invalid_operand_size
	mov	bl,11000000b
	or	bl,al
	mov	al,bh
	shl	al,3
	or	bl,al
	mov	al,0Fh
	mov	ah,dl
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
test_instruction:
	mov	byte [base_code],84h
	lodsb
	call	get_size_operator
	cmp	al,10h
	je near_o0 test_reg
	cmp	al,'['
	jne near_o0 invalid_operand
      test_mem:
	call	get_address
	push	edx
	push	bx
	push	cx
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	test_mem_imm
	cmp	al,10h
	jne near_o0 invalid_operand
      test_mem_reg:
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	pop	cx
	pop	bx
	pop	edx
	mov	al,ah
	cmp	al,1
	je	test_mem_reg_8bit
	cmp	al,2
	je	test_mem_reg_16bit
	cmp	al,4
	je	test_mem_reg_32bit
	jmp	invalid_operand_size
      test_mem_reg_8bit:
	call	store_instruction
	jmp	instruction_assembled
      test_mem_reg_16bit:
	call	operand_16bit_prefix
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      test_mem_reg_32bit:
	call	operand_32bit_prefix
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      test_mem_imm:
	mov	al,byte [operand_size]
	cmp	al,1
	je	test_mem_imm_8bit
	cmp	al,2
	je	test_mem_imm_16bit
	cmp	al,4
	je near_o0 test_mem_imm_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
	jmp	test_mem_imm_32bit
      test_mem_imm_8bit:
	call	get_byte_value
	mov	byte [value],al
	mov	byte [postbyte_register],0
	mov	byte [base_code],0F6h
	pop	cx
	pop	bx
	pop	edx
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      test_mem_imm_16bit:
	call	get_word_value
	mov	word [value],ax
	mov	byte [postbyte_register],0
	mov	byte [base_code],0F7h
	call	operand_16bit_prefix
	pop	cx
	pop	bx
	pop	edx
	call	store_instruction
	mov	ax,word [value]
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      test_mem_imm_32bit:
	call	get_dword_value
	mov	dword [value],eax
	mov	byte [postbyte_register],0
	mov	byte [base_code],0F7h
	call	operand_32bit_prefix
	pop	cx
	pop	bx
	pop	edx
	call	store_instruction
	mov	eax,dword [value]
	call	mark_relocation
	stosd
	jmp	instruction_assembled
      test_reg:
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	test_reg_imm
	cmp	al,10h
	jne near_o0 invalid_operand
      test_reg_reg:
	lodsb
	call	convert_register
	shl	al,3
	mov	bl,byte [postbyte_register]
	or	bl,al
	or	bl,11000000b
	mov	al,ah
	cmp	al,1
	je	test_reg_reg_8bit
	cmp	al,2
	je	test_reg_reg_16bit
	cmp	al,4
	je	test_reg_reg_32bit
	jmp	invalid_operand_size
      test_reg_reg_32bit:
	call	operand_32bit_prefix
	inc	byte [base_code]
	jmp	basic_reg_reg_8bit
      test_reg_reg_16bit:
	call	operand_16bit_prefix
	inc	byte [base_code]
      test_reg_reg_8bit:
	mov	al,byte [base_code]
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      test_reg_imm:
	mov	al,byte [operand_size]
	cmp	al,1
	je	test_reg_imm_8bit
	cmp	al,2
	je	test_reg_imm_16bit
	cmp	al,4
	je near_o0 test_reg_imm_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
	jmp	test_reg_imm_32bit
      test_reg_imm_8bit:
	call	get_byte_value
	mov	dl,al
	mov	ah,11000000b
	mov	bl,byte [postbyte_register]
	and	bl,111b
	or	bl,bl
	jz	test_al_imm
	or	ah,bl
	mov	al,0F6h
	stosw
	mov	al,dl
	stosb
	jmp	instruction_assembled
      test_al_imm:
	mov	al,0A8h
	stosb
	mov	al,dl
	stosb
	jmp	instruction_assembled
      test_reg_imm_16bit:
	call	get_word_value
	mov	dx,ax
	call	operand_16bit_prefix
	mov	ah,11000000b
	mov	bl,byte [postbyte_register]
	and	bl,111b
	or	bl,bl
	jz	test_ax_imm
	or	ah,bl
	mov	al,0F7h
	stosw
	mov	ax,dx
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      test_ax_imm:
	mov	al,0A9h
	stosb
	mov	ax,dx
	stosw
	jmp	instruction_assembled
      test_reg_imm_32bit:
	call	get_dword_value
	mov	edx,eax
	call	operand_32bit_prefix
	mov	ah,11000000b
	mov	bl,byte [postbyte_register]
	and	bl,111b
	or	bl,bl
	jz	test_eax_imm
	or	ah,bl
	mov	al,0F7h
	stosw
	mov	eax,edx
	call	mark_relocation
	stosd
	jmp	instruction_assembled
      test_eax_imm:
	mov	al,0A9h
	stosb
	mov	eax,edx
	stosd
	jmp	instruction_assembled
xchg_instruction:
	mov	byte [base_code],86h
	lodsb
	call	get_size_operator
	cmp	al,10h
	je near_o0 xchg_reg
	cmp	al,'['
	jne near_o0 invalid_operand
      xchg_mem:
	call	get_address
	push	edx
	push	bx
	push	cx
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
      xchg_mem_reg:
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	pop	cx
	pop	bx
	pop	edx
	mov	al,ah
	cmp	al,1
	je	xchg_mem_reg_8bit
	cmp	al,2
	je	xchg_mem_reg_16bit
	cmp	al,4
	je	xchg_mem_reg_32bit
	jmp	invalid_operand_size
      xchg_mem_reg_8bit:
	call	store_instruction
	jmp	instruction_assembled
      xchg_mem_reg_16bit:
	call	operand_16bit_prefix
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      xchg_mem_reg_32bit:
	call	operand_32bit_prefix
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      xchg_reg:
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	je near_o0 xchg_reg_mem
	cmp	al,10h
	jne near_o0 invalid_operand
      xchg_reg_reg:
	lodsb
	call	convert_register
	mov	bh,al
	mov	bl,byte [postbyte_register]
	shl	byte [postbyte_register],3
	or	al,11000000b
	or	byte [postbyte_register],al
	mov	al,ah
	cmp	al,1
	je	xchg_reg_reg_8bit
	cmp	al,2
	je	xchg_reg_reg_16bit
	cmp	al,4
	je	xchg_reg_reg_32bit
	jmp	invalid_operand_size
      xchg_reg_reg_32bit:
	call	operand_32bit_prefix
	or	bh,bh
	jz	xchg_ax_reg
	xchg	bh,bl
	or	bh,bh
	jz	xchg_ax_reg
	inc	byte [base_code]
	jmp	xchg_reg_reg_8bit
      xchg_reg_reg_16bit:
	call	operand_16bit_prefix
	or	bh,bh
	jz	xchg_ax_reg
	xchg	bh,bl
	or	bh,bh
	jz	xchg_ax_reg
	inc	byte [base_code]
      xchg_reg_reg_8bit:
	mov	al,byte [base_code]
	mov	ah,byte [postbyte_register]
	stosw
	jmp	instruction_assembled
      xchg_ax_reg:
	mov	al,90h
	add	al,bl
	stosb
	jmp	instruction_assembled
      xchg_reg_mem:
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,1
	je	xchg_reg_mem_8bit
	cmp	al,2
	je	xchg_reg_mem_16bit
	cmp	al,4
	je	xchg_reg_mem_32bit
	jmp	invalid_operand_size
      xchg_reg_mem_8bit:
	call	store_instruction
	jmp	instruction_assembled
      xchg_reg_mem_32bit:
	call	operand_32bit_prefix
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      xchg_reg_mem_16bit:
	call	operand_16bit_prefix
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
push_instruction:
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	push_reg
	cmp	al,'('
	je near_o0 push_imm
	cmp	al,'['
	jne near_o0 invalid_operand
      push_mem:
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,2
	je	push_mem_16bit
	cmp	al,4
	je	push_mem_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
      push_mem_16bit:
	call	operand_16bit_prefix
	mov	byte [base_code],0FFh
	mov	byte [postbyte_register],110b
	call	store_instruction
	jmp	push_done
      push_mem_32bit:
	call	operand_32bit_prefix
	mov	byte [base_code],0FFh
	mov	byte [postbyte_register],110b
	call	store_instruction
	jmp	push_done
      push_reg:
	lodsb
	cmp	al,60h
	jae	push_sreg
	call	convert_register
	mov	dl,al
	add	dl,50h
	mov	al,ah
	cmp	al,2
	je	push_reg_16bit
	cmp	al,4
	je	push_reg_32bit
	jmp	invalid_operand_size
      push_reg_16bit:
	call	operand_16bit_prefix
	mov	al,dl
	stosb
	jmp	push_done
      push_reg_32bit:
	call	operand_32bit_prefix
	mov	al,dl
	stosb
	jmp	push_done
      push_sreg:
	mov	bl,byte [operand_size]
	cmp	bl,4
	je	push_sreg32
	cmp	bl,2
	je	push_sreg16
	or	bl,bl
	jz	push_sreg_store
	jmp	invalid_operand_size
      push_sreg16:
	mov	bl,al
	call	operand_16bit_prefix
	mov	al,bl
	jmp	push_sreg_store
      push_sreg32:
	mov	bl,al
	call	operand_32bit_prefix
	mov	al,bl
      push_sreg_store:
	cmp	al,70h
	jae near_o0 invalid_operand
	sub	al,61h
	cmp	al,4
	jae	push_sreg_386
	shl	al,3
	add	al,6
	stosb
	jmp	push_done
      push_sreg_386:
	sub	al,4
	shl	al,3
	mov	ah,0A0h
	add	ah,al
	mov	al,0Fh
	stosw
	jmp	push_done
      push_imm:
	mov	al,byte [operand_size]
	cmp	al,2
	je	push_imm_16bit
	cmp	al,4
	je	push_imm_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [code_type],16
	je	push_imm_optimized_16bit
      push_imm_optimized_32bit:
	call	get_dword_value
	mov	edx,eax
	cmp	byte [value_type],0
	jne	push_imm_32bit_forced
	cmp	eax,-80h
	jl	push_imm_32bit_forced
	cmp	eax,80h
	jge	push_imm_32bit_forced
      push_imm_8bit:
	mov	ah,al
	mov	al,6Ah
	stosw
	jmp	push_done
      push_imm_optimized_16bit:
	call	get_word_value
	mov	dx,ax
	cmp	byte [value_type],0
	jne	push_imm_16bit_forced
	cmp	ax,-80h
	jl	push_imm_16bit_forced
	cmp	ax,80h
	jge	push_imm_16bit_forced
	jmp	push_imm_8bit
      push_imm_16bit:
	call	get_word_value
	mov	dx,ax
	call	operand_16bit_prefix
      push_imm_16bit_forced:
	mov	al,68h
	stosb
	mov	ax,dx
	call	mark_relocation
	stosw
	jmp	push_done
      push_imm_32bit:
	call	get_dword_value
	mov	edx,eax
	call	operand_32bit_prefix
      push_imm_32bit_forced:
	mov	al,68h
	stosb
	mov	eax,edx
	call	mark_relocation
	stosd
      push_done:
	lodsb
	dec	esi
	cmp	al,0Fh
	je near_o0 instruction_assembled
	or	al,al
	jz near_o0 instruction_assembled
	mov	byte [operand_size],0
	mov	byte [forced_size],0
	jmp	push_instruction
pop_instruction:
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	pop_reg
	cmp	al,'['
	jne near_o0 invalid_operand
      pop_mem:
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,2
	je	pop_mem_16bit
	cmp	al,4
	je	pop_mem_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
      pop_mem_16bit:
	call	operand_16bit_prefix
	mov	byte [base_code],08Fh
	mov	byte [postbyte_register],0
	call	store_instruction
	jmp	pop_done
      pop_mem_32bit:
	call	operand_32bit_prefix
	mov	byte [base_code],08Fh
	mov	byte [postbyte_register],0
	call	store_instruction
	jmp	pop_done
      pop_reg:
	lodsb
	cmp	al,60h
	jae	pop_sreg
	call	convert_register
	mov	dl,al
	add	dl,58h
	mov	al,ah
	cmp	al,2
	je	pop_reg_16bit
	cmp	al,4
	je	pop_reg_32bit
	jmp	invalid_operand_size
      pop_reg_16bit:
	call	operand_16bit_prefix
	mov	al,dl
	stosb
	jmp	pop_done
      pop_reg_32bit:
	call	operand_32bit_prefix
	mov	al,dl
	stosb
	jmp	pop_done
      pop_sreg:
	mov	bl,byte [operand_size]
	cmp	bl,4
	je	pop_sreg32
	cmp	bl,2
	je	pop_sreg16
	or	bl,bl
	jz	pop_sreg_store
	jmp	invalid_operand_size
      pop_sreg16:
	mov	bl,al
	call	operand_16bit_prefix
	mov	al,bl
	jmp	pop_sreg_store
      pop_sreg32:
	mov	bl,al
	call	operand_32bit_prefix
	mov	al,bl
      pop_sreg_store:
	cmp	al,70h
	jae near_o0 invalid_operand
	sub	al,61h
	cmp	al,1
	je near_o0 illegal_instruction
	cmp	al,4
	jae	pop_sreg_386
	shl	al,3
	add	al,7
	stosb
	jmp	pop_done
      pop_sreg_386:
	sub	al,4
	shl	al,3
	mov	ah,0A1h
	add	ah,al
	mov	al,0Fh
	stosw
      pop_done:
	lodsb
	dec	esi
	cmp	al,0Fh
	je near_o0 instruction_assembled
	or	al,al
	jz near_o0 instruction_assembled
	mov	byte [operand_size],0
	mov	byte [forced_size],0
	jmp	pop_instruction
inc_instruction:
	mov	byte [base_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je near_o0 inc_reg
	cmp	al,'['
	je	inc_mem
	jne near_o0 invalid_operand
      inc_mem:
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,1
	je	inc_mem_8bit
	cmp	al,2
	je	inc_mem_16bit
	cmp	al,4
	je	inc_mem_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
      inc_mem_8bit:
	mov	al,0FEh
	xchg	al,byte [base_code]
	mov	byte [postbyte_register],al
	call	store_instruction
	jmp	instruction_assembled
      inc_mem_16bit:
	call	operand_16bit_prefix
	mov	al,0FFh
	xchg	al,byte [base_code]
	mov	byte [postbyte_register],al
	call	store_instruction
	jmp	instruction_assembled
      inc_mem_32bit:
	call	operand_32bit_prefix
	mov	al,0FFh
	xchg	al,byte [base_code]
	mov	byte [postbyte_register],al
	call	store_instruction
	jmp	instruction_assembled
      inc_reg:
	lodsb
	call	convert_register
	mov	dl,al
	shr	al,4
	mov	al,ah
	cmp	al,1
	je	inc_reg_8bit
	mov	dh,byte [base_code]
	shl	dh,3
	add	dl,dh
	add	dl,40h
	cmp	al,2
	je	inc_reg_16bit
	cmp	al,4
	je	inc_reg_32bit
	jmp	invalid_operand_size
      inc_reg_8bit:
	mov	al,0FEh
	mov	ah,byte [base_code]
	shl	ah,3
	or	ah,dl
	or	ah,11000000b
	stosw
	jmp	instruction_assembled
      inc_reg_16bit:
	call	operand_16bit_prefix
	mov	al,dl
	stosb
	jmp	instruction_assembled
      inc_reg_32bit:
	call	operand_32bit_prefix
	mov	al,dl
	stosb
	jmp	instruction_assembled
arpl_instruction:
	mov	byte [base_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	arpl_reg
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	cmp	ah,2
	jne near_o0 invalid_operand_size
	mov	byte [base_code],63h
	call	store_instruction
	jmp	instruction_assembled
      arpl_reg:
	lodsb
	call	convert_register
	cmp	ah,2
	jne near_o0 invalid_operand_size
	mov	dl,al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	cmp	ah,2
	jne near_o0 invalid_operand_size
	mov	ah,al
	shl	ah,3
	or	ah,dl
	or	ah,11000000b
	mov	al,63h
	stosw
	jmp	instruction_assembled
bound_instruction:
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,2
	je	bound_16bit
	cmp	al,4
	je	bound_32bit
	jmp	invalid_operand_size
      bound_32bit:
	call	operand_32bit_prefix
	mov	byte [base_code],62h
	call	store_instruction
	jmp	instruction_assembled
      bound_16bit:
	call	operand_16bit_prefix
	mov	byte [base_code],62h
	call	store_instruction
	jmp	instruction_assembled
set_instruction:
	mov	byte [base_code],0Fh
	mov	byte [extended_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	set_reg
	cmp	al,'['
	jne near_o0 invalid_operand
      set_mem:
	call	get_address
	cmp	byte [operand_size],1
	ja near_o0 invalid_operand_size
	mov	byte [postbyte_register],0
	call	store_instruction
	jmp	instruction_assembled
      set_reg:
	lodsb
	call	convert_register
	mov	bl,al
	cmp	ah,1
	jne near_o0 invalid_operand_size
	mov	ah,byte [extended_code]
	mov	al,0Fh
	stosw
	mov	al,11000000b
	or	al,bl
	stosb
	jmp	instruction_assembled
ret_instruction_16bit:
	mov	ah,al
	call	operand_16bit_prefix
	mov	al,ah
	jmp	ret_instruction
ret_instruction_32bit:
	mov	ah,al
	call	operand_32bit_prefix
	mov	al,ah
ret_instruction:
	mov	byte [base_code],al
	lodsb
	dec	esi
	or	al,al
	jz	simple_ret
	cmp	al,0Fh
	je	simple_ret
	lodsb
	call	get_size_operator
	or	ah,ah
	jz	ret_imm
	cmp	ah,2
	je	ret_imm
	jmp	invalid_operand_size
      ret_imm:
	cmp	al,'('
	jne near_o0 invalid_operand
	call	get_word_value
	cmp	byte [value_type],0
	jne near_o0 invalid_use_of_symbol
	mov	dx,ax
	mov	al,byte [base_code]
	stosb
	mov	ax,dx
	stosw
	jmp	instruction_assembled
      simple_ret:
	mov	al,byte [base_code]
	inc	al
	stosb
	jmp	instruction_assembled
lea_instruction:
	mov	byte [base_code],8Dh
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	mov	al,byte [operand_size]
	push	ax
	mov	byte [operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	pop	ax
	cmp	al,2
	je	lea_16bit
	cmp	al,4
	je	lea_32bit
	jmp	invalid_operand_size
      lea_16bit:
	call	operand_16bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      lea_32bit:
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
ls_instruction:
	or	al,al
	jz	les_instruction
	cmp	al,3
	jz	lds_instruction
	add	al,0B0h
	mov	byte [extended_code],al
	mov	byte [base_code],0Fh
	jmp	ls_code_ok
      les_instruction:
	mov	byte [base_code],0C4h
	jmp	ls_code_ok
      lds_instruction:
	mov	byte [base_code],0C5h
      ls_code_ok:
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	add	byte [operand_size],2
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,4
	je	ls_16bit
	cmp	al,6
	je	ls_32bit
	jmp	invalid_operand_size
      ls_16bit:
	call	operand_16bit_prefix
	call	store_instruction
	cmp	byte [operand_size],0
	je near_o0 instruction_assembled
	cmp	byte [operand_size],4
	jne near_o0 invalid_operand_size
	jmp	instruction_assembled
      ls_32bit:
	call	operand_32bit_prefix
	call	store_instruction
	cmp	byte [operand_size],0
	je near_o0 instruction_assembled
	cmp	byte [operand_size],6
	jne near_o0 invalid_operand_size
	jmp	instruction_assembled
enter_instruction:
	lodsb
	call	get_size_operator
	cmp	ah,2
	je	enter_imm16_size_ok
	or	ah,ah
	jnz near_o0 invalid_operand_size
      enter_imm16_size_ok:
	cmp	al,'('
	jne near_o0 invalid_operand
	call	get_word_value
	cmp	byte [value_type],0
	jne near_o0 invalid_use_of_symbol
	push	ax
	mov	byte [operand_size],0
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	ah,1
	je	enter_imm8_size_ok
	or	ah,ah
	jnz near_o0 invalid_operand_size
      enter_imm8_size_ok:
	cmp	al,'('
	jne near_o0 invalid_operand
	call	get_byte_value
	mov	dl,al
	pop	bx
	mov	al,0C8h
	stosb
	mov	ax,bx
	stosw
	mov	al,dl
	stosb
	jmp	instruction_assembled
sh_instruction:
	mov	byte [postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je near_o0 sh_reg
	cmp	al,'['
	jne near_o0 invalid_operand
      sh_mem:
	call	get_address
	push	edx
	push	bx
	push	cx
	mov	al,byte [operand_size]
	push	ax
	mov	byte [operand_size],0
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'('
	je near_o0 sh_mem_imm
	cmp	al,10h
	jne near_o0 invalid_operand
      sh_mem_reg:
	lodsb
	cmp	al,11h
	jne near_o0 invalid_operand
	pop	ax
	pop	cx
	pop	bx
	pop	edx
	cmp	al,1
	je	sh_mem_cl_8bit
	cmp	al,2
	je	sh_mem_cl_16bit
	cmp	al,4
	je	sh_mem_cl_32bit
	or	ah,ah
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
      sh_mem_cl_8bit:
	mov	byte [base_code],0D2h
	call	store_instruction
	jmp	instruction_assembled
      sh_mem_cl_16bit:
	mov	byte [base_code],0D3h
	call	operand_16bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      sh_mem_cl_32bit:
	mov	byte [base_code],0D3h
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      sh_mem_imm:
	mov	al,byte [operand_size]
	or	al,al
	jz	sh_mem_imm_size_ok
	cmp	al,1
	jne near_o0 invalid_operand_size
      sh_mem_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop	ax
	pop	cx
	pop	bx
	pop	edx
	cmp	al,1
	je	sh_mem_imm_8bit
	cmp	al,2
	je	sh_mem_imm_16bit
	cmp	al,4
	je near_o0 sh_mem_imm_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
      sh_mem_imm_8bit:
	cmp	byte [value],1
	je	sh_mem_1_8bit
	mov	byte [base_code],0C0h
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      sh_mem_1_8bit:
	mov	byte [base_code],0D0h
	call	store_instruction
	jmp	instruction_assembled
      sh_mem_imm_16bit:
	cmp	byte [value],1
	je	sh_mem_1_16bit
	mov	byte [base_code],0C1h
	call	operand_16bit_prefix
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      sh_mem_1_16bit:
	mov	byte [base_code],0D1h
	call	operand_16bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      sh_mem_imm_32bit:
	cmp	byte [value],1
	je	sh_mem_1_32bit
	mov	byte [base_code],0C1h
	call	operand_32bit_prefix
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      sh_mem_1_32bit:
	mov	byte [base_code],0D1h
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      sh_reg:
	lodsb
	call	convert_register
	shl	byte [postbyte_register],3
	or	al,11000000b
	or	byte [postbyte_register],al
	mov	al,ah
	push	ax
	mov	byte [operand_size],0
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	sh_reg_imm
	cmp	al,10h
	jne near_o0 invalid_operand
      sh_reg_reg:
	lodsb
	cmp	al,11h
	jne near_o0 invalid_operand
	pop	ax
	mov	bl,byte [postbyte_register]
	cmp	al,1
	je	sh_reg_cl_8bit
	cmp	al,2
	je	sh_reg_cl_16bit
	cmp	al,4
	je	sh_reg_cl_32bit
	jmp	invalid_operand_size
      sh_reg_cl_8bit:
	mov	al,0D2h
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      sh_reg_cl_16bit:
	call	operand_16bit_prefix
	mov	al,0D3h
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      sh_reg_cl_32bit:
	call	operand_32bit_prefix
	mov	al,0D3h
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      sh_reg_imm:
	mov	al,byte [operand_size]
	or	al,al
	jz	sh_reg_imm_size_ok
	cmp	al,1
	jne near_o0 invalid_operand_size
      sh_reg_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop	ax
	mov	bl,byte [postbyte_register]
	cmp	al,1
	je	sh_reg_imm_8bit
	cmp	al,2
	je	sh_reg_imm_16bit
	cmp	al,4
	je	sh_reg_imm_32bit
	jmp	invalid_operand_size
      sh_reg_imm_8bit:
	cmp	byte [value],1
	je	sh_reg_1_8bit
	mov	al,0C0h
	stosb
	mov	al,bl
	mov	ah,byte [value]
	stosw
	jmp	instruction_assembled
      sh_reg_1_8bit:
	mov	al,0D0h
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      sh_reg_imm_16bit:
	cmp	byte [value],1
	je	sh_reg_1_16bit
	call	operand_16bit_prefix
	mov	al,0C1h
	stosb
	mov	al,bl
	mov	ah,byte [value]
	stosw
	jmp	instruction_assembled
      sh_reg_1_16bit:
	call	operand_16bit_prefix
	mov	al,0D1h
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      sh_reg_imm_32bit:
	cmp	byte [value],1
	je	sh_reg_1_32bit
	call	operand_32bit_prefix
	mov	al,0C1h
	stosb
	mov	al,bl
	mov	ah,byte [value]
	stosw
	jmp	instruction_assembled
      sh_reg_1_32bit:
	call	operand_32bit_prefix
	mov	al,0D1h
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
shd_instruction:
	mov	byte [base_code],0Fh
	mov	byte [extended_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je near_o0 shd_reg
	cmp	al,'['
	jne near_o0 invalid_operand
      shd_mem:
	call	get_address
	push	edx
	push	bx
	push	cx
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	xor	al,al
	xchg	al,byte [operand_size]
	push	ax
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	shd_mem_reg_imm
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	cmp	al,11h
	jne near_o0 invalid_operand
	pop	ax
	pop	cx
	pop	bx
	pop	edx
	cmp	al,2
	je	shd_mem_reg_cl_16bit
	cmp	al,4
	je	shd_mem_reg_cl_32bit
	jmp	invalid_operand_size
      shd_mem_reg_cl_16bit:
	call	operand_16bit_prefix
	inc	byte [extended_code]
	call	store_instruction
	jmp	instruction_assembled
      shd_mem_reg_cl_32bit:
	call	operand_32bit_prefix
	inc	byte [extended_code]
	call	store_instruction
	jmp	instruction_assembled
      shd_mem_reg_imm:
	mov	al,byte [operand_size]
	or	al,al
	jz	shd_mem_reg_imm_size_ok
	cmp	al,1
	jne near_o0 invalid_operand_size
      shd_mem_reg_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop	ax
	pop	cx
	pop	bx
	pop	edx
	cmp	al,2
	je	shd_mem_reg_imm_16bit
	cmp	al,4
	je	shd_mem_reg_imm_32bit
	jmp	invalid_operand_size
      shd_mem_reg_imm_16bit:
	call	operand_16bit_prefix
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      shd_mem_reg_imm_32bit:
	call	operand_32bit_prefix
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      shd_reg:
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	bl,byte [postbyte_register]
	shl	al,3
	or	bl,al
	or	bl,11000000b
	mov	al,ah
	push	ax
	push	bx
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	mov	byte [operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	shd_reg_reg_imm
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	cmp	al,11h
	jne near_o0 invalid_operand
	pop	bx
	pop	ax
	cmp	al,2
	je	shd_reg_reg_cl_16bit
	cmp	al,4
	je	shd_reg_reg_cl_32bit
	jmp	invalid_operand_size
      shd_reg_reg_cl_16bit:
	call	operand_16bit_prefix
	jmp	shd_reg_reg_cl_store
      shd_reg_reg_cl_32bit:
	call	operand_32bit_prefix
      shd_reg_reg_cl_store:
	mov	ah,byte [extended_code]
	inc	ah
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
      shd_reg_reg_imm:
	mov	al,byte [operand_size]
	or	al,al
	jz	shd_reg_reg_imm_size_ok
	cmp	al,1
	jne near_o0 invalid_operand_size
      shd_reg_reg_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop	bx
	pop	ax
	cmp	al,2
	je	shd_reg_reg_imm_16bit
	cmp	al,4
	je	shd_reg_reg_imm_32bit
	jmp	invalid_operand_size
      shd_reg_reg_imm_16bit:
	call	operand_16bit_prefix
	jmp	shd_reg_reg_imm_store
      shd_reg_reg_imm_32bit:
	call	operand_32bit_prefix
      shd_reg_reg_imm_store:
	mov	ah,byte [extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
movx_instruction:
	mov	byte [base_code],0Fh
	mov	byte [extended_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	mov	al,ah
	cmp	al,2
	je	movx_16bit
	cmp	al,4
	je	movx_32bit
	jmp	invalid_operand_size
      movx_16bit:
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	mov	byte [operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	movx_16bit_reg
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,1
	je	movx_16bit_mem_8bit
	or	al,al
	jnz near_o0 invalid_operand_size
      movx_16bit_mem_8bit:
	call	operand_16bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      movx_16bit_reg:
	lodsb
	call	convert_register
	mov	bl,byte [postbyte_register]
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	cmp	ah,1
	jne near_o0 invalid_operand_size
	call	operand_16bit_prefix
	mov	al,0Fh
	stosb
	mov	al,byte [extended_code]
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      movx_32bit:
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	mov	byte [operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	movx_32bit_reg
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,1
	je	movx_32bit_mem_8bit
	cmp	al,2
	je	movx_32bit_mem_16bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
      movx_32bit_mem_8bit:
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      movx_32bit_mem_16bit:
	inc	byte [extended_code]
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      movx_32bit_reg:
	lodsb
	call	convert_register
	mov	bl,byte [postbyte_register]
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	mov	al,ah
	cmp	al,1
	je	movx_32bit_reg_8bit
	cmp	al,2
	je	movx_32bit_reg_16bit
	jmp	invalid_operand_size
      movx_32bit_reg_8bit:
	call	operand_32bit_prefix
	mov	al,0Fh
	stosb
	mov	al,byte [extended_code]
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      movx_32bit_reg_16bit:
	call	operand_32bit_prefix
	mov	al,0Fh
	stosb
	mov	al,byte [extended_code]
	inc	al
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
bt_instruction:
	mov	byte [postbyte_register],al
	shl	al,3
	add	al,83h
	mov	byte [extended_code],al
	mov	byte [base_code],0Fh
	lodsb
	call	get_size_operator
	cmp	al,10h
	je near_o0 bt_reg
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	push	eax
	push	bx
	push	cx
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	cmp	byte [esi],'('
	je	bt_mem_imm
	cmp	byte [esi],11h
	jne	bt_mem_reg
	cmp	byte [esi+2],'('
	je	bt_mem_imm
      bt_mem_reg:
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	pop	cx
	pop	bx
	pop	edx
	mov	al,ah
	cmp	al,2
	je	bt_mem_reg_16bit
	cmp	al,4
	je	bt_mem_reg_32bit
	jmp	invalid_operand_size
      bt_mem_reg_16bit:
	call	operand_16bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      bt_mem_reg_32bit:
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      bt_mem_imm:
	xor	al,al
	xchg	al,byte [operand_size]
	push	ax
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne near_o0 invalid_operand
	mov	al,byte [operand_size]
	or	al,al
	jz	bt_mem_imm_size_ok
	cmp	al,1
	jne near_o0 invalid_operand_size
      bt_mem_imm_size_ok:
	mov	byte [extended_code],0BAh
	call	get_byte_value
	mov	byte [value],al
	pop	ax
	cmp	al,2
	je	bt_mem_imm_16bit
	cmp	al,4
	je	bt_mem_imm_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
	jmp	bt_mem_imm_32bit
      bt_mem_imm_16bit:
	call	operand_16bit_prefix
	pop	cx
	pop	bx
	pop	edx
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      bt_mem_imm_32bit:
	call	operand_32bit_prefix
	pop	cx
	pop	bx
	pop	edx
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      bt_reg:
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	cmp	byte [esi],'('
	je	bt_reg_imm
	cmp	byte [esi],11h
	jne	bt_reg_reg
	cmp	byte [esi+2],'('
	je	bt_reg_imm
      bt_reg_reg:
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	bl,byte [postbyte_register]
	shl	al,3
	or	bl,al
	or	bl,11000000b
	mov	al,ah
	cmp	al,2
	je	bt_reg_reg_16bit
	cmp	al,4
	je	bt_reg_reg_32bit
	jmp	invalid_operand_size
      bt_reg_reg_16bit:
	call	operand_16bit_prefix
	mov	ah,byte [extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
      bt_reg_reg_32bit:
	call	operand_32bit_prefix
	mov	ah,byte [extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
      bt_reg_imm:
	xor	al,al
	xchg	al,byte [operand_size]
	push	ax
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne near_o0 invalid_operand
	mov	al,byte [operand_size]
	or	al,al
	jz	bt_reg_imm_size_ok
	cmp	al,1
	jne near_o0 invalid_operand_size
      bt_reg_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop	ax
	cmp	al,2
	je	bt_reg_imm_16bit
	cmp	al,4
	je	bt_reg_imm_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
	jmp	bt_reg_imm_32bit
      bt_reg_imm_16bit:
	call	operand_16bit_prefix
	jmp	bt_reg_imm_store
      bt_reg_imm_32bit:
	call	operand_32bit_prefix
      bt_reg_imm_store:
	mov	ax,0BA0Fh
	stosw
	mov	al,11000000b
	or	al,byte [postbyte_register]
	mov	ah,byte [extended_code]
	sub	ah,83h
	or	al,ah
	stosb
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
bs_instruction:
	mov	byte [extended_code],al
	mov	byte [base_code],0Fh
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	cmp	al,10h
	je	bs_reg_reg
	cmp	al,'['
	jne near_o0 invalid_argument
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,2
	je	bs_reg_mem_16bit
	cmp	al,4
	je	bs_reg_mem_32bit
	jmp	invalid_operand_size
      bs_reg_mem_16bit:
	call	operand_16bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      bs_reg_mem_32bit:
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      bs_reg_reg:
	lodsb
	call	convert_register
	mov	bl,byte [postbyte_register]
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	mov	al,ah
	cmp	al,2
	je	bs_reg_reg_16bit
	cmp	al,4
	je	bs_reg_reg_32bit
	jmp	invalid_operand_size
      bs_reg_reg_16bit:
	call	operand_16bit_prefix
	jmp	bs_reg_reg_store
      bs_reg_reg_32bit:
	call	operand_32bit_prefix
      bs_reg_reg_store:
	mov	ah,byte [extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
imul_instruction:
	mov	byte [base_code],0F6h
	mov	byte [postbyte_register],5
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	imul_reg
	cmp	al,'['
	jne near_o0 invalid_operand
      imul_mem:
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,1
	je	imul_mem_8bit
	cmp	al,2
	je	imul_mem_16bit
	cmp	al,4
	je	imul_mem_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
      imul_mem_8bit:
	call	store_instruction
	jmp	instruction_assembled
      imul_mem_16bit:
	call	operand_16bit_prefix
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      imul_mem_32bit:
	call	operand_32bit_prefix
	inc	byte [base_code]
	call	store_instruction
	jmp	instruction_assembled
      imul_reg:
	lodsb
	call	convert_register
	cmp	byte [esi],','
	je	imul_reg_
	mov	bl,byte [postbyte_register]
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	cmp	ah,1
	je	imul_reg_8bit
	cmp	ah,2
	je	imul_reg_16bit
	cmp	ah,4
	je	imul_reg_32bit
	jmp	invalid_operand_size
      imul_reg_8bit:
	mov	ah,bl
	mov	al,0F6h
	stosw
	jmp	instruction_assembled
      imul_reg_16bit:
	call	operand_16bit_prefix
	mov	ah,bl
	mov	al,0F7h
	stosw
	jmp	instruction_assembled
      imul_reg_32bit:
	call	operand_32bit_prefix
	mov	ah,bl
	mov	al,0F7h
	stosw
	jmp	instruction_assembled
      imul_reg_:
	mov	byte [postbyte_register],al
	inc	esi
	cmp	byte [esi],'('
	je near_o0 imul_reg_imm
	cmp	byte [esi],11h
	jne	imul_reg__
	cmp	byte [esi+2],'('
	je near_o0 imul_reg_imm
      imul_reg__:
	lodsb
	call	get_size_operator
	cmp	al,10h
	je near_o0 imul_reg_reg
	cmp	al,'['
	je	imul_reg_mem
	jne near_o0 invalid_operand
      imul_reg_mem:
	call	get_address
	push	edx
	push	bx
	push	cx
	cmp	byte [esi],','
	je	imul_reg_mem_imm
	mov	al,byte [operand_size]
	cmp	al,2
	je	imul_reg_mem_16bit
	cmp	al,4
	je	imul_reg_mem_32bit
	jmp	invalid_operand_size
      imul_reg_mem_16bit:
	call	operand_16bit_prefix
	jmp	imul_reg_mem_store
      imul_reg_mem_32bit:
	call	operand_32bit_prefix
      imul_reg_mem_store:
	pop	cx
	pop	bx
	pop	edx
	mov	byte [base_code],0Fh
	mov	byte [extended_code],0AFh
	call	store_instruction
	jmp	instruction_assembled
      imul_reg_mem_imm:
	inc	esi
	xor	cl,cl
	xchg	cl,byte [operand_size]
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne near_o0 invalid_operand
	mov	al,byte [operand_size]
	mov	byte [operand_size],cl
	cmp	al,1
	je	imul_reg_mem_imm_8bit
	cmp	al,2
	je	imul_reg_mem_imm_16bit
	cmp	al,4
	je near_o0 imul_reg_mem_imm_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	cl,2
	je	imul_reg_mem_imm_16bit
	cmp	cl,4
	je near_o0 imul_reg_mem_imm_32bit
	jmp	invalid_operand_size
      imul_reg_mem_imm_8bit:
	call	get_byte_value
	mov	byte [value],al
	pop	cx
	pop	bx
	pop	edx
	mov	byte [base_code],6Bh
	cmp	byte [operand_size],2
	je	imul_reg_mem_16bit_imm_8bit
	cmp	byte [operand_size],4
	je	imul_reg_mem_32bit_imm_8bit
	jmp	invalid_operand_size
      imul_reg_mem_16bit_imm_8bit:
	call	operand_16bit_prefix
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      imul_reg_mem_32bit_imm_8bit:
	call	operand_32bit_prefix
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      imul_reg_mem_imm_16bit:
	call	get_word_value
	mov	word [value],ax
	pop	cx
	pop	bx
	pop	edx
	mov	byte [base_code],69h
	cmp	byte [operand_size],2
	jne near_o0 invalid_operand_size
	call	operand_16bit_prefix
	call	store_instruction
	mov	ax,word [value]
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      imul_reg_mem_imm_32bit:
	call	get_dword_value
	mov	dword [value],eax
	pop	cx
	pop	bx
	pop	edx
	mov	byte [base_code],69h
	cmp	byte [operand_size],4
	jne near_o0 invalid_operand_size
	call	operand_32bit_prefix
	call	store_instruction
	mov	eax,dword [value]
	call	mark_relocation
	stosd
	jmp	instruction_assembled
      imul_reg_imm:
	mov	dl,byte [postbyte_register]
	mov	bl,dl
	dec	esi
	jmp	imul_reg_reg_imm
      imul_reg_reg:
	lodsb
	call	convert_register
	mov	bl,byte [postbyte_register]
	mov	dl,al
	cmp	byte [esi],','
	je	imul_reg_reg_imm
	mov	al,ah
	cmp	al,2
	je	imul_reg_reg_16bit
	cmp	al,4
	je	imul_reg_reg_32bit
	jmp	invalid_operand_size
      imul_reg_reg_16bit:
	call	operand_16bit_prefix
	jmp	imul_reg_reg_store
      imul_reg_reg_32bit:
	call	operand_32bit_prefix
      imul_reg_reg_store:
	mov	ax,0AF0Fh
	stosw
	mov	al,dl
	shl	bl,3
	or	al,bl
	or	al,11000000b
	stosb
	jmp	instruction_assembled
      imul_reg_reg_imm:
	inc	esi
	xor	cl,cl
	xchg	cl,byte [operand_size]
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne near_o0 invalid_operand
	mov	al,byte [operand_size]
	mov	byte [operand_size],cl
	cmp	al,1
	je	imul_reg_reg_imm_8bit
	cmp	al,2
	je near_o0 imul_reg_reg_imm_16bit
	cmp	al,4
	je near_o0 imul_reg_reg_imm_32bit
	or	al,al
	jnz near_o0 invalid_operand_size
	cmp	cl,2
	je	imul_reg_reg_imm_16bit
	cmp	cl,4
	je near_o0 imul_reg_reg_imm_32bit
	jmp	invalid_operand_size
      imul_reg_reg_imm_8bit:
	push	bx
	push	dx
	call	get_byte_value
	pop	dx
	pop	bx
      imul_reg_reg_imm_8bit_store:
	mov	byte [value],al
	cmp	byte [operand_size],2
	je	imul_reg_reg_16bit_imm_8bit
	cmp	byte [operand_size],4
	je	imul_reg_reg_32bit_imm_8bit
	jmp	invalid_operand_size
      imul_reg_reg_16bit_imm_8bit:
	call	operand_16bit_prefix
	mov	al,6Bh
	stosb
	mov	al,dl
	shl	bl,3
	or	al,bl
	or	al,11000000b
	stosb
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      imul_reg_reg_32bit_imm_8bit:
	call	operand_32bit_prefix
	mov	al,6Bh
	stosb
	mov	al,dl
	shl	bl,3
	or	al,bl
	or	al,11000000b
	stosb
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      imul_reg_reg_imm_16bit:
	push	bx
	push	dx
	call	get_word_value
	pop	dx
	pop	bx
	cmp	byte [value_type],0
	jne	imul_reg_reg_imm_16bit_forced
	cmp	ax,-80h
	jl	imul_reg_reg_imm_16bit_forced
	cmp	ax,80h
	jl	imul_reg_reg_imm_8bit_store
      imul_reg_reg_imm_16bit_forced:
	mov	word [value],ax
	call	operand_16bit_prefix
	mov	al,69h
	stosb
	mov	al,dl
	shl	bl,3
	or	al,bl
	or	al,11000000b
	stosb
	mov	ax,word [value]
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      imul_reg_reg_imm_32bit:
	push	bx
	push	dx
	call	get_dword_value
	pop	dx
	pop	bx
	cmp	byte [value_type],0
	jne	imul_reg_reg_imm_32bit_forced
	cmp	ax,-80h
	jl	imul_reg_reg_imm_32bit_forced
	cmp	ax,80h
	jl near_o0 imul_reg_reg_imm_8bit_store
      imul_reg_reg_imm_32bit_forced:
	mov	dword [value],eax
	call	operand_32bit_prefix
	mov	al,69h
	stosb
	mov	al,dl
	shl	bl,3
	or	al,bl
	or	al,11000000b
	stosb
	mov	eax,dword [value]
	call	mark_relocation
	stosd
	jmp	instruction_assembled
in_instruction:
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	or	al,al
	jnz near_o0 invalid_operand
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	mov	al,ah
	push	ax
	mov	byte [operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	in_imm
	cmp	al,10h
	je	in_reg
	jmp	invalid_operand
      in_reg:
	lodsb
	cmp	al,22h
	jne near_o0 invalid_operand
	pop	ax
	cmp	al,1
	je	in_al_dx
	cmp	al,2
	je	in_ax_dx
	cmp	al,4
	je	in_eax_dx
	jmp	invalid_operand_size
      in_al_dx:
	mov	al,0ECh
	stosb
	jmp	instruction_assembled
      in_ax_dx:
	call	operand_16bit_prefix
	mov	al,0EDh
	stosb
	jmp	instruction_assembled
      in_eax_dx:
	call	operand_32bit_prefix
	mov	al,0EDh
	stosb
	jmp	instruction_assembled
      in_imm:
	mov	al,byte [operand_size]
	or	al,al
	jz	in_imm_size_ok
	cmp	al,1
	jne near_o0 invalid_operand_size
      in_imm_size_ok:
	call	get_byte_value
	mov	dl,al
	pop	ax
	cmp	al,1
	je	in_al_imm
	cmp	al,2
	je	in_ax_imm
	cmp	al,4
	je	in_eax_imm
	jmp	invalid_operand_size
      in_al_imm:
	mov	al,0E4h
	stosb
	mov	al,dl
	stosb
	jmp	instruction_assembled
      in_ax_imm:
	call	operand_16bit_prefix
	mov	al,0E5h
	stosb
	mov	al,dl
	stosb
	jmp	instruction_assembled
      in_eax_imm:
	call	operand_32bit_prefix
	mov	al,0E5h
	stosb
	mov	al,dl
	stosb
	jmp	instruction_assembled
out_instruction:
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	out_imm
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	cmp	al,22h
	jne near_o0 invalid_operand
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	mov	byte [operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	or	al,al
	jnz near_o0 invalid_operand
	mov	al,ah
	cmp	al,1
	je	out_dx_al
	cmp	al,2
	je	out_dx_ax
	cmp	al,4
	je	out_dx_eax
	jmp	invalid_operand_size
      out_dx_al:
	mov	al,0EEh
	stosb
	jmp	instruction_assembled
      out_dx_ax:
	call	operand_16bit_prefix
	mov	al,0EFh
	stosb
	jmp	instruction_assembled
      out_dx_eax:
	call	operand_32bit_prefix
	mov	al,0EFh
	stosb
	jmp	instruction_assembled
      out_imm:
	mov	al,byte [operand_size]
	or	al,al
	jz	out_imm_size_ok
	cmp	al,1
	jne near_o0 invalid_operand_size
      out_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	mov	byte [operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	or	al,al
	jnz near_o0 invalid_operand
	mov	al,ah
	cmp	al,1
	je	out_imm_al
	cmp	al,2
	je	out_imm_ax
	cmp	al,4
	je	out_imm_eax
	jmp	invalid_operand_size
      out_imm_al:
	mov	al,0E6h
	stosb
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      out_imm_ax:
	call	operand_16bit_prefix
	mov	al,0E7h
	stosb
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      out_imm_eax:
	call	operand_32bit_prefix
	mov	al,0E7h
	stosb
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
lar_instruction:
	mov	byte [extended_code],al
	mov	byte [base_code],0Fh
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	lar_reg_reg
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	mov	al,byte [operand_size]
	cmp	al,2
	je	lar_16bit
	cmp	al,4
	je	lar_32bit
	jmp	invalid_operand_size
      lar_16bit:
	call	operand_16bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      lar_32bit:
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      lar_reg_reg:
	lodsb
	call	convert_register
	mov	bl,byte [postbyte_register]
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	mov	al,ah
	cmp	al,2
	je	lar_reg_reg_16bit
	cmp	al,4
	je	lar_reg_reg_32bit
	jmp	invalid_operand_size
      lar_reg_reg_32bit:
	call	operand_32bit_prefix
	jmp	lar_reg_reg_store
      lar_reg_reg_16bit:
	call	operand_16bit_prefix
      lar_reg_reg_store:
	mov	al,0Fh
	mov	ah,byte [extended_code]
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
invlpg_instruction:
	mov	byte [base_code],0Fh
	mov	byte [extended_code],1
	mov	byte [postbyte_register],7
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	call	store_instruction
	jmp	instruction_assembled
basic_486_instruction:
	mov	byte [base_code],0Fh
	mov	byte [extended_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je near_o0 basic_486_reg
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	push	edx
	push	bx
	push	cx
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	pop	cx
	pop	bx
	pop	edx
	mov	al,ah
	cmp	al,1
	je	basic_486_mem_reg_8bit
	cmp	al,2
	je	basic_486_mem_reg_16bit
	cmp	al,4
	je	basic_486_mem_reg_32bit
	jmp	invalid_operand_size
      basic_486_mem_reg_8bit:
	call	store_instruction
	jmp	instruction_assembled
      basic_486_mem_reg_16bit:
	call	operand_16bit_prefix
	inc	byte [extended_code]
	call	store_instruction
	jmp	instruction_assembled
      basic_486_mem_reg_32bit:
	call	operand_32bit_prefix
	inc	byte [extended_code]
	call	store_instruction
	jmp	instruction_assembled
      basic_486_reg:
	lodsb
	call	convert_register
	mov	byte [postbyte_register],al
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	bl,byte [postbyte_register]
	shl	al,3
	or	bl,al
	or	bl,11000000b
	mov	al,ah
	cmp	al,1
	je	basic_486_reg_reg_8bit
	cmp	al,2
	je	basic_486_reg_reg_16bit
	cmp	al,4
	je	basic_486_reg_reg_32bit
	jmp	invalid_operand_size
      basic_486_reg_reg_32bit:
	call	operand_32bit_prefix
	inc	byte [extended_code]
	jmp	basic_486_reg_reg_8bit
      basic_486_reg_reg_16bit:
	call	operand_16bit_prefix
	inc	byte [extended_code]
      basic_486_reg_reg_8bit:
	mov	al,0Fh
	mov	ah,byte [extended_code]
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
bswap_instruction:
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	call	convert_register
	mov	ah,al
	add	ah,0C8h
	cmp	ah,4
	jne near_o0 invalid_operand_size
	call	operand_32bit_prefix
	mov	al,0Fh
	stosw
	jmp	instruction_assembled
conditional_jump:
	mov	byte [base_code],al
	lodsb
	call	get_jump_operator
	cmp	byte [jump_type],2
	je near_o0 invalid_operand
	call	get_size_operator
	cmp	al,'('
	jne near_o0 invalid_operand
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	cmp	byte [value_type],1
	je near_o0 invalid_use_of_symbol
	sub	eax,edi
	add	eax,dword [org_start]
	sub	eax,2
	cmp	dword [org_sib],0
	jne near_o0 invalid_use_of_symbol
	mov	bl,byte [operand_size]
	cmp	bl,1
	je near_o0 conditional_jump_8bit
	cmp	bl,2
	je	conditional_jump_16bit
	cmp	bl,4
	je	conditional_jump_32bit
	or	bl,bl
	jnz near_o0 invalid_operand_size
	cmp	eax,80h
	jb	conditional_jump_8bit
	cmp	eax,-80h
	jae	conditional_jump_8bit
	cmp	byte [code_type],16
	je	conditional_jump_16bit
      conditional_jump_32bit:
	sub	eax,4
	mov	edx,eax
	mov	ecx,edi
	call	operand_32bit_prefix
	sub	edx,edi
	add	edx,ecx
	mov	ah,byte [base_code]
	add	ah,10h
	mov	al,0Fh
	stosw
	mov	eax,edx
	stosd
	jmp	instruction_assembled
      conditional_jump_16bit:
	sub	eax,2
	mov	edx,eax
	mov	ecx,edi
	call	operand_16bit_prefix
	sub	edx,edi
	add	edx,ecx
	mov	ah,byte [base_code]
	add	ah,10h
	mov	al,0Fh
	stosw
	mov	eax,edx
	stosw
	cmp	eax,10000h
	jge	jump_out_of_range
	cmp	eax,-10000h
	jl	jump_out_of_range
	jmp	instruction_assembled
      conditional_jump_8bit:
	mov	edx,eax
	mov	ah,al
	mov	al,byte [base_code]
	stosw
	cmp	edx,80h
	jge	jump_out_of_range
	cmp	edx,-80h
	jl	jump_out_of_range
	jmp	instruction_assembled
      jump_out_of_range:
	cmp	dword [error_line],0
	jne near_o0 instruction_assembled
	mov	eax,dword [current_line]
	mov	dword [error_line],eax
	mov	dword [error],relative_jump_out_of_range
	jmp	instruction_assembled
loop_instruction_16bit:
	mov	cl,al
	call	address_16bit_prefix
	mov	al,cl
	jmp	loop_instruction
loop_instruction_32bit:
	mov	cl,al
	call	address_32bit_prefix
	mov	al,cl
loop_instruction:
	mov	byte [base_code],al
	lodsb
	call	get_jump_operator
	cmp	byte [jump_type],2
	je near_o0 invalid_operand
	call	get_size_operator
	cmp	al,'('
	jne near_o0 invalid_operand
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	cmp	byte [value_type],1
	je near_o0 invalid_use_of_symbol
	sub	eax,edi
	add	eax,dword [org_start]
	cmp	dword [org_sib],0
	jne near_o0 invalid_use_of_symbol
	mov	bl,byte [operand_size]
	cmp	bl,1
	je	loop_8bit
	or	bl,bl
	jnz near_o0 invalid_operand_size
      loop_8bit:
	sub	eax,2
	mov	edx,eax
	mov	al,byte [base_code]
	stosb
	mov	eax,edx
	stosb
	cmp	eax,80h
	jge near_o0 jump_out_of_range
	cmp	eax,-80h
	jl near_o0 jump_out_of_range
	jmp	instruction_assembled
call_instruction:
	mov	byte [postbyte_register],10b
	mov	byte [base_code],0E8h
	mov	byte [extended_code],9Ah
	jmp	process_jmp
jmp_instruction:
	mov	byte [postbyte_register],100b
	mov	byte [base_code],0E9h
	mov	byte [extended_code],0EAh
      process_jmp:
	lodsb
	call	get_jump_operator
	call	get_size_operator
	cmp	al,10h
	je near_o0 jmp_reg
	cmp	al,'('
	je near_o0 jmp_imm
	cmp	al,'['
	jne near_o0 invalid_operand
      jmp_mem:
	call	get_address
	mov	byte [base_code],0FFh
	mov	edx,eax
	mov	al,byte [operand_size]
	or	al,al
	jz	jmp_mem_size_not_specified
	cmp	al,2
	je near_o0 jmp_mem_16bit
	cmp	al,4
	je	jmp_mem_32bit
	cmp	al,6
	je	jmp_mem_48bit
	jmp	invalid_operand_size
      jmp_mem_size_not_specified:
	cmp	byte [jump_type],2
	je	jmp_mem_far
	cmp	byte [jump_type],1
	je	jmp_mem_near
	cmp	byte [current_pass],0
	jne near_o0 operand_size_not_specified
	cmp	byte [next_pass_needed],0
	je near_o0 operand_size_not_specified
      jmp_mem_near:
	cmp	byte [code_type],16
	je	jmp_mem_16bit
	jmp	jmp_mem_near_32bit
      jmp_mem_far:
	cmp	byte [code_type],16
	je	jmp_mem_far_32bit
      jmp_mem_48bit:
	cmp	byte [jump_type],1
	je near_o0 invalid_operand_size
	call	operand_32bit_prefix
	inc	byte [postbyte_register]
	call	store_instruction
	jmp	instruction_assembled
      jmp_mem_32bit:
	cmp	byte [jump_type],2
	je	jmp_mem_far_32bit
	cmp	byte [jump_type],1
	je	jmp_mem_near_32bit
	cmp	byte [code_type],16
	je	jmp_mem_far_32bit
      jmp_mem_near_32bit:
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      jmp_mem_far_32bit:
	call	operand_16bit_prefix
	inc	byte [postbyte_register]
	call	store_instruction
	jmp	instruction_assembled
      jmp_mem_16bit:
	cmp	byte [jump_type],2
	je near_o0 invalid_operand_size
	call	operand_16bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      jmp_reg:
	lodsb
	call	convert_register
	mov	bl,al
	or	bl,11000000b
	mov	al,ah
	cmp	al,2
	je	jmp_reg_16bit
	cmp	al,4
	je	jmp_reg_32bit
	jmp	invalid_operand_size
      jmp_reg_32bit:
	cmp	byte [jump_type],2
	je	jmp_reg_far32bit
	cmp	byte [jump_type],1
	je	jmp_reg_near32bit
	cmp	byte [code_type],16
	je	jmp_reg_far32bit
      jmp_reg_near32bit:
	call	operand_32bit_prefix
	mov	al,byte [postbyte_register]
	shl	al,3
	or	bl,al
	mov	ah,bl
	mov	al,0FFh
	stosw
	jmp	instruction_assembled
      jmp_reg_far32bit:
	call	operand_32bit_prefix
	mov	al,byte [postbyte_register]
	inc	al
	shl	al,3
	or	bl,al
	mov	ah,bl
	mov	al,0FFh
	stosw
	jmp	instruction_assembled
      jmp_reg_16bit:
	cmp	byte [jump_type],2
	je near_o0 invalid_operand_size
	call	operand_16bit_prefix
	mov	al,byte [postbyte_register]
	shl	al,3
	or	bl,al
	mov	ah,bl
	mov	al,0FFh
	stosw
	jmp	instruction_assembled
      jmp_imm:
	push	esi
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	pop	ebx
	cmp	byte [esi],':'
	je near_o0 jmp_far
	cmp	byte [value_type],1
	je near_o0 invalid_use_of_symbol
	cmp	byte [jump_type],2
	je near_o0 invalid_operand
	sub	eax,edi
	add	eax,dword [org_start]
	sub	eax,2
	cmp	dword [org_sib],0
	jne near_o0 invalid_use_of_symbol
	mov	bl,byte [operand_size]
	cmp	bl,1
	je near_o0 jmp_8bit
	cmp	bl,2
	je	jmp_16bit
	cmp	bl,4
	je	jmp_32bit
	or	bl,bl
	jnz near_o0 invalid_operand_size
	cmp	byte [base_code],0E9h
	jne	jmp_no8bit
	cmp	eax,80h
	jb	jmp_8bit
	cmp	eax,-80h
	jae	jmp_8bit
      jmp_no8bit:
	cmp	byte [code_type],32
	je	jmp_32bit
      jmp_16bit:
	dec	eax
	mov	edx,eax
	mov	ecx,edi
	call	operand_16bit_prefix
	sub	edx,edi
	add	edx,ecx
	mov	al,byte [base_code]
	stosb
	mov	eax,edx
	stosw
	cmp	eax,10000h
	jge near_o0 jump_out_of_range
	cmp	eax,-10000h
	jl near_o0 jump_out_of_range
	jmp	instruction_assembled
      jmp_32bit:
	sub	eax,3
	mov	edx,eax
	mov	ecx,edi
	call	operand_32bit_prefix
	sub	edx,edi
	add	edx,ecx
	mov	al,byte [base_code]
	stosb
	mov	eax,edx
	stosd
	jmp	instruction_assembled
      jmp_8bit:
	cmp	byte [base_code],0E9h
	jne near_o0 invalid_operand_size
	mov	edx,eax
	mov	ah,al
	mov	al,0EBh
	stosw
	cmp	edx,80h
	jge near_o0 jump_out_of_range
	cmp	edx,-80h
	jl near_o0 jump_out_of_range
	jmp	instruction_assembled
      jmp_far:
	cmp	byte [jump_type],1
	je near_o0 invalid_operand
	mov	esi,ebx
	call	get_word_value
	mov	dx,ax
	mov	bl,byte [operand_size]
	cmp	bl,4
	je	jmp_far_16bit
	cmp	bl,6
	je	jmp_far_32bit
	or	bl,bl
	jnz near_o0 invalid_operand_size
	cmp	byte [code_type],32
	je	jmp_far_32bit
      jmp_far_16bit:
	inc	esi
	lodsb
	cmp	al,'('
	jne near_o0 invalid_operand
	mov	al,byte [value_type]
	push	ax
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_word_value
	mov	ebx,eax
	call	operand_16bit_prefix
	mov	al,byte [extended_code]
	stosb
	mov	ax,bx
	call	mark_relocation
	stosw
	pop	ax
	mov	byte [value_type],al
	mov	ax,dx
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      jmp_far_32bit:
	inc	esi
	lodsb
	cmp	al,'('
	jne near_o0 invalid_operand
	mov	al,byte [value_type]
	push	ax
	cmp	byte [esi],'.'
	je near_o0 invalid_value
	call	get_dword_value
	mov	ebx,eax
	call	operand_32bit_prefix
	mov	al,byte [extended_code]
	stosb
	mov	eax,ebx
	call	mark_relocation
	stosd
	pop	ax
	mov	byte [value_type],al
	mov	ax,dx
	call	mark_relocation
	stosw
	jmp	instruction_assembled
ins_instruction:
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	or	eax,eax
	jnz near_o0 invalid_address
	or	bl,ch
	jnz near_o0 invalid_address
	cmp	bh,27h
	je	ins_16bit
	cmp	bh,47h
	jne near_o0 invalid_address
	call	address_32bit_prefix
	jmp	ins_store
      ins_16bit:
	call	address_16bit_prefix
      ins_store:
	cmp	byte [segment_register],1
	ja near_o0 invalid_address
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	cmp	al,22h
	jne near_o0 invalid_operand
	mov	al,6Ch
	cmp	byte [operand_size],1
	je near_o0 simple_instruction
	inc	al
	cmp	byte [operand_size],2
	je near_o0 simple_instruction_16bit
	cmp	byte [operand_size],4
	je near_o0 simple_instruction_32bit
	cmp	byte [operand_size],0
	je near_o0 operand_size_not_specified
	jmp	invalid_operand_size
outs_instruction:
	lodsb
	cmp	al,10h
	jne near_o0 invalid_operand
	lodsb
	cmp	al,22h
	jne near_o0 invalid_operand
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	or	eax,eax
	jnz near_o0 invalid_address
	or	bl,ch
	jnz near_o0 invalid_address
	cmp	bh,26h
	je	outs_16bit
	cmp	bh,46h
	jne near_o0 invalid_address
	call	address_32bit_prefix
	jmp	outs_store
      outs_16bit:
	call	address_16bit_prefix
      outs_store:
	cmp	byte [segment_register],4
	je	outs_segment_ok
	call	store_segment_prefix
      outs_segment_ok:
	mov	al,6Eh
	cmp	byte [operand_size],1
	je near_o0 simple_instruction
	inc	al
	cmp	byte [operand_size],2
	je near_o0 simple_instruction_16bit
	cmp	byte [operand_size],4
	je near_o0 simple_instruction_32bit
	cmp	byte [operand_size],0
	je near_o0 operand_size_not_specified
	jmp	invalid_operand_size
movs_instruction:
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	or	eax,eax
	jnz near_o0 invalid_address
	or	bl,ch
	jnz near_o0 invalid_address
	cmp	byte [segment_register],1
	ja near_o0 invalid_address
	push	bx
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	pop	dx
	or	eax,eax
	jnz near_o0 invalid_address
	or	bl,ch
	jnz near_o0 invalid_address
	mov	al,dh
	mov	ah,bh
	shr	al,4
	shr	ah,4
	cmp	al,ah
	jne near_o0 address_sizes_do_not_agree
	and	bh,111b
	and	dh,111b
	cmp	bh,6
	jne near_o0 invalid_address
	cmp	dh,7
	jne near_o0 invalid_address
	cmp	al,2
	je	movs_16bit
	cmp	al,4
	jne near_o0 invalid_address
	call	address_32bit_prefix
	jmp	movs_store
      movs_16bit:
	call	address_16bit_prefix
      movs_store:
	cmp	byte [segment_register],4
	je	movs_segment_ok
	call	store_segment_prefix
      movs_segment_ok:
	mov	al,0A4h
	mov	bl,byte [operand_size]
	cmp	bl,1
	je near_o0 simple_instruction
	inc	al
	cmp	bl,2
	je near_o0 simple_instruction_16bit
	cmp	bl,4
	je near_o0 simple_instruction_32bit
	or	bl,bl
	jz near_o0 operand_size_not_specified
	jmp	invalid_operand_size
lods_instruction:
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	or	eax,eax
	jnz near_o0 invalid_address
	or	bl,ch
	jnz near_o0 invalid_address
	cmp	bh,26h
	je	lods_16bit
	cmp	bh,46h
	jne near_o0 invalid_address
	call	address_32bit_prefix
	jmp	lods_store
      lods_16bit:
	call	address_16bit_prefix
      lods_store:
	cmp	byte [segment_register],4
	je	lods_segment_ok
	call	store_segment_prefix
      lods_segment_ok:
	mov	al,0ACh
	cmp	byte [operand_size],1
	je near_o0 simple_instruction
	inc	al
	cmp	byte [operand_size],2
	je near_o0 simple_instruction_16bit
	cmp	byte [operand_size],4
	je near_o0 simple_instruction_32bit
	cmp	byte [operand_size],0
	je near_o0 operand_size_not_specified
	jmp	invalid_operand_size
stos_instruction:
	mov	byte [base_code],al
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	or	eax,eax
	jnz near_o0 invalid_address
	or	bl,ch
	jnz near_o0 invalid_address
	cmp	bh,27h
	je	stos_16bit
	cmp	bh,47h
	jne near_o0 invalid_address
	call	address_32bit_prefix
	jmp	stos_store
      stos_16bit:
	call	address_16bit_prefix
      stos_store:
	cmp	byte [segment_register],1
	ja near_o0 invalid_address
	mov	al,byte [base_code]
	cmp	byte [operand_size],1
	je near_o0 simple_instruction
	inc	al
	cmp	byte [operand_size],2
	je near_o0 simple_instruction_16bit
	cmp	byte [operand_size],4
	je near_o0 simple_instruction_32bit
	cmp	byte [operand_size],0
	je near_o0 operand_size_not_specified
	jmp	invalid_operand_size
cmps_instruction:
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	or	eax,eax
	jnz near_o0 invalid_address
	or	bl,ch
	jnz near_o0 invalid_address
	mov	al,byte [segment_register]
	push	ax
	push	bx
	lodsb
	cmp	al,','
	jne near_o0 invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	or	eax,eax
	jnz near_o0 invalid_address
	or	bl,ch
	jnz near_o0 invalid_address
	pop	dx
	pop	ax
	cmp	byte [segment_register],1
	ja near_o0 invalid_address
	mov	byte [segment_register],al
	mov	al,dh
	mov	ah,bh
	shr	al,4
	shr	ah,4
	cmp	al,ah
	jne near_o0 address_sizes_do_not_agree
	and	bh,111b
	and	dh,111b
	cmp	bh,7
	jne near_o0 invalid_address
	cmp	dh,6
	jne near_o0 invalid_address
	cmp	al,2
	je	cmps_16bit
	cmp	al,4
	jne near_o0 invalid_address
	call	address_32bit_prefix
	jmp	cmps_store
      cmps_16bit:
	call	address_16bit_prefix
      cmps_store:
	cmp	byte [segment_register],4
	je	cmps_segment_ok
	call	store_segment_prefix
      cmps_segment_ok:
	mov	al,0A6h
	mov	bl,byte [operand_size]
	cmp	bl,1
	je near_o0 simple_instruction
	inc	al
	cmp	bl,2
	je near_o0 simple_instruction_16bit
	cmp	bl,4
	je near_o0 simple_instruction_32bit
	or	bl,bl
	jz near_o0 operand_size_not_specified
	jmp	invalid_operand_size
xlat_instruction:
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne near_o0 invalid_operand
	call	get_address
	or	eax,eax
	jnz near_o0 invalid_address
	or	bl,ch
	jnz near_o0 invalid_address
	cmp	bh,23h
	je	xlat_16bit
	cmp	bh,43h
	jne near_o0 invalid_address
	call	address_32bit_prefix
	jmp	xlat_store
      xlat_16bit:
	call	address_16bit_prefix
      xlat_store:
	call	store_segment_prefix_if_necessary
	mov	al,0D7h
	cmp	byte [operand_size],1
	jbe near_o0 simple_instruction
	jmp	invalid_operand_size
cmpsd_instruction:
	mov	al,0A7h
	mov	ah,[esi]
	or	ah,ah
	jmp	simple_instruction_32bit
movsd_instruction:
	mov	al,0A5h
	mov	ah,[esi]
	or	ah,ah
	jmp	simple_instruction_32bit
convert_register:
	mov	ah,al
	shr	ah,4
	and	al,111b
	cmp	ah,4
	ja near_o0 invalid_operand
      match_register_size:
	cmp	ah,byte [operand_size]
	je	register_size_ok
	cmp	byte [operand_size],0
	jne near_o0 operand_sizes_do_not_match
	mov	byte [operand_size],ah
      register_size_ok:
	ret
get_size_operator:
	xor	ah,ah
	cmp	al,11h
	jne	operand_size_ok
	lodsw
	xchg	al,ah
	mov	byte [forced_size],1
	cmp	ah,byte [operand_size]
	je	forced_ok
	cmp	byte [operand_size],0
	jne near_o0 operand_sizes_do_not_match
	mov	byte [operand_size],ah
      forced_ok:
	ret
      operand_size_ok:
	cmp	al,'['
	jne	forced_ok
	mov	byte [forced_size],0
	ret
get_jump_operator:
	mov	byte [jump_type],0
	cmp	al,12h
	jne	jump_operator_ok
	lodsw
	mov	byte [jump_type],al
	mov	al,ah
      jump_operator_ok:
	ret
operand_16bit_prefix:
	cmp	byte [code_type],16
	je	size_prefix_ok
	mov	al,66h
	stosb
	ret
operand_32bit_prefix:
	cmp	byte [code_type],32
	je	size_prefix_ok
	mov	al,66h
	stosb
      size_prefix_ok:
	ret
store_segment_prefix_if_necessary:
	mov	al,byte [segment_register]
	or	al,al
	jz	segment_prefix_ok
	cmp	al,3
	je	ss_prefix
	cmp	al,4
	ja	segment_prefix_386
	jb	segment_prefix
	cmp	bh,25h
	je	segment_prefix
	cmp	bh,45h
	je	segment_prefix
	cmp	bh,44h
	je	segment_prefix
	ret
      ss_prefix:
	cmp	bh,25h
	je	segment_prefix_ok
	cmp	bh,45h
	je	segment_prefix_ok
	cmp	bh,44h
	je	segment_prefix_ok
	jmp	segment_prefix
store_segment_prefix:
	mov	al,byte [segment_register]
	or	al,al
	jz	segment_prefix_ok
	cmp	al,5
	jae	segment_prefix_386
      segment_prefix:
	dec	al
	shl	al,3
	add	al,26h
	stosb
	jmp	segment_prefix_ok
      segment_prefix_386:
	add	al,64h-5
	stosb
      segment_prefix_ok:
	ret
store_instruction:
	call	store_segment_prefix_if_necessary
      store_instruction_main:
	or	bx,bx
	jz near_o0 address_immediate
	mov	al,bl
	or	al,bh
	and	al,11110000b
	cmp	al,40h
	je near_o0 postbyte_32bit
	call	address_16bit_prefix
	call	store_instruction_code
	cmp	bx,2326h
	je	address_bx_si
	cmp	bx,2623h
	je	address_bx_si
	cmp	bx,2327h
	je	address_bx_di
	cmp	bx,2723h
	je	address_bx_di
	cmp	bx,2526h
	je	address_bp_si
	cmp	bx,2625h
	je	address_bp_si
	cmp	bx,2527h
	je	address_bp_di
	cmp	bx,2725h
	je	address_bp_di
	cmp	bx,2600h
	je	address_si
	cmp	bx,2700h
	je	address_di
	cmp	bx,2300h
	je	address_bx
	cmp	bx,2500h
	je	address_bp
	jmp	invalid_address
      address_bx_si:
	xor	al,al
	jmp	postbyte_16bit
      address_bx_di:
	mov	al,1
	jmp	postbyte_16bit
      address_bp_si:
	mov	al,10b
	jmp	postbyte_16bit
      address_bp_di:
	mov	al,11b
	jmp	postbyte_16bit
      address_si:
	mov	al,100b
	jmp	postbyte_16bit
      address_di:
	mov	al,101b
	jmp	postbyte_16bit
      address_bx:
	mov	al,111b
	jmp	postbyte_16bit
      address_bp:
	mov	al,110b
      postbyte_16bit:
	cmp	ch,1
	je	address_8bit_value
	cmp	ch,2
	je	address_16bit_value
	or	ch,ch
	jnz near_o0 address_sizes_do_not_agree
	or	edx,edx
	jz	address
	cmp	edx,80h
	jb	address_8bit_value
	cmp	edx,-80h
	jae	address_8bit_value
      address_16bit_value:
	or	al,10000000b
	mov	cl,byte [postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	mov	eax,edx
	stosw
	cmp	edx,10000h
	jge near_o0 value_out_of_range
	cmp	edx,-8000h
	jl near_o0 value_out_of_range
	ret
      address_8bit_value:
	or	al,01000000b
	mov	cl,byte [postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	mov	al,dl
	stosb
	cmp	edx,80h
	jge near_o0 value_out_of_range
	cmp	edx,-80h
	jl near_o0 value_out_of_range
	ret
      address:
	cmp	al,110b
	je	address_8bit_value
	mov	cl,byte [postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	ret
      postbyte_32bit:
	call	address_32bit_prefix
	call	store_instruction_code
	cmp	bl,44h
	je near_o0 invalid_address
	or	cl,cl
	jz near_o0 only_base_register
      base_and_index:
	mov	al,100b
	xor	ah,ah
	cmp	cl,1
	je	scale_ok
	cmp	cl,2
	je	scale_1
	cmp	cl,4
	je	scale_2
	or	ah,11000000b
	jmp	scale_ok
      scale_2:
	or	ah,10000000b
	jmp	scale_ok
      scale_1:
	or	ah,01000000b
      scale_ok:
	or	bh,bh
	jz near_o0 only_index_register
	and	bl,111b
	shl	bl,3
	or	ah,bl
	and	bh,111b
	or	ah,bh
	cmp	ch,1
	je	sib_address_8bit_value
	test	ch,4
	jnz	sib_address_32bit_value
	cmp	ch,2
	je near_o0 address_sizes_do_not_agree
	cmp	bh,5
	je	address_value
	or	edx,edx
	jz	sib_address
      address_value:
	cmp	edx,80h
	jb	sib_address_8bit_value
	cmp	edx,-80h
	jae	sib_address_8bit_value
      sib_address_32bit_value:
	or	al,10000000b
	mov	cl,byte [postbyte_register]
	shl	cl,3
	or	al,cl
	stosw
	jmp	store_address_32bit_value
      sib_address_8bit_value:
	or	al,01000000b
	mov	cl,byte [postbyte_register]
	shl	cl,3
	or	al,cl
	stosw
	mov	al,dl
	stosb
	cmp	edx,80h
	jge near_o0 value_out_of_range
	cmp	edx,-80h
	jl near_o0 value_out_of_range
	ret
      sib_address:
	mov	cl,byte [postbyte_register]
	shl	cl,3
	or	al,cl
	stosw
	ret
      only_index_register:
	or	ah,101b
	and	bl,111b
	shl	bl,3
	or	ah,bl
	mov	cl,byte [postbyte_register]
	shl	cl,3
	or	al,cl
	stosw
	test	ch,4
	jnz near_o0 store_address_32bit_value
	or	ch,ch
	jnz near_o0 invalid_address_size
	jmp	store_address_32bit_value
      zero_index_register:
	mov	bl,4
	mov	cl,1
	jmp	base_and_index
      only_base_register:
	mov	al,bh
	and	al,111b
	cmp	al,4
	je	zero_index_register
	cmp	ch,1
	je	simple_address_8bit_value
	test	ch,4
	jnz	simple_address_32bit_value
	cmp	ch,2
	je near_o0 address_sizes_do_not_agree
	or	edx,edx
	jz	simple_address
	cmp	edx,80h
	jb	simple_address_8bit_value
	cmp	edx,-80h
	jae	simple_address_8bit_value
      simple_address_32bit_value:
	or	al,10000000b
	mov	cl,byte [postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	jmp	store_address_32bit_value
      simple_address_8bit_value:
	or	al,01000000b
	mov	cl,byte [postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	mov	al,dl
	stosb
	cmp	edx,80h
	jge near_o0 value_out_of_range
	cmp	edx,-80h
	jl near_o0 value_out_of_range
	ret
      simple_address:
	cmp	al,5
	je	simple_address_8bit_value
	mov	cl,byte [postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	ret
      address_immediate:
	test	ch,4
	jnz	address_immediate_32bit
	cmp	ch,2
	je	address_immediate_16bit
	or	ch,ch
	jnz near_o0 invalid_address_size
	cmp	byte [code_type],16
	je	addressing_16bit
      address_immediate_32bit:
	call	address_32bit_prefix
	call	store_instruction_code
	mov	al,101b
	mov	cl,byte [postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
      store_address_32bit_value:
	test	ch,80h
	jz	address_relocation_ok
	push	word [value_type]
	mov	byte [value_type],2
	call	mark_relocation
	pop	ax
	mov	byte [value_type],al
      address_relocation_ok:
	mov	eax,edx
	stosd
	ret
      addressing_16bit:
	cmp	edx,10000h
	jge	address_immediate_32bit
	cmp	edx,-8000h
	jl	address_immediate_32bit
	movzx	edx,dx
      address_immediate_16bit:
	call	address_16bit_prefix
	call	store_instruction_code
	mov	al,110b
	mov	cl,byte [postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	mov	eax,edx
	stosw
	cmp	edx,10000h
	jge near_o0 value_out_of_range
	cmp	edx,-8000h
	jl near_o0 value_out_of_range
	ret
      store_instruction_code:
	mov	al,byte [base_code]
	stosb
	cmp	al,0Fh
	jne	instruction_code_ok
      store_extended_code:
	mov	al,byte [extended_code]
	stosb
      instruction_code_ok:
	ret
      address_16bit_prefix:
	cmp	byte [code_type],16
	je	instruction_prefix_ok
	mov	al,67h
	stosb
	ret
      address_32bit_prefix:
	cmp	byte [code_type],32
	je	instruction_prefix_ok
	mov	al,67h
	stosb
      instruction_prefix_ok:
	ret

;%include '../formats.inc'

; flat assembler source
; Copyright (c) 1999-2001, Tomasz Grysztar
; All rights reserved.

format_directive:
	cmp	edi,dword [code_start]
	jne near_o0 unexpected_instruction
	cmp	byte [output_format],0
	jne near_o0 unexpected_instruction
	lodsb
	cmp	al,18h
	jne near_o0 invalid_argument
	lodsb
	mov	byte [output_format],al
	jmp	instruction_assembled
entry_directive:
	bts	dword [format_flags],1
	jc near_o0 symbol_already_defined
	jmp	illegal_instruction
stack_directive:
	bts	dword [format_flags],2
	jc near_o0 symbol_already_defined
	jmp	illegal_instruction
heap_directive:
	bts	dword [format_flags],3
	jc near_o0 symbol_already_defined
	jmp	illegal_instruction
mark_relocation:
	ret

;%include '../tables.inc'

; flat assembler source
; Copyright (c) 1999-2001, Tomasz Grysztar
; All rights reserved.

get_operator:
	push	esi
	push	ebp
	mov	ebp,1
	cmp	byte [esi],1Ah
	jne	operator_start
	inc	esi
	lodsb
	movzx	ebp,al
      operator_start:
	mov	edx,esi
      check_operator:
	mov	esi,edx
	movzx	ecx,byte [edi]
	jecxz	no_operator
	inc	edi
	mov	ebx,edi
	add	ebx,ecx
	cmp	ecx,ebp
	jne	next_operator
	repe	cmpsb
	je	operator_found
      next_operator:
	mov	edi,ebx
	inc	edi
	jmp	check_operator
      no_operator:
	xor	al,al
	pop	ebp
	pop	esi
	ret
      operator_found:
	pop	ebp
	pop	eax
	mov	al,[edi]
	ret

get_symbol:
	mov	edx,esi
	mov	ebp,ecx
      scan_symbols:
	mov	esi,edx
	movzx	eax,byte [edi]
	or	al,al
	jz	no_symbol
	mov	ecx,ebp
	inc	edi
	mov	ebx,edi
	add	ebx,eax
	mov	ah,[esi]
	cmp	ah,[edi]
	jb	no_symbol
	ja	next_symbol
	cmp	cl,al
	jne	next_symbol
	repe	cmpsb
	jb	no_symbol
	je	symbol_ok
      next_symbol:
	mov	edi,ebx
	add	edi,2
	jmp	scan_symbols
      no_symbol:
	mov	esi,edx
	mov	ecx,ebp
	stc
	ret
      symbol_ok:
	mov	ax,[ebx]
	clc
	ret

get_instruction:
	mov	edx,esi
	mov	ebp,ecx
	cmp	ecx,11
	ja	no_instruction
	sub	cl,2
	jc	no_instruction
	movzx	edi,word [instructions+ecx*2]
	add	edi,instructions
      scan_instructions:
	mov	esi,edx
	mov	al,[edi]
	or	al,al
	jz	no_instruction
	mov	ecx,ebp
	mov	ebx,edi
	add	ebx,ecx
	repe	cmpsb
	jb	no_instruction
	je	instruction_ok
      next_instruction:
	mov	edi,ebx
	add	edi,3
	jmp	scan_instructions
      no_instruction:
	mov	esi,edx
	mov	ecx,ebp
	stc
	ret
      instruction_ok:
	mov	al,[ebx]
	mov	bx,[ebx+1]
	clc
	ret

get_label_id:
	cmp	ecx,100h
	jae near_o0 name_too_long
	cmp	byte [esi],'.'
	jne	standard_label
	cmp	byte [esi+1],'.'
	je	standard_label
	cmp	dword [current_locals_prefix],0
	je	standard_label
	push	edi
	push	ecx
	push	esi
	mov	edi,dword [additional_memory]
	xor	al,al
	stosb
	mov	esi,dword [current_locals_prefix]
	mov	ebx,edi
	lodsb
	movzx	ecx,al
	lea	ebp,[edi+ecx]
	cmp	ebp,dword [additional_memory_end]
	jae near_o0 out_of_memory
	rep	movsb
	pop	esi
	pop	ecx
	add	al,cl
	jc near_o0 name_too_long
	lea	ebp,[edi+ecx]
	cmp	ebp,dword [additional_memory_end]
	jae near_o0 out_of_memory
	rep	movsb
	mov	dword [additional_memory],edi
	pop	edi
	push	esi
	movzx	ecx,al
	mov	esi,ebx
	call	get_label_id
	pop	esi
	ret
      standard_label:
	cmp	ecx,1
	jne	find_label
	lodsb
	cmp	al,'$'
	je	get_current_offset_id
	cmp	al,'%'
	je	get_counter_id
	dec	esi
	jmp	find_label
      get_current_offset_id:
	xor	eax,eax
	ret
      get_counter_id:
	mov	eax,1
	ret
      find_label:
	xor	ebx,ebx
	xor	eax,eax
	xor	ebp,ebp
      hash_label:
	movzx	eax,byte [esi+ebx]
	add	ebp,eax
	inc	bl
	cmp	bl,cl
	jb	hash_label
	shl	ebx,24
	or	ebp,ebx
	mov	dword [label_hash],ebp
	push	edi
	push	esi
	mov	ebx,esi
	mov	edx,ecx
	mov	eax,dword [labels_list]
      check_label:
	mov	esi,ebx
	mov	ecx,edx
	cmp	eax,dword [memory_end]
	je	add_label
	cmp	ebp,[eax]
	jne	next_label
	mov	edi,[eax+4]
	repe	cmpsb
	je	label_found
      next_label:
	add	eax,16
	jmp	check_label
      label_found:
	add	esp,4
	pop	edi
	ret
      add_label:
	pop	esi
	cmp	byte [esi-1],0
	je	label_name_ok
	mov	al,[esi]
	cmp	al,30h
	jb	name_first_char_ok
	cmp	al,39h
	jbe near_o0 invalid_name
      name_first_char_ok:
	cmp	ecx,1
	jne	check_for_reserved_word
	cmp	al,'$'
	je near_o0 reserved_word_used_as_symbol
      check_for_reserved_word:
	call	get_instruction
	jnc near_o0 reserved_word_used_as_symbol
	mov	edi,data_directives
	call	get_symbol
	jnc near_o0 reserved_word_used_as_symbol
	mov	edi,symbols
	call	get_symbol
	jnc near_o0 reserved_word_used_as_symbol
	mov	edi,formatter_symbols
	call	get_symbol
	jnc near_o0 reserved_word_used_as_symbol
      label_name_ok:
	mov	eax,dword [labels_list]
	sub	eax,16
	mov	dword [labels_list],eax
	mov	[eax+4],esi
	add	esi,ecx
	mov	edx,dword [label_hash]
	mov	[eax],edx
	pop	edi
	cmp	eax,edi
	jbe near_o0 out_of_memory
	ret

CASE_INSENSITIVE equ 0
%define CASE_SENSITIVE

symbol_characters db 25
 db 9,0Ah,0Dh,1Ah,20h,'+-/*:=|&~()[]<>{},;\'


















operators:
 db 1,'+',80h
 db 1,'-',81h
 db 1,'*',90h
 db 1,'/',91h
 db 3,'mod',0A0h
 db 3,'and',0B0h
 db 2,'or',0B1h
 db 3,'xor',0B2h
 db 3,'shl',0C0h
 db 3,'shr',0C1h
 db 0

single_operand_operators:
 db 3,'not',0D0h
 db 3,'rva',0E0h
 db 0

directive_operators:
 db 2,'at',80h
 db 2,'eq',81h
 db 4,'from',82h
 db 2,'in',83h
 db 2,'on',84h
 db 0

address_registers:
 db 2,'bp',0,25h
 db 2,'bx',0,23h
 db 2,'di',0,27h
 db 3,'eax',0,40h
 db 3,'ebp',0,45h
 db 3,'ebx',0,43h
 db 3,'ecx',0,41h
 db 3,'edi',0,47h
 db 3,'edx',0,42h
 db 3,'esi',0,46h
 db 3,'esp',0,44h
 db 2,'si',0,26h
 db 0

address_sizes:
 db 4,'byte',0,1
 db 5,'dword',0,4
 db 4,'word',0,2
 db 0

symbols:
 db 2,'ah',10h,14h
 db 2,'al',10h,10h
 db 2,'ax',10h,20h
 db 2,'bh',10h,17h
 db 2,'bl',10h,13h
 db 2,'bp',10h,25h
 db 2,'bx',10h,23h
 db 4,'byte',11h,1
 db 2,'ch',10h,15h
 db 2,'cl',10h,11h
 db 3,'cr0',10h,50h
 db 3,'cr2',10h,52h
 db 3,'cr3',10h,53h
 db 3,'cr4',10h,54h
 db 2,'cs',10h,62h
 db 2,'cx',10h,21h
 db 2,'dh',10h,16h
 db 2,'di',10h,27h
 db 2,'dl',10h,12h
 db 6,'dqword',11h,16
 db 3,'dr0',10h,70h
 db 3,'dr1',10h,71h
 db 3,'dr2',10h,72h
 db 3,'dr3',10h,73h
 db 3,'dr5',10h,75h
 db 3,'dr6',10h,76h
 db 3,'dr7',10h,77h
 db 2,'ds',10h,64h
 db 5,'dword',11h,4
 db 2,'dx',10h,22h
 db 3,'eax',10h,40h
 db 3,'ebp',10h,45h
 db 3,'ebx',10h,43h
 db 3,'ecx',10h,41h
 db 3,'edi',10h,47h
 db 3,'edx',10h,42h
 db 2,'es',10h,61h
 db 3,'esi',10h,46h
 db 3,'esp',10h,44h
 db 3,'far',12h,2
 db 2,'fs',10h,65h
 db 5,'fword',11h,6
 db 2,'gs',10h,66h
 db 3,'mm0',10h,80h
 db 3,'mm1',10h,81h
 db 3,'mm2',10h,82h
 db 3,'mm3',10h,83h
 db 3,'mm4',10h,84h
 db 3,'mm5',10h,85h
 db 3,'mm6',10h,86h
 db 3,'mm7',10h,87h
 db 4,'near',12h,1
 db 5,'pword',11h,6
 db 5,'qword',11h,8
 db 2,'si',10h,26h
 db 2,'sp',10h,24h
 db 2,'ss',10h,63h
 db 2,'st',10h,0A0h
 db 3,'st0',10h,0A0h
 db 3,'st1',10h,0A1h
 db 3,'st2',10h,0A2h
 db 3,'st3',10h,0A3h
 db 3,'st4',10h,0A4h
 db 3,'st5',10h,0A5h
 db 3,'st6',10h,0A6h
 db 3,'st7',10h,0A7h
 db 5,'tword',11h,0Ah
 db 5,'use16',13h,10h
 db 5,'use32',13h,20h
 db 4,'word',11h,2
 db 4,'xmm0',10h,90h
 db 4,'xmm1',10h,91h
 db 4,'xmm2',10h,92h
 db 4,'xmm3',10h,93h
 db 4,'xmm4',10h,94h
 db 4,'xmm5',10h,95h
 db 4,'xmm6',10h,96h
 db 4,'xmm7',10h,97h
 db 0

formatter_symbols:
 %ifndef CASE_SENSITIVE
 db 6,'binary',18h,1
 db 4,'code',19h,5
 db 7,'console',1Bh,3
 db 4,'data',19h,6
 db 11,'discardable',19h,25
 db 3,'dll',1Bh,80h
 db 10,'executable',19h,29
 db 6,'export',1Ah,0
 db 6,'fixups',1Ah,5
 db 3,'gui',1Bh,2
 db 4,'i386',1Bh,43h
 db 4,'i486',1Bh,44h
 db 4,'i586',1Bh,45h
 db 6,'import',1Ah,1
 db 2,'mz',18h,2
 db 6,'native',1Bh,1
 db 2,'pe',18h,3
 db 8,'readable',19h,30
 db 8,'resource',1Ah,2
 db 9,'shareable',19h,28
 db 5,'udata',19h,7
 db 9,'writeable',19h,31
 %else
 db 3,'DLL',1Bh,80h
 db 3,'GUI',1Bh,2
 db 2,'MZ',18h,2
 db 2,'PE',18h,3
 db 6,'binary',18h,1
 db 4,'code',19h,5
 db 7,'console',1Bh,3
 db 4,'data',19h,6
 db 11,'discardable',19h,25
 db 10,'executable',19h,29
 db 6,'export',1Ah,0
 db 6,'fixups',1Ah,5
 db 4,'i386',1Bh,43h
 db 4,'i486',1Bh,44h
 db 4,'i586',1Bh,45h
 db 6,'import',1Ah,1
 db 6,'native',1Bh,1
 db 8,'readable',19h,30
 db 8,'resource',1Ah,2
 db 9,'shareable',19h,28
 db 5,'udata',19h,7
 db 9,'writeable',19h,31
 %endif
 db 0

preprocessor_directives:
 db 7,'include'
 dw include_file-preprocessor
 db 5,'macro'
 dw define_macro-preprocessor
 db 5,'purge'
 dw purge_macro-preprocessor
 db 5,'struc'
 dw define_struc-preprocessor
 db 0

macro_directives:
 db 6,'common'
 dw common_block-preprocessor
 db 7,'forward'
 dw forward_block-preprocessor
 db 5,'local'
 dw local_symbols-preprocessor
 db 7,'reverse'
 dw reverse_block-preprocessor
 db 0

data_handlers:
 dw data_bytes-assembler
 dw data_file-assembler
 dw reserve_bytes-assembler
 dw data_words-assembler
 dw data_unicode-assembler
 dw reserve_words-assembler
 dw data_dwords-assembler
 dw reserve_dwords-assembler
 dw data_pwords-assembler
 dw reserve_pwords-assembler
 dw data_qwords-assembler
 dw reserve_qwords-assembler
 dw data_twords-assembler
 dw reserve_twords-assembler

data_directives:
 db 2,'db',1,0
 db 2,'dd',4,6
 db 2,'dp',6,8
 db 2,'dq',8,10
 db 2,'dt',10,12
 db 2,'du',2,4
 db 2,'dw',2,3
 db 4,'file',1,1
 db 2,'rb',1,2
 db 2,'rd',4,7
 db 2,'rp',6,9
 db 2,'rq',8,11
 db 2,'rt',10,13
 db 2,'rw',2,5
 db 0

instructions:
 dw instructions_2-instructions
 dw instructions_3-instructions
 dw instructions_4-instructions
 dw instructions_5-instructions
 dw instructions_6-instructions
 dw instructions_7-instructions
 dw instructions_8-instructions
 dw instructions_9-instructions
 dw instructions_10-instructions
 dw instructions_11-instructions

%macro dbw 3
  db %1, %2
  dw %3
%endm


instructions_2:
 dbw 'bt',4, bt_instruction-assembler
 dbw 'if',0, if_directive-assembler
 dbw 'in',0, in_instruction-assembler
 dbw 'ja',77h, conditional_jump-assembler
 dbw 'jb',72h, conditional_jump-assembler
 dbw 'jc',72h, conditional_jump-assembler
 dbw 'je',74h, conditional_jump-assembler
 dbw 'jg',7Fh, conditional_jump-assembler
 dbw 'jl',7Ch, conditional_jump-assembler
 dbw 'jo',70h, conditional_jump-assembler
 dbw 'jp',7Ah, conditional_jump-assembler
 dbw 'js',78h, conditional_jump-assembler
 dbw 'jz',74h, conditional_jump-assembler
 dbw 'or',08h, basic_instruction-assembler
 db 0
instructions_3:
 dbw 'aaa',37h, simple_instruction-assembler
 dbw 'aad',0D5h, aa_instruction-assembler
 dbw 'aam',0D4h, aa_instruction-assembler
 dbw 'aas',3Fh, simple_instruction-assembler
 dbw 'adc',10h, basic_instruction-assembler
 dbw 'add',00h, basic_instruction-assembler
 dbw 'and',20h, basic_instruction-assembler
 dbw 'bsf',0BCh, bs_instruction-assembler
 dbw 'bsr',0BDh, bs_instruction-assembler
 dbw 'btc',7, bt_instruction-assembler
 dbw 'btr',6, bt_instruction-assembler
 dbw 'bts',5, bt_instruction-assembler
 dbw 'cbw',98h, simple_instruction_16bit-assembler
 dbw 'cdq',99h, simple_instruction_32bit-assembler
 dbw 'clc',0F8h, simple_instruction-assembler
 dbw 'cld',0FCh, simple_instruction-assembler
 dbw 'cli',0FAh, simple_instruction-assembler
 dbw 'cmc',0F5h, simple_instruction-assembler
 dbw 'cmp',38h, basic_instruction-assembler
 dbw 'cwd',99h, simple_instruction_16bit-assembler
 dbw 'daa',27h, simple_instruction-assembler
 dbw 'das',2Fh, simple_instruction-assembler
 dbw 'dec',1, inc_instruction-assembler
 dbw 'div',6, single_operand_instruction-assembler
 dbw 'end',0, end_directive-assembler
 dbw 'hlt',0F4h, simple_instruction-assembler
 dbw 'inc',0, inc_instruction-assembler
 dbw 'ins',0, ins_instruction-assembler
 dbw 'int',0CDh, int_instruction-assembler
 dbw 'jae',73h, conditional_jump-assembler
 dbw 'jbe',76h, conditional_jump-assembler
 dbw 'jge',7Dh, conditional_jump-assembler
 dbw 'jle',7Eh, conditional_jump-assembler
 dbw 'jmp',0, jmp_instruction-assembler
 dbw 'jna',76h, conditional_jump-assembler
 dbw 'jnb',73h, conditional_jump-assembler
 dbw 'jnc',73h, conditional_jump-assembler
 dbw 'jne',75h, conditional_jump-assembler
 dbw 'jng',7Eh, conditional_jump-assembler
 dbw 'jnl',7Dh, conditional_jump-assembler
 dbw 'jno',71h, conditional_jump-assembler
 dbw 'jnp',7Bh, conditional_jump-assembler
 dbw 'jns',79h, conditional_jump-assembler
 dbw 'jnz',75h, conditional_jump-assembler
 dbw 'jpe',7Ah, conditional_jump-assembler
 dbw 'jpo',7Bh, conditional_jump-assembler
 dbw 'lar',2, lar_instruction-assembler
 dbw 'lds',3, ls_instruction-assembler
 dbw 'lea',0, lea_instruction-assembler
 dbw 'les',0, ls_instruction-assembler
 dbw 'lfs',4, ls_instruction-assembler
 dbw 'lgs',5, ls_instruction-assembler
 dbw 'lsl',3, lar_instruction-assembler
 dbw 'lss',2, ls_instruction-assembler
 dbw 'mov',0, mov_instruction-assembler
 dbw 'mul',4, single_operand_instruction-assembler
 dbw 'neg',3, single_operand_instruction-assembler
 dbw 'nop',90h, simple_instruction-assembler
 dbw 'not',2, single_operand_instruction-assembler
 dbw 'org',0, org_directive-assembler
 dbw 'out',0, out_instruction-assembler
 dbw 'pop',0, pop_instruction-assembler
 dbw 'rcl',2, sh_instruction-assembler
 dbw 'rcr',3, sh_instruction-assembler
 dbw 'rep',0F3h, prefix_instruction-assembler
 dbw 'ret',0C2h, ret_instruction-assembler
 dbw 'rol',0, sh_instruction-assembler
 dbw 'ror',1, sh_instruction-assembler
 dbw 'rsm',0AAh, simple_extended_instruction-assembler
 dbw 'sal',6, sh_instruction-assembler
 dbw 'sar',7, sh_instruction-assembler
 dbw 'sbb',18h, basic_instruction-assembler
 dbw 'shl',4, sh_instruction-assembler
 dbw 'shr',5, sh_instruction-assembler
 dbw 'stc',0F9h, simple_instruction-assembler
 dbw 'std',0FDh, simple_instruction-assembler
 dbw 'sti',0FBh, simple_instruction-assembler
 dbw 'sub',28h, basic_instruction-assembler
 dbw 'ud2',0Bh, simple_extended_instruction-assembler
 dbw 'xor',30h, basic_instruction-assembler
 db 0
instructions_4:
 dbw 'arpl',0, arpl_instruction-assembler
 dbw 'call',0, call_instruction-assembler
 dbw 'clts',6, simple_extended_instruction-assembler
 dbw 'cmps',0, cmps_instruction-assembler
 dbw 'cwde',98h, simple_instruction_32bit-assembler
 dbw 'else',0, else_directive-assembler
 dbw 'heap',0, heap_directive-assembler
 dbw 'idiv',7, single_operand_instruction-assembler
 dbw 'imul',0, imul_instruction-assembler
 dbw 'int3',0CCh, simple_instruction-assembler
 dbw 'into',0CEh, simple_instruction-assembler
 dbw 'invd',8, simple_extended_instruction-assembler
 dbw 'iret',0CFh, simple_instruction-assembler
 dbw 'jcxz',0E3h, loop_instruction_16bit-assembler
 dbw 'jnae',72h, conditional_jump-assembler
 dbw 'jnbe',77h, conditional_jump-assembler
 dbw 'jnge',7Ch, conditional_jump-assembler
 dbw 'jnle',7Fh, conditional_jump-assembler
 dbw 'lahf',9Fh, simple_instruction-assembler
 dbw 'load',0, load_directive-assembler
 dbw 'lock',0F0h, prefix_instruction-assembler
 dbw 'lods',0, lods_instruction-assembler
 dbw 'loop',0E2h, loop_instruction-assembler
 dbw 'movs',0, movs_instruction-assembler
 dbw 'outs',0, outs_instruction-assembler
 dbw 'popa',61h, simple_instruction-assembler
 dbw 'popf',9Dh, simple_instruction-assembler
 dbw 'push',0, push_instruction-assembler
 dbw 'repe',0F3h, prefix_instruction-assembler
 dbw 'repz',0F3h, prefix_instruction-assembler
 dbw 'retd',0C2h, ret_instruction_32bit-assembler
 dbw 'retf',0CAh, ret_instruction-assembler
 dbw 'retn',0C2h, ret_instruction-assembler
 dbw 'retw',0C2h, ret_instruction_16bit-assembler
 dbw 'sahf',9Eh, simple_instruction-assembler
 dbw 'scas',0AEh, stos_instruction-assembler
 dbw 'seta',97h, set_instruction-assembler
 dbw 'setb',92h, set_instruction-assembler
 dbw 'setc',92h, set_instruction-assembler
 dbw 'sete',94h, set_instruction-assembler
 dbw 'setg',9Fh, set_instruction-assembler
 dbw 'setl',9Ch, set_instruction-assembler
 dbw 'seto',90h, set_instruction-assembler
 dbw 'setp',9Ah, set_instruction-assembler
 dbw 'sets',98h, set_instruction-assembler
 dbw 'setz',94h, set_instruction-assembler
 dbw 'shld',0A4h, shd_instruction-assembler
 dbw 'shrd',0ACh, shd_instruction-assembler
 dbw 'stos',0AAh, stos_instruction-assembler
 dbw 'test',0, test_instruction-assembler
 dbw 'wait',9Bh, simple_instruction-assembler
 dbw 'xadd',0C0h, basic_486_instruction-assembler
 dbw 'xchg',0, xchg_instruction-assembler
 dbw 'xlat',0D7h, xlat_instruction-assembler
 db 0
instructions_5:
 dbw 'bound',0, bound_instruction-assembler
 dbw 'bswap',0, bswap_instruction-assembler
 dbw 'cmpsb',0A6h, simple_instruction-assembler
 dbw 'cmpsd',0, cmpsd_instruction-assembler
 dbw 'cmpsw',0A7h, simple_instruction_16bit-assembler
 dbw 'cpuid',0A2h, simple_extended_instruction-assembler
 dbw 'enter',0, enter_instruction-assembler
 dbw 'entry',0, entry_directive-assembler
 dbw 'fwait',9Bh, simple_instruction-assembler
 dbw 'iretd',0CFh, simple_instruction_32bit-assembler
 dbw 'iretw',0CFh, simple_instruction_16bit-assembler
 dbw 'jecxz',0E3h, loop_instruction_32bit-assembler
 dbw 'label',0, label_directive-assembler
 dbw 'leave',0C9h, simple_instruction-assembler
 dbw 'lodsb',0ACh, simple_instruction-assembler
 dbw 'lodsd',0ADh, simple_instruction_32bit-assembler
 dbw 'lodsw',0ADh, simple_instruction_16bit-assembler
 dbw 'loopd',0E2h, loop_instruction_32bit-assembler
 dbw 'loope',0E1h, loop_instruction-assembler
 dbw 'loopw',0E2h, loop_instruction_16bit-assembler
 dbw 'loopz',0E1h, loop_instruction-assembler
 dbw 'movsb',0A4h, simple_instruction-assembler
 dbw 'movsd',0, movsd_instruction-assembler
 dbw 'movsw',0A5h, simple_instruction_16bit-assembler
 dbw 'movsx',0BEh, movx_instruction-assembler
 dbw 'movzx',0B6h, movx_instruction-assembler
 dbw 'popad',61h, simple_instruction_32bit-assembler
 dbw 'popaw',61h, simple_instruction_16bit-assembler
 dbw 'popfd',9Dh, simple_instruction_32bit-assembler
 dbw 'popfw',9Dh, simple_instruction_16bit-assembler
 dbw 'pusha',60h, simple_instruction-assembler
 dbw 'pushf',9Ch, simple_instruction-assembler
 dbw 'repne',0F2h, prefix_instruction-assembler
 dbw 'repnz',0F2h, prefix_instruction-assembler
 dbw 'retfd',0CAh, ret_instruction_32bit-assembler
 dbw 'retfw',0CAh, ret_instruction_16bit-assembler
 dbw 'retnd',0C2h, ret_instruction_32bit-assembler
 dbw 'retnw',0C2h, ret_instruction_16bit-assembler
 dbw 'scasb',0AEh, simple_instruction-assembler
 dbw 'scasd',0AFh, simple_instruction_32bit-assembler
 dbw 'scasw',0AFh, simple_instruction_16bit-assembler
 dbw 'setae',93h, set_instruction-assembler
 dbw 'setbe',96h, set_instruction-assembler
 dbw 'setge',9Dh, set_instruction-assembler
 dbw 'setle',9Eh, set_instruction-assembler
 dbw 'setna',96h, set_instruction-assembler
 dbw 'setnb',93h, set_instruction-assembler
 dbw 'setnc',93h, set_instruction-assembler
 dbw 'setne',95h, set_instruction-assembler
 dbw 'setng',9Eh, set_instruction-assembler
 dbw 'setnl',9Dh, set_instruction-assembler
 dbw 'setno',91h, set_instruction-assembler
 dbw 'setnp',9Bh, set_instruction-assembler
 dbw 'setns',99h, set_instruction-assembler
 dbw 'setnz',95h, set_instruction-assembler
 dbw 'setpe',9Ah, set_instruction-assembler
 dbw 'setpo',9Bh, set_instruction-assembler
 dbw 'stack',0, stack_directive-assembler
 dbw 'stosb',0AAh, simple_instruction-assembler
 dbw 'stosd',0ABh, simple_instruction_32bit-assembler
 dbw 'stosw',0ABh, simple_instruction_16bit-assembler
 dbw 'times',0, times_directive-assembler
 dbw 'xlatb',0D7h, simple_instruction-assembler
 db 0
instructions_6:
 dbw 'format',0, format_directive-assembler
 dbw 'looped',0E1h, loop_instruction_32bit-assembler
 dbw 'loopew',0E1h, loop_instruction_16bit-assembler
 dbw 'loopne',0E0h, loop_instruction-assembler
 dbw 'loopnz',0E0h, loop_instruction-assembler
 dbw 'loopzd',0E1h, loop_instruction_32bit-assembler
 dbw 'loopzw',0E1h, loop_instruction_16bit-assembler
 dbw 'pushad',60h, simple_instruction_32bit-assembler
 dbw 'pushaw',60h, simple_instruction_16bit-assembler
 dbw 'pushfd',9Ch, simple_instruction_32bit-assembler
 dbw 'pushfw',9Ch, simple_instruction_16bit-assembler
 dbw 'repeat',0, repeat_directive-assembler
 dbw 'setalc',0D6h, simple_instruction-assembler
 dbw 'setnae',92h, set_instruction-assembler
 dbw 'setnbe',97h, set_instruction-assembler
 dbw 'setnge',9Ch, set_instruction-assembler
 dbw 'setnle',9Fh, set_instruction-assembler
 db 0
instructions_7:
 dbw 'loopned',0E0h, loop_instruction_32bit-assembler
 dbw 'loopnew',0E0h, loop_instruction_16bit-assembler
 dbw 'loopnzd',0E0h, loop_instruction_32bit-assembler
 dbw 'loopnzw',0E0h, loop_instruction_16bit-assembler
 dbw 'virtual',0, virtual_directive-assembler
 db 0
instructions_8:
 db 0
instructions_9:
 db 0
instructions_10:
 db 0
instructions_11:
 db 0

;%include done

_copyright db 'Copyright (c) 1999-2002, Tomasz Grysztar',0

_logo db 'flat assembler  version ',VERSION_STRING,0xA,0



_usage db 'usage: fasm source output',0xA,0

_passes_suffix db ' passes, ',0
_seconds_suffix db ' seconds, ',0
_bytes_suffix db ' bytes.',0xA,0

_counter db 4,'0000'

prebss:
bss_align equ ($$-$)&3
section .bss align=1  ; We could use `absolute $' here instead, but that's broken (breaks address calculation in program_end-bss+prebss-file_header) in NASM 0.95--0.97.
bss resb bss_align  ; Uninitialized data follows.

memory_start resb 4
memory_end resb 4
additional_memory resb 4
additional_memory_end resb 4
input_file resb 4
output_file resb 4
source_start resb 4
code_start resb 4
code_size resb 4
real_code_size resb 4
start_time resb 4
written_size resb 4

current_line resb 4
macros_list resb 4
macro_constants resb 4
macro_block resb 4
macro_block_line_number resb 4
struc_name resb 4
current_locals_prefix resb 4
labels_list resb 4
label_hash resb 4
org_start resb 4
org_sib resb 4
undefined_data_start resb 4
undefined_data_end resb 4
counter resb 4
counter_limit resb 4
error_line resb 4
error resb 4
display_buffer resb 4
structures_buffer resb 4
number_start resb 4
current_offset resb 4
value resb 8
fp_value resb 8
format_flags resb 4
number_of_relocations resb 4
number_of_sections resb 4
stub_size resb 4
header_data resb 4
sections_data resb 4
current_section resb 4
machine resb 2
subsystem resb 2
subsystem_version resb 4

macro_status resb 1
parenthesis_stack resb 1
output_format resb 1
code_type resb 1
current_pass resb 1
next_pass_needed resb 1
reloc_labels resb 1
times_working resb 1
virtual_data resb 1
fp_sign resb 1
fp_format resb 1  ; TODO(pts): Remove unused variables.
value_size resb 1
forced_size resb 1
value_type resb 1
address_size resb 1
compare_type resb 1
base_code resb 1
extended_code resb 1
postbyte_register resb 1
segment_register resb 1
operand_size resb 1
imm_sized resb 1
jump_type resb 1
mmx_size resb 1
mmx_prefix resb 1
nextbyte resb 1

characters resb 100h
converted resb 100h
available_memory resb 4

program_end:

; __END__
