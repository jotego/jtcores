# Compares an instruction trace from ref32010 with one from tb_dsp.v.
# Input: the two traces pasted side by side with '|' between them.
# Fields per side: pc rom acc preg treg ar0 ar1 str stk0 stk1 stk2 stk3.
#
# IKA32010 differs from MAME's TMS32010 in two ways the Wardner program cannot
# observe, and only those two are tolerated, each in the one place it can show:
#
#  - OVM (STR 0x4000) is set by MAME's reset and left clear by IKA32010. It is
#    ignored until a ROVM (7f8a) or SOVM (7f8b) has run.
#  - MAME sets INTM (STR 0x2000) when it takes an interrupt; IKA32010 does not.
#    It is ignored on the line at the vector (pc 002) and the one after it, and
#    only as MAME set / IKA32010 clear. The Wardner vector is B 30b, and 30b is
#    DINT, which sets INTM in both.
#
# Anything else is a divergence. Prints a summary line; exits 1 on divergence.
BEGIN { FS = "|" }
{
    # each line shows the state before its instruction runs, so OVM is defined
    # from the line after the ROVM or SOVM
    if( ovm_armed ) ovm_known = 1
    split($1, r, " "); split($2, k, " ")
    other = 0
    for( i = 1; i <= 12; i++ ) if( i != 8 && r[i] != k[i] ) other = 1
    x = xor(strtonum("0x" r[8]), strtonum("0x" k[8]))
    since = (r[1] == "002") ? 0 : since + 1
    if( other || x != 0 ) {
        allow = 0
        if( !ovm_known ) allow = or(allow, 0x4000)
        if( since <= 1 && and(strtonum("0x" r[8]), 0x2000) && !and(strtonum("0x" k[8]), 0x2000) )
            allow = or(allow, 0x2000)
        if( other || and(x, compl(allow)) ) {
            if( !bad ) { first = NR; fref = $1; fika = $2 }
            bad++
        } else if( and(x, 0x4000) ) ovm_n++
        else intm_n++
    }
    if( r[2] == "7f8a" || r[2] == "7f8b" ) ovm_armed = 1
}
END {
    printf "%d instructions, %d diverge, tolerated: %d OVM before ROVM/SOVM, %d INTM at the vector\n", \
        NR, bad, ovm_n, intm_n
    if( bad ) { printf "first divergence at instruction %d\n  ref %s\n  ika %s\n", first, fref, fika; exit 1 }
}
