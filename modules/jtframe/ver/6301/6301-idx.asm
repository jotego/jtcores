; 6301-specific instructions

	LDA #$12
	LDX #$2
	STA $40,x
	AIM #$02,$40,x
	LDB $40,x			; should be $02
	CMPB #$02
	BNE BAD

	CLRB
	OIM #$F1,$40,x
	LDB $40,x			; should be $F3
	CMPB #$F3
	BNE BAD

	CLRB
	EIM #$59,$40,x
	LDB $40,x			; should be $AA
	CMPB #$AA
	BNE BAD

	TIM #$01,$40,x
	BNE BAD
	TIM #$02,$40,x
	BEQ BAD

GOOD:
	LDX #$BABE
	CLR $4001			; stops the sim
	BRA GOOD

BAD:
	LDX #$DEAD
	CLR $4001
	BRA BAD