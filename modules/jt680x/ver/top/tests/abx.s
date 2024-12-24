	; check INX, INS, LDX,LDS,CPX (imm), TSX
	include defs.inc

	LDX	#$81
	LDB #$7F

	ABX
	CPX #$100
	BNE BAD
	BVS BAD
	BCS BAD

	LDX #$0
	LDB #$FF
	LDA #$40
LOOP:
	ABX
	DECA
	BNE LOOP
	CPX #($FF*$40)
	BNE BAD

	LDX #$78FF
	LDB #$1
	ABX
	BPL BAD
	BVC BAD
	BCS BAD

	LDX #$FFFF
	ABX
	BMI BAD
	BVC BAD
	BCC BAD

	include finish.inc