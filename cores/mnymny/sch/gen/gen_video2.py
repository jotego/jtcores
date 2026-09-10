#!/usr/bin/env python3
"""1B11140 VIDEO 2/5 (PDF p4): background pipeline."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from kisch import Sheet, SN, validate
from hier import ROOT, SHEETS
M = SHEETS['video2']
sh = Sheet(M['title'])
sh.head = sh.head.replace(sh.head.split('(uuid "')[1].split('"')[0], M['filuuid'])
sh.instpath = f"/{ROOT}/{M['symuuid']}"
S=sh.stub; P=sh.power

# sigma adders + row latch + handshake
sh.place('jt74:74LS283','1G',1, 40,180, value='74LS283')
for pin,net in (('5','SV1i'),('3','SV2i'),('14','SV3i'),('12','SV4i'),
                ('6','1VP'),('2','2VP'),('15','4VP'),('11','8VP'),
                ('4','HPLA0'),('1','HPLA1'),('13','HPLA2'),('10','HPLA3')):
    S('1G',1,pin,net)
sh.place('jt74:74LS283','1H',1, 40,230, value='74LS283')
for pin,net in (('5','SV5i'),('3','SV6i'),('14','SV7i'),('12','SV8i'),
                ('6','16VP'),('2','32VP'),('15','64VP'),('11','128VP'),
                ('4','HPLA4'),('1','HPLA5'),('13','HPLA6'),('10','HPLA7')):
    S('1H',1,pin,net)
sh.place('jt74:74LS374','1F',1, 45,120, value='74LS374')
for i,pin in enumerate(('3','4','7','8','13','14','17','18')): S('1F',1,pin,'SV%di'%(i+1))
for i,pin in enumerate(('2','5','6','9','12','15','16','19')): S('1F',1,pin,'SV%d'%(i+1))
S('1F',1,'11','/VPL'); P('1F',1,'1','VSS',down=True)
sh.place('jt74:74LS175','2G',1, 45,45, value='74LS175')
for pin,net in (('4','SV1'),('5','SV2'),('12','SV3'),('13','SV4'),('9','CKOK1')):
    S('2G',1,pin,net)
sh.place('jt74:74LS175','2F',1, 90,45, value='74LS175')
for pin,net in (('4','SV5'),('5','SV6'),('12','SV7'),('13','SV8'),('9','CKOK2')):
    S('2F',1,pin,net)
sh.place('jt74:74LS20','2H',2, 40,85, value='74LS20')
for pin,net in (('12','SV8'),('13','SV7'),('10','SV6'),('9','SV5'),('8','/DOKVER')):
    S('2H',2,pin,net)
sh.place('jt74:74LS86','2E',1, 95,85, value='74LS86')
S('2E',1,'1','CKOK1'); S('2E',1,'2','CKOK2'); S('2E',1,'3','/CKOKVER')
# address muxes into tile RAM
sh.place('jt74:74LS157','1E',1, 110,140, value='74LS157')
for pin,net in (('14','128HP'),('11','AB7'),('2','AB6'),('5','AB5'),('3','AB4'),('1','/SABBKG')):
    S('1E',1,pin,net)
for pin,net in (('9','A6t'),('12','A5t'),('7','A4t'),('4','A3t')): S('1E',1,pin,net)
sh.place('jt74:74LS157','1D',1, 110,190, value='74LS157')
for pin,net in (('14','/VRHB'),('11','/VRLB'),('2','AB3'),('5','AB8'),('1','/SABBKG')):
    S('1D',1,pin,net)
for pin,net in (('9','A7t'),('4','A8t')): S('1D',1,pin,net)
sh.place('jt74:74LS157','1C',1, 110,240, value='74LS157')
for pin,net in (('14','AB3'),('11','AB2'),('5','AB1'),('2','AB0'),
                ('10','64HP'),('13','32HP'),('6','16HP'),('3','8HP'),('1','/SABBKG')):
    S('1C',1,pin,net)
for pin,net in (('9','A0t'),('12','A1t'),('7','A2t'),('4','A9t')): S('1C',1,pin,net)
# tile RAM
RAMA={'5':'A0t','6':'A1t','7':'A2t','4':'A3t','3':'A4t','2':'A5t','1':'A6t','17':'A7t','16':'A8t','15':'A9t'}
for ref,x,dn,wr in (('2A',165,('A6d','A5d','A4d','A3d'),'/VRHB'),
                    ('2B',165,('S11','S10','S9','S8'),'/VRHB'),
                    ('2C',165,('S7','S6','S5','S4'),'/VRLB')):
    y = {'2A':100,'2B':170,'2C':240}[ref]
    sh.place('arcade:MN2114',ref,1,x,y, value='2114')
    for pin,net in RAMA.items(): S(ref,1,pin,net)
    for pin,net in zip(('14','13','12','11'),dn): S(ref,1,pin,net)
    S(ref,1,'8','/SABBKG'); S(ref,1,'10',wr)
# PAP latch, HPLA latch, sigma->AF muxes
sh.place('jt74:74LS175','4H',1, 185,45, value='74LS175')
for pin,net in (('13','PAP0'),('12','PAP1'),('4','PAP3'),('5','PAP2'),('9','/LPFMSW')):
    S('4H',1,pin,net)
sh.place('jt74:74LS374','2J',1, 190,90, value='74LS374')
for i,pin in enumerate(('3','4','7','8','13','14','17','18')): S('2J',1,pin,'HPLA%d'%i)
S('2J',1,'11','HHH'); P('2J',1,'1','VSS',down=True)
sh.place('jt74:74LS157','2D',1, 150,60, value='74LS157')
for pin,net in (('9','S3'),('12','S2'),('7','S1'),('4','S0'),('1','MPX')): S('2D',1,pin,net)
for ref,y,outs in (('3C',40,(('7','AF12'),('4','AF11'))),
                   ('3B',95,(('9','AF10'),('12','AF9'),('7','AF8'),('4','AF7'))),
                   ('3A',150,(('9','AF6'),('12','AF5'),('7','AF4'),('4','AF3')))):
    sh.place('jt74:74LS157',ref,1, 235,y, value='74LS157')
    S(ref,1,'1','MPX')
    for pin,net in outs: S(ref,1,pin,net)
    for pin,net in (('5','S13' if ref=='3C' else ('S11' if ref=='3B' else 'S7')),
                    ('2','S12' if ref=='3C' else ('S10' if ref=='3B' else 'S6'))):
        S(ref,1,pin,net)
sh.place('jt74:74LS04','3G',6, 205,140, value='74LS04')
S('3G',6,'13','4H'); S('3G',6,'12','4HN')
sh.place('jt74:74LS32','3H',4, 230,140, value='74LS32')
S('3H',4,'13','256H'); S('3H',4,'12','4HN'); S('3H',4,'11','MPX')
sh.place('jt74:74LS86','4M',4, 235,190, value='74LS86')
S('4M',4,'12','HHH'); S('4M',4,'13','8H'); S('4M',4,'11','HHX')
# readback buffers
sh.place('jt74:74LS244','1A',1, 250,225, value='74LS244')
for pin,net in (('2','BKB2'),('4','BKB1'),('6','S13'),('8','S12'),
                ('18','DBB3'),('16','DBB2'),('14','DBB1'),('12','DBB0'),
                ('1','/RDBKGH'),('19','/RDBKGH')):
    S('1A',1,pin,net)
sh.place('jt74:74LS245','1B',1, 250,265, value='74LS245')
for i,(a,b) in enumerate((('2','18'),('3','17'),('4','16'),('5','15'),('6','14'),('7','13'),('8','12'),('9','11'))):
    S('1B',1,a,'S%d'%(11-i) if i<8 else ''); S('1B',1,b,'DBB%d'%(7-i))
S('1B',1,'1','R/WB'); S('1B',1,'19','/CSBB2')
sh.place('jt74:74LS08','3F',4, 60,275, value='74LS08')
S('3F',4,'12','/WRBKGH'); S('3F',4,'13','/RDBKGH'); S('3F',4,'11','/VRHB')
sh.place('jt74:74LS08','3F',1, 100,275, value='74LS08')
S('3F',1,'1','/WRBKGL'); S('3F',1,'2','/RDBKGL'); S('3F',1,'3','/VRLB')
# bg ROM sockets (option B3/B2/B1 shown on ROM module page too)
for ref,x in (('4A',290,),('4C',322,),('4E',354,)):
    sh.place('mnymny:2764',ref,1,x,55, value='2732/2764')
    for pin,net in (('2','AF12'),('23','AF11'),('21','AF10'),('24','AF9'),('25','AF8'),
                    ('3','AF7'),('4','AF6'),('5','AF5'),('6','AF4'),('7','AF3'),
                    ('8','S2'),('9','S1'),('10','S0')):
        S(ref,1,pin,net)
    base={'4A':16,'4C':8,'4E':0}[ref]
    for i,pin in enumerate(('11','12','13','15','16','17','18','19')):
        sh.stub_bus(ref,pin,'D%d'%(base+i),x+24)
    sh.bus_close(x+24,None,ybot=96)
    P(ref,1,'14','VSS',down=True); P(ref,1,'28','VCC'); P(ref,1,'27','VCC'); P(ref,1,'1','VCC')
    S(ref,1,'20','/OEF'); S(ref,1,'22','/OEF')
sh.bus_seg((290+24,96),(354+24,96))
sh.buslabel('D[0..23]',290+24+2,96,0)
# 12x LS194 shifter grid
GRID=[(('3D','X1L'),('3E','X1R'),('4F','X4L'),('4G','X4R'),0),
      (('5A','X2L'),('5B','X2R'),('5C','X5L'),('5D','X5R'),8),
      (('6A','X3L'),('6B','X3R'),('6C','X6L'),('6D','X6R'),16)]
for row,(c0,c1,c2,c3,dbase) in enumerate(GRID):
    for col,(ref,xout) in enumerate((c0,c1,c2,c3)):
        x=270+col*32; y=140+row*45
        sh.place('jt74:74LS194',ref,1,x,y, value='74LS194')
        half = dbase + (4 if col%2==0 else 0)
        for i,pin in enumerate(('3','4','5','6')):
            sh.stub_bus(ref,pin,'D%d'%(half+3-i),x-16)
        sh.bus_close(x-16,None)
        S(ref,1,'9','S0T1' if col<2 else 'S0T2')
        S(ref,1,'10','S1T1' if col<2 else 'S1T2')
        S(ref,1,'11','6MHz')
        S(ref,1,'12',xout)
        P(ref,1,'1','VCC')
# CN2
sh.place('mnymny:CONN40','CN2',1, 390,150, value='CN2 (ROM module)')
CN2={'6':'AF12','11':'AF11','16':'AF10','9':'AF9','7':'AF8','5':'AF7','8':'AF6',
     '10':'AF5','12':'AF4','13':'AF3','14':'S2','15':'S1','18':'S0'}
for pin,net in CN2.items():
    S('CN2',1,pin,net)
for i,pin in enumerate(('24','27','3','20','4','22','2','1','33','32','35','29','31','26','28','30','17','19','21','23','25','37','39','40')):
    S('CN2',1,pin,'D%d'%i)
for pin in ('34','36','38'): P('CN2',1,pin,'VSS',down=True)
sh.save('cores/mnymny/sch/video2.kicad_sch')
print(validate('cores/mnymny/sch/video2.kicad_sch'))
