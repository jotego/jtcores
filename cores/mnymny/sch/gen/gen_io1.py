#!/usr/bin/env python3
"""1B11141 IO 1/3 (PDF p8): Z80, ROM, RAM+NVRAM, decode, LS259 mainlatch, reset/watchdog."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from kisch import Sheet, SN, validate
from hier import ROOT, SHEETS
M = SHEETS['io1']
sh = Sheet(M['title'])
sh.head = sh.head.replace(sh.head.split('(uuid "')[1].split('"')[0], M['filuuid'])
sh.instpath = f"/{ROOT}/{M['symuuid']}"
S=sh.stub; P=sh.power

# --- Z80 4A ---
sh.place('jt_cpu:Z80','4A',1, 70,110, value='Z80')
zp = sh.pins('4A',1)
# label everything by pin name convention of jt_cpu Z80: address/data/ctrl
ZNETS={'27':'/M1','19':'/MREQ','28':'/RFSH','24':'/WAIT','17':'/NMI','16':'/INT',
       '18':'/HALT','26':'/RESET','6':'1Hu','21':'/RD','22':'/WR','25':'/BUSRQ','23':'/BUSAK'}
for pin,net in ZNETS.items():
    if pin in zp: S('4A',1,pin,net,'L')
for i,pin in enumerate(('30','31','32','33','34','35','36','37','38','39','40','1','2','3','4','5')):
    if pin in zp: S('4A',1,pin,'A%d'%i,'R')
for i,pin in enumerate(('14','15','12','8','7','9','10','13')):
    if pin in zp: S('4A',1,pin,'D%d'%i,'R')
P('4A',1,'11','VCC'); P('4A',1,'29','VSS',down=True)

# --- address buffers 4B/3B LS244 -> ABx ---
for ref,x,ins in (('4B',150,[('2','A0','18','AB0'),('4','A1','16','AB1'),('6','A2','14','AB2'),('8','A3','12','AB3'),
                             ('11','A4','9','AB4'),('13','A5','7','AB5'),('15','A6','5','AB6'),('17','A7','3','AB7')]),
                  ('3B',150,None)):
    pass
sh.place('jt74:74LS244','4B',1, 160,70, value='74LS244')
sh.place('jt74:74LS244','3B',1, 160,130, value='74LS244')
B244=[('2','18'),('4','16'),('6','14'),('8','12'),('11','9'),('13','7'),('15','5'),('17','3')]
for i,(a,b) in enumerate(B244):
    S('4B',1,a,'A%d'%i,'L'); S('4B',1,b,'AB%d'%i,'R')
for i,(a,b) in enumerate(B244):
    nm=('A%d'%(i+8)) if i<6 else ('A%d'%(i+8))
    S('3B',1,a,nm,'L'); S('3B',1,b,'AB%d'%(i+8) if i<6 else 'AB%d'%(i+8),'R')
for ref in ('4B','3B'):
    P(ref,1,'1','VSS',down=True); P(ref,1,'19','VSS',down=True)

# --- data buffer 2G LS245 -> DBB ---
sh.place('jt74:74LS245','2G',1, 160,190, value='74LS245')
for i,(a,b) in enumerate((('2','18'),('3','17'),('4','16'),('5','15'),('6','14'),('7','13'),('8','12'),('9','11'))):
    S('2G',1,a,'D%d'%i,'L'); S('2G',1,b,'DBB%d'%i,'R')
S('2G',1,'1','/RDB','L'); S('2G',1,'19','/CSBB','L')

# --- decode 3C LS138 (CS1..CS6), 4C LS139, 4D LS155 ---
sh.place('jt74:74LS138','3C',1, 60,200, value='74LS138')
for pin,net in (('1','AB12'),('2','AB13'),('3','A14'),('4','/MREQ'),('5','/RFSH'),('6','VCCEN')):
    S('3C',1,pin,net,'L')
for pin,net in (('15','/CS1'),('14','/CS2'),('13','/CS3'),('12','/CS4'),('11','/CS5'),('10','/CS6'),('9','/CSBB'),('7','/CS7')):
    S('3C',1,pin,net,'R')
sh.place('jt74:74LS139','4C',1, 60,232, value='74LS139')
for pin,net in (('2','AB10'),('3','AB11'),('1','/CS7')):
    S('4C',1,pin,net,'L')
for pin,net in (('4','/CSURAM1'),('5','/CSURAM2'),('6','/CS8255'),('7','/AFR')):
    S('4C',1,pin,net,'R')
sh.place('jt74:74LS139','4C',2, 60,252, value='74LS139')
for pin,net in (('14','AB10'),('13','AB11'),('15','/SAB')):
    S('4C',2,pin,net,'L')
for pin,net in (('12','/AFR2'),('11','/SABOB3'),('10','/SABBKG2'),('9','/CSRAMNV')):
    S('4C',2,pin,net,'R')
sh.place('jt74:74LS155','4D',1, 130,238, value='74LS155')
for pin,net in (('13','AB10'),('3','AB11'),('2','/RDB'),('14','/WRB'),('1','/GA'),('15','/GB')):
    S('4D',1,pin,net,'L')
for pin,net in (('9','/WRBKGL'),('10','/WRBKGH'),('11','/WROBJ'),('7','/RDBKGL'),('6','/RDBKGH'),('5','/RDOBJ')):
    S('4D',1,pin,net,'R')

# --- strobe ORs 4F LS32 x4, 1C 74HC32 x2, 5D LS10 gates, 5C LS02 ---
sh.place('jt74:74LS32','4F',1, 195,215, value='74LS32')
S('4F',1,'1','/WRB','L'); S('4F',1,'2','/CS8255','L'); S('4F',1,'3','/WRMIX','R')
sh.place('jt74:74LS32','4F',2, 195,230, value='74LS32')
S('4F',2,'4','/WRB','L');  S('4F',2,'5','/AFR','L');   S('4F',2,'6','/WRSOUND','R')
sh.place('jt74:74LS32','4F',3, 195,245, value='74LS32')
S('4F',3,'10','/RDB','L'); S('4F',3,'9','/AFR','L');   S('4F',3,'8','/RDGETT','R')
sh.place('jt74:74LS32','4F',4, 195,260, value='74LS32')
S('4F',4,'12','/RDB','L'); S('4F',4,'13','AB9','L');   S('4F',4,'11','/RDSW','R')
sh.place('jt74:74LS32','1C',4, 230,120, value='74HC32')
S('1C',4,'13','/CSURAM2','L'); S('1C',4,'12','A','L'); S('1C',4,'11','WD1','R')
sh.place('jt74:74LS32','1C',3, 255,120, value='74HC32')
S('1C',3,'10','WD1','L'); S('1C',3,'9','/WD','L'); S('1C',3,'8','B','R')
sh.place('jt74:74LS02','5C',1, 40,35, value='74LS02')
S('5C',1,'2','HBLANK','L'); S('5C',1,'3','/SABBKG','L'); S('5C',1,'1','SABBKG_G','R')
sh.place('jt74:74LS10','5D',1, 128,210, value='74LS10')
S('5D',1,'1','WREN1','L'); S('5D',1,'2','WREN2','L'); S('5D',1,'13','WRENC','L'); S('5D',1,'12','/WREN','R')

# --- LS259 mainlatch 3G ---
sh.place('jt74:74LS259','3G',1, 255,235, value='74LS259')
for pin,net in (('13','DBB0'),('1','AB0'),('2','AB1'),('3','AB2'),('14','/WRMIX'),('15','/RESET')):
    S('3G',1,pin,net,'L')
for pin,net in (('4','VCMA0'),('5','HCMA'),('6','RESSOUND'),('7','Q3'),('9','Q4'),('10','Q5'),('11','COUNT'),('12','/INTST')):
    S('3G',1,pin,net,'R')

# --- ROMs 1A/1B, RAM 2A/2B, NVRAM 2C/2D ---
for ref,x,val in (('1A',295,'2732/2764'),('1B',350,'2764')):
    sh.place('mnymny:2764',ref,1,x,70,value=val)
    amap={'10':'AB0','9':'AB1','8':'AB2','7':'AB3','6':'AB4','5':'AB5','4':'AB6','3':'AB7',
          '25':'AB8','24':'AB9','21':'AB10','23':'AB11','2':'A15'}
    for pin,net in amap.items(): S(ref,1,pin,net,'L')
    for i,pin in enumerate(('11','12','13','15','16','17','18','19')): S(ref,1,pin,'D%d'%i,'R')
    S(ref,1,'20','/CE_'+ref,'L'); S(ref,1,'22','/OE_'+ref,'L')
    P(ref,1,'28','VCC'); P(ref,1,'27','VCC'); P(ref,1,'1','VCC'); P(ref,1,'14','VSS',down=True)
RAMP={'5':'AB0','6':'AB1','7':'AB2','4':'AB3','3':'AB4','2':'AB5','1':'AB6','17':'AB7','16':'AB8','15':'AB9'}
for ref,x,val,dn in (('2A',268,'2114',('D0','D1','D2','D3')),('2B',296,'2114',('D4','D5','D6','D7')),
                     ('2C',326,'2114/6514',('D0','D1','D2','D3')),('2D',354,'2114/6514',('D4','D5','D6','D7'))):
    sh.place('arcade:MN2114',ref,1,x,180,value=val)
    for pin,net in RAMP.items(): S(ref,1,pin,net,'L')
    for pin,net in zip(('14','13','12','11'),dn): S(ref,1,pin,net,'R')
    cs='/CSURAM1' if ref in ('2A','2B') else '/CSRAMNV'
    S(ref,1,'8',cs,'L'); S(ref,1,'10','/WD_W','L')
# --- reset / watchdog analog corner ---
sh.place('mnymny:TL7705','1D',1, 45,248, value='TL7705')
S('1D',1,'2','VCC_SENSE','L'); S('1D',1,'5','/RESET','R'); S('1D',1,'6','RESET','R')
sh.place('Device:Q_NPN_BCE','Q1',1, 92,255, value='BC548')
sh.place('Device:Q_NPN_BCE','Q2',1, 110,255, value='BC327')
sh.place('Device:D','D1',1, 128,250, rot=90, value='1N4148')
sh.place('Device:D','D2',1, 128,258, rot=90, value='1N4148')
sh.place('Device:D','D28',1, 250,40, rot=90, value='1N4148')
sh.place('Device:Battery_Cell','BT1',1, 265,60, value='3.6V')
S('BT1',1,'1','VBAT','R'); P('BT1',1,'2','VSS',down=True)
S('D28',1,'1','VCC_D','L'); S('D28',1,'2','VBAT','R')
sh.place('Device:R_Network08_US','R12',1, 200,40, value='8x27K')
# --- CN4 ---
sh.place('mnymny:CONN50','CN4',1, 390,145, value='CN4 (ROM module)')
CN4={}
for i,pin in enumerate(('21','22','23','24','25','26','27','28')): CN4[pin]='D%d'%i
for i,pin in enumerate(('11','14','13','16','15','18','17','20','32','31','29','33')): CN4[pin]='AB%d'%i
CN4.update({'3':'AB12','4':'AB13','1':'A14','19':'A15','2':'/RDB','6':'/WRB','8':'/RFSH',
            '30':'/CS2','35':'/CS3','43':'/CS4','34':'/CS5','36':'/CS6',
            '7':'DBB3','10':'DBB4','12':'DBB5','9':'DBB6','5':'DBB7'})
for pin,net in CN4.items(): S('CN4',1,pin,net,'L')
for pin in ('37','39','41','42','44','45','46','47','48','49','50'):
    P('CN4',1,pin,'VSS',down=True)
P('CN4',1,'38','VCC'); P('CN4',1,'40','VCC')

sh.save('cores/mnymny/sch/io1.kicad_sch')
print(validate('cores/mnymny/sch/io1.kicad_sch'))
