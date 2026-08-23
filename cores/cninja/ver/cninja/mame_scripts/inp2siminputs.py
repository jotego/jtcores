#!/usr/bin/env python3
# Convert a MAME per-frame input dump (dump_perframe_inputs.lua output: "frame
# INPUTS SYSTEM" hex per line) into jtframe sim_inputs.hex (one cab-format hex
# per frame). cninja INPUTS (DATAEAST_2BUTTON, P1 low byte, active-low):
#   bit0=UP bit1=DOWN bit2=LEFT bit3=RIGHT bit4=B1(attack) bit5=B2(jump) bit7=START
# SYSTEM bit0=COIN1. cab bits: coin=1 1p=4 right=0x10 left=0x20 down=0x40 up=0x80
# b1=0x100 b2=0x200.  Usage: inp2siminputs.py perframe.txt > sim_inputs.hex
import sys
for line in open(sys.argv[1]):
    fn,inp,sysv=line.split(); p=~int(inp,16)&0xff; s=~int(sysv,16)&0xff; v=0
    if p&0x01:v|=0x80
    if p&0x02:v|=0x40
    if p&0x04:v|=0x20
    if p&0x08:v|=0x10
    if p&0x10:v|=0x100
    if p&0x20:v|=0x200
    if p&0x80:v|=0x04
    if s&0x01:v|=0x01
    print("%x"%v)
