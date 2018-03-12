;===============================================================================
;
; `7MM"""Yp,   .g8"""bgd `7MM"""Mq.`7MMF'
;   MM    Yb .dP'     `M   MM   `MM. MM
;   MM    dP dM'       `   MM   ,M9  MM
;   MM"""bg. MM            MMmmdM9   MM
;   MM    `Y MM.           MM        MM      ,
;   MM    ,9 `Mb.     ,'   MM        MM     ,M
; .JMMmmmd9    `"bmmmd'  .JMML.    .JMMmmmmMMM
;
; BCPL for the WDC W65C265SXB
;-------------------------------------------------------------------------------
; Copyright (C),2018 Andrew John Jacobs.
; All rights reserved.
;
; This work is licensed under a Creative Commons Attribution NonCommercial-
; ShareAlike 4.0 International License.
;
; See here for details:
;
;	https://creativecommons.org/licenses/by-nc-sa/4.0/
;
;-------------------------------------------------------------------------------

		.65816

;===============================================================================
; Macros
;-------------------------------------------------------------------------------

short_a		.macro
		.longa	off
		sep	#$20
		.endm

short_i		.macro
		.longa	off
		sep	#$10
		.endm

short_ai	.macro
		.longa	off
		sep	#$30
		.endm

long_a		.macro
		.longa	on
		rep	#$20
		.endm

long_i		.macro
		.longa	on
		rep	#$10
		.endm

long_ai		.macro
		.longa	on
		rep	#$30
		.endm

;===============================================================================
; Constants
;-------------------------------------------------------------------------------

; The starting addresses of the data memory area using (/CS7)

MEML		.equ	$c00000		; Lo byte
MEMH		.equ	$c10000		; Hi byte

; CH376S USB Interface Commands

SET_BAUDRATE	.equ	$02
ENTER_SLEEP	.equ	$03
RESET_ALL	.equ	$05
CHECK_EXIST	.equ	$06
GET_STATUS	.equ	$22

SET_FILE_NAME	.equ	$aa		; FIX

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

		.page0
		.org	$00

ACCA		.space	2
ACCB		.space	2

G		.space	2
C		.space	2
P		.space	2

W		.space	2

FI		.space	2
FO		.space	2

;-------------------------------------------------------------------------------

		.bss
		.org	$0200

COMMAND		.space	256

;===============================================================================
;-------------------------------------------------------------------------------

		.code
		.org	$0400

		.longa	off
		.longi	off
RESET:
		sei
		sec
		xce

		ldx	#$ff
		txs

; Reset Hardware

		clc
		xce
		long_i


; Mount Disk

; Read Command

; Load Target


;===============================================================================
; INTCODE Interpreter
;-------------------------------------------------------------------------------

;	 15  14  13  12  11  10  9   8   7   6   5   4   3   2   1   0
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;   +0  |  Opcode   | I | P | G | X |       Operand (when X = 0)        |
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;   +1  |                     Operand (when X = 1)                      |
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+

		.longa	on
		.longi	on

		stz	ACCA
		stz	ACCB

		stz	FO
		stz	FO
		inc	FO

Step:
		ldx	C		; Fetch the next instruction
		short_a
		lda	>MEMH,x
		xba
		lda	>MEML,x
		long_a
		inx
		sta	W

		bit	#$0200		; Short operand?
		if eq			; Yes, extract from instruction
		 and	#$01ff
		 tay
		else
		 short_a		; No, fetch from next word
		 lda	>MEMH,x
		 xba
		 lda	>MEML,x
		 long_a
		 inx
		 tay			; Save in Y
		endif
		stx	C		; Update program counter

		lda	W
		bit	#$0800		; Relative to stack?
		if ne
		 clc
		 tya
		 adc	P
		 tay
		else
		 bit	#$0400		; Relative to global vector?
		 if ne
		  clc
		  tya
		  adc	G
		  tay
		 endif
		endif

		lda	W
		bit	#$1000		; Indirect memory address?
		if ne
		 tyx			; Yes, look up address
		 short_a
		 lda	>MEMH,x
		 xba
		 lda	>MEML,x
		 long_a
		 tay			; And save in Y
		endif

		lda	W		; Extract opcode
		and	#$e000
		xba
		lsr	a
		lsr	a
		lsr	a
		lsr	a
		tax
		jmp	(Opcode,x)
Opcode:
		.word	OpcodeL
		.word	OpcodeS
		.word	OpcodeA
		.word	OpcodeJ
		.word	OpcodeT
		.word	OpcodeF
		.word	OpcodeK
		.word	OpcodeX

;-------------------------------------------------------------------------------
; Memory Load

OpcodeL:
		lda	ACCA		; Transfer A into B
		sta	ACCB
		tyx			; Load from M[D]
		short_a
		lda	>MEMH,x
		xba
		lda	>MEML,x
		long_a
		sta	ACCA		; Save in A
		jmp	Step

;-------------------------------------------------------------------------------
; Memory Store

OpcodeS:
		lda	ACCA
		tyx
		short_a
		sta	>MEML,x
		xba
		sta	>MEMH,x
		long_a
		jmp	Step

;-------------------------------------------------------------------------------
; Addition

OpcodeA:
		clc
		tya
		adc	ACCA
		sta	ACCA
		jmp	Step

;-------------------------------------------------------------------------------
; Unconditional Jump

OpcodeJ:
		sty	C
		jmp	Step

;-------------------------------------------------------------------------------
; Jump if True

OpcodeT:
		lda	ACCA
		if ne
		 sty	C
		endif
		jmp	Step

;-------------------------------------------------------------------------------
; Jump if False

OpcodeF:
		lda	ACCA
		if eq
		 sty	C
		endif
		jmp	Step

;-------------------------------------------------------------------------------
; Call

OpcodeK:

		jmp	Step

;-------------------------------------------------------------------------------
; Execute Function

OpcodeX:
		tya			; Get function index
		if ne			; Not zero?
		 cmp	#40		; .. but less than 40?
		 if cc
		  dec	a		; Scale to jump table index
		  asl	a
		  tax
		  jmp	(Function,x)	; And goto to handler
		 endif
		endif

		bra 	$		; FIX: Invalid function

Function:
		.word	Function1
		.word	Function2
		.word	Function3
		.word	Function4
		.word	Function5
		.word	Function6
		.word	Function7
		.word	Function8
		.word	Function9
		.word	Function10
		.word	Function11
		.word	Function12
		.word	Function13
		.word	Function14
		.word	Function15
		.word	Function16
		.word	Function17
		.word	Function18
		.word	Function19
		.word	Function20
		.word	Function21
		.word	Function22
		.word	Function23
		.word	Function24
		.word	Function25
		.word	Function26
		.word	Function27
		.word	Function28
		.word	Function29
		.word	Function30
		.word	Function31
		.word	Function32
		.word	Function33
		.word	Function34
		.word	Function35
		.word	Function36
		.word	Function37
		.word	Function38
		.word	Function39

;-------------------------------------------------------------------------------
; A = M[A]

Function1:
		ldx	ACCA		; Fetch memory address
		short_a
		lda	>MEMH,x		; Recover the value
		xba
		lda	>MEML,x
		long_a
		sta	ACCA		; And store
		jmp	Step		; Done.

;-------------------------------------------------------------------------------
; A = -A

Function2:
		sec
		lda	#0		; Subtract A from zero
		sbc	ACCA
		sta	ACCA		; And store
		jmp	Step		; Done.

;-------------------------------------------------------------------------------
; A = ~A

Function3:
		lda	#$ffff		; Invert all bits in A
		eor	ACCA
		sta	ACCA		; And store
		jmp	Step		; Done.

;-------------------------------------------------------------------------------

Function4:
Function5:
Function6:
Function7:

;-------------------------------------------------------------------------------
; A = B + A

Function8:
		clc
		lda	ACCB
		adc	ACCA
		sta	ACCA
		jmp	Step

;-------------------------------------------------------------------------------
; A = B - A

Function9:
		sec
		lda	ACCB
		sbc	ACCA
		sta	ACCA
		jmp	Step

;-------------------------------------------------------------------------------
; A = (B == A)

Function10:
		lda	ACCA
		stz	ACCA
		cmp	ACCB
		if eq
		 dec	ACCA
		endif
		jmp	Step

;-------------------------------------------------------------------------------
; A = (B != A)

Function11:
		lda	ACCA
		stz	ACCA
		cmp	ACCB
		if ne
		 dec	ACCA
		endif
		jmp 	Step

;-------------------------------------------------------------------------------

Function12:
		jmp	Step

;-------------------------------------------------------------------------------

Function13:
		jmp	Step

;-------------------------------------------------------------------------------

Function14:
		jmp	Step

;-------------------------------------------------------------------------------

Function15:
		jmp	Step

;-------------------------------------------------------------------------------
; A = B << A

Function16:
		lda	ACCB
		ldx	ACCA
		if ne
		 cpx	#$16
		 if cs
		  stz	ACCA
		  jmp	Step
		 endif
		 repeat
		  asl	a
		  dex
		 until eq
		endif
		sta	ACCA
		jmp	Step

;-------------------------------------------------------------------------------
; A = B >> A

Function17:
		lda	ACCB
		ldx	ACCA
		if ne
		 cpx	#$16
		 if cs
		  stz	ACCA
		  jmp	Step
		 endif
		 repeat
		  lsr	a
		  dex
		 until eq
		endif
		sta	ACCA
		jmp	Step

;-------------------------------------------------------------------------------
; A = B & A

Function18:
		lda	ACCB
		and	ACCA
		sta	ACCA
		jmp	Step

;-------------------------------------------------------------------------------
; A = B | A

Function19:
		lda	ACCB
		ora	ACCA
		sta	ACCA
		jmp	Step

;-------------------------------------------------------------------------------
; A = B ^ A

Function20:
		lda	ACCB
		eor	ACCA
		sta	ACCA
		jmp	Step

;-------------------------------------------------------------------------------
; A = ~(B ^ A)

Function21:
		lda	ACCB
		eor	ACCA
		eor	#$ffff
		sta	ACCA
		jmp	Step

;-------------------------------------------------------------------------------

Function22:
		bra	$		; FIX: Exit

;-------------------------------------------------------------------------------

Function23:
		jmp	Step

;-------------------------------------------------------------------------------
; FI = A-1

Function24:
		lda	ACCA
		dec	a
		sta	FI
		jmp	Step

;-------------------------------------------------------------------------------
; FO = A-1

Function25:
		lda	ACCA
		dec	a
		sta	FO
		jmp	Step

;-------------------------------------------------------------------------------
; Read a byte

Function26:
		jmp	Step

;-------------------------------------------------------------------------------
; Write a byte

Function27:
		jmp	Step

;-------------------------------------------------------------------------------
; Open for read

Function28:
		jmp	Step

;-------------------------------------------------------------------------------
; Open for write

Function29:
		jmp	Step

;-------------------------------------------------------------------------------
; Stop

Function30:
		jmp	Step

;-------------------------------------------------------------------------------
; A = M[P]

Function31:
		ldx	P
		short_a
		lda	>MEMH,x
		xba
		lda	>MEML,x
		long_a
		sta	ACCA
		jmp	Step

;-------------------------------------------------------------------------------
; P,C = A,B

Function32:
		lda	ACCA
		sta	P
		lda	ACCB
		sta	C
		jmp	Step

;-------------------------------------------------------------------------------

Function33:
		jmp	Step

;-------------------------------------------------------------------------------

Function34:
		jmp	Step

;-------------------------------------------------------------------------------

Function35:
		jmp	Step

;-------------------------------------------------------------------------------
; GETBYTE (A,B)

Function36:
		lda	ACCB		; Work out byte offset
		lsr	a
		php			; Save carry
		clc			; Add base word address
		adc	ACCA
		tax			; Save in index register
		plp			; Pull back carry
		short_a
		if cc
		 lda	>MEMH,x		; Load from either high
		else
		 lda	>MEML,x		; .. or low byte
		endif
		long_a
		and	#$00ff		; Mask to byte value
		sta	ACCA		; And save
		jmp	Step		; Done

;-------------------------------------------------------------------------------
; PUTBYTE(A,B,M[P+4])

Function37:
		lda	ACCB		; Work out byte offset
		lsr	a
		php			; Save carry
		clc			; Add base word address
		adc	ACCA
		tay			; Save in index register
		ldx	P		; Fetch stack pointer
		plp			; Pull back carry
		short_a
		lda	>MEML+4,x	; Fetch byte to store
		tyx
		if cc
		 sta	>MEMH,x		; Save in either high
		else
		 sta	>MEML,x		; .. or low byte
		endif
		long_a
		jmp	Step		; Done.

;-------------------------------------------------------------------------------
; A = FI+1

Function38:
		lda	FI
		inc	a
		sta	ACCA
		jmp	Step

;-------------------------------------------------------------------------------
; A = FO+1

Function39:
		lda	FO
		inc	a
		sta	ACCA
		jmp	Step

;===============================================================================
; CH376S Module Interface
;-------------------------------------------------------------------------------


		.longa	off
SetFileName:
		lda	#SET_FILE_NAME	; Send command
		jsr	SendCommand
		repeat
		 lda	!0,x		; Followed by null terminated
		 php			; .. string
		 jsr	DiskTx
		 plp
		until eq
		jmp	ReadStatus


; Transmit the command synchronisation prefix to the CH376 followed by the
; command code.

		.longa	off
SendCommand:
		pha			; Save the command
		lda	#$57		; Send the prefix
		jsr	DiskTx
		lda	#$aa
		jsr	DiskTx
		pla			; Recover command
		jmp	DiskTx		; And send

;
		.longa	off
ReadStatus:
		rts

;===============================================================================
; UART Interfaces
;-------------------------------------------------------------------------------

UartTx:
		rts

UartRx:
		rts

;-------------------------------------------------------------------------------

DiskTx:
		rts

DiskRx:
		rts

		.org	$fffc
		.word	RESET

		.end
