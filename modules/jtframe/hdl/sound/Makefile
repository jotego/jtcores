all: uprate2.hex uprate3.hex firjt49.hex

uprate2.hex: filter2 fir_coeff
	fir_coeff filter2 > uprate2.hex

uprate3.hex: filter3 fir_coeff
	fir_coeff filter3 > uprate3.hex

firjt49.hex: firjt49 fir_coeff
	fir_coeff firjt49 > firjt49.hex

filter2: jtframe_fir2.m
	octave jtframe_fir2.m

filter3: jtframe_fir3.m
	octave jtframe_fir3.m

firjt49: firjt49.m
	octave firjt49.m

fir_coeff: fir_coeff.c
	gcc fir_coeff.c -o fir_coeff