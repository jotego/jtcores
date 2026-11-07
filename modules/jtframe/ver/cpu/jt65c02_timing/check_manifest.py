#!/usr/bin/env python3
"""Validate the historical WDC opcode/timing comparison data.

Source transcription: WDC W65C02S datasheet, 2024-02-16, Table 5-2 p.22;
base cycles Table 4-1 pp.19-20 and Table 7-1 p.30. The 16x16 matrix below
is transcribed directly from Table 5-2, not read from jt65c02.yaml. The
canonical CSV is checked against the full matrix and derived timing rules.
"""
from pathlib import Path
import csv, re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
CANON=HERE/'canonical_wdc.csv'
EXPECTED=HERE/'expected.mem'
FINDINGS=HERE/'known_wdc_findings.csv'
KNOWN_FINDING_COUNT=145
KNOWN_FINDING_HASH=0x02a64215
YAML=ROOT/'modules/jt680x/ucode/65c02.yaml'

GRID=[
'BRK:s ORA:ix - - TSB:z ORA:z ASL:z RMB0:z PHP:s ORA:# ASL:A - TSB:a ORA:a ASL:a BBR0:b',
'BPL:r ORA:iy ORA:iz - TRB:z ORA:x ASL:x RMB1:z CLC:i ORA:y INC:A - TRB:a ORA:q ASL:q BBR1:b',
'JSR:a AND:ix - - BIT:z AND:z ROL:z RMB2:z PLP:s AND:# ROL:A - BIT:a AND:a ROL:a BBR2:b',
'BMI:r AND:iy AND:iz - BIT:x AND:x ROL:x RMB3:z SEC:i AND:y DEC:A - BIT:q AND:q ROL:q BBR3:b',
'RTI:s EOR:ix - - - EOR:z LSR:z RMB4:z PHA:s EOR:# LSR:A - JMP:a EOR:a LSR:a BBR4:b',
'BVC:r EOR:iy EOR:iz - - EOR:x LSR:x RMB5:z CLI:i EOR:y PHY:s - - EOR:q LSR:q BBR5:b',
'RTS:s ADC:ix - - STZ:z ADC:z ROR:z RMB6:z PLA:s ADC:# ROR:A - JMP:ai ADC:a ROR:a BBR6:b',
'BVS:r ADC:iy ADC:iz - STZ:x ADC:x ROR:x RMB7:z SEI:i ADC:y PLY:s - JMP:ax ADC:q ROR:q BBR7:b',
'BRA:r STA:ix - - STY:z STA:z STX:z SMB0:z DEY:i BIT:# TXA:i - STY:a STA:a STX:a BBS0:b',
'BCC:r STA:iy STA:iz - STY:x STA:x STX:zy SMB1:z TYA:i STA:y TXS:i - STZ:a STA:q STZ:q BBS1:b',
'LDY:# LDA:ix LDX:# - LDY:z LDA:z LDX:z SMB2:z TAY:i LDA:# TAX:i - LDY:a LDA:a LDX:a BBS2:b',
'BCS:r LDA:iy LDA:iz - LDY:x LDA:x LDX:zy SMB3:z CLV:i LDA:y TSX:i - LDY:q LDA:q LDX:y BBS3:b',
'CPY:# CMP:ix - - CPY:z CMP:z DEC:z SMB4:z INY:i CMP:# DEX:i WAI:i CPY:a CMP:a DEC:a BBS4:b',
'BNE:r CMP:iy CMP:iz - - CMP:x DEC:x SMB5:z CLD:i CMP:y PHX:s STP:i - CMP:q DEC:q BBS5:b',
'CPX:# SBC:ix - - CPX:z SBC:z INC:z SMB6:z INX:i SBC:# NOP:i - CPX:a SBC:a INC:a BBS6:b',
'BEQ:r SBC:iy SBC:iz - - SBC:x INC:x SMB7:z SED:i SBC:y PLX:s - - SBC:q INC:q BBS7:b']
MODE={'s':'stack','i':'implied','A':'accumulator','#':'immediate','z':'zero_page',
      'x':'zero_page_x','zy':'zero_page_y','a':'absolute','q':'absolute_x','y':'absolute_y',
      'ix':'zp_indexed_indirect','iy':'zp_indirect_indexed','iz':'zp_indirect',
      'ai':'absolute_indirect','ax':'absolute_indexed_indirect','r':'relative','b':'zp_relative'}
BYTES={'s':1,'i':1,'A':1,'#':2,'z':2,'x':2,'zy':2,'a':3,'q':3,'y':3,
       'ix':2,'iy':2,'iz':2,'ai':3,'ax':3,'r':2,'b':3}
CYCLES={'i':2,'A':2,'#':2,'z':3,'x':4,'zy':4,'a':4,'q':4,'y':4,
        'ix':6,'iy':5,'iz':5,'ai':6,'ax':6,'r':2,'b':5}
STACK={'BRK':7,'PHP':3,'PLP':4,'PHA':3,'PLA':4,'PHY':3,'PLY':4,'PHX':3,'PLX':4,'RTI':6,'RTS':6}

