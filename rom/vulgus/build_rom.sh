#!/bin/bash

###########################
# GAME and ROM Definition #
###########################

OrigGameRom=vulgus.zip
FinalGameRom=JTVULGUS.rom

RomBlock[0]="MAIN         ;vulgus.002;vulgus.003;vulgus.004;vulgus.005;1-8n.bin"
RomBlock[1]="SOUND        ;1-11c.bin;1-11c.bin"
RomBlock[2]="CHAR         ;1-3d.bin"
# note that SCROLL Z is repeated
# lower bytes
RomBlock[3]="SCROLL Z     ;2-4a.bin;2-5a.bin"
RomBlock[4]="SCROLL X     ;2-2a.bin;2-3a.bin"
# upper bytes
RomBlock[5]="SCROLL Y     ;2-6a.bin;2-7a.bin"
RomBlock[6]="SCROLL Y     ;2-6a.bin;2-7a.bin"
# lower bytes
RomBlock[7]="Objects XW   ;2-4n.bin;2-5n.bin"
# upper bytes
RomBlock[8]="Objects ZY   ;2-2n.bin;2-3n.bin"
# Not in SDRAM:
#  0    1   2  3    4  5  6   7   8     9
# IRQ  c9.bin x 3   R  G  B CHAR OBJ  Timing
RomBlock[9]="PROMs        ;82s126.9k;c9.bin;c9.bin;c9.bin;e8.bin;e9.bin;e10.bin;d1.bin;j2.bin;82s129.8n"

romset='212'
md5valid='410250f0a3af08ead86b4ddd8dd78006'
fullname='Vulgus CAPCOM (1984)'

tmpdir='./tmp/'

#########################
# The command line help #
#########################
display_help() {
    echo "Usage: $0 [option...] " >&2
    echo
    echo "   -d, --rom_dir            Set the directory where the Mame ROMs or game ROM are located"
    echo "   -m, --merged             Use Merged Roms "
    echo
    exit 1
}

#########################
# Rom Length Function   #
#########################

function rom_len {
    echo $(printf "%05Xh" $(du --bytes $FinalGameRom | cut -f 1))
}

#########################
# Generation            #
#########################
echo
echo -e "ROM Generator for $fullname FPGA replication by Jotego\n"


#while getopts d:m:g: option
#do
#case "${option}"
#in
#d) MAME_DIR=${OPTARG};;
#m) MERGED=${OPTARG};;
#g) GAME=${OPTARG};;
#esac
#done
#echo 'Directorio mame' $MAME_DIR
#echo 'Merged' $MERGED
#echo 'Game' $GAME

if [ ! -f "$OrigGameRom" ]; then
    echo -e "ERROR: Original ROM $OrigGameRom not found. Please use MAME $romset merged rom\n"
    exit 1
    #display_help
else
    #Unzip to TMP
    if [ ! -d $tmpdir ]; then
        mkdir $tmpdir
    fi
    unzip=$(command -v unzip)
    if [ -z "$unzip" ]; then
        echo -e "ERROR: Unzip command not available. Please install with: apt-get install unzip\n"
        exit 1
    fi
    unzip -o $OrigGameRom -d $tmpdir > /dev/null 2>&1
fi

# Create and populate ROM file
if [ -f "$FinalGameRom" ]; then
    rm -f $FinalGameRom
    touch $FinalGameRom
fi

echo "ROM Block Info"
for block in "${RomBlock[@]}"
do
    IFS=";" read -r -a files <<< "${block}"
    echo "${files[0]} starts at $(rom_len)"
    files=("${files[@]:1}") #Shift
    for i in "${files[@]}"; do
        if [ ! -e $tmpdir$i ]; then
            echo -e "ERROR: Cannot find rom file $tmpdir$i. Please use MAME $romset merged rom\n"
            exit 1
        fi
        cat $tmpdir$i >> $FinalGameRom
    done
done

echo
echo "ROM $FinalGameRom generated OK"
echo "ROM length $(rom_len)"

#Clean Temporal Dir
rm -rf $tmpdir


#Documentation

#cp JTVULGUS.rom $JTGNG/rom/JTVULGUS.rom

