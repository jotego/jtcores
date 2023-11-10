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

# MRA tool to generate .arc files
cd /tmp
git clone https://github.com/mist-devel/mra-tools-c.git
cd mra-tools-c.git
make -j
mv mra /usr/local/bin/mra

# Verilator
apt install git help2man perl python3 make autoconf g++ flex bison ccache
apt install libgoogle-perftools-dev numactl perl-doc
apt install libfl2  # Ubuntu only (ignore if gives error)
apt install libfl-dev  # Ubuntu only (ignore if gives error)
apt install zlibc zlib1g zlib1g-dev  # Ubuntu only (ignore if gives error)

cd $HOME
unset VERILATOR_ROOT
git clone http://git.veripool.org/git/verilator --depth 1 || exit $?
cd $HOME/verilator
autoconf
./configure
# compile using 80% of available CPUs
make -j $((`nproc`*4/5))
export VERILATOR_ROOT=`pwd`
echo export VERILATOR_ROOT=`pwd` >> $HOME/.bashrc

# nice to have
apt install --yes htop

# git configuration
git config --global url.ssh://git@github.com/.insteadOf https://github.com/
git config --global alias.d diff
git config --global alias.co checkout
git config --global alias.st status
git config --global alias.p pull
git config --global alias.b bisect
git config --global alias.su "submodule update"
git config --global alias.r "reset --hard"
git config pull.rebase true

# Go
GONAME=go1.21.3.linux-amd64.tar.gz
wget https://go.dev/dl/$GONAME
rm -rf /usr/local/go && tar -C /usr/local -xzf $GONAME
rm -f $GONAME
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
echo export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin >> $HOME/.bashrc
go install github.com/spf13/cobra-cli@latest
go install golang.org/x/tools/cmd/goimports@latest
go install golang.org/x/tools/cmd/godoc@latest


# GitHub CLI
type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
&& sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& sudo apt update \
&& sudo apt install gh -y

# Set up repositories
cat<<EOF
Run these commands after setting the SSH key in GitHub

cd $HOME
git clone --recurse-submodules git@github.com:jotego/jtcores.git
mkdir jtmisc
cd jtmisc
git clone --depth 1 --shallow-since="$(date --date='-2 weeks' +%F)" git@github.com:jotego/jtbin.git
git clone git@github.com:jotego/jtbeta.git
git clone git@github.com:JTFPGA/jtutil.git
EOF
