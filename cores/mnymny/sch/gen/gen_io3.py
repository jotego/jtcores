#!/usr/bin/env python3
"""1B11141 IO 3/3 (PDF p10): CN1 / CN3 pinouts."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from kisch import Sheet, validate
from hier import ROOT, SHEETS
M = SHEETS['io3']
sh = Sheet(M['title'])
sh.head = sh.head.replace(sh.head.split('(uuid "')[1].split('"')[0], M['filuuid'])
sh.instpath = f"/{ROOT}/{M['symuuid']}"

sh.place('mnymny:CONN50','CN1',1, 60,150, value='CN1 (video board)')
CN1={}
for i in range(8): CN1[str(i+1)]='DBB%d'%i
for i in range(10): CN1[str(i+10)]='AB%d'%i
CN1.update({'21':'B','22':'G','23':'R','24':'/SYNC','26':'1Hu','28':'/VBLANK','29':'HBLANK',
 '30':'/SABBKG','31':'HCMA','32':'/RDBKGH','34':'/WRBKGH','36':'/RDOBJ','38':'/RDBKGL',
 '40':'/WRBKGL','42':'/WROBJ','44':'VCMA','46':'/SABOBJ'})
for pin,net in CN1.items(): sh.stub('CN1',1,pin,net,'L')
for pin in ('9','20','25','27','33','35','37','39','41','43','45','47','48','49','50'):
    sh.power('CN1',1,pin,'VSS',down=True)

sh.place('mnymny:CONN20','CN3',1, 200,110, value='CN3 (audio board)')
CN3={'6':'S0','3':'S1','4':'S2','1':'S3','10':'S4','7':'S5','5':'S6','8':'S7',
     '9':'HSOUND','2':'RESSOUND','18':'+12V','17':'+12V','16':'-5V','15':'-5V',
     '12':'VCC','11':'VCC','20':'SPK1','19':'SPK0'}
for pin,net in CN3.items(): sh.stub('CN3',1,pin,net,'L')
for pin in ('14','13'): sh.power('CN3',1,pin,'VSS',down=True)

sh.save('cores/mnymny/sch/io3.kicad_sch')
print(validate('cores/mnymny/sch/io3.kicad_sch'))
