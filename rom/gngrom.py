#!/usr/bin/python
import sys

if len(sys.argv) > 1:
    game=sys.argv[1]
    print "Generating file for game: ",game
    if game != "makaimur" and game != "makaimurg" and game != "gngt" and game != "gngc":
        print "Wrong game name. Please use one of these:"
        print "makaimur, makaimurg, gng, gngc"
        exit(1)
else:
    game="gngt"

fo = open('JTGNG.rom','wb')

def append_file( file_list ):
    for fname in file_list:
        with open(fname,'rb') as f:
            fo.write( f.read() )

def byte_merge( file_list ):    
    with open(file_list[0],'rb') as flsb:
        blsb = flsb.read()
    with open(file_list[1],'rb') as fmsb:
        bmsb = fmsb.read()
    for k in range(len(blsb)):
        fo.write( blsb[k] )
        fo.write( bmsb[k] )

def append_dup( filename ):
    with open(filename,'rb') as f:
        buf = f.read()        
    for k in range(len(buf)):
        fo.write(buf[k])
        fo.write(buf[k])

if game == "makaimur":
    roms = {
        'rom8n'     : '8n.rom',
        'rom10n'    : '10n.rom',
        'rom12n'    : '12n.rom',
        'rom_char'  : 'gg1.bin',
        'audio'     : 'gg2.bin',
        'romx9'     : 'gg9.bin',
        'romx7'     : 'gg7.bin',
        'romx11'    : 'gg11.bin',
        'romx8'     : 'gg8.bin',
        'romx6'     : 'gg6.bin',
        'romx10'    : 'gg10.bin',
        'romx17'    : 'gng13.n4',
        'romx16'    : 'gg16.bin',
        'romx15'    : 'gg15.bin',
        'romx14'    : 'gng16.l4',
        'romx13'    : 'gg13.bin',
        'romx12'    : 'gg12.bin' }
elif game == "makaimurg":
    roms = {
        'rom10n'    : 'mj04g.bin',
        'rom8n'     : 'mj03g.bin',
        'rom12n'    : 'mj05g.bin',
        'rom_char'  : 'gg1.bin',
        'audio'     : 'gg2.bin',
        'romx9'     : 'gg9.bin',
        'romx7'     : 'gg7.bin',
        'romx11'    : 'gg11.bin',
        'romx8'     : 'gg8.bin',
        'romx6'     : 'gg6.bin',
        'romx10'    : 'gg10.bin',
        'romx17'    : 'gng13.n4',
        'romx16'    : 'gg16.bin',
        'romx15'    : 'gg15.bin',
        'romx14'    : 'gng16.l4',
        'romx13'    : 'gg13.bin',
        'romx12'    : 'gg12.bin' }
elif game == "gngc":
        roms = {
        'rom10n'    :'mm_c_04',
        'rom8n'     :'mm_c_03',
        'rom12n'    :'mm_c_05',
        'rom_char'  :'gg1.bin',
        'audio'     :'gg2.bin',
        'romx9'     :'gg9.bin',
        'romx7'     :'gg7.bin',
        'romx11'    :'gg11.bin',
        'romx8'     :'gg8.bin',
        'romx6'     :'gg6.bin',
        'romx10'    :'gg10.bin',
        'romx17'    :'gng13.n4',
        'romx16'    :'gg16.bin',
        'romx15'    :'gg15.bin',
        'romx14'    :'gng16.l4',
        'romx13'    :'gg13.bin',
        'romx12'    :'gg12.bin' }
elif game == "gngt":
    roms = {
        'rom8n'     :'mmt03d.8n',
        'rom10n'    :'mmt04d.10n',
        'rom12n'    :'mmt05d.13n',
        'rom_char'  :'mm01.11e',
        'audio'     :'mm02.14h',
        'romx9'     :'mm09.3c',
        'romx7'     :'mm07.3b',
        'romx11'    :'mm11.3e',
        'romx8'     :'mm08.1c',
        'romx6'     :'mm06.1b',
        'romx10'    :'mm10.1e',
        'romx17'    :'mm17.4n',
        'romx16'    :'mm16.3n',
        'romx15'    :'mm15.1n',
        'romx14'    :'mm14.4l',
        'romx13'    :'mm13.3l',
        'romx12'    :'mm12.1l' }

append_file( [roms['rom8n'], roms['rom10n'], roms['rom12n']] )
# print "Sound starts at "
append_file( [roms['audio']] )
# print "Char starts at "
append_file( [roms['rom_char']] )
# print "Scroll starts at "
byte_merge( [roms['romx9'], roms['romx7']])
byte_merge( [roms['romx8'], roms['romx6']])
# print "Scroll upper 8 bits at "
append_dup( roms['romx11'])
append_dup( roms['romx10'])
# print "Object starts at "
byte_merge( [roms['romx17'], roms['romx14']])
byte_merge( [roms['romx16'], roms['romx13']])
byte_merge( [roms['romx15'], roms['romx12']])
