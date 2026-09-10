#!/usr/bin/env python3
"""1B11140 VIDEO 5/5 (PDF p7): CN1, shifter-mode mux 9C, BK latch 9B, /VIDOUT flop."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from kisch import Sheet, SN, validate
from hier import ROOT, SHEETS
M = SHEETS['video5']
sh = Sheet(M['title'])
sh.head = sh.head.replace(sh.head.split('(uuid "')[1].split('"')[0], M['filuuid'])
sh.instpath = f"/{ROOT}/{M['symuuid']}"

# CN1 to IO board
sh.place('mnymny:CONN50','CN1',1, 45,150, value='CN1 (IO board)')
CN1={}
for i in range(8): CN1[str(i+1)]='DBB%d'%i
for i in range(10): CN1[str(i+10)]='AB%d'%i
CN1.update({'21':'B','22':'G','23':'R','24':'/SYNC','26':'1Hu','28':'/VBLANK','29':'HBLANK',
 '30':'/SABBKG','31':'HCMA','32':'/RDBKGH','34':'/WRBKGH','36':'/RDOBJ','38':'/RDBKGL',
 '40':'/WRBKGL','42':'/WROBJ','44':'VCMA','46':'/SABOBJ'})
for pin,net in CN1.items(): sh.stubx('CN1',pin,net)
sh.powerx('CN1','47','VCC')
for pin in ('9','20','25','27','33','35','37','39','41','43','45','48','49','50'):
    sh.powerx('CN1',pin,'VSS',down=True)
sh.place('Device:C','C1',1, 120,240, value='0.1u')
sh.place('Device:C_Polarized_Small_US','C2',1, 135,240, value='220u')

# 9C LS153 mode mux (both halves)
sh.place('jt74:74LS153','9C',1, 200,90, value='74LS153')
sh.place('jt74:74LS153','9C',2, 200,120, value='74LS153')
for pin in ('4','5'): sh.stubx('9C',pin,'HHH1')
for pin in ('10','13'): sh.stubx('9C',pin,'HHH1')
for pin in ('3','6','11','12'): sh.stubx('9C',pin,'HCMP1')
sh.stubx('9C','2','SELECT'); sh.stubx('9C','14','/256Hx')
sh.stubx('9C','7','MXA'); sh.stubx('9C','9','MXB')
sh.powerx('9C','1','VSS',down=True); sh.powerx('9C','15','VSS',down=True)
# inverters + 5F LS00 -> S0T/S1T
sh.place('jt74:74LS14','6H',6, 240,85, value='74LS14')
sh.stubx('6H','13','MXA'); sh.stubx('6H','12','MXAN')
sh.place('jt74:74LS14','6H',5, 240,120, value='74LS14')
sh.stubx('6H','11','MXB'); sh.stubx('6H','10','MXBN')
for u,ins,out in ((1,(('1','/YA'),('2','MXAN')),'S0T1'),
                  (2,(('4','MXAN'),('5','MXA')),'S1T1'),
                  (3,(('10','/YB'),('9','MXBN')),'S0T2'),
                  (4,(('12','MXBN'),('13','MXB')),'S1T2')):
    sh.place('jt74:74LS00','5F',u, 280,70+u*18, value='74LS00')
    for pin,net in ins: sh.stubx('5F',pin,net)
    sh.stubx('5F',('3','6','8','11')[u-1],out)
# HCMP fan-out
sh.place('jt74:74LS08','8A',3, 300,160, value='74LS08')
sh.stubx('8A','10','HCMP1'); sh.stubx('8A','9','HCMPD'); sh.stubx('8A','8','HCMP12')
sh.place('jt74:74LS08','8A',2, 300,180, value='74LS08')
sh.stubx('8A','4','HCMP1'); sh.stubx('8A','5','HCMPD'); sh.stubx('8A','6','HCMP11')
sh.place('jt74:74LS14','8E',6, 265,165, value='74LS14')
sh.stubx('8E','13','HCMP1'); sh.stubx('8E','12','HCMPD')
sh.place('jt74:74LS14','6H',1, 300,205, value='74LS14')
sh.stubx('6H','1','HCMP2'); sh.stubx('6H','2','HCMP21')
sh.place('jt74:74LS14','8E',1, 300,225, value='74LS14')
sh.stubx('8E','1','HCMP2'); sh.stubx('8E','2','HCMP22')
# BK latch 9B
sh.place('jt74:74LS175','9B',1, 210,190, value='74LS175')
sh.stubx('9B','5','BKB1'); sh.stubx('9B','12','BKB2')
sh.stubx('9B','7','BK1'); sh.stubx('9B','2','BK2')
sh.stubx('9B','9','/LD1'); sh.powerx('9B','1','VCC')
# /VIDOUT flop 6P + double inverter
sh.place('jt74:74LS14','8E',5, 180,240, value='74LS14')
sh.stubx('8E','11','ABVIDOUT'); sh.stubx('8E','10','AVN1')
sh.place('jt74:74LS14','8E',4, 205,240, value='74LS14')
sh.stubx('8E','9','AVN1'); sh.stubx('8E','8','AVN2')
sh.place('jt74:74LS74','6P',2, 240,240, value='74LS74')
sh.stubx('6P','12','AVN2'); sh.stubx('6P','11','6MHz'); sh.stubx('6P','8','/VIDOUT')
sh.powerx('6P','10','VCC'); sh.powerx('6P','13','VCC')
sh.save('cores/mnymny/sch/video5.kicad_sch')
print(validate('cores/mnymny/sch/video5.kicad_sch'))
