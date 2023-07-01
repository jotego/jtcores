;*************************************************************
;
;                 TINY BASIC FOR ZILOG Z80
;                       VERSION 2.0
;                     BY LI-CHEN WANG
;
;                  MODIFIED AND TRANSLATED
;                    TO INTEL MNEMONICS
;                     BY ROGER RAUSKOLB
;                      10 OCTOBER,1976
;
;                  MODIFIED AND TRANSLATED
;                    TO ZILOG MNEMONICS
;                      BY DOUG GABBARD
;            www.retrodepot.net
;
;           RELEASED TO THE PUBLIC
;                      10 OCTOBER,2017
;                  YEAH, 41 YEARS LATER....
;
;                         @COPYLEFT
;                   ALL WRONGS RESERVED
;
;*************************************************************
; This code is derived from the original 8080 Tiny Basic.
; It was first compiled in 8080 Mnemonics, then disassembled
; into Zilog Mnemonics.  And then checked against the original
; to ensure accuracy.  It was then partially enhanced with z80
; specific code. And once done, it was then modified to work
; with the G80-S Micro Computer. However, that portion of the
; code has been left out in order to make this code a little
; more portable.  There are only three routines that one needs
; to write, and specifing the serial port's I/O address, in
; order to make this version work with your own DIY computer.
; Those routines can be found at the end of the source code.
;
; I hope you find good use for this relic. However, I would
; ask that if you do find use for it, please put a reference
; to me in your work. And please, distribute freely.
;*************************************************************
; Notes for JTFrame version:
;  Adapted to work with GNU z80asm
;  Added interrupt handling

SerialPort:     EQU     0F0H            ; This the serial output port


SPACE:          EQU     020H            ; Space
TAB:            EQU     09H             ; HORIZONTAL TAB
CTRLC:          EQU     03H             ; Control "C"
CTRLG:          EQU     07H             ; Control "G"
BKSP:           EQU     08H             ; Back space
LF:             EQU     0AH             ; Line feed
CS:             EQU     0CH             ; Clear screen
CR:             EQU     0DH             ; Carriage return
CTRLO:          EQU     0FH             ; Control "O"
CTRLQ:          EQU     011H            ; Control "Q"
CTRLR:          EQU     012H            ; Control "R"
CTRLS:          EQU     013H            ; Control "S"
CTRLU:          EQU     015H            ; Control "U"
ESC:            EQU     01BH            ; Escape
DEL:            EQU     07FH            ; Delete

; Adjust to fit RAM mapping
STACK:          EQU     087FFH          ; STACK (Last RAM address)
OCSW:           EQU     08000H          ;SWITCH FOR OUTPUT
CURRNT:         EQU     OCSW+1          ;POINTS FOR OUTPUT
STKGOS:         EQU     OCSW+3          ;SAVES SP IN 'GOSUB'
VARNXT:         EQU     OCSW+5          ;TEMP STORAGE
STKINP:         EQU     OCSW+7          ;SAVES SP IN 'INPUT'
LOPVAR:         EQU     OCSW+9          ;'FOR' LOOP SAVE AREA
LOPINC:         EQU     OCSW+11         ;INCREMENT
LOPLMT:         EQU     OCSW+13         ;LIMIT
LOPLN:          EQU     OCSW+15         ;LINE NUMBER
LOPPT:          EQU     OCSW+17         ;TEXT POINTER
RANPNT:         EQU     OCSW+19         ;RANDOM NUMBER POINTER
TXTUNF:         EQU     OCSW+21         ;->UNFILLED TEXT AREA
TXTBGN:         EQU     OCSW+23         ;TEXT SAVE AREA BEGINS

TXTEND:         EQU     08700H          ;TEXT SAVE AREA ENDS


;*************************************************************
; *** ZERO PAGE SUBROUTINES ***
;
; THE Z80 INSTRUCTION SET ALLOWS FOR 8 ROUTINES IN LOW MEMORY
; THAT MAY BE CALLED BY RST 00H, 08H, 10H, 18H, 20H, 28H, 30H,
; AND 38H.  THIS IS A ONE BYTE INSTRUCTION, AND IS FUNCTIONALLY
; SIMILAR TO THE THREE BYTE INSTRUCTION 'CALL XXXX'. TINY BASIC
; WILL USE THE RST INSTRUCTION FOR THE 7 MOST FREQUENTLY USED
; SUBROUTINES. TWO OTHER SUBROUTINES (CRLF & TSTNUM) ARE ALSO
; IN THIS SECTION. THEY CAN BE REACHED WITH 'CALL'.
;*************************************************************

DWA:    MACRO WHERE
        DB   (WHERE >> 8) + 128
        DB   WHERE & 0FFH
        ENDM

        ORG  0000H

START:
        LD SP,STACK                     ;*** COLD START ***
        LD A,0FFH
        JP INIT

RST08:  EX (SP),HL                      ;*** TSTC OR RST 08H ***
        RST 28H                         ;IGNORE BLANKS AND
        CP (HL)                         ;TEST CHARACTER
        JP TC1                          ;REST OF THIS IS AT TC1

CRLF:
        LD A,CR                         ;*** CRLF ***

RST10:  PUSH AF                         ;*** OUTC OR RST 10H ***
        LD A,(OCSW)                     ;PRINT CHARACTER ONLY
        OR A                            ;IF OCSW SWITCH IS ON
        JP OUTC                         ;REST OF THIS AT OUTC

RST18:  CALL EXPR2                      ;*** EXPR OR RST 18H ***
        PUSH HL                         ;EVALUATE AN EXPRESSION
        JP EXPR1                        ;REST OF IT AT EXPR1
        DB 'W'

RST20:  LD A,H                          ;*** COMP OR RST 20H ***
        CP D                            ;COMPARE HL WITH DE
        RET NZ                          ;RETURN CORRECT C AND
        LD A,L                          ;Z FLAGS
        CP E                            ;BUT OLD A IS LOST
        RET
        DB 'AN'

SS1:
RST28:  LD A,(DE)                       ;*** IGNBLK/RST 28H ***
        CP 20H                          ;IGNORE BLANKS
        RET NZ                          ;IN TEXT (WHERE DE->)
        INC DE                          ;AND RETURN THE FIRST
        JP SS1                          ;NON-BLANK CHAR. IN A

RST30:  POP AF                          ;*** FINISH/RST 30H ***
        CALL FIN                        ;CHECK END OF COMMAND
        JP QWHAT                        ;PRINT "WHAT?" IF WRONG
        DB 'G'

RST38:  RST 28H                         ;*** TSTV OR RST 38H ***
        SUB 40H                         ;TEST VARIABLES
        RET C                           ;C:NOT A VARIABLE
        JR NZ,TV1                       ;NOT "@" ARRAY
        INC DE                          ;IT IS THE "@" ARRAY
        CALL PARN                       ;@ SHOULD BE FOLLOWED
        ADD HL,HL                       ;BY (EXPR) AS ITS INDEX
        JR C,QHOW                       ;IS INDEX TOO BIG?
        PUSH DE                         ;WILL IT OVERWRITE
        EX DE,HL                        ;TEXT?
        CALL SIZE                       ;FIND SIZE OF FREE
        RST 20H                         ;AND CHECK THAT
        JP C,ASORRY                     ;IF SO, SAY "SORRY"
        LD HL,VARBGN                    ;IF NOT GET ADDRESS
        CALL SUBDE                      ;OF @(EXPR) AND PUT IT
        POP DE                          ;IN HL
        RET                             ;C FLAG IS CLEARED

TV1:
        CP 1BH                          ;NOT @, IS IT A TO Z?
        CCF                             ;IF NOT RETURN C FLAG
        RET C
        INC DE                          ;IF A THROUGH Z
        LD HL,VARBGN                    ;COMPUTE ADDRESS OF
        RLCA                            ;THAT VARIABLE
        ADD A,L                         ;AND RETURN IT IN HL
        LD L,A                          ;WITH C FLAG CLEARED
        LD A,00H
        ADC A,H
        LD H,A
        RET

NMI66:                                  ;MUST BE AT 66H
        RETI

TC1:
        INC HL                          ;COMPARE THE BYTE THAT
        JR Z,TC2                        ;FOLLOWS THE RST INST.
        PUSH BC                         ;WITH THE TEXT (DE->)
        LD C,(HL)                       ;IF NOT =, ADD THE 2ND
        LD B,00H                        ;BYTE THAT FOLLOWS THE
        ADD HL,BC                       ;RST TO THE OLD PC
        POP BC                          ;I.E., DO A RELATIVE
        DEC DE                          ;JUMP IF NOT =

TC2:
        INC DE                          ;IF =, SKIP THOSE BYTES
        INC HL                          ;AND CONTINUE
        EX (SP),HL
        RET

TSTNUM:
        LD HL,0000H                     ;*** TSTNUM ***
        LD B,H                          ;TEST IF THE TEXT IS
        RST 28H                         ;A NUMBER

TN1:
        CP 30H                          ;IF NOT, RETURN 0 IN
        RET C                           ;B AND HL
        CP 3AH                          ;IF NUMBERS, CONVERT
        RET NC                          ;TO BINARY IN HL AND
        LD A,0F0H                       ;SET B TO # OF DIGITS
        AND H                           ;IF H>255, THERE IS NO
        JR NZ,QHOW                      ;ROOM FOR NEXT DIGIT
        INC B                           ;B COUNTS # OF DIGITS
        PUSH BC
        LD B,H                          ;HL=10*HL+(NEW DIGIT)
        LD C,L
        ADD HL,HL                       ;WHERE 10* IS DONE BY
        ADD HL,HL                       ;SHIFT AND ADD
        ADD HL,BC
        ADD HL,HL
        LD A,(DE)                       ;AND (DIGIT) IS FROM
        INC DE                          ;STRIPPING THE ASCII
        AND 0FH                         ;CODE
        ADD A,L
        LD L,A
        LD A,00H
        ADC A,H
        LD H,A
        POP BC
        LD A,(DE)                       ;DO THIS DIGIT AFTER
        JP P,TN1                        ;DIGIT. S SAYS OVERFLOW

QHOW:
        PUSH DE                         ;*** ERROR "HOW?" ***
