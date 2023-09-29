#!/bin/bash
# Packages needed on a fresh Ubuntu 20,04 installation
# Sublime-text isn't really needed for compilation but
# it is the recommended text editor

set -e

# Sublime
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list

apt update
apt upgrade --yes

apt install --yes --install-suggests apt-transport-https nfs-common
apt install --yes --install-suggests build-essential git gtkwave figlet xmlstarlet \
    sublime-text docker

# required by iverilog
apt install --yes flex gperf bison

# required by MAME
apt install --yes libqwt-qt5-dev libsdl2-dev libfontconfig1-dev libsdl2-ttf-dev \
    libfontconfig-dev libpulse-dev qtbase5-dev qtbase5-dev-tools \
    qtchooser qt5-qmake

# jtcore and jtupdate
apt install --yes parallel locate python3-pip
updatedb

# open picoblaze assembler needed for assembling the cheat and beta code
pip install --upgrade opbasm

# as31 to compile 8051/8751 assembler code
apt install --yes as31

# asm48 to compile MCS-48 assembler code
cd /tmp
git clone https://github.com/jotego/asm48.git
cd asm48
make
cp 8039dasm asm48 /usr/local/bin

# macro assembler for many, many CPUs
cd /tmp
wget http://john.ccac.rwth-aachen.de:8000/ftp/as/source/c_version/asl-current.tar.gz
tar xfz asl-current.tar.gz
cd asl-current
make
cp alink asl p2bin p2hex pbind plist *.msg /usr/local/bin
cp man/* /usr/local/share/man/man1/

# Verilator
cd $HOME
unset VERILATOR_ROOT
git clone http://git.veripool.org/git/verilator --depth 1 || exit $?
cd $HOME/verilator
autoconf
./configure
# compile using 80% of available CPUs
make -j $((`nproc`*4/5))
export VERILATOR_ROOT=`pwd`