def canonical_rows():
    rows={}
    for hi,line in enumerate(GRID):
        cells=line.split()
        assert len(cells)==16
        for lo,cell in enumerate(cells):
            if cell=='-': continue
            op=(hi<<4)|lo; name,mode=cell.split(':'); size=BYTES[mode]
            cyc=STACK[name] if mode=='s' else CYCLES[mode]
            if name=='BRK': size=2
            if name=='JSR': cyc=6
            if name=='JMP' and mode=='a': cyc=3
            if name in ('WAI','STP'): cyc=0
            if name=='BRA': cyc=3
            if name in ('ASL','LSR','ROL','ROR','INC','DEC') and mode!='A': cyc+=2
            if name in ('TRB','TSB'): cyc+=2
            if name.startswith(('RMB','SMB')): cyc=5
            if name=='STA' and mode in ('q','y','iy'): cyc+=1
            if name=='STZ' and mode=='q': cyc+=1
            # WDC's taken relative branches (and taken BBR/BBS) add a cycle
            # when the target crosses a page. BRA is always taken, so it can
            # also incur this crossing penalty in addition to its base time.
            cross=int((mode in ('q','y','iy') and name not in ('STA','STZ')) or mode in ('r','b'))
            taken=int(mode in ('r','b') and name!='BRA')
            decimal=int(name in ('ADC','SBC'))
            rows[op]=(name,MODE[mode],size,cyc,cross,taken,decimal)
    assert len(rows)==212
    return rows

def load_and_validate():
    expected=canonical_rows()
    got={}
    with CANON.open(newline='') as f:
        for row in csv.DictReader(f):
            op=int(row['opcode'],16)
            if op in got: raise ValueError(f'duplicate canonical opcode {op:02X}')
            got[op]=(row['mnemonic'],row['canonical_mode'],int(row['bytes']),
                     int(row['base_binary_cycles'] or 0),int(row['page_cross_extra']),
                     int(row['taken_extra']),int(row['decimal_extra']))
    if got!=expected:
        missing=sorted(set(expected)-set(got)); extra=sorted(set(got)-set(expected))
        bad=[f'{op:02X}' for op in set(got)&set(expected) if got[op]!=expected[op]]
        raise ValueError(f'canonical mismatch missing={missing} extra={extra} changed={bad}')
    def validate_candidate(candidate):
        if candidate!=expected: raise ValueError('canonical rows differ from source transcriptions')
        return True
    text=YAML.read_text()
    implemented={int(x,16) for x in re.findall(r'\bop:\s*0x([0-9a-fA-F]{2})\b',text)}
    target_opcodes=set(expected)-{0xCB,0xDB}
    if len(implemented)!=210: raise ValueError(f'expected 210 Rockwell opcode encodings; found {len(implemented)}')
    if implemented!=target_opcodes:
        raise ValueError('local instruction set differs from Rockwell matrix outside omitted WAI/STP')
    # Independently inventory the exact observed WDC-relative deviations. The RTL
    # repeats this ordered fingerprint after measuring every path; both gates must
    # agree so CI tolerates only this reviewed compatibility baseline.
    findings=[]
    with FINDINGS.open(newline='') as f:
        for row in csv.DictReader(f):
            findings.append((int(row['key'],16),int(row['observation_raw_or_status']),
                             int(row['observed_cycles_or_bit']),int(row['expected_cycles_or_bit'])))
    if len(findings)!=KNOWN_FINDING_COUNT:
        raise ValueError(f'known finding inventory size {len(findings)} != {KNOWN_FINDING_COUNT}')
    fingerprint=0x811c9dc5
    for entry in findings:
        for value in entry:
            fingerprint=((fingerprint ^ value)*16777619)&0xffffffff
    if fingerprint!=KNOWN_FINDING_HASH:
        raise ValueError(f'known finding fingerprint {fingerprint:08x} != {KNOWN_FINDING_HASH:08x}')
    # Negative controls exercise complete-row validation, not only the RTL comparator.
    for mutant in ({k:v for k,v in got.items() if k!=0xEA},
                   {**got,0xEA:(got[0xEA][0],got[0xEA][1],2,*got[0xEA][3:])},
                   {**got,0xEA:(got[0xEA][0],got[0xEA][1],got[0xEA][2],got[0xEA][3]+1,*got[0xEA][4:])}):
        try: validate_candidate(mutant)
        except ValueError: pass
        else: raise AssertionError('manifest negative control escaped')
    # Base opcode test fixture starts with C=Z=N=V=0 and bit memory $40=$00:
    # BCC/BNE/BPL/BVC and all BBR forms are taken; other conditionals/BBS are not.
    packed=[]
    for op,(name,mode,size,base,cross,taken,decimal) in sorted(expected.items()):
        if op not in implemented: continue
        fixture=base
        if op in (0x90,0xD0,0x10,0x50) or name.startswith('BBR'):
            fixture+=1
        packed.append(f'{op:02X}{fixture:02X}{size:02X}')
    return packed

def main():
    load_and_validate()
    print(f'WDC historical comparison oracle verified: 212 named rows; local profile implements 210; historical finding rows={KNOWN_FINDING_COUNT} hash={KNOWN_FINDING_HASH:08x}')
if __name__=='__main__': main()
