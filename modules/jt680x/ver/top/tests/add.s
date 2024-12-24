	; check TSX,TXS
	include defs.inc

	LDA #$7F
	LDB #$10
	ABA
	BVC BAD
	BPL BAD
	BEQ BAD
	CMPA #$8F
	BNE BAD
	CMPB #$10
	BNE BAD

	LDA #$FF
	LDB #$7F
	ABA
	BMI BAD
	BVS BAD
	ADCB #$10
	CMPB #$90
	BNE BAD
	BVC BAD

	LDD #$C000
	ADDD #$8000
	BMI BAD
	BVC BAD
	BCC BAD

	LDA #$10
	LDB #$23

	include finish.inc