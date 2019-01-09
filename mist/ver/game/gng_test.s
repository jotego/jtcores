	; load in last 8kB of ROM
	ORG $8000

SCR_PALRAM	EQU $3800
OBJ_PALRAM	EQU $3840
CHR_PALRAM	EQU $38C0
SND_LATCH	EQU	$3A00
HPOS_LOW	EQU $3B08
HPOS_HIGH	EQU $3B09
VPOS_LOW	EQU $3B0A
VPOS_HIGH	EQU $3B0B
OKOUT		EQU $3C00
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
PAL_STATUS	EQU $0

RESET: 
	ORCC #$10
	LDS	#$1E00-1
	LDA #$18
	TFR A,DP
	CLRA
	STA	BANK
	LDA #0
	STA FLIP
	CLRA
	STA FLIPVAR
	LDA #$BC
	LDB #$1
	STA HPOS_LOW
	STB HPOS_HIGH
	STA VPOS_LOW
	STB VPOS_HIGH

    LBSR SEND_SNDCODE

	;LBSR CHK_CHR_ATTR
	;LBSR CHK_SCR_ATTR
	LBSR SETUP_PAL
	;LBSR LEFT_OBJ_TEST
	;LBSR SCR_FLICKER
	;LBSR CHK_SDRAM

	;LBSR TEST_SCR_TFR

	;LBSR SHOW_TAITO
	LBSR CHKCHAR
	LBSR CHKSCR
	BSR FINISH

	;LBSR TEST_CHARPAL
	;LBSR FILLSCR
	;LBSR TEST_SCRPAL
	;LBSR CLRCHAR
	;LBSR FILL_ALLCHAR
	;LBSR CLRSCR

	LDU #$DEAD
;	BSR FILL_LONGSTR
;	LBSR FILL_HEXSTR
;	LBSR FILL_CORNERS
;	LBSR APPLY_ATTR
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FINISH:
	BRA FINISH
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LEFT_OBJ_TEST:
	; COPY OBJECTS
	LDY #OBJ_LEFT
	LDX #$1E3C
@L2:
	LDA ,Y+
	CMPA #$FA
	BEQ @LFIN
	STA ,X+
	BRA @L2
@LFIN:

	; COPY SCROLL
	LDX #INITIAL_BACKGROUND
	LDY #SCR

@L:	
	LDD (INITIAL_BACKGROUND_ATTS-INITIAL_BACKGROUND),X
	STD $400,Y
	LDD ,X++	; background
	STD ,Y++
	CMPX #(INITIAL_BACKGROUND+$90)
	BNE @L

	STA OKOUT
LOCALEND: 
	LDA #10
	CMPA >PAL_STATUS
	BNE LOCALEND
	; MOVES ALL SPRITES ONE PIXEL TO THE LEFT
	LDB #24
	LDX #$1E3E
@L:	LDA ,X
	DECA
	STA ,X
	LEAX 4,X
	DECB
	BNE @L
	LDA #9
	STA >PAL_STATUS

	BRA LOCALEND
	RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SHOW_TAITO:
	LDX #$2360
	LDY #TAITO_CHR
	LDB #$40
@L:
	LDA ,Y+
	STA ,X+
	DECB
	BNE @L
	RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SCR_FLICKER:
	LDX #$2000
	LDY #SCR_FLICKER_CHAR
	CLRB
@SCRL:
	LDA ,Y
	BNE @SIGUE
	LDY #SCR_FLICKER_CHAR
	LDA ,Y
@SIGUE:
	STA ,X
	LDA #3
	STA $400,X
	STA $C00,X
	LDA 9,Y
	STA $800,X
	LEAY 1,Y
	LEAX 1,X	
	CMPX #$2400
	BLT @SCRL
	RTS


SCR_FLICKER_CHAR:
	FCB $20,$20,$20,1,2,3,0
SCR_FLICKER_SCR:	
	FCB 1,2,3,4,5,6,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SETUP_PAL:
	; primero la paleta
	LDA #0
	STA >PAL_STATUS
	ANDCC #$EF
