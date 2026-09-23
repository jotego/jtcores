#!/usr/bin/env python3
"""1B11142 AUDIO 2/3 (PDF p12): analog filters, mixer, TDA1510 amp, PSU."""
import sys
sys.path.insert(0,'cores/mnymny/sch/gen')
from kisch import Sheet, SN, validate
from hier import ROOT, SHEETS
M = SHEETS['audio2']
sh = Sheet(M['title'])
sh.head = sh.head.replace(sh.head.split('(uuid "')[1].split('"')[0], M['filuuid'])
sh.instpath = f"/{ROOT}/{M['symuuid']}"
SX=sh.stubx; PX=sh.powerx

def amp(ref,x,y,inp,inm,out):
    sh.place('mnymny:LM3900',ref,1,x,y,value='LM3900')
    SX(ref,'2',inp); SX(ref,'3',inm); SX(ref,'4',out)
def rc(ref,x,y,val,a=None,b=None,cap=False,rot=90):
    sh.place('Device:C' if cap else 'Device:R_US',ref,1,x,y,rot=rot,value=val)
    if a: SX(ref,'1' if rot==90 else '1',a)
    if b: SX(ref,'2',b)

# --- rullante (snare) ---
amp('5C1', 95,45,'RUL1','RUL2','RULLANTE0')
for ref,x,y,v,a,b,c in (('R133',35,45,'1K','ANAL1','GNDA',0),('C63',45,40,'0.01','ANAL1','GNDA',1),
                        ('R132',60,38,'1K','SW4A','RUL2',0),('R131',75,32,'150K','RUL2','RUL1',0),
                        ('R130',95,28,'33K','RUL2','RULLANTE0',0),('R120',108,52,'47K','RUL1','VCC2',0),
                        ('R124',130,45,'39K','RULLANTE0','AMIX',0)):
    rc(ref,x,y,v,a,b,cap=bool(c))
# --- cassa (kick) ---
amp('5C2', 95,95,'CAS1','CAS2','CASSA0')
for ref,x,y,v,a,b,c in (('R126',40,80,'470K','SW3A','CAS2',0),('R128',40,90,'56K','CAS2','GNDA',0),
                        ('R125',60,75,'560K','CAS2','CAS3',0),('C62',60,68,'1000p','CAS2','CAS3',1),
                        ('R129',35,100,'1K','CAS4','GNDA',0),('R127',48,100,'100K','CAS4','CAS2',0),
                        ('R123',70,95,'1K','CAS3','CAS5',0),('C68',80,90,'0.1u','CAS5','CAS6',1),
                        ('R122',92,85,'33K','CAS6','CASSA0',0),('R104',105,80,'120K','CAS6','CASSA0',0),
                        ('C61',75,108,'10u','CAS5','GNDA',1),('R102',105,100,'10K','CAS6','VCC2',0),
                        ('R103',95,108,'10K','CAS6','GNDA',0),('R84',112,108,'1K5','CASSA0','GNDA',0),
                        ('R105',130,95,'56K','CASSA0','AMIX',0)):
    rc(ref,x,y,v,a,b,cap=bool(c))
# --- basso ---
amp('5B1', 80,150,'BAS1','BAS2','BAS3')
amp('5C3', 150,150,'BAS5','BAS6','BASSO0')
for ref,x,y,v,a,b,c in (('C29',40,140,'0.1u','ANAL2','BAS7',1),('R69',52,140,'2K2','BAS7','BAS2',0),
                        ('R46',35,152,'1K','ANAL2','GNDA',0),('R98',80,132,'180K','BAS2','BAS3',0),
                        ('C52',80,125,'0.02u','BAS2','BAS3',1),('R99',72,162,'47K','BAS1','VCC2',0),
                        ('R100',85,168,'1K','BAS1','GNDA',0),('R101',60,168,'4K7','BAS1','VCC2',0),
                        ('C53',100,148,'0.02u','BAS3','BAS8',1),('R118',112,148,'33K','BAS8','BAS5',0),
                        ('C54',112,160,'2.2u','BAS8','GNDA',1),('R83',125,140,'2K2','BAS8','BAS5',0),
                        ('R85',150,128,'120K','BAS6','BASSO0',0),('C45',150,120,'1000p','BAS6','BASSO0',1),
                        ('R86',140,160,'100K','BAS6','GNDA',0),('R87',132,170,'33K','BAS6','VCC2',0),
                        ('R88',148,170,'15','BAS6','GNDA',0),('R106',175,150,'68K','BASSO0','AMIX',0)):
    rc(ref,x,y,v,a,b,cap=bool(c))
