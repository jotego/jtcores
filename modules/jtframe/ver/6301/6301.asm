; 6301-specific instructions

	LDA #$12
	STA $40
	AIM #$02,$40
	LDB $40			; should be $02
	CMPB #$02
	BNE BAD

	CLRB
	OIM #$F1,$40
	LDB $40			; should be $F3
	CMPB #$F3
	BNE BAD

	CLRB
	EIM #$59,$40
	LDB $40			; should be $AA
	CMPB #$AA
	BNE BAD

	TIM #$01,$40
	BNE BAD
	TIM #$02,$40
	BEQ BAD

GOOD:
	LDX #$BABE
	CLR $4001			; stops the sim
	BRA GOOD

BAD:
	LDX #$DEAD
	CLR $4001
	BRA BAD