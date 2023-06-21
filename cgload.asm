;
; Loader for California Games
;
; Copyright (c) 2023 Vitaly Sinilin
;
; 19 June 2023
;

cpu 8086
[map all cgload.map]

%macro res_fptr 0
.off		resw	1
.seg		resw	1
%endmacro

PSP_SZ		equ	100h
STACK_SZ	equ	64

section .text

		org	PSP_SZ

		jmp	short main
byemsg		db	"Visit http://sinil.in/mintware/californiagames/$"

main:		mov	sp, __stktop
		mov	bx, sp
		mov	cl, 4
		shr	bx, cl				; new size in pars
		mov	ah, 4Ah				; resize memory block
		int	21h

		mov	bx, __bss_size
.zero_bss:	dec	bx
		mov	byte [__bss + bx], bh
		jnz	.zero_bss

		mov	[cmdtail.seg], cs		; pass cmd tail from
		mov	word [cmdtail.off], 80h		; our PSP

		mov	ax, 3521h			; read int 21h vector
		int	21h				; es:bx <- cur handler
		mov	[int21.seg], es			; save original
		mov	[int21.off], bx			; int 21h vector

		mov	dx, int_handler			; setup our own
		mov	ax, 2521h			; handler for int 21h
		int	21h				; ds:dx -> new handler

		mov	dx, exe
		push	ds
		pop	es
		mov	bx, parmblk
		mov	ax, 4B00h			; exec
		int	21h

		jnc	.success
		call	uninstall
		mov	dx, errmsg
		jmp	short .exit

.success:	mov	dx, byemsg
.exit:		mov	ah, 9
		int	21h
		mov	ah, 4Dh				; read errorlevel
		int	21h				; errorlevel => AL
		mov	ah, 4Ch				; exit
		int	21h

;------------------------------------------------------------------------------

int_handler:
		cmp	ah, 4Ah
		jne	.legacy
		push	ax

		; Fix free memory detection. Original program asks DOS to
		; allocate a memory block of size 7FFFh paragraphs (545272)
		; and compares returned maximum available block size found
		; in BX with 4D80h (317440). If the call succeeds, allocated
		; segment address in AX is taken as a maximum available block
		; size (which makes no sense!).
		;
		; The first problem here is that the programmer never expect
		; this call to succeed, so errorneous branch was never covered.
		; Instead of fixing the branch we will make sure the call
		; will always fail even under DOSBox.
		;
		; The second problem is that even if the call has failed,
		; returned maximum available block size value is treated as
		; a signed value which it's not, so we need to fix this as
		; well.
		mov	byte [192h], 0FFh	; 7FFFh => FFFFh
		mov	byte [1A3h], 73h	; jge => jae

		; Disable copy protection.
		mov	word [42ECh], 9090h
		mov	word [42FDh], 9090h
		mov	word [4319h], 9090h
		mov	word [432Ah], 9090h
		mov	word [433Eh], 9090h
		mov	word [4340h], 9090h
		mov	word [4343h], 9090h
		mov	word [4345h], 9090h
		mov	word [459Ch], 9090h
		mov	word [459Eh], 9090h
		mov	word [45A3h], 9090h

		; Modified patch from NewRisingSun that fixes AT keyboard.
		mov	word [9932h], 0CEBh
		mov	word [9940h], 00B4h
		mov	byte [9943h], 16h

		push	dx
		call	uninstall	; restore original vector of int 21h
		pop	dx

		pop	ax
.legacy:	jmp	far [cs:int21]

;------------------------------------------------------------------------------

uninstall:
		push	ds
		lds	dx, [cs:int21]
		mov	ax, 2521h
		int	21h
		pop	ds
		ret

;------------------------------------------------------------------------------

errmsg		db	"Unable to exec original "
exe		db	"calgames.exe",0,"$"


section .bss follows=.text nobits

__bss		equ	$
int21		res_fptr
parmblk		resw	1				; environment seg
cmdtail		res_fptr				; cmd tail
		resd	1				; first FCB address
		resd	1				; second FCB address
__bss_size	equ	$-__bss


section .stack align=16 follows=.bss nobits

		resb	(STACK_SZ+15) & ~15		; make sure __stktop
__stktop	equ	$				; is on segment boundary
