    DI

    LD DE,$CC00
    LD HL,SPRDATA
    LD BC,$80
    LDIR

END:
    JP END

SPRDATA:
DB  $10,$01,$10,$40
DB  $20,$FF,$20,$FF
DB  $30,$FF,$30,$FF
DB  $40,$FF,$40,$FF
DB  $50,$FF,$50,$FF
DB  $60,$FF,$60,$FF
DB  $70,$FF,$70,$FF
DB  $80,$FF,$80,$FF

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