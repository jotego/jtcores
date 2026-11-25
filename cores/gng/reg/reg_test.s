; GnG core regression test ROM
; Uses the real GnG boot sequence, then displays a test screen
; Assembles with: lwasm reg_test.s --output=reg_test.bin --format=raw
; Output spans $6000-$FFFF (40960 bytes), split into gg4.bin + gg3.bin

    ORG $6000

; === Palette indices (FPGA pixel_mux prefix 2'b11 = $C0) ===
PAL_HDR     EQU 0   ; green + amber shadow
PAL_ON      EQU 1   ; red (pressed button)
PAL_OFF     EQU 2   ; blue (released button)
PAL_DIP_ON  EQU 3   ; green fill (DIP on)
PAL_DIP_OFF EQU 4   ; dark fill (DIP off)
PAL_BORDER  EQU 5   ; cyan border

DIP_TILE    EQU $01 ; tile code for DIP switch glyph

; =====================================================================
; Boot sequence — matches real GnG hardware init at $6000
; =====================================================================
RESET:
    ORCC #$50               ; disable IRQ+FIRQ

    ; fill sprite RAM with $F8 (off-screen Y)
    LDX  #$1E00
    LDY  #$0060
    LDD  #$F8F8
@SPR:
    STD  ,X++
    STD  ,X++
    LEAY -1,Y
    BNE  @SPR

    ; wait 100 VBLANKs for video timing to stabilize
    LDB  #100
SYNCLOOP:
    SYNC
    LDA  $3C00              ; read OKOUT (real game convention)
    DECB
    BNE  SYNCLOOP

    ; set stack — needed before any subroutine call
    LDS  #$1DFF

    ; write palette during VBLANK via tight indexed loop
    SYNC
    LDY  #PAL_DATA
    LDX  #$0000
PAL_COPY:
    LDA  ,Y+
    STA  $38C0,X            ; FPGA chars at $C0+
    LDA  ,Y+
    STA  $39C0,X
    LEAX 1,X
    CMPX #$0018             ; 6 palettes x 4 colors
    BNE  PAL_COPY

    ; hardware init
    LDB  #$01
    STB  $3D00              ; flip OFF
    CLRA
    CLRB
    STD  $3B08              ; H scroll = 0
    STD  $3B0A              ; V scroll = 0
    LDB  #$00
    TFR  B,DP               ; DP = 0 (critical for direct-page addressing)
    STB  $3D01              ; sound CPU reset

    ; clear scroll VRAM
    LDX  #$2800
    LDY  #$2C00
    CLRA
    CLRB
@CLRSCR:
    STA  ,X+
    STB  ,Y+
    CMPX #$2C00
    BLO  @CLRSCR

    ; clear char VRAM: tile=$20, attr=$00
    LDX  #$2000
    LDA  #$20
    CLRB
@CLRCHR:
    STA  ,X
    STB  $400,X
    LEAX 1,X
    CMPX #$2400
    BNE  @CLRCHR

    ; select bank 0
    CLRA
    STA  $3E00

    ; enable IRQ, wait one frame for DMA
    ANDCC #$EF
    SYNC

; =====================================================================
; Test display
; =====================================================================
    LBSR DRAW_BORDER

    LDX  #$2083
    LDY  #STR_HEADER
    LBSR PRINT_STR

    LDX  #$20C3
    LDY  #STR_RAM_OK
    LBSR PRINT_STR

    LDX  #$2103
    LDY  #STR_P1
    LBSR PRINT_STR

    LDX  #$2143
    LDY  #STR_P2
    LBSR PRINT_STR

    LDX  #$2183
    LDY  #STR_SYS
    LBSR PRINT_STR

    LDX  #$2203
    LDY  #STR_DSW1
    LBSR PRINT_STR

    LDX  #$2243
    LDY  #STR_DSW2
    LBSR PRINT_STR

    LDX  #$22C3
    LDY  #STR_FRM
    LBSR PRINT_STR

; === Main loop ===
MAIN_LOOP:
    LDA  $3001
    LDX  #$2107
    LDY  #TBL_JOY
    LBSR SHOW_INPUTS

    LDA  $3002
    LDX  #$2147
    LDY  #TBL_JOY
    LBSR SHOW_INPUTS

    LDA  $3000
    LDX  #$2187
    LDY  #TBL_SYS
    LBSR SHOW_INPUTS

    LDA  $3003
    LDX  #$2208
    LBSR SHOW_DSW

    LDA  $3004
    LDX  #$2248
    LBSR SHOW_DSW

    LDA  <$01
    LDX  #$22C8
    LBSR SHOW_HEX

    BRA  MAIN_LOOP

; =============================================
DRAW_BORDER:
    LDA  #PAL_BORDER
    LDX  #$2440
    LDB  #32
@TOP:
    STA  ,X+
    DECB
    BNE  @TOP
    LDX  #$27A0
    LDB  #32
@BOT:
    STA  ,X+
    DECB
    BNE  @BOT
    LDX  #$2460
    LDB  #26
@SIDES:
    STA  ,X
    STA  31,X
    LEAX 32,X
    DECB
    BNE  @SIDES
    RTS

; =============================================
PRINT_STR:
    LDA  ,Y+
    BEQ  @D
    STA  ,X+
    BRA  PRINT_STR
@D: RTS

; =============================================
SHOW_INPUTS:
    STA  <$02
@LP:
    LDB  ,Y+
    CMPB #$FF
    BEQ  @DN
    LDA  ,Y+
    STA  ,X
    BITB <$02
    BNE  @OFF
    LDA  #PAL_ON
    BRA  @ST
@OFF:
    LDA  #PAL_OFF
@ST:
    STA  $400,X
    LEAX 1,X
    BRA  @LP
@DN:
    RTS

; =============================================
SHOW_DSW:
    STA  <$02
    LDB  #8
@LP:
    LDA  #DIP_TILE
    STA  ,X
    LSL  <$02
    BCS  @OFF
    LDA  #PAL_DIP_ON
    BRA  @ST
@OFF:
    LDA  #PAL_DIP_OFF
@ST:
    STA  $400,X
    LEAX 1,X
    DECB
    BNE  @LP
    RTS

; =============================================
SHOW_HEX:
    PSHS A
    LSRA
    LSRA
    LSRA
    LSRA
    BSR  @NIB
    PULS A
    ANDA #$0F
@NIB:
    CMPA #10
    BLO  @DIG
    ADDA #('A'-10)
    STA  ,X+
    RTS
@DIG:
    ADDA #'0'
    STA  ,X+
    RTS

; =============================================
; IRQ handler — fires at VBLANK
IRQ_HANDLER:
    STB  $3C00              ; trigger sprite DMA
    LDY  #PAL_DATA
    LDX  #$0000
@PAL:
    LDA  ,Y+
    STA  $38C0,X            ; FPGA chars at $C0+
    LDA  ,Y+
    STA  $39C0,X
    LEAX 1,X
    CMPX #$0018
    BNE  @PAL
    INC  <$01               ; frame counter
    RTI

; =============================================
; Palette data table: (RG, B) pairs for entries $C0-$D7
PAL_DATA:
    ; pal 0: header — green body + amber shadow
    FCB $00,$00,$0E,$20,$F8,$00,$00,$00
    ; pal 1: pressed — red body + dark red shadow
    FCB $00,$00,$F2,$20,$80,$00,$00,$00
    ; pal 2: released — blue body + dark blue shadow
    FCB $00,$00,$24,$E0,$12,$60,$00,$00
    ; pal 3: DIP ON — green fill + gray frame
    FCB $00,$00,$0F,$20,$88,$80,$00,$00
    ; pal 4: DIP OFF — dark fill + gray frame
    FCB $00,$00,$22,$20,$77,$70,$00,$00
    ; pal 5: border — pen 0 = dark cyan
    FCB $06,$80,$00,$00,$00,$00,$00,$00

; =============================================
; Input tables: (mask, char) pairs, $FF = end
TBL_JOY:
    FCB $08,$55,$04,$44,$02,$4C,$01,$52
    FCB $10,$41,$20,$42
    FCB $FF
TBL_SYS:
    FCB $01,$31,$02,$32,$20,$54,$40,$43
    FCB $FF

; Strings
STR_HEADER:
    FCN "GNG CORE TEST  PAGE 1/1"
STR_RAM_OK:
    FCN "RAM OK"
STR_P1:
    FCN "P1: "
STR_P2:
    FCN "P2: "
STR_SYS:
    FCN "SYS:"
STR_DSW1:
    FCN "DSW1:"
STR_DSW2:
    FCN "DSW2:"
STR_FRM:
    FCN "FRM: "

; =============================================
    FILL $FF,$8000-*

    ORG  $8000
    FILL $FF,$FFF8-*

    ORG  $FFF8
    FDB  IRQ_HANDLER
    FDB  IRQ_HANDLER
    FDB  IRQ_HANDLER
    FDB  RESET
