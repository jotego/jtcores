#!/usr/bin/env python3
"""1B11140 VIDEO 4/5 (PDF p6): control-logic customs, object RAM, collision."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from kisch import Sheet, SN, validate
from hier import ROOT, SHEETS
M = SHEETS['video4']
sh = Sheet(M['title'])
sh.head = sh.head.replace(sh.head.split('(uuid "')[1].split('"')[0], M['filuuid'])
sh.instpath = f"/{ROOT}/{M['symuuid']}"
SX=sh.stubx; PX=sh.powerx

# X result muxes
for ref,y,ins,outs in (('5E',50,(('2','X1R'),('5','X2R'),('14','X3R'),('3','X1L'),('6','X2L'),('13','X3L')),
                        (('4','X1'),('7','X2'),('12','X3'))),
                       ('6E',95,(('2','X4R'),('5','X5R'),('14','X6R'),('3','X4L'),('6','X5L'),('13','X6L')),
                        (('4','X4'),('7','X5'),('12','X6')))):
    sh.place('jt74:74LS157',ref,1, 45,y, value='74LS157')
    for pin,net in ins: SX(ref,pin,net)
    for pin,net in outs: SX(ref,pin,net)
    SX(ref,'1','HCMP21' if ref=='5E' else 'HCMP22')
# ABT flop
sh.place('jt74:74LS74','6P',1, 100,55, value='74LS74')
SX('6P','2','1H'); SX('6P','3','6MHz'); SX('6P','5','/ABT'); PX('6P','4','VCC'); PX('6P','1','VCC')
# control logic customs
sh.place('mnymny:CTRL6J','6J',1, 190,55, value='CONTROL LOGIC 1')
for pin,net in (('2','1H'),('3','2H'),('4','4H'),('5','/ABLOAD'),('6','256Hx'),('7','SELECT'),
                ('8','8H'),('9','/256H'),('11','256H*'),
                ('19','/YA'),('18','/YB'),('17','/CNTLDT1'),('16','/CNTLDT2'),
                ('15','/CNTLD'),('14','/CNTCLR'),('13','BIT80P'),('12','LDCOL3H')):
    SX('6J',pin,net)
sh.place('jt74:74LS14','6HA',1, 235,80, value='74LS14')
SX('6HA','1','BIT80P'); SX('6HA','2','BIT80')
sh.place('mnymny:CTRL6K','6K',1, 300,55, value='CONTROL LOGIC 2')
for pin,net in (('11','/X456'),('8','/X123'),('2','1H'),('3','2H'),('4','4H'),('5','8H'),
                ('6','/256H'),('7','/ABT'),('1','/256H*'),('9','SELECT'),
                ('19','/COLL1'),('18','/VPL'),('16','/OBDLOUT'),('15','CKOKVER'),
                ('14','LPREPFP'),('13','/LPFMSW')):
    SX('6K',pin,net)
sh.place('jt74:74LS14','6HB',2, 345,80, value='74LS14')
SX('6HB','3','LPREPFP'); SX('6HB','4','LPREPF')
# SELECT / 256Hx / ABLOAD flops
sh.place('jt74:74LS74','6N',1, 165,105, value='74LS74')
SX('6N','2','/LD2'); SX('6N','3','/256H'); SX('6N','5','SEL1')
sh.place('jt74:74LS74','6N',2, 195,105, value='74LS74')
SX('6N','12','SEL1'); SX('6N','11','SEL1'); SX('6N','8','SELECT'); SX('6N','13','256Hx')
sh.place('jt74:74LS00','6LA',1, 165,130, value='74LS00')
SX('6LA','3','16V'); SX('6LA','2','VBLANK'); SX('6LA','1','SEL0')
sh.place('jt74:74LS74','6M',2, 250,110, value='74LS74')
SX('6M','12','/DOKVER'); SX('6M','11','/CKOKVER'); SX('6M','9','RWTP')
sh.place('jt74:74LS74','6M',1, 355,150, value='74LS74')
SX('6M','2','CNTLDD'); SX('6M','3','6MHz'); SX('6M','5','/ABLOAD')
sh.place('jt74:74LS14','6HC',3, 330,165, value='74LS14')
SX('6HC','5','/CNTLD'); SX('6HC','6','CNTLDD')
# R/WT gates
sh.place('jt74:74LS04','5KA',5, 300,115, value='74LS04')
SX('5KA','11','RWTP'); SX('5KA','10','RWTN')
sh.place('jt74:74LS00','6LB',4, 330,110, value='74LS00')
SX('6LB','13','RWTN'); SX('6LB','12','6MHz'); SX('6LB','11','R/WT2')
sh.place('jt74:74LS04','5KB',1, 300,130, value='74LS04')
SX('5KB','1','RWTP'); SX('5KB','2','RWTN2')
sh.place('jt74:74LS00','6LC',2, 330,130, value='74LS00')
SX('6LC','4','RWTN2'); SX('6LC','5','6MHz'); SX('6LC','6','R/WT1')
# HPLA latches -> COL/PAP/CF
sh.place('jt74:74LS373','4J',1, 55,155, value='74LS373')
for i,pin in enumerate(('3','4','7','8','13','14','17','18')): SX('4J',pin,'HPLA%d'%i)
for i,pin in enumerate(('2','5','6','9','12','15','16','19')): SX('4J',pin,'PL%d'%i)
SX('4J','11','LPREPF'); SX('4J','1','/LDPL')
sh.place('jt74:74LS175','4K',1, 105,155, value='74LS175')
for pin,net in (('2','COL4'),('7','COL5'),('10','COL6'),('13','HHHx'),('9','LDCOL3H'),
                ('4','PL0'),('5','PL1'),('12','PL2'),('13','PL3')):
    SX('4K',pin,net)
sh.place('jt74:74LS377','3K',1, 105,205, value='74LS377')
for pin,net in (('3','HHH'),('4','HCMP1*'),('7','/256H'),
                ('2','HHH*'),('5','HCMP1'),('6','/256H*'),('11','6MHz')):
    SX('3K',pin,net)
sh.place('jt74:74LS374','3J',1, 55,225, value='74LS374')
for i,pin in enumerate(('3','4','7','8','13','14','17','18')): SX('3J',pin,'HPLA%d'%i)
for pin,net in (('2','COL1'),('5','COL2'),('6','COL3'),('9','CF1'),('12','CF2'),('15','CF3'),('16','CF4')):
    SX('3J',pin,net)
SX('3J','11','LPREPF'); SX('3J','1','/COLL1')
# OBJ RAM address muxes
sh.place('jt74:74LS157','1P',1, 175,175, value='74LS157')
for pin,net in (('10','BIT80'),('13','256H'),('6','ASDES'),('3','64H'),
                ('11','AB7'),('14','AB6'),('5','AB5'),('2','AB4'),
                ('9','AO7'),('12','AO6'),('7','AO5'),('4','AO4'),('1','/SABOBJ')):
    SX('1P',pin,net)
sh.place('jt74:74LS157','1N',1, 175,225, value='74LS157')
for pin,net in (('10','32H'),('13','16H'),('6','A1DES'),('3','A0DES'),
                ('11','AB3'),('14','AB2'),('5','AB1'),('2','AB0'),
                ('9','AO3'),('12','AO2'),('7','AO1'),('4','AO0'),('1','/SABOBJ')):
    SX('1N',pin,net)
# object RAM pair + buffers
for ref,y,dn in (('1L',175,('B0','B1','B2','B3')),('1M',235,('B4','B5','B6','B7'))):
    sh.place('arcade:MN2114',ref,1, 245,y, value='2114')
    for i,pin in enumerate(('5','6','7','4','3','2','1','17','16','15')):
        sh.stub_bus(ref,pin,'AO%d'%i,222)
    for pin,net in zip(('14','13','12','11'),dn): sh.stub_bus(ref,pin,net,268)
    SX(ref,'8','/CSOBJ'); SX(ref,'10','/WROBJW')
sh.bus_close(222,'AO[0..9]')
sh.bus_close(268,'B[0..7]')
sh.place('jt74:74LS245','1K',1, 300,195, value='74LS245')
for i,(a,b) in enumerate((('2','18'),('3','17'),('4','16'),('5','15'),('6','14'),('7','13'),('8','12'),('9','11'))):
    SX('1K',a,'B%d'%(7-i)); SX('1K',b,'DBB%d'%(7-i))
SX('1K','19','/CSOB'); SX('1K','1','R/WOB')
sh.place('jt74:74LS241','1J',1, 335,225, value='74LS241')
for i,(a,b) in enumerate((('2','18'),('4','16'),('6','14'),('8','12'),('11','9'),('13','7'),('15','5'),('17','3'))):
    SX('1J',a,'B%d'%(7-i)); SX('1J',b,'HPLA%d'%(7-i))
# DES mux + strobes
sh.place('jt74:74LS157','2K',1, 245,140, value='74LS157')
for pin,net in (('3','2H'),('6','4H'),('10','HHH*'),('2','8H'),('5','128H'),('11','HHHx'),
                ('4','A0DES'),('7','A1DES'),('12','A2DES'),('9','HHH1'),('1','256H')):
    SX('2K',pin,net)
sh.place('jt74:74LS08','3FA',2, 130,255, value='74LS08')
SX('3FA','4','2H'); SX('3FA','5','8H'); SX('3FA','6','G28')
sh.place('jt74:74LS08','3FB',3, 290,155, value='74LS08')
SX('3FB','10','/WROBJ'); SX('3FB','9','/RDOBJ'); SX('3FB','8','/CSOB')
sh.place('jt74:74LS04','36A',5, 315,170, value='74LS04')
SX('36A','11','/WROBJ'); SX('36A','10','/WROBJW')
sh.save('cores/mnymny/sch/video4.kicad_sch')
print(validate('cores/mnymny/sch/video4.kicad_sch'))
