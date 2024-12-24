	; check INX, INS, LDX,LDS,CPX (imm), TSX
	include defs.inc

	LDX	#$0
	BCS BAD
	BNE BAD
	BVS BAD

	INX
	CPX #1
	BNE BAD

	LDX #$80
	LDA #$F0
L0:
	INX
	DECA
	BNE L0
	CPX #$170
	BNE BAD

	LDX #$FFFF
	INX
	BNE BAD

	; Next with S
	LDS	#$0
	BCS BAD
	BNE BAD
	BVS BAD

	INS
	TSX
	CPX #2
	BNE BAD

	LDS #$80
	LDA #$F0
L1:
	INS
	DECA
	BNE L1
	TSX
	CPS #$171
	BNE BAD

	LDS #$FFFF
	INS
	BNE BAD

	include finish.inc