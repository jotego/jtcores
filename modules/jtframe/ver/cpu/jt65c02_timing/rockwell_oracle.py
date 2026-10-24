#!/usr/bin/env python3
"""Validate the Rockwell R65C02 opcode/timing transcription and emit expected.mem.

Primary source: Rockwell R65C02/R65C102/R65C112 data sheet, SHA-256
0c526b991bff7133e53d753cf6ec1a7a7b31520daf938961676b3bd43e2b37f5.
The 16x16 grid below is transcribed from the R65C00 Instruction Set Op Code
Matrix, printed page 1-11 (PDF page 9); timing footnotes and indirect-JMP
details are from that page and Table 4 on printed page 1-10 (PDF page 8).
The intended profile is the original Rockwell R65C02. WAI/STP are absent.
"""
from pathlib import Path
import csv
import re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
CANON=HERE/'canonical_rockwell.csv'
EXPECTED=HERE/'expected.mem'
YAML=ROOT/'modules/jt680x/ucode/65c02.yaml'
CTRL=ROOT/'modules/jt680x/hdl/jt65c02_ctrl.v'
DECO_YAML=ROOT/'modules/jt680x/ucode/deco222.yaml'

# Row/column entries are copied from the Rockwell 210-opcode matrix. “-” is a
# blank matrix cell; blank cells are reserved encodings, not named instructions.
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
'CPY:# CMP:ix - - CPY:z CMP:z DEC:z SMB4:z INY:i CMP:# DEX:i - CPY:a CMP:a DEC:a BBS4:b',
'BNE:r CMP:iy CMP:iz - - CMP:x DEC:x SMB5:z CLD:i CMP:y PHX:s - - CMP:q DEC:q BBS5:b',
'CPX:# SBC:ix - - CPX:z SBC:z INC:z SMB6:z INX:i SBC:# NOP:i - CPX:a SBC:a INC:a BBS6:b',
'BEQ:r SBC:iy SBC:iz - - SBC:x INC:x SMB7:z SED:i SBC:y PLX:s - - SBC:q INC:q BBS7:b']
MODE={'s':'stack','i':'implied','A':'accumulator','#':'immediate','z':'zero_page',
      'x':'zero_page_x','zy':'zero_page_y','a':'absolute','q':'absolute_x','y':'absolute_y',
      'ix':'zero_page_indexed_indirect','iy':'zero_page_indirect_indexed','iz':'zero_page_indirect',
      'ai':'absolute_indirect','ax':'absolute_indexed_indirect','r':'relative','b':'zero_page_relative'}
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
            op=(hi<<4)|lo
            name,mode=cell.split(':')
            size=BYTES[mode]
            cyc=STACK[name] if mode=='s' else CYCLES[mode]
            # The opcode matrix counts BRK as a one-byte encoding. Its
            # signature consumes a second padding byte, so the simulator's
            # PC span is recorded separately from the source byte count.
            if name=='JSR': cyc=6
            if name=='JMP' and mode=='a': cyc=3
            if name=='BRA': cyc=3
            if name in ('ASL','LSR','ROL','ROR','INC','DEC') and mode!='A':
                # Rockwell matrix lists absolute-indexed RMW as 7 cycles.
                cyc+=3 if mode=='q' else 2
            if name in ('TRB','TSB'): cyc+=2
            if name.startswith(('RMB','SMB')): cyc=5
            if name=='STA' and mode in ('q','y','iy'): cyc+=1
            if name=='STZ' and mode=='q': cyc+=1
            is_rmw=name in ('ASL','LSR','ROL','ROR','INC','DEC','TRB','TSB') or name.startswith(('RMB','SMB'))
            cross=int((mode in ('q','y','iy') and name not in ('STA','STZ') and not is_rmw) or mode in ('r','b'))
            taken=int(mode in ('r','b') and name!='BRA')
            decimal=int(name in ('ADC','SBC'))
            indirect_ff=int(name=='JMP' and mode=='ai')
            pc_span=2 if name=='BRK' else size
            rows[op]=(name,MODE[mode],size,pc_span,cyc,cross,taken,decimal,indirect_ff)
    assert len(rows)==210
    return rows

def read_csv(path):
    rows={}
    with path.open(newline='') as f:
        for row in csv.DictReader(f):
            op=int(row['opcode'],16)
            if op in rows: raise ValueError(f'duplicate opcode {op:02X}')
            rows[op]=(row['mnemonic'],row['addressing_mode'],int(row['encoding_bytes']),
                      int(row['pc_span']),int(row['base_cycles']),
                      int(row['page_cross_extra']),int(row['taken_extra']),
                      int(row['decimal_extra']),int(row['indirect_ff_extra']))
    return rows

