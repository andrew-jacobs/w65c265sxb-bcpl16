;===============================================================================
;
; `7MM"""Yp,   .g8"""bgd `7MM"""Mq.`7MMF'
;   MM	  Yb .dP'     `M   MM	`MM. MM
;   MM	  dP dM'       `   MM	,M9  MM
;   MM"""bg. MM		   MMmmdM9   MM
;   MM	  `Y MM.	   MM	     MM	     ,
;   MM	  ,9 `Mb.     ,'   MM	     MM	    ,M
; .JMMmmmd9    `"bmmmd'	 .JMML.	   .JMMmmmmMMM
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
;===============================================================================
; Notes:
;
; Timer2 is used to time 1mSec periods
; Timer3 is used for 9600 baud
; Timer4 is used for xxxx baud
; UART3 to communicate with the console
; UART2 to communicate with the CH376S module
;
;-------------------------------------------------------------------------------

		.65816

		.include "w65c265.inc"
		.include "w65c265sxb.inc"

;===============================================================================
; Constants
;-------------------------------------------------------------------------------

; ASCII Control Characters

NUL		.equ	$00
BEL		.equ	$07
BS		.equ	$08
LF		.equ	$0a
CR		.equ	$0d
DEL		.equ	$7f

;

T2_HZ		.equ	1000
T2_COUNT	.equ	OSC_FREQ / (16 * T2_HZ)

BRG_9600	.equ	OSC_FREQ / (16 * 9600) - 1

; The starting addresses of the data memory area using (/CS7)

MEML		.equ	$c00000		; Lo byte
MEMH		.equ	$c10000		; Hi byte

; CH376S USB Interface Commands

SET_BAUDRATE	.equ	$02
ENTER_SLEEP	.equ	$03
RESET_ALL	.equ	$05
CHECK_EXIST	.equ	$06
SET_USB_MODE	.equ	$15
GET_STATUS	.equ	$22
RD_USB_DATA0	.equ	$27
DISK_CONNECT	.equ	$30
DISK_MOUNT	.equ	$31

SET_FILE_NAME	.equ	$aa		; FIX

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

		.page0
		.org	$00
		
TICK		.space	2

ACCA		.space	2
ACCB		.space	2

G		.space	2
C		.space	2
P		.space	2

W		.space	2

FI		.space	2
FO		.space	2

CMDL		.space	1		; The command line length
ARGC		.space	1		; The number of command line tokens
ARGV		.space	31		; The offset to each token

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
		sei				; Disable interrupts and
		emulate				; .. return to 8-bit mode
		ldx	#$ff			; Reset the stack
		txs

; Reset Hardware
		stz	TER
		stz	TIER
		stz	EIER
		stz	UIER
		
		lda	#<T2_COUNT		; Set T2 for 1mSec
		sta	T2CL
		lda	#>T2_COUNT
		sta	T2CH

		lda	#%11110000		; Set UARTs to use timer 3
		trb	TCR
		lda	#<BRG_9600		; And set baud rate
		sta	T3CL
		lda	#>BRG_9600
		sta	T3CH

		lda	#(1<<2)|(1<<3)		; Enable timers 2 & 3
		tsb	TER

		lda	#%00100101		; Set UART3 & 2 for 8-N-1
		sta	ACSR3
		sta	ACSR2

		native				; Go 16-bit
		long_i				; .. with long X/Y
		
		stz	TICK
		jsr	NewLine
		ldx	#BOOT_STRING
		jsr	Print

;-------------------------------------------------------------------------------
; Mount Disk

		lda	#$06			; USB-HOST with SOF
		jsr	SetUsbMode
		jsr	DiskConnect		; Try to connect
		cmp	#$14
		if eq
		 jsr	DiskMount
		 jsr	ReadUsbData
		else
		 ldx	#NODISK_STRING
		 jsr	Print
		endif

;-------------------------------------------------------------------------------
; Read Command

NewCommand:
		ldx	#PROMPT_STRING		; Display command prompt
		jsr	Print
		ldx	#0			; Empty the buffer
		repeat
		
	lda #2
	jsr DiskRx
	if cc
	 pha
	 lda	#'['
	 jsr	UartTx
	 pla
	 jsr	Hex2
	 lda	#']'
	 jsr	UartTx
	endif
		 jsr	UartRx			; Wait for a character
		 cmp	#CR			; End of entry?
		 break eq			; Yes

		 cmp	#DEL			; Convert DEL into BS
		 if eq
		  lda	#BS
		 endif

		 cmp	#BS			; Delete last character?
		 if eq
		  cpx	#0			; Anything in the buffer?
		  if ne
		   dex				; Reduce the command length
		   pha				; Erase the last character
		   jsr	UartTx
		   lda	#' '
		   jsr	UartTx
		   pla
		   jsr	UartTx
		   continue			; And try again
		  endif
		 endif
		
		 cmp 	#' '			; Printable character?
		 if cs
		  sta	COMMAND,x		; Yes, save in buffer 
		  inx
		  jsr	UartTx			; .. and echo to user
		 else
		  lda	#BEL			; Otherwise ring the 
		  jsr	UartTx			; .. terminal bell
		 endif		
		forever
		stz	COMMAND+0,x		; Terminate the buffer
		stz	COMMAND+1,x

;-------------------------------------------------------------------------------
; Tokenise the command buffer

		ldx	#0			; Reset buffer index
		txy				; And next token
		
		repeat
		 repeat				; Skip over leading spaces
		  lda	COMMAND,x
		  cmp	#' '
		  break ne
		  inx
		 forever
		 
		 cmp	#NUL			; End of command?
		 break eq			; Yes
		 
		 txa				; Save starting index
		 sta	ARGV,y
		 iny
		 repeat
		  inx
		  lda	COMMAND,x
		  beq	.Done
		  cmp	#' '
		 until eq
		 stz	COMMAND,x
		 inx
		forever
.Done:		tya				; Save number of tokens
		sta	ARGC
		
	jsr	Hex2
	jsr	NewLine
	
	repeat
	 cpy	#0			; Any tokens left?
	 break	eq			; No
	 dey
	 tya
	 jsr	Hex2
	 lda	#':'
	 jsr	UartTx
	 lda	ARGV,y
	 tax
	 repeat
	  lda	COMMAND,x
	  break eq
	  inx
	  jsr	UartTx
	 forever
	 lda	#':'
	 jsr	UartTx
	 jsr	NewLine
	forever
	
		jmp	NewCommand
;-------------------------------------------------------------------------------
		
		
		repeat
		 lda	#100
		 jsr	DiskRx
		 if cc
		  jsr	Hex2
		 else
		  lda	#'.'
		  jsr	UartTx
		 endif
		forever

		brk


; Load Target


Hex2:
		pha
		lsr	a
		lsr	a
		lsr	a
		lsr	a
		jsr	Hex
		pla
Hex:
		and	#$0f
		ora	#'0'
		cmp	#'9'+1
		if	cs
		 adc	#6
		endif
		jmp	UartTx

;===============================================================================
; INTCODE Interpreter
;-------------------------------------------------------------------------------

;	 15  14	 13  12	 11  10	 9   8	 7   6	 5   4	 3   2	 1   0
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;   +0	|  Opcode   | I | P | G | X |	    Operand (when X = 0)	|
;	+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
;   +1	|		      Operand (when X = 1)			|
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

		bra	$		; FIX: Invalid function

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
		jmp	Step

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
; FINISH

Function22:
		bra	$		; FIX: Exit

;-------------------------------------------------------------------------------
; SWITCHON

Function23:
		jmp	Step

;-------------------------------------------------------------------------------
; FI = A-1 SELECTINPUT

Function24:
		lda	ACCA
		dec	a
		sta	FI
		jmp	Step

;-------------------------------------------------------------------------------
; FO = A-1 SELECTOUTPUT

Function25:
		lda	ACCA
		dec	a
		sta	FO
		jmp	Step

;-------------------------------------------------------------------------------
; Read a byte RDCH

Function26:
		jmp	Step

;-------------------------------------------------------------------------------
; Write a byte WRCH

Function27:
		jmp	Step

;-------------------------------------------------------------------------------
; Open for read FINDINPUT

Function28:
		jmp	Step

;-------------------------------------------------------------------------------
; Open for write FINDOUTPUT

Function29:
		jmp	Step

;-------------------------------------------------------------------------------
; Stop

Function30:
		jmp	Step

;-------------------------------------------------------------------------------
; A = M[P] LEVEL

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
; P,C = A,B LONGJUMP

Function32:
		lda	ACCA
		sta	P
		lda	ACCB
		sta	C
		jmp	Step

;-------------------------------------------------------------------------------
; ENDREAD

Function33:
		jmp	Step

;-------------------------------------------------------------------------------
; ENDWRITE

Function34:
		jmp	Step

;-------------------------------------------------------------------------------
; APTOVEC

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
; A = FI+1 INPUT

Function38:
		lda	FI
		inc	a
		sta	ACCA
		jmp	Step

;-------------------------------------------------------------------------------
; A = FO+1 OUTPUT

Function39:
		lda	FO
		inc	a
		sta	ACCA
		jmp	Step

; 40 UNRDCH
; 41 REWIND
		
;===============================================================================
; CH376S Module Interface
;-------------------------------------------------------------------------------

		.longa	off
SetUsbMode:
		pha
		lda	#SET_USB_MODE
		jsr	SendCommand
		pla
		jsr	DiskTx
		brl	ReadStatus
		
		.longa	off
DiskConnect:
		lda	#DISK_CONNECT
		jsr	SendCommand
		brl	ReadStatus
		
		
		.longa	off
DiskMount:
		lda	#DISK_MOUNT
		jsr	SendCommand
		phx
		ldx	#20
		repeat
		 lda	#200
		 jsr	DiskRx
		 break cc
	lda #'.'
	jsr UartTx
		 dex
		 if eq
		  plx
		  sec
		  rts
		 endif
		forever
	pha
	lda 	#'('
	jsr	UartTx
	pla
	jsr	Hex2
	lda 	#')'
	jsr	UartTx
		plx
		clc
		rts
		;bra	ReadStatus
		

		.longa	off
ReadUsbData:
		lda	#RD_USB_DATA0
		jsr	SendCommand
	lda 	#'{'
	jsr	UartTx
		repeat
		 lda	#100
		 jsr	DiskRx
		until cs
	lda	#'}'
	jsr	UartTx
		rts

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
		bra	ReadStatus


; Transmit the command synchronisation prefix to the CH376 followed by the
; command code.

		.longa	off
SendCommand:
		pha			; Save the command
	lda 	#'{'
	jsr	UartTx
		repeat
		 lda	#2
		 jsr	DiskRx
		 break cs
		 jsr	Hex2
		forever
	lda	#'}'
	jsr	UartTx
		lda	#$57		; Send the prefix
		jsr	DiskTx
		lda	#$ab
		jsr	DiskTx
		pla			; Recover command
		jmp	DiskTx		; And send

;
		.longa	off
ReadStatus:
		lda	#10
		jsr	DiskRx
	pha
	jsr	Hex2
	pla
		rts
		

;===============================================================================
; UART Interfaces
;-------------------------------------------------------------------------------

; Use UART3 to communicate with the console
; Use UART2 to communicate with the CH376S module

		.longa	off
UartTx:
		pha
		lda	#1<<7
		repeat
		 bit	UIFR
		until	ne
		pla
		sta	ARTD3
		rts

		.longa	off
UartRx:
		lda	#1<<6
		repeat
		 bit	UIFR
		until	ne
		lda	ARTD3
		rts
		
		.longi	on
NewLine:
		ldx	#CRLF_STRING
		
Print:
		repeat
		 lda	!0,x
		 break	eq
		 jsr	UartTx
		 inx
		forever
		rts

;-------------------------------------------------------------------------------

		.longa	off
DiskTx:
		pha
		lda	#1<<5
		repeat
		 bit	UIFR
		until	ne
		pla
		sta	ARTD2
	jmp	Hex2
		rts

; Read a character from the Disk input serial line waiting at most A mSecs
; for something to arrive. If C = 0 then A contains the character. If C = 1 then
; a timeout occurred.

		.longa	off
DiskRx:
		repeat
		 pha			; Save the timeout count
		 lda	#1<<2		; Clear timer2 interrupt flag
		 tsb	TIFR
		 repeat
		  lda	#1<<4		; Has some data arrived?
		  bit	UIFR
		  if ne
		   pla			; Yes, drop the timeout count
		   lda	ARTD2		; Fetch the serial data
		   clc			; Indicate data read
		   rts			; Done.
		  endif
		  lda	#1<<2		; Has T2 rolled over?
		  bit	TIFR
		 until ne
		 pla
		 dec	a
		until eq
		sec			; Indicate timeout
		rts			; Done.

;===============================================================================
;-------------------------------------------------------------------------------

BOOT_STRING	.byte	CR,LF,"W65C265SXB BCPL [18.03]"
CRLF_STRING	.byte	CR,LF,NUL
PROMPT_STRING	.byte	CR,LF,"$ ",NUL
NODISK_STRING	.byte	CR,LF,"No disk",NUL


;		.org	$fffc
;		.word	RESET

		.end
