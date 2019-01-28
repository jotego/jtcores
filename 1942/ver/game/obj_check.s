    DI

    LD DE,$CC00
    LD HL,SPRDATA
    LD BC,$80
    LDIR

END:
    JP END

SPRDATA:
DB  $10,$01,$11,$40
DB  $20,$FF,$22,$FF
DB  $30,$FF,$33,$FF
DB  $40,$FF,$44,$FF
DB  $50,$FF,$55,$FF
DB  $60,$FF,$66,$FF
DB  $70,$FF,$77,$FF
DB  $80,$FF,$88,$FF

DB  $BB,$01,$10,$80
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF

DB  $CC,$01,$10,$A0
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF

DB  $DD,$01,$10,$D0
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF

; extra
DB  $FF,$FF,$FF,$FF