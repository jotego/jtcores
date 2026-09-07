#!/usr/bin/env python3
"""Video sheet 1/5 (1B11140), components laid out to mirror money_money.pdf p3.
Placement only. Coordinates mapped from the scan; refine in KiCad as needed."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from hier import ROOT, SHEETS
from kisch import lib_symbol, power_symbol, pins_of, pins_of_unit, uid, extract, _cache, LIBS, load

# extra: pull Device:R_US / Device:C blocks from kunio (KiCad stock symbols)
_kun = load('cores/kunio/sch/colmix.kicad_sch')
def stock(lib_id):
    b = extract(_kun, lib_id)          # e.g. "Device:R_US"
    return b

def get_sym(lib_id):
    if lib_id.startswith('Device:'):
        return stock(lib_id)
    if lib_id.startswith('power:'):
        return power_symbol(lib_id.split(':')[1])
    return lib_symbol(lib_id)

# scan->mm mapping (image ~2000x1390; drawing border px x:80..1960 y:55..1320)
def SN(v): return round(round(v/1.27)*1.27,2)
def MM(px,py):
    x = 15 + (px-80)/1880.0*395
    y = 12 + (py-55)/1265.0*278
    return (SN(x), SN(y))

# (lib_id, ref, unit, px, py, rot)
C = [
 # --- sync / blank (top-left) ---
 ('jt74:74LS10','5N',3, 205,155,0),
 ('jt74:74LS74','5P',2, 360,165,0),
 ('jt74:74LS02','5H',2, 575,300,0),
 ('jt74:74LS08','5G',3, 575,370,0),
 ('jt74:74LS04','5K',5, 185,395,0),
 ('jt74:74LS04','5K',4, 185,475,0),
 ('jt74:74LS00','5J',2, 320,455,0),
 ('jt74:74LS74','5M',1, 440,475,0),
 ('jt74:74LS08','5G',2, 575,445,0),
 # --- V counter (mid-left) ---
 ('jt74:74LS74','2L',1, 145,615,0),
 ('jt74:74LS161','3N',1, 360,640,0),
 ('jt74:74LS161','4N',1, 535,640,0),
 ('jt74:74LS02','5H',1, 695,625,0),
 # --- H counter (lower-mid-left) ---
 ('jt74:74LS74','2L',2, 145,880,0),
 ('jt74:74LS161','3L',1, 360,900,0),
 ('jt74:74LS161','4L',1, 535,900,0),
 ('jt74:74LS04','5K',3, 660,800,0),
 # --- oscillator (bottom-left) ---   # 6MHz buffer  # 1Hu buffer  # 6MHz buffer 2  # osc inv 1  # osc inv 2  # osc inv 3
 ('jt74:74LS368','2N',1, 470,1075,0),   # hex 3-state buffer/inverter (whole chip)
 ('mnymny:Crystal','QZ',1, 300,1210,0),
 ('Device:C','C2',1, 300,1060,0),
 ('Device:R_US','R1',1, 470,1005,90),
 ('Device:R_US','R2',1, 205,1100,90),
 ('jt74:74LS107','2M',1, 640,1120,0),
 ('jt74:74LS107','2M',2, 750,1120,0),
 # --- flip XOR V ladder (center) ---
 ('jt74:74LS86','4P',1, 915,150,0),
 ('jt74:74LS86','4P',2, 915,205,0),
 ('jt74:74LS86','4P',3, 915,260,0),
 ('jt74:74LS86','4P',4, 915,315,0),
 ('jt74:74LS86','3P',1, 915,385,0),
 ('jt74:74LS86','3P',2, 915,440,0),
 ('jt74:74LS86','3P',3, 915,495,0),
 ('jt74:74LS86','3P',4, 915,555,0),
 # --- flip XOR H ladder (center) ---
 ('jt74:74LS86','4M',1, 915,630,0),
 ('jt74:74LS86','3M',1, 915,700,0),
 ('jt74:74LS86','3M',2, 915,760,0),
 ('jt74:74LS86','3M',3, 915,815,0),
 ('jt74:74LS86','3M',4, 915,875,0),
 # --- center bottom ---
 ('jt74:74LS20','5L',1, 965,925,0),
 ('jt74:74LS74','5M',2, 975,1015,0),
 ('jt74:74LS10','5N',1, 1235,1075,0),
 ('jt74:74LS10','5N',2, 1290,1155,0),
 ('jt74:74LS04','5K',2, 1140,1155,0),
 # --- palette (right) ---
 ('jt74:74LS02','8L',4, 1120,145,0),
 ('jt74:74LS02','8L',1, 1215,145,0),
 ('mnymny:82S131','9F',1, 1325,205,0),
 ('mnymny:82S131','9G',1, 1325,475,0),
 ('jt74:74LS374','9J',1, 1500,310,0),
 ('jt74:74LS157','9E',1, 1610,710,0),
 ('jt74:74LS157','9D',1, 1610,890,0),
 ('jt74:74LS02','6G',2, 1350,985,0),
 ('jt74:74LS00','6L',3, 1480,985,0),
 ('jt74:74LS367','9M',1, 1650,1120,0),  # hex 3-state buffer (whole chip)
 # --- DAC resistors (right) ---
 ('Device:R_US','R8',1, 1660,150,90),
 ('Device:R_US','R9',1, 1660,210,90),
 ('Device:R_US','R10',1, 1660,270,90),
 ('Device:R_US','R11',1, 1660,330,90),
 ('Device:R_US','R12',1, 1660,390,90),
 ('Device:R_US','R5',1, 1660,450,90),
 ('Device:R_US','R4',1, 1660,505,90),
 ('Device:R_US','R6',1, 1660,560,90),
 ('Device:R_US','R7',1, 1770,230,0),
 ('Device:R_US','R13',1, 1770,360,0),
 ('Device:R_US','R3',1, 1770,520,0),
 ('Device:R_US','R15',1, 1790,1035,90),
 ('Device:R_US','R14',1, 1790,1075,90),
 ('Device:R_US','R16',1, 1790,1115,90),
 ('Device:R_US','R17',1, 1790,1155,90),
 ('Device:R_US','R19',1, 1810,1180,0),
 ('Device:R_US','R18',1, 1840,1250,90),
]

VAL = {'82S131':'82S131','QZ':'18.432MHz','C2':'100pF','R1':'330','R2':'330',
       'R8':'680','R9':'1K','R10':'820','R11':'1K','R12':'1K2','R5':'820','R4':'1K',
       'R6':'1K2','R7':'470','R13':'390','R3':'390','R15':'','R14':'','R16':'','R17':'',
       'R19':'470','R18':'100'}
def value_for(lib_id,ref):
    if ref in VAL: return VAL[ref]
    if lib_id.startswith('jt74:'): return lib_id.split(':')[1]
    if lib_id=='mnymny:82S131': return '82S131'
    return lib_id.split(':')[1]

used=sorted({c[0] for c in C})
lib_syms=[get_sym(u) for u in used] + [power_symbol('VCC'), power_symbol('VSS')]

def prop(name,val,x,y,hide=False):
    h='\n\t\t\t\t(hide yes)' if hide else ''
    return (f'\t\t(property "{name}" "{val}"\n\t\t\t(at {x} {y} 0)\n'
            f'\t\t\t(effects\n\t\t\t\t(font\n\t\t\t\t\t(size 1.27 1.27)\n\t\t\t\t){h}\n\t\t\t)\n\t\t)\n')

out=['(kicad_sch\n\t(version 20231120)\n\t(generator "eeschema")\n\t(generator_version "8.0")\n']
RU=SHEETS['video1']['filuuid']
IP=f"/{ROOT}/{SHEETS['video1']['symuuid']}"
out.append(f'\t(uuid "{RU}")\n\t(paper "A3")\n')
out.append('\t(title_block\n\t\t(title "MONEY MONEY - 1B11140 VIDEO 1/5")\n\t\t(date "2026-09-07")\n\t\t(rev "P82-003/A/M3")\n\t\t(company "JOTEGO")\n'
           '\t\t(comment 1 "Money Money / Jack Rabbit")\n\t\t(comment 2 "For repair and maintenance")\n\t)\n')
out.append('\t(lib_symbols\n')
for b in lib_syms: out.append('\t\t'+b.replace('\n','\n\t\t')+'\n')
out.append('\t)\n')

for lib_id,ref,unit,px,py,rot in C:
    pmap=pins_of(get_sym(lib_id))
    X,Y=MM(px,py)
    su=uid()
    s=f'\t(symbol\n\t\t(lib_id "{lib_id}")\n\t\t(at {X} {Y} {rot})\n\t\t(unit {unit})\n'
    s+='\t\t(exclude_from_sim no)\n\t\t(in_bom yes)\n\t\t(on_board yes)\n\t\t(dnp no)\n'
    s+=f'\t\t(uuid "{su}")\n'
    dp = 5.08 if lib_id.startswith(('Device:','mnymny:Crystal')) else 12
    s+=prop("Reference",ref,X,Y-dp)
    s+=prop("Value",value_for(lib_id,ref),X,Y+dp)
    s+=prop("Footprint","",X,Y,hide=True)
    for num in sorted(pmap): s+=f'\t\t(pin "{num}"\n\t\t\t(uuid "{uid()}")\n\t\t)\n'
    s+=('\t\t(instances\n\t\t\t(project "mnymny"\n'
        f'\t\t\t\t(path "{IP}"\n\t\t\t\t\t(reference "{ref}")\n\t\t\t\t\t(unit {unit})\n\t\t\t\t)\n\t\t\t)\n\t\t)\n')
    out.append(s+'\t)\n')


# ---------- WIRING: flip-XOR ladders (labels-on-stubs, JOTEGO single-wire style) ----------
import math as _math
def _pin_abs(X,Y,R,px,py):
    a=_math.radians(R); y=-py
    return (round(X+px*_math.cos(a)-y*_math.sin(a),2), round(Y+px*_math.sin(a)+y*_math.cos(a),2))
STUB=5.08
_wires=[]; _labels=[]
# find placement (X,Y) for a given ref/unit from table C
def _xy(ref,unit):
    for lib_id,r,u,px,py,rot in C:
        if r==ref and u==unit: return MM(px,py)+(rot,lib_id)
    raise SystemExit(f'NOT PLACED: {ref} unit {unit}')
# gate -> (A_in bit, out primed); B_in is the common flip control
LADDERS=[
 ('VCMA',[('4P',1,'128V'),('4P',2,'64V'),('4P',3,'32V'),('4P',4,'16V'),
          ('3P',1,'8V'),('3P',2,'4V'),('3P',3,'2V'),('3P',4,'1V')]),
 ('HCMP1*',[('4M',1,'128H'),('3M',1,'64H'),('3M',2,'32H'),('3M',3,'16H'),('3M',4,'8H')]),
]
def _lab(name,x,y,side):
    ang=0; just='right' if side=='L' else 'left'
    _labels.append(f'\t(label "{name}"\n\t\t(at {x} {y} {ang})\n\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n\t\t\t)\n\t\t\t(justify {just})\n\t\t)\n\t\t(uuid "{uid()}")\n\t)\n')
def _wire(x1,y1,x2,y2):
    _wires.append(f'\t(wire\n\t\t(pts\n\t\t\t(xy {x1} {y1}) (xy {x2} {y2})\n\t\t)\n\t\t(stroke\n\t\t\t(width 0)\n\t\t\t(type default)\n\t\t)\n\t\t(uuid "{uid()}")\n\t)\n')
for ctrl,gates in LADDERS:
    for ref,unit,bit in gates:
        X,Y,rot,lib_id=_xy(ref,unit)
        pu=pins_of_unit(lib_symbol(lib_id),unit)
        # inputs: the two smallest-x pins; output: the +x pin
        ins=sorted([n for n in pu if pu[n][0]<0], key=lambda n:pu[n][1])
        outn=[n for n in pu if pu[n][0]>0][0]
        pA=pu[ins[-1]]; pB=pu[ins[0]]  # A=top (higher y), B=bottom
        ax,ay=_pin_abs(X,Y,rot,pA[0],pA[1]); _wire(ax,ay,ax-STUB,ay); _lab(bit,ax-STUB,ay,'L')
        bx,by=_pin_abs(X,Y,rot,pB[0],pB[1]); _wire(bx,by,bx-STUB,by); _lab(ctrl,bx-STUB,by,'L')
        ox,oy=_pin_abs(X,Y,rot,pu[outn][0],pu[outn][1]); _wire(ox,oy,ox+STUB,oy); _lab(bit+"'",ox+STUB,oy,'R')

# ---------- WIRING: oscillator + /3 divider + clock buffers ----------
def _pins(ref,unit):
    X,Y,rot,lib_id=_xy(ref,unit)
    pu=pins_of_unit(lib_symbol(lib_id) if not lib_id.startswith(('Device:','power:')) else get_sym(lib_id),unit)
    if not pu: pu=pins_of(get_sym(lib_id))
    return {n:_pin_abs(X,Y,rot,px,py) for n,(px,py,_a) in pu.items()}
def _wire_L(a,b):
    if a[0]==b[0] or a[1]==b[1]: _wire(a[0],a[1],b[0],b[1])
    else:
        _wire(a[0],a[1],b[0],a[1]); _wire(b[0],a[1],b[0],b[1])
def _chain(*pts):
    for i in range(len(pts)-1): _wire_L(pts[i],pts[i+1])
def _stub_label(ref,unit,pin,name,side):
    pp=_pins(ref,unit)[pin]
    dx=-STUB if side=='L' else STUB
    _wire(pp[0],pp[1],round(pp[0]+dx,2),pp[1]); _lab(name,round(pp[0]+dx,2),pp[1],side)
def _pwr(ref,unit,pin,kind,down=False):
    pp=_pins(ref,unit)[pin]
    pr=uid()
    out.append(
        f'\t(symbol\n\t\t(lib_id "power:{kind}")\n\t\t(at {pp[0]} {pp[1]} {180 if down else 0})\n\t\t(unit 1)\n'
        f'\t\t(exclude_from_sim no)\n\t\t(in_bom no)\n\t\t(on_board yes)\n\t\t(dnp no)\n\t\t(uuid "{pr}")\n'
        + prop("Reference","#PWR",pp[0],pp[1],hide=True)
        + prop("Value",("VCC" if kind=="VCC" else "GND"),pp[0]+3,pp[1])
        + f'\t\t(pin "1"\n\t\t\t(uuid "{uid()}")\n\t\t)\n'
        + '\t\t(instances\n\t\t\t(project "mnymny"\n'
          f'\t\t\t\t(path "{IP}"\n\t\t\t\t\t(reference "#PWR")\n\t\t\t\t\t(unit 1)\n\t\t\t\t)\n\t\t\t)\n\t\t)\n\t)\n')

N2=lambda pin:_pins('2N',1)[pin]
M1=lambda pin:_pins('2M',1)[pin]
M2=lambda pin:_pins('2M',2)[pin]
R_1=_pins('R1',1); R_2=_pins('R2',1); C_2=_pins('C2',1); QZp=_pins('QZ',1)
def _junc(x,y):
    out.append(f'\t(junction\n\t\t(at {x} {y})\n\t\t(diameter 0)\n\t\t(color 0 0 0 0)\n\t\t(uuid "{uid()}")\n\t)\n'.replace('{uid()}',uid()))
def _seg(*pts):
    for a,b in zip(pts,pts[1:]):
        if a!=b: _wire(a[0],a[1],b[0],b[1])
R2p=_pins('R2',1); R1p=_pins('R1',1); C2p=_pins('C2',1); QZq=_pins('QZ',1)
p2,p3,p4,p5,p6,p7 = (N2(k) for k in ('2','3','4','5','6','7'))
m112=M1('12'); m29=M2('9')
# NOTE: Device:R_US at rot 90: pin 1 = RIGHT pin, pin 2 = LEFT pin
R2L,R2R = R2p['2'],R2p['1']
R1L,R1R = R1p['2'],R1p['1']
# XT1: R2.left <- left rail -> top run -> C2.top drop -> 2N.2
ytop=SN(min(p2[1],C2p['1'][1])-5.08); xrail=SN(R2L[0]-5.08); xmid=SN(p2[0]-5.08)
_seg(R2L,(xrail,R2L[1]),(xrail,ytop),(C2p['1'][0],ytop))
_seg((C2p['1'][0],ytop),C2p['1'])
_seg((C2p['1'][0],ytop),(xmid,ytop),(xmid,p2[1]),p2)
_junc(C2p['1'][0],ytop)
# XT2: 2N.3 -> over the top -> far-left outer rail -> low bus -> R2.right (up) ; branch QZ.1
ybus2=SN(QZq['1'][1]-6.35); xouter=SN(R2L[0]-10.16); ytop2=SN(min(p2[1],C2p['1'][1])-10.16)
_seg(p3,(SN(p3[0]+2.54),p3[1]),(SN(p3[0]+2.54),ytop2),(xouter,ytop2),(xouter,ybus2),(R2R[0],ybus2))
_seg((R2R[0],ybus2),R2R)
_junc(R2R[0],ybus2)
_seg((R2R[0],ybus2),(QZq['1'][0],ybus2),QZq['1'])
# XT3: QZ.2 -> up rail -> 2N.4 ; rail continues up to R1.left (R1 sits above the chip)
xv=SN(QZq['2'][0]+5.08)
_seg(QZq['2'],(xv,QZq['2'][1]),(xv,p4[1]))
_seg((xv,p4[1]),p4)
_junc(xv,p4[1])
_seg((xv,p4[1]),(xv,R1L[1]),(R1L[0],R1L[1]))
# XT4: 2N.5 -> right rail: up to R1.right, down to bus under the chip -> 2N.6 ; branch C2.bot
xr5=SN(p5[0]+5.08); ybus4=SN(N2('15')[1]+2.54); xl6=SN(p6[0]-7.62); xC=C2p['2'][0]
_seg(p5,(xr5,p5[1]))
_seg((xr5,p5[1]),(xr5,R1R[1]),(R1R[0],R1R[1]))
_junc(xr5,p5[1])
_seg((xr5,p5[1]),(xr5,ybus4),(xl6,ybus4))
_seg((xl6,ybus4),(xl6,p6[1]),p6)
_junc(xl6,ybus4)
_seg((xl6,ybus4),(xC,ybus4))
_seg((xC,ybus4),C2p['2'])
# OSC18: 2N.7 -> one straight run along the CK row (hits 2M1.12 and 2M2.9)
xs7=SN(p7[0]+3.81)
_seg(p7,(xs7,p7[1]),(xs7,m112[1]),(m29[0],m29[1]))
_junc(m112[0],m112[1])
# 2MJ1: J1 <- /Q2 as a top loop (PDF style), no labels
j1=M1('1'); q2b=M2('6')
ytl=SN(j1[1]-7.62); xj=SN(j1[0]-3.81); xq=SN(q2b[0]+5.08)
_seg(j1,(xj,j1[1]),(xj,ytl),(xq,ytl),(xq,q2b[1]),q2b)
# /3 cross-coupling via labels (CLK = Q1)
for r,u,pin,name,side in [('2M',1,'3','CLK','R'),('2M',2,'8','CLK','L'),
                          ('2N',1,'12','CLK','L')]:
    _stub_label(r,u,pin,name,side)
# clock buffer outputs + 1H buffer
_stub_label('2N',1,'11','6MHz','R')
_stub_label('2N',1,'10','6MHz','L')
_stub_label('2N',1,'9','/6MHz','R')
_stub_label('2N',1,'14','1H','L')
_stub_label('2N',1,'13','1Hu','R')
# K / /RD to VCC, /OE to GND
for r,u,pin in [('2M',1,'4'),('2M',1,'13'),('2M',2,'11'),('2M',2,'10')]:
    _pwr(r,u,pin,'VCC')
for pin in ('1','15'):
    _pwr('2N',1,pin,'VSS',down=True)


# ---------- WIRING: sync / blank / V+H counters ----------
def _pwrx(ref,unit,pin,kind='VCC'):
    _pwr(ref,unit,pin,kind,down=(kind=='VSS'))
# VBLANK chain: 5N u3 NAND(32V,64V,128V) -> 5P u2 latch
for pn,nm in (('11','128V'),('10','64V'),('9','32V')): _stub_label('5N',3,pn,nm,'L')
p5n=_pins('5N',3); p5p=_pins('5P',2)
_seg(p5n['8'],(SN(p5n['8'][0]+2.54),p5n['8'][1]))
_seg((SN(p5n['8'][0]+2.54),p5n['8'][1]),(SN(p5p['12'][0]-2.54),p5p['12'][1]),p5p['12'])
_stub_label('5P',2,'11','16V','L')
_stub_label('5P',2,'9','/VBLANK','R')
_stub_label('5P',2,'8','VBLANK','R')
_pwrx('5P',2,'10'); _pwrx('5P',2,'13')
# CBLANK* : 5H u2 NOR(VBLANK,256H)
_stub_label('5H',2,'6','VBLANK','L'); _stub_label('5H',2,'5','256H','L')
_stub_label('5H',2,'4','CBLANK*','R')
# 256H inverter 5K u5, HCMP1* 5G u3
_stub_label('5K',5,'11','/256H','L'); _stub_label('5K',5,'10','256H','R')
_stub_label('5G',3,'10','256H','L');  _stub_label('5G',3,'9','HCMA','L')
_stub_label('5G',3,'8','HCMP1*','R')
# sync flop 5M u1: D=NAND(32H,/64H), CK=16H, /PRE=256H
_stub_label('5K',4,'9','64H','L'); 
p5k4=_pins('5K',4); p5j=_pins('5J',2)
_seg(p5k4['8'],(SN(p5k4['8'][0]+2.54),p5k4['8'][1]),(SN(p5j['5'][0]-2.54),p5j['5'][1]),p5j['5'])
_stub_label('5J',2,'4','32H','L')
p5m=_pins('5M',1)
_seg(p5j['6'],(SN(p5j['6'][0]+2.54),p5j['6'][1]),(SN(p5m['2'][0]-2.54),p5m['2'][1]),p5m['2'])
_stub_label('5M',1,'3','16H','L')
_stub_label('5M',1,'4','256H','L')
_pwrx('5M',1,'1')
_stub_label('5M',1,'5','SYNCV','R')
_stub_label('5M',1,'6','VCK','R')
# CSYNC 5G u2
_stub_label('5G',2,'4','/VSYNC','L'); _stub_label('5G',2,'5','SYNCV','L')
_stub_label('5G',2,'6','/CSYNC','R')
# V counter: 2L u1 toggle + 3N/4N
pv=_pins('2L',1)
_seg(pv['6'],(SN(pv['6'][0]+2.54),pv['6'][1]),(SN(pv['6'][0]+2.54),SN(pv['6'][1]+6.35)),
     (SN(pv['2'][0]-3.81),SN(pv['6'][1]+6.35)),(SN(pv['2'][0]-3.81),pv['2'][1]),pv['2'])
_stub_label('2L',1,'3','VCK','L'); _stub_label('2L',1,'5','1V','R')
_pwrx('2L',1,'4'); _pwrx('2L',1,'1')
for ref in ('3N','4N'):
    _stub_label(ref,1,'2','VCK','L')
    _stub_label(ref,1,'9','/VLD','L')
    _pwrx(ref,1,'1')
for pn,nm in (('10','1V'),('7','1V')): _stub_label('3N',1,pn,nm,'L')
for pn,nm in (('10','VTC1'),('7','VTC1')): _stub_label('4N',1,pn,nm,'L')
_stub_label('3N',1,'15','VTC1','R'); _stub_label('4N',1,'15','VTC2','R')
for pn,nm in (('14','2V'),('13','4V'),('12','8V'),('11','16V')): _stub_label('3N',1,pn,nm,'R')
for pn,nm in (('14','32V'),('13','64V'),('12','128V'),('11','/VSYNC')): _stub_label('4N',1,pn,nm,'R')
for pn,k in (('3','VSS'),('4','VSS'),('5','VCC'),('6','VCC')): _pwrx('3N',1,pn,k)
for pn,k in (('3','VCC'),('4','VCC'),('5','VCC'),('6','VSS')): _pwrx('4N',1,pn,k)
# V reload inverter 5H u1
for pn in ('2','3'): _stub_label('5H',1,pn,'VTC2','L')
_stub_label('5H',1,'1','/VLD','R')
# H counter: 2L u2 + 3L/4L (2L u2 toggle already implied by osc? no - wire it)
ph=_pins('2L',2)
_seg(ph['8'],(SN(ph['8'][0]+2.54),ph['8'][1]),(SN(ph['8'][0]+2.54),SN(ph['8'][1]+6.35)),
     (SN(ph['12'][0]-3.81),SN(ph['8'][1]+6.35)),(SN(ph['12'][0]-3.81),ph['12'][1]),ph['12'])
_stub_label('2L',2,'11','6MHz','L'); _stub_label('2L',2,'9','1H','R')
_pwrx('2L',2,'10'); _pwrx('2L',2,'13')
for ref in ('3L','4L'):
    _stub_label(ref,1,'2','6MHz','L')
    _pwrx(ref,1,'1')
for pn,nm in (('10','1H'),('7','1H')): _stub_label('3L',1,pn,nm,'L')
for pn,nm in (('10','HTC1'),('7','HTC1')): _stub_label('4L',1,pn,nm,'L')
_pwrx('3L',1,'9')   # /PE=VCC free run
_stub_label('4L',1,'9','/HLD','L')
_stub_label('3L',1,'15','HTC1','R'); _stub_label('4L',1,'15','HTC2','R')
for pn,nm in (('14','2H'),('13','4H'),('12','8H'),('11','16H')): _stub_label('3L',1,pn,nm,'R')
for pn,nm in (('14','32H'),('13','64H'),('12','128H'),('11','/256H')): _stub_label('4L',1,pn,nm,'R')
for pn in ('3','4','5','6'): _pwrx('3L',1,pn,'VSS')
for pn,k in (('3','VSS'),('4','VSS'),('5','VCC'),('6','VSS')): _pwrx('4L',1,pn,k)
# H reload inverter 5K u3
_stub_label('5K',3,'5','HTC2','L'); _stub_label('5K',3,'6','/HLD','R')
# HBLANK flop 5M u2 + 5L NAND
for pn,nm in (('1','8H'),('2','16H'),('4','32H'),('5','64H')): _stub_label('5L',1,pn,nm,'L')
p5l=_pins('5L',1); p5m2=_pins('5M',2)
_seg(p5l['6'],(SN(p5l['6'][0]+2.54),p5l['6'][1]),(SN(p5m2['12'][0]-2.54),p5m2['12'][1]),p5m2['12'])
_stub_label('5M',2,'11','2H','L')
_stub_label('5M',2,'13','256H','L')
_pwrx('5M',2,'10')
_stub_label('5M',2,'9','HBLANK','R')
# LD strobes: 5N u1 -> /LD1 ; 5K u2 + 5N u2 -> /LD2
for pn,nm in (('1','1H'),('2','2H'),('13','4H')): _stub_label('5N',1,pn,nm,'L')
_stub_label('5N',1,'12','/LD1','R')
_stub_label('5K',2,'3','4H','L')
p5k2=_pins('5K',2); p5n2=_pins('5N',2)
_seg(p5k2['4'],(SN(p5k2['4'][0]+2.54),p5k2['4'][1]),(SN(p5n2['4'][0]-2.54),p5n2['4'][1]),p5n2['4'])
_stub_label('5N',2,'3','1H','L'); _stub_label('5N',2,'5','2H','L')
_stub_label('5N',2,'6','/LD2','R')
# ---------- WIRING: palette ----------
# 8L double inverter: SELOBJ -> PA0 (A0 of both PROMs)
for pn in ('11','12'): _stub_label('8L',4,pn,'SELOBJ','L')
p84=_pins('8L',4); p81=_pins('8L',1)
_seg(p84['13'],(SN(p84['13'][0]+2.54),p84['13'][1]))
for pn in ('2','3'):
    _seg((SN(p84['13'][0]+2.54),p84['13'][1]),(SN(p81[pn][0]-2.54),p81[pn][1]),p81[pn])
_junc(SN(p84['13'][0]+2.54),p84['13'][1])
_stub_label('8L',1,'1','PA0','R')
# 9F/9G PROMs
for ref,dnames in (('9F',('PD0','PD1','PD2','PD3')),('9G',('PD4','PD5','PD6','PD7'))):
    for pn,nm in (('5','PA0'),('6','BK1'),('7','BK2'),('4','PA3'),('3','PA4'),
                  ('2','PA5'),('1','PA6'),('15','PA7'),('14','PA8')):
        _stub_label(ref,1,pn,nm,'L')
    for pn,nm in zip(('12','11','10','9'),dnames):
        _stub_label(ref,1,pn,nm,'R')
    _pwrx(ref,1,'13','VSS')
    _pwrx(ref,1,'16','VCC'); _pwrx(ref,1,'8','VSS')
# 9J latch
for pn,nm in (('3','PD0'),('4','PD1'),('7','PD2'),('8','PD3'),
              ('13','PD4'),('14','PD5'),('17','PD6'),('18','PD7'),
              ('11','6MHz'),('1','/VIDOUT')):
    _stub_label('9J',1,pn,nm,'L')
# DAC ladder: 9J Q -> series R -> gun node with pulldown
p9j=_pins('9J',1)
GUNS=[('B',('2','R8'),('5','R9'),None,'R7'),
      ('G',('6','R10'),('9','R11'),('12','R12'),'R13'),
      ('R',('15','R5'),('16','R4'),('19','R6'),'R3')]
xnode=SN(363)
for gi,(gun,*taps) in enumerate(GUNS):
    pull=taps[-1]; taps=[t for t in taps[:-1] if t]
    rows=[]
    for qi,(qpin,rref) in enumerate(taps):
        rp=_pins(rref,1)
        lft=rp['2'] if rp['2'][0]<rp['1'][0] else rp['1']
        rgt=rp['1'] if rp['2'][0]<rp['1'][0] else rp['2']
        q=p9j[qpin]
        xb=SN(q[0]+2.54+qi*1.27)
        _seg(q,(xb,q[1]),(xb,lft[1]),lft)
        _seg(rgt,(xnode,rgt[1]))
        rows.append(rgt[1])
    pp=_pins(pull,1)
    ptop=pp['1'] if pp['1'][1]<pp['2'][1] else pp['2']
    pbot=pp['2'] if pp['1'][1]<pp['2'][1] else pp['1']
    _seg(ptop,(ptop[0],SN(min(rows)-2.54)),(xnode,SN(min(rows)-2.54)))
    _pwr(pull,1,('2' if pbot==pp['2'] else '1'),'VSS',down=True)
    _seg((xnode,SN(min(rows)-2.54)),(xnode,max(rows)))
    for r in rows[:-1]: _junc(xnode,r)
    _lab(gun,xnode,SN(min(rows)-2.54),'R')
# 9E/9D muxes
for pn,nm in (('3','X1OUT'),('6','X2OUT'),('13','X3OUT'),('10','COLOUT1'),
              ('2','X4OUT'),('5','X5OUT'),('14','X6OUT'),('11','COLOUT4'),('1','SELECT')):
    _stub_label('9E',1,pn,nm,'L')
for pn,nm in (('4','PA3'),('7','PA4'),('9','PA5'),('12','PA6')):
    _stub_label('9E',1,pn,nm,'R')
_pwrx('9E',1,'15','VSS')
for pn,nm in (('3','COLOUT2'),('6','COLOUT3'),('2','COLOUT5'),('5','COLOUT6'),('1','SELECT')):
    _stub_label('9D',1,pn,nm,'L')
for pn,nm in (('4','PA7'),('7','PA8')):
    _stub_label('9D',1,pn,nm,'R')
_pwrx('9D',1,'15','VSS')
# VIDOUT gating 6G/6L (inputs uncertain - flagged in PROGRESS)
_stub_label('6G',2,'5','HBLANK','L'); _stub_label('6G',2,'6','VBLANK','L')
p6g=_pins('6G',2); p6l=_pins('6L',3)
_seg(p6g['4'],(SN(p6g['4'][0]+2.54),p6g['4'][1]),(SN(p6l['9'][0]-2.54),p6l['9'][1]),p6l['9'])
_stub_label('6L',3,'10','CBLANK*','L')
_stub_label('6L',3,'8','/VIDOUT','R')
# 9M buffers: CF1-4 + CSYNC -> SYNC out
for pn,nm in (('2','CF1'),('4','CF2'),('6','CF3'),('10','CF4'),('12','/CSYNC')):
    _stub_label('9M',1,pn,nm,'L')
for pn,nm in (('3','CF1O'),('5','CF2O'),('7','CF3O'),('9','CF4O')):
    _stub_label('9M',1,pn,nm,'R')
p9m=_pins('9M',1); r18=_pins('R18',1); r19=_pins('R19',1)
r18l=r18['2'] if r18['2'][0]<r18['1'][0] else r18['1']
r18r=r18['1'] if r18l==r18['2'] else r18['2']
_seg(p9m['11'],(SN(p9m['11'][0]+2.54),p9m['11'][1]),(SN(p9m['11'][0]+2.54),r18l[1]),r18l)
r19t=r19['1'] if r19['1'][1]<r19['2'][1] else r19['2']
r19b=r19['2'] if r19t==r19['1'] else r19['1']
_pwr('R19',1,('1' if r19t==r19['1'] else '2'),'VCC')
_seg(r19b,(r19b[0],r18l[1]))
_junc(r19b[0],r18l[1]) if False else None
_seg(r18r,(SN(r18r[0]+3.81),r18r[1]))
_lab('/SYNC',SN(r18r[0]+3.81),r18r[1],'R')
_pwrx('9M',1,'1','VSS'); _pwrx('9M',1,'15','VSS')

out += _wires + _labels

out.append(')\n')
txt=''.join(out)
open('cores/mnymny/sch/video1.kicad_sch','w').write(txt)
print("placements:",len(C),"paren balance:",txt.count('(')-txt.count(')'),"bytes:",len(txt))
# sanity: unique refs
import collections
refs=collections.Counter(c[1] for c in C)
print("multi-unit refs:",{k:v for k,v in refs.items() if v>1})
