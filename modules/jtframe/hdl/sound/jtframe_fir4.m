# FIR
pkg load signal

f1=0.24;
f2=0.25;
N=69
hc=round(fir1(N-1,f1,'low')*(2^15-1));
hc_fft=abs(fft(hc));
hdb=20*log10(hc_fft);
haux=hc';
save filter4 haux
bw=0;
for i=1:N
    if hdb(i) < hdb(1)-3
        bw=(i-1)/N*2;
        break
    endif
endfor
printf("Gain at DC %d dB = %d. Reject at f2 = %.0f dB. BW=%.3f\n", hdb(1), hc_fft(1), hdb(round(N*f2))-hdb(1), bw )
printf("Group delay=%d\n", grpdelay(hc)(10))
printf("Delay =%d ms (Fs=26000)\n", grpdelay(hc)(10)/26)
# use freqz(hc) to display the frequency response
freqz(hc)