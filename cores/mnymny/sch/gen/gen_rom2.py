#!/usr/bin/env python3
"""1B11147 ROM MODULE 2/2 (PDF p15): audio-board ROMs via CN3."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from kisch import Sheet, SN, validate
from hier import ROOT, SHEETS
M = SHEETS['rom2']
sh = Sheet(M['title'])
sh.head = sh.head.replace(sh.head.split('(uuid "')[1].split('"')[0], M['filuuid'])
sh.instpath = f"/{ROOT}/{M['symuuid']}"

# CN3 (50-pin, left edge)
sh.place('mnymny:CONN50','CN3',1, 25,150, value='CN3')
CN3 = {}
for i,pin in enumerate(('5','7','9','11','13','15','17','19')): CN3[pin]='AD%d'%i
for pin,net in (('24','AD8'),('23','AD9'),('25','AD10'),('26','AD11'),('21','AD14'),('22','AD15')): CN3[pin]=net
for pin,net in (('3','/CS0A'),('4','/CS1A'),('50','/CS4A'),('49','/CS5A')): CN3[pin]=net
for i,pin in enumerate(('6','8','10','12','14','16','18','20')): CN3[pin]='D%d'%i
for i,pin in enumerate(('28','30','32','34','36','38','40','43','48','46','44','42','47','45')): CN3[pin]='A%d'%i
for i,pin in enumerate(('27','29','31','33','35','37','39','41')): CN3[pin]='DB%d'%i
for pin,net in CN3.items(): sh.stub('CN3',1,pin,net,'L')
sh.power('CN3',1,'1','VCC')
sh.power('CN3',1,'2','VSS',down=True)

# speech CPU ROMs 7,8 (AD bus, D data) - 2732/2764/27128 sockets
def socket(ref,x,y,anets,dnets,cs,rr):
    sh.place('mnymny:27128',ref,1,x,y,value='2732/64/128')
    amap={'10':0,'9':1,'8':2,'7':3,'6':4,'5':5,'4':6,'3':7,'25':8,'24':9,'21':10,'23':11,'2':12,'26':13}
    for pin,idx in amap.items(): sh.stub_bus(ref,pin,anets[idx],x-27)
    for pin,net in zip(('11','12','13','15','16','17','18','19'),dnets): sh.stub_bus(ref,pin,net,x+27)
    sh.bus_close(x-27,None,ytop=y-35)
    sh.bus_close(x+27,None,ybot=y+52)
    sh.stub(ref,1,'20',cs,'L'); sh.stub(ref,1,'22',cs,'L')
    for pin in ('28','27','1'): sh.power(ref,1,pin,'VCC')
    sh.power(ref,1,'14','VSS',down=True)
    sh.place('Device:R_US',rr,1,x+22,y+35,rot=0,value='27K')
    sh.power(rr,1,'1','VCC')
    pp=sh.pins(rr,1)['2']; sh.wire(pp[0],pp[1],pp[0],SN(pp[1]+2.54)); sh.label(cs,pp[0],SN(pp[1]+2.54),'L',90)

AD=['AD%d'%i for i in range(12)]+['AD14','AD15']
DD=['D%d'%i for i in range(8)]
A=['A%d'%i for i in range(14)]
DB=['DB%d'%i for i in range(8)]
socket('7', 120, 65, AD, DD, '/CS0A','R7')
socket('8', 210, 65, AD, DD, '/CS1A','R8')
socket('9', 120,185, A,  DB, '/CS5A','R9')
socket('13',210,185, A,  DB, '/CS4A','R12')
sh.bus_seg((120-27,30),(210-27,30))
sh.buslabel('AD[0..15]',120-27+2,30,0)
sh.bus_seg((120+27,117),(210+27,117))
sh.buslabel('D[0..7]',120+27+2,117,0)
sh.bus_seg((120-27,150),(210-27,150))
sh.buslabel('A[0..13]',120-27+2,150,0)
sh.bus_seg((120+27,237),(210+27,237))
sh.buslabel('DB[0..7]',120+27+2,237,0)

sh.save('cores/mnymny/sch/rom2.kicad_sch')
print(validate('cores/mnymny/sch/rom2.kicad_sch'))
