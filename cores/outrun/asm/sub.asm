RAM     EQU $60000
SIO     EQU $90000

    ORG 0
    DC.L RAM+$8000
    DC.L RESET
    ORG $100

RESET:  
    ; copy the ROM
    MOVE.L #0,A0
    MOVE.L #RAM,A1
    MOVE.L #$8000>>2-1,D0
COPY_ROM:
    MOVE.L (A0)+,(A1)+
    DBF D0,COPY_ROM

    ; test the RAM vs ROM
    MOVE.L #0,A0
    MOVE.L #RAM,A1
    MOVE.L #$8000>>2-1,D0
    MOVE.L #1,D7
CMP_ROM:
    MOVE.L (A0)+,D1
    CMP.L (A1)+,D1
    BNE BAD

GOOD:
    MOVE.W #$BABE,D0
    MOVE.L #0,A0
    MOVE.W D0,(A0)
    BRA GOOD

BAD:
    MOVE.W #$BAD,D0
    MOVE.L #0,A0
    MOVE.W D0,(A0)+
    MOVE.W D7,(A0)
    BRA BAD

;    ORG $0
;    DS.L SIO
;    DS.L RESET

    END