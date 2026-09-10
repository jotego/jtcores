#!/usr/bin/env python3
"""1B11141 IO 2/3 (PDF p9): 8255, controls, DIP matrix, sound latch, coin counter."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from kisch import Sheet, SN, validate
from hier import ROOT, SHEETS
M = SHEETS['io2']
sh = Sheet(M['title'])
sh.head = sh.head.replace(sh.head.split('(uuid "')[1].split('"')[0], M['filuuid'])
sh.instpath = f"/{ROOT}/{M['symuuid']}"
S=sh.stub; P=sh.power

# 8255 PPI 4H
sh.place('mnymny:8255','4H',1, 95,140, value='8255')
PA=(('4','1J_LEFT'),('3','1J_RIGHT'),('2','1P_SHOOT1'),('1','1P_SHOOT3'),
    ('40','1P_SHOOT2'),('39','1J_UP'),('38','1J_DOWN'),('37','1P_SHOOT4'))
PB=(('18','2J_LEFT'),('19','2J_RIGHT'),('20','2P_SHOOT1'),('21','2P_SHOOT3'),
    ('22','2P_SHOOT2'),('23','2J_UP'),('24','2J_DOWN'),('25','2P_SHOOT4'))
PC=(('14','1PLAYER'),('15','2PLAYER'),('16','SERVICE1'),('17','SERVICE2'),
    ('13','PC4'),('12','PC5'),('11','PC6'),('10','PC7'))
for pin,net in PA+PB+PC: S('4H',1,pin,net)
for i,pin in enumerate(('34','33','32','31','30','29','28','27')): sh.stub_bus('4H',pin,'D%d'%i,128)
sh.bus_close(128,'D[0..7]')
for pin,net in (('9','AB0'),('8','AB1'),('36','/WRB'),('5','/RDB'),('6','/CS8255'),('35','RESET')):
    S('4H',1,pin,net)
# sound latch 2H
sh.place('jt74:74LS374','2H',1, 210,60, value='74LS374')
for i,pin in enumerate(('3','4','7','8','13','14','17','18')): sh.stub_bus('2H',pin,'DBB%d'%i,182)
for i,pin in enumerate(('2','5','6','9','12','15','16','19')): sh.stub_bus('2H',pin,'S%d'%i,238)
sh.bus_close(182,'DBB[0..7]')
sh.bus_close(238,'S[0..7]')
S('2H',1,'11','/WRSOUND'); P('2H',1,'1','VSS',down=True)
# coin GET buffers 3H/2I (top pair)
sh.place('mnymny:40097','3H',1, 200,120, value='40097')
for pin,net in (('2','GET1'),('4','GET2'),('6','GET3'),('15','/RDGETT'),('1','/RDGETT')):
    S('3H',1,pin,net)
for pin,net in (('3','DBB0'),('5','DBB1'),('7','DBB2')): S('3H',1,pin,net)
sh.place('mnymny:40097','2I',1, 200,175, value='40097')
S('2I',1,'2','HSOUND'); S('2I',1,'3','DBB3')
S('2I',1,'15','/RDGETT'); S('2I',1,'1','/RDGETT')
# DIP readback buffers 3H/2I second halves (right pair, /RDSW)
sh.place('mnymny:40097','3H',1, 285,120, value='40097') if False else None
sh.place('mnymny:40097','2J',1, 285,150, value='40097')
for pin,net in (('2','ROW0'),('4','ROW1'),('6','ROW2'),('10','ROW3'),('12','ROW4'),('14','ROW5')):
    S('2J',1,pin,net)
for pin,net in (('3','DBB0'),('5','DBB1'),('7','DBB2'),('9','DBB3'),('11','DBB4'),('13','DBB5')):
    S('2J',1,pin,net)
S('2J',1,'15','/RDSW'); S('2J',1,'1','/RDSW')
# DIP banks + diode matrix (see PROGRESS: diodes drawn as note)
for ref,x,rows in (('5I',285,('D20','D21','D22','D23','D24','D25','D26','D27')),
                   ('4I',285,None),('3I',285,None)):
    pass
sh.place('mnymny:DIPSW8','5I',1, 300,60, value='SW 5I')
sh.place('mnymny:DIPSW8','4I',1, 300,110, value='SW 4I')
sh.place('mnymny:DIPSW8','3I',1, 300,160, value='SW 3I')
for ref in ('5I','4I','3I'):
    for i in range(8):
        S(ref,1,str(i+1),'PC4' if ref=='5I' else ('PC5' if ref=='4I' else 'PC6'))
        S(ref,1,str(16-i),'COL%d'%i)
# coin counter driver
sh.place('Device:Q_NPN_BCE','Q3',1, 150,240, value='BC548')
sh.place('Device:Q_NPN_BCE','Q4',1, 180,240, value='BC337')
sh.place('Device:D','D3',1, 205,235, rot=90, value='1N4004')
sh.place('Device:R_US','R17',1, 120,240, rot=90, value='4K7')
sh.place('Device:R_US','R18',1, 150,258, rot=90, value='10K')
sh.place('Device:R_US','R19',1, 180,258, rot=90, value='1K')
S('R17',1,'2','COUNT')
S('D3',1,'1','CN2_A13'); S('D3',1,'2','CN2_A15')
# CN2 edge connector
sh.place('mnymny:CONN_AB22','CN2',1, 365,140, value='CN2 (cabinet edge)')
CNA={'A8':'1J_RIGHT','A7':'1P_SHOOT1','A12':'1P_SHOOT3','A6':'1P_SHOOT2','A9':'1J_UP',
     'A11':'1J_DOWN','A4':'2J_LEFT','A3':'2P_SHOOT1','A10':'2P_SHOOT3','A5':'1PLAYER',
     'A14':'GET2','A16':'VCC','A17':'VCC','A18':'VCC','A19':'-5V','A20':'-5V',
     'A21':'SPK0','A22':'SPK1','A1':'G','A2':'/SYNC','A13':'CN2_A13','A15':'CN2_A15'}
CNB={'B8':'1J_LEFT','B12':'1P_SHOOT4','B4':'2J_RIGHT','B3':'2P_SHOOT2','B6':'2J_UP',
     'B9':'2J_DOWN','B11':'2P_SHOOT4','B5':'2PLAYER','B7':'SERVICE1','B10':'SERVICE2',
     'B13':'GET1','B14':'GET3','B21':'+12V','B22':'+12V','B2':'R','B1':'B'}
for pin,net in CNA.items(): S('CN2',1,pin,net)
for pin,net in CNB.items(): S('CN2',1,pin,net)
for pin in ('B15','B16','B17','B18'): P('CN2',1,pin,'VSS',down=True)
sh.save('cores/mnymny/sch/io2.kicad_sch')
print(validate('cores/mnymny/sch/io2.kicad_sch'))
