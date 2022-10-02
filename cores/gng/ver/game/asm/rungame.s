	ORG $0

RESET: 
	ORCC #$10
	LDA	#$80
	STA	$3E00	; BANK, clears start-up bank. This will cause a reset
