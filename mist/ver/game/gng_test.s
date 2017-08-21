	ORG $0

SCR_PALRAM	EQU $3800
CHR_PALRAM	EQU $38C0
HPOS_LOW	EQU $3B08
HPOS_HIGH	EQU $3B09
VPOS_LOW	EQU $3B0A
VPOS_HIGH	EQU $3B0B
BANK		EQU $3E00
FLIP		EQU $3D00
JOY1		EQU $3001
JOY2		EQU $3002
CRC			EQU $3005

CHR			EQU $2000
CHR_ATT		EQU $2400
SCR			EQU $2800
SCR_ATT		EQU $2C00

FLIPVAR		EQU $1010

RESET: 
	ORCC #$10
	LDS	#$1E00-1
	CLRA
	STA	BANK
	LDA #1
	STA FLIP
	CLRA
	STA FLIPVAR
	CLRA
	STA HPOS_LOW
	STA HPOS_HIGH
	STA VPOS_LOW
	STA VPOS_HIGH

	; primero la paleta
	LDA #1
	STA $1000	; FLAG
	ANDCC #$EF
@L:	LDA $1000
	CMPA #1
	BEQ @L

	LBSR TEST_SCR_TFR

	;LBSR CHKSCR
	;LBSR CHKCHAR

	;LBSR TEST_CHARPAL
	;LBSR CLRCHAR
	;LBSR FILLSCR
	;LBSR FILL_ALLCHAR
	;LBSR CLRSCR
	;LBSR TEST_SCRPAL

	LDU #$DEAD
;	BSR FILL_LONGSTR
;	LBSR FILL_HEXSTR
;	LBSR FILL_CORNERS
;	BSR APPLY_ATTR
	LDU #$BABE

;	BSR SHOW_CRC

FIN:
	LDA	JOY1
	BITA #$20
	BEQ	JUEGO
	BITA #$10
	BEQ TOGGLE_FLIP
;	LDX	#$2042
;	BSR	SHOW_JOY
;	LDA	JOY2
;	LDX	#$2062
;	BSR	SHOW_JOY	
	BRA FIN
TOGGLE_FLIP:
	LDA FLIPVAR
	INCA
	STA FLIP
	STA FLIPVAR
	BRA FIN
	BRA FIN
JUEGO:
	ORCC #$10
	LDA	#$80
	STA	$3E00	; BANK, clears start-up bank. This will cause a reset

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FILL_CORNERS: ; Simulates in 2 frames use -frames 1
	; External corners
	LDA #'A'
	STA $2000
	LDA #'B'
	STA $201F
	LDA #'C'
	STA $23D0
	LDA #'D'
	STA $23FF
	; Internal corners
	LDA #'A'
	STA $2104
	LDA #'B'
	STA $210C
	LDA #'C'
	STA $22D4
	LDA #'D'
	STA $22FC
	; Central corners
	LDA #'A'
	STA $2146
	LDA #'B'
	STA $214A
	LDA #'C'
	STA $2156
	LDA #'D'
	STA $215A
	RTS

;*************************************************
; FILLS WITH ALL Characters
FILL_ALLCHAR:
	CLRA
	LDB #3
	LDX #CHR
@L:
	STA ,X
	ADDA #1
	BCC @L2
	ADDB #$40
@L2:
	STB $400,X
	LEAX 1,X
	CMPX #(CHR+$400)
	BLT @L
	RTS




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
	LDA	CRC
	LDX #$2120
	BSR	HEX2CHAR
	LDA	CRC+1
	BSR	HEX2CHAR
	LDA	CRC+2
	BSR	HEX2CHAR
	LDA	CRC+3
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
; Write BLANK scroll tiles over all screen
; with 0 attributes
CLRSCR:
	LDX #SCR
	LDY #SCR_ATT
	CLRB
@L:	
	STB ,X+
	STB ,Y+
	CMPX #SCR_ATT
	BNE @L
	RTS

; *****************************************
; Fills scroll tiles over all screen
; with 0 attributes
FILLSCR:
	LDX #SCR
	LDY #SCR_ATT
	CLRB
	CLRA
@L:	
	STA ,X+
	INCA
	STB ,Y+
	CMPX #SCR_ATT
	BNE @L

	CLRB
	CLRA
@L2:
	STA ,X+
	INCB
	CMPB #$10
	BNE @L2
	INCA
	CMPX #(SCR_ATT+$400)
	BLT @L2

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
	LDX #$2120
	LDY #CHAR_MAL
@L2:	
	LDA ,Y+
	BEQ @MAL
	STA ,X+
	BRA @L2

; *****************************************
; Verify R/W on character memory
CHKSCR:
	LDU #$BABE
	LDX #SCR
	CLRA
