#!/usr/bin/awk -f
# Provides a list of SDRAM pins that have not been assigned to I/O registers
BEGIN {
    FS=";"
    dump=0
}
/^; Output Pins/ {
    dump=1
    next
}
/^; Bidir Pins/ {
    dump=2
    next
}
/^;/ {
    if( dump==1 ) {
        # $2 = pin name
        # $8 = output register
        if( match($2,"SDRAM_") && match($8,"no") && match($2,"SDRAM_CLK")==0) {
            gsub(/ /,"",$2)
            print $2
        }
    }
    if( dump==2 ) {
        # $2  = pin name
        # $11 = input register
        # $12 = output register
        # print $2,$11,$12
        if( match($2,"SDRAM_") && (match($11,"no") || match($12,"no")) )
            if( match($2,"SDRAM_CLK")==0 ) {
                #gsub(/ /,"",$2)
                print $2
            }
    }
}

/^$/{
    # print "Dump to zero"
    dump=0
}
