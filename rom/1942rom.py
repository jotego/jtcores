#!/usr/bin/python
import sys
import os.path
import binascii
import platform

output_name='JT1942.rom'

python_version = platform.python_version_tuple()
if python_version[0] != '2':
    print("Error: this script requires Python 2 to work.")
    exit(1)

rompath=""

arg_cur=1
game="1942"
while len(sys.argv) > arg_cur:
    if sys.argv[arg_cur] == "-path":
        arg_cur = arg_cur+1
        rompath=sys.argv[arg_cur]+"/"
    else:        
        game=sys.argv[arg_cur]
        print("Generating file for game: ",game)
        if game != "1942": #and game != "makaimurg" and game != "gngt" and game != "gngc":
            print("Wrong game name. Please use one of these:")
            print("1942")
            exit(1)
    arg_cur = arg_cur+1

def append_file( file_list ):
    for fname in file_list:
        with open(rompath+fname,'rb') as f:
            fo.write( f.read() )

def byte_merge( file_list ):    
    with open(rompath+file_list[0],'rb') as flsb:
        blsb = flsb.read()
    with open(rompath+file_list[1],'rb') as fmsb:
        bmsb = fmsb.read()
    for k in range(len(blsb)):
        fo.write( blsb[k] )
        fo.write( bmsb[k] )

def append_dup( filename ):
    with open(rompath+filename,'rb') as f:
        buf = f.read()        
    for k in range(len(buf)):
        fo.write(buf[k])
        fo.write(buf[k])

def check_files( filenames ):
    problem=False
    for i in filenames.values():
        if os.path.isfile(rompath+i)==False:
            print("Cannot find file "+i)
            problem = True
    if problem:
        print("You have to unzip your Ghosts'n Goblins ROM files in")
        print("the same folder as gngrom.py")
        exit(1)

if game == "1942":
    roms = {
        'main0'     : "srb-03.m3",
        'main1'     : "srb-04.m4",
        'main2'     : "srb-05.m5",
        'main3'     : "srb-06.m6",
        'main4'     : "srb-07.m7",
        'audio'     : "sr-01.c11",
        'char'      : "sr-02.f2",
        'scr0'      : "sr-08.a1",
        'scr1'      : "sr-09.a2",
        'scr2'      : "sr-10.a3",
        'scr3'      : "sr-11.a4",
        'scr4'      : "sr-12.a5",
        'scr5'      : "sr-13.a6",
        'obj0'      : "sr-14.l1",
        'obj1'      : "sr-15.l2",
        'obj2'      : "sr-16.n1",
        'obj3'      : "sr-17.n2",
        'e8'        : "sb-5.e8",
        'e9'        : "sb-6.e9",
        'e10'       : "sb-7.e10",
        'f1'        : "sb-0.f1",
        'd6'        : "sb-4.d6",
        'k3'        : "sb-8.k3",
        'd1'        : "sb-2.d1",
        'd2'        : "sb-3.d2",
        'd6'        : "sb-4.d6",
        'k6'        : "sb-1.k6",
        'm11'       : "sb-9.m11",
    }
    rom_crc = '8389D079'
else:
    print("Unsupported option: ", game)
    exit(1)

def report_pos( msg ):
    print("%s starts at 0x%x" % (msg,fo.tell()/2) )

check_files( roms )

fo = open(output_name,'wb')

append_file( [roms['main0'], 
              roms['main1'],
              roms['main2'],
              roms['main3'],
              roms['main3'], # main3 is repeated to make it 16kB
              roms['main4']] )
#print("Sound starts at 0x%x" % fo.tell() )
report_pos( "Sound" )
append_file( [roms['audio']] )

report_pos( "Char" )
append_file( [roms['char']] )

report_pos( "Scroll" )
byte_merge( [roms['scr0'], roms['scr1']])
byte_merge( [roms['scr2'], roms['scr3']])

report_pos( "Scroll (upper)" )
append_dup( roms['scr4'])
append_dup( roms['scr5'])

report_pos( "Objects" )
byte_merge( [roms['obj0'], roms['obj1']])
report_pos( "Objects (upper)" )
byte_merge( [roms['obj2'], roms['obj3']])

# PROMs
report_pos( "PROMs" )
byte_merge( [roms["k6"],  roms["k6"]  ])
byte_merge( [roms["d1"],  roms["d1"]  ])
byte_merge( [roms["d2"],  roms["d2"]  ])
byte_merge( [roms["d6"],  roms["d6"]  ])
byte_merge( [roms["e8"],  roms["e8"]  ])
byte_merge( [roms["e9"],  roms["e9"]  ])
byte_merge( [roms["e10"], roms["e10"] ])
byte_merge( [roms["f1"],  roms["f1"]  ])
byte_merge( [roms["k3"],  roms["k3"]  ])
byte_merge( [roms["m11"], roms["m11"] ])

# Calculate CRC
fo.close()
with open(output_name,'rb') as f:
    buf = f.read()
    buf=(binascii.crc32(buf) & 0xFFFFFFFF )
    if format(buf,'08X') != rom_crc:
        print("Wrong CRC check sum for generated ROM file")
        print("Maybe your rom set is not correct. You can")
        print("still try it.")
        print("CRC: %X" % buf)
    else:
        print("CRC check = %s correct " % rom_crc)
        print("Copy the file %s to your SD card." % output_name )