# --- ANAL3/ANAL6 switched mixers ---
for ref,x,y,v,a,b,c in (('R72',40,190,'10K','ANAL3','AN3A',0),('R71',32,198,'1K','ANAL3','GNDA',0),
                        ('R70',60,190,'10K','SW1B','AN3B',0),('C44',72,190,'0.1',None,None,1),
                        ('R82',88,190,'10K','AN3B','AMIX',0),('R80',88,198,'10K','AN3B','AMIX2',0),
                        ('C56',52,205,'0.01u','SW1B','GNDA',1),('C43',75,205,'0.01','AN3B','GNDA',1),
                        ('R48',40,220,'10K','ANAL6','AN6A',0),('R47',32,228,'1K','ANAL6','GNDA',0),
                        ('C42',55,220,'0.1u',None,None,1),('R81',70,220,'10K','AN6A','AN3B',0)):
    rc(ref,x,y,v,a,b,cap=bool(c))
# --- piano ---
amp('5B2', 140,205,'PIA1','PIA2','PIANO0')
for ref,x,y,v,a,b,c in (('C41',105,200,'0.1','AMIX2','PIA3',1),('R79',118,200,'47K','PIA3','PIA2',0),
                        ('C49',135,188,'0.01','PIA2','PIANO0',1),('R107',148,192,'100K','PIA2','PIANO0',0),
                        ('R93',130,215,'100K','PIA1','VCC2',0),('R92',118,222,'33K','PIA1','GNDA',0),
                        ('R91',135,222,'12K','PIA1','GNDA',0),('R90',168,205,'68K','PIANO0','AMIX',0)):
    rc(ref,x,y,v,a,b,cap=bool(c))
# --- ANAL5 noise gate (3A LS74 + T6) ---
sh.place('jt74:74LS74','3A',1, 95,245, value='74LS74')
SX('3A','3','NG1'); SX('3A','2','NG2'); SX('3A','5','NG3')
sh.place('jt74:74LS14','4A2',2, 80,258, value='74LS14')
SX('4A2','3','NG3'); SX('4A2','4','NG2')
sh.place('Device:Q_NPN_BCE','T6',1, 65,245, value='BC548')
for ref,x,y,v,a,b,c in (('R67',40,242,'1K','ANAL5','NG4',0),('R66',32,252,'1K','ANAL5','GNDA',0),
                        ('C28',52,250,'1000p','NG4','GNDA',1),('R40',60,258,'100K',None,None,0),
                        ('R64',72,232,'4K7','NG5','VCC2',0),('R65',85,232,'4K7','NG6','VCC2',0),
                        ('R39',110,258,'220','NG3','GNDA',0),('C37',118,262,'1u',None,'GNDA',1)):
    rc(ref,x,y,v,a,b,cap=bool(c))
# --- tromba ladder (4B LS156 + R41..R76 + R97) ---
sh.place('jt74:74LS156','4B',1, 230,215, value='74LS156')
for pin,net in (('13','IOA2'),('3','IOA1'),('1','IOA0'),('15','TRE'),('2','TRE2'),('14','TRE3')):
    SX('4B',pin,net)
LAD=(('9','R41','8K2'),('10','R42','5K6'),('11','R43','3K3'),('12','R44','1K8'),
     ('7','R73','820'),('6','R74','390'),('5','R75','150'),('4','R76','47'))
