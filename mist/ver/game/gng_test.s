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

	; CHAR filling
	LDU #0
	LDX #$2000
	LDY #$2400
	LDA #' '
	CLRB
@L:	
	STB ,Y+
	STA ,X+
	CMPX #$2400
	BNE @L

	; Hello world
	LDX #$2100
	LDY #HELLO
@L: LDA ,Y+
	BEQ @L2
	STA ,X+
	BRA @L
@L2:
	NOP


@L:	BRA @L

MAL: LDU #1
	BRA MAL

HELLO:
	.STRZ "HELLO WORLD. FROM Ghost N Goblins in MiST."

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