def validate():
    expected=canonical_rows()
    actual=read_csv(CANON)
    if actual!=expected:
        missing=sorted(set(expected)-set(actual)); extra=sorted(set(actual)-set(expected))
        bad=[f'{op:02X}' for op in set(actual)&set(expected) if actual[op]!=expected[op]]
        raise ValueError(f'Rockwell oracle mismatch missing={missing} extra={extra} changed={bad}')
    text=YAML.read_text()
    implemented={int(x,16) for x in re.findall(r'\bop:\s*0x([0-9a-fA-F]{2})\b',text)}
    if implemented!=set(expected):
        raise ValueError(f'YAML/Rockwell opcode mismatch missing={sorted(set(expected)-implemented)} extra={sorted(implemented-set(expected))}')
    declared={int(op,16):int(cycles) for op,cycles in re.findall(
        r'\bop:\s*0x([0-9a-fA-F]{1,2})\b[^\n]*?\bcycles:\s*(\d+)',text)}
    wrong_cycles={op:(declared.get(op),row[4]+row[6]) for op,row in expected.items()
                  if declared.get(op)!=row[4]+row[6]}
    if wrong_cycles:
        raise ValueError(f'YAML cycles must equal Rockwell base plus same-page taken cycle: {wrong_cycles}')
    reserved=set(range(256))-set(expected)
    ctrl=CTRL.read_text()
    match=re.search(r'function reserved_nop\(input \[7:0\] opcode\);(.*?)endfunction',ctrl,re.S)
    if not match: raise ValueError('reserved_nop decoder is missing')
    declared={int(x,16) for x in re.findall(r"8'h([0-9a-fA-F]{2})",match.group(1))}
    if declared!=reserved:
        raise ValueError(f'reserved-NOP decoder differs from Rockwell blank cells missing={sorted(reserved-declared)} extra={sorted(declared-reserved)}')
    deco_text=DECO_YAML.read_text()
    deco_expected={int(x,16) for x in re.findall(r'\bop:\s*0x([0-9a-fA-F]{2})\b',deco_text)}
    deco_match=re.search(r'function deco222_nop\(input \[7:0\] opcode\);(.*?)endfunction',ctrl,re.S)
    if not deco_match: raise ValueError('DECO222 NOP exception decoder is missing')
    deco_declared={int(x,16) for x in re.findall(r"8'h([0-9a-fA-F]{2})",deco_match.group(1))}
    if deco_declared!=deco_expected:
        raise ValueError(f'DECO222 NOP exceptions differ from deco222.yaml missing={sorted(deco_expected-deco_declared)} extra={sorted(deco_declared-deco_expected)}')
    # Mutants guard the independent source transcription dimensions most
    # likely to be accidentally normalized to the WDC profile: conditional
    # page crossing, decimal correction, fixed seven-cycle indexed RMW, and
    # the Rockwell indirect-JMP page-wrap behavior.
    def validate_candidate(candidate):
        if candidate!=expected:
            changed=sorted(op for op in set(candidate)|set(expected)
                           if candidate.get(op)!=expected.get(op))
            raise ValueError(f'candidate differs from Rockwell transcription at {[f"{op:02X}" for op in changed]}')
    mutations={
        'missing': (0xEA, None),
        'cycle': (0xEA, lambda row: (*row[:4],row[4]+1,*row[5:])),
        'branch_page_cross': (0xD0, lambda row: (*row[:5],row[5]+1,*row[6:])),
        'decimal_extra': (0x69, lambda row: (*row[:7],row[7]+1,*row[8:])),
        'absx_rmw': (0x1E, lambda row: (*row[:4],row[4]-1,*row[5:])),
        'jmp_ff': (0x6C, lambda row: (*row[:8],0)),
    }
    for mutate,(opcode,change) in mutations.items():
        mutant=dict(expected)
        if change is None: mutant.pop(opcode)
        else: mutant[opcode]=change(expected[opcode])
        try: validate_candidate(mutant)
        except ValueError: pass
        else: raise AssertionError(f'{mutate} negative control escaped')
    print('Rockwell oracle negative controls rejected: missing-opcode, changed-cycle, '
          'branch-page-cross, decimal-extra, absX-RMW, JMP-XXFF')
    packed=[]
    for op,(name,mode,size,pc_span,base,cross,taken,decimal,indirect_ff) in sorted(expected.items()):
        fixture=base
        if op in (0x90,0xD0,0x10,0x50) or name.startswith('BBR'): fixture+=1
        packed.append(f'{op:02X}{fixture:02X}{pc_span:02X}')
    return packed

def write_csv():
    rows=canonical_rows()
    with CANON.open('w',newline='') as f:
        fields=['opcode','mnemonic','addressing_mode','encoding_bytes','pc_span','base_cycles',
                'page_cross_extra','taken_extra','decimal_extra','indirect_ff_extra','source']
        w=csv.DictWriter(f,fieldnames=fields); w.writeheader()
        for op,(name,mode,size,pc_span,base,cross,taken,decimal,indirect_ff) in sorted(rows.items()):
            source=('Rockwell matrix, p.1-11; BRK PC span includes padding byte'
                    if name=='BRK' else 'Rockwell R65C00 opcode matrix, p.1-11')
            w.writerow({'opcode':f'{op:02X}','mnemonic':name,'addressing_mode':mode,'encoding_bytes':size,
                        'pc_span':pc_span,
                        'base_cycles':base,'page_cross_extra':cross,'taken_extra':taken,
                        'decimal_extra':decimal,'indirect_ff_extra':indirect_ff,
                        'source':source})

def main():
    lines=validate()
    EXPECTED.write_text('\n'.join(lines)+'\n')
    print(f'Rockwell R65C02 source oracle verified: {len(lines)} named opcodes; '
          f'{256-len(lines)} reserved bytes; matrix p.1-11, enhancements Table 4 p.1-10; expected.mem generated')

if __name__=='__main__': main()