#echo 1 - Vulgus (set 1) - Default
#echo 2 - Mach-9 (bootleg of Vulgus)
#echo 3 - Vulgus (Japan?)
#echo 4 - Vulgus (set 2)
#
#:VULGUS
#set zip1m=MAME\vulgus.zip
#set ifilesm=vulgus.002+vulgus.003+vulgus.004+vulgus.005+1-8n.bin+1-11c.bin+1-11c.bin+1-3d.bin+2-4a.bin+2-5a.bin+2-2a.bin+2-3a.bin+2-6a.bin+2-7a.bin+2-6a.bin+2-7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+e10.bin+d1.bin+j2.bin+82s129.8n
#set zip1=MAME\vulgus.zip
#set ifiles=vulgus.002+vulgus.003+vulgus.004+vulgus.005+1-8n.bin+1-11c.bin+1-11c.bin+1-3d.bin+2-4a.bin+2-5a.bin+2-2a.bin+2-3a.bin+2-6a.bin+2-7a.bin+2-6a.bin+2-7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+e10.bin+d1.bin+j2.bin+82s129.8n
#set md5valid=410250f0a3af08ead86b4ddd8dd78006
#set ofile=JTVULGUS.ROM
#set fullname=Vulgus (set 1) - Default
#
#:MACH9
#set zip1m=MAME\vulgus.zip
#set ifilesm=mach9\02_4n.bin+vulgus.003+vulgus.004+mach9\05_7n.bin+1-8n.bin+1-11c.bin+1-11c.bin+mach9\01_3d.bin+2-4a.bin+mach9\11_5a.bin+2-2a.bin+mach9\09_3a.bin+2-6a.bin+mach9\13_7a.bin+2-6a.bin+mach9\13_7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+mach9\82s129_10e.bin+d1.bin+j2.bin+82s129.8n
#set zip1=MAME\mach9.zip
#set ifiles=02_4n.bin+03_5n.bin+04_6n.bin+05_7n.bin+06_8n.bin+07_11c.bin+07_11c.bin+01_3d.bin+10_4a.bin+11_5a.bin+08_2a.bin+09_3a.bin+12_6a.bin+13_7a.bin+12_6a.bin+13_7a.bin+16_4n.bin+17_5n.bin+14_2n.bin+15_3n.bin+82s129_9k.bin+82s129_9c.bin+82s129_9c.bin+82s129_9c.bin+82s129_8e.bin+82s129_9e.bin+82s129_10e.bin+82s129_1d.bin+82s129_2j.bin+82s129_8n.bin
#set md5valid=eb03683437787decdc1b80c689baff6d
#set ofile=Mach-9 (bootleg of Vulgus).rom
#set fullname=Mach-9 (bootleg of Vulgus)
#
#:VULGUSJ
#set zip1m=MAME\vulgus.zip
#set ifilesm=vulgusj\1-4n.bin+vulgusj\1-5n.bin+vulgusj\1-6n.bin+vulgusj\1-7n.bin+1-8n.bin+1-11c.bin+1-11c.bin+1-3d.bin+2-4a.bin+2-5a.bin+2-2a.bin+2-3a.bin+2-6a.bin+2-7a.bin+2-6a.bin+2-7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+e10.bin+d1.bin+j2.bin+82s129.8n
#set zip1=MAME\vulgusj.zip
#set ifiles=1-4n.bin+1-5n.bin+1-6n.bin+1-7n.bin+1-8n.bin+1-11c.bin+1-11c.bin+1-3d.bin+2-4a.bin+2-5a.bin+2-2a.bin+2-3a.bin+2-6a.bin+2-7a.bin+2-6a.bin+2-7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+e10.bin+d1.bin+j2.bin+82s129.8n
#set md5valid=8515013723d82c947293f8d17f37549a
#set ofile=Vulgus (Japan).rom
#set fullname=Vulgus (Japan?)
#
#:VULGUSA
#set zip1m=MAME\vulgus.zip
#set ifilesm=vulgusa\v2+vulgusa\v3+vulgusa\v4+vulgusa\v5+1-8n.bin+1-11c.bin+1-11c.bin+1-3d.bin+2-4a.bin+2-5a.bin+2-2a.bin+2-3a.bin+2-6a.bin+2-7a.bin+2-6a.bin+2-7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+e10.bin+d1.bin+j2.bin+82s129.8n
#set zip1=MAME\vulgusa.zip
#set ifiles=v2+v3+v4+v5+1-8n.bin+1-11c.bin+1-11c.bin+1-3d.bin+2-4a.bin+2-5a.bin+2-2a.bin+2-3a.bin+2-6a.bin+2-7a.bin+2-6a.bin+2-7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+e10.bin+d1.bin+j2.bin+82s129.8n
#set md5valid=cc7ff45328905f65aa6866e90260d081
#set ofile=Vulgus (set 2).rom
#set fullname=Vulgus (set 2)
#

