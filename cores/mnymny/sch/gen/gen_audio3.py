#!/usr/bin/env python3
"""1B11142 AUDIO 3/3 (PDF p13): speech 6802, PIA 1I, TMS5200, MC1408 DAC."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from kisch import Sheet, SN, validate
from hier import ROOT, SHEETS
M = SHEETS['audio3']
sh = Sheet(M['title'])
sh.head = sh.head.replace(sh.head.split('(uuid "')[1].split('"')[0], M['filuuid'])
sh.instpath = f"/{ROOT}/{M['symuuid']}"
S=sh.stub; P=sh.power

# speech 6802
sh.place('mnymny:6802','3L',1, 55,120, value='6802')
for i,pin in enumerate([str(n) for n in list(range(9,21))+list(range(22,26))]): S('3L',1,pin,'AD%d'%i)
for i,pin in enumerate(('33','32','31','30','29','28','27','26')): S('3L',1,pin,'D%d'%i)
for pin,net in (('37','E1'),('34','R/W1'),('5','VMA1'),('4','/INT2'),('2','/HALT2'),('3','MR2'),
                ('6','/NMI2'),('36','/RST_SH1'),('40','RST2'),('39','XTAL1B'),('38','CKu')):
    S('3L',1,pin,net)
# CNA rows used on this page
sh.place('mnymny:CONN50','CNA',1, 140,140, value='CNA')
CNA={'3':'/CS0A','4':'/CS1A'}
for i,pin in enumerate(('6','8','10','12','14','16','18','20')): CNA[pin]='D%d'%i
for i,pin in enumerate(('5','7','9','11','13','15','17','19','23','25','21','26','24','22')): CNA[pin]='AD%d'%i
for pin,net in CNA.items(): S('CNA',1,pin,net)
# PIA 1I
sh.place('mnymny:6821','1I',1, 215,110, value='6821')
for i,pin in enumerate(('33','32','31','30','29','28','27','26')): S('1I',1,pin,'D%d'%i)
for pin,net in (('25','E1'),('21','R/W1'),('23','/CSP'),('34','/RST_SH1'),
                ('36','AD0'),('35','AD1'),('24','AD4'),('22','AD7'),
                ('39','CA2S'),('18','CB1S'),('13','ACSN')):
    S('1I',1,pin,net)
for i in range(8): S('1I',1,str(2+i),'SPA%d'%i)
S('1I',1,'10','/WSPB0'); S('1I',1,'11','/RSPB1')
sh.place('jt74:74LS14','4A',6, 275,60, value='74LS14')
S('4A',6,'13','ACSN'); S('4A',6,'12','ACS')
# TMS5200
sh.place('mnymny:TMS5200','1H',1, 300,120, value='TMS5200')
for pin,net in (('1','SPA0'),('26','SPA1'),('24','SPA2'),('22','SPA3'),
                ('19','SPA4'),('12','SPA5'),('13','SPA6'),('14','SPA7'),
                ('28','/WSPB0'),('27','/RSPB1'),('18','CA2S'),('17','CB1S'),
                ('8','SP'),('4','RC1'),('5','OSC'),('6','RC2')):
    S('1H',1,pin,net)
P('1H',1,'11','VSS',down=True)
# RC oscillator parts
sh.place('Device:R_US','R19',1, 345,120, rot=0, value='100K')
sh.place('Device:C','C24',1, 358,120, rot=0, value='22pF')
sh.place('Device:R_US','R20',1, 345,85, rot=90, value='220')
sh.place('Device:C','C25',1, 332,85, rot=0, value='0.1u')
S('R19',1,'1','RC1'); S('R19',1,'2','RC2'); S('C24',1,'1','RC1'); S('C24',1,'2','RC2')
S('R20',1,'2','RC1')
# read-back latch 2F, comms latch 2G, DAC 1F
sh.place('jt74:74LS374','2F',1, 130,200, value='74LS374')
for i,pin in enumerate(('3','4','7','8','13','14','17','18')): S('2F',1,pin,'DIA%d'%i)
for i,pin in enumerate(('2','5','6','9','12','15','16','19')): S('2F',1,pin,'D%d'%i)
S('2F',1,'11','/CSDIA'); P('2F',1,'1','VSS',down=True)
sh.place('jt74:74LS374','2G',1, 130,245, value='74LS374')
for i,pin in enumerate(('3','4','7','8','13','14','17','18')): S('2G',1,pin,'D%d'%i)
for i,pin in enumerate(('2','5','6','9','12','15','16','19')): S('2G',1,pin,'IOB%d'%i)
S('2G',1,'11','/CSCOM'); P('2G',1,'1','VSS',down=True)
sh.place('mnymny:MC1408','1F',1, 200,215, value='MC1408')
for pin,net in (('12','DIA0'),('11','DIA1'),('10','DIA2'),('9','DIA3'),
                ('8','DIA4'),('7','DIA5'),('6','DIA6'),('5','DIA7')):
    S('1F',1,pin,net)
S('1F',1,'4','DACO'); S('1F',1,'3','-5V'); S('1F',1,'16','COMP1')
# DAC output stage T4 + speech filter opamp 4D
sh.place('Device:R_US','R13',1, 233,210, rot=0, value='3M3')
sh.place('Device:R_US','R14',1, 233,228, rot=90, value='3K3')
sh.place('Device:Q_NPN_BCE','T4',1, 250,228, value='2N4401')
sh.place('mnymny:LM3900','4D',1, 262,180, value='LM3900')
S('4D',1,'3','SPF1'); S('4D',1,'2','SPF2'); S('4D',1,'4','A_SH2')
for rr,x,y,v,rot in (('R62',225,165,'220K',90),('R61',245,165,'820K',90),('R49',255,158,'820K',90),
                     ('R50',238,192,'820K',0),('R11',285,192,'2K2',0),('P2',300,192,'10K',0)):
    sh.place('Device:R_US',rr,1,x,y,rot=rot,value=v)
sh.place('Device:C','C33',1, 235,165, rot=90, value='470p')
sh.place('Device:C','C30',1, 255,150, rot=90, value='47p')
sh.place('Device:C','C8',1, 285,175, rot=90, value='0.1u')
# decode 4E LS139 x2 + 5E LS00 + 6H inverters
sh.place('jt74:74LS139','4E',1, 300,215, value='74LS139')
S('4E',1,'1','VMA1N'); S('4E',1,'2','AD12'); S('4E',1,'3','AD13')
S('4E',1,'4','/SEL0'); S('4E',1,'5','/CS1S'); S('4E',1,'6','/CS2S'); S('4E',1,'7','/SEL3')
sh.place('jt74:74LS139','4E',2, 300,240, value='74LS139')
S('4E',2,'15','/SEL0'); S('4E',2,'14','AD10'); S('4E',2,'13','AD11')
S('4E',2,'12','/SELA'); S('4E',2,'11','/SELB'); S('4E',2,'10','/SELC'); S('4E',2,'9','/SELD')
sh.place('jt74:74LS14','6H',3, 270,215, value='74LS14')
S('6H',3,'5','VMA1'); S('6H',3,'6','VMA1N')
sh.place('jt74:74LS14','6H',4, 270,255, value='74LS14')
S('6H',4,'9','E1'); S('6H',4,'8','E1N')
for u,pins,out in ((1,('1','2'),'/CSDIA'),(2,('4','5'),'/CSP'),(3,('9','10'),'/CSCOM'),(4,('12','13'),'/CSH')):
    sh.place('jt74:74LS00','5E',u, 340,200+15*u, value='74LS00')
    S('5E',u,pins[0],'/SELA' if u==1 else ('/SEL3' if u==2 else ('/SELB' if u==3 else '/SELC')))
    S('5E',u,pins[1],'E1N')
    S('5E',u,('3','6','8','11')[u-1],out)
# handshake buffer 2E LS244 -> CN2
sh.place('jt74:74LS244','2E',1, 340,100, value='74LS244')
for i,(a,b) in enumerate((('2','18'),('4','16'),('6','14'),('8','12'),('11','9'),('13','7'),('15','5'),('17','3'))):
    S('2E',1,a,'HS%d'%i); S('2E',1,b,'D%d'%i)
S('2E',1,'1','/CSH'); S('2E',1,'19','/CSH')
# transistors / misc
sh.place('Device:Q_NPN_BCE','T1',1, 370,60, value='2N3904')
sh.place('Device:Q_PNP_EBC','T2',1, 370,80, value='BC327')
sh.place('Device:Q_PNP_EBC','T3',1, 370,100, value='BC327')
sh.place('Device:Q_NPN_BCE','T5',1, 190,60, value='2N3904')
sh.place('Device:D','LD1',1, 205,55, rot=90, value='LED')
sh.place('Device:R_US','R32',1, 220,60, rot=0, value='470')
sh.place('Device:R_US','R33',1, 175,66, rot=90, value='8K2')
sh.place('Device:R_US','R34',1, 165,55, rot=0, value='3K3')
# CN2 audio edge
sh.place('mnymny:CONN20','CN2',1, 385,190, value='CN2')
for pin,net in (('1','SPK0'),('2','SPK1'),('10','VCC'),('3','+12V'),('5','-5V'),('6','-5V'),
                ('4','+12V'),('12','ACS'),('19','RESSOUND')):
    S('CN2',1,pin,net)
sh.save('cores/mnymny/sch/audio3.kicad_sch')
print(validate('cores/mnymny/sch/audio3.kicad_sch'))
