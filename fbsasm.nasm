; by pts@fazekas.hu at Thu Mar 21 07:44:40 CET 2024
;
; This is the source of code fasm 1.30 in NASM syntax, for Linux i386 only.
;
; Compile with: nasm-0.98.39 -O999999999 -w+orphan-labels -f bin -o fnasm fasm.asm && chmod +x fnasm
;
; !! It may not work (untested).
;
	cpu 386
	bits 32

; flat assembler source
; Copyright (c) 1999-2002, Tomasz Grysztar
; All rights reserved.

	program_base equ 0x700000

	org	program_base
	use32

;	macro	align value { rb (value-1) - ($ + value-1) mod value }

file_header:
	db	0x7F,'ELF',1,1,1
	times	file_header+0x10-$ db 0
	dw	2,3
	dd	1,start
	dd	program_header-file_header,0,0
	dw	program_header-file_header,0x20,1,0,0,0

program_header:
	dd	1,0,program_base,0
	dd	bss-program_base,program_end-program_base,7,0x1000

start:

	mov	esi,_logo
	call	display_string

	pop	eax
	cmp	eax,3
	jne	information
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

	mov	eax,78
	mov	ebx,buffer
	xor	ecx,ecx
	int	0x80
	mov	eax,dword [buffer]
	mov	ecx,1000
	mul	ecx
	mov	ebx,eax
	mov	eax,dword [buffer+4]
	div	ecx
	add	eax,ebx
	mov	[start_time],eax

	call	preprocessor
	call	parser
	call	assembler

	movzx	eax,byte [current_pass]  ; !! Guess `byte'. !! There are hundreds of lines like this.
	inc	al
	call	display_number
	mov	esi,_passes_suffix
	call	display_string
	mov	eax,78
	mov	ebx,buffer
	xor	ecx,ecx
	int	0x80
	mov	eax,dword [buffer]
	mov	ecx,1000
	mul	ecx
	mov	ebx,eax
	mov	eax,dword [buffer+4]
	div	ecx
	add	eax,ebx
	sub	eax,[start_time]
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
	mov	eax,[written_size]
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

; flat assembler source
; Copyright (c) 1999-2002, Tomasz Grysztar
; All rights reserved.

O_ACCMODE  equ 00003
O_RDONLY   equ 00000
O_WRONLY   equ 00001
O_RDWR	   equ 00002
O_CREAT    equ 00100
O_EXCL	   equ 00200
O_NOCTTY   equ 00400
O_TRUNC    equ 01000
O_APPEND   equ 02000
O_NONBLOCK equ 04000

S_ISUID    equ 04000
S_ISGID    equ 02000
S_ISVTX    equ 01000
S_IRUSR    equ 00400
S_IWUSR    equ 00200
S_IXUSR    equ 00100
S_IRGRP    equ 00040
S_IWGRP    equ 00020
S_IXGRP    equ 00010
S_IROTH    equ 00004
S_IWOTH    equ 00002
S_IXOTH    equ 00001

init_memory:
	xor	ebx,ebx
	mov	eax,45
	int	0x80
	mov	[additional_memory],eax
	mov	ebx,buffer
	mov	eax,116
	int	0x80
	mov dword [buffer+14h],0x100000  ; PATCH
    allocate_memory:
	mov	ebx,[additional_memory]
	add	ebx,dword [buffer+14h]
	mov	eax,45
	int	0x80
	mov	[memory_end],eax
	sub	eax,[additional_memory]
	jz	not_enough_memory
	shr	eax,3
	add	eax,[additional_memory]
	mov	[additional_memory_end],eax
	mov	[memory_start],eax
	ret
    not_enough_memory:
	shr	dword [buffer+14h],1
	cmp	dword [buffer+14h],4000h
	jb	out_of_memory
	jmp	allocate_memory

exit_program:
	movzx	ebx,al
	mov	eax,1
	int	0x80

open:
	push edx
	push esi
	push edi
	push ebp
	mov	ebx,edx
	mov	eax,5
	mov	ecx,O_RDONLY
	xor	edx,edx
	int	0x80
	pop ebp
	pop edi
	pop esi
	pop edx
	test	eax,eax
	js	file_error
	mov	ebx,eax
	clc
	ret
    file_error:
	stc
	ret
create:
	push edx
	push esi
	push edi
	push ebp
	mov	ebx,edx
	mov	eax,5
	mov	ecx,O_CREAT+O_TRUNC+O_WRONLY
	mov	edx,S_IRUSR+S_IWUSR+S_IRGRP
	int	0x80
	pop ebp
	pop edi
	pop esi
	pop edx
	test	eax,eax
	js	file_error
	mov	ebx,eax
	clc
	ret
close:
	mov	eax,6
	int	0x80
	ret
read:
	push ecx
	push edx
	push esi
	push edi
	push ebp
	mov	eax,3
	xchg	ecx,edx
	int	0x80
	pop ebp
	pop edi
	pop esi
	pop edx
	pop ecx
	test	eax,eax
	js	file_error
	cmp	eax,ecx
	jne	file_error
	clc
	ret
write:
	push edx
	push esi
	push edi
	push ebp
	mov	eax,4
	xchg	ecx,edx
	int	0x80
	pop ebp
	pop edi
	pop esi
	pop edx
	test	eax,eax
	js	file_error
	clc
	ret
lseek:
	mov	ecx,edx
	xor	edx,edx
	mov	dl,al
	mov	eax,19
	int	0x80
	clc
	ret

display_string:
	push ebx
	mov	edi,esi
	mov	edx,esi
	or	ecx,-1
	xor	al,al
	repne	scasb
	neg	ecx
	sub	ecx,2
	mov	eax,4
	mov	ebx,1
	xchg	ecx,edx
	int	0x80
	pop ebx
	ret
display_block:
	push ebx
	mov	eax,4
	mov	ebx,1
	mov	edx,ecx
	mov	ecx,esi
	int	0x80
	pop ebx
	ret
display_character:
	push ebx
	mov	[character],dl
	mov	eax,4
	mov	ebx,1
	mov	ecx,character
	mov	edx,ebx
	int	0x80
	pop ebx
	ret
display_number:
	push ebx
	mov	ecx,1000000000
	xor	edx,edx
	xor	bl,bl
      display_loop:
	div	ecx
	push edx
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
	push ebx
	push ecx
	call	display_character
	pop ecx
	pop ebx
      digit_ok:
	mov	eax,ecx
	xor	edx,edx
	mov	ecx,10
	div	ecx
	mov	ecx,eax
	pop eax
	or	ecx,ecx
	jnz	display_loop
	pop ebx
	ret

fatal_error:
	mov	esi,error_prefix
	call	display_string
	pop esi
	call	display_string
	mov	esi,error_suffix
	call	display_string
	mov	al,0FFh
	jmp	exit_program
assembler_error:
	call	flush_display_buffer
	mov	ebx,[current_line]
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
	cmp	ebx,[current_line]
	je	line_number_ok
	mov	dl,20h
	call	display_character
	mov	esi,[current_line]
	mov	esi,[esi]
	movzx	ecx,byte [esi]
	inc	esi
	call	display_block
	mov	esi,line_number_start
	call	display_string
	mov	esi,[current_line]
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
	push eax
	xor	al,al
	call	lseek
	mov	ecx,[esp]
	mov	edx,[memory_start]
	call	read
	call	close
	pop ecx
	mov	esi,[memory_start]
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
	mov	esi,[memory_start]
	sub	ecx,esi
	call	display_block
	mov	esi,lf
	call	display_string
	mov	esi,error_prefix
	call	display_string
	pop esi
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

;macro dm string { db string,0 }
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

VERSION_STRING equ "1.30"

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
	push ebp
	mov	ebp,esp
	push edi
	mov	edi,operators
	call	get_operator
	pop edi
	or	al,al
	jz	expression_loop
	push ebp
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
	push ebp
	push edi
	mov	edi,single_operand_operators
	call	get_operator
	pop edi
      expression_number:
	push eax
	cmp	byte [esi],0
	je	invalid_expression
	call	convert_number
	pop eax
	or	al,al
	jz	expression_operator
	stosb
      expression_operator:
	push edi
	mov	edi,operators
	call	get_operator
	pop edi
	pop ebp
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
	pop bx
	mov	byte [edi],bl
	inc	edi
	jmp	operators_loop
      push_operator:
	push ax
	jmp	expression_loop
      expression_end:
	cmp	esp,ebp
	je	expression_converted
	pop ax
	stosb
	jmp	expression_end
      expression_converted:
	pop ebp
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
	jne	invalid_expression
	ret
      symbol_value:
	lodsb
	cmp	al,1Ah
	jne	invalid_value
	lodsb
	movzx	ecx,al
	push ecx
	push esi
	push edi
	mov	edi,address_registers
	call	get_symbol
	jnc	register_value
	mov	edi,symbols
	call	get_symbol
	jnc	invalid_value
	pop edi
	pop esi
	pop ecx
	call	get_label_id
	mov	byte [edi-1],11h
	stosd
	ret
      register_value:
	pop edi
	add	esp,8
	mov	byte [edi-1],10h
	mov	al,ah
	stosb
	ret

get_number:
	xor	ebp,ebp
	lodsb
	cmp	al,22h
	je	get_text_number
	cmp	al,1Ah
	jne	not_number
	lodsb
	movzx	ecx,al
	mov	[number_start],esi
	mov	al,[esi]
	sub	al,30h
	jb	invalid_number
	cmp	al,9
	ja	invalid_number
	mov	eax,esi
	add	esi,ecx
	push esi
	sub	esi,2
	mov	dword [edi],0
	mov	dword [edi+4],0
	inc	esi
	cmp	word [eax],'0x'
	je	get_hex_number
	dec	esi
	cmp	byte [esi+1],'h'
	je	get_hex_number
	cmp	byte [esi+1],'o'
	je	get_oct_number
	cmp	byte [esi+1],'b'
	je	get_bin_number
	cmp	byte [esi+1],'d'
	je	get_dec_number
	inc	esi
	cmp	byte [eax],'0'
	je	get_oct_number
      get_dec_number:
	xor	edx,edx
	mov	ebx,1
      get_dec_digit:
	cmp	esi,[number_start]
	jb	number_ok
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
	pop eax
      invalid_number:
	mov	esi,[number_start]
	dec	esi
      not_number:
	dec	esi
	stc
	ret
      get_bin_number:
	xor	bl,bl
      get_bin_digit:
	cmp	esi,[number_start]
	jb	number_ok
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
	cmp	esi,[number_start]
	jb	number_ok
	movzx	eax,byte [esi]
	cmp	al,'x'
	je	hex_number_ok
	sub	al,30h
	jc	bad_number
	cmp	al,9
	jbe	hex_digit_ok
	sub	al,7
	cmp	al,15
	jbe	hex_digit_ok
	sub	al,20h
	jc	bad_number
	cmp	al,15
	ja	bad_number
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
	cmp	esi,[number_start]
	jb	number_ok
	movzx	eax,byte [esi]
	sub	al,30h
	jc	bad_number
	cmp	al,7
	ja	bad_number
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
	cmp	esi,[number_start]
	jne	bad_number
      number_ok:
	pop esi
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

get_fp_value:
	push edi
	push esi
	lodsb
	cmp	al,1Ah
	je	fp_value_start
	cmp	al,'-'
	je	fp_sign_ok
	cmp	al,'+'
	jne	not_fp_value
      fp_sign_ok:
	lodsb
	cmp	al,1Ah
	jne	not_fp_value
      fp_value_start:
	lodsb
	movzx	ecx,al
	xor	ah,ah
      check_fp_value:
	lodsb
	cmp	al,'.'
	je	fp_character_dot
	cmp	al,'E'
	je	fp_character_exp
	cmp	al,'0'
	jb	not_fp_value
	cmp	al,'9'
	ja	not_fp_value
	jmp	fp_character_ok
      fp_character_dot:
	or	ah,ah
	jnz	not_fp_value
	or	ah,1
	jmp	fp_character_ok
      fp_character_exp:
	cmp	ah,1
	ja	not_fp_value
	mov	ah,2
	cmp	ecx,1
	jne	fp_character_ok
	cmp	byte [esi],'+'
	je	fp_exp_sign
	cmp	byte [esi],'-'
	jne	fp_character_ok
      fp_exp_sign:
	inc	esi
	cmp	byte [esi],1Ah
	jne	not_fp_value
	inc	esi
	lodsb
	movzx	ecx,al
	inc	ecx
      fp_character_ok:
	loop	check_fp_value
	or	ah,ah
	jz	not_fp_value
	pop esi
	lodsb
	mov	[fp_sign],0
	cmp	al,1Ah
	je	fp_get
	inc	esi
	cmp	al,'+'
	je	fp_get
	mov	[fp_sign],1
      fp_get:
	lodsb
	movzx	ecx,al
	xor	edx,edx
	mov	edi,fp_value
	mov	[edi],edx
	mov	[edi+4],edx
	mov	[edi+12],edx
	call	fp_optimize
	mov	[fp_format],0
	mov	al,[esi]
      fp_before_dot:
	lodsb
	cmp	al,'.'
	je	fp_dot
	cmp	al,'E'
	je	fp_exponent
	sub	al,30h
	mov	edi,fp_value+16
	xor	edx,edx
	mov	dword [edi+12],edx
	mov	dword [edi],edx
	mov	dword [edi+4],edx
	mov	[edi+7],al
	mov	dl,7
	mov	dword [edi+8],edx
	call	fp_optimize
	mov	edi,fp_value
	push ecx
	mov	ecx,10
	call	fp_mul
	pop ecx
	mov	ebx,fp_value+16
	call	fp_add
	loop	fp_before_dot
      fp_dot:
	mov	edi,fp_value+16
	xor	edx,edx
	mov	[edi],edx
	mov	[edi+4],edx
	mov	byte [edi+7],80h
	mov	[edi+8],edx
	mov	dword [edi+12],edx
	dec	ecx
	jz	fp_done
      fp_after_dot:
	lodsb
	cmp	al,'E'
	je	fp_exponent
	inc	[fp_format]
	cmp	[fp_format],80h
	jne	fp_counter_ok
	mov	[fp_format],7Fh
      fp_counter_ok:
	dec	esi
	mov	edi,fp_value+16
	push ecx
	mov	ecx,10
	call	fp_div
	push dword [edi]
	push dword [edi+4]
	push dword [edi+8]
	push dword [edi+12]
	lodsb
	sub	al,30h
	movzx	ecx,al
	call	fp_mul
	mov	ebx,edi
	mov	edi,fp_value
	call	fp_add
	mov	edi,fp_value+16
	pop dword [edi+12]
	pop dword [edi+8]
	pop dword [edi+4]
	pop dword [edi]
	pop ecx
	loop	fp_after_dot
	jmp	fp_done
      fp_exponent:
	or	[fp_format],80h
	xor	edx,edx
	xor	ebp,ebp
	dec	ecx
	jnz	get_exponent
	cmp	byte [esi],'+'
	je	fp_exponent_sign
	cmp	byte [esi],'-'
	jne	fp_done
      fp_exponent_sign:
	not	ebp
	add	esi,2
	lodsb
	movzx	ecx,al
      get_exponent:
	movzx	eax,byte [esi]
	inc	esi
	sub	al,30h
	imul	edx,10
	cmp	edx,8000h
	jae	value_out_of_range
	add	edx,eax
	loop	get_exponent
	mov	edi,fp_value
	or	edx,edx
	jz	fp_done
	mov	ecx,edx
	or	ebp,ebp
	jnz	fp_negative_power
      fp_power:
	push ecx
	mov	ecx,10
	call	fp_mul
	pop ecx
	loop	fp_power
	jmp	fp_done
      fp_negative_power:
	push ecx
	mov	ecx,10
	call	fp_div
	pop ecx
	loop	fp_negative_power
      fp_done:
	mov	edi,fp_value
	mov	al,[fp_format]
	mov	[edi+10],al
	mov	al,[fp_sign]
	mov	[edi+11],al
	test	byte [edi+15],80h
	jz	fp_ok
	add	dword [edi],1
	adc	dword [edi+4],0
	jnc	fp_ok
	mov	eax,[edi+4]
	shrd	[edi],eax,1
	shr	eax,1
	or	eax,80000000h
	mov	[edi+4],eax
	inc	word [edi+8]
      fp_ok:
	pop edi
	clc
	ret
      not_fp_value:
	pop esi
	pop edi
	stc
	ret
      fp_mul:
	or	ecx,ecx
	jz	fp_zero
	mov	eax,[edi+12]
	mul	ecx
	mov	[edi+12],eax
	mov	ebx,edx
	mov	eax,[edi]
	mul	ecx
	add	eax,ebx
	adc	edx,0
	mov	[edi],eax
	mov	ebx,edx
	mov	eax,[edi+4]
	mul	ecx
	add	eax,ebx
	adc	edx,0
	mov	[edi+4],eax
      .loop:
	or	edx,edx
	jz	.done
	mov	eax,[edi]
	shrd	[edi+12],eax,1
	mov	eax,[edi+4]
	shrd	[edi],eax,1
	shrd	eax,edx,1
	mov	[edi+4],eax
	shr	edx,1
	inc	dword [edi+8]
	cmp	dword [edi+8],8000h
	jge	value_out_of_range
	jmp	.loop
      .done:
	ret
      fp_div:
	mov	eax,[edi+4]
	xor	edx,edx
	div	ecx
	mov	[edi+4],eax
	mov	eax,[edi]
	div	ecx
	mov	[edi],eax
	mov	eax,[edi+12]
	div	ecx
	mov	[edi+12],eax
	mov	ebx,eax
	or	ebx,[edi]
	or	ebx,[edi+4]
	jz	fp_zero
      .loop:
	test	byte [edi+7],80h
	jnz	.exp_ok
	mov	eax,[edi]
	shld	[edi+4],eax,1
	mov	eax,[edi+12]
	shld	[edi],eax,1
	shl	eax,1
	mov	[edi+12],eax
	dec	dword [edi+8]
	shl	edx,1
	jmp	.loop
      .exp_ok:
	mov	eax,edx
	xor	edx,edx
	div	ecx
	add	[edi+12],eax
	adc	dword [edi],0
	adc	dword [edi+4],0
	jnc	.done
	mov	eax,[edi+4]
	mov	ebx,[edi]
	shrd	[edi],eax,1
	shrd	[edi+12],ebx,1
	shr	eax,1
	or	eax,80000000h
	mov	[edi+4],eax
	inc	dword [edi+8]
      .done:
	ret
      fp_add:
	cmp	dword [ebx+8],8000h
	je	.done
	cmp	dword [edi+8],8000h
	je	.copy
	mov	eax,[ebx+8]
	cmp	eax,[edi+8]
	jge	.exp_ok
	mov	eax,[edi+8]
      .exp_ok:
	call	.change_exp
	xchg	ebx,edi
	call	.change_exp
	xchg	ebx,edi
	mov	edx,[ebx+12]
	mov	eax,[ebx]
	mov	ebx,[ebx+4]
	add	[edi+12],edx
	adc	[edi],eax
	adc	[edi+4],ebx
	jnc	.done
	mov	eax,[edi]
	shrd	[edi+12],eax,1
	mov	eax,[edi+4]
	shrd	[edi],eax,1
	shr	eax,1
	or	eax,80000000h
	mov	[edi+4],eax
	inc	dword [edi+8]
      .done:
	ret
      .copy:
	mov	eax,[ebx]
	mov	[edi],eax
	mov	eax,[ebx+4]
	mov	[edi+4],eax
	mov	eax,[ebx+8]
	mov	[edi+8],eax
	mov	eax,[ebx+12]
	mov	[edi+12],eax
	ret
      .change_exp:
	push ecx
	mov	ecx,eax
	sub	ecx,[ebx+8]
	mov	edx,[ebx+4]
	jecxz	.exp_done
      .exp_loop:
	mov	ebp,[ebx]
	shrd	[ebx+12],ebp,1
	shrd	[ebx],edx,1
	shr	edx,1
	inc	dword [ebx+8]
	loop	.exp_loop
      .exp_done:
	mov	[ebx+4],edx
	pop ecx
	ret
      fp_optimize:
	mov	eax,[edi]
	mov	ebp,[edi+4]
	or	ebp,[edi]
	or	ebp,[edi+12]
	jz	fp_zero
      .loop:
	test	byte [edi+7],80h
	jnz	.done
	shld	[edi+4],eax,1
	mov	ebp,[edi+12]
	shld	eax,ebp,1
	mov	[edi],eax
	shl	dword [edi+12],1
	dec	dword [edi+8]
	jmp	.loop
      .done:
	ret
      fp_zero:
	mov	dword [edi+8],8000h
	ret

calculate_expression:
	lodsb
	or	al,al
	jz	get_string_value
	cmp	al,'.'
	je	convert_fp
	cmp	al,1
	je	get_byte_number
	cmp	al,2
	je	get_word_number
	cmp	al,4
	je	get_dword_number
	cmp	al,8
	je	get_qword_number
	cmp	al,0Fh
	je	value_out_of_range
	cmp	al,10h
	je	get_register
	cmp	al,11h
	je	get_label
	cmp	al,')'
	je	expression_calculated
	cmp	al,']'
	je	expression_calculated
	sub	edi,10h
	mov	ebx,edi
	sub	ebx,10h
	mov	dx,[ebx+8]
	or	dx,[edi+8]
	cmp	al,0E0h
	je	calculate_rva
	cmp	al,0D0h
	je	calculate_not
	cmp	al,0D1h
	je	calculate_neg
	cmp	al,80h
	je	calculate_add
	cmp	al,81h
	je	calculate_sub
	mov	ah,[ebx+12]
	or	ah,[edi+12]
	jnz	invalid_use_of_symbol
	cmp	al,90h
	je	calculate_mul
	cmp	al,91h
	je	calculate_div
	or	dx,dx
	jnz	invalid_expression
	cmp	al,0A0h
	je	calculate_mod
	cmp	al,0B0h
	je	calculate_and
	cmp	al,0B1h
	je	calculate_or
	cmp	al,0B2h
	je	calculate_xor
	cmp	al,0C0h
	je	calculate_shl
	cmp	al,0C1h
	je	calculate_shr
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
	jz	current_offset_label
	cmp	eax,1
	je	counter_label
	mov	ebx,eax
	test	byte [ebx+8],1
	jz	label_undefined
	test	byte [ebx+8],4
	jz	label_defined
	mov	al,[current_pass]
	cmp	al,[ebx+9]
	jne	label_undefined
      label_defined:
	mov	al,[ebx+11]
	cmp	[next_pass_needed],0
	je	label_type_ok
	cmp	[current_pass],0
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
	jz	calculate_expression
	cmp	[forced_size],2
	je	calculate_expression
	cmp	[forced_size],1
	jne	check_size
	cmp	[operand_size],0
	jne	calculate_expression
	mov	[operand_size],al
	jmp	calculate_expression
      check_size:
	xchg	[operand_size],al
	or	al,al
	jz	calculate_expression
	cmp	al,[operand_size]
	jne	operand_sizes_do_not_match
	jmp	calculate_expression
      current_offset_label:
	cmp	[reloc_labels],0
	je	get_current_offset
	mov	byte [edi+12],2
      get_current_offset:
	mov	eax,[current_offset]
	sub	eax,[org_start]
	cdq
	stosd
	mov	eax,edx
	stosd
	mov	eax,[org_sib]
	stosd
	scasd
	jmp	calculate_expression
      counter_label:
	mov	eax,[counter]
	stosd
	xor	eax,eax
	stosd
	scasd
	scasd
	jmp	calculate_expression
      label_undefined:
	cmp	[current_pass],0
	jne	invalid_value
	or	[next_pass_needed],-1
	mov	byte [edi+12],0
	xor	eax,eax
	stosd
	stosd
	scasd
	scasd
	jmp	calculate_expression
      calculate_add:
	cmp	[next_pass_needed],0
	jne	add_values
	cmp	byte [edi+12],0
	je	add_values
	cmp	byte [ebx+12],0
	jne	invalid_use_of_symbol
      add_values:
	mov	al,[edi+12]
	or	[ebx+12],al
	mov	eax,[edi]
	add	[ebx],eax
	mov	eax,[edi+4]
	adc	[ebx+4],eax
	or	dx,dx
	jz	calculate_expression
	push esi
	mov	esi,ebx
	lea	ebx,[edi+10]
	mov	cl,[edi+8]
	call	add_register
	lea	ebx,[edi+11]
	mov	cl,[edi+9]
	call	add_register
	pop esi
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
	jne	invalid_expression
	mov	[esi+9],cl
	mov	al,[ebx]
	mov	[esi+11],al
      add_register_done:
	ret
      calculate_sub:
	xor	ah,ah
	cmp	[next_pass_needed],0
	jne	sub_values
	mov	ah,[ebx+12]
	mov	al,[edi+12]
	or	al,al
	jz	sub_values
	cmp	al,ah
	jne	invalid_use_of_symbol
	xor	ah,ah
      sub_values:
	mov	byte [ebx+12],ah
	mov	eax,[edi]
	sub	[ebx],eax
	mov	eax,[edi+4]
	sbb	[ebx+4],eax
	or	dx,dx
	jz	calculate_expression
	push esi
	mov	esi,ebx
	lea	ebx,[edi+10]
	mov	cl,[edi+8]
	call	sub_register
	lea	ebx,[edi+11]
	mov	cl,[edi+9]
	call	sub_register
	pop esi
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
	push esi
	push dx
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
	jnz	value_out_of_range
      mul_numbers:
	mov	eax,[esi+4]
	mul	dword [edi]
	or	edx,edx
	jnz	value_out_of_range
	mov	ecx,eax
	mov	eax,[esi]
	mul	dword [edi+4]
	or	edx,edx
	jnz	value_out_of_range
	add	ecx,eax
	jc	value_out_of_range
	mov	eax,[esi]
	mul	dword [edi]
	add	edx,ecx
	jc	value_out_of_range
	mov	[esi],eax
	mov	[esi+4],edx
	or	bl,bl
	jz	mul_ok
	not	dword [esi]
	not	dword [esi+4]
	add	dword [esi],1
	adc	dword [esi+4],0
      mul_ok:
	pop dx
	or	dx,dx
	jz	mul_calculated
	cmp	word [edi+8],0
	jne	invalid_value
	cmp	byte [esi+8],0
	je	mul_first_register_ok
	mov	al,[edi]
	cbw
	cwde
	cdq
	cmp	edx,[edi+4]
	jne	value_out_of_range
	cmp	eax,[edi]
	jne	value_out_of_range
	imul	byte [esi+10]
	mov	dl,ah
	cbw
	cmp	ah,dl
	jne	value_out_of_range
	mov	[esi+10],al
      mul_first_register_ok:
	cmp	byte [esi+9],0
	je	mul_calculated
	mov	al,[edi]
	cbw
	cwde
	cdq
	cmp	edx,[edi+4]
	jne	value_out_of_range
	cmp	eax,[edi]
	jne	value_out_of_range
	imul	byte [esi+11]
	mov	dl,ah
	cbw
	cmp	ah,dl
	jne	value_out_of_range
	mov	[esi+11],al
      mul_calculated:
	pop esi
	jmp	calculate_expression
      calculate_div:
	push esi
	push dx
	mov	esi,ebx
	call	div_64
	pop dx
	or	dx,dx
	jz	div_calculated
	cmp	byte [esi+8],0
	je	div_first_register_ok
	mov	al,[edi]
	cbw
	cwde
	cdq
	cmp	edx,[edi+4]
	jne	value_out_of_range
	cmp	eax,[edi]
	jne	value_out_of_range
	or	al,al
	jz	value_out_of_range
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
	jne	value_out_of_range
	cmp	eax,[edi]
	jne	value_out_of_range
	or	al,al
	jz	value_out_of_range
	mov	al,[esi+11]
	cbw
	idiv	byte [edi]
	mov	[esi+11],al
      div_calculated:
	pop esi
	jmp	calculate_expression
      calculate_mod:
	push esi
	mov	esi,ebx
	call	div_64
	mov	[esi],eax
	mov	[esi+4],edx
	pop esi
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
	cmp	[value_size],1
	je	xor_byte
	cmp	[value_size],2
	je	xor_word
	cmp	[value_size],4
	je	xor_dword
	cmp	[value_size],6
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
	jnz	zero_value
	mov	ecx,[edi]
	cmp	ecx,64
	jae	zero_value
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
	jne	invalid_expression
	cmp	byte [edi+12],0
	jne	invalid_use_of_symbol
	cmp	[value_size],1
	je	not_byte
	cmp	[value_size],2
	je	not_word
	cmp	[value_size],4
	je	not_dword
	cmp	[value_size],6
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
	jne	invalid_expression
	cmp	byte [edi+12],0
	jne	invalid_use_of_symbol
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
	jne	invalid_expression
	mov	al,[edi+12]
	cmp	al,2
	je	rva_ok
	or	al,al
	jnz	invalid_use_of_symbol
	cmp	[next_pass_needed],0
	je	invalid_use_of_symbol
      rva_ok:
	mov	byte [edi+12],0
	mov	eax,[header_data]
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
	cmp	[next_pass_needed],0
	je	value_out_of_range
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
	mov	al,[value_size]
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
	jae	value_out_of_range
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
	jae	value_out_of_range
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
	ja	value_out_of_range
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
	mov	[value_size],1
	mov	[forced_size],2
	mov	[current_offset],edi
	call	calculate_expression
	cmp	word [edi+8],0
	jne	invalid_value
	cmp	byte [edi+12],0
	jne	invalid_use_of_symbol
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
	cmp	[error_line],0
	jne	return_value
	mov	eax,[current_line]
	mov	[error_line],eax
	mov	[error],value_out_of_range
	ret
get_word_value:
	mov	[value_size],2
	mov	[forced_size],2
	mov	[current_offset],edi
	call	calculate_expression
	cmp	word [edi+8],0
	jne	invalid_value
	mov	al,[edi+12]
	cmp	al,2
	je	invalid_use_of_symbol
	mov	[value_type],al
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
	mov	[value_size],4
	mov	[forced_size],2
	mov	[current_offset],edi
	call	calculate_expression
	cmp	word [edi+8],0
	jne	invalid_value
	mov	al,[edi+12]
	mov	[value_type],al
      check_dword_value:
	mov	eax,[edi]
	cmp	dword [edi+4],0
	je	dword_positive
	cmp	dword [edi+4],-1
	jne	range_exceeded
	test	eax,1 << 31
	jz	range_exceeded
      dword_positive:
	ret
get_pword_value:
	mov	[value_size],6
	mov	[forced_size],2
	mov	[current_offset],edi
	call	calculate_expression
	cmp	word [edi+8],0
	jne	invalid_value
	mov	al,[edi+12]
	mov	[value_type],al
	mov	eax,[edi]
	mov	edx,[edi+4]
	cmp	edx,10000h
	jge	range_exceeded
	cmp	edx,-8000h
	jl	range_exceeded
	ret
get_qword_value:
	mov	[value_size],8
	mov	[forced_size],2
	mov	[current_offset],edi
	call	calculate_expression
	cmp	word [edi+8],0
	jne	invalid_value
	mov	al,[edi+12]
	mov	[value_type],al
	mov	eax,[edi]
	mov	edx,[edi+4]
	ret
get_value:
	mov	[operand_size],0
	mov	[forced_size],0
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne	invalid_value
	mov	al,[operand_size]
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
	jnz	invalid_value
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
	mov	[segment_register],0
	mov	[address_size],0
	mov	[value_size],4
	push address_ok
	mov	al,[esi]
	and	al,11110000b
	cmp	al,60h
	jne	get_size_prefix
	lodsb
	sub	al,60h
	mov	[segment_register],al
	mov	al,[esi]
	and	al,11110000b
      get_size_prefix:
	cmp	al,70h
	jne	calculate_address
	lodsb
	sub	al,70h
	cmp	al,4
	ja	invalid_address_size
	mov	[address_size],al
	mov	[value_size],al
	jmp	calculate_address
get_address_value:
	mov	[address_size],0
	mov	[value_size],4
	push address_ok
      calculate_address:
	mov	[current_offset],edi
	call	calculate_expression
	mov	al,[edi+12]
	mov	[value_type],al
	cmp	al,1
	je	invalid_use_of_symbol
	or	al,al
	jz	address_symbol_ok
	mov	al,84h
	xchg	[address_size],al
	or	al,al
	jz	address_symbol_ok
	cmp	al,4
	jne	address_sizes_do_not_agree
      address_symbol_ok:
	xor	bx,bx
	xor	cl,cl
	mov	ch,[address_size]
	cmp	word [edi+8],0
	je	check_dword_value
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
	jne	invalid_address
      check_address_registers:
	or	al,ah
	cmp	al,2
	je	address_16bit
	cmp	al,4
	jne	invalid_address
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
	jz	check_word_value
	cmp	cl,1
	je	check_word_value
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
	jnz	invalid_address
	mov	bl,al
	mov	cl,dl
	jmp	address_register_ok
      address_ok:
	mov	edx,eax
	ret

calculate_logical_expression:
	call	get_logical_value
      logical_loop:
	push ax
	lodsb
	cmp	al,'|'
	je	logical_or
	cmp	al,'&'
	je	logical_and
	dec	esi
	pop ax
	ret
      logical_or:
	call	get_logical_value
	pop bx
	or	al,bl
	jmp	logical_loop
      logical_and:
	call	get_logical_value
	pop bx
	and	al,bl
	jmp	logical_loop

get_logical_value:
	xor	al,al
	cmp	byte [esi],'~'
	jne	negation_ok
	inc	esi
	or	al,-1
      negation_ok:
	push ax
	cmp	byte [esi],'{'
	je	logical_expression
	push esi
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
	je	compare_values
	cmp	al,'>'
	je	compare_values
	cmp	al,'<'
	je	compare_values
	cmp	al,'�'
	je	compare_values
	cmp	al,'�'
	je	compare_values
	cmp	al,'�'
	je	compare_values
	dec	esi
      find_eq_symbol:
	cmp	byte [esi],81h
	je	compare_symbols
	cmp	byte [esi],83h
	je	scan_symbols_list
	call	check_character
	jc	logical_number
	cmp	al,','
	jne	next_eq_symbol
	mov	bl,1
      next_eq_symbol:
	call	skip_symbol
	jmp	find_eq_symbol
      compare_symbols:
	inc	esi
	pop ebx
	mov	edx,esi
	push edi
	mov	edi,ebx
	mov	ecx,esi
	dec	ecx
	sub	ecx,edi
	repe	cmpsb
	pop edi
	je	symbols_equal
	mov	esi,edx
      symbols_different:
	call	check_character
	jc	return_false
	call	skip_symbol
	jmp	symbols_different
      symbols_equal:
	call	check_character
	jc	return_true
	jmp	symbols_different
      scan_symbols_list:
	or	bl,bl
	jnz	invalid_expression
	xor	bp,bp
	inc	esi
	lodsb
	cmp	al,'<'
	jne	invalid_expression
	pop ebx
	mov	ecx,esi
	sub	ecx,2
	sub	ecx,ebx
      compare_in_list:
	mov	edx,esi
	push ecx
	push edi
	mov	edi,ebx
	repe	cmpsb
	pop edi
	pop ecx
	jne	not_equal_in_list
	cmp	byte [esi],','
	je	skip_rest_of_list
	cmp	byte [esi],'>'
	jne	not_equal_in_list
      skip_rest_of_list:
	call	check_character
	jc	invalid_expression
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
	jc	invalid_expression
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
	pop esi
	call	get_value
	mov	bl,[value_type]
	push eax
	push edx
	push bx
	lodsb
	mov	[compare_type],al
	call	get_value
	pop bx
	cmp	[next_pass_needed],0
	jne	values_ok
	cmp	bl,[value_type]
	jne	invalid_use_of_symbol
      values_ok:
	pop ecx
	pop ebx
	cmp	[compare_type],'='
	je	check_equal
	cmp	[compare_type],'>'
	je	check_greater
	cmp	[compare_type],'<'
	je	check_less
	cmp	[compare_type],'�'
	je	check_not_less
	cmp	[compare_type],'�'
	je	check_not_greater
	cmp	[compare_type],'�'
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
	pop esi
	call	get_value
	cmp	[value_type],0
	jne	invalid_expression
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
	push ax
	lodsb
	cmp	al,'}'
	jne	invalid_expression
	pop ax
      logical_value_ok:
	pop bx
	xor	al,bl
	ret

;%include '../preproce.inc'

; flat assembler source
; Copyright (c) 1999-2001, Tomasz Grysztar
; All rights reserved.

preprocessor:
	mov	eax,[memory_start]
	mov	[source_start],eax
	push	dword [additional_memory]
	mov	eax,[additional_memory]
	mov	[macros_list],eax
	mov	eax,[additional_memory_end]
	mov	[labels_list],eax
	mov	[display_buffer],0
	mov	[macro_status],0
	mov	edx,[input_file]
	mov	edi,[memory_start]
	call	preprocess_file
	jc	main_file_not_found
	cmp	[macro_status],0
	jne	unexpected_end_of_file
	pop	dword [additional_memory]
	mov	[code_start],edi
	ret

preprocess_file:
	push	dword [memory_end]
	push edx
	call	open
	jc	no_source_file
	mov	al,2
	xor	edx,edx
	call	lseek
	push eax
	xor	al,al
	xor	edx,edx
	call	lseek
	pop ecx
	mov	edx,[memory_end]
	dec	edx
	mov	byte [edx],1Ah
	sub	edx,ecx
	jc	out_of_memory
	mov	esi,edx
	cmp	edx,edi
	jbe	out_of_memory
	mov	[memory_end],edx
	call	read
	call	close
	pop edx
	xor	ecx,ecx
	mov	ebx,esi
      preprocess_source:
	inc	ecx
	mov	[current_line],edi
	mov	eax,edx
	stosd
	mov	eax,ecx
	stosd
	mov	eax,esi
	sub	eax,ebx
	stosd
	push ebx
	push edx
	call	convert_line
	call	preprocess_line
	pop edx
	pop ebx
      next_line:
	cmp	byte [esi-1],1Ah
	jne	preprocess_source
      file_end:
	pop	dword [memory_end]
	clc
	ret
      no_source_file:
	pop eax
	pop eax
	stc
	ret

convert_line:
	push ecx
	cmp	[macro_status],0
	jle	convert_line_data
	mov	ax,3Bh
	stosw
      convert_line_data:
	cmp	edi,[memory_end]
	jae	out_of_memory
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
	je	convert_string
	cmp	ah,22h
	je	convert_string
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
	ja	name_too_long
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
	je	ignore_comment
	cmp	al,5Ch
	je	concate_lines
	stosb
	jmp	convert_line_data
      control_character:
	cmp	al,1Ah
	je	line_end
	cmp	al,0Dh
	je	cr_character
	cmp	al,0Ah
	je	lf_character
	cmp	al,9
	je	convert_line_data
	or	al,al
	jnz	symbol_character
	jmp	line_end
      lf_character:
	lodsb
	cmp	al,0Dh
	je	line_end
	dec	esi
	jmp	line_end
      cr_character:
	lodsb
	cmp	al,0Ah
	je	line_end
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
	je	missing_end_quote
	cmp	al,0Dh
	je	missing_end_quote
	or	al,al
	jz	missing_end_quote
	cmp	al,1Ah
	je	missing_end_quote
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
	je	unexpected_end_of_file
	cmp	al,0Ah
	je	concate_lf
	cmp	al,0Dh
	je	concate_cr
	cmp	al,3Bh
	jne	extra_characters_on_line
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
	je	lf_character
	cmp	al,0Dh
	je	cr_character
	or	al,al
	jz	line_end
	cmp	al,1Ah
	jne	ignore_comment
      line_end:
	xor	al,al
	stosb
	pop ecx
	ret

preprocess_line:
	push	dword [struc_name]
	push ecx
	push esi
	mov	esi,[current_line]
	add	esi,12
	mov	al,[macro_status]
	dec	al
	jz	find_macro_block
	dec	al
	jz	skip_macro_block
      preprocess_instruction:
	lodsb
	cmp	al,':'
	je	preprocess_instruction
	movzx	ecx,byte [esi]
	inc	esi
	cmp	al,1Ah
	jne	not_preprocessor_symbol
	push edi
	mov	edi,preprocessor_directives
	call	get_symbol
	pop edi
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
	mov	[struc_name],0
	jmp	use_macro
      not_macro:
	mov	[struc_name],esi
	add	esi,ecx
	lodsb
	cmp	al,':'
	je	preprocess_instruction
	cmp	al,1Ah
	jne	not_preprocessor_symbol
	cmp	dword [esi],3+('equ' << 8)  ; !! Is it the right string order?
	je	define_symbolic_constant
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
	mov	esi,[current_line]
	add	esi,12
	call	process_symbolic_constants
      line_preprocessed:
	pop esi
	pop ecx
	pop	dword [struc_name]
	ret
get_macro:
	mov	edx,esi
	mov	ebp,edi
	mov	ebx,[additional_memory]
      check_macro:
	mov	cl,al
	cmp	ebx,[macros_list]
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
	push edi
	mov	ebx,esi
	mov	eax,ecx
	mov	edx,[labels_list]
      scan_symbolic_constants:
	mov	ecx,eax
	mov	esi,ebx
	cmp	edx,[additional_memory_end]
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
	pop edi
	stc
	ret
      symbolic_constant_found:
	pop edi
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
	jne	invalid_argument
	lodsd
	mov	edx,esi
	add	esi,eax
	cmp	byte [esi],0
	jne	extra_characters_on_line
	call	preprocess_file
	jc	file_not_found
	jmp	line_preprocessed
define_symbolic_constant:
	add	esi,4
	push esi
	call	process_symbolic_constants
	pop ebx
	mov	edx,[labels_list]
	sub	edx,16
	cmp	edx,[additional_memory]
	jb	out_of_memory
	mov	[labels_list],edx
	mov	ecx,edi
	dec	ecx
	sub	ecx,ebx
	mov	[edx+8],ecx
	mov	[edx+12],ebx
	mov	ebx,[struc_name]
	mov	byte [ebx-2],3Bh
	mov	al,[ebx-1]
	mov	[edx],al
	mov	[edx+4],ebx
	jmp	line_preprocessed
define_struc:
	or	ah,1
define_macro:
	cmp	[macro_status],0
	jne	unexpected_instruction
	lodsb
	cmp	al,1Ah
	jne	invalid_name
	lodsb
	mov	ebx,[additional_memory]
	mov	[ebx],ax
	mov	[ebx+4],esi
	add	ebx,8
	cmp	ebx,[labels_list]
	jae	out_of_memory
	mov	[additional_memory],ebx
	movzx	eax,al
	add	esi,eax
	mov	[macro_status],1
	xor	bl,bl
	lodsb
	or	al,al
	jz	line_preprocessed
	cmp	al,'{'
	je	found_macro_block
	dec	esi
      skip_macro_arguments:
	lodsb
	cmp	al,1Ah
	je	skip_macro_argument
	cmp	al,'['
	jne	invalid_macro_arguments
	xor	bl,-1
	jz	invalid_macro_arguments
	lodsb
	cmp	al,1Ah
	jne	invalid_macro_arguments
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
	jnz	invalid_macro_arguments
	or	al,al
	jz	line_preprocessed
	cmp	al,'{'
	je	found_macro_block
	jmp	invalid_macro_arguments
      find_macro_block:
	add	esi,2
	lodsb
	or	al,al
	jz	line_preprocessed
	cmp	al,'{'
	jne	unexpected_characters
      found_macro_block:
	mov	[macro_status],2
      skip_macro_block:
	lodsb
	cmp	al,1Ah
	je	skip_macro_symbol
	cmp	al,3Bh
	je	skip_macro_symbol
	cmp	al,22h
	je	skip_macro_string
	or	al,al
	jz	line_preprocessed
	cmp	al,'}'
	jne	skip_macro_block
	lodsb
	or	al,al
	jnz	extra_characters_on_line
	mov	[macro_status],0
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
	jne	invalid_name
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
	jnz	extra_characters_on_line
	jmp	line_preprocessed
use_macro:
	push	dword [macro_constants]
	push	dword [macro_block]
	push	dword [macro_block_line_number]
	push	dword [counter]
	push	dword [counter_limit]
	or	[macro_status],80h
	or	byte [ebx+1],80h
	mov	edx,esi
	movzx	esi,byte [ebx]
	add	esi,[ebx+4]
	push edi
	mov	edi,[additional_memory]
	mov	[macro_constants],edi
	mov	[counter],0
      process_macro_arguments:
	lodsb
	or	al,al
	jz	find_macro_instructions
	cmp	al,'{'
	je	macro_instructions_start
	cmp	al,'['
	jne	get_macro_argument
	mov	ebp,esi
	inc	esi
	inc	[counter]
      get_macro_argument:
	movzx	eax,byte [esi]
	inc	esi
	mov	[edi+4],esi
	add	esi,eax
	ror	eax,8
	or	eax,[counter]
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
	cmp	edi,[labels_list]
	jae	out_of_memory
	lodsb
	cmp	al,','
	je	next_argument
	cmp	al,']'
	je	next_arguments_group
	dec	esi
	jmp	arguments_end
      next_argument:
	cmp	byte [edx],','
	jne	process_macro_arguments
	inc	edx
	jmp	process_macro_arguments
      next_arguments_group:
	cmp	byte [edx],','
	jne	arguments_end
	inc	edx
	inc	[counter]
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
	jne	unexpected_characters
      macro_instructions_start:
	cmp	byte [edx],0
	jne	invalid_macro_arguments
	mov	[additional_memory],edi
	pop edi
	mov	ecx,80000000h
	push	dword [current_line]
	mov	[macro_block],esi
	mov	[macro_block_line_number],ecx
	mov	eax,1
	xchg	eax,[counter]
	mov	[counter_limit],eax
	or	eax,eax
	jnz	process_macro_line
	mov	[counter_limit],1
      process_macro_line:
	mov	[current_line],edi
	mov	eax,[ebx+4]
	dec	eax
	stosd
	mov	eax,ecx
	stosd
	mov	eax,[esp]
	stosd
	or	[macro_status],40h
	push ebx
	push ecx
      process_macro:
	lodsb
	cmp	al,'}'
	je	macro_line_processed
	or	al,al
	jz	macro_line_processed
	cmp	al,1Ah
	je	process_macro_symbol
	and	[macro_status],~40h
	stosb
	cmp	al,22h
	jne	process_macro
      copy_macro_string:
	mov	ecx,[esi]
	add	ecx,4
	rep	movsb
	jmp	process_macro
      process_macro_symbol:
	push esi
	push edi
	test	[macro_status],40h
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
	pop edi
	pop eax
	mov	byte [edi],0
	inc	edi
	pop ecx
	pop ebx
	jmp	edx
      not_macro_directive:
	and	[macro_status],~40h
	mov	eax,[counter]
	or	eax,eax
	jnz	check_for_macro_constant
	inc	eax
      check_for_macro_constant:
	shl	eax,8
	mov	al,[esi]
	inc	esi
	movzx	ebp,al
	mov	edx,[macro_constants]
	mov	ebx,esi
      scan_macro_constants:
	cmp	edx,[additional_memory]
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
	cmp	[counter],0
	jne	replace_macro_constant
	mov	eax,[edx]
	shr	eax,8
	or	eax,eax
	jz	replace_macro_constant
	cmp	eax,[counter_limit]
	je	replace_macro_constant
	pop edi
	mov	ecx,[edx+8]
	mov	esi,[edx+12]
	rep	movsb
	mov	byte [edi],','
	inc	edi
	mov	esi,ebx
	inc	eax
	shl	eax,8
	mov	al,[esi-1]
	push edi
	jmp	scan_macro_constants
      replace_macro_constant:
	pop edi
	pop eax
	mov	ecx,[edx+8]
	mov	edx,[edx+12]
	xchg	esi,edx
	rep	movsb
	mov	esi,edx
	jmp	process_macro
      not_macro_constant:
	pop edi
	pop esi
	mov	al,1Ah
	stosb
	mov	al,[esi]
	inc	esi
	stosb
	cmp	byte [esi],'.'
	jne	copy_macro_symbol
	mov	ebx,[struc_name]
	or	ebx,ebx
	jz	copy_macro_symbol
	xchg	esi,ebx
	movzx	ecx,byte [esi-1]
	add	[edi-1],cl
	jc	name_too_long
	rep	movsb
	xchg	esi,ebx
      copy_macro_symbol:
	movzx	ecx,al
	rep	movsb
	jmp	process_macro
      macro_line_processed:
	mov	byte [edi],0
	inc	edi
	push eax
	call	preprocess_line
	pop eax
	pop ecx
	pop ebx
	cmp	al,'}'
	je	macro_block_processed
      process_next_line:
	inc	ecx
	add	esi,14
	jmp	process_macro_line
      local_symbols:
	lodsb
	cmp	al,1Ah
	jne	invalid_argument
	push edi
	push ecx
	movzx	ecx,byte [esi]
	inc	esi
	mov	edx,[additional_memory]
	mov	eax,[counter]
	shl	eax,8
	mov	al,cl
	mov	[edx],eax
	mov	[edx+4],esi
	movzx	eax,[_counter]
	mov	edi,[memory_end]
	sub	edi,eax
	sub	edi,ecx
	sub	edi,3
	mov	[memory_end],edi
	mov	[edx+12],edi
	add	al,cl
	jc	name_too_long
	inc	al
	jz	name_too_long
	mov	byte [edi],1Ah
	inc	edi
	mov	[edi],al
	inc	edi
	add	eax,2
	mov	[edx+8],eax
	add	edx,16
	cmp	edx,[labels_list]
	jae	out_of_memory
	mov	[additional_memory],edx
	rep	movsb
	mov	al,'?'
	stosb
	movzx	ecx,byte [_counter]
	push esi
	mov	esi,_counter+1
	rep	movsb
	pop esi
	pop ecx
	pop edi
	cmp	edi,[memory_end]
	jae	out_of_memory
	lodsb
	cmp	al,','
	je	local_symbols
	cmp	al,'}'
	je	macro_block_processed
	or	al,al
	jnz	extra_characters_on_line
	jmp	process_next_line
      common_block:
	call	close_macro_block
	jc	process_macro_line
	mov	[counter],0
	jmp	new_macro_block
      forward_block:
	call	close_macro_block
	jc	process_macro_line
	mov	[counter],1
	jmp	new_macro_block
      reverse_block:
	call	close_macro_block
	jc	process_macro_line
	mov	eax,[counter_limit]
	or	eax,80000000h
	mov	[counter],eax
      new_macro_block:
	mov	[macro_block],esi
	mov	[macro_block_line_number],ecx
	jmp	process_macro_line
      close_macro_block:
	push ecx
	mov	eax,_counter
	call	increase_counter
	pop ecx
	cmp	[counter],0
	je	block_closed
	jl	reverse_counter
	mov	eax,[counter]
	cmp	eax,[counter_limit]
	je	block_closed
	inc	[counter]
	jmp	continue_block
      reverse_counter:
	mov	eax,[counter]
	dec	eax
	cmp	eax,80000000h
	je	block_closed
	mov	[counter],eax
      continue_block:
	mov	esi,[macro_block]
	mov	ecx,[macro_block_line_number]
	stc
	ret
      block_closed:
	clc
	ret
      macro_block_processed:
	call	close_macro_block
	jc	process_macro_line
	and	byte [ebx+1],~80h
	pop	dword [current_line]
	mov	eax,[macro_constants]
	mov	[additional_memory],eax
	mov	[macro_status],0
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
	mov	eax,[memory_end]
	mov	[labels_list],eax
	mov	[current_locals_prefix],0
	mov	esi,[source_start]
	mov	edi,[code_start]
	push	dword [additional_memory]
     parser_loop:
	mov	[current_line],esi
	cmp	edi,[labels_list]
	jae	out_of_memory
	mov	al,0Fh
	stosb
	mov	eax,esi
	stosd
	add	esi,12
	call	parse_line
	cmp	esi,[code_start]
	jb	parser_loop
	xor	al,al
	stosb
	pop	dword [additional_memory]
	mov	eax,[code_start]
	mov	[source_start],eax
	mov	[code_start],edi
	ret

parse_line:
	mov	[parenthesis_stack],0
      instruction_start:
	cmp	byte [esi],1Ah
	jne	empty_instruction
	push edi
	inc	esi
	movzx	ecx,byte [esi]
	inc	esi
	cmp	byte [esi+ecx],':'
	je	simple_label
	push esi
	push ecx
	add	esi,ecx
	cmp	byte [esi],1Ah
	je	check_for_data_label
	cmp	byte [esi],'='
	je	constant_label
	pop ecx
	pop esi
	jmp	get_main_instruction
      check_for_data_label:
	inc	esi
	movzx	ecx,byte [esi]
	inc	esi
	push edi
	mov	edi,data_directives
	call	get_symbol
	pop edi
	jnc	data_label
	pop ecx
	pop esi
      get_main_instruction:
	call	get_instruction
	jnc	parse_instruction
	mov	edi,data_directives
	call	get_symbol
	jnc	data_instruction
	mov	edi,symbols
	call	get_symbol
	pop edi
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
	pop ecx
	pop esi
	pop edi
	call	identify_label
	mov	byte [edi],3
	inc	edi
	stosd
	xor	al,al
	stosb
	inc	esi
	jmp	parse_arguments
      data_label:
	pop ecx
	pop ebx
	pop edi
	push ax
	push esi
	mov	esi,ebx
	call	identify_label
	mov	byte [edi],2
	inc	edi
	stosd
	pop esi
	pop ax
	stosb
	push edi
	jmp	data_instruction
      simple_label:
	pop edi
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
	mov	[current_locals_prefix],ebx
	ret
      local_label_name:
	call	get_label_id
	ret
      parse_prefix_instruction:
	cmp	byte [esi],1Ah
	jne	parse_arguments
	push edi
	inc	esi
	movzx	ecx,byte [esi]
	inc	esi
	jmp	get_main_instruction
      parse_label_directive:
	push edi
	lodsb
	cmp	al,1Ah
	jne	invalid_argument
	movzx	ecx,byte [esi]
	lodsb
	pop edi
	mov	al,2
	stosb
	call	identify_label
	stosd
	xor	al,al
	stosb
	jmp	parse_arguments
      parse_instruction:
	pop edi
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
	cmp	bx,segment_directive-assembler
	je	parse_label_directive
      parse_arguments:
	lodsb
	cmp	al,':'
	je	instruction_separator
	cmp	al,','
	je	separator
	cmp	al,'='
	je	separator
	cmp	al,'|'
	je	separator
	cmp	al,'&'
	je	separator
	cmp	al,'~'
	je	separator
	cmp	al,'>'
	je	greater
	cmp	al,'<'
	je	less
	cmp	al,')'
	je	close_expression
	or	al,al
	jz	line_parsed
	cmp	al,'['
	je	address_argument
	cmp	al,']'
	je	separator
	dec	esi
	cmp	al,1Ah
	jne	expression_argument
	push edi
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
	pop edi
	movsb
	jmp	argument_parsed
      symbol_argument:
	pop edi
	stosw
	jmp	argument_parsed
      operator_argument:
	pop edi
	stosb
	cmp	al,80h
	je	forced_expression
	jmp	argument_parsed
      check_argument:
	push esi
	push ecx
	sub	esi,2
	mov	edi,single_operand_operators
	call	get_operator
	pop ecx
	pop esi
	or	al,al
	jnz	not_instruction
	call	get_instruction
	jnc	parse_instruction
	mov	edi,data_directives
	call	get_symbol
	jnc	data_instruction
      not_instruction:
	pop edi
	sub	esi,2
      expression_argument:
	cmp	byte [esi],22h
	jne	not_string
	mov	eax,[esi+1]
	cmp	eax,8
	ja	string_argument
	lea	ebx,[esi+5+eax]
	push ebx
	push ecx
	push esi
	push edi
	mov	al,'('
	stosb
	call	convert_expression
	mov	al,')'
	stosb
	pop eax
	pop edx
	pop ecx
	pop ebx
	cmp	esi,ebx
	jne	expression_parsed
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
	push esi
	push edi
	inc	esi
	mov	al,'{'
	stosb
	inc	[parenthesis_stack]
	jmp	parse_arguments
      parse_expression:
	mov	al,'('
	stosb
	call	get_fp_value
	jc	expression
	mov	al,'.'
	stosb
	mov	eax,[fp_value]
	stosd
	mov	eax,[fp_value+4]
	stosd
	mov	eax,[fp_value+8]
	stosd
	jmp	expression_parsed
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
	push esi
	add	esi,4
	lea	ebx,[esi+1]
	cmp	byte [esi],':'
	pop esi
	jne	convert_address
	add	esi,2
	mov	ecx,2
	push ebx
	push edi
	mov	edi,symbols
	call	get_symbol
	pop edi
	pop esi
	jc	invalid_address
	cmp	al,10h
	jne	invalid_address
	mov	al,ah
	and	ah,11110000b
	cmp	ah,60h
	jne	invalid_address
	stosb
      convert_address:
	cmp	byte [esi],1Ah
	jne	convert_address_value
	push esi
	lodsw
	movzx	ecx,ah
	push edi
	mov	edi,address_sizes
	call	get_symbol
	pop edi
	jc	no_size_prefix
	mov	al,ah
	add	al,70h
	stosb
	add	esp,4
	jmp	convert_address_value
      no_size_prefix:
	pop esi
      convert_address_value:
	call	convert_expression
	lodsb
	cmp	al,']'
	jne	invalid_address
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
	mov	al,'�'
	jmp	separator
      less:
	cmp	byte [edi-1],83h
	je	separator
	cmp	byte [esi],'>'
	je	not_equal
	cmp	byte [esi],'='
	jne	separator
	inc	esi
	mov	al,'�'
	jmp	separator
      not_equal:
	inc	esi
	mov	al,'�'
	jmp	separator
      argument_parsed:
	cmp	[parenthesis_stack],0
	je	parse_arguments
	dec	[parenthesis_stack]
	add	esp,8
	jmp	argument_parsed
      expression_parsed:
	cmp	[parenthesis_stack],0
	je	parse_arguments
	cmp	byte [esi],')'
	jne	argument_parsed
	dec	[parenthesis_stack]
	pop edi
	pop esi
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
	mov	[current_locals_prefix],eax
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
	cmp	[parenthesis_stack],0
	jne	invalid_expression
	ret

;%include '../assemble.inc'

; flat assembler source
; Copyright (c) 1999-2001, Tomasz Grysztar
; All rights reserved.

assembler:
	mov	edi,[labels_list]
	mov	ecx,[memory_end]
	sub	ecx,edi
	shr	ecx,2
	xor	eax,eax
	rep	stosd
	mov	[current_pass],0
	mov	[number_of_sections],0
	mov	[times_working],0
      assembler_loop:
	mov	eax,[labels_list]
	mov	[display_buffer],eax
	mov	eax,[additional_memory_end]
	mov	[structures_buffer],eax
	mov	[next_pass_needed],0
	mov	[output_format],0
	mov	[format_flags],0
	mov	[code_type],16
	mov	[reloc_labels],0
	mov	[virtual_data],0
	mov	esi,[source_start]
	mov	edi,[code_start]
	mov	[org_start],edi
	mov	[org_sib],0
	mov	[error_line],0
	mov	[counter],0
	mov	[number_of_relocations],0
      pass_loop:
	call	assemble_line
	jnc	pass_loop
	mov	eax,[structures_buffer]
	cmp	eax,[additional_memory_end]
	jne	unexpected_end_of_file
	cmp	[output_format],3
	jne	pass_done
	call	finish_pe
      pass_done:
	cmp	[next_pass_needed],0
	je	assemble_done
      next_pass:
	inc	[current_pass]
	cmp	[current_pass],100
	jae	code_cannot_be_generated
	jmp	assembler_loop
      pass_error:
	mov	[current_line],eax
	jmp	near [error]
      assemble_done:
	mov	eax,[error_line]
	or	eax,eax
	jnz	pass_error
	call	flush_display_buffer
      assemble_ok:
	mov	eax,edi
	sub	eax,[code_start]
	mov	[real_code_size],eax
	cmp	edi,[undefined_data_end]
	jne	calculate_code_size
	mov	edi,[undefined_data_start]
      calculate_code_size:
	sub	edi,[code_start]
	mov	[code_size],edi
	mov	[written_size],0
	mov	edx,[output_file]
	call	create
	jc	write_failed
	cmp	[output_format],2
	jne	write_code
	call	write_mz_header
      write_code:
	mov	edx,[code_start]
	mov	ecx,[code_size]
	add	[written_size],ecx
	call	write
	jc	write_failed
	call	close
	ret

assemble_line:
	mov	eax,[display_buffer]
	sub	eax,100h
	cmp	edi,eax
	jae	out_of_memory
	lodsb
	or	al,al
	jz	source_end
	cmp	al,1
	je	assemble_instruction
	cmp	al,2
	je	define_label
	cmp	al,3
	je	define_constant
	cmp	al,0Fh
	je	new_line
	cmp	al,13h
	je	code_type_setting
	cmp	al,10h
	jne	illegal_instruction
	lodsb
	mov	ah,al
	shr	ah,4
	cmp	ah,6
	jne	illegal_instruction
	and	al,1111b
	mov	[segment_register],al
	call	store_segment_prefix
	jmp	assemble_line
      code_type_setting:
	lodsb
	mov	[code_type],al
	jmp	line_assembled
      new_line:
	lodsd
	mov	[current_line],eax
	jmp	assemble_line
      define_label:
	lodsd
	mov	ebx,eax
	lodsb
	mov	dl,al
	xor	ch,ch
	cmp	[reloc_labels],0
	je	label_reloc_ok
	mov	ch,2
      label_reloc_ok:
	xchg	ch,[ebx+11]
	mov	al,[current_pass]
	test	byte [ebx+8],1
	jz	new_label
	cmp	al,[ebx+9]
	je	symbol_already_defined
	mov	[ebx+9],al
	mov	eax,edi
	sub	eax,[org_start]
	xchg	[ebx],eax
	cdq
	xchg	[ebx+4],edx
	mov	ebp,[org_sib]
	xchg	[ebx+12],ebp
	cmp	[current_pass],0
	je	assemble_line
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
	or	[next_pass_needed],-1
	jmp	assemble_line
      new_label:
	or	byte [ebx+8],1
	mov	[ebx+9],al
	mov	byte [ebx+10],dl
	mov	eax,edi
	sub	eax,[org_start]
	mov	[ebx],eax
	cdq
	mov	dword [ebx+4],edx
	mov	eax,[org_sib]
	mov	[ebx+12],eax
	jmp	assemble_line
      define_constant:
	lodsd
	push eax
	lodsb
	push ax
	call	get_value
	pop bx
	mov	ch,bl
	pop ebx
      make_constant:
	mov	cl,[current_pass]
	test	byte [ebx+8],1
	jz	new_constant
	cmp	cl,[ebx+9]
	jne	redefine_constant
	test	byte [ebx+8],2
	jz	symbol_already_defined
	or	byte [ebx+8],4
      redefine_constant:
	mov	[ebx+9],cl
	xchg	[ebx],eax
	xchg	[ebx+4],edx
	mov	cl,[value_type]
	xchg	[ebx+11],cl
	cmp	[current_pass],0
	je	assemble_line
	cmp	eax,[ebx]
	jne	changed_constant
	cmp	edx,[ebx+4]
	jne	changed_constant
	cmp	cl,[ebx+11]
	jne	changed_constant
	jmp	assemble_line
      changed_constant:
	test	byte [ebx+8],4
	jnz	assemble_line
	or	[next_pass_needed],-1
	jmp	assemble_line
      new_constant:
	or	byte [ebx+8],1+2
	mov	word [ebx+9],cx
	mov	[ebx],eax
	mov	[ebx+4],edx
	mov	cl,[value_type]
	mov	[ebx+11],cl
	jmp	assemble_line
      assemble_instruction:
	mov	[operand_size],0
	mov	[forced_size],0
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
	jnz	extra_characters_on_line
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
	jz	nothing_to_skip
	cmp	al,0Fh
	je	nothing_to_skip
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
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	mov	[reloc_labels],0
	mov	dl,[value_type]
	or	dl,dl
	jz	org_ok
	cmp	dl,2
	jne	invalid_use_of_symbol
	or	[reloc_labels],-1
      org_ok:
	mov	ecx,edi
	sub	ecx,eax
	mov	[org_start],ecx
	mov	[org_sib],0
	jmp	instruction_assembled
label_directive:
	lodsb
	cmp	al,2
	jne	invalid_argument
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
	sub	eax,[org_start]
	mov	ebp,[org_sib]
	cmp	byte [esi],80h
	jne	define_free_label
	inc	esi
	lodsb
	cmp	al,'('
	jne	invalid_argument
	mov	byte [ebx+11],0
	push ebx
	push cx
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_address_value
	or	bh,bh
	setnz	ch
	xchg	ch,cl
	mov	bp,cx
	shl	ebp,16
	mov	bl,bh
	mov	bp,bx
	pop cx
	pop ebx
	mov	dl,al
	mov	dh,[value_type]
	cmp	dh,1
	je	invalid_use_of_symbol
	jb	free_label_reloc_ok
      define_free_label:
	xor	dh,dh
	cmp	[reloc_labels],0
	je	free_label_reloc_ok
	mov	dh,2
      free_label_reloc_ok:
	xchg	dh,[ebx+11]
	mov	cl,[current_pass]
	test	byte [ebx+8],1
	jz	new_free_label
	cmp	cl,[ebx+9]
	je	symbol_already_defined
	mov	ch,dh
	mov	[ebx+9],cl
	xchg	[ebx],eax
	cdq
	xchg	[ebx+4],edx
	xchg	[ebx+12],ebp
	cmp	[current_pass],0
	je	instruction_assembled
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
	or	[next_pass_needed],-1
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
	jne	invalid_argument
	lodsd
	inc	esi
	push eax
	mov	al,1
	cmp	byte [esi],11h
	jne	load_size_ok
	lodsb
	lodsb
      load_size_ok:
	cmp	al,8
	ja	invalid_value
	mov	[operand_size],al
	lodsb
	cmp	al,82h
	jne	invalid_argument
	lodsw
	cmp	ax,'('
	jne	invalid_argument
	lea	edx,[esi+4]
	mov	eax,[esi]
	lea	esi,[esi+4+eax+1]
	call	open
	jc	file_not_found
	mov	al,2
	xor	edx,edx
	call	lseek
	xor	edx,edx
	cmp	byte [esi],':'
	jne	load_position_ok
	inc	esi
	cmp	byte [esi],'('
	jne	invalid_argument
	inc	esi
	cmp	byte [esi],'.'
	je	invalid_value
	push ebx
	call	get_dword_value
	pop ebx
	mov	edx,eax
      load_position_ok:
	xor	al,al
	call	lseek
	mov	dword [value],0
	mov	dword [value+4],0
	movzx	ecx,[operand_size]
	mov	edx,value
	call	read
	jc	error_reading_file
	call	close
	mov	eax,dword [value]
	mov	edx,dword [value+4]
	pop ebx
	xor	ch,ch
	mov	[value_type],0
	jmp	make_constant
display_directive:
	push esi
	push edi
      prepare_display:
	lodsb
	cmp	al,'('
	jne	invalid_argument
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
	cmp	edi,[display_buffer]
	jae	out_of_memory
	lodsb
	or	al,al
	jz	do_display
	cmp	al,0Fh
	je	do_display
	cmp	al,','
	jne	extra_characters_on_line
	jmp	prepare_display
      do_display:
	dec	esi
	mov	ebp,edi
	pop edi
	pop ebx
	push esi
	push edi
	mov	esi,edi
	mov	ecx,ebp
	sub	ecx,esi
	mov	edi,[display_buffer]
	sub	edi,ecx
	sub	edi,4
	cmp	edi,esi
	jbe	out_of_memory
	mov	[display_buffer],edi
	mov	eax,ecx
	rep	movsb
	stosd
	pop edi
	pop esi
	jmp	instruction_assembled
flush_display_buffer:
	mov	eax,[display_buffer]
	or	eax,eax
	jz	display_done
	mov	esi,[labels_list]
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
	push esi
	call	display_block
	pop esi
	cmp	esi,[display_buffer]
	jne	display_messages
	mov	ax,0A0Dh
	cmp	word [value],ax
	je	display_ok
	mov	esi,value
	mov	[esi],ax
	mov	ecx,2
	call	display_block
      display_ok:
	mov	eax,[labels_list]
	mov	[display_buffer],eax
      display_done:
	ret
times_directive:
	lodsb
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	or	eax,eax
	jz	zero_times
	cmp	byte [esi],':'
	jne	times_argument_ok
	inc	esi
      times_argument_ok:
	push	dword [counter]
	push	dword [counter_limit]
	mov	[counter_limit],eax
	mov	[counter],1
      times_loop:
	push esi
	or	[times_working],-1
	call	assemble_line
	mov	eax,[counter_limit]
	cmp	[counter],eax
	je	times_done
	inc	[counter]
	pop esi
	jmp	times_loop
      times_done:
	mov	[times_working],0
	pop eax
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
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_address_value
	xor	ch,ch
	or	bh,bh
	jz	set_virtual
	mov	ch,1
	jmp	set_virtual
      virtual_at_current:
	dec	esi
	mov	eax,edi
	sub	eax,[org_start]
	xor	bx,bx
	xor	cx,cx
	mov	[value_type],0
	cmp	[reloc_labels],0
	je	set_virtual
	mov	[value_type],2
      set_virtual:
	mov	edx,[org_sib]
	mov	byte [org_sib],bh
	mov	byte [org_sib+1],bl
	mov	byte [org_sib+2],ch
	mov	byte [org_sib+3],cl
	call	allocate_structure_data
	mov	word [ebx],virtual_directive-assembler
	neg	eax
	add	eax,edi
	xchg	[org_start],eax
	mov	[ebx+4],eax
	mov	[ebx+8],edx
	mov	al,[virtual_data]
	mov	[ebx+2],al
	mov	al,[reloc_labels]
	mov	[ebx+3],al
	mov	[ebx+0Ch],edi
	or	[virtual_data],-1
	mov	[reloc_labels],0
	cmp	[value_type],1
	je	invalid_use_of_symbol
	cmp	[value_type],2
	jne	instruction_assembled
	or	[reloc_labels],-1
	jmp	instruction_assembled
      allocate_structure_data:
	mov	ebx,[structures_buffer]
	sub	ebx,10h
	cmp	ebx,[additional_memory]
	jb	out_of_memory
	mov	[structures_buffer],ebx
	ret
      find_structure_data:
	mov	ebx,[structures_buffer]
      scan_structures:
	cmp	ebx,[additional_memory_end]
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
	jc	unexpected_instruction
	mov	al,[ebx+2]
	mov	[virtual_data],al
	mov	al,[ebx+3]
	mov	[reloc_labels],al
	mov	eax,[ebx+4]
	mov	[org_start],eax
	mov	eax,[ebx+8]
	mov	[org_sib],eax
	mov	edi,[ebx+0Ch]
      remove_structure_data:
	push esi
	push edi
	mov	esi,[structures_buffer]
	mov	ecx,ebx
	sub	ecx,esi
	lea	edi,[esi+10h]
	mov	[structures_buffer],edi
	shr	ecx,2
	rep	movsd
	pop edi
	pop esi
	jmp	instruction_assembled
repeat_directive:
	cmp	[times_working],0
	jne	unexpected_instruction
	lodsb
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	or	eax,eax
	jz	zero_repeat
	call	allocate_structure_data
	mov	word [ebx],repeat_directive-assembler
	xchg	eax,[counter_limit]
	mov	[ebx+4],eax
	mov	eax,1
	xchg	eax,[counter]
	mov	[ebx+8],eax
	mov	[ebx+0Ch],esi
	jmp	instruction_assembled
      end_repeat:
	cmp	[times_working],0
	jne	unexpected_instruction
	call	find_structure_data
	jc	unexpected_instruction
	mov	eax,[counter_limit]
	inc	[counter]
	cmp	[counter],eax
	jbe	continue_repeating
	mov	eax,[ebx+4]
	mov	[counter_limit],eax
	mov	eax,[ebx+8]
	mov	[counter],eax
	jmp	remove_structure_data
      continue_repeating:
	mov	esi,[ebx+0Ch]
	jmp	instruction_assembled
      zero_repeat:
	mov	al,[esi]
	or	al,al
	jz	unexpected_end_of_file
	cmp	al,0Fh
	jne	extra_characters_on_line
	call	find_end_repeat
	jmp	instruction_assembled
      find_end_repeat:
	call	find_structure_end
	cmp	ax,repeat_directive-assembler
	jne	unexpected_instruction
	ret
      find_structure_end:
	call	skip_line
	lodsb
	cmp	al,0Fh
	jne	unexpected_end_of_file
	lodsd
	mov	[current_line],eax
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
	je	skip_if
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
	cmp	[times_working],0
	jne	unexpected_instruction
	call	calculate_logical_expression
	mov	dl,al
	mov	al,[esi]
	or	al,al
	jz	unexpected_end_of_file
	cmp	al,0Fh
	jne	extra_characters_on_line
	or	dl,dl
	jnz	if_true
	call	find_else
	jc	instruction_assembled
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
	jz	unexpected_end_of_file
	cmp	al,0Fh
	jne	extra_characters_on_line
	call	allocate_structure_data
	mov	word [ebx],if_directive-assembler
	or	byte [ebx+2],-1
	jmp	instruction_assembled
      else_directive:
	cmp	[times_working],0
	jne	unexpected_instruction
	mov	ax,if_directive-assembler
	call	find_structure_data
	jc	unexpected_instruction
	cmp	byte [ebx+2],0
	jne	unexpected_instruction
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
	jz	unexpected_end_of_file
	cmp	al,0Fh
	jne	extra_characters_on_line
	call	find_end_if
	jmp	remove_structure_data
      end_if:
	cmp	[times_working],0
	jne	unexpected_instruction
	call	find_structure_data
	jc	unexpected_instruction
	jmp	remove_structure_data
      skip_if:
	call	find_else
	jc	find_structure_end
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
	jne	unexpected_instruction
	stc
	ret
      else_found:
	clc
	ret
      find_end_if:
	call	find_structure_end
	cmp	ax,if_directive-assembler
	jne	unexpected_instruction
	ret
end_directive:
	lodsb
	cmp	al,1
	jne	invalid_argument
	lodsw
	inc	esi
	cmp	ax,virtual_directive-assembler
	je	end_virtual
	cmp	ax,repeat_directive-assembler
	je	end_repeat
	cmp	ax,if_directive-assembler
	je	end_if
	cmp	ax,data_directive-assembler
	je	end_data
	jmp	invalid_argument

data_bytes:
	lodsb
	cmp	al,'('
	je	get_byte
	cmp	al,'?'
	jne	invalid_argument
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
	cmp	edi,[display_buffer]
	jae	out_of_memory
	lodsb
	or	al,al
	jz	data_end
	cmp	al,0Fh
	je	data_end
	cmp	al,','
	jne	extra_characters_on_line
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
	cmp	[virtual_data],0
	je	mark_undefined_data
	ret
      mark_undefined_data:
	cmp	eax,[undefined_data_end]
	je	undefined_data_ok
	mov	[undefined_data_start],eax
      undefined_data_ok:
	mov	[undefined_data_end],edi
	ret
data_unicode:
	or	[base_code],-1
	jmp	get_words_data
data_words:
	mov	[base_code],0
      get_words_data:
	lodsb
	cmp	al,'('
	je	get_word
	cmp	al,'?'
	jne	invalid_argument
	mov	eax,edi
	mov	word [edi],0
	scasw
	call	undefined_data
	jmp	word_ok
      get_word:
	cmp	[base_code],0
	je	word_data_value
	cmp	byte [esi],0
	je	word_string
      word_data_value:
	call	get_word_value
	call	mark_relocation
	stosw
      word_ok:
	cmp	edi,[display_buffer]
	jae	out_of_memory
	lodsb
	or	al,al
	jz	data_end
	cmp	al,0Fh
	je	data_end
	cmp	al,','
	jne	extra_characters_on_line
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
	jne	invalid_argument
	mov	eax,edi
	mov	dword [edi],0
	scasd
	call	undefined_data
	jmp	dword_ok
      get_dword:
	push esi
	call	get_dword_value
	pop ebx
	cmp	byte [esi],':'
	je	complex_dword
	call	mark_relocation
	stosd
	jmp	dword_ok
      complex_dword:
	mov	esi,ebx
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_word_value
	mov	dx,ax
	inc	esi
	lodsb
	cmp	al,'('
	jne	invalid_operand
	mov	al,[value_type]
	push ax
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_word_value
	call	mark_relocation
	stosw
	pop ax
	mov	[value_type],al
	mov	ax,dx
	call	mark_relocation
	stosw
      dword_ok:
	cmp	edi,[display_buffer]
	jae	out_of_memory
	lodsb
	or	al,al
	jz	data_end
	cmp	al,0Fh
	je	data_end
	cmp	al,','
	jne	extra_characters_on_line
	jmp	data_dwords
data_pwords:
	lodsb
	cmp	al,'('
	je	get_pword
	cmp	al,'?'
	jne	invalid_argument
	mov	eax,edi
	mov	dword [edi],0
	scasd
	mov	word [edi],0
	scasw
	call	undefined_data
	jmp	pword_ok
      get_pword:
	push esi
	call	get_pword_value
	pop ebx
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
	je	invalid_value
	call	get_word_value
	mov	dx,ax
	inc	esi
	lodsb
	cmp	al,'('
	jne	invalid_operand
	mov	al,[value_type]
	push ax
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	call	mark_relocation
	stosd
	pop ax
	mov	[value_type],al
	mov	ax,dx
	call	mark_relocation
	stosw
      pword_ok:
	cmp	edi,[display_buffer]
	jae	out_of_memory
	lodsb
	or	al,al
	jz	data_end
	cmp	al,0Fh
	je	data_end
	cmp	al,','
	jne	extra_characters_on_line
	jmp	data_pwords
data_qwords:
	lodsb
	cmp	al,'('
	je	get_qword
	cmp	al,'?'
	jne	invalid_argument
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
	cmp	edi,[display_buffer]
	jae	out_of_memory
	lodsb
	or	al,al
	jz	data_end
	cmp	al,0Fh
	je	data_end
	cmp	al,','
	jne	extra_characters_on_line
	jmp	data_qwords
data_twords:
	lodsb
	cmp	al,'('
	je	get_tbyte
	cmp	al,'?'
	jne	invalid_argument
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
	jne	invalid_value
	cmp	word [esi+8],8000h
	je	fp_zero_tbyte
	mov	eax,[esi]
	stosd
	mov	eax,[esi+4]
	stosd
	mov	ax,[esi+8]
	add	ax,3FFFh
	cmp	ax,8000h
	jae	value_out_of_range
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
	cmp	edi,[display_buffer]
	jae	out_of_memory
	lodsb
	or	al,al
	jz	data_end
	cmp	al,0Fh
	je	data_end
	cmp	al,','
	jne	extra_characters_on_line
	jmp	data_twords
data_file:
	lodsw
	cmp	ax,'('
	jne	invalid_argument
	lea	edx,[esi+4]
	mov	eax,[esi]
	lea	esi,[esi+4+eax+1]
	call	open
	jc	file_not_found
	mov	al,2
	xor	edx,edx
	call	lseek
	push eax
	xor	edx,edx
	cmp	byte [esi],':'
	jne	position_ok
	inc	esi
	cmp	byte [esi],'('
	jne	invalid_argument
	inc	esi
	cmp	byte [esi],'.'
	je	invalid_value
	push ebx
	call	get_dword_value
	pop ebx
	mov	edx,eax
	sub	[esp],edx
      position_ok:
	cmp	byte [esi],','
	jne	size_ok
	inc	esi
	cmp	byte [esi],'('
	jne	invalid_argument
	inc	esi
	cmp	byte [esi],'.'
	je	invalid_value
	push ebx
	push edx
	call	get_dword_value
	pop edx
	pop ebx
	mov	[esp],eax
      size_ok:
	cmp	[next_pass_needed],0
	jne	file_reserve
	xor	al,al
	call	lseek
	pop ecx
	mov	edx,edi
	add	edi,ecx
	jc	out_of_memory
	cmp	edi,[display_buffer]
	jae	out_of_memory
	call	read
	jc	error_reading_file
	call	close
      check_for_next_name:
	lodsb
	cmp	al,','
	je	data_file
	dec	esi
	jmp	instruction_assembled
      file_reserve:
	call	close
	pop ecx
	add	edi,ecx
	jc	out_of_memory
	cmp	edi,[display_buffer]
	jae	out_of_memory
	jmp	check_for_next_name
reserve_bytes:
	lodsb
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	cmp	eax,0
	jl	reserve_negative
	mov	ecx,eax
	mov	edx,ecx
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[display_buffer]
	jae	out_of_memory
	push edi
	cmp	[next_pass_needed],0
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
	pop eax
	call	undefined_data
	jmp	instruction_assembled
      reserve_negative:
	cmp	[error_line],0
	jne	instruction_assembled
	mov	eax,[current_line]
	mov	[error_line],eax
	mov	[error],invalid_value
	jmp	instruction_assembled
reserve_words:
	lodsb
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	cmp	eax,0
	jl	reserve_negative
	mov	ecx,eax
	mov	edx,ecx
	shl	edx,1
	jc	out_of_memory
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[display_buffer]
	jae	out_of_memory
	push edi
	cmp	[next_pass_needed],0
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
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	cmp	eax,0
	jl	reserve_negative
	mov	ecx,eax
	mov	edx,ecx
	shl	edx,1
	jc	out_of_memory
	shl	edx,1
	jc	out_of_memory
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[display_buffer]
	jae	out_of_memory
	push edi
	cmp	[next_pass_needed],0
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
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	cmp	eax,0
	jl	reserve_negative
	mov	ecx,eax
	shl	ecx,1
	jc	out_of_memory
	add	ecx,eax
	mov	edx,ecx
	shl	edx,1
	jc	out_of_memory
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[display_buffer]
	jae	out_of_memory
	push edi
	cmp	[next_pass_needed],0
	je	zero_words
	lea	edi,[edi+ecx*2]
	jmp	reserved_data
reserve_qwords:
	lodsb
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	cmp	eax,0
	jl	reserve_negative
	mov	ecx,eax
	shl	ecx,1
	jc	out_of_memory
	mov	edx,ecx
	shl	edx,1
	jc	out_of_memory
	shl	edx,1
	jc	out_of_memory
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[display_buffer]
	jae	out_of_memory
	push edi
	cmp	[next_pass_needed],0
	je	zero_dwords
	lea	edi,[edi+ecx*4]
	jmp	reserved_data
reserve_twords:
	lodsb
	cmp	al,'('
	jne	invalid_argument
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	cmp	eax,0
	jl	reserve_negative
	mov	ecx,eax
	shl	ecx,2
	jc	out_of_memory
	add	ecx,eax
	mov	edx,ecx
	shl	edx,1
	jc	out_of_memory
	add	edx,edi
	jc	out_of_memory
	cmp	edx,[display_buffer]
	jae	out_of_memory
	push edi
	cmp	[next_pass_needed],0
	je	zero_words
	lea	edi,[edi+ecx*2]
	jmp	reserved_data

simple_instruction:
	stosb
	jmp	instruction_assembled
simple_instruction_16bit:
	cmp	[code_type],32
	je	size_prefix
	stosb
	jmp	instruction_assembled
      size_prefix:
	mov	ah,al
	mov	al,66h
	stosw
	jmp	instruction_assembled
simple_instruction_32bit:
	cmp	[code_type],16
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
	ja	invalid_operand_size
	cmp	al,'('
	jne	invalid_operand
	call	get_byte_value
	mov	ah,al
	mov	al,0CDh
	stosw
	jmp	instruction_assembled
aa_instruction:
	push ax
	mov	bl,10
	cmp	byte [esi],'('
	jne	.store
	inc	esi
	xor	al,al
	xchg	al,[operand_size]
	cmp	al,1
	ja	invalid_operand_size
	call	get_byte_value
	mov	bl,al
      .store:
	cmp	[operand_size],0
	jne	invalid_operand
	pop ax
	mov	ah,bl
	stosw
	jmp	instruction_assembled

basic_instruction:
	mov	[base_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	basic_reg
	cmp	al,'['
	jne	invalid_operand
      basic_mem:
	call	get_address
	push edx
	push bx
	push cx
	lodsb
	cmp	al,','
	jne	invalid_operand
	cmp	byte [esi],11h
	sete	al
	mov	[imm_sized],al
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	basic_mem_imm
	cmp	al,10h
	jne	invalid_operand
      basic_mem_reg:
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	pop cx
	pop bx
	pop edx
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
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      basic_mem_reg_32bit:
	call	operand_32bit_prefix
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      basic_mem_imm:
	mov	al,[operand_size]
	cmp	al,1
	je	basic_mem_imm_8bit
	cmp	al,2
	je	basic_mem_imm_16bit
	cmp	al,4
	je	basic_mem_imm_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
	jmp	basic_mem_imm_32bit
      basic_mem_imm_8bit:
	call	get_byte_value
	mov	byte [value],al
	mov	al,[base_code]
	shr	al,3
	mov	[postbyte_register],al
	pop cx
	pop bx
	pop edx
	mov	[base_code],80h
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      basic_mem_imm_16bit:
	call	get_word_value
	mov	word [value],ax
	mov	al,[base_code]
	shr	al,3
	mov	[postbyte_register],al
	call	operand_16bit_prefix
	pop cx
	pop bx
	pop edx
	cmp	[value_type],0
	jne	.store
	cmp	[imm_sized],0
	jne	.store
	cmp	word [value],80h
	jb	basic_mem_simm_8bit
	cmp	word [value],-80h
	jae	basic_mem_simm_8bit
      .store:
	mov	[base_code],81h
	call	store_instruction
	mov	ax,word [value]
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      basic_mem_simm_8bit:
	mov	[base_code],83h
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      basic_mem_imm_32bit:
	call	get_dword_value
	mov	dword [value],eax
	mov	al,[base_code]
	shr	al,3
	mov	[postbyte_register],al
	call	operand_32bit_prefix
	pop cx
	pop bx
	pop edx
	cmp	[value_type],0
	jne	.store
	cmp	[imm_sized],0
	jne	.store
	cmp	dword [value],80h
	jb	basic_mem_simm_8bit
	cmp	dword [value],-80h
	jae	basic_mem_simm_8bit
      .store:
	mov	[base_code],81h
	call	store_instruction
	mov	eax,dword [value]
	call	mark_relocation
	stosd
	jmp	instruction_assembled
      basic_reg:
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	cmp	byte [esi],11h
	sete	al
	mov	[imm_sized],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	basic_reg_reg
	cmp	al,'('
	je	basic_reg_imm
	cmp	al,'['
	jne	invalid_operand
      basic_reg_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	basic_reg_mem_8bit
	cmp	al,2
	je	basic_reg_mem_16bit
	cmp	al,4
	je	basic_reg_mem_32bit
	jmp	invalid_operand_size
      basic_reg_mem_8bit:
	add	[base_code],2
	call	store_instruction
	jmp	instruction_assembled
      basic_reg_mem_16bit:
	call	operand_16bit_prefix
	add	[base_code],3
	call	store_instruction
	jmp	instruction_assembled
      basic_reg_mem_32bit:
	call	operand_32bit_prefix
	add	[base_code],3
	call	store_instruction
	jmp	instruction_assembled
      basic_reg_reg:
	lodsb
	call	convert_register
	shl	al,3
	mov	bl,[postbyte_register]
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
	inc	[base_code]
	jmp	basic_reg_reg_8bit
      basic_reg_reg_16bit:
	call	operand_16bit_prefix
	inc	[base_code]
      basic_reg_reg_8bit:
	mov	al,[base_code]
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      basic_reg_imm:
	mov	al,[operand_size]
	cmp	al,1
	je	basic_reg_imm_8bit
	cmp	al,2
	je	basic_reg_imm_16bit
	cmp	al,4
	je	basic_reg_imm_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
	jmp	basic_reg_imm_32bit
      basic_reg_imm_8bit:
	call	get_byte_value
	mov	dl,al
	mov	ah,[base_code]
	or	ah,11000000b
	mov	bl,[postbyte_register]
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
	mov	al,[base_code]
	add	al,4
	stosb
	mov	al,dl
	stosb
	jmp	instruction_assembled
      basic_reg_imm_16bit:
	call	get_word_value
	mov	dx,ax
	call	operand_16bit_prefix
	mov	ah,[base_code]
	or	ah,11000000b
	mov	bl,[postbyte_register]
	and	bl,111b
	or	ah,bl
	cmp	[value_type],0
	jne	.store
	cmp	[imm_sized],0
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
	mov	al,[base_code]
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
	mov	ah,[base_code]
	or	ah,11000000b
	mov	bl,[postbyte_register]
	and	bl,111b
	or	ah,bl
	cmp	[value_type],0
	jne	.store
	cmp	[imm_sized],0
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
	mov	al,[base_code]
	add	al,5
	stosb
	mov	eax,edx
	call	mark_relocation
	stosd
	jmp	instruction_assembled
single_operand_instruction:
	mov	[base_code],0F6h
	mov	[postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	single_reg
	cmp	al,'['
	jne	invalid_operand
      single_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	single_mem_8bit
	cmp	al,2
	je	single_mem_16bit
	cmp	al,4
	je	single_mem_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      single_mem_8bit:
	call	store_instruction
	jmp	instruction_assembled
      single_mem_16bit:
	call	operand_16bit_prefix
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      single_mem_32bit:
	call	operand_32bit_prefix
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      single_reg:
	lodsb
	call	convert_register
	mov	bl,[postbyte_register]
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
	mov	[base_code],88h
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	mov_reg
	cmp	al,'['
	jne	invalid_operand
      mov_mem:
	call	get_address
	push edx
	push bx
	push cx
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	mov_mem_imm
	cmp	al,10h
	jne	invalid_operand
      mov_mem_reg:
	lodsb
	cmp	al,60h
	jae	mov_mem_sreg
	call	convert_register
	mov	[postbyte_register],al
	pop cx
	pop bx
	pop edx
	cmp	ah,1
	je	mov_mem_reg_8bit
	cmp	ah,2
	je	mov_mem_reg_16bit
	cmp	ah,4
	je	mov_mem_reg_32bit
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
	jnz	invalid_address_size
	cmp	[code_type],32
	je	mov_mem_address32_al
	cmp	edx,10000h
	jb	mov_mem_address16_al
      mov_mem_address32_al:
	call	address_32bit_prefix
	call	store_segment_prefix_if_necessary
	mov	al,0A2h
      store_mov_address32:
	stosb
	push instruction_assembled
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
	jge	value_out_of_range
	jmp	instruction_assembled
      mov_mem_reg_16bit:
	call	operand_16bit_prefix
	mov	al,[postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_mem_ax
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      mov_mem_ax:
	cmp	ch,2
	je	mov_mem_address16_ax
	test	ch,4
	jnz	mov_mem_address32_ax
	or	ch,ch
	jnz	invalid_address_size
	cmp	[code_type],32
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
	mov	al,[postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_mem_ax
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      mov_mem_sreg:
	cmp	al,70h
	jae	invalid_operand
	sub	al,61h
	mov	[postbyte_register],al
	pop cx
	pop bx
	pop edx
	mov	ah,[operand_size]
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
	mov	[base_code],8Ch
	call	store_instruction
	jmp	instruction_assembled
      mov_mem_imm:
	mov	al,[operand_size]
	cmp	al,1
	je	mov_mem_imm_8bit
	cmp	al,2
	je	mov_mem_imm_16bit
	cmp	al,4
	je	mov_mem_imm_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
	jmp	mov_mem_imm_32bit
      mov_mem_imm_8bit:
	call	get_byte_value
	mov	byte [value],al
	mov	[postbyte_register],0
	mov	[base_code],0C6h
	pop cx
	pop bx
	pop edx
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      mov_mem_imm_16bit:
	call	get_word_value
	mov	word [value],ax
	mov	[postbyte_register],0
	mov	[base_code],0C7h
	call	operand_16bit_prefix
	pop cx
	pop bx
	pop edx
	call	store_instruction
	mov	ax,word [value]
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      mov_mem_imm_32bit:
	call	get_dword_value
	mov	dword [value],eax
	mov	[postbyte_register],0
	mov	[base_code],0C7h
	call	operand_32bit_prefix
	pop cx
	pop bx
	pop edx
	call	store_instruction
	mov	eax,dword [value]
	call	mark_relocation
	stosd
	jmp	instruction_assembled
      mov_reg:
	lodsb
	cmp	al,50h
	jae	mov_sreg
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	je	mov_reg_mem
	cmp	al,'('
	je	mov_reg_imm
	cmp	al,10h
	jne	invalid_operand
      mov_reg_reg:
	lodsb
	cmp	al,50h
	jae	mov_reg_sreg
	call	convert_register
	shl	al,3
	mov	bl,[postbyte_register]
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
	inc	[base_code]
	jmp	mov_reg_reg_8bit
      mov_reg_reg_16bit:
	call	operand_16bit_prefix
	inc	[base_code]
      mov_reg_reg_8bit:
	mov	al,[base_code]
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
	ja	invalid_operand
	sub	al,61h
	mov	bl,[postbyte_register]
	shl	al,3
	or	bl,al
	or	bl,11000000b
	cmp	[operand_size],4
	je	mov_reg_sreg32
	cmp	[operand_size],2
	jne	invalid_operand_size
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
	mov	bl,[postbyte_register]
	shl	al,3
	or	bl,al
	or	bl,11000000b
	cmp	[operand_size],4
	jne	invalid_operand_size
	mov	ah,bh
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
      mov_reg_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	mov_reg_mem_8bit
	cmp	al,2
	je	mov_reg_mem_16bit
	cmp	al,4
	je	mov_reg_mem_32bit
	jmp	invalid_operand_size
      mov_reg_mem_8bit:
	mov	al,[postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_al_mem
	add	[base_code],2
	call	store_instruction
	jmp	instruction_assembled
      mov_al_mem:
	cmp	ch,2
	je	mov_al_mem_address16
	test	ch,4
	jnz	mov_al_mem_address32
	or	ch,ch
	jnz	invalid_address_size
	cmp	[code_type],32
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
	mov	al,[postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_ax_mem
	add	[base_code],3
	call	store_instruction
	jmp	instruction_assembled
      mov_ax_mem:
	cmp	ch,2
	je	mov_ax_mem_address16
	test	ch,4
	jnz	mov_ax_mem_address32
	or	ch,ch
	jnz	invalid_address_size
	cmp	[code_type],32
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
	mov	al,[postbyte_register]
	or	al,bl
	or	al,bh
	jz	mov_ax_mem
	add	[base_code],3
	call	store_instruction
	jmp	instruction_assembled
      mov_reg_imm:
	mov	al,[operand_size]
	cmp	al,1
	je	mov_reg_imm_8bit
	cmp	al,2
	je	mov_reg_imm_16bit
	cmp	al,4
	je	mov_reg_imm_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
	jmp	mov_reg_imm_32bit
      mov_reg_imm_8bit:
	call	get_byte_value
	mov	ah,al
	mov	al,[postbyte_register]
	and	al,111b
	add	al,0B0h
	stosw
	jmp	instruction_assembled
      mov_reg_imm_16bit:
	call	get_word_value
	mov	dx,ax
	call	operand_16bit_prefix
	mov	al,[postbyte_register]
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
	mov	al,[postbyte_register]
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
	je	mov_creg
	cmp	ah,7
	je	mov_dreg
	ja	invalid_operand
	sub	al,61h
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	je	mov_sreg_mem
	cmp	al,10h
	jne	invalid_operand
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
	mov	al,[postbyte_register]
	shl	al,3
	or	bl,al
	mov	al,8Eh
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      mov_sreg_mem:
	call	get_address
	mov	al,[operand_size]
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
	mov	[base_code],8Eh
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
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	cmp	ah,4
	jne	invalid_operand_size
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
cmov_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	je	cmov_reg_mem
	cmp	al,10h
	jne	invalid_operand
      cmov_reg_reg:
	lodsb
	call	convert_register
	mov	bl,[postbyte_register]
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	mov	al,ah
	cmp	al,2
	je	cmov_reg_reg_16bit
	cmp	al,4
	je	cmov_reg_reg_32bit
	jmp	invalid_operand_size
      cmov_reg_reg_32bit:
	call	operand_32bit_prefix
	jmp	cmov_reg_reg_store
      cmov_reg_reg_16bit:
	call	operand_16bit_prefix
      cmov_reg_reg_store:
	mov	ah,[extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
      cmov_reg_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,2
	je	cmov_reg_mem_16bit
	cmp	al,4
	je	cmov_reg_mem_32bit
	jmp	invalid_operand_size
      cmov_reg_mem_16bit:
	call	operand_16bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      cmov_reg_mem_32bit:
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
test_instruction:
	mov	[base_code],84h
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	test_reg
	cmp	al,'['
	jne	invalid_operand
      test_mem:
	call	get_address
	push edx
	push bx
	push cx
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	test_mem_imm
	cmp	al,10h
	jne	invalid_operand
      test_mem_reg:
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	pop cx
	pop bx
	pop edx
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
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      test_mem_reg_32bit:
	call	operand_32bit_prefix
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      test_mem_imm:
	mov	al,[operand_size]
	cmp	al,1
	je	test_mem_imm_8bit
	cmp	al,2
	je	test_mem_imm_16bit
	cmp	al,4
	je	test_mem_imm_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
	jmp	test_mem_imm_32bit
      test_mem_imm_8bit:
	call	get_byte_value
	mov	byte [value],al
	mov	[postbyte_register],0
	mov	[base_code],0F6h
	pop cx
	pop bx
	pop edx
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      test_mem_imm_16bit:
	call	get_word_value
	mov	word [value],ax
	mov	[postbyte_register],0
	mov	[base_code],0F7h
	call	operand_16bit_prefix
	pop cx
	pop bx
	pop edx
	call	store_instruction
	mov	ax,word [value]
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      test_mem_imm_32bit:
	call	get_dword_value
	mov	dword [value],eax
	mov	[postbyte_register],0
	mov	[base_code],0F7h
	call	operand_32bit_prefix
	pop cx
	pop bx
	pop edx
	call	store_instruction
	mov	eax,dword [value]
	call	mark_relocation
	stosd
	jmp	instruction_assembled
      test_reg:
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	test_reg_imm
	cmp	al,10h
	jne	invalid_operand
      test_reg_reg:
	lodsb
	call	convert_register
	shl	al,3
	mov	bl,[postbyte_register]
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
	inc	[base_code]
	jmp	basic_reg_reg_8bit
      test_reg_reg_16bit:
	call	operand_16bit_prefix
	inc	[base_code]
      test_reg_reg_8bit:
	mov	al,[base_code]
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      test_reg_imm:
	mov	al,[operand_size]
	cmp	al,1
	je	test_reg_imm_8bit
	cmp	al,2
	je	test_reg_imm_16bit
	cmp	al,4
	je	test_reg_imm_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
	jmp	test_reg_imm_32bit
      test_reg_imm_8bit:
	call	get_byte_value
	mov	dl,al
	mov	ah,11000000b
	mov	bl,[postbyte_register]
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
	mov	bl,[postbyte_register]
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
	mov	bl,[postbyte_register]
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
	mov	[base_code],86h
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	xchg_reg
	cmp	al,'['
	jne	invalid_operand
      xchg_mem:
	call	get_address
	push edx
	push bx
	push cx
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
      xchg_mem_reg:
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	pop cx
	pop bx
	pop edx
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
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      xchg_mem_reg_32bit:
	call	operand_32bit_prefix
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      xchg_reg:
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	je	xchg_reg_mem
	cmp	al,10h
	jne	invalid_operand
      xchg_reg_reg:
	lodsb
	call	convert_register
	mov	bh,al
	mov	bl,[postbyte_register]
	shl	[postbyte_register],3
	or	al,11000000b
	or	[postbyte_register],al
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
	inc	[base_code]
	jmp	xchg_reg_reg_8bit
      xchg_reg_reg_16bit:
	call	operand_16bit_prefix
	or	bh,bh
	jz	xchg_ax_reg
	xchg	bh,bl
	or	bh,bh
	jz	xchg_ax_reg
	inc	[base_code]
      xchg_reg_reg_8bit:
	mov	al,[base_code]
	mov	ah,[postbyte_register]
	stosw
	jmp	instruction_assembled
      xchg_ax_reg:
	mov	al,90h
	add	al,bl
	stosb
	jmp	instruction_assembled
      xchg_reg_mem:
	call	get_address
	mov	al,[operand_size]
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
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      xchg_reg_mem_16bit:
	call	operand_16bit_prefix
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
push_instruction:
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	push_reg
	cmp	al,'('
	je	push_imm
	cmp	al,'['
	jne	invalid_operand
      push_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,2
	je	push_mem_16bit
	cmp	al,4
	je	push_mem_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      push_mem_16bit:
	call	operand_16bit_prefix
	mov	[base_code],0FFh
	mov	[postbyte_register],110b
	call	store_instruction
	jmp	push_done
      push_mem_32bit:
	call	operand_32bit_prefix
	mov	[base_code],0FFh
	mov	[postbyte_register],110b
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
	mov	bl,[operand_size]
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
	jae	invalid_operand
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
	mov	al,[operand_size]
	cmp	al,2
	je	push_imm_16bit
	cmp	al,4
	je	push_imm_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[code_type],16
	je	push_imm_optimized_16bit
      push_imm_optimized_32bit:
	call	get_dword_value
	mov	edx,eax
	cmp	[value_type],0
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
	cmp	[value_type],0
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
	je	instruction_assembled
	or	al,al
	jz	instruction_assembled
	mov	[operand_size],0
	mov	[forced_size],0
	jmp	push_instruction
pop_instruction:
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	pop_reg
	cmp	al,'['
	jne	invalid_operand
      pop_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,2
	je	pop_mem_16bit
	cmp	al,4
	je	pop_mem_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      pop_mem_16bit:
	call	operand_16bit_prefix
	mov	[base_code],08Fh
	mov	[postbyte_register],0
	call	store_instruction
	jmp	pop_done
      pop_mem_32bit:
	call	operand_32bit_prefix
	mov	[base_code],08Fh
	mov	[postbyte_register],0
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
	mov	bl,[operand_size]
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
	jae	invalid_operand
	sub	al,61h
	cmp	al,1
	je	illegal_instruction
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
	je	instruction_assembled
	or	al,al
	jz	instruction_assembled
	mov	[operand_size],0
	mov	[forced_size],0
	jmp	pop_instruction
inc_instruction:
	mov	[base_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	inc_reg
	cmp	al,'['
	je	inc_mem
	jne	invalid_operand
      inc_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	inc_mem_8bit
	cmp	al,2
	je	inc_mem_16bit
	cmp	al,4
	je	inc_mem_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      inc_mem_8bit:
	mov	al,0FEh
	xchg	al,[base_code]
	mov	[postbyte_register],al
	call	store_instruction
	jmp	instruction_assembled
      inc_mem_16bit:
	call	operand_16bit_prefix
	mov	al,0FFh
	xchg	al,[base_code]
	mov	[postbyte_register],al
	call	store_instruction
	jmp	instruction_assembled
      inc_mem_32bit:
	call	operand_32bit_prefix
	mov	al,0FFh
	xchg	al,[base_code]
	mov	[postbyte_register],al
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
	mov	dh,[base_code]
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
	mov	ah,[base_code]
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
	mov	[base_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	arpl_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	cmp	ah,2
	jne	invalid_operand_size
	mov	[base_code],63h
	call	store_instruction
	jmp	instruction_assembled
      arpl_reg:
	lodsb
	call	convert_register
	cmp	ah,2
	jne	invalid_operand_size
	mov	dl,al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	cmp	ah,2
	jne	invalid_operand_size
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
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,2
	je	bound_16bit
	cmp	al,4
	je	bound_32bit
	jmp	invalid_operand_size
      bound_32bit:
	call	operand_32bit_prefix
	mov	[base_code],62h
	call	store_instruction
	jmp	instruction_assembled
      bound_16bit:
	call	operand_16bit_prefix
	mov	[base_code],62h
	call	store_instruction
	jmp	instruction_assembled
set_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	set_reg
	cmp	al,'['
	jne	invalid_operand
      set_mem:
	call	get_address
	cmp	[operand_size],1
	ja	invalid_operand_size
	mov	[postbyte_register],0
	call	store_instruction
	jmp	instruction_assembled
      set_reg:
	lodsb
	call	convert_register
	mov	bl,al
	cmp	ah,1
	jne	invalid_operand_size
	mov	ah,[extended_code]
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
	mov	[base_code],al
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
	jne	invalid_operand
	call	get_word_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	dx,ax
	mov	al,[base_code]
	stosb
	mov	ax,dx
	stosw
	jmp	instruction_assembled
      simple_ret:
	mov	al,[base_code]
	inc	al
	stosb
	jmp	instruction_assembled
lea_instruction:
	mov	[base_code],8Dh
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	mov	al,[operand_size]
	push ax
	mov	[operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop ax
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
	mov	[extended_code],al
	mov	[base_code],0Fh
	jmp	ls_code_ok
      les_instruction:
	mov	[base_code],0C4h
	jmp	ls_code_ok
      lds_instruction:
	mov	[base_code],0C5h
      ls_code_ok:
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	add	[operand_size],2
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,4
	je	ls_16bit
	cmp	al,6
	je	ls_32bit
	jmp	invalid_operand_size
      ls_16bit:
	call	operand_16bit_prefix
	call	store_instruction
	cmp	[operand_size],0
	je	instruction_assembled
	cmp	[operand_size],4
	jne	invalid_operand_size
	jmp	instruction_assembled
      ls_32bit:
	call	operand_32bit_prefix
	call	store_instruction
	cmp	[operand_size],0
	je	instruction_assembled
	cmp	[operand_size],6
	jne	invalid_operand_size
	jmp	instruction_assembled
enter_instruction:
	lodsb
	call	get_size_operator
	cmp	ah,2
	je	enter_imm16_size_ok
	or	ah,ah
	jnz	invalid_operand_size
      enter_imm16_size_ok:
	cmp	al,'('
	jne	invalid_operand
	call	get_word_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	push ax
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	ah,1
	je	enter_imm8_size_ok
	or	ah,ah
	jnz	invalid_operand_size
      enter_imm8_size_ok:
	cmp	al,'('
	jne	invalid_operand
	call	get_byte_value
	mov	dl,al
	pop bx
	mov	al,0C8h
	stosb
	mov	ax,bx
	stosw
	mov	al,dl
	stosb
	jmp	instruction_assembled
sh_instruction:
	mov	[postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	sh_reg
	cmp	al,'['
	jne	invalid_operand
      sh_mem:
	call	get_address
	push edx
	push bx
	push cx
	mov	al,[operand_size]
	push ax
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	sh_mem_imm
	cmp	al,10h
	jne	invalid_operand
      sh_mem_reg:
	lodsb
	cmp	al,11h
	jne	invalid_operand
	pop ax
	pop cx
	pop bx
	pop edx
	cmp	al,1
	je	sh_mem_cl_8bit
	cmp	al,2
	je	sh_mem_cl_16bit
	cmp	al,4
	je	sh_mem_cl_32bit
	or	ah,ah
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      sh_mem_cl_8bit:
	mov	[base_code],0D2h
	call	store_instruction
	jmp	instruction_assembled
      sh_mem_cl_16bit:
	mov	[base_code],0D3h
	call	operand_16bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      sh_mem_cl_32bit:
	mov	[base_code],0D3h
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      sh_mem_imm:
	mov	al,[operand_size]
	or	al,al
	jz	sh_mem_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      sh_mem_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop ax
	pop cx
	pop bx
	pop edx
	cmp	al,1
	je	sh_mem_imm_8bit
	cmp	al,2
	je	sh_mem_imm_16bit
	cmp	al,4
	je	sh_mem_imm_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      sh_mem_imm_8bit:
	cmp	byte [value],1
	je	sh_mem_1_8bit
	mov	[base_code],0C0h
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      sh_mem_1_8bit:
	mov	[base_code],0D0h
	call	store_instruction
	jmp	instruction_assembled
      sh_mem_imm_16bit:
	cmp	byte [value],1
	je	sh_mem_1_16bit
	mov	[base_code],0C1h
	call	operand_16bit_prefix
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      sh_mem_1_16bit:
	mov	[base_code],0D1h
	call	operand_16bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      sh_mem_imm_32bit:
	cmp	byte [value],1
	je	sh_mem_1_32bit
	mov	[base_code],0C1h
	call	operand_32bit_prefix
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      sh_mem_1_32bit:
	mov	[base_code],0D1h
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      sh_reg:
	lodsb
	call	convert_register
	shl	[postbyte_register],3
	or	al,11000000b
	or	[postbyte_register],al
	mov	al,ah
	push ax
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	sh_reg_imm
	cmp	al,10h
	jne	invalid_operand
      sh_reg_reg:
	lodsb
	cmp	al,11h
	jne	invalid_operand
	pop ax
	mov	bl,[postbyte_register]
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
	mov	al,[operand_size]
	or	al,al
	jz	sh_reg_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      sh_reg_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop ax
	mov	bl,[postbyte_register]
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
	mov	[base_code],0Fh
	mov	[extended_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	shd_reg
	cmp	al,'['
	jne	invalid_operand
      shd_mem:
	call	get_address
	push edx
	push bx
	push cx
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	xor	al,al
	xchg	al,[operand_size]
	push ax
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	shd_mem_reg_imm
	cmp	al,10h
	jne	invalid_operand
	lodsb
	cmp	al,11h
	jne	invalid_operand
	pop ax
	pop cx
	pop bx
	pop edx
	cmp	al,2
	je	shd_mem_reg_cl_16bit
	cmp	al,4
	je	shd_mem_reg_cl_32bit
	jmp	invalid_operand_size
      shd_mem_reg_cl_16bit:
	call	operand_16bit_prefix
	inc	[extended_code]
	call	store_instruction
	jmp	instruction_assembled
      shd_mem_reg_cl_32bit:
	call	operand_32bit_prefix
	inc	[extended_code]
	call	store_instruction
	jmp	instruction_assembled
      shd_mem_reg_imm:
	mov	al,[operand_size]
	or	al,al
	jz	shd_mem_reg_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      shd_mem_reg_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop ax
	pop cx
	pop bx
	pop edx
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
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	bl,[postbyte_register]
	shl	al,3
	or	bl,al
	or	bl,11000000b
	mov	al,ah
	push ax
	push bx
	lodsb
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,'('
	je	shd_reg_reg_imm
	cmp	al,10h
	jne	invalid_operand
	lodsb
	cmp	al,11h
	jne	invalid_operand
	pop bx
	pop ax
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
	mov	ah,[extended_code]
	inc	ah
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
      shd_reg_reg_imm:
	mov	al,[operand_size]
	or	al,al
	jz	shd_reg_reg_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      shd_reg_reg_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop bx
	pop ax
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
	mov	ah,[extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
movx_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	mov	al,ah
	cmp	al,2
	je	movx_16bit
	cmp	al,4
	je	movx_32bit
	jmp	invalid_operand_size
      movx_16bit:
	lodsb
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	movx_16bit_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	movx_16bit_mem_8bit
	or	al,al
	jnz	invalid_operand_size
      movx_16bit_mem_8bit:
	call	operand_16bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      movx_16bit_reg:
	lodsb
	call	convert_register
	mov	bl,[postbyte_register]
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	cmp	ah,1
	jne	invalid_operand_size
	call	operand_16bit_prefix
	mov	al,0Fh
	stosb
	mov	al,[extended_code]
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      movx_32bit:
	lodsb
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	movx_32bit_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	movx_32bit_mem_8bit
	cmp	al,2
	je	movx_32bit_mem_16bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      movx_32bit_mem_8bit:
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      movx_32bit_mem_16bit:
	inc	[extended_code]
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      movx_32bit_reg:
	lodsb
	call	convert_register
	mov	bl,[postbyte_register]
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
	mov	al,[extended_code]
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
      movx_32bit_reg_16bit:
	call	operand_32bit_prefix
	mov	al,0Fh
	stosb
	mov	al,[extended_code]
	inc	al
	stosb
	mov	al,bl
	stosb
	jmp	instruction_assembled
bt_instruction:
	mov	[postbyte_register],al
	shl	al,3
	add	al,83h
	mov	[extended_code],al
	mov	[base_code],0Fh
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	bt_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	push eax
	push bx
	push cx
	lodsb
	cmp	al,','
	jne	invalid_operand
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
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	pop cx
	pop bx
	pop edx
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
	xchg	al,[operand_size]
	push ax
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne	invalid_operand
	mov	al,[operand_size]
	or	al,al
	jz	bt_mem_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      bt_mem_imm_size_ok:
	mov	[extended_code],0BAh
	call	get_byte_value
	mov	byte [value],al
	pop ax
	cmp	al,2
	je	bt_mem_imm_16bit
	cmp	al,4
	je	bt_mem_imm_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
	jmp	bt_mem_imm_32bit
      bt_mem_imm_16bit:
	call	operand_16bit_prefix
	pop cx
	pop bx
	pop edx
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      bt_mem_imm_32bit:
	call	operand_32bit_prefix
	pop cx
	pop bx
	pop edx
	call	store_instruction
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
      bt_reg:
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
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
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	bl,[postbyte_register]
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
	mov	ah,[extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
      bt_reg_reg_32bit:
	call	operand_32bit_prefix
	mov	ah,[extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
      bt_reg_imm:
	xor	al,al
	xchg	al,[operand_size]
	push ax
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne	invalid_operand
	mov	al,[operand_size]
	or	al,al
	jz	bt_reg_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      bt_reg_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	pop ax
	cmp	al,2
	je	bt_reg_imm_16bit
	cmp	al,4
	je	bt_reg_imm_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
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
	or	al,[postbyte_register]
	mov	ah,[extended_code]
	sub	ah,83h
	or	al,ah
	stosb
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
bs_instruction:
	mov	[extended_code],al
	mov	[base_code],0Fh
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	je	bs_reg_reg
	cmp	al,'['
	jne	invalid_argument
	call	get_address
	mov	al,[operand_size]
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
	mov	bl,[postbyte_register]
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
	mov	ah,[extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled

pm_word_instruction:
	mov	ah,al
	shr	ah,4
	and	al,111b
	mov	[base_code],0Fh
	mov	[extended_code],ah
	mov	[postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	pm_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,2
	je	.store
	or	al,al
	jnz	invalid_operand_size
      .store:
	call	store_instruction
	jmp	instruction_assembled
      pm_reg:
	lodsb
	call	convert_register
	cmp	ah,2
	jne	invalid_operand_size
	mov	bl,al
	mov	al,0Fh
	mov	ah,[extended_code]
	stosw
	mov	al,[postbyte_register]
	shl	al,3
	or	al,bl
	or	al,11000000b
	stosb
	jmp	instruction_assembled
pm_pword_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],1
	mov	[postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,6
	je	.store
	or	al,al
	jnz	invalid_operand_size
      .store:
	call	store_instruction
	jmp	instruction_assembled

imul_instruction:
	mov	[base_code],0F6h
	mov	[postbyte_register],5
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	imul_reg
	cmp	al,'['
	jne	invalid_operand
      imul_mem:
	call	get_address
	mov	al,[operand_size]
	cmp	al,1
	je	imul_mem_8bit
	cmp	al,2
	je	imul_mem_16bit
	cmp	al,4
	je	imul_mem_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      imul_mem_8bit:
	call	store_instruction
	jmp	instruction_assembled
      imul_mem_16bit:
	call	operand_16bit_prefix
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      imul_mem_32bit:
	call	operand_32bit_prefix
	inc	[base_code]
	call	store_instruction
	jmp	instruction_assembled
      imul_reg:
	lodsb
	call	convert_register
	cmp	byte [esi],','
	je	imul_reg_
	mov	bl,[postbyte_register]
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
	mov	[postbyte_register],al
	inc	esi
	cmp	byte [esi],'('
	je	imul_reg_imm
	cmp	byte [esi],11h
	jne	imul_reg__
	cmp	byte [esi+2],'('
	je	imul_reg_imm
      imul_reg__:
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	imul_reg_reg
	cmp	al,'['
	je	imul_reg_mem
	jne	invalid_operand
      imul_reg_mem:
	call	get_address
	push edx
	push bx
	push cx
	cmp	byte [esi],','
	je	imul_reg_mem_imm
	mov	al,[operand_size]
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
	pop cx
	pop bx
	pop edx
	mov	[base_code],0Fh
	mov	[extended_code],0AFh
	call	store_instruction
	jmp	instruction_assembled
      imul_reg_mem_imm:
	inc	esi
	xor	cl,cl
	xchg	cl,[operand_size]
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne	invalid_operand
	mov	al,[operand_size]
	mov	[operand_size],cl
	cmp	al,1
	je	imul_reg_mem_imm_8bit
	cmp	al,2
	je	imul_reg_mem_imm_16bit
	cmp	al,4
	je	imul_reg_mem_imm_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	cl,2
	je	imul_reg_mem_imm_16bit
	cmp	cl,4
	je	imul_reg_mem_imm_32bit
	jmp	invalid_operand_size
      imul_reg_mem_imm_8bit:
	call	get_byte_value
	mov	byte [value],al
	pop cx
	pop bx
	pop edx
	mov	[base_code],6Bh
	cmp	[operand_size],2
	je	imul_reg_mem_16bit_imm_8bit
	cmp	[operand_size],4
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
	pop cx
	pop bx
	pop edx
	mov	[base_code],69h
	cmp	[operand_size],2
	jne	invalid_operand_size
	call	operand_16bit_prefix
	call	store_instruction
	mov	ax,word [value]
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      imul_reg_mem_imm_32bit:
	call	get_dword_value
	mov	dword [value],eax
	pop cx
	pop bx
	pop edx
	mov	[base_code],69h
	cmp	[operand_size],4
	jne	invalid_operand_size
	call	operand_32bit_prefix
	call	store_instruction
	mov	eax,dword [value]
	call	mark_relocation
	stosd
	jmp	instruction_assembled
      imul_reg_imm:
	mov	dl,[postbyte_register]
	mov	bl,dl
	dec	esi
	jmp	imul_reg_reg_imm
      imul_reg_reg:
	lodsb
	call	convert_register
	mov	bl,[postbyte_register]
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
	xchg	cl,[operand_size]
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne	invalid_operand
	mov	al,[operand_size]
	mov	[operand_size],cl
	cmp	al,1
	je	imul_reg_reg_imm_8bit
	cmp	al,2
	je	imul_reg_reg_imm_16bit
	cmp	al,4
	je	imul_reg_reg_imm_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	cl,2
	je	imul_reg_reg_imm_16bit
	cmp	cl,4
	je	imul_reg_reg_imm_32bit
	jmp	invalid_operand_size
      imul_reg_reg_imm_8bit:
	push bx
	push dx
	call	get_byte_value
	pop dx
	pop bx
      imul_reg_reg_imm_8bit_store:
	mov	byte [value],al
	cmp	[operand_size],2
	je	imul_reg_reg_16bit_imm_8bit
	cmp	[operand_size],4
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
	push bx
	push dx
	call	get_word_value
	pop dx
	pop bx
	cmp	[value_type],0
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
	push bx
	push dx
	call	get_dword_value
	pop dx
	pop bx
	cmp	[value_type],0
	jne	imul_reg_reg_imm_32bit_forced
	cmp	ax,-80h
	jl	imul_reg_reg_imm_32bit_forced
	cmp	ax,80h
	jl	imul_reg_reg_imm_8bit_store
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
	jne	invalid_operand
	lodsb
	call	convert_register
	or	al,al
	jnz	invalid_operand
	lodsb
	cmp	al,','
	jne	invalid_operand
	mov	al,ah
	push ax
	mov	[operand_size],0
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
	jne	invalid_operand
	pop ax
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
	mov	al,[operand_size]
	or	al,al
	jz	in_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      in_imm_size_ok:
	call	get_byte_value
	mov	dl,al
	pop ax
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
	jne	invalid_operand
	lodsb
	cmp	al,22h
	jne	invalid_operand
	lodsb
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	or	al,al
	jnz	invalid_operand
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
	mov	al,[operand_size]
	or	al,al
	jz	out_imm_size_ok
	cmp	al,1
	jne	invalid_operand_size
      out_imm_size_ok:
	call	get_byte_value
	mov	byte [value],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	or	al,al
	jnz	invalid_operand
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
	mov	[extended_code],al
	mov	[base_code],0Fh
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	lar_reg_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
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
	mov	bl,[postbyte_register]
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
	mov	ah,[extended_code]
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
invlpg_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],1
	mov	[postbyte_register],7
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	call	store_instruction
	jmp	instruction_assembled
basic_486_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	basic_486_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	push edx
	push bx
	push cx
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	pop cx
	pop bx
	pop edx
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
	inc	[extended_code]
	call	store_instruction
	jmp	instruction_assembled
      basic_486_mem_reg_32bit:
	call	operand_32bit_prefix
	inc	[extended_code]
	call	store_instruction
	jmp	instruction_assembled
      basic_486_reg:
	lodsb
	call	convert_register
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	bl,[postbyte_register]
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
	inc	[extended_code]
	jmp	basic_486_reg_reg_8bit
      basic_486_reg_reg_16bit:
	call	operand_16bit_prefix
	inc	[extended_code]
      basic_486_reg_reg_8bit:
	mov	al,0Fh
	mov	ah,[extended_code]
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
bswap_instruction:
	lodsb
	call	get_size_operator
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	mov	ah,al
	add	ah,0C8h
	cmp	ah,4
	jne	invalid_operand_size
	call	operand_32bit_prefix
	mov	al,0Fh
	stosw
	jmp	instruction_assembled
cmpxchg8b_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],0C7h
	mov	[postbyte_register],1
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,8
	je	.store
	or	al,al
	jnz	invalid_operand_size
      .store:
	call	store_instruction
	jmp	instruction_assembled

conditional_jump:
	mov	[base_code],al
	lodsb
	call	get_jump_operator
	cmp	[jump_type],2
	je	invalid_operand
	call	get_size_operator
	cmp	al,'('
	jne	invalid_operand
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],1
	je	invalid_use_of_symbol
	sub	eax,edi
	add	eax,[org_start]
	sub	eax,2
	cmp	[org_sib],0
	jne	invalid_use_of_symbol
	mov	bl,[operand_size]
	cmp	bl,1
	je	conditional_jump_8bit
	cmp	bl,2
	je	conditional_jump_16bit
	cmp	bl,4
	je	conditional_jump_32bit
	or	bl,bl
	jnz	invalid_operand_size
	cmp	eax,80h
	jb	conditional_jump_8bit
	cmp	eax,-80h
	jae	conditional_jump_8bit
	cmp	[code_type],16
	je	conditional_jump_16bit
      conditional_jump_32bit:
	sub	eax,4
	mov	edx,eax
	mov	ecx,edi
	call	operand_32bit_prefix
	sub	edx,edi
	add	edx,ecx
	mov	ah,[base_code]
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
	mov	ah,[base_code]
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
	mov	al,[base_code]
	stosw
	cmp	edx,80h
	jge	jump_out_of_range
	cmp	edx,-80h
	jl	jump_out_of_range
	jmp	instruction_assembled
      jump_out_of_range:
	cmp	[error_line],0
	jne	instruction_assembled
	mov	eax,[current_line]
	mov	[error_line],eax
	mov	[error],relative_jump_out_of_range
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
	mov	[base_code],al
	lodsb
	call	get_jump_operator
	cmp	[jump_type],2
	je	invalid_operand
	call	get_size_operator
	cmp	al,'('
	jne	invalid_operand
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],1
	je	invalid_use_of_symbol
	sub	eax,edi
	add	eax,[org_start]
	cmp	[org_sib],0
	jne	invalid_use_of_symbol
	mov	bl,[operand_size]
	cmp	bl,1
	je	loop_8bit
	or	bl,bl
	jnz	invalid_operand_size
      loop_8bit:
	sub	eax,2
	mov	edx,eax
	mov	al,[base_code]
	stosb
	mov	eax,edx
	stosb
	cmp	eax,80h
	jge	jump_out_of_range
	cmp	eax,-80h
	jl	jump_out_of_range
	jmp	instruction_assembled
call_instruction:
	mov	[postbyte_register],10b
	mov	[base_code],0E8h
	mov	[extended_code],9Ah
	jmp	process_jmp
jmp_instruction:
	mov	[postbyte_register],100b
	mov	[base_code],0E9h
	mov	[extended_code],0EAh
      process_jmp:
	lodsb
	call	get_jump_operator
	call	get_size_operator
	cmp	al,10h
	je	jmp_reg
	cmp	al,'('
	je	jmp_imm
	cmp	al,'['
	jne	invalid_operand
      jmp_mem:
	call	get_address
	mov	[base_code],0FFh
	mov	edx,eax
	mov	al,[operand_size]
	or	al,al
	jz	jmp_mem_size_not_specified
	cmp	al,2
	je	jmp_mem_16bit
	cmp	al,4
	je	jmp_mem_32bit
	cmp	al,6
	je	jmp_mem_48bit
	jmp	invalid_operand_size
      jmp_mem_size_not_specified:
	cmp	[jump_type],2
	je	jmp_mem_far
	cmp	[jump_type],1
	je	jmp_mem_near
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      jmp_mem_near:
	cmp	[code_type],16
	je	jmp_mem_16bit
	jmp	jmp_mem_near_32bit
      jmp_mem_far:
	cmp	[code_type],16
	je	jmp_mem_far_32bit
      jmp_mem_48bit:
	cmp	[jump_type],1
	je	invalid_operand_size
	call	operand_32bit_prefix
	inc	[postbyte_register]
	call	store_instruction
	jmp	instruction_assembled
      jmp_mem_32bit:
	cmp	[jump_type],2
	je	jmp_mem_far_32bit
	cmp	[jump_type],1
	je	jmp_mem_near_32bit
	cmp	[code_type],16
	je	jmp_mem_far_32bit
      jmp_mem_near_32bit:
	call	operand_32bit_prefix
	call	store_instruction
	jmp	instruction_assembled
      jmp_mem_far_32bit:
	call	operand_16bit_prefix
	inc	[postbyte_register]
	call	store_instruction
	jmp	instruction_assembled
      jmp_mem_16bit:
	cmp	[jump_type],2
	je	invalid_operand_size
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
	cmp	[jump_type],2
	je	jmp_reg_far32bit
	cmp	[jump_type],1
	je	jmp_reg_near32bit
	cmp	[code_type],16
	je	jmp_reg_far32bit
      jmp_reg_near32bit:
	call	operand_32bit_prefix
	mov	al,[postbyte_register]
	shl	al,3
	or	bl,al
	mov	ah,bl
	mov	al,0FFh
	stosw
	jmp	instruction_assembled
      jmp_reg_far32bit:
	call	operand_32bit_prefix
	mov	al,[postbyte_register]
	inc	al
	shl	al,3
	or	bl,al
	mov	ah,bl
	mov	al,0FFh
	stosw
	jmp	instruction_assembled
      jmp_reg_16bit:
	cmp	[jump_type],2
	je	invalid_operand_size
	call	operand_16bit_prefix
	mov	al,[postbyte_register]
	shl	al,3
	or	bl,al
	mov	ah,bl
	mov	al,0FFh
	stosw
	jmp	instruction_assembled
      jmp_imm:
	push esi
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	pop ebx
	cmp	byte [esi],':'
	je	jmp_far
	cmp	[value_type],1
	je	invalid_use_of_symbol
	cmp	[jump_type],2
	je	invalid_operand
	sub	eax,edi
	add	eax,[org_start]
	sub	eax,2
	cmp	[org_sib],0
	jne	invalid_use_of_symbol
	mov	bl,[operand_size]
	cmp	bl,1
	je	jmp_8bit
	cmp	bl,2
	je	jmp_16bit
	cmp	bl,4
	je	jmp_32bit
	or	bl,bl
	jnz	invalid_operand_size
	cmp	[base_code],0E9h
	jne	jmp_no8bit
	cmp	eax,80h
	jb	jmp_8bit
	cmp	eax,-80h
	jae	jmp_8bit
      jmp_no8bit:
	cmp	[code_type],32
	je	jmp_32bit
      jmp_16bit:
	dec	eax
	mov	edx,eax
	mov	ecx,edi
	call	operand_16bit_prefix
	sub	edx,edi
	add	edx,ecx
	mov	al,[base_code]
	stosb
	mov	eax,edx
	stosw
	cmp	eax,10000h
	jge	jump_out_of_range
	cmp	eax,-10000h
	jl	jump_out_of_range
	jmp	instruction_assembled
      jmp_32bit:
	sub	eax,3
	mov	edx,eax
	mov	ecx,edi
	call	operand_32bit_prefix
	sub	edx,edi
	add	edx,ecx
	mov	al,[base_code]
	stosb
	mov	eax,edx
	stosd
	jmp	instruction_assembled
      jmp_8bit:
	cmp	[base_code],0E9h
	jne	invalid_operand_size
	mov	edx,eax
	mov	ah,al
	mov	al,0EBh
	stosw
	cmp	edx,80h
	jge	jump_out_of_range
	cmp	edx,-80h
	jl	jump_out_of_range
	jmp	instruction_assembled
      jmp_far:
	cmp	[jump_type],1
	je	invalid_operand
	mov	esi,ebx
	call	get_word_value
	mov	dx,ax
	mov	bl,[operand_size]
	cmp	bl,4
	je	jmp_far_16bit
	cmp	bl,6
	je	jmp_far_32bit
	or	bl,bl
	jnz	invalid_operand_size
	cmp	[code_type],32
	je	jmp_far_32bit
      jmp_far_16bit:
	inc	esi
	lodsb
	cmp	al,'('
	jne	invalid_operand
	mov	al,[value_type]
	push ax
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_word_value
	mov	ebx,eax
	call	operand_16bit_prefix
	mov	al,[extended_code]
	stosb
	mov	ax,bx
	call	mark_relocation
	stosw
	pop ax
	mov	[value_type],al
	mov	ax,dx
	call	mark_relocation
	stosw
	jmp	instruction_assembled
      jmp_far_32bit:
	inc	esi
	lodsb
	cmp	al,'('
	jne	invalid_operand
	mov	al,[value_type]
	push ax
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	mov	ebx,eax
	call	operand_32bit_prefix
	mov	al,[extended_code]
	stosb
	mov	eax,ebx
	call	mark_relocation
	stosd
	pop ax
	mov	[value_type],al
	mov	ax,dx
	call	mark_relocation
	stosw
	jmp	instruction_assembled
ins_instruction:
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	cmp	bh,27h
	je	ins_16bit
	cmp	bh,47h
	jne	invalid_address
	call	address_32bit_prefix
	jmp	ins_store
      ins_16bit:
	call	address_16bit_prefix
      ins_store:
	cmp	[segment_register],1
	ja	invalid_address
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	cmp	al,22h
	jne	invalid_operand
	mov	al,6Ch
	cmp	[operand_size],1
	je	simple_instruction
	inc	al
	cmp	[operand_size],2
	je	simple_instruction_16bit
	cmp	[operand_size],4
	je	simple_instruction_32bit
	cmp	[operand_size],0
	je	operand_size_not_specified
	jmp	invalid_operand_size
outs_instruction:
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	cmp	al,22h
	jne	invalid_operand
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	cmp	bh,26h
	je	outs_16bit
	cmp	bh,46h
	jne	invalid_address
	call	address_32bit_prefix
	jmp	outs_store
      outs_16bit:
	call	address_16bit_prefix
      outs_store:
	cmp	[segment_register],4
	je	outs_segment_ok
	call	store_segment_prefix
      outs_segment_ok:
	mov	al,6Eh
	cmp	[operand_size],1
	je	simple_instruction
	inc	al
	cmp	[operand_size],2
	je	simple_instruction_16bit
	cmp	[operand_size],4
	je	simple_instruction_32bit
	cmp	[operand_size],0
	je	operand_size_not_specified
	jmp	invalid_operand_size
movs_instruction:
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	cmp	[segment_register],1
	ja	invalid_address
	push bx
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop dx
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	mov	al,dh
	mov	ah,bh
	shr	al,4
	shr	ah,4
	cmp	al,ah
	jne	address_sizes_do_not_agree
	and	bh,111b
	and	dh,111b
	cmp	bh,6
	jne	invalid_address
	cmp	dh,7
	jne	invalid_address
	cmp	al,2
	je	movs_16bit
	cmp	al,4
	jne	invalid_address
	call	address_32bit_prefix
	jmp	movs_store
      movs_16bit:
	call	address_16bit_prefix
      movs_store:
	cmp	[segment_register],4
	je	movs_segment_ok
	call	store_segment_prefix
      movs_segment_ok:
	mov	al,0A4h
	mov	bl,[operand_size]
	cmp	bl,1
	je	simple_instruction
	inc	al
	cmp	bl,2
	je	simple_instruction_16bit
	cmp	bl,4
	je	simple_instruction_32bit
	or	bl,bl
	jz	operand_size_not_specified
	jmp	invalid_operand_size
lods_instruction:
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	cmp	bh,26h
	je	lods_16bit
	cmp	bh,46h
	jne	invalid_address
	call	address_32bit_prefix
	jmp	lods_store
      lods_16bit:
	call	address_16bit_prefix
      lods_store:
	cmp	[segment_register],4
	je	lods_segment_ok
	call	store_segment_prefix
      lods_segment_ok:
	mov	al,0ACh
	cmp	[operand_size],1
	je	simple_instruction
	inc	al
	cmp	[operand_size],2
	je	simple_instruction_16bit
	cmp	[operand_size],4
	je	simple_instruction_32bit
	cmp	[operand_size],0
	je	operand_size_not_specified
	jmp	invalid_operand_size
stos_instruction:
	mov	[base_code],al
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	cmp	bh,27h
	je	stos_16bit
	cmp	bh,47h
	jne	invalid_address
	call	address_32bit_prefix
	jmp	stos_store
      stos_16bit:
	call	address_16bit_prefix
      stos_store:
	cmp	[segment_register],1
	ja	invalid_address
	mov	al,[base_code]
	cmp	[operand_size],1
	je	simple_instruction
	inc	al
	cmp	[operand_size],2
	je	simple_instruction_16bit
	cmp	[operand_size],4
	je	simple_instruction_32bit
	cmp	[operand_size],0
	je	operand_size_not_specified
	jmp	invalid_operand_size
cmps_instruction:
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	mov	al,[segment_register]
	push ax
	push bx
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	pop dx
	pop ax
	cmp	[segment_register],1
	ja	invalid_address
	mov	[segment_register],al
	mov	al,dh
	mov	ah,bh
	shr	al,4
	shr	ah,4
	cmp	al,ah
	jne	address_sizes_do_not_agree
	and	bh,111b
	and	dh,111b
	cmp	bh,7
	jne	invalid_address
	cmp	dh,6
	jne	invalid_address
	cmp	al,2
	je	cmps_16bit
	cmp	al,4
	jne	invalid_address
	call	address_32bit_prefix
	jmp	cmps_store
      cmps_16bit:
	call	address_16bit_prefix
      cmps_store:
	cmp	[segment_register],4
	je	cmps_segment_ok
	call	store_segment_prefix
      cmps_segment_ok:
	mov	al,0A6h
	mov	bl,[operand_size]
	cmp	bl,1
	je	simple_instruction
	inc	al
	cmp	bl,2
	je	simple_instruction_16bit
	cmp	bl,4
	je	simple_instruction_32bit
	or	bl,bl
	jz	operand_size_not_specified
	jmp	invalid_operand_size
xlat_instruction:
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	or	eax,eax
	jnz	invalid_address
	or	bl,ch
	jnz	invalid_address
	cmp	bh,23h
	je	xlat_16bit
	cmp	bh,43h
	jne	invalid_address
	call	address_32bit_prefix
	jmp	xlat_store
      xlat_16bit:
	call	address_16bit_prefix
      xlat_store:
	call	store_segment_prefix_if_necessary
	mov	al,0D7h
	cmp	[operand_size],1
	jbe	simple_instruction
	jmp	invalid_operand_size

basic_fpu_instruction:
	mov	[postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	basic_fpu_streg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,4
	je	basic_fpu_mem_32bit
	cmp	al,8
	je	basic_fpu_mem_64bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      basic_fpu_mem_32bit:
	mov	[base_code],0D8h
	call	store_instruction
	jmp	instruction_assembled
      basic_fpu_mem_64bit:
	mov	[base_code],0DCh
	call	store_instruction
	jmp	instruction_assembled
      basic_fpu_streg:
	cmp	[operand_size],0
	jne	invalid_operand
	lodsb
	mov	ah,al
	shr	ah,4
	cmp	ah,0Ah
	jne	invalid_operand
	and	al,111b
	mov	ah,[postbyte_register]
	cmp	ah,2
	je	basic_fpu_single_streg
	cmp	ah,3
	je	basic_fpu_single_streg
	or	al,al
	jz	basic_fpu_st0
	shl	ah,3
	or	al,ah
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	cmp	al,0A0h
	jne	invalid_operand
	mov	ah,[postbyte_register]
	or	ah,11000000b
	mov	al,0DCh
	stosw
	jmp	instruction_assembled
      basic_fpu_st0:
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	mov	ah,al
	shr	ah,4
	cmp	ah,0Ah
	jne	invalid_operand
	and	al,111b
	mov	ah,[postbyte_register]
	shl	ah,3
	or	ah,al
	or	ah,11000000b
	mov	al,0D8h
	stosw
	jmp	instruction_assembled
      basic_fpu_single_streg:
	shl	ah,3
	or	ah,al
	or	ah,11000000b
	mov	al,0D8h
	stosw
	jmp	instruction_assembled
simple_fpu_instruction:
	mov	ah,al
	or	ah,11000000b
	mov	al,0D9h
	stosw
	jmp	instruction_assembled
fi_instruction:
	mov	[postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,2
	je	fi_mem_16bit
	cmp	al,4
	je	fi_mem_32bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      fi_mem_32bit:
	mov	[base_code],0DAh
	call	store_instruction
	jmp	instruction_assembled
      fi_mem_16bit:
	mov	[base_code],0DEh
	call	store_instruction
	jmp	instruction_assembled
fld_instruction:
	mov	[postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	fld_streg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,4
	je	fld_mem_32bit
	cmp	al,8
	je	fld_mem_64bit
	cmp	al,10
	je	fld_mem_80bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      fld_mem_32bit:
	mov	[base_code],0D9h
	call	store_instruction
	jmp	instruction_assembled
      fld_mem_64bit:
	mov	[base_code],0DDh
	call	store_instruction
	jmp	instruction_assembled
      fld_mem_80bit:
	mov	al,[postbyte_register]
	cmp	al,0
	je	.store
	dec	[postbyte_register]
	cmp	al,3
	je	.store
	jmp	invalid_operand_size
      .store:
	add	[postbyte_register],5
	mov	[base_code],0DBh
	call	store_instruction
	jmp	instruction_assembled
      fld_streg:
	cmp	[operand_size],0
	jne	invalid_operand
	lodsb
	mov	ah,al
	shr	ah,4
	cmp	ah,0Ah
	jne	invalid_operand
	and	al,111b
	mov	ah,[postbyte_register]
	shl	ah,3
	or	ah,al
	or	ah,11000000b
	cmp	[postbyte_register],2
	jae	fst_streg
	mov	al,0D9h
	stosw
	jmp	instruction_assembled
      fst_streg:
	mov	al,0DDh
	stosw
	jmp	instruction_assembled
fild_instruction:
	mov	[postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	cmp	al,2
	je	fild_mem_16bit
	cmp	al,4
	je	fild_mem_32bit
	cmp	al,8
	je	fild_mem_64bit
	or	al,al
	jnz	invalid_operand_size
	cmp	[current_pass],0
	jne	operand_size_not_specified
	cmp	[next_pass_needed],0
	je	operand_size_not_specified
      fild_mem_32bit:
	mov	[base_code],0DBh
	call	store_instruction
	jmp	instruction_assembled
      fild_mem_16bit:
	mov	[base_code],0DFh
	call	store_instruction
	jmp	instruction_assembled
      fild_mem_64bit:
	mov	al,[postbyte_register]
	cmp	al,0
	je	.store
	dec	[postbyte_register]
	cmp	al,3
	je	.store
	jmp	invalid_operand_size
      .store:
	add	[postbyte_register],5
	mov	[base_code],0DFh
	call	store_instruction
	jmp	instruction_assembled
fbld_instruction:
	mov	[postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	or	al,al
	jz	fbld_mem_80bit
	cmp	al,10
	je	fbld_mem_80bit
	jmp	invalid_operand_size
      fbld_mem_80bit:
	mov	[base_code],0DFh
	call	store_instruction
	jmp	instruction_assembled
faddp_instruction:
	mov	[postbyte_register],al
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	mov	ah,al
	shr	ah,4
	cmp	ah,0Ah
	jne	invalid_operand
	and	al,111b
	mov	ah,[postbyte_register]
	shl	ah,3
	or	al,ah
	mov	[postbyte_register],al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	cmp	al,0A0h
	jne	invalid_operand
	mov	ah,[postbyte_register]
	or	ah,11000000b
	mov	al,0DEh
	stosw
	jmp	instruction_assembled
fcompp_instruction:
	mov	ax,0D9DEh
	stosw
	jmp	instruction_assembled
fxch_instruction:
	mov	[base_code],0D9h
	mov	[postbyte_register],1
	jmp	fpu_streg
ffree_instruction:
	mov	[base_code],0DDh
	mov	[postbyte_register],al
      fpu_streg:
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	mov	ah,al
	shr	ah,4
	cmp	ah,0Ah
	jne	invalid_operand
	and	al,111b
	mov	ah,[postbyte_register]
	shl	ah,3
	or	ah,al
	or	ah,11000000b
	mov	al,[base_code]
	stosw
	jmp	instruction_assembled
fldenv_instruction:
	mov	[base_code],0D9h
	jmp	fpu_mem
fsave_instruction:
	mov	[base_code],0DDh
      fpu_mem:
	mov	[postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	cmp	[operand_size],0
	jne	invalid_operand_size
	call	store_instruction
	jmp	instruction_assembled
fldcw_instruction:
	mov	[postbyte_register],al
	mov	[base_code],0D9h
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	or	al,al
	jz	fldcw_mem_16bit
	cmp	al,2
	je	fldcw_mem_16bit
	jmp	invalid_operand_size
      fldcw_mem_16bit:
	call	store_instruction
	jmp	instruction_assembled
fstsw_instruction:
	mov	al,9Bh
	stosb
fnstsw_instruction:
	mov	[base_code],0DDh
	mov	[postbyte_register],7
	lodsb
	call	get_size_operator
	cmp	al,10h
	je	fstsw_reg
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	mov	al,[operand_size]
	or	al,al
	jz	fstsw_mem_16bit
	cmp	al,2
	je	fstsw_mem_16bit
	jmp	invalid_operand_size
      fstsw_mem_16bit:
	call	store_instruction
	jmp	instruction_assembled
      fstsw_reg:
	lodsb
	cmp	al,20h
	jne	invalid_operand
	mov	ax,0E0DFh
	stosw
	jmp	instruction_assembled
finit_instruction:
	mov	byte [edi],9Bh
	inc	edi
fninit_instruction:
	mov	ah,al
	mov	al,0DBh
	stosw
	jmp	instruction_assembled
fcomi_instruction:
	mov	dh,0DBh
	jmp	fcomi_streg
fcomip_instruction:
	mov	dh,0DFh
      fcomi_streg:
	mov	dl,al
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	mov	ah,al
	shr	al,4
	cmp	al,0Ah
	jne	invalid_operand
	and	ah,111b
	add	ah,dl
	mov	al,dh
	stosw
	jmp	instruction_assembled

movd_instruction:
	lodsb
	cmp	al,10h
	je	movd_reg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	test	[operand_size],~4
	jnz	invalid_operand_size
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	call	make_mmx_prefix
	mov	[postbyte_register],al
	mov	[base_code],0Fh
	mov	[extended_code],7Eh
	call	store_mmx_instruction
	jmp	instruction_assembled
      movd_reg:
	lodsb
	cmp	al,80h
	ja	movd_mmreg
	call	convert_register
	cmp	ah,4
	jne	invalid_operand_size
	mov	[operand_size],0
	push ax
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	call	make_mmx_prefix
	pop bx
	shl	al,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	ax,7E0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
      movd_mmreg:
	call	convert_mmx_register
	call	make_mmx_prefix
	push ax
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	je	movd_mmreg_reg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop ax
	mov	[postbyte_register],al
	test	[operand_size],~4
	jnz	invalid_operand_size
	mov	[base_code],0Fh
	mov	[extended_code],6Eh
	call	store_mmx_instruction
	jmp	instruction_assembled
      movd_mmreg_reg:
	lodsb
	call	convert_register
	cmp	ah,4
	jne	invalid_operand_size
	pop bx
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	ax,6E0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
      make_mmx_prefix:
	mov	[mmx_prefix],0
	cmp	[operand_size],16
	jne	no_mmx_prefix
	mov	[mmx_prefix],66h
      no_mmx_prefix:
	ret
movq_instruction:
	lodsb
	cmp	al,10h
	je	movq_mmreg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	test	[operand_size],~8
	jnz	invalid_operand_size
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	mov	[postbyte_register],al
	mov	[base_code],0Fh
	cmp	ah,16
	je	movq_mem_xmmreg
	mov	[extended_code],7Fh
	call	store_instruction
	jmp	instruction_assembled
     movq_mem_xmmreg:
	mov	[extended_code],0D6h
	mov	[mmx_prefix],66h
	call	store_mmx_instruction
	jmp	instruction_assembled
     movq_mmreg:
	lodsb
	call	convert_mmx_register
	push ax
	lodsb
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lodsb
	cmp	al,10h
	je	movq_mmreg_mmreg
	call	get_size_operator
	call	get_address
	test	[operand_size],~8
	jnz	invalid_operand_size
	pop ax
	mov	[postbyte_register],al
	mov	[base_code],0Fh
	cmp	[operand_size],16
	je	movq_xmmreg_mem
	mov	[extended_code],6Fh
	call	store_instruction
	jmp	instruction_assembled
      movq_xmmreg_mem:
	mov	[extended_code],7Eh
	mov	[mmx_prefix],0F3h
	call	store_instruction
	jmp	instruction_assembled
      movq_mmreg_mmreg:
	pop bx
	lodsb
	call	convert_mmx_register
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	cmp	ah,16
	je	movq_xmmreg_xmmreg
	mov	ax,6F0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
      movq_xmmreg_xmmreg:
	mov	ax,0FF3h
	stosw
	mov	al,07Eh
	mov	ah,bl
	stosw
	jmp	instruction_assembled
movdq_instruction:
	mov	[mmx_prefix],al
	lodsb
	cmp	al,10h
	je	movdq_mmreg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	mov	[postbyte_register],al
	mov	[base_code],0Fh
	mov	[extended_code],7Fh
	call	store_mmx_instruction
	jmp	instruction_assembled
      movdq_mmreg:
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	push ax
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	je	movdq_mmreg_mmreg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop ax
	mov	[postbyte_register],al
	mov	[base_code],0Fh
	mov	[extended_code],6Fh
	call	store_mmx_instruction
	jmp	instruction_assembled
      movdq_mmreg_mmreg:
	pop bx
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	ax,6F0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
movq2dq_instruction:
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	mov	bl,al
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,8
	jne	invalid_operand_size
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	mov	ax,0FF3h
	stosw
	mov	al,0D6h
	mov	ah,bl
	stosw
	jmp	instruction_assembled
movdq2q_instruction:
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,8
	jne	invalid_operand_size
	mov	bl,al
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	mov	ax,0FF2h
	stosw
	mov	al,0D6h
	mov	ah,bl
	stosw
	jmp	instruction_assembled

mmx_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	call	make_mmx_prefix
	push ax
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	je	mmx_mmreg_mmreg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
      mmx_mmreg_mem:
	call	get_address
	pop ax
	mov	[postbyte_register],al
	call	store_mmx_instruction
	jmp	instruction_assembled
      mmx_mmreg_mmreg:
	lodsb
	call	convert_mmx_register
	pop bx
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	ah,[extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
mmx_ps_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	call	make_mmx_prefix
	push ax
	lodsb
	cmp	al,','
	jne	invalid_operand
	mov	[operand_size],0
	lodsb
	cmp	al,10h
	je	mmx_mmreg_mmreg
	call	get_size_operator
	cmp	al,'('
	je	mmx_ps_mmreg_imm8
	cmp	al,'['
	je	mmx_mmreg_mem
	jmp	invalid_operand
      mmx_ps_mmreg_imm8:
	call	get_byte_value
	mov	byte [value],al
	test	[operand_size],~1
	jnz	invalid_value
	mov	al,[extended_code]
	mov	ah,al
	shr	al,4
	and	ah,1111b
	add	ah,70h
	mov	[extended_code],ah
	sub	al,0Ch
	shl	al,1
	pop bx
	shl	al,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	ah,[extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	mov	al,byte [value]
	stosb
	jmp	instruction_assembled
pmovmskb_instruction:
	mov	[extended_code],al
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	cmp	ah,4
	jnz	invalid_operand_size
	mov	bl,al
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	call	make_mmx_prefix
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	al,0Fh
	mov	ah,[extended_code]
	stosw
	mov	al,bl
	stosb
	cmp	[extended_code],0C5h
	jne	instruction_assembled
      mmx_imm8:
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	test	ah,~1
	jnz	invalid_operand_size
	cmp	al,'('
	jne	invalid_operand
	call	get_byte_value
	stosb
	jmp	instruction_assembled
pinsrw_instruction:
	mov	[extended_code],al
	mov	[base_code],0Fh
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	call	make_mmx_prefix
	mov	[postbyte_register],al
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	je	pinsrw_mmreg_reg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	cmp	[operand_size],0
	je	pinsrw_store
	cmp	[operand_size],2
	jne	invalid_operand_size
      pinsrw_store:
	call	store_mmx_instruction
	jmp	mmx_imm8
      pinsrw_mmreg_reg:
	lodsb
	call	convert_register
	cmp	ah,4
	jne	invalid_operand_size
	mov	bl,[postbyte_register]
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	al,0Fh
	mov	ah,[extended_code]
	stosw
	mov	al,bl
	stosb
	jmp	mmx_imm8
pshufw_instruction:
	mov	[mmx_size],8
	mov	[mmx_prefix],al
	jmp	pshuf_instruction
pshufd_instruction:
	mov	[mmx_size],16
	mov	[mmx_prefix],al
      pshuf_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],70h
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,[mmx_size]
	jne	invalid_operand_size
	push ax
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	je	pshufw_mmreg_mmreg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop ax
	mov	[postbyte_register],al
	call	store_mmx_instruction
	jmp	mmx_imm8
      pshufw_mmreg_mmreg:
	lodsb
	call	convert_mmx_register
	pop bx
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	ah,[extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	mmx_imm8

sse_ps_instruction:
	mov	[mmx_size],16
	mov	[mmx_prefix],0
	jmp	sse_instruction
sse_pd_instruction:
	mov	[mmx_size],16
	mov	[mmx_prefix],66h
	jmp	sse_instruction
sse_ss_instruction:
	mov	[mmx_size],4
	mov	[mmx_prefix],0F3h
	jmp	sse_instruction
sse_sd_instruction:
	mov	[mmx_size],8
	mov	[mmx_prefix],0F2h
	jmp	sse_instruction
comiss_instruction:
	mov	[mmx_size],4
	mov	[mmx_prefix],0
	jmp	sse_instruction
comisd_instruction:
	mov	[mmx_size],8
	mov	[mmx_prefix],66h
	jmp	sse_instruction
cvtpd2dq_instruction:
	mov	[mmx_size],16
	mov	[mmx_prefix],0F2h
	jmp	sse_instruction
cvtdq2pd_instruction:
	mov	[mmx_size],16
	mov	[mmx_prefix],0F3h
sse_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lodsb
	cmp	al,10h
	jne	invalid_operand
      sse_xmmreg:
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
      sse_reg:
	push ax
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	je	sse_xmmreg_xmmreg
	call	get_size_operator
	call	get_address
	pop ax
	mov	[postbyte_register],al
	cmp	[operand_size],0
	je	sse_mem_size_ok
	mov	al,[mmx_size]
	cmp	[operand_size],al
	jne	invalid_operand_size
      sse_mem_size_ok:
	call	store_mmx_instruction
	cmp	[extended_code],0C6h
	je	mmx_imm8
	jmp	instruction_assembled
      sse_xmmreg_xmmreg:
	cmp	[extended_code],12h
	je	invalid_operand
	cmp	[extended_code],16h
	je	invalid_operand
      sse_xmmreg_xmmreg_ok:
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	pop bx
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	al,0Fh
	mov	ah,[extended_code]
	stosw
	mov	al,bl
	stosb
	cmp	[extended_code],0C6h
	jne	instruction_assembled
ps_dq_instruction:
	mov	bl,al
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	mov	ax,0F66h
	stosw
	mov	ah,bl
	mov	al,73h
	stosw
	jmp	mmx_imm8
movps_instruction:
	mov	[mmx_prefix],0
	jmp	sse_movp
movpd_instruction:
	mov	[mmx_prefix],66h
      sse_movp:
	mov	[base_code],0Fh
	mov	[extended_code],al
	mov	[mmx_size],16
	jmp	sse_mov_instruction
movss_instruction:
	mov	[mmx_size],4
	mov	[mmx_prefix],0F3h
	jmp	sse_movs
movsd_instruction:
	mov	al,0A5h
	mov	ah,[esi]
	or	ah,ah
	jz	simple_instruction_32bit
	cmp	ah,0Fh
	je	simple_instruction_32bit
	mov	al,66h
	stosb
	mov	[mmx_size],8
	mov	[mmx_prefix],0F2h
      sse_movs:
	mov	[base_code],0Fh
	mov	[extended_code],10h
	jmp	sse_mov_instruction
movlps_instruction:
	mov	[mmx_prefix],0
	jmp	sse_movlp
movlpd_instruction:
	mov	[mmx_prefix],66h
      sse_movlp:
	mov	[base_code],0Fh
	mov	[extended_code],al
	mov	[mmx_size],8
	jmp	sse_mov_instruction
sse_mov_instruction:
	lodsb
	cmp	al,10h
	je	sse_xmmreg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	inc	[extended_code]
	call	get_address
	cmp	[operand_size],0
	je	sse_mem_xmmreg
	mov	al,[mmx_size]
	cmp	[operand_size],al
	jne	invalid_operand_size
	mov	[operand_size],0
      sse_mem_xmmreg:
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	mov	[postbyte_register],al
	call	store_mmx_instruction
	jmp	instruction_assembled
movhlps_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	mov	[mmx_size],0
	mov	[mmx_prefix],0
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	push ax
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	je	sse_xmmreg_xmmreg_ok
	jmp	invalid_operand
movmskps_instruction:
	mov	[mmx_prefix],0
	jmp	sse_movmsk
movmskpd_instruction:
	mov	[mmx_prefix],66h
      sse_movmsk:
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	cmp	ah,4
	jne	invalid_operand_size
	mov	[operand_size],0
	mov	bl,al
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	ax,500Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
cmpps_instruction:
	mov	[mmx_prefix],0
	jmp	cmppx_instruction
cmppd_instruction:
	mov	[mmx_prefix],66h
      cmppx_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],0C2h
	mov	[mmx_size],16
	mov	[nextbyte],-1
	jmp	sse_cmp_instruction
cmp_ps_instruction:
	mov	[mmx_prefix],0
	jmp	cmp_px_instruction
cmp_pd_instruction:
	mov	[mmx_prefix],66h
      cmp_px_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],0C2h
	mov	[mmx_size],16
	mov	[nextbyte],al
	jmp	sse_cmp_instruction
cmpss_instruction:
	mov	[mmx_size],4
	mov	[mmx_prefix],0F3h
	jmp	cmpsx_instruction
cmpsd_instruction:
	mov	al,0A7h
	mov	ah,[esi]
	or	ah,ah
	jz	simple_instruction_32bit
	cmp	ah,0Fh
	je	simple_instruction_32bit
	mov	[mmx_size],8
	mov	[mmx_prefix],0F2h
      cmpsx_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],0C2h
	mov	[nextbyte],-1
	jmp	sse_cmp_instruction
cmp_ss_instruction:
	mov	[mmx_size],4
	mov	[mmx_prefix],0F3h
	jmp	cmp_sx_instruction
cmp_sd_instruction:
	mov	[mmx_size],8
	mov	[mmx_prefix],0F2h
      cmp_sx_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],0C2h
	mov	[nextbyte],al
sse_cmp_instruction:
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	push ax
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	je	sse_cmp_xmmreg_xmmreg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	mov	[operand_size],0
	call	get_address
	pop ax
	mov	[postbyte_register],al
	cmp	[operand_size],0
	je	sse_cmp_xmmreg_mem_store
	mov	al,[mmx_size]
	cmp	[operand_size],al
	jne	invalid_operand_size
      sse_cmp_xmmreg_mem_store:
	call	store_mmx_instruction
      sse_cmp_nextbyte:
	mov	al,[nextbyte]
	cmp	al,-1
	jne	nextbyte_ok
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	call	get_size_operator
	test	[operand_size],~1
	jnz	invalid_value
	cmp	al,'('
	jne	invalid_operand
	call	get_byte_value
	cmp	al,7
	ja	invalid_value
      nextbyte_ok:
	stosb
	jmp	instruction_assembled
      sse_cmp_xmmreg_xmmreg:
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	pop bx
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	ah,[extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	sse_cmp_nextbyte
cvtpi2ps_instruction:
	mov	[mmx_prefix],0
	jmp	cvtpi_instruction
cvtpi2pd_instruction:
	mov	[mmx_prefix],66h
      cvtpi_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	push ax
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	je	cvtpi_xmmreg_xmmreg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop ax
	mov	[postbyte_register],al
	cmp	[operand_size],0
	je	cvtpi_size_ok
	cmp	[operand_size],8
	jne	invalid_operand_size
      cvtpi_size_ok:
	call	store_mmx_instruction
	jmp	instruction_assembled
      cvtpi_xmmreg_xmmreg:
	lodsb
	call	convert_mmx_register
	cmp	ah,8
	jne	invalid_operand_size
	pop bx
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	ah,[extended_code]
	mov	al,0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
cvtsi2ss_instruction:
	mov	[mmx_prefix],0F3h
	jmp	cvtsi_instruction
cvtsi2sd_instruction:
	mov	[mmx_prefix],0F2h
      cvtsi_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,16
	jne	invalid_operand_size
	push ax
	mov	[operand_size],0
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	je	cvtsi_xmmreg_reg
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	pop ax
	mov	[postbyte_register],al
	cmp	[operand_size],0
	je	cvtsi_size_ok
	cmp	[operand_size],4
	jne	invalid_operand_size
      cvtsi_size_ok:
	call	store_mmx_instruction
	jmp	instruction_assembled
      cvtsi_xmmreg_reg:
	lodsb
	call	convert_register
	cmp	[operand_size],4
	jne	invalid_operand_size
	pop bx
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	al,0Fh
	mov	ah,[extended_code]
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
cvtps2pi_instruction:
	mov	[mmx_prefix],0
	jmp	cvtpd_instruction
cvtpd2pi_instruction:
	mov	[mmx_prefix],66h
      cvtpd_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	mov	[mmx_size],8
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,8
	jne	invalid_operand_size
	mov	[operand_size],0
	jmp	sse_reg
cvtss2si_instruction:
	mov	[mmx_prefix],0F3h
	jmp	cvt2si_instruction
cvtsd2si_instruction:
	mov	[mmx_prefix],0F2h
      cvt2si_instruction:
	mov	[extended_code],al
	mov	[base_code],0Fh
	mov	[mmx_size],4
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	cmp	ah,4
	jne	invalid_operand_size
	mov	[operand_size],0
	jmp	sse_reg

fxsave_instruction:
	mov	[extended_code],0AEh
      extended_mem:
	mov	[base_code],0Fh
	mov	[postbyte_register],al
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	cmp	ah,0
	je	fxsave_size_ok
	cmp	ah,4
	jne	invalid_operand_size
	mov	al,[postbyte_register]
	cmp	al,10b
	jb	invalid_operand_size
	cmp	al,11b
	ja	invalid_operand_size
      fxsave_size_ok:
	call	get_address
	call	store_instruction
	jmp	instruction_assembled
prefetch_instruction:
	mov	[extended_code],18h
	jmp	extended_mem
fence_instruction:
	mov	bl,al
	mov	ax,0AE0Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
pause_instruction:
	mov	ax,90F3h
	stosw
	jmp	instruction_assembled
maskmovq_instruction:
	mov	cl,8
	mov	[mmx_prefix],0
	jmp	maskmov_instruction
maskmovdqu_instruction:
	mov	cl,16
	mov	[mmx_prefix],66h
      maskmov_instruction:
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	cmp	ah,cl
	jne	invalid_operand_size
	push ax
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	pop bx
	shl	bl,3
	or	bl,al
	or	bl,11000000b
	call	store_mmx_prefix
	mov	ax,0F70Fh
	stosw
	mov	al,bl
	stosb
	jmp	instruction_assembled
movntq_instruction:
	mov	[extended_code],al
	mov	[mmx_prefix],0
	jmp	movnt_instruction
movntdq_instruction:
	mov	[extended_code],al
	mov	[mmx_prefix],66h
      movnt_instruction:
	mov	[base_code],0Fh
	cmp	[extended_code],0E7h
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_mmx_register
	jne	movnt_128bit
	cmp	[mmx_prefix],0
	jne	movnt_128bit
	cmp	ah,8
	je	movnt_store
	jmp	invalid_operand_size
      movnt_128bit:
	cmp	ah,16
	jne	invalid_operand_size
      movnt_store:
	mov	[postbyte_register],al
	call	store_mmx_instruction
	jmp	instruction_assembled
movnti_instruction:
	mov	[base_code],0Fh
	mov	[extended_code],al
	lodsb
	call	get_size_operator
	cmp	al,'['
	jne	invalid_operand
	call	get_address
	lodsb
	cmp	al,','
	jne	invalid_operand
	lodsb
	cmp	al,10h
	jne	invalid_operand
	lodsb
	call	convert_register
	cmp	ah,4
	jne	invalid_operand_size
	mov	[postbyte_register],al
	call	store_instruction
	jmp	instruction_assembled

convert_register:
	mov	ah,al
	shr	ah,4
	and	al,111b
	cmp	ah,4
	ja	invalid_operand
      match_register_size:
	cmp	ah,[operand_size]
	je	register_size_ok
	cmp	[operand_size],0
	jne	operand_sizes_do_not_match
	mov	[operand_size],ah
      register_size_ok:
	ret
convert_mmx_register:
	mov	ah,al
	shr	ah,4
	and	al,111b
	cmp	ah,9
	je	xmm_register
	ja	invalid_operand
	mov	ah,8
	jmp	match_register_size
      xmm_register:
	and	al,0Fh
	mov	ah,16
	jmp	match_register_size
get_size_operator:
	xor	ah,ah
	cmp	al,11h
	jne	operand_size_ok
	lodsw
	xchg	al,ah
	mov	[forced_size],1
	cmp	ah,[operand_size]
	je	forced_ok
	cmp	[operand_size],0
	jne	operand_sizes_do_not_match
	mov	[operand_size],ah
      forced_ok:
	ret
      operand_size_ok:
	cmp	al,'['
	jne	forced_ok
	mov	[forced_size],0
	ret
get_jump_operator:
	mov	[jump_type],0
	cmp	al,12h
	jne	jump_operator_ok
	lodsw
	mov	[jump_type],al
	mov	al,ah
      jump_operator_ok:
	ret
operand_16bit_prefix:
	cmp	[code_type],16
	je	size_prefix_ok
	mov	al,66h
	stosb
	ret
operand_32bit_prefix:
	cmp	[code_type],32
	je	size_prefix_ok
	mov	al,66h
	stosb
      size_prefix_ok:
	ret
store_segment_prefix_if_necessary:
	mov	al,[segment_register]
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
	mov	al,[segment_register]
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
store_mmx_prefix:
	mov	al,[mmx_prefix]
	or	al,al
	jz	mmx_prefix_ok
	stosb
      mmx_prefix_ok:
	ret
store_mmx_instruction:
	call	store_segment_prefix
	call	store_mmx_prefix
	jmp	store_instruction_main
store_instruction:
	call	store_segment_prefix_if_necessary
      store_instruction_main:
	or	bx,bx
	jz	address_immediate
	mov	al,bl
	or	al,bh
	and	al,11110000b
	cmp	al,40h
	je	postbyte_32bit
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
	jnz	address_sizes_do_not_agree
	or	edx,edx
	jz	address
	cmp	edx,80h
	jb	address_8bit_value
	cmp	edx,-80h
	jae	address_8bit_value
      address_16bit_value:
	or	al,10000000b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	mov	eax,edx
	stosw
	cmp	edx,10000h
	jge	value_out_of_range
	cmp	edx,-8000h
	jl	value_out_of_range
	ret
      address_8bit_value:
	or	al,01000000b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	mov	al,dl
	stosb
	cmp	edx,80h
	jge	value_out_of_range
	cmp	edx,-80h
	jl	value_out_of_range
	ret
      address:
	cmp	al,110b
	je	address_8bit_value
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	ret
      postbyte_32bit:
	call	address_32bit_prefix
	call	store_instruction_code
	cmp	bl,44h
	je	invalid_address
	or	cl,cl
	jz	only_base_register
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
	jz	only_index_register
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
	je	address_sizes_do_not_agree
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
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stosw
	jmp	store_address_32bit_value
      sib_address_8bit_value:
	or	al,01000000b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stosw
	mov	al,dl
	stosb
	cmp	edx,80h
	jge	value_out_of_range
	cmp	edx,-80h
	jl	value_out_of_range
	ret
      sib_address:
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stosw
	ret
      only_index_register:
	or	ah,101b
	and	bl,111b
	shl	bl,3
	or	ah,bl
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stosw
	test	ch,4
	jnz	store_address_32bit_value
	or	ch,ch
	jnz	invalid_address_size
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
	je	address_sizes_do_not_agree
	or	edx,edx
	jz	simple_address
	cmp	edx,80h
	jb	simple_address_8bit_value
	cmp	edx,-80h
	jae	simple_address_8bit_value
      simple_address_32bit_value:
	or	al,10000000b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	jmp	store_address_32bit_value
      simple_address_8bit_value:
	or	al,01000000b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	mov	al,dl
	stosb
	cmp	edx,80h
	jge	value_out_of_range
	cmp	edx,-80h
	jl	value_out_of_range
	ret
      simple_address:
	cmp	al,5
	je	simple_address_8bit_value
	mov	cl,[postbyte_register]
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
	jnz	invalid_address_size
	cmp	[code_type],16
	je	addressing_16bit
      address_immediate_32bit:
	call	address_32bit_prefix
	call	store_instruction_code
	mov	al,101b
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
      store_address_32bit_value:
	test	ch,80h
	jz	address_relocation_ok
	push word [value_type]
	mov	[value_type],2
	call	mark_relocation
	pop ax
	mov	[value_type],al
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
	mov	cl,[postbyte_register]
	shl	cl,3
	or	al,cl
	stosb
	mov	eax,edx
	stosw
	cmp	edx,10000h
	jge	value_out_of_range
	cmp	edx,-8000h
	jl	value_out_of_range
	ret
      store_instruction_code:
	mov	al,[base_code]
	stosb
	cmp	al,0Fh
	jne	instruction_code_ok
      store_extended_code:
	mov	al,[extended_code]
	stosb
      instruction_code_ok:
	ret
      address_16bit_prefix:
	cmp	[code_type],16
	je	instruction_prefix_ok
	mov	al,67h
	stosb
	ret
      address_32bit_prefix:
	cmp	[code_type],32
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
	cmp	edi,[code_start]
	jne	unexpected_instruction
	cmp	[output_format],0
	jne	unexpected_instruction
	lodsb
	cmp	al,18h
	jne	invalid_argument
	lodsb
	mov	[output_format],al
	cmp	al,2
	je	format_mz
	cmp	al,3
	je	format_pe
	jmp	instruction_assembled
entry_directive:
	bts	[format_flags],1
	jc	symbol_already_defined
	mov	al,[output_format]
	cmp	al,2
	je	mz_entry
	cmp	al,3
	je	pe_entry
	jmp	illegal_instruction
stack_directive:
	bts	[format_flags],2
	jc	symbol_already_defined
	mov	al,[output_format]
	cmp	al,2
	je	mz_stack
	cmp	al,3
	je	pe_stack
	jmp	illegal_instruction
heap_directive:
	bts	[format_flags],3
	jc	symbol_already_defined
	mov	al,[output_format]
	cmp	al,2
	je	mz_heap
	cmp	al,3
	je	pe_heap
	jmp	illegal_instruction
mark_relocation:
	cmp	[value_type],0
	je	relocation_ok
	cmp	[virtual_data],0
	jne	relocation_ok
	cmp	[output_format],2
	je	mark_mz_relocation
	cmp	[output_format],3
	je	mark_pe_relocation
      relocation_ok:
	ret

format_mz:
	mov	edx,[additional_memory]
	mov	[header_data],edx
	push edi
	mov	edi,edx
	mov	ecx,1Ch >> 2
	xor	eax,eax
	rep	stosd
	mov	[additional_memory],edi
	pop edi
	mov	word [edx+0Ch],0FFFFh
	mov	word [edx+10h],1000h
	mov	[code_type],16
	jmp	instruction_assembled
mark_mz_relocation:
	push eax
	push ebx
	inc	[number_of_relocations]
	mov	ebx,[additional_memory]
	mov	eax,edi
	sub	eax,[code_start]
	mov	[ebx],ax
	shr	eax,16
	shl	ax,12
	mov	[ebx+2],ax
	cmp	word [ebx],0FFFFh
	jne	mz_relocation_ok
	inc	word [ebx+2]
	sub	word [ebx],10h
      mz_relocation_ok:
	add	ebx,4
	cmp	ebx,[structures_buffer]
	jae	out_of_memory
	mov	[additional_memory],ebx
	pop ebx
	pop eax
	ret
segment_directive:
	cmp	[output_format],2
	jne	illegal_instruction
	cmp	[virtual_data],0
	jne	illegal_instruction
	lodsb
	cmp	al,2
	jne	invalid_argument
	lodsd
	inc	esi
	mov	ebx,eax
	mov	eax,edi
	sub	eax,[code_start]
	mov	ecx,0Fh
	add	eax,0Fh
	and	eax,1111b
	sub	ecx,eax
	mov	edx,edi
	xor	al,al
	rep	stosb
	mov	[org_start],edi
	mov	eax,edx
	call	undefined_data
	mov	eax,edi
	sub	eax,[code_start]
	shr	eax,4
	cmp	eax,10000h
	jae	value_out_of_range
	mov	cl,[current_pass]
	cmp	byte [ebx+8],0
	je	new_segment
	cmp	cl,[ebx+9]
	je	symbol_already_defined
	xchg	[ebx],eax
	xor	edx,edx
	xchg	[ebx+4],edx
	cmp	eax,[ebx]
	jne	changed_segment
	or	edx,edx
	jnz	changed_segment
	jmp	segment_ok
      changed_segment:
	or	[next_pass_needed],-1
	jmp	segment_ok
      new_segment:
	mov	byte [ebx+8],1
	mov	[ebx+9],cl
	mov	byte [ebx+10],0
	mov	byte [ebx+11],1
	mov	[ebx],eax
	mov	dword [ebx+4],0
      segment_ok:
	mov	al,16
	cmp	byte [esi],13h
	jne	segment_type_ok
	lodsb
	lodsb
      segment_type_ok:
	mov	[code_type],al
	jmp	instruction_assembled
mz_entry:
	lodsb
	cmp	al,'('
	jne	invalid_argument
	call	get_word_value
	cmp	[next_pass_needed],0
	je	check_initial_cs
	cmp	[current_pass],0
	je	initial_cs_ok
      check_initial_cs:
	cmp	[value_type],1
	jne	invalid_address
      initial_cs_ok:
	mov	edx,[header_data]
	mov	[edx+16h],ax
	lodsb
	cmp	al,':'
	jne	invalid_argument
	lodsb
	cmp	al,'('
	jne	invalid_argument
	ja	invalid_address
	call	get_word_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[header_data]
	mov	[edx+14h],ax
	jmp	instruction_assembled
mz_stack:
	lodsb
	cmp	al,'('
	jne	invalid_argument
	call	get_word_value
	cmp	byte [esi],':'
	je	stack_pointer
	cmp	ax,10h
	jb	invalid_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[header_data]
	mov	[edx+10h],ax
	jmp	instruction_assembled
      stack_pointer:
	cmp	[next_pass_needed],0
	je	check_initial_ss
	cmp	[current_pass],0
	je	initial_ss_ok
      check_initial_ss:
	cmp	[value_type],1
	jne	invalid_address
      initial_ss_ok:
	mov	edx,[header_data]
	mov	[edx+0Eh],ax
	lodsb
	cmp	al,':'
	jne	invalid_argument
	lodsb
	cmp	al,'('
	jne	invalid_argument
	call	get_word_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[header_data]
	mov	[edx+10h],ax
	bts	[format_flags],4
	jmp	instruction_assembled
mz_heap:
	cmp	[output_format],2
	jne	illegal_instruction
	lodsb
	call	get_size_operator
	cmp	ah,1
	je	invalid_value
	cmp	ah,2
	ja	invalid_value
	cmp	al,'('
	jne	invalid_argument
	call	get_word_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[header_data]
	mov	[edx+0Ch],ax
	jmp	instruction_assembled
write_mz_header:
	mov	edx,[header_data]
	bt	[format_flags],4
	jc	mz_stack_ok
	mov	eax,[real_code_size]
	dec	eax
	shr	eax,4
	inc	eax
	mov	[edx+0Eh],ax
	shl	eax,4
	movzx	ecx,word [edx+10h]
	add	eax,ecx
	mov	[real_code_size],eax
      mz_stack_ok:
	mov	edi,[additional_memory]
	mov	eax,[number_of_relocations]
	shl	eax,2
	add	eax,1Ch
	sub	edi,eax
	xchg	edi,[additional_memory]
	mov	ecx,0Fh
	add	eax,0Fh
	and	eax,1111b
	sub	ecx,eax
	xor	al,al
	rep	stosb
	sub	edi,[additional_memory]
	mov	ecx,edi
	shr	edi,4
	mov	word [edx],'MZ' 	; signature
	mov	[edx+8],di		; header size in paragraphs
	mov	eax,[number_of_relocations]
	mov	[edx+6],ax		; number of relocation entries
	mov	eax,[code_size]
	add	eax,ecx
	mov	esi,eax
	shr	esi,9
	and	eax,1FFh
	inc	si
	or	ax,ax
	jnz	mz_size_ok
	mov	ax,200h
	dec	si
      mz_size_ok:
	mov	[edx+2],ax		; number of bytes in last page
	mov	[edx+4],si		; number of pages
	mov	eax,[real_code_size]
	dec	eax
	shr	eax,4
	inc	eax
	mov	esi,[code_size]
	dec	esi
	shr	esi,4
	inc	esi
	sub	eax,esi
	mov	[edx+0Ah],ax		; minimum memory in addition to code
	add	[edx+0Ch],ax		; maximum memory in addition to code
	salc
	mov	ah,al
	or	[edx+0Ch],ax
	mov	word [edx+18h],1Ch	; offset of relocation table
	add	[written_size],ecx
	call	write
	jc	write_failed
	ret

make_stub:
	or	edx,edx
	jnz	stub_from_file
	push esi
	mov	edx,edi
	xor	eax,eax
	mov	ecx,20h
	rep	stosd
	mov	eax,40h+default_stub_end-default_stub
	mov	cx,100h+default_stub_end-default_stub
	mov	word [edx],'MZ'
	mov	word [edx+4],1
	mov	word [edx+2],ax
	mov	word [edx+8],4
	mov	word [edx+0Ah],10h
	mov	word [edx+0Ch],0FFFFh
	mov	word [edx+10h],cx
	mov	word [edx+3Ch],ax
	mov	word [edx+18h],40h
	lea	edi,[edx+40h]
	mov	esi,default_stub
	mov	ecx,default_stub_end-default_stub
	rep	movsb
	pop esi
	jmp	stub_ok
      default_stub:
	use16
	push cs
	pop ds
	mov	dx,stub_message-default_stub
	mov	ah,9
	int	21h
	mov	ax,4C01h
	int	21h
      stub_message db 'this program cannot be run in DOS mode.',0Dh,0Ah,24h
	dd 0, 0  ;rq	1
      default_stub_end:
	use32
      stub_from_file:
	call	open
	jc	file_not_found
	mov	edx,edi
	mov	ecx,1Ch
	push esi
	mov	esi,edx
	call	read
	jc	binary_stub
	cmp	word [esi],'MZ'
	jne	binary_stub
	add	edi,1Ch
	movzx	ecx,word [esi+6]
	dec	ecx
	sar	ecx,3
	inc	ecx
	shl	ecx,2
	add	ecx,(40h-1Ch) >> 2
	lea	eax,[edi+ecx*4]
	cmp	edi,[display_buffer]
	jae	out_of_memory
	xor	eax,eax
	rep	stosd
	mov	edx,40h
	xchg	dx,[esi+18h]
	xor	al,al
	call	lseek
	movzx	ecx,word [esi+6]
	shl	ecx,2
	lea	edx,[esi+40h]
	call	read
	mov	edx,edi
	sub	edx,esi
	shr	edx,4
	xchg	dx,[esi+8]
	shl	edx,4
	xor	al,al
	call	lseek
	movzx	ecx,word [esi+4]
	dec	ecx
	shl	ecx,9
	sub	ecx,eax
	movzx	eax,word [esi+2]
	add	ecx,eax
	mov	edx,edi
	push ecx
	dec	ecx
	shr	ecx,3
	inc	ecx
	shl	ecx,1
	lea	eax,[edi+ecx*4]
	cmp	edi,[display_buffer]
	jae	out_of_memory
	xor	eax,eax
	rep	stosd
	pop ecx
	call	read
	call	close
	mov	edx,edi
	sub	edx,esi
	mov	ax,dx
	and	ax,1FFh
	mov	[esi+2],ax
	dec	edx
	shr	edx,9
	inc	edx
	mov	[esi+4],dx
	mov	eax,edi
	sub	eax,esi
	mov	[esi+3Ch],eax
	pop esi
      stub_ok:
	ret
      binary_stub:
	mov	esi,edi
	mov	ecx,40h >> 2
	xor	eax,eax
	rep	stosd
	mov	al,2
	xor	edx,edx
	call	lseek
	push eax
	xor	al,al
	xor	edx,edx
	call	lseek
	mov	ecx,[esp]
	add	ecx,40h
	dec	ecx
	shr	ecx,3
	inc	ecx
	shl	ecx,3
	mov	ax,cx
	and	ax,1FFh
	mov	[esi+2],ax
	mov	eax,ecx
	dec	eax
	shr	eax,9
	inc	eax
	mov	[esi+4],ax
	mov	[esi+3Ch],ecx
	sub	ecx,40h
	mov	eax,10000h
	sub	eax,ecx
	jbe	binary_heap_ok
	shr	eax,4
	mov	[esi+0Ah],ax
      binary_heap_ok:
	mov	word [esi],'MZ'
	mov	word [esi+8],4
	mov	ax,0FFFFh
	mov	[esi+0Ch],ax
	dec	ax
	mov	[esi+10h],ax
	sub	ax,0Eh
	mov	[esi+0Eh],ax
	mov	[esi+16h],ax
	mov	word [esi+14h],100h
	mov	word [esi+18h],40h
	mov	eax,[display_buffer]
	sub	eax,ecx
	cmp	edi,eax
	jae	out_of_memory
	mov	edx,edi
	shr	ecx,2
	xor	eax,eax
	rep	stosd
	pop ecx
	call	read
	call	close
	pop esi
	ret

format_pe:
	mov	[machine],14Ch		; intel 80386
	mov	[subsystem],3		; console subsystem
	mov	[subsystem_version],3 + (10 << 16)
	xor	edx,edx
      pe_settings:
	cmp	byte [esi],84h
	je	get_stub_name
	cmp	byte [esi],1Bh
	jne	pe_settings_ok
	lodsb
	lodsb
	test	al,80h+40h
	jz	subsystem_setting
	test	al,80h
	jz	machine_setting
	cmp	al,80h
	je	pe_dll
	jmp	pe_settings
      pe_dll:
	bts	[format_flags],8
	jc	symbol_already_defined
	jmp	pe_settings
      machine_setting:
	bts	[format_flags],6
	jc	symbol_already_defined
	and	ax,3Fh
	add	ax,149h
	mov	[machine],ax
	jmp	pe_settings
      subsystem_setting:
	bts	[format_flags],7
	jc	symbol_already_defined
	and	ax,3Fh
	mov	[subsystem],ax
	cmp	byte [esi],'('
	jne	pe_settings
	inc	esi
	cmp	byte [esi],'.'
	jne	invalid_value
	inc	esi
	push edx
	call	fp_to_version
	pop edx
	add	esi,12
	mov	[subsystem_version],eax
	jmp	pe_settings
      get_stub_name:
	lodsb
	lodsw
	cmp	ax,'('
	jne	invalid_argument
	lodsd
	mov	edx,esi
	add	esi,eax
	inc	esi
      pe_settings_ok:
	cmp	[current_pass],0
	je	make_pe_stub
	add	edi,[stub_size]
	jmp	pe_stub_ok
      make_pe_stub:
	call	make_stub
      pe_stub_ok:
	mov	[header_data],edi
	mov	edx,edi
	mov	eax,edi
	sub	eax,[code_start]
	mov	[stub_size],eax
	imul	ecx,[number_of_sections],28h
	add	ecx,18h+0E0h
	add	ecx,eax
	dec	ecx
	shr	ecx,9
	inc	ecx
	shl	ecx,9
	sub	ecx,eax
	mov	eax,[display_buffer]
	sub	eax,ecx
	cmp	edi,eax
	jae	out_of_memory
	shr	ecx,2
	xor	eax,eax
	rep	stosd
	mov	word [edx],'PE' 	; signature
	mov	ax,[machine]
	mov	word [edx+4],ax
	mov	dword [edx+14h],0E0h	; size of optional header
	mov	dword [edx+16h],10B818Eh; flags and magic value
	mov	dword [edx+34h],400000h ; base of image
	mov	dword [edx+38h],1000h	; section alignment
	mov	dword [edx+3Ch],200h	; file alignment
	mov	word [edx+40h],1	; OS version
	mov	ax,[subsystem]
	mov	[edx+5Ch],ax
	mov	eax,[subsystem_version]
	mov	[edx+48h],eax
	mov	word [edx+1Ah],VERSION_MAJOR + (VERSION_MINOR << 8)
	mov	eax,edi
	sub	eax,[code_start]
	mov	[edx+54h],eax		; size of headers
	mov	dword [edx+60h],1000h	; stack reserve
	mov	dword [edx+64h],1000h	; stack commit
	mov	dword [edx+68h],10000h	; heap reserve
	mov	dword [edx+6Ch],0	; heap commit
	mov	dword [edx+74h],16	; number of directories
	dec	eax
	shr	eax,12
	inc	eax
	shl	eax,12
	mov	[edx+28h],eax		; entry point rva
	mov	[code_type],32
	or	[reloc_labels],-1
	mov	[number_of_sections],0
	mov	[sections_data],edi
	lea	ebx,[edx+18h+0E0h]
	mov	[current_section],ebx
	mov	dword [ebx],'.fla'
	mov	dword [ebx+4],'t'
	mov	[ebx+14h],edi
	mov	[ebx+0Ch],eax
	mov	dword [ebx+24h],0E0000060h
	neg	eax
	add	eax,edi
	sub	eax,[edx+34h]
	mov	[org_start],eax
	bt	[format_flags],8
	jnc	instruction_assembled
	or	dword [edx+16h],2000h
	jmp	instruction_assembled
      fp_to_version:
	cmp	byte [esi+11],0
	jne	invalid_value
	cmp	byte [esi+10],2
	ja	invalid_value
	mov	dx,[esi+8]
	cmp	dx,8000h
	je	zero_version
	mov	eax,[esi+4]
	cmp	dx,7
	jg	invalid_value
	mov	cx,7
	sub	cx,dx
	mov	eax,[esi+4]
	shr	eax,cl
	mov	ebx,eax
	shr	ebx,24
	cmp	bl,100
	jae	invalid_value
	and	eax,0FFFFFFh
	mov	ecx,100
	mul	ecx
	shrd	eax,edx,24
	jnc	version_ok
	inc	eax
      version_ok:
	shl	eax,16
	mov	ax,bx
	ret
      zero_version:
	xor	eax,eax
	ret
section_directive:
	cmp	[output_format],3
	jne	illegal_instruction
	cmp	[virtual_data],0
	jne	illegal_instruction
	call	close_section
	bts	[format_flags],5
	lea	ecx,[ebx+28h]
	cmp	ecx,[sections_data]
	jbe	new_section
	sub	ebx,28h
	or	[next_pass_needed],-1
      new_section:
	mov	[ebx+0Ch],eax
	lodsw
	cmp	ax,'('
	jne	invalid_argument
	lea	edx,[esi+4]
	mov	ecx,[esi]
	lea	esi,[esi+4+ecx+1]
	cmp	ecx,8
	ja	name_too_long
	xor	eax,eax
	mov	[ebx],eax
	mov	[ebx+4],eax
	push esi
	push edi
	mov	edi,ebx
	mov	esi,edx
	rep	movsb
	pop edi
	pop esi
	mov	[code_type],32
	mov	dword [ebx+24h],0
	mov	[ebx+14h],edi
	mov	edx,[header_data]
	mov	eax,edi
	sub	eax,[ebx+0Ch]
	sub	eax,[edx+34h]
	mov	[org_start],eax
      get_section_flags:
	lodsb
	cmp	al,1Ah
	je	set_directory
	cmp	al,19h
	je	section_flag
	dec	esi
	cmp	al,13h
	jne	instruction_assembled
	lodsb
	lodsb
	mov	[code_type],al
	cmp	al,16
	jne	instruction_assembled
	or	byte [ebx+24h],4
	jmp	instruction_assembled
      set_directory:
	movzx	eax,byte [esi]
	inc	esi
	mov	ecx,ebx
	xchg	ecx,[edx+78h+eax*8]
	or	ecx,ecx
	jnz	symbol_already_defined
	mov	dword [edx+78h+eax*8+4],-1
	cmp	al,5
	jne	get_section_flags
	call	make_pe_fixups
	jmp	get_section_flags
      section_flag:
	lodsb
	mov	cl,al
	mov	eax,1
	shl	eax,cl
	or	dword [ebx+24h],eax
	jmp	get_section_flags
      close_section:
	mov	ebx,[current_section]
	mov	eax,edi
	sub	eax,[ebx+14h]
	jnz	finish_section
	bt	[format_flags],5
	jc	finish_section
	mov	eax,[ebx+0Ch]
	ret
      finish_section:
	mov	[ebx+8],eax
	cmp	edi,[undefined_data_end]
	jne	align_section
	mov	edi,[undefined_data_start]
      align_section:
	mov	edx,edi
	sub	edx,[ebx+14h]
	mov	ecx,edx
	dec	ecx
	shr	ecx,9
	inc	ecx
	shl	ecx,9
	mov	[ebx+10h],ecx
	sub	ecx,edx
	xor	al,al
	rep	stosb
	mov	eax,[code_start]
	sub	dword [ebx+14h],eax
	mov	eax,[ebx+8]
	dec	eax
	shr	eax,12
	inc	eax
	shl	eax,12
	add	eax,[ebx+0Ch]
	add	ebx,28h
	mov	[current_section],ebx
	inc	word [number_of_sections]
	jz	illegal_instruction
	ret
data_directive:
	cmp	[output_format],3
	jne	illegal_instruction
	lodsb
	cmp	al,1Ah
	je	predefined_data_type
	cmp	al,'('
	jne	invalid_argument
	call	get_byte_value
	cmp	al,16
	jb	data_type_ok
	jmp	invalid_value
      predefined_data_type:
	movzx	eax,byte [esi]
	inc	esi
      data_type_ok:
	mov	ebx,[current_section]
	mov	ecx,edi
	sub	ecx,[ebx+14h]
	add	ecx,[ebx+0Ch]
	mov	edx,[header_data]
	xchg	ecx,[edx+78h+eax*8]
	or	ecx,ecx
	jnz	symbol_already_defined
	call	allocate_structure_data
	mov	word [ebx],data_directive-assembler
	mov	[ebx+2],al
	cmp	al,5
	jne	instruction_assembled
	call	make_pe_fixups
	jmp	instruction_assembled
      end_data:
	cmp	[output_format],3
	jne	illegal_instruction
	call	find_structure_data
	jc	unexpected_instruction
	movzx	eax,byte [ebx+2]
	mov	edx,[current_section]
	mov	ecx,edi
	sub	ecx,[edx+14h]
	add	ecx,[edx+0Ch]
	mov	edx,[header_data]
	sub	ecx,[edx+78h+eax*8]
	mov	[edx+78h+eax*8+4],ecx
	jmp	remove_structure_data
pe_entry:
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne	invalid_argument
	test	ah,~4
	jnz	invalid_address
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[next_pass_needed],0
	je	check_pe_entry
	cmp	[current_pass],0
	je	pe_entry_ok
      check_pe_entry:
	cmp	[value_type],2
	jne	invalid_address
      pe_entry_ok:
	mov	edx,[header_data]
	sub	eax,[edx+34h]
	mov	[edx+28h],eax
	jmp	instruction_assembled
pe_stack:
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne	invalid_argument
	test	ah,~4
	jnz	invalid_address
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[header_data]
	mov	[edx+60h],eax
	cmp	byte [esi],','
	jne	default_stack_commit
	lodsb
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne	invalid_argument
	test	ah,~4
	jnz	invalid_address
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[header_data]
	mov	[edx+64h],eax
	cmp	eax,[edx+60h]
	ja	value_out_of_range
	jmp	instruction_assembled
      default_stack_commit:
	mov	dword [edx+64h],1000h
	mov	eax,[edx+60h]
	cmp	eax,1000h
	ja	instruction_assembled
	mov	dword [edx+64h],eax
	jmp	instruction_assembled
pe_heap:
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne	invalid_argument
	test	ah,~4
	jnz	invalid_address
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[header_data]
	mov	[edx+68h],eax
	cmp	byte [esi],','
	jne	default_heap_commit
	lodsb
	lodsb
	call	get_size_operator
	cmp	al,'('
	jne	invalid_argument
	test	ah,~4
	jnz	invalid_address
	cmp	byte [esi],'.'
	je	invalid_value
	call	get_dword_value
	cmp	[value_type],0
	jne	invalid_use_of_symbol
	mov	edx,[header_data]
	mov	[edx+6Ch],eax
	cmp	eax,[edx+68h]
	ja	value_out_of_range
	jmp	instruction_assembled
      default_heap_commit:
	mov	dword [edx+6Ch],0
	jmp	instruction_assembled
mark_pe_relocation:
	push eax
	push ebx
	mov	ebx,[current_section]
	mov	eax,edi
	sub	eax,[ebx+14h]
	add	eax,[ebx+0Ch]
	mov	ebx,[additional_memory]
	inc	[number_of_relocations]
	jz	invalid_use_of_symbol
	mov	[ebx],eax
	add	ebx,4
	cmp	ebx,[structures_buffer]
	jae	out_of_memory
	mov	[additional_memory],ebx
	pop ebx
	pop eax
	ret
make_pe_fixups:
	push ebx
	push edx
	push esi
	mov	ecx,[number_of_relocations]
	jecxz	fixups_done
	mov	esi,[additional_memory]
	mov	eax,ecx
	shl	eax,2
	sub	esi,eax
	mov	[additional_memory],esi
	or	[number_of_relocations],-1
	mov	edx,1000h
	mov	ebp,edi
      make_fixups:
	cmp	[esi],edx
	jb	store_fixup
	mov	eax,edi
	sub	eax,ebp
	test	eax,11b
	jz	fixups_block
	xor	ax,ax
	stosw
	add	dword [ebx],2
      fixups_block:
	mov	eax,edx
	add	edx,1000h
	cmp	[esi],edx
	jae	fixups_block
	stosd
	mov	ebx,edi
	mov	eax,8
	stosd
      store_fixup:
	add	dword [ebx],2
	mov	eax,[esi]
	and	ax,0FFFh
	or	ax,3000h
	stosw
	add	esi,4
	loop	make_fixups
      fixups_done:
	pop esi
	pop edx
	pop ebx
	ret
finish_pe:
	call	close_section
	mov	edx,[header_data]
	mov	[edx+50h],eax
	cmp	[number_of_relocations],0
	jle	pe_flags_ok
	or	word [edx+16h],1
      pe_flags_ok:
	mov	eax,[number_of_sections]
	mov	[edx+6],ax
	xor	ecx,ecx
      process_directories:
	mov	eax,[edx+78h+ecx*8]
	or	eax,eax
	jz	directory_ok
	cmp	dword [edx+78h+ecx*8+4],-1
	jne	directory_ok
      section_data:
	mov	ebx,[edx+78h+ecx*8]
	mov	eax,[ebx+0Ch]
	mov	[edx+78h+ecx*8],eax	; directory rva
	mov	eax,[ebx+8]
	mov	[edx+78h+ecx*8+4],eax	; directory size
      directory_ok:
	inc	cl
	cmp	cl,10h
	jb	process_directories
	mov	eax,edi
	sub	eax,[code_start]
	mov	[code_size],eax
	ret

;%include '../tables.inc'

; flat assembler source
; Copyright (c) 1999-2001, Tomasz Grysztar
; All rights reserved.

get_operator:
	push esi
	push ebp
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
	pop ebp
	pop esi
	ret
      operator_found:
	pop ebp
	pop eax
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
	jae	name_too_long
	cmp	byte [esi],'.'
	jne	standard_label
	cmp	byte [esi+1],'.'
	je	standard_label
	cmp	[current_locals_prefix],0
	je	standard_label
	push edi
	push ecx
	push esi
	mov	edi,[additional_memory]
	xor	al,al
	stosb
	mov	esi,[current_locals_prefix]
	mov	ebx,edi
	lodsb
	movzx	ecx,al
	lea	ebp,[edi+ecx]
	cmp	ebp,[additional_memory_end]
	jae	out_of_memory
	rep	movsb
	pop esi
	pop ecx
	add	al,cl
	jc	name_too_long
	lea	ebp,[edi+ecx]
	cmp	ebp,[additional_memory_end]
	jae	out_of_memory
	rep	movsb
	mov	[additional_memory],edi
	pop edi
	push esi
	movzx	ecx,al
	mov	esi,ebx
	call	get_label_id
	pop esi
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
	mov	[label_hash],ebp
	push edi
	push esi
	mov	ebx,esi
	mov	edx,ecx
	mov	eax,[labels_list]
      check_label:
	mov	esi,ebx
	mov	ecx,edx
	cmp	eax,[memory_end]
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
	pop edi
	ret
      add_label:
	pop esi
	cmp	byte [esi-1],0
	je	label_name_ok
	mov	al,[esi]
	cmp	al,30h
	jb	name_first_char_ok
	cmp	al,39h
	jbe	invalid_name
      name_first_char_ok:
	cmp	ecx,1
	jne	check_for_reserved_word
	cmp	al,'$'
	je	reserved_word_used_as_symbol
      check_for_reserved_word:
	call	get_instruction
	jnc	reserved_word_used_as_symbol
	mov	edi,data_directives
	call	get_symbol
	jnc	reserved_word_used_as_symbol
	mov	edi,symbols
	call	get_symbol
	jnc	reserved_word_used_as_symbol
	mov	edi,formatter_symbols
	call	get_symbol
	jnc	reserved_word_used_as_symbol
      label_name_ok:
	mov	eax,[labels_list]
	sub	eax,16
	mov	[labels_list],eax
	mov	[eax+4],esi
	add	esi,ecx
	mov	edx,[label_hash]
	mov	[eax],edx
	pop edi
	cmp	eax,edi
	jbe	out_of_memory
	ret

CASE_INSENSITIVE equ 0

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
 %if CASE_INSENSITIVE
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

instructions_2:
 db 'bt',4
 dw bt_instruction-assembler
 db 'if',0
 dw if_directive-assembler
 db 'in',0
 dw in_instruction-assembler
 db 'ja',77h
 dw conditional_jump-assembler
 db 'jb',72h
 dw conditional_jump-assembler
 db 'jc',72h
 dw conditional_jump-assembler
 db 'je',74h
 dw conditional_jump-assembler
 db 'jg',7Fh
 dw conditional_jump-assembler
 db 'jl',7Ch
 dw conditional_jump-assembler
 db 'jo',70h
 dw conditional_jump-assembler
 db 'jp',7Ah
 dw conditional_jump-assembler
 db 'js',78h
 dw conditional_jump-assembler
 db 'jz',74h
 dw conditional_jump-assembler
 db 'or',08h
 dw basic_instruction-assembler
 db 0
instructions_3:
 db 'aaa',37h
 dw simple_instruction-assembler
 db 'aad',0D5h
 dw aa_instruction-assembler
 db 'aam',0D4h
 dw aa_instruction-assembler
 db 'aas',3Fh
 dw simple_instruction-assembler
 db 'adc',10h
 dw basic_instruction-assembler
 db 'add',00h
 dw basic_instruction-assembler
 db 'and',20h
 dw basic_instruction-assembler
 db 'bsf',0BCh
 dw bs_instruction-assembler
 db 'bsr',0BDh
 dw bs_instruction-assembler
 db 'btc',7
 dw bt_instruction-assembler
 db 'btr',6
 dw bt_instruction-assembler
 db 'bts',5
 dw bt_instruction-assembler
 db 'cbw',98h
 dw simple_instruction_16bit-assembler
 db 'cdq',99h
 dw simple_instruction_32bit-assembler
 db 'clc',0F8h
 dw simple_instruction-assembler
 db 'cld',0FCh
 dw simple_instruction-assembler
 db 'cli',0FAh
 dw simple_instruction-assembler
 db 'cmc',0F5h
 dw simple_instruction-assembler
 db 'cmp',38h
 dw basic_instruction-assembler
 db 'cwd',99h
 dw simple_instruction_16bit-assembler
 db 'daa',27h
 dw simple_instruction-assembler
 db 'das',2Fh
 dw simple_instruction-assembler
 db 'dec',1
 dw inc_instruction-assembler
 db 'div',6
 dw single_operand_instruction-assembler
 db 'end',0
 dw end_directive-assembler
 db 'fld',0
 dw fld_instruction-assembler
 db 'fst',2
 dw fld_instruction-assembler
 db 'hlt',0F4h
 dw simple_instruction-assembler
 db 'inc',0
 dw inc_instruction-assembler
 db 'ins',0
 dw ins_instruction-assembler
 db 'int',0CDh
 dw int_instruction-assembler
 db 'jae',73h
 dw conditional_jump-assembler
 db 'jbe',76h
 dw conditional_jump-assembler
 db 'jge',7Dh
 dw conditional_jump-assembler
 db 'jle',7Eh
 dw conditional_jump-assembler
 db 'jmp',0
 dw jmp_instruction-assembler
 db 'jna',76h
 dw conditional_jump-assembler
 db 'jnb',73h
 dw conditional_jump-assembler
 db 'jnc',73h
 dw conditional_jump-assembler
 db 'jne',75h
 dw conditional_jump-assembler
 db 'jng',7Eh
 dw conditional_jump-assembler
 db 'jnl',7Dh
 dw conditional_jump-assembler
 db 'jno',71h
 dw conditional_jump-assembler
 db 'jnp',7Bh
 dw conditional_jump-assembler
 db 'jns',79h
 dw conditional_jump-assembler
 db 'jnz',75h
 dw conditional_jump-assembler
 db 'jpe',7Ah
 dw conditional_jump-assembler
 db 'jpo',7Bh
 dw conditional_jump-assembler
 db 'lar',2
 dw lar_instruction-assembler
 db 'lds',3
 dw ls_instruction-assembler
 db 'lea',0
 dw lea_instruction-assembler
 db 'les',0
 dw ls_instruction-assembler
 db 'lfs',4
 dw ls_instruction-assembler
 db 'lgs',5
 dw ls_instruction-assembler
 db 'lsl',3
 dw lar_instruction-assembler
 db 'lss',2
 dw ls_instruction-assembler
 db 'ltr',3
 dw pm_word_instruction-assembler
 db 'mov',0
 dw mov_instruction-assembler
 db 'mul',4
 dw single_operand_instruction-assembler
 db 'neg',3
 dw single_operand_instruction-assembler
 db 'nop',90h
 dw simple_instruction-assembler
 db 'not',2
 dw single_operand_instruction-assembler
 db 'org',0
 dw org_directive-assembler
 db 'out',0
 dw out_instruction-assembler
 db 'pop',0
 dw pop_instruction-assembler
 db 'por',0EBh
 dw mmx_instruction-assembler
 db 'rcl',2
 dw sh_instruction-assembler
 db 'rcr',3
 dw sh_instruction-assembler
 db 'rep',0F3h
 dw prefix_instruction-assembler
 db 'ret',0C2h
 dw ret_instruction-assembler
 db 'rol',0
 dw sh_instruction-assembler
 db 'ror',1
 dw sh_instruction-assembler
 db 'rsm',0AAh
 dw simple_extended_instruction-assembler
 db 'sal',6
 dw sh_instruction-assembler
 db 'sar',7
 dw sh_instruction-assembler
 db 'sbb',18h
 dw basic_instruction-assembler
 db 'shl',4
 dw sh_instruction-assembler
 db 'shr',5
 dw sh_instruction-assembler
 db 'stc',0F9h
 dw simple_instruction-assembler
 db 'std',0FDh
 dw simple_instruction-assembler
 db 'sti',0FBh
 dw simple_instruction-assembler
 db 'str',1
 dw pm_word_instruction-assembler
 db 'sub',28h
 dw basic_instruction-assembler
 db 'ud2',0Bh
 dw simple_extended_instruction-assembler
 db 'xor',30h
 dw basic_instruction-assembler
 db 0
instructions_4:
 db 'arpl',0
 dw arpl_instruction-assembler
 db 'call',0
 dw call_instruction-assembler
 db 'clts',6
 dw simple_extended_instruction-assembler
 db 'cmps',0
 dw cmps_instruction-assembler
 db 'cwde',98h
 dw simple_instruction_32bit-assembler
 db 'data',0
 dw data_directive-assembler
 db 'else',0
 dw else_directive-assembler
 db 'emms',77h
 dw simple_extended_instruction-assembler
 db 'fabs',100001b
 dw simple_fpu_instruction-assembler
 db 'fadd',0
 dw basic_fpu_instruction-assembler
 db 'fbld',4
 dw fbld_instruction-assembler
 db 'fchs',100000b
 dw simple_fpu_instruction-assembler
 db 'fcom',2
 dw basic_fpu_instruction-assembler
 db 'fcos',111111b
 dw simple_fpu_instruction-assembler
 db 'fdiv',6
 dw basic_fpu_instruction-assembler
 db 'fild',0
 dw fild_instruction-assembler
 db 'fist',2
 dw fild_instruction-assembler
 db 'fld1',101000b
 dw simple_fpu_instruction-assembler
 db 'fldz',101110b
 dw simple_fpu_instruction-assembler
 db 'fmul',1
 dw basic_fpu_instruction-assembler
 db 'fnop',010000b
 dw simple_fpu_instruction-assembler
 db 'fsin',111110b
 dw simple_fpu_instruction-assembler
 db 'fstp',3
 dw fld_instruction-assembler
 db 'fsub',4
 dw basic_fpu_instruction-assembler
 db 'ftst',100100b
 dw simple_fpu_instruction-assembler
 db 'fxam',100101b
 dw simple_fpu_instruction-assembler
 db 'fxch',1
 dw fxch_instruction-assembler
 db 'heap',0
 dw heap_directive-assembler
 db 'idiv',7
 dw single_operand_instruction-assembler
 db 'imul',0
 dw imul_instruction-assembler
 db 'insb',6Ch
 dw simple_instruction-assembler
 db 'insd',6Dh
 dw simple_instruction_32bit-assembler
 db 'insw',6Dh
 dw simple_instruction_16bit-assembler
 db 'int3',0CCh
 dw simple_instruction-assembler
 db 'into',0CEh
 dw simple_instruction-assembler
 db 'invd',8
 dw simple_extended_instruction-assembler
 db 'iret',0CFh
 dw simple_instruction-assembler
 db 'jcxz',0E3h
 dw loop_instruction_16bit-assembler
 db 'jnae',72h
 dw conditional_jump-assembler
 db 'jnbe',77h
 dw conditional_jump-assembler
 db 'jnge',7Ch
 dw conditional_jump-assembler
 db 'jnle',7Fh
 dw conditional_jump-assembler
 db 'lahf',9Fh
 dw simple_instruction-assembler
 db 'lgdt',2
 dw pm_pword_instruction-assembler
 db 'lidt',3
 dw pm_pword_instruction-assembler
 db 'lldt',2
 dw pm_word_instruction-assembler
 db 'lmsw',16h
 dw pm_word_instruction-assembler
 db 'load',0
 dw load_directive-assembler
 db 'lock',0F0h
 dw prefix_instruction-assembler
 db 'lods',0
 dw lods_instruction-assembler
 db 'loop',0E2h
 dw loop_instruction-assembler
 db 'movd',0
 dw movd_instruction-assembler
 db 'movq',0
 dw movq_instruction-assembler
 db 'movs',0
 dw movs_instruction-assembler
 db 'orpd',56h
 dw sse_pd_instruction-assembler
 db 'orps',56h
 dw sse_ps_instruction-assembler
 db 'outs',0
 dw outs_instruction-assembler
 db 'pand',0DBh
 dw mmx_instruction-assembler
 db 'popa',61h
 dw simple_instruction-assembler
 db 'popf',9Dh
 dw simple_instruction-assembler
 db 'push',0
 dw push_instruction-assembler
 db 'pxor',0EFh
 dw mmx_instruction-assembler
 db 'repe',0F3h
 dw prefix_instruction-assembler
 db 'repz',0F3h
 dw prefix_instruction-assembler
 db 'retd',0C2h
 dw ret_instruction_32bit-assembler
 db 'retf',0CAh
 dw ret_instruction-assembler
 db 'retn',0C2h
 dw ret_instruction-assembler
 db 'retw',0C2h
 dw ret_instruction_16bit-assembler
 db 'sahf',9Eh
 dw simple_instruction-assembler
 db 'scas',0AEh
 dw stos_instruction-assembler
 db 'seta',97h
 dw set_instruction-assembler
 db 'setb',92h
 dw set_instruction-assembler
 db 'setc',92h
 dw set_instruction-assembler
 db 'sete',94h
 dw set_instruction-assembler
 db 'setg',9Fh
 dw set_instruction-assembler
 db 'setl',9Ch
 dw set_instruction-assembler
 db 'seto',90h
 dw set_instruction-assembler
 db 'setp',9Ah
 dw set_instruction-assembler
 db 'sets',98h
 dw set_instruction-assembler
 db 'setz',94h
 dw set_instruction-assembler
 db 'sgdt',0
 dw pm_pword_instruction-assembler
 db 'shld',0A4h
 dw shd_instruction-assembler
 db 'shrd',0ACh
 dw shd_instruction-assembler
 db 'sidt',1
 dw pm_pword_instruction-assembler
 db 'sldt',0
 dw pm_word_instruction-assembler
 db 'smsw',14h
 dw pm_word_instruction-assembler
 db 'stos',0AAh
 dw stos_instruction-assembler
 db 'test',0
 dw test_instruction-assembler
 db 'verr',4
 dw pm_word_instruction-assembler
 db 'verw',5
 dw pm_word_instruction-assembler
 db 'wait',9Bh
 dw simple_instruction-assembler
 db 'xadd',0C0h
 dw basic_486_instruction-assembler
 db 'xchg',0
 dw xchg_instruction-assembler
 db 'xlat',0D7h
 dw xlat_instruction-assembler
 db 0
instructions_5:
 db 'addpd',58h
 dw sse_pd_instruction-assembler
 db 'addps',58h
 dw sse_ps_instruction-assembler
 db 'addsd',58h
 dw sse_sd_instruction-assembler
 db 'addss',58h
 dw sse_ss_instruction-assembler
 db 'andpd',54h
 dw sse_pd_instruction-assembler
 db 'andps',54h
 dw sse_ps_instruction-assembler
 db 'bound',0
 dw bound_instruction-assembler
 db 'bswap',0
 dw bswap_instruction-assembler
 db 'cmova',47h
 dw cmov_instruction-assembler
 db 'cmovb',42h
 dw cmov_instruction-assembler
 db 'cmovc',42h
 dw cmov_instruction-assembler
 db 'cmove',44h
 dw cmov_instruction-assembler
 db 'cmovg',4Fh
 dw cmov_instruction-assembler
 db 'cmovl',4Ch
 dw cmov_instruction-assembler
 db 'cmovo',40h
 dw cmov_instruction-assembler
 db 'cmovp',4Ah
 dw cmov_instruction-assembler
 db 'cmovs',48h
 dw cmov_instruction-assembler
 db 'cmovz',44h
 dw cmov_instruction-assembler
 db 'cmppd',0
 dw cmppd_instruction-assembler
 db 'cmpps',0
 dw cmpps_instruction-assembler
 db 'cmpsb',0A6h
 dw simple_instruction-assembler
 db 'cmpsd',0
 dw cmpsd_instruction-assembler
 db 'cmpss',0
 dw cmpss_instruction-assembler
 db 'cmpsw',0A7h
 dw simple_instruction_16bit-assembler
 db 'cpuid',0A2h
 dw simple_extended_instruction-assembler
 db 'divpd',5Eh
 dw sse_pd_instruction-assembler
 db 'divps',5Eh
 dw sse_ps_instruction-assembler
 db 'divsd',5Eh
 dw sse_sd_instruction-assembler
 db 'divss',5Eh
 dw sse_ss_instruction-assembler
 db 'enter',0
 dw enter_instruction-assembler
 db 'entry',0
 dw entry_directive-assembler
 db 'f2xm1',110000b
 dw simple_fpu_instruction-assembler
 db 'faddp',0
 dw faddp_instruction-assembler
 db 'fbstp',6
 dw fbld_instruction-assembler
 db 'fclex',0E2h
 dw finit_instruction-assembler
 db 'fcomi',0F0h
 dw fcomi_instruction-assembler
 db 'fcomp',3
 dw basic_fpu_instruction-assembler
 db 'fdivp',6
 dw faddp_instruction-assembler
 db 'fdivr',7
 dw basic_fpu_instruction-assembler
 db 'ffree',0
 dw ffree_instruction-assembler
 db 'fiadd',0
 dw fi_instruction-assembler
 db 'ficom',2
 dw fi_instruction-assembler
 db 'fidiv',6
 dw fi_instruction-assembler
 db 'fimul',1
 dw fi_instruction-assembler
 db 'finit',0E3h
 dw finit_instruction-assembler
 db 'fistp',3
 dw fild_instruction-assembler
 db 'fisub',4
 dw fi_instruction-assembler
 db 'fldcw',5
 dw fldcw_instruction-assembler
 db 'fldpi',101011b
 dw simple_fpu_instruction-assembler
 db 'fmulp',1
 dw faddp_instruction-assembler
 db 'fprem',111000b
 dw simple_fpu_instruction-assembler
 db 'fptan',110010b
 dw simple_fpu_instruction-assembler
 db 'fsave',6
 dw fsave_instruction-assembler
 db 'fsqrt',111010b
 dw simple_fpu_instruction-assembler
 db 'fstcw',7
 dw fldcw_instruction-assembler
 db 'fstsw',0
 dw fstsw_instruction-assembler
 db 'fsubp',4
 dw faddp_instruction-assembler
 db 'fsubr',5
 dw basic_fpu_instruction-assembler
 db 'fucom',4
 dw ffree_instruction-assembler
 db 'fwait',9Bh
 dw simple_instruction-assembler
 db 'fyl2x',110001b
 dw simple_fpu_instruction-assembler
 db 'iretd',0CFh
 dw simple_instruction_32bit-assembler
 db 'iretw',0CFh
 dw simple_instruction_16bit-assembler
 db 'jecxz',0E3h
 dw loop_instruction_32bit-assembler
 db 'label',0
 dw label_directive-assembler
 db 'leave',0C9h
 dw simple_instruction-assembler
 db 'lodsb',0ACh
 dw simple_instruction-assembler
 db 'lodsd',0ADh
 dw simple_instruction_32bit-assembler
 db 'lodsw',0ADh
 dw simple_instruction_16bit-assembler
 db 'loopd',0E2h
 dw loop_instruction_32bit-assembler
 db 'loope',0E1h
 dw loop_instruction-assembler
 db 'loopw',0E2h
 dw loop_instruction_16bit-assembler
 db 'loopz',0E1h
 dw loop_instruction-assembler
 db 'maxpd',5Fh
 dw sse_pd_instruction-assembler
 db 'maxps',5Fh
 dw sse_ps_instruction-assembler
 db 'maxsd',5Fh
 dw sse_sd_instruction-assembler
 db 'maxss',5Fh
 dw sse_ss_instruction-assembler
 db 'minpd',5Dh
 dw sse_pd_instruction-assembler
 db 'minps',5Dh
 dw sse_ps_instruction-assembler
 db 'minsd',5Dh
 dw sse_sd_instruction-assembler
 db 'minss',5Dh
 dw sse_ss_instruction-assembler
 db 'movsb',0A4h
 dw simple_instruction-assembler
 db 'movsd',0
 dw movsd_instruction-assembler
 db 'movss',0
 dw movss_instruction-assembler
 db 'movsw',0A5h
 dw simple_instruction_16bit-assembler
 db 'movsx',0BEh
 dw movx_instruction-assembler
 db 'movzx',0B6h
 dw movx_instruction-assembler
 db 'mulpd',59h
 dw sse_pd_instruction-assembler
 db 'mulps',59h
 dw sse_ps_instruction-assembler
 db 'mulsd',59h
 dw sse_sd_instruction-assembler
 db 'mulss',59h
 dw sse_ss_instruction-assembler
 db 'outsb',6Eh
 dw simple_instruction-assembler
 db 'outsd',6Fh
 dw simple_instruction_32bit-assembler
 db 'outsw',6Fh
 dw simple_instruction_16bit-assembler
 db 'paddb',0FCh
 dw mmx_instruction-assembler
 db 'paddd',0FEh
 dw mmx_instruction-assembler
 db 'paddq',0D4h
 dw mmx_instruction-assembler
 db 'paddw',0FDh
 dw mmx_instruction-assembler
 db 'pandn',0DFh
 dw mmx_instruction-assembler
 db 'pause',0
 dw pause_instruction-assembler
 db 'pavgb',0E0h
 dw mmx_instruction-assembler
 db 'pavgw',0E3h
 dw mmx_instruction-assembler
 db 'popad',61h
 dw simple_instruction_32bit-assembler
 db 'popaw',61h
 dw simple_instruction_16bit-assembler
 db 'popfd',9Dh
 dw simple_instruction_32bit-assembler
 db 'popfw',9Dh
 dw simple_instruction_16bit-assembler
 db 'pslld',0F2h
 dw mmx_ps_instruction-assembler
 db 'psllq',0F3h
 dw mmx_ps_instruction-assembler
 db 'psllw',0F1h
 dw mmx_ps_instruction-assembler
 db 'psrad',0E2h
 dw mmx_ps_instruction-assembler
 db 'psraw',0E1h
 dw mmx_ps_instruction-assembler
 db 'psrld',0D2h
 dw mmx_ps_instruction-assembler
 db 'psrlq',0D3h
 dw mmx_ps_instruction-assembler
 db 'psrlw',0D1h
 dw mmx_ps_instruction-assembler
 db 'psubb',0F8h
 dw mmx_instruction-assembler
 db 'psubd',0FAh
 dw mmx_instruction-assembler
 db 'psubq',0FBh
 dw mmx_instruction-assembler
 db 'psubw',0F9h
 dw mmx_instruction-assembler
 db 'pusha',60h
 dw simple_instruction-assembler
 db 'pushf',9Ch
 dw simple_instruction-assembler
 db 'rcpps',53h
 dw sse_ps_instruction-assembler
 db 'rcpss',53h
 dw sse_ss_instruction-assembler
 db 'rdmsr',32h
 dw simple_extended_instruction-assembler
 db 'rdpmc',33h
 dw simple_extended_instruction-assembler
 db 'rdtsc',31h
 dw simple_extended_instruction-assembler
 db 'repne',0F2h
 dw prefix_instruction-assembler
 db 'repnz',0F2h
 dw prefix_instruction-assembler
 db 'retfd',0CAh
 dw ret_instruction_32bit-assembler
 db 'retfw',0CAh
 dw ret_instruction_16bit-assembler
 db 'retnd',0C2h
 dw ret_instruction_32bit-assembler
 db 'retnw',0C2h
 dw ret_instruction_16bit-assembler
 db 'scasb',0AEh
 dw simple_instruction-assembler
 db 'scasd',0AFh
 dw simple_instruction_32bit-assembler
 db 'scasw',0AFh
 dw simple_instruction_16bit-assembler
 db 'setae',93h
 dw set_instruction-assembler
 db 'setbe',96h
 dw set_instruction-assembler
 db 'setge',9Dh
 dw set_instruction-assembler
 db 'setle',9Eh
 dw set_instruction-assembler
 db 'setna',96h
 dw set_instruction-assembler
 db 'setnb',93h
 dw set_instruction-assembler
 db 'setnc',93h
 dw set_instruction-assembler
 db 'setne',95h
 dw set_instruction-assembler
 db 'setng',9Eh
 dw set_instruction-assembler
 db 'setnl',9Dh
 dw set_instruction-assembler
 db 'setno',91h
 dw set_instruction-assembler
 db 'setnp',9Bh
 dw set_instruction-assembler
 db 'setns',99h
 dw set_instruction-assembler
 db 'setnz',95h
 dw set_instruction-assembler
 db 'setpe',9Ah
 dw set_instruction-assembler
 db 'setpo',9Bh
 dw set_instruction-assembler
 db 'stack',0
 dw stack_directive-assembler
 db 'stosb',0AAh
 dw simple_instruction-assembler
 db 'stosd',0ABh
 dw simple_instruction_32bit-assembler
 db 'stosw',0ABh
 dw simple_instruction_16bit-assembler
 db 'subpd',5Ch
 dw sse_pd_instruction-assembler
 db 'subps',5Ch
 dw sse_ps_instruction-assembler
 db 'subsd',5Ch
 dw sse_sd_instruction-assembler
 db 'subss',5Ch
 dw sse_ss_instruction-assembler
 db 'times',0
 dw times_directive-assembler
 db 'wrmsr',30h
 dw simple_extended_instruction-assembler
 db 'xlatb',0D7h
 dw simple_instruction-assembler
 db 'xorpd',57h
 dw sse_pd_instruction-assembler
 db 'xorps',57h
 dw sse_ps_instruction-assembler
 db 0
instructions_6:
 db 'andnpd',55h
 dw sse_pd_instruction-assembler
 db 'andnps',55h
 dw sse_ps_instruction-assembler
 db 'cmovae',43h
 dw cmov_instruction-assembler
 db 'cmovbe',46h
 dw cmov_instruction-assembler
 db 'cmovge',4Dh
 dw cmov_instruction-assembler
 db 'cmovle',4Eh
 dw cmov_instruction-assembler
 db 'cmovna',46h
 dw cmov_instruction-assembler
 db 'cmovnb',43h
 dw cmov_instruction-assembler
 db 'cmovnc',43h
 dw cmov_instruction-assembler
 db 'cmovne',45h
 dw cmov_instruction-assembler
 db 'cmovng',4Eh
 dw cmov_instruction-assembler
 db 'cmovnl',4Dh
 dw cmov_instruction-assembler
 db 'cmovno',41h
 dw cmov_instruction-assembler
 db 'cmovnp',4Bh
 dw cmov_instruction-assembler
 db 'cmovns',49h
 dw cmov_instruction-assembler
 db 'cmovnz',45h
 dw cmov_instruction-assembler
 db 'cmovpe',4Ah
 dw cmov_instruction-assembler
 db 'cmovpo',4Bh
 dw cmov_instruction-assembler
 db 'comisd',2Fh
 dw comisd_instruction-assembler
 db 'comiss',2Fh
 dw comiss_instruction-assembler
 db 'fcomip',0F0h
 dw fcomip_instruction-assembler
 db 'fcompp',0
 dw fcompp_instruction-assembler
 db 'fdivrp',7
 dw faddp_instruction-assembler
 db 'ficomp',3
 dw fi_instruction-assembler
 db 'fidivr',7
 dw fi_instruction-assembler
 db 'fisubr',5
 dw fi_instruction-assembler
 db 'fldenv',4
 dw fldenv_instruction-assembler
 db 'fldl2e',101010b
 dw simple_fpu_instruction-assembler
 db 'fldl2t',101001b
 dw simple_fpu_instruction-assembler
 db 'fldlg2',101100b
 dw simple_fpu_instruction-assembler
 db 'fldln2',101101b
 dw simple_fpu_instruction-assembler
 db 'fnclex',0E2h
 dw fninit_instruction-assembler
 db 'fninit',0E3h
 dw fninit_instruction-assembler
 db 'fnstsw',0
 dw fnstsw_instruction-assembler
 db 'format',0
 dw format_directive-assembler
 db 'fpatan',110011b
 dw simple_fpu_instruction-assembler
 db 'fprem1',110101b
 dw simple_fpu_instruction-assembler
 db 'frstor',4
 dw fsave_instruction-assembler
 db 'fscale',111101b
 dw simple_fpu_instruction-assembler
 db 'fstenv',6
 dw fldenv_instruction-assembler
 db 'fsubrp',5
 dw faddp_instruction-assembler
 db 'fucomi',0E8h
 dw fcomi_instruction-assembler
 db 'fucomp',5
 dw ffree_instruction-assembler
 db 'fxsave',0
 dw fxsave_instruction-assembler
 db 'invlpg',0
 dw invlpg_instruction-assembler
 db 'lfence',0E8h
 dw fence_instruction-assembler
 db 'looped',0E1h
 dw loop_instruction_32bit-assembler
 db 'loopew',0E1h
 dw loop_instruction_16bit-assembler
 db 'loopne',0E0h
 dw loop_instruction-assembler
 db 'loopnz',0E0h
 dw loop_instruction-assembler
 db 'loopzd',0E1h
 dw loop_instruction_32bit-assembler
 db 'loopzw',0E1h
 dw loop_instruction_16bit-assembler
 db 'mfence',0F0h
 dw fence_instruction-assembler
 db 'movapd',28h
 dw movpd_instruction-assembler
 db 'movaps',28h
 dw movps_instruction-assembler
 db 'movdqa',66h
 dw movdq_instruction-assembler
 db 'movdqu',0F3h
 dw movdq_instruction-assembler
 db 'movhpd',16h
 dw movlpd_instruction-assembler
 db 'movhps',16h
 dw movlps_instruction-assembler
 db 'movlpd',12h
 dw movlpd_instruction-assembler
 db 'movlps',12h
 dw movlps_instruction-assembler
 db 'movnti',0C3h
 dw movnti_instruction-assembler
 db 'movntq',0E7h
 dw movntq_instruction-assembler
 db 'movupd',10h
 dw movpd_instruction-assembler
 db 'movups',10h
 dw movps_instruction-assembler
 db 'paddsb',0ECh
 dw mmx_instruction-assembler
 db 'paddsw',0EDh
 dw mmx_instruction-assembler
 db 'pextrw',0C5h
 dw pmovmskb_instruction-assembler
 db 'pinsrw',0C4h
 dw pinsrw_instruction-assembler
 db 'pmaxsw',0EEh
 dw mmx_instruction-assembler
 db 'pmaxub',0DEh
 dw mmx_instruction-assembler
 db 'pminsw',0EAh
 dw mmx_instruction-assembler
 db 'pminub',0DAh
 dw mmx_instruction-assembler
 db 'pmulhw',0E5h
 dw mmx_instruction-assembler
 db 'pmullw',0D5h
 dw mmx_instruction-assembler
 db 'psadbw',0F6h
 dw mmx_instruction-assembler
 db 'pshufd',66h
 dw pshufd_instruction-assembler
 db 'pshufw',0
 dw pshufw_instruction-assembler
 db 'pslldq',111b
 dw ps_dq_instruction-assembler
 db 'psrldq',011b
 dw ps_dq_instruction-assembler
 db 'psubsb',0E8h
 dw mmx_instruction-assembler
 db 'psubsw',0E9h
 dw mmx_instruction-assembler
 db 'pushad',60h
 dw simple_instruction_32bit-assembler
 db 'pushaw',60h
 dw simple_instruction_16bit-assembler
 db 'pushfd',9Ch
 dw simple_instruction_32bit-assembler
 db 'pushfw',9Ch
 dw simple_instruction_16bit-assembler
 db 'repeat',0
 dw repeat_directive-assembler
 db 'setalc',0D6h
 dw simple_instruction-assembler
 db 'setnae',92h
 dw set_instruction-assembler
 db 'setnbe',97h
 dw set_instruction-assembler
 db 'setnge',9Ch
 dw set_instruction-assembler
 db 'setnle',9Fh
 dw set_instruction-assembler
 db 'sfence',0F8h
 dw fence_instruction-assembler
 db 'shufpd',0C6h
 dw sse_pd_instruction-assembler
 db 'shufps',0C6h
 dw sse_ps_instruction-assembler
 db 'sqrtpd',51h
 dw sse_pd_instruction-assembler
 db 'sqrtps',51h
 dw sse_ps_instruction-assembler
 db 'sqrtsd',51h
 dw sse_sd_instruction-assembler
 db 'sqrtss',51h
 dw sse_ss_instruction-assembler
 db 'wbinvd',9
 dw simple_extended_instruction-assembler
 db 0
instructions_7:
 db 'clflush',111b
 dw fxsave_instruction-assembler
 db 'cmovnae',42h
 dw cmov_instruction-assembler
 db 'cmovnbe',47h
 dw cmov_instruction-assembler
 db 'cmovnge',4Ch
 dw cmov_instruction-assembler
 db 'cmovnle',4Fh
 dw cmov_instruction-assembler
 db 'cmpeqpd',0
 dw cmp_pd_instruction-assembler
 db 'cmpeqps',0
 dw cmp_ps_instruction-assembler
 db 'cmpeqsd',0
 dw cmp_sd_instruction-assembler
 db 'cmpeqss',0
 dw cmp_ss_instruction-assembler
 db 'cmplepd',2
 dw cmp_pd_instruction-assembler
 db 'cmpleps',2
 dw cmp_ps_instruction-assembler
 db 'cmplesd',2
 dw cmp_sd_instruction-assembler
 db 'cmpless',2
 dw cmp_ss_instruction-assembler
 db 'cmpltpd',1
 dw cmp_pd_instruction-assembler
 db 'cmpltps',1
 dw cmp_ps_instruction-assembler
 db 'cmpltsd',1
 dw cmp_sd_instruction-assembler
 db 'cmpltss',1
 dw cmp_ss_instruction-assembler
 db 'cmpnepd',4
 dw cmp_pd_instruction-assembler
 db 'cmpneps',4
 dw cmp_ps_instruction-assembler
 db 'cmpnesd',4
 dw cmp_sd_instruction-assembler
 db 'cmpness',4
 dw cmp_ss_instruction-assembler
 db 'cmpnlpd',5
 dw cmp_pd_instruction-assembler
 db 'cmpnlps',5
 dw cmp_ps_instruction-assembler
 db 'cmpnlsd',5
 dw cmp_sd_instruction-assembler
 db 'cmpnlss',5
 dw cmp_ss_instruction-assembler
 db 'cmpxchg',0B0h
 dw basic_486_instruction-assembler
 db 'display',0
 dw display_directive-assembler
 db 'fcmovnb',0C0h
 dw fcomi_instruction-assembler
 db 'fcmovne',0C8h
 dw fcomi_instruction-assembler
 db 'fcmovnu',0D8h
 dw fcomi_instruction-assembler
 db 'fdecstp',110110b
 dw simple_fpu_instruction-assembler
 db 'fincstp',110111b
 dw simple_fpu_instruction-assembler
 db 'frndint',111100b
 dw simple_fpu_instruction-assembler
 db 'fsincos',111011b
 dw simple_fpu_instruction-assembler
 db 'fucomip',0E8h
 dw fcomip_instruction-assembler
 db 'fxrstor',1
 dw fxsave_instruction-assembler
 db 'fxtract',110100b
 dw simple_fpu_instruction-assembler
 db 'fyl2xp1',111001b
 dw simple_fpu_instruction-assembler
 db 'ldmxcsr',10b
 dw fxsave_instruction-assembler
 db 'loopned',0E0h
 dw loop_instruction_32bit-assembler
 db 'loopnew',0E0h
 dw loop_instruction_16bit-assembler
 db 'loopnzd',0E0h
 dw loop_instruction_32bit-assembler
 db 'loopnzw',0E0h
 dw loop_instruction_16bit-assembler
 db 'movdq2q',0
 dw movdq2q_instruction-assembler
 db 'movhlps',12h
 dw movhlps_instruction-assembler
 db 'movlhps',16h
 dw movhlps_instruction-assembler
 db 'movntdq',0E7h
 dw movntdq_instruction-assembler
 db 'movntpd',2Bh
 dw movntdq_instruction-assembler
 db 'movntps',2Bh
 dw movntq_instruction-assembler
 db 'movq2dq',0
 dw movq2dq_instruction-assembler
 db 'paddusb',0DCh
 dw mmx_instruction-assembler
 db 'paddusw',0DDh
 dw mmx_instruction-assembler
 db 'pcmpeqb',74h
 dw mmx_instruction-assembler
 db 'pcmpeqd',76h
 dw mmx_instruction-assembler
 db 'pcmpeqw',75h
 dw mmx_instruction-assembler
 db 'pcmpgtb',64h
 dw mmx_instruction-assembler
 db 'pcmpgtd',66h
 dw mmx_instruction-assembler
 db 'pcmpgtw',65h
 dw mmx_instruction-assembler
 db 'pmaddwd',0F5h
 dw mmx_instruction-assembler
 db 'pmulhuw',0E4h
 dw mmx_instruction-assembler
 db 'pmuludq',0F4h
 dw mmx_instruction-assembler
 db 'pshufhw',0F3h
 dw pshufd_instruction-assembler
 db 'pshuflw',0F2h
 dw pshufd_instruction-assembler
 db 'psubusb',0D8h
 dw mmx_instruction-assembler
 db 'psubusw',0D9h
 dw mmx_instruction-assembler
 db 'rsqrtps',52h
 dw sse_ps_instruction-assembler
 db 'rsqrtss',52h
 dw sse_ss_instruction-assembler
 db 'section',0
 dw section_directive-assembler
 db 'segment',0
 dw segment_directive-assembler
 db 'stmxcsr',11b
 dw fxsave_instruction-assembler
 db 'sysexit',35h
 dw simple_extended_instruction-assembler
 db 'ucomisd',2Eh
 dw comisd_instruction-assembler
 db 'ucomiss',2Eh
 dw comiss_instruction-assembler
 db 'virtual',0
 dw virtual_directive-assembler
 db 0
instructions_8:
 db 'cmpnleps',6
 dw cmp_ps_instruction-assembler
 db 'cmpnless',6
 dw cmp_ss_instruction-assembler
 db 'cmpordps',7
 dw cmp_ps_instruction-assembler
 db 'cmpordss',7
 dw cmp_ss_instruction-assembler
 db 'cvtdq2pd',0E6h
 dw cvtdq2pd_instruction-assembler
 db 'cvtdq2ps',5Bh
 dw sse_ps_instruction-assembler
 db 'cvtpd2dq',0E6h
 dw cvtpd2dq_instruction-assembler
 db 'cvtpd2pi',2Dh
 dw cvtpd2pi_instruction-assembler
 db 'cvtpd2ps',5Ah
 dw sse_pd_instruction-assembler
 db 'cvtpi2pd',2Ah
 dw cvtpi2pd_instruction-assembler
 db 'cvtpi2ps',2Ah
 dw cvtpi2ps_instruction-assembler
 db 'cvtps2dq',5Bh
 dw sse_pd_instruction-assembler
 db 'cvtps2pd',5Ah
 dw sse_ps_instruction-assembler
 db 'cvtps2pi',2Dh
 dw cvtps2pi_instruction-assembler
 db 'cvtsd2si',2Dh
 dw cvtsd2si_instruction-assembler
 db 'cvtsd2ss',5Ah
 dw sse_sd_instruction-assembler
 db 'cvtsi2sd',2Ah
 dw cvtsi2sd_instruction-assembler
 db 'cvtsi2ss',2Ah
 dw cvtsi2ss_instruction-assembler
 db 'cvtss2sd',5Ah
 dw sse_ss_instruction-assembler
 db 'cvtss2si',2Dh
 dw cvtss2si_instruction-assembler
 db 'fcmovnbe',0D0h
 dw fcomi_instruction-assembler
 db 'maskmovq',0
 dw maskmovq_instruction-assembler
 db 'movmskpd',0
 dw movmskpd_instruction-assembler
 db 'movmskps',0
 dw movmskps_instruction-assembler
 db 'packssdw',6Bh
 dw mmx_instruction-assembler
 db 'packsswb',63h
 dw mmx_instruction-assembler
 db 'packuswb',67h
 dw mmx_instruction-assembler
 db 'pmovmskb',0D7h
 dw pmovmskb_instruction-assembler
 db 'sysenter',34h
 dw simple_extended_instruction-assembler
 db 'unpckhpd',15h
 dw sse_pd_instruction-assembler
 db 'unpckhps',15h
 dw sse_ps_instruction-assembler
 db 'unpcklpd',14h
 dw sse_pd_instruction-assembler
 db 'unpcklps',14h
 dw sse_ps_instruction-assembler
 db 0
instructions_9:
 db 'cmpxchg8b',0
 dw cmpxchg8b_instruction-assembler
 db 'cvttpd2dq',0E6h
 dw sse_pd_instruction-assembler
 db 'cvttpd2pi',2Ch
 dw cvtpd2pi_instruction-assembler
 db 'cvttps2dq',5Bh
 dw cvtdq2pd_instruction-assembler
 db 'cvttps2pi',2Ch
 dw cvtps2pi_instruction-assembler
 db 'cvttsd2si',2Ch
 dw cvtsd2si_instruction-assembler
 db 'cvttss2si',2Ch
 dw cvtss2si_instruction-assembler
 db 'punpckhbw',68h
 dw mmx_instruction-assembler
 db 'punpckhdq',6Ah
 dw mmx_instruction-assembler
 db 'punpckhwd',69h
 dw mmx_instruction-assembler
 db 'punpcklbw',60h
 dw mmx_instruction-assembler
 db 'punpckldq',62h
 dw mmx_instruction-assembler
 db 'punpcklwd',61h
 dw mmx_instruction-assembler
 db 0
instructions_10:
 db 'cmpunordps',3
 dw cmp_ps_instruction-assembler
 db 'cmpunordss',3
 dw cmp_ss_instruction-assembler
 db 'loadall286',5
 dw simple_extended_instruction-assembler
 db 'loadall386',7
 dw simple_extended_instruction-assembler
 db 'maskmovdqu',0
 dw maskmovdqu_instruction-assembler
 db 'prefetcht0',1
 dw prefetch_instruction-assembler
 db 'prefetcht1',2
 dw prefetch_instruction-assembler
 db 'prefetcht2',3
 dw prefetch_instruction-assembler
 db 'punpckhqdq',6Dh
 dw sse_pd_instruction-assembler
 db 'punpcklqdq',6Ch
 dw sse_pd_instruction-assembler
 db 0
instructions_11:
 db 'prefetchnta',0
 dw prefetch_instruction-assembler
 db 0


;%include done

_copyright db 'Copyright (c) 1999-2002, Tomasz Grysztar',0

_logo db 'flat assembler  version ',VERSION_STRING,0xA,0
_usage db 'usage: fasm source output',0xA,0

_passes_suffix db ' passes, ',0
_seconds_suffix db ' seconds, ',0
_bytes_suffix db ' bytes.',0xA,0

_counter db 4,'0000'

bss:

absolute $
alignb 4
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
fp_format resb 1
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
buffer resb 100h

program_end:
