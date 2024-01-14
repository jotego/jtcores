	; sound CPU test
	; Writes and checks random data in the TRI-RAM region
	ORG $0
RAM0 EQU $7000
RAM1 EQU $77FF

LFSR MACRO
	; x8+x6+x5+x4+1 polynomial
	BITA #$20
	BEQ X5
	EORA #$80
X5:	BITA #$10
	BEQ X4
	EORA #$80
X4:	BITA #$08
	BEQ WRROT
	EORA #$80
WRROT:
	TFR A,B		; get A's MSB in the carry
	LSLB
	ROLA		; A has a new pseudo random number
	ENDM

	LDA 1
	TFR A,DP

MAINLOOP:
	; Write random data
	TFR DP,A
	LDX	#RAM0
WRLOOP:
	STA ,X
	LFSR
	LEAX 1,X
	CMPX #RAM1
	BNE WRLOOP

	; Check the writes
	TFR DP,A
	LDX	#RAM0
CKLOOP:
	CMPA ,X
	BNE BAD
	LFSR
	LEAX 1,X
	CMPX #RAM1
	BNE CKLOOP

	; Iterate avoiding DP=0
	TFR DP,A
ZZ:	INCA
	BEQ ZZ
	TFR A,DP
	LDS #$BABE
	BRA MAINLOOP

BAD:
	LDB ,X
	LDS #$DEAD
	BRA BAD

	; Fill with zeros
	DC.B	[$10000-*]0