;	LBSR CLRCHAR
;	; DELETE SCROLL attributes
;	LDX #SCR_ATT
;	CLRA
;	CLRB
;@L:	
;	STD ,X++
;	CMPX #(SCR_ATT+$400)
;	BNE @L
@PAL:
	CLRA
	LDB >PAL_STATUS
	CMPB #3
	BLO @PAL
	RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; check SDRAM, takes < 60ms to simulate
CHK_Y16:
	LDA #10
	STA <1
@L:
	LDA ,Y+
	LBSR HEX2CHAR
	LDA #$20
	STA ,X+
	DEC <1
	BNE @L
	RTS

CHK_SDRAM:
	LDA #1
	STA $1000	; FLAG
	ANDCC #$EF
	LBSR CLRCHAR
	LDX #CHR_ATT
	LDA #3
@L:	STA ,X+
	CMPX #SCR
	BNE @L
@PAL:
	LDA $1000
	CMPA #1
	BEQ @PAL

CHK_SDRAM_NOPAL:
	ORCC #$10	; DISABLE FURTHER INTERRUPTS
	LDA #$40
	STA BANK
	LDX #$2080
	LDY #$6000
	BSR CHK_Y16

	LDX #$20A0
	LDY #$8000
	BSR CHK_Y16

	LDX #$20C0
	LDY #$C000
	BSR CHK_Y16

	CLRA
	STA >0
@BANKTEST:
	LDY #$4000
	LDX #$20C0
	LDA >0
@ADDX:
	LEAX $40,X
	DECA
	CMPA #$FF
	BGT @ADDX
@GO:
	BSR CHK_Y16
	LDA >0
	INCA
	CMPA #5
	BNE @NEXT
	LBSR CLRSCR
	LDX	SCR_ATT
	LDA #3
@L:
	STA ,X+
	CMPX #(SCR_ATT+$400)
	BNE @L
	BRA CHK_SDRAM_NOPAL
@NEXT:
	STA >0
	STA BANK
	BRA @BANKTEST

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

; Write two characters and two attributes to check that
; it is read in correct order
CHK_CHR_ATTR:
	LDX #CHR
	LDA #1
	LDB #$81
CHK_CHR_ATTR_LOOP:
	STA ,X
	STB $400,X
	LEAX $1,X
	INCA
	INCB
	CMPA #0
	BNE CHK_CHR_ATTR_LOOP
	RTS

; Write two characters and two attributes to check that
; it is read in correct order
CHK_SCR_ATTR:
	LDX #SCR
	LDA #1
	LDB #$81
CHK_SCR_ATTR_LOOP:
	STA ,X
	STB $400,X
	LEAX $1,X
	INCA
	INCB
	CMPA #0
	BNE CHK_SCR_ATTR_LOOP
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
	;ADDA #55
	STA	,X+
	RTS
@L:
	;ADDA #48
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
	LDD #$1001
@L:	
	STA  ,X	
	STB $400,X
	CMPA ,X
	BNE @MAL
	CMPB $400,X
	BNE @MAL
	LEAX 1,X
	ADDA #1
	ANDA #$F
	ADDB #$10
	ANDB #$F0
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
; Verify R/W on background memory
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
	LDY #SCRSTR
@L4:
	LDA ,Y
	BNE @L3
	CMPX #(SCR+$400)
	BGE @L5
	LDY #SCRSTR
	LDA ,Y
@L3:
	STA ,X
	LDA 8,Y
	STA $400,X
	LEAX 1,X
	LEAY 1,Y
	BRA @L4
@L5:
	RTS

RGBSTR:
	.STRZ "RGBW"
	FCB 0,1,2,3
SCRSTR:
	FCB $77,$11,$22,$33,$10,$20,$30,0
	FCB   7,1,2,3,$11,$12,$13

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

	LDA #$61
	LDX #(SCR+$262)
	STA ,X
	LDA #$BA
	STA $400,X


	LDA #$0
	LDX #(SCR+$244)
	STA ,X
	LDA #$C2
	STA $400,X
	RTS

