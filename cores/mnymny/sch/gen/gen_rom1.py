#!/usr/bin/env python3
"""1B11147 ROM MODULE 1/2 (PDF p14): main CPU ROM sockets, protection PAL, CN1/CN2."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
import kisch
from kisch import Sheet, SN, validate
from hier import ROOT, SHEETS

M = SHEETS['rom1']
sh = Sheet(M['title'])
sh.uuid = M['filuuid']
sh.head = sh.head.replace(sh.head.split('(uuid "')[1].split('"')[0], M['filuuid'])
sh.instpath = f"/{ROOT}/{M['symuuid']}"

# ---- CN1 (left edge) ----
sh.place('mnymny:CONN50','CN1',1, 25,150, value='CN1')
CN1 = {  # pin -> net
 '38':'PU1','40':'PU1',
 '11':'AB0','14':'AB1','13':'AB2','16':'AB3','15':'AB4','18':'AB5','17':'AB6','20':'AB7',
 '32':'AB8','31':'AB9','29':'AB10','19':'A15','33':'AB11',
 '21':'D0','22':'D1','23':'D2','24':'D3','25':'D4','26':'D5','27':'D6','28':'D7',
 '3':'AB12','4':'AB13','1':'A14','2':'/RDB','6':'/WRB','8':'/RFSH',
 '7':'DBB3','10':'DBB4','12':'DBB5','9':'DBB6','5':'DBB7',
 '30':'/CS2','35':'/CS3','43':'/CS4','34':'/CS5','36':'/CS6',
}
for pin,net in CN1.items(): sh.stub('CN1',1,pin,net,'L')
for pin in ('42','37','39','41','44','46','48','50','45','47','49'):
    sh.power('CN1',1,pin,'VSS',down=True)

# ---- main CPU ROM sockets (2732/2764), top row ----
ROMS = [('2','/CS2',95),('3','/CS3',150),('4','/CS4',205),('10','/CS5',260),('11','/CS6',315)]
for ref,cs,x in ROMS:
    sh.place('mnymny:2764',ref,1,x,60,value='2732/2764')
    p={'10':'AB0','9':'AB1','8':'AB2','7':'AB3','6':'AB4','5':'AB5','4':'AB6','3':'AB7',
       '25':'AB8','24':'AB9','21':'AB10','2':'A15','23':'ABx',
       '20':cs,'22':'AB11'}
    for pin,net in p.items(): sh.stub(ref,1,pin,net,'L')
    for i,pin in enumerate(('11','12','13','15','16','17','18','19')):
        sh.stub(ref,1,pin,'D%d'%i,'R')
    for pin in ('28','27','1'): sh.power(ref,1,pin,'VCC')
    sh.power(ref,1,'14','VSS',down=True)
# 27K pullups on the /CS strap pads
for rr,cs,x in (('R3','/CS2',95),('R4','/CS3',150),('R6','/CS4',205),('R10','/CS5',260),('R11','/CS6',315)):
    sh.place('Device:R_US',rr,1,x+18,95,rot=0,value='27K')
    sh.power(rr,1,'1','VCC')
    pp=sh.pins(rr,1)['2']
    sh.wire(pp[0],pp[1],pp[0],SN(pp[1]+2.54))
    sh.label(cs,pp[0],SN(pp[1]+2.54),'L',90)
sh.place('Device:R_US','R5',1, 45,25, rot=0, value='27K')
sh.power('R5',1,'1','VCC')
p5=sh.pins('R5',1)['2']; sh.wire(p5[0],p5[1],p5[0],SN(p5[1]+2.54)); sh.label('PU1',p5[0],SN(p5[1]+2.54),'L',90)

# ---- protection PAL (pos 1) ----
sh.place('mnymny:PAL16L8','1',1, 70,235, value='PAL16L8')
PALP={'1':'AB1','2':'AB2','3':'AB9','4':'AB10','5':'AB11','6':'AB12','7':'AB13',
      '8':'A14','9':'/RDB','11':'/WRB'}
for pin,net in PALP.items(): sh.stub('1',1,pin,net,'L')
for pin,net in (('13','/RFSH'),('16','DBB3'),('17','DBB4'),('18','DBB5'),('19','DBB6'),('12','DBB7')):
    sh.stub('1',1,pin,net,'R')

# ---- B sockets (bg ROM options) ----
BS=[('5','B3',[('11','DF16'),('12','DF17'),('13','DF18'),('15','DF19'),('16','DF20'),('17','DF21'),('18','DF22'),('19','DF23')],150),
    ('6','B2',[('11','DF8'),('12','DF9'),('13','DF10'),('15','DF11'),('16','DF12'),('17','DF13'),('18','DF14'),('19','DF15')],215),
    ('12','B1',[('11','DF0'),('12','DF1'),('13','DF2'),('15','DF3'),('16','DF4'),('17','DF5'),('18','DF6'),('19','DF7')],280)]
AFP={'2':'AF12','23':'AF11','21':'AF10','24':'AF9','25':'AF8','3':'AF7','4':'AF6',
     '5':'AF5','6':'AF4','7':'AF3','8':'SIG2','9':'SIG1','10':'SIG0'}
for ref,val,dnets,x in BS:
    sh.place('mnymny:2764',ref,1,x,225,value=val+' 2764')
    for pin,net in AFP.items(): sh.stub(ref,1,pin,net,'L')
    for pin,net in dnets: sh.stub(ref,1,pin,net,'R')
    for pin in ('28','27','1'): sh.power(ref,1,pin,'VCC')
    sh.power(ref,1,'14','VSS',down=True)
    sh.power(ref,1,'20','VSS',down=True)
    sh.stub(ref,1,'22','/OEB','L')

# ---- CN2 (right edge) ----
sh.place('mnymny:CONN40','CN2',1, 378,150, value='CN2')
CN2={'6':'AF12','11':'AF11','16':'AF10','9':'AF9','7':'AF8','5':'AF7','8':'AF6',
     '10':'AF5','12':'AF4','13':'AF3','15':'SIG2','18':'SIG1','14':'SIG0',
     '24':'DF0','2':'DF1','13x':'','20':'DF3','4':'DF4','22':'DF5','3':'DF6','1':'DF7',
     '33':'DF8','32':'DF9','35':'DF10','28':'DF11','26':'DF12','31':'DF13','29':'DF14','30':'DF15',
     '40':'DF16','39':'DF17','37':'DF18','25':'DF19','23':'DF20','21':'DF21','19':'DF22','17':'DF23'}
for pin,net in CN2.items():
    if net and pin.isdigit(): sh.stub('CN2',1,pin,net,'L')
for pin in ('34','36','38'): sh.power('CN2',1,pin,'VSS',down=True)
# AR pullup arrays (10K) on B-socket VCC group
for rr,x in (('AR1',150),('AR2',165),('AR3',330),('AR4',345),('AR5',360)):
    sh.place('Device:R_US',rr,1,x,190,rot=0,value='10K')
    sh.power(rr,1,'1','VCC')
    pp=sh.pins(rr,1)['2']
    sh.wire(pp[0],pp[1],pp[0],SN(pp[1]+2.54)); sh.label('/OEB',pp[0],SN(pp[1]+2.54),'L',90)

sh.save('cores/mnymny/sch/rom1.kicad_sch')
print(validate('cores/mnymny/sch/rom1.kicad_sch'))
