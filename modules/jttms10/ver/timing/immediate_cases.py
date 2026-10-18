#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""TI immediate forms, source-level operands independent of stored encodings.

SPVU001A: ADDI 12-38/39, CMPI 12-54/55, MOVI 12-159/160,
SUBI 12-249/250, ANDI/ANDNI 12-43/45, ORI 12-173, XORI 12-256.
SUBI/CMPI and the ANDI alias store one's-complement extension words.
The architectural model operates on the original immediate, never that
encoded operand or a decoded DUT/microcode operation.
"""
from alu_cases import arithmetic, initial_status
from oracle import immediate_states
from scalar_cases import MASK32, N, Z, V

# Name, width, opcode, printed entry page. ANDI/ANDNI are distinct source
# forms with a shared opcode and complementary extension encodings.
FORMS = (
    ('ADDI',16,0x0B00,'12-38'), ('ADDI',32,0x0B20,'12-39'),
    ('CMPI',16,0x0B40,'12-54'), ('CMPI',32,0x0B60,'12-55'),
    ('SUBI',16,0x0BE0,'12-249'), ('SUBI',32,0x0D00,'12-250'),
    ('MOVI',16,0x09C0,'12-159'), ('MOVI',32,0x09E0,'12-160'),
    ('ANDI',32,0x0B80,'12-43'), ('ANDNI',32,0x0B80,'12-45'),
    ('ORI',32,0x0BA0,'12-173'), ('XORI',32,0x0BC0,'12-256'),
)


def operand(value, width):
    value &= (1 << width)-1
    if width == 16 and value & 0x8000:
        value -= 1 << 16
    return value & MASK32


def result(name, value, width, dest, status):
    source=operand(value,width)
    if name in ('ADDI','SUBI','CMPI'):
        stored,flags=arithmetic({'ADDI':'ADD','SUBI':'SUB','CMPI':'CMP'}[name],source,dest,status)
        return (dest if name=='CMPI' else stored),flags
    if name=='MOVI':
        return source,(status & ~(N|Z|V)) | (source & N) | (Z if source==0 else 0)
    stored={'ANDI':dest & source, 'ANDNI':dest & ~source,
            'ORI':dest | source, 'XORI':dest ^ source}[name] & MASK32
    return stored,(status & ~Z) | (Z if stored==0 else 0)


def extension_words(name, value, width):
    encoded=~value if name in ('SUBI','CMPI','ANDI') else value
    return [(encoded >> bit)&0xFFFF for bit in range(0,width,16)]


# Literal primary examples: (name,width,immediate,before,after,NCZV).
# MOVI C is unaffected; use C=1 here. Logical operations preserve N/C/V;
# their literal Z checks use N=C=V=1 to exercise preservation as well.
TI_EXAMPLES = (
    ('ADDI',16,1,0xFFFFFFFF,0,6),
    ('ADDI',16,1,0x7FFFFFFF,0x80000000,9),
    ('ADDI',16,32767,2,0x8001,0),
    ('ADDI',32,0x80000000,0xFFFFFFFF,0x7FFFFFFF,5),
    ('ADDI',32,32768,0x7FFFFFFF,0x80007FFF,9),
    ('CMPI',16,1,0,0,12), ('CMPI',16,1,0x80000000,0x80000000,1),
    ('CMPI',16,-2,0xFFFFFFFE,0xFFFFFFFE,2),
    ('CMPI',32,0x8000,0x80007FFF,0x80007FFF,1),
    ('CMPI',32,0xFFFF7FFF,0x7FFF7FFF,0x7FFF7FFF,13),
    ('SUBI',16,32767,0x80007FFE,0x7FFFFFFF,1),
    ('SUBI',16,-32768,0x7FFF8000,0x80000000,13),
    ('SUBI',32,32769,0x80008000,0x7FFFFFFF,1),
    ('SUBI',32,-32771,0x7FFF7FFD,0x80000000,13),
    ('MOVI',16,32767,0xDEADBEEF,0x7FFF,4),
    ('MOVI',16,0,0xDEADBEEF,0,6),
    ('MOVI',16,-32768,0xDEADBEEF,0xFFFF8000,12),
    ('MOVI',32,32768,0xDEADBEEF,0x8000,4),
    ('MOVI',32,-32769,0xDEADBEEF,0xFFFF7FFF,12),
    ('MOVI',32,0x80000000,0xDEADBEEF,0x80000000,12),
    ('ANDI',32,0xAAAAAAAA,0x55555555,0,15),
    ('ANDNI',32,0xAAAAAAAA,0x55555555,0x55555555,13),
    ('ORI',32,0xAAAAAAAA,0x55555555,0xFFFFFFFF,13),
    ('XORI',32,0xFFFFFFFF,0xFFFFFFFF,0,15),
)


def immediate_cases():
    for off in (False,True):
        for name,width,base,page in FORMS:
            values=(0,1,0x7FFF,0x8000,0xFFFF,0x1234,0xA5A5,0x8001) if width==16 else (
                0,1,0x7FFFFFFF,0x80000000,0xFFFFFFFF,0x8000,0xFFFF7FFF,0x12345678,0xAAAAAAAA,0x55555555)
            pairs=[(dest,value) for dest in (0,1,0x7FFFFFFF,0x80000000,0xFFFFFFFF,0xAAAA5555) for value in values]
            vectors=[]
            for q,(dest,value) in enumerate(pairs):
                for carry in (0,1):
                    status=(initial_status(q) & ~(1<<30)) | (carry<<30)
                    # Neither field width/extension changes an immediate.
                    status ^= ((q&31)<<6) | ((q&1)<<5)
                    vectors.append((f'p{q}_c{carry}',q%3,dest,value,status,None))
            for q,example in enumerate(TI_EXAMPLES):
                op,bits,value,dest,stored,flags=example
                if (op,bits)==(name,width):
                    vectors.append((f'ti{q}',0,dest,value,0xF0000810,(stored,0x810|(flags<<28))))
            for tag,rd,dest,value,status,literal in vectors:
                regs=[0x11223344,0x55667788,0x99AABBCC,status];regs[rd]=dest
                expected=list(regs);expected[rd],flags=result(name,value,width,dest,status)
                if literal is not None:
                    assert (expected[rd],flags)==literal,(name,width,tag)
                yield dict(name=f'immediate_{name.lower()}_{width}_{tag}_{"off" if off else "hit"}',
                    coverage_id=name+('_IW' if width==16 else '_IL'),opcode=base|rd,
                    extensions=extension_words(name,value,width),regs=regs,expected_regs=expected,
                    expected_st=flags,states=immediate_states(width=width,cache_disabled=off),
                    cache_disabled=off,citation='SPVU001A '+page,
                    conditions=dict(source_immediate=value,width=width,destination=rd,before=dest,literal_example=literal is not None))

    # Warm fixtures cross each cache-word boundary; only these extra probes
    # alter the original matrix's fixed layout (historical baseline above).
    for off in (False,True):
        for name,width,base,page in FORMS:
            for offset in (0,2,3):
                status=0xF0000810;value=0x8001 if width==16 else 0x12348001
                regs=[0x7FFFFFFF,0x55667788,0x99AABBCC,status]
                expected=list(regs);expected[0],flags=result(name,value,width,regs[0],status)
                yield dict(name=f'immediate_{name.lower()}_{width}_align{offset}_{"off" if off else "hit"}',
                    coverage_id=name+('_IW' if width==16 else '_IL'),opcode=base,
                    extensions=extension_words(name,value,width),instruction_word_offset=offset,
                    regs=regs,expected_regs=expected,expected_st=flags,
                    states=immediate_states(width=width,cache_disabled=off),
                    cache_disabled=off,citation='SPVU001A '+page+'; 5.4.7; 11-24',
                    conditions=dict(source_immediate=value,width=width,destination=0,word_offset=offset))
    # First pass: opcode at word3 is resident, extension's subsegment absent.
    # The four-word fill has nine additional states (p.5-24), and all fill
    # cycles have IAQ high even though the requested word is an immediate.
    for name,width,base,page in FORMS:
        status=0xF0000810;value=0x8001 if width==16 else 0x12348001
        regs=[0x7FFFFFFF,0x55667788,0x99AABBCC,status]
        expected=list(regs);expected[0],flags=result(name,value,width,regs[0],status)
        yield dict(name=f'immediate_{name.lower()}_{width}_extension_miss',
            coverage_id=name+('_IW' if width==16 else '_IL'),opcode=base,
            extensions=extension_words(name,value,width),regs=regs,expected_regs=expected,
            expected_st=flags,states=immediate_states(width=width)+9,
            cache_disabled=False,cache_miss='extension',measure_pass=0,
            citation='SPVU001A '+page+'; 5.4.7 p.5-24; 11-24',
            conditions=dict(source_immediate=value,width=width,destination=0,extension_miss=True))

        if width==32:
            yield dict(name=f'immediate_{name.lower()}_{width}_second_extension_miss',
                coverage_id=name+'_IL',opcode=base,extensions=extension_words(name,value,width),
                regs=regs,expected_regs=expected,expected_st=flags,states=12,
                cache_disabled=False,cache_miss='extension',miss_word=2,
                instruction_word_offset=2,measure_pass=0,
                citation='SPVU001A '+page+'; 5.4.7 p.5-24; 11-24',
                conditions=dict(source_immediate=value,width=width,destination=0,second_extension_miss=True))
