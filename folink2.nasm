;
; folink2.nasm: flat OMF linker implemented in NASM 0.98.39
; by pts@fazekas.hu at Tue Mar 26 02:24:06 CET 2024
;
; This linker just dumps the data in the LEDATA, LEDATA386, LIDATA and
; LIDATA386 records in the input OMF file. For the LIDATA and LIDATA386
; records, it expands the repeated bytes. It fails if it encounters
; multiple segments or any relocations (fixupps).
;
; Compile with: nasm-0.98.39 -O999999999 -w+orphan-labels -f bin -o folink2.com folink2.nasm
;
; Implementation based on folink2.c and on the disassembly of the
; folink2.obj file created by `dosmc -mt -c folink2.c'.
;

	bits 16
	cpu 8086
	org 100h  ; DOS .com file is loaded at CS:0x100.

_start:  ; Entry point of the DOS .com program.
		cld
		mov di, ___section_c_bss
		mov cx, (___section_startup_ubss-___section_c_bss+1)>>1
		xor ax, ax
		rep stosw
		mov di, argv_bytes
		mov bp, argv_pointers
		push bp
		push es
		lds si, [0x2c-2]  ; Environment segment within PSP.
		
		xor si, si
		lodsb
.next_entry:	test al, al
		jz .end_entries
.next_char:	test al, al
		lodsb
		jnz .next_char
		jmp short .next_entry
.end_entries:	inc si  ; Skip over a single byte.
		inc si  ; Skip over '\0'.
		; Now ds:si points to the program name as an uppercase, absolute pathname with extension (e.g. .EXE or .COM). We will use it as argv.
		
		; Copy program name to argv[0].
		mov [bp], di  ; argv[0] pointer.
		inc bp
		inc bp
		mov cx, 144  ; To avoid overflowing argv_bytes. See above why 144.
.next_copy:	dec cx
		jnz .argv0_limit_not_reached
		xor al, al
		stosb
		jmp short .after_copy
.argv0_limit_not_reached:
		lodsb
		stosb
		test al, al
		jnz .next_copy
.after_copy:
		
		; Now copy cmdline.
		pop ds  ; PSP.
		mov si, 0x80  ; Command-line size byte within PSP, usually space. 0..127, we trust it.
		lodsb
		xor ah, ah
		xchg bx, ax  ; bx := ax.
		mov byte [si+bx], 0
.scan_for_arg:	lodsb
		test al, al
		jz .after_cmdline
		cmp al, ' '
		je .scan_for_arg
		cmp al, 9  ; Tab.
		je .scan_for_arg
		mov [bp], di  ; Start new argv[...] element. Uses ss by default, good.
		inc bp
		inc bp
		stosb  ; First byte of argv[...].
.next_argv_byte:
		lodsb
		stosb
		test al, al
		jz .after_cmdline
		cmp al, ' '
		je .end_arg
		cmp al, 9  ; Tab.
		jne .next_argv_byte
.end_arg:	dec di
		xor al, al
		stosb  ; Replace whitespace with terminating '\0'.
		jmp short .scan_for_arg
		
.after_cmdline:	mov word [bp], 0  ; NULL at the end of argv.
		pop dx  ; argv_pointers. Final return value of dx.
		sub bp, dx
		xchg ax, bp  ; ax := bp.
		;shr ax, 1  ; Set ax to argc, it's final return value. No need to set it, main below doesn't use it.
		; Fall through to main_never_returns.

main_never_returns:  ; Never returns. Takes argv in DX.
		mov bp, sp
		sub sp, 12h
		mov bx, dx
		xor ax, ax
		cmp word [bx+2], ax
		je .8
		cmp word [bx+4], ax
		je .8
		cmp word [bx+6], ax
		je .9
.8:
		mov bx, 23h
		mov dx, msg_usage
		mov ax, 2
		call write_
		mov ax, 4c01h
		int 21h
.9:
		mov ax, word [bx+2]
		xor dx, dx
		call open2_
		mov word [_rdfd], ax
		test ax, ax
		jge .10
		mov ax, 14h
		call fatal_
.10:
		mov ax, word [bx+4]
		call creat1_
		mov word [_wrfd], ax
		test ax, ax
		jge .11
		mov ax, 15h
		call fatal_
.11:
		xor bx, bx
		mov byte [bp-2], 0
.12:
		mov word [_rsize], 3
		call r8_
		mov dx, ax
		call r16_le_
		mov word [_rsize], ax
		test ax, ax
		ja .13
		mov ax, 2
		call fatal_
.13:
		dec word [_rsize]
		cmp dx, 8ah
		je .15
		cmp dx, 8bh
		je .15
		cmp dx, 88h
		je .14
		cmp dx, 9ah
		je .14
		cmp dx, 96h
		je .14
		cmp dx, 98h
		je .14
		cmp dx, 99h
		je .14
		cmp dx, 80h
		jne .16
.14:
		cmp word [_rsize], 0
		jbe .21
		call r8_
		jmp .14
.15:
		jmp .41
.16:
		cmp dx, 0a0h
		je .17
		cmp dx, 0a2h
		je .17
		cmp dx, 0a1h
		je .17
		cmp dx, 0a3h
		jne .26
.17:
		call r8_
		cmp ax, 1
		je .18
		mov ax, 0bh
		call fatal_
.18:
		call r16_le_
		mov cx, ax
		cmp dx, 0a1h
		je .19
		cmp dx, 0a3h
		jne .20
.19:
		call r16_le_
.20:
		cmp byte [bp-2], 0
		je .22
		cmp cx, bx
		je .23
		mov ax, 4
		call fatal_
		jmp .23
.21:
		jmp .38
.22:
		mov bx, cx
		inc byte [bp-2]
.23:
		cmp dx, 0a0h
		je .24
		cmp dx, 0a1h
		jne .27
.24:
		add bx, word [_rsize]
.25:
		cmp word [_rsize], 0
		jbe .21
		call r8_
		call w8_
		jmp .25
.26:
		jmp .37
.27:
		call r16_le_
		mov cx, ax
		mov word [bp-8], ax
		mov word [bp-18], 0
		cmp dx, 0a3h
		jne .28
		call r16_le_
		mov word [bp-18], ax
.28:
		call r16_le_
		mov si, ax
		test ax, ax
		jne .29
		mov ax, 6
		call fatal_
.29:
		test si, si
		jbe .21
		call r16_le_
		mov cx, ax
		mov di, ax
		mov word [bp-6], 0
		cmp dx, 0a3h
		jne .30
		call r16_le_
		mov word [bp-6], ax
.30:
		call r16_le_
		test ax, ax
		je .31
		mov ax, 8
		call fatal_
.31:
		call r8_
		mov cx, ax
		call r8_
		mov word [bp-12], ax
		cmp cx, 1
		je .32
		mov ax, 9
		call fatal_
.32:
		mov ax, word [bp-8]
		mov word [bp-10], ax
		mov cx, word [bp-18]
.33:
		mov ax, word [bp-10]
		or ax, cx
		test ax, ax
		jbe .36
		add bx, di
		mov word [bp-4], di
		mov ax, word [bp-6]
		mov word [bp-14], ax
.34:
		mov ax, word [bp-14]
		or ax, word [bp-4]
		test ax, ax
		jbe .35
		mov al, byte [bp-12]
		call w8_
		add word [bp-4], -1
		adc word [bp-14], -1
		jmp .34
.35:
		add word [bp-10], -1
		adc cx, -1
		jmp .33
.36:
		dec si
		jmp .29
.37:
		mov ax, 12h
		call fatal_
.38:
		inc word [_rsize]
		call r8_
		cmp word [_rsize], 0
		jne .40
.39:
		jmp .12
.40:
		mov ax, 0ah
		call fatal_
		jmp .39
.41:
		call wflush_
		mov ax, 4c00h  ; EXIT_SUCCESS.
		int 21h
		; Not reached.

fatal_:  ; Never returns.
		mov cx, ax
		mov bx, 15h
		mov dx, msg_fatal
		mov ax, 2
		call write_
		xchg ax, cx  ; AL := CL; AH := junk; CL := junk.
		mov ah, 4ch
		int 21h
		; Not reached.

wflush_:
		push bx
		push dx
		mov ax, word [_wri]
		test ax, ax
		jbe .6
		mov bx, ax
		mov ax, word [_wrfd]
		mov dx, _wrbuf
		call write_
		test ax, ax
		jle .4
		cmp ax, word [_wri]
		je .5
.4:
		mov ax, 7
		call fatal_
.5:
		xor ax, ax
		mov word [_wri], ax
.6:
		pop dx
		pop bx
		ret

w8_:
		push bx
		push dx
		mov dl, al
		cmp word [_wri], 200h
		jne .7
		call wflush_
.7:
		mov bx, word [_wri]
		mov byte [bx+_wrbuf], dl
		inc bx
		mov word [_wri], bx
		pop dx
		pop bx
		ret

r8_:
		push bx
		push dx
		cmp word [_rsize], 0
		jne .1
		mov ax, 3
		call fatal_
.1:
		mov ax, word [_rdi]
		cmp ax, word [_rdlimit]
		jne .3
		mov ax, word [_rdfd]
		mov bx, 200h
		mov dx, _rdbuf
		call read_
		mov bx, ax
		test ax, ax
		jg .2
		mov ax, 5
		call fatal_
.2:
		mov word [_rdlimit], bx
		xor ax, ax
		mov word [_rdi], ax
.3:
		mov bx, word [_rdi]
		mov al, byte [bx+_rdbuf]
		xor ah, ah
		dec word [_rsize]
		inc bx
		mov word [_rdi], bx
		pop dx
		pop bx
		ret

r16_le_:
		push dx
		call r8_  ; Read low byte.
		xchg dx, ax  ; DX := AX; AX := junk.
		call r8_  ; Read high byte.
		mov dh, al
		xchg dx, ax
		pop dx
		ret

; ssize_t write(int fd, const void *buf, size_t count);
; Optimized for size. AX == fd, DX == buf, BX == count.
write_:		push cx
		xchg ax, bx		; AX := count; BX := fd.
		xchg ax, cx		; CX := count; AX := junk.
		mov ah, 0x40
		jmp int21cx

; ssize_t read(int fd, void *buf, size_t count);
; Optimized for size. AX == fd, DX == buf, BX == count.
read_:		push cx
		xchg ax, bx		; AX := count; BX := fd.
		xchg ax, cx		; CX := count; AX := junk.
		mov ah, 0x3f
int21cx:	int 0x21
		jnc .ok
		sbb ax, ax		; AX := -1.
.ok:		pop cx
		ret


; int creat(const char *pathname, int mode);
; int creat1(const char *pathname);
; Optimized for size. AX == pathname, DX == mode.
; The value O_CREAT | O_TRUNC | O_WRONLY is used as flags.
; mode is ignored, except for bit 8 (read-only). Recommended value: 0644,
; for Unix compatibility.
creat1_:
creat_:		push cx
		xchg ax, dx		; DX := pathname; AX := mode.
		xor cx, cx
		test ah, 1
		jz .1
		inc cx			; CX := 1 means read-only.
.1:		mov ah, 0x3c
		jmp int21cx

; int open(const char *pathname, int flags, int mode);
; int open2(const char *pathname, int flags);
; Optimized for size. AX == pathname, DX == flags, BX == mode.
; Unix open(2) is able to create new files (O_CREAT), in DOS please use
; creat() for that.
; mode is ignored. Recommended value: 0644, for Unix compatibility.
open2_:
open_:		xchg ax, dx		; DX := pathname; AX := junk.
		mov ah, 0x3d
		int 0x21
		jnc .ok
		sbb ax, ax		; AX := -1.
.ok:		ret

msg_fatal:	db 'folink2 fatal error', 13, 10, 0
msg_usage:	db 'Usage: folink2 <in.obj> <out.bin>', 13, 10, 0

; --- Variables initialized to 0 by _start.
		absolute $
		resb ($$-$)&1  ; align 2
		;section .bss align=1
___section_bss:

___section_c_bss:
_wrbuf:		resb 0x200
_rdbuf:		resb 0x200
_wrfd:		resb 2
_rdfd:		resb 2
_wri:		resb 2
_rdlimit:	resb 2
_rsize:		resb 2
_rdi:		resb 2

; --- Uninitialized .bss used by _start.    ___section_startup_ubss:
___section_startup_ubss:

argv_bytes	resb 270
argv_pointers	resb 130

___section_ubss_end:
