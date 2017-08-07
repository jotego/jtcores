	ORG $0

RESET: 
	ORCC #$10
	LDS	#$1E00-1
	CLRA
	STA	$3E00	; BANK
	STA $3D00	; FLIP

	; BRA FIN
	LDA #1
	STA $1000	; FLAG
	ANDCC #$EF
@L:	LDA $1000
	CMPA #1
	BEQ @L

	LBSR CLRCHAR
	; BRA FIN
	; BSR CHKCHAR

	LDU #$DEAD
	; Hello world
	LDX #$2140
	LDU #$2540
	LDY	#HELLO
@L: LDA ,Y+
	BEQ @L3
	STA ,X+
	ANDA #1
	STA ,U+
	BRA @L
@L3:
	LDU #$BABE


FIN:
	LDA	$3001
	LDX	#$2042
	BSR	SHOW_JOY
	LDA	$3002
	LDX	#$2062
	BSR	SHOW_JOY
	BRA FIN

SHOW_JOY:
	LDY #6
SHOW_JOY_LOOP:
	LDB #'1'
	BITA #1
	BNE @L2
	LDB #'0'
@L2:
	STB ,X+
	LSRA
	LEAY ,-Y
	CMPY #0
	BNE SHOW_JOY_LOOP
	RTS

MAL: LDU #1
	BRA MAL

WRITECHARMEM:
	; Write to char memory
	LDA #$01
	STA $3F02 ; Row address
	CLRA
	STA $3F03
	; Col address
	CLRA
	STA $3F04	
	LDA #$20
	STA $3F05
	; Values
	LDY #$3F00
	LDX #$3F07
	LDA #$81
	LDB #$42
	STD ,Y
	CLR ,X
	INC $3F05

	LDA #$24
	LDB #$18
	STD ,Y
	CLR ,X
	INC $3F05

	LDA #$18
	LDB #$24
	STD ,Y
	CLR ,X
	INC $3F05

	LDA #$42
	LDB #$81
	STD ,Y
	CLR ,X
	INC $3F05
	RTS

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

;********************************************
; Fills all screen with hex numbers
FILLCHAR:
	LDX #$2000
	LDY #HEXSTR
@L: LDA ,Y+
	BNE @L2
	LDY #HEXSTR
	LDA ,Y+
@L2:
	STA ,X+
	CMPX #$2400
	BEQ @L3
	BRA @L
@L3:
	LDU #$BABE
	RTS

HEXSTR:
	.STRZ "0123456789ABCDEF"

HELLO:
	.STRZ "      hola mundo"

IRQSERVICE:
	; ORCC #$10
	; fill palette
	; RG mem test
	CLRA	; Is the palette already filled?
	CMPA $1000
	BNE @DOWORK
	RTI		
@DOWORK:
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
	; CC=0, RG
	LDA #$09
	STA ,X+
	LDA #$18
	STA ,X+
	LDA #$27
	STA ,X+
	LDA #$36
	STA ,X+
	; CC=0, B
	LDA #$A0
	STA ,Y+
	LDA #$B0
	STA ,Y+
	LDA #$C0
	STA ,Y+
	LDA #$D0
	STA ,Y+	
	; CC=1, RG
	LDA #$AB
	STA ,X+
	LDA #$BC
	STA ,X+
	LDA #$CD
	STA ,X+
	LDA #$DE
	STA ,X+
	; CC=0, B
	LDA #$10
	STA ,Y+
	LDA #$20
	STA ,Y+
	LDA #$30
	STA ,Y+
	LDA #$40
	STA ,Y+

	CLR $1000
	RTI

	FILL $FF,$1FF8-*

	ORG $1FF8
	.DW IRQSERVICE
	FILL $FF,$1FFE-*
	ORG $1FFE
	.DW	0000	; Reset vector