AHOW:
        LD DE,HOW
        JP ERROR_ROUTINE


HOW:    DB "HOW?",CR
OK:     DB "OK",CR
WHAT:   DB "WHAT?",CR
SORRY:  DB "SORRY",CR

;*************************************************************
;
; *** MAIN ***
;
; THIS IS THE MAIN LOOP THAT COLLECTS THE TINY BASIC PROGRAM
; AND STORES IT IN THE MEMORY.
;
; AT START, IT PRINTS OUT "(CR)OK(CR)", AND INITIALIZES THE
; STACK AND SOME OTHER INTERNAL VARIABLES.  THEN IT PROMPTS
; ">" AND READS A LINE.  IF THE LINE STARTS WITH A NON-ZERO
; NUMBER, THIS NUMBER IS THE LINE NUMBER.  THE LINE NUMBER
; (IN 16 BIT BINARY) AND THE REST OF THE LINE (INCLUDING CR)
; IS STORED IN THE MEMORY.  IF A LINE WITH THE SAME LINE
; NUMBER IS ALREADY THERE, IT IS REPLACED BY THE NEW ONE.  IF
; THE REST OF THE LINE CONSISTS OF A CR ONLY, IT IS NOT STORED
; AND ANY EXISTING LINE WITH THE SAME LINE NUMBER IS DELETED.
;
; AFTER A LINE IS INSERTED, REPLACED, OR DELETED, THE PROGRAM
; LOOPS BACK AND ASKS FOR ANOTHER LINE.  THIS LOOP WILL BE
; TERMINATED WHEN IT READS A LINE WITH ZERO OR NO LINE
; NUMBER; AND CONTROL IS TRANSFERED TO "DIRECT".
;
; TINY BASIC PROGRAM SAVE AREA STARTS AT THE MEMORY LOCATION
; LABELED "TXTBGN" AND ENDS AT "TXTEND".  WE ALWAYS FILL THIS
; AREA STARTING AT "TXTBGN", THE UNFILLED PORTION IS POINTED
; BY THE CONTENT OF A MEMORY LOCATION LABELED "TXTUNF".
;
; THE MEMORY LOCATION "CURRNT" POINTS TO THE LINE NUMBER
; THAT IS CURRENTLY BEING INTERPRETED.  WHILE WE ARE IN
; THIS LOOP OR WHILE WE ARE INTERPRETING A DIRECT COMMAND
; (SEE NEXT SECTION). "CURRNT" SHOULD POINT TO A 0.
;*************************************************************

RSTART:
        LD SP,STACK

ST1:
        CALL CRLF                       ;AND JUMP TO HERE
        LD DE,OK                        ;DE->STRING
        SUB A                           ;A=0
        CALL PRTSTG                     ;PRINT STRING UNTIL CR
        LD HL,ST2+1                     ;LITERAL 0
        LD (CURRNT),HL                  ;CURRENT->LINE # = 0

ST2:
        LD HL,0000H
        LD (LOPVAR),HL
        LD (STKGOS),HL

ST3:
        LD A,'>'                        ;PROMPT '>' AND
        CALL GETLN                      ;READ A LINE
        PUSH DE                         ;DE->END OF LINE
        LD DE,BUFFER                    ;DE->BEGINNING OF LINE
        CALL TSTNUM                     ;TEST IF IT IS A NUMBER
        RST 28H
        LD A,H                          ;HL=VALUE OF THE # OR
        OR L                            ;0 IF NO # WAS FOUND
        POP BC                          ;BC->END OF LINE
        JP Z,DIRECT
        DEC DE                          ;BACKUP DE AND SAVE
        LD A,H                          ;VALUE OF LINE # THERE
        LD (DE),A
        DEC DE
        LD A,L
        LD (DE),A
        PUSH BC                         ;BC,DE->BEGIN, END
        PUSH DE
        LD A,C
        SUB E

        PUSH AF                         ;A=# OF BYTES IN LINE
        CALL FNDLN                      ;FIND THIS LINE IN SAVE
        PUSH DE                         ;AREA, DE->SAVE AREA
        JR NZ,ST4                       ;NZ:NOT FOUND, INSERT
        PUSH DE                         ;Z:FOUND, DELETE IT
        CALL FNDNXT                     ;FIND NEXT LINE
                                        ;DE->NEXT LINE
        POP BC                          ;BC->LINE TO BE DELETED
        LD HL,(TXTUNF)                  ;HL->UNFILLED SAVE AREA
        CALL MVUP                       ;MOVE UP TO DELETE
        LD H,B                          ;TXTUNF->UNFILLED ARA
        LD L,C
        LD (TXTUNF),HL                  ;UPDATE

ST4:
        POP BC                          ;GET READY TO INSERT
        LD HL,(TXTUNF)                  ;BUT FIRST CHECK IF
        POP AF                          ;THE LENGTH OF NEW LINE
        PUSH HL                         ;IS 3 (LINE # AND CR)
        CP 03H                          ;THEN DO NOT INSERT
        JR Z,RSTART                     ;MUST CLEAR THE STACK
        ADD A,L                         ;COMPUTE NEW TXTUNF
        LD L,A
        LD A,00H
        ADC A,H
        LD H,A                          ;HL->NEW UNFILLED AREA
        LD DE,TXTEND                    ;CHECK TO SEE IF THERE
        RST 20H                         ;IS ENOUGH SPACE
        JP NC,QSORRY                    ;SORRY, NO ROOM FOR IT
        LD (TXTUNF),HL                  ;OK, UPDATE TXTUNF
        POP DE                          ;DE->OLD UNFILLED AREA
        CALL MVDOWN
        POP DE                          ;DE->BEGIN, HL->END
        POP HL
        CALL MVUP                       ;MOVE NEW LINE TO SAVE
        JR ST3                          ;AREA

;*************************************************************
;
; WHAT FOLLOWS IS THE CODE TO EXECUTE DIRECT AND STATEMENT
; COMMANDS.  CONTROL IS TRANSFERED TO THESE POINTS VIA THE
; COMMAND TABLE LOOKUP CODE OF 'DIRECT' AND 'EXEC' IN LAST
; SECTION.  AFTER THE COMMAND IS EXECUTED, CONTROL IS
; TRANSFERED TO OTHERS SECTIONS AS FOLLOWS:
;
; FOR 'LIST', 'NEW', AND 'STOP': GO BACK TO 'RSTART'
; FOR 'RUN': GO EXECUTE THE FIRST STORED LINE IF ANY, ELSE
; GO BACK TO 'RSTART'.
; FOR 'GOTO' AND 'GOSUB': GO EXECUTE THE TARGET LINE.
; FOR 'RETURN' AND 'NEXT': GO BACK TO SAVED RETURN LINE.
; FOR ALL OTHERS: IF 'CURRENT' -> 0, GO TO 'RSTART', ELSE
; GO EXECUTE NEXT COMMAND.  (THIS IS DONE IN 'FINISH'.)
;*************************************************************
;
; *** NEW *** STOP *** RUN (& FRIENDS) *** & GOTO ***
;
; 'NEW(CR)' SETS 'TXTUNF' TO POINT TO 'TXTBGN'
;
; 'STOP(CR)' GOES BACK TO 'RSTART'
;
; 'RUN(CR)' FINDS THE FIRST STORED LINE, STORE ITS ADDRESS (IN
; 'CURRENT'), AND START EXECUTE IT.  NOTE THAT ONLY THOSE
; COMMANDS IN TAB2 ARE LEGAL FOR STORED PROGRAM.
;
; THERE ARE 3 MORE ENTRIES IN 'RUN':
; 'RUNNXL' FINDS NEXT LINE, STORES ITS ADDR. AND EXECUTES IT.
; 'RUNTSL' STORES THE ADDRESS OF THIS LINE AND EXECUTES IT.
; 'RUNSML' CONTINUES THE EXECUTION ON SAME LINE.
;
; 'GOTO EXPR(CR)' EVALUATES THE EXPRESSION, FIND THE TARGET
; LINE, AND JUMP TO 'RUNTSL' TO DO IT.
;*************************************************************

NEW:
        CALL ENDCHK                     ;*** NEW(CR) ***
        LD HL,TXTBGN
        LD (TXTUNF),HL
STOP:
        CALL ENDCHK                     ;*** STOP(CR) ***
        JP RSTART
RUN:
        CALL ENDCHK                     ;*** RUN(CR) ***
        LD DE,TXTBGN                    ;FIRST SAVED LINE
RUNNXL:
        LD HL,00H                       ;*** RUNNXL ***
        CALL FNDLP                      ;FIND WHATEVER LINE #
        JP C,RSTART                     ;C:PASSED TXTUNF, QUIT
RUNTSL:
        EX DE,HL                        ;*** RUNTSL ***
        LD (CURRNT),HL                  ;SET 'CURRENT'->LINE #
        EX DE,HL
        INC DE                          ;BUMP PASS LINE #
        INC DE
RUNSML:
        CALL CHKIO                      ;*** RUNSML ***
        LD HL,TAB2-1                    ;FIND COMMAND IN TAB2
        JP EXEC                         ;AND EXECUTE IT
GOTO:
        RST 18H                         ;*** GOTO EXPR ***
        PUSH DE                         ;SAVE FOR ERROR ROUTINE
        CALL ENDCHK                     ;MUST FIND A CR
        CALL FNDLN                      ;FIND THE TARGET LINE
        JP NZ,AHOW                      ;NO SUCH LINE #
        POP AF                          ;CLEAR THE PUSH DE
        JR RUNTSL                       ;GO DO IT

;*************************************************************
;
; *** LIST *** & PRINT ***
;
; LIST HAS TWO FORMS:
; 'LIST(CR)' LISTS ALL SAVED LINES
; 'LIST #(CR)' START LIST AT THIS LINE #
; YOU CAN STOP THE LISTING BY CONTROL C KEY
;
; PRINT COMMAND IS 'PRINT ....;' OR 'PRINT ....(CR)'
; WHERE '....' IS A LIST OF EXPRESIONS, FORMATS, BACK-
; ARROWS, AND STRINGS.  THESE ITEMS ARE SEPERATED BY COMMAS.
;
; A FORMAT IS A POUND SIGN FOLLOWED BY A NUMBER.  IT CONTROLS
; THE NUMBER OF SPACES THE VALUE OF A EXPRESION IS GOING TO
; BE PRINTED.  IT STAYS EFFECTIVE FOR THE REST OF THE PRINT
; COMMAND UNLESS CHANGED BY ANOTHER FORMAT.  IF NO FORMAT IS
; SPECIFIED, 6 POSITIONS WILL BE USED.
;
; A STRING IS QUOTED IN A PAIR OF SINGLE QUOTES OR A PAIR OF
; DOUBLE QUOTES.
;
; A BACK-ARROW MEANS GENERATE A (CR) WITHOUT (LF)
;
; A (CRLF) IS GENERATED AFTER THE ENTIRE LIST HAS BEEN
; PRINTED OR IF THE LIST IS A NULL LIST.  HOWEVER IF THE LIST
; ENDED WITH A COMMA, NO (CRLF) IS GENERATED.
;*************************************************************

LIST:
        CALL TSTNUM                     ;TEST IF THERE IS A #
        CALL ENDCHK                     ;IF NO # WE GET A 0
        CALL FNDLN                      ;FIND THIS OR NEXT LINE
LS1:
        JP C,RSTART                     ;C:PASSED TXTUNF
        CALL PRTLN                      ;PRINT THE LINE
        CALL CHKIO                      ;STOP IF HIT CONTROL-C
        CALL FNDLP                      ;FIND NEXT LINE
        JR LS1                          ;AND LOOP BACK
PRINT:
        LD C,06H                        ;C = # OF SPACES
        RST 08H                         ;F NULL LIST & ";"
        DB 3BH
        DB PR2-$-1
        CALL CRLF                       ;GIVE CR-LF AND
        JR RUNSML                       ;CONTINUE SAME LINE
PR2:
        RST 08H                         ;IF NULL LIST (CR)
        DB CR
        DB PR0-$-1
        CALL CRLF                       ;ALSO GIVE CR-LF AND
        JR RUNNXL                       ;GO TO NEXT LINE
PR0:
        RST 08H                         ;ELSE IS IT FORMAT?
        DB '#'
        DB PR1-$-1
        RST 18H                         ;YES, EVALUATE EXPR.
        LD C,L                          ;AND SAVE IT IN C
        JR PR3                          ;LOOK FOR MORE TO PRINT
PR1:
        CALL QTSTG                      ;OR IS IT A STRING?
        JR PR8                          ;IF NOT, MUST BE EXPR.
PR3:
        RST 08H                         ;IF ",", GO FIND NEXT
        DB ','
        DB PR6-$-1
        CALL FIN                        ;IN THE LIST.
        JR PR0                          ;LIST CONTINUES
PR6:
        CALL CRLF                       ;LIST ENDS
        RST 30H
PR8:
        RST 18H                         ;EVALUATE THE EXPR
        PUSH BC
        CALL PRTNUM                     ;PRINT THE VALUE
        POP BC
        JR PR3                          ;MORE TO PRINT?

;*************************************************************
;
; *** GOSUB *** & RETURN ***
;
; 'GOSUB EXPR;' OR 'GOSUB EXPR (CR)' IS LIKE THE 'GOTO'
; COMMAND, EXCEPT THAT THE CURRENT TEXT POINTER, STACK POINTER
; ETC. ARE SAVE SO THAT EXECUTION CAN BE CONTINUED AFTER THE
; SUBROUTINE 'RETURN'.  IN ORDER THAT 'GOSUB' CAN BE NESTED
; (AND EVEN RECURSIVE), THE SAVE AREA MUST BE STACKED.
; THE STACK POINTER IS SAVED IN 'STKGOS', THE OLD 'STKGOS' IS
; SAVED IN THE STACK.  IF WE ARE IN THE MAIN ROUTINE, 'STKGOS'
; IS ZERO (THIS WAS DONE BY THE "MAIN" SECTION OF THE CODE),
; BUT WE STILL SAVE IT AS A FLAG FOR NO FURTHER 'RETURN'S.
;
; 'RETURN(CR)' UNDOS EVERYTHING THAT 'GOSUB' DID, AND THUS
; RETURN THE EXECUTION TO THE COMMAND AFTER THE MOST RECENT
; 'GOSUB'.  IF 'STKGOS' IS ZERO, IT INDICATES THAT WE
; NEVER HAD A 'GOSUB' AND IS THUS AN ERROR.
;*************************************************************

GOSUB:
        CALL PUSHA                      ;SAVE THE CURRENT "FOR"
        RST 18H                         ;PARAMETERS
        PUSH DE                         ;AND TEXT POINTER
        CALL FNDLN                      ;FIND THE TARGET LINE
        JP NZ,AHOW                      ;NOT THERE. SAY "HOW?"
        LD HL,(CURRNT)                  ;FOUND IT, SAVE OLD.
        PUSH HL                         ;'CURRNT' OLD 'STKGOS'
        LD HL,(STKGOS)
        PUSH HL
        LD HL,0000H                     ;AND LOAD NEW ONES
        LD (LOPVAR),HL
        ADD HL,SP
        LD (STKGOS),HL
        JP RUNTSL                       ;THEN RUN THAT LINE
RETURN:
        CALL ENDCHK                     ;THERE MUST BE A CR
        LD HL,(STKGOS)                  ;OLD STACK POINTER
        LD A,H                          ;0 MEANS NOT EXIST
        OR L
        JP Z,QWHAT                      ;SO, WE SAY: "WHAT?"
        LD SP,HL                        ;ELSE, RESTORE IT
        POP HL
        LD (STKGOS),HL                  ;AND THE OLD "STKGOS"
        POP HL
        LD (CURRNT),HL                  ;AND THE OLD 'CURRNT'
        POP DE                          ;OLD TEXT POINTER
        CALL POPA                       ;OLD "FOR" PARAMETERS
        RST 30H                         ;AND WE ARE BACK HOME

;*************************************************************
;
; *** FOR *** & NEXT ***
;
; 'FOR' HAS TWO FORMS:
; 'FOR VAR=EXP1 TO EXP2 STEP EXP3' AND 'FOR VAR=EXP1 TO EXP2'
; THE SECOND FORM MEANS THE SAME THING AS THE FIRST FORM WITH
; EXP3=1.  (I.E., WITH A STEP OF +1.)
; TBI WILL FIND THE VARIABLE VAR, AND SET ITS VALUE TO THE
; CURRENT VALUE OF EXP1.  IT ALSO EVALUATES EXP2 AND EXP3
; AND SAVE ALL THESE TOGETHER WITH THE TEXT POINTER ETC. IN
; THE 'FOR' SAVE AREA, WHICH CONSISTS OF 'LOPVAR', 'LOPINC',
; 'LOPLMT', 'LOPLN', AND 'LOPPT'.  IF THERE IS ALREADY SOME-
; THING IN THE SAVE AREA (THIS IS INDICATED BY A NON-ZERO
; 'LOPVAR'), THEN THE OLD SAVE AREA IS SAVED IN THE STACK
; BEFORE THE NEW ONE OVERWRITES IT.
; TBI WILL THEN DIG IN THE STACK AND FIND OUT IF THIS SAME
; VARIABLE WAS USED IN ANOTHER CURRENTLY ACTIVE 'FOR' LOOP.
; IF THAT IS THE CASE, THEN THE OLD 'FOR' LOOP IS DEACTIVATED.
; (PURGED FROM THE STACK..)
;
; 'NEXT VAR' SERVES AS THE LOGICAL (NOT NECESSARILLY PHYSICAL)
; END OF THE 'FOR' LOOP.  THE CONTROL VARIABLE VAR. IS CHECKED
; WITH THE 'LOPVAR'.  IF THEY ARE NOT THE SAME, TBI DIGS IN
; THE STACK TO FIND THE RIGHT ONE AND PURGES ALL THOSE THAT
; DID NOT MATCH.  EITHER WAY, TBI THEN ADDS THE 'STEP' TO
; THAT VARIABLE AND CHECK THE RESULT WITH THE LIMIT.  IF IT
; IS WITHIN THE LIMIT, CONTROL LOOPS BACK TO THE COMMAND
; FOLLOWING THE 'FOR'.  IF OUTSIDE THE LIMIT, THE SAVE AREA
; IS PURGED AND EXECUTION CONTINUES.
;*************************************************************

FOR:
        CALL PUSHA                      ;SAVE THE OLD SAVE AREA
        CALL SETVAL                     ;SET THE CONTROL VAR.
        DEC HL                          ;HL IS ITS ADDRESS
        LD (LOPVAR),HL                  ;SAVE THAT
        LD HL,TAB5-1                    ;USE 'EXEC' TO LOOK
        JP EXEC                         ;FOR THE WORK 'TO'
FR1:
        RST 18H                         ;EVALUATE THE LIMITE
        LD (LOPLMT),HL                  ;SAVE THAT
        LD HL,TAB6-1                    ;USE 'EXEC' TO LOOK
        JP EXEC                         ;FOR THE WORD 'STEP'
FR2:
        RST 18H                         ;FOUND IT, GET STEP
        JR FR4
FR3:
        LD HL,0001H                     ;NOT FOUND, SET TO 1
FR4:
        LD (LOPINC),HL                  ;SAVE THAT TOO
FR5:
        LD HL,(CURRNT)                  ;SAVE CURRENT LINE #
        LD (LOPLN),HL
        EX DE,HL                        ;AND TEXT POINTER
        LD (LOPPT),HL
        LD BC,0AH                       ;DIG INTO STACK TO
        LD HL,(LOPVAR)                  ;FIND 'LOPVAR'
        EX DE,HL
        LD H,B
        LD L,B                          ;HL=0 NOW
        ADD HL,SP                       ;HERE IS THE STACK
        DB 3EH                          ;DISASSEMBLY SAID "ld a,09h"
FR7:
        ADD HL,BC                       ;EACH LEVEL IS 10 DEEP - DIS = 09
        LD A,(HL)                       ;GET THAT OLD 'LOPVAR'
        INC HL
        OR (HL)
        JR Z,FR8                        ;0 SAYS NO MORE IN IT
        LD A,(HL)
        DEC HL
        CP D                            ;SAME AS THIS ONE?
        JR NZ,FR7
        LD A,(HL)                       ;THE OTHER HALF?
        CP E
        JR NZ,FR7
        EX DE,HL                        ;YES, FOUND ONE
        LD HL,0000H
        ADD HL,SP                       ;TRY TO MOVE SP
        LD B,H
        LD C,L
        LD HL,000AH
        ADD HL,DE
        CALL MVDOWN                     ;AND PURGE 10 WORDS
        LD SP,HL                        ;IN THE STACK
FR8:
        LD HL,(LOPPT)                   ;JOB DONE, RESTORE DE
        EX DE,HL
        RST 30H                         ;AND CONTINUE
;
NEXT:
        RST 38H                         ;GET ADDRESS OF VAR.
        JP C,QWHAT                      ;NO VARIABLE, "WHAT?"
        LD (VARNXT),HL                  ;YES, SAVE IT
NX0:
        PUSH DE                         ;SAVE TEXT POINTER
        EX DE,HL
        LD HL,(LOPVAR)                  ;GET VAR. IN 'FOR'
        LD A,H
        OR L                            ;0 SAYS NEVER HAD ONE
        JP Z,AWHAT                      ;SO WE ASK: "WHAT?"
        RST 20H                         ;ELSE WE CHECK THEM
        JR Z,NX3                        ;OK, THEY AGREE
        POP DE                          ;NO, LET'S SEE
        CALL POPA                       ;PURGE CURRENT LOOP
        LD HL,(VARNXT)                  ;AND POP ONE LEVEL
        JR NX0                          ;GO CHECK AGAIN
NX3:
        LD E,(HL)                       ;COME HERE WHEN AGREED
        INC HL
        LD D,(HL)                       ;DE=VALUE OF VAR.
        LD HL,(LOPINC)
        PUSH HL
        LD A,H
        XOR D
        LD A,D
        ADD HL,DE                       ;ADD ONE STEP
        JP M,NX4
        XOR H
        JP M,NX5
NX4:
        EX DE,HL
        LD HL,(LOPVAR)                  ;PUT IT BACK
        LD (HL),E
        INC HL
        LD (HL),D
        LD HL,(LOPLMT)                  ;HL->LIMIT
        POP AF                          ;OLD HL
        OR A
        JP P,NX1                        ;STEP > 0
        EX DE,HL                        ;STEP < 0
NX1:
        CALL CKHLDE                     ;COMPARE WITH LIMIT
        POP DE                          ;RESTORE TEXT POINTER
        JR C,NX2                        ;OUTSIDE LIMIT
        LD HL,(LOPLN)                   ;WITHIN LIMIT, GO
        LD (CURRNT),HL                  ;BACK TO THE SAVED
        LD HL,(LOPPT)                   ;'CURRNT' AND TEXT
        EX DE,HL                        ;POINTER
        RST 30H
NX5:
        POP HL
        POP DE
NX2:
        CALL POPA                       ;PURGE THIS LOOP
        RST 30H

;*************************************************************
;
; *** REM *** IF *** INPUT *** & LET (& DEFLT) ***
;
; 'REM' CAN BE FOLLOWED BY ANYTHING AND IS IGNORED BY TBI.
; TBI TREATS IT LIKE AN 'IF' WITH A FALSE CONDITION.
;
; 'IF' IS FOLLOWED BY AN EXPR. AS A CONDITION AND ONE OR MORE
; COMMANDS (INCLUDING OTHER 'IF'S) SEPERATED BY SEMI-COLONS.
; NOTE THAT THE WORD 'THEN' IS NOT USED.  TBI EVALUATES THE
; EXPR. IF IT IS NON-ZERO, EXECUTION CONTINUES.  IF THE
; EXPR. IS ZERO, THE COMMANDS THAT FOLLOWS ARE IGNORED AND
; EXECUTION CONTINUES AT THE NEXT LINE.
;
; 'INPUT' COMMAND IS LIKE THE 'PRINT' COMMAND, AND IS FOLLOWED
; BY A LIST OF ITEMS.  IF THE ITEM IS A STRING IN SINGLE OR
; DOUBLE QUOTES, OR IS A BACK-ARROW, IT HAS THE SAME EFFECT AS
; IN 'PRINT'.  IF AN ITEM IS A VARIABLE, THIS VARIABLE NAME IS
; PRINTED OUT FOLLOWED BY A COLON.  THEN TBI WAITS FOR AN
; EXPR. TO BE TYPED IN.  THE VARIABLE IS THEN SET TO THE
; VALUE OF THIS EXPR.  IF THE VARIABLE IS PROCEDED BY A STRING
; (AGAIN IN SINGLE OR DOUBLE QUOTES), THE STRING WILL BE
; PRINTED FOLLOWED BY A COLON.  TBI THEN WAITS FOR INPUT EXPR.
; AND SET THE VARIABLE TO THE VALUE OF THE EXPR.
;
; IF THE INPUT EXPR. IS INVALID, TBI WILL PRINT "WHAT?",
; "HOW?" OR "SORRY" AND REPRINT THE PROMPT AND REDO THE INPUT.
; THE EXECUTION WILL NOT TERMINATE UNLESS YOU TYPE CONTROL-C.
; THIS IS HANDLED IN 'INPERR'.
;
; 'LET' IS FOLLOWED BY A LIST OF ITEMS SEPERATED BY COMMAS.
; EACH ITEM CONSISTS OF A VARIABLE, AN EQUAL SIGN, AND AN EXPR.
; TBI EVALUATES THE EXPR. AND SET THE VARIABLE TO THAT VALUE.
; TBI WILL ALSO HANDLE 'LET' COMMAND WITHOUT THE WORD 'LET'.
; THIS IS DONE BY 'DEFLT'.
;*************************************************************

REM:
        LD HL,0000H                     ;*** REM ***
        DB 3EH                          ;THIS IS LIKE 'IF 0'
IFF:
        RST 18H                         ;*** IF ***
        LD A,H                          ;IS THE EXPR.=0?
        OR L
        JP NZ,RUNSML                    ;NO, CONTINUE
        CALL FNDSKP                     ;YES, SKIP REST OF LINE
        JP NC,RUNTSL                    ;AND RUN THE NEXT LINE
        JP RSTART                       ;IF NO NEXT, RE-START
INPERR:
        LD HL,(STKINP)                  ;*** INPERR ***
        LD SP,HL                        ;RESTORE OLD SP
        POP HL                          ;AND OLD 'CURRNT'
        LD (CURRNT),HL
        POP DE                          ;AND OLD TEXT POINTER
        POP DE                          ;REDO INPUT
INPUT:                                  ;*** INPUT ***
IP1:
        PUSH DE                         ;SAVE IN CASE OF ERROR
        CALL QTSTG                      ;IS NEXT ITEM A STRING?
        JR IP2                          ;NO
        RST 38H                         ;YES, BUT FOLLOWED BY A
        JR C,IP4                        ;VARIABLE? NO.
        JR IP3                          ;YES. INPUT VARIABLE
IP2:
        PUSH DE                         ;SAVE FOR 'PRTSTG'
        RST 38H                         ;MUST BE VARIABLE NOW
        JP C,QWHAT                      ;"WHAT?" IT IS NOT?
        LD A,(DE)                       ;GET READY FOR 'PRTSTR'
        LD C,A
        SUB A
        LD (DE),A
        POP DE
        CALL PRTSTG                     ;PRINT STRING AS PROMPT
        LD A,C                          ;RESTORE TEXT
        DEC DE
        LD (DE),A
IP3:
        PUSH DE                         ;SAVE TEXT POINTER
        EX DE,HL
        LD HL,(CURRNT)                  ;ALSO SAVE 'CURRNT'
        PUSH HL
        LD HL,IP1                       ;A NEGATIVE NUMBER
        LD (CURRNT),HL                  ;AS A FLAG
        LD HL,0000H                     ;SAVE SP TOO
        ADD HL,SP
        LD (STKINP),HL
        PUSH DE                         ;OLD HL
        LD A,3AH                        ;PRINT THIS TOO
        CALL GETLN                      ;AND GET A LINE
        LD DE,BUFFER                    ;POINTS TO BUFFER
        RST 18H                         ;EVALUATE INPUT
        NOP                             ;CAN BE 'CALL ENDCHK'
        NOP
        NOP
        POP DE                          ;OK,GET OLD HL
        EX DE,HL
        LD (HL),E                       ;SAVE VALUE IN VAR.
        INC HL
        LD (HL),D
        POP HL                          ;GET OLD 'CURRNT'
        LD (CURRNT),HL
        POP DE                          ;AND OLD TEXT POINTER
IP4:
        POP AF                          ;PURGE JUNK IN STACK
        RST 08H                         ;IS NEXT CH. ','?
        DB ','
        DB IP5-$-1
        JR IP1                          ;YES, MORE ITEMS.
IP5:
        RST 30H
DEFLT:
        LD A,(DE)                       ;***  DEFLT ***
        CP CR                           ;EMPTY LINE IS OK
        JR Z,LT1                        ;ELSE IT IS 'LET'
LET:
        CALL SETVAL                     ;*** LET ***
        RST 08H                         ;SET VALUE TO VAR
        DB ','                          ;---DISASSEMBLE = INC L
        DB LT1-$-1                      ;---DISASSEMBLE = INC BC
        JR LET                          ;ITEM BY ITEM
LT1:
        RST 30H                         ;UNTIL FINISH
;*************************************************************
;
; *** EXPR ***
;
; 'EXPR' EVALUATES ARITHMETICAL OR LOGICAL EXPRESSIONS.
; <EXPR>::<EXPR2>
;         <EXPR2><REL.OP.><EXPR2>
; WHERE <REL.OP.> IS ONE OF THE OPERATORS IN TAB8 AND THE
; RESULT OF THESE OPERATIONS IS 1 IF TRUE AND 0 IF FALSE.
; <EXPR2>::=(+ OR -)<EXPR3>(+ OR -<EXPR3>)(....)
; WHERE () ARE OPTIONAL AND (....) ARE OPTIONAL REPEATS.
; <EXPR3>::=<EXPR4>(* OR /><EXPR4>)(....)
; <EXPR4>::=<VARIABLE>
;           <FUNCTION>
;           (<EXPR>)
; <EXPR> IS RECURSIVE SO THAT VARIABLE '@' CAN HAVE AN <EXPR>
; AS INDEX, FUNCTIONS CAN HAVE AN <EXPR> AS ARGUMENTS, AND
; <EXPR4> CAN BE AN <EXPR> IN PARANTHESE.
;*************************************************************

EXPR1:
        LD HL,TAB8-1                    ;LOOKUP REL.OP.
        JP EXEC                         ;GO DO IT
XP11:
        CALL XP18                       ;REL.OP.">="
        RET C                           ;NO, RETURN HL=0
        LD L,A                          ;YES, RETURN HL=1
        RET
XP12:
        CALL XP18                       ;REL.OP."#"
        RET Z                           ;FALSE, RETURN HL=0
        LD L,A                          ;TRUE, RETURN HL=1
        RET
XP13:
        CALL XP18                       ;REL.OP.">"
        RET Z                           ;FALSE
        RET C                           ;ALSO FALSE, HL=0
        LD L,A                          ;TRUE, HL=1
        RET
XP14:
        CALL XP18                       ;REL.OP."<="
        LD L,A                          ;SET HL=1
        RET Z                           ;REL. TRUE, RETURN
        RET C
        LD L,H                          ;ELSE SET HL=0
        RET
XP15:
        CALL XP18                       ;REL.OP."="
        RET NZ                          ;FALSE, RETURN HL=0
        LD L,A                          ;ELSE SET HL=1
        RET
XP16:
        CALL XP18                       ;REL.OP."<"
        RET NC                          ;FALSE, RETURN HL=0
        LD L,A                          ;ELSE SET HL=1
        RET
XP17:
        POP HL                          ;NOT .REL.OP
        RET                             ;RETURN HL=<EXPR2>
XP18:
        LD A,C                          ;SUBROUTINE FOR ALL
        POP HL                          ;REL.OP.'S
        POP BC
        PUSH HL                         ;REVERSE TOP OF STACK
        PUSH BC
        LD C,A
        CALL EXPR2                      ;GET 2ND <EXPR2>
        EX DE,HL                        ;VALUE IN DE NOW
        EX (SP),HL                      ;1ST <EXPR2> IN HL
        CALL CKHLDE                     ;COMPARE 1ST WITH 2ND
        POP DE                          ;RESTORE TEXT POINTER
        LD HL,0000H                     ;SET HL=0, A=1
        LD A,01H
        RET
EXPR2:
        RST 08H                         ;NEGATIVE SIGN?
        DB '-'
        DB XP21-$-1
        LD HL,0000H                     ;YES, FAKE '0-'
        JR XP26                         ;TREAT LIKE SUBTRACT
XP21:
        RST 08H                         ;POSITIVE SIGN? IGNORE
        DB '+'
        DB XP22-$-1
XP22:
        CALL EXPR3                      ;1ST <EXPR3>
XP23:
        RST 08H                         ;ADD?
        DB  '+'
        DB XP25-$-1
        PUSH HL                         ;YES, SAVE VALUE
        CALL EXPR3                      ;GET 2ND <EXPR3>
XP24:
        EX DE,HL                        ;2ND IN DE
        EX (SP),HL                      ;1ST IN HL
        LD A,H                          ;COMPARE SIGN
        XOR D
        LD A,D
        ADD HL,DE
        POP DE                          ;RESTORE TEXT POINTER
        JP M,XP23                       ;1ST AND 2ND SIGN DIFFER
        XOR H                           ;1ST AND 2ND SIGN EQUAL
        JP P,XP23                       ;SO IS RESULT
        JP QHOW                         ;ELSE WE HAVE OVERFLOW
XP25:
        RST 08H                         ;SUBTRACT?
        DB '-'
        DB XP42-$-1
XP26:
        PUSH HL                         ;YES, SAVE 1ST <EXPR3>
        CALL EXPR3                      ;GET 2ND <EXPR3>
        CALL CHGSGN                     ;NEGATE
        JR XP24                         ;AND ADD THEM
;
EXPR3:
        CALL EXPR4                      ;GET 1ST <EXPR4>
XP31:
        RST 08H                         ;MULTIPLY?
        DB '*'
        DB XP34-$-1
        PUSH HL                         ;YES, SAVE 1ST
        CALL EXPR4                      ;AND GET 2ND <EXPR4>
        LD B,00H                        ;CLEAR B FOR SIGN
        CALL CHKSGN                     ;CHECK SIGN
        EX (SP),HL                      ;1ST IN HL
        CALL CHKSGN                     ;CHECK SIGN OF 1ST
        EX DE,HL
        EX (SP),HL
        LD A,H                          ;IS HL > 255 ?
        OR A
        JR Z,XP32                       ;NO
        LD A,D                          ;YES, HOW ABOUT DE
        OR D
        EX DE,HL                        ;PUT SMALLER IN HL
        JP NZ,AHOW                      ;ALSO >, WILL OVERFLOW
XP32:
        LD A,L                          ;THIS IS DUMB
        LD HL,0000H                     ;CLEAR RESULT
        OR A                            ;ADD AND COUNT
        JR Z,XP35
XP33:
        ADD HL,DE
        JP C,AHOW                       ;OVERFLOW
        DEC A
        JR NZ,XP33
        JR XP35                         ;FINISHED
XP34:
        RST 08H                         ;DIVIDE?
        DB '/'
        DB XP42-$-1
        PUSH HL                         ;YES, SAVE 1ST <EXPR4>
        CALL EXPR4                      ;AND GET THE SECOND ONE
        LD B,00H                        ;CLEAR B FOR SIGN
        CALL CHKSGN                     ;CHECK SIGN OF 2ND
        EX (SP),HL                      ;GET 1ST IN HL
        CALL CHKSGN                     ;CHECK SIGN OF 1ST
        EX DE,HL
        EX (SP),HL
        EX DE,HL
        LD A,D                          ;DIVIDE BY 0?
        OR E
        JP Z,AHOW                       ;SAY "HOW?"
        PUSH BC                         ;ELSE SAVE SIGN
        CALL DIVIDE                     ;USE SUBROUTINE
        LD H,B                          ;RESULT IN HL NOW
        LD L,C
        POP BC                          ;GET SIGN BACK
XP35:
        POP DE                          ;AND TEXT POINTER
        LD A,H                          ;HL MUST BE +
        OR A
        JP M,QHOW                       ;ELSE IT IS OVERFLOW
        LD A,B
        OR A
        CALL M,CHGSGN                   ;CHANGE SIGN IF NEEDED
        JR XP31                         ;LOOK FOR MORE TERMS
EXPR4:
        LD HL,TAB4-1                    ;FIND FUNCTION IN TAB4
        JP EXEC                         ;AND GO DO IT
XP40:
        RST 38H                         ;NO, NOT A FUNCTION
        JR C,XP41                       ;NOR A VARIABLE
        LD A,(HL)                       ;VARIABLE
        INC HL
        LD H,(HL)                       ;VALUE IN HL
        LD L,A
        RET
XP41:
        CALL TSTNUM                     ;OR IS IT A NUMBER
        LD A,B                          ;# OF DIGIT
        OR A
        RET NZ                          ;OK
PARN:
        RST 08H
        DB '('
        DB XP43-$-1
        RST 18H                         ;"(EXPR)"
        RST 08H
        DB ')'
        DB XP43-$-1
XP42:
        RET
XP43:
        JP QWHAT                        ;ELSE SAY: "WHAT?"
RND:
        CALL PARN                       ;*** RND(EXPR) ***
        LD A,H                          ;EXPR MUST BE +
        OR A
        JP M,QHOW
        OR L                            ;AND NON-ZERO
        JP Z,QHOW
        PUSH DE                         ;SAVE BOTH
        PUSH HL
        LD HL,(RANPNT)                  ;GET MEMORY AS RANDOM
        LD DE,LSTROM                    ;NUMBER
        RST 20H
        JR C,RA1                        ;WRAP AROUND IF LAST
        LD HL,START
RA1:
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD (RANPNT),HL
        POP HL
        EX DE,HL
        PUSH BC
        CALL DIVIDE                     ;RND (N)=MOD(M,N)+1
        POP BC
        POP DE
        INC HL
        RET
ABS:
        CALL PARN                       ;*** ABS (EXPR) ***
        DEC DE
        CALL CHKSGN                     ;CHECK SIGN
        INC DE
        RET
SIZE:
        LD HL,(TXTUNF)                  ;*** SIZE ***
        PUSH DE                         ;GET THE NUMBER OF FREE
        EX DE,HL                        ;BYTES BETWEEN 'TXTUNF'
        LD HL,VARBGN                    ;AND 'VARBGN'
        CALL SUBDE
        POP DE
        RET
;*************************************************************
;
; *** DIVIDE *** SUBDE *** CHKSGN *** CHGSGN *** & CKHLDE ***
;
; 'DIVIDE' DIVIDES HL BY DE, RESULT IN BC, REMAINDER IN HL
;
; 'SUBDE' SUBSTRACTS DE FROM HL
;
; 'CHKSGN' CHECKS SIGN OF HL.  IF +, NO CHANGE.  IF -, CHANGE
; SIGN AND FLIP SIGN OF B.
;
; 'CHGSGN' CHECKS SIGN N OF HL AND B UNCONDITIONALLY.
;
; 'CKHLDE' CHECKS SIGN OF HL AND DE.  IF DIFFERENT, HL AND DE
; ARE INTERCHANGED.  IF SAME SIGN, NOT INTERCHANGED.  EITHER
; CASE, HL DE ARE THEN COMPARED TO SET THE FLAGS.
;*************************************************************

DIVIDE:
        PUSH HL                         ;*** DIVIDE ***
        LD L,H                          ;DIVIDE H BY DE
        LD H,00H
        CALL DV1
        LD B,C                          ;SAVE RESULT IN B
        LD A,L                          ;(REMAINDER+L)/DE
        POP HL
        LD H,A
DV1:
        LD C,0FFH                       ;RESULT IN C
DV2:
        INC C                           ;DUMB ROUTINE
        CALL SUBDE                      ;DIVIDE BY SUBTRACT
        JR NC,DV2                       ;AND COUNT
        ADD HL,DE
        RET
SUBDE:
        LD A,L                          ;*** SUBDE ***
        SUB E                           ;SUBSTRACT DE FROM
        LD L,A                          ;HL
        LD A,H
        SBC A,D
        LD H,A
        RET
CHKSGN:
        LD A,H                          ;*** CHKSGN ***
        OR A                            ;CHECK SIGN OF HL
        RET P
CHGSGN:
        LD A,H                          ;*** CHGSGN ***
        PUSH AF
        CPL                             ;CHANGE SIGN OF HL
        LD H,A
        LD A,L
        CPL
        LD L,A
        INC HL
        POP AF
        XOR H
        JP P,QHOW
        LD A,B                          ;AND ALSO FLIP B
        XOR 80H
        LD B,A
        RET
CKHLDE:
        LD A,H                          ;SAME SIGN?
        XOR D                           ;YES, COMPARE
        JP P,CK1                        ;NO, XCHANGE AND COMP
        EX DE,HL
CK1:
        RST 20H
        RET
;*************************************************************
;
; *** SETVAL *** FIN *** ENDCHK *** & ERROR (& FRIENDS) ***
;
; "SETVAL" EXPECTS A VARIABLE, FOLLOWED BY AN EQUAL SIGN AND
; THEN AN EXPR.  IT EVALUATES THE EXPR. AND SET THE VARIABLE
; TO THAT VALUE.
;
; "FIN" CHECKS THE END OF A COMMAND.  IF IT ENDED WITH ";",
; EXECUTION CONTINUES.  IF IT ENDED WITH A CR, IT FINDS THE
; NEXT LINE AND CONTINUE FROM THERE.
;
; "ENDCHK" CHECKS IF A COMMAND IS ENDED WITH CR.  THIS IS
; REQUIRED IN CERTAIN COMMANDS.  (GOTO, RETURN, AND STOP ETC.)
;
; "ERROR" PRINTS THE STRING POINTED BY DE (AND ENDS WITH CR).
; IT THEN PRINTS THE LINE POINTED BY 'CURRNT' WITH A "?"
; INSERTED AT WHERE THE OLD TEXT POINTER (SHOULD BE ON TOP
; OF THE STACK) POINTS TO.  EXECUTION OF TB IS STOPPED
; AND TBI IS RESTARTED.  HOWEVER, IF 'CURRNT' -> ZERO
; (INDICATING A DIRECT COMMAND), THE DIRECT COMMAND IS NOT
; PRINTED.  AND IF 'CURRNT' -> NEGATIVE # (INDICATING 'INPUT'
; COMMAND), THE INPUT LINE IS NOT PRINTED AND EXECUTION IS
; NOT TERMINATED BUT CONTINUED AT 'INPERR'.
;
; RELATED TO 'ERROR' ARE THE FOLLOWING:
; 'QWHAT' SAVES TEXT POINTER IN STACK AND GET MESSAGE "WHAT?"
; 'AWHAT' JUST GET MESSAGE "WHAT?" AND JUMP TO 'ERROR'.
; 'QSORRY' AND 'ASORRY' DO SAME KIND OF THING.
; 'AHOW' AND 'AHOW' IN THE ZERO PAGE SECTION ALSO DO THIS.
;*************************************************************

SETVAL:
        RST 38H                         ;*** SETVAL ***
        JP C,QWHAT                      ;"WHAT?" NO VARIABLE
        PUSH HL                         ;SAVE ADDRESS OF VAR.
        RST 08H                         ;PASS "=" SIGN
        DB '='
        DB SV1-$-1
        RST 18H                         ;EVALUATE EXPR.
        LD B,H                          ;VALUE IS IN BC NOW
        LD C,L
        POP HL                          ;GET ADDRESS
        LD (HL),C                       ;SAVE VALUE
        INC HL
        LD (HL),B
        RET
SV1:
        JP QWHAT                        ;NO "=" SIGN
FIN:
        RST 08H                         ;*** FIN ***
        DB 3BH
        DB FI1-$-1
        POP AF                          ;";", PURGE RET. ADDR.
        JP RUNSML                       ;CONTINUE SAME LINE
FI1:
        RST 08H                         ;NOT ";", IS IT CR?
        DB CR
        DB FI2-$-1
        POP AF                          ;YES, PURGE RET. ADDR.
        JP RUNNXL                       ;RUN NEXT LINE
FI2:
        RET                             ;ELSE RETURN TO CALLER
ENDCHK:
        RST 28H                         ;*** ENDCHK ***
        CP CR                           ;END WITH CR?
        RET Z                           ;OK, ELSE SAY: "WHAT?"
QWHAT:
        PUSH DE                         ;*** QWHAT ***
AWHAT:
        LD DE,WHAT                      ;*** AWHAT ***
ERROR_ROUTINE:
        SUB A                           ;*** ERROR ***
        CALL PRTSTG                     ;PRINT 'WHAT?', 'HOW?'
        POP DE                          ;OR 'SORRY'
        LD A,(DE)                       ;SAVE THE CHARACTER
        PUSH AF                         ;AT WHERE OLD DE ->
        SUB A                           ;AND PUT A 0 THERE
        LD (DE),A
        LD HL,(CURRNT)                  ;GET CURRENT LINE #
        PUSH HL
        LD A,(HL)                       ;CHECK THE VALUE
        INC HL
        OR (HL)
        POP DE
        JP Z,RSTART                     ;IF ZERO, JUST RESTART
        LD A,(HL)                       ;IF NEGATIVE,
        OR A
        JP M,INPERR                     ;REDO INPUT
        CALL PRTLN                      ;ELSE PRINT THE LINE
        DEC DE                          ;UPTO WHERE THE 0 IS
        POP AF                          ;RESTORE THE CHARACTER
        LD (DE),A
        LD A,3FH                        ;PRINT A "?"
        RST 10H
        SUB A                           ;AND THE REST OF THE
        CALL PRTSTG                     ;LINE
        JP RSTART                       ;THEN RESTART
QSORRY:
        PUSH DE                         ;*** QSORRY ***
ASORRY:
        LD DE,SORRY                     ;*** ASORRY ***
        JR ERROR_ROUTINE
;*************************************************************
;
; *** GETLN *** FNDLN (& FRIENDS) ***
;
; 'GETLN' READS A INPUT LINE INTO 'BUFFER'.  IT FIRST PROMPT
; THE CHARACTER IN A (GIVEN BY THE CALLER), THEN IT FILLS
; THE BUFFER AND ECHOS.  IT IGNORES LF'S AND NULLS, BUT STILL
; ECHOS THEM BACK.  RUB-OUT IS USED TO CAUSE IT TO DELETE
; THE LAST CHARACTER (IF THERE IS ONE), AND ALT-MOD IS USED TO
; CAUSE IT TO DELETE THE WHOLE LINE AND START IT ALL OVER.
; CR SIGNALS THE END OF A LINE, AND CAUSE 'GETLN' TO RETURN.
;
; 'FNDLN' FINDS A LINE WITH A GIVEN LINE # (IN HL) IN THE
; TEXT SAVE AREA.  DE IS USED AS THE TEXT POINTER.  IF THE
; LINE IS FOUND, DE WILL POINT TO THE BEGINNING OF THAT LINE
; (I.E., THE LOW BYTE OF THE LINE #), AND FLAGS ARE NC & Z.
; IF THAT LINE IS NOT THERE AND A LINE WITH A HIGHER LINE #
; IS FOUND, DE POINTS TO THERE AND FLAGS ARE NC & NZ.  IF
; WE REACHED THE END OF TEXT SAVE AREA AND CANNOT FIND THE
; LINE, FLAGS ARE C & NZ.
; 'FNDLN' WILL INITIALIZE DE TO THE BEGINNING OF THE TEXT SAVE
; AREA TO START THE SEARCH.  SOME OTHER ENTRIES OF THIS
; ROUTINE WILL NOT INITIALIZE DE AND DO THE SEARCH.
; 'FNDLNP' WILL START WITH DE AND SEARCH FOR THE LINE #.
; 'FNDNXT' WILL BUMP DE BY 2, FIND A CR AND THEN START SEARCH.
; 'FNDSKP' USE DE TO FIND A CR, AND THEN START SEARCH.
;*************************************************************

GETLN:
        RST 10H                         ;*** GETLN ***
        LD DE,BUFFER                    ;PROMPT AND INIT.
GL1:
        CALL CHKIO                      ;CHECK KEYBOARD
        JR Z,GL1                        ;NO INPUT, WAIT
        CP 7FH                          ;DELETE LAST CHARACTER?
        JR Z,GL3                        ;YES
        RST 10H                         ;INPUT, ECHO BACK
        CP 0AH                          ;IGNORE LF
        JR Z,GL1
        OR A                            ;IGNORE NULL
        JR Z,GL1
        CP 7DH                          ;DELETE THE WHOLE LINE?
        JR Z,GL4                        ;YES
        LD (DE),A                       ;ELSE SAVE INPUT
        INC DE                          ;AND BUMP POINTER
        CP 0DH                          ;WAS IT CR
        RET Z                           ;YES, END OF LINE
        LD A,E                          ;ELSE MORE FREE ROOM?
        CP BUFEND & 0FFH
        JR NZ,GL1                       ;YES, GET NEXT INPUT
GL3:
        LD A,E                          ;DELETE LAST CHARACTER
        CP BUFFER & 0FFH                ;BUT DO WE HAVE ANY?
        JR Z,GL4                        ;NO, REDO WHOLE LINE
        DEC DE                          ;YES, BACKUP POINTER
        LD A,5CH                        ;AND ECHO A BACK-SLASH
        RST 10H
        JR GL1                          ;GO GET NEXT INPUT
GL4:
        CALL CRLF                       ;REDO ENTIRE LINE
        LD A,05EH                       ;CR, LF AND UP-ARROW
        JR GETLN
FNDLN:
        LD A,H                          ;*** FNDLN ***
        OR A                            ;CHECK SIGN OF HL
        JP M,QHOW                       ;IT CANNOT BE -
        LD DE,TXTBGN                    ;INIT TEXT POINTER
FNDLP:                                  ;*** FDLNP ***
FL1:
        PUSH HL                         ;SAVE LINE #
        LD HL,(TXTUNF)                  ;CHECK IF WE PASSED END
        DEC HL
        RST 20H
        POP HL                          ;GET LINE # BACK
        RET C                           ;C,NZ PASSED END
        LD A,(DE)                       ;WE DID NOT, GET BYTE 1
        SUB L                           ;IS THIS THE LINE?
        LD B,A                          ;COMPARE LOW ORDER
        INC DE
        LD A,(DE)                       ;GET BYTE 2
        SBC A,H                         ;COMPARE HIGH ORDER
        JR C,FL2                        ;NO, NOT THERE YET
        DEC DE                          ;ELSE WE EITHER FOUND
        OR B                            ;IT, OR IT IS NOT THERE
        RET                             ;NC,Z;FOUND, NC,NZ:NO
FNDNXT:                                 ;*** FNDNXT ***
        INC DE                          ;FIND NEXT LINE
FL2:
        INC DE                          ;JUST PASSED BYTE 1 & 2
FNDSKP:
        LD A,(DE)                       ;*** FNDSKP ***
        CP CR                           ;TRY TO FIND CR
        JR NZ,FL2                       ;KEEP LOOKING
        INC DE                          ;FOUND CR, SKIP OVER
        JR FL1                          ;CHECK IF END OF TEXT
;*************************************************************
;
; *** PRTSTG *** QTSTG *** PRTNUM *** & PRTLN ***
;
; 'PRTSTG' PRINTS A STRING POINTED BY DE.  IT STOPS PRINTING
; AND RETURNS TO CALLER WHEN EITHER A CR IS PRINTED OR WHEN
; THE NEXT BYTE IS THE SAME AS WHAT WAS IN A (GIVEN BY THE
; CALLER).  OLD A IS STORED IN B, OLD B IS LOST.
;
; 'QTSTG' LOOKS FOR A BACK-ARROW, SINGLE QUOTE, OR DOUBLE
; QUOTE.  IF NONE OF THESE, RETURN TO CALLER.  IF BACK-ARROW,
; OUTPUT A CR WITHOUT A LF.  IF SINGLE OR DOUBLE QUOTE, PRINT
; THE STRING IN THE QUOTE AND DEMANDS A MATCHING UNQUOTE.
; AFTER THE PRINTING THE NEXT 3 BYTES OF THE CALLER IS SKIPPED
; OVER (USUALLY A JUMP INSTRUCTION.
;
; 'PRTNUM' PRINTS THE NUMBER IN HL.  LEADING BLANKS ARE ADDED
; IF NEEDED TO PAD THE NUMBER OF SPACES TO THE NUMBER IN C.
; HOWEVER, IF THE NUMBER OF DIGITS IS LARGER THAN THE # IN
; C, ALL DIGITS ARE PRINTED ANYWAY.  NEGATIVE SIGN IS ALSO
; PRINTED AND COUNTED IN, POSITIVE SIGN IS NOT.
;
; 'PRTLN' PRINTS A SAVED TEXT LINE WITH LINE # AND ALL.
;*************************************************************

PRTSTG:
        LD B,A                          ;*** PRTSTG ***
PS1:
        LD A,(DE)                       ;GET A CHARACTER
        INC DE                          ;BUMP POINTER
        CP B                            ;SAME AS OLD A?
        RET Z                           ;YES, RETURN
        RST 10H                         ;NO, NEXT
        CP CR                           ;WAS IT A CR?
        JR NZ,PS1                       ;NO, NEXT
        RET                             ;YES, RETURN
QTSTG:
        RST 08H                         ;*** QTSTG ***
        DB '"'
        DB QT3-$-1
        LD A,22H                        ;IT IS A "
QT1:
        CALL PRTSTG                     ;PRINT UNTIL ANOTHER
        CP CR                           ;WAS LAST ONE A CR?
        POP HL                          ;RETURN ADDRESS
        JP Z,RUNNXL                     ;WAS CR, RUN NEXT LINE
QT2:
        INC HL                          ;SKIP 3 BYTES ON RETURN
        INC HL
        INC HL
        JP (HL)                         ;RETURN
QT3:
        RST 08H                         ;IS IT A '?
        DB 27H
        DB QT4-$-1
        LD A,27H                        ;YES, DO THE SAME
        JR QT1                          ;AS IN "
QT4:
        RST 08H                         ;IS IT BACK-ARROW?
        DB 5FH
        DB QT5-$-1
        LD A,8DH                        ;YES, CR WITHOUT LF
        RST 10H                         ;DO IT TWICE TO GIVE
        RST 10H                         ;TTY ENOUGH TIME
        POP HL                          ;RETURN ADDRESS
        JR QT2
QT5:
        RET                             ;NONE OF ABOVE
;
PRTNUM:
        LD B,00H                        ;*** PRTNUM ***
        CALL CHKSGN                     ;CHECK SIGN
        JP P,PN1                        ;NO SIGN
        LD B,'-'                        ;B=SIGN
        DEC C                           ;'-' TAKES SPACE
PN1:
        PUSH DE                         ;SAVE
        LD DE,000AH                     ;DECIMAL
        PUSH DE                         ;SAVE AS FLAG
        DEC C                           ;C=SPACES
        PUSH BC                         ;SAVE SIGN & SPACE
PN2:
        CALL DIVIDE                     ;DIVIDE HL BY 10
        LD A,B                          ;RESULT 0?
        OR C
        JR Z,PN3                        ;YES, WE GOT ALL
        EX (SP),HL                      ;NO, SAVE REMAINDER
        DEC L                           ;AND COUNT SPACE
        PUSH HL                         ;HL IS OLD BC
        LD H,B                          ;MOVE RESULT TO BC
        LD L,C
        JR PN2                          ;AND DIVIDE BY 10
PN3:
        POP BC                          ;WE GOT ALL DIGITS IN
PN4:
        DEC C                           ;THE STACK
        LD A,C                          ;LOOK AT SPACE COUNT
        OR A
        JP M,PN5                        ;NO LEADING BLANKS
        LD A,20H                        ;LEADING BLANKS
        RST 10H
        JR PN4                          ;MORE?
PN5:
        LD A,B                          ;PRINT SIGN
        OR A
        CALL NZ,0010H
        LD E,L                          ;LAST REMAINDER IN E
PN6:
        LD A,E                          ;CHECK DIGIT IN E
        CP 0AH                          ;10 IS FLAG FOR NO MORE
        POP DE
        RET Z                           ;IF SO, RETURN
        ADD A,30H                       ;ELSE, CONVERT TO ASCII
        RST 10H                         ;PRINT THE DIGIT
        JR PN6                          ;GO BACK FOR MORE
PRTLN:
        LD A,(DE)                       ;*** PRTLN ***
        LD L,A                          ;LOW ORDER LINE #
        INC DE
        LD A,(DE)                       ;HIGH ORDER
        LD H,A
        INC DE
        LD C,04H                        ;PRINT 4 DIGIT LINE #
        CALL PRTNUM
        LD A,20H                        ;FOLLOWED BY A BLANK
        RST 10H
        SUB A                           ;AND THEN THE NEXT
        CALL PRTSTG
        RET
;*************************************************************
;
; *** MVUP *** MVDOWN *** POPA *** & PUSHA ***
;
; 'MVUP' MOVES A BLOCK UP FROM WHERE DE-> TO WHERE BC-> UNTIL
; DE = HL
;
; 'MVDOWN' MOVES A BLOCK DOWN FROM WHERE DE-> TO WHERE HL->
; UNTIL DE = BC
;
; 'POPA' RESTORES THE 'FOR' LOOP VARIABLE SAVE AREA FROM THE
; STACK
;
; 'PUSHA' STACKS THE 'FOR' LOOP VARIABLE SAVE AREA INTO THE
; STACK
;*************************************************************

MVUP:
        RST 20H                         ;*** MVUP ***
        RET Z                           ;DE = HL, RETURN
        LD A,(DE)                       ;GET ONE BYTE
        LD (BC),A                       ;MOVE IT
        INC DE                          ;INCREASE BOTH POINTERS
        INC BC
        JR MVUP                         ;UNTIL DONE
MVDOWN:
        LD A,B                          ;*** MVDOWN ***
        SUB D                           ;TEST IF DE = BC
        JP NZ,MD1                       ;NO, GO MOVE
        LD A,C                          ;MAYBE, OTHER BYTE?
        SUB E
        RET Z                           ;YES, RETURN
MD1:
        DEC DE                          ;ELSE MOVE A BYTE
        DEC HL                          ;BUT FIRST DECREASE
        LD A,(DE)                       ;BOTH POINTERS AND
        LD (HL),A                       ;THEN DO IT
        JR MVDOWN                       ;LOOP BACK
POPA:
        POP BC                          ;BC = RETURN ADDR.
        POP HL                          ;RESTORE LOPVAR, BUT
        LD (LOPVAR),HL                  ;=0 MEANS NO MORE
        LD A,H
        OR L
        JR Z,PP1                        ;YEP, GO RETURN
        POP HL                          ;NOP, RESTORE OTHERS
        LD (LOPINC),HL
        POP HL
        LD (LOPLMT),HL
        POP HL
        LD (LOPLN),HL
        POP HL
        LD (LOPPT),HL
PP1:
        PUSH BC                         ;BC = RETURN ADDR.
        RET
PUSHA:
        LD HL,STKLMT                    ;*** PUSHA ***
        CALL CHGSGN
        POP BC                          ;BC=RETURN ADDRESS
        ADD HL,SP                       ;IS STACK NEAR THE TOP?
        JP NC,QSORRY                    ;YES, SORRY FOR THAT
        LD HL,(LOPVAR)                  ;ELSE SAVE LOOP VAR'S
        LD A,H                          ;BUT IF LOPVAR IS 0
        OR L                            ;THAT WILL BE ALL
        JR Z,PU1
        LD HL,(LOPPT)                   ;ELSE, MORE TO SAVE
        PUSH HL
        LD HL,(LOPLN)
        PUSH HL
        LD HL,(LOPLMT)
        PUSH HL
        LD HL,(LOPINC)
        PUSH HL
        LD HL,(LOPVAR)
PU1:
        PUSH HL
        PUSH BC                         ;BC = RETURN ADDR.
        RET
;*************************************************************
;
; *** OUTC *** & CHKIO ***
;
; THESE ARE THE ONLY I/O ROUTINES IN TBI.
; 'OUTC' IS CONTROLLED BY A SOFTWARE SWITCH 'OCSW'.  IF OCSW=0
; 'OUTC' WILL JUST RETURN TO THE CALLER.  IF OCSW IS NOT 0,
; IT WILL OUTPUT THE BYTE IN A.  IF THAT IS A CR, A LF IS ALSO
; SEND OUT.  ONLY THE FLAGS MAY BE CHANGED AT RETURN. ALL REG.
; ARE RESTORED.
;
; 'CHKIO' CHECKS THE INPUT.  IF NO INPUT, IT WILL RETURN TO
; THE CALLER WITH THE Z FLAG SET.  IF THERE IS INPUT, Z FLAG
; IS CLEARED AND THE INPUT BYTE IS IN A.  HOWEVER, IF THE
; INPUT IS A CONTROL-O, THE 'OCSW' SWITCH IS COMPLIMENTED, AND
; Z FLAG IS RETURNED.  IF A CONTROL-C IS READ, 'CHKIO' WILL
; RESTART TBI AND DO NOT RETURN TO THE CALLER.
;
; Do not modify these routines.  Routines requiring
; modification are : SERIAL_INIT, RX_RDY, and TX_RDY.
;*************************************************************

INIT:
        DI
        CALL SERIAL_INIT        ;INITIALIZE THE SIO
        LD D,19H
PATLOP:
        CALL CRLF
        DEC D
        JR NZ,PATLOP
        SUB A
        LD DE,MSG1          ;PRINT THE BOOT MESSAGES
        CALL PRTSTG
        LD DE,MSG2
        CALL PRTSTG
        LD HL,START
        LD (RANPNT),HL
        LD HL,TXTBGN
        LD (TXTUNF),HL
        JP RSTART
OUTC:
        JR NZ,OUTC2         ;IT IS ON
        POP AF                          ;IT IS OFF
        RET                             ;RESTORE AF AND RETURN
OUTC2:
        CALL TX_RDY         ;SEE IF TRANSMIT IS AVAILABLE
        POP AF                          ;RESTORE THE REGISTER
        OUT (SerialPort),A      ;SEND THE BYTE
        CP CR
        RET NZ
        LD A,LF
        RST 10H
        LD A,CR
        RET
CHKIO:
        CALL RX_RDY         ;CHECK IF CHARACTER AVAILABLE
        RET Z                           ;RETURN IF NO CHARACTER AVAILABLE

        PUSH BC                         ;IF IT'S A LF, IGNORE AND RETURN
        LD B,A                          ; AS IF THERE WAS NO CHARACTER.
        SUB LF
        JR Z,CHKIO2
        LD A,B                          ;OTHERWISE RESTORE 'A' AND 'BC'
        POP BC                          ; AND CONTINUE ON.

        CP 0FH                          ;IS IT CONTROL-0?
        JR NZ,CI1                       ;NO, MORE CHECKING
        LD A,(OCSW)                     ;CONTROL-0 FLIPS OCSW
        CPL                             ;ON TO OFF, OFF TO ON
        LD (OCSW),A
        JR CHKIO                        ;GET ANOTHER INPUT
CHKIO2:
        LD A,00H                        ;CLEAR A
        OR A                            ;ZET THE Z-FLAG
        POP BC                          ;RESTORE THE 'BC' PAIR
        RET                             ;RETURN WITH 'Z' SET.
CI1:
        CP 03H                          ;IS IT CONTROL-C?
        RET NZ                          ;NO, RETURN "NZ"
        JP RSTART                       ;YES, RESTART TBI


MSG1:   DB   ESC,"[2J",ESC,"[H"         ;SCREEN CLEAR
        DB   'Z80 TINY BASIC 2.0g',CR       ;BOOT MESSAGE
MSG2:   DB   'PORTED BY DOUG GABBARD, 2017',CR

;*************************************************************
;
; *** TABLES *** DIRECT *** & EXEC ***
;
; THIS SECTION OF THE CODE TESTS A STRING AGAINST A TABLE.
; WHEN A MATCH IS FOUND, CONTROL IS TRANSFERED TO THE SECTION
; OF CODE ACCORDING TO THE TABLE.
;
; AT 'EXEC', DE SHOULD POINT TO THE STRING AND HL SHOULD POINT
; TO THE TABLE-1.  AT 'DIRECT', DE SHOULD POINT TO THE STRING.
; HL WILL BE SET UP TO POINT TO TAB1-1, WHICH IS THE TABLE OF
; ALL DIRECT AND STATEMENT COMMANDS.
;
; A '.' IN THE STRING WILL TERMINATE THE TEST AND THE PARTIAL
; MATCH WILL BE CONSIDERED AS A MATCH.  E.G., 'P.', 'PR.',
; 'PRI.', 'PRIN.', OR 'PRINT' WILL ALL MATCH 'PRINT'.
;
; THE TABLE CONSISTS OF ANY NUMBER OF ITEMS.  EACH ITEM
; IS A STRING OF CHARACTERS WITH BIT 7 SET TO 0 AND
; A JUMP ADDRESS STORED HI-LOW WITH BIT 7 OF THE HIGH
; BYTE SET TO 1.
;
; END OF TABLE IS AN ITEM WITH A JUMP ADDRESS ONLY.  IF THE
; STRING DOES NOT MATCH ANY OF THE OTHER ITEMS, IT WILL
; MATCH THIS NULL ITEM AS DEFAULT.
;*************************************************************

TAB1:                                   ;DIRECT COMMANDS
        DB 'LIST'
        DWA LIST
        DB 'RUN'
        DWA RUN
        DB 'NEW'
        DWA NEW
TAB2:                                   ;DIRECT/STATEMENT
        DB 'NEXT'
        DWA NEXT
        DB 'LET'
        DWA LET
        DB 'IF'
        DWA IFF
        DB 'GOTO'
        DWA GOTO
        DB 'GOSUB'
        DWA GOSUB
        DB 'RETURN'
        DWA RETURN
        DB 'REM'
        DWA REM
        DB 'FOR'
        DWA FOR
        DB 'INPUT'
        DWA INPUT
        DB 'PRINT'
        DWA PRINT
        DB 'STOP'
        DWA STOP
        DWA DEFLT
TAB4:                                   ;FUNCTIONS
        DB 'RND'
        DWA RND
        DB 'ABS'
        DWA ABS
        DB 'SIZE'
        DWA SIZE
        DWA XP40
TAB5:                                   ;"TO" IN "FOR"
        DB 'TO'
        DWA FR1
        DWA QWHAT
TAB6:                                   ;"STEP" IN "FOR"
        DB 'STEP'
        DWA FR2
        DWA FR3
TAB8:                                   ;RELATION OPERATORS
        DB '>='
        DWA XP11
        DB '#'
        DWA XP12
        DB '>'
        DWA XP13
        DB '='
        DWA XP15
        DB '<='
        DWA XP14
        DB '<'
        DWA XP16
        DWA XP17
DIRECT: LD HL,TAB1-1                   ;*** DIRECT ***
EXEC:                                   ;*** EXEC ***
EX0:    RST 28H                         ;IGNORE LEADING BLANKS
        PUSH DE                         ;SAVE POINTER
EX1:
        LD A,(DE)                       ;IF FOUND '.' IN STRING
        INC DE                          ;BEFORE ANY MISMATCH
        CP 23H                          ;WE DECLARE A MATCH
        JR Z,EX3
        INC HL                          ;HL->TABLE
        CP (HL)                         ;IF MATCH, TEST NEXT
        JR Z,EX1
        LD A,7FH                        ;ELSE SEE IF BIT 7
        DEC DE                          ;OF TABLE IS SET, WHICH
        CP (HL)                         ;IS THE JUMP ADDR. (HI)
        JR C,EX5                        ;C:YES, MATCHED
EX2:
        INC HL                          ;NC:NO, FIND JUMP ADDR.
        CP (HL)
        JR NC,EX2
        INC HL                          ;BUMP TO NEXT TAB. ITEM
        POP DE                          ;RESTORE STRING POINTER
        JR EX0                          ;TEST AGAINST NEXT ITEM
EX3:
        LD A,7FH                        ;PARTIAL MATCH, FIND
EX4:
        INC HL                          ;JUMP ADDR., WHICH IS
        CP (HL)                         ;FLAGGED BY BIT 7
        JR NC,EX4
EX5:
        LD A,(HL)                       ;LOAD HL WITH THE JUMP
        INC HL                          ;ADDRESS FROM THE TABLE
        LD L,(HL)
        AND 7FH                         ;MASK OFF BIT 7
        LD H,A
        POP AF                          ;CLEAN UP THE GABAGE
        JP (HL)                         ;AND WE GO DO IT
;-------------------------------------------------------------------------------
;///////////////////////////////////////////////////////////////////////////////
;-------------------------------------------------------------------------------
;COMPUTER SPECIFIC ROUTINES.
;-------------------------------------------------------------------------------
SERIAL_INIT:

    ; This routine is for initializing your serial port.

        RET
;-------------------------------------------------------------------------------
TX_RDY:
    ; This routine is checking if the Serial Port is ready to send
    ; a character.
    IN A,(0F1h)
    AND 1
    JP NZ,TX_RDY
    RET
        
;-------------------------------------------------------------------------------
RX_RDY:

    ; This routine is for checking if a character is available over
    ; serial. If a character is available, it returns to the calling
    ; function with the character in 'A' and the Z-flag reset.
    ; However, if a character is not available, it returns with the
    ; Z-flag set.

        RET
;-------------------------------------------------------------------------------
;///////////////////////////////////////////////////////////////////////////////
;-------------------------------------------------------------------------------

LSTROM:                                 ;ALL ABOVE CAN BE ROM
                    ;HERE DOWN MUST BE RAM
        ORG  08000H
        ORG  08700H ; Last 256 bytes of RAM
VARBGN: DS   55                         ;VARIABLE @(0)
BUFFER: DS   64                         ;INPUT BUFFER
BUFEND: DS   1                          ;BUFFER ENDS
STKLMT: DS   1                          ;TOP LIMIT FOR STACK
        END
