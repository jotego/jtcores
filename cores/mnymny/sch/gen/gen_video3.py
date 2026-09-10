#!/usr/bin/env python3
"""1B11140 VIDEO 3/5 (PDF p5): object line buffers + 82S100 PLAs."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from kisch import Sheet, SN, validate
from hier import ROOT, SHEETS
M = SHEETS['video3']
sh = Sheet(M['title'])
sh.head = sh.head.replace(sh.head.split('(uuid "')[1].split('"')[0], M['filuuid'])
sh.instpath = f"/{ROOT}/{M['symuuid']}"

def half(idx, y0, cnt1,cnt2, xorA,xorB, gA,gB,gC, cmpA,cmpB, buf, ramL,ramR, lat, cst, abd, rwt, cld):
    # position counters
    for ref,hpla in ((cnt1,('HPLA7','HPLA6','HPLA5','HPLA4')),(cnt2,('HPLA3','HPLA2','HPLA1','HPLA0'))):
        y = y0 if ref==cnt1 else y0+42
        sh.place('jt74:74LS161',ref,1, 45,y, value='74LS161')
        for pin,net in zip(('6','5','4','3'),hpla): sh.stubx(ref,pin,net)
        sh.stubx(ref,'9',cld); sh.stubx(ref,'2','6MHz'); sh.stubx(ref,'1','/CNTCLR')
        for pin,q in zip(('11','12','13','14'),('QD','QC','QB','QA')):
            sh.stubx(ref,pin,'%s_%s'%(ref,q))
    # XOR banks -> buffer address A0..A7
    for bank,(src,outs) in ((xorA,(cnt1,('A7','A6','A5','A4'))),(xorB,(cnt2,('A3','A2','A1','A0')))):
        for u in range(1,5):
            sh.place('jt74:74LS86',bank,u, 95,y0-8+ (0 if bank==xorA else 42) + u*9, value='74LS86')
            ip = {1:('1','2','3'),2:('4','5','6'),3:('9','10','8'),4:('12','13','11')}[u]
            sh.stubx(bank,ip[0],'%s_Q%s'%(src,'DCBA'[u-1]))
            sh.stubx(bank,ip[1],'HCMP1%d'%idx)
            sh.stubx(bank,ip[2],outs[u-1]+('B%d'%idx))
    # CST gates
    sh.place('jt74:74LS10',gA,1, 150,y0-10, value='74LS10')
    sh.stubx(gA,'1','%s_QD'%cnt1); sh.stubx(gA,'2','%s_QC'%cnt1); sh.stubx(gA,'13','%s_QB'%cnt1)
    sh.stubx(gA,'12','CSTP%d'%idx)
    sh.place('jt74:74LS27',gB,1, 175,y0-10, value='74LS27')
    sh.stubx(gB,'1','CSTP%d'%idx); sh.stubx(gB,'2','ABDISP%d'%idx); sh.stubx(gB,'13','%s_QA'%cnt1)
    sh.stubx(gB,'12','/CST%d'%idx)
    # data XOR/compare pair
    for u in range(1,5):
        sh.place('jt74:74LS86',cmpA,u, 205,y0-14+u*8, value='74LS86')
        sh.place('jt74:74LS86',cmpB,u, 230,y0-14+u*8, value='74LS86')
    # LS244 buffer + 2148 RAMs + LS374 latch
    sh.place('jt74:74LS244',buf,1, 185,y0+30, value='74LS244')
    sh.stubx(buf,'1','R/WT%d'%idx); sh.stubx(buf,'19','R/WT%d'%idx)
    for ram,x in ((ramL,175),(ramR,215)):
        sh.place('arcade:AM2148-55PC',ram,1, x,y0+62, value='2148H')
        for i,pin in enumerate(('5','6','7','4','3','2','1','17','16','15')):
            sh.stubx(ram, pin, 'A%d'%i + 'B%d'%idx)
        sh.stubx(ram,'8','/CST%d'%idx); sh.stubx(ram,'10','R/WT%d'%idx)
        for i,pin in enumerate(('14','13','12','11')):
            sh.stubx(ram, pin, ('%s_D%d'%(ram,i)))
    sh.place('jt74:74LS374',lat,1, 255,y0+45, value='74LS374')
    sh.stubx(lat,'11','CLK%d'%idx)
    for i,pin in enumerate(('2','5','6','9','12','15','16','19')):
        sh.stubx(lat,pin,('X%d' if idx==2 else 'COLOUT%d')%(i+1) if i<6 else '%s_Q%d'%(lat,i))

half(2, 55,  '7G','8G','7F','8F','6F','6G','6F2','7A','8A','7C','7E','7D','7B','CST2','ABDISP2','RWT2','/CNTLDT2')
half(1, 175, '8H','7H','8J','7J','8K','8L','8K2','7P','8P','7M','7K','7L','7N','CST1','ABDISP1','RWT1','/CNTLDT1')

# 82S100 PLAs
sh.place('mnymny:82S100','8C',1, 330,80, value='82S100')
for pin,net in (('21','/VBLANK'),('22','SELECT'),('23','/256Hx'),
                ('27','X6'),('26','X5'),('25','X4'),('24','X3'),('20','X2'),('2','X1')):
    sh.stubx('8C',pin,net)
for pin,net in (('15','X4OUT'),('13','X5OUT'),('12','X6OUT'),('18','X1OUT'),('17','X2OUT'),('16','X3OUT'),
                ('11','ABDISP1'),('10','ABVIDOUT')):
    sh.stubx('8C',pin,net)
sh.powerx('8C','19','VSS',down=True)
sh.place('jt74:74LS27','8D',2, 370,120, value='74LS27')
sh.stubx('8D','3','X4'); sh.stubx('8D','4','X5'); sh.stubx('8D','5','X6'); sh.stubx('8D','6','/X456')
sh.place('jt74:74LS27','8D',3, 370,140, value='74LS27')
sh.stubx('8D','9','X1'); sh.stubx('8D','10','X2'); sh.stubx('8D','11','X3'); sh.stubx('8D','8','/X123')
sh.place('mnymny:82S100','8N',1, 330,200, value='82S100')
for pin,net in (('9','COL1'),('8','COL2'),('7','COL3'),('3','COL4'),('2','COL5'),('27','COL6'),
                ('23','SELECT'),('22','/256Hx'),('20','COL1P'),('21','COL2P')):
    sh.stubx('8N',pin,net)
for pin,net in (('15','COLOUT4'),('13','COLOUT5'),('12','COLOUT6'),('18','COLOUT1'),('17','COLOUT2'),('16','COLOUT3'),
                ('11','ABDISP2'),('10','SELOBJ')):
    sh.stubx('8N',pin,net)
sh.powerx('8N','19','VSS',down=True)
sh.save('cores/mnymny/sch/video3.kicad_sch')
print(validate('cores/mnymny/sch/video3.kicad_sch'))
