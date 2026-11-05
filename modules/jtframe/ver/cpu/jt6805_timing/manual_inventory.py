#!/usr/bin/env python3
"""Motorola M6805 User's Manual, 2nd ed. (1983), Appendix F oracle.

The opcode map and timing formulae below are transcribed from the manual's
numerical listing, printed pp. 227-232 (PDF pages 240-245). HMOS values are
normative for MC68705P3; the paired CMOS values are retained for comparison.
This file is deliberately independent of JT6805 YAML and generated ucode.
"""

def inventory():
    rows = {}

    def add(codes, mnemonic, mode, hmos, cmos, length, scope="HMOS+CMOS"):
        for code in codes:
            if code in rows:
                raise ValueError(f"duplicate manual opcode {code:02X}")
            rows[code] = (mnemonic, mode, hmos, cmos, length, scope)

    # Bit test/branch (BTB), bit set/clear (BSC), and relative branches.
    for bit in range(8):
        rows[2*bit]   = (f"BRSET{bit}","BTB",10,5,3,"HMOS+CMOS")
        rows[2*bit+1] = (f"BRCLR{bit}","BTB",10,5,3,"HMOS+CMOS")
        rows[0x10+2*bit]   = (f"BSET{bit}","BSC",7,5,2,"HMOS+CMOS")
        rows[0x11+2*bit] = (f"BCLR{bit}","BSC",7,5,2,"HMOS+CMOS")
    branches=("BRA","BRN","BHI","BLS","BCC","BCS","BNE","BEQ",
              "BHCC","BHCS","BPL","BMI","BMC","BMS","BIL","BIH")
    for op,name in enumerate(branches,0x20): rows[op]=(name,"REL",4,3,2,"HMOS+CMOS")

    # Direct, indexed-offset, and indexed-no-offset RMW instruction groups.
    rmw = (0x30,0x33,0x34,0x36,0x37,0x38,0x39,0x3A,0x3C,0x3D,0x3F)
    rmw_names = ("NEG","COM","LSR","ROR","ASR","LSL","ROL","DEC","INC","TST","CLR")
    for code, name in zip(rmw, rmw_names): rows[code] = (name,"DIR",6,4 if name=="TST" else 5,2,"HMOS+CMOS")
    for base, mode, hmos, cmos in ((0x60,"IX1",7,6),(0x70,"IX",6,5)):
        codes = tuple(base+(x & 0x0f) for x in rmw)
        add(codes, "RMW", mode, hmos, cmos, 2 if mode=="IX1" else 1)
        for code, name in zip(codes, rmw_names):
            if name=="TST": rows[code]=(name,mode,hmos,5 if mode=="IX1" else 4,2 if mode=="IX1" else 1,"HMOS+CMOS")

    # Inherent A/X operations; four cycles in HMOS, three in CMOS.
    inherent = {
        0x40:"NEG",0x43:"COM",0x44:"LSR",0x46:"ROR",0x47:"ASR",0x48:"LSL",0x49:"ROL",0x4A:"DEC",0x4C:"INC",0x4D:"TST",0x4F:"CLR",
        0x50:"NEG",0x53:"COM",0x54:"LSR",0x56:"ROR",0x57:"ASR",0x58:"LSL",0x59:"ROL",0x5A:"DEC",0x5C:"INC",0x5D:"TST",0x5F:"CLR",
    }
    for code,name in inherent.items(): rows[code]=(name+('A' if code<0x50 else 'X'),"INH",4,3,1,"HMOS+CMOS")

    # Control operations and the two CMOS-only power instructions.
    control={0x80:("RTI",9,9),0x81:("RTS",6,6),0x83:("SWI",11,10),
             0x97:("TAX",2,2),0x98:("CLC",2,2),0x99:("SEC",2,2),
             0x9A:("CLI",2,2),0x9B:("SEI",2,2),0x9C:("RSP",2,2),
             0x9D:("NOP",2,2),0x9F:("TXA",2,2)}
    for code,(name,h,c) in control.items(): rows[code]=(name,"INH",h,c,1,"HMOS+CMOS")
    rows[0x8E]=("STOP","INH",None,2,1,"CMOS-only")
    rows[0x8F]=("WAIT","INH",None,2,1,"CMOS-only")

    # Immediate accumulator/index operations and BSR.
    imm={0xA0:"SUB",0xA1:"CMP",0xA2:"SBC",0xA3:"CPX",0xA4:"AND",0xA5:"BIT",0xA6:"LDA",
         0xA8:"EOR",0xA9:"ADC",0xAA:"ORA",0xAB:"ADD",0xAE:"LDX"}
    for code,name in imm.items(): rows[code]=(name,"IMM",2,2,2,"HMOS+CMOS")
    rows[0xAD]=("BSR","REL",8,6,2,"HMOS+CMOS")

    # Register/memory forms. Family timings come from Appendix F tables.
    families = {
        "DIR": (0xB0,4,3,2), "EXT": (0xC0,5,4,3), "IX2": (0xD0,6,5,3),
        "IX1": (0xE0,5,4,2), "IX": (0xF0,4,3,1),
    }
    mnemonics=("SUB","CMP","SBC","CPX","AND","BIT","LDA","STA","EOR","ADC","ORA","ADD","JMP","JSR","LDX","STX")
    for mode,(base,read_h,read_c,length) in families.items():
        for off,name in enumerate(mnemonics):
            if mode=="DIR" and name=="JMP": h,c=3,2
            elif mode=="DIR" and name=="JSR": h,c=7,5
            elif mode=="EXT" and name=="JMP": h,c=4,3
            elif mode=="EXT" and name=="JSR": h,c=8,6
            elif mode=="IX2" and name=="JMP": h,c=5,4
            elif mode=="IX2" and name=="JSR": h,c=9,7
            elif mode=="IX1" and name=="JMP": h,c=4,3
            elif mode=="IX1" and name=="JSR": h,c=8,6
            elif mode=="IX" and name=="JMP": h,c=3,2
            elif mode=="IX" and name=="JSR": h,c=7,5
            elif mode=="EXT" and name=="STX": h,c=6,5
            elif name in ("STA","STX"):
                h,c=read_h+1,read_c+1
                if name=="STX" and mode=="DIR": h,c=5,4
            else: h,c=read_h,read_c
            code=base+off
            rows[code]=(name,mode,h,c,length,"HMOS+CMOS")

    # Preserve documented Appendix F conflicts instead of normalizing them to
    # either the DUT or a family formula. The selected oracle follows the
    # instruction-specific timing table and HMOS Appendix G2 bus sequence.
    names={0x40:"NEGA",0x43:"COMA",0x44:"LSRA",0x46:"RORA",0x47:"ASRA",0x48:"LSLA",0x49:"ROLA",0x4A:"DECA",0x4C:"INCA",0x4D:"TSTA",0x4F:"CLRA",
           0x50:"NEGX",0x53:"COMX",0x54:"LSRX",0x56:"RORX",0x57:"ASRX",0x58:"LSLX",0x59:"ROLX",0x5A:"DECX",0x5C:"INCX",0x5D:"TSTX",0x5F:"CLRX"}
    for code,name in names.items(): rows[code]=(name,*rows[code][1:])
    for code in (0x30,0x33,0x34,0x36,0x37,0x38,0x39,0x3A,0x3C,0x3D,0x3F):
        name=rows[code][0]
        for base,mode in ((0x60,"IX1"),(0x70,"IX")):
            ixcode=base+(code&15)
            rows[ixcode]=(name, *rows[ixcode][1:])
    conflict={
        0xB7:"App.F printed p.231 says 4/4; STA instruction table printed p.210 and App.G2 printed p.240 say 5/4. Select chapter/G2 for HMOS and CMOS; retain App.F as conflicting evidence.",
        0xBC:"App.F printed p.231 says 3/3; JMP instruction table printed p.193 says 3/2; App.G2 printed p.240 confirms HMOS 3. Select chapter/G2; retain Appendix-F CMOS conflict.",
        0xCC:"App.F printed p.231 says 4/4; JMP instruction table printed p.193 says 4/3. App.G2 p.241 does not list this form. Select the chapter table; retain Appendix-F conflict.",
        0xDC:"App.F printed p.231 says 5/5; JMP instruction table printed p.193 says 5/4; App.G2 printed p.242 confirms HMOS 5. Select chapter/G2; retain Appendix-F CMOS conflict.",
        0xCE:"App.F printed p.231 says 4/4; LDX instruction table printed p.196 says 5/4. App.G2 p.241 does not list this form. Select the chapter table; retain App.F HMOS conflict.",
        0xCF:"App.F printed p.231 says 5/5; STX instruction table printed p.212 and App.G2 printed p.241 say 6/5. Select chapter/G2; retain Appendix-F conflict.",
        0xEC:"App.F printed p.232 says 4/4; JMP instruction table printed p.193 says 4/3; App.G2 printed p.242 confirms HMOS 4. Select chapter/G2; retain Appendix-F CMOS conflict.",
        0xFC:"App.F printed p.232 says 3/3; JMP instruction table printed p.193 says 3/2; App.G2 printed p.241 confirms HMOS 3. Select chapter/G2; retain Appendix-F CMOS conflict.",
    }
    for code, note in conflict.items(): rows[code] = (*rows[code], note)
    for code,row in list(rows.items()):
        if len(row)==6: rows[code]=(*row,"")
    return rows

