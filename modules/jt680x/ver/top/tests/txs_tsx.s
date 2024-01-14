	; check TSX,TXS
	include defs.inc

	LDS	#$12FF
	TSX
	CPX #$1300
	BNE BAD

	LDX #$AB00
	TXS
	LDX #RAM
	STS ,X
	BEQ BAD
	BCS BAD
	BPL BAD

	LDD #$AAFF
	CPA ,X
	BNE BAD
	CPB 1,X
	BNE BAD

	include finish.inc