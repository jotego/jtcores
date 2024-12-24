; 6301-specific instructions

	LDD #$1234
	LDX #$CAFE

	XGDX

	CPX #$1234
	BNE BAD
	CMPA #$CA
	BNE BAD
	CMPB #$FE
	BNE BAD

GOOD:
	LDX #$BABE
	CLR $4001			; stops the sim
	BRA GOOD

BAD:
	LDX #$DEAD
	CLR $4001
	BRA BAD