# Converts logo128.png to a 1-bit hex file
# to be used with osd.v

I=imread("logo128.png");
[r c] = size(I);
# bit conversion
f=fopen("osdback.hex","w");
f2=fopen("osdback.v","w")
fprintf(f2,"initial begin\n")
global cnt
cnt=0
for j=1:8:r/2
    # fill to make width = 256
    for k=c+1:256
        fprintf(f,"0\n")
        dump(f2,0)
    endfor
    for k=1:c
        val=0;
        for b=0:7
            if I( (j+b)*2,k)!=0
                printf("*")             
                val=bitset(val,b+1);
            else
                printf(" ")
            endif
        endfor
        fprintf(f,"%X\n",val)
        dump(f2,1)
    endfor
    printf("\n")
endfor
fprintf(f2, "\nend");
fclose(f)
fclose(f2)