SEND_SNDCODE:
    LDX #$1000
    LDY #17
LONGWAIT:
    LEAX -1,X
    CMPX #0
    BNE LONGWAIT
    LDX #$1000
    LEAY -1,Y
    CMPY #0
    BNE LONGWAIT

    LDA #$28
    STA SND_LATCH
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

; TAITO screen, load from $2360, 16*4=$40 BYTES
TAITO_CHR:
	FCB $20,$20,$10,$20,$31,$39,$38,$35,$20,$54,$41,$49,$54,$4f,$20,$41
	FCB $4D,$45,$52,$49,$43,$41,$20,$43,$4F,$52,$50,$2E,$20,$20,$20,$20
	FCB $20,$20,$4C,$49,$43,$45,$4E,$53,$45,$44,$20,$46,$52,$4F,$4D,$20
	FCB $43,$41,$50,$43,$4F,$4D,$20,$43,$4F,$2E,$2C,$20,$4C,$54,$44,$2E
TAITO_CHR_ATT: ; LOAD FROM $2760, FOR $40 BYTES
	FCB 0,0,5,5,5,5,5,5,5,5,5,5,5,5,5,5
	FCB 5,5,5,5,5,5,5,5,5,5,5,5,0,0,0,0
	FCB 0,0,9,9,9,9,9,9,9,9,9,9,9,9,9,9
	FCB 9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9
	

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

OBJECT_PALETTE: ; 4 paletas de 16 colores
	FDB $FFF0,$EEE0,$DDD0,$CCC0	; Gray  tones
	FDB $BBB0,$AAA0,$9990,$8880	; Gray  tones
	FDB $7770,$6660,$5550,$4440	; Gray  tones
	FDB $3330,$2220,$1110,$0000	; Gray  tones

	FDB $FFF0,$EEE0,$DDD0,$CCC0	; Gray  tones
	FDB $BBB0,$AAA0,$9990,$8880	; Gray  tones
	FDB $7770,$6660,$5550,$4440	; Gray  tones
	FDB $3330,$2220,$1110,$0000	; Gray  tones

	FDB $FFF0,$EEE0,$DDD0,$CCC0	; Gray  tones
	FDB $BBB0,$AAA0,$9990,$8880	; Gray  tones
	FDB $7770,$6660,$5550,$4440	; Gray  tones
	FDB $3330,$2220,$1110,$0000	; Gray  tones

	FDB $FFF0,$EEE0,$DDD0,$CCC0	; Gray  tones
	FDB $BBB0,$AAA0,$9990,$8880	; Gray  tones
	FDB $7770,$6660,$5550,$4440	; Gray  tones
	FDB $3330,$2220,$1110,$0000	; Gray  tones

INITIAL_BACKGROUND: ; $2800...
	FDB $0000,$0000,$0000,$0000,$00AF,$A8A9,$AB06,$B000 ;00
	FDB $E9E6,$F4F2,$EDE3,$E3E3,$8081,$8180,$8229,$8D00	;10
	FDB $0000,$0000,$0000,$0000,$00A5,$A7A8,$AA06,$B000	;20
	FDB $E8E6,$F4F1,$EEE3,$E3E3,$8101,$8081,$822A,$8D00	;30
	FDB $0000,$0000,$0000,$0000,$0000,$A3A7,$A906,$B000	;40
	FDB $E9E6,$F4F2,$EDE3,$E3E3,$8180,$8180,$8229,$8D00	;50
	FDB $0000,$0000,$0000,$0000,$0000,$00A4,$A606,$B000	;60
	FDB $E8E6,$F4F1,$EEE3,$E3E3,$8081,$8081,$822A,$8D00	;70
	FDB $0000,$0000,$0000,$0000,$0000,$0000,$A306,$B000	;80

