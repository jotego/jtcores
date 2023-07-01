# FIR
pkg load signal

f1=0.48;
f2=0.52;
N=127
hc=round(fir1(N-1,f1,'low')*2^15);
printf("Stopband attenuation %d dB\n", N*22*(f2-f1))
hc_fft=abs(fft(hc));
hdb=20*log10(hc_fft);
haux=hc';
save filter2 haux
printf("Gain at DC %d dB = %d. Reject at f2 = %.0f dB. BW=%.3f\n", hdb(1), hc_fft(1), hdb(round(N*f2))-hdb(1), bw )
printf("Group delay=%d\n", grpdelay(hc)(10))
# use freqz(hc) to display the frequency response