for i,(pin,rr,val) in enumerate(LAD):
    SX('4B',pin,'TL%d'%i)
    rc(rr,262,196+i*7,val,'TL%d'%i,'TROMBA1')
rc('R97',285,235,'150K','TROMBA1','AMIX')
rc('C40',275,225,'0.1','TROMBA1',None,cap=True)
# --- 4016 switches 5D ---
sh.place('mnymny:4016','5D',1, 55,65, value='4016')
for pin,net in (('13','IOA4'),('5','IOA3'),('6','SW3C'),('12','SW4C'),
                ('1','ANAL1'),('2','SW4A'),('4','ANAL1B'),('3','SW3A'),
                ('8','AN3A'),('9','SW1B'),('11','AN3X'),('10','SW1X')):
    SX('5D',pin,net)
# --- output level + a(SH3) ---
amp('5B3', 305,60,'LV1','LV2','LEV0')
for ref,x,y,v,a,b,c in (('R119',270,40,'4K7','LV1','VCC2',0),('R117',270,48,'1K','LV1','GNDA',0),
                        ('R116',285,45,'47K','AMIX','LV2',0),('R77',285,55,'10K','A_SH3','LV2',0),
                        ('R115',305,40,'82K','LV2','LEV0',0),('R114',330,60,'4K7','LEV0','LEV1',0),
                        ('R45',345,55,'10K','LEV1','NU1',0),('R68',360,65,'10K','LEV2','LEVEL',0),
                        ('R3',330,80,'10K','A_SH3','AMPIN',0),('C7',318,80,'0.1u','A_SH3',None,1)):
    rc(ref,x,y,v,a,b,cap=bool(c))
sh.place('Device:Q_NPN_BCE','T7',1, 352,45, value='BC548')
sh.place('Device:R_Potentiometer_Trim_US','P1',1, 345,70, value='10K')
# --- TDA1510 power amp ---
sh.place('mnymny:TDA1510','2B',1, 310,120, value='TDA1510')
SX('2B','2','AMPIN'); SX('2B','1','AMPFB')
SX('2B','5','SPK0'); SX('2B','9','SPK1')
for ref,x,y,v,a,b,c in (('R1',280,105,'100K','AMPIN','TDA3',0),('R2',345,100,'100K',None,None,0),
                        ('C9',345,108,'47uF',None,'GNDA',1),('C6',360,125,'0.22u',None,'GNDA',1),
                        ('C10',282,138,'100uF',None,None,1),('C11',352,138,'100uF',None,None,1),
                        ('C12',300,145,'0.1','SPK0','GNDA',1),('C13',330,145,'0.1','SPK1','GNDA',1),
                        ('R5',308,152,'4.7','SPK0','GNDA',0),('R6',322,152,'4.7','SPK1','GNDA',0),
                        ('R8',292,152,'100K','SPK0','GNDA',0),('R10',338,152,'100K','SPK1','GNDA',0),
                        ('R9',305,165,'2K2','AMPFB',None,0),('C14',320,165,'4.7u',None,'GNDA',1),
                        ('R7',362,145,'680','TDA13','GNDA',0),('C15',362,152,'330p','TDA13','GNDA',1)):
    rc(ref,x,y,v,a,b,cap=bool(c))
# --- PSU corner ---
sh.place('Device:D','D1',1, 300,190, rot=90, value='1N4004')
SX('D1','1','+12'); SX('D1','2','VCC2')
for ref,x,y,v,a,b,c in (('C1',285,200,'2200uF','+12','GNDA',1),('C5',298,200,'0.1','VCC2','GNDA',1),
                        ('C2',311,200,'100uF','VCC2','GNDA',1),('C63B',324,200,'0.1','-5V','GNDA',1),
                        ('C3',337,200,'100uF','-5V','GNDA',1),('C4',350,200,'0.1','V0','GNDA',1)):
    rc(ref,x,y,v,a,b,cap=bool(c))
sh.save('cores/mnymny/sch/audio2.kicad_sch')
print(validate('cores/mnymny/sch/audio2.kicad_sch'))