if __name__ == "__main__":
    import csv
    from pathlib import Path
    out=Path("oracle.csv")
    with out.open("w",newline="") as f:
        w=csv.writer(f); w.writerow(("opcode","mnemonic","mode","hmos_cycles","cmos_cycles","bytes","scope","manual_ref","source_conflict"))
        for code,(name,mode,h,c,n,scope,conflict) in sorted(inventory().items()):
            appf_page = 228 if code <= 0x2c else 229 if code <= 0x6c else 230 if code <= 0xb6 else 231 if code <= 0xe3 else 232
            g2_page = (239 if mode in ("INH","IMM","BTB","BSC") else
                       240 if mode == "REL" or mode == "DIR" else
                       241 if mode in ("EXT","IX") else 242)
            chapter=f"App.F numerical listing printed p.{appf_page}"
            if code not in (0xCC,0xCE): chapter += f"; App.G2 bus cycles printed p.{g2_page}"
            if conflict:
                chapter += f"; instruction-specific table printed p.{193 if code in (0xBC,0xCC,0xDC,0xEC,0xFC) else 210 if code==0xB7 else 196}"
            w.writerow((f"{code:02X}",name,mode,"" if h is None else h,"" if c is None else c,n,scope,chapter,conflict))
    with Path("manual_cases.hex").open("w") as f:
        for code,(name,mode,h,c,n,scope,conflict) in sorted(inventory().items()):
            extension = 1 if scope == "CMOS-only" else 0
            f.write(f"{code:02X}{n:X}{15 if h is None else h:X}{c:X}{extension:X}00\n")
    print(f"Wrote {len(inventory())} manual encoding rows to {out}")
