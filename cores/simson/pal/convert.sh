#!/bin/bash

# Parodius
jedutil -view ParodiusDa_053884.PAL1.F6.jed gal16v8 > parodius-pal1.txt
jedutil -view ParodiusDa_053885.PAL2.G6.jed gal16v8 > parodius-pal2.txt
jedutil -view ParodiusDa_053886.PAL3.H6.jed gal16v8 > parodius-pal3.txt

sed -i -e "/\.oe = vcc$/d" -e "1,6d"  parodius-pal?.txt
sed -i "s/\/\///g" parodius-pal?.txt

function rename {
	LF=`echo $EACH|cut -f1 -d:`
	RP=`echo $EACH|cut -f2 -d:`
	sed -i "s/\b$LF\b/$RP /g" $1
}

for EACH in "i1:\/AS" "i2:BANKR" "i3:A15" "i4:A14" "i5:A13" \
			"i6:A12" "i7:A11" "i8:A10" "i9:WOC1" "i11:WOC0" \
			"o19:UNPAGED" "o18:NC" "o17:PAGED" "o16:WORK" "o15:OBJRAM" "o14:PALETTE" \
			"o13:i6" "o12:i7"
do
	rename parodius-pal3.txt
done

for EACH in "i1:NC"  "i2:\/UNPAGED" "i3:A15" "i4:A14" "i5:A13" \
            "i6:A13" "i7:A18" "i8:A17" "i9:A16" "i11:\/PAGED" \
            o12:progA13 o13:progA14 o14:progA15 o15:progA16 \
            o16:prog2 o17:prog1
do
	rename parodius-pal2.txt
done

for EACH in i1:AS i2:ROMRD i3:A9 i4:A8 i5:A7 "i6:\/i6" "i7:\/i7" \
		    i8:A6 i9:A5 i11:A4 o18:VCS o17:OBJCFG o16:PCU o14:MISC o13:IOCS o12:JOYSTK
do
	rename parodius-pal1.txt
done

sed -i "s/\/\///g" parodius-pal?.txt

# Vendetta
jedutil -view Vendetta-054242.jed gal16v8 > vendetta-u21.txt
jedutil -view Vendetta-054243.jed gal16v8 > vendetta-u22.txt
sed -i -e "1,14d" -e "/\.oe = vcc$/d" vendetta-*.txt

for EACH in "i1:\/AS" "i2:INIT" "i3:A15" "i4:A14" "i5:A13" "i6:A12" "i7:A11" "i8:A10" "i9:W0C1" "i11:W0C0" \
			"o19:BUFFEN" "o17:PROGCS" "o16:COLOCS" "o15:OBJCS" "o14:WORKCS" \
			"o13:i6" "o12:i7"
do
	rename vendetta-u21.txt
done

for EACH in "i1:AS" "i2:RMRD" "i3:A9" "i4:A8" "i5:A7" "i8:A6" "i9:A5" "i11:A4" \
			"o12:JOYSTK" "o13:STSW" "o14:OBJREG" "o15:PCUCS" "o16:CCUCS" "o17:IOCS" "o18:HIPCS" "o19:VRAMCS"
do
	rename vendetta-u22.txt
done

sed -i "s/\/\///g" vendetta-*.txt