@L:	
	STA ,X
	CMPA ,X+
	BNE @MAL
	ADDA #$11
	CMPX #(SCR+$800)
	BNE @L
	LDU #$FACE
	RTS
@MAL:
	LDU #$DEAD
	LDX #$2120
	LDY #SCR_MAL
@L2:	
	LDA ,Y+
	BEQ @MAL
	STA ,X+
	BRA @L2

;********************************************
; Test character colour assignment
TEST_CHARPAL:
	LDX #CHR
	LDY #RGBSTR
@L4:
	LDA ,Y
	BNE @L3
	CMPX #(CHR+$400)
	BGE @L5
	LDY #RGBSTR
	LDA ,Y
@L3:
	STA ,X
	LDA 5,Y
	STA $400,X
	LEAX 1,X
	LEAY 1,Y
	BRA @L4
@L5:
	RTS

;********************************************
; Test scroll colour assignment
TEST_SCRPAL:
	LDX #SCR
	LDY #RGBSTR
@L4:
	LDA ,Y
	BNE @L3
	CMPX #(SCR+$400)
	BGE @L5
	LDY #RGBSTR
	LDA ,Y
@L3:
	STA ,X
	LDA 5,Y
	STA $400,X
	LEAX 1,X
	LEAY 1,Y
	BRA @L4
@L5:
	RTS

RGBSTR:
	.STRZ "RGBW"
	FCB 0,1,2,3

;********************************************
; Fills in 3 scroll entries to verify data transfer
TEST_SCR_TFR:
	LDA #$1
	LDX #(SCR+$240)
	STA ,X
	LDA #$3F
	STA $400,X

	LDA #$50
	LDX #(SCR+$242)
	STA ,X
	LDA #$B9
	STA $400,X

	LDA #$0
	LDX #(SCR+$244)
	STA ,X
	LDA #$C2
	STA $400,X
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
CHAR_MAL:
	.STRZ "     bad char RAM"
SCR_MAL:
	.STRZ "     bad scroll RAM"

CHAR_PALETTE:
	; Characters. 16 palettes
	FDB $F000,$A000,$5000,$0000	; Red   tones
	FDB $0F00,$0A00,$0500,$0000	; Green tones
	FDB $00F0,$00A0,$0050,$0000	; Blue  tones
	FDB $FFF0,$AAA0,$5550,$0000	; Gray  tones

	FDB $F000,$A000,$5000,$0000	; Red   tones
	FDB $0F00,$0A00,$0500,$0000	; Green tones
	FDB $00F0,$00A0,$0050,$0000	; Blue  tones
	FDB $FFF0,$AAA0,$5550,$0000	; Gray  tones

	FDB $F000,$A000,$5000,$0000	; Red   tones
	FDB $0F00,$0A00,$0500,$0000	; Green tones
	FDB $00F0,$00A0,$0050,$0000	; Blue  tones
	FDB $FFF0,$AAA0,$5550,$0000	; Gray  tones

	FDB $F000,$A000,$5000,$0000	; Red   tones
	FDB $0F00,$0A00,$0500,$0000	; Green tones
	FDB $00F0,$00A0,$0050,$0000	; Blue  tones
	FDB $FFF0,$AAA0,$5550,$0000	; Gray  tones

; Scroll. 8 palettes
SCROLL_PALETTE:
	FDB $F000,$A000,$5000,$0000	; Red   tones
	FDB $0F00,$0A00,$0500,$0000	; Green tones
	FDB $00F0,$00A0,$0050,$0000	; Blue  tones
	FDB $FFF0,$AAA0,$5550,$0000	; Gray  tones

	FDB $F000,$A000,$5000,$0000	; Red   tones
	FDB $0F00,$0A00,$0500,$0000	; Green tones
	FDB $00F0,$00A0,$0050,$0000	; Blue  tones
	FDB $FFF0,$AAA0,$5550,$0000	; Gray  tones
OBJECT_PALETTE:

IRQSERVICE:
	; ORCC #$10
	; fill palette
	; RG mem test
	CLRA	; Is the palette already filled?
	CMPA $1000
	BNE @DOWORK
	RTI		
@DOWORK:
	LDX #CHR_PALRAM
	LDY #CHAR_PALETTE	
@L:	LDD ,Y++
	STA ,X
	STB $100,X
	LEAX 1,X
	CMPY #SCROLL_PALETTE
	BNE @L

	LDX #SCR_PALRAM
	LDY #SCROLL_PALETTE	
@L2:
	LDD ,Y++
	STA ,X
	STB $100,X
	LEAX 1,X
	CMPY #OBJECT_PALETTE
	BNE @L2

	CLR $1000
	RTI

	FILL $FF,$1FF8-*

	ORG $1FF8
	.DW IRQSERVICE
	FILL $FF,$1FFE-*
	ORG $1FFE
	.DW	0000	; Reset vector
