	ORG $0

RESET: 
	ORCC #$10
	LDS	#$1E00-1
	ANDCC #$EF
	CLRA
	STA	$3E00	; BANK
	STA $3D00	; FLIP

	LDA #1
	STA $1000	; FLAG
@L:	LDA $1000
	CMPA #1
	BEQ @L

	; BSR CLRCHAR
	BSR CHKCHAR

	; Hello world
	LDX #$2000
	LDY #HELLO
@L: LDA ,Y+
	BNE @L2
	LDY #HELLO
	LDA ,Y+
@L2:
	STA ,X+
	CMPX #$2400
	BEQ @L3
	BRA @L
@L3:


@L:	BRA @L

MAL: LDU #1
	BRA MAL

; *****************************************
; Write BLANK character over all screen
; with 0 attributes
CLRCHAR:
	; CHAR filling
	LDX #$2000
	LDY #$2400
	LDA #' '
	CLRB
@L:	
	STA ,X+
	STB ,Y+
	CMPY #$2800
	BNE @L
	RTS

; *****************************************
; Verify R/W on character memory
CHKCHAR:
	LDU #$BABE
	LDX #$2000
	LDY #$5555
@L:	
	TFR Y,D
	STD ,X	
	SUBD ,X++
	BNE @MAL
	CMPX #$2800
	BNE @L
	LDU #$FACE
	RTS
@MAL:
	LDU #$DEAD
	RTS

HELLO:
	.STRZ "0123456789ABCDEF"

IRQSERVICE:
	; ORCC #$10
	; fill palette
	; RG mem test
	LDX #$3800
	LDY #$3900
	CLRA
	CLRB	
@L:	STD ,X++
	STD ,Y++
	CMPX #$3900
	BNE @L

	; Character colours
	LDX #$38C0	
	LDY #$39C0
	CLRA
	LDB #4
@L:
	STA ,Y+
	STA ,X+
	ADDA #$11
	DECB
	BNE @L
	CLR $1000
	RTI

	FILL $FF,$1FF8-*

	ORG $1FF8
	.DW IRQSERVICE
	FILL $FF,$1FFE-*
	ORG $1FFE
	.DW	0000	; Reset vector
