    DI

    LD DE,$CC00
    LD HL,SPRDATA
    LD BC,$80
    LDIR

END:
    JP END

SPRDATA:
DB  $33,$01,$80,$40
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF

DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF

DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF

DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF
DB  $FF,$FF,$FF,$FF

; extra
DB  $FF,$FF,$FF,$FF