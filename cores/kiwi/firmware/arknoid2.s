;   THIS FILE IS PART OF JTCORES.
;   JTCORES PROGRAM IS FREE SOFTWARE: YOU CAN REDISTRIBUTE IT AND/OR MODIFY
;   IT UNDER THE TERMS OF THE GNU GENERAL PUBLIC LICENSE AS PUBLISHED BY
;   THE FREE SOFTWARE FOUNDATION, EITHER VERSION 3 OF THE LICENSE, OR
;   (AT YOUR OPTION) ANY LATER VERSION.
;
;   JTCORES PROGRAM IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL,
;   BUT WITHOUT ANY WARRANTY; WITHOUT EVEN THE IMPLIED WARRANTY OF
;   MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.  SEE THE
;   GNU GENERAL PUBLIC LICENSE FOR MORE DETAILS.
;
;   YOU SHOULD HAVE RECEIVED A COPY OF THE GNU GENERAL PUBLIC LICENSE
;   ALONG WITH JTCORES.  IF NOT, SEE <HTTP://WWW.GNU.ORG/LICENSES/>.
;
;   AUTHOR: JOSE TEJADA GOMEZ. TWITTER: @TOPAPATE
;   VERSION: 1.0
;   DATE: 24-4-2023
;
;   FIRMWARE COMPATIBLE WITH ARKANOID 2

	RELAXED ON

CMD	EQU	R4
REPORT 	EQU	R5
OLDCOIN	EQU	R6
CREDITS	EQU	R7

COIN_A	EQU	$30
CRED_A	EQU	$31
COIN_B	EQU	$32
CRED_B	EQU	$33
COUNT_A	EQU	$34
COUNT_B	EQU	$35

TOMAIN  MACRO   VAL
	MOV A,#VAL
	MOV STS,A	; Upper 4 bits can be read in the upper memory address
	MOV A,#VAL	; by the Z80
	OUT DBB,A
LOOP:   JOBF LOOP
	ENDM

WAITFF	MACRO		; wait for about 1ms
	MOV R1,#$FF
LOOP:	DJNZ R1,LOOP
	ENDM

READDB	MACRO
LOOP:	JNIBF LOOP
	IN A,DBB
	ENDM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	ORG 0
	; ABSOLUTE ADDRESSING UPTO ADDRESS 7 = Timer interrupt
	JMP START
	NOP
	RETR    ; ADDRESS 3 = IRQ service
	NOP
	NOP
	RETR
START:      ; ADDRESS 7
	MOV A,#0
	MOV PSW,A
	DIS I
	DIS TCNTI
	STOP TCNT
	CLR F0
	CLR F1


	TOMAIN $55
	; Clear the memory
	MOV R0,#$20
	MOV R1,#$60
	MOV A,#0
$$LOOP:	MOV @R0,A
	INC R0
	DJNZ R1,$$LOOP

	TOMAIN $AA

	; Get 4 values for the coin settings
	MOV R0,#COIN_A
	MOV R1,#4
COINAGE:
	READDB
	CLR F1
	MOV @R0,A
	INC R0
	DJNZ R1,COINAGE

	TOMAIN $5A	; final initialization signal

	MOV CREDITS,#0
	MOV REPORT,#0
	; Poll the coin switches independently from the Z80's C1 command.
	; The timer overflow throttles this polling and gives short pulses a
	; chance to be latched without keeping the status code asserted.
	MOV A,#211
	MOV T,A
	STRT T
	; infinite loop to read cabinet inputs
L:  	JOBF L2
	JMP CKCMD
L2:	CALL RDCOINS
	JNIBF L
	IN A,DBB
	JF1 A1WR
	; check if command is 41
	; then add the data received
	MOV R0,A	; keep the data
	MOV A,CMD
	ADD A,#$BF	; -$41
	JNZ L		; it wasn't $41, ignore
	MOV A,CREDITS
	ADD A,R0
	MOV CREDITS,A
	OUT DBB,A
	JMP L		; should we output the new credit count? / continue
A1WR:
	CLR F1
	MOV CMD,A
	; If CMD=C1, return credits and consume one latched coin report
	ADD A,#$3F	; -$C1
	JNZ CK15
	MOV A,REPORT
	MOV STS,A
	MOV REPORT,#0
	MOV A,CREDITS
	OUT DBB,A
	JMP L
CK15:	; if CMD=15, decrement the credits by 1
	MOV A,CMD
	ADD A,#$EB	; -$15
	JNZ L
	MOV A,CREDITS
	JZ CKCMD
	DEC CREDITS
	JMP L

CKCMD:	; output buttons, all inactive for now
	; A coin report belongs to one C1 reply only.  Clearing the status
	; here prevents a stale coin code from being counted more than once.
	MOV A,#0
	MOV STS,A
	MOV A,#4
	OUTL P2,A
	IN A,P1
	ORL A,#$0F
	MOV R0,A	; 1P inputs here
	MOV A,#5
	OUTL P2,A
	IN A,P1
	RR A
	RR A
	RR A
	RR A
	ORL A,#$F0
	ANL A,R0	; 1P+2P inputs ready
       	OUT DBB,A
	JMP L

RDCOINS:
	; The timer keeps this independent from C1 but avoids re-sampling on
	; every pass through the UPI-41 wait loop.
	MOV A,T
	JNZ COINDONE

	MOV A,#0
	JNT0 T0C	; T0/1 high when coin is held
	ORL A,#0x10
T0C:	JNT1 T1C
	ORL A,#0x20
T1C:	MOV R2,A	; preserve the new coin switches across the coinage calls

	; Each slot is edge-triggered independently.  If both switches close
	; together, report coin A (the same priority as the MAME model) while
	; crediting both slots.
	MOV A,R2
	ANL A,#$10
	JZ CKB
	MOV A,OLDCOIN
	ANL A,#$10
	JNZ CKB
	CALL ADDA
CKB:	MOV A,R2
	ANL A,#$20
	JZ SAVEC
	MOV A,OLDCOIN
	ANL A,#$20
	JNZ SAVEC
	CALL ADDB
SAVEC:
	MOV A,R2
	MOV OLDCOIN,A

COINDONE:
	RET

ADDA:	MOV REPORT,#$10
	MOV R0,#COUNT_A
	MOV A,@R0
	INC A
	MOV @R0,A
	MOV R1,A
	MOV R0,#COIN_A
	MOV A,@R0
	XRL A,R1
	JNZ ADONE
	MOV R0,#COUNT_A
	MOV A,#0
	MOV @R0,A
	MOV R0,#CRED_A
	MOV A,@R0
	CALL ADDCRED
ADONE:	RET

ADDB:	MOV A,REPORT
	JNZ BCOUNT
	MOV REPORT,#$20
BCOUNT:	MOV R0,#COUNT_B
	MOV A,@R0
	INC A
	MOV @R0,A
	MOV R1,A
	MOV R0,#COIN_B
	MOV A,@R0
	XRL A,R1
	JNZ BDONE
	MOV R0,#COUNT_B
	MOV A,#0
	MOV @R0,A
	MOV R0,#CRED_B
	MOV A,@R0
	CALL ADDCRED
BDONE:	RET

ADDCRED:
	MOV R1,A
	MOV A,CREDITS
	ADD A,R1
	MOV R1,A
	ADD A,#$F7
	JNC ADDOK
	MOV CREDITS,#9
	RET
ADDOK:	MOV A,R1
	MOV CREDITS,A
	RET
