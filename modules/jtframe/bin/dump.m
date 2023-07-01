function dump(f2,val)
    global cnt
    fprintf(f2,"bkg[%4d]=8'h%02X; ",cnt,val)
    cnt=cnt+1;
    if mod(cnt,16)==0
        fprintf(f2,"\n")
    endif
endfunction