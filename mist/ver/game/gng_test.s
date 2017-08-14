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
;	BSR FILL_LONGSTR
	LBSR FILL_HEXSTR
	BSR APPLY_ATTR
	LDU #$BABE

;	BSR SHOW_CRC

FIN:
	LDA	$3001
	BITA #$20
	BEQ	JUEGO
;	LDX	#$2042
;	BSR	SHOW_JOY
;	LDA	$3002
;	LDX	#$2062
;	BSR	SHOW_JOY	
	BRA FIN
JUEGO:
	ORCC #$10
	LDA	#$80
	STA	$3E00	; BANK, clears start-up bank. This will cause a reset

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

APPLY_ATTR:
	LDX #$2400
	CLRA
	CLRB
@L:	CMPA #3
	BLE	@L2
	CLRA
@L2:STA ,X+
	INCB
	CMPB #$10
	BNE @L2
	CLRB
	INCA
	CMPX #$2800
	BLE @L
	RTS

; Fills the screen using the LONGSTR data
FILL_LONGSTR:
	LDX #$2000
	LDU #$2400
	LDY	#LONGSTR
@L: LDA ,Y+
	BEQ @L3
	STA ,X+
	ANDA #1
	STA ,U+
	BRA @L
@L3:
	CMPX #$2400
	BGT @L4
	LDY #LONGSTR
	BRA @L
@L4:
	RTS

SHOW_CRC:
	; Read CRC
	LDA	$3005
	LDX #$2120
	BSR	HEX2CHAR
	LDA	$3006
	BSR	HEX2CHAR
	LDA	$3007
	BSR	HEX2CHAR
	LDA	$3008
	BSR	HEX2CHAR
	RTS

HEX2CHAR:
	TFR A,B
	LSRA
	LSRA
	LSRA
	LSRA
	BSR HEX4CHAR
	TFR B,A
	ANDA #15
	BRA HEX4CHAR

HEX4CHAR:
	CMPA #10
	BLT	@L
	ADDA #55
	STA	,X+
	RTS
@L:
	ADDA #48
	STA	,X+
	RTS

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
FILL_HEXSTR:
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

LONGSTR:
	.STRZ "0 12 34 56 78 9A B C D E F G H I J K L M N O P Q R S T U V X Y Z"

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
	; CC=0 red tones, RG
	LDA #$00
	STA ,X+
	LDA #$50
	STA ,X+
	LDA #$A0
	STA ,X+
	LDA #$F0
	STA ,X+
	; CC=0, B
	CLRA
	STA ,Y+
	STA ,Y+	
	STA ,Y+	
	STA ,Y+	
	; CC=1 green tones, RG
	LDA #$00
	STA ,X+
	LDA #$05
	STA ,X+
	LDA #$0A
	STA ,X+
	LDA #$0F
	STA ,X+
	; CC=1, B
	CLRA
	STA ,Y+
	STA ,Y+
	STA ,Y+
	STA ,Y+

	; CC=2 blue tones, RG
	CLRA
	STA ,X+
	STA ,X+
	STA ,X+
	STA ,X+
	; CC=2, B
	LDA #$00
	STA ,Y+
	LDA #$55
	STA ,Y+
	LDA #$AA
	STA ,Y+
	LDA #$FF
	STA ,Y+

	; CC=3 gray tones, RG
	LDA #$00
	STA ,X+
	STA ,Y+
	LDA #$55
	STA ,X+
	STA ,Y+
	LDA #$AA
	STA ,X+
	STA ,Y+
	LDA #$FF
	STA ,X+
	STA ,Y+

	; CC=4 mixed colours, RG
	LDA #$00
	STA ,X+
	LDA #$0A
	STA ,X+
	LDA #$A0
	STA ,X+
	LDA #$FF
	STA ,X+
	; CC=1, B
	LDA #$00
	STA ,Y+
	LDA #$AA
	STA ,Y+
	LDA #$AA
	STA ,Y+
	LDA #$FF
	STA ,Y+	

	CLR $1000
	RTI

	FILL $FF,$1FF8-*

	ORG $1FF8
	.DW IRQSERVICE
	FILL $FF,$1FFE-*
	ORG $1FFE
	.DW	0000	; Reset vector
