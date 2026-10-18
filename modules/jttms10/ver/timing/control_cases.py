#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""TI control-flow timing and architectural fixtures, independent of RTL.

PCs are bit addresses; relative offsets are signed word counts from PC'.
Target NOPs return through A12 to register initialization on either path,
so the measured second pass starts with the same operands and warm targets.
"""
from alu_cases import initial_status
from scalar_cases import MASK32, N, C, Z, V
from load_cases import extract
from store_cases import insert

PAGES = dict(JUMP='12-98', EXGPC='12-79', DSJ='12-70',
             DSJEQ='12-71/72', DSJNE='12-73/74', DSJS='12-75',
             JR_SHORT='12-94/95', JR_LONG='12-96/97', JACC='12-92/93')
BASES = dict(JUMP=0x0160, EXGPC=0x0120, DSJ=0x0D80,
             DSJEQ=0x0DA0, DSJNE=0x0DC0, DSJS=0x3800,
             JR_SHORT=0xC000, JR_LONG=0xC000, JACC=0xC080)
LENGTHS = dict(JUMP=1, EXGPC=1, DSJ=2, DSJEQ=2, DSJNE=2, DSJS=1,
               JR_SHORT=1, JR_LONG=2, JACC=3)


def condition(code, status):
    """TI condition table pp.12-92..97; code1 is positive (N=Z=0)."""
    if code not in range(16):
        raise ValueError('condition code must be 0..15')
    n,c,z,v=(bool(status & mask) for mask in (N,C,Z,V))
    return (True, not(n or z), c or z, not(c or z), n!=v, n==v,
            n!=v or z, n==v and not z, c, not c, z, not z,
            v, not v, n, not n)[code]


def decrement(name, value, status):
    """TI pp.12-70..75: original Z gates both decrement and jump."""
    if name not in ('DSJ','DSJEQ','DSJNE','DSJS'):
        raise ValueError('not a decrement-and-jump instruction')
    enabled = name not in ('DSJEQ','DSJNE') or bool(status & Z)==(name=='DSJEQ')
    result=(value-1)&MASK32 if enabled else value
    return result, enabled and result!=0


def control_states(name, *, taken=True, cache_disabled=False):
    """Primary counts, including the slower DSJS no-jump path.

    JR summary/entry conflicts are retained on the fixtures, never hidden.
    SPVS002C (June1991) p14 gives JR_LONG no-jump minimum 2, unlike the
    older entry's 4 and summary's 1. Its selected CD5 adds the normal
    following-opcode fetch penalty to that newer minimum. All alternatives
    and the inferred CD count remain explicit on the fixtures.
    """
    if name not in PAGES:
        raise ValueError('unknown control-flow instruction')
    hit,cd = ((2,5) if name in ('JUMP','EXGPC') else
              ((2,5) if taken else (3,6)) if name=='DSJS' else
              ((3,9) if taken else (2,8)) if name in ('DSJ','DSJEQ','DSJNE') else
              ((2,5) if taken else (1,4)) if name=='JR_SHORT' else
              ((3,6) if taken else (2,5)) if name=='JR_LONG' else
              ((3,6) if taken else (4,7)))
    return (hit,cd)[int(cache_disabled)]


def fetch_extensions(case):
    """Untaken JR/JAcc do not need the unused relative/absolute address.

    TI conditional execution descriptions pp.12-92/96; fetch on request
    with CD (§5.4.7 p.5-25). DSJ's 2/8 no-jump count still includes its
    offset word, including when the original Z gate inhibits decrement.
    """
    flow=case['control_flow']
    return [] if flow['form'] in ('JR_LONG','JACC') and not flow['taken'] else case.get('extensions',[])


def fixture(name, *, off=False, flags=0, bank=0, reg=0, value=9,
            displacement=8, code=0, low_bits=0, alignment=0, tag=None,
            single_pass=False, test_address=None, target_address=None):
    if name not in PAGES or bank not in (0,1) or reg not in (0,1,2,3,15):
        raise ValueError('undefined control-flow fixture')
    if name in ('JUMP','EXGPC','DSJ','DSJEQ','DSJNE','DSJS') and not bank and reg==3:
        raise ValueError('A3 holds the initial ST in these fixtures')
    if test_address is not None:
        if name not in ('JUMP','EXGPC') or test_address%16 or target_address is None or target_address%16:
            raise ValueError('literal register-jump PCs must be word aligned')
        displacement=(target_address-test_address-16)//16
    if name=='DSJS' and (not displacement or not -31<=displacement<=31):
        raise ValueError('DSJS fixture displacement must fit its five-bit magnitude')
    if name=='JR_SHORT' and (not displacement or not -127<=displacement<=127):
        raise ValueError('short relative fixture displacement must be nonzero and exclude 80h')
    if name in ('DSJ','DSJEQ','DSJNE','JR_LONG') and not -32768<=displacement<=32767:
        raise ValueError('long relative displacement must fit 16 bits')
    st=initial_status(flags)
    a=[0x11223344,0x55667788,0x99AABBCC,st]
    b={q:0xB0102030+q*0x1020304 for q in range(4)}
    sp=0x12345000
    def put(register_value):
        nonlocal sp
        if reg==15:sp=register_value
        elif bank:b[reg]=register_value
        else:a[reg]=register_value
    taken=True
    if name.startswith('DSJ'):
        put(value)
        updated,taken=decrement(name,value,st)
    elif name in ('JR_SHORT','JR_LONG','JACC'):
        taken=condition(code,st)
    expected=list(a);extra={f'b{r}':v for r,v in b.items()};extra['sp']=sp
    if name.startswith('DSJ'):
        if reg==15:extra['sp']=updated
        elif bank:extra[f'b{reg}']=updated
        else:expected[reg]=updated
    suffix=f'{"m" if displacement<0 else "p"}{abs(displacement)}'
    detail=tag or f'cc{code}_nzcv{flags:x}_r{bank}_{reg}_v{value:08x}_d{suffix}_lo{low_bits:x}_a{alignment}'
    opcode=BASES[name]
    if name in ('JR_SHORT','JR_LONG','JACC'):
        opcode|=code<<8
        if name=='JR_SHORT':opcode|=displacement&255
    else:
        opcode|=bank<<4|reg
        if name=='DSJS':opcode|=int(displacement<0)<<10|abs(displacement)<<5
    row=dict(name=f'control_{name.lower()}_{detail}_{"off" if off else "hit"}',
        coverage_id={'JUMP':'JUMP_R','EXGPC':'EXGPC_R'}.get(name,name),
        opcode=opcode,extensions=[0]*(LENGTHS[name]-1),
        regs=a,initial_b_regs=b,initial_sp=sp,expected_regs=expected,
        expected_extra_regs=extra,expected_st=st,cache_disabled=off,
        states=control_states(name,taken=taken,cache_disabled=off),
        citation='SPVU001A '+PAGES[name],
        control_flow=dict(form=name,taken=taken,displacement=displacement,
                          bank=bank,register=reg,low_bits=low_bits,single_pass=single_pass,
                          test_address=test_address),
        instruction_word_offset=alignment,
        conditions=dict(form=name,taken=taken,nczv=flags,condition_code=code,
                        bank=bank,register=reg,value=value,
                        displacement=displacement,low_bits=low_bits))
    if single_pass:row['measure_pass']=0
    if name in ('JR_SHORT','JR_LONG','JACC'):
        row['conditions'].update(bank=None,register=None,value=None)
    if name in ('JR_SHORT','JR_LONG'):
        summary_hit = (2 if name=='JR_SHORT' else 3) if taken else (2 if name=='JR_SHORT' else 1)
        summary_cd=summary_hit+3
        entry_hit=(2 if name=='JR_SHORT' else 3) if taken else (1 if name=='JR_SHORT' else 4)
        row['source_values']=dict(summary_cpu=summary_hit,summary_cd=summary_cd,
            datasheet_cpu=(2 if name=='JR_SHORT' else 3) if taken else (1 if name=='JR_SHORT' else 2),
            entry_typical_cpu=entry_hit,entry_typical_cd=entry_hit+3,
            policy_cpu=control_states(name,taken=taken),
            policy_cd=control_states(name,taken=taken,cache_disabled=True))
        row['timing_source_status']='primary-summary-consistent' if taken else 'inferred-conflict-resolution'
        row['source_notes']='SPVS002C June1991 p14 supplies minimum counts. JR_SHORT agrees with its entry; JR_LONG no-jump minimum2 differs from SPVU001A entry4 and summary1. CD5 for that path is inferred as minimum2 plus the following-opcode fetch3; the older sources print CD7/4. No official erratum is claimed.'
        row['citation']+='; SPVS002C June1991 p14'
    return row


def program(case, movi):
    """Assemble real setup/target paths; no expected counts enter the HDL."""
    flow=case['control_flow'];name=flow['form'];length=LENGTHS[name]
    displacement=flow['displacement']
    target_words=([case['target_opcode'],0x0300,0x0300,0x016C]
                  if 'control_follow' in case else [0x0300,0x016C])
    words=movi(0xC00000B0,14)+movi(0x8018 if case['cache_disabled'] else 0x18,13)
    words += [0x0550,0x81AE]
    loop=0x1000+16*len(words)
    words+=movi(loop,12)  # target/fallthrough return, outside watched A0..A3
    positions={}
    for reg,value in enumerate(case['regs']):
        positions[(0,reg)]=len(words);words+=movi(value,reg)
    for reg,value in case['initial_b_regs'].items():
        positions[(1,reg)]=len(words);words+=movi(value,16+reg)
    positions[(0,15)]=positions[(1,15)]=len(words)
    words+=movi(case['initial_sp'],15)
    words += [0x01A3]+[0x0300]*12
    single_pass=flow['single_pass']
    local_back=displacement<0 and abs(displacement)<1024 and not single_pass
    if local_back:
        # Skip a backward target on entry. Its NOP/JUMP return makes both
        # first-pass outcomes reinitialize the original counter and flags.
        skip=len(words);words += [0xC000,0]
        if flow['test_address'] is not None:
            test_index=(flow['test_address']-0x1000)//16
            target_index=test_index+length+displacement
            assert target_index>=len(words)
            words += [0x0300]*(target_index-len(words))
        else:
            target_index=len(words)
            test_index=target_index-displacement-length
            while test_index%4!=case['instruction_word_offset']:
                words.append(0x0300);target_index+=1;test_index+=1
        assert test_index>=target_index+len(target_words)
        words += target_words
        words += [0x0300]*(test_index-len(words))
        words[skip+1]=(test_index-skip-2)&0xFFFF
    else:
        while len(words)%4!=case['instruction_word_offset']:words.append(0x0300)
        test_index=len(words)
        target_index=test_index+length+displacement
    test_pc=0x1000+16*test_index
    fallthrough=(test_pc+16*length)&MASK32
    target=(fallthrough+16*displacement)&MASK32
    if name in ('JUMP','EXGPC'):
        bank,reg=flow['bank'],flow['register'];value=target|flow['low_bits']
        pos=positions[(bank,reg)]
        words[pos:pos+3]=movi(value,(bank<<4)|reg if reg!=15 else 15)
        if reg==15:case['initial_sp']=value;case['expected_extra_regs']['sp']=value
        elif bank:case['initial_b_regs'][reg]=value;case['expected_extra_regs'][f'b{reg}']=value
        else:case['regs'][reg]=value;case['expected_regs'][reg]=value
        if name=='EXGPC':
            saved=case.get('literal_return_pc',fallthrough)
            if reg==15:case['expected_extra_regs']['sp']=saved
            elif bank:case['expected_extra_regs'][f'b{reg}']=saved
            else:case['expected_regs'][reg]=saved
    if name in ('DSJ','DSJEQ','DSJNE','JR_LONG'):
        case['extensions']=[displacement&0xFFFF]
    elif name=='JACC':
        operand=target|flow['low_bits']
        case['extensions']=[operand&0xFFFF,operand>>16]
        case['conditions']['target_operand']=operand
    words += [case['opcode'],*case['extensions'],0x0300,0x016C]
    if single_pass and target_index>=len(words):
        words += [0x0300]*(target_index+1-len(words))
    if not local_back and not single_pass:
        if test_index+length+2<=target_index<1024:
            words += [0x0300]*(target_index-len(words))+target_words
        else:
            # Signed 16-bit displacement endpoints use sparse full-address
            # instruction words, initialized as stimulus like ordinary code.
            image={((target&~63)+16*q)&MASK32:0x0300 for q in range(8)}
            image.update({(target+16*q)&MASK32:word for q,word in enumerate(target_words)})
            case['initial_memory']=sorted(image.items())
    next_pc=target if flow['taken'] else fallthrough
    case['conditions'].update(test_pc=test_pc,pc_prime=fallthrough,target=target)
    if single_pass:
        # The current opcode fill already contains this nearby target.
        # Stop at the first following decode, including a legal self jump
        # or a target that happens to contain another control instruction.
        assert target//64==test_pc//64
        case['expected_next_opcode']=words[(next_pc-0x1000)//16]
    else:case['expected_next_opcode']=target_words[0]
    if 'control_follow' in case:case['follow_pc']=(next_pc+16)&MASK32
    return words,test_pc,next_pc


def control_cases():
    identities=((0,0),(0,1),(0,2),(0,15),(1,0),(1,1),(1,3),(1,15))
    for off in (False,True):
        for name in ('JUMP','EXGPC'):
            for bank,reg in identities:
                for low in range(16):
                    for displacement in (-8,8):
                        yield fixture(name,off=off,flags=low,bank=bank,reg=reg,
                                      displacement=displacement,low_bits=low)
        # Literal PCs, target and saved return from TI p.12-79.
        for target in (0x1C10,0x1C50):
            row=fixture('EXGPC',off=off,reg=1,test_address=0x2080,
                        target_address=target,tag=f'guide_{target:08x}')
            row['literal_return_pc']=0x2090
            yield row
        for name in ('DSJ','DSJEQ','DSJNE','DSJS'):
            for flags in (0,3,5,0xA,0xC,0xF):
                for bank,reg in identities:
                    for value in (0,1,2,9,0x80000000,MASK32):
                        for displacement in ((-31,-3,3,31) if name=='DSJS' else (-32768,-8,8,32767)):
                            yield fixture(name,off=off,flags=flags,bank=bank,reg=reg,
                                          value=value,displacement=displacement)
        for name in ('JR_SHORT','JR_LONG','JACC'):
            for code in range(16):
                for flags in range(16):
                    for displacement in ((-127,-3,3,127) if name=='JR_SHORT' else
                                         (-32768,-8,8,32767) if name=='JR_LONG' else (-8,8)):
                        yield fixture(name,off=off,flags=flags,code=code,displacement=displacement)
        # All within-subsegment opcode offsets, independently of the full
        # condition/operand matrix's default alignment.
        for name in PAGES:
            for alignment in (1,2,3):
                yield fixture(name,off=off,flags=0xF,code=10,alignment=alignment,
                              tag=f'word_offset{alignment}')
        for name in ('DSJS','JR_SHORT'):
            for displacement in (-2,-1,1,2):
                for take in (False,True):
                    yield fixture(name,off=off,flags=3 if take else 0,code=10,
                        value=9 if take else 1,displacement=displacement,
                        alignment=2 if displacement<0 else 0,single_pass=True,
                        tag=f'close_{displacement}_{int(take)}')
        for name in ('DSJ','DSJEQ','DSJNE'):
            for value in (1,9):
                yield fixture(name,off=off,flags=3 if name=='DSJEQ' else 0,value=value,
                    displacement=0,single_pass=True,tag=f'zero_offset_{value}')
        # Every early CEN phase includes each control path, both cached
        # and CD, with the actual A/B/SP register paths kept active.
        for name in PAGES:
            for take in ((True,) if name in ('JUMP','EXGPC') else (False,True)):
                flags=(3 if take else 0) if name in ('JR_SHORT','JR_LONG','JACC','DSJEQ') else (0 if take else 3)
                yield fixture(name,off=off,flags=flags,code=10,bank=1,reg=15,
                    value=1 if not take and name in ('DSJ','DSJS') else 9,
                    tag=f'phase_{"taken" if take else "untaken"}')
    # Fast direct dispatch must prime the following instruction's actual
    # synchronous register ports, including an early first-state field.
    for name in ('JR_LONG','JACC'):
        for kind in ('load','store'):
            for displacement in (-8,8):
                row=fixture(name,off=True,flags=3,code=10,displacement=displacement,
                            tag=f'target_{kind}_{"back" if displacement<0 else "forward"}')
                memory=[(0x6000,0x9B6D),(0x6010,0xA596),(0x6020,0x35C6)]
                a=list(row['regs']);a[0]=0x600F if kind=='store' else 0x11223344
                a[2]=0xE1709B6D if kind=='store' else 0x600F
                expected=list(a);st=row['expected_st']
                if kind=='load':
                    value=extract(memory,0x600F,16,False);expected[0]=value
                    st=(st & ~(N|Z|V)) | (value&N) | (Z if not value else 0)
                row.update(regs=a,expected_regs=list(a),initial_memory=memory,
                    target_opcode=0x8040 if kind=='store' else 0x8440,
                    control_follow=dict(kind=kind,states=11 if kind=='store' else 8,
                                        transfers=5 if kind=='store' else 3),
                    expected_follow_regs=expected,expected_follow_st=st,
                    expected_follow_memory=insert(memory,0x600F,16,a[2]) if kind=='store' else memory,
                    drain_instructions=2)
                yield row
    # The combined absolute-address capture must use a nonzero high word,
    # including bit31 and near-wrap targets. Register jumps exercise the
    # same full transport addresses and ignored low target bits.
    for off in (False,True):
        for name in ('JUMP','EXGPC','JACC'):
            for bank in ((0,) if name=='JACC' else (0,1)):
                for displacement in (0x01000000,0x07FFF000,0x08000000,0x0FFFF000):
                    yield fixture(name,off=off,flags=3,code=10,bank=bank,reg=1,
                        displacement=displacement,low_bits=15,
                        tag=f'high_pc_{displacement:08x}_r{bank}')