INITIAL_BACKGROUND_ATTS: ; $2c00
	FDB $0000,$0000,$0000,$0000,$0007,$1717,$1709,$0700 ; 00
	FDB $4141,$4141,$4141,$4141,$4040,$4040,$4008,$4000 ; 10
	FDB $0000,$0000,$0000,$0000,$0017,$1717,$1709,$0700 ; 20
	FDB $4141,$4141,$4141,$4141,$4040,$4040,$4008,$4000 ; 30
	FDB $0000,$0000,$0000,$0000,$0000,$1717,$1709,$0700 ; 40
	FDB $4141,$4141,$4141,$4141,$4040,$4040,$4008,$4000 ; 50
	FDB $0000,$0000,$0000,$0000,$0000,$0017,$1709,$0700 ; 60
	FDB $4141,$4141,$4141,$4141,$4040,$4040,$4008,$4000 ; 70
	FDB $0000,$0000,$0000,$0000,$0000,$0000,$1709,$0700 ; 80

; 1E3C onwards
OBJ_LEFT: 
	FCB $7C,$70,$C2,$F0
	FCB $74,$70,$B2,$F0
	FCB $7D,$71,$C2,$00	;hover
	FCB $75,$71,$B2,$00	;hover
	FCB $7A,$79,$C2,$20
	FCB $72,$70,$B2,$20
	FCB $7B,$70,$C2,$30
	FCB $73,$70,$B2,$30
	FCB $18,$01,$C2,$FF	;hover
	FCB $10,$01,$B2,$FF	;hover
	FCB $19,$00,$C2,$0F
	FCB $11,$00,$B2,$0F
	FCB $11,$00,$F8,$0F
	FCB $2F,$00,$F8,$0F
	FCB $27,$00,$F8,$0F
	FCB $2E,$01,$F8,$FF	;hover
	FCB $26,$01,$F8,$FF	;hover
	FCB $2F,$00,$F8,$0F
	FCB $27,$00,$F8,$0F
	FCB $25,$00,$F8,$0F
	FCB $17,$00,$F8,$0F
	FCB $10,$04,$F8,$0C
	FCB $2B,$00,$F8,$11
	FCB $23,$00,$F8,$11
	FCB $28,$00,$F8,$01
	FCB $20,$00,$F8,$01
	FCB $28,$00,$F8,$11
	FCB $21,$00,$F8,$11	; #28
	FCB $FA

IRQSERVICE:
	; ORCC #$10
	; fill palette
	; RG mem test
	CLRA 
	CMPA >PAL_STATUS
	BEQ DO_CHARPAL
	INCA
	CMPA >PAL_STATUS
	BEQ DO_SCRPAL
	INCA
	CMPA >PAL_STATUS
	BEQ DO_OBJPAL
	; palette is done
	LDA #10
	STA >PAL_STATUS
	CLR OKOUT
	RTI
DO_CHARPAL:
	LDX #CHR_PALRAM
	LDY #CHAR_PALETTE	
@L:	LDD ,Y++
	STA ,X
	STB $100,X
	LEAX 1,X
	CMPY #SCROLL_PALETTE
	BNE @L
	LDA #1
	STA >PAL_STATUS
	RTI

DO_SCRPAL:
	LDX #SCR_PALRAM
	LDY #SCROLL_PALETTE	
@L2:
	LDD ,Y++
	STA ,X
	STB $100,X
	LEAX 1,X
	CMPY #OBJECT_PALETTE
	BNE @L2
	LDA #2
	STA >PAL_STATUS
	RTI

DO_OBJPAL:
	LDX #OBJ_PALRAM
	LDY #OBJECT_PALETTE	
@L:	LDD ,Y++
	STA ,X
	STB $100,X
	LEAX 1,X
	CMPY #(OBJECT_PALETTE+4*8*4)
	BNE @L	
	LDA #3
	STA >PAL_STATUS
	RTI

	;FILL $FF,$FDFF-*
	FILL $F8,$FFF8-*

	ORG $FFF8
	.DW IRQSERVICE
	FILL $FF,$FFFE-*
	ORG $FFFE
	.DW	$8000	; Reset vector
