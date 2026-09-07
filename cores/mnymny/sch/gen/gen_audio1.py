#!/usr/bin/env python3
"""1B11142 AUDIO 1/3 (PDF p11): melody 6802, PIA 4I, 2x AY-3-8910."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from kisch import Sheet, SN, validate
from hier import ROOT, SHEETS
M = SHEETS['audio1']
sh = Sheet(M['title'])
sh.head = sh.head.replace(sh.head.split('(uuid "')[1].split('"')[0], M['filuuid'])
sh.instpath = f"/{ROOT}/{M['symuuid']}"
S=sh.stub; P=sh.power

# 6802 melody CPU 4L
sh.place('mnymny:6802','4L',1, 60,120, value='6802')
for i,pin in enumerate([str(n) for n in list(range(9,21))+list(range(22,26))]): S('4L',1,pin,'A%d'%i)
for i,pin in enumerate(('33','32','31','30','29','28','27','26')): S('4L',1,pin,'DB%d'%i)
for pin,net in (('37','E'),('34','R/W'),('5','VMA'),('4','/IRQB'),('2','/HALT'),('3','MR'),
                ('6','/NMI'),('36','DBE'),('40','/RST'),('39','XTAL1'),('38','EXTAL1'),('35','VCC_ST')):
    S('4L',1,pin,net)
# CNA connector (to ROM module CN3)
sh.place('mnymny:CONN50','CNA',1, 160,140, value='CNA')
CNA={}
for i,pin in enumerate(('27','29','31','33','35','37','39','41')): CNA[pin]='DB%d'%i
for i,pin in enumerate(('28','30','32','34','36','38','40','43','48','46','44','42','47','45')): CNA[pin]='A%d'%i
CNA.update({'50':'/CS4A','49':'/CS5A'})
for pin,net in CNA.items(): S('CNA',1,pin,net)
# decode 6I LS156 + 6H LS14 inverters
sh.place('jt74:74LS156','6I',1, 215,90, value='74LS156')
for pin,net in (('13','A13'),('3','A14'),('15','A15N'),('2','VMA'),('14','VMA')):
    S('6I',1,pin,net)
for pin,net in (('7','/CS2'),('9','/CS4A'),('12','/CS5A'),('5','/CS1A'),('4','/CS0A')):
    S('6I',1,pin,net)
sh.place('jt74:74LS14','6H',1, 195,60, value='74LS14')
S('6H',1,'1','A15'); S('6H',1,'2','A15N')
sh.place('jt74:74LS14','6H',2, 195,75, value='74LS14')
S('6H',2,'3','A12'); S('6H',2,'4','A12N')
# 4040 divider + 4F LS74 -> CKGI / CB1
sh.place('mnymny:4040','5F',1, 200,180, value='4040')
S('5F',1,'10','CKu'); S('5F',1,'11','MR40'); S('5F',1,'9','CKGI'); S('5F',1,'1','Q12')
sh.place('jt74:74LS74','4F',1, 245,180, value='74LS74')
S('4F',1,'3','Q12'); S('4F',1,'2','CB1N'); S('4F',1,'5','CB1'); S('4F',1,'6','CB1N')
# 3.58MHz oscillator (74S04 6L x3 + QZ1)
sh.place('jt74:74LS04','6L',1, 60,240, value='74S04')
S('6L',1,'1','XTAL1'); S('6L',1,'2','OSC1')
sh.place('jt74:74LS04','6L',2, 85,240, value='74S04')
S('6L',2,'3','OSC1'); S('6L',2,'4','OSC2')
sh.place('jt74:74LS04','6L',3, 110,240, value='74S04')
S('6L',3,'5','OSC2'); S('6L',3,'6','CKu')
sh.place('mnymny:Crystal','QZ1',1, 72,255, value='3.580MHz')
S('QZ1',1,'1','XTAL1'); S('QZ1',1,'2','OSC1')
sh.place('Device:R_US','R138',1, 72,228, rot=90, value='470')
S('R138',1,'2','XTAL1'); S('R138',1,'1','OSC1')
sh.place('Device:R_US','R137',1, 97,228, rot=90, value='470')
S('R137',1,'2','OSC1'); S('R137',1,'1','OSC2')
sh.place('Device:C','C68',1, 122,255, rot=90, value='1000p')
S('C68',1,'1','OSC2'); S('C68',1,'2','CKu')
# reset network -> RESSOUND
sh.place('Device:R_US','R136',1, 145,235, rot=0, value='27K')
sh.place('Device:D','D2',1, 158,235, rot=0, value='1N4148')
sh.place('Device:C','C64',1, 145,255, rot=0, value='4.7u')
sh.place('Device:Q_NPN_BCE','T8',1, 170,248, value='BC548')
sh.place('Device:R_US','R135',1, 190,240, rot=90, value='4K7')
sh.place('Device:R_US','R134',1, 190,252, rot=90, value='100K')
S('R135',1,'2','RESSOUND')
S('R136',1,'1','RST_N'); S('D2',1,'1','RST_N')
# pullup pack
sh.place('Device:R_US','R37',1, 120,90, rot=90, value='3K3')
sh.place('Device:R_US','R35',1, 120,97, rot=90, value='3K3')
sh.place('Device:R_US','R36',1, 120,104, rot=90, value='3K3')
sh.place('Device:R_US','R38',1, 120,111, rot=90, value='3K3')
for rr,net in (('R37','/IRQB'),('R35','/HALT'),('R36','MR'),('R38','/NMI')):
    S(rr,1,'2',net); P(rr,1,'1','VCC')
# PIA 6821 4I
sh.place('mnymny:6821','4I',1, 250,120, value='6821')
for i,pin in enumerate(('33','32','31','30','29','28','27','26')): S('4I',1,pin,'DB%d'%i)
for pin,net in (('34','/RST'),('21','R/W'),('25','E'),('23','/CS2'),('24','A2'),('22','A3'),
                ('36','A0'),('35','A1'),('18','CB1'),('38','/IRQA'),('37','/IRQB'),('40','CA1')):
    S('4I',1,pin,net)
for i in range(8): S('4I',1,str(2+i),'PA%d'%i)
for pin,net in (('10','PB0'),('11','PB1'),('12','PB2'),('13','PB3')):
    S('4I',1,pin,net)
# AY-3-8910 4H (effects) & 4G (melody)
for ref,x,extra in (('4H',330,(('21','LEVEL'),('20','LEVELT'),('13','SW1'),
                               ('4','ANAL4'),('3','ANAL5'),('38','ANAL6'),
                               ('29','PB2'),('27','PB3'))),
                    ('4G',330,(('21','IOA0'),('20','IOA1'),('19','IOA2'),('18','IOA3'),('17','IOA4'),
                               ('13','IOB0'),('12','IOB1'),('11','IOB2'),('10','IOB3'),('9','IOB4'),
                               ('8','IOB5'),('7','IOB6'),('6','IOB7'),
                               ('4','ANAL1'),('3','ANAL2'),('38','ANAL3'),
                               ('29','PB0'),('27','PB1')))):
    y = 70 if ref=='4H' else 190
    sh.place('arcade:AY-3-8910',ref,1,x,y, value='AY-3-8910')
    for i,pin in enumerate(('37','36','35','34','33','32','31','30')): S(ref,1,pin,'PA%d'%i)
    S(ref,1,'22','CKGI'); S(ref,1,'23','/RST')
    for pin,net in extra: S(ref,1,pin,net)
sh.save('cores/mnymny/sch/audio1.kicad_sch')
print(validate('cores/mnymny/sch/audio1.kicad_sch'))
