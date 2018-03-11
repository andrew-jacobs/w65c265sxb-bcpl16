;===============================================================================
;-------------------------------------------------------------------------------



		.65816

short_a		.macro
		.longa	off
		sep	#$20
		.endm


long_a		.macro
		.longa	on
		rep	#$20
		.endm

MEML		.equ	$c00000
MEMH		.equ	$c10000


		.page0
		.org	$00

ACCA		.space	2
ACCB		.space	2

G		.space	2
C		.space	2
P		.space	2

W		.space	2
;D		.space	2


		.code
		.org	$0400


;===============================================================================

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

		jmp	(Function,x)
Function:
		.word	Function0
		
		
Function0:


		.end