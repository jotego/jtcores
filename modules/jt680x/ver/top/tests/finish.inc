; Simulation control bits
; 0 -> set to finish the sim
; 1 -> set to mark a bad result
; 5 -> set to trigger IRQ.  Clear manually
; 6 -> set to trigger FIRQ. Clear manually
; 7 -> set to trigger NMI.  Clear manually
TESTCTRL EQU $1000

END:    LDX #$BABE
        CPX #$BABE
        BNE BAD                 ; This catches a PC error where the PC has a 1-byte offset
        LDA #3
        LDX #TESTCTRL
        STA ,X                  ; Finish test, result ok
        BRA END
BAD:    LDX #$DEAD
        LDA #1
        LDX #TESTCTRL
        STA ,X                  ; Finish test, result bad
        BRA BAD

        DC.B  [$FFFE-*]0
        FDB   $F000